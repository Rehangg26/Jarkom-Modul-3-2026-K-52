//Jalanin di geto:
#!/bin/sh

# Nomor 18 - kirara = backup, passive health check

cat > /etc/nginx/conf.d/upstream.conf <<'EOF'
upstream api_cluster {
  server 192.237.4.15 weight=3 max_fails=2 fail_timeout=5s;   # nanami
  server 192.237.4.16 weight=1 max_fails=2 fail_timeout=5s;   # todo
  server 192.237.4.17 backup;                                  # kirara
}
EOF

# pindah ke server berikutnya kalau error, supaya klien tidak kena 502
grep -q proxy_next_upstream /etc/nginx/sites-available/geto || \
sed -i '/proxy_pass http:\/\/api_cluster;/a\    proxy_next_upstream error timeout http_502 http_503 http_504;\n    proxy_connect_timeout 2s;' /etc/nginx/sites-available/geto

nginx -t && service nginx restart


//TEST FAILOVER
#1. Matikan Nginx di nanami dan todo:
service nginx stop

#2. Dari klien (Net2/Net3), semua request harus dijawab kirara, tanpa 502:
for i in $(seq 1 12); do curl -s -o /dev/null -w "%{http_code}\n" http://jujutsu.k52.com/api; done | sort | uniq -c
for i in $(seq 1 6); do curl -s http://jujutsu.k52.com/api; echo; done
# "worker":"kirara", status 200

#3. Pulihkan nanami dan todo:
service nginx start
#tunggu >5 detik (fail_timeout), lalu cek lagi, harus balik ke nanami/todo:
sleep 6
for i in $(seq 1 8); do curl -s http://jujutsu.k52.com/api | grep -o '"worker":"[a-z]*"'; done | sort | uniq -c
