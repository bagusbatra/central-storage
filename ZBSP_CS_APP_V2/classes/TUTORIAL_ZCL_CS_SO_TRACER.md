# Tutorial: Membuat Global Class ZCL_CS_SO_TRACER via SE24

Tutorial ini mengasumsikan Anda **belum pernah membuat global class**. Ikuti berurutan.

File yang dibutuhkan (ada di repo ini):

| File | Isinya |
|---|---|
| `classes/ZCL_CS_SO_TRACER.abap` | Kode class-nya |
| `reports/ZTEST_CS_SO_TRACER_CLS.abap` | Program test untuk membuktikan class-nya benar |

---

## Kenapa dijadikan Global Class?

Report `ZTEST_SO_TRACE_RECURSIVE` punya logikanya **di dalam program itu sendiri** (local class
`LCL_TRACER`). Local class **tidak bisa dipakai program lain** — dia terkunci di dalam programnya.

Global class dibuat lewat **SE24** dan disimpan sebagai objek repository tersendiri, jadi bisa
dipanggil siapa saja: background job, BSP, report lain, function module.

Yang berubah dari versi report **hanya packaging-nya**. Logika bisnisnya dipindah apa adanya, dengan
tiga pengecualian yang sudah Anda setujui:

1. Metode BOM "baca tabel langsung" **dihapus** (terbukti salah hitung base quantity). Sekarang selalu
   pakai FM `CS_BOM_EXPL_MAT_V2`.
2. Method `DISPLAY` dan semua `WRITE`/`FORMAT COLOR` **dihapus**. Class ini murni logic — hasil pohon
   dikembalikan lewat `ET_NODE`, biar pemanggil yang urus tampilannya.
3. Parameter selection-screen (`P_VBELN` dkk) jadi **parameter method `TRACE`**.

---

## BAGIAN 1 — Buka SE24 dan buat class

### 1.1 Masuk SE24

Di command field SAP, ketik `/nSE24` → **Enter**. Muncul layar **Class Builder: Initial Screen**.

### 1.2 Ketik nama class

Di field **Object type**, ketik persis:

```
ZCL_CS_SO_TRACER
```

Klik **Create**.

> **Konvensi nama:** `Z` = objek customer (aman dari upgrade SAP). `CL` = class. Jadi `ZCL_` adalah
> awalan standar untuk global class buatan sendiri. Ini bukan aturan teknis yang dipaksa sistem,
> tapi konvensi yang dipakai semua orang — ikuti saja.

### 1.3 Popup "Create Class"

Muncul popup. Isi:

| Field | Isi |
|---|---|
| **Class** | `ZCL_CS_SO_TRACER` (sudah terisi) |
| **Description** | `Telusur rekursif Sales Order: Order + BOM + Stok` |
| **Instantiation** | **Public** |
| **Class Type** | **Usual ABAP Class** |
| **Final** | ✅ centang |

Klik **Save**.

### 1.4 Package

Sama seperti waktu membuat report:

- **Untuk sekarang (uji coba)** → klik tombol **Local Object** → package jadi `$TMP`, tidak butuh
  Transport Request.
- **Kalau nanti mau dipakai background job / BSP di Production** → class ini **harus** masuk package Z
  yang bisa di-transport (misal `ZPP` / `ZCS`), dan butuh TR.

> ⚠️ **Perhatian:** kalau class-nya `$TMP` tapi program BSP/background job Anda ada di package Z yang
> transportable, SAP akan **menolak transport**-nya (objek transportable tidak boleh bergantung pada
> objek lokal). Jadi: uji coba dulu di `$TMP`, dan **sebelum** dipakai produksi, pindahkan class ke
> package Z lewat menu **Goto → Object Directory Entry**.

---

## BAGIAN 2 — Cek: SE24 Anda punya "source code based editor" atau tidak?

Ini menentukan cara Anda mengisi kodenya. Ada dua kemungkinan.

### Cara mengeceknya

Setelah class dibuat, Anda ada di **Class Builder**. Lihat menu:

**Utilities → Settings → Class Builder** (tab)

Di situ ada checkbox / radio button dengan nama kira-kira:
- **"Source Code-Based"** atau
- **"Class Builder: source code based"** atau
- **"Editor Mode: Source Code-Based"**

Atau lebih cepat: di toolbar Class Builder, cari tombol bertuliskan **"Source Code-Based"** /
ikon yang mengubah tampilan jadi editor teks penuh. Di SAP versi lebih baru (7.0 EhP2 ke atas)
tombol ini hampir selalu ada.

---

### 🅐 KALAU ADA source-code editor → **JAUH LEBIH MUDAH**, pakai ini

1. Aktifkan mode source-code-based (centang setting di atas, atau klik tombolnya).
2. Layar berubah jadi satu editor teks besar, isinya kerangka:
   ```abap
   CLASS zcl_cs_so_tracer DEFINITION
     PUBLIC
     FINAL
     CREATE PUBLIC .
     PUBLIC SECTION.
     PROTECTED SECTION.
     PRIVATE SECTION.
   ENDCLASS.

   CLASS zcl_cs_so_tracer IMPLEMENTATION.
   ENDCLASS.
   ```
3. **Ctrl+A** → **Delete** (hapus semua).
4. Buka file `classes/ZCL_CS_SO_TRACER.abap`, **Ctrl+A** → **Ctrl+C**.
5. Paste ke editor SAP (**Ctrl+V**).
6. **Save** (Ctrl+S) → **Activate** (Ctrl+F3).

Selesai. Lompat ke **Bagian 4**.

> File `.abap` yang saya buat memang ditulis dalam format ini (`CLASS ... DEFINITION PUBLIC FINAL
> CREATE PUBLIC.` ... `ENDCLASS.` diikuti `CLASS ... IMPLEMENTATION.` ... `ENDCLASS.`), jadi bisa
> di-paste utuh tanpa diedit.

---

### 🅑 KALAU TIDAK ADA (SE24 form-based saja) → input manual, ikuti urutan di Bagian 3

Ini lebih lama (mungkin 30–45 menit) tapi tidak sulit. Kuncinya: **kerjakan berurutan**, jangan
loncat-loncat, karena SAP akan mengeluh kalau Anda mengisi source code method yang tipenya
belum dideklarasikan.

---

## BAGIAN 3 — Input manual per-method (kalau SE24 Anda form-based)

**Urutan yang efisien — kerjakan persis seperti ini:**

```
1. Tab "Types"       -> semua TYPES dulu  (public dulu, lalu private)
2. Tab "Attributes"  -> semua DATA
3. Tab "Methods"     -> semua NAMA method + visibility (belum isi kodenya)
4. Tab "Methods"     -> klik "Parameters" tiap method, isi signature-nya
5. Tab "Methods"     -> double-click tiap method, paste source code-nya
6. Activate
```

Kenapa urutan ini? Karena **method signature butuh TYPES**, dan **source code butuh signature +
attributes**. Kalau dibalik, SAP akan error terus dan Anda akan bingung sendiri.

### 3.1 Tab **Types**

Buka file `ZCL_CS_SO_TRACER.abap`, salin blok `TYPES:` satu per satu.

**Public** (Visibility = Public):

| Type | Isi |
|---|---|
| `TY_NODE` | struktur node — salin blok `TYPES: BEGIN OF ty_node ... END OF ty_node.` |
| `TT_NODE` | `TYPE STANDARD TABLE OF ty_node WITH DEFAULT KEY` |

**Private** (Visibility = Private):

`TY_ORD`, `TT_ORD`, `TT_ORD_SORTED`, `TY_COMP`, `TT_COMP`, `TT_PATH`, `TY_MEMO`, `TY_CACHE_BOM`,
`TY_CACHE_STOCK`, `TY_CACHE_MAKT` — semuanya ada di bagian `PRIVATE SECTION` file `.abap`.

