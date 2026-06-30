# Update Monitoring — Konsistensi Status & Kecepatan Detail SO

> Ditulis **30 Juni 2026** berdasarkan pembacaan menyeluruh kode terkini:
> `monitoring.htm`, `monitoring_detail.htm`, `riwayat.htm`, `index.htm`, `classes/ZCL_CS_UTIL.abap`, `MIMEs/js/js.js`.
> Dokumen ini fokus pada dua keluhan:
> 1. **Inkonsistensi status & progress bar** antara *Daftar Sales Order* (sidebar) dan *Ringkasan* detail.
> 2. **Lambatnya** tampil detail SO (beberapa detik) setelah klik kartu di Daftar SO.

---

## 0. Ringkasan Temuan (TL;DR)

| # | Masalah | Akar Penyebab | Dampak | Perbaikan Inti |
|---|---------|---------------|--------|----------------|
| 1 | SO tampil **Selesai / 100%** di sidebar, tapi **Proses / 0%** di Ringkasan | AFPO **tidak diagregasi** per item. Tiap halaman mengambil **satu baris AFPO** lewat `READ TABLE … BINARY SEARCH`. Jika satu item SO punya **>1 order produksi**, baris yang terbaca **berbeda** antar query → klasifikasi beda | Status & % bertentangan antar tampilan; KPI tidak bisa dipercaya | Agregasi `psmng`/`wemng` per item (`COLLECT` by `kdauf`/`kdpos`) di **semua** tampilan, sama persis seperti `riwayat.htm` |
| 2 | Detail SO butuh beberapa detik untuk muncul | Endpoint AJAX `monitoring_detail.htm` mengeksekusi **±13 query** sinkron, termasuk seluruh rantai BOM (MAST→STPO→MAKT→MARD→EKPO→EKET) & status order (AFKO/AUFK/JEST) — padahal tab default adalah **Ringkasan** yang tidak butuh data itu | Tunggu lama tiap klik, walau pengguna tidak membuka tab Item & BOM | **Lazy-load**: detail ringan (4 query) tampil instan; rantai BOM dipindah ke endpoint terpisah yang baru dimuat saat tab *Item & BOM* diklik |

Keduanya **saling terkait**: keduanya berasal dari tab Item & BOM/BOM-chain dan dari cara AFPO dibaca. Memperbaiki keduanya sekaligus = satu paket pekerjaan.

---

## 1. Analisis Masalah #1 — Inkonsistensi Status & Progress Bar

### 1.1 Apa yang terjadi di layar

- **Daftar Sales Order** (`monitoring.htm`): satu SO berlabel **Selesai** (hijau, border `so-border-done`) dengan bar **100.00%**.
- Setelah diklik, **Ringkasan** (`monitoring_detail.htm`): KPI `Selesai = 0`, status item **Proses**, bar keseluruhan **0.00%**.

Padahal **logika klasifikasinya identik** di kedua file:

`monitoring.htm:214-229` (sidebar, per item, lalu `COLLECT` per SO):
```abap
IF ls_item_row-psmng > 0.
  lv_stat_pct = ( ls_item_row-wemng / ls_item_row-psmng ) * 100.
  IF lv_stat_pct >= 100. ls_so_stat-done = 1.
  ELSE.                  ls_so_stat-inprog = 1. ENDIF.
ELSE.
  ls_so_stat-noprod = 1.
ENDIF.
```

`monitoring_detail.htm:229-238` (Ringkasan):
```abap
IF ls_item_row-psmng > 0.
  lv_prog = ls_item_row-wemng * 100 / ls_item_row-psmng.
  IF lv_prog >= 100. lv_tot_done  = lv_tot_done  + 1.
  ELSE.              lv_tot_inprg = lv_tot_inprg + 1. ENDIF.
ELSE.
  lv_tot_noprd = lv_tot_noprd + 1.
ENDIF.
```

Karena rumusnya sama, satu-satunya cara hasilnya berbeda adalah **`psmng`/`wemng` yang masuk berbeda**. Di situlah akar penyebabnya.

### 1.2 Akar penyebab: AFPO dibaca satu baris, tanpa agregasi

