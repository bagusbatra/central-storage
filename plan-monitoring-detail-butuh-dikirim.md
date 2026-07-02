# Planning — Perubahan `monitoring_detail.htm`: Tab "Butuh Dikirim" + Gabung "Ringkasan/Info Order"

> Rencana pengembangan panel detail SO pada Central Storage Dashboard (ZBSP_CS_APP).
> Dua perubahan:
> 1. **Tambah tab baru "Butuh Dikirim"** — komponen SO yang masih perlu dikirim dari Plant 1000/Sloc 1D00.
> 2. **Gabung tab "Ringkasan" + "Info Order"** menjadi satu tab bernama **"Ringkasan"**.
>
> Status dokumen: **DRAFT / PLAN**. Disusun setelah tanya-jawab requirement (lihat §1).

---

## 0. Koordinasi antar-plan (baca sebelum implementasi)

> Plan ini berjalan berdampingan dengan **`plan-monitoring-bom-dotbar.md`** (dot-bar perjalanan sloc di baris komponen).
> Keduanya **aman dikembangkan bersamaan**, tetapi menyentuh file yang sama & berbagi konsep pipeline
> `1D00 → 2KCS → 2261 → 2262 → 22F2 → 22F3 → 229K`. Titik yang **wajib dikoordinasikan**:

| # | Titik singgung | Aturan koordinasi |
|---|----------------|-------------------|
| 1 | **`monitoring_bom.htm` (file sama)** | Plan ini menambah cabang **`mode=kirim`**; dot-bar mengubah **path default (Item & BOM)**. Buat skeleton `IF lv_mode='kirim' … ELSE … ENDIF` dulu (plan ini), dot-bar mengedit **di dalam `ELSE`**. |
| 2 | **CONSTANTS** | **Satu blok gabungan.** Hindari deklarasi ganda `lc_horizon` (dobel = gagal aktivasi). `lc_plant '2000'` yang sudah ada dipakai ulang. |
| 3 | **Definisi "sudah masuk 2KCS"** | **HARUS identik** dengan dot-bar. Konsistensi kunci: material yang muncul di tab **Butuh Dikirim** (belum sampai 2KCS) = **titik-1 MERAH** di dot-bar. Beda definisi → tampilan kontradiktif. |
| 4 | **Logika MSEG⨝MKPF net-reversal** | Pusatkan ke **`ZCL_CS_UTIL`** (dipakai kedua plan). Sekali tulis, hindari drift. |
| 5 | **Beban query** | Plan ini lazy (request terpisah `mode=kirim`); dot-bar menambah beban ke path default. Tidak saling menambah beban bila cabang dijaga terpisah. |
| 6 | **`reference.md` + cache-buster** | Gabung jadi **satu** pembaruan doc & satu kali bump versi (`js.js`/`style.css`/`monitoring.htm`). |

**Hubungan konseptual:** tab Butuh Dikirim = tahap *sebelum* 2KCS (titik-1 merah pada dot-bar); dot-bar = perjalanan *setelah* 2KCS. Dua sisi dari pipeline yang sama.

**Urutan kerja gabungan yang disarankan:** (1) Fase 0 verifikasi movement type; (2) CONSTANTS gabungan + `ZCL_CS_UTIL`; (3) restrukturisasi tab + skeleton `mode` (plan ini); (4) isi dot-bar di cabang `ELSE` (plan dot-bar); (5) satu kali update `reference.md` + cache-buster.

---

## 1. Keputusan Requirement (hasil konfirmasi)

