# Tutorial Instalasi & Pemakaian — ZTEST_SO_TRACE_RECURSIVE

Tutorial ini ditulis dengan asumsi **Anda baru pertama kali membuat program ABAP**.
Ikuti berurutan dari atas ke bawah. Jangan lompat.

File kode: `ZTEST_SO_TRACE_RECURSIVE.abap` (ada di folder yang sama dengan tutorial ini).

---

## Ringkasan: program ini ngapain?

Anda kasih **1 nomor Sales Order + 1 nomor item**. Program akan:

1. Cari semua **Production Order** milik SO itu (seperti yang Anda lakukan di **COOIS**).
2. Untuk tiap order, **explode BOM 1 level** (seperti **CS03**) untuk dapat daftar komponennya.
3. Tiap komponen dicek: *"komponen ini punya production order sendiri nggak?"*
   - **Punya** → berarti dia barang setengah jadi → ulangi langkah 2 untuk order itu (**rekursi turun 1 level**).
   - **Nggak punya** → berarti dia **bahan baku / barang beli** → berhenti di situ, lalu cek **stok unrestricted**-nya (seperti **MB52**).
4. Cetak hasilnya sebagai **pohon** + **summary** + **pengukuran waktu** tiap bagian.

Program ini **READ-ONLY**. Tidak ada satu pun perintah tulis ke database. Aman.

---

## BAGIAN 1 — Persiapan (5 menit)

### 1.1 Cek Anda punya akses developer

Program ABAP hanya bisa dibuat kalau Anda punya **Developer Key**. Coba dulu langkah di Bagian 2.
Kalau nanti muncul popup **"Register Developer"** atau **"Enter Access Key"**, artinya user SAP Anda
belum terdaftar sebagai developer. Hubungi **Basis team** Anda, minta:

> "Tolong daftarkan user SAP saya sebagai developer, saya butuh developer access key untuk membuat program custom di client development."

Tanpa ini, Anda tidak bisa lanjut. Ini bukan hal aneh, prosedur normal di semua perusahaan.

### 1.2 Pastikan Anda di client DEVELOPMENT

Lihat pojok kanan bawah layar SAP, ada tulisan system + client (misal `DEV 100`).
**Jangan pernah** membuat program langsung di client **Production**. Kalau ragu, tanya tim Basis
system/client mana yang boleh dipakai development.

---

## BAGIAN 2 — Membuat program baru (SE38)

Ada dua tcode yang bisa dipakai: **SE38** (khusus report, lebih sederhana) dan **SE80** (workbench
lengkap). **Kita pakai SE38** karena lebih langsung.

### 2.1 Buka SE38

1. Di layar utama SAP (SAP Easy Access), lihat kotak input di kiri atas (di sebelah tombol centang hijau).
   Itu namanya **command field**.
2. Ketik: `/nSE38`  lalu tekan **Enter**.
   - Awalan `/n` artinya "tutup transaksi sekarang, buka yang baru". Kalau command field-nya kosong
     dan Anda memang di menu utama, ketik `SE38` saja juga bisa.
3. Muncul layar **ABAP Editor: Initial Screen**.

### 2.2 Ketik nama program

Di field **Program**, ketik persis:

```
ZTEST_SO_TRACE_RECURSIVE
```

> **Kenapa harus diawali huruf Z?**
> Di SAP, nama objek yang diawali **Z** atau **Y** adalah "wilayah customer" — area yang dijamin
> tidak akan bentrok / ditimpa saat SAP melakukan upgrade. Objek standar SAP diawali huruf lain
> (misal `RM07DOCS`). Ini konvensi wajib, bukan gaya-gayaan.

### 2.3 Klik Create

Klik tombol **Create** (atau tekan **F5**).

### 2.4 Isi Program Attributes

Muncul popup **ABAP: Program Attributes**. Isi seperti ini:

| Field | Isi | Penjelasan |
|---|---|---|
| **Title** | `Telusur Rekursif SO - Order + BOM + Stok` | Judul bebas, ini yang muncul di daftar program |
| **Type** | **Executable Program** | **WAJIB pilih ini.** Ini yang dimaksud "Type 1". Kalau salah pilih (misal "Include" atau "Module Pool"), program tidak bisa dijalankan pakai F8 |
| **Status** | `Test Program` | Opsional, tapi bagus untuk menandai ini program uji coba |
| **Application** | kosongkan saja | Opsional |

Klik **Save** (ikon disket).

### 2.5 Popup Package — ini bagian yang sering bikin bingung

Muncul popup **Create Object Directory Entry** yang minta **Package**.

Anda punya **2 pilihan**:

---

