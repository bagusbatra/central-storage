# Update & Rencana Pengembangan — Central Storage Production Dashboard

---

## A. Bug / Isu Teknis

| # | Lokasi | Deskripsi | Prioritas |
|---|--------|-----------|-----------|
| 1 | `index.htm:225` | `lv_weekday = ( ls_vbak-erdat - '20240101' ) MOD 7` — Bergantung pada referensi tanggal 2024-01-01 (Monday). Untuk data sebelum 2024, hasil pengurangan negatif dan perilaku MOD di ABAP tidak terdefinisi. Ganti dengan fungsi weekday SAP bawaan. | Tinggi |
| 2 | `index.htm:225` | Agregasi mingguan menggunakan `(erdat - ref_date) MOD 7` untuk menghitung hari dalam sepekan. Untuk data dengan rentang >1 tahun, offset tetap benar secara matematis, tetapi pendekatan ini rentan dan tidak portable. Gunakan `FUNCTION `DATE_GET_WEEK`` atau `sy-datum` sebagai referensi dinamis. | Sedang |
| 3 | `monitoring.htm:109-113` | Query menggunakan `SELECT * FROM vbak` dengan RANGES `lr_vbeln` dan `lr_kunnr`. Jika kedua RANGES kosong (user isi tanggal saja tanpa SO/Customer), empty RANGES `IN` di Open SQL bisa mengembalikan semua record (tidak memfilter). Perilaku ini tergantung versi SAP — perlu dikonfirmasi dan ditangani eksplisit. | Sedang |
| 4 | `monitoring.htm:119-122` | `SELECT * FROM vbap` — inkonsisten dengan index.htm yang menggunakan SELECT kolom spesifik. | Rendah |
| 5 | `monitoring.htm:126-129` | `SELECT * FROM afpo` — inkonsisten dengan index.htm. | Rendah |
| 6 | `index.htm:837` | Canvas chart tidak *responsive*. Ukuran canvas di-set sekali saat `window.onload`; jika window di-resize, chart tidak menyesuaikan. | Rendah |
| 7 | `main.htm` | Autentikasi hanya memeriksa `sy-uname`. Tidak ada pengecekan otorisasi (SU53/PFCG). Jika user SAP valid tetapi tidak berhak, tetap bisa mengakses. | Sedang |

---

## B. Fitur yang Belum Ada

### B.1 Dashboard

| Fitur | Keterangan | Prioritas |
|-------|-----------|-----------|
| **Grafik trend harian/bulanan** | Hanya ada bar chart mingguan. Belum ada line chart untuk melihat tren harian atau bulanan. | Sedang |
| **Tooltip pada chart** | Bar chart canvas murni tanpa tooltip. Saat hover bar, user tidak bisa melihat angka detail tanpa klik. | Rendah |
| **Export data** (Excel/PDF) | Tidak ada tombol export untuk tabel SO, item, atau BOM. | Sedang |
| **Filter User Preference** | Setiap reload, filter period kembali ke default 30 hari. Tidak ada persistensi (misal via SAP user parameter). | Rendah |
| **KPI Tambahan** | Hanya completion rate. Belum ada: *on-time delivery rate*, *average production lead time*, *item backlog*. | Rendah |

### B.2 Monitoring

| Fitur | Keterangan | Prioritas |
|-------|-----------|-----------|
| **Wildcard / partial search** | Filter SO dan Customer hanya exact match (EQ). Tidak bisa mencari dengan pola (pattern search / CP). | Sedang |
| **Nama Customer** | Hanya menampilkan kode customer (KUNNR). Tidak mengambil nama dari tabel KNA1. | Sedang |
| **Status produksi header SO** | Sidebar hanya menampilkan jumlah item, belum ada ringkasan status progres per SO. | Rendah |
| **Loading skeleton** | monitoring.htm tidak memiliki skeleton loading seperti index.htm. | Rendah |
| **Pagination state di URL** | Pagination SO di-reset setiap reload. Tidak ada state di URL parameter. | Rendah |

### B.3 Umum

| Fitur | Keterangan | Prioritas |
|-------|-----------|-----------|
| **Multi-Plant** | Plant 2000 hardcoded di semua query (`werks = '2000'`). Aplikasi tidak bisa digunakan untuk plant lain tanpa modifikasi kode. | Tinggi |
| **Role-based access** | Tidak ada pembedaan role (viewer, supervisor, admin). | Sedang |
| **Dark mode** | Hanya tema terang. | Rendah |
| **Responsive layout** | Layout menggunakan `display: table` — tidak responsif di mobile/tablet. | Rendah |

---

## C. Perbaikan Kinerja

