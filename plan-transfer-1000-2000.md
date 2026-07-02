# Planning Development — Tab Baru "Transfer Material 1D00 → 2KCS"

> Rencana pengembangan tab ke-4 pada Central Storage Dashboard (ZBSP_CS_APP).
> Tujuan: melihat **material apa saja dari Plant 1000 / Sloc 1D00 yang akan & sudah dikirim
> ke Plant 2000 / Sloc 2KCS**, untuk memenuhi kebutuhan produksi Plant 2000.
> Disusun berdasarkan tanya-jawab requirement (lihat §1). Status dokumen: **DRAFT / PLAN**.

---

## 1. Ringkasan Requirement (hasil konfirmasi)

| Aspek | Keputusan |
|-------|-----------|
| **Proses SAP** | **Transfer Posting (MB1B)** — gerakan **1-step 301** (plant→plant) / 311 (sloc). Sumber aktual: **MSEG/MKPF**. |
| **Definisi "akan dikirim"** | Tampilkan **dua status**: *Belum Dikirim* & *Sudah Dikirim*. (Karena 1-step **tidak** ada in-transit, status "in-transit" tidak berlaku → diganti "Belum/Sudah Dikirim".) |
| **Sumber "Belum Dikirim"** | **Kebutuhan produksi Plant 2000** — reservasi (**RESB**) order produksi 2000 yang komponennya bersumber di 1D00. |
| **Cakupan material** | **Semua** material transfer, **dengan opsi filter** (material / tanggal / dokumen / status). |
| **Kolom tampilan** | ① Material + qty + tgl rencana · ② Nomor dokumen + status · ③ Stok tersedia di 1D00 · ④ SO/produksi terkait. |

**Rute fisik:** `Plant 1000 / Sloc 1D00` → `Plant 2000 / Sloc 2KCS`.

---

## 2. Catatan Penting, Asumsi & Risiko (WAJIB dibaca sebelum coding)

1. **MB1B tidak punya status "rencana".** Transfer posting hanya mencatat pergerakan yang **sudah** terjadi (MSEG). Maka daftar "Belum Dikirim" **harus** diturunkan dari **kebutuhan** (reservasi RESB), bukan dari MSEG. Ini disepakati.

2. **1-step = tidak ada in-transit.** Gerakan 301/311 memindah stok dalam satu posting. Tidak ada tahap "sudah GI, belum GR". Jadi status sistem cuma **2**: *Belum Dikirim* (masih perlu) vs *Sudah Dikirim* (sudah diposting).
   - ⚠️ **Verifikasi:** 311 hanya untuk sloc→sloc dalam **satu plant** — tidak bisa lintas plant 1000→2000. Untuk lintas-plant 1-step, gerakan standar adalah **301**. Pastikan movement type sebenarnya via **MB51/ST05** (bisa jadi 301, 301+311 dua langkah, atau Z-movement).

3. **Model data "Belum Dikirim" perlu diverifikasi di sistem** (paling berisiko). Ada dua kemungkinan struktur reservasi — cek dulu di **SE16 → RESB**:

   | Model | Kondisi | Cara deteksi | Kelebihan |
   |-------|---------|--------------|-----------|
   | **A — Reservasi transfer langsung** | Ada reservasi MB1B bergerakan 301/311 dengan `RESB-WERKS='1000'`, `LGORT='1D00'`, `UMWRK='2000'`, `UMLGO='2KCS'` | RESB `bwart IN (301,311)` + open qty | Paling akurat & sederhana; benar-benar "akan dikirim" |
   | **B — Turunan shortage produksi** | Hanya ada reservasi komponen order produksi 2000 (`RESB-WERKS='2000'`), tidak ada reservasi transfer | Kebutuhan komponen 2000 (RESB open) − stok di 2KCS (MARD) = kekurangan → dipenuhi dari 1D00 | Tetap jalan walau tak ada reservasi transfer |

   **Rekomendasi:** cek apakah **Model A** ada. Jika ya → pakai A (jauh lebih sederhana & tepat). Jika tidak → pakai **Model B** (perlu perhitungan shortage). Plan di bawah menulis keduanya; pilih saat implementasi setelah cek RESB.

