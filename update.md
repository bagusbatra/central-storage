# Update & Pedoman Pengembangan — Central Storage Production Dashboard

> Dokumen ini ditulis ulang **29 Juni 2026** berdasarkan pembacaan menyeluruh seluruh kode terkini
> (`index.htm`, `monitoring.htm`, `monitoring_detail.htm`, `main.htm`, `js/js.js`, `css/style.css`).
> Banyak isu dari versi sebelumnya **sudah selesai** (lihat Bagian 1). Bagian A–H di bawah hanya memuat
> temuan yang **masih relevan** pada kode saat ini.

---

## 0. Pemahaman Sistem (ringkasan)

**Apa ini:** aplikasi **SAP BSP** (ABAP *Page with Flow Logic*) untuk memonitor progres produksi di **Central Storage KMI 2 — Plant 2000 Surabaya**. Render server-side dengan tag `<%= %>`, ditambah AJAX untuk panel detail.

**Tujuan:** memberi visibilitas real-time status produksi yang diturunkan dari Sales Order, membaca tabel SAP langsung tanpa database terpisah.

**Rantai data inti:**
`VBAK` (header SO) → `VBAP` (item, filter `werks='2000'`) → `AFPO` (`psmng`=target, `wemng`=hasil GR) → status item.
Drill BOM: `MAST` → `STPO` → `MAKT` (+ `MARD` stok, `EKPO` open PO, `AFKO` status order). Nama customer dari `KNA1`.

**Aturan status item:** AFPO ada & `psmng>0` → `pct = wemng/psmng*100`; `≥100` = **Selesai**, selain itu = **Proses**; tidak ada AFPO / `psmng=0` = **Belum Produksi**.

**Halaman & alur:**
| File | Peran |
|------|-------|
| `main.htm` | Flow Logic inisialisasi. Autentikasi = hanya cek `sy-uname` tidak kosong. |
| `index.htm` | Dashboard: KPI, bar mingguan (Canvas), donut, kotak customer (KNA1), 10 SO terbaru. Filter periode 7/30/90 via POST reload. |
| `monitoring.htm` | Pencarian (SO / kode cust / nama cust / rentang tanggal), sidebar daftar SO (paginasi 5/hal di sisi klien, **semua** baris dirender server-side), panel utama dimuat via AJAX. |
| `monitoring_detail.htm` | Fragmen HTML AJAX (`?vbeln=`). Tab **Ringkasan / Item & BOM / Info Order**, expand BOM, tooltip material (stok & PO). |
| `MIMEs/css/style.css`, `MIMEs/js/js.js` | Aset bersama (sudah dipisah dari HTML). Chart digambar manual via Canvas, tanpa library. |

Plant 2000 di-*hardcode* (`CONSTANTS lc_plant`) di setiap halaman.

---

## 1. Sudah Selesai Sejak Versi Sebelumnya ✅

Agar pedoman ini akurat, berikut item lama yang **kini sudah diimplementasikan** — jangan dikerjakan ulang:

- CSS & JS dipisah ke file eksternal (`style.css`, `js.js`).
- `SELECT *` diganti kolom spesifik di hampir semua query (sisa `SELECT SINGLE *` di detail — lihat D).
- AJAX partial refresh untuk panel detail (`monitoring_detail.htm` via `XMLHttpRequest`) + cache per-VBELN di sisi klien.
- Skeleton loading di panel detail.
- Nama customer dari KNA1 (sidebar, kotak customer, detail).
- Wildcard / partial search (opsi `CP`) untuk SO & kode customer; pencarian nama customer.
- KPI tambahan: On-Time Delivery, Lead Time, Backlog (catatan akurasi di A).
- Tooltip hover pada bar chart + drill-down klik bar.
- Canvas chart responsif (redraw saat resize, debounce).
- Header kolom tabel detail bisa di-sort (`sortCol`).
- Tab di panel detail; tooltip material (MARD stok + EKPO open PO).
- Timestamp "Data per: …" di footer.
- Paginasi sidebar dengan state di URL hash (`#page=N`).
- Optimasi hitung item per SO: `READ … BINARY SEARCH` + `LOOP FROM` (bukan nested loop penuh).
- Empty state pencarian dengan ilustrasi SVG.

