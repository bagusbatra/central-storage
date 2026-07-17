# Dokumentasi Sumber Data — ZBSP_CS_APP (Central Storage Dashboard, Plant 2000)

Dokumen ini menjelaskan **secara rinci dari mana setiap halaman BSP mengambil datanya**: tabel SAP yang dibaca, kolom yang dipilih, filter WHERE, join, urutan query, dan pengolahan di ABAP hingga menjadi angka/teks yang tampil di layar.

> Semua halaman berada di `Page with Flow Logic/`. Helper terpusat berada di `classes/ZCL_CS_UTIL.abap`. Konstanta plant utama: `lc_plant = '2000'` (Central Storage KMI 2 Surabaya); tahap Pembahanan berada di Plant 1000.

---

## Daftar Tabel SAP yang Dipakai Aplikasi

| Tabel | Isi | Dipakai di |
|---|---|---|
| `VBAK` | Header Sales Order (vbeln, erdat, auart, kunnr, netwr, waerk) | index, monitoring, monitoring_detail, riwayat |
| `VBAP` | Item Sales Order (vbeln, posnr, matnr, arktx, kwmeng, vrkme, werks) | index, monitoring, monitoring_detail, monitoring_bom, riwayat |
| `KNA1` | Master customer (kunnr, name1, mcod1, ort01) | index, monitoring, monitoring_detail, riwayat |
| `AFPO` | Item order produksi (kdauf, kdpos, matnr, psmng, wemng, meins, aufnr, pwerk) | semua halaman monitoring + index, riwayat, transfer |
| `AFKO` | Header order produksi (aufnr, dispo, aufpl, gstrp, gltrp, getri) | index, monitoring, monitoring_detail, monitoring_bom, riwayat, diag_movement |
| `AUFK` | Master order (aufnr → objnr) | monitoring_bom |
| `JEST` | Status objek aktif (objnr, stat, inact) | monitoring_bom |
| `RESB` | Reservasi/komponen order produksi (aufnr, matnr, bdmng, enmng, bdter, lgort, meins) | monitoring_bom, transfer |
| `MAST` / `STPO` | BOM master (matnr→stlnr; stlnr→idnrk, menge, meins) | monitoring_bom (fallback) |
| `MAKT` | Deskripsi material (matnr, maktx) | monitoring_bom, transfer, diag_movement |
| `MARD` | Stok per storage location (matnr, werks, lgort, labst) | monitoring_bom (fallback), transfer, diag_movement |
| `EKPO` / `EKET` | Item PO & jadwal PO (open PO, eindt, menge, wemng) | monitoring_bom (fallback) |
| `MSEG` ⨝ `MKPF` | Baris gerakan material + tanggal posting (bwart, shkzg, lgort, umlgo, umwrk, kdauf, sobkz, budat) | transfer, diag_movement, (via `pmb_output_status`) monitoring_bom mode=kirim |
| `AFVC` | Operasi order (aufpl, vornr, arbid) | monitoring_bom, diag_movement (badge/scope "Line" Wood Furniture) |
| `CRCO` | Work center → cost center (objid, kostl, kokrs, begda, endda) | monitoring_bom, diag_movement |
| `T001L` | Nama storage location (lgobe) | diag_movement |
| `INDX` (cluster `cs`) | Cache snapshot transfer (`ID 'TRANSFER_V3'`) | transfer |

---

## Konsep Bersama: Mesin Tahap 4-Tingkat (D23)

Empat halaman (index, monitoring, monitoring_detail, riwayat) memakai **pipeline query yang identik** untuk menentukan tahap tiap item SO. Sumber datanya:

### 1. Order UTAMA per item (D21 "Opsi B")
```abap
SELECT kdauf kdpos psmng wemng FROM afpo
  WHERE kdauf = vbap-vbeln AND kdpos = vbap-posnr
    AND matnr = vbap-matnr.        " material output = material item SO
```
- **Sengaja tanpa filter DISPO/plant** — order utama (assembly akhir) bisa di plant/MRP mana pun.
- Bila ada >1 order (beberapa run produksi), `psmng`/`wemng` **dijumlahkan** per (kdauf, kdpos).
- Item dianggap "main_ok" bila `psmng > 0 AND wemng >= psmng` (Delivered = Target).

