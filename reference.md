# Data Reference — Central Storage Production Dashboard (ZBSP_CS_APP)

> Dokumentasi **sumber data** setiap halaman: berasal dari **tabel SAP apa**, **kolom apa**,
> kunci join, filter, dan dipakai untuk apa. Disusun dari pembacaan menyeluruh seluruh kode
> BSP (`Page with Flow Logic/*.htm`) + kelas global `ZCL_CS_UTIL`.
> Aplikasi: SAP BSP (ABAP *Page with Flow Logic*), monitoring produksi **Plant 2000** (KMI 2 Surabaya).
> Sistem: **S/4HANA** (VBUK/VBUP sudah dihapus — status SD dibaca dari VBAK).

---

## 0. Konvensi Umum

| Hal | Nilai / Aturan |
|-----|----------------|
| **Plant** | `CONSTANTS lc_plant TYPE vbap-werks VALUE '2000'` — di-*hardcode* di setiap halaman. Semua item difilter `VBAP-WERKS = '2000'`. |
| **Filter SO Plant** | Header SO diambil dengan subquery `vbeln IN ( SELECT vbeln FROM vbap WHERE werks = '2000' )`, lalu item difilter ulang `werks = '2000'`. SO multi-plant hanya menyumbang item 2000-nya. |
| **Konversi input** | Nomor SO / kode customer dari input user selalu lewat FM `CONVERSION_EXIT_ALPHA_INPUT` (tambah leading zero) sebelum dipakai di query. |
| **Aturan status item** | AFPO (per item, **diagregasi**) `psmng>0` & `wemng>=psmng` → **Selesai**; `psmng>0` & `wemng<psmng` → **Proses**; tak ada AFPO / `psmng=0` → **Belum Produksi**. |
| **Persentase item** | `pct = wemng / psmng * 100`, dibatasi maks 100 (`ZCL_CS_UTIL=>item_pct`). Persentase SO = **rata-rata** pct item (Σpct / jumlah item). |
| **Agregasi AFPO** | 1 item SD (`kdauf`+`kdpos`) bisa punya >1 order produksi → `psmng`/`wemng` **dijumlah** via `COLLECT` sebelum klasifikasi. |
| **Status SD (S/4)** | `VBAK-GBSTK` (Overall) & `VBAK-LFSTK` (Delivery); `C` = *Completely processed* / *Fully delivered*. |
| **Aman SQL injection** | Semua Open SQL statis + host variable + `RANGES`; tidak ada SQL dinamis. |

---

## 1. Kelas Global `ZCL_CS_UTIL`

Sumber: `ZBSP_CS_APP/classes/ZCL_CS_UTIL.abap`. **Tidak** mengakses tabel DB (murni util).

| Anggota | Tipe/Signature | Fungsi |
|---------|----------------|--------|
| `ty_pct` | `p LENGTH 8 DECIMALS 2` | Tipe persentase progres. |
| `gc_st_done / gc_st_inprog / gc_st_noprod` | `i` = 1 / 2 / 3 | Kode status item. |
| `item_status( iv_psmng, iv_wemng )` | → `i` | Klasifikasi status item dari total target & GR. |
| `item_pct( iv_psmng, iv_wemng )` | → `ty_pct` | Persentase progres 1 item (maks 100). |
| `css_pct( iv_pct )` | → `string` | Lebar CSS aman lokal (0–100, desimal dipaksa titik). |
| `prog_bar_class( iv_pct )` | → `string` | Kelas warna bar (`prog-green/blue/yellow/orange/red`). |
| `prog_txt_class( iv_pct )` | → `string` | Kelas warna teks persen. |
| `fmt_date( iv_date )` | → `string` | `DATS` → `'DD/MM/YYYY'`. |
| `gc_plant_2000/1000`, `gc_sloc_1d00` | konstanta | Plant/sloc dipakai `monitoring_bom.htm` (Sloc Terkini) & transfer. |
| `ty_qty` / `ty_dotbar` / `ty_lgort_range`, `gc_sloc_2kcs…229k`, `pipeline_slocs( )`, `dot_stages( … )` | tipe/konstanta/method | **Tidak dipakai** (sisa pendekatan dot-bar/pipeline yang diganti "Sloc Terkini"). Boleh dihapus. |

