//ASUMSI IP (sesuaikan dengan tabel spesifikasi, find&replace kalau beda):
# gojo 192.237.1.10  (DMZ / Net1)
# Net4: tengen .10, yaga .11, inumaki .12, maki .13, panda .14,
#       nanami .15, todo .16, kirara .17, geto .18
# Zona reverse = 1.237.192.in-addr.arpa (karena gojo di 192.237.1.x)

//Jalanin di utahime (MASTER):
#!/bin/sh

# Nomor 12 - A record, CNAME, PTR, Forwarder

# Forwarder ke gateway internet
cat > /etc/bind/named.conf.options <<'EOF'
options {
  directory "/var/cache/bind";
  forwarders { 192.168.122.1; };
  recursion yes;
  allow-query { any; };
  allow-recursion { any; };
  dnssec-validation no;
  listen-on-v6 { any; };
};
EOF

# Tambah zona reverse
cat > /etc/bind/named.conf.local <<'EOF'
zone "jujutsu.k52.com" {
  type master;
  file "/etc/bind/jarkom/db.jujutsu.k52.com";
  notify yes;
  also-notify { 192.237.1.3; };
  allow-transfer { 192.237.1.3; };
};

zone "1.237.192.in-addr.arpa" {
  type master;
  file "/etc/bind/jarkom/db.192.237.1";
  notify yes;
  also-notify { 192.237.1.3; };
  allow-transfer { 192.237.1.3; };
};
EOF

# Zona forward (serial dinaikkan)
cat > /etc/bind/jarkom/db.jujutsu.k52.com <<'EOF'
$TTL 604800
@   IN  SOA ns1.jujutsu.k52.com. admin.jujutsu.k52.com. (
        2026101303 ; Serial
        604800     ; Refresh
        86400      ; Retry
        2419200    ; Expire
        604800 )   ; Negative Cache TTL
;
@   IN  NS  ns1.jujutsu.k52.com.
@   IN  NS  ns2.jujutsu.k52.com.
ns1 IN  A   192.237.1.2
ns2 IN  A   192.237.1.3
@   IN  A   192.237.1.10
www IN  CNAME jujutsu.k52.com.
EOF

# Zona reverse
cat > /etc/bind/jarkom/db.192.237.1 <<'EOF'
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
2   IN  PTR ns1.jujutsu.k52.com.
3   IN  PTR ns2.jujutsu.k52.com.
10  IN  PTR jujutsu.k52.com.
EOF

chown -R root:bind /etc/bind/jarkom

named-checkconf
named-checkzone jujutsu.k52.com /etc/bind/jarkom/db.jujutsu.k52.com
named-checkzone 1.237.192.in-addr.arpa /etc/bind/jarkom/db.192.237.1

service named restart 2>/dev/null || service bind9 restart


//Jalanin di shoko (SLAVE):
#!/bin/sh

cat > /etc/bind/named.conf.options <<'EOF'
options {
  directory "/var/cache/bind";
  forwarders { 192.168.122.1; };
  recursion yes;
  allow-query { any; };
  allow-recursion { any; };
  dnssec-validation no;
  listen-on-v6 { any; };
};
EOF

cat > /etc/bind/named.conf.local <<'EOF'
zone "jujutsu.k52.com" {
  type slave;
  masters { 192.237.1.2; };
  file "/var/lib/bind/db.jujutsu.k52.com";
};

zone "1.237.192.in-addr.arpa" {
  type slave;
  masters { 192.237.1.2; };
  file "/var/lib/bind/db.192.237.1";
};
EOF

named-checkconf
service named restart 2>/dev/null || service bind9 restart

sleep 2
ls -l /var/lib/bind/


//TEST dari client (Net2 / Net3):
dig jujutsu.k52.com A +short
dig www.jujutsu.k52.com CNAME
dig -x 192.237.1.10
dig @192.237.1.2 www.jujutsu.k52.com CNAME +short
dig @192.237.1.3 -x 192.237.1.10 +short

#cek forwarder & internet
dig google.com +short
ping -c 3 google.com