### 2. Order bertahap per item (whitelist MRP)
```abap
SELECT a~kdauf a~kdpos a~psmng a~wemng k~dispo
  FROM afpo AS a INNER JOIN afko AS k ON a~aufnr = k~aufnr
  WHERE a~kdauf = vbap-vbeln AND a~kdpos = vbap-posnr
    AND k~dispo IN zcl_cs_util=>wf_dispo_range( ).
```
Klasifikasi `AFKO-DISPO` (MRP controller) → tahap:

| DISPO | Tahap | Stage # | Plant fisik |
|---|---|---|---|
| `WM1`, `WM2`, `PN1`, `PN2` | Pembahanan | 1 | 1000 |
| `GA1`, `GA2` | Produksi | 2 | 2000 |
| `EB2`, `CH1` (D29) | Ready Assy / Finish | 3 | 2000 |

Per item, psmng/wemng **diakumulasi per tahap** ke `t_pmb/d_pmb`, `t_prd/d_prd`, `t_fin/d_fin` beserta flag `has_pmb/has_prd/has_fin`.

### 3. Ladder finalisasi tahap (identik di 4 halaman)
```
lv_fin_ok  = has_fin = X AND d_fin >= t_fin          " order Finish sendiri tuntas
lv_done_ok = main_ok OR fin_ok

IF has_pmb=X AND d_pmb < t_pmb  → stage 1 (Pembahanan)
ELSEIF has_prd=X AND d_prd < t_prd → stage 2 (Produksi)
ELSEIF done_ok                  → stage 4 (Selesai — benar-benar tuntas)
ELSEIF has_fin=X                → stage 3 (Ready Assy — ada order Finish, belum tuntas)
ELSEIF has_prd=X                → stage 2 (jaring pengaman)
ELSEIF has_pmb=X                → stage 1 (jaring pengaman)
ELSE                            → stage 2
```

### 4. Scope D22
```abap
DELETE lt_item_stage WHERE has_prd = abap_false AND has_fin = abap_false.
```
Item yang **sama sekali tidak punya** order Produksi (GA1/GA2) **dan** order Finish (EB2/CH1) dikeluarkan dari scope aplikasi. Item yang cuma sampai Pembahanan tidak dihitung.

### 5. Pengecualian customer "Sample"
Semua halaman daftar SO membaca:
```abap
SELECT kunnr FROM kna1 WHERE mcod1 LIKE '%SAMPLE%'.
```
lalu mengecualikan kunnr tersebut (di index: hapus dari `lt_vbak`; di monitoring/riwayat: range `E`/`EQ` pada `lr_kunnr`).

---

## 1. `index.htm` — Dashboard Statistik & Grafik

### Parameter input (GET)
| Parameter | Fungsi | Default |
|---|---|---|
| `period` | 7 / 30 / 60 / 90 / 365 hari mundur dari `sy-datum` | 30 |
| `date_from`, `date_to` | Rentang eksplisit (YYYY-MM-DD); menang atas `period`; auto-swap bila terbalik | — |
| `cust_search` | Kata kunci filter kotak customer | — |

### Urutan query
1. **Pengecualian Sample** — `KNA1` (`mcod1 LIKE '%SAMPLE%'`).
2. **Header SO** — `VBAK` (vbeln, erdat, kunnr, auart) dengan:
   - `erdat BETWEEN lv_dfrom AND lv_dto`
   - `vbeln IN ( SELECT vbeln FROM vbap WHERE werks = '2000' )` — hanya SO yang punya item Plant 2000.
3. **Item SO** — `VBAP` (vbeln, posnr, matnr) FOR ALL ENTRIES header, `werks='2000'`.
4. **Order utama** — `AFPO` per (vbeln, posnr, matnr) → `lt_main_ord` (lihat konsep bersama §1).
5. **Order bertahap** — `AFPO ⨝ AFKO` dgn `dispo IN wf_dispo_range( )` → ladder D23 (§2–3) → scope D22 (§4).
6. **Sinkronisasi scope**: `lt_vbap` dipangkas ke item yang lolos `lt_item_stage`; `lt_vbak` dipangkas ke SO yang masih punya item.

