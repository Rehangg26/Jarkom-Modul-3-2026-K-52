//jalanin di tengen
#!/bin/sh

# Nomor 1 dan 2 - tengen sebagai DHCP server
# Kelompok K52, prefix 192.237.x.x

# IP statis tengen di Net4
ip addr replace 192.237.4.10/24 dev eth0
ip route replace default via 192.237.4.1 dev eth0

# DNS sementara untuk install/update package
echo "nameserver 192.168.122.1" > /etc/resolv.conf

# Install DHCP server jika belum ada
if ! command -v dhcpd >/dev/null 2>&1; then
  apt update
  apt install -y isc-dhcp-server
fi

# Konfigurasi DHCP server
cat > /etc/dhcp/dhcpd.conf <<'EOF'
default-lease-time 600;
max-lease-time 7200;

authoritative;

subnet 192.237.4.0 netmask 255.255.255.0 {
}

subnet 192.237.2.0 netmask 255.255.255.0 {
  range 192.237.2.10 192.237.2.95;
  option routers 192.237.2.1;
  option broadcast-address 192.237.2.255;
  option domain-name-servers 192.237.1.2, 192.237.1.3;
  option domain-name "k52.com";
}

subnet 192.237.3.0 netmask 255.255.255.0 {
  range 192.237.3.10 192.237.3.199;
  option routers 192.237.3.1;
  option broadcast-address 192.237.3.255;
  option domain-name-servers 192.237.1.2, 192.237.1.3;
  option domain-name "k52.com";
}
EOF

# Jalankan DHCP server di interface Net4
sed -i 's/^INTERFACESv4=.*/INTERFACESv4="eth0"/' /etc/default/isc-dhcp-server

dhcpd -t -cf /etc/dhcp/dhcpd.conf
service isc-dhcp-server restart
