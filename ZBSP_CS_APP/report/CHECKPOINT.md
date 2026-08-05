# Checkpoint Rencana Pengembangan — ZBSP_CS_APP

Ringkasan status setiap jalur pengembangan aplikasi Central Storage.
Diperbarui: 2026-08-05 (index2.htm aktif di SAP; Detail Komponen berbasis real stock)

**Aturan folder:** `ZBSP_CS_APP/` adalah cermin objek SAP — apa pun di dalamnya
ada atau akan ada di sistem. Bahan rujukan yang tidak diaktifkan ada di
`reference/`. Selengkapnya di `README.md` akar repo.

**Cara pakai:** kolom Status memakai arti yang ketat di bawah ini. "Jalan"
berarti sudah aktif di SAP dan dipakai; "Belum teruji" berarti kodenya ada
tetapi belum pernah diaktifkan atau dijalankan di sistem. Jangan menaikkan
status tanpa bukti.

| Status | Arti |
|---|---|
| ✅ Jalan | Aktif di SAP, sudah dipakai, angkanya sudah diperiksa |
| 🟡 Sebagian | Sebagian fitur jalan, sisanya masih dummy atau belum tersambung |
| 🔧 Dikerjakan | Sedang dalam pengerjaan aktif |
| ⏸️ Belum teruji | Kode ada, belum pernah diaktifkan/dijalankan di SAP |
| 🚧 Terhalang | Menunggu keputusan atau data dari luar |

---

## Ikhtisar

| # | Jalur | Status | Berkas utama | Checkpoint terakhir |
|---|---|---|---|---|
| 1 | Dashboard Central Storage | ✅ Jalan | `index.htm`, `dash_*.htm` | Restrukturisasi 2026-07-24 |
| 2 | Monitoring / Pelacakan SO | ✅ Jalan | `monitoring.htm` | Perbaikan status SO 2026-07-23 |
| 3 | Diagnostik Routing (Fase 0) | ✅ Selesai | `diag_routing.htm` | Dijalankan 2026-07-30, hasil terkunci |
| 4 | Dashboard Production | 🟡 Sebagian | `index2.htm`, `dash_prod.htm` + 12 fragment | Aktif di SAP 2026-08-05. Angka belum diverifikasi silang; Sanding & OUT belum bersumber |
| 5 | Peta Perjalanan SO | 🟡 Sebagian | `routing_map.htm` | Dot map + stok real, 2026-07-31 |
| 6 | Pohon Konvergensi Material | 🔧 Dikerjakan | `ZCL_CS_PEG.abap` | Task 3 dari 11, 2026-08-01 |
| 7 | Pemetaan Cost Center (`map_sec`) | 🚧 Terhalang | — | 64 cost center menunggu diberi nama |

---

## 1. Dashboard Central Storage — ✅ Jalan

Dashboard grafis: stok per bagian, ranking buyer, sales order, feed pergerakan
barang realtime.

- **Berkas:** `index.htm`, `dash_cs.htm`, `dash_kpi.htm`, `dash_detail.htm`, `dash_feed.htm`, `dash_mrp.htm`, `dash_so.htm`
- **Checkpoint:** restrukturisasi 2026-07-24 — `index3a.htm` jadi dashboard grafis, pelacakan pindah ke `monitoring.htm`
- **Catatan:** query stok berat (~15 detik terukur), karena itu KPI dimuat asinkron lewat `dash_kpi.htm` dan `dash_cs.htm` di-cache 90 detik (SHARED BUFFER `indx(zc)`)

## 2. Monitoring / Pelacakan SO — ✅ Jalan

Pelacakan material per SO+Item, status komponen BOM berbasis RESB.

- **Berkas:** `monitoring.htm`, `monitoring_detail.htm`
- **Checkpoint:** D47/D48 — status komponen BOM dirombak dari tebakan saldo stok jadi berbasis `RESB` (`BDMNG`/`ENMNG`) yang discope ke `AUFNR` order induk
- **Pelajaran yang mengikat seluruh aplikasi:** JANGAN memfilter `XLOEK = space` di WHERE saat SELECT `RESB`. Order yang sudah TECO umumnya ber-`XLOEK='X'` sebagai penutupan administratif reservasi, bukan tanda barangnya belum dipakai. Filter itu pernah membuat order yang sudah tuntas tampil "Tidak Ada Data"

