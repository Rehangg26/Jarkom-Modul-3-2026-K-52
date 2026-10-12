//jalankan di jichi:

# Install DHCP relay jika belum ada
if ! command -v dhcrelay >/dev/null 2>&1; then
  apt update
  apt install -y isc-dhcp-relay
fi

# Konfigurasi DHCP relay:
# eth2 = Net2 client DHCP
# eth3 = Net3 client DHCP
# eth4 = jalur ke DHCP server tengen
cat > /etc/default/isc-dhcp-relay <<'EOF'
SERVERS="192.237.4.10"
INTERFACES="eth2 eth3 eth4"
OPTIONS=""
EOF

#untuk resart
service isc-dhcp-relay restart
