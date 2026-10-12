| Bagian | Node dan perannya |
|---|---|
| Penghubung seluruh jaringan | **jichi**: router utama, akses internet melalui NAT, dan DHCP relay |
| Network 1 — `P.1.0/24` | **utahime**: DNS master; **shoko**: DNS slave; **gojo**: pintu masuk layanan web/API |
| Network 2 — `P.2.0/24` | **itadori, fushiguro**: klien pool 1; **zenin, okkotsu**: klien pool 2 |
| Network 3 — `P.3.0/24` | **ino, kusakabe**: lease singkat; **miwa**: lease panjang; **kugisaki**: alamat tetap melalui DHCP |
| Network 4 — `P.4.0/24` | **tengen**: DHCP server; **geto**: pembagi beban API; **maki, panda**: frontend; **nanami, todo**: API utama; **kirara**: API cadangan; **yaga, inumaki**: database master dan slave |