---

## 2. `main.htm` — Inisialisasi & Autentikasi

**Sumber data:** *Tidak ada query tabel.*

| Bagian | Sumber | Keterangan |
|--------|--------|------------|
| Autentikasi | `sy-uname` (field sistem) | Jika `sy-uname` kosong → `navigation->vhost_authentication( )`. Tidak ada `AUTHORITY-CHECK`. |

---

## 3. `index.htm` — Dashboard

**Input (GET):** `period` (7/30/90, default 30), `cust_search`.
**Periode:** `lv_dfrom = sy-datum - period`, `lv_dto = sy-datum`.

| # | Bagian / KPI | Tabel | Kolom diambil | Kunci / Filter | Dipakai untuk |
|---|--------------|-------|---------------|----------------|---------------|
| 1 | Header SO periode | **VBAK** | `vbeln, erdat, kunnr, auart` | `erdat BETWEEN dfrom AND dto` + `vbeln IN (SELECT vbeln FROM VBAP WHERE werks=2000)` | Basis semua KPI, chart, kartu. |
| 2 | Filter plant (subquery) | **VBAP** | `vbeln` | `werks = 2000` | Membatasi SO ke Plant 2000. |
| 3 | Item produksi | **VBAP** | `vbeln, posnr` | FAE `lt_vbak`, `werks = 2000` | Hitung total item, prune SO, klasifikasi. |
| 4 | Produksi per item | **AFPO** | `kdauf, kdpos, psmng, wemng, aufnr` | FAE `lt_vbap`, `kdauf=vbeln AND kdpos=posnr` | Status item (Selesai/Proses/Belum), rate. |
| 5 | Target finish order | **AFKO** | `aufnr, gltrp` | FAE order selesai (`lt_ordfin`), `aufnr=...` | KPI **OTD** (target vs aktual). |
| 6 | Dokumen GR | **MSEG** | `mblnr, mjahr, aufnr` | FAE `lt_ordfin`, `aufnr=... AND bwart='101'` | Tanggal selesai aktual order. |
| 7 | Tanggal posting GR | **MKPF** | `mblnr, mjahr, budat` | FAE `lt_mseg`, `mblnr, mjahr` | `grdat` = BUDAT GR **terakhir** → OTD & lead time. |
| 8 | Nama customer | **KNA1** | `kunnr, name1` | FAE `lt_cust_list`, `kunnr=...` | Kotak customer. |

**KPI & visual yang diturunkan:**
- **Total Sales Order / Total Item Produksi** = `lines(lt_vbak)` / `lines(lt_vbap)`.
- **Item Selesai / Dalam Proses / Belum Produksi** = agregasi klasifikasi item.
- **Tingkat Penyelesaian** = done / total item × 100.
- **Penyelesaian Order Produksi (OTD)** = order dengan `grdat <= gltrp` / total order ber-target × 100 (berbasis tanggal GR aktual vs `AFKO-GLTRP`).
- **Rata-rata Umur Item Proses / Lead time** = rata-rata (`grdat − VBAK-erdat`) hari untuk order selesai.
- **Item Backlog** = item proses yang `sy-datum − erdat > 30` hari.
- **Bar mingguan** = distribusi status item per minggu (kunci = Senin awal minggu, dari `VBAK-erdat`).
- **Donut** = proporsi Selesai/Proses/Belum seluruh item.
- **Kartu "SO Terbaru"** = 5 SO `erdat` terbaru.

---

## 4. `index_oldcard.htm` — Kartu "SO Terlama Belum Selesai" (AJAX fragment)

**Dipanggil:** async dari `index.htm` (lazy-load). **Horizon:** `lc_backlog_days = 90` hari (`erdat >= sy-datum − 90`).