#### Pilihan A — `$TMP` (Local Object) — **INI YANG SAYA SARANKAN untuk sekarang**

Klik tombol **Local Object** (biasanya ada di bawah popup).

- Package otomatis jadi `$TMP`.
- Artinya: program ini **lokal**, hanya ada di system ini, **tidak akan pernah di-transport** ke QAS/PROD.
- **Tidak butuh Transport Request sama sekali.** Popup TR tidak akan muncul.
- Cocok banget untuk program uji coba seperti ini.
- Kekurangan: kalau nanti Anda mau memindahkannya ke Production, harus dipindah dulu ke package Z
  yang benar (bisa diubah belakangan lewat SE38 → menu **Goto → Object Directory Entry**).

Karena program ini eksplisit untuk **TESTING & PENGUKURAN PERFORMA**, **pilih ini**. Selesai,
langsung lompat ke **Bagian 3**.

---

#### Pilihan B — Package Z (kalau memang mau di-transport)

Kalau perusahaan Anda mewajibkan semua objek masuk package resmi:

1. Ketik nama package Z perusahaan Anda (tanya tim ABAP, misal `ZPP`, `ZDEV`, `ZCS`).
2. Klik **Save**.
3. Muncul popup **Prompt for Transportable Workbench Request**:
   - **Kalau sudah ada TR yang terbuka atas nama Anda** → pilih dari daftar (klik ikon "Own Requests"
     untuk melihat TR milik Anda), lalu klik centang hijau.
   - **Kalau belum punya TR** → klik tombol **Create Request** (ikon kertas kosong / "Own Requests" →
     "Create"):
     - **Short Description**: isi misal `Program telusur rekursif SO - testing`
     - Klik **Save** (disket).
     - TR baru dibuat, nomornya seperti `DEVK900123`. **Catat nomor ini** — nanti dibutuhkan
       kalau mau transport ke QAS/PROD.
     - Klik centang hijau untuk memilih TR tadi.

> **Apa itu Transport Request (TR)?**
> Bayangkan TR seperti "kotak paket". Semua perubahan yang Anda buat (program, tabel, dll) dimasukkan
> ke kotak ini. Nanti tim Basis akan "mengirim" kotak ini dari system DEV → QAS → PROD, supaya
> perubahan Anda ikut pindah. Objek dengan package `$TMP` tidak masuk kotak manapun — dia tinggal
> selamanya di DEV. Itulah kenapa `$TMP` tidak butuh TR.

---

## BAGIAN 3 — Paste kode

1. Sekarang Anda ada di layar **ABAP Editor** (layar hitam/putih besar tempat menulis kode).
   Isinya mungkin sudah ada 1-2 baris otomatis seperti `REPORT ztest_so_trace_recursive.`

2. **Hapus semua isinya dulu**:
   - Klik di area kode.
   - Tekan **Ctrl+A** (select all), lalu **Delete**.

3. **Buka file `ZTEST_SO_TRACE_RECURSIVE.abap`** di komputer Anda (pakai Notepad / VS Code).
   Tekan **Ctrl+A**, lalu **Ctrl+C** (copy semua).

4. Kembali ke SAP, klik di area kode, tekan **Ctrl+V** (paste).

5. Klik **Save** (disket / **Ctrl+S**).

> **Kalau paste-nya gagal / cuma sebagian masuk:**
> SAP GUI kadang bermasalah dengan paste teks sangat panjang. Alternatifnya:
> menu **Utilities → More Utilities → Upload/Download → Upload**, lalu pilih file `.abap` tadi
> dari komputer Anda. Isinya akan dimuat langsung ke editor.

---

## BAGIAN 4 — Isi teks selection screen (opsional tapi disarankan)

Program ini memakai **text symbol** (`text-b01`, `text-b02`, `text-b03`) untuk judul kotak di
selection screen, dan **selection text** untuk label tiap field. Kalau tidak diisi, program **tetap
jalan normal**, cuma labelnya kosong/jelek. Cara mengisinya:

### 4.1 Text symbols (judul kotak)

1. Dari ABAP Editor: menu **Goto → Text Elements → Text Symbols**.
2. Di tab **Text Symbols**, isi:

| Sym | Text |
|---|---|
| `B01` | `Input Sales Order` |
| `B02` | `Metode BOM Explosion` |
| `B03` | `Opsi Performa` |

3. Klik **Save**, lalu **Activate** (Ctrl+F3).

### 4.2 Selection texts (label field)

1. Masih di layar Text Elements, klik tab **Selection Texts**.
2. Isi kolom **Text**:

| Name | Text |
|---|---|
| `P_VBELN` | `SO Number` |
| `P_POSNR` | `SO Item` |
| `P_DEPTH` | `Max Recursion Depth` |
| `P_BOM_FM` | `BOM: pakai FM standar SAP` |
| `P_BOM_TB` | `BOM: baca tabel langsung` |
| `P_CAPID` | `BOM Application (CAPID)` |
| `P_STLAN` | `BOM Usage (STLAN)` |
| `P_OMEMO` | `Order-level memoization` |
| `P_BOMC` | `Cache BOM explosion per material` |
| `P_CACHE` | `Cache stok + deskripsi material` |
| `P_TRACE` | `Cetak trace detail` |

3. **Save** → **Activate**.
4. Kembali ke kode: tekan **F3** (Back).

---

## BAGIAN 5 — Activate program

**Activate** = "kompilasi + jadikan versi aktif". Program yang cuma di-Save tapi belum di-Activate
**tidak bisa dijalankan**.

1. Tekan **Ctrl+F3**, atau klik ikon **korek api / kembang api** (Activate) di toolbar.
2. Kalau muncul popup daftar objek yang mau di-activate, **centang semua**, klik centang hijau.

### 5.1 Kalau muncul SYNTAX ERROR

Di bagian bawah layar akan muncul pesan merah. Contoh:

```
E:Field "AFKO~DISPO" is unknown. It is neither in one of the specified tables
  nor defined by a "DATA" statement.
```

**Cara membacanya:**

| Bagian pesan | Artinya |
|---|---|
| `E:` | E = Error (harus dibetulkan). `W:` = Warning (boleh diabaikan) |
| `Field "AFKO~DISPO" is unknown` | Field `DISPO` **tidak ada** di tabel `AFKO` **di sistem Anda** |
| nomor baris | Klik dua kali pada pesan errornya → kursor otomatis lompat ke baris yang salah |

**Error yang PALING MUNGKIN Anda temui** (dan ini justru wajar, karena tiap sistem SAP beda):
semuanya soal **nama field/tabel yang saya asumsikan**. Cara membetulkannya ada di
**Bagian 8 (Daftar Asumsi)** di bawah. Jangan panik — semua sudah saya tandai di kode dengan
komentar `ASUMSI #n`.

Cara cepat mengecek: tekan **Ctrl+F2** (Check Syntax) kapan saja untuk melihat error tanpa activate.

---

## BAGIAN 6 — Menjalankan program

### 6.1 Jalankan

Tekan **F8** (Execute), atau klik ikon jam/orang berlari di toolbar.

### 6.2 Isi selection screen

Muncul layar input. Isi seperti ini:

```
--- Input Sales Order ---------------------------------
SO Number ............ [ 0000012345 ]   <- nomor SO Anda
SO Item .............. [ 10         ]   <- ketik 10 saja, SAP otomatis jadi 000010
Max Recursion Depth .. [ 10         ]   <- biarkan default

--- Metode BOM Explosion ------------------------------
(o) BOM: pakai FM standar SAP      <- biarkan terpilih untuk run pertama
( ) BOM: baca tabel langsung
BOM Application (CAPID) [ PP01 ]
BOM Usage (STLAN) ..... [ 1    ]

--- Opsi Performa -------------------------------------
[x] Order-level memoization          <- biarkan ON
[x] Cache BOM explosion per material <- biarkan ON
[x] Cache stok + deskripsi material  <- biarkan ON
[ ] Cetak trace detail
```

**Dari mana dapat nomor SO untuk dicoba?**
Kalau belum punya contoh, cari dulu SO yang **pasti punya production order**:
- Buka tcode **COOIS**
- Di field **Sales Order**, kosongkan; jalankan dengan filter plant Anda saja
- Ambil satu baris hasilnya, lihat kolom **Sales Order** dan **Sales Order Item**
- Pakai nilai itu di program ini

> **Saran run pertama:** pakai **Max Recursion Depth = 2** dulu. Kalau langsung 10 dan BOM Anda
> ternyata sangat dalam/lebar, program bisa lama sekali di percobaan pertama. Naikkan bertahap
> setelah tahu bentuk datanya.

Tekan **F8** lagi untuk eksekusi.

### 6.3 Kalau program terasa menggantung (hang)

Tekan tombol **Cancel** di SAP GUI, atau dari session lain buka tcode **SM50** → cari proses Anda →
**Process → Cancel Without Core**. Lalu jalankan ulang dengan `Max Recursion Depth` lebih kecil.
Program sudah punya pengaman circular-BOM, tapi BOM yang sangat lebar tetap bisa makan waktu lama.

---

## BAGIAN 7 — Membaca hasil output

Outputnya 3 blok:

### Blok 1 — POHON