| # | Aspek | Keputusan |
|---|-------|-----------|
| Q1 | **Cara sajian data "Butuh Dikirim"** | Lewat **`monitoring_bom.htm` + parameter `mode`** (`?vbeln=X&mode=kirim`), **di-lazy-load terpisah** saat tab diklik. Konsisten pola `loadBOM()`; detail utama tetap tampil instan. |
| Q2 | **Layout tabel** | **Tabel datar seperti `transfer.htm`** (per material): `Material │ Nama │ Butuh │ Stok 2KCS │ Perlu Kirim │ Sat │ Stok 1D00 │ Sudah Dikirim │ Tgl Butuh │ Status`. |
| Q3 | **Definisi "butuh dikirim"** | **Reuse rekonsiliasi `transfer.htm` (Model B), di-scope ke SO ini.** Tampil bila `Perlu Kirim = max(0, Butuh − Stok 2KCS) > 0` **DAN** material punya stok di 1000/1D00. Kosong → **"Semua bahan telah dikirim"**. |
| Q4 | **Tab gabungan** | Nama **"Ringkasan"**. Urutan isi: **Info Order dulu (atas)**, lalu ringkasan status/KPI + daftar item (bawah). |

**Hasil akhir 3 tab:** `Ringkasan` │ `Item & BOM` │ `Butuh Dikirim`.

**Rute fisik transfer:** `Plant 1000 / Sloc 1D00` → `Plant 2000 / Sloc 2KCS` (sama seperti `transfer.htm`).

---

## 2. Kondisi Saat Ini (baseline)

### 2.1 `monitoring_detail.htm` (endpoint RINGAN, AJAX fragment)
- Menghitung: VBAK+KNA1 (header/Info Order), VBAP+AFPO agregat (ringkasan status item).
- 3 tab: **Ringkasan** (`tab-summary`, aktif), **Item & BOM** (`tab-items`, lazy), **Info Order** (`tab-info`).
- Tab **Item & BOM** hanya berisi placeholder `bom-lazy-hint`; isinya di-fetch dari `monitoring_bom.htm`.

### 2.2 `monitoring_bom.htm` (endpoint BERAT, AJAX fragment)
- Merender **isi tab Item & BOM**: item → komponen RESB (gaya COOIS) / fallback BOM master.
- Dipanggil `js.js` `loadBOM()`/`fetchBOM()`; hasil di-cache `soBomCache[vbeln]`.

### 2.3 `transfer.htm` (halaman penuh — sumber logika yang di-reuse)
- Model REKONSILIASI per material (Model B):
  - `Butuh = Σ(RESB.bdmng − RESB.enmng)` open, `werks=2000, xloek=' ', kzear=' '`.
  - `Perlu Kirim = max(0, Butuh − Stok 2KCS)`.
  - `Sudah Dikirim = Σ MSEG(mvt 301, 1D00→2KCS)` net `SHKZG`.
  - Status: `Tercukupi` (perlu=0) / `Akan Dikirim` (stok 1D00 cukup) / `Kurang Stok 1D00`.
- Sudah punya **filter `so_num`** → mengumpulkan `aufnr` order produksi SO (`AFPO.kdauf`) menjadi `RANGE`. **Inilah scoping per-SO yang kita butuhkan.**

### 2.4 `js.js` — plumbing lazy-load (PERLU DIPERLUAS)
- `switchTab()` hanya memanggil `loadBOM()` untuk `tab-items`.
- `fetchBOM()` **hardcoded** ke URL `monitoring_bom.htm?vbeln=…` (tanpa `mode`), cache `soBomCache`, dan `applyBOMIfWaiting()`/`renderBOM()` **hardcoded** ke pane `#tab-items`.
- ⇒ Butuh loader **paralel** untuk `mode=kirim` (cache & pane terpisah).

---

## 3. Desain Perubahan

### 3.1 `monitoring_detail.htm` — restrukturisasi tab (tanpa query baru)

Semua data untuk tab gabungan **sudah dihitung** (VBAK/KNA1 + agregat AFPO). Perubahan **murni HTML**:

1. **Nav tab** → 3 tombol:
   ```
   [▣ Ringkasan]  [☰ Item & BOM]  [🚚 Butuh Dikirim]
   ```
   - Hapus tombol "Info Order".
   - Tambah tombol "Butuh Dikirim" → `switchTab('tab-kirim', this)`.
2. **Tab `tab-summary` (Ringkasan)** — gabungkan isi, urutan **Info Order → Ringkasan**:
   - (atas) grid `.info-order-grid` (dipindah dari `tab-info`).
   - (bawah) `.sum-kpi-row` + `.ovr-prog-wrap` + `.sum-item-list` (isi lama Ringkasan).
   - Opsional: sub-judul kecil (mis. `<div class="bom-title">Info Order</div>` / `…Ringkasan Status`) sebagai pemisah visual.