| # | Bagian | Tabel | Kolom diambil | Kunci / Filter | Dipakai untuk |
|---|--------|-------|---------------|----------------|---------------|
| 1 | Header + status SD | **VBAK** | `vbeln, erdat, kunnr, auart, gbstk, lfstk` | `erdat >= sy-datum−90` + `vbeln IN (SELECT vbeln FROM VBAP WHERE werks=2000)` | Kandidat backlog + filter selesai. |
| 2 | Filter plant (subquery) | **VBAP** | `vbeln` | `werks = 2000` | Batasi ke Plant 2000. |
| 3 | Item (5 SO terpilih) | **VBAP** | `vbeln, posnr` | FAE `lt_bl_hdr` (≤5), `werks=2000` | Statistik progress bar. |
| 4 | Produksi item | **AFPO** | `kdauf, kdpos, psmng, wemng` | FAE `lt_bl_vbap`, `kdauf=vbeln AND kdpos=posnr` | Rata-rata progres bar & rincian. |

**Aturan filter "belum selesai"** (langsung dari VBAK): **buang** SO bila `LFSTK='C'` (Fully Delivered) **ATAU** `GBSTK='C'` (Complete). `FKSTK`/billing **sengaja bukan** trigger. Sisanya diurut **tertua** (`erdat` naik), diambil **5** — baru fetch VBAP/AFPO (hemat query).

---

## 5. `monitoring.htm` — Monitoring (pencarian + sidebar SO)

**Input (GET):** `so_num`, `cust_num`, `cust_name`, `date_from`, `date_to`, `search_btn`.
**Default tanggal:** 30 hari terakhir (kecuali cari `so_num` tanpa tanggal → `erdat_from='19000101'`).

| # | Bagian | Tabel | Kolom diambil | Kunci / Filter | Dipakai untuk |
|---|--------|-------|---------------|----------------|---------------|
| 1 | Cari nama customer | **KNA1** | `kunnr, name1` | `mcod1 LIKE pattern` (huruf besar, case-insensitive) | Konversi nama → range `kunnr`. |
| 2 | Header SO | **VBAK** | `vbeln, erdat, auart, kunnr` | `erdat BETWEEN from AND to` + `vbeln IN lr_vbeln` + `kunnr IN lr_kunnr` + `vbeln IN (SELECT vbeln FROM VBAP WHERE werks=2000)` | Daftar SO sidebar. |
| 3 | Nama customer | **KNA1** | `kunnr, name1` | FAE `lt_local_hdr`, `kunnr=...` | Nama di kartu SO sidebar. |
| 4 | Item SO | **VBAP** | `vbeln, posnr, matnr, arktx, kwmeng, vrkme` | FAE `lt_local_hdr`, `vbeln=... AND werks=2000` | Hitung item & status per SO. |
| 5 | Produksi item | **AFPO** | `kdauf, kdpos, psmng, wemng` | FAE `lt_temp_vbap`, `kdauf=vbeln AND kdpos=posnr` | Agregasi → status & rate per SO. |

**Diturunkan:** status per SO (done/inprog/noprod, rata-rata pct), warna bar & **border kiri** (mengikuti warna bar via `prog-*` → `so-bl-*`), chip label status. Panel detail dimuat **AJAX** ke `monitoring_detail.htm`.

---

## 6. `monitoring_detail.htm` — Detail SO (AJAX fragment, tab Ringkasan/Item/Butuh Dikirim)

**Input:** `vbeln` (lewat ALPHA conversion).

| # | Bagian | Tabel | Kolom diambil | Kunci / Filter | Dipakai untuk |
|---|--------|-------|---------------|----------------|---------------|
| 1 | Header SO | **VBAK** | `vbeln, erdat, auart, kunnr, netwr, waerk` | `SELECT SINGLE WHERE vbeln=...` | Ringkasan header, nilai order. |
| 2 | Customer | **KNA1** | `kunnr, name1, ort01` | `SELECT SINGLE WHERE kunnr=...` | Nama & kota customer. |
| 3 | Item SO | **VBAP** | `vbeln, posnr, matnr, arktx, kwmeng, vrkme` | `vbeln=... AND werks=2000` | Daftar item + status ringkas. |
| 4 | Produksi item | **AFPO** | `kdauf, kdpos, psmng, wemng` | FAE `lt_temp_vbap`, `kdauf=vbeln AND kdpos=posnr` | Progres & status item. |