### Angka yang tampil
| Elemen | Sumber |
|---|---|
| **Total Sales Order** | `lines( lt_vbak )` setelah semua filter |
| **Total Item Produksi** | `lines( lt_vbap )` setelah scope D22 |
| **Proses Pembahanan / Produksi / Ready Assy / Selesai** | Hitungan item per `stage` 1–4 |
| **Bar chart** | Agregasi per **bucket waktu** berdasarkan `VBAK-ERDAT`. Granularitas otomatis dari lebar rentang: ≤7 hari = harian (`D`), ≤30 = mingguan (`W1`), ≤60 = 2 mingguan (`W2`), ≤90 = 3 mingguan (`W3`), >90 = bulanan (`M`). Bucket W* di-anchor ke Senin 2024-01-01 (`lc_ref_mon`), lalu **di-clip (D28)** ke `lv_dfrom/lv_dto` agar drill-down tak melebar. |
| **Donut chart** | Total 4 tahap seluruh item (angka yang sama dgn 4 kartu) |
| **Kotak Customer** | `COLLECT` kunnr dari `lt_vbak` (hitung SO per customer) + nama dari `KNA1`; sort `so_cnt DESC`; tanpa pencarian tampil 6 teratas |
| **Footer "Data per"** | `sy-datum` + `sy-uzeit` saat render |

### Injeksi data ke JavaScript
ABAP membangun array JSON string (`lv_jmonths`, `lv_jwdates`, `lv_jwdates_end`, `lv_jpembahanan`, `lv_jproduksi`, `lv_jreadyassy`, `lv_jselesai`) yang di-embed ke `<script>` inline sebagai `weekLabels`, `weekDates`, `weekDatesEnd`, `chartGran`, `chartGranLabel`, `pembahananCounts`, `produksiCounts`, `readyAssyCounts`, `selesaiCounts` + versi skalar utk donut. `js/js.js` membaca variabel global ini.

---

## 2. `main.htm` — Gerbang Autentikasi

**Tidak membaca tabel apa pun.** Hanya:
- `sy-uname` — bila kosong panggil `navigation->vhost_authentication( )` lalu `RETURN`.

---

## 3. `monitoring.htm` — Daftar SO + Monitoring Progres

### Parameter input (GET)
| Parameter | Perlakuan |
|---|---|
| `so_num` | `CONVERSION_EXIT_ALPHA_INPUT` (zero-pad) → range `EQ` **dan** `CP '*input*'` (substring) |
| `item_num` (D24) | Filter POSNR: exact zero-padded (`10`→`000010`) **atau** pattern `CP '*input*'`; diterapkan di ABAP atas `lt_temp_vbap`, lalu SO tanpa item tersisa ikut dihapus |
| `cust_num` | Sama seperti so_num (ALPHA + EQ + CP) pada KUNNR |
| `cust_name` | Diabaikan bila `cust_num` terisi. `KNA1 WHERE mcod1 LIKE '%NAMA%'` (upper-case) → daftar kunnr `EQ`. Tanpa hasil → `lv_name_no_match` = daftar SO pasti kosong |
| `date_from` / `date_to` | Batas `VBAK-ERDAT`. Default: 30 hari terakhir. **Kecuali** bila mencari by `so_num`/`item_num` tanpa tanggal → `date_from = '19000101'` (dokumen lama tetap ketemu) |

### Urutan query
1. `KNA1` (%SAMPLE%) → exclude range.
2. **Header** `VBAK` (vbeln, erdat, auart, kunnr): `erdat BETWEEN … AND vbeln IN lr_vbeln AND kunnr IN lr_kunnr AND vbeln IN (SELECT vbeln FROM vbap WHERE werks='2000')`.
3. **Nama customer** `KNA1` FOR ALL ENTRIES header.
4. **Item** `VBAP` (vbeln, posnr, matnr) `werks='2000'` (+ filter item_num D24).
5. **Order utama** `AFPO` (konsep bersama §1).
6. **Order bertahap** `AFPO ⨝ AFKO` + ladder D23 + scope D22 (§2–4).
7. **Ringkasan per SO** — `COLLECT` ke `lt_so_stat` (total, pembahanan, produksi, readyassy, selesai per vbeln).
8. **SO tanpa item ber-tahap dihapus** dari daftar sidebar.
9. Sort final: `erdat DESC, vbeln DESC`.

### Status label per kartu SO (sidebar)
Prioritas dari `lt_so_stat`:
- `selesai = total (>0)` → **Selesai** (hijau)
- `readyassy > 0 OR selesai > 0` → **Ready Assy** (biru)
- `produksi > 0` → **Produksi** (kuning)
- selain itu → **Pembahanan** (abu)