## 3. Diagnostik Routing Fase 0 — ✅ Selesai

Halaman sekali-pakai, read-only, untuk membuktikan apakah mockup Component
Movement punya sumber data di SAP.

- **Berkas:** `diag_routing.htm`
- **Dijalankan:** 2026-07-30, SO 10446, 36 order
- **Hasil yang jadi acuan seluruh pengembangan berikutnya:**

| Bagian | Vonis |
|---|---|
| B — operasi per order | **Maksimum 2 operasi, 86,1% order hanya 1 operasi, TIDAK ADA yang ≥3.** Alur antar tahap bukan routing multi-operasi, melainkan rangkaian order terpisah |
| C — konfirmasi | **Tersedia.** 74 baris AFRU, 0 dibatalkan, 41 operasi → 26 confirmed / 5 active / 10 queue |
| D — work center | **17 WC nyata** pada scope ini (mockup mengarang 52) |
| G/I — pengelompokan | SAP tidak punya field "grup/section". Kandidat: cost center. **64 cost center perlu dipetakan** |

- **Angka acuan uji:** SO 10446 = 36 order, 2 item SO, 35 material, 41 operasi, 26/5/10

## 4. Dashboard Production — 🟡 Sebagian

UI disalin dari `reference/prototype-ui/index.html` (permintaan user 2026-08-01),
lalu berubah banyak sekali 2026-08-03 s/d 08-05. Yang tertulis di bawah adalah
keadaan **sekarang**, bukan sejarahnya — sejarahnya di `report/daily/`.

- **Berkas: 14 objek SE80** — 2 halaman + 12 Page Fragment. Semuanya wajib aktif
- **Sumbu utama:** Buyer
- **Aktivasi:** dikonfirmasi user **2026-08-05** — seluruh objek aktif & aman.
  ⚠️ Perubahan 2026-08-05 (umur data, urutan keterlambatan, penghapusan
  `part=ops`, pemulihan cache) **BELUM** ikut diaktifkan

### ⚠️ Cakupan enam SLoc — ketentuan wajib

`2KCS` · `2261` · `2262` · `22E2` · `22E3` · `229K`

Sempat diperluas ke delapan (`22EK`, `2292`) 2026-08-03 lalu **dikembalikan ke
enam** 2026-08-04. Sample customer `2000000004` selalu dibuang.
Satu "komponen" = COUNT DISTINCT (VBELN + POSNR + MATNR).

### Lintasan Produksi — empat tahap

| Tahap | Antri | Selesai |
|---|---|---|
| IN dari Storage | — | `2KCS` |
| Machining Center | `2261` | `2262` |
| Banding | `22E2` | `22E3` |
| Sanding | `229K` | 🔴 **tidak ada SLoc keluar** |
| OUT ke Storage | — | 🔴 **sengaja kosong, tanpa sumber data** |

🔴 **`229K` berarti ANTRI SANDING, bukan selesai.** Sebelum 2026-08-03 seluruh
aplikasi memperlakukannya sebagai CP4 = 100% (`ZCL_CS_UTIL` `gc_st_done`,
`cp_qty`). Model lama itu **salah** — ditetapkan user. `cp_qty` kode mati
sehingga tidak ada yang rusak, tapi jangan dipakai lagi sebagai penanda selesai.

🔴 **Sanding setengah buta.** `2292` (Sanding D-OUT) adalah satu-satunya penanda
"selesai Sanding"; sejak ia keluar dari cakupan, `lv_sd_d` dan `lv_g_sd` **nol
permanen**. UI menampilkan "tanpa SLoc", bukan "0" — dua hal yang sangat berbeda.
Belum diputuskan; tiga jalan keluar ada di `daily/2026-08-04.md`.