**Catatan tab (3 tab):** **Ringkasan** kini **gabungan** Info Order (atas) + ringkasan status item
(bawah) — tab "Info Order" terpisah dihapus (murni HTML, tanpa query baru di file ini). Tab
**"Item & BOM"** (rantai berat) dimuat **lazy** dari `monitoring_bom.htm`. Tab **"Butuh Dikirim"**
juga **lazy** dari `monitoring_bom.htm?mode=kirim` (js.js: `loadKirim/fetchKirim/renderKirim`,
cache `soKirimCache`, pane `#tab-kirim`).

---

## 7. `monitoring_bom.htm` — Tab Item & BOM (AJAX fragment, BERAT)

**Input:** `vbeln`. Rantai terberat: order produksi + komponen/reservasi + BOM master + stok + PO.

| # | Bagian | Tabel | Kolom diambil | Kunci / Filter | Dipakai untuk |
|---|--------|-------|---------------|----------------|---------------|
| 1 | Item SO | **VBAP** | `vbeln, posnr, matnr, arktx, kwmeng, vrkme` | `vbeln=... AND werks=2000` | Baris item. |
| 2 | Order produksi | **AFPO** | `kdauf, kdpos, psmng, wemng, meins, aufnr` | FAE item, `kdauf=vbeln AND kdpos=posnr` | Progres item + order wakil. |
| 3 | Tanggal order | **AFKO** | `aufnr, gstrp, gltrp, getri` | FAE `lt_afpo_pre`, `aufnr=...` | Tanggal mulai/target/aktual order. |
| 4 | Objek status | **AUFK** | `aufnr, objnr` | FAE `lt_afpo_pre`, `aufnr=...` | Jembatan ke status sistem. |
| 5 | Status sistem | **JEST** | `objnr, stat` | FAE `lt_aufk_pre`, `objnr=... AND inact=' '` | Label status order (CRTD/REL/CNF/TECO). |
| 6 | Komponen/reservasi | **RESB** | `aufnr, matnr, werks, lgort, bdmng, meins` | FAE `lt_afpo_pre`, `aufnr=... AND xloek=' '` | Daftar komponen per order (gaya COOIS). |
| 7 | Nama storage loc | **T001L** | `werks, lgort, lgobe` | FAE `lt_resb`, `werks=... AND lgort=...` | Kolom "Sloc – Nama Sloc". |
| 8 | BOM header | **MAST** | `matnr, stlnr` | FAE `lt_local_item`, `matnr=... AND werks=2000` | Fallback BOM item tanpa order. |
| 9 | BOM item | **STPO** | `stlnr, idnrk, menge, meins` | FAE `lt_mast_pre`, `stlnr=...` | Komponen BOM master. |
| 10 | Nama material | **MAKT** | `matnr, maktx` | FAE komponen (RESB ∪ STPO), `matnr=... AND spras=sy-langu` | Nama komponen. |
| 11 | Stok | **MARD** | `matnr, labst` | FAE `lt_comp`, `matnr=idnrk AND werks=2000 AND labst>0` | Stok komponen (tooltip). |
| 12 | PO terbuka | **EKPO** | `ebeln, ebelp, matnr` | FAE `lt_comp`, `matnr=idnrk AND werks=2000 AND loekz=' ' AND elikz=' '` | PO belum lengkap komponen. |
| 13 | Jadwal PO | **EKET** | `ebeln, ebelp, eindt, menge, wemng` | FAE `lt_ekpo_pre`, `ebeln=... AND ebelp=...` | Qty terbuka `Σ(menge−wemng)` + ETA `eindt` terawal. |
| 14 | **Sloc Terkini** (stok) | **MARD** | `matnr, werks, lgort, labst` | FAE material komponen (RESB), `labst>0 AND (werks=2000 OR (werks=1000 AND lgort=1D00))` | Lokasi stok material kini (semua sloc Plant 2000; +1D00 bila belum masuk). |
| 15 | Nama sloc terkini | **T001L** | `werks, lgort, lgobe` | FAE `lt_curloc`, `werks=... AND lgort=...` | Nama sloc untuk badge Sloc Terkini (bisa di luar sloc reservasi RESB). |

