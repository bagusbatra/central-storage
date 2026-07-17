# Dokumentasi Fitur & Elemen UI — ZBSP_CS_APP (Central Storage Dashboard, Plant 2000)

Dokumen ini menjelaskan **secara rinci fitur setiap elemen di setiap halaman**: apa fungsinya, bagaimana perilakunya saat diklik/hover/keyboard, dan fungsi JavaScript (`MIMEs/js/js.js`) yang menggerakkannya. Untuk sumber datanya lihat `DOKUMENTASI-SUMBER-DATA.md`.

---

## A. Elemen Bersama (muncul di banyak halaman)

### A.1 Header Bar (`.header-bar`)
Tampil di: index, monitoring, riwayat, transfer.
| Elemen | Fitur |
|---|---|
| Judul + subjudul | Nama aplikasi "Central Storage Production Dashboard" + deskripsi konteks halaman (statistik / monitoring / riwayat / transfer) |
| **User dropdown** (`.header-user`) | Menampilkan `User SAP: <sy-uname>`. Klik → `toggleUserDropdown(e)` membuka/menutup menu (`#user-dropdown`, class `open`). Klik di luar → `closeUserDropdown()` menutup otomatis. `Esc` juga menutup (via `handleGlobalKeydown`) |
| Menu **Logout** | `userLogout()` → redirect ke `index.htm?~logoff` (mekanisme logoff standar BSP) |

### A.2 Navbar (`.navbar`)
Tautan: **Dashboard** (`index.htm`), **Monitoring** (`monitoring.htm`), **Riwayat** (`riwayat.htm`). Halaman aktif diberi class `active`.
- Menu **Transfer disembunyikan** dari navbar (keputusan D25) — `transfer.htm` masih bisa diakses via URL langsung dan tetap menampilkan tab Transfer aktif di navbar-nya sendiri.
- `diag_movement.htm` dan `maintenance.htm` sengaja tidak pernah ditautkan.

### A.3 Tombol Info "i" (`.info-btn`)
Tampil di kartu statistik & judul chart index.htm.
- Klik → `toggleInfo(btn, ev)`: membuat popover `.info-pop` berisi teks dari atribut `data-info`, diposisikan di bawah tombol, di-clamp agar tidak keluar layar (lebar 260px).
- Klik tombol yang sama lagi → menutup (toggle). Klik di luar → `closeInfoOnOutside`. `Esc` → `closeInfoPop()`.

### A.4 Format Angka Otomatis (B6)
- `formatNumbers(root)` dijalankan saat init dan setiap kali fragmen AJAX dirender.
- Elemen ber-class `.cur-fmt` (uang) → `toLocaleString('id-ID')` maks 2 desimal; `.num-fmt` (kuantitas) → maks 3 desimal.
- Atribut `data-fmt="1"` mencegah format ganda.

### A.5 Anti Double-Submit (B7)
`lockAllForms()`: setiap `<form>` diberi listener submit yang **menonaktifkan semua tombol submit** (opacity 0.6) sesaat setelah submit (di-`setTimeout(0)` agar `value` tombol tetap terkirim).

### A.6 Aksesibilitas Keyboard (B9)
- `enhanceA11y(root)`: semua baris klik-able (`.so-item-row`, `.clickable-item-row`, `tr[onclick]`) diberi `tabindex="0"` + `role="button"` → bisa difokus dengan Tab.
- `handleGlobalKeydown`: **Enter/Space** pada elemen `role=button` memicu `click()`; **Esc** menutup tooltip material, popover info, dan user dropdown.

### A.7 Footer Halaman (`.page-footer`)
`Data per: <tanggal> <jam> WIB • User: <uname> • Plant: 2000` — stempel waktu render server, bukan waktu klien. Di transfer.htm ditambah indikator `snapshot cache (≤ 600 dtk)` bila data dari cache.