### Panel kanan
Tidak diisi dari halaman ini — dimuat AJAX oleh `js.js` `viewDetails(vbeln)` dari `monitoring_detail.htm`.

---

## 4. `monitoring_detail.htm` — Fragment Detail SO (AJAX, ringan)

URL: `monitoring_detail.htm?vbeln=XXXXXXXXXX` — mengembalikan **fragmen HTML** (tanpa html/head/body). D26: sistem checkpoint 229K lama (RESB+MSEG via `item_cp_status`) sudah **tidak dipakai** — hanya AFPO⨝AFKO.

### Urutan query
1. `vbeln` di-ALPHA-pad.
2. **Header** — `SELECT SINGLE vbeln erdat auart kunnr netwr waerk FROM vbak`.
3. **Customer** — `SELECT SINGLE kunnr name1 ort01 FROM kna1`.
4. **Item** — `VBAP` (vbeln, posnr, matnr, arktx) `werks='2000'`.
5. **Order utama** `AFPO` (§1) + **order bertahap** `AFPO ⨝ AFKO` + ladder D23 + scope D22.

### Data yang tampil
| Elemen | Sumber |
|---|---|
| Info Order (No SO, Tgl, Tipe, Kode+Nama Customer, Kota, Nilai) | `VBAK` + `KNA1`; Nilai hanya bila `netwr > 0` (diformat `cur-fmt` oleh JS) |
| Badge **Status SO** | Ladder yang sama dgn monitoring.htm: Selesai / Ready Assy / Produksi / Pembahanan / "Di Luar Scope" (tak ada item lolos D22) |
| KPI Ringkasan (Total Item, Pembahanan, Produksi, Ready Assy, Selesai) | Hitungan `stage` per item dari `lt_item_stage`; item luar scope di-skip |
| Tab "Item & BOM" dan "Butuh Dikirim" | **Kosong** saat dirender — `data-vbeln` + `data-loaded=0`, diisi lazy oleh js.js dari `monitoring_bom.htm` |

---

## 5. `monitoring_bom.htm` — Fragment Item & BOM / Butuh Dikirim (AJAX, berat)

URL:
- `monitoring_bom.htm?vbeln=X` → tab **Item & BOM** (scope Produksi + Ready Assy: `GA1/GA2/EB2/CH1`)
- `monitoring_bom.htm?vbeln=X&mode=kirim` → tab **Butuh Dikirim** (scope Pembahanan: `WM1/WM2/PN1/PN2`)

**Satu jalur kode untuk kedua tab (D6)** — yang berbeda hanya sub-range DISPO (`lr_dispo`, diambil dari `wf_dispo_range()` lalu difilter per mode, D10), judul tabel (`lv_bom_title`), dan prefiks id DOM (`lv_id_prefix = 'k-'` utk mode kirim).