```
 #  LV  TIPE         ORDER        MATERIAL (indent = level)  DESKRIPSI      PLNT MRP TARGET QTY  QTY ADA  UOM STATUS         SYSTEM STATUS / KETERANGAN
------------------------------------------------------------------------------------------------------------------------------------------------------
 1   0  [ORDER]      1000012345   MAT-JADI-A                 Meja Jati      2000 001     10,000   10,000  PC  SELESAI        REL DLV TECO
 2   1  [ORDER]      1000012346     +- MAT-SETENGAH-B        Kaki Meja      2000 002     40,000   20,000  PC  BELUM SELESAI  REL PRC CNF
 3   2  [BHN BAKU]   -               +- KAYU-JATI-RAW        Kayu Jati Log  2000         80,000  150,000  M3  TERSEDIA
 4   2  [BHN BAKU]   -               +- LEM-X                Lem Kayu       2000          5,000    2,000  KG  BELUM
 5   1  [BHN BAKU]   -             +- SEKRUP-M5              Sekrup M5      2000         20,000   90,000  PC  TERSEDIA
 6   0  [ORDER]      1000012399   MAT-JADI-C                 Kursi Jati     2000 001      5,000    0,000  PC  BELUM SELESAI  REL
 7   1  [SUDAH ADA]  1000012346     +- MAT-SETENGAH-B        Kaki Meja      2000 002     40,000   20,000  PC  BELUM SELESAI  Sudah ditelusuri di node #2 - lihat baris tsb
```

Cara bacanya:

- **#** = nomor node. Dipakai oleh baris `[SUDAH ADA]` untuk menunjuk ke node aslinya.
- **LV** = kedalaman. `0` = production order utama milik SO. `1` = anaknya. `2` = cucunya. Dst.
- **Indentasi + tanda `+-`** menunjukkan siapa anak siapa. `KAYU-JATI-RAW` (LV 2) adalah komponen
  dari `MAT-SETENGAH-B` (LV 1), bukan dari `MAT-JADI-A`.
- **[ORDER]** = material ini **diproduksi sendiri** (punya production order). Kolom **QTY ADA** =
  Delivered Qty (sudah di-GR berapa).
- **[BHN BAKU]** = material ini **tidak punya production order** → dianggap bahan baku/beli.
  Kolom **QTY ADA** = **stok unrestricted** (setara MB52).
- **STATUS**:
  - `SELESAI` (order) = Delivered Qty >= Target Qty
  - `TERSEDIA` (bahan baku) = Stok Unrestricted >= Target Qty
  - `BELUM SELESAI` / `BELUM` = sebaliknya. Baris ini diwarnai **merah**.
- **[SUDAH ADA]** = order ini **sudah pernah ditelusuri tuntas** di cabang lain (lihat contoh node #7:
  `MAT-SETENGAH-B` dipakai baik oleh meja maupun kursi). Program **sengaja tidak menelusurinya ulang** —
  itulah optimasinya. Barisnya berwarna **netral** (bukan hijau/merah) supaya jelas ini cuma rujukan,
  bukan hasil hitungan baru. Statusnya diambil dari hasil penelusuran aslinya. Untuk melihat rincian
  anak-anaknya, lihat nomor node yang disebut di kolom keterangan.
- **[WARNING]** = cabang dihentikan. Ada 2 sebab: **circular BOM** (material muncul lagi di jalur yang
  sama) atau **max depth tercapai**. Kalau muncul ini, pohonnya **tidak lengkap**.

### Blok 2 — SUMMARY

```
SUMMARY
Total node ditelusuri  : 6   ( ORDER: 3 , BAHAN BAKU: 3 )
Node REF (rujukan)     : 1   (order yang sudah ditelusuri di cabang lain - TIDAK dihitung ulang di atas)
STATUS KESELURUHAN SO  : BELUM SELESAI
                         3 node belum selesai / stok kurang.
                         1 node REF menunjuk ke sub-tree yang belum selesai.
```

**STATUS KESELURUHAN SO** = `SELESAI` **hanya kalau SEMUA node** (order maupun bahan baku) statusnya
selesai/tersedia. Cukup 1 node merah → keseluruhan jadi `BELUM SELESAI`. Ini sesuai spec Anda.

**Node REF tidak ikut dihitung** di "Total node ditelusuri" — supaya order yang sama tidak dihitung
dua kali. Tapi **statusnya tetap ikut menentukan** STATUS KESELURUHAN SO, jadi angka akhirnya tetap
akurat.

### Blok 3 — PENGUKURAN PERFORMA  ← ini tujuan utama program