---

## A. Bug Fungsional (prioritaskan)

> **STATUS — diperbaiki 29 Jun 2026 (A1–A8 sudah dikodekan).** Karena ini ABAP/BSP yang tidak bisa
> dikompilasi di luar SAP, **wajib uji aktivasi di SE80 + smoke test runtime (ST22)** sebelum rilis.
> Ringkasan perubahan ada di bawah tabel; baris tabel dipertahankan sebagai konteks bug awal.

| # | Lokasi | Deskripsi | Prioritas |
|---|--------|-----------|-----------|
| **A1** | `monitoring_detail.htm:201,208,221` | **Empty `FOR ALL ENTRIES`.** Query MAKT, MARD, EKPO dijalankan `FOR ALL ENTRIES IN lt_stpo_pre` **tanpa** `IF lt_stpo_pre IS NOT INITIAL`. MAST & STPO sudah dijaga, tetapi STPO→hilir tidak. Jika sebuah material punya MAST tapi STPO kosong (tidak ada komponen), `lt_stpo_pre` kosong → FAE dengan tabel driver kosong **mengembalikan SELURUH tabel** (full scan MAKT/MARD/EKPO). Potensi lambat parah / beban DB. | **Kritis** |
| **A2** | `monitoring_detail.htm:350-353` | **Status order AFKO salah field.** Kode memakai `AFKO-GSTRS` (tanggal *scheduled start*, tipe DATS) seakan teks status: `gstrs CS 'TECO' / 'CNF' / 'REL'`. Tidak akan pernah cocok → selalu jatuh ke ELSE = "Dibuat". Status sistem order ada di `JEST`/`JCDS` via `AUFK-OBJNR`. Gunakan FM `STATUS_TEXT_EDIT` (objnr = `'OR' && aufnr` atau dari AUFK) atau baca `JEST` (`stat`, `inact=''`). | **Tinggi** |
| **A3** | `index.htm:189-201,515-524` | **KPI "On-Time Delivery" menyesatkan.** Dihitung `on_time/total = done/(done+inprog)` **tanpa** membandingkan tanggal jatuh tempo apa pun. Itu bukan ketepatan waktu; nyaris menduplikasi *completion rate*. OTD sebenarnya butuh perbandingan tanggal target (mis. `AFKO-GLTRP`/`FTRMP`) vs tanggal GR aktual. Saat ini label "item tepat waktu" tidak benar. | **Tinggi** |
| **A4** | `index.htm:198,259-262` | **Lead time tidak akurat.** `lv_lead_days += ( sy-datum - ls_vbak-erdat )` mengukur **umur SO sampai hari ini**, bukan durasi SO-dibuat → selesai. SO yang selesai lama tetap menyumbang umur penuhnya. Butuh tanggal penyelesaian aktual (tanggal GR terakhir, mis. dari `MSEG`/`AFRU`/`MKPF`) untuk lead time yang benar. | **Tinggi** |
| **A5** | `monitoring.htm:121,135` | **Filter customer saling meniadakan.** Cabang kode customer hanya jalan jika `cust_name` kosong; cabang nama hanya jika `cust_num` kosong. Jika **keduanya** diisi, **tidak ada** filter customer yang ditambahkan → `lr_kunnr` kosong → query mengembalikan semua SO pada rentang tanggal (filter diam-diam diabaikan). Tetapkan prioritas eksplisit atau gabungkan. | Sedang |
| **A6** | `monitoring.htm:136-140` | **Pencarian nama case-sensitive.** `TRANSLATE lv_ui_name TO UPPER CASE` lalu `WHERE name1 LIKE '%...%'`. Pada DB case-sensitive, pola huruf besar tidak cocok dengan `KNA1-name1` yang campuran huruf. Gunakan pembandingan yang konsisten (`UPPER( name1 ) LIKE`, atau filter di aplikasi atas hasil, atau field pencarian `MCOD1`). | Sedang |
| **A7** | `monitoring_detail.htm:221-228,449` | **EKPO open-PO perlu verifikasi.** (a) `EKPO-EILDT` dipakai sebagai tanggal kirim — tanggal pengiriman standar ada di `EKET-EINDT`, bukan EKPO; pastikan field ini benar-benar ada/terisi di sistem Anda (kalau tidak, ETA selalu kosong / berisiko dump). (b) "Open PO" memakai `menge` penuh, bukan sisa belum-diterima (`menge − jumlah GR`). Pertimbangkan join `EKET`/`EKBE`. | Sedang |
| **A8** | `index.htm:277` | **Agregasi mingguan pakai epoch hardcode** `( erdat - '20240101' ) MOD 7`. `20240101` memang Senin sehingga hasil benar, dan `MOD` ABAP non-negatif untuk pembagi positif, jadi tidak rusak — tetapi rapuh & tidak portable. Ganti dengan FM hari (`DATE_COMPUTE_DAY` → `sy-fdayw`) atau `lv_week_mon = erdat - ( ( erdat - <senin_referensi> ) MOD 7 )` dengan referensi dinamis. | Rendah |

