# Rencana Pengembangan index3.htm — Perbaikan #1–#6 (+ diskusi #7)

> Target: `ZBSP_CS_APP/Page with Flow Logic/index3.htm` (halaman pelacakan per SO+Item).
> Tanggal: 2026-07-22. #1–#6 siap dikembangkan; #7 dibahas terpisah (belum masuk plan).
> Catatan uji: BSP tak bisa dites di luar SAP → verifikasi = aktivasi SE80 + eyeball.

---

## Prasyarat (bukan bagian dari 6, tapi wajib lebih dulu)

**P0 — Arahkan self-reference ke index3.htm.** Saat ini index3 masih menunjuk
`index.htm` di 12 titik (form action, link Reset/Selesai/Kembali, `userLogout`,
selector reset sessionStorage). Kalau tidak diperbaiki, submit filter/form
Transfer akan melompat ke index.htm. Ganti `index.htm` → `index3.htm` pada semua
titik fungsional (bukan komentar), dan `STORE_KEY` → `'pelacakan3_trs_form'`.

---

## #1 — Hilangkan leading zeros pada nomor material

**Masalah:** matnr tampil 18 digit (`000000000020086291`); diinginkan `20086291`.

**Solusi:** panggil `CONVERSION_EXIT_MATN1_OUTPUT` di ABAP **sebelum** dikirim ke
HTML (pola sama dengan `CONVERSION_EXIT_CUNIT_OUTPUT` untuk satuan yang sudah ada).
Konversi di loop enrichment yang sudah ada, sekali per baris:

| Field | Lokasi konversi | Catatan |
|---|---|---|
| `<o>-matnr` (order) | loop enrich MAKT `lt_ord` | display-only → aman dikonversi in-place |
| `<bc>-idnrk` (komponen BOM) | loop enrich `lt_bomcomp` | display-only |
| `<s>-matnr` (stok) | loop enrich `lt_stok` | display-only |
| `<h>-matnr` (riwayat) | loop enrich `lt_hist` | dipakai juga di `data-hist-mat` (filter JS) → konversi tetap konsisten |
| `ls_vbap_hdr-matnr` (info) | setelah SELECT SINGLE VBAP | display-only |

**⚠️ Kekecualian penting — form Transfer Posting:** `ls_trs_row-matnr` dipakai di
**hidden field `trs_matnr`** yang dikirim ke `BAPI_GOODSMVT_CREATE` (butuh format
ter-pad). Jangan konversi field itu. Untuk kolom yang **terlihat**, tambah field
baru `matnr_disp` di `ty_trs_row`, isi dengan hasil MATN1_OUTPUT, dan tampilkan
`matnr_disp` di sel; hidden `trs_matnr` tetap `matnr` (ter-pad).

**Snippet pola:**
```abap
CALL FUNCTION 'CONVERSION_EXIT_MATN1_OUTPUT'
  EXPORTING input  = <o>-matnr
  IMPORTING output = <o>-matnr.
```

---

## #2 — Form Transfer Posting terlalu memakan ruang

**Masalah:** panel kanan (~40%) menyempitkan tabel data utama → harus scroll kanan.

**Solusi (rekomendasi): panel kanan collapsible + mode.** Dua lapis:
1. **Toggle lipat**: tombol "◀ Sembunyikan Transfer" / "Transfer Posting ▶". Saat
   dilipat, panel kanan `display:none` dan kolom kiri melebar ke **100%**
   (ubah `width:60%` → auto / full). Status lipat disimpan di `localStorage`
   supaya menetap antar reload.
2. **Mode (opsional, di atas toggle):** radio "Mode Monitoring" (default, panel
   Transfer tersembunyi, tabel full-width) vs "Mode Transaksi" (panel Transfer
   tampil). Mode Monitoring = orang yang cuma memantau tak terganggu form input.

**Mekanisme teknis:** layout saat ini pakai `display:table` 60/40. Ganti ke
**flex** (`.pel-main{display:flex}` kiri `flex:1`, kanan `width:380px`), lalu JS
toggle menambah class `.trs-collapsed` pada kontainer → kanan `display:none`,
kiri otomatis penuh. Tidak mengubah logika ABAP sama sekali.