### Urutan query
| Step | Query | Keterangan |
|---|---|---|
| 1 | `VBAP` (vbeln, posnr, matnr, arktx, kwmeng, vrkme), `werks='2000'` | Item SO |
| 2 | `AFPO ⨝ AFKO` (kdauf,kdpos,psmng,wemng,meins,aufnr,**pwerk**,dispo) `WHERE dispo IN lr_dispo` | Order komponen per scope tab. Diberi `stage_rank`/`stage_lbl` dari DISPO (fallback dari PWERK). `SORT kdauf kdpos stage_rank aufnr` + **dedup `COMPARING kdauf kdpos aufnr` (D20** — order multi-POSNR menduplikasi baris) |
| 2b | `AFPO` per (vbeln,posnr,**matnr**) **tanpa filter apa pun** | **Order UTAMA (D5)** — basis Target/Hasil GR/Progres baris item header. Sengaja tanpa filter DISPO/plant |
| — | Driver `lt_aufnr_drv` = aufnr order komponen ∪ order utama | Untuk step 3/3b |
| 3 | `AFKO` (aufnr, aufpl, gstrp, gltrp, getri) | Tanggal Basic Start/Finish, Actual Finish |
| 3b | `AUFK` (aufnr→objnr) → `JEST` (`inact=' '`) | Status sistem order: prioritas `I0045` TECO=4 > `I0009` CNF=3 > `I0002` REL=2 > CRTD=1 |
| 3c | `RESB` (aufnr, matnr, werks, lgort, bdmng, meins) FOR ALL ENTRIES `lt_afpo_pre` | Daftar Komponen gaya COOIS. **Filter `xloek=' '` DIHAPUS (D19)** — order tuntas punya RESB berstatus deleted, tanpa ini SO selesai tampak kosong. Baris matnr kosong dibuang |
| 3d | `zcl_cs_util=>pmb_output_status( lt_pmbkey )` — **hanya mode=kirim** | Nasib fisik material (GR/QC/konsumsi/kirim) per key (kdauf, kdpos, matnr) dari MSEG. D7 v2: dihitung utk SEMUA komponen (AFPO-WEMNG terbukti tak mewakili GR aktual) |
| 3e | `AFKO-AUFPL → AFVC` (operasi pertama = vornr terkecil per aufpl) `→ CRCO` (`objid=arbid, kokrs='PC01', begda<=sy-datum<=endda`) → `KOSTL` → `wf_line_name()` | **Badge "Line"** (Unit Wood Furniture) per order wakil item; hasil: nama line (`ln-wf`), "Unit lain", atau "Belum ada operasi" |
| 4 | Gabung VBAP + order utama | psmng/wemng dijumlah **hanya lintas order utama**; order wakil = order utama dgn rasio GR/target **terendah** |
| 5 | `MAST` (matnr, werks='2000') → `STPO` (stlnr→idnrk, menge, meins) | **Fallback BOM master** utk item TANPA order produksi |
| 6 | `MAKT` (spras=sy-langu) driver = matnr RESB ∪ idnrk STPO | Nama material |
| 7 | `MARD` (`werks='2000'`, `labst>0`, COLLECT per matnr) + `EKPO` (`loekz=' '`, `elikz=' '`) → `EKET` (open qty = menge−wemng, ETA = eindt terawal) | **Hanya utk fallback BOM master** — data tooltip stok/open PO |

### Data yang tampil per baris item (header)
| Kolom | Sumber |
|---|---|
| Item / Material # / Deskripsi | `VBAP-POSNR / MATNR / ARKTX` |
| Qty SO | `VBAP-KWMENG` + `VRKME` |
| **Target** | Σ `AFPO-PSMNG` order **UTAMA** saja (D5 — bukan dijumlah dgn order komponen) |
| **Hasil GR** | Σ `AFPO-WEMNG` order UTAMA |
| **Progres** | `wemng/psmng×100` (cap 100), kelas warna dari `zcl_cs_util=>prog_bar_class/prog_txt_class`; tanpa order = "No Prod" |
| Badge status + "Target: dd/mm/yyyy" | JEST order wakil + `AFKO-GLTRP` |
| Badge Line | Rantai 3e |
| **D9**: item punya order utama tapi NOL komponen RESB di scope tab → seluruh baris item **disembunyikan** | |

### Data per baris komponen (expand)
Tahap+DISPO, `AFPO-AUFNR`, `RESB-MATNR`, `MAKT-MAKTX`, Target/Delivered Qty per ORDER (`AFPO-PSMNG/WEMNG`), Progres per order. Expand detail: System Status (JEST), Kuantitas (`RESB-BDMNG`), Basic Start/Finish (`AFKO-GSTRP/GLTRP`), Actual Finish (`AFKO-GETRI`). Mode kirim menambah blok **Status Pergerakan Material**: qty_gr, qty_qc, qty_wait, qty_used (per order konsumen), qty_sent (per SLoc tujuan) dari `pmb_output_status` (MSEG).

---

## 6. `riwayat.htm` — Arsip SO Selesai

### Parameter input
`so_num`, `cust_num`, `cust_name`, `date_from`, `date_to` — perlakuan identik monitoring.htm, **kecuali**:
- **D18**: filter tanggal **opsional tanpa default** — tanpa input, `date_from='19000101'` s/d `sy-datum` (seluruh riwayat).

### Urutan query
Identik monitoring.htm langkah 1–7 (VBAK → VBAP → AFPO order utama → AFPO⨝AFKO ladder D23 → D22 → `COLLECT lt_so_stat`), plus `VBAK-NETWR/WAERK` ikut dibaca untuk tampilan nilai SO.