Satu **item SO** (`AFPO-KDAUF` = nomor SO, `AFPO-KDPOS` = posisi item) **bisa memiliki lebih dari satu order produksi** (`AFPO-AUFNR` berbeda) — kasus produksi terpisah/parsial, rework, atau order yang dibuat ulang. Maka di tabel AFPO bisa ada **beberapa baris dengan `kdauf`+`kdpos` yang sama**, contoh:

| AUFNR | KDAUF | KDPOS | PSMNG | WEMNG | (interpretasi) |
|-------|-------|-------|------:|------:|----------------|
| 100001 | 10000021 | 10 | 100 | 100 | order lama, GR penuh |
| 100050 | 10000021 | 10 | 100 |   0 | order baru, belum GR |

Ketiga halaman *live* membaca AFPO seperti ini:

- `monitoring.htm:198-200`
- `monitoring_detail.htm:212-214`
- `index.htm:207-209`

```abap
SORT lt_afpo_pre BY kdauf kdpos.       " kunci sort TIDAK menyertakan aufnr
READ TABLE lt_afpo_pre INTO ls_afpo_row
  WITH KEY kdauf = … kdpos = … BINARY SEARCH.   " ambil 1 baris saja
```

`READ … BINARY SEARCH` mengembalikan **satu** baris yang cocok. Karena `SORT` hanya berdasarkan `kdauf kdpos` (bukan `aufnr`), **urutan di antara baris yang berkunci sama tidak ditentukan** dan bergantung pada urutan baris yang dipulangkan DB. Dua halaman menjalankan **SELECT terpisah pada waktu berbeda**, sehingga baris "pertama" bisa berbeda:

- Sidebar kebetulan membaca baris **100/100** → item dihitung **Selesai** → SO **100%**.
- Detail kebetulan membaca baris **100/0** → item **Proses** → SO **0%**.

Itulah inkonsistensi yang dilaporkan. Bersifat **non-deterministik** sehingga kadang muncul, kadang tidak.

### 1.3 Bukti: `riwayat.htm` sudah benar

`riwayat.htm:176-199` **sudah** menjumlahkan AFPO per item sebelum klasifikasi, dengan komentar eksplisit:

```abap
" Satu item SO (kdauf/kdpos) bisa punya >1 order produksi … psmng & wemng
" DIJUMLAHKAN per item via COLLECT, agar item hanya 'selesai' bila TOTAL GR
" >= TOTAL target — bukan dari salah satu order saja.
LOOP AT lt_afpo_pre INTO ls_afpo_row.
  CLEAR ls_afpo_agg.
  ls_afpo_agg-kdauf = ls_afpo_row-kdauf.
  ls_afpo_agg-kdpos = ls_afpo_row-kdpos.
  ls_afpo_agg-psmng = ls_afpo_row-psmng.
  ls_afpo_agg-wemng = ls_afpo_row-wemng.
  COLLECT ls_afpo_agg INTO lt_afpo_agg.
ENDLOOP.
SORT lt_afpo_agg BY kdauf kdpos.
```

→ Setelah agregasi, kunci `kdauf`+`kdpos` menjadi **unik**, `READ … BINARY SEARCH` deterministik, dan klasifikasi mengikuti **TOTAL** (200 target / 100 GR = 50% → Proses). **Inilah pola yang harus disalin ke `monitoring.htm`, `monitoring_detail.htm`, dan `index.htm`.**

### 1.4 Menegaskan aturan "Selesai = semua item selesai"

Permintaan: *"data dinyatakan selesai jika tidak ada SO Item yang diproses ataupun belum produksi"* → **SO Selesai ⟺ `inprog = 0` DAN `noprod = 0` ⟺ `done = total`.**

Logika label SO di sidebar (`monitoring.htm:358-372`) **sudah** memakai aturan ini (`IF ls_so_stat_r-done = ls_so_stat_r-total → 'Selesai'`). Jadi yang rusak **bukan** aturan SO-level, melainkan **klasifikasi item** (§1.2). Begitu agregasi diterapkan, aturan SO-level langsung konsisten dengan sendirinya.

> Catatan presisi: pertahankan ambang `>= 100` (bukan `= 100`) untuk meredam pembulatan. Item dengan `psmng=0`/tanpa AFPO tetap **Belum Produksi** (bukan Selesai), sehingga SO dengan item tanpa order produksi tidak akan salah-hijau.