| # | Lokasi | Issue | Saran | Prioritas |
|---|--------|-------|-------|-----------|
| 1 | `monitoring.htm:119,126,160,166,172` | Menggunakan `SELECT *` untuk semua tabel (VBAP, AFPO, MAST, STPO, MAKT). | Ubah ke SELECT kolom spesifik seperti index.htm. | Tinggi |
| 2 | `index.htm:97-101` | Query `lt_recent` menggunakan subquery `IN (SELECT...)` untuk verifikasi Plant 2000. Untuk dataset besar, subquery bisa lambat. | Alternatif: gunakan `FOR ALL ENTRIES` + pruning seperti query utama. | Rendah |
| 3 | `monitoring.htm:461-466` | `getElementsByTagName('div')` mengiterasi SEMUA div di DOM. Tidak efisien. | Gunakan `document.querySelectorAll('[data-type="so-card"]')`. | Rendah |
| 4 | Seluruh halaman | Tidak ada caching. Setiap request memicu query ke database SAP. | Implementasikan ABAP buffer / shared memory untuk data agregat yang jarang berubah. | Rendah |

---

## D. Code Quality & Maintainability

| # | Lokasi | Issue | Saran |
|---|--------|-------|-------|
| 1 | `index.htm`, `monitoring.htm` | CSS embedded langsung di HTML. | Pisahkan ke file CSS eksternal. |
| 2 | `index.htm`, `monitoring.htm` | JavaScript embedded langsung di HTML. | Pisahkan ke file JS eksternal. |
| 3 | `index.htm`, `monitoring.htm` | Plant 2000 hardcoded di banyak tempat. | Buat konstanta atau parameter BSP di awal halaman. |
| 4 | `index.htm` | Format JSON arrays manual via CONCATENATE. Rawan error delimiter/quote. | Gunakan class transformasi ABAP (cl_trex_json_serializer) atau method `/UI2/CL_JSON=>SERIALIZE`. |
| 5 | `index.htm:225` | `'20240101'` hardcoded. | Jadikan parameter aplikasi atau gunakan perhitungan dinamis. |
| 6 | `monitoring.htm:300-304` | `LOOP AT lt_local_item WHERE vbeln = ...` di dalam LOOP AT lt_local_hdr — nested loop tidak efisien. | Pre-process: SORT lt_local_item BY vbeln + READ BINARY SEARCH. |
| 7 | Kedua halaman | Tidak ada komentar pada JavaScript frontend. | Tambahkan komentar minimal untuk fungsi utama. |
| 8 | `README.md` | Tidak ada informasi tentang persyaratan sistem SAP (min release, OSS notes, dll). | Tambahkan prerequisite. |

---

## E. Saran Fitur Baru (Jangka Panjang)

| Fitur | Deskripsi | Estimasi Dampak |
|-------|-----------|----------------|
| **Dashboard per Shift** | Menampilkan breakdown produksi per shift (pagi/siang/malam) dengan filter shift. | Sedang |
| **QR Code / Barcode** | Scan SO atau material via barcode scanner untuk快速 lookup. | Sedang |
| **Integration dengan EWM/PP** | Ambil data dari tabel produksi lain (AFKO, AFRU, MSEG) untuk akurasi progress real-time. | Besar |
| **Grafik Perbandingan** | Bandingkan periode saat ini vs periode sebelumnya (month-over-month, year-over-year). | Sedang |
| **User Activity Log** | Catat siapa mengakses dashboard dan kapan. | Rendah |
| **Dashboard Export Gambar** | Export grafik dashboard sebagai PNG. | Rendah |

---

## F. Prioritas Pelaksanaan

### Fase 1 — Critical (Bug Fix)
1. Perbaiki agregasi mingguan (`index.htm:225`) — ganti `'20240101'` dengan referensi dinamis atau fungsi SAP.
2. Tambah validasi RANGES kosong di monitoring.htm (pastikan filter bekerja dengan benar).
3. Tambah pengecekan otorisasi user di main.htm.

### Fase 2 — High (Fitur Missing)
1. Support multi-plant (parameter BSP untuk plant code).
2. Export Excel/PDF untuk tabel.
3. Auto-refresh dashboard (interval timer).
4. Tampilkan nama customer dari KNA1.

### Fase 3 — Medium (Performance)
1. Ubah `SELECT *` jadi SELECT kolom spesifik di monitoring.htm.
2. Optimasi nested loop di monitoring.htm (SORT + BINARY SEARCH).
3. Responsive chart canvas (redraw on resize).

### Fase 4 — Low (Code Quality)
1. Pisahkan CSS/JS ke file eksternal.
2. Gunakan JSON serializer daripada CONCATENATE manual.
3. Tambah print-friendly CSS.
4. Dark mode.