3. **Hapus** blok `<div class="tab-pane" id="tab-info">…</div>`.
4. **Tambah** pane baru (pola sama `tab-items`, lazy):
   ```html
   <div class="tab-pane" id="tab-kirim" data-vbeln="<%= lv_vbeln %>" data-loaded="0">
     <div class="bom-lazy-hint">Memuat data butuh dikirim…</div>
   </div>
   ```
- Komentar header ABAP (baris 8–12) diperbarui: hapus penyebutan "Info Order" sbagai tab terpisah.
- **Tidak ada perubahan logika ABAP** di file ini.

### 3.2 `monitoring_bom.htm` — cabang `mode`

Tambah pembacaan parameter & percabangan **di paling atas** dan **di blok render**:

```abap
DATA lv_mode TYPE string.
lv_mode = request->get_form_field( 'mode' ).   " '' (default) | 'kirim'
```

Struktur logika:
```
lv_req_vb = …ambil vbeln…
IF lv_req_vb IS NOT INITIAL.
  …ALPHA vbeln…
  IF lv_mode = 'kirim'.
     "=== BLOK BARU: rekonsiliasi butuh-dikirim (§3.3) ==="
  ELSE.
     "=== BLOK LAMA: Item & BOM (tak berubah) ==="
  ENDIF.
ENDIF.
```
Render (setelah `%>`):
```
IF lv_vbeln IS INITIAL. …placeholder param…
ELSEIF lv_mode = 'kirim'. …tabel butuh dikirim (§3.4)…
ELSE. …tabel Item & BOM lama…
ENDIF.
```

> Menaruh keduanya di **satu file** memenuhi permintaan "data ada di `monitoring_bom.htm`", dan cabang `mode` mencegah query berat Item & BOM ikut jalan saat hanya tab Butuh Dikirim yang diminta (dan sebaliknya).

### 3.3 Blok ABAP baru "Butuh Dikirim" (di-scope per SO)

Konstanta baru (di `monitoring_bom.htm`, ikut pola `transfer.htm`):
```abap
CONSTANTS: lc_dst_sloc TYPE lgort_d VALUE '2KCS',
           lc_src_plant TYPE werks_d VALUE '1000',
           lc_src_sloc  TYPE lgort_d VALUE '1D00',
           lc_mvt_out   TYPE bwart   VALUE '301',
           lc_horizon   TYPE i       VALUE 90.
" lc_plant '2000' sudah ada.
```

Alur (lift dari `transfer.htm`, **scope = SO ini**, tanpa form filter):
```
1. AFPO WHERE kdauf = lv_vbeln  → kumpulkan aufnr → RANGE lr_aufnr.
   IF kosong → lt_need kosong → render "Semua bahan telah dikirim".
2. RESB WHERE werks='2000' AND xloek=' ' AND kzear=' ' AND aufnr IN lr_aufnr.
   Agregasi per matnr: need += (bdmng−enmng) untuk baris open (>0);
   simpan bdter paling awal + aufnr wakil.
3. MAKT (nama), MARD (stok 2KCS & stok 1D00), MSEG+MKPF (Sudah Dikirim net SHKZG, horizon 90 hr)
   — identik transfer.htm langkah 3–5.
4. Per material: perlu = max(0, need − stok_dst).
   status: perlu=0 → 'Tercukupi'(tf-ok) ; stok_src≥perlu → 'Akan Dikirim'(tf-need) ;
           else → 'Kurang Stok 1D00'(tf-short).
5. FILTER tampilan (inti tab): simpan hanya baris "butuh dikirim":
   perlu > 0  AND  stok_src > 0        (lihat §5 catatan edge-case).
6. SORT perlu DESCENDING matnr ASCENDING.
```

> **Reuse maksimal:** langkah 2–4 hampir 1:1 dengan `transfer.htm` (baris 111–226). Perbedaan: `lr_aufnr` **selalu** diisi dari SO ini (bukan opsional dari filter), dan tak ada filter material/status/GET.