---

## 2. Strategi Perbaikan #1 — Agregasi AFPO Terpusat

### 2.1 Prinsip

**Satu sumber kebenaran** untuk dua hal:
1. **Agregasi AFPO per item** (`psmng`/`wemng` dijumlah per `kdauf`+`kdpos`).
2. **Klasifikasi item** (done / inprog / noprod) dari ambang yang sama.

Sejalan dengan pola D1 yang sudah ada (warna progres dipusatkan di `ZCL_CS_UTIL`), pusatkan juga **klasifikasi** di `ZCL_CS_UTIL` agar ambang tidak terduplikasi di 4 tempat.

### 2.2 Tambahan pada `ZCL_CS_UTIL` (baru)

Tambah konstanta status + method klasifikasi (kecil, aman, tanpa SELECT — agar tidak menambah dependensi tabel pada class):

```abap
PUBLIC SECTION.
  CONSTANTS: gc_st_done   TYPE i VALUE 1,   " Selesai (GR >= target)
             gc_st_inprog TYPE i VALUE 2,   " Proses  (ada target, GR < target)
             gc_st_noprod TYPE i VALUE 3.   " Belum Produksi (tanpa order / target 0)

  "! Klasifikasi status item dari total target & total GR (sudah diagregasi).
  "! Pastikan iv_psmng/iv_wemng adalah TOTAL seluruh order produksi item tsb.
  CLASS-METHODS item_status
    IMPORTING iv_psmng       TYPE afpo-psmng
              iv_wemng       TYPE afpo-wemng
    RETURNING VALUE(rv_code) TYPE i.
```

```abap
METHOD item_status.
  DATA lv_pct TYPE ty_pct.
  IF iv_psmng > 0.
    lv_pct = iv_wemng * 100 / iv_psmng.
    IF lv_pct >= 100. rv_code = gc_st_done.
    ELSE.             rv_code = gc_st_inprog.
    ENDIF.
  ELSE.
    rv_code = gc_st_noprod.
  ENDIF.
ENDMETHOD.
```

> **Dependensi deployment:** seperti method `prog_bar_class` sebelumnya, `ZCL_CS_UTIL` harus **dibuat & diaktifkan ulang di SE24/ADT** sebelum halaman BSP diaktifkan.

### 2.3 Pola agregasi AFPO standar (disalin ke 3 halaman)

Karena tipe tabel BSP berbeda-beda per halaman, agregasi tetap dilakukan **inline** dengan pola identik (sama seperti `riwayat.htm`). Definisikan struktur agregat lokal:

```abap
TYPES: BEGIN OF ty_afpo_agg,
         kdauf TYPE afpo-kdauf,
         kdpos TYPE afpo-kdpos,
         psmng TYPE afpo-psmng,
         wemng TYPE afpo-wemng,
       END OF ty_afpo_agg.
DATA: lt_afpo_agg TYPE TABLE OF ty_afpo_agg,
      ls_afpo_agg TYPE ty_afpo_agg.
```

Setelah `SELECT … FROM afpo … INTO lt_afpo_pre`, ganti `SORT lt_afpo_pre BY kdauf kdpos` dengan:

```abap
LOOP AT lt_afpo_pre INTO ls_afpo_row.
  CLEAR ls_afpo_agg.
  ls_afpo_agg-kdauf = ls_afpo_row-kdauf.
  ls_afpo_agg-kdpos = ls_afpo_row-kdpos.
  ls_afpo_agg-psmng = ls_afpo_row-psmng.
  ls_afpo_agg-wemng = ls_afpo_row-wemng.
  COLLECT ls_afpo_agg INTO lt_afpo_agg.
ENDLOOP.
SORT lt_afpo_agg BY kdauf kdpos.
```

Lalu `READ TABLE lt_afpo_agg … BINARY SEARCH` (bukan `lt_afpo_pre`) saat menggabungkan ke struktur item. Kunci kini unik → deterministik.

### 2.4 Perubahan per file

**`monitoring.htm`**
- Tambah `ty_afpo_agg` + tabel agregat (§2.3).
- Loop join `lt_temp_vbap` (baris 190-209): `READ TABLE lt_afpo_agg …` alih-alih `lt_afpo_pre`.
- (Opsional) ganti blok klasifikasi (baris 218-227) memakai `zcl_cs_util=>item_status( … )` → `gc_st_done`/`inprog`/`noprod`.

