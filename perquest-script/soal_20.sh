//Jalanin di kusakabe (Net3):
#!/bin/sh

# Nomor 20 - Benchmark dengan Apache Benchmark

apk update
apk add apache2-utils curl

# Ringkasan metrik penting dari output ab
ringkas() {
  egrep "Requests per second|Time per request|Failed requests|Non-2xx|Complete requests|50%|95%|99%|Length|Exceptions"
}

//--- 1. Baseline web utama (/) ---
ab -n 600 -c 30 http://jujutsu.k52.com/ | tee /root/ab_root.txt | ringkas

//--- 2. /api dengan rate limiting AKTIF ---
ab -n 600 -c 30 http://jujutsu.k52.com/api | tee /root/ab_api_limit.txt | ringkas

//--- 3. Baseline /api TANPA rate limit ---
//matikan rate limit dulu di gojo:
: > /etc/nginx/snippets/api_ratelimit.conf
nginx -t && nginx -s reload

//jalankan lagi di kusakabe:
ab -n 600 -c 30 http://jujutsu.k52.com/api | tee /root/ab_api_baseline.txt | ringkas

//hidupkan lagi rate limit di gojo:
cat > /etc/nginx/snippets/api_ratelimit.conf <<'EOF'
limit_req zone=apilimit;
limit_req_status 429;
EOF
nginx -t && nginx -s reload

//--- 4. Bandingkan hasil (di kusakabe) ---
for f in ab_root ab_api_baseline ab_api_limit; do
  echo "== $f =="
  egrep "Requests per second|Time per request|Failed requests|Non-2xx" /root/$f.txt
done

# CATATAN: "Failed requests (Length)" di ab sering false-positive karena isi
# respon beda tiap worker (maki/panda, nanami/todo). Kalau mau mengabaikannya,
# tambahkan opsi -l: ab -l -n 600 -c 30 http://jujutsu.k52.com/


//--- 5. Analisis access log di gojo ---
echo "Total request:"; wc -l < /var/log/nginx/gojo_access.log

echo "Distribusi status HTTP:"
grep -o ' status=[0-9]*' /var/log/nginx/gojo_access.log | sort | uniq -c

echo "Ditolak rate limit (429, ups=- karena ditolak gojo sebelum ke upstream):"
grep 'status=429' /var/log/nginx/gojo_access.log | grep -c 'ups=-'

echo "Kegagalan aplikasi/upstream (5xx dari backend, ups berisi kode):"
grep -E 'status=5[0-9]{2}' /var/log/nginx/gojo_access.log | grep -vc 'ups=-'

echo "Kegagalan koneksi (499 = klien menutup koneksi):"
grep -c 'status=499' /var/log/nginx/gojo_access.log

echo "Cache web (HIT/MISS):"
grep -o 'cache=[A-Z-]*' /var/log/nginx/gojo_access.log | sort | uniq -c

# Cara membedakan:
#  - request ditolak kebijakan : status=429, ups=-          (dari gojo sendiri)
#  - kegagalan aplikasi        : status=502/503/504, ups=502/.. (backend error)
#  - kegagalan koneksi         : status=499 atau ab "Failed requests (Connect/Exceptions)"
