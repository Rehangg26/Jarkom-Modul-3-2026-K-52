#cek mekanisme autostart
ps -p 1 -o comm,args

#agar script tidak jalan terlalu cepat, tambahin ini
#jichi
#!/bin/sh

sleep 3
exec >> /root/init.log 2>&1
echo "init jichi started $(date)"

#tengen
#!/bin/sh

sleep 3
exec >> /root/init.log 2>&1
echo "init tengen started $(date)"

#utahime
#!/bin/sh

sleep 3
exec >> /root/init.log 2>&1
echo "init utahime started $(date)"

#shoko
#!/bin/sh

sleep 3
exec >> /root/init.log 2>&1
echo "init shoko started $(date)"

#jalankan ini di setiap node tadi (jichi, tengen, utahime, shoko)
chmod +x /root/init.sh



#cek di jichi
ip -br addr
ip route
sysctl net.ipv4.ip_forward
ps aux | grep dhcrelay

#cek di tengen
ip -br addr
service isc-dhcp-server status

#cek di utahime
ip -br addr#

#cek di shoko
ip -br addr
