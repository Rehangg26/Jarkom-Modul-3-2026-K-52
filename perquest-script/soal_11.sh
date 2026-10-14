//Jalanin di utahime (DNS MASTER):
#!/bin/sh

# Nomor 11 - BIND9 Master di utahime
# Kelompok K52, <xxxx> = k52  -> domain jujutsu.k52.com

ip addr replace 192.237.1.2/24 dev eth0
ip route replace default via 192.237.1.1 dev eth0
echo "nameserver 192.168.122.1" > /etc/resolv.conf

if ! command -v named >/dev/null 2>&1; then
  apt update
  apt install -y bind9 bind9utils dnsutils
fi

mkdir -p /etc/bind/jarkom

cat > /etc/bind/named.conf.local <<'EOF'
zone "jujutsu.k52.com" {
  type master;
  file "/etc/bind/jarkom/db.jujutsu.k52.com";
  notify yes;
  also-notify { 192.237.1.3; };
  allow-transfer { 192.237.1.3; };
};
EOF

cat > /etc/bind/jarkom/db.jujutsu.k52.com <<'EOF'
$TTL 604800
@   IN  SOA ns1.jujutsu.k52.com. admin.jujutsu.k52.com. (
        2026101301 ; Serial
        604800     ; Refresh
        86400      ; Retry
        2419200    ; Expire
        604800 )   ; Negative Cache TTL
;
@   IN  NS  ns1.jujutsu.k52.com.
@   IN  NS  ns2.jujutsu.k52.com.
ns1 IN  A   192.237.1.2
ns2 IN  A   192.237.1.3
EOF

chown -R root:bind /etc/bind/jarkom

# cek error
named-checkconf
named-checkzone jujutsu.k52.com /etc/bind/jarkom/db.jujutsu.k52.com

service named restart 2>/dev/null || service bind9 restart


//Jalanin di shoko (DNS SLAVE):
#!/bin/sh

# Nomor 11 - BIND9 Slave di shoko

ip addr replace 192.237.1.3/24 dev eth0
ip route replace default via 192.237.1.1 dev eth0
echo "nameserver 192.168.122.1" > /etc/resolv.conf

if ! command -v named >/dev/null 2>&1; then
  apt update
  apt install -y bind9 bind9utils dnsutils
fi

cat > /etc/bind/named.conf.local <<'EOF'
zone "jujutsu.k52.com" {
  type slave;
  masters { 192.237.1.2; };
  file "/var/lib/bind/db.jujutsu.k52.com";
};
EOF

named-checkconf
service named restart 2>/dev/null || service bind9 restart

# cek zona sudah ke-transfer
sleep 2
ls -l /var/lib/bind/
dig @192.237.1.3 jujutsu.k52.com SOA +short


//TEST SINKRONISASI: naikkan serial di utahime
sed -i 's/2026101301/2026101302/' /etc/bind/jarkom/db.jujutsu.k52.com
rndc reload

//lalu cek di shoko (serial harus ikut naik jadi 2026101302):
dig @192.237.1.3 jujutsu.k52.com SOA +short


//TEST dari salah satu client (itadori / ino / dll):
dig @192.237.1.2 jujutsu.k52.com NS
dig @192.237.1.3 jujutsu.k52.com NS
dig @192.237.1.2 jujutsu.k52.com SOA +short
dig @192.237.1.3 jujutsu.k52.com SOA +short
