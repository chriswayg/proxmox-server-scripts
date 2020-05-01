#!/bin/bash
# automatic removal of Proxmox subscription reminder during upgrades
# - tested with Proxmox 6
#
# exit on error
set -e

#echo "--- File changed: $1" >> /var/log/incron.log

# Since we are watching the whole directory, we need to check for the correct file
if [ "$1" == "proxmoxlib.js.dpkg-tmp" ]; then
    echo "$(date +%Y-%m-%d_%H:%M) proxmoxlib.js has been upgraded - patching file" >> /var/log/incron.log

    # wait a bit until the file has its permanent name
    sleep 15

    # patch the files
    cp /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js.bak
    sed -i "s/data.status !== 'Active'/false/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
    systemctl restart pveproxy.service

    # log  the changes
    diff /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js.bak /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js >> /var/log/incron.log
fi