### Ringkasan perbaikan yang diterapkan (29 Jun 2026)

- **A1 ✅** `monitoring_detail.htm` — query MAKT/MARD/EKPO kini dibungkus `IF lt_stpo_pre IS NOT INITIAL`. Empty-FAE tidak lagi mungkin.
- **A2 ✅** Status order tidak lagi dari `AFKO-GSTRS`. Ditambah query `AUFK` (objnr) → `JEST` (status aktif, `inact=' '`), dipetakan prioritas CRTD/REL(I0002)/CNF(I0009)/TECO(I0045) → label & class. **Uji:** pastikan kode status internal sesuai customizing Anda (`I0002/I0009/I0045`).
- **A3 ✅ (relabel jujur)** Kartu "On-Time Delivery Rate" → **"Penyelesaian Order Produksi"** (= item selesai / item ber-order). Teks "tepat waktu" & alert OTD disesuaikan. OTD sejati (vs tanggal jatuh tempo) tetap di roadmap (F).
- **A4 ✅ (reposisi)** Kartu "Rata-rata Lead Time" → **"Rata-rata Umur Item Proses"** (WIP aging); akumulasi dipindah dari item *selesai* ke item *proses* sehingga angkanya bermakna. Lead-time selesai sejati (butuh tgl GR aktual) tetap roadmap.
- **A5 ✅** `monitoring.htm` — kode customer kini diprioritaskan; jika kode & nama sama-sama diisi, kode dipakai (tidak lagi diam-diam mengabaikan filter).
- **A6 ✅** Pencarian nama customer kini `WHERE mcod1 LIKE` (field pencarian huruf besar) → case-insensitive.
- **A7 ✅** Open-PO dirombak: `EKPO` (item PO aktif) → `EKET` (jadwal kirim). Qty terbuka = `Σ(menge − wemng)` (sisa, bukan menge penuh); ETA = `EKET-EINDT` paling awal. **Uji:** verifikasi `EKET` terisi untuk PO Anda.
- **A8 ✅** Agregasi mingguan pakai `DATE_COMPUTE_DAY` (Senin awal minggu dinamis), epoch `'20240101'` dihapus.

**Catatan uji prioritas:** A2 (kode status JEST) & A7 (EKET) paling perlu diverifikasi dengan data nyata; A3/A4 adalah perubahan **label & makna KPI** — konfirmasikan definisinya cocok dengan kebutuhan bisnis sebelum rilis.

---

## B. Inkonsistensi & Masalah UI/UX

> **STATUS — diperbaiki 29 Jun 2026 (B1–B7, B9).** Ringkasan ada di bawah tabel. **Uji di browser**
> setelah aktivasi (terutama format angka & form GET). B8 dinilai *acceptable* (tidak diubah).