**Kolom "Sloc Terkini"** pada baris komponen (menggantikan progres GR/target lama): badge sloc tempat
**stok material berada kini** (MARD `labst>0`) di Plant 2000, atau `1D00` (merah) bila belum masuk.
Rute internal Plant 2000 **dinamis** per material (banyak sloc; mvt 311/261/101) → **tidak** dilacak
sebagai tahap/persen. Material yang sama hanya berpindah sloc (bukan menjadi assembly baru).
Bila material tersebar di >1 sloc, semua badge ditampilkan (qty terbesar dulu).

> **Catatan:** `ZCL_CS_UTIL=>dot_stages`/`pipeline_slocs` + tipe `ty_qty`/`ty_dotbar` masih ada di class
> namun **tidak dipakai lagi** (pendekatan dot-bar/pipeline diganti "Sloc Terkini"). Boleh dihapus.

### 7b. `monitoring_bom.htm?mode=kirim` — Fragment "Butuh Dikirim" (di-scope per SO)

Cabang `IF lv_mode = 'kirim'` pada file yang sama. Merender **tabel datar per material** komponen yang
masih **perlu dikirim** `1000/1D00 → 2000/2KCS` untuk SO ini. Logika **di-lift dari `transfer.htm` §8b**
(Model B, rekonsiliasi per material), bedanya **selalu di-scope** ke `aufnr` order milik SO (tanpa form
filter/cache/pagination). Konstanta plant/sloc reuse `ZCL_CS_UTIL` (`gc_plant_1000/2000`, `gc_sloc_1d00/2kcs`).

| # | Bagian | Tabel | Kolom diambil | Kunci / Filter | Dipakai untuk |
|---|--------|-------|---------------|----------------|---------------|
| 1 | Order milik SO | **AFPO** | `aufnr` | `kdauf = vbeln` → RANGE `lr_kaufnr` | Scope RESB ke order SO ini |
| 2 | Kebutuhan (Butuh) | **RESB** | `matnr, meins, bdmng, enmng, aufnr, bdter` | `werks='2000' AND xloek=' ' AND kzear=' ' AND aufnr IN lr_kaufnr` (open di loop) | `Butuh = Σ(bdmng−enmng)` per material |
| 3 | Nama material | **MAKT** | `matnr, maktx` | FAE, `spras=sy-langu` | Nama |
| 4 | Stok tujuan/sumber | **MARD** | `matnr, werks, lgort, labst` | `(2000/2KCS)` & `(1000/1D00)` | Stok 2KCS & Stok 1D00 |
| 5 | Sudah Dikirim | **MSEG** ⨝ **MKPF** | `mblnr, matnr, menge, shkzg, budat` | `bwart='301' AND werks='1000' AND lgort='1D00' AND budat >= sy-datum−90` | Terkirim aktual (net `SHKZG`) |

**Diturunkan:** `Perlu Kirim = max(0, Butuh − Stok 2KCS)`; status `Tercukupi`/`Akan Dikirim`/`Kurang Stok 1D00`.
**Filter tampilan:** hanya `perlu>0` — **tetap tampil walau Stok 1D00 = 0** (status "Kurang Stok 1D00" merah),
agar kebutuhan paling kritis tidak tersembunyi (keputusan edge-case, selaras Action Center). Urut `perlu` DESC.
Empty-state: `lr_kaufnr` kosong → "belum ada order produksi"; ada order tapi tak ada kekurangan → "Semua bahan telah dikirim".

#### Validasi 2026-07-11 — "Butuh" (kolom) sumbernya RESB, BUKAN VBAP-KWMENG

