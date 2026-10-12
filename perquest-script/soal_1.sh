//Jalanin di jichi: 
#!/bin/sh

# Nomor 1 - Konfigurasi router jichi

# IP NAT ke GNS3 NAT
ip addr replace 192.168.122.100/24 dev eth0

# IP gateway untuk tiap network internal
ip addr replace 192.237.1.1/24 dev eth1
ip addr replace 192.237.2.1/24 dev eth2
ip addr replace 192.237.3.1/24 dev eth3
ip addr replace 192.237.4.1/24 dev eth4

# Default route ke NAT GNS3
ip route replace default via 192.168.122.1 dev eth0

# Aktifkan routing antar-interface
sysctl -w net.ipv4.ip_forward=1

# Source NAT agar client internal bisa keluar lewat eth0
iptables -t nat -C POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null || \
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE


//Jalanin di utahime:
#!/bin/sh

# Nomor 1 - IP statis utahime
# Kelompok K52, prefix 192.237.x.x

ip addr replace 192.237.1.2/24 dev eth0
ip route replace default via 192.237.1.1 dev eth0

//Jalanin di shoko:
#!/bin/sh

# Nomor 1 - IP statis shoko
# Kelompok K52, prefix 192.237.x.x

ip addr replace 192.237.1.3/24 dev eth0
ip route replace default via 192.237.1.1 dev eth0

//Jalanin di tengen:
#!/bin/sh

# Nomor 1 - IP statis tengen
# Kelompok K52, prefix 192.237.x.x

ip addr replace 192.237.4.10/24 dev eth0
ip route replace default via 192.237.4.1 dev eth0
