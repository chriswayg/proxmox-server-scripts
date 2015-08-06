#!/bin/bash
# Script for static network setup in a Debian 7 or 8  KVM guest on a Proxmox host
# for use after cloning a KVM
#
# The host server has one bridge for routing additional IPs
# and another bridge for local IP's with NAT accessible via the main server IP
mainserverip="217.79.181.100"

getinfo() {
  read -e -p "Enter the IP address for your server: " -i "10.10.10.254" staticip
  read -e -p "Enter the netmask for your network: " -i "255.255.255.0" netmask
  read -e -p "Enter the IP of your Gateway: " -i "10.10.10.1" gatewayip
  read -e -p "Enter the Hostname: " -i "$HOSTNAME" newhostname
}

getinfoaddip() {
  read -e -p "Enter the IP address for your server (additional external IP): " -i "203.0.113.0" staticip
  read -e -p "Enter the netmask for your point-to-point network: " -i "255.255.255.255" netmask
  read -e -p "Enter the IP of your Gateway (main Proxmox IP): " -i "$mainserverip" gatewayip
  read -e -p "Enter the Hostname: " -i "$HOSTNAME" newhostname
}

writenetworkfile() {
#> /etc/network/interfaces
cat << EOF > /etc/network/interfaces
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).
# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto eth0
#Your static network configuration
iface eth0 inet static
# Guest on vmbr1 behind NAT
address $staticip
netmask $netmask
gateway $gatewayip
EOF

# add pointopoint for external IP address
if [[ $addip == "Y" || $addip == "y" ]]; then
    echo "pointopoint $gatewayip" >> /etc/network/interfaces
    echo "# use vmbr0 on Proxmox server" >> /etc/network/interfaces
fi

# change hosts
cat << EOF > /etc/hosts
127.0.0.1       localhost
$staticip       $newhostname.lightinasia.org       $newhostname

# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF
#don't use any space before of after 'EOF' in the previous lines

# change hostname
echo "$newhostname" > /etc/hostname
hostname -F /etc/hostname

  echo ""
  echo "Your settings were saved in"
  echo "    /etc/network/interfaces"
  echo "    /etc/hosts"
  echo "    /etc/hostname"
  echo ""
  echo "restarting networking..."
  systemctl restart networking; systemctl status networking
  echo ""
  echo "NETWORK:"
  ip addr show dev eth0
  echo "ROUTE:"
  ip route
  exit 0
}

checkinfo() {
read -p "Are you configuring this server with an additional external IP (answer no if using NAT)? [y/n]: " addip
  case $addip in
    [Yy]* ) getinfoaddip;;
    [Nn]* ) getinfo;;
        * ) echo "Please enter y or n!"
            exit 1
            ;;
esac
echo ""
echo "Your settings will be changed to the following:"
echo "Your hostname is:             $newhostname"
echo "Your decicated Server IP is:  $staticip"
echo "The mask for the Network is:  $netmask"
echo "Address of your Gateway is:   $gatewayip"
echo ""
}

clear
echo "Let's set up a static IP address and hostname for your VM"
echo ""
checkinfo

while true; do
  read -p "Are these settings correct? [y/n]: " yn
  case $yn in
    [Yy]* ) writenetworkfile;;
    [Nn]* ) checkinfo;;
        * ) echo "Please enter y or n!";;
  esac
done