---

## G. Optimasi Performa & UX Lanjutan

### G.1 Arsitektur Query & Database

| # | Issue | Dampak | Solusi |
|---|-------|--------|--------|
| 1 | **`DELETE lt_vbak` di dalam LOOP** — `index.htm:126-132`. Setiap DELETE menggeser indeks internal tabel. Untuk 1000+ SO, overhead akumulasi signifikan. | Sedang | Gunakan pendekatan *flag-based*: tambah field `lv_pruned`, set flag, lalu `DELETE lt_vbak WHERE flag = 'X'` di luar LOOP. |
| 2 | **Nested LOOP untuk hitung item per SO** — `monitoring.htm:300-304`. `LOOP AT lt_local_item WHERE vbeln = ...` dijalankan untuk setiap header SO. Kompleksitas O(n×m). | Tinggi | Pre-komputasi: `lt_item_count` via LOOP tunggal `lt_local_item`, akumulasi count per vbeln, kemudian READ TABLE. |
| 3 | **FOR ALL ENTRIES tanpa deduplikasi** — Monitoring.htm query MAKT (`idnrk`). Jika source table memiliki banyak duplikat `idnrk`, query jadi *bloated* dan berpotensi *short dump* karena batas 9999 baris per batch. | Tinggi | Gunakan `DELETE ADJACENT DUPLICATES FROM` sebelum `FOR ALL ENTRIES`. |
| 4 | **SELECT * vs SELECT kolom** — Masih ada beberapa `SELECT *` di monitoring.htm. Transfer data semua kolom dari DB ke application server memboroskan memory dan network. | Tinggi | Ganti semua `SELECT *` dengan daftar kolom eksplisit. |
| 5 | **Subquery di VBAK untuk filter Plant** — `index.htm:101` dan `monitoring.htm:113`. Subquery `IN(SELECT ...)` seringkali kurang optimal dibanding `FOR ALL ENTRIES` oleh optimizer SAP. | Rendah | Konsisten gunakan `FOR ALL ENTRIES` + pruning pattern seperti di index.htm. |
| 6 | **Tidak ada query hint / index hint** — Query tidak memanfaatkan index spesifik. Untuk tabel VBAK/VBAP yang besar (>1 juta record), *full table scan* bisa terjadi. | Sedang | Analisis ST05, tambah *database hint* jika diperlukan (misal `%_HINTS ORACLE 'INDEX(...)'`). |
| 7 | **AFPO query tanpa filter status produksi** — `index.htm:139-145` mengambil semua AFPO tanpa filter status (CRTD, REL, CNF, DLVR, TECO). Data produksi yang sudah *closed* tetap ditarik. | Rendah | Tambah filter `afpo-status` di mana relevan untuk mengurangi volume data. |

### G.2 ABAP Processing

| # | Issue | Dampak | Solusi |
|---|-------|--------|--------|
| 8 | **CONCATENATE manual untuk JSON** — `index.htm:268-290`. String concatenation di LOOP untuk setiap minggu. Untuk 52 minggu, ini 5×52 = 260 operasi CONCATENATE. | Rendah | Gunakan class `cl_trex_json_serializer` atau `cl_bcs_json` (SAP 7.40+). Lebih cepat dan aman dari *delimiter injection*. |
| 9 | **Konversi tanggal berulang** — Format DD/MM/YYYY via `CONCATENATE` dengan offset `+6(2)/+4(2)/+0(4)` diulang di 3 tempat (index.htm:191,597; monitoring.htm:305). | Rendah | Buat FORM/METHOD `format_date` reusable. |
| 10 | **Variabel p DECIMALS berlebihan** — Banyak variabel `p LENGTH 8 DECIMALS 2` yang hanya dipakai untuk perhitungan sementara. Tipe p dengan decimals tinggi boros CPU. | Rendah | Gunakan tipe integer untuk counter, `p DECIMALS 2` hanya untuk rate/prosentase akhir. |
| 11 | **lt_so_prog di-sort 2×** — `index.htm:223` (SORT BY vbeln) dan `index.htm:538` (SORT BY rate ASCENDING). Bisa digabung jadi 1 sort dengan secondary key. | Rendah | Gunakan `SORT lt_so_prog BY rate ASCENDING vbeln ASCENDING`. |

### G.3 Frontend & Rendering