🔴 **Kotak OUT sengaja kosong** (2026-08-04). Tidak ada sumber data yang
menghitung barang keluar dari enam SLoc. Versi pertamanya menghitung dari
`DPRODKM` — daftar yang menurut definisinya hanya berisi komponen **ber-saldo**,
sehingga syaratnya mustahil dan hasilnya **selalu 0** tanpa ketahuan. Jangan
mengisinya dengan angka yang artinya dipinjam dari perhitungan lain.

### Isi halaman

| Panel | Keadaan |
|---|---|
| Kartu ringkasan | **BUYER** & **SALES ORDER** saja. Semua kartu lain dihapus user 2026-08-04/05 |
| Lintasan Produksi | 4 tahap di atas; Banding & Sanding dua area dalam satu kartu |
| Sales Order | bar **5 segmen** (IN·Machining·Banding·Sanding·Selesai); SO yang tuntas seluruhnya **disaring keluar**, jumlahnya dilaporkan |
| Detail Komponen | **kosong sampai satu SO diklik**. 4 tab real-stock: Central Storage / Machining / Banding / Sanding |

Kolom Detail Komponen: `KOMPONEN | REAL STOCK & SLOC | QTY TARGET | QTY DEL |
PROGRES | JADWAL`. Baris **terurut keterlambatan**, paling telat di atas.

- Tab ditentukan **posisi stok**; Qty Target/Del diambil dari **order tahap yang
  sesuai tab** (`AFPO-PSMNG`/`WEMNG`)
- Jadwal = selisih hari terhadap `AFKO-GSTRP` (Bas. start date). **"Terlambat"
  berarti seharusnya sudah MULAI**, bukan seharusnya selesai
- ⚠️ Komponen yang stoknya habis **tidak muncul sama sekali** — konsekuensi
  "berdasarkan real stock". Satu-satunya jejaknya di segmen hijau bar kartu SO
- ⚠️ Sanding tidak punya DISPO, jadi qty-nya memakai **order paling akhir**
  sebagai wakil. Diperingatkan di kaki tabel saat tab itu dibuka

### Endpoint `dash_prod.htm`

| part | Isi | Cache |
|---|---|---|
| `stock` | MSKA enam SLoc → kartu, buyer, daftar SO, Lintasan | `DPRODST` |
| `hist` | `MSEG ⨝ MKPF` → "sudah lewat" tiap tahap | `DPRODHI` |
| `komp` | komponen SATU SO+Item | tidak di-cache (selalu discope) |

- **Jendela waktu `lc_bulan` = 3 bulan** membatasi MSEG (`budat`) dan AFPO
  (`gstrp`). ⚠️ **MSKA tidak bisa dibatasi** — saldo stok tidak punya tanggal,
  dan justru itu query terberat (~15 dtk). Jendelanya dinyatakan di legenda UI
- **Umur data** dikirim lewat header `X-Data-Age` (2026-08-05), bukan disisipkan
  ke JSON: jawaban dari cache diteruskan apa adanya
- `part=hist` & `part=komp` membaca `DPRODKM` dari `part=stock`. Kalau hilang,
  keduanya memaksa `part=stock&fresh=1` — mengulang permintaan yang sama tidak
  menolong, karena `part=stock` hanya menulis daftar itu saat benar-benar
  menghitung
- ⚠️ `DPRODSI` masih ditulis tapi **tanpa pembaca** sejak `part=ops` dihapus

### Batas yang tidak boleh dinaikkan diam-diam

`lc_maxso = 500` · `lc_maxkmp = 400` · `lc_maxkm2 = 2000` · `lc_bulan = 3` ·
TTL cache 300 dtk. Kalau terlampaui, UI **wajib** mengatakannya
(`solist_more`, `solist_done`).

### Daftar objek SE80

⚠️ Fragment **wajib** bertipe "Page Fragment" — dibuat sebagai "Page with Flow
Logic", SE80 mengompilasinya sendirian dan variabel halaman induk dilaporkan
tidak dikenal.

