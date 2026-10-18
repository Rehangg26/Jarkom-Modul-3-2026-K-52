//Jalanin di geto (Load Balancer internal, 192.237.4.18):
#!/bin/sh

# Nomor 15 - Nginx LB, upstream api_cluster, Weighted Round Robin 3:1

ip addr replace 192.237.4.18/24 dev eth0
ip route replace default via 192.237.4.1 dev eth0
echo "nameserver 192.168.122.1" > /etc/resolv.conf

apt update
apt install -y nginx curl

cat > /etc/nginx/conf.d/upstream.conf <<'EOF'
upstream api_cluster {
  server 192.237.4.15 weight=3;   # nanami
  server 192.237.4.16 weight=1;   # todo
}
EOF

cat > /etc/nginx/sites-available/geto <<'EOF'
server {
  listen 80 default_server;
  server_name jujutsu.k52.com;

  # hanya gojo dan jaringan Data Center
  allow 192.237.1.10;
  allow 192.237.4.0/24;
  deny all;

  location / {
    proxy_pass http://api_cluster;
    proxy_set_header Host $host;
  }
}
EOF

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/geto /etc/nginx/sites-enabled/geto
nginx -t && service nginx restart


//TEST distribusi 3:1 - jalanin dari tengen (jaringan lokal Data Center):
apt install -y curl
for i in $(seq 1 40); do
  curl -s http://192.237.4.18/api | grep -o '"worker":"[a-z]*"'
done | sort | uniq -c
# hasil yang diharapkan: nanami 30 : todo 10

#kalo error
#Jalankan di Yaga
echo "skip-name-resolve" >> /etc/mysql/mariadb.conf.d/99-master.cnf
service mariadb restart

#Nanami
time mysql -h 192.237.4.11 -ushibuya -pshibuya_k52 -e "SELECT 1;"

#Geto -> kalo ini udah langsung ke test lagi
curl --max-time 5 http://192.237.4.15/api
curl --max-time 5 http://192.237.4.16/api

