#!/bin/bash

# Used for backing up a complete Proxmox 3.4 server on Debian 7 
# the VM's (in lib/vz) are backed up separately by Proxmox

# This backup script should be run daily via cron

# Abort entire script if any command fails
set -e

# Exclude the following from being backed up, because:
# - /udev/ files can cause eth0 to be renamed
# - /cluster.fw - we disable firewall during restore
# - interfaces, hosts & hostname may need to be modified
# - resolv.conf can interrupt rsync
# - /etc/issue has Proxmox server IP in it
# - grub.cfg has hardware specific UUIDs for the disks
# - fstab could have disk UUIDs, mtab is dynamic
# - .s3ql data is handled by s3ql itself
# - /mnt/ contains the /s3ql backup dir
# - /dev /proc /sys /run are populated at boot
# - /tmp /media /lost+found does not need to be backed up
# - lib/vz holding VM's are backed up separately by Proxmox
cat > /tmp/exclude.txt << "EOF"
/etc/udev
/etc/pve/firewall/cluster.fw
/etc/network/interfaces
/etc/hosts
/etc/hostname
/etc/resolv.conf
/etc/issue
/boot/grub/grub.cfg
/etc/fstab
/etc/mtab
/root/.s3ql
/mnt
/dev
/proc
/sys
/run
/tmp
/media
/lost+found
/var/lib/vz/images
/var/lib/vz/private
/var/lib/vz/root
EOF

# copy some excluded files for later reference
cp /boot/grub/grub.cfg /boot/grub/grub.cfg.restore
cp /etc/issue /etc/issue.restore
cp /etc/resolv.conf /etc/resolv.conf.restore
cp /etc/fstab /etc/fstab.restore
cp -R /etc/udev/ /etc/udev.restore/

# copy network related files for optional restore
cp /etc/network/interfaces /etc/network/interfaces.restore
cp /etc/hosts /etc/hosts.restore
cp /etc/hostname /etc/hostname.restore

# Backup destination with s3ql filesystem
# - authinfo2 needs to be provided and storage already active on S3
mountpoint="/mnt/s3ql"
backupdir="$mountpoint/proxmoxfs"
AUTHFILE="/root/.s3ql/authinfo2"
STORAGE_URL="s3://proxmoxchris"

mkdir -p /var/log/s3ql

# check, if backup filesystem is mounted
if ! mountpoint -q "$mountpoint"; then
    # clean mountpoint
    rm -vfR $mountpoint/*
    # Check and mount file system
    fsck.s3ql --log /var/log/s3ql/fsck.log --batch --authfile "$AUTHFILE" "$STORAGE_URL"
    mount.s3ql --log /var/log/s3ql/mount.log --authfile "$AUTHFILE" "$STORAGE_URL" "$mountpoint"
fi

# exit, if not mounted
mountpoint "$mountpoint"

# Figure out the most recent backup
mkdir -p "$backupdir"
cd "$backupdir"
last_backup=`python <<EOF
import os
import re
backups=sorted(x for x in os.listdir('.') if re.match(r'^[\\d-]{10}_[\\d:]{8}$', x))
if backups:
    print backups[-1]
EOF`

# Duplicate the most recent backup unless this is the first backup
# s3qlcp duplicates a directory tree without physically copying the file contents
new_backup=`date "+%Y-%m-%d_%H:%M:%S"`
if [ -n "$last_backup" ]; then
    echo "Copying $last_backup to $new_backup..."
    s3qlcp "$last_backup" "$new_backup"

    # Make the last backup immutable
    # (in case the previous backup was interrupted prematurely)
    s3qllock "$last_backup"
fi

# ..and update the copy using rsync
rsync --archive --hard-links --acls --xattrs --one-file-system \
      --delete-during --delete-excluded --partial-dir=.rsync-partial \
      --progress --human-readable --stats \
      --log-file="/var/log/s3ql/rsync-backup-$new_backup" \
      --exclude-from=/tmp/exclude.txt \
      "/" "./$new_backup/"

# Make the new backup immutable
s3qllock "$new_backup"

# Expire old backups
# intelligently removes old backups that are no longer needed
expire_backups --use-s3qlrm 1 2 7 14 31 90 180 360

rm /tmp/exclude.txt

# the filesystem stays mounted, as it is also used for other backups
# an init script unmounts the fs before shutdown