**`monitoring_detail.htm`**
- Sama: agregasi sebelum loop join (baris 204-224) dan klasifikasi Ringkasan (baris 229-238) memakai `lt_afpo_agg` + `item_status`.
- ⚠️ **Perhatian `aufnr`:** struktur item detail menyimpan `aufnr` untuk tag status order & target finish di tab Item & BOM. Agregat menghilangkan `aufnr`. **Keputusan desain:** simpan `aufnr` **secara terpisah** dari baris AFPO mentah untuk keperluan tag order (mis. pilih order paling relevan: yang **paling belum selesai**/teraktif, atau tampilkan jumlah order). Progress per item & status Ringkasan tetap dari **agregat**. Lihat §3 — karena tab Item & BOM akan dipindah ke endpoint terpisah, penanganan `aufnr` ikut pindah ke sana.

**`index.htm`**
- Sama: agregasi `lt_afpo` per `kdauf`/`kdpos` sebelum control-break loop (baris 185-224), `READ` dari tabel agregat, klasifikasi via `item_status`. Membuat **donut, stacked bar, dan KPI dashboard konsisten** dengan Monitoring & Riwayat.

**`riwayat.htm`** — sudah benar; bila `item_status` dibuat, selaraskan agar ambang seragam (opsional, kosmetik).

### 2.5 Hasil yang diharapkan

- SO yang sama menampilkan **status & % identik** di Dashboard, Daftar SO, Ringkasan, dan Riwayat.
- "Selesai" hanya jika **seluruh** item GR ≥ target (tidak ada Proses/Belum Produksi).
- Item dengan order produksi terpisah dihitung dari **total** GR vs total target (tidak lagi "bocor" menjadi 100% karena satu order lama).

---

## 3. Analisis Masalah #2 — Detail SO Lambat Tampil

### 3.1 Penyebab

`monitoring_detail.htm` adalah **satu** endpoint AJAX yang, untuk setiap klik, menjalankan **±13 query sinkron sebelum** fragmen dikembalikan:

| # | Query | Untuk tab | Berat? |
|---|-------|-----------|--------|
| 0 | `VBAK` SELECT SINGLE | Ringkasan/Info | ringan |
| 0b | `KNA1` SELECT SINGLE | Ringkasan/Info | ringan |
| 1 | `VBAP` | Ringkasan/Item | ringan |
| 2 | `AFPO` (FAE) | Ringkasan/Item | ringan |
| 3 | `AFKO` (FAE) | **Item & BOM** | sedang |
| 3b | `AUFK` (FAE) | **Item & BOM** | sedang |
| 3c | `JEST` (FAE) | **Item & BOM** | sedang |
| 6 | `MAST` (FAE) | **Item & BOM** | berat |
| 6 | `STPO` (FAE) | **Item & BOM** | berat |
| 6 | `MAKT` (FAE) | **Item & BOM** | berat |
| 6 | `MARD` (FAE) | **Item & BOM** | berat |
| 6 | `EKPO` (FAE) | **Item & BOM** | berat |
| 6 | `EKET` (FAE) | **Item & BOM** | berat |

Tab default yang ditampilkan adalah **Ringkasan** (`monitoring_detail.htm:363,369`; JS `viewDetails` tidak lagi memaksa pindah tab — `js.js:410-411`). Namun **9 dari 13 query** (no. 3–6) hanya dibutuhkan tab **Item & BOM**. Artinya pengguna **selalu menunggu rantai BOM** walau mungkin tidak pernah membuka tab itu. Inilah "beberapa detik" itu.

### 3.2 Yang sudah baik (jangan diubah)

- `js.js:382-387` — **cache per `vbeln`** (`soDetailCache`): klik SO yang sama kedua kali = instan, tanpa request.
- `js.js:389-400` — **skeleton loader** tampil selama menunggu (UX sudah memadai).
- C4 (memo): driver komponen unik (`lt_comp`) sudah mengurangi duplikasi FAE pada MAKT/MARD/EKPO.

---

## 4. Strategi Perbaikan #2 — Lazy-Load Tab Item & BOM