**Alternatif** (kalau tak mau collapsible): pindah seluruh Transfer Posting ke
**tab tersendiri** ("Transfer") di deretan tab — tabel utama selalu full-width.
Rekomendasi tetap collapsible karena transfer sering dipakai berdampingan.

---

## #3 — Jargon SAP di header kolom (tooltip penjelas)

**Masalah:** "Unrestr.", "Qual.Insp", "Blocked", "Target QTY", "Del QTY", "Sloc"
tak dimengerti orang awam.

**Solusi:** tambah **tooltip** pada `<th>` via atribut `title` (native, aksesibel,
nol JS) + tanda visual kecil (garis bawah titik-titik / ikon ⓘ) agar terlihat bisa
di-hover. Definisi awam yang diusulkan:

| Kolom | title (tooltip) |
|---|---|
| Unrestr. | "Stok bebas dipakai — sudah lolos QC, siap digunakan/kirim." |
| Qual.Insp | "Stok dalam Inspeksi Kualitas — menunggu pemeriksaan QC." |
| Blocked | "Stok diblokir — tidak boleh dipakai (mis. rusak/ditahan)." |
| Target QTY | "Jumlah yang direncanakan diproduksi pada order ini." |
| Del QTY | "Jumlah yang sudah selesai/diterima dari order ini." |
| Progres | "Persentase Del QTY terhadap Target QTY." |
| Sloc | "Storage Location — lokasi penyimpanan di dalam plant." |

**CSS penanda:** `th[title]{ text-decoration:underline dotted; cursor:help; }` atau
tambah `<span class="hdr-hint">ⓘ</span>` dengan `title`.

---

## #4 — Urutan tab

**Sekarang:** Pembahanan · Produksi · Riwayat · Stok · Info Order (tab-pmb aktif).
**Target:** **Info Order · Pembahanan · Produksi · Stok Saat Ini · Riwayat Pergerakan.**

**Solusi:** susun ulang 5 tombol `<button pelTab(...)>` sesuai urutan target,
pindahkan class `active` ke tombol **Info Order**, dan pindahkan class `active`
pada `<div class="tab-pane">` dari `tab-pmb` ke `tab-info`. (Konten pane tak
berubah; JS `pelTab` tetap.) Perhatikan **Stok sebelum Riwayat** (beda dari urutan
sdebelumnya).

---

## #5 — Tambah Status di Info Sales Order

**Masalah:** status pemrosesan (setara "Overall Status" di VA03) belum tampil,
padahal sudah dihitung.

**Data:** sudah ada di ABAP (D36):
- `lv_hdr_stat_lbl` ← **VBUK-GBSTK** (Overall status SO/header).
- `lv_itm_stat_lbl` ← **VBUP-GBSTA** (Overall status per **item** — inilah yang
  tampil di VA03 kolom "Overall Status" tiap item). Domain STATV: A=Belum, B=Sebagian, C=Selesai.

