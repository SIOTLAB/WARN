cat > /etc/NetworkManager/conf.d/100-disable-wifi-randomization.conf <<EOF
[connection]
wifi.mac-address-randomization=1

[device]
wifi.scan-rand-mac-address=no