```
PENGUKURAN PERFORMA  (GET RUN TIME FIELD, satuan mikrodetik)
Waktu TOTAL eksekusi        :      1.245,320 ms  (      1245320 us )
-------------------------------------------------------------------
  PRELOAD semua order (1x)  :        160,000 ms  |  12,8 %  |    42 order ditarik sekaligus
  Pencarian ORDER (lookup)  :          0,110 ms  |   0,0 %  | dipanggil    42 x  <- bukan query DB lagi
  BOM EXPLOSION (CS03)      :        920,500 ms  |  73,9 %  | dipanggil     8 x
  CEK STOK (MB52)           :         98,200 ms  |   7,8 %  | dipanggil    15 x
  BACA RESERVATION (RESB)   :         44,300 ms  |   3,5 %  | dipanggil    15 x
-------------------------------------------------------------------
Order-level cache HIT       :    89 x  <-- sebanyak ini penelusuran sub-tree BERHASIL DIHINDARI
BOM-explosion cache HIT     :     6 x  (per material+plant+qty)
Cache hit stok              :    22 x  (query DB yang berhasil dihindari)
Cache hit deskripsi materi  :    41 x
```

**Cara membuktikan penghematannya (ini yang Anda tunggu):**

Jalankan **dua kali** dengan SO yang sama:

1. Sekali dengan checkbox **"Order-level memoization" DIMATIKAN** → ini perilaku lama (versi 1).
2. Sekali dengan checkbox itu **DINYALAKAN** (default).

Bandingkan **"Waktu TOTAL eksekusi"** dan angka **"dipanggil ... x"**. Yang **HARUS SAMA** di kedua
run: bentuk pohon (kecuali baris `[SUDAH ADA]` yang menggantikan sub-tree berulang) dan
**STATUS KESELURUHAN SO**. Kalau status keseluruhannya **berbeda**, berarti ada bug — laporkan,
jangan dipakai.

**Cara memakainya untuk keputusan desain BSP nanti:**

- Lihat **% terbesar** — itu bottleneck Anda. Di contoh di atas, **BOM explosion 73,9%** →
  di BSP nanti, bagian inilah yang harus di-cache atau di-batch, bukan yang lain.
- **Bandingkan 2 metode BOM.** Jalankan sekali dengan `BOM: pakai FM standar SAP`, catat angkanya.
  Jalankan lagi dengan `BOM: baca tabel langsung`, catat lagi. Biasanya baca tabel jauh lebih cepat,
  tapi kurang akurat (tidak handle validity date & pemilihan alternatif BOM otomatis). Anda perlu
  tahu trade-off ini **sebelum** menulis BSP.
- **Bandingkan cache ON vs OFF.** Uncheck `Aktifkan cache`, jalankan lagi. Selisih waktunya =
  keuntungan nyata dari caching → itu argumen kuat untuk menerapkan cache yang sama di BSP.
- **Jumlah "dipanggil N x"** menunjukkan berapa kali database dipukul. Angka ini yang meledak kalau
  BOM-nya lebar. Kalau `dipanggil` sudah ratusan kali untuk 1 SO saja, jangan pakai pola rekursif
  ini apa adanya di BSP — perlu diubah jadi pendekatan batch (ambil semua data sekaligus, olah di memory).

---

## BAGIAN 8 — DAFTAR ASUMSI YANG WAJIB ANDA VERIFIKASI

**Baca bagian ini sebelum percaya pada angka apapun yang keluar dari program.**

Saya tidak tahu konfigurasi sistem SAP Anda, jadi saya memakai tabel/field/FM yang **paling umum**
di SAP standar. Setiap asumsi sudah ditandai di kode dengan komentar `ASUMSI #n`. Berikut daftar
lengkapnya + cara mengeceknya.

### Cara cek sebuah TABEL (pakai SE11)

1. Tcode **SE11** → pilih radio **Database table** → ketik nama tabel → klik **Display**.
2. Cari field yang dimaksud di daftar. Kalau ada → asumsi benar.
3. Untuk lihat **isi datanya**: dari SE11 tekan **F8** (Display Data) → isi filter → **F8** lagi.
   Atau pakai tcode **SE16N** (lebih enak) → ketik nama tabel → isi filter → **F8**.

### Cara cek sebuah FUNCTION MODULE (pakai SE37)

1. Tcode **SE37** → ketik nama FM → **Display**.
2. Kalau muncul "does not exist" → FM-nya tidak ada di sistem Anda.
3. Untuk uji coba langsung: dari SE37 tekan **F8** (Test) → isi parameternya → **F8** lagi → lihat
   hasilnya di tabel output.

---

### ASUMSI #1 — Link SO → Production Order lewat tabel **AFPO**