### 4.1 Pendekatan (direkomendasikan): pecah jadi dua endpoint

**Endpoint ringan — `monitoring_detail.htm` (diubah):** hanya hitung yang dibutuhkan **Ringkasan + Info Order**:
- Query 0, 0b, 1, 2 saja (VBAK, KNA1, VBAP, AFPO **+ agregasi §2.3**).
- Render: header, tab-nav, tab **Ringkasan** (terisi), tab **Info Order** (terisi), dan tab **Item & BOM** sebagai **shell kosong** + spinner:
  ```html
  <div class="tab-pane" id="tab-items" data-vbeln="<%= lv_vbeln %>" data-loaded="0">
    <div class="bom-lazy-hint">Memuat detail item &amp; BOM…</div>
  </div>
  ```
- **Hapus** dari file ini: blok query 3, 3b, 3c (AFKO/AUFK/JEST) dan blok 6 (MAST→EKET), serta seluruh markup tabel Item & BOM (pindah ke endpoint baru).
- Efek: detail awal hanya **4 query ringan** → tampil **instan**.

**Endpoint berat — `monitoring_bom.htm` (BARU):** mengembalikan **isi tab Item & BOM** saja (fragmen, tanpa wrapper):
- Query: VBAP + AFPO (**agregasi §2.3** untuk progress per item) + AFKO/AUFK/JEST (status order) + MAST→EKET (BOM, stok, open PO).
- Di sinilah penanganan `aufnr` untuk tag status order berada (lihat §2.4).
- Markup = tabel `data-table` + baris BOM + tooltip material (dipindah apa adanya dari `monitoring_detail.htm:421-584`).

### 4.2 Perubahan JS (`js.js`)

1. **`switchTab`** — saat tab `tab-items` diaktifkan untuk pertama kali, muat lewat AJAX:
   ```js
   function switchTab(tabId, btn) {
     /* … kode aktif/inaktif pane seperti sekarang … */
     if (tabId === 'tab-items') {
       var pane = document.getElementById('tab-items');
       if (pane && pane.getAttribute('data-loaded') === '0') {
         loadBOM(pane);
       }
     }
   }
   ```
2. **`loadBOM(pane)`** — fetch `monitoring_bom.htm?vbeln=…`, cache per `vbeln` (`soBomCache`), lalu `formatNumbers()` + `enhanceA11y()` pada fragmen baru:
   ```js
   var soBomCache = {};
   function loadBOM(pane) {
     var vbeln = pane.getAttribute('data-vbeln');
     if (soBomCache[vbeln]) { pane.innerHTML = soBomCache[vbeln];
       pane.setAttribute('data-loaded','1'); formatNumbers(pane); enhanceA11y(pane); return; }
     pane.innerHTML = '<div class="bom-lazy-hint">Memuat…</div>';
     var xhr = new XMLHttpRequest();
     xhr.open('GET', 'monitoring_bom.htm?vbeln=' + encodeURIComponent(vbeln), true);
     xhr.onload = function() {
       if (xhr.status === 200) { soBomCache[vbeln] = xhr.responseText;
         pane.innerHTML = xhr.responseText; pane.setAttribute('data-loaded','1');
         formatNumbers(pane); enhanceA11y(pane); }
       else { pane.innerHTML = '<div class="placeholder-ctx"><p style="color:#ef4444;">Gagal memuat BOM (HTTP ' + xhr.status + ').</p></div>'; }
     };
     xhr.onerror = function() { pane.innerHTML = '<div class="placeholder-ctx"><p style="color:#ef4444;">Error koneksi.</p></div>'; };
     xhr.send();
   }
   ```
3. **`soDetailCache`** tetap menyimpan fragmen ringan; tambah `soBomCache` untuk tab berat. Bersihkan keduanya bila perlu (mis. saat reload daftar).

> **Opsi peningkatan (opsional):** *prefetch* `monitoring_bom.htm` di latar belakang segera setelah fragmen ringan tampil (mis. `setTimeout` 300 ms), sehingga saat pengguna mengklik tab Item & BOM datanya sudah siap, tanpa menghambat tampil awal.

### 4.3 Alternatif yang dipertimbangkan (tidak direkomendasikan)