> **Tips:** di tab Types, klik tombol **"Direct Type Entry"** (ikon pensil/kertas). Itu akan membuka
> editor teks kecil tempat Anda bisa **paste** definisi `TYPES` lengkap, jauh lebih cepat daripada
> mengetik field satu per satu di grid.

### 3.2 Tab **Attributes**

Semua **Private**, Level = **Instance Attribute**.

Parameter run (diisi dari method TRACE):

| Attribute | Type |
|---|---|
| `MV_VBELN` | `VBELN_VA` |
| `MV_POSNR` | `POSNR_VA` |
| `MV_DEPTH` | `I` |
| `MV_CAPID` | `CAPID` |
| `MV_STLAN` | `STLAN` |
| `MV_OMEMO` | `ABAP_BOOL` |
| `MV_BOMC` | `ABAP_BOOL` |
| `MV_CACHE` | `ABAP_BOOL` |

State hasil telusur:

| Attribute | Type |
|---|---|
| `MT_NODE` | `TT_NODE` |
| `MV_IDX` | `I` |
| `MT_ALL_ORD` | `TT_ORD_SORTED` |
| `MT_C_STOCK` | `SORTED TABLE OF ty_cache_stock WITH UNIQUE KEY matnr werks` |
| `MT_C_MAKT` | `SORTED TABLE OF ty_cache_makt WITH UNIQUE KEY matnr` |
| `MT_C_ORDER` | `SORTED TABLE OF ty_memo WITH UNIQUE KEY aufnr` |
| `MT_C_BOM` | `SORTED TABLE OF ty_cache_bom WITH UNIQUE KEY matnr werks capid stlan qty` |

Counter performa (semua `TYPE I`):
`MV_US_TOTAL`, `MV_US_PRE`, `MV_US_ORD`, `MV_US_BOM`, `MV_US_STK`, `MV_US_RESB`,
`MV_N_PRE`, `MV_N_ORD`, `MV_N_BOM`, `MV_N_STK`, `MV_N_RESB`,
`MV_H_STK`, `MV_H_MAKT`, `MV_H_OMEMO`, `MV_H_BOMC`.

> Empat attribute `MT_C_*` bertipe **sorted table dengan key**, yang **tidak bisa diketik di kolom
> "Associated Type"** di grid biasa. Gunakan tombol **"Direct Type Entry"** untuk itu, lalu ketik
> definisi lengkapnya. Kalau SE24 Anda tetap menolak, buat dulu `TYPES` untuk masing-masing tabel
> itu di tab **Types** (misal `TT_C_STOCK TYPE SORTED TABLE OF ty_cache_stock WITH UNIQUE KEY matnr
> werks`), lalu attribute-nya tinggal bertipe `TT_C_STOCK`.

### 3.3 Tab **Methods** — nama + visibility

Buat semua method ini dulu (kolom **Level** = *Instance Method* untuk semuanya):

| Method | Visibility |
|---|---|
| `TRACE` | **Public** |
| `NODE_TO_STRING` | **Public** |
| `RESET_STATE` | Private |
| `PRELOAD_ALL_ORDERS` | Private |
| `GET_ORDERS` | Private |
| `PROCESS_ORDER` | Private |
| `EXPLODE_BOM` | Private |
| `EXPLODE_BOM_FM` | Private |
| `GET_STOCK` | Private |
| `GET_RESB_QTY` | Private |
| `GET_MAKTX` | Private |
| `ADD_NODE` | Private |

### 3.4 Tab **Methods** — isi Parameters tiap method

Taruh kursor di baris method → klik tombol **Parameters**. Isi sesuai file `.abap`.

Contoh untuk `TRACE`:

| Parameter | Type | Pass by | Typing | Associated Type | Default |
|---|---|---|---|---|---|
| `IV_VBELN` | Importing | Value | Type | `VBELN_VA` | |
| `IV_POSNR` | Importing | Value | Type | `POSNR_VA` | |
| `IV_MAX_DEPTH` | Importing | Value | Type | `I` | `10` |
| `IV_CAPID` | Importing | Value | Type | `CAPID` | `'PP01'` |
| `IV_STLAN` | Importing | Value | Type | `STLAN` | `'1'` |
| `IV_USE_OMEMO` | Importing | Value | Type | `ABAP_BOOL` | `ABAP_TRUE` |
| `IV_USE_BOMC` | Importing | Value | Type | `ABAP_BOOL` | `ABAP_TRUE` |
| `IV_USE_CACHE` | Importing | Value | Type | `ABAP_BOOL` | `ABAP_TRUE` |
| `ET_NODE` | Exporting | | Type | `TT_NODE` | |
| `EV_STATUS` | Exporting | | Type | `CHAR14` | |
| `EV_TOTAL_NODE` | Exporting | | Type | `I` | |
| `EV_NODE_BELUM` | Exporting | | Type | `I` | |
| `EV_DURATION_US` | Exporting | | Type | `I` | |

Untuk `PROCESS_ORDER`, jangan lupa parameter **Returning**-nya: `RV_OK`, type `ABAP_BOOL`.
(Parameter Returning **wajib** Pass by **Value** — SE24 akan memaksa ini otomatis.)

> **Kalau `CHAR14` tidak ada** di sistem Anda (error "type CHAR14 unknown"): buat TYPES publik
> `TY_STATUS(14) TYPE C` di tab Types, lalu pakai `TY_STATUS` untuk `EV_STATUS`. Jangan lupa
> menyesuaikan program test-nya juga.

### 3.5 Tab **Methods** — paste source code

**Double-click** nama method → editor kodenya terbuka → paste isi method dari file `.abap`
(**hanya yang di antara `METHOD xxx.` dan `ENDMETHOD.`**, tanpa baris `METHOD`/`ENDMETHOD`-nya
sendiri, karena SAP sudah menyediakan itu).

Ulangi untuk 12 method. **Save** tiap selesai satu.

---

## BAGIAN 4 — Activate

Tekan **Ctrl+F3** (Activate). Centang semua objek kalau muncul popup.

**Error yang paling mungkin muncul**, semua sudah pernah kita bahas:

| Error | Artinya | Solusi |
|---|---|---|
| `Field "AFKO~DISPO" is unknown` | field beda di sistem Anda | lihat ASUMSI #2 di `TUTORIAL_ZTEST_SO_TRACE.md` |
| `Type "CHAR14" is unknown` | data element itu tidak ada | pakai `TY_STATUS(14) TYPE C` buatan sendiri |
| `Type "ABAP_BOOL" is unknown` | sistem terlalu lama | tambahkan `TYPE-POOLS abap.` — tapi kalau report lama Anda sudah jalan pakai `abap_bool`, ini tidak akan terjadi |
| `RETURNING parameter must be fully typed` | ada RETURNING bertipe generic (`TYPE c` polos) | pastikan `RV_OK` bertipe `ABAP_BOOL`, bukan `C` |

---

## BAGIAN 5 — Test langsung dari SE24 (tanpa program apapun)

Class Builder punya fitur test bawaan. Ini cara tercepat mengecek class-nya hidup.

1. Masih di SE24 dengan class Anda terbuka dan **sudah aktif**.
2. Tekan **F8** (atau klik ikon **Test** / menu **Class → Test**).
3. Muncul layar **Test Class ZCL_CS_SO_TRACER** berisi daftar method.
4. Klik tombol di sebelah method **TRACE**.
5. Muncul layar input parameter. Isi:

   | Parameter | Nilai |
   |---|---|
   | `IV_VBELN` | `10478` (SAP akan melengkapi jadi `0000010478`) |
   | `IV_POSNR` | `10` (jadi `000010`) |
   | `IV_MAX_DEPTH` | `10` |
   | `IV_CAPID` | `PP01` |
   | `IV_STLAN` | `1` |
   | `IV_USE_OMEMO` | `X` |
   | `IV_USE_BOMC` | `X` |
   | `IV_USE_CACHE` | `X` |