| # | Lokasi | Deskripsi | Prioritas |
|---|--------|-----------|-----------|
| **B1** | `js.js:391-395` | Setelah AJAX, panel **selalu dipaksa** ke tab "Item & BOM" + `expandAllBOM()`. Tab default "Ringkasan" (yang dirender server-side dengan KPI ringkas) **tidak pernah tampil pertama**. Tentukan: apakah Ringkasan atau Item yang jadi landing tab, lalu konsistenkan dengan markup `active` di server. | Sedang |
| **B2** | CSS warna "Belum Produksi" | Tidak konsisten: di chart/donut/pill = **abu-abu** (`#d1d5db`), tetapi border SO card & progress fill `prog-black` = **hitam** (`#1f2937`). Sinyal visual untuk status yang sama berbeda. Samakan. | Rendah |
| **B3** | `style.css:399-401`, `.so-sl-noprod` | Chip "Belum Produksi" = teks `#9ca3af` di atas `#f3f4f6` → kontras rendah (gagal WCAG AA). Pertegas warna teks. | Rendah |
| **B4** | Form pencarian (3 pola berbeda) | Dashboard period (POST reload), dashboard customer search (POST reload), monitoring search (POST reload), detail (AJAX). Tidak ada pola POST-redirect-GET → refresh memunculkan dialog "kirim ulang form", dan hasil tidak bisa di-*bookmark*. | Sedang |
| **B5** | `monitoring.htm` saat load awal | Tanpa pencarian, sidebar tampil "Daftar Sales Order (0 Dokumen)" kosong tanpa panduan, sementara panel kanan punya placeholder. Tambah hint "Mulai dengan mencari SO/customer/tanggal" di sidebar. | Rendah |
| **B6** | `index.htm:652`, `monitoring_detail.htm:508` | Nilai uang `netwr` & angka qty (`kwmeng/psmng/wemng/menge`) ditampilkan mentah dari ABAP (mis. `1234567.890000`), tanpa pemisah ribuan / pembulatan. Format via `WRITE … TO` atau helper JS `toLocaleString` (sudah dipakai di tooltip material — terapkan konsisten). | Sedang |
| **B7** | Double-submit | Tombol "CARI DATA" / period / customer tidak dicegah dari klik ganda → query duplikat. Disable tombol + spinner saat submit. | Rendah |
| **B8** | Paginasi sidebar | Setelah POST (search), URL hash `#page=N` hilang → halaman balik ke 1. Karena search = full reload, state paginasi tidak bertahan antar pencarian (hanya bertahan saat back/forward tanpa reload). | Rendah |
| **B9** | Keyboard & a11y | Baris/kartu pakai `onclick` pada `<div>`/`<tr>` tanpa `role`/`tabindex`/handler keyboard. Tidak bisa dioperasikan keyboard. Tambah dukungan Enter/Escape & shortcut periode. | Rendah |

### Ringkasan perbaikan yang diterapkan (29 Jun 2026)

- **B1 ✅** `js.js viewDetails` — tidak lagi memaksa tab "Item & BOM" + `expandAllBOM()` setelah AJAX. Panel mendarat di tab **Ringkasan** (sesuai markup server). Lebih ringan & konsisten.
- **B2 ✅** `style.css` — "Belum Produksi" diseragamkan ke abu-abu: `prog-black`, `txt-black`, `so-border-noprod` (dari hitam `#1f2937` → `#9ca3af`/`#6b7280`).
- **B3 ✅** `.so-sl-noprod` kontras dinaikkan (`#e5e7eb` + `#4b5563`).
- **B4 ✅** Semua form filter (dashboard period, dashboard customer search, monitoring search) → `method="get"`. Hasil idempotent: reload tidak memunculkan dialog "kirim ulang", URL bisa di-*bookmark*/share. `get_form_field` membaca query GET sama seperti POST.
- **B5 ✅** `monitoring.htm` — sidebar menampilkan panduan **"Mulai Pencarian"** saat halaman dibuka sebelum ada pencarian.
- **B6 ✅** Format angka via helper JS `formatNumbers()` (kelas `.cur-fmt` uang & `.num-fmt` kuantitas, `toLocaleString('id-ID')`). Diterapkan ke netwr (dashboard & Info Order), qty/target/GR di tabel item, dan qty komponen BOM. Dipanggil saat load **dan** setelah AJAX (termasuk dari cache). `data-val` numerik untuk sort tetap utuh.
- **B7 ✅** `lockAllForms()` — tombol submit dinonaktifkan (ditunda 0ms agar value tetap terkirim) untuk cegah klik ganda.
- **B9 ✅** `enhanceA11y()` menambah `role="button"` + `tabindex="0"` ke baris yang bisa diklik (saat load & setelah AJAX); `handleGlobalKeydown` menambah **Enter/Space** untuk aktivasi & **Escape** untuk menutup tooltip/dropdown.
- **B8 ⏸️ (acceptable, tidak diubah)** Dengan B4 (GET), pencarian baru wajar reset ke halaman 1; hash `#page` tetap bertahan saat back/forward. Tidak ada perubahan.

