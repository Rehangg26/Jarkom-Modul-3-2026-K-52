//Jalanin di gojo (Reverse Proxy publik, 192.237.1.10):
#!/bin/sh

# Nomor 16 - Path-Based Routing
#   /     -> maki & panda (Round Robin)
#   /api  -> geto

ip addr replace 192.237.1.10/24 dev eth0
ip route replace default via 192.237.1.1 dev eth0
echo "nameserver 192.168.122.1" > /etc/resolv.conf

apt update
apt install -y nginx curl

cat > /etc/nginx/conf.d/upstream_gojo.conf <<'EOF'
upstream frontend_cluster {
  server 192.237.4.13;   # maki
  server 192.237.4.14;   # panda
}

upstream geto_backend {
  server 192.237.4.18;   # geto
}
EOF

cat > /etc/nginx/sites-available/gojo <<'EOF'
server {
  listen 80 default_server;
  server_name jujutsu.k52.com www.jujutsu.k52.com;

  location / {
    proxy_pass http://frontend_cluster;
    proxy_set_header Host $host;
    # header IP klien (juga dipakai untuk nomor 17)
    proxy_set_header X-Real-IP $remote_addr;
    # gojo adalah proxy paling depan -> XFF di-reset, tidak percaya XFF dari klien
    proxy_set_header X-Forwarded-For $remote_addr;
  }

  location /api {
    proxy_pass http://geto_backend;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $remote_addr;
  }
}
EOF

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/gojo /etc/nginx/sites-enabled/gojo
nginx -t && service nginx restart


//TEST dari client Divisi A atau B:
#Round robin frontend: harus gantian maki / panda
for i in 1 2 3 4; do curl -s http://jujutsu.k52.com/; done
curl -s http://www.jujutsu.k52.com/

#/api: dijawab nanami / todo (rasio 3:1)
for i in 1 2 3 4; do curl -s http://jujutsu.k52.com/api; echo; done

#kalau DNS belum bisa, pakai header Host:
curl -s -H "Host: jujutsu.k52.com" http://192.237.1.10/