- **Tetap satu endpoint, optimasi query saja.** Pada satu request BSP server-side, semua query tetap berjalan sebelum HTML dikirim — tidak bisa "menunda" sebagian dalam satu fragmen. Maka tetap lambat. Lazy-load (§4.1) adalah satu-satunya cara menghilangkan tunggu di tab default.
- **Render seluruh BOM untuk seluruh SO di muka** (seperti sidebar sekarang): justru memperberat, ditolak.

### 4.4 Catatan deployment

- `monitoring_bom.htm` adalah **BSP page baru** → harus dibuat & diaktifkan di SE80 dalam aplikasi `ZBSP_CS_APP`, satu paket/transport.
- Naikkan versi cache-buster JS (`js.js?r=3`) agar `switchTab`/`loadBOM` baru terambil browser.

---

## 5. Urutan Implementasi & Pengujian

**Fase 1 — Konsistensi (Masalah #1), risiko rendah, dampak tinggi**
1. Tambah `item_status` + konstanta di `ZCL_CS_UTIL`, aktifkan di SE24.
2. Terapkan agregasi AFPO (§2.3) + `item_status` di `monitoring.htm`, lalu `monitoring_detail.htm`, lalu `index.htm`.
3. Aktifkan ulang halaman BSP.
4. **Uji:** cari SO yang punya item dengan >1 order produksi (satu lama GR penuh + satu baru GR 0). Pastikan label & % **sama** di Daftar SO ↔ Ringkasan ↔ Dashboard. Pastikan SO hanya "Selesai" bila semua item GR ≥ target.

**Fase 2 — Kecepatan (Masalah #2)**
5. Buat `monitoring_bom.htm` (pindahkan blok BOM + status order dari `monitoring_detail.htm`, sertakan agregasi AFPO).
6. Rampingkan `monitoring_detail.htm` menjadi Ringkasan + Info + shell tab Item & BOM.
7. Tambah `loadBOM`/`soBomCache` + hook di `switchTab` (`js.js`), naikkan `?r=`.
8. **Uji:** klik SO → Ringkasan muncul **instan**; klik tab Item & BOM → BOM dimuat (spinner lalu tabel); klik tab lagi/SO sama → dari cache (instan); tooltip material & expand BOM tetap berfungsi.

**Smoke test umum:** SO tanpa item produksi (semua Belum Produksi) → bukan hijau; SO sebagian selesai → Proses; angka GR/target di tab Item & BOM cocok dengan Ringkasan.

---

## 6. Risiko & Mitigasi

| Risiko | Mitigasi |
|--------|----------|
| `ZCL_CS_UTIL` belum diaktifkan sebelum BSP → dump | Aktifkan class **lebih dulu** (sudah jadi pola D1). |
| `monitoring_bom.htm` lupa dibuat/diaktifkan → tab Item & BOM gagal muat | Checklist deployment; JS sudah menangani HTTP error dengan pesan. |
| Pemilihan `aufnr` untuk tag status order saat item multi-order ambigu | Tetapkan aturan eksplisit (mis. order **paling belum selesai**) & dokumentasikan; progress tetap dari agregat. |
| Cache browser memakai JS lama | Naikkan `?r=` pada `<script src="js/js.js">`. |
| `COLLECT` pada kuantitas desimal | Tipe `psmng`/`wemng` sudah sesuai DDIC AFPO; `COLLECT` aman untuk numerik. |

---

## 7. Lampiran — Referensi Baris Kode

- Sidebar baca AFPO 1 baris: `monitoring.htm:198-200`; klasifikasi: `:214-229`; label SO: `:358-372`.
- Detail baca AFPO 1 baris: `monitoring_detail.htm:212-214`; Ringkasan: `:226-248`; blok berat AFKO/AUFK/JEST: `:163-201`; rantai BOM: `:250-348`; markup Item & BOM: `:421-584`.
- Pola agregasi benar (acuan): `riwayat.htm:170-199`.
- Dashboard baca AFPO 1 baris: `index.htm:206-224`.
- AJAX detail + cache + skeleton: `js.js:370-420`; `switchTab`: `:601-609`.
- Helper warna/tanggal terpusat: `classes/ZCL_CS_UTIL.abap`.
</content>
</invoke>
