# Roadmap — Menyambungkan Data `index2.htm`

Dibuat: 2026-08-01 · Direvisi: 2026-08-01 (ketentuan wajib dari user)
Halaman: `ZBSP_CS_APP/Page with Flow Logic/index2.htm` (Dashboard Production)
Status UI: **selesai & sudah diaktifkan di SAP**, tampilan sesuai prototype

Dokumen ini pegangan penyambungan data. Kalau Anda membuka sesi baru, baca
dokumen ini dari atas — isinya cukup untuk melanjutkan tanpa konteks lain.

---

## KETENTUAN WAJIB

Ditetapkan user 2026-08-01. Berlaku untuk **seluruh** panel di halaman ini.
Kalau sebuah panel melanggar salah satunya, panel itu salah — bukan
ketentuannya yang dinegosiasi.

### W1 — Cakupan data: enam storage location

Data yang diambil terfokus pada **SO yang memiliki stok** di:

```
2KCS · 2261 · 2262 · 22E2 · 22E3 · 229K
```

Berlaku untuk apa pun yang diturunkan darinya — nama buyer, komponen, SO,
work center, semuanya. Satu SO masuk cakupan kalau punya stok di **salah satu**
SLoc di atas.

> ⚠️ **Ini memperluas aturan lama.** Blok DATA LIVE yang ada sekarang hanya
> memfilter `lgort = '2KCS'`. Begitu diperluas ke enam SLoc, **angka kartu
> KOMPONEN yang sekarang live akan berubah (naik)**. Itu benar dan diharapkan,
> bukan regresi. Catat angka sebelum & sesudah saat mengerjakannya.

### W2 — PLO tidak dipakai

Hapus seluruh keterangan PLO dari halaman: sub-teks kartu BUYER ("16 PLO"),
label panel SO ("Semua Buyer • 15 PLO"), dan field `plonum` di kartu SO.
Panel SO memakai **SO + SO Item**, bukan planned order.

`PLAF` tidak disentuh sama sekali di halaman ini.

### W3 — Pemetaan SLoc ke center

| Center | SLoc |
|---|---|
| **Machining Center** | `2KCS`, `2261`, `2262` |
| **Edge Banding & Sanding** | `22E2`, `22E3`, `229K` |

---

## Arti tiga warna di Lintasan Produksi

Bar 3 segmen di tiap kotak center memakai arti berikut. **Ini definisi resmi**
— legenda halaman ("Dikerjakan / Antri / Sudah Lewat") harus dibaca dengan
urutan kuning → biru → hijau.

### Machining Center

| Warna | Arti | Sumber |
|---|---|---|
| 🟡 Kuning — **antri** | Barang masih berada di `2KCS` | Saldo stok di 2KCS |
| 🔵 Biru — **dikerjakan** | Barang ada di `2261`/`2262`. Perlu dibedakan lagi: **masih antre di center** atau **sudah masuk proses**; kalau sudah, di **WC mana** | Saldo stok 2261/2262 + status operasi + `AFVC-ARBID` → `CRHD-ARBPL` |
| 🟢 Hijau — **sudah lewat** | Pernah masuk & selesai di Machining Center, walaupun **stoknya sudah tidak ada** karena lanjut ke proses berikutnya | **Bukan saldo stok** — lihat bagian "Masalah warna hijau" |

### Edge Banding & Sanding

| Warna | Arti | Sumber |
|---|---|---|
| 🟡 Kuning — **antri** | Barang masih antre, belum masuk proses edge banding maupun sanding | Saldo stok, belum di 22E2/22E3/229K |
| 🔵 Biru — **dikerjakan** | Barang ada di `22E2`/`22E3` (edge banding) atau `229K` (sanding). Info WC wajib ikut | Saldo stok + status operasi + WC |
| 🟢 Hijau — **sudah lewat** | Sudah selesai fase ini; barang siap untuk pre-assy / assy | Sama seperti MC — lihat di bawah |

Informasi WC dari segmen biru dipakai dua kali: di bar center, dan sebagai isi
**tooltip di Peta Work Center**.

