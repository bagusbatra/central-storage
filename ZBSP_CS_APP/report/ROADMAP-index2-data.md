# Roadmap — Menyambungkan Data `index2.htm`

Dibuat: 2026-08-01 · Direvisi: 2026-08-03 (tahap 5 & 6 selesai, K4 & K6 ditutup)
Halaman: `ZBSP_CS_APP/Page with Flow Logic/index2.htm` (Dashboard Production)
Endpoint: `ZBSP_CS_APP/Page with Flow Logic/dash_prod.htm` — **wajib ikut aktif**
Status UI: **selesai & sudah diaktifkan di SAP**, tampilan sesuai prototype

Dokumen ini pegangan penyambungan data. Kalau Anda membuka sesi baru, baca
dokumen ini dari atas — isinya cukup untuk melanjutkan tanpa konteks lain.

## Kemajuan per 2026-08-03

| Tahap | Isi | Status |
|---|---|---|
| 0 | Perluas cakupan SLoc | ✅ Selesai — 1 → 6 (2026-08-01) → **8** (2026-08-03) |
| 1 | Filter Buyer + kartu BUYER | ✅ Selesai |
| 2 | Panel SO | ✅ Selesai — klik SO ditambahkan 2026-08-03 |
| 3 | Dua kotak center + tiga warna | ✅ Selesai — hijau dari `MSEG` |
| 4 | Peta Work Center | ❌ **DIBATALKAN** 2026-08-03 — seluruh elemen work center dihapus atas permintaan user |
| 5 | Detail Komponen | ✅ Selesai 2026-08-03 |
| 6 | DI PRODUKSI / SELESAI PROD. | ✅ Selesai. BOTTLENECK ❌ dibatalkan bersama work center |
| 7 | Finalisasi CONFIRMED | ✅ Ditutup lewat rename **OPERASI SELESAI** |

**Tidak ada keputusan terbuka yang tersisa.** K5 gugur bersama penghapusan
work center, dan dengan itu seluruh tahap roadmap ini selesai atau dibatalkan.

---

## KETENTUAN WAJIB

Ditetapkan user 2026-08-01. Berlaku untuk **seluruh** panel di halaman ini.
Kalau sebuah panel melanggar salah satunya, panel itu salah — bukan
ketentuannya yang dinegosiasi.

### W1 — Cakupan data: **delapan** storage location

Diperluas dari enam ke delapan 2026-08-03 (`22EK`, `2292`). Data yang diambil
terfokus pada **SO yang memiliki stok** di:

```
2KCS · 2261 · 2262 · 22EK · 22E2 · 22E3 · 229K · 2292
```

Berlaku untuk apa pun yang diturunkan darinya — nama buyer, komponen, dan SO. Satu SO masuk cakupan kalau punya stok di **salah satu**
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

**Lintasan Produksi — empat tahap** (ketetapan user 2026-08-03). Tiap tahap
punya SLoc MASUK (antri) dan SLoc KELUAR (selesai):

| Tahap | Antri | Selesai |
|---|---|---|
| IN dari Storage | — | `2KCS` |
| **Machining Center** | `2261` | `2262` |
| **Banding** | `22EK`, `22E2` | `22E3` |
| **Sanding** | `229K` | `2292` |
| OUT ke Storage | — | tidak punya SLoc — dihitung dari MSEG |

> 🔴 **`229K` KINI BERARTI "ANTRI SANDING", BUKAN "SELESAI".** Sebelum
> 2026-08-03 seluruh aplikasi memperlakukannya sebagai CP4 = 100% selesai
> (`ZCL_CS_UTIL` `gc_st_done`, `cp_qty( )` CP4). Model itu **salah** —
> ditetapkan user. `cp_qty( )` sudah kode mati sehingga tidak ada yang rusak,
> tapi jangan memakai 229K sebagai penanda selesai lagi di mana pun.

> ⚠️ `2292` = "Sanding D-OUT" menurut T001L (`ZCL_CS_UTIL.abap:289`). User
> sempat menulis `2297`; SLoc itu tidak ada di sistem maupun repo, dan
> dikonfirmasi sebagai salah ketik.

> ⚠️ **OUT adalah tafsiran**, bukan ketetapan: komponen yang pernah masuk
> salah satu dari delapan SLoc tapi kini tidak bersaldo di satu pun.

---

## Arti tiga warna di Lintasan Produksi

Bar 3 segmen di tiap kotak center memakai arti berikut. **Ini definisi resmi**
— legenda halaman ("Dikerjakan / Antri / Sudah Lewat") harus dibaca dengan
urutan kuning → biru → hijau.

### Machining Center