6. Tekan **F8** (Execute).
7. **Tunggu ~6-7 detik.** (Jangan panik kalau layar diam — memang selama itu.)
8. Hasilnya muncul di bagian bawah layar, di area **Exporting**:
   - `EV_STATUS` → harusnya `BELUM SELESAI`
   - `EV_TOTAL_NODE` → harusnya `41`
   - `EV_NODE_BELUM` → jumlah node yang belum selesai
   - `EV_DURATION_US` → sekitar `6000000`–`7000000` (mikrodetik = 6–7 detik)
   - `ET_NODE` → **double-click** untuk membuka isi tabelnya dan melihat pohonnya

> **Kenapa SE24 Test berguna:** Anda bisa memastikan class-nya benar **sebelum** menulis program
> pemanggil apapun. Kalau di sini sudah salah, jangan buang waktu bikin program test.

---

## BAGIAN 6 — Program test terpisah (ZTEST_CS_SO_TRACER_CLS)

SE24 Test bagus untuk cek cepat, tapi susah untuk membandingkan **isi pohonnya baris per baris**
dengan report lama. Untuk itu ada program test kecil.

1. **SE38** → nama program: `ZTEST_CS_SO_TRACER_CLS` → **Create**
2. Type: **Executable Program**, Title: `Test class ZCL_CS_SO_TRACER`
3. Package: **Local Object** (`$TMP`) — ini cuma program test, tidak perlu di-transport
4. Paste isi file `reports/ZTEST_CS_SO_TRACER_CLS.abap`
5. **Save** → **Activate** (Ctrl+F3)
6. **F8** → isi SO `10478`, item `10` → **F8**

Program ini akan mencetak setiap node sebagai 1 baris teks (lewat `NODE_TO_STRING`), lalu di bagian
bawah menampilkan angka pembandingnya:

```
=== HASIL (bandingkan dengan report lama ZTEST_SO_TRACE_RECURSIVE) ===

Total node (ORDER + BAHAN BAKU) : 41       <- harus 41
Node REF                        : 27       <- harus 27
Node WARNING                    : 0
Node belum selesai (incl. REF)  : ...
STATUS KESELURUHAN SO           : BELUM SELESAI   <- harus BELUM SELESAI
Durasi                          : 6.610,000 ms    <- harus sekitar 6000-7000 ms

COCOK: class menghasilkan hasil yang sama dengan report lama.
```

### Kalau TIDAK COCOK

Program akan bilang begitu. Sebelum menyalahkan class-nya, cek dulu:

1. **Apakah Anda memakai SO yang sama?** Angka 41/27 itu spesifik untuk SO 10478 item 10.
2. **Apakah datanya sudah berubah?** Kalau sejak pengukuran dulu ada GR baru, order baru, atau stok
   berubah, angkanya **memang akan beda** — dan itu **benar**, bukan bug.
3. **Cara membandingkan yang adil:** jalankan `ZTEST_SO_TRACE_RECURSIVE` dan `ZTEST_CS_SO_TRACER_CLS`
   **berurutan hari itu juga** pada SO yang sama. Kalau keduanya beda, **baru** itu bug refactor.

---

## BAGIAN 7 — Setelah class terbukti benar: dipakai apa?

Class ini dirancang untuk dua konsumen. Pola pemakaiannya:

### Background job (banyak SO)

```abap
DATA: lo_tracer TYPE REF TO zcl_cs_so_tracer,
      lt_node   TYPE zcl_cs_so_tracer=>tt_node,
      lv_status TYPE char14,
      lv_total  TYPE i,
      lv_belum  TYPE i,
      lv_us     TYPE i.

CREATE OBJECT lo_tracer.          " CUKUP SEKALI, di luar loop

LOOP AT lt_so INTO ls_so.
  lo_tracer->trace(
    EXPORTING iv_vbeln = ls_so-vbeln
              iv_posnr = ls_so-posnr
    IMPORTING et_node       = lt_node
              ev_status     = lv_status
              ev_total_node = lv_total
              ev_node_belum = lv_belum
              ev_duration_us = lv_us ).

  " ... simpan lt_node / lv_status ke Z-table Anda di sini ...
ENDLOOP.
```