**Bonus (sekaligus):** C3 ditangani — `getElementsByTagName('div')` diganti `querySelectorAll('[data-type="so-card"]')`. Listener "klik di luar untuk tutup dropdown" kini juga dipasang di halaman Monitoring (sebelumnya hanya di Dashboard).

**Perlu uji:** format angka di browser (pastikan `<%= %>` ABAP mengeluarkan desimal dengan titik), perilaku form GET (URL & reload), dan navigasi keyboard.

---

## C. Performa

> **STATUS — 29 Jun 2026:** C1 ✅, C3 ✅, C4 ✅ dikerjakan. **C2/C5/C6 ditunda** (alasan di bawah tabel). Uji setelah aktivasi.

| # | Lokasi | Issue | Saran | Prioritas |
|---|--------|-------|-------|-----------|
| **C1** | `index.htm:212` | `READ TABLE lt_so_prog WITH KEY vbeln` **tanpa** BINARY SEARCH di dalam LOOP item → O(item × SO). Hotspot utama dashboard untuk periode 90 hari. | Pakai *sorted/hashed table* untuk `lt_so_prog`, atau akumulasi via `COLLECT`, atau jaga terurut + `READ … BINARY SEARCH` + sisipan. | Sedang/Tinggi |
| **C2** | `monitoring.htm:320-392` | Semua baris SO dirender server-side, lalu disembunyikan via CSS; hanya 5 tampil. Untuk ratusan SO, DOM membengkak. | Render hanya halaman aktif, ambil halaman lain via AJAX (detail sudah AJAX — terapkan pola sama ke daftar). | Sedang |
| **C3 ✅** | `js.js:663` | ~~`getElementsByTagName('div')` mengiterasi **semua** div untuk mengumpulkan kartu SO.~~ **Selesai (29 Jun 2026)** — diganti `querySelectorAll('[data-type="so-card"]')` saat mengerjakan B. | `document.querySelectorAll('[data-type="so-card"]')`. | Rendah |
| **C4** | `monitoring_detail.htm:195-228` | FAE ke STPO/MAKT/MARD/EKPO tanpa `DELETE ADJACENT DUPLICATES … COMPARING` pada kunci driver (`idnrk`). Banyak `idnrk` duplikat → driver membengkak. | Dedup tabel driver sebelum FAE. (Sekaligus memperbaiki A1 dengan guard kosong.) | Rendah |
| **C5** | Semua halaman | Tidak ada caching layer ABAP; data agregat KPI sama untuk semua user tetapi di-query tiap request. | Shared memory / buffer (`CL_SHM_AREA` atau `EXPORT … TO SHARED BUFFER`), refresh tiap N menit. | Rendah |
| **C6** | `index.htm:122`, `monitoring.htm:160` | Filter Plant via subquery `vbeln IN ( SELECT vbeln FROM vbap WHERE werks=… )`. Optimizer kadang kurang optimal dibanding `FOR ALL ENTRIES` + pruning (pola yang sudah dipakai untuk `lt_vbak`). | Konsistenkan ke pola pruning. | Rendah |

### Ringkasan perbaikan yang diterapkan (29 Jun 2026)

- **C1 ✅ (hotspot utama)** `index.htm` — loop klasifikasi item ditulis ulang jadi **O(n)** dengan *control-break manual* (lt_vbap sudah terurut `BY vbeln`). Menghilangkan `READ lt_so_prog` linear per item **dan** mengurangi `READ lt_vbak` jadi sekali per SO (bukan per item). `erdat` SO disimpan di `lv_so_erdat` untuk WIP aging. Hasil agregat identik.
- **C3 ✅** (lihat Bagian B) — `querySelectorAll('[data-type="so-card"]')`.
- **C4 ✅** `monitoring_detail.htm` — dibuat driver komponen unik `lt_comp` (`SORT` + `DELETE ADJACENT DUPLICATES COMPARING idnrk`); MAKT/MARD/EKPO kini FAE `IN lt_comp` (bukan `lt_stpo_pre` yang penuh duplikat). `lt_stpo_pre` tetap terurut `BY stlnr` agar binary-search BOM tidak rusak.