| Warna | Arti | Sumber |
|---|---|---|
| 🟡 Kuning — **antri** | Barang masih berada di `2KCS` | Saldo stok di 2KCS |
| 🔵 Biru — **dikerjakan** | Barang ada di `2261`/`2262` | Saldo stok 2261/2262 |
| 🟢 Hijau — **sudah lewat** | Pernah masuk & selesai di Machining Center, walaupun **stoknya sudah tidak ada** karena lanjut ke proses berikutnya | **Bukan saldo stok** — lihat bagian "Masalah warna hijau" |

### Edge Banding & Sanding

| Warna | Arti | Sumber |
|---|---|---|
| 🟡 Kuning — **antri** | Barang masih antre, belum masuk proses edge banding maupun sanding | Saldo stok, belum di 22E2/22E3/229K |
| 🔵 Biru — **dikerjakan** | Barang ada di `22E2`/`22E3` (edge banding) atau `229K` (sanding) | Saldo stok |
| 🟢 Hijau — **sudah lewat** | Sudah selesai fase ini; barang siap untuk pre-assy / assy | Sama seperti MC — lihat di bawah |

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

### Tahap 4 — Peta Work Center — ❌ DIBATALKAN 2026-08-03

Seluruh elemen work center dihapus dari halaman ini atas permintaan user:
section Peta Work Center, kartu BOTTLENECK, sub-label "40 WC"/"20 WC", kolom
WC di Detail Komponen dan di baris bentang tahap, serta rantai
`AFVC-ARBID → CRHD-ARBPL` di endpoint.

Petanya memang tidak pernah tersambung data — isinya `Math.random()` sejak
awal — dan bergantung pada K5 yang tak kunjung diputuskan. Menghapusnya
menutup K5 sekaligus membuang satu-satunya elemen dummy yang tersisa.

### Tahap 5 — Detail Komponen — ✅ SELESAI 2026-08-03

Endpoint `dash_prod.htm?part=komp` (ringkasan) + `?part=ops1` (tahap satu
komponen). Satu baris = satu komponen (SO+Item+Material), bisa dibentangkan.

- **Status komponen dari konfirmasi operasi (AFRU)**, dinilai **di tahap center
  yang sedang dipilih** — bukan dari posisi SLoc
- **Baris bentang berisi TAHAP (order), bukan VORNR.** Alasannya justru
  temuan bagian B di atas: 86,1% order hanya punya 1 operasi, jadi daftar
  VORNR hampir selalu satu baris. Daftar tahap menjadikannya peta perjalanan
- **Komponen dipetakan ke center lewat `AFPO-PWERK` + `AFKO-DISPO`**, bukan
  dari nama work center — pengelompokan WC memang belum diputuskan (bagian G/I)
- **Batas 400 komponen** tanpa scope, 2000 bila discope ke satu SO/buyer;
  sisanya dicacah dan dilaporkan lewat `more`, tidak dibuang diam-diam
- **✅ K4 ditutup:** kolom QTY ROUTING diganti kolom **OPERASI** berisi
  `done/tot op` + work center aktif. Rantai 3+ tahap memang tidak akan pernah
  muncul; kolomnya diisi hal yang benar-benar ada

⚠️ **Verifikasi lama tidak berlaku lagi.** "Jumlah baris tanpa filter = jumlah
komponen di kartu KOMPONEN" **salah** untuk tabel ini: kartu berbasis saldo
stok, tabel berbasis order+operasi, dan komponen tanpa order di tahap itu
sengaja tidak ditampilkan (dicacah sebagai `nook`). Verifikasi penggantinya:
`baris tab Dikerjakan + Antri + Selesai = rows.length`, dan
`rows.length + nook` = jumlah komponen yang punya order di tahap itu.

### Tahap 6 — Kartu DI PRODUKSI / SELESAI PROD. — ✅ SELESAI

- **DI PRODUKSI** — ✅ selesai. Komponen yang punya stok di SLoc proses
  (di luar 2KCS). Sub-teks dua baris: rasio thd total komponen, lalu
  rincian `MC: n · EB: n`. Seluruhnya dari angka yang sudah dikirim
  `part=stock`; tidak ada query baru
- **SELESAI PROD.** — ✅ selesai, **didefinisi ulang** 2026-08-03
  (Opsi B / Tafsir X): `AFPO-WEMNG ≥ PSMNG` **DAN** stok kosong di keenam
  SLoc → field `done_real`. Definisi lama ("stok ada di 229K") hanya proxy
  sementara; field `done` sengaja tetap dikirim sebagai pembanding sampai
  PPIC memverifikasi angka baru
- **BOTTLENECK** — ❌ dihapus 2026-08-03 bersama seluruh elemen work center

### Tahap 7 — Finalisasi CONFIRMED — ✅ DITUTUP 2026-08-03

