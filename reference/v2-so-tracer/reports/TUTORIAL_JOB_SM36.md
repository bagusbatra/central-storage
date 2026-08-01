# Tutorial: Pasang & Jadwalkan ZCS_JOB_UPDATE_SO_STATUS

Program: `reports/ZCS_JOB_UPDATE_SO_STATUS.abap`
Prasyarat (sudah ada di sistem Anda): class `ZCL_CS_SO_TRACER`, tabel `ZCS_SO_STATUS`,
lock object `EZCS_SO_JOB`.

---

## BAGIAN 1 — Buat program di SE38

Anda sudah paham dasarnya. Yang **beda kali ini** cuma dua hal:

### 1.1 Tidak ada selection screen

Program ini **sengaja tanpa `PARAMETERS`/`SELECT-OPTIONS`**. Waktu Anda tekan **F8**, dia
**langsung jalan** — tidak ada layar input dulu. Ini memang yang kita mau: background job tidak
punya orang yang mengisi layar.

Konsekuensinya: **hati-hati menekan F8.** Program ini **menulis ke tabel `ZCS_SO_STATUS`**. Sekali
tekan, dia langsung memproses semua SO eligible. Tidak ada tombol batal.

### 1.2 Langkah pembuatan

1. **SE38** → Program: `ZCS_JOB_UPDATE_SO_STATUS` → **Create**
2. Attributes:
   - **Title**: `Job: update status SO ke ZCS_SO_STATUS`
   - **Type**: **Executable Program**
   - **Status**: `Test Program` (untuk sekarang)
3. Package: **Local Object** (`$TMP`) untuk uji coba.
   > ⚠️ **Tapi ingat:** kalau nanti mau dijadwalkan sebagai job **produksi**, program **dan** class
   > `ZCL_CS_SO_TRACER` **dan** tabel `ZCS_SO_STATUS` harus sama-sama ada di package Z yang
   > transportable. Objek `$TMP` tidak bisa di-transport.
4. Paste isi file `.abap` → **Save** → **Activate** (Ctrl+F3)

---

## BAGIAN 2 — Test manual dulu (WAJIB, jangan langsung dijadwalkan)

Menjadwalkan job yang belum pernah diuji itu resep bencana: dia akan gagal diam-diam tiap 15 menit
dan Anda baru tahu berhari-hari kemudian.

### 2.1 Cek dulu berapa SO yang akan diproses

**Sebelum** menjalankan programnya, cek dulu volume kerjanya. Buka **SE16N** → tabel `VBUP`, atau
lebih baik jalankan query ini lewat SE16N di `VBAK`:

- Filter: `VDATU` ≤ (hari ini + 180 hari)

Perkirakan berapa item SO yang akan lolos filter. **Ini penting**, karena:

> **1 SO ≈ 6–7 detik.** Kalau ada **100 SO eligible**, satu run ≈ **11 menit**. Kalau ada **200 SO**,
> ≈ **22 menit** — dan itu **lebih lama dari interval job 15 menit**, yang artinya job berikutnya akan
> selalu menemukan lock terpakai dan melewatkan diri (dilaporkan di log sebagai "Job lain sedang
> berjalan"). Bukan error, tapi jadwal 15 menit Anda praktis tidak terpakai.
>
> **Kalau perkiraan Anda > ~100 SO, jangan pakai interval 15 menit.** Naikkan jadi 1 jam, atau
> persempit filter eligible-nya (misal 90 hari, bukan 180).

### 2.2 Jalankan sekali secara manual

**F8** di SE38. Program langsung jalan. **Tunggu** — bisa beberapa menit, layarnya diam.

Setelah selesai, akan muncul list output seperti ini:

```
=== ZCS_JOB_UPDATE_SO_STATUS ===
Mulai : 14.07.2026 09:15:22   User: BAGUS   Client: 100

Lock EZCS_SO_JOB berhasil diambil.
SO+Item eligible ditemukan: 12

SO 0000010478 item 000010 -> BELUM SELESAI | node: 41 | belum: 8 | 6.610,0 ms
SO 0000010479 item 000010 -> SELESAI       | node: 12 | belum: 0 | 1.204,0 ms
...
Lock EZCS_SO_JOB dilepas.

=== SUMMARY ===
SO+Item diproses      : 12
  sukses              : 12
  error (dilewati)    : 0
Baru terdeteksi CLOSED: 0
Total waktu job       : 74,3 detik
Selesai               : 14.07.2026 09:16:36
```

### 2.3 Verifikasi hasilnya masuk ke tabel

**SE16N** → tabel `ZCS_SO_STATUS` → **F8**. Cek:

- Baris untuk SO 10478 item 10 ada, `STATUS` = `BELUM SELESAI`, `TOTAL_NODE` = 41.
  **Angka ini harus sama dengan hasil `ZTEST_CS_SO_TRACER_CLS`.** Kalau beda, ada yang salah.
- `ACTIVE_FLAG` = `X`, `CLOSED_DATE` kosong.
- `RUN_DATE` / `RUN_TIME` = waktu Anda menjalankan barusan.
- `ERROR_FLAG` kosong untuk semua baris (kalau ada yang `X`, baca `ERROR_MSG`-nya).

### 2.4 Jalankan KEDUA KALINYA

Ini menguji hal yang tidak teruji di run pertama: **apakah MODIFY-nya meng-update, bukan
menduplikasi?**

Tekan F8 lagi. Lalu cek `ZCS_SO_STATUS` — **jumlah barisnya harus TETAP SAMA**, hanya `RUN_TIME`
yang berubah. Kalau barisnya bertambah dua kali lipat, berarti primary key tabelnya salah.

### 2.5 Test deteksi CLOSED (opsional tapi bagus)

Kalau mau memastikan Langkah 4 bekerja: cari satu SO di `ZCS_SO_STATUS` yang `ACTIVE_FLAG = 'X'`,
lalu di SAP tutup/complete SO itu (atau ubah `VDATU`-nya jauh ke depan >180 hari). Jalankan program
lagi. Baris itu harusnya jadi `ACTIVE_FLAG` = kosong dan `CLOSED_DATE` = hari ini.

---

## BAGIAN 3 — Jadwalkan sebagai Background Job (SM36)

**Apa itu background job?** Program yang jalan **sendiri** di server tanpa ada orang yang membukanya,
sesuai jadwal. Tidak ada layar, tidak ada user. Outputnya (semua `WRITE` di program) tidak hilang —
disimpan sebagai **Job Log** dan **Spool**, yang bisa Anda baca kapan saja lewat SM37.

### 3.1 Buka SM36

Command field → `/nSM36` → Enter. Muncul layar **Define Background Job**.

### 3.2 Isi header job

| Field | Isi |
|---|---|
| **Job name** | `ZCS_SO_STATUS_15MIN` (bebas, tapi pakai nama yang jelas — nanti Anda cari job ini di SM37 pakai nama ini) |
| **Job class** | **C** |
| **Target server / Exec. target** | **kosongkan** |

> **Job class itu apa?** Prioritas. **A** = tertinggi (dipakai job kritikal sistem), **B** = sedang,
> **C** = normal. **Pakai C.** Job kita bukan prioritas sistem; kalau dikasih A, dia bisa merebut
> work process dari job SAP yang lebih penting.

> **Target server kosong = biarkan SAP memilih server yang paling longgar.** Isi ini hanya kalau
> tim Basis Anda menyuruh.

### 3.3 Tentukan APA yang dijalankan (Step)

1. Klik tombol **Step** (di toolbar atas).
2. Muncul layar **Create Step 1**.
3. Di bagian **ABAP Program**:
   | Field | Isi |
   |---|---|
   | **Name** | `ZCS_JOB_UPDATE_SO_STATUS` |
   | **Variant** | **KOSONGKAN** |
   | **Language** | `EN` (atau biarkan default) |

   > **Kenapa Variant dikosongkan?** Variant = "isian selection screen yang disimpan". Program kita
   > **tidak punya selection screen**, jadi tidak ada yang perlu disimpan. Kalau SAP memaksa minta
   > variant, berarti Anda salah program.

4. Klik **Save** (disket). Kembali ke layar utama.
5. Klik **Back** (F3) sekali lagi kalau perlu, sampai kembali ke **Define Background Job**.

### 3.4 Tentukan KAPAN dijalankan (Start Condition)

1. Klik tombol **Start condition** (toolbar atas).
2. Muncul popup dengan beberapa tombol: **Immediate**, **Date/Time**, **After job**, **After event**,
   dll.
3. Klik **Date/Time**.
4. Isi:
   | Field | Isi |
   |---|---|
   | **Scheduled start — Date** | tanggal hari ini (atau besok) |
   | **Scheduled start — Time** | jam mulai, misal `08:00:00` |

5. **INI BAGIAN PENTINGNYA** — centang checkbox **"Periodic job"** (di bagian bawah popup).
6. Klik tombol **Period values** (aktif setelah "Periodic job" dicentang).
7. Muncul popup pilihan periode: Hourly / Daily / Weekly / Monthly / **Other period**.
8. Klik **Other period**.
9. Isi: **Minutes** = `15`. (Biarkan Hours/Days = 0.)
10. Klik centang hijau → **Save** → **Save** lagi sampai kembali ke layar utama.

### 3.5 Aktifkan job

Di layar **Define Background Job**, klik **Save** (disket).

Job sekarang **terjadwal**. Dia akan mulai pada jam yang Anda tentukan, lalu mengulang tiap 15 menit
**selamanya** sampai Anda hentikan.

---

## BAGIAN 4 — Memantau job (SM37)

### 4.1 Lihat job Anda

`/nSM37` → **Simple Job Selection**:

| Field | Isi |
|---|---|
| **Job name** | `ZCS_SO_STATUS_15MIN` (atau `ZCS*` untuk melihat semua) |
| **User name** | `*` |
| **Job status** | centang **semua** (Scheduled, Released, Ready, Active, Finished, Canceled) |
| **From date / To date** | rentang tanggal yang mau dilihat |

**F8**.

### 4.2 Arti status job

| Status | Artinya |
|---|---|
| **Scheduled** | Sudah dibuat tapi **belum dilepas** — belum akan jalan. Kalau job Anda mentok di sini, klik job → **Job → Release** |
| **Released** | Terjadwal, menunggu waktunya tiba |
| **Ready** | Waktunya sudah tiba, menunggu work process kosong |
| **Active** | **Sedang berjalan sekarang** |
| **Finished** | Selesai normal |
| **Canceled** | **Gagal / dump.** Baca Job Log-nya |

### 4.3 Baca Job Log — ini yang paling sering Anda butuhkan

1. Pilih (centang) baris job.
2. Klik tombol **Job log**.
3. Muncul log ringkas: kapan mulai, kapan selesai, ada error atau tidak.

### 4.4 Baca output WRITE program (Spool)

Job log hanya berisi pesan sistem. Semua `WRITE` di program (daftar SO, summary) masuk ke **Spool**:

1. Pilih baris job → klik **Spool**.
2. Muncul daftar spool request → double-click → **Display Contents**.
3. Di situlah summary dan detail per-SO Anda.

### 4.5 Menghentikan / mengubah job

- **Hentikan sementara**: pilih job → **Job → Released → Scheduled** (job jadi tidak jalan lagi,
  tapi definisinya tersimpan)
- **Hapus**: pilih job → tombol **Delete**
- **Ubah interval**: pilih job → **Job → Change** → **Start condition** → ubah period values
- **Jalankan sekarang juga** (tanpa menunggu jadwal): pilih job → **Job → Repeat scheduling** →
  Immediate

---

## BAGIAN 5 — Hal-hal yang perlu Anda awasi setelah job jalan

### 5.1 "Job lain sedang berjalan" muncul terus di log

Artinya: **satu run belum selesai, run berikutnya sudah datang.** Lock-nya bekerja sesuai desain
(mencegah overlap), tapi jadwal 15 menit Anda praktis tidak terpakai.

**Solusinya bukan mematikan lock-nya.** Solusinya salah satu dari:
- Perlebar interval (SM37 → Change → Start condition → Period values → 30 atau 60 menit), **atau**
- Persempit filter eligible (ubah `180` di `SELECT_ELIGIBLE` jadi 90 hari), **atau**
- Kurangi beban per SO (tapi ini berarti mengubah class-nya — pekerjaan lain).

### 5.2 Job status "Canceled"

Baca Job Log. Penyebab yang paling mungkin:

| Penyebab | Ciri di log | Solusi |
|---|---|---|
| **TIME_OUT** | job mati setelah ~10-60 menit | terlalu banyak SO. Persempit filter. Job class C punya batas waktu — tanya Basis berapa |
| **Field tidak dikenal** | error saat program dijalankan | ASUMSI-A/B/C — lihat komentar di kode |
| **Authorization** | "no authorization" | user job (biasanya user Anda sendiri) tidak punya akses ke tabel tertentu — minta Basis |

### 5.3 Lock nyangkut?

Kalau job mati mendadak, **lock dilepas otomatis** oleh SAP saat program berakhir — tidak akan macet
selamanya. Tapi kalau Anda curiga ada yang nyangkut:

`/nSM12` → isi **Table name** = `ZCS_SO_STATUS` → **F8**. Kalau ada entri padahal tidak ada job yang
`Active` di SM37, boleh dihapus manual dari layar ini.

### 5.4 Baris ERROR_FLAG = 'X'

Program **sengaja tidak berhenti** kalau satu SO gagal — dia mencatat errornya dan lanjut. Cek
berkala:

**SE16N** → `ZCS_SO_STATUS` → filter `ERROR_FLAG` = `X` → **F8**. Baca kolom `ERROR_MSG`.

Kalau SO yang sama error terus-menerus tiap run, ada masalah data di SO itu yang perlu dilihat
manual.

---

## Lampiran — Tiga ASUMSI di program ini yang WAJIB Anda cek

| Kode | Asumsi | Cara verifikasi |
|---|---|---|
| **ASUMSI-A** | `VBUP-GBSTA <> 'C'` = item masih open | **SE11 → VBUP → field GBSTA → double-click domain → tab "Value Range"**. Pastikan `C` = *Completely processed*. Kalau kodenya beda di sistem Anda, ganti di `FORM select_eligible`. **Ini yang paling penting** — kalau salah, job akan memproses SO yang sudah selesai (boros) atau melewatkan SO yang masih aktif (bahaya). |
| **ASUMSI-B** | `VBAK-VDATU` = requested delivery date | ✅ **Sudah Anda verifikasi.** Aman. |
| **ASUMSI-C** | `VBAK-KUNNR` = Sold-To Party | Kalau saat Activate muncul `Field KUNNR is unknown`, pakai fallback `VBPA` dengan `PARVW = 'AG'`. Kode fallback-nya sudah saya siapkan sebagai komentar di `FORM select_eligible`, tinggal disalin. |