---

## Masalah warna hijau — perlu brainstorming mendalam

**Masalahnya, dengan kata-kata user:** real stock dari proses yang sudah
selesai otomatis tidak ada lagi, karena materialnya lanjut ke proses
berikutnya. Tapi halaman tetap harus bisa menyatakan bahwa material itu
**pernah masuk dan pernah selesai** di center tersebut. Dan ini **tidak
berlaku** bagi material yang memang tidak pernah masuk center itu.

**Arah yang sudah terlihat (belum diputuskan):** saldo stok menjawab *"di mana
barang sekarang"*; yang dibutuhkan warna hijau adalah *"pernah lewat mana"* —
dan itu pertanyaan **pergerakan barang**, bukan saldo. Sumbernya `MSEG`.

Yang sudah ada di aplikasi ini:

- **Empat halaman aktif sudah membaca MSEG langsung** — `dash_detail.htm`,
  `dash_feed.htm`, `dash_mrp.htm`, `monitoring.htm`. Jadi pendekatannya
  terbukti jalan di sistem ini
- **`ZCL_CS_UTIL` sudah memuat "mesin checkpoint"** yang persis merumuskan
  kebutuhan ini, lewat `cp_qty( )`:

  | Checkpoint | Definisi |
  |---|---|
  | CP1 Diterima 2KCS | net masuk `2KCS` dari Plant 1000 (301/311, SHKZG 'S'), dikurangi 'H' keluar balik |
  | CP2 Masuk Machining | net masuk `2261` dengan `umlgo=2KCS` (301/311) |
  | CP3 Keluar Machining | GR bwart 101 di `2262` |
  | CP4 Selesai (229K) | net masuk `229K` dari sumber mana pun, dikurangi 'H' keluar |

  Aturan global di sana: bwart `321` **selalu dikecualikan** — itu pelepasan
  Quality Inspection (lgort = umlgo), bukan perpindahan fisik.

> ⚠️ **Tapi `cp_qty( )` adalah kode mati.** Diperiksa 2026-08-01: tidak ada satu
> pun halaman yang memanggilnya (`cp_qty`, `item_cp_status`, `dot_stages` —
> nol pemanggil). Jadi rumusannya sudah dipikirkan matang, tapi **belum pernah
> terbukti benar terhadap data nyata**. Jangan langsung dipakai; verifikasi
> dulu terhadap satu SO yang diketahui riwayatnya.

**Yang harus diputuskan saat brainstorming:**

1. Warna hijau dihitung dari **jumlah** (net qty pernah masuk) atau **status
   biner** (pernah/tidak pernah)?
2. Batas "selesai di center" itu apa — keluar dari SLoc center, atau masuk ke
   SLoc center berikutnya?
3. Bagaimana membedakan "tidak pernah masuk MC" dari "sudah lewat MC"?
   Keduanya sama-sama berstok 0 di 2261/2262
4. Apakah `cp_qty( )` dihidupkan kembali (setelah diverifikasi), atau
   `index2.htm` menghitung sendiri dari MSEG?
5. Beban query — MSEG itu tabel besar; perlu batas periode?

---

## Prinsip kerja

1. **Satu tahap = satu commit.** Kalau sebuah angka salah, yang ditelusuri
   hanya satu tahap
2. **Jangan menampilkan angka yang belum jelas definisinya.** Lebih baik tetap
   dummy dan ditandai. Halaman ini dipakai orang produksi untuk mengambil
   keputusan
3. **Data masuk lewat array JS** di blok `DATA DUMMY UNTUK JS`; logika
   filter/render tidak perlu disentuh. Escape kutip tunggal pada teks SAP
   (`MAKTX`, `NAME1`) sebelum masuk string JS
4. **Verifikasi silang**, bukan "kelihatannya benar" — tiap tahap punya
   pembanding
5. Sebelum commit: `python scripts/check_bsp.py "…/index2.htm"`

---

## Tahapan