⚠️ Fragment **tetap** membawa direktif page (language abap) di baris 1, ditempel
RAPAT ke tag berikutnya. Teks di antaranya ikut tercetak ke keluaran, dan untuk
endpoint JSON itu merusak jawabannya.

| Objek | Tipe | Isi |
|---|---|---|
| `index2.htm` | Page with Flow Logic | rangka halaman |
| `cs2_css_base.htm` | Page Fragment | CSS dasar |
| `cs2_css_panel.htm` | Page Fragment | CSS panel bawah |
| `cs2_icons.htm` | Page Fragment | symbol SVG |
| `cs2_body.htm` | Page Fragment | markup |
| `cs2_js_core.htm` | Page Fragment | state, init, buyer, daftar SO |
| `cs2_js_detail.htm` | Page Fragment | tabel Detail Komponen |
| `cs2_js_kpi.htm` | Page Fragment | kpiGet, Lintasan, tooltip, boot |
| `dash_prod.htm` | Page with Flow Logic | rangka endpoint |
| `dp_komp.htm` | Page Fragment | part=komp pengumpulan |
| `dp_komp_out.htm` | Page Fragment | part=komp perakitan |
| `dp_hist.htm` | Page Fragment | part=hist |
| `dp_stock.htm` | Page Fragment | part=stock |
| `dp_stock_so.htm` | Page Fragment | part=stock daftar SO + JSON |

⚠️ `dp_ops.htm` **DIHAPUS 2026-08-05** — objek SE80-nya perlu ikut dihapus.

### 🔴 Yang belum pernah dibuktikan

**Tidak ada satu angka pun yang pernah diverifikasi silang.** Prinsip kerja #4 di
ROADMAP menuntutnya. Halaman sudah aktif, jadi ini sekarang bisa dan harus
dikerjakan: bandingkan `komp` dari `part=stock` dengan kartu stok `index.htm`.

Belum diukur juga: waktu jalan tiap `part` (field `ms`), dan perilaku saat cache
`DPRODKM` hilang.

### Pelajaran yang mengikat

1. **Jangan menulis token BSP di komentar mana pun** — bahkan saat menjelaskan
   token itu sendiri. Satu delimiter penutup di komentar menggugurkan seluruh
   blok, dan pesan errornya menunjuk baris yang salah
2. **Jangan menulis tag HTML lengkap di komentar** — sebuah `script`
   ber-kurung-sudut sempat menelan 37 KB isi halaman saat dipindai
3. **`scripts/check_bsp.py` dijalankan SEBELUM menempel ke SE80.** Ia menangkap
   (1) dan (2) — tapi hanya di komentar ABAP, bukan komentar BSP
4. **Uji di browser sebelum menyerahkan.** Satu syntax error JS menggugurkan
   seluruh blok script; pernah lolos tiga commit berturut-turut

## 5. Peta Perjalanan SO — 🟡 Sebagian

Ketik No. SO (+ Item opsional) → peta perjalanan per komponen.

- **Berkas:** `routing_map.htm`
- **Bentuk:** rantai stasiun berpanah, tiap stasiun bisa berisi titik operasi (dot map + tooltip) dan stok real yang ada di situ
- **Rantai stasiun:** `[1] Pembahanan` → `(Central Storage)` → `[2] Machining` → `[3] Edge Banding` → `[4] Sanding` → `(Lokasi lain)`
- **Sumbu pengisi:** order → stasiun lewat plant + `AFKO-DISPO`; stok → stasiun lewat plant + SLoc
- **Batas yang diketahui:**
  - Rantai berhenti di Sanding — tahap sesudahnya tidak punya DISPO maupun SLoc sendiri (lihat jalur 7)
  - Sanding hanya punya stok, tidak ada order yang memetakan ke sana
  - Urutan 1→2→3→4 adalah **asumsi urutan proses**, bukan data SAP
- **Akan dirombak** oleh jalur 6 menjadi pohon konvergensi

## 6. Pohon Konvergensi Material — 🔧 Dikerjakan