**Solusi:** tambah `info-field` di bagian **Info Sales Order** (dan Info Item)
menampilkan status sebagai **badge berwarna DENGAN tooltip penjelas** (atribut
`title`, sama seperti #3 — agar orang awam paham arti tiap status, bukan cuma warna):

| Status (GBSTA/GBSTK) | Warna | Tooltip (`title`) |
|---|---|---|
| C — Selesai Diproses | 🟢 hijau | "Seluruh proses untuk item/SO ini sudah selesai (mis. sudah dikirim penuh)." |
| B — Sebagian Diproses | 🟡 kuning | "Sebagian proses sudah berjalan, tapi belum tuntas seluruhnya." |
| A — Belum Diproses | ⚪ abu | "Belum ada proses yang berjalan untuk item/SO ini." |

Teks tooltip dipetakan di ABAP berbarengan dengan label (satu `CASE gbsta`), disimpan
di `lv_itm_stat_tip` / `lv_hdr_stat_tip`, lalu ditulis ke atribut `title`:

```html
<div class="info-field">
  <div class="info-field-lbl">Status Item (Overall)</div>
  <div class="info-field-val"><span class="stat-badge stat-<%= ls_vbup_item-gbsta %>" title="<%= lv_itm_stat_tip %>"><%= lv_itm_stat_lbl %></span></div>
</div>
```
CSS badge: `.stat-badge{cursor:help;}` `.stat-C{background:#dcfce7;color:#15803d} .stat-B{background:#fef3c7;color:#92400e} .stat-A{background:#f3f4f6;color:#4b5563}`.

**Catatan akurasi:** kalau ternyata "Overall Status" VA03 di sistem Anda berasal
dari kombinasi status lain (bukan murni GBSTA), lapor — mudah disesuaikan (D36
sudah mengantisipasi ini).

---

## #6 — Dua Pie/Donut Chart di Info Order (Pembahanan & Produksi)

**Permintaan:** 2 chart, persentase = **rata-rata keseluruhan progress** order tiap
tahap (Pembahanan = Plant 1000; Produksi = Plant 2000).

**Hitung (ABAP):** loop `lt_ord`, akumulasi progress per order (`wemng/psmng*100`,
di-cap 100) terpisah per plant, lalu rata-rata:
```abap
" per order: prog = wemng/psmng*100 (skip psmng=0)
" lv_avg_pmb = Σprog(plant1000) / jml_order_ber-target(plant1000)
" lv_avg_prd = Σprog(plant2000) / jml_order_ber-target(plant2000)
```
Simpan `lv_avg_pmb`, `lv_avg_prd` (TYPE i / p).

**Render:** **SVG donut** server-side (bukan library). Satu ring per tahap: arc
terisi = persen, angka besar di tengah. Ditaruh berdampingan di atas/So bagian Info
Order. Warna pinjam pemetaan progress yang ada (`zcl_cs_util=>prog_bar_class`) atau
biru tunggal.

> Catatan desain: untuk **satu rasio** (satu %), bentuk yang tepat adalah **radial
> gauge/donut**, bukan pie beririsan banyak — persis "pie progress" yang Anda
> maksud. Saat membangun, saya terapkan panduan `dataviz` (SVG, arc dihitung dari
> keliling, tetheme light/dark, angka pakai tabular-nums).

**Kosong-state:** kalau tak ada order ber-target di suatu tahap → tampilkan "Belum
ada data" alih-alih 0%.

---

## Urutan kerja yang disarankan

1. **P0** self-ref → index3.htm (fondasi).
2. **#4** urutan tab (cepat, kelihatan).
3. **#1** leading zeros (sentuh banyak titik, tapi mekanis).
4. **#3** tooltip header.
5. **#5** status badge.
6. **#6** donut Pembahanan/Produksi.
7. **#2** collapsible Transfer (paling banyak sentuh layout).

Tiap langkah: edit → aktivasi SE80 → eyeball. Commit menunggu instruksi Anda.

---

## #7 — Status aktual komponen BOM (FINAL, siap dikembangkan)

**Tujuan:** saat komponen BOM ditampilkan (klik material di tab Pembahanan/Produksi),
tiap komponen menunjukkan **status aktual**: sudah tersedia di lokasi rakit, masih
di KMI 1, sedang dibuat, atau belum ada.

### Keputusan (hasil diskusi 2026-07-22)
- **Transfer 1-langkah (301/311)** → stok pindah instan, **tidak ada in-transit**.
  Konsekuensi: **tidak ada status "sedang dikirim"** sebagai keadaan stok; komponen
  hanya "masih di KMI 1" atau "sudah di KMI 2". (Penanda transien "baru dikirim
  hari ini" = fase 2.)
- **Fokus buat saja** → cek order produksi komponen (AFKO) untuk "sedang dibuat";
  **tidak** menggali PO pembelian.
- **Semua stok** → gabung MSKA (SO-stock, SOBKZ='E', vbeln=SO) + MARD (stok bebas).

### Model status v1 (relatif terhadap plant tab aktif: Pembahanan=1000, Produksi=2000)

| Badge | Status | Aturan |
|---|---|---|
| 🟢 hijau | **Sudah di lokasi rakit** | stok komponen > 0 di **plant tab** (7 SLoc) |
| 🟡 kuning | **Masih di KMI 1** | stok komponen > 0 di **Plant 1000** & plant tab = 2000 |
| 🔵 biru | **Sedang dibuat** | tak ada stok, tapi ada order produksi komponen terbuka (wemng<psmng) di Plant 1000 |
| 🔴 merah | **Belum tersedia** | tak ada stok & tak ada order terbuka |

Prioritas evaluasi: 🟢 → 🟡 → 🔵 → 🔴. Untuk tab Pembahanan, 🟡 praktis tak muncul.

**Fase 2 (ditunda):** ⚪ "Terpakai" (MSEG 261/RESB), penanda "baru dikirim hari ini",
dan **qty coverage "tersedia X / butuh Y"** (butuh = qty dasar BOM STKO-BMENG × qty order).

### Data & query (batched, server-side, nol query per-baris)
Komponen BOM sudah dirender penuh saat load → hitung status semua komponen sekaligus:
1. Kumpulkan semua `idnrk` unik dari `lt_bomcomp`.
2. **1× SELECT MSKA** (matnr IN idnrk, vbeln=SO, sobkz='E') → stok SO per plant.
3. **1× SELECT MARD** (matnr IN idnrk) → stok bebas per plant.
4. **1× SELECT AFPO⨝AFKO** (matnr IN idnrk, pwerk=1000, wemng<psmng) → order terbuka.
5. Agregasi ke lookup per material: `stk_1000`, `stk_2000`, `has_order`.

### Struktur & penentuan
Tambah field di `ty_bomcomp`: `parent_pwerk`, `status_lbl`, `status_cls`, `status_tip` (tooltip penjelas + detail qty/lokasi).
- Saat build BOM, set `parent_pwerk` dari order pemilik `stlnr`.
- Saat enrich, derive badge:
```abap
" P = parent_pwerk; look up stok komponen
IF stk_at_P > 0.            status = 'Sudah di lokasi rakit' (hijau).
ELSEIF P = '2000' AND stk_1000 > 0. status = 'Masih di KMI 1' (kuning).
ELSEIF has_order = 'X'.     status = 'Sedang dibuat' (biru).
ELSE.                       status = 'Belum tersedia' (merah).
ENDIF.
```

### Tampilan
- Kolom baru **"Status"** di tabel Komponen BOM (setelah kolom Unit).
- Badge kecil berwarna, reuse gaya `.mv-badge`, `cursor:help`.
- **Tooltip per warna (`title`)** — WAJIB, agar orang awam paham arti tiap warna,
  bukan cuma melihat warna. Isi tooltip = **penjelasan status + detail aktual
  (qty/lokasi)**:

| Badge | Tooltip (`title`) = penjelasan + detail |
|---|---|
| 🟢 Sudah di lokasi rakit | "Stok komponen sudah ada di plant tempat rakitan dikerjakan. — Tersedia 8 di 2000/2KCS" |
| 🟡 Masih di KMI 1 | "Stok komponen masih di Plant 1000 (Pembahanan), belum dikirim ke lokasi rakit. — Tersedia 12 di 1000/1D00" |
| 🔵 Sedang dibuat | "Belum ada stok, tapi ada order produksi komponen yang masih berjalan. — Order 000123456, 60% selesai" |
| 🔴 Belum tersedia | "Tidak ada stok & tidak ada order produksi terbuka untuk komponen ini." |

Bagian penjelasan (kalimat pertama) dipetakan di ABAP berbarengan dengan penentuan
badge (`status_tip`); bagian detail (qty/lokasi/order) dirakit dari hasil agregasi.
Kedua bagian digabung ke `<bc>-status_tip` lalu ditulis ke `title`.

### Catatan
- Stok komponen SO: MSKA di-scope `vbeln = SO` (make-to-order). Kalau ternyata
  komponen make-to-stock (anonim, tanpa SO), MARD bebas yang menangkapnya.
- Performa: 3 SELECT batched atas daftar `idnrk` — ringan.
- Verifikasi: silang-cek badge dgn MMBE (posisi stok komponen) & COOIS (order komponen).
