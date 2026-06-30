# Rencana Pengembangan — Menu "Riwayat" (Arsip SO Selesai)

> Status: **DRAFT RENCANA** — untuk direvisi dulu sebelum pengkodean.
> Aplikasi: BSP `ZBSP_CS_APP`, Plant 2000 Surabaya.
> Disusun: 2026-06-29.

---

## 1. Ringkasan Fitur

Menambahkan **menu ketiga** pada navbar (setelah *Dashboard* dan *Monitoring*) bernama **Riwayat**.
Halaman ini berfungsi sebagai **arsip Sales Order yang produksinya sudah selesai 100%** — daftar
pekerjaan yang sudah tuntas, bisa difilter dan diklik untuk melihat detail produksinya.

Halaman baru: **`riwayat.htm`** (BSP Page with Flow Logic).

---

## 2. Keputusan dari Sesi Tanya-Jawab (2026-06-29)

| Aspek | Keputusan |
|---|---|
| **Isi Riwayat** | SO selesai (arsip produksi) |
| **Kriteria masuk** | Semua item GR 100% (selesai) |
| **Filter & pencarian** | Rentang tanggal kustom (dari–sampai), per customer (nama/kode), per nomor SO. **Hanya status selesai** (tidak perlu filter status lain) |
| **Aksi data** | Klik baris → buka panel detail produksi yang sudah ada (`monitoring_detail.htm`) |

---

## 3. Definisi Presisi "SO Selesai"

Sebuah Sales Order masuk Riwayat **jika dan hanya jika**:

1. **Scope Plant 2000** — punya item di `VBAP` dengan `werks = '2000'`.
2. **Punya minimal 1 item produksi** (total item > 0).
3. **Setiap item GR 100%** — untuk SEMUA item: `AFPO-PSMNG > 0` **DAN** `AFPO-WEMNG >= AFPO-PSMNG`.
   - Artinya: jumlah item `done` == total item, **tanpa** ada item `inprog` maupun `noprod`.
   - SO yang punya item tanpa order produksi (`psmng = 0`) **TIDAK** dianggap selesai.

> Logika klasifikasi item (done/inprog/noprod) identik dengan yang sudah dipakai di
> `index.htm` & `monitoring.htm` — bisa di-reuse pola control-break-nya.

---

## 4. Arsitektur & File yang Terlibat

| File | Aksi | Keterangan |
|---|---|---|
| `riwayat.htm` | **BUAT BARU** | Halaman list arsip SO selesai + filter bar + wadah panel detail |
| `index.htm` | **UBAH** | Tambah link menu "Riwayat" di navbar (`~baris 450-453`) |
| `monitoring.htm` | **UBAH** | Tambah link menu "Riwayat" di navbar |
| `monitoring_detail.htm` | **REUSE apa adanya** | Endpoint AJAX panel detail — tidak diubah |
| `MIMEs/js/js.js` | **REUSE apa adanya** | `viewDetails()`, `formatNumbers()`, `switchTab()`, `toggleBOMRow()`, dll. |
| `MIMEs/css/style.css` | **REUSE** (mungkin +sedikit) | Class `so-item-row`, `filter-bar`, tabel, panel detail sudah tersedia |
| `ZCL_CS_UTIL` | **REUSE** | `fmt_date()`, `prog_bar_class()`, `prog_txt_class()`, type `ty_pct` |

**Catatan reuse panel detail:** `js.js:viewDetails(vbeln)` hanya butuh DOM:
- baris dengan `id="row-<vbeln>"` + `onclick="viewDetails('<vbeln>')"`
- satu wadah `id="main-panel-container"`

Selama `riwayat.htm` menyediakan dua hal ini, panel detail (Ringkasan / Item & BOM / Info Order)
langsung berfungsi tanpa kode JS baru.

---

## 5. Rancangan Halaman (UI)