### Tahap 0 — Perluas cakupan ke enam SLoc

**Wajib didahulukan.** Semua tahap lain bergantung pada cakupan yang benar.

- Ubah filter `lgort = '2KCS'` di blok DATA LIVE jadi `lgort IN (6 SLoc)`
- Tambahkan `lgort` ke struktur `lt_stok` — tahap berikutnya butuh tahu
  material ada di SLoc mana, bukan cuma ada atau tidak
- Catat angka kartu KOMPONEN **sebelum & sesudah**; kenaikannya wajar

**Verifikasi:** kartu KOMPONEN naik, dan jumlah per SLoc masuk akal
dibanding kartu KPI stok di `index.htm` (Central Storage / Machining /
Banding / Sanding).

### Tahap 1 — Filter Buyer + kartu BUYER

- **Sumber:** pola `dash_cs.htm` — `MSKA` (6 SLoc) → `VBAK-KUNNR` →
  `KNA1-NAME1`, sample customer `2000000004` dibuang
- **Isi:** array `BUYERS` (`id`=KUNNR, `name`=NAME1, `pct`), kartu BUYER,
  label `status-indicator` di header
- **Hapus** sub-teks "16 PLO" (W2) — ganti dengan sesuatu yang punya arti,
  mis. jumlah SO
- **❓ K1:** `pct` per buyer itu persen dari apa? Prototype tidak menjelaskan

**Verifikasi:** bandingkan dengan panel Buyer di `index.htm`. Perhatikan:
`dash_cs.htm` memakai **2KCS saja**, halaman ini memakai enam SLoc — jadi
daftarnya boleh lebih banyak, tapi **setiap buyer di `dash_cs` harus muncul
juga di sini**. Kalau ada yang hilang, ada yang salah.

### Tahap 2 — Panel SO

Ketentuan user untuk panel ini:

- Tidak memakai PLO (W2)
- Menampilkan **semua SO dan SO Item**-nya
- **Urutan jangan berantakan** — tetapkan urutan eksplisit (SO lalu Item
  menaik) dan pastikan `SORT` mengikutinya
- **Fitur search berdasarkan SO dan Item** — tambahan baru, belum ada di
  prototype. Perlu kotak pencarian di panel SO
- **Klik baris → sidebar kanan** menampilkan **semua komponen** SO+Item itu
  sesuai enam SLoc. Ini elemen UI baru yang belum ada di prototype
- **❓ K2:** arti segmen progress bar — akan didiskusikan

**Verifikasi:** jumlah SO harus sama dengan hitungan distinct `vbeln` dari
`lt_stok` setelah tahap 0.

### Tahap 3 — Dua kotak center + tiga warna

Mengikuti definisi warna di bagian atas dokumen ini.

- 🟡 dan 🔵 bisa dikerjakan dari saldo stok + status operasi
- 🟢 **diblokir** sampai brainstorming warna hijau selesai. Kerjakan kuning &
  biru dulu, hijau tetap dummy dan **ditandai jelas** di UI bahwa angkanya
  belum nyata
- Segmen biru harus sekalian menghasilkan data WC untuk tahap 4

**Verifikasi:** total operasi kedua center dibandingkan `lv_op_total` yang
sudah dihitung halaman. Acuan SO 10446: 41 operasi, 26 confirmed / 5 active /
10 queue (`diag_routing.htm` bagian C).

### Tahap 4 — Peta Work Center + tooltip

- Menampilkan WC sesuai **card yang sedang aktif** (MC atau EBS)
- **Semua WC tampil**, dibedakan warna beban: rendah / sedang / tinggi
- **Tooltip modern** berisi apa yang ada di dalam WC tersebut — material apa,
  berapa, milik SO siapa. Datanya dari segmen biru tahap 3
- **❓ K5:** "beban" dihitung dari apa? Jumlah operasi antre, jumlah komponen,
  atau qty? Akan dibahas