4. **Konsistensi Plant 2000.** Sesuai audit sebelumnya, aplikasi hanya menyentuh kebutuhan Plant 2000. Tab ini menambah pembacaan Plant **1000** khusus untuk stok sumber (1D00) & transfer keluar — ini **disengaja** dan terbatas pada konteks transfer, bukan mencampur kebutuhan produksi plant lain.

### 2b. Kebenaran Angka "Sudah Dikirim" (KRITIS — jangan dilewat)

5. **Netting pembatalan/reversal.** Posting 301 dapat dibatalkan (mvt **302**) atau di-reverse. Bila tidak di-net → "Sudah Dikirim" **over-count**. Solusi: (a) filter dokumen pembatal `MSEG-SMBLN = ' '` (baris ini bukan hasil pembatalan) **dan** kecualikan baris yang **dibatalkan** oleh dokumen lain; atau (b) jumlahkan qty ber-tanda `SHKZG` (H = kredit/keluar, S = debit) sehingga reversal saling meniadakan. Tetapkan saat Fase 0.

6. **Struktur baris MSEG 301.** Gerakan 301 satu-langkah bisa menulis **sepasang baris** (keluar 1000 + masuk 2000) atau memakai `SHKZG` debit/kredit. Salah filter → **dobel hitung**. **Wajib** baca 1 dokumen contoh di SE16/MSEG untuk memastikan baris mana yang mewakili "kirim 1D00→2KCS" (biasanya baris `WERKS=1000, LGORT=1D00, SHKZG='H'`).

7. **Konsistensi satuan (UoM).** `RESB-BDMNG`, `MSEG-MENGE`, `MARD-LABST` dapat berbeda satuan (base vs order unit). **Jangan** menjumlah qty lintas material; tampilkan `MEINS` per baris. Perbandingan Butuh/Terkirim per material harus dalam satuan yang sama (pakai base unit).

8. **Hindari dobel-hitung Belum vs Sudah → pakai REKONSILIASI per material.** Satu material bisa sebagian terkirim, sebagian belum. Alih-alih dua daftar terpisah, tampilkan **satu baris per material**: `Butuh (RESB-BDMNG) | Terkirim (RESB-ENMNG atau Σ MSEG) | Sisa | Stok 1D00`. `RESB-ENMNG` sudah mencerminkan qty terpenuhi, jadi **Sisa = Butuh − Terkirim** = jawaban "yang AKAN dikirim". Ini lebih jujur & langsung menjawab kebutuhan Anda.

9. **Batch (CHARG).** Bila material dikelola batch, transfer terjadi per batch — pertimbangkan kolom `CHARG` (`MSEG-CHARG` / `RESB-CHARG`) bila relevan.

10. **Makna "Tanggal" beda per konteks.** Belum/Sisa → `RESB-BDTER` (tgl kebutuhan). Sudah → `MKPF-BUDAT` (tgl posting aktual). Beri label kolom yang jelas agar tak rancu.

---

## 3. Konstanta Baru (di halaman baru)

```abap
CONSTANTS:
  lc_src_plant TYPE werks_d  VALUE '1000',   " plant sumber
  lc_src_sloc  TYPE lgort_d  VALUE '1D00',   " sloc sumber
  lc_dst_plant TYPE werks_d  VALUE '2000',   " plant tujuan (Central Storage)
  lc_dst_sloc  TYPE lgort_d  VALUE '2KCS',   " sloc tujuan
  lc_mvt_out   TYPE bwart    VALUE '301'.     " gerakan transfer (VERIFIKASI: 301/311/Z)
```

> Pertimbangkan memusatkan konstanta plant di satu include bersama (lihat backlog D4) karena kini
> ada 2 plant + 2 sloc yang dipakai lintas halaman.

---

## 4. Sumber Data (Tabel · Kolom · Filter)

### 4.1 Bagian "SUDAH DIKIRIM" — transfer aktual (MSEG + MKPF)

