# proxmox-server-scripts
Miscellaneous scripts for configuring and administering a Proxmox (Debian) server and VMs

#### Backup and Restore with S3QL

 - s3ql: an init script for mounting the s3ql encryped filesystem for use as a storage directory in Proxmox
 - s3ql_backup.sh: for backing up a whole Proxmox server with s3ql to Amazon S3 storage
 - s3ql_restore.sh:	for restoring a whole Proxmox server with 3sql from Amazon S3 storage

#### Networking in KVM Guests
 - setup_network.sh: for changing static network settings in Debian guest VM after cloning

#### Automatically remove Proxmox “No Valid Subscription” message on upgrades

It is annoying, that the Proxmox “No Valid Subscription” message re-appears after each Proxmox software update, even if you initially patched the pve-manager file. Since Proxmox is free software under the GPL, I do not like the connotation of the message, which makes it sound like one is using unlicenced software. If you want to use the community repository for updates and do not need commercial support, it is completely legitimate to run Proxmox this way. If you want to use the 'enterprise repository', please look into the attractive [subscription options](https://www.proxmox.com/en/proxmox-ve/pricing). 

 - proxmox_noreminder.sh: the script automatically removes the Proxmox 3.4 “No Valid Subscription” message on upgrades by watching the relevant directory with ```incron```. Incron is watching the directory, as it seems to trigger more reliably than watching only the file. A few files in this directory are replaced during each upgrade, but only one needs to be patched in this edition of Proxmox. The script also patches the Proxmox Support Tab with a more friendly message.

Initially backup & patch the files manually and confirm with diff, that the changes are as expected:
```
cp /usr/share/pve-manager/ext4/pvemanagerlib.js /usr/share/pve-manager/ext4/pvemanagerlib.js.bak
sed -i -r -e "s/if \(data.status !== 'Active'\) \{/if (false) {/" /usr/share/pve-manager/ext4/pvemanagerlib.js 
sed -i -r -e "s/You do not have a valid subscription for this server/This server is receiving updates from the Proxmox VE No-Subscription Repository/" /usr/share/pve-manager/ext4/pvemanagerlib.js 
sed -i -r -e "s/No valid subscription/Community Edition/" /usr/share/pve-manager/ext4/pvemanagerlib.js

diff /usr/share/pve-manager/ext4/pvemanagerlib.js.bak /usr/share/pve-manager/ext4/pvemanagerlib.js
```

Install Incron and only allow the root user
```
apt-get install incron
echo "root" >> /etc/incron.allow
```

and copy the script:
```
mkdir -v /etc/incron.scripts
cp proxmox_noreminder.sh /etc/incron.scripts/proxmox_noreminder.sh
chmod +x /etc/incron.scripts/proxmox_noreminder.sh
```

Add the following in incrontab
```
incrontab -e
...
/usr/share/pve-manager/ext4/ IN_CREATE /etc/incron.scripts/proxmox_noreminder.sh $#
```

Test with (in another terminal):
```
tail -f /var/log/syslog | grep incrond
tail -n 30 -f /var/log/incron.log
```
Reinstalling pve-manager should trigger incron:
```
apt-get install --reinstall pve-manager
```

###### Disclaimer:
*The above scripts & patches may have unforeseen consequences and automatic patching could harm your system. Always backup your Proxmox system before applying such changes! Proxmox may change the code at any time, making the patches useless or even counterproductive. Please make sure you understand the code before applying it to your system. Also, IANAL, and in my opinion the above Proxmox patches are permitted under the GPL, but if want to make sure, please consult a copyright lawyer in your jurisdiction. This disclaimer should not be interpreted as legal advice.*

---
###### License:
This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.
