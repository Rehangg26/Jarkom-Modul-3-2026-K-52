#matikan DHCP relay di jichi
#ketik ini di jichi:
service isc-dhcp-relay stop

#cek apakah benar benar mati
ps aux | grep dhcrelay

#sekarang cek di ino:
ip addr flush dev eth0

#jalankan ini di ino:
udhcpc -i eth0 -n -q
#ino pasti gagal untuk mendapatkan new ip dari jichi karena DHCP relay mati
#contoh otput:
# udhcpc: broadcasting discover
# udhcpc failed to get a DHCP lease
# udhcpc: no lease, failing

#jalanin di jichi 
#buat restart DHCP relay:
service isc-dhcp-relay start

#cek lagi di ino apakah sudah nyala 
#cek di ino:
udhcpc -i eth0 -n -q
