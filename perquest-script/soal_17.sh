//=============== gojo ===============
#header X-Real-IP dan X-Forwarded-For sudah ada di config nomor 16, cek:
grep -n "X-Real-IP\|X-Forwarded-For" /etc/nginx/sites-available/gojo
nginx -t && service nginx reload


//=============== geto (192.237.4.18) ===============
#!/bin/sh

# Nomor 17 - geto hanya percaya header klien dari proxy terpercaya (gojo)
# Pakai geo/map, BUKAN realip module, supaya $remote_addr tetap IP asli koneksi
# sehingga allow/deny tetap bekerja.

cat > /etc/nginx/conf.d/trust.conf <<'EOF'
# proxy terpercaya
geo $remote_addr $trusted_proxy {
  default       0;
  192.237.1.10  1;   # gojo
}

# header X-Real-IP harus berformat IPv4 yang valid
map $http_x_real_ip $valid_real_ip {
  default "";
  "~^[0-9]{1,3}(\.[0-9]{1,3}){3}$" $http_x_real_ip;
}

# kalau datang dari gojo -> pakai header; selain itu -> pakai IP koneksi asli
map $trusted_proxy $real_client_ip {
  1       $valid_real_ip;
  default $remote_addr;
}

map $trusted_proxy $real_xff {
  1       $http_x_forwarded_for;
  default $remote_addr;
}
EOF

cat > /etc/nginx/sites-available/geto <<'EOF'
server {
  listen 80 default_server;
  server_name jujutsu.k52.com;

  allow 192.237.1.10;
  allow 192.237.4.0/24;
  deny all;

  location / {
    proxy_pass http://api_cluster;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $real_client_ip;
    proxy_set_header X-Forwarded-For $real_xff;
  }
}
EOF

nginx -t && service nginx restart


//=============== nanami, todo, kirara ===============
#!/bin/sh

# API hanya mempercayai X-Real-IP kalau koneksi datang dari geto, dan IP divalidasi.
# (realip module tidak dipakai di worker karena akan merusak allow/deny geto)

cat > /var/www/api/api/index.php <<'EOF'
<?php
mysqli_report(MYSQLI_REPORT_OFF);
header('Content-Type: application/json');

$trusted_proxy = '192.237.4.18';   // geto
$client_ip = $_SERVER['REMOTE_ADDR'];

if ($client_ip === $trusted_proxy && !empty($_SERVER['HTTP_X_REAL_IP'])) {
  $cand = trim($_SERVER['HTTP_X_REAL_IP']);
  if (filter_var($cand, FILTER_VALIDATE_IP)) {
    $client_ip = $cand;
  }
}

$logged = false;
$db = @new mysqli('192.237.4.11', 'shibuya', 'shibuya_k52', 'db_shibuya_k52');
if (!$db->connect_errno) {
  $host = gethostname();
  $path = $_SERVER['REQUEST_URI'];
  $stmt = $db->prepare("INSERT INTO request_logs (client_ip, hostname, path) VALUES (?,?,?)");
  $stmt->bind_param('sss', $client_ip, $host, $path);
  $logged = $stmt->execute();
}

echo json_encode([
  'status'    => 'ok',
  'worker'    => gethostname(),
  'client_ip' => $client_ip,
  'logged'    => $logged
]);
EOF


//=============== TEST ===============
#dari klien Net2 (mis. itadori) dan Net3 (mis. ino), catat IP-nya dulu:
ip -br addr show eth0
curl -s http://jujutsu.k52.com/api

#coba spoof header, harus tetap tercatat IP asli (gojo menimpa header):
curl -s -H "X-Real-IP: 1.2.3.4" -H "X-Forwarded-For: 1.2.3.4" http://jujutsu.k52.com/api

#cek database di yaga:
mysql -e "SELECT id, client_ip, hostname, path, created_at FROM db_shibuya_k52.request_logs ORDER BY id DESC LIMIT 10;"
# client_ip harus = IP klien (192.237.2.x / 192.237.3.x), bukan IP gojo (192.237.1.10) / geto (192.237.4.18)
