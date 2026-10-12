#di tengen:

cat >> /etc/dhcp/dhcpd.conf <<'EOF'

host kugisaki {
  hardware ethernet 02:42:c6:ce:c0:00;
  fixed-address 192.237.3.99;
}
EOF

#cek error
dhcpd -t -cf /etc/dhcp/dhcpd.conf

#restart
service isc-dhcp-server restart

#cek di kugisaki:
udhcpc -i eth0