### Ditunda — alasan

- **C2 (Sedang) ⏸️** *Lazy pagination* sidebar butuh endpoint/parameter baru untuk merender **satu halaman** kartu SO + query `COUNT` total + refactor JS paginasi. Perubahan arsitektur cukup besar dan berisiko bila diubah tanpa bisa diuji. Untuk jumlah SO tipikal (puluhan–ratusan) DOM masih wajar. **Rekomendasi:** kerjakan saat ada akses uji di sistem; pola AJAX `monitoring_detail.htm` bisa jadi acuan. **Prasyarat D1 (ZCL_CS_UTIL) kini sudah ✅**, jadi endpoint baru bisa langsung memakai helper warna tanpa menduplikasi logika.
- **C5 (Rendah) ⏸️** Caching shared memory (`CL_SHM_AREA`) = pekerjaan infrastruktur (kelas SHM, area, invalidasi) — bukan edit halaman; masuk roadmap.
- **C6 (Rendah) ⏸️** Mengganti subquery `IN (SELECT…)` ke FAE+prune menambah ~10 baris + loop prune di tiap query, untuk manfaat marginal (optimizer HANA menangani IN-subquery dengan baik). Risiko > manfaat tanpa uji. Dibiarkan.

---

## D. Kualitas Kode & Maintainability

> **STATUS — 29 Jun 2026:** D1 ✅ dikerjakan via **global class `ZCL_CS_UTIL`** (lihat ringkasan di bawah tabel).
> **WAJIB:** buat & aktifkan class di SE24/ADT **sebelum** mengaktifkan `monitoring.htm` & `monitoring_detail.htm`.

| # | Lokasi | Issue | Saran |
|---|--------|-------|-------|
| **D1 ✅** | 4 tempat | ~~**Logika klasifikasi status & ambang warna diduplikasi**~~ **Selesai** — pemetaan persentase→warna (100/70/45/20) dipusatkan di `ZCL_CS_UTIL`. (`js.js progClass` ternyata *dead code* → catat di D3.) | Pusatkan: satu method ABAP. ✔ `zcl_cs_util=>prog_bar_class()` / `prog_txt_class()`. |
| **D2 ✅** | `monitoring_detail.htm:97,101` | ~~`SELECT SINGLE * FROM vbak` / `kna1`~~ **Selesai** — kolom spesifik. | Pilih kolom spesifik (vbeln, erdat, auart, kunnr, netwr, waerk / name1, ort01). |
| **D3 ✅** | `style.css`, `js.js` | ~~**CSS mati** + `progClass` mati~~ **Selesai** — semua dihapus. | Hapus untuk mengurangi ukuran & kebingungan. |
| **D4** | Plant 2000 | Di-hardcode sebagai `CONSTANTS lc_plant` di tiga halaman terpisah. | Pindahkan ke satu include/konstanta bersama, atau parameter aplikasi (lihat F — multi-plant). |
| **D5** | `index.htm:392-414` | JSON array chart dibangun manual via `CONCATENATE`, rawan delimiter/quote. | `/UI2/CL_JSON=>SERIALIZE` atau `cl_trex_json_serializer`. |
| **D6 ✅** | Format tanggal | ~~Pola `+6(2)/+4(2)/+0(4)` diulang~~ **Selesai** — `zcl_cs_util=>fmt_date()`. | FORM/METHOD `format_date_ddmmyyyy` reusable. ✔ |
| **D7 ✅** | `monitoring_detail.htm:129` | ~~`gamng`/`gstrs`~~ **Selesai otomatis saat A2** (select AFKO kini `aufnr gltrp`). | Bersihkan select list setelah A2 diperbaiki; pertimbangkan `GLTRP` untuk target finish. |
| **D8** | Dokumentasi | `README.md`, `erd.md`, `flowchart.md` belum mencerminkan KNA1/AFKO/MARD/EKPO, `monitoring_detail.htm`, AJAX, tab, KPI baru. | Sinkronkan (lihat Bagian G). |

