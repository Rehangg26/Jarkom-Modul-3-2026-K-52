#jalankan ini untuk ngecek apakah daftar lease DHCP dari server sudah sesuai
#di tengen:
cat /var/lib/dhcp/dhcpd.leases

#jika di tengen tidak muncul punya kugisaki
#bisa melakukan ping melalui itadori ke kugisaki
ping -c 3 192.237.3.100