Material menyusut lewat penggabungan (20 → 5:1 → 4 → 2:1 → 2 → 2:1 → 1), jadi
bentuk datanya pohon, bukan rantai. Dibangun dari pegging `RESB`.

- **Spec:** `docs/superpowers/specs/2026-07-31-pohon-konvergensi-material-design.md`
- **Rencana:** `docs/superpowers/plans/2026-07-31-pohon-konvergensi-material.md` (11 task)
- **Ledger:** `.superpowers/sdd/2026-07-31-pohon-konvergensi-material/progress.md`
- **Berkas baru:** `classes/ZCL_CS_PEG.abap`, `classes/ZCL_CS_PEG_TESTS.abap`

| Task | Isi | Status |
|---|---|---|
| 1 | Kerangka class, `op_status( )`, `stn_of_order( )` | ✅ Selesai, review bersih |
| 2 | Sisi pohon & deteksi akar | ✅ Selesai, review bersih |
| 3 | DFS berlevel, siklus, duplikat | 🔧 Perbaikan selesai, **re-review tertunda** (loop dijeda utk perubahan UI) |
| 4 | Status kesiapan, rasio, catatan | ⬜ Belum |
| 5 | `build( )` — query database | ⬜ Belum |
| 6 | Ringkasan stasiun, work center, operasi | ⬜ Belum |
| 7–9 | Perombakan `routing_map.htm` | ⬜ Belum |
| 10 | Pembersihan & dokumentasi | ⬜ Belum |
| 11 | `index2.htm` pakai `op_status( )` | ⬜ Belum |

**⏸️ Belum teruji sama sekali di SAP.** `ZCL_CS_PEG` belum pernah dibuat di
SE24, belum pernah diaktifkan, dan kesepuluh test ABAP Unit belum pernah
dijalankan. Rencananya satu kali aktivasi + eksekusi tes setelah Task 6.

**Keputusan yang mengikat:**

| Kode | Keputusan |
|---|---|
| K1 | Fokus halaman = diagnosa hambatan ("kenapa tahap ini belum jalan") |
| K2 | Arti "stok 0" dibedakan lewat `RESB-ENMNG` — tanpa ini order yang sudah selesai tampak tertahan |
| K3 | Semua order SO+Item masuk pohon tanpa filter DISPO; yang di luar 7 nilai baku ditandai dan bisa disembunyikan lewat JS |
| K4 | Barang beli (komponen tanpa order pembuat) dibuang dari pohon |
| K5 | Logika pegging di class `ZCL_CS_PEG`, halaman hanya menyajikan |
| K6 | Kartu stasiun sebagai ringkasan + tabel pohon sebagai tampilan utama |
| K7 | Arah pohon: produk akhir di atas, bahan mentah di bawah |
| K8 | Kartu stasiun bisa diklik → panel rincian |

**Aturan tambahan yang lahir dari review (semua putusan user):**

- `op_status( )` adalah satu-satunya salinan hidup rumus status operasi
- Parameter qty wajib `p LENGTH 15 DECIMALS 3` — `TYPE p` polos membulatkan dan bisa membalik status
- Plant 1000 ber-DISPO di luar WM/PN jatuh ke stasiun 9 "Lainnya", bukan Pembahanan
- Pencarian order pembuat wajib berkunci **(matnr, kdpos)**, bukan matnr saja
- **Pohon tidak boleh kosong secara diam-diam** — bila akar tak terdeteksi (khas siklus tertutup), semua order jadi akar dan ditandai

**Utang yang diterima sadar:** barang beli tidak masuk pohon, jadi kalau yang
menahan produksi adalah lem/sekrup/engsel, halaman ini tidak melihatnya.
Diredam lewat catatan "tidak ada komponen produksi" pada daun yang semua
komponennya barang beli, dan label status yang tidak pernah berbunyi "siap
jalan".

## 7. Pemetaan Cost Center (`map_sec`) — 🚧 Terhalang

Prasyarat untuk memunculkan stasiun sesudah Sanding (Assembling / Finishing /
Packing). Tahap-tahap itu tidak punya DISPO maupun SLoc sendiri, jadi tidak
bisa diturunkan dari data yang ada.