- ⚠️ Prototype mengasumsikan 60 WC (40 MC + 20 EBS). Kenyataannya **17 WC**
  pada scope SO 10446 (`diag_routing.htm` bagian D). Grid akan tampak jauh
  lebih kosong — putuskan bentuknya setelah melihat hasil nyatanya

### Tahap 5 — Detail Komponen

Tampilan boleh mengikuti prototype, tapi isinya akan dibahas lebih dulu.

- ⚠️ Kolom QTY ROUTING tidak akan pernah menampilkan rantai tahap — maks 2
  operasi per order, 86,1% hanya 1 operasi (`diag_routing.htm` bagian B)
- **❓ K4:** kolom itu diisi apa

**Verifikasi:** jumlah baris tanpa filter = jumlah komponen di kartu KOMPONEN.

### Tahap 6 — Kartu DI PRODUKSI / SELESAI PROD. / BOTTLENECK

Bergantung tahap 3 & 4.

- **DI PRODUKSI** ("WIP di lantai") — dari segmen biru
- **SELESAI PROD.** ("kembali ke storage") — terkait langsung masalah warna
  hijau; **diblokir** sampai itu selesai
- **BOTTLENECK** — WC dengan beban tertinggi dari tahap 4

### Tahap 7 — Finalisasi CONFIRMED

**❓ K6:** prototype menulis "basis komponen diterima"; angka sekarang berbasis
**operasi** ter-konfirmasi (AFRU). Setelah tahap 5, data komponen sudah ada
sehingga kedua definisi bisa dihitung dan dibandingkan.

---

## Daftar keputusan terbuka

| # | Keputusan | Tahap | Status |
|---|---|---|---|
| K1 | Arti `%` per buyer | 1 | ❓ belum |
| K2 | Arti segmen progress bar SO | 2 | ❓ akan didiskusikan |
| K3 | **Cara menghitung warna hijau "sudah lewat"** | 3 | ❓ **brainstorming mendalam** |
| K4 | Isi kolom QTY ROUTING | 5 | ❓ akan didiskusikan |
| K5 | Dasar perhitungan "beban" WC | 4 | ❓ akan didiskusikan |
| K6 | Definisi CONFIRMED | 7 | ❓ belum |

K3 adalah yang paling menentukan — dia memblokir tahap 3 (sebagian), tahap 6
(sebagian), dan menyentuh arti kartu SELESAI PROD.

---

## Ambang kinerja

Halaman menjalankan query MSKA + VBAK + AFKO⨝AFPO + AFVC + AFVV + AFRU secara
sinkron saat dibuka. Tahap 0 memperluas cakupan ke enam SLoc, dan warna hijau
kemungkinan menambah `MSEG` — tabel besar.

**Aturan:** kalau waktu muat melewati **5 detik**, hentikan penambahan query
dan pindah ke pola yang sudah terbukti di aplikasi ini — endpoint AJAX
terpisah + cache SHARED BUFFER TTL 90 detik, seperti `dash_cs.htm` dan
`dash_kpi.htm`. `index.htm` dulu ber-TTFB 15 detik karena query stok
dijalankan sinkron; jangan mengulangi itu.

Saat itu terjadi akan ada berkas `.htm` baru yang ikut harus diaktifkan di
SE80. Saat ini `index2.htm` masih berdiri sendiri tanpa dependensi.

---

## Di luar cakupan roadmap ini

- **Jalur `ZCL_CS_PEG`** (pohon konvergensi) — tertahan di Task 3, belum pernah
  dibuat di SE24. Terpisah, tidak memblokir. Titik temu satu-satunya: Task 11
  akan membuat `index2.htm` memanggil `ZCL_CS_PEG=>op_status( )`; kalau itu
  dikerjakan, class **wajib** aktif di SE24 sebelum halaman diaktifkan
- **Stasiun setelah Sanding** (Assembling/Finishing/Packing) — menunggu 64
  cost center diberi nama grup di `map_sec`
- **Perubahan bentuk UI** di luar yang dipaksa data (tahap 4) dan dua elemen
  baru yang diminta user: kotak pencarian SO/Item dan sidebar kanan komponen