| # | Tabel | Kolom | Filter / Kunci | Untuk |
|---|-------|-------|----------------|-------|
| 1 | **MSEG** | `mblnr, mjahr, zeile, bwart, matnr, werks, lgort, umwrk, umlgo, menge, meins, aufnr` | `bwart = lc_mvt_out` `AND werks = '1000' AND lgort = '1D00'` `AND umwrk = '2000' AND umlgo = '2KCS'` | Baris transfer keluar 1D00→2KCS |
| 2 | **MKPF** | `mblnr, mjahr, budat, usnam` | FAE `lt_mseg`, `mblnr=… AND mjahr=…` | Tanggal posting (tgl kirim aktual) + user |
| 3 | **MAKT** | `matnr, maktx` | FAE material, `matnr=… AND spras=sy-langu` | Nama material |

> **Rentang tanggal:** batasi `MKPF-BUDAT` pada horizon (mis. 90 hari) agar query ringan — konsisten pola dashboard. `MSEG-AUFNR` untuk tautan ke order/SO (§4.3).
>
> **Netting reversal (WAJIB, §2b-5/6):** tambah kolom `smbln, shkzg, charg` ke SELECT MSEG.
> Kecualikan/net baris pembatalan — mis. `smbln = ' '` dan agregasi qty mengikuti `SHKZG`
> (H keluar, S masuk) sehingga 302/pembalikan saling meniadakan. Pastikan struktur baris 301
> di sistem Anda dulu (baca 1 dokumen contoh) sebelum mengunci filter ini.

### 4.2 Bagian "BELUM DIKIRIM" — kebutuhan yang belum dipenuhi (RESB)

**Model A (reservasi transfer langsung — utamakan bila ada):**

| # | Tabel | Kolom | Filter / Kunci | Untuk |
|---|-------|-------|----------------|-------|
| 1 | **RESB** | `rsnum, rspos, matnr, werks, lgort, umwrk, umlgo, bdmng, enmng, meins, bdter, aufnr, bwart, xloek, kzear` | `bwart IN (301,311) AND werks='1000' AND lgort='1D00'` `AND umwrk='2000' AND umlgo='2KCS'` `AND xloek=' ' AND kzear=' '` `AND (bdmng − enmng) > 0` | Qty yang belum dipindah = `bdmng − enmng`, tgl rencana = `bdter` |

**Model B (turunan shortage produksi 2000 — fallback):**

| # | Tabel | Kolom | Filter / Kunci | Untuk |
|---|-------|-------|----------------|-------|
| 1 | **RESB** | `matnr, werks, lgort, bdmng, enmng, meins, bdter, aufnr, xloek, kzear` | `werks='2000' AND xloek=' ' AND kzear=' '` `AND (bdmng−enmng)>0` | Kebutuhan komponen produksi 2000 |
| 2 | **MARD** | `matnr, labst` | `werks='2000' AND lgort='2KCS'` | Stok tersedia di tujuan |
| 3 | (kalkulasi) | — | `shortage = Σ(bdmng−enmng) − labst_2KCS`, jika `>0` → perlu dikirim dari 1D00 | Qty "akan dikirim" |

### 4.3 Kolom pelengkap (dipakai kedua bagian)

| # | Tabel | Kolom | Filter / Kunci | Untuk |
|---|-------|-------|----------------|-------|
| A | **MARD** | `matnr, labst` | `werks='1000' AND lgort='1D00' AND labst>0` | **Kolom "Stok di 1D00"** (ketersediaan sumber) |
| B | **AFPO** | `aufnr, kdauf, kdpos` | FAE `aufnr` dari RESB/MSEG | Order produksi → nomor **SO (kdauf)** |
| C | **VBAK** | `vbeln, kunnr` | FAE `kdauf` | **SO terkait** + customer |
| D | **KNA1** | `kunnr, name1` | FAE `kunnr` | Nama customer (opsional) |

> Tautan **SO/produksi terkait**: `RESB-AUFNR`/`MSEG-AUFNR` → `AFPO-AUFNR` → `AFPO-KDAUF` = nomor SO. Bila reservasi/transfer tidak ber-`aufnr` (transfer stok murni), kolom SO dikosongkan.

---

## 5. Logika Penurunan Data — **model REKONSILIASI per material** (§2b-8)

