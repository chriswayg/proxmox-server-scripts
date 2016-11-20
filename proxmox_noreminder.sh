#!/bin/bash
# automatic removal of Proxmox subscription reminder during upgrades
# - tested with Proxmox 3.4 and 4.0
#
# exit on error
set -e

# Since we are watching the whole directory, we need to check for the correct file
if [ "$1" == "pvemanagerlib.js.dpkg-tmp" ]; then
    echo "$(date +%Y-%m-%d_%H:%M) pvemanagerlib.js has been upgraded - patching file" >> /var/log/incron.log

    # wait a bit until the file has its permanent name
    sleep 10

    # patch the files
    cp /usr/share/pve-manager/ext6/pvemanagerlib.js /usr/share/pve-manager/ext6/pvemanagerlib.js.bak
    sed -i -r -e "s/if \(data.status !== 'Active'\) \{/if (false) {/" /usr/share/pve-manager/ext6/pvemanagerlib.js >>/var/log/incron.log 2>&1
    sed -i -r -e "s/You do not have a valid subscription for this server/This server is receiving updates from the Proxmox VE No-Subscription Repository/" /usr/share/pve-manager/ext6/pvemanagerlib.js >>/var/log/incron.log 2>&1
    sed -i -r -e "s/No valid subscription/Community Edition/" /usr/share/pve-manager/ext6/pvemanagerlib.js >>/var/log/incron.log 2>&1

    # log  the changes
    diff /usr/share/pve-manager/ext6/pvemanagerlib.js.bak /usr/share/pve-manager/ext6/pvemanagerlib.js >> /var/log/incron.log
fi
