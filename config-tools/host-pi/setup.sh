#!/bin/bash

if [ "$EUID" -ne 0 ]
    then echo "Script must be run as root"
    exit
fi

systemctl daemon-reload
systemctl stop NetworkManager
systemctl disable NetworkManager avahi-daemon libnss-mdns

apt update
apt install -y libnss-resolve hostapd
rm /etc/resolv.conf
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

rm -r /etc/network /etc/dhcp

systemctl enable systemd-networkd
systemctl enable systemd-resolved
systemctl start systemd-networkd

cat > /etc/systemd/network/05-wired.network <<EOF
[Match]
Name=e*

[Network]
## Uncomment only one option block
# Option: using a DHCP server and multicast DNS
LLMNR=no
LinkLocalAddressing=no
MulticastDNS=yes
DHCP=ipv4

# Option: using link-local ip addresses and multicast DNS
#LLMNR=no
#LinkLocalAddressing=yes
#MulticastDNS=yes

# Option: using static ip address and multicast DNS
# (example, use your settings)
#Address=192.168.50.60/24
#Gateway=192.168.50.1
#DNS=84.200.69.80 1.1.1.1
#MulticastDNS=yes
EOF

cat > /etc/systemd/network/02-br0.netdev <<EOF
[NetDev]
Name=br0
Kind=bridge
EOF

cat > /etc/systemd/network/04-br0_add-eth0.network <<EOF
[Match]
Name=eth0
[Network]
Bridge=br0
EOF

cat > /etc/systemd/network/12-br0_up.network <<EOF
[Match]
Name=br0
[Network]
MulticastDNS=yes
DHCP=yes
# to use static IP uncomment these and comment DHCP=yes
#Address=192.168.50.60/24
#Gateway=192.168.50.1
#DNS=84.200.69.80 1.1.1.1
EOF

cp ./hostapd.conf /etc/hostapd/hostapd.conf

systemctl unmask hostapd
systemctl enable hostapd

reboot