| Field | Saya asumsikan | Cek di |
|---|---|---|
| `AFPO-KDAUF` | Sales Order number | SE11 → AFPO |
| `AFPO-KDPOS` | Sales Order item | SE11 → AFPO |
| `AFPO-PSMNG` | **Target Qty** (order item quantity) | SE11 → AFPO |
| `AFPO-WEMNG` | **Delivered Qty** (hasil GR) | SE11 → AFPO |
| `AFPO-DWERK` | Plant | SE11 → AFPO |

**Cara verifikasi paling meyakinkan:**
1. Buka **COOIS**, filter pakai Sales Order Anda, catat order-order yang muncul + qty-nya.
2. Buka **SE16N** → tabel `AFPO` → filter `KDAUF` = nomor SO Anda → **F8**.
3. **Order yang muncul harus sama persis** dengan hasil COOIS. Qty `PSMNG` harus sama dengan
   kolom "Order quantity" di COOIS, dan `WEMNG` sama dengan "Delivered quantity".

**Kalau tidak cocok:** kemungkinan besar SO Anda **bukan Make-To-Order**. Kalau link SO→order di
sistem Anda lewat jalur lain (misal WBS element / Project), field-nya beda dan bagian
`METHOD get_orders` harus disesuaikan.

> **Catatan penting soal "Delivered Qty":** spec Anda menyebut *"Delivered Qty / Confirmed Qty"*.
> Ini **dua hal berbeda** di SAP:
> - **Delivered** (`AFPO-WEMNG`) = sudah **Goods Receipt** → barangnya sudah nyata ada di gudang. ← **ini yang saya pakai**
> - **Confirmed** (`AFKO-IGMNG`) = sudah **dikonfirmasi selesai di mesin** (CO11N), tapi belum tentu sudah di-GR.
>
> Untuk pertanyaan *"barangnya sudah jadi belum?"*, **WEMNG lebih tepat**. Kalau Anda ternyata mau
> pakai Confirmed Qty, ganti `is_ord-wemng` di `METHOD process_order` dengan field `IGMNG` dari AFKO
> (dan tambahkan `k~igmng` di SELECT-nya). Putuskan ini bersama user Anda.

---

### ASUMSI #2 — **AFKO-DISPO** = MRP Controller, **AFKO-STLNR** = nomor BOM order

Cek di SE11 → `AFKO`. Cari field `DISPO`, `STLNR`, `STLAL`.

**Kalau `DISPO` tidak ada di AFKO** (syntax error saat activate): hapus `k~dispo` dari kedua SELECT
di `METHOD get_orders`, dan hapus juga field `dispo` dari `TYPES ty_ord`. Program sudah punya
fallback: kalau DISPO kosong, dia ambil dari `MARC-DISPO` (material master).

---

### ASUMSI #3 — **AUFK-LOEKZ = 'X'** artinya order sudah dihapus

Program **membuang** order yang di-flag hapus. Kalau Anda justru mau ikut menampilkannya, hapus baris
`AND u~loekz = space.` di `METHOD get_orders` (ada 2 tempat).

> **Pertimbangkan juga:** apakah order yang statusnya **TECO** atau **CLSD** masih mau ikut ditelusuri?
> Saat ini **ikut** semua. Kalau mau dibuang, tambahkan filter di JEST.

---

### ASUMSI #4 — Status order ada di **JEST** + teksnya di **TJ02T**

| Hal | Asumsi |
|---|---|
| `JEST-OBJNR` | kunci penghubung ke `AUFK-OBJNR` |
| `JEST-INACT = space` | status sedang **AKTIF** |
| `JEST-STAT` diawali `'I'` | **system status** (CRTD/REL/TECO/DLV). Diawali `'E'` = user status → **diabaikan** program ini |
| `TJ02T-TXT04` | teks pendek status |

**Verifikasi:** buka 1 production order di **CO03** → menu **Header → Status** → catat status yang
muncul. Bandingkan dengan kolom SYSTEM STATUS di output program. Harus sama.

**Kalau Anda juga butuh USER status:** ganti filter `ls_jest-stat(1) = 'I'` jadi `= 'E'`, dan baca
teksnya dari tabel `TJ30T` (bukan TJ02T).

---

### ASUMSI #5 — **MARC-DISPO** = MRP Controller di material master

Cek SE11 → `MARC`. Dipakai hanya sebagai cadangan kalau AFKO-DISPO kosong. Rendah risiko.

---

### ASUMSI #6 — FM **`CS_BOM_EXPL_MAT_V2`** untuk BOM explosion

Ini FM standar SAP yang paling umum untuk explode BOM material.

**Verifikasi:** SE37 → `CS_BOM_EXPL_MAT_V2` → **Display**. Kalau tidak ada, coba alternatifnya:
`CS_BOM_EXPLOSION` atau `CSAP_MAT_BOM_READ`. Kalau tetap tidak ada, **pakai saja radio button
"BOM: baca tabel langsung"** — itu tidak butuh FM sama sekali.

