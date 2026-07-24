# Restrukturisasi: Dashboard Grafis + Migrasi Pelacakan ke Monitoring

**Tanggal:** 2026-07-24
**File terdampak:** `ZBSP_CS_APP/Page with Flow Logic/index3a.htm`, `monitoring.htm`, `dash_feed.htm` (baru)
**Konteks:** SAP BSP ABAP, Central Storage KMI 2, Plant 1000 (Pembahanan) & Plant 2000 (Produksi) Surabaya.

---

## 1. Tujuan

Memisahkan dua fungsi yang saat ini menumpuk di `index3a.htm`:

1. **Pelacakan detail per SO+Item** (Info Order, Pembahanan, Produksi, Stok, Riwayat, form Transfer Posting) — **dipindah** ke `monitoring.htm`.
2. **`index3a.htm` ditulis ulang** menjadi **Dashboard Grafis**: ringkasan agregat pergerakan material per lokasi produksi, dikelompokkan per buyer, plus panel realtime pergerakan barang.

## 2. Ruang lingkup & rencana file

| File | Aksi |
|------|------|
| `monitoring.htm` | Isi lama SUDAH di-backup oleh user. Diganti dengan konten pelacakan SO+Item dari `index3a.htm`. Semua `action="index3.htm"` + link Reset + selector reset sessionStorage diarahkan ulang ke `monitoring.htm`. `<title>`, `<h1>`, dan navbar diselaraskan. |
| `index3a.htm` | Ditulis ulang total menjadi Dashboard Grafis (lihat §3–§5). |
| `dash_feed.htm` (baru) | Endpoint BSP yang meng-output `application/json`: N pergerakan barang terakhir. Dipanggil JS dari `index3a.htm` tiap ~15 detik. |

**Di luar ruang lingkup (keputusan user):**
- `pelacakan.htm` (twin duplikat isi lama index3a) **diabaikan** untuk sekarang — boleh menjadi stale.
- `index.htm`, `index2.htm`, `index3.htm` tidak disentuh.

## 3. Dashboard Grafis (`index3a.htm`)

### 3.1 Filter tanggal
- Default: **30 hari terakhir** berdasarkan posting date `MKPF-BUDAT` (`sy-datum - 30` s/d `sy-datum`).
- Input custom "Dari" & "Sampai" (form GET/POST ke `index3a.htm` sendiri).

### 3.2 Panel KPI ringkas
- Baris angka/bar: total SO-Item unik per lokasi (agregat semua buyer) untuk gambaran cepat. Opsional grafik bar sederhana (CSS, tanpa library eksternal — jaga tetap ringan).

### 3.3 Tabel per buyer (panel utama)
- Baris = **nama buyer** (`KNA1-NAME1`), **kecuali `KUNNR = 2000000004`** (sample customer).
- Kolom (nilai = **COUNT DISTINCT `KDAUF`+`KDPOS`** yang barangnya masuk ke lokasi tsb dalam rentang):

  | Lokasi | Plant | SLoc |
  |--------|-------|------|
  | Pembahanan | 1000 | 1D00 |
  | Central Storage | 2000 | 2KCS |
  | Machining | 2000 | 2261, 2262 |
  | Banding | 2000 | 22E2, 22E3 |
  | Sanding | 2000 | 229K |
  | QI Plant 1000 | 1000 | pergerakan QI |
  | QI Plant 2000 | 2000 | pergerakan QI |

## 4. Sumber data & aturan hitung

- **"Masuk ke lokasi"** = baris `MSEG` sisi terima (`SHKZG = 'S'`) dengan `WERKS`/`LGORT` = lokasi target, dan `BUDAT` (via join `MKPF` on `MBLNR`+`MJAHR`) dalam rentang tanggal terpilih.
- **Nilai sel** = jumlah pasangan `(KDAUF, KDPOS)` unik pada baris-baris tsb.
- **QI Plant 1000 / 2000** = SO-Item unik dengan pergerakan terkait Quality Inspection di plant tsb dalam rentang (kandidat movement type: `321`/`322`, dan/atau baris ber-`INSMK`).
  - ⚠️ **Asumsi yang harus dikonfirmasi saat implementasi**: himpunan movement type / indikator QI yang tepat. Ikuti gaya kode existing — tampilkan/laporkan bila hasil kosong agar mudah dikoreksi.
