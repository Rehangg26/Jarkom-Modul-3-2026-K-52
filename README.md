# Praktikum Jaringan Komputer Modul 3 — K-52 (2026)

## Pemetaan jaringan

| Jaringan | Subnet | Gateway | Isi |
|---|---|---|---|
| Network 1 / DMZ | 192.237.1.0/24 | 192.237.1.1 | utahime, shoko, gojo |
| Network 2 / Divisi A | 192.237.2.0/24 | 192.237.2.1 | itadori, fushiguro, zenin, okkotsu |
| Network 3 / Divisi B | 192.237.3.0/24 | 192.237.3.1 | ino, kusakabe, miwa, kugisaki |
| Network 4 / Data Center | 192.237.4.0/24 | 192.237.4.1 | DHCP, database, load balancer, worker |

| Node | IP / kebijakan | Peran |
|---|---|---|
| jichi eth0 | WAN DHCP, terlihat 192.168.122.100/24 | ke NAT GNS3 |
| jichi eth1–eth4 | 192.237.1.1, .2.1, .3.1, .4.1 | gateway empat subnet |
| utahime | 192.237.1.2/24 | DNS Master |
| shoko | 192.237.1.3/24 | DNS Slave |
| gojo | 192.237.1.10/24 | Public reverse proxy |
| tengen | 192.237.4.10/24 | DHCP server |
| yaga | 192.237.4.11/24 | MariaDB Master |
| inumaki | 192.237.4.12/24 | MariaDB Slave |
| maki | 192.237.4.13/24 | Frontend |
| panda | 192.237.4.14/24 | Frontend |
| nanami | 192.237.4.15/24 | API utama, bobot 3 |
| todo | 192.237.4.16/24 | API utama, bobot 1 |
| kirara | 192.237.4.17/24 | API backup |
| geto | 192.237.4.18/24 | Load balancer API |
| itadori, fushiguro | 192.237.2.10–192.237.2.35 | Pool 1 |
| zenin, okkotsu | 192.237.2.70–192.237.2.95 | Pool 2 |
| ino, kusakabe | 192.237.3.10–192.237.3.89 | Short lease 1800 detik |
| miwa | 192.237.3.100–192.237.3.199 | Long lease 43200 detik |
| kugisaki | 192.237.3.99 | Fixed address berdasarkan MAC |

Alamat infrastruktur mengikuti skrip K-52 nomor 12, 16, dan 17; tabel spesifikasi terpisah tidak terdapat pada lampiran. Semua host statis memakai gateway `.1` pada subnet masing-masing.

## Alur layanan

- DHCP: client Network 2/3 → relay jichi → tengen.
- DNS: client → utahime atau shoko; shoko menerima transfer zona dari utahime.
- Frontend: client → gojo → maki/panda.
- API: client → gojo → geto → nanami/todo; kirara sebagai backup.
- Database: API → yaga → replikasi ke inumaki.

## Daftar soal