- **Sumber daftar:** `diag_routing.htm` bagian I-b menghasilkan baris `map_sec`
  siap tempel
- **Yang dibutuhkan:** **64 cost center** perlu diberi nama grup. Daftarnya
  definitif — dihitung dari seluruh populasi order belum selesai (200.446
  order), bukan sepotong per SO
- **Kandidat yang sudah terlihat:** `1131400002` PROSES ASSEMBLY 2 (25 WC),
  `1131200000` EDGE BANDING IMA A (12 WC), `1131300003` SANDER KOMPONEN
- **Yang menghalangi:** butuh orang yang tahu pembagian unit di lapangan untuk
  memberi nama grupnya. Bukan pekerjaan yang bisa ditebak dari data

---

## Catatan lintas jalur

**Jebakan yang sudah memakan korban — jangan diulang:**

1. **`<form action="">` kosong** membuat filter mengembalikan SELURUH data.
   Semua form/link GET wajib menulis `action="namafile.htm"` eksplisit
2. **Delimiter BSP di dalam komentar ABAP.** Menulis tag output BSP di komentar
   memotong scriptlet di tengah — parser berhenti pada `%>` pertama. Gejalanya
   "Closing without opening" di baris penutup blok
3. **`VBUK`/`VBUP` kosong di S/4HANA.** Status SO/item dibaca dari
   `GBSTK`/`GBSTA` di `VBAK`/`VBAP`
4. **Filter `XLOEK` di WHERE RESB** — lihat jalur 2
5. **Elemen inline dengan CSS tinggi/margin vertikal.** `<span>` mengabaikan
   `height` dan `margin` vertikal; perlu `display:block`
6. **Tag HTML utuh di dalam komentar ABAP.** Menulis tag script/link lengkap
   di komentar membuat parser HTML editor mengira ada blok terbuka, lalu
   memparse sisa berkas sebagai bahasa lain. Tidak merusak BSP tapi meracuni
   tooling — tulis tanpa kurung sudut
7. **Resource dari CDN.** Font/ikon/JS dari domain luar tidak akan pernah
   termuat. Semua harus inline

**Alat bantu:** `scripts/check_bsp.py` memeriksa jebakan 1, 2, 6 plus
pasangan blok ABAP dan keseimbangan markup. Batasnya: hitungan div/span
tidak sahih untuk halaman yang markup-nya dipecah lintas cabang `IF` ABAP
(mis. `monitoring.htm`)

**False positive yang aman diabaikan:** linter CSS di IDE menandai
`property value expected` pada baris `style="width:<%= ... %>%"`. Linter tidak
mengenal tag output BSP; hasil render di server valid.

**Mesin checkpoint yang menganggur.** `ZCL_CS_UTIL` memuat `cp_qty( )`,
`item_cp_status( )`, dan `dot_stages( )` yang merumuskan pergerakan barang per
checkpoint dari `MSEG⨝MKPF` (CP1 Diterima 2KCS · CP2 Masuk Machining 2261 ·
CP3 Keluar Machining 2262 · CP4 Selesai 229K; bwart `321` selalu dikecualikan
karena itu pelepasan QI, bukan perpindahan fisik). Diperiksa 2026-08-01:
**tidak ada satu pun halaman yang memanggilnya** — rumusannya matang tapi
belum pernah terbukti terhadap data nyata. Ini kandidat kuat untuk menjawab
K3, tapi wajib diverifikasi dulu terhadap SO yang riwayatnya diketahui.
Empat halaman aktif (`dash_detail`, `dash_feed`, `dash_mrp`, `monitoring`)
sudah membaca MSEG langsung, jadi pendekatannya sendiri terbukti jalan.

**Urutan aktivasi di SAP:** class dulu, baru halaman. `ZCL_CS_UTIL` dan
(nanti) `ZCL_CS_PEG` harus aktif di SE24 sebelum halaman BSP yang
memanggilnya diaktifkan.