### A.8 Entry Point JS
`initPage()` dipanggil pada `DOMContentLoaded` (PERF #6, bukan `window.onload`). Ia mendeteksi jenis halaman:
- Ada `#so-list-viewport` → mode **halaman list** (monitoring/riwayat): inisialisasi paginasi sidebar.
- Tidak ada → mode **index**: gambar chart, lepas skeleton (`body.page-loading` dihapus), pasang listener resize/hover/klik chart.

---

## B. `index.htm` — Dashboard Statistik & Grafik

### B.1 Filter Periode (baris tombol)
- 5 tombol submit: **7 Hari / 30 Hari / 60 Hari / 90 Hari / 1 Tahun** — masing-masing `name="period"` dengan value berbeda; form GET `action="index.htm"`.
- Tombol periode aktif diberi class `active` (dihitung server: `lv_cls7`…`lv_cls365`).
- Hidden input `cust_search` ikut disertakan → **pencarian customer tidak hilang** saat ganti periode.

### B.2 Filter Rentang Tanggal
- Dua `<input type="date">` (`date_from`, `date_to`) + tombol **Terapkan Rentang**.
- Bila keduanya terisi valid (10 karakter), rentang **menang atas tombol periode**; bila terbalik, server menukar otomatis.
- Teks ringkasan: "Menampilkan data **<label periode>** • grafik per **<granularitas>**" — granularitas otomatis (Hari/Minggu/2 Minggu/3 Minggu/Bulan) dari lebar rentang.

### B.3 Kartu Statistik (6 kartu, `.stat-card`)
| Kartu | Makna angka | Info-btn menjelaskan |
|---|---|---|
| **Total Sales Order** | SO Plant 2000 dgn ≥1 item ber-order bertahap; customer Sample dikecualikan | definisi scope MRP |
| **Total Item Produksi** | Item dgn ≥1 order Produksi/Ready Assy (GA1/GA2/EB2/CH1); item cuma-Pembahanan tidak dihitung | |
| **Proses Pembahanan** | Item yang tahap terjauhnya masih Pembahanan (belum masuk Produksi) | MRP WM1/WM2/PN1/PN2, Plant 1000 |
| **Proses Produksi** | Item sudah Produksi (GA1/GA2), belum ada order Ready Assy | |
| **Ready Assy** | Komponen sudah tahap Finish (EB2/CH1), siap rakit, tapi order utamanya belum tuntas | |
| **Selesai** | Order utama Delivered = Target — benar-benar tuntas | |

### B.4 Bar Chart "Item Produksi per <granularitas>" (`#barChart`, canvas)
Digambar murni canvas 2D oleh `drawBarChart()` — tanpa library chart.
- **Stacked bar 4 warna** per bucket waktu, urutan bawah→atas: Pembahanan (abu `#d1d5db`) → Produksi (amber `#f59e0b`) → Ready Assy (biru `#3b82f6`) → Selesai (hijau `#10b981`). Segmen teratas diberi sudut membulat (`drawRoundTop`).
- **Badge total** (pil biru tua) di puncak tiap bar.
- **Sumbu Y**: 5 tick otomatis (`tickStep = ceil(max/5)`); label X: nama granularitas + label bucket (DD/MM atau MM/YYYY).
- **Hover**: `mousemove` mendeteksi bar di bawah kursor (koordinat diskalakan `canvas.width/rect.width`), kursor jadi pointer, dan **tooltip** digambar di atas bar: rentang tanggal bucket (dari `weekDatesEnd` yang **sudah di-clip server**, D28) + rincian Total/Selesai/Ready Assy/Produksi/Pembahanan dengan warna teks selaras serinya. `mouseout` mereset.
- **Klik bar = drill-down**: `drillDown(idx)` → navigasi `monitoring.htm?date_from=…&date_to=…&search_btn=X` memakai tanggal awal & akhir bucket persis seperti yang dihitung chart (fallback `bucketEndDate()` hanya bila `weekDatesEnd` tidak ada). Hint di bawah chart: "💡 Klik bar untuk melihat detail SO…".
- **Responsif**: lebar canvas dihitung ulang dari parent tiap render; `resize` window memicu gambar ulang dengan `debounce(200ms)` anti-flicker.
- **Kosong**: bila tidak ada bucket, tampil teks "Belum ada data untuk ditampilkan".
- **Skeleton loading** (`.chart-skel`) tampil sampai `body.page-loading` dilepas oleh `initPage()`.

### B.5 Donut Chart "Tahap Produksi Item" (`#donutChart`)
`drawDonutChart()`:
- 4 segmen searah jarum jam dari jam 12, urutan Selesai → Ready Assy → Produksi → Pembahanan (hijau selalu mulai di atas).
- **Lubang tengah** menampilkan `% selesai` (bulat) + kata "selesai".
- Total 0 → lingkaran abu + "Tidak ada data". Responsif (cap 220px). Legend di bawah menampilkan angka absolut tiap tahap.

### B.6 Pencarian & Kotak Customer
- Input `cust_search` + tombol **Cari** (form GET terpisah yang **membawa filter periode/rentang aktif** lewat hidden input — state tidak hilang).
- Tombol **✕ Reset** hanya muncul bila sedang ada kata kunci.
- Hasil: kartu `.cust-box` per customer (kode, nama, jumlah SO). **Klik kartu → `monitoring.htm?cust_num=<kunnr>&search_btn=X`** (langsung memfilter Monitoring ke customer itu).
- Tanpa pencarian: hanya **6 customer teratas** (terbanyak SO) + catatan "Menampilkan 6 dari N…". Pencarian menampilkan semua yang cocok + hitungan hasil; pesan khusus bila kosong.

### B.7 Injeksi Data ABAP→JS
Blok `<script>` inline mendefinisikan `weekLabels/weekDates/weekDatesEnd/chartGran/chartGranLabel` + 4 array seri + 4 skalar donut, lalu memuat `js/js.js?r=9` (query `?r=` = cache-busting versi).

---

## C. `main.htm` — Gerbang Autentikasi

Tanpa UI. Bila `sy-uname` kosong → `navigation->vhost_authentication()`. Berfungsi sebagai halaman start yang memastikan sesi ter-autentikasi.

---

## D. `monitoring.htm` — Monitoring Progres Produksi

### D.1 Form Filter (`.filter-card`)
Form GET `action="monitoring.htm"` (action **wajib eksplisit** — bug form action kosong pernah membuat filter mengembalikan semua data):
| Field | Fitur |
|---|---|
| **Nomor Sales Order** | Menerima nomor penuh atau **sebagian** (substring); zero-padding otomatis |
| **Nomor Item** (D24) | `10` otomatis dicocokkan dgn `000010`; substring juga didukung |
| **Kode Customer** | Exact + substring |
| **Nama Customer** | Pencarian nama via KNA1-MCOD1 (case-insensitive); diabaikan bila Kode Customer terisi |
| **Dari/Sampai Tanggal** | Batas tanggal buat SO; default 30 hari; **otomatis tanpa batas** bila mencari by nomor SO/Item tanpa tanggal |
| **CARI DATA** | Submit; tombol ter-disable setelah klik (anti double-submit) |

### D.2 Sidebar — Daftar Sales Order (`.sidebar-panel`)
- Header: "Daftar Sales Order (N Dokumen)".
- **Kartu SO** (`.so-item-row`, `data-type="so-card"`): nomor SO, badge jumlah item, nama customer, **label status berwarna** (Selesai hijau / Ready Assy biru / Produksi kuning / Pembahanan abu — juga mewarnai border kiri via class `so-bl-*`), tanggal + tipe dokumen.
- **Klik kartu → `viewDetails(vbeln)`**: kartu aktif di-highlight (class `active`), panel kanan dimuat AJAX.
- **Empty state** dua varian: belum mencari ("Mulai Pencarian" + instruksi) dan hasil kosong (pesan spesifik per jenis filter yang gagal: SO/item/nama/kode customer + saran + tombol **Reset Filter**).
- **Paginasi klien**: `#so-list-viewport` `data-page-size="10"` → 10 kartu per halaman. Tombol **« Prev / Next »** (`changePage(±1)`), indikator "x / y". Halaman aktif disimpan di **URL hash `#page=N`** (`history.replaceState`) sehingga bertahan saat back/forward; dibaca ulang oleh `getPageFromHash()`.

### D.3 Panel Utama (`#main-panel-container`)
- Awal: placeholder "Belum Ada Dokumen Terpilih".
- `viewDetails(vbeln)`:
  1. Sajikan dari **cache klien** `soDetailCache[vbeln]` bila pernah dimuat (instan).
  2. Bila belum: tampilkan **skeleton loading** (judul + baris tabel abu), lalu XHR GET `monitoring_detail.htm?vbeln=…`.
  3. Sukses → render + `formatNumbers` + `enhanceA11y` + **jadwalkan prefetch BOM**; gagal → pesan error HTTP/koneksi merah.
- **Prefetch idle (perf)**: `schedulePrefetchBOM(vbeln)` menunggu 400ms; bila SO masih aktif (pengguna tidak lanjut menelusuri), `fetchBOM()` mengambil fragmen Item & BOM **di latar belakang** dan menyimpannya di `soBomCache` — klik tab jadi (nyaris) instan. Deduplikasi request via `bomInflight`.

### D.4 Isi Panel Detail (dari `monitoring_detail.htm`)
- **Header**: "SO #… — Nama Customer".
- **Tab-nav** 3 tab (`switchTab`):
  1. **▣ Ringkasan** (default, langsung terisi)
  2. **☰ Item & BOM** (lazy)
  3. **🚚 Butuh Dikirim** (lazy)

#### Tab Ringkasan
- **Info Order** (grid label-nilai): Nomor SO, Tanggal Dibuat, Tipe Dokumen, Kode & Nama Customer, Kota (bila ada), Nilai SO (bila >0, terformat uang), **badge Status SO** berwarna (ladder sama dgn kartu sidebar; ekstra "Di Luar Scope" abu bila tak ada item lolos scope).
- **Ringkasan Status**: 5 kartu KPI — Total Item, Pembahanan, Produksi, Ready Assy, Selesai (kartu Selesai bergaya khusus `sum-kpi-done`).

#### Tab Item & BOM / Tab Butuh Dikirim
Keduanya dimuat lazy saat tab pertama kali diklik (`loadBOM`/`loadKirim`): tampilkan skeleton → tandai pane `data-awaiting` → XHR `monitoring_bom.htm?vbeln=…` (+`&mode=kirim` utk Butuh Dikirim) → cache terpisah (`soBomCache` / `soKirimCache`) → render. Setelah dimuat (`data-loaded=1`) pindah-pindah tab instan. Fitur isi tab dijelaskan di bagian E.

---

## E. Fragmen `monitoring_bom.htm` — Isi Tab Item & BOM / Butuh Dikirim

Perbedaan kedua tab hanya **scope tahap**: Item & BOM = Produksi + Ready Assy (GA1/GA2/EB2/CH1); Butuh Dikirim = Pembahanan (WM1/WM2/PN1/PN2, Plant 1000) — ditandai judul biru khusus di mode kirim. Prefiks id `k-` mencegah tabrakan DOM karena kedua pane hidup bersamaan.

### E.1 Baris Kontrol BOM
- **+ Buka Semua BOM** → `expandAllBOM()`: semua baris BOM dibuka (animasi CSS `bom-open`), penanda `currentActiveBOMId='*'`.
- **− Tutup Semua BOM** → `collapseAllBOM()`: menutup semua dengan delay 330ms (menunggu animasi collapse selesai sebelum `display:none`).

### E.2 Tabel Item (`.data-table`)
- **Header kolom sortable** (`.sort-th`, `onclick="sortCol(this,'num'|'str')"`): klik pertama ascending, klik lagi descending; indikator class `sort-asc/sort-desc`; nilai diambil dari `data-val` (angka mentah) bila ada, fallback teks; string di-compare locale `'id'`. **Baris BOM expandable ikut pindah bersama baris induknya** (di-sort sebagai pasangan).
- Kolom: Item, Material #, Deskripsi Komponen, Qty SO, **Target** (tooltip `title` menjelaskan: AFPO-PSMNG order UTAMA), **Hasil GR** (AFPO-WEMNG order utama), **Progres** (GR/Target).
- **Badge "Line"** di kolom deskripsi: nama unit Wood Furniture (class `ln-wf`) atau "Unit lain"/"Belum ada operasi" (`ln-other`), dengan `title` tooltip yang membedakan penyebab (di luar whitelist / CRCO tidak valid / AFVC kosong) — untuk debugging.
- **Progress bar** per item: bar berwarna (kelas dari `prog_bar_class`) + persen; item tanpa order = teks miring "No Prod".
- **Badge status order** (Selesai Teknis/Dikonfirmasi/Diproses/Dibuat — dari JEST) + "Target: dd/mm/yyyy" (AFKO-GLTRP) di bawah progress bar.
- **Klik baris item → `toggleBOMRow(id)`**: membuka baris detail BOM di bawahnya; **hanya satu BOM terbuka pada satu waktu** (yang lama ditutup otomatis, kecuali sedang mode "buka semua").
- Item yang punya order utama tapi **tidak punya komponen di scope tab** ini disembunyikan seluruhnya (D9). Bila tak ada item sama sekali → pesan kosong yang menyebut scope tab.

### E.3 Daftar Komponen Order (expand, gaya COOIS)
- Judul sesuai tab. Kolom: **Tahap** (badge berwarna per stage + kode DISPO), Order, Material Komponen, Nama Material, Target Qty, Delivered Qty (tooltip menjelaskan AFPO-PSMNG/WEMNG per order), **Progres per order**.
- Komponen tampil **berurutan alur produksi** (Pembahanan → Produksi → Finish) berkat sort stage_rank.
- **Klik baris komponen → `toggleCompRow(id)`**: membuka **detail komponen**: System Status (badge JEST), Kuantitas (RESB-BDMNG), Basic Start/Finish Date, Actual Finish Date ("-" bila kosong).
- **Khusus tab Butuh Dikirim** — blok **"Status Pergerakan Material (GR/QC/Konsumsi/Kirim)"** per komponen:
  - Total Diterima (GR) di SLoc sumber;
  - 🟠 Sedang QC (Quality Inspection);
  - 🔵 Tersedia, belum dipakai/dikirim;
  - 🟣 Sudah Dikonsumsi — dirinci per order konsumen + tanggal terakhir;
  - 🟢 Sudah Dikirim — dirinci per SLoc/Plant tujuan + tanggal terakhir;
  - fallback "Belum ada Goods Receipt untuk komponen ini di MSEG".

### E.4 Fallback BOM Master (item tanpa order produksi)
- Tabel sederhana: Material Komponen, Nama, Kuantitas.
- **Kode material dapat diklik** (`.mat-link`, `showMatTooltip(this)`): membuka **tooltip material** berisi data yang sudah diembed sebagai `data-*` attributes (tanpa request tambahan): kode+nama, Dibutuhkan BOM, Stok tersedia + badge **✓ Cukup / ⚠ Kurang Stok** (stok≥kebutuhan), Open PO masuk + **ETA** (atau "Tidak ada").
  - Toggle: klik elemen sama = tutup; klik elemen lain = pindah; tombol ×, klik di luar, atau Esc = tutup. Posisi di bawah elemen, di-clamp ke viewport.
- Bila BOM tak terpasang: "BOM belum terpasang di Plant 2000."

---

## F. `riwayat.htm` — Arsip SO Selesai

### F.1 Form Filter
Sama dengan monitoring.htm **minus Nomor Item**. Perbedaan perilaku: tanggal **opsional tanpa default** — tanpa input, seluruh riwayat ditampilkan (header sidebar mencantumkan "Seluruh Riwayat (tanpa batas tanggal)" atau rentang aktif).

### F.2 Sidebar — Arsip SO
- Default hanya SO yang **semua item-nya Selesai tuntas**.
- **Kartu SO selesai** (border hijau `so-border-done`): nomor, badge item, customer, label "Selesai", tanggal+tipe, **Nilai SO** (terformat uang). Klik → `viewDetails()` membuka panel detail yang sama persis dengan Monitoring (Ringkasan/Item & BOM/Butuh Dikirim).
- **Kartu SO belum tuntas** — hanya muncul saat mencari by nomor SO (`lv_keep_incompl`): border/label "in-progress" dengan tahap dominan, baris ekstra "**x / y item tuntas — → Buka di Monitoring**", tooltip title, dan **klik mengarahkan ke `monitoring.htm?so_num=…`** (bukan membuka panel di sini) — Riwayat tetap "hanya untuk yang benar-benar tuntas".
- Empty state: "Tidak ada SO selesai" + saran + tombol Reset Filter (hanya bila ada filter aktif).
- Paginasi klien sama dengan Monitoring (default 5 kartu — viewport riwayat tidak menyetel `data-page-size`).

---

## G. `transfer.htm` — Transfer Material 1D00 → 2KCS *(tersembunyi dari navbar)*

### G.1 Form Filter
Material (substring), Nomor Sales Order, dropdown **Status** (Semua / Perlu Dikirim / Tercukupi), tombol TAMPILKAN. GET idempotent — bisa di-bookmark/reload tanpa dialog kirim ulang.

### G.2 Baris KPI
- **Perlu Dikirim: N material** (oranye), **Kurang stok 1D00: N** (merah), **Total material: N**, plus keterangan rute & scope: "Rute: 1000/1D00 → 2000/2KCS • Scope: Wood Furniture • Diterima 2KCS = seluruh histori (mvt 301/311)".

### G.3 Tabel Rekonsiliasi
Kolom: Material, Nama, **Butuh** (Σ sisa kebutuhan RESB), **Stok 2KCS**, **Perlu Kirim** (tebal oranye), Sat, **Stok 1D00**, **Diterima 2KCS** (header ber-`title` panjang menjelaskan definisi CP1; di bawah angka tampil "Dok <mblnr>" dokumen penerimaan terakhir), **Tgl Butuh**, **SO**, **Status**.
- **Link SO** → `monitoring.htm?so_num=…&search_btn=X` (lompat langsung ke Monitoring SO tersebut); "—" bila tidak ada.
- **Badge status** 3 warna: `Tercukupi` (tf-ok) / `Akan Dikirim` (tf-need) / `Kurang Stok 1D00` (tf-short — **seluruh baris diberi latar merah muda**).
- Urutan: Tgl Butuh terbaru di atas.
- Empty state membedakan dua sebab: "Tidak ada order produksi untuk SO tersebut" vs tidak ada material + catatan bahwa daftar hanya memuat komponen **Wood Furniture** (Chair/Metal/DRW memang tak tampil).

### G.4 Pagination Server-Side
50 baris/halaman. Bar bawah: "Menampilkan a–b dari N", tombol **‹ Sebelumnya / Berikutnya ›** sebagai **link GET `?page=N`** yang **mempertahankan filter aktif** (query-string `matnr/so_num/status` di-escape dan dilampirkan); tombol non-aktif dirender sebagai span abu.

### G.5 Cache Snapshot
Tampilan default (tanpa filter SO) dilayani dari snapshot INDX (TTL 600 detik) → load nyaris instan; footer menandai `• snapshot cache (≤ 600 dtk)` bila aktif.

---

## H. `diag_movement.htm` — Halaman Diagnostik (alat internal, sekali pakai)

Form input: Material (wajib utk section A/B/C, **opsional** utk B2/D/E), rentang tanggal (default 180 hari), hidden `go=1` — **query berat hanya jalan setelah form benar-benar disubmit**, membuka halaman saja tidak memicu scan MSEG.

| Section | Elemen & fitur |
|---|---|
| **A** | Tabel snapshot stok MARD per SLoc di Plant 1000 & 2000 (bandingkan 1D00 vs 2KCS…229K) |
| **B** | Ringkasan movement type: bwart, jumlah kejadian, contoh rute, SHKZG — untuk 1 material |
| **B2** | Frekuensi movement **per rute SLoc** (populasi, agregasi di DB): Dari SLoc → Ke SLoc, bwart, SHKZG, jumlah baris, total qty; **kode SLoc pipeline di-highlight**. Inilah tabel yang jadi dasar penguncian asumsi Checkpoint Engine |
| **C** | Daftar gerakan mentah: tanggal, dokumen, bwart, dari→ke, SHKZG, qty (sort terbaru dulu) |
| **C2** | Kamus nama SLoc (T001L) semua kode yang muncul di B2 |
| **D** | Ringkasan seperti B2 tapi **khusus Wood Furniture** (scope cost center); banner peringatan bila hasil terpotong cap 200.000 baris; legenda menjelaskan over-include material campuran (D = batas atas) |
| **E** | Analisis keterikatan MSEG ke Sales Order (30 hari): statistik baris ber-KDAUF / SOBKZ='E' / anonim + persentase, **angka penentu** = transfer 301/311 ber-KDAUF, **vonis otomatis berwarna** (hijau=bisa per-SO / merah=stok anonim / kuning=campuran atau data kurang) + 25 contoh baris ber-KDAUF |

---

## I. `maintenance.htm` — Halaman Pemeliharaan

Halaman mandiri (CSS & JS inline semua — tetap tampil walau MIME repository dimatikan).
| Elemen | Fitur |
|---|---|
| **Eyebrow + beacon** | Titik kuning berdenyut (animasi `pulse`) + label "Pemeliharaan Terjadwal · Plant 2000" |
| **Headline & lede** | Pesan tenang bahwa produksi & data SAP tidak terpengaruh |
| **Animasi konveyor** | Belt bergaris berjalan (`roll` 1.4s) + krat hitam melintas (`haul` 7s) + strip hazard kuning-hitam; **`prefers-reduced-motion` mematikan semua animasi** (krat diam di tengah) |
| **Readout** | Perkiraan Aktif (tanggal+jam target, dari konstanta ABAP), **Sisa Waktu** countdown, kontak bantuan |
| **Countdown JS** | Sisa detik dihitung server (`lv_secs`), lalu di-tick tiap detik di klien: format `d hari HH:MM:SS`; saat 0 → status "Selesai" + **auto-reload 1,5 detik** kemudian; bila target sudah lewat saat load, langsung state "coba muat ulang" |
| **Tombol "Muat ulang halaman"** | `window.location.reload()`; halaman juga ber-`Cache-Control: no-store` |
| **Footer** | Sistem SID, user, timestamp WIB |

---

## J. Ringkasan Alur Interaksi Antar-Halaman

```
index.htm ──klik bar chart──────────▶ monitoring.htm?date_from&date_to
index.htm ──klik kartu customer─────▶ monitoring.htm?cust_num
riwayat.htm ─klik SO belum tuntas──▶ monitoring.htm?so_num
transfer.htm ─klik link SO─────────▶ monitoring.htm?so_num

monitoring.htm / riwayat.htm
  └─ klik kartu SO ── XHR ─▶ monitoring_detail.htm?vbeln   (tab Ringkasan)
       ├─ prefetch idle 400ms / klik tab ─ XHR ─▶ monitoring_bom.htm?vbeln          (Item & BOM)
       └─ klik tab ────────────────────── XHR ─▶ monitoring_bom.htm?vbeln&mode=kirim (Butuh Dikirim)
```

Semua fragmen AJAX di-cache per `vbeln` di sisi klien selama halaman hidup (`soDetailCache`, `soBomCache`, `soKirimCache`) dengan deduplikasi request in-flight — menelusuri bolak-balik antar SO tidak memukul server dua kali.

---

*Dokumen dibuat 2026-07-17 berdasarkan pembacaan langsung seluruh source di `ZBSP_CS_APP/` (halaman BSP, `js/js.js`, `style.css`, `ZCL_CS_UTIL`).*
