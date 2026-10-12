| Bagian | Node dan perannya |
|---|---|
| Penghubung seluruh jaringan | **jichi**: router utama, akses internet melalui NAT, dan DHCP relay |
| Network 1 — `P.1.0/24` | **utahime**: DNS master; **shoko**: DNS slave; **gojo**: pintu masuk layanan web/API |
| Network 2 — `P.2.0/24` | **itadori, fushiguro**: klien pool 1; **zenin, okkotsu**: klien pool 2 |
| Network 3 — `P.3.0/24` | **ino, kusakabe**: lease singkat; **miwa**: lease panjang; **kugisaki**: alamat tetap melalui DHCP |
| Network 4 — `P.4.0/24` | **tengen**: DHCP server; **geto**: pembagi beban API; **maki, panda**: frontend; **nanami, todo**: API utama; **kirara**: API cadangan; **yaga, inumaki**: database master dan slave |

| No. | Tujuan sederhananya |
|---|---|
| 1 | Membuat jaringan saling terhubung dan bisa mengakses internet. |
| 2 | Menyiapkan tengen sebagai pembagi alamat IP. |
| 3 | Membuat permintaan DHCP dapat menyeberang subnet melalui jichi. |
| 4 | Memisahkan kelompok klien Network 2 ke dua rentang IP. |
| 5 | Memberikan masa peminjaman IP berbeda pada klien Network 3. |
| 6 | Memastikan kugisaki selalu mendapatkan IP yang sama. |
| 7 | Memeriksa IP, gateway, DNS, dan catatan lease seluruh klien. |
| 8 | Mengamati proses DHCP: Discover, Offer, Request, ACK. |
| 9 | Membuktikan dampak relay mati dan pemulihannya. |
| 10 | Membuktikan DHCP server dan relay kembali bekerja setelah restart. |
| 11 | Membuat DNS master–slave dan membuktikan sinkronisasi zona. |
| 12 | Menyiapkan nama domain, alias, reverse DNS, dan penerusan kueri internet. |
| 13 | Membuat database utama dan salinannya melalui replikasi. |
| 14 | Menyiapkan frontend/API serta membatasi akses langsung ke worker. |
| 15 | Membagi request API ke nanami dan todo dengan bobot 3:1. |
| 16 | Mengarahkan path `/` ke frontend dan `/api` ke layanan API. |
| 17 | Memastikan database mencatat IP asli klien meskipun melewati proxy. |
| 18 | Mengalihkan API ke kirara ketika kedua worker utama gagal. |
| 19 | Menguji cache web dan pembatasan request API. |
| 20 | Mengukur kinerja layanan dan membedakan penyebab request gagal. |


1. Ketika Curtain menutup Shibuya, jalur komunikasi antar zona Jujutsu High terputus. Pulihkan konektivitas dasar dengan mengonfigurasi jichi: eth0 memperoleh WAN dari NAT, sedangkan eth1–eth4 menjadi gateway Network 1–4 sesuai tabel pemetaan. Aktifkan IPv4 forwarding dan source NAT, lalu tetapkan IP statis host infrastruktur sesuai tabel spesifikasi. Buktikan konektivitas setiap host ke gateway dan akses eksternal dari host yang relevan.

   <img width="777" height="137" alt="Screenshot 2026-10-12 191715" src="https://github.com/user-attachments/assets/dfeb44c4-5c5c-4475-a557-7621549d4c5f" />