### Ringkasan perbaikan yang diterapkan (29 Jun 2026)

- **D1 ✅** Dibuat global class **`ZCL_CS_UTIL`** (source: `ZBSP_CS_APP/classes/ZCL_CS_UTIL.abap`) dengan `prog_bar_class( pct )` & `prog_txt_class( pct )`. Empat titik ABAP yang sebelumnya menyalin ambang 100/70/45/20 kini memanggil class:
  - `monitoring.htm` sidebar (progress fill SO),
  - `monitoring_detail.htm` — overall bar (Ringkasan), per-item summary, dan tabel Item & BOM.
  - Kasus *belum produksi* (`prog-black`/`txt-black`) tetap di pemanggil karena kontekstual (psmng=0 / semua noprod).
  - Mengubah ambang/warna progres cukup di satu tempat → drift hilang.
- **Catatan dependency (PENTING):** `monitoring.htm` & `monitoring_detail.htm` sekarang memanggil `zcl_cs_util=>...`. **Buat & aktifkan `ZCL_CS_UTIL` di SE24/ADT dulu** (assign ke package & transport ZBSP_CS_APP) sebelum aktivasi halaman, kalau tidak halaman gagal kompilasi.
- **D2 ✅** `monitoring_detail.htm` — `SELECT SINGLE *` VBAK/KNA1 diganti kolom spesifik (`vbeln erdat auart kunnr netwr waerk` / `kunnr name1 ort01`).
- **D3 ✅** Dihapus CSS mati: `.prog-bar`, `.prog-bar-inner`, `.info-icon`, blok `.so-stat-row`/`.so-pill-*`/`.so-mini-bar*`, `.bom-loading` + `@keyframes bom-pulse`. Dihapus pula fungsi JS mati `progClass()`.
- **D6 ✅** Ditambah `zcl_cs_util=>fmt_date( dats )` → 'DD/MM/YYYY'; pola `+6(2)/+4(2)/(4)` yang berulang (erdat SO, recent, footer di index & monitoring; header & target di detail) kini memanggil helper. (Format khusus tetap dibiarkan: kunci YYYYMMDD mingguan, label DD/MM chart, ETA DD/MM.)
- **D7 ✅ (otomatis saat A2)** `gstrs`/`gamng` sudah hilang dari select AFKO.

**Belum dikerjakan di D:** D5 (JSON via CONCATENATE) — **ditunda**: `/UI2/CL_JSON` menghasilkan array-of-objects sehingga JS chart (`weekLabels`/`doneCounts` paralel) harus direstrukturisasi; risiko > manfaat karena data hanya angka & label DD/MM (risiko injeksi delimiter rendah). D8 (sinkron dokumentasi) → ditangani di **Bagian G**.

---

## E. Keamanan & Robustness

| # | Lokasi | Issue | Saran |
|---|--------|-------|-------|
| **E1** | Semua output `<%= %>` | BSP **tidak meng-encode HTML** secara default. Field seperti `arktx`, `name1`, `maktx`, dan input pencarian yang dipantulkan kembali (`value="<%= lv_ui_vbeln %>"`) bisa memicu **XSS terpantul/tersimpan** bila berisi `<`, `"`, `&`. | Encode via `cl_http_utility=>escape_html( )` untuk semua data yang berasal dari master data/input user, terutama yang masuk ke atribut HTML (`data-name`). |
| **E2** | `main.htm` | Autentikasi hanya cek `sy-uname` non-kosong. Tidak ada `AUTHORITY-CHECK` / objek otorisasi. User SAP valid mana pun bisa akses. | Tambah `AUTHORITY-CHECK` (mis. atas plant/area) + tampilkan pesan tolak. |
| **E3** | Form POST | Tidak ada token anti-CSRF. (Risiko rendah, app internal.) | Pertimbangkan CSRF token BSP bila terekspos lebih luas. |
| **E4** | `monitoring_detail.htm` AJAX | Endpoint menerima `vbeln` apa pun tanpa cek apakah user berhak; tidak ada rate limiting. | Validasi & terapkan otorisasi yang sama dengan E2 di endpoint fragmen. |