| # | Issue | Dampak | Solusi |
|---|-------|--------|--------|
| 12 | **Semua SO di-render server-side, disembunyikan via CSS** — `monitoring.htm:296-315`. 100 SO → 100 div di-render, padahal hanya 5 yang tampil. DOM *bloated*. | Sedang | Render hanya 5 per halaman di server, kirim AJAX request saat ganti halaman (lazy pagination). |
| 13 | **Canvas chart blocking main thread** — `index.htm:669-814`. Drawing chart via Canvas API di `window.onload` memblokir interaksi user hingga selesai. | Sedang | Gunakan `requestAnimationFrame` + `setTimeout(0)` untuk *deferred rendering*. Atau pindah ke `Chart.js` / `D3.js` yang sudah *async-friendly*. |
| 14 | **Full page reload setiap filter** — Setiap klik "7/30/90 Hari" atau "Cari" melakukan POST → full page reload. | Tinggi | Implementasikan **AJAX partial refresh** (SAP BSP + XML/JSON response + JS update DOM). Filter period dan search jadi *instant*. |
| 15 | **Formulir monitoring tidak ada validasi HTML5** — Input tanggal bisa diisi asal, tidak ada `required`, `min`, `max`. Jika user isi format salah, page error. | Sedang | Tambah `type="date"`, `required`, `min`/`max` pada field. Validasi client-side + server-side. |
| 16 | **Parameter filter tidak tercermin di URL** — Setelah search, user tidak bisa *bookmark* atau *share* hasil filter. | Rendah | Update `history.replaceState`/`pushState` dengan parameter filter di URL. |
| 17 | **Tidak ada timestamp data** — User tidak tahu kapan data terakhir di-refresh (tanggal query dieksekusi). | Rendah | Tambah informasi `"Data per: DD/MM/YYYY HH:MM"` di footer atau header. |
| 18 | **Skeleton loading hanya di dashboard** — monitoring.htm tidak punya skeleton. | Sedang | Terapkan skeleton untuk sidebar SO list dan panel detail. |
| 19 | **Chart bar tidak ada tooltip** — User harus klik bar untuk melihat detail. Tidak bisa hover untuk lihat angka. | Rendah | Implementasikan *canvas hover detection* untuk tooltip, atau migrasi ke library chart yang sudah mendukung. |
| 20 | **Table columns tidak sortable** — User tidak bisa sortir kolom (misal klik header "Rate" untuk sort ASC/DESC). | Rendah | Tambah JS click handler pada header tabel untuk *client-side sorting*. |

### G.4 Jaringan & Infrastructure

| # | Issue | Dampak | Solusi |
|---|-------|--------|--------|
| 21 | **Tidak ada compression untuk response HTML** — BSP page output bisa >200KB untuk banyak data. | Rendah | Aktifkan HTTP compression (gzip) di level ICM / SICF. |
| 22 | **No CDN / cache for static assets** — Logo dan background via MIME repository. Setiap load halaman di-download ulang. | Rendah | Set HTTP cache headers untuk MIME assets (Expires / Cache-Control). |
| 23 | **Data tidak di-cache di layer ABAP** — Setiap request user → query DB → response. Data agregat (total SO, rate) sama untuk semua user. | Tinggi | Implementasikan **shared memory** (CL_SHM_AREA) atau **buffer internal** (EXPORT/IMPORT TO SHARED MEMORY) untuk data KPI yang berubah lambat. Refresh buffer setiap N menit. |
| 24 | **Parallel data fetching tidak dimanfaatkan** — Query recent (index.htm:97) dan query utama (index.htm:107) independen, bisa dijalankan paralel. ABAP tidak mendukung *async query*, tetapi bisa via RFC parallel task. | Rendah | Pisahkan block query ke RFC function module dan panggil parallel via `CALL FUNCTION... STARTING NEW TASK`. |

### G.5 UX Flow Improvements

| # | Saran UX | Detail |
|---|----------|--------|
| 25 | **Redirect setelah search** | monitoring.htm saat ini menggunakan POST → prevent re-submit dialog. Ubah ke GET + redirect agar URL bisa di-bookmark. |
| 26 | **Date shortcut buttons** | Tambah tombol "Bulan Ini", "Minggu Ini", "Tahun Ini" di monitoring, seperti filter period di dashboard. |
| 27 | **Double-click protection** | Form submit tidak dicegah dari double-click. User bisa double-klik "CARI" → query duplikat. | 
| 28 | **Loading spinner on search** | Tidak ada feedback visual saat search berlangsung. Tambah spinner overlay dengan timeout. |
| 29 | **BOM row animation** | Expand BOM sudah ada animasi fadeIn, tapi collapse instant. Konsistenkan animasi. |
| 30 | **Keyboard shortcut** | Tekan Enter untuk search, Escape untuk reset filter, shortcut 1/2/3 untuk period filter. |