- **Buyer** = `MSEG-KDAUF` → `VBAK-KUNNR` → `KNA1-NAME1`. `GROUP BY` buyer. **Exclude `KUNNR = 2000000004`**.
- **Performa** (requirement: ringan & load cepat):
  - Batasi lewat `MKPF-BUDAT` (rentang) + daftar `WERKS/LGORT` sempit; hindari full scan `MSEG`.
  - Ambil field minimal (`mblnr mjahr matnr werks lgort shkzg bwart insmk kdauf kdpos menge meins`).
  - Agregasi COUNT DISTINCT dilakukan di ABAP (internal table + SORT/DELETE ADJACENT DUPLICATES atau HASHED lookup).
  - Nama buyer: satu SELECT batched `FOR ALL ENTRIES` ke `VBAK` lalu `KNA1`.

## 5. Realtime feed (`dash_feed.htm`)

- Halaman BSP terpisah, flow logic meng-set content-type `application/json` dan menulis array JSON N pergerakan terakhir (mis. 30 baris): `budat/cputm`, `matnr`+`maktx`, `from (werks/lgort)`, `to (werks/lgort)`, `menge`+`meins`, `buyer`, `bwart_lbl`.
- Scope sama dengan dashboard: SLoc yang dipantau, exclude `KUNNR 2000000004`.
- Di `index3a.htm`: `setInterval(fetchFeed, 15000)` + `fetch('dash_feed.htm')` → render ulang daftar realtime tanpa reload halaman. Payload kecil → tidak membebani.
- Fallback: bila `fetch` gagal, tetap tampilkan data terakhir; jangan bikin halaman error.

## 6. Migrasi konten ke `monitoring.htm`

- Pindahkan blok ABAP (deklarasi TYPES/DATA, query AFPO/AFKO/STPO/RESB/MSEG/MSKA/MARD, derive status BOM) + seluruh markup tab (Info Order, Pembahanan, Produksi, Stok Saat Ini, Riwayat Pergerakan) + form Transfer Posting + JS terkait.
- Ganti semua rujukan diri: `action="index3.htm"` → `action="monitoring.htm"`; link Reset → `monitoring.htm`; `userLogout()` target; selector reset sessionStorage.
- Pertahankan perbaikan status SO/Item terbaru (label SAP: `Open`/`Being processed`/`Completed`, sumber `VBAK-GBSTK`/`VBAP-GBSTA`) dan penataan Info Order terkini.

## 7. Navigasi

- **Dua entri navbar** di kedua halaman: **Dashboard** (`index3a.htm`) dan **Monitoring** (`monitoring.htm`), saling terhubung; entri aktif menyesuaikan halaman yang sedang dibuka.

## 8. Non-functional

- Tanpa library JS/CSS eksternal (konsisten dengan halaman existing; menjaga ringan & cepat).
- UI konsisten dengan gaya visual app saat ini (navbar, kartu, warna badge).
- ABAP mengikuti pola existing (SELECT batched `FOR ALL ENTRIES`, field-symbol untuk enrichment, konversi UoM/MATN1/ALPHA seperlunya).

## 9. Asumsi & pertanyaan terbuka

1. Movement type/indikator QI yang tepat — dikonfirmasi saat implementasi (lihat §4).
2. Field tanggal = `MKPF-BUDAT` (bukan `CPUDT`).
3. `MSEG` di sistem ini memuat `KDAUF/KDPOS` untuk pergerakan SO-stock pada SLoc target (sudah dipakai di blok Riwayat existing → diasumsikan tersedia).
4. `dash_feed.htm` boleh dibuat sebagai halaman BSP baru dalam aplikasi yang sama.
5. `pelacakan.htm` sengaja tidak disinkronkan (keputusan user).