### Filter inti (pembeda dari monitoring)
```abap
" default: HANYA SO yang SEMUA item-nya stage=4 (selesai = total)
" KECUALI pencarian by so_num → lv_keep_incompl = X (SO belum tuntas tetap tampil)
```
- SO tanpa item ber-stat (total=0) selalu dihapus.
- SO lengkap → kartu hijau "Selesai", klik = `viewDetails()` (panel AJAX detail sama dgn monitoring).
- SO belum lengkap (hanya muncul saat cari by nomor SO) → kartu "in-progress" dengan label tahap dominan + link redirect ke `monitoring.htm?so_num=…`; menampilkan `selesai/total item tuntas`.

---

## 7. `transfer.htm` — Transfer Material 1D00 → 2KCS *(disembunyikan dari navbar, D25)*

Model rekonsiliasi per material: `Butuh = Σ(RESB.BDMNG − RESB.ENMNG)` open; `Perlu Kirim = max(0, Butuh − Stok 2KCS)`; `Diterima 2KCS = CP1`.

### Parameter input
| Parameter | Fungsi |
|---|---|
| `matnr` | Filter substring material (CP, upper-case) — diterapkan di ABAP |
| `so_num` | ALPHA-pad → `AFPO WHERE kdauf = SO` → range `lr_aufnr` utk RESB; SO tanpa order = hasil kosong |
| `status` | `''` semua / `'need'` (perlu>0) / `'ok'` (perlu=0) |
| `page` | Pagination server-side, 50 baris/halaman (`lc_page_size`) |

### Cache (POIN 7)
Path default (tanpa filter SO) di-cache di **cluster INDX** `ID 'TRANSFER_V3'`, TTL 600 detik (`lc_cache_ttl`). Filter matnr/status diterapkan di ABAP atas snapshot. Versi ID dinaikkan bila struktur/makna berubah.

### Urutan query (saat cache miss)
1. **RESB** (matnr, meins, bdmng, enmng, aufnr, bdter): `werks='2000' AND xloek=' ' AND kzear=' ' AND aufnr IN lr_aufnr`. Open qty (`bdmng>enmng`) disaring di loop (Open SQL klasik tak bisa banding kolom-kolom).
2. **Scope Wood Furniture** — `zcl_cs_util=>wf_order_filter( )` (rantai AFKO→AFVC→CRCO→whitelist cost center); order tanpa routing/cost center valid TIDAK lolos. Komponen order Chair/Metal/DRW tersaring keluar.
3. Agregasi per material: Σ open qty, `aufnr` wakil pertama, `bdter` paling awal.
4. **AFPO** (aufnr→kdauf) → kolom SO.
5. **MAKT** → nama material.
6. **MARD** — stok `2000/2KCS` (stok_dst) dan `1000/1D00` (stok_src), dijumlah di loop.
7. **MSEG ⨝ MKPF** — kolom **"Diterima 2KCS" = definisi CP1 persis**:
   - `werks='2000' AND lgort='2KCS' AND bwart IN transfer_bwarts()` (301/311, tanpa horizon tanggal)
   - `SHKZG='S'` → tambah (+ catat `budat`/`mblnr` terakhir)
   - `SHKZG='H'` **hanya dikurangi bila `umwrk='1000'`** (retur balik); 'H' ke SLoc hilir (2261 dst) = kemajuan, **diabaikan**.
8. Status per material: `Tercukupi` (perlu=0) / `Akan Dikirim` (stok 1D00 cukup) / `Kurang Stok 1D00`.

### KPI & sort
`lv_cnt_need` (perlu>0), `lv_cnt_short` (kurang stok), total; sort `bdter DESC, matnr ASC`. Catatan: filter "sembunyikan stok_src<=0" sedang **dinonaktifkan** (diagnosa).

---

## 8. `diag_movement.htm` — Diagnostik Gerakan Material (Fase 0, sekali pakai)

Tidak ditautkan di navbar; alat verifikasi asumsi Checkpoint Engine. Input: `matnr` (wajib utk A/B/C, opsional utk B2/D/E), `date_from`/`date_to` (default 180 hari), hidden `go=1` (guard agar buka halaman saja tidak memicu scan berat).

