# Roadmap — Menyambungkan Data `index2.htm`

Dibuat: 2026-08-01
Halaman: `ZBSP_CS_APP/Page with Flow Logic/index2.htm` (Dashboard Production)
Status UI: **selesai & sudah diaktifkan di SAP**, tampilan sesuai prototype

Dokumen ini mengatur urutan penyambungan data. Dikerjakan tahap demi tahap
sesuai urutan di bawah; tiap tahap punya definisi, sumber data, cara
verifikasi, dan keputusan yang harus diambil sebelum mulai.

---

## Prinsip yang mengikat seluruh roadmap

1. **Aturan cakupan tidak berubah.** Halaman ini hanya menghitung SO yang punya
   **real stock** di Central Storage: `MSKA` WERKS 2000 / LGORT 2KCS /
   SOBKZ='E' / KALAB>0, sample customer `2000000004` dibuang lewat VBAK.
   Setiap panel harus tunduk pada cakupan ini — kalau tidak, angka antar panel
   tidak akan saling cocok.
2. **Satu tahap = satu commit.** Supaya kalau sebuah angka ternyata salah,
   yang perlu ditelusuri hanya satu tahap.
3. **Jangan menampilkan angka yang belum jelas definisinya.** Lebih baik tetap
   dummy dan ditandai, daripada tampil meyakinkan tetapi salah arti. Halaman
   ini akan dipakai orang produksi mengambil keputusan.
4. **Data masuk lewat array JS.** Semua panel dinamis dirender JS dari array di
   blok `DATA DUMMY UNTUK JS`. Fase data mengganti isi array itu dari ABAP —
   logika filter/render tidak perlu disentuh. Ingat meng-escape kutip tunggal
   pada teks dari SAP (`MAKTX`, `NAME1`) sebelum masuk string JS.
5. **Verifikasi silang, bukan "kelihatannya benar".** Tiap tahap punya
   pembanding: halaman lain yang sudah jalan, atau angka acuan dari
   `diag_routing.htm`.
6. Sebelum tiap commit: `python scripts/check_bsp.py "…/index2.htm"`.

---

## Ketidakcocokan prototype vs data nyata — baca dulu

Prototype dibuat sebelum data diperiksa. Tiga hal berikut **tidak akan cocok**,
dan itu bukan bug:

| Prototype | Kenyataan (bukti) | Dampak |
|---|---|---|
| 60 work center (40 MC + 20 EBS) | **17 WC nyata** pada scope SO 10446 (`diag_routing.htm` bagian D) | Peta WC akan jauh lebih sedikit kotaknya |
| "Edge Banding & Sanding" satu center | Hanya `EB2` punya DISPO. **Sanding tidak punya order sama sekali**, hanya stok di SLoc `229K` | Center EBS praktis = Edge Banding saja |
| QTY ROUTING menampilkan rantai tahap | Maks 2 operasi per order, 86,1% hanya 1 operasi, tidak ada yang ≥3 (`diag_routing.htm` bagian B) | Kolom itu tidak akan pernah menampilkan rantai panjang |

Konsekuensinya harus diputuskan, bukan disembunyikan. Lihat tahap 5 dan 4.

---

## Keputusan yang harus diambil (dan kapan)

| # | Keputusan | Dibutuhkan di tahap |
|---|---|---|
| K1 | Arti `%` di tombol buyer — persen dari apa? | 1 |
| K2 | Arti 4 segmen bar di kartu SO | 2 |
| K3 | Arti "WIP" di kotak center — komponen atau operasi? | 3 |
| K4 | Kolom QTY ROUTING mau diisi apa, mengingat rantai tahap tidak ada | 4 |
| K5 | Peta WC: tampilkan apa adanya (17 kotak) atau ubah bentuknya | 5 |
| K6 | Definisi CONFIRMED — ikut prototype ("basis komponen diterima") atau tetap basis operasi | 7 |

Keputusan diambil **saat tahapnya tiba**, bukan sekarang — supaya berdasar
angka nyata yang sudah terlihat, bukan tebakan.

---

## Tahap 1 — Filter Buyer + kartu BUYER

**Kenapa pertama:** buyer adalah sumbu yang menyaring semua panel lain. Kalau
daftar buyer salah, semua yang di bawahnya ikut salah.