```
+----------------------------------------------------------+
|  Header bar (judul + user SAP + logout)                  |
+----------------------------------------------------------+
|  Navbar:  [Dashboard]  [Monitoring]  [Riwayat *aktif*]   |
+----------------------------------------------------------+
|  Filter bar:                                             |
|   Tanggal: [dari]  s/d  [sampai]   Customer: [____]      |
|   No. SO: [____]   [Cari]  [Reset]                       |
+----------------------------------------------------------+
|  Ringkasan: "Menampilkan N SO selesai (periode ...)"     |
+----------------------------------------------------------+
|  KIRI (list)            |  KANAN (panel detail)          |
|  +------------------+   |  +--------------------------+  |
|  | SO #... selesai  |   |  | (main-panel-container)   |  |
|  | Customer / tgl   |   |  | placeholder: "Pilih SO"  |  |
|  | total item       |   |  | -> reuse monitoring_     |  |
|  +------------------+   |  |    detail.htm via AJAX   |  |
|  | SO #... selesai  |   |  +--------------------------+  |
|  +------------------+   |                                |
+----------------------------------------------------------+
|  Footer (timestamp, user, plant)                         |
+----------------------------------------------------------+
```

Layout 2 kolom (list + detail) mengikuti pola `monitoring.htm` agar konsisten.

---

## 6. Logika ABAP (alur di `riwayat.htm`)

1. **Baca parameter filter** (`request->get_form_field`): `date_from`, `date_to`, `cust_search`, `so_num`.
   - Default rentang tanggal bila kosong → **lihat Bagian 9 (keputusan terbuka)**.
2. **SELECT header** dari `VBAK` (kolom spesifik: `vbeln erdat kunnr auart netwr waerk`)
   `WHERE erdat BETWEEN date_from AND date_to`
   (+ `AND vbeln = so_num` bila diisi).
3. **SELECT item** `VBAP` `WHERE werks = '2000'` (FOR ALL ENTRIES dari header, dengan guard).
   - Prune header: buang SO tanpa item Plant 2000.
4. **SELECT** `AFPO` (`kdauf kdpos psmng wemng`) untuk hitung status item.
5. **Klasifikasi + agregasi per-SO** (control-break O(n), pola sama `index.htm`):
   - hitung `done / inprog / noprod` per SO.
6. **FILTER inti**: simpan hanya SO yang **`done == total` dan `total > 0`** (semua item GR 100%).
7. **Filter customer** (opsional): join `KNA1` untuk nama; saring `cust_search` terhadap kode/nama.
8. **Sort** daftar hasil → urutan lihat Bagian 9.
9. **Render** daftar SO (kiri) + wadah `main-panel-container` (kanan) + filter bar.

**Performa:** rentang tanggal membatasi `VBAK`; semua `FOR ALL ENTRIES` diberi guard
`IF lt_xxx IS NOT INITIAL` (sesuai pola anti-bug yang sudah ada di proyek).

---

## 7. Filter & Pencarian (detail)

- **Rentang tanggal**: dua input `type="date"` (atau text `DD/MM/YYYY`) → dikirim via form `GET`
  (idempotent, bisa di-bookmark) seperti filter periode di Dashboard.
- **Customer**: input teks, cocokkan terhadap `KNA1-NAME1` atau `KUNNR` (case-insensitive),
  reuse pola `index.htm` (TRANSLATE UPPER + NS).
- **Nomor SO**: input teks → `CONVERSION_EXIT_ALPHA_INPUT` → filter `vbeln`.
- **Status**: TIDAK ada filter status — halaman ini per definisi hanya menampilkan yang selesai.
- **Reset**: link kembali ke `riwayat.htm` tanpa parameter (pakai default rentang tanggal).

---

## 8. Interaksi (klik → detail)