**✅ K6 ditutup**, tapi tidak dengan cara yang diduga dokumen ini. Alih-alih
memilih salah satu dari dua definisi, **labelnya yang diubah**: kartu
`CONFIRMED` menjadi **`OPERASI SELESAI`**. Definisi & query tidak berubah —
yang dihitung memang operasi ter-konfirmasi. Kartu tidak lagi mengklaim
"komponen diterima" seperti maksud prototype.

Sub-teks jadi `X dari Y operasi`; peringatan pembatasan 1.500 order pindah ke
ikon ⚠ + tooltip.

---

## Daftar keputusan terbuka

| # | Keputusan | Tahap | Status |
|---|---|---|---|
| K1 | Arti `%` per buyer | 1 | ✅ Ditutup 2026-08-01 — komponen yang sudah keluar dari 2KCS ÷ seluruh komponen buyer itu |
| K2 | Arti segmen progress bar SO | 2 | ✅ Ditutup 2026-08-01 — kuning 2KCS · biru MC · hijau EBS |
| K3 | **Cara menghitung warna hijau "sudah lewat"** | 3 | ✅ Ditutup 2026-08-01 — `MSEG` shkzg='S', pernah masuk & stok kini nol (`part=hist`) |
| K4 | Isi kolom QTY ROUTING | 5 | ✅ Ditutup 2026-08-03 — jadi kolom OPERASI: `done/tot op` + WC aktif |
| K5 | Dasar perhitungan "beban" WC | 4 | ❌ **GUGUR** 2026-08-03 — work center dihapus, pertanyaannya tidak relevan lagi |
| K6 | Definisi CONFIRMED | 7 | ✅ Ditutup 2026-08-03 — label diubah jadi OPERASI SELESAI, definisi tetap operasi |

**Tidak ada keputusan terbuka yang tersisa.** K5 gugur 2026-08-03: kedua hal
yang dulu diblokirnya — peta Work Center dan kartu BOTTLENECK — dihapus
seluruhnya, jadi pertanyaan "beban WC dihitung dari apa" tidak punya konsumen
lagi.

Kalau suatu saat work center dihidupkan kembali, K5 harus dibuka ulang lebih
dulu, dan rantai `AFVC-ARBID → CRHD-ARBPL` yang dibuang dari `dp_komp.htm`
bisa diambil lagi dari git.

---

## Ambang kinerja — ambangnya SUDAH terlampaui, polanya sudah dipindah

Peringatan yang ditulis di sini 2026-08-01 terbukti benar dan **sudah
terjadi**: setelah tahap 0 memperluas cakupan ke enam SLoc, halaman menjadi
>1 menit / timeout. Query sinkron dipindahkan seluruhnya ke endpoint AJAX
`dash_prod.htm` + cache SHARED BUFFER `indx(zc)`, TTL **300 detik**.

**Akibatnya, dua hal yang dulu tertulis di sini tidak berlaku lagi:**

- ❌ ~~"Halaman menjalankan query … secara sinkron"~~ — `index2.htm` **tidak
  menjalankan SELECT sama sekali**. HTML keluar seketika, angka menyusul
- ❌ ~~"`index2.htm` masih berdiri sendiri tanpa dependensi"~~ — **aktivasi SE80
  kini butuh DUA berkas**: `index2.htm` dan `dash_prod.htm`. Tanpa yang kedua,
  seluruh kartu tetap bertanda "-"

**Aturan yang menggantikannya:** jangan menambah SELECT baru di `index2.htm`.
Kalau butuh data, tambahkan di `dash_prod.htm` supaya ikut ter-cache dan tidak
memblokir tampilan. Batas yang sudah dipasang dan jangan dinaikkan diam-diam:
`lc_maxord = 1500`, `lc_maxso = 500`, `lc_maxkmp = 400`, `lc_maxkm2 = 2000`.
Kalau sebuah batas terlampaui, UI **wajib** mengatakannya (`trunc`, `more`,
`solist_more`) — daftar yang diam-diam terpotong lebih berbahaya daripada
daftar yang mengaku tidak lengkap.

## Cara menguji tanpa server SAP

Ditambahkan 2026-08-03 setelah satu *syntax error* JavaScript diam-diam
mematikan seluruh blok `<script>` selama tiga commit (lihat
`daily/2026-08-03.md` bagian 1).

1. Baca `index2.htm`, buang seluruh tag `<% %>`, `<%= %>`, `<%-- --%>`
2. Sisipkan `<script>` yang menimpa `window.kpiGet` dengan stub pembalas JSON
   palsu **berbentuk sama persis** dengan yang dijanjikan `dash_prod.htm`
3. Sajikan lewat `http://localhost` — `file://` ditolak ekstensi browser
4. Periksa statis juga: `new Function(isiBlokScript)` menangkap syntax error
   yang tidak terlihat dari membaca kode

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