Alih-alih dua daftar terpisah, hasil akhir = **satu baris per material** (opsional per material+SO):
`Butuh | Terkirim | Sisa | Stok 1D00 | Status`.

```
1. Baca parameter filter (material, tgl_from/to, status, dokumen).

2. BUTUH (kebutuhan yang harus ada di 2KCS):
   - (Model A) RESB transfer 1D00→2KCS: Butuh=BDMNG, Terkirim=ENMNG, Sisa=BDMNG−ENMNG.
     (Model B) RESB kebutuhan produksi 2000 (open) − stok 2KCS = shortage → Sisa.
   - Agregasi per MATNR (jumlah dalam BASE UNIT; jangan campur satuan).

3. TERKIRIM (verifikasi/aktual):
   - SELECT MSEG (301, 1000/1D00→2000/2KCS) dalam rentang tgl.
   - NET reversal (SHKZG / SMBLN, §2b-5/6). JOIN MKPF (budat).
   - Model A: Terkirim boleh diambil dari RESB-ENMNG (lebih sederhana) —
     MSEG dipakai untuk kolom "tgl kirim terakhir" & nomor dokumen.

4. LENGKAPI tiap material:
   - Stok 1D00  ← MARD (werks=1000, lgort=1D00).
   - Nama       ← MAKT.
   - SO terkait ← AUFNR (RESB/MSEG) → AFPO → KDAUF → VBAK (+KNA1).

5. Hitung status per baris:
   - Sisa = 0            → 'Sudah Dikirim'  (hijau)
   - Sisa > 0            → 'Belum Dikirim'  (oranye)
   - Sisa > 0 & Stok1D00 < Sisa → tandai 'Kurang stok sumber' (merah)

6. Terapkan filter (status/material/tgl/dok/**SO**), urutkan, render tabel.
   - Filter **SO**: pertahankan baris yang KDAUF (dari AUFNR→AFPO) = SO dicari.
     Baris transfer tanpa AUFNR (stok murni) TIDAK muncul saat filter SO aktif.
```

**Ringkasan tabel yang diakses tab ini:** RESB, MSEG, MKPF, MARD, MAKT, AFPO, VBAK, (KNA1 opsional).

---

## 6. Arsitektur Halaman (ikuti pola yang ada)

| Komponen | Rencana |
|----------|---------|
| **File halaman** | `Page with Flow Logic/transfer.htm` (BSP Page with Flow Logic, pola sama `monitoring.htm`). |
| **Navbar** | Tambah tab ke-4 **di semua halaman**: `index.htm`, `monitoring.htm`, `riwayat.htm`, `transfer.htm`. Ikon usulan `&#128666;` (truk) / `&#8644;` (transfer). |
| **Filter** | Form `method="get"` (idempotent, konsisten B4): material, **nomor SO**, rentang tanggal, status (Semua/Belum/Sudah), nomor dokumen. Filter SO lewat ALPHA-conversion, cocokkan ke `KDAUF` hasil `AUFNR→AFPO`. |
| **Tabel data** | Reuse gaya `.so-item-row` / tabel item + `.badge` untuk status. Format angka via `formatNumbers()` (js.js). |
| **Paginasi** | Reuse pola sidebar (`data-type`, `renderPagination()` di js.js) bila baris banyak. |
| **CSS/JS** | Reuse `style.css` & `js.js`. Tambah kelas badge status baru bila perlu (`.tf-belum` / `.tf-sudah`). Bump cache-buster `?r=`. |
| **Helper** | Reuse `ZCL_CS_UTIL=>fmt_date`, `css_pct` (bila ada bar pemenuhan). |
| **AJAX detail** | v1 **tidak perlu** — cukup tabel. (Opsional v2: klik baris → riwayat pergerakan material.) |

---

## 7. Rancangan UI (v1)