**Jenis bukti: INSPEKSI KODE (static), bukan runtime.** Terpicu kecurigaan: di browser tab Butuh Dikirim,
banyak material berbeda menampilkan angka **Butuh yang sama (20)**, mirip qty SO → diduga salah ambil dari
`VBAP-KWMENG`. Hasil telusur kode:
- Field "Butuh" = `ls_kneed-need`, diisi HANYA dari `RESB-BDMNG − RESB-ENMNG` (`monitoring_bom.htm`
  baris 292 `lv_kopen = ls_kresb-bdmng - ls_kresb-enmng`, 299 `ls_kneed-need = lv_kopen`, 304
  `<kn>-need = <kn>-need + lv_kopen`), diagregasi per `matnr`. **Tidak ada `SELECT … FROM vbap` di
  cabang `mode=kirim`** (VBAP/`KWMENG` hanya di cabang Item & BOM). ⇒ Hipotesis "Butuh dari VBAP-KWMENG"
  **TERBANTAH oleh kode**.
- Logika "Butuh" di `mode=kirim` **byte-identik** dengan `transfer.htm` (baris 178–206): SELECT, rumus
  `bdmng−enmng`, agregasi per material, dan scope (`aufnr` dari `AFPO WHERE kdauf=SO`) semua sama; `lc_plant`
  = `lc_dst_plant` = `'2000'`. ⇒ Untuk SO yang sama, **kedua halaman WAJIB menghasilkan angka Butuh identik**;
  lift tidak menambah divergensi.

> ⏳ **BELUM DIKONFIRMASI RUNTIME (SO uji: 10578).** Perbandingan angka aktual `transfer.htm?so_num=10578`
> vs `mode=kirim` untuk SO 10578 **belum tercatat** — sesi ini hanya inspeksi kode + prediksi, angka browser
> tidak pernah di-paste balik. **Jangan tulis sebagai "tervalidasi" tanpa angka.** Cara memutuskan apakah
> "semua = 20" itu benar/bug: buka **SE16 → RESB** untuk 1 order SO 10578 (`AUFNR` dari `AFPO WHERE kdauf`),
> baca `BDMNG` per `MATNR`. Jika RESB genuinely bervariasi (mis. 20/40/80) tapi tab tampil semua-20 → bug
> di logika BERSAMA (transfer.htm ⇄ kirim), perbaiki terpusat. Jika RESB sendiri = 20 untuk semua komponen
> → data 1:1/unit, tampilan benar. **TODO sesi berikut: isi angka aktual di sini.**

> ✅ **DIVERIFIKASI & DIPERBAIKI 2026-07-11 — overcounting "Sudah Dikirim" (filter UMWRK/UMLGO):**
> query MSEG di `transfer.htm` **dan** cabang `mode=kirim` semula hanya menyaring sisi **keluar**
> (`werks=1000/lgort=1D00 + bwart=301`) tanpa memverifikasi **tujuan** → mvt 301 dari `1D00` yang sebenarnya
> transfer **internal Plant 1000** (mis. `1D00 → 1E03` "Molding Input", **bukan** `2KCS`) ikut terhitung
> sebagai "Sudah Dikirim" (**over-count**).
> **Verifikasi (SE11 + SE16):** `MSEG-UMWRK` = *Receiving plant*, `MSEG-UMLGO` = *Receiving storage location*,
> keduanya **CHAR 4**. Bukti nyata: **dokumen material 4908670272** — baris keluar (`LGORT=1D00`, `SHKZG='H'`)
> membawa `UMWRK=1000` / `UMLGO=1E03` (dikonfirmasi via MIGO Display), yaitu transfer internal Plant 1000.
> **Perbaikan:** ditambahkan `AND m~umwrk = '2000' AND m~umlgo = '2KCS'` ke WHERE SELECT MSEG di **KEDUA** file
> (di `transfer.htm` via `lc_dst_plant`/`lc_dst_sloc`; di `monitoring_bom.htm` K5 via `lc_plant`/`gc_sloc_2kcs`
> — nilai identik `'2000'`/`'2KCS'`, sinkron, tanpa divergensi). `UMWRK`/`UMLGO` dipakai di WHERE saja (tidak
> perlu masuk SELECT list / `ty_mv`/`ty_kmv`).
> **⚠️ DAMPAK ANGKA (DIHARAPKAN, BUKAN BUG):** setelah perbaikan ini, kolom **"Sudah Dikirim" bisa TURUN** di
> `transfer.htm` dan `mode=kirim` untuk material yang sebelumnya ter-inflasi oleh transfer internal 1D00 (mis.
> ke 1E03). Ini **koreksi overcounting yang disengaja** — bukan regresi. Konsekuensi lanjutan: sebagian material
> bisa tampak **lebih** butuh dikirim dari sebelumnya (lebih akurat). Bila ada yang bingung melihat riwayat angka
> berubah turun mulai 2026-07-11, inilah sebabnya.
> **Backlog sisa (opsional):** sentralisasi query rekonsiliasi ke method `ZCL_CS_UTIL` agar logika bersama
> transfer.htm ⇄ kirim tidak lagi diduplikasi (hindari drift ke depan). Cross-check tambahan: MD04 (Special
> Procurement `40` di MM03 MRP2 → Planned Order/PurReq dengan Supplying Plant eksplisit) — pelengkap, bukan pengganti.