> Catatan positif: query memakai `CONVERSION_EXIT_ALPHA_INPUT` + `RANGES` + host variable (`LIKE lv_name_pattern`), sehingga **aman dari SQL injection** (tidak ada Open SQL dinamis). Pertahankan pola ini.

---

## F. Fitur yang Belum Ada / Roadmap

| Fitur | Keterangan | Prioritas |
|-------|-----------|-----------|
| **Multi-plant** | Plant 2000 hardcoded. Jadikan parameter (dropdown plant + `lc_plant` dari input/parameter aplikasi). | Tinggi |
| **OTD & lead time yang benar** | Implementasikan dengan tanggal target vs aktual (AFKO/AFRU/MSEG) — sekaligus menyelesaikan A3/A4. | Tinggi |
| **Export Excel/PDF** | Tidak ada export untuk tabel SO/item/BOM. | Sedang |
| **Auto-refresh dashboard** | Timer interval + indikator "live". | Sedang |
| **Trend line harian/bulanan** | Saat ini hanya bar mingguan. | Sedang |
| **Role-based access** | Viewer / supervisor / admin (sejalan E2). | Sedang |
| **Persistensi preferensi user** | Periode & filter reset tiap reload; simpan via SAP user parameter / `localStorage`. | Rendah |
| **Integrasi PP/EWM lebih dalam** | `AFKO`/`AFRU`/`MSEG` untuk akurasi progress & tanggal nyata. | Besar |
| **Perbandingan periode** | Month-over-month / year-over-year. | Sedang |
| **Dark mode** | Hanya tema terang. | Rendah |

---

## G. Sinkronisasi Dokumentasi

- **README.md**: perbarui struktur file (folder `MIMEs/css`, `MIMEs/js`, `monitoring_detail.htm`), tabel SAP baru (KNA1, AFKO, MARD, EKPO), arsitektur AJAX, daftar fitur (tab, tooltip material, KPI baru), serta prasyarat sistem (rilis SAP min., otorisasi).
- **erd.md**: tambah KNA1, AFKO, MARD, EKPO ke ERD & kardinalitas; tambah struktur `ty_local_item` versi detail (dengan `aufnr`), `ty_cust_info`, `ty_so_stat`, `ty_mard_agg`, `ty_ekpo_slim`.
- **flowchart.md**: tambahkan alur AJAX `viewDetails → monitoring_detail.htm`, alur tab, tooltip material, dan KPI OTD/lead time/backlog di dashboard.

---

## H. Urutan Pelaksanaan yang Disarankan

**Fase 1 — Kritis/Tinggi (benerin dulu)**
1. **A1** guard `IF lt_stpo_pre IS NOT INITIAL` sebelum MAKT/MARD/EKPO (cepat, dampak besar).
2. **A2** status order AFKO via JEST/`STATUS_TEXT_EDIT` (saat ini selalu "Dibuat").
3. **A3 + A4** perbaiki/relabel KPI OTD & lead time agar tidak menyesatkan (minimal beri label jujur sambil menunggu data tanggal aktual).
4. **A7** verifikasi `EKPO-EILDT` di ST22/runtime sebelum dianggap aman.

**Fase 2 — Sedang**
1. **A5** logika filter customer saat dua field diisi; **A6** case-insensitive name search.
2. **B1** tentukan landing tab; **B6** format angka/uang.
3. **C1** optimasi `lt_so_prog`; **C2** paginasi sidebar via AJAX.
4. **E1/E2** HTML-escape output + `AUTHORITY-CHECK`.

**Fase 3 — Rendah / Kualitas**
1. **D1** pusatkan logika klasifikasi; **D3** hapus CSS mati; **D2/D5/D6** kebersihan ABAP.
2. **B2/B3** konsistensi warna & kontras; **B5/B7/B9** UX kecil.
3. **A8** ganti epoch hardcode agregasi mingguan.

**Fase 4 — Roadmap**
- Multi-plant, export, auto-refresh, OTD/lead time berbasis data aktual, dark mode, sinkron dokumentasi (G).