**Sumber data:** pola sudah terbukti di `dash_cs.htm` (panel Buyer) —
`MSKA` 2KCS → `VBAK-KUNNR` → `KNA1-NAME1`, sample customer dibuang, lalu
COUNT DISTINCT `vbeln` & `matnr` per buyer.

**Yang diisi:**
- Array JS `BUYERS` → `id` (KUNNR), `name` (NAME1), `pct`
- Kartu BUYER: nilai = COUNT DISTINCT buyer; sub-teks = jumlah PLO
- Label `status-indicator` di header: "N Buyer | M WC"

**⚠️ K1 — arti `pct`.** Prototype menampilkan persen per buyer tanpa
menjelaskan persen dari apa. Kandidat: (a) % operasi confirmed milik SO buyer
itu, (b) % material yang sudah keluar dari 2KCS, (c) % order selesai GR.
Pilih satu dan tulis di komentar; jangan pakai angka tanpa arti.

**Verifikasi:** buka `index.htm` — panel Buyer di sana memakai cakupan yang
sama. **Daftar dan jumlah buyer harus identik.** Kalau beda, salah satunya
salah dan harus diselesaikan sebelum lanjut.

---

## Tahap 2 — Daftar SO/PLO

**Sumber data:**
- SO: `vbeln` dari `lt_stok` yang sudah ada di halaman
- Buyer: sama dengan tahap 1
- Deskripsi: `VBAP-ARKTX`, atau `MAKTX` material item
- **PLO: `PLAF-PLNUM`** — terbukti ada, `diag_routing.htm` bagian H menemukan
  19 baris PLAF untuk SO 10446 per SO+Item
- Jumlah komponen & pcs: dari `lt_stok`
- "N selesai": butuh definisi yang sama dengan K2

**Yang diisi:** array JS `SO_DATA`, label `so-buyer-label`, dan sub-teks
"N PLO" di kartu BUYER (tahap 1 menunggu angka ini).

**⚠️ K2 — 4 segmen bar.** Prototype memakai 4 warna (amber/biru/hijau/abu)
tanpa keterangan. Kandidat: belum mulai / dikerjakan / selesai / sisa. Warna
keempat (abu) mungkin "belum ada order". Tetapkan dan tulis di legenda —
saat ini legenda halaman hanya menyebut 3 status.

**Verifikasi:** jumlah SO harus sama dengan `lv_so_cnt` yang sudah dihitung
blok DATA LIVE. Angka itu **sudah ada di halaman** dan belum dipakai.

---

## Tahap 3 — Dua kotak center (WIP per center)

**Sumber data:** order dalam cakupan, dipisah lewat plant + DISPO —
Machining Center = Plant 2000 `GA1`/`GA2`; Edge Banding & Sanding = `EB2`.
Status operasi memakai rumus baku (`ΣAFRU-LMNGA` vs `AFVV-MGVRG`, baris
`STOKZ='X'` dibuang) yang sudah ada di blok DATA LIVE 2.

**Yang diisi:** angka WIP tiap kotak, "N pcs", "✓ N", dan bar 3 segmen
(done/wip/queue). Jumlah WC di sub-judul kotak.

**⚠️ K3 — arti WIP.** Prototype menulis "WIP" tanpa satuan. Kandidat:
jumlah komponen yang sedang di center itu, atau jumlah operasi berstatus
`active`. Angka `lv_op_act` **sudah dihitung** di halaman dan belum dipakai —
kandidat langsung kalau WIP dimaknai per operasi.

**Verifikasi:** total operasi kedua center harus sama dengan `lv_op_total`
yang sudah dihitung. Untuk SO 10446: 41 operasi, 26 confirmed / 5 active /
10 queue (`diag_routing.htm` bagian C).

---

## Tahap 4 — Tabel Detail Komponen

**Sumber data:** komponen = material dalam cakupan, disaring per center dan
buyer. Status dari rumus operasi yang sama.

**Yang diisi:** array JS `COMPONENT_DATA` — `name`, `code`, `buyerName`,
`mat`, `qty`, `center`, `wc`, `status`, `pos`.