```
┌─ Navbar: Dashboard | Monitoring | Riwayat | [Transfer] ─────────────────────┐
│ Judul: Transfer Material 1D00 → 2KCS (Plant 1000 → Plant 2000)              │
│                                                                             │
│ [Material ___] [No SO ___] [Tgl __ s/d __] [Status ▾] [No Dok ___] [Cari]   │
│                                                                             │
│  KPI kecil: Perlu Dikirim: N material · Total Sisa qty … · Kurang stok: K   │
│                                                                             │
│  ┌ Tabel (REKONSILIASI per material) ──────────────────────────────────┐    │
│  │ Material | Nama | Butuh | Terkirim | Sisa | Sat | Stok 1D00 | SO | Status │
│  │ 6100xxxx | ...  |  100  |    60    │  40  | PC  |   120     |10..| ● Belum │
│  │ 6100yyyy | ...  |   50  |    50    │   0  | KG  |    80     |10..| ● Sudah │
│  │ 6100zzzz | ...  |   80  |    10    │  70  | PC  |    30 ⚠   |10..| ● Kurang│
│  └──────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘
```

- **Sisa = Butuh − Terkirim** = qty yang **AKAN dikirim** (inti pertanyaan).
- **Badge status:** `● Belum Dikirim` (Sisa>0, oranye) · `● Sudah Dikirim` (Sisa=0, hijau) · `● Kurang stok` (Sisa>Stok 1D00, merah ⚠).
- **Satuan (Sat)** ditampilkan per baris — jangan jumlahkan lintas material.
- Kolom **SO** bisa diklik → `monitoring.htm?so_num=…` (reuse navigasi).
- Baris dapat di-expand (opsional v2) → daftar dokumen MB1B (MSEG) + tgl kirim per pergerakan.

---

## 8. Rencana Implementasi Bertahap

| Fase | Aktivitas | Status |
|------|-----------|--------|
| **0. Verifikasi data** | MB51 movement type; SE16 RESB Model A/B; `UMWRK/UMLGO`, `SHKZG`, UoM, batch | ⏳ **MENUNGGU ANDA** (butuh akses SAP) — worksheet §8.1 |
| **1. Skeleton halaman** | `transfer.htm` + tab ke-4 di 4 halaman | ✅ Selesai |
| **2. Basis rekonsiliasi (RESB)** | RESB → Butuh/Sisa per material + MAKT | ✅ Selesai (Model B, perlu konfirmasi Fase 0) |
| **3. Aktual MB1B (MSEG)** | MSEG+MKPF (net `SHKZG`) → tgl & dok kirim | ✅ Selesai (asumsi mvt 301) |
| **4. Kolom pelengkap** | Stok 1D00/2KCS (MARD), SO (AFPO→VBAK), status | ✅ Selesai |
| **5. Filter & status** | Material / SO / status + badge | ✅ Selesai |
| **6. Polish** | Format angka, KPI, empty-state, total, scroll, highlight kurang-stok | ✅ Selesai (paginasi & filter tgl/dok → v2) |
| **7. Dokumentasi** | `reference.md` §8b + matriks | ✅ Selesai |

> **Ringkas:** Fase 1–7 sudah dikodekan (v1). **Fase 0 wajib Anda jalankan** untuk memvalidasi 3 asumsi
> (movement type, Model A/B, netting `SHKZG`). Bila hasilnya beda, ubahannya kecil & terlokalisir di `transfer.htm`.

### 8.1. Worksheet Fase 0 (jalankan di SAP, lapor hasilnya)

| # | Cek | Transaksi / Query | Yang dicatat | Konsekuensi |
|---|-----|-------------------|--------------|-------------|
| **V1** | Movement type transfer | **MB51**: Plant `1000`, Sloc `1D00`, filter tujuan ke 2000/2KCS | Angka mvt (301? 311? Z?) | Kalau ≠ 301 → ubah `lc_mvt_out` di `transfer.htm` |
| **V2** | Struktur baris & arah | **SE16→MSEG**: buka 1 dokumen dari V1 | Baris `WERKS=1000/LGORT=1D00` → `SHKZG`=? (`H`/`S`); `UMWRK/UMLGO`=2000/2KCS? | Konfirmasi netting `SHKZG='H'` benar (bila keluar = `S`, balik tanda) |
| **V3** | Reservasi transfer (Model A) | **SE16→RESB**: `WERKS=1000, LGORT=1D00, BWART=301` | Ada baris? | **Ada → Model A** (ganti filter RESB ke 1000/1D00). **Tidak → tetap Model B** |
| **V4** | Reservasi produksi 2000 (Model B) | **SE16→RESB**: `WERKS=2000, KZEAR=' ', XLOEK=' '` | Ada baris open? `AUFNR` terisi? | Bila kosong → sumber "Butuh" perlu didefinisikan ulang |
| **V5** | Satuan (UoM) | Bandingkan `RESB-MEINS` vs `MSEG-MEINS` vs `MARD` (MMBE) 1 material | Sama atau beda? | Beda → tambah konversi base unit |
| **V6** | Batch | Material master (MM03) 1 komponen | Batch-managed? | Ya → tambah kolom `CHARG` |
| **V7** | Cocokkan angka | **MB51/MMBE/MD04** vs tampilan tab | Terkirim/Stok/Butuh cocok? | Selisih → telusuri filter terkait |

