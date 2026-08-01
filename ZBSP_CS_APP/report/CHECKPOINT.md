# Checkpoint Rencana Pengembangan — ZBSP_CS_APP

Ringkasan status setiap jalur pengembangan aplikasi Central Storage.
Diperbarui: 2026-08-01 (setelah perubahan UI index2.htm & penataan folder)

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
| 4 | Dashboard Production | 🟡 Sebagian | `index2.htm` | UI diganti mengikuti `prototype/`, 2026-08-01 |
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

- **Berkas:** `index2.htm`
- **Sumbu utama:** **Buyer** (dulu SO)
- **Pusat produksi:** 2 center — Machining Center (40 WC) + Edge Banding &
  Sanding (20 WC). Dulu 3 section
- **Alur:** Storage → Machining → Edge Banding → Storage
- **Aturan cakupan (masih berlaku, disepakati 2026-07-30):** hanya SO yang
  punya **real stock** di Central Storage — `MSKA` WERKS 2000 / LGORT 2KCS /
  SOBKZ='E' / KALAB>0, sample customer `2000000004` dibuang. Free stock MARD
  tidak ikut. Satu "komponen" = COUNT DISTINCT (VBELN+POSNR+MATNR)
- **Sudah live:** kartu KOMPONEN, kartu CONFIRMED
- **Masih dummy:** kartu BUYER / DI PRODUKSI / SELESAI PROD. / BOTTLENECK,
  filter buyer, dua kotak center, peta work center, daftar SO/PLO, tabel
  Detail Komponen — dikirim ke JS sebagai array bertanda
  `DATA DUMMY UNTUK JS`; fase data cukup mengganti isinya
- **Sudah dihitung, belum dipakai layout:** `lv_op_act` (kandidat kartu DI
  PRODUKSI), `lv_so_cnt` (kandidat label panel SO/PLO). Menunggu fase data
  memastikan definisinya cocok
- **Ikon:** Font Awesome CDN diganti 19 `symbol` SVG inline — CDN tidak
  terjangkau dari jaringan SAP
- ⚠️ **Beda definisi yang belum beres:** prototype menulis CONFIRMED =
  "basis komponen diterima"; angka kita berbasis **operasi** ter-konfirmasi
  (AFRU). Sub-teks kartu sengaja menyebut "op" agar tidak mengklaim
  berlebihan
- **Utang:** kolom QTY ROUTING tidak akan pernah menampilkan 3+ tahap —
  konsekuensi langsung temuan diagnostik bagian B
- **Menunggu Task 11:** rumus status operasi dialihkan memanggil
  `ZCL_CS_PEG=>op_status( )`

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

**Urutan aktivasi di SAP:** class dulu, baru halaman. `ZCL_CS_UTIL` dan
(nanti) `ZCL_CS_PEG` harus aktif di SE24 sebelum halaman BSP yang
memanggilnya diaktifkan.
