# proxmox-server-scripts
Miscellaneous scripts for configuring and administering a Proxmox (Debian) server and VMs

 - s3ql: an init script for mounting the s3ql encryped filesystem for use as a storage directory in Proxmox
 - s3ql_backup.sh: for backing up a whole Proxmox server with s3ql to Amazon S3 storage
 - s3ql_restore.sh:	for restoring a whole Proxmox server with 3sql from Amazon S3 storage
 - setup_network.sh: for changing static network settings in Debian guest VM after cloning


---
###### License:
This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.