---

## 9. Pertanyaan Terbuka / Verifikasi di Sistem

- [ ] **Movement type transfer sebenarnya?** (301 / 311 / 351 / Z-movement) — cek MB51.
- [ ] **Struktur baris 301** — baca 1 dokumen di SE16/MSEG: 1 baris atau sepasang? `SHKZG` mana yang mewakili keluar 1D00? (§2b-6, cegah dobel-hitung)
- [ ] **Reversal** — bagaimana pembatalan tercatat (302 / `SMBLN`)? Konfirmasi cara netting. (§2b-5)
- [ ] **`UMWRK`/`UMLGO` (receiving plant/sloc) terisi** di MSEG untuk gerakan ini? Kalau tidak, deteksi tujuan pakai cara lain.
- [ ] **Model A ada?** Ada reservasi transfer (RESB bwart 301/311, 1D00→2KCS)? Kalau tidak → Model B.
- [ ] **Satuan (UoM)** — RESB/MSEG/MARD pakai satuan sama? Perlu konversi ke base unit? (§2b-7)
- [ ] **Batch-managed?** Perlu kolom `CHARG`? (§2b-9)
- [ ] **Reservasi ber-`AUFNR`?** Untuk tautan SO. Kalau transfer stok murni tanpa order, kolom SO kosong.
- [ ] **Horizon tanggal** untuk "Sudah Dikirim" (default 90 hari?).
- [ ] **Nama tab final:** "Transfer" / "Kiriman Masuk" / "Suplai 1D00→2KCS"?

---

## 10. Checklist Uji (setelah aktivasi)

- [ ] Aktivasi `transfer.htm` + navbar 4 tab tampil di semua halaman.
- [ ] **Terkirim** cocok dengan MB51 (material, qty, tgl, dokumen) — **setelah** netting reversal.
- [ ] **Butuh/Sisa** cocok dengan reservasi terbuka (`BDMNG−ENMNG`) / shortage nyata.
- [ ] **Reversal 302** benar-benar mengurangi angka Terkirim (uji 1 kasus batal).
- [ ] Satuan per baris benar; tidak ada penjumlahan lintas satuan.
- [ ] Stok 1D00 cocok dengan MMBE/MARD; badge "Kurang stok" muncul saat Sisa > Stok 1D00.
- [ ] Filter material/tanggal/status/dokumen/**SO** berfungsi (GET, bookmarkable).
- [ ] Filter **SO** hanya menampilkan material yang order produksinya (AUFNR→AFPO→KDAUF) milik SO tsb.
- [ ] SO terkait mengarah benar ke Monitoring.
- [ ] Format angka & tanggal konsisten; empty-state muncul saat tak ada data.
- [ ] Tidak ada full-scan berat (cek ST05).

---

## 11. Tabel Baru yang Diperkenalkan ke Aplikasi

Belum pernah dipakai di halaman lain (perlu otorisasi baca bila ada `AUTHORITY-CHECK` ke depan):
**MSEG, MKPF, RESB** (RESB & MSEG sebagian sudah dipakai di `monitoring_bom.htm` / `index.htm`), **MARD** untuk plant 1000/1D00 (baru: sebelumnya MARD hanya werks 2000).

> Setelah tab jadi, tambahkan seksi tab ini ke **`reference.md`** dan perbarui matriks tabel per halaman.