---

## 8. `riwayat.htm` — Arsip SO Selesai

**Input (GET):** `so_num`, `cust_num`, `cust_name`, `date_from`, `date_to`, `search_btn`. **Default:** 90 hari.

| # | Bagian | Tabel | Kolom diambil | Kunci / Filter | Dipakai untuk |
|---|--------|-------|---------------|----------------|---------------|
| 1 | Cari nama customer | **KNA1** | `kunnr, name1` | `mcod1 LIKE pattern` | Nama → range `kunnr`. |
| 2 | Header SO | **VBAK** | `vbeln, erdat, auart, kunnr, netwr, waerk` | `erdat BETWEEN from AND to` + `vbeln IN lr_vbeln` + `kunnr IN lr_kunnr` + `vbeln IN (SELECT vbeln FROM VBAP WHERE werks=2000)` | Kandidat arsip. |
| 3 | Item SO | **VBAP** | `vbeln, posnr` | FAE `lt_local_hdr`, `vbeln=... AND werks=2000` | Hitung item & kelengkapan. |
| 4 | Produksi item | **AFPO** | `kdauf, kdpos, psmng, wemng` | FAE `lt_temp_vbap`, `kdauf=vbeln AND kdpos=posnr` | Klasifikasi (agregasi per item). |
| 5 | Nama customer | **KNA1** | `kunnr, name1` | FAE `lt_local_hdr`, `kunnr=...` | Nama di kartu arsip. |

**Aturan arsip:** simpan SO hanya bila **semua** item Plant 2000 sudah GR 100% (`done = total`). Pengecualian: cari `so_num` → SO belum selesai juga ditampilkan (label "SO Belum Selesai").

---

## 8b. `transfer.htm` — Transfer Material 1D00 → 2KCS (tab baru)

**Input (GET):** `matnr`, `so_num`, `status` (''/`need`/`ok`).
**Model:** rekonsiliasi per material. `Perlu Kirim = max(0, Butuh − Stok 2KCS)`.
**Asumsi (verifikasi Fase 0):** movement `301`; "Butuh" dari RESB kebutuhan Plant 2000 (Model B).

| # | Bagian | Tabel | Kolom diambil | Kunci / Filter | Dipakai untuk |
|---|--------|-------|---------------|----------------|---------------|
| 1 | Order milik SO (filter) | **AFPO** | `aufnr, kdauf` | `kdauf = so_num` | Batasi RESB ke order SO tsb |
| 2 | Kebutuhan (Butuh) | **RESB** | `matnr, meins, bdmng, enmng, aufnr, bdter` | `werks='2000' AND xloek=' ' AND kzear=' ' AND bdmng>enmng` (+`aufnr IN` bila filter SO) | `Butuh = Σ(bdmng−enmng)` per material |
| 3 | SO terkait | **AFPO** | `aufnr, kdauf` | FAE `aufnr` dari RESB | Nomor SO per material |
| 4 | Nama material | **MAKT** | `matnr, maktx` | FAE, `spras=sy-langu` | Nama |
| 5 | Stok tujuan/sumber | **MARD** | `matnr, werks, lgort, labst` | `(2000/2KCS)` & `(1000/1D00)` | Stok 2KCS & Stok 1D00 |
| 6 | Sudah Dikirim | **MSEG** | `mblnr, mjahr, matnr, menge, shkzg` | `bwart='301' AND werks='1000' AND lgort='1D00'` | Terkirim aktual (net `SHKZG`) |
| 7 | Tgl posting kirim | **MKPF** | `mblnr, mjahr, budat` | FAE `lt_mseg`, `budat >= sy-datum−90` | Tgl & dokumen kirim terakhir |