- [Soal 1 — Konektivitas Dasar dan NAT](#soal-1)
- [Soal 2 — DHCP Server Tengen](#soal-2)
- [Soal 3 — DHCP Relay Jichi](#soal-3)
- [Soal 4 — Dua Pool DHCP Network 2](#soal-4)
- [Soal 5 — Short Lease dan Long Lease](#soal-5)
- [Soal 6 — Static Lease Kugisaki](#soal-6)
- [Soal 7 — Validasi Konfigurasi Klien](#soal-7)
- [Soal 8 — Packet Capture DHCP DORA](#soal-8)
- [Soal 9 — Gangguan dan Pemulihan Relay](#soal-9)
- [Soal 10 — Autostart setelah Restart](#soal-10)
- [Soal 11 — DNS Master–Slave](#soal-11)
- [Soal 12 — A, CNAME, PTR, dan DNS Forwarder](#soal-12)
- [Soal 13 — Replikasi MariaDB](#soal-13)
- [Soal 14 — Frontend, API, dan Pembatasan Akses](#soal-14)
- [Soal 15 — Weighted Round Robin 3:1](#soal-15)
- [Soal 16 — Path-Based Routing Gojo](#soal-16)
- [Soal 17 — Pencatatan IP Asli Klien](#soal-17)
- [Soal 18 — Failover ke Worker Cadangan](#soal-18)
- [Soal 19 — Proxy Cache dan Rate Limiting](#soal-19)
- [Soal 20 — Benchmark dan Analisis Log](#soal-20)

---

<a id="soal-1"></a>

## Soal 1 — Konektivitas Dasar dan NAT

### Soal

> Ketika Curtain menutup Shibuya, jalur komunikasi antar zona Jujutsu High terputus. Pulihkan konektivitas dasar dengan mengonfigurasi jichi: eth0 memperoleh WAN dari NAT, sedangkan eth1–eth4 menjadi gateway Network 1–4 sesuai tabel pemetaan. Aktifkan IPv4 forwarding dan source NAT, lalu tetapkan IP statis host infrastruktur sesuai tabel spesifikasi. Buktikan konektivitas setiap host ke gateway dan akses eksternal dari host yang relevan.

### Maksud soal

Menghubungkan empat subnet melalui jichi, menyediakan gateway, dan menerjemahkan alamat sumber saat trafik keluar menuju NAT GNS3.

### Cara mengerjakan

**Pada jichi**, WAN menggunakan DHCP di konfigurasi persisten `/etc/network/interfaces`:

```ini
auto eth0
iface eth0 inet dhcp
```

Interface internal menggunakan alamat gateway pada tabel di atas. Aktifkan forwarding dan NAT:

```sh
sysctl -w net.ipv4.ip_forward=1
printf 'net.ipv4.ip_forward=1\n' > /etc/sysctl.d/99-jarkom.conf
iptables -t nat -C POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null ||
  iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
```

**Pada masing-masing host infrastruktur**, beri IP sesuai tabel dan default route ke gateway subnetnya. Contoh utahime:

```sh
ip addr replace 192.237.1.2/24 dev eth0
ip route replace default via 192.237.1.1 dev eth0
printf 'nameserver 192.168.122.1\n' > /etc/resolv.conf
```

Pola yang sama berlaku untuk seluruh host statis. Route default di jichi didapat dari DHCP WAN; jangan mengasumsikan IP WAN selalu `.100`.

Skrip yang tersimpan di repository: [soal_1.sh](perquest-script/soal_1.sh). Bagian penyesuaian di atas perlu dibedakan dari script sumber.

### Cara melakukan validasi

```sh
ip -br addr
ip route
sysctl net.ipv4.ip_forward
iptables -t nat -S POSTROUTING
# Pada setiap host: ping gateway sesuai subnet
ping -c 3 192.237.1.1
ping -c 3 192.168.122.1
ping -c 3 google.com
```

### Bukti pengujian

**1. IP di Jichi**

![1. IP di Jichi](<Assets/1. IP di Jichi.png>)

### Hasil dan analisis

Script asli mengunci WAN ke `192.168.122.100/24`, dan gambar memperlihatkan alamat itu. Persyaratan soal meminta WAN melalui DHCP; konfigurasi DHCP WAN diberikan di bawah sebagai penyesuaian. Foto ini membuktikan IP interface jichi, belum membuktikan ping setiap host atau seluruh akses eksternal.

---

<a id="soal-2"></a>

## Soal 2 — DHCP Server Tengen

### Soal

> Tengen, penjaga pusat distribusi di Data Center, harus mengambil alih pengalokasian alamat bagi wilayah yang membutuhkan konfigurasi dinamis. Konfigurasikan isc-dhcp-server pada [PREFIX IP].4.10. Deklarasikan Network 4 ([PREFIX IP].4.0/24) sebagai subnet lokal tanpa pool dinamis, lalu siapkan scope DHCP untuk Network 2 ([PREFIX IP].2.0/24) dan Network 3 ([PREFIX IP].3.0/24). Validasi konfigurasi dan pastikan service aktif tanpa error “No subnet declaration”.

### Maksud soal

Menjalankan DHCP server di Data Center. Subnet lokal tetap wajib dideklarasikan meskipun tidak membagikan alamat dinamis.

### Cara mengerjakan

Konfigurasi berikut berasal dari [soal_2.sh](perquest-script/soal_2.sh). Jalankan setiap bagian pada node yang disebut dalam komentar; berkas ini berisi instruksi beberapa node, bukan satu script untuk dieksekusi seluruhnya pada satu node.

```sh
# jalanin di tengen
#!/bin/sh

# Nomor 1 dan 2 - tengen sebagai DHCP server
# Kelompok K52, prefix 192.237.x.x

# IP statis tengen di Net4
ip addr replace 192.237.4.10/24 dev eth0
ip route replace default via 192.237.4.1 dev eth0

# DNS sementara untuk install/update package
echo "nameserver 192.168.122.1" > /etc/resolv.conf

# Install DHCP server jika belum ada
if ! command -v dhcpd >/dev/null 2>&1; then
  apt update
  apt install -y isc-dhcp-server
fi

# Konfigurasi DHCP server
cat > /etc/dhcp/dhcpd.conf <<'EOF'
default-lease-time 600;
max-lease-time 7200;

authoritative;

subnet 192.237.4.0 netmask 255.255.255.0 {
}

subnet 192.237.2.0 netmask 255.255.255.0 {
  range 192.237.2.10 192.237.2.95;
  option routers 192.237.2.1;
  option broadcast-address 192.237.2.255;
  option domain-name-servers 192.237.1.2, 192.237.1.3;
  option domain-name "k52.com";
}

subnet 192.237.3.0 netmask 255.255.255.0 {
  range 192.237.3.10 192.237.3.199;
  option routers 192.237.3.1;
  option broadcast-address 192.237.3.255;
  option domain-name-servers 192.237.1.2, 192.237.1.3;
  option domain-name "k52.com";
}
EOF

# Jalankan DHCP server di interface Net4
sed -i 's/^INTERFACESv4=.*/INTERFACESv4="eth0"/' /etc/default/isc-dhcp-server

dhcpd -t -cf /etc/dhcp/dhcpd.conf
service isc-dhcp-server restart
```

### Cara melakukan validasi

```sh
dhcpd -t -cf /etc/dhcp/dhcpd.conf
service isc-dhcp-server status
ip -br addr show eth0
```

### Bukti pengujian

Tidak tersedia gambar khusus nomor 2. Status server pada pengujian restart berikut dipakai sebagai bukti pendukung.

**10. Bukti autorestart tengen berhasil**

![10. Bukti autorestart tengen berhasil](<Assets/10. Bukti autorestart tengen berhasil.png>)

### Hasil dan analisis

Tidak ada gambar bernomor 2 dalam arsip. Bukti status tengen pada soal 10 dan lease klien pada soal 4–6 dipakai sebagai bukti pendukung; bukan tangkapan validasi awal `dhcpd -t`.

---

<a id="soal-3"></a>

## Soal 3 — DHCP Relay Jichi

### Soal

> Permintaan alamat dari Divisi A dan Divisi B tidak dapat menyeberangi subnet secara langsung. Konfigurasikan jichi sebagai DHCP Relay menuju tengen ([PREFIX IP].4.10), menggunakan eth2 untuk Network 2 dan eth3 untuk Network 3. Buktikan bahwa client dari kedua subnet berhasil memperoleh lease melalui relay.

### Maksud soal

Meneruskan broadcast DHCP dari Network 2–3 ke tengen. Relay mengisi giaddr agar server memilih subnet yang tepat.

### Cara mengerjakan

Konfigurasi berikut berasal dari [soal_3.sh](perquest-script/soal_3.sh). Jalankan setiap bagian pada node yang disebut dalam komentar; berkas ini berisi instruksi beberapa node, bukan satu script untuk dieksekusi seluruhnya pada satu node.

```sh
# jalankan di jichi:

# Install DHCP relay jika belum ada
if ! command -v dhcrelay >/dev/null 2>&1; then
  apt update
  apt install -y isc-dhcp-relay
fi

# Konfigurasi DHCP relay:
# eth2 = Net2 client DHCP
# eth3 = Net3 client DHCP
# eth4 = jalur ke DHCP server tengen
cat > /etc/default/isc-dhcp-relay <<'EOF'
SERVERS="192.237.4.10"
INTERFACES="eth2 eth3 eth4"
OPTIONS=""
EOF

#untuk resart
service isc-dhcp-relay restart
```

### Cara melakukan validasi

```sh
ps aux | grep "[d]hcrelay"
# Pada client di Network 2 dan 3
udhcpc -i eth0 -n -q
ip -br addr
ip route
```

### Bukti pengujian

**3. Bukti DHCP relay di jichi**

![3. Bukti DHCP relay di jichi](<Assets/3. Bukti DHCP relay di jichi.png>)

### Hasil dan analisis

Gambar proses memperlihatkan `dhcrelay -q -i eth2 -i eth3 -i eth4 192.237.4.10`. Bukti lease Network 2 dan 3 tersedia pada soal 4–6.

---

<a id="soal-4"></a>

## Soal 4 — Dua Pool DHCP Network 2

### Soal

> Agar tim Dev dan Support di Divisi A menerima jatah alamat yang berbeda, atur dua pool DHCP pada Network 2. Tetapkan Pool 1 ([PREFIX IP].2.10–[PREFIX IP].2.35) untuk itadori dan fushiguro, serta Pool 2 ([PREFIX IP].2.70–[PREFIX IP].2.95) untuk zenin dan okkotsu. Rentang [PREFIX IP].2.36–[PREFIX IP].2.69 tidak boleh dialokasikan. Karena seluruh client berada pada subnet yang sama, gunakan DHCP class berdasarkan MAC Address atau Client ID untuk memisahkan kedua kelompok.

### Maksud soal

Memilih pool berdasarkan identitas MAC, bukan sekadar mendefinisikan dua range pada subnet yang sama.

### Cara mengerjakan

Konfigurasi berikut berasal dari [soal_4.sh](perquest-script/soal_4.sh). Jalankan setiap bagian pada node yang disebut dalam komentar; berkas ini berisi instruksi beberapa node, bukan satu script untuk dieksekusi seluruhnya pada satu node.

```sh
# jalankan di tengen:

cat > /etc/dhcp/dhcpd.conf <<'EOF'
default-lease-time 600;
max-lease-time 7200;

authoritative;

class "net2-pool-a" {
  match if binary-to-ascii(16, 8, ":", substring(hardware, 1, 6)) = "2:42:37:27:6:0" or
           binary-to-ascii(16, 8, ":", substring(hardware, 1, 6)) = "2:42:0:c1:ee:0";
}

class "net2-pool-b" {
  match if binary-to-ascii(16, 8, ":", substring(hardware, 1, 6)) = "2:42:d:fc:26:0" or
           binary-to-ascii(16, 8, ":", substring(hardware, 1, 6)) = "2:42:69:17:c1:0";
}

subnet 192.237.4.0 netmask 255.255.255.0 {
}

subnet 192.237.2.0 netmask 255.255.255.0 {
  option routers 192.237.2.1;
  option broadcast-address 192.237.2.255;
  option domain-name-servers 192.237.1.2, 192.237.1.3;
  option domain-name "k52.com";

  pool {
    allow members of "net2-pool-a";
    range 192.237.2.10 192.237.2.35;
  }

  pool {
    allow members of "net2-pool-b";
    range 192.237.2.70 192.237.2.95;
  }
}

subnet 192.237.3.0 netmask 255.255.255.0 {
  range 192.237.3.10 192.237.3.199;
  option routers 192.237.3.1;
  option broadcast-address 192.237.3.255;
  option domain-name-servers 192.237.1.2, 192.237.1.3;
  option domain-name "k52.com";
}
EOF

#Restart DHCP
service isc-dhcp-server restart

#jalankan ini di Net2 (itadori, fushiguro, zenin, okkotsu):
udhcpc -i eth0
```

### Cara melakukan validasi

```sh
ip link show eth0
udhcpc -i eth0 -n -q
ip -br addr
ip route
```

### Bukti pengujian

**4. Bukti IP Pool di Itadori**

![4. Bukti IP Pool di Itadori](<Assets/4. Bukti IP Pool di Itadori.png>)

**4. Gateway dari Itadori**

![4. Gateway dari Itadori](<Assets/4. Gateway dari Itadori.png>)

**4. Pool IP di Fushiguro**

![4. Pool IP di Fushiguro](<Assets/4. Pool IP di Fushiguro.png>)

**4. Pool IP di Zenin**

![4. Pool IP di Zenin](<Assets/4. Pool IP di Zenin.png>)

### Hasil dan analisis

Itadori mendapatkan `192.237.2.10`, Fushiguro `.2.11`, dan Zenin `.2.70` dengan gateway `.2.1`. Tidak tersedia foto khusus Okkotsu. MAC dalam skrip adalah identitas konfigurasi yang disimpan; setelah membuat ulang container, cocokkan kembali dengan `ip link show eth0`.

---

<a id="soal-5"></a>

## Soal 5 — Short Lease dan Long Lease

### Soal

> Setiap tim lapangan memiliki durasi operasi yang berbeda. Pada Network 3, berikan short lease 30 menit (1800 detik) kepada ino dan kusakabe, serta long lease 12 jam (43200 detik) kepada miwa. Gunakan pool short lease [PREFIX IP].3.10–[PREFIX IP].3.89 dan pool long lease [PREFIX IP].3.100–[PREFIX IP].3.199. Sesuaikan default-lease-time dan max-lease-time untuk setiap kelas client. Berikan pula DHCP options berupa DNS [PREFIX IP].1.2 dan [PREFIX IP].1.3, serta domain-search <xxxx>.com.

### Maksud soal

Membedakan masa sewa berdasarkan kelas klien: 1800 detik untuk ino/kusakabe dan 43200 detik untuk miwa.

### Cara mengerjakan

Konfigurasi berikut berasal dari [soal_5.sh](perquest-script/soal_5.sh). Jalankan setiap bagian pada node yang disebut dalam komentar; berkas ini berisi instruksi beberapa node, bukan satu script untuk dieksekusi seluruhnya pada satu node.

```sh
#di tengan lakukan ini:
cat > /etc/dhcp/dhcpd.conf <<'EOF'
default-lease-time 600;
max-lease-time 7200;

authoritative;

class "net2-pool-a" {
  match if binary-to-ascii(16, 8, ":", substring(hardware, 1, 6)) = "2:42:37:27:6:0" or
           binary-to-ascii(16, 8, ":", substring(hardware, 1, 6)) = "2:42:0:c1:ee:0";
}

class "net2-pool-b" {
  match if binary-to-ascii(16, 8, ":", substring(hardware, 1, 6)) = "2:42:d:fc:26:0" or
           binary-to-ascii(16, 8, ":", substring(hardware, 1, 6)) = "2:42:69:17:c1:0";
}

class "net3-short-lease" {
  match if binary-to-ascii(16, 8, ":", substring(hardware, 1, 6)) = "2:42:bf:d2:9f:0" or
           binary-to-ascii(16, 8, ":", substring(hardware, 1, 6)) = "2:42:c4:4a:1a:0";
}

class "net3-long-lease" {
  match if binary-to-ascii(16, 8, ":", substring(hardware, 1, 6)) = "2:42:17:24:b6:0";
}

subnet 192.237.4.0 netmask 255.255.255.0 {
}

subnet 192.237.2.0 netmask 255.255.255.0 {
  option routers 192.237.2.1;
  option broadcast-address 192.237.2.255;
  option domain-name-servers 192.237.1.2, 192.237.1.3;
  option domain-name "k52.com";

  pool {
    allow members of "net2-pool-a";
    range 192.237.2.10 192.237.2.35;
  }

  pool {
    allow members of "net2-pool-b";
    range 192.237.2.70 192.237.2.95;
  }
}

subnet 192.237.3.0 netmask 255.255.255.0 {
  option routers 192.237.3.1;
  option broadcast-address 192.237.3.255;
  option domain-name-servers 192.237.1.2, 192.237.1.3;
  option domain-name "k52.com";

  pool {
    allow members of "net3-short-lease";
    range 192.237.3.10 192.237.3.89;
    default-lease-time 1800;
    max-lease-time 1800;
  }

  pool {
    allow members of "net3-long-lease";
    range 192.237.3.100 192.237.3.199;
    default-lease-time 43200;
    max-lease-time 43200;
  }
}
EOF

#lakukan ini setelah update
#test error
dhcpd -t -cf /etc/dhcp/dhcpd.conf
#restart
service isc-dhcp-server restart

#cek di Net3 (ino, kusakabe, miwa):
udhcpc -i eth0
```

Tambahkan baris berikut pada kedua scope klien (Network 2 dan 3), tanpa menghapus class/pool yang sudah dibuat:

```conf
option domain-search "k52.com";
```

`domain-name` (option 15) dan `domain-search` (option 119) merupakan opsi berbeda.

### Cara melakukan validasi

```sh
udhcpc -i eth0 -n -q
cat /etc/resolv.conf
# Pada tengen
dhcpd -t -cf /etc/dhcp/dhcpd.conf
```

### Bukti pengujian

**5. Pool IP di ino**

![5. Pool IP di ino](<Assets/5. Pool IP di ino.png>)

**5. Pool IP di miwa**

![5. Pool IP di miwa](<Assets/5. Pool IP di miwa.png>)

### Hasil dan analisis

Ino menerima `192.237.3.10` dengan lease **1800 detik**. Miwa menerima `192.237.3.100` dengan lease **43200 detik**. Script asli hanya memakai `option domain-name`, sehingga `option domain-search "k52.com";` perlu ditambahkan untuk memenuhi opsi search secara eksplisit. Bukti DNS/search dari seluruh klien belum tersedia.

---

<a id="soal-6"></a>

## Soal 6 — Static Lease Kugisaki

### Soal

> Kugisaki ditetapkan sebagai personel VIP yang harus mempertahankan alamat yang sama setiap kali terhubung. Buat DHCP static lease berdasarkan MAC Address client tersebut dengan fixed address [PREFIX IP].3.99. Pastikan alamat ini berada di luar seluruh pool dinamis, validasi konfigurasi server, lalu renew lease pada client. Buktikan bahwa alamat yang diterima sesuai dengan reservasi.

### Maksud soal

Menjadikan 192.237.3.99 reservasi MAC Kugisaki, di luar semua pool dinamis.

### Cara mengerjakan

Konfigurasi berikut berasal dari [soal_6.sh](perquest-script/soal_6.sh). Jalankan setiap bagian pada node yang disebut dalam komentar; berkas ini berisi instruksi beberapa node, bukan satu script untuk dieksekusi seluruhnya pada satu node.

```sh
#di tengen:

cat >> /etc/dhcp/dhcpd.conf <<'EOF'

host kugisaki {
  hardware ethernet 02:42:c6:ce:c0:00;
  fixed-address 192.237.3.99;
}
EOF

#cek error
dhcpd -t -cf /etc/dhcp/dhcpd.conf

#restart
service isc-dhcp-server restart

#cek di kugisaki:
udhcpc -i eth0
```

### Cara melakukan validasi

```sh
udhcpc -i eth0 -n -q
ip -br addr show eth0
ip route
```

### Bukti pengujian

**6. Pool IP di kugisaki**

![6. Pool IP di kugisaki](<Assets/6. Pool IP di kugisaki.png>)

### Hasil dan analisis

Kugisaki memperoleh `192.237.3.99` dari `192.237.4.10`, lease 600 detik. Durasi ini mengikuti pengaturan global; soal ini mensyaratkan alamat tetap, bukan lease khusus. Reservasi `.99` berada di antara pool `.10–.89` dan `.100–.199`.

---

<a id="soal-7"></a>

## Soal 7 — Validasi Konfigurasi Klien

### Soal

> Setelah aturan alokasi diterapkan, pastikan setiap client menerima konfigurasi jaringan sesuai wilayahnya: subnet mask 255.255.255.0 (/24), gateway dan broadcast address yang benar, DNS [PREFIX IP].1.2 serta [PREFIX IP].1.3, dan domain-search yang ditentukan. Periksa IP address dan routing seluruh client Divisi A dan Divisi B, kemudian cocokkan lease dengan /var/lib/dhcp/dhcpd.leases pada tengen. Pastikan tidak ada alamat yang bertabrakan atau berada di luar kebijakan pool.

### Maksud soal

Memastikan alamat, route, DNS, broadcast, search domain, serta catatan lease konsisten dengan kebijakan DHCP.

### Cara mengerjakan

Konfigurasi berikut berasal dari [soal_7.sh](perquest-script/soal_7.sh). Jalankan setiap bagian pada node yang disebut dalam komentar; berkas ini berisi instruksi beberapa node, bukan satu script untuk dieksekusi seluruhnya pada satu node.

```sh
#jalankan ini untuk ngecek apakah daftar lease DHCP dari server sudah sesuai
#di tengen:
cat /var/lib/dhcp/dhcpd.leases

#jika di tengen tidak muncul punya kugisaki
#bisa melakukan ping melalui itadori ke kugisaki
ping -c 3 192.237.3.100
```

Untuk ping khusus Kugisaki, gunakan alamat reservasi yang benar:

```sh
ping -c 3 192.237.3.99
```

Jangan menafsirkan `.3.100` sebagai alamat Kugisaki.

### Cara melakukan validasi

```sh
ip -4 addr show eth0
ip route
cat /etc/resolv.conf
# Pada tengen
cat /var/lib/dhcp/dhcpd.leases
grep -A 4 "host kugisaki" /etc/dhcp/dhcpd.conf
```

### Bukti pengujian

**7. IP & Gateway kugisaki**

![7. IP & Gateway kugisaki](<Assets/7. IP & Gateway kugisaki.png>)

**7. ping dari itadori ke kugisaki**

![7. ping dari itadori ke kugisaki](<Assets/7. ping dari itadori ke kugisaki.png>)

### Hasil dan analisis

Route Kugisaki menunjukkan sumber `192.237.3.99` dan gateway `192.237.3.1`. Gambar bernama “ping dari itadori ke kugisaki” sebenarnya melakukan ping ke **192.237.3.100** (alamat Miwa pada soal 5), sehingga hanya membuktikan konektivitas antarsubnet ke `.100`, bukan ping Kugisaki. Fixed-address ISC DHCP tidak harus muncul sebagai lease dinamis pada `dhcpd.leases`. Bukti DNS/search, broadcast, serta seluruh klien masih perlu ditambahkan.

---

<a id="soal-8"></a>

## Soal 8 — Packet Capture DHCP DORA

### Soal

> Sebelum Curtain dibuka kembali, buktikan bahwa proses pemberian alamat berjalan sesuai protokol. Lakukan packet capture saat salah satu client Network 2 atau Network 3 meminta lease baru. Gunakan tcpdump pada tengen atau jalur menuju Data Center untuk menunjukkan urutan DHCPDISCOVER → DHCPOFFER → DHCPREQUEST → DHCPACK. Identifikasi alamat server, alamat yang diberikan, lease time, dan field giaddr. Pastikan nilai giaddr sesuai dengan interface jichi yang menerima request dari subnet client.

### Maksud soal

Mengamati Discover, Offer, Request, dan ACK serta peran giaddr pada komunikasi melalui relay.

### Cara mengerjakan

Konfigurasi berikut berasal dari [soal_8.sh](perquest-script/soal_8.sh). Jalankan setiap bagian pada node yang disebut dalam komentar; berkas ini berisi instruksi beberapa node, bukan satu script untuk dieksekusi seluruhnya pada satu node.

```sh
#lakukan tcpdump di tengen
tcpdump -i eth0 -n -vvv port 67 or port 68

#langsung buka node itadori
#request ulang DHCP lease dari server:
udhcpc -i eth0 -n
```

### Cara melakukan validasi

```sh
tcpdump -i eth0 -n -vvv "udp port 67 or udp port 68"
# Pada klien uji, dari console lokal, setelah menghentikan udhcpc lama
ip -4 addr flush dev eth0
udhcpc -i eth0 -n -q
```

### Bukti pengujian

**8. bukti tcpdump di tengen dari itadori**

![8. bukti tcpdump di tengen dari itadori](<Assets/8. bukti tcpdump di tengen dari itadori.png>)

### Hasil dan analisis

Bagian capture yang terlihat menunjukkan **DHCP Discover**, `Gateway-IP 192.237.2.1` (giaddr), dan MAC klien `02:42:37:27:06:00`. Gambar terpotong sebelum keseluruhan Offer–Request–ACK, sehingga belum cukup untuk menyatakan empat fase beserta lease time sudah seluruhnya terdokumentasi.

Pada capture lengkap, periksa server identifier `192.237.4.10`, alamat yang ditawarkan pada `yiaddr`, lease time option 51, serta giaddr `.2.1` untuk Network 2 atau `.3.1` untuk Network 3. Keempat pesan harus dicocokkan berdasarkan transaction ID yang sama.

---

<a id="soal-9"></a>

## Soal 9 — Gangguan dan Pemulihan Relay

### Soal

> Sebuah gangguan memutus jalur relay dan membuat permintaan alamat tidak sampai ke Data Center. Hentikan service DHCP Relay pada jichi, lalu paksa salah satu client di Network 2 atau Network 3 meminta lease baru dan catat gejalanya. Pulihkan service relay, ulangi permintaan DHCP, lalu buktikan bahwa client kembali memperoleh alamat dari pool yang benar dengan gateway semula.

### Maksud soal

Membandingkan permintaan lease baru ketika relay berhenti dan setelah relay dipulihkan.

### Cara mengerjakan

Konfigurasi berikut berasal dari [soal_9.sh](perquest-script/soal_9.sh). Jalankan setiap bagian pada node yang disebut dalam komentar; berkas ini berisi instruksi beberapa node, bukan satu script untuk dieksekusi seluruhnya pada satu node.

```sh
#matikan DHCP relay di jichi
#ketik ini di jichi:
service isc-dhcp-relay stop

#cek apakah benar benar mati
ps aux | grep dhcrelay

#sekarang cek di ino:
ip addr flush dev eth0

#jalankan ini di ino:
udhcpc -i eth0 -n -q
#ino pasti gagal untuk mendapatkan new ip dari jichi karena DHCP relay mati
#contoh otput:
# udhcpc: broadcasting discover
# udhcpc failed to get a DHCP lease
# udhcpc: no lease, failing

#jalanin di jichi 
#buat restart DHCP relay:
service isc-dhcp-relay start

#cek lagi di ino apakah sudah nyala 
#cek di ino:
udhcpc -i eth0 -n -q
```

### Cara melakukan validasi

```sh
service isc-dhcp-relay stop
ps aux | grep "[d]hcrelay"
# Pada ino melalui console GNS3
ip -4 addr flush dev eth0
udhcpc -i eth0 -n -q
# Pada jichi
service isc-dhcp-relay start
# Ulangi udhcpc di ino dan cek ip route
```

### Bukti pengujian

**9. Bukti DHCP relay bisa saat jichi up**

![9. Bukti DHCP relay bisa saat jichi up](<Assets/9. Bukti DHCP relay bisa saat jichi up.png>)

**9. Bukti tidak bisa DHCP relay saat jichi down**

![9. Bukti tidak bisa DHCP relay saat jichi down](<Assets/9. Bukti tidak bisa DHCP relay saat jichi down.png>)

### Hasil dan analisis

Saat relay berhenti, Ino mengulang Discover dan berakhir `no lease, failing`. Setelah relay hidup, Ino mendapatkan `192.237.3.10` dari tengen. Gambar pemulihan memperlihatkan sisa lease **1459 detik**, bukan penetapan ulang kebijakan short lease menjadi 1459 detik.

---

<a id="soal-10"></a>

## Soal 10 — Autostart setelah Restart

### Soal

> Setelah gangguan Shibuya tertangani, pastikan pemulihan bertahan setelah restart. Aktifkan autostart DHCP Server pada tengen dan DHCP Relay pada jichi, lalu restart kedua node. Verifikasi status layanan, IP, gateway, lease, dan konektivitas client Network 2–3. Pastikan kebijakan Pool 1, Pool 2, short lease, long lease, dan fixed address tetap berlaku.

### Maksud soal

Memastikan IP, forwarding, NAT, DHCP server, serta relay pulih tanpa konfigurasi manual setelah node dijalankan ulang.

### Cara mengerjakan

Pelengkap berikut adalah pola pemulihan yang dapat diterapkan; hook startup sebenarnya harus disesuaikan dengan init image, tidak cukup hanya `chmod +x`.

1. Simpan konfigurasi interface statis pada `/etc/network/interfaces` di setiap server dan gateway (WAN jichi tetap DHCP).
2. Simpan konfigurasi final DHCP nomor 4–6 dalam `/etc/dhcp/dhcpd.conf`, bukan kembali ke pool awal nomor 2.
3. Buat `/root/init.sh` sesuai peran. Pada **jichi**:

```sh
#!/bin/sh
exec >> /root/init.log 2>&1
sysctl -w net.ipv4.ip_forward=1
iptables -t nat -C POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null ||
  iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
service isc-dhcp-relay start
```

Pada **tengen**:

```sh
#!/bin/sh
exec >> /root/init.log 2>&1
dhcpd -t -cf /etc/dhcp/dhcpd.conf || exit 1
service isc-dhcp-server start
```

4. Periksa PID 1 dengan `ps -p 1 -o comm,args`. Jika image menggunakan SysV dan menjalankan init/runlevel, aktifkan melalui `update-rc.d isc-dhcp-server defaults` pada tengen dan `update-rc.d isc-dhcp-relay defaults` pada jichi. Jika entrypoint image memanggil `/root/init.sh`, gunakan hook tersebut. Jika tidak, pastikan script dipanggil oleh mekanisme startup GNS3/image yang benar.
5. Stop–Start kedua node dari GNS3, lalu lakukan pemeriksaan berikut tanpa menjalankan init secara manual. `.bashrc` bukan bukti autostart karena baru dieksekusi saat membuka shell.

Skrip yang tersimpan di repository: [soal_10.sh](perquest-script/soal_10.sh). Bagian penyesuaian di atas perlu dibedakan dari script sumber.

### Cara melakukan validasi

```sh
# jichi
ip -br addr
ip route
sysctl net.ipv4.ip_forward
ps aux | grep "[d]hcrelay"
# tengen
service isc-dhcp-server status
dhcpd -t -cf /etc/dhcp/dhcpd.conf
# Seluruh client Network 2–3
udhcpc -i eth0 -n -q
ip -br addr
ip route
cat /etc/resolv.conf
```

### Bukti pengujian

**10. Bukti autorestart jichi berhasil**

![10. Bukti autorestart jichi berhasil](<Assets/10. Bukti autorestart jichi berhasil.png>)

**10. Bukti autorestart shoko berhasil**

![10. Bukti autorestart shoko berhasil](<Assets/10. Bukti autorestart shoko berhasil.png>)

**10. Bukti autorestart tengen berhasil**

![10. Bukti autorestart tengen berhasil](<Assets/10. Bukti autorestart tengen berhasil.png>)

**10. Bukti autorestart utahime berhasil**

![10. Bukti autorestart utahime berhasil](<Assets/10. Bukti autorestart utahime berhasil.png>)

### Hasil dan analisis

Gambar memperlihatkan IP empat node kembali tersedia, forwarding bernilai 1, relay aktif, dan `dhcpd is running`. Skrip nomor 10 di arsip hanya berisi potongan init dan pemeriksaan; hook pemanggil init tidak disertakan. Bukti renew semua kelas klien setelah restart belum tersedia, sehingga pemulihan seluruh kebijakan belum dapat dinyatakan lengkap.

---

<a id="soal-11"></a>

## Soal 11 — DNS Master–Slave

### Soal

> Utahime dan Shoko ditugaskan membangun sistem penamaan domain resmi agar seluruh pos tidak perlu menghafal alamat IP mentah. Konfigurasikan BIND9 pada utahime sebagai DNS Master dan shoko sebagai DNS Slave untuk mengelola domain jujutsu.<xxxx>.com. Atur SOA record, NS delegasi untuk kedua server, dan terapkan allow-transfer dari Master ke Slave. Pastikan file zona berhasil tersinkronisasi otomatis ke shoko saat nomor serial di utahime dinaikkan, lalu buktikan dengan melakukan query dig ke kedua server dari salah satu client.

### Maksud soal

Membuat utahime sebagai sumber zona dan shoko sebagai salinan otomatis. Kenaikan serial digunakan untuk menguji pembaruan zona.

### Cara mengerjakan

Konfigurasi berikut berasal dari [soal_11.sh](perquest-script/soal_11.sh). Jalankan setiap bagian pada node yang disebut dalam komentar; berkas ini berisi instruksi beberapa node, bukan satu script untuk dieksekusi seluruhnya pada satu node.

```sh
# Jalanin di utahime (DNS MASTER):
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


# Jalanin di shoko (DNS SLAVE):
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


# TEST SINKRONISASI: naikkan serial di utahime
sed -i 's/2026101301/2026101302/' /etc/bind/jarkom/db.jujutsu.k52.com
rndc reload

# lalu cek di shoko (serial harus ikut naik jadi 2026101302):
dig @192.237.1.3 jujutsu.k52.com SOA +short


# TEST dari salah satu client (itadori / ino / dll):
dig @192.237.1.2 jujutsu.k52.com NS
dig @192.237.1.3 jujutsu.k52.com NS
dig @192.237.1.2 jujutsu.k52.com SOA +short
dig @192.237.1.3 jujutsu.k52.com SOA +short
```

### Cara melakukan validasi

```sh
dig @192.237.1.2 jujutsu.k52.com NS
dig @192.237.1.3 jujutsu.k52.com NS
dig @192.237.1.2 jujutsu.k52.com SOA +short
dig @192.237.1.3 jujutsu.k52.com SOA +short
```

### Bukti pengujian

**11. Dig Ino SOA**

![11. Dig Ino SOA](<Assets/11. Dig Ino SOA.png>)

**11. Dig ino 1.2**

![11. Dig ino 1.2](<Assets/11. Dig ino 1.2.png>)

**11. Dig ino 1.3**

![11. Dig ino 1.3](<Assets/11. Dig ino 1.3.png>)

**11.Serial shoko**

![11.Serial shoko](<Assets/11.Serial shoko.png>)

### Hasil dan analisis

Query NS ke kedua server menghasilkan NOERROR dan NS ns1/ns2. Shoko menunjukkan serial berubah dari **2026101301** ke **2026101302**; query SOA dari Ino menunjukkan serial kedua server sama, yaitu **2026101302**.

---

<a id="soal-12"></a>

## Soal 12 — A, CNAME, PTR, dan DNS Forwarder

### Soal

> Peta domain harus memetakan pintu masuk utama dan tetap bisa mencari alamat di luar kawasan Shibuya. Pada utahime, buat A record jujutsu.<xxxx>.com yang mengarah ke gojo, serta CNAME www yang merujuk ke domain utama tersebut. Buat pula Reverse DNS (zona PTR) untuk melacak IP gojo kembali ke domain resminya, dan aktifkan fitur DNS Forwarder pada BIND9 mengarah ke IP gateway internet (192.168.122.1). Uji dari client dengan dig untuk mengecek CNAME, PTR, dan buktikan client tetap bisa melakukan ping ke domain internet seperti google.com.

### Maksud soal

Mengarahkan domain layanan ke gojo, menyediakan alias www dan PTR, serta tetap melayani resolusi domain internet.

### Cara mengerjakan

Konfigurasi berikut berasal dari [soal_12.sh](perquest-script/soal_12.sh). Jalankan setiap bagian pada node yang disebut dalam komentar; berkas ini berisi instruksi beberapa node, bukan satu script untuk dieksekusi seluruhnya pada satu node.

```sh
# ASUMSI IP (sesuaikan dengan tabel spesifikasi, find&replace kalau beda):
# gojo 192.237.1.10  (DMZ / Net1)
# Net4: tengen .10, yaga .11, inumaki .12, maki .13, panda .14,
#       nanami .15, todo .16, kirara .17, geto .18
# Zona reverse = 1.237.192.in-addr.arpa (karena gojo di 192.237.1.x)

# Jalanin di utahime (MASTER):
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


# Jalanin di shoko (SLAVE):
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


# TEST dari client (Net2 / Net3):
dig jujutsu.k52.com A +short
dig www.jujutsu.k52.com CNAME
dig -x 192.237.1.10
dig @192.237.1.2 www.jujutsu.k52.com CNAME +short
dig @192.237.1.3 -x 192.237.1.10 +short

#cek forwarder & internet
dig google.com +short
ping -c 3 google.com
```

### Cara melakukan validasi

```sh
dig jujutsu.k52.com A +short
dig www.jujutsu.k52.com CNAME
dig -x 192.237.1.10
dig @192.237.1.3 -x 192.237.1.10 +short
dig google.com +short
ping -c 3 google.com
```

### Bukti pengujian

**12. Cek forawarder internet**

![12. Cek forawarder internet](<Assets/12. Cek forawarder internet.png>)

**12. Dig client domain**

![12. Dig client domain](<Assets/12. Dig client domain.png>)

**12. Dig client ke gojo**

![12. Dig client ke gojo](<Assets/12. Dig client ke gojo.png>)

**12. Dig domain short**

![12. Dig domain short](<Assets/12. Dig domain short.png>)

### Hasil dan analisis

A record menghasilkan `192.237.1.10`, CNAME www menunjuk ke `jujutsu.k52.com.`, PTR `.1.10` kembali ke domain tersebut, dan query ke shoko juga berhasil. Ping google.com memperlihatkan 3 paket terkirim, 3 diterima, 0% packet loss.

---

<a id="soal-13"></a>

## Soal 13 — Replikasi MariaDB

### Soal

> Kepala Sekolah Yaga dan Inumaki mendirikan database terpusat yang redundan agar log aktivitas kutukan tetap aman tersimpan. Konfigurasikan MariaDB pada yaga sebagai DB-Master dan inumaki sebagai DB-Slave. Buat database db_shibuya_<xxxx> beserta tabel request_logs di Master, aktifkan binary logging (log-bin, server-id), lalu hubungkan inumaki sebagai Slave yang menyalin data secara realtime dengan CHANGE MASTER TO. Berikan hak akses remote bagi seluruh node di Network 4, lalu buktikan replikasi berhasil dengan memasukkan data baru di Master dan memeriksa hasilnya di Slave.

### Maksud soal

Menyimpan log terpusat di yaga dan menyalinnya ke inumaki melalui replikasi MariaDB.

### Cara mengerjakan

**Rekonstruksi konfigurasi — cocokkan dengan konfigurasi node sebelum digunakan sebagai catatan runtime.**

**Yaga dan Inumaki:**

```sh
apt update
apt install -y mariadb-server
mkdir -p /var/log/mysql
chown mysql:mysql /var/log/mysql
```

Pada **yaga**, buat `/etc/mysql/mariadb.conf.d/60-jarkom.cnf`:

```ini
[mysqld]
bind-address=0.0.0.0
server-id=1
log-bin=/var/log/mysql/mysql-bin
binlog-format=ROW
```

Pada **inumaki**, gunakan berkas yang sama dengan isi:

```ini
[mysqld]
server-id=2
relay-log=/var/log/mysql/relay-bin
read-only=1
```

Restart MariaDB keduanya. Untuk setup baru dengan slave kosong, mulai replikasi sebelum membuat database agar DDL ikut tersalin. Pada yaga:

```sql
CREATE USER 'repl'@'192.237.4.12' IDENTIFIED BY 'repl_k52';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'192.237.4.12';
SHOW MASTER STATUS;
```

Pada inumaki, gunakan **File dan Position aktual** dari output terakhir yaga, bukan menyalin angka 1679 dari foto:

```sql
CHANGE MASTER TO
  MASTER_HOST='192.237.4.11',
  MASTER_USER='repl',
  MASTER_PASSWORD='repl_k52',
  MASTER_LOG_FILE='<File aktual yaga>',
  MASTER_LOG_POS=<Position aktual yaga>;
START SLAVE;
SHOW SLAVE STATUS\G
```

Untuk database yang sudah berisi data, ambil snapshot konsisten beserta koordinat binlog dan impor ke slave terlebih dahulu; sekadar memakai posisi terbaru tidak menyalin data lama.

Pada **yaga**, setelah replikasi aktif:

```sql
CREATE DATABASE IF NOT EXISTS db_shibuya_k52;
USE db_shibuya_k52;
CREATE TABLE IF NOT EXISTS request_logs (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  client_ip VARCHAR(45) NOT NULL,
  hostname VARCHAR(100) NOT NULL,
  path VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE USER IF NOT EXISTS 'shibuya'@'192.237.4.%'
  IDENTIFIED BY 'shibuya_k52';
GRANT SELECT, INSERT ON db_shibuya_k52.* TO 'shibuya'@'192.237.4.%';
INSERT INTO request_logs(client_ip,hostname,path)
VALUES ('10.10.10.10','tes-master','/tes');
```

Nama database dan akun aplikasi mengikuti kredensial yang muncul dalam skrip soal 17. Akun `repl` di atas merupakan contoh pelengkap, tidak tercantum dalam arsip.

### Cara melakukan validasi

```sh
# inumaki: periksa Slave_IO_Running dan Slave_SQL_Running = Yes
mysql -e "SHOW SLAVE STATUS\G"
mysql -e "SELECT * FROM db_shibuya_k52.request_logs;"
# tengen: uji akun remote sesuai screenshot
mysql -h 192.237.4.11 -ushibuya -pshibuya_k52 -e "SELECT * FROM db_shibuya_k52.request_logs;"
```

### Bukti pengujian

**13. Akses Remote Tengen**

![13. Akses Remote Tengen](<Assets/13. Akses Remote Tengen.png>)

**13. LOGS**

![13. LOGS](<Assets/13. LOGS.png>)

**13. Logs Inumaki**

![13. Logs Inumaki](<Assets/13. Logs Inumaki.png>)

### Hasil dan analisis

Akses remote dari tengen berhasil membaca dua baris uji (`10.10.10.10`, `tes-master`, `/tes`) di yaga. Gambar yaga dan inumaki menampilkan **SHOW MASTER STATUS / SHOW BINARY LOGS**, masing-masing file `mysql-bin.000001` posisi 1679. Ini tidak membuktikan bahwa slave telah tersambung atau menyalin baris: masih diperlukan `SHOW SLAVE STATUS\G` dan SELECT data di inumaki. Skrip asli nomor 13 kosong; konfigurasi berikut adalah rekonstruksi, bukan salinan konfigurasi runtime.

---

<a id="soal-14"></a>

## Soal 14 — Frontend, API, dan Pembatasan Akses

### Soal

> Para penyihir lapangan bersiaga di Data Center sebagai pekerja backend untuk memproses aplikasi. Pasang Nginx dan PHP-FPM pada maki dan panda untuk menyajikan web frontend yang menampilkan hostname masing-masing. Pada nanami, todo, dan kirara, siapkan layanan API yang mencatat log request ke database yaga. Konfigurasikan virtual host agar worker merespons domain layanan yang ditentukan. Batasi akses langsung dari klien ke worker, web worker hanya menerima trafik melalui jalur proxy web yang ditentukan, sedangkan worker API hanya menerima trafik melalui geto. Uji bahwa akses langsung dari klien ditolak, sementara akses melalui reverse proxy tetap berhasil.

### Maksud soal

Menyediakan dua frontend dan tiga API worker, dengan akses HTTP worker dibatasi berdasarkan alamat proxy penghubung.

### Cara mengerjakan

**Rekonstruksi konfigurasi worker.** Pada maki, panda, nanami, todo, dan kirara:

```sh
apt update
apt install -y nginx php-fpm php-mysql
```

Sesuaikan socket PHP-FPM dengan versi yang benar-benar terpasang, cek `ls /run/php/`. Contoh berikut menggunakan PHP 8.4.

**Maki dan panda:** buat `/var/www/html/index.php`:

```php
<?php
header('Content-Type: text/plain');
echo "Web frontend dilayani oleh: " . gethostname() . "\n";
```

Isi `/etc/nginx/sites-available/default` di kedua frontend:

```nginx
server {
    listen 80 default_server;
    server_name jujutsu.k52.com www.jujutsu.k52.com;
    root /var/www/html;
    index index.php;
    allow 192.237.1.10; # gojo
    deny all;
    location / { try_files $uri $uri/ /index.php; }
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.4-fpm.sock;
    }
}
```

**Nanami, todo, kirara:** buat direktori `/var/www/api/api/` dan gunakan `index.php` API pada soal 17. Konfigurasi virtual host worker:

```nginx
server {
    listen 80 default_server;
    server_name jujutsu.k52.com www.jujutsu.k52.com;
    root /var/www/api;
    index index.php;
    allow 192.237.4.18; # geto
    deny all;
    location /api { try_files $uri $uri/ /api/index.php?$query_string; }
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.4-fpm.sock;
    }
}
```

Pada seluruh worker:

```sh
service php8.4-fpm start
nginx -t && service nginx restart
```

Pembatasan ini berdasarkan IP koneksi langsung. `server_name` sendiri tidak cukup untuk melarang akses langsung: kontrol `allow/deny` yang memastikan jalur proxy dipatuhi.

### Cara melakukan validasi

```sh
# itadori: semua akses langsung berikut diharapkan 403
for ip in 13 14; do curl -i http://192.237.4.$ip/; done
for ip in 15 16 17; do curl -i http://192.237.4.$ip/api; done
# Setelah gojo/geto dikonfigurasi
curl -i http://jujutsu.k52.com/
curl -i http://jujutsu.k52.com/api
```

### Bukti pengujian

**14 Test Nanami Todo**

![14 Test Nanami Todo](<Assets/14 Test Nanami Todo.png>)

**14. Test Kirara**

![14. Test Kirara](<Assets/14. Test Kirara.png>)

**14. Test panda maki**

![14. Test panda maki](<Assets/14. Test panda maki.png>)

### Hasil dan analisis

Akses langsung dari Itadori ke maki `.4.13`, panda `.4.14`, nanami `.4.15`, todo `.4.16`, dan kirara `.4.17` menghasilkan **403 Forbidden**. Akses lewat proxy terlihat pada soal 15–18. Skrip asli nomor 14 kosong; contoh konfigurasi di bawah melengkapi penjelasan implementasi.

---

<a id="soal-15"></a>

## Soal 15 — Weighted Round Robin 3:1

### Soal

> Geto bertugas mengendalikan pembagian beban request API di internal Data Center agar server tidak tumbang bersamaan. Konfigurasikan Nginx pada geto sebagai Load Balancer internal dengan upstream api_cluster yang mengarahkan trafik ke nanami dan todo. Terapkan algoritma Weighted Round Robin dengan bobot 3:1, di mana nanami menerima porsi beban tiga kali lebih banyak daripada todo. Buktikan distribusi beban ini dengan melakukan loop request berulang kali ke geto dari jaringan lokal Data Center dan periksa rasio responnya.

### Maksud soal

Membagikan trafik API ke nanami dan todo dengan bobot 3:1 pada geto.

### Cara mengerjakan

**Pada geto**, definisikan `/etc/nginx/conf.d/upstream_geto.conf` (di konteks `http`):

```nginx
upstream api_cluster {
    server 192.237.4.15 weight=3; # nanami
    server 192.237.4.16 weight=1; # todo
}
```

Virtual host `/etc/nginx/sites-available/geto`:

```nginx
server {
    listen 80 default_server;
    server_name jujutsu.k52.com;
    allow 192.237.1.10;
    allow 192.237.4.0/24;
    deny all;
    location / {
        proxy_pass http://api_cluster;
        proxy_set_header Host $host;
    }
}
```

Aktifkan setelah memasang nginx:

```sh
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/geto /etc/nginx/sites-enabled/geto
nginx -t && service nginx restart
```

Pada soal 17, blok virtual host geto ini diperbarui untuk meneruskan IP asli.

### Cara melakukan validasi

```sh
# Jalankan pada tengen
for i in $(seq 1 40); do
  curl -s --max-time 5 http://192.237.4.18/api | grep -o '"worker":"[a-z]*"'
done | sort | uniq -c
```

### Bukti pengujian

**15. Test Tengen**

![15. Test Tengen](<Assets/15. Test Tengen.png>)

### Hasil dan analisis

Dari tengen, 40 request ke `192.237.4.18/api` menghasilkan **30 nanami dan 10 todo**, tepat 3:1. Skrip nomor 15 kosong; blok berikut merekonstruksi konfigurasi sesuai pengujian tersebut.

---

<a id="soal-16"></a>

## Soal 16 — Path-Based Routing Gojo

### Soal

> Gojo berdiri di perbatasan DMZ sebagai gerbang publik tunggal bagi seluruh client dari luar maupun dalam. Konfigurasikan Nginx pada gojo untuk melayani domain jujutsu.<xxxx>.com dan www.jujutsu.<xxxx>.com menggunakan metode Path-Based Routing. Atur agar request root (/) diteruskan secara Round Robin ke worker frontend (maki dan panda), sedangkan request ke path /api diteruskan langsung ke geto. Uji dari client Divisi A atau B bahwa akses ke web utama dibalas oleh Maki/Panda, sedangkan akses ke /api diteruskan dan dijawab oleh Nanami/Todo.

### Maksud soal

Menyediakan satu pintu masuk: root menuju frontend, sedangkan /api menuju geto dan API worker.

### Cara mengerjakan

Konfigurasi berikut berasal dari [soal_16.sh](perquest-script/soal_16.sh). Jalankan setiap bagian pada node yang disebut dalam komentar; berkas ini berisi instruksi beberapa node, bukan satu script untuk dieksekusi seluruhnya pada satu node.

```sh
# Jalanin di gojo (Reverse Proxy publik, 192.237.1.10):
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


# TEST dari client Divisi A atau B:
#Round robin frontend: harus gantian maki / panda
for i in 1 2 3 4; do curl -s http://jujutsu.k52.com/; done
curl -s http://www.jujutsu.k52.com/

#/api: dijawab nanami / todo (rasio 3:1)
for i in 1 2 3 4; do curl -s http://jujutsu.k52.com/api; echo; done

#kalau DNS belum bisa, pakai header Host:
curl -s -H "Host: jujutsu.k52.com" http://192.237.1.10/
```

### Cara melakukan validasi

```sh
for i in 1 2 3 4; do curl -s http://jujutsu.k52.com/; done
curl -s http://www.jujutsu.k52.com/
for i in 1 2 3 4; do curl -s http://jujutsu.k52.com/api; echo; done
```

### Bukti pengujian

**16. Test loopback**

![16. Test loopback](<Assets/16. Test loopback.png>)

### Hasil dan analisis

Root dan alias www menghasilkan respons frontend; hasil yang tampak adalah beberapa respons maki kemudian panda. Potongan kecil ini membuktikan kedua frontend dapat merespons, bukan rasio alternasi 1:1 pada setiap pasangan request. Empat respons API tampak nanami, nanami, nanami, todo. IP klien pada foto tahap ini masih IP geto (`192.237.4.18`); koreksinya dibuktikan pada soal 17.

---

<a id="soal-17"></a>

## Soal 17 — Pencatatan IP Asli Klien

### Soal

> Komando pusat perlu mengetahui IP asli klien yang mengirimkan request tanpa tertukar dengan IP proxy perantara. Konfigurasikan gojo dan geto agar meneruskan informasi alamat klien melalui header X-Real-IP dan X-Forwarded-For. Pastikan geto hanya mempercayai informasi alamat klien yang diterima dari proxy terpercaya, dan skrip API menyimpan alamat klien yang telah diverifikasi ke kolom client_ip pada tabel request_logs di database yaga. Uji dengan mengirimkan request dari klien Network 2 dan Network 3 ke endpoint /api, kemudian periksa database untuk memastikan alamat yang tercatat sesuai dengan IP klien asal, bukan IP gojo atau geto.

### Maksud soal

Menjaga IP klien melintasi dua proxy dan menyimpan IP yang telah diverifikasi, bukan mempercayai header bebas dari klien.

### Cara mengerjakan

Konfigurasi berikut berasal dari [soal_17.sh](perquest-script/soal_17.sh). Jalankan setiap bagian pada node yang disebut dalam komentar; berkas ini berisi instruksi beberapa node, bukan satu script untuk dieksekusi seluruhnya pada satu node.

```sh
# =============== gojo ===============
#header X-Real-IP dan X-Forwarded-For sudah ada di config nomor 16, cek:
grep -n "X-Real-IP\|X-Forwarded-For" /etc/nginx/sites-available/gojo
nginx -t && service nginx reload


# =============== geto (192.237.4.18) ===============
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


# =============== nanami, todo, kirara ===============
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


# =============== TEST ===============
#dari klien Net2 (mis. itadori) dan Net3 (mis. ino), catat IP-nya dulu:
ip -br addr show eth0
curl -s http://jujutsu.k52.com/api

#coba spoof header, harus tetap tercatat IP asli (gojo menimpa header):
curl -s -H "X-Real-IP: 1.2.3.4" -H "X-Forwarded-For: 1.2.3.4" http://jujutsu.k52.com/api

#cek database di yaga:
mysql -e "SELECT id, client_ip, hostname, path, created_at FROM db_shibuya_k52.request_logs ORDER BY id DESC LIMIT 10;"
# client_ip harus = IP klien (192.237.2.x / 192.237.3.x), bukan IP gojo (192.237.1.10) / geto (192.237.4.18)
```

### Cara melakukan validasi

```sh
# Pada itadori dan kusakabe
ip -br addr show eth0
curl -s http://jujutsu.k52.com/api
curl -s -H "X-Real-IP: 1.2.3.4" -H "X-Forwarded-For: 1.2.3.4" http://jujutsu.k52.com/api
# Pada yaga
mysql -e "SELECT id,client_ip,hostname,path,created_at FROM db_shibuya_k52.request_logs ORDER BY id DESC LIMIT 10;"
```

### Bukti pengujian

**17. Cek database**

![17. Cek database](<Assets/17. Cek database.png>)

**17. Net2**

![17. Net2](<Assets/17. Net2.png>)

**17. Net3**

![17. Net3](<Assets/17. Net3.png>)

### Hasil dan analisis

Itadori tercatat sebagai `192.237.2.10`, sedangkan Kusakabe sebagai `192.237.3.11`. Percobaan header palsu `1.2.3.4` dari Itadori tetap menghasilkan IP asli `.2.10`. Baris terbaru database menunjukkan IP Network 2 dan 3; baris lama masih memuat `.4.18` dari pengujian sebelum perbaikan header.

---

<a id="soal-18"></a>

## Soal 18 — Failover ke Worker Cadangan

### Soal

> nanami dan todo merupakan worker API utama, sedangkan kirara disiapkan sebagai worker cadangan. Konfigurasikan upstream api_cluster pada geto agar kirara menjadi server backup, serta terapkan passive health check dengan parameter max_fails=2 dan fail_timeout=5s pada worker API utama. Pastikan kirara menjalankan layanan API yang kompatibel dengan endpoint utama. Simulasikan gangguan dengan menghentikan layanan Nginx atau layanan API pada nanami dan todo. Buktikan dari klien bahwa request ke /api dialihkan ke kirara dan menghasilkan respons API yang valid tanpa error 502 Bad Gateway.

### Maksud soal

Menggunakan kirara hanya saat worker utama tidak tersedia, dengan passive health check pada nanami/todo.

### Cara mengerjakan

**Pada geto**, ganti definisi `api_cluster` sebelumnya, jangan mendeklarasikan upstream dengan nama sama dua kali:

```nginx
upstream api_cluster {
    server 192.237.4.15 weight=3 max_fails=2 fail_timeout=5s;
    server 192.237.4.16 weight=1 max_fails=2 fail_timeout=5s;
    server 192.237.4.17 backup; # kirara
}
```

Dalam `location /` geto, pertahankan konfigurasi header soal 17 dan tambahkan:

```nginx
proxy_connect_timeout 2s;
proxy_read_timeout 5s;
proxy_next_upstream error timeout http_502 http_503 http_504;
proxy_next_upstream_tries 3;
```

Jalankan `nginx -t && service nginx reload`. Health check ini **pasif**: kegagalan diketahui saat ada request, bukan probe periodik. Kirara menggunakan virtual host dan API yang sama seperti worker utama.

**Pada nanami dan todo**, hentikan layanan:

```sh
service nginx stop
```

Lakukan loop uji dari Kusakabe. Setelah pengujian, jalankan `service nginx start` pada kedua worker utama; beri waktu untuk percobaan ulang sesuai fail_timeout.

### Cara melakukan validasi

```sh
# Kusakabe, sebelum limiter nomor 19 diaktifkan
for i in $(seq 1 12); do
  curl -s -o /dev/null -w "%{http_code}\n" http://jujutsu.k52.com/api
done | sort | uniq -c
for i in $(seq 1 6); do curl -s http://jujutsu.k52.com/api; echo; done
```

### Bukti pengujian

**18. dijawab kirara**

![18. dijawab kirara](<Assets/18. dijawab kirara.png>)

### Hasil dan analisis

Dari Kusakabe, 12 request menghasilkan **12 HTTP 200**. Respons JSON berisi `worker: kirara`, `client_ip: 192.237.3.11`, dan `logged: true`. Ini membuktikan endpoint cadangan melayani request; tangkapan stop service dan konfigurasi health check tidak disertakan. Script nomor 18 kosong; konfigurasi berikut adalah rekonstruksi.

---

<a id="soal-19"></a>

## Soal 19 — Proxy Cache dan Rate Limiting

### Soal

> gojo bertugas mengoptimalkan layanan web sekaligus membatasi request berlebihan. Konfigurasikan Nginx Proxy Caching untuk halaman web frontend dengan masa berlaku cache 10 menit dan tambahkan header X-Cache-Status. Terapkan rate limiting pada path /api dengan batas 10 request per detik per IP klien. Buktikan bahwa request ke halaman web yang memenuhi syarat cache menghasilkan status MISS pada akses awal dan HIT pada akses berikutnya. Uji rate limiting secara terpisah dengan mengirimkan request beruntun ke /api, kemudian catat status respons yang dihasilkan ketika batas terlampaui.

### Maksud soal

Mengurangi akses berulang ke frontend dengan cache 10 menit dan membatasi /api hingga 10 request per detik per IP.

### Cara mengerjakan

**Pada gojo**, tambahkan konfigurasi di konteks `http`, misalnya `/etc/nginx/conf.d/cache_limit.conf`:

```nginx
proxy_cache_path /var/cache/nginx/jujutsu levels=1:2
    keys_zone=jujutsu_cache:10m inactive=20m use_temp_path=off;
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
```

Buat direktori cache dan beri kepemilikan ke user worker nginx:

```sh
mkdir -p /var/cache/nginx/jujutsu
chown -R www-data:www-data /var/cache/nginx/jujutsu
```

Pada server gojo soal 16, gunakan dua location berikut. Semua header proxy tetap dikirim; tidak ada cache untuk API agar pencatatan request tetap berjalan.

```nginx
location / {
    proxy_pass http://frontend_cluster;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $remote_addr;
    proxy_cache jujutsu_cache;
    proxy_cache_key "$scheme$request_method$host$request_uri";
    proxy_cache_valid 200 10m;
    add_header X-Cache-Status $upstream_cache_status always;
}
location /api {
    limit_req zone=api_limit;
    limit_req_status 429;
    proxy_pass http://geto_backend;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $remote_addr;
}
```

Validasi dengan `nginx -t && service nginx reload`. Tanpa `burst`, request beruntun lebih mudah ditolak. Rasio 200/429 bergantung waktu kedatangan request. Cache membuat beberapa respons frontend berturut-turut berasal dari objek yang sama; uji round robin nomor 16 dilakukan sebelum cache atau memakai URI yang belum tersimpan.

### Cara melakukan validasi

```sh
# Kusakabe: gunakan URI frontend yang belum pernah di-cache untuk MISS awal
for i in 1 2 3; do
 curl -s -D - -o /dev/null http://jujutsu.k52.com/ | grep -i X-Cache-Status
done
seq 1 40 | xargs -P 20 -I{} sh -c 'curl -s -o /dev/null -w "%{http_code}\n" http://jujutsu.k52.com/api' | sort | uniq -c
```

### Bukti pengujian

**19. Test di net3**

![19. Test di net3](<Assets/19. Test di net3.png>)

### Hasil dan analisis

Pengujian frontend menunjukkan **MISS, HIT, HIT**. Burst 40 request API menghasilkan **1 respons 200 dan 39 respons 429**. Angka ini merupakan hasil satu burst, bukan ukuran kapasitas stabil 10 request/detik. Script nomor 19 kosong; konfigurasi berikut adalah contoh yang memenuhi target cache dan limiter.

---

<a id="soal-20"></a>

## Soal 20 — Benchmark dan Analisis Log

### Soal

> Sebelum Curtain di Shibuya resmi dibuka, Kusakabe memimpin audit untuk menguji kapasitas layanan. Dari terminal kusakabe, jalankan benchmark menggunakan Apache Benchmark dengan parameter -n 600 -c 30 menuju http://jujutsu.<xxxx>.com/. Catat Requests per Second (RPS), latensi, dan jumlah request yang gagal. Lakukan pengujian tambahan pada endpoint /api untuk mengamati efek rate limiting. Bandingkan hasil pengujian baseline dengan hasil ketika rate limiting aktif, serta gunakan access log gojo untuk membedakan kegagalan aplikasi, koneksi, dan request yang ditolak oleh kebijakan rate limit.

### Maksud soal

Membandingkan kapasitas frontend, API baseline, dan API dengan limiter sambil memisahkan penolakan kebijakan dari kegagalan layanan.

### Cara mengerjakan

**Pada Kusakabe (Alpine):**

```sh
apk add apache2-utils curl
ab -n 600 -c 30 http://jujutsu.k52.com/ > /root/ab_root.txt
```

Untuk baseline API, pada gojo nonaktifkan sementara hanya `limit_req zone=api_limit;` di location `/api`, lalu `nginx -t && service nginx reload`. Jalankan pada Kusakabe:

```sh
ab -n 600 -c 30 http://jujutsu.k52.com/api > /root/ab_api_baseline.txt
```

Aktifkan kembali limiter di gojo, reload, lalu jalankan:

```sh
ab -n 600 -c 30 http://jujutsu.k52.com/api > /root/ab_api_limit.txt
```

Gunakan kondisi worker, cache, dan resource yang sama untuk perbandingan yang adil. Jika respons JSON antarworker panjangnya berbeda, ApacheBench dapat menghitung `Length` sebagai failed request walaupun statusnya 200. Catat rincian Connect/Receive/Length/Exceptions; uji tambahan `ab -l` dapat mengizinkan panjang respons dinamis, tetapi tidak mengganti hasil asli.

Agar log memuat atribut analisis seperti pada gambar, definisikan format di konteks `http` nginx gojo:

```nginx
log_format audit '$remote_addr [$time_local] "$request" status=$status '
                 'ups=$upstream_status cache=$upstream_cache_status '
                 'rt=$request_time urt=$upstream_response_time';
```

Di server gojo tambahkan:

```nginx
access_log /var/log/nginx/gojo_access.log audit;
error_log /var/log/nginx/gojo_error.log;
```

**Hasil pada screenshot:**

| Skenario | RPS | Time per request mean | Mean across concurrent requests | Failed requests | Non-2xx |
|---|---:|---:|---:|---:|---:|
| Root frontend | 5958.35 | 5.035 ms | 0.168 ms | 0 | Tidak ditampilkan |
| API baseline | 781.89 | 38.369 ms | 1.279 ms | 149 | Tidak ditampilkan |
| API dengan limiter | 5565.45 | 5.390 ms | 0.180 ms | 598 | 598 |

**Interpretasi:** RPS API setelah limiter lebih tinggi karena sebagian besar request segera ditolak, bukan karena API memproses lebih banyak pekerjaan. Latensi `Time per request (mean)` berbeda makna dari baris `across all concurrent requests`; jangan mencampurkannya. Penyebab 149 failed pada baseline tidak bisa dipastikan karena rincian failed requests tidak tampak dalam gambar.

**Agregasi access log yang terlihat:**

| Atribut | Jumlah |
|---|---:|
| Total request | 1843 |
| status 200 | 1206 |
| status 429 | 637 |
| Cache `-` | 1240 |
| Cache HIT | 602 |
| Cache MISS | 1 |

Angka log merupakan agregasi beberapa percobaan, sehingga tidak harus sama dengan satu batch 600 request. Pada potongan gambar, perintah menghitung kategori error tidak semuanya memperlihatkan angka hasil; jangan menyimpulkan nilainya nol.

- **Rate limit:** status 429, umumnya `ups=-` karena ditolak sebelum mencapai upstream; korelasikan error log `limiting requests`.
- **Aplikasi/upstream:** periksa 5xx, `ups`, dan error log. Status 502/504 dapat berasal dari kegagalan koneksi atau timeout menuju upstream, bukan selalu error kode aplikasi.
- **Koneksi klien:** status 499 berarti klien menutup koneksi; kegagalan koneksi yang tidak membentuk request HTTP mungkin tidak tercatat di access log dan perlu dilihat pada rincian ApacheBench.

Contoh pemeriksaan di gojo:

```sh
grep -c 'status=429' /var/log/nginx/gojo_access.log
grep -E 'status=5[0-9]{2}' /var/log/nginx/gojo_access.log
grep -c 'status=499' /var/log/nginx/gojo_access.log
tail -n 100 /var/log/nginx/gojo_error.log
```

### Cara melakukan validasi

```sh
for f in ab_root ab_api_baseline ab_api_limit; do
 echo "=== $f ==="
 grep -E "Requests per second|Time per request|Failed requests|Non-2xx" /root/$f.txt
done
```

### Bukti pengujian

**20. bandingin hasil di kusakabe**

![20. bandingin hasil di kusakabe](<Assets/20. bandingin hasil di kusakabe.png>)

**20. cek akses log**

![20. cek akses log](<Assets/20. cek akses log.png>)