### 3.4 Render tabel "Butuh Dikirim"

- **Fragment saja** (tanpa `<html>`/navbar/filter form) — konsisten endpoint AJAX.
- Reuse gaya tabel datar `transfer.htm` (inline style) + kelas `.badge tf-ok/tf-need/tf-short` (sudah ada di `style.css`).
- **Kolom** (Q2), tanpa kolom "SO" (karena sudah dalam konteks SO):
  `Material │ Nama │ Butuh │ Stok 2KCS │ Perlu Kirim │ Sat │ Stok 1D00 │ Sudah Dikirim │ Tgl Butuh │ Status`.
- Angka pakai `<span class="num-fmt" data-val="…">` → di-`formatNumbers()` oleh js.js.
- Baris `tf-short` → highlight `background:#fef2f2;` (sama transfer.htm).
- **Empty-state** (aturan 3): bila tak ada baris lolos filter →
  ```
  ✔ Semua bahan telah dikirim untuk SO ini.
  ```
  (bedakan dari kasus "SO tanpa order produksi" bila perlu, mis. teks berbeda.)

### 3.5 `js.js` — loader paralel `mode=kirim`

Tambah cache & fungsi terpisah (jangan ganggu jalur BOM yang ada):
```js
var soKirimCache = {};      // cache fragmen butuh-dikirim per vbeln
var kirimInflight = {};
```
- `switchTab()`: tambah cabang
  ```js
  if (tabId === 'tab-kirim' && pane && pane.getAttribute('data-loaded') === '0') {
    loadKirim(pane);
  }
  ```
- `loadKirim(pane)` / `fetchKirim(vbeln)` / `renderKirim(pane,vbeln)` — cermin `loadBOM/fetchBOM/renderBOM`, beda:
  - URL: `monitoring_bom.htm?vbeln=…&mode=kirim`.
  - Cache: `soKirimCache`; pane: `#tab-kirim`.
  - Setelah render: `formatNumbers(pane)` (+ `enhanceA11y(pane)`).
- **Prefetch idle**: opsional (v2). v1 cukup load saat tab diklik (skeleton → render).

### 3.6 Cache-buster
- Bump versi include di **`monitoring.htm`** (halaman yang memuat detail): `js/js.js?r=<naik>` (dan `css/style.css?r=` bila menambah CSS).

---

## 4. Berkas yang Disentuh

| Berkas | Perubahan |
|--------|-----------|
| `Page with Flow Logic/monitoring_detail.htm` | HTML: gabung tab Ringkasan+Info Order, tambah tombol & pane `tab-kirim`. (tanpa ABAP baru) |
| `Page with Flow Logic/monitoring_bom.htm` | ABAP: baca `mode`, cabang blok "kirim" (rekonsiliasi per SO) + render tabel. |
| `MIMEs/js/js.js` | Tambah `loadKirim/fetchKirim/renderKirim` + cabang di `switchTab`; cache `soKirimCache`. |
| `monitoring.htm` | Bump cache-buster `?r=` js/(css). |
| `reference.md` | Dokumentasikan tab baru + matriks tabel (RESB/MSEG/MKPF/MARD 1000 kini juga dipakai `monitoring_bom.htm`). |

---

## 5. Catatan, Asumsi & Risiko (baca sebelum coding)