**⚠️ K4 — kolom QTY ROUTING.** Prototype menampilkan `qty | MC @ WC-xx`.
Bagian `@ WC` bisa diisi dari `AFVC-ARBID` → `CRHD-ARBPL`. Yang tidak bisa
adalah menampilkan rantai tahap, karena rantai itu tidak ada di level operasi
(temuan bagian B). Putuskan: tampilkan WC saat ini saja, atau tampilkan
rangkaian order antar tahap seperti di `routing_map.htm`.

**Verifikasi:** jumlah baris tabel (tanpa filter) harus sama dengan jumlah
komponen yang dilaporkan kartu KOMPONEN — kartu itu **sudah live**.

---

## Tahap 5 — Peta Work Center

**Sumber data:** `AFVC-ARBID` → `CRHD-ARBPL` (+ `CRTX-KTEXT`), beban dihitung
dari jumlah operasi per WC.

**⚠️ K5 — bentuk tampilan.** Grid prototype dirancang untuk 20 kolom × banyak
baris (60 WC). Dengan 17 WC nyata, grid itu akan tampak kosong dan janggal.
Pilihan: biarkan apa adanya (jujur, tapi jelek), kurangi jumlah kolom, atau
tampilkan seluruh WC master Plant 2000 dan tandai mana yang terpakai.
**Putuskan setelah melihat bentuk nyatanya** — jalankan tahap ini dengan grid
apa adanya dulu, lihat hasilnya, baru sesuaikan.

**Verifikasi:** bandingkan daftar WC dengan `diag_routing.htm` bagian D untuk
SO yang sama.

---

## Tahap 6 — Kartu DI PRODUKSI / SELESAI PROD. / BOTTLENECK

Bergantung tahap 3 dan 5.

- **DI PRODUKSI** ("WIP di lantai"): mengikuti keputusan K3
- **SELESAI PROD.** ("kembali ke storage"): kandidat = komponen yang sudah
  punya stok balik di 2KCS setelah diproses. Perlu ditelusuri lewat pergerakan
  material, bukan status operasi — **ini yang paling belum jelas sumbernya**
- **BOTTLENECK**: WC dengan antrean terbanyak dari tahap 5

---

## Tahap 7 — Finalisasi CONFIRMED

**⚠️ K6.** Prototype menulis "basis komponen diterima"; angka sekarang berbasis
**operasi** ter-konfirmasi (AFRU). Setelah tahap 4 selesai, data komponen sudah
ada sehingga definisi berbasis komponen bisa dihitung dan dibandingkan.
Pilih satu, lalu samakan sub-teks kartunya dengan definisi yang dipilih.

---

## Ambang kinerja

Halaman sekarang menjalankan query MSKA + VBAK + AFKO/AFPO + AFVC + AFVV +
AFRU secara langsung saat dibuka. Tiap tahap menambah beban.

**Aturannya:** kalau waktu muat melewati **5 detik**, hentikan penambahan
query dan pindahkan ke pola yang sudah terbukti di aplikasi ini — endpoint
AJAX terpisah + cache SHARED BUFFER TTL 90 detik, seperti `dash_cs.htm` dan
`dash_kpi.htm`. `index.htm` dulu ber-TTFB 15 detik karena query stok
dijalankan sinkron; jangan mengulangi itu.

Saat itu terjadi akan ada berkas `.htm` baru yang ikut harus diaktifkan di
SE80. Sekarang `index2.htm` masih berdiri sendiri tanpa dependensi.

---

## Yang sengaja TIDAK masuk roadmap ini

- **Jalur `ZCL_CS_PEG`** (pohon konvergensi) — tertahan di Task 3, belum pernah
  dibuat di SE24. Jalur terpisah, tidak memblokir roadmap ini. Satu-satunya
  titik temu: Task 11 akan membuat `index2.htm` memanggil
  `ZCL_CS_PEG=>op_status( )`. Kalau itu dikerjakan, class **wajib** aktif di
  SE24 sebelum halaman diaktifkan
- **Stasiun setelah Sanding** (Assembling/Finishing/Packing) — menunggu 64 cost
  center diberi nama grup di `map_sec`
- **Perubahan bentuk UI** di luar penyesuaian yang dipaksa data (tahap 5)
