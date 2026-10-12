//jalankan di tengen:

cat > /etc/dhcp/dhcpd.conf <<'EOF'
default-lease-time 600;
max-lease-time 7200;

authoritative;

class "net2-pool-a" {
  match if binary-to-ascii(16, 8, ":", substring(hardware, 1, 6)) = "2:42:37:27:6:0" or
           binary-to-ascii(16, 8, ":", substring(hardware, 1, 6)) = "2:42:0:c1:ee:0";
}

class "net2-pool-b" {
  match if binary-to-ascii(16, 8, ":", substring(hardware, 1, 6)) = "2:42:d:fc:26:0" or
           binary-to-ascii(16, 8, ":", substring(hardware, 1, 6)) = "2:42:69:17:c1:0";
}

subnet 192.237.4.0 netmask 255.255.255.0 {
}

subnet 192.237.2.0 netmask 255.255.255.0 {
  option routers 192.237.2.1;
  option broadcast-address 192.237.2.255;
  option domain-name-servers 192.237.1.2, 192.237.1.3;
  option domain-name "k52.com";

  pool {
    allow members of "net2-pool-a";
    range 192.237.2.10 192.237.2.35;
  }

  pool {
    allow members of "net2-pool-b";
    range 192.237.2.70 192.237.2.95;
  }
}

subnet 192.237.3.0 netmask 255.255.255.0 {
  range 192.237.3.10 192.237.3.199;
  option routers 192.237.3.1;
  option broadcast-address 192.237.3.255;
  option domain-name-servers 192.237.1.2, 192.237.1.3;
  option domain-name "k52.com";
}
EOF

#Restart DHCP
service isc-dhcp-server restart

#jalankan ini di Net2 (itadori, fushiguro, zenin, okkotsu):
udhcpc -i eth0
