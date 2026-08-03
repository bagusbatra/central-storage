# Checkpoint Rencana Pengembangan — ZBSP_CS_APP

Ringkasan status setiap jalur pengembangan aplikasi Central Storage.
Diperbarui: 2026-08-03 (index2.htm fase data — Detail Komponen aktif, Perbaikan #1)

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
| 4 | Dashboard Production | 🟡 Sebagian | `index2.htm`, `dash_prod.htm` | Fase data 6 dari 8 tahap, 2026-08-03. Sisa: peta WC & BOTTLENECK (terhalang K5) |
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

UI disalin dari `reference/prototype-ui/index.html` (permintaan user 2026-08-01). Versi
sebelumnya ("Lintasan Routing & Confirmation", porting prototype lama) diganti total; isinya masih ada di git.

- **Berkas:** `index2.htm` (UI) + `dash_prod.htm` (endpoint JSON) — **keduanya
  wajib aktif di SE80**
- **Sumbu utama:** **Buyer** (dulu SO)
- **Pusat produksi:** 2 center — Machining Center (40 WC) + Edge Banding &
  Sanding (20 WC). Dulu 3 section
- **Alur:** Storage → Machining → Edge Banding → Storage
- **⚠️ ATURAN CAKUPAN DIPERLUAS (ketentuan wajib user, 2026-08-01):** SO yang
  dihitung adalah yang punya stok di **enam** SLoc: `2KCS`, `2261`, `2262`,
  `22E2`, `22E3`, `229K` — bukan lagi 2KCS saja. Berlaku untuk buyer,
  komponen, SO, work center, semuanya. Sample customer `2000000004` tetap
  dibuang. Satu "komponen" = COUNT DISTINCT (VBELN+POSNR+MATNR)
- **PLO tidak dipakai** (ketentuan wajib user); `PLAF` tidak disentuh
- **Pemetaan center — DUA sumbu berbeda, jangan dicampur:**
  - **stok** → SLoc: Machining = `2KCS`/`2261`/`2262`;
    Edge Banding & Sanding = `22E2`/`22E3`/`229K`
  - **order** → `AFPO-PWERK` + `AFKO-DISPO`: Pembahanan = 1000 +
    WM1/WM2/PN1/PN2; Machining = 2000 + GA1/GA2; Edge Banding = 2000 + EB2.
    ⚠️ Sanding TIDAK punya DISPO, jadi pada sumbu order "EBS" = EB2 saja

### Halaman ini TIDAK lagi menjalankan query sendiri

Seluruh data lewat `dash_prod.htm` secara asinkron (dibuat 2026-08-01 setelah
halaman menjadi >1 menit/timeout). **Aktivasi SE80 kini butuh DUA berkas.**

| part | Isi | Cache |
|---|---|---|
| `stock` | MSKA enam SLoc → kartu, buyer, daftar SO, dua kotak center | `DPRODST` |
| `hist` | `MSEG` → segmen hijau "sudah lewat" | `DPRODHI` |
| `ops` | AFKO→AFVC→AFVV→AFRU → kartu OPERASI SELESAI | `DPRODOP` |
| `komp` | ringkasan komponen untuk tabel Detail Komponen | `DPRODKPM`/`DPRODKPE` |
| `ops1` | seluruh tahap SATU komponen (saat baris dibentangkan) | tanpa cache |

`part=hist`, `komp`, `ops1` membaca daftar komponen dari SHARED BUFFER
`DPRODKM` yang ditulis `part=stock` — **harus dipanggil setelahnya**.
TTL 300 dtk, `?fresh=1` memaksa hitung ulang.

- **Sudah live:** BUYER, SALES ORDER, OPERASI SELESAI, DI PRODUKSI, filter
  buyer, dua kotak center (tiga warna), daftar SO, tabel Detail Komponen
- **Masih dummy:** kartu BOTTLENECK dan peta Work Center (`Math.random()`) —
  keduanya terhalang K5
- ⏸️ **Belum di-commit & belum pernah dijalankan di SE80** (per 2026-08-03):
  paket Perbaikan #1 — header bar biru, rename OPERASI SELESAI, sub-teks dua
  baris DI PRODUKSI, dan `done_real` untuk SELESAI PROD. Yang terakhir membawa
  SELECT baru yang **waktu jalannya belum pernah diukur**. Jangan menaikkan
  statusnya tanpa bukti dari sistem
- **Ikon:** Font Awesome CDN diganti 19 `symbol` SVG inline — CDN tidak
  terjangkau dari jaringan SAP
- **Tabel yang dibaca:** MSKA, MSEG, VBAK, KNA1, MAKT, AFKO⨝AFPO, AFVC, AFVV,
  AFRU, CRHD

### Definisi yang mudah disalahpahami

- ⚠️ **Detail Komponen sengaja TIDAK sebanding dengan dua kotak center.**
  Kotak center berbasis saldo stok (MSKA); tabel berbasis konfirmasi operasi
  (AFRU). Dua pertanyaan berbeda — jangan "diperbaiki" agar sama
- **CONFIRMED → OPERASI SELESAI** (2026-08-03). Definisi tetap operasi
  ter-konfirmasi; yang berubah labelnya, supaya tidak lagi mengklaim
  "komponen diterima" seperti maksud prototype. K6 ditutup begini
- **SELESAI PROD. didefinisi ulang** (2026-08-03, Opsi B/Tafsir X):
  `AFPO-WEMNG ≥ PSMNG` **dan** stok kosong di keenam SLoc → field `done_real`.
  Field lama `done` (proxy "stok ada di 229K") sengaja masih dikirim untuk
  pembanding; hapus hanya setelah PPIC memverifikasi angka baru
- **Kolom QTY ROUTING** diganti kolom **OPERASI** berisi `done/tot op` +
  work center aktif. K4 ditutup begini — rantai 3+ tahap memang tidak akan
  pernah muncul, konsekuensi temuan diagnostik bagian B

- **Menunggu Task 11:** rumus status operasi dialihkan memanggil
  `ZCL_CS_PEG=>op_status( )`. Rumus itu kini tersalin di **empat** tempat
  (`diag_routing.htm`, `routing_map.htm`, `dash_prod.htm` part=ops & part=komp)
- 📍 **Fase data punya roadmap sendiri:** `report/ROADMAP-index2-data.md`.
  **Baca itu dulu kalau melanjutkan di sesi baru**
- 🔴 **Satu-satunya penghambat tersisa — K5 "dasar perhitungan beban WC":**
  memblokir peta Work Center (tahap 4) dan kartu BOTTLENECK (tahap 6). K1–K4
  dan K6 sudah ditutup

### 🔴 Pelajaran 2026-08-03 — jangan diulang

Satu *syntax error* JavaScript (kutip tunggal di dalam string berkutip tunggal,
di `drawCenters()`) menggugurkan **seluruh blok `<script>`**, sehingga sejak
`2752c18` tidak ada satu pun panel `index2.htm` yang terisi. Tiga commit
berturut-turut diserahkan tanpa halaman pernah dibuka.

**Sejak sekarang `index2.htm` diuji lewat tiruan browser sebelum diserahkan:**
buang tag `<% %>`, timpa `window.kpiGet` dengan stub JSON palsu, sajikan lewat
`http://localhost`, dan periksa statis dengan `new Function(isiBlokScript)`.
Prosedur lengkapnya di `report/daily/2026-08-03.md` bagian 6.

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
