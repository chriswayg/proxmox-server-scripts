#!/bin/bash

# Restore the whole Proxmox system from a s3ql backup

# Abort entire script if any command fails
set -e

# Backup essential networking files
cp /etc/network/interfaces /etc/network/interfaces.bak
cp /etc/hosts /etc/hosts.bak
cp /etc/resolv.conf /etc/resolv.conf.bak

# default log location is 
mkdir -p ~/.s3ql

# This has all the s3 auth information (careful where you store the script!)
if [ ! -f ~/.s3ql/authinfo2 ]; then
cat >  ~/.s3ql/authinfo2  << "EOF"
[s3]
storage-url: s3://proxmoxchris
backend-login: [AWS Access Key ID]
backend-password: [AWS Secret Access Key]
fs-passphrase: ********
EOF
chmod -v 600 ~/.s3ql/authinfo2
fi

# Restore from source mounted with s3ql filesystem
mountpoint="/mnt/s3ql"
backupdir="$mountpoint/proxmoxfs"
AUTHFILE="/root/.s3ql/authinfo2"
STORAGE_URL="s3://proxmoxchris"

mkdir -p $mountpoint
# put all s3ql logs here
mkdir -p /var/log/s3ql

# check, if backup filesystem is mounted
if ! mountpoint -q "$mountpoint"; then
    echo "mounting $mountpoint"
    # Check and mount file system
    fsck.s3ql --log /var/log/s3ql/fsck.log --batch --authfile "$AUTHFILE" "$STORAGE_URL"
    mount.s3ql --log /var/log/s3ql/mount.log --authfile "$AUTHFILE" "$STORAGE_URL" "$mountpoint"
fi

# exit, if not mounted
mountpoint "$mountpoint"

# optional argument is a valid backup directory like 2015-07-30_21:53:13
# if no directory is given, then use the most recent backup
if [ $# -ge 1 ]
then
  from_backup=$1
else
# Figure out the most recent backup
cd "$backupdir"
from_backup=`python <<EOF
import os
import re
backups=sorted(x for x in os.listdir('.') if re.match(r'^[\\d-]{10}_[\\d:]{8}$', x))
if backups:
    print backups[-1]
EOF`
fi

if [ ! -d "$backupdir/$from_backup" ]; then
  echo -e "\nusage: s3ql_restore.sh [YYYY-MM-DD_HH:MM]"
  echo "Please choose a valid backup from:"
  ls -1 $backupdir
  exit 1
fi

echo -e "\nRestore from $backupdir/$from_backup with the following content? [y/n]"
ls $backupdir/$from_backup
    read -n 1 -r
    if ! [[ $REPLY =~ ^[Yy]$ ]]
    then
            echo -e "\nAbort..."
            exit
    fi
echo

# restore the system using 10 rsync processes
/usr/lib/s3ql/pcp.py -a --debug $backupdir/$from_backup/ /

## restore the system using 1 rsync process with exclusion file list
# cat > /tmp/exclude.txt << "EOF"
# /boot/grub/grub.cfg
# /etc/udev
# /etc/mtab
# /etc/fstab
# /etc/issue
# /dev
# /proc
# /sys
# /tmp
# /run
# /mnt
# /media
# /lost+found
# /var/lib/vz/images
# /var/lib/vz/private
# /var/lib/vz/root
# /root/.s3ql
# EOF
# rsync --archive --hard-links --acls --xattrs --one-file-system \
#        --partial-dir=.rsync-partial \
#        --progress --human-readable --stats \
#        --log-file="/var/log/s3ql/rsync-restore-$from_backup.log" \
#        --exclude-from=/tmp/exclude.txt \
#        "$backupdir/$from_backup/" "/"
# rm /tmp/exclude.txt

echo -e "\nYou need to modify the following files before restarting:"
echo "* /etc/network/interfaces - Main IP, additional IPs, NAT rules"
echo "  (also inside KVMs utilizing an additional IP)"
echo "* /etc/hosts - Main IP (also inside KVMs utilizing an additional IP)"
echo "* /etc/resolv.conf - DNS"
echo "* possibly run update-grub"