**Diturunkan:** `Perlu Kirim`, status (`Tercukupi`/`Akan Dikirim`/`Kurang Stok 1D00`), tautan SO → `monitoring.htm`.

---

## 9. Kamus Tabel SAP (ringkas)

| Tabel | Nama | Kolom yang dipakai | Kunci utama |
|-------|------|---------------------|-------------|
| **VBAK** | SD Header | vbeln, erdat, kunnr, auart, netwr, waerk, gbstk, lfstk | vbeln |
| **VBAP** | SD Item | vbeln, posnr, matnr, arktx, kwmeng, vrkme, werks | vbeln, posnr |
| **AFPO** | Order Produksi (item) | kdauf, kdpos, psmng, wemng, meins, aufnr | aufnr, posnr |
| **AFKO** | Order Produksi (header) | aufnr, gstrp, gltrp, getri | aufnr |
| **AUFK** | Order Master | aufnr, objnr | aufnr |
| **JEST** | Status Objek | objnr, stat, inact | objnr, stat |
| **RESB** | Reservasi/Komponen | aufnr, matnr, werks, lgort, bdmng, meins, xloek | rsnum, rspos, … |
| **T001L** | Storage Location | werks, lgort, lgobe | werks, lgort |
| **MAST** | BOM–Material Link | matnr, werks, stlnr | matnr, werks, stlan |
| **STPO** | BOM Item | stlnr, idnrk, menge, meins | stlnr, stlkn |
| **MAKT** | Teks Material | matnr, maktx, spras | matnr, spras |
| **MARD** | Stok per Sloc | matnr, werks, labst | matnr, werks, lgort |
| **EKPO** | PO Item | ebeln, ebelp, matnr, werks, loekz, elikz | ebeln, ebelp |
| **EKET** | Jadwal PO | ebeln, ebelp, eindt, menge, wemng | ebeln, ebelp, etenr |
| **MSEG** | Dokumen Material (item) | mblnr, mjahr, aufnr, bwart | mblnr, mjahr, zeile |
| **MKPF** | Dokumen Material (header) | mblnr, mjahr, budat | mblnr, mjahr |
| **KNA1** | Customer Master | kunnr, name1, ort01, mcod1 | kunnr |

---

## 10. Ringkasan Tabel per Halaman

| Halaman | Tabel yang diakses |
|---------|--------------------|
| `main.htm` | *(tidak ada — hanya `sy-uname`)* |
| `index.htm` | VBAK, VBAP, AFPO, AFKO, MSEG, MKPF, KNA1 |
| `index_oldcard.htm` | VBAK, VBAP, AFPO |
| `monitoring.htm` | KNA1, VBAK, VBAP, AFPO |
| `monitoring_detail.htm` | VBAK, KNA1, VBAP, AFPO |
| `monitoring_bom.htm` | VBAP, AFPO, AFKO, AUFK, JEST, RESB, T001L, MAST, STPO, MAKT, MARD, EKPO, EKET *(+ MSEG, MKPF di `mode=kirim`)* |
| `riwayat.htm` | KNA1, VBAK, VBAP, AFPO |
| `transfer.htm` | AFPO, RESB, MAKT, MARD, MSEG, MKPF |

> **Catatan status kolom VBAK (S/4HANA):** `GBSTK`/`LFSTK` ada di VBAK; `FKSTK` (billing) **tidak** ada di VBAK dan tidak dipakai. Di sistem ECC, status ada di VBUK/VBUP (tidak berlaku untuk sistem ini).
