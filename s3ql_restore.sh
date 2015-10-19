#!/bin/bash

# Restore the whole Proxmox system from a s3ql backup to the same system
# or a system with similar hardware and the same filesystem

# Abort entire script if any command fails
set -e

# Install s3ql (pve-enterprise.list causes error during update)
rm -vf /etc/apt/sources.list.d/pve-enterprise.list
apt-get update && apt-get install -y s3ql

# Additional backup of essential networking files
# - adding a random string to prevent it from being overwritten, if running script repeatedly
rand=$(cat /dev/urandom | tr -cd 'a-f0-9' | head -c 8)
cp /etc/network/interfaces /etc/network/interfaces.bak-$rand
cp /etc/hosts /etc/hosts.bak-$rand
cp /etc/hostname /etc/hostname.bak-$rand
cp /etc/resolv.conf /etc/resolv.conf.bak-$rand

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
    fsck.s3ql --log /var/log/s3ql/fsck.log --authfile "$AUTHFILE" "$STORAGE_URL"
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

# disable firewall, as sometimes locked out after restore
cat >  /etc/pve/firewall/cluster.fw  << "EOF"
[OPTIONS]
enable: 0
EOF

# restore the system using 10 rsync processes
# - file exclusions are already handled by the backup script
# - thus this method should be faster
/usr/lib/s3ql/pcp.py -a --debug $backupdir/$from_backup/ /

## restore the system using 1 rsync process with exclusion file list
# - use this, if you need to exclude additional files
# - if the s3ql_backup script was used, then exclusions were already applied during backup
# cat > /tmp/exclude.txt << "EOF"
# /etc/pve/firewall/cluster.fw
# /etc/network/interfaces
# /etc/hosts
# /etc/hostname
# EOF
#
# rsync --archive --hard-links --acls --xattrs --one-file-system \
#        --partial-dir=.rsync-partial \
#        --progress --human-readable --stats \
#        --log-file="/var/log/s3ql/rsync-restore-$from_backup.log" \
#        --exclude-from=/tmp/exclude.txt \
#        "$backupdir/$from_backup/" "/"
# rm /tmp/exclude.txt

echo -e "\n*** Things TO DO after restore:"
echo "* check and reenable Proxmox Firewall (as it has been disabled)"
echo "* possibly run 'update-grub'"

echo -e "\n*** The following files were not overwritten, but can be restored manually:"
echo "- /boot/grub/grub.cfg.restore"
echo "- /etc/resolv.conf.restore"
echo "- /etc/issue.restore"
echo "- /etc/fstab.restore"
echo "- /etc/udev.restore"

echo -e "\n*** If you restored Proxmox to a different system,"
echo "you may need to modify the following files before restarting:"
echo "* /etc/network/interfaces - Main IP, additional IPs, NAT rules"
echo "  (also inside KVMs utilizing an additional IP)"
echo "* /etc/hosts - Main IP (also inside KVMs utilizing an additional IP)"
echo "* /etc/hostname - be sure to check hostname configuration"
echo "* These are available for manual or automatic restore here:"
echo "* /etc/network/interfaces.restore, /etc/hosts.restore, /etc/hostname.restore"

echo -e "\nOverwrite networking files & hostname now? [y/n]"
    read -n 1 -r
    if ! [[ $REPLY =~ ^[Yy]$ ]]
    then
            exit
    fi

# restore these files    
cp -v /etc/network/interfaces.restore /etc/network/interfaces
cp -v /etc/hosts.restore /etc/hosts
cp -v /etc/hostname.restore /etc/hostname
hostname -F /etc/hostname
