#lakukan tcpdump di tengen
tcpdump -i eth0 -n -vvv port 67 or port 68

#langsung buka node itadori
#request ulang DHCP lease dari server:
udhcpc -i eth0 -n