**Parameter yang paling mungkin salah di sistem Anda:**

| Param | Default saya | Artinya | Kalau salah, akibatnya |
|---|---|---|---|
| `CAPID` = `PP01` | BOM application untuk **produksi** | Hasil BOM kosong atau salah alternatif |
| `STLAN` = `1` | BOM usage **produksi** (`1`). Ada juga engineering (`2`), costing (`6`) | Hasil BOM kosong |
| `MEHRS` = `' '` | **single level** (sesuai spec Anda) | Jangan diubah jadi `'X'`, nanti jadi multi-level dan rekursi Anda dobel |

**Cara memastikan CAPID & STLAN yang benar:** tanya tim **PP** Anda, atau buka **CS03** untuk satu
material, lihat field **BOM Usage** yang muncul di layar. Angka itulah `STLAN` yang benar.

**Uji cepat FM ini tanpa program:** SE37 → `CS_BOM_EXPL_MAT_V2` → **F8 (Test)** → isi
`CAPID`=PP01, `MTNRV`=material Anda, `WERKS`=plant Anda, `DATUV`=tanggal hari ini, `EMENG`=1,
`MEHRS`= (kosong) → **F8**. Lihat tabel `STB` di hasil. Kalau ada isinya → parameter Anda benar.

---

### ASUMSI #7 — Rantai tabel BOM: **MAST → STKO → STAS → STPO**

Dipakai kalau Anda pilih radio "BOM: baca tabel langsung".

| Tabel | Perannya | Field kunci |
|---|---|---|
| `MAST` | material → nomor BOM | `MATNR` + `WERKS` + `STLAN` → `STLNR`, `STLAL` |
| `STKO` | header BOM | `BMENG` = **base quantity** (qty komponen berlaku untuk sekian unit produk jadi) |
| `STAS` | item mana yang ikut di alternatif ini | `LKENZ = 'X'` → item **dihapus** |
| `STPO` | detail item | `IDNRK` = komponen, `MENGE` = qty, `POSTP` = item category |

**`STLTY = 'M'`** artinya BOM material (bukan BOM equipment/dokumen).

**`POSTP = 'L'`** = **stock item** → hanya inilah yang program ambil. Item bertipe `N` (non-stock),
`T` (text), `R` (variable-size) **diabaikan**, karena tidak punya stok untuk dicek.

**Keterbatasan yang HARUS Anda sadari:** metode baca-tabel ini **tidak** menangani validity date BOM
dan **tidak** memilih alternatif BOM secara pintar (dia ambil alternatif pertama yang ketemu).
Untuk data produksi nyata, **FM lebih akurat**. Metode tabel ini disediakan untuk **pembanding
kecepatan** dan sebagai cadangan.

---

### ASUMSI #8 — Stok unrestricted = **MARD-LABST**  ← **PALING SERING JADI MASALAH**

| Field MARD | Artinya | Dipakai? |
|---|---|---|
| `LABST` | **Unrestricted use** | ✅ **YA** |
| `INSME` | Quality Inspection | ❌ tidak (sesuai spec Anda) |
| `SPEME` | Blocked | ❌ tidak (sesuai spec Anda) |

Program menjumlahkan `LABST` dari **semua storage location** dalam plant tersebut.

**Verifikasi:** buka **MB52** → isi material + plant yang sama → bandingkan kolom
**"Unrestricted"** dengan kolom **QTY ADA** di output program. **Harus sama.**

> ### ⚠️ KALAU STOK KELUAR 0 PADAHAL MB52 ADA ISINYA — BACA INI
>
> Penyebab nomor satu: bahan baku Anda disimpan sebagai **Sales Order Stock** (special stock `E`),
> yang lazim di skenario **Make-To-Order**. Stok jenis ini **tidak ada di MARD**, tapi di tabel
> **`MSKA`** (field `KALAB`).
>
> Cara mengeceknya: di **MB52**, lihat apakah ada kolom **"Special Stock"** yang berisi `E` dan ada
> nomor Sales Order-nya. Kalau ya → di file `.abap`, cari `METHOD get_stock`, lalu **buang tanda
> komentar** pada blok "OPSIONAL - Sales Order Stock" di dalamnya.
>
> Kemungkinan lain: stok ada di **subcontracting** (`MSLB`) atau **consignment vendor** (`MKOL`).
> Lihat kolom special stock di MB52 untuk memastikan.

---

### ASUMSI #9 — **RESB** = kebutuhan komponen order