**Object-nya boleh dipakai ulang di dalam loop.** Method `TRACE` memanggil `RESET_STATE` di baris
pertama, jadi semua cache & node dari SO sebelumnya dibersihkan. Tidak akan ada data nyasar.

> ⚠️ **Tapi perhatikan konsekuensi performanya:** karena cache di-reset tiap SO, **tidak ada
> penghematan lintas-SO**. Kalau 100 SO memakai sub-assembly yang sama, BOM-nya tetap di-explode
> ulang di tiap SO. Untuk 1 SO = ~6,6 detik, maka 100 SO ≈ **11 menit**. Itu wajar untuk background
> job (jalan malam hari), tapi **hitung dulu** berapa SO yang mau diproses sebelum menjadwalkannya.

### BSP drill-down (1 SO)

Sama persis, tapi tanpa loop. Panggil `TRACE`, lalu render `ET_NODE` jadi HTML.

> ⚠️ **Peringatan penting untuk BSP:** 6,6 detik itu **terlalu lama untuk request web**. User akan
> mengira halamannya hang, dan beberapa konfigurasi web dispatcher akan timeout duluan. Sebelum
> memakai class ini langsung di BSP, pertimbangkan: jalankan background job-nya duluan, simpan
> hasilnya ke Z-table, lalu BSP tinggal **membaca Z-table** (instan). Class yang sama dipakai
> dua-duanya — bedanya BSP membaca hasil yang sudah jadi, bukan menghitung saat itu juga.
>
> Field `PARENT` di `TY_NODE` sengaja ada untuk ini: dari situ Anda bisa merekonstruksi struktur
> pohonnya (nested `<ul>` atau tabel ber-indent) tanpa perlu mengulang rekursinya.

---

## Lampiran — Ringkasan ASUMSI yang tetap berlaku

Semua komentar `ASUMSI #1`–`#10` dari report lama **dipertahankan persis** di class ini, di method
yang sesuai:

| ASUMSI | Isinya | Ada di method |
|---|---|---|
| #1 | `AFPO-KDAUF/KDPOS/PSMNG/WEMNG` = link SO → order + qty | `PRELOAD_ALL_ORDERS` |
| #2 | `AFKO-DISPO` = MRP Controller, `AFKO-STLNR` = nomor BOM | `PRELOAD_ALL_ORDERS` |
| #3 | `AUFK-LOEKZ = 'X'` = order dihapus | `PRELOAD_ALL_ORDERS` |
| #4 | Status order di `JEST` + teks di `TJ02T` | `PRELOAD_ALL_ORDERS` |
| #5 | `MARC-DISPO` = MRP Controller material master (fallback) | `PRELOAD_ALL_ORDERS` |
| #6 | FM `CS_BOM_EXPL_MAT_V2`, CAPID `PP01`, STLAN `1`, `MEHRS = ' '` | `EXPLODE_BOM_FM` |
| #7 | ~~Rantai tabel MAST/STKO/STAS/STPO~~ | **DIHAPUS** (metode baca-tabel dibuang) |
| #8 | `MARD-LABST` = stok unrestricted (bukan QI/Blocked) | `GET_STOCK` |
| #9 | `RESB-BDMNG` = requirement qty, `XLOEK` = dihapus | `GET_RESB_QTY` |
| #10 | `MAKT` = deskripsi material per bahasa | `GET_MAKTX` |

**ASUMSI #8 tetap yang paling rawan**: kalau stok bahan baku keluar `0` padahal MB52 ada isinya,
kemungkinan besar stoknya adalah *sales order stock* (special stock `E`) yang tersimpan di `MSKA-KALAB`,
bukan `MARD`. Blok kodenya sudah disiapkan sebagai komentar di dalam `GET_STOCK`, tinggal dibuka.