- Tiap baris SO: `<div id="row-<vbeln>" onclick="viewDetails('<vbeln>')">`.
- Wadah kanan: `<div id="main-panel-container">` berisi placeholder awal.
- `viewDetails()` (sudah ada) meng-AJAX `monitoring_detail.htm?vbeln=...` dan menyuntik HTML.
- Tab Ringkasan / Item & BOM / Info Order + tooltip Target/Hasil GR otomatis ikut (reuse penuh).
- **Tidak ada kode JS baru** yang dibutuhkan.

---

## 9. Keputusan yang Masih Terbuka (FINAL)

| # | Pertanyaan | Usulan default saya |
|---|---|---|
| 9.1 | **Default rentang tanggal** saat halaman pertama dibuka? | 1 tahun terakhir (konsisten dgn opsi Dashboard). Alternatif: tahun berjalan / semua data |
| 9.2 | **Urutan sort** daftar riwayat? | Tanggal buat SO (`erdat`) terbaru di atas |
| 9.3 | **Batas jumlah baris / paginasi?** | Cap awal (mis. 100 baris) + paginasi client-side seperti Monitoring, agar tidak berat |
| 9.4 | Tampilkan kolom **"Tanggal Selesai"** (tanggal GR terakhir)? | **Skip di v1** — butuh query histori GR (MSEG/AFRU) yang menambah beban. Bisa ditambah nanti |
| 9.5 | Tampilkan **Nilai SO** (`netwr` + `waerk`) di list? | Ya, sebagai info tambahan (data sudah ada di VBAK) |
| 9.6 | Dasar **rentang tanggal**: tanggal buat SO (`erdat`) atau tanggal selesai produksi? | `erdat` dulu (sederhana). Tanggal selesai menyusul bila 9.4 disetujui |
| 9.7 | Perlu **indikator/empty state** khusus saat tidak ada SO selesai? | Ya, pesan "Tidak ada SO selesai pada rentang ini." |

---

## 10. Rencana Implementasi Bertahap

1. **Fase 1 — Navbar & kerangka**
   - Tambah link "Riwayat" di navbar `index.htm`, `monitoring.htm`.
   - Buat `riwayat.htm` kerangka (header, navbar, footer) — tampil kosong dulu.
2. **Fase 2 — Query & filter inti**
   - Implement SELECT VBAK/VBAP/AFPO + klasifikasi + filter "semua item GR 100%".
3. **Fase 3 — Filter bar**
   - Form rentang tanggal + customer + nomor SO (GET).
4. **Fase 4 — List + panel detail**
   - Render list (`row-<vbeln>` + `viewDetails`) + `main-panel-container`.
5. **Fase 5 — Polish**
   - Empty state, format angka (`num-fmt`/`cur-fmt`), guard performa, sort/paginasi (sesuai 9.x).

---

## 11. Testing & Urutan Deploy (SE80)

- Aktifkan ulang `index.htm` & `monitoring.htm` (navbar berubah).
- Aktifkan `riwayat.htm` baru.
- Pastikan `ZCL_CS_UTIL` sudah aktif (sudah terpasang).
- Uji: buka Riwayat → cek hanya SO selesai yang muncul → uji filter tanggal/customer/SO →
  klik baris → panel detail tampil benar (Ringkasan/Item & BOM/Info Order).
- Uji kasus kosong (rentang tanpa SO selesai).

---

## 12. Risiko / Catatan

- **Beban query**: tanpa batas tanggal, arsip bisa besar. Wajib ada default rentang + guard FAE.
- **Konsistensi "selesai"**: pastikan definisi GR 100% sama persis dengan Monitoring agar tidak
  membingungkan user (SO yang di Monitoring "Selesai" harus muncul di Riwayat, dan sebaliknya).
- **Reuse `monitoring_detail.htm`**: tidak diubah — aman, tapi berarti panel detail tetap menampilkan
  data produksi terkini (live), bukan snapshot historis. Sesuai kebutuhan saat ini (arsip = daftar,
  detail = kondisi aktual).