| Field | Artinya |
|---|---|
| `RESB-AUFNR` | order yang membutuhkan |
| `RESB-MATNR` | material komponen |
| `RESB-BDMNG` | **requirement quantity** ← target qty bahan baku |
| `RESB-XLOEK = 'X'` | item reservation **dihapus** → tidak dihitung |

Program pakai RESB **duluan**. Kalau tidak ketemu reservation, baru fallback ke hasil BOM explosion
(BOM qty × order qty induk), dan barisnya diberi keterangan `Qty dari BOM (tidak ada reservation)`.

**Verifikasi:** buka production order di **CO03** → tab **Components** → bandingkan "Requirement
quantity" tiap komponen dengan kolom **TARGET QTY** di output program.

---

### ASUMSI #10 — **MAKT** = deskripsi material, difilter `SPRAS = sy-langu`

Kalau deskripsi keluar kosong, kemungkinan material Anda tidak punya deskripsi di bahasa login Anda.
Ganti `spras = sy-langu` jadi `spras = 'E'` di `METHOD get_maktx`.

---

## BAGIAN 9 — Troubleshooting

| Gejala | Kemungkinan penyebab | Solusi |
|---|---|---|
| **"TIDAK ADA PRODUCTION ORDER untuk SO ..."** | Nomor SO/item salah, atau SO bukan MTO | Cek dulu di **COOIS** pakai filter Sales Order yang sama. Kalau COOIS juga kosong → datanya memang tidak ada. Kalau COOIS ada isi tapi program kosong → **ASUMSI #1 salah** |
| **SO Item tidak cocok** | POSNR itu NUMC(6) | Ketik `10`, SAP otomatis jadi `000010`. Jangan ketik `000010` manual kalau ragu, ketik `10` saja |
| **Pohon cuma level 0, tidak ada anak sama sekali** | BOM explosion gagal / kosong | Coba ganti ke radio **"BOM: baca tabel langsung"**. Kalau itu jalan → berarti CAPID/STLAN Anda salah (**ASUMSI #6**). Uji FM-nya langsung lewat SE37 |
| **Semua bahan baku QTY ADA = 0** | Stok ada di special stock, bukan MARD | Lihat **ASUMSI #8**, aktifkan blok MSKA |
| **Banyak baris `[WARNING] CIRCULAR BOM`** | BOM Anda memang melingkar, ATAU material yang sama dipakai di 2 level berbeda secara sah | Cek manual di **CS03**. Kalau memang sah (bukan circular betulan), logika deteksi perlu diperlonggar — misalnya dibandingkan per `order`, bukan per `material` |
| **`[WARNING] MAX RECURSION DEPTH`** | Struktur produk lebih dalam dari batas | Naikkan `Max Recursion Depth` (misal 15). Kalau tetap muncul di depth 20+, curigai ada circular yang tidak terdeteksi |
| **Program lama sekali / TIME_OUT dump** | BOM lebar → jumlah query meledak | Turunkan depth. Pastikan cache ON. Lihat angka "dipanggil N x" di output — itu bukti bottleneck-nya |
| **Syntax error saat Activate** | Nama field beda di sistem Anda | Klik dua kali pesan error → lompat ke barisnya → cocokkan dengan **Bagian 8** |
| **Popup minta Access Key** | User belum terdaftar developer | Hubungi tim Basis (lihat Bagian 1.1) |

---

## BAGIAN 10 — Setelah berhasil jalan: apa selanjutnya?

Program ini sengaja dirancang supaya logikanya gampang dipindah ke BSP:

- **Semua logika ada di `LCL_TRACER`**, terpisah dari `METHOD display` (yang urusan cetak-mencetak).
  Untuk BSP nanti: pindahkan `LCL_TRACER` ke class global lewat **SE24** (misal `ZCL_SO_TRACER`),
  buang `METHOD display`, dan ganti dengan method yang mengembalikan `mt_node` sebagai tabel —
  biar BSP yang merender HTML-nya.
- **`mt_node` sudah punya field `parent`**, jadi struktur pohonnya bisa direkonstruksi di HTML
  (nested `<ul>`, atau tabel dengan indentasi) tanpa perlu mengulang rekursi.
- **Sebelum memindahkannya**, lihat dulu angka "dipanggil N x" di blok performa. Kalau untuk 1 SO
  saja sudah ratusan kali pukul database, **jangan langsung dipakai di BSP** — request web punya
  batas waktu, dan pola rekursif ini perlu diubah dulu jadi batch (ambil semua order + semua RESB +
  semua stok sekali jalan pakai `FOR ALL ENTRIES`, lalu susun pohonnya di memory). Justru **untuk
  menjawab pertanyaan itulah** program pengukuran ini dibuat.
