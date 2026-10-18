//Jalanin di gojo:
#!/bin/sh

# Nomor 19 - Proxy Cache (10 menit) + Rate Limit /api (10 r/s per IP)

mkdir -p /var/cache/nginx/web
chown -R www-data:www-data /var/cache/nginx/web

# Global: log format, cache path, zona rate limit
cat > /etc/nginx/conf.d/gojo_global.conf <<'EOF'
log_format gojo_ext 'ip=$remote_addr time=$time_iso8601 req="$request" status=$status ups=$upstream_status cache=$upstream_cache_status rt=$request_time urt=$upstream_response_time';

proxy_cache_path /var/cache/nginx/web levels=1:2 keys_zone=webcache:10m max_size=100m inactive=10m use_temp_path=off;

limit_req_zone $binary_remote_addr zone=apilimit:10m rate=10r/s;
EOF

# Snippet rate limit (dipisah supaya gampang di-on/off untuk nomor 20)
mkdir -p /etc/nginx/snippets
cat > /etc/nginx/snippets/api_ratelimit.conf <<'EOF'
limit_req zone=apilimit;
limit_req_status 429;
EOF

cat > /etc/nginx/sites-available/gojo <<'EOF'
server {
  listen 80 default_server;
  server_name jujutsu.k52.com www.jujutsu.k52.com;

  access_log /var/log/nginx/gojo_access.log gojo_ext;

  # Web frontend: Round Robin + cache 10 menit
  location / {
    proxy_pass http://frontend_cluster;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $remote_addr;

    proxy_cache webcache;
    proxy_cache_key "$scheme$host$request_uri";
    proxy_cache_valid 200 10m;
    add_header X-Cache-Status $upstream_cache_status always;
  }

  # API: rate limit 10 r/s per IP klien, diteruskan ke geto
  location /api {
    include snippets/api_ratelimit.conf;

    proxy_pass http://geto_backend;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $remote_addr;
  }
}
EOF

nginx -t && service nginx restart


//TEST CACHE (dari client):
for i in 1 2 3; do curl -s -D - -o /dev/null http://jujutsu.k52.com/ | grep -i x-cache-status; done
# akses pertama: MISS, selanjutnya: HIT

//TEST RATE LIMIT (dari client), 40 request paralel ke /api:
seq 1 40 | xargs -P 20 -I{} curl -s -o /dev/null -w "%{http_code}\n" http://jujutsu.k52.com/api | sort | uniq -c
# Respon 200 = lolos, 429 = ditolak karena melewati 10 r/s

//cek di gojo:
grep -c "status=429" /var/log/nginx/gojo_access.log
tail -n 20 /var/log/nginx/gojo_access.log