| Section | Query | Isi |
|---|---|---|
| **A** | `MARD` per matnr, werks 1000/2000 | Snapshot stok semua SLoc |
| **B** | `MSEG ⨝ MKPF` per matnr + rentang tgl, werks 1000/2000 | Ringkasan per `bwart`: hitungan + contoh rute; nama SLoc dari `T001L` |
| **B2** | `MSEG ⨝ MKPF` **GROUP BY di DB** (lgort, umlgo, bwart, shkzg → COUNT/SUM) `WHERE lgort IN pipeline OR umlgo IN pipeline` (`pipeline_slocs()`: 2KCS/2261/2262/22F2/22F3/229K) | Frekuensi movement per rute SLoc — populasi (matnr opsional). Dasar keputusan final movement type CP |
| **C** | (data B) baris mentah | Daftar gerakan: tgl, bwart, dari→ke, SHKZG, qty |
| **C2** | `T001L` werks 2000 & 1000 (2000 menang bila dobel) | Kamus nama semua SLoc yang muncul di B2 |
| **D** | `MSEG ⨝ MKPF` mentah (cap 200.000 baris) → rantai `AFKO→AFVC→CRCO→wf_line_name()` | Ringkasan B2 **khusus Wood Furniture**. Aturan scope: (1) baris ber-aufnr masuk hanya bila order lolos whitelist WF; (2) baris transfer tanpa aufnr masuk bila matnr pernah muncul di order WF (⚠️ over-include material campuran — D = batas atas) |
| **E** | `MSEG ⨝ MKPF` 30 hari (kolom + `kdauf`, `kdpos`, `sobkz`), scope WF sama dgn D | Vonis "bisakah pipeline dipilah per SO": hitung baris ber-KDAUF, SOBKZ='E', anonim; **angka penentu** = baris transfer 301/311 ber-KDAUF (`lv_e_trfkd`); verdict otomatis (STOK ANONIM / SALES-ORDER STOCK / CAMPURAN) + 25 contoh baris |

---

## 9. `maintenance.htm` — Halaman Pemeliharaan

Halaman **mandiri** (tanpa css/js eksternal). Tidak membaca tabel bisnis apa pun:
- Konstanta hard-coded: `lc_end_date`, `lc_end_time`, `lc_contact`.
- `sy-datum`/`sy-uzeit` → sisa detik countdown (dikirim ke JS inline).
- `sy-sysid`, `sy-uname` → footer.

---

## 10. Peran `ZCL_CS_UTIL` sebagai Sumber Kebenaran

Halaman **tidak menulis literal** SLoc/movement type/MRP — semuanya dari class:

| Method / Konstanta | Dipakai halaman | Isi |
|---|---|---|
| `wf_dispo_range( )` | index, monitoring, monitoring_detail, monitoring_bom, riwayat | Range MRP whitelist: WM1/WM2/PN1/PN2/GA1/GA2/EB2/CH1 |
| `fmt_date( )` | semua | `DD/MM/YYYY` |
| `prog_bar_class( )` / `prog_txt_class( )` / `css_pct( )` | monitoring_bom | Pemetaan % → kelas warna CSS (satu-satunya sumber ambang 100/70/45/20) |
| `pmb_output_status( )` | monitoring_bom (mode=kirim) | Nasib fisik material dari MSEG: GR/QC/wait/consumed/sent per (kdauf,kdpos,matnr) |
| `wf_line_name( kostl )` | monitoring_bom, diag_movement | Whitelist 10 cost center Wood Furniture → nama line |
| `wf_order_filter( aufnr_tab )` | transfer, diag_movement (E) | Saring order lolos whitelist WF (batched AFKO→AFVC→CRCO) |
| `pipeline_slocs( )` | diag_movement | Range SLoc pipeline 2KCS/2261/2262/22F2/22F3/229K |
| `transfer_bwarts( )` | transfer | Range bwart 301/311 (321 tak pernah ikut) |
| `gc_plant_1000/2000`, `gc_sloc_1d00/2kcs/…`, `gc_bwart_301/311`, `gc_shkzg_s`, `gc_kokrs` | transfer, monitoring_bom, diag_movement | Konstanta plant/sloc/movement/controlling area |
| `dot_stages( )`, `cp_qty( )`, `item_cp_status( )`, `wf_route_status( )` | *(mesin checkpoint lama — tidak lagi dipanggil dari halaman mana pun setelah D26)* | |

---

*Dokumen dibuat 2026-07-17 berdasarkan pembacaan langsung seluruh source di `ZBSP_CS_APP/`.*