1. **Asumsi transfer.htm ikut terbawa.** Movement type `301`, Model B (RESB kebutuhan 2000), netting `SHKZG='H'`, horizon 90 hari — **belum diverifikasi di sistem** (Fase 0 di `plan-transfer-1000-2000.md` masih ⏳). Bila hasil verifikasi berbeda, ubah **terpusat**: idealnya keduanya berbagi konstanta/logika (lihat §6).
2. **Duplikasi logika transfer.htm ↔ monitoring_bom.htm.** Kita menyalin ~langkah 2–4. Risiko drift bila salah satu diubah. Mitigasi jangka pendek: beri komentar silang "sinkron dengan transfer.htm §5"; jangka panjang: pindah ke method di `ZCL_CS_UTIL` (§6, backlog).
3. **Edge-case filter `stok_src > 0` (Q3).** Aturan Anda: tampil bila perlu>0 **DAN ada stok di 1D00**. Konsekuensi: komponen yang **sangat** dibutuhkan tapi **stok 1D00 = 0** **tidak muncul** — padahal itu justru paling "butuh dikirim". 
   - **Rekomendasi:** tetap tampilkan baris `perlu>0` walau `stok_src=0`, dengan status **"Kurang Stok 1D00"** (highlight merah), sehingga tidak ada kebutuhan yang tersembunyi. → *Perlu keputusan Anda* (default plan: ikut aturan literal `stok_src>0`; ubah 1 baris IF bila setuju rekomendasi).
4. **Konsistensi UoM.** `RESB-BDMNG`/`MSEG-MENGE`/`MARD-LABST` bisa beda satuan; jangan jumlah lintas material. Tampilkan `MEINS` per baris (sudah).
5. **Beban query.** Tab ini menambah pembacaan RESB/MSEG/MKPF/MARD saat diklik. Karena lazy + di-scope ke `aufnr` SO (bukan seluruh plant seperti `transfer.htm`), beban jauh lebih ringan. Tetap cek ST05 pasca-aktivasi.
6. **`mode` tak dikenal.** Nilai selain `'kirim'` → jatuh ke default Item & BOM (aman, backward-compatible untuk `fetchBOM` lama yang tak kirim `mode`).
7. **Pane a11y & format angka.** Fragment butuh dikirim harus lewat `formatNumbers()` setelah inject (tanpa itu angka mentah).

---

## 6. Backlog / Perbaikan Menyusul (opsional)
- **Sentralisasi rekonsiliasi** ke `ZCL_CS_UTIL` (mis. method `get_transfer_need( iv_vbeln )`) → dipakai `transfer.htm` **dan** `monitoring_bom.htm` (hilangkan duplikasi §5-2).
- **Sentralisasi konstanta plant/sloc/mvt** (backlog D4 pada plan transfer) — kini dipakai di 2 file.
- **Prefetch idle** tab Butuh Dikirim (seperti BOM) bila terasa lambat.
- **Klik baris → riwayat MB1B** (MSEG) per material (v2).

---

## 7. Checklist Uji (setelah aktivasi)
- [ ] Panel detail SO tampil 3 tab: Ringkasan │ Item & BOM │ Butuh Dikirim.
- [ ] Tab **Ringkasan** memuat Info Order (atas) + KPI/daftar item (bawah); tak ada tab "Info Order" terpisah; tak ada regresi angka ringkasan.
- [ ] Tab **Item & BOM** tetap berfungsi persis seperti sebelumnya (mode default, `fetchBOM` tanpa `mode`).
- [ ] Tab **Butuh Dikirim** lazy-load `?mode=kirim`; skeleton → tabel; angka ter-format.
- [ ] Baris hanya material `perlu>0` (sesuai keputusan edge-case §5-3); urut perlu DESC.
- [ ] Angka **Perlu Kirim / Butuh / Stok** cocok dengan `transfer.htm` (filter SO sama) untuk SO uji.
- [ ] SO tanpa kekurangan → **"Semua bahan telah dikirim"**; SO tanpa order → pesan sesuai.
- [ ] `tf-short` highlight merah muncul saat stok 1D00 < perlu.
- [ ] Tidak ada full-scan berat (ST05); tab lain tak melambat.
- [ ] Cache-buster dinaikkan; tak ada JS lama ter-cache.

---

## 8. Urutan Implementasi
1. `monitoring_detail.htm` — restrukturisasi tab (paling aman, murni HTML).
2. `monitoring_bom.htm` — cabang `mode` + blok "kirim" + render tabel.
3. `js.js` — `loadKirim/fetchKirim/renderKirim` + cabang `switchTab`.
4. Bump cache-buster di `monitoring.htm`.
5. Aktivasi & uji (Checklist §7); verifikasi angka vs `transfer.htm`.
6. Perbarui `reference.md`.
