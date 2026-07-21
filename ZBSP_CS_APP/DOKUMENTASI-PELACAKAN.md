# Dokumentasi Halaman Pelacakan Material per SO+Item

Halaman BSP untuk **melacak satu pasang Sales Order + Item** dari sisi order produksi, pergerakan barang, dan posisi stok — plus form **Transfer Posting (MvT 311)** multi-material.

> **Lokasi (D44):** halaman ini sekarang adalah **`index.htm`** — entry point aplikasi.
> `pelacakan.htm` masih ada sebagai **duplikat identik** (keputusan user). Lihat §11.
> Dokumen pendamping: [`DOKUMENTASI-SUMBER-DATA.md`](DOKUMENTASI-SUMBER-DATA.md) (sumber data seluruh app), [`DOKUMENTASI-FITUR-ELEMEN.md`](DOKUMENTASI-FITUR-ELEMEN.md) (elemen UI bersama)

---

## 1. Ringkasan

| Aspek | Keterangan |
|---|---|
| **Tujuan** | Jawab pertanyaan "material untuk SO+Item ini sekarang ada di mana, sudah bergerak ke mana, dan berapa sisanya" |
| **Input** | `so_num` + `item_num` (GET, dua-duanya wajib) |
| **Output** | 5 tab data + form Transfer Posting di kolom kanan |
| **Sifat** | **Data mentah langsung** — sengaja TIDAK memakai mesin tahap 4-tingkat / checkpoint yang dipakai `index`/`monitoring`/`riwayat` |
| **Rendering** | Penuh server-side, satu request. Tidak ada AJAX/lazy-load |
| **Navigasi** | Entry point aplikasi. Navbar-nya **hanya berisi satu entri** (`Pelacakan`, aktif) — lihat §10 |

### Kenapa "data mentah"?

Halaman ini lahir sebagai pembanding COOIS. Nilai yang tampil di tab Pembahanan/Produksi adalah field order itu sendiri (`AFPO-PSMNG` / `AFPO-WEMNG` / `AFPO-LGORT`), **satu baris = satu order produksi**, tanpa agregasi lintas order dan tanpa interpretasi tahap. Yang dipinjam dari `ZCL_CS_UTIL` hanya utilitas pemetaan persen→CSS (`prog_bar_class`, `prog_txt_class`, `css_pct`) dan `fmt_date` — murni presentasi, bukan logika bisnis.

---

## 2. Scope Lokasi (kunci seluruh halaman)

Seluruh query data dibatasi ke **7 kombinasi plant+storage location** yang sama:

| Tahap | Plant | Storage Location |
|---|---|---|
| Pembahanan | `1000` | `1D00` |
| Produksi | `2000` | `2KCS`, `2261`, `2262`, `22E2`, `22E3`, `229K` |

Filter ini muncul **empat kali** dan harus selalu diubah bersamaan:

| Baris | Query |
|---|---|
| `~266` | `AFPO ⨝ AFKO` (tab Pembahanan & Produksi) |
| `~370` | `MSEG` (tab Riwayat Pergerakan) |
| `~525` | `MSKA` (tab Stok Saat Ini) |

Konstanta yang dideklarasikan (`~31`):

```abap
CONSTANTS: lc_werks_1000 TYPE afpo-pwerk VALUE '1000',
           lc_werks_2000 TYPE afpo-pwerk VALUE '2000',
           lc_lgort_1d00 TYPE afpo-lgort VALUE '1D00'.
```

> ⚠️ **Belum konsisten.** Hanya plant 1000/2000 dan SLoc 1D00 yang jadi konstanta; enam SLoc plant 2000 masih literal yang diulang di tiga query. Query `MSEG` dan `MSKA` bahkan pakai literal `'1000'`/`'2000'`, bukan konstantanya.
>
> ⚠️ Kode SLoc **`22E3` tidak ada di daftar konstanta `ZCL_CS_UTIL` manapun** — diketik apa adanya sesuai instruksi user, belum pernah dikonfirmasi ulang.

---

## 3. Alur Eksekusi

```
request masuk
 │
 ├─ so_num & item_num kosong ──────────────► empty-state "Mulai Pelacakan"
 │
 ├─ CONVERSION_EXIT_ALPHA_INPUT(so_num)
 ├─ item_num numerik? ──► zero-pad ke NUMC(6)
 │
 ├─ SELECT SINGLE VBAP (validasi SO+Item ada)
 │   └─ tidak ketemu ────────────────────► empty-state "SO / Item Tidak Ditemukan"
 │
 ├─ lv_so_found = true
 │   ├─ VBAK + KNA1 + VBUK + VBUP   ──► tab Info Order
 │   ├─ AFPO ⨝ AFKO + MAKT          ──► tab Pembahanan & Produksi
 │   ├─ STPO (per AFKO-STLNR)       ──► expand komponen BOM
 │   ├─ MSEG + MKPF + MAKT          ──► tab Riwayat Pergerakan
 │   └─ MSKA + MARA + MAKT          ──► tab Stok Saat Ini
 │
 └─ blok Transfer Posting (independen dari SO+Item di atas)
     ├─ trs_step = 'preview' ──► parse textarea + query MSKA per baris
     └─ trs_step = 'submit'  ──► BAPI_GOODSMVT_CREATE
```

Validasi SO+Item adalah **gerbang**: semua query berat hanya jalan setelah `lv_so_found = abap_true`. Blok Transfer Posting di luar gerbang itu — form kanan tetap bisa dipakai walau belum cari SO.

---

## 4. Sumber Data per Tab

### 4.1 Tab Pembahanan & Produksi

Keduanya membaca **satu tabel internal yang sama** (`lt_ord`), dibedakan hanya saat render (`LOOP AT lt_ord WHERE pwerk = ...`).

```abap
SELECT a~kdauf a~kdpos a~aufnr a~matnr a~psmng a~wemng a~meins a~pwerk
       a~lgort k~stlnr
  FROM afpo AS a INNER JOIN afko AS k ON a~aufnr = k~aufnr
  WHERE a~kdauf = lv_so AND a~kdpos = lv_item
    AND ( <7 lokasi> ).
```

| Kolom UI | Sumber | Catatan |
|---|---|---|
| Material | `AFPO-MATNR` | |
| No Material | `MAKT-MAKTX` | batched `FOR ALL ENTRIES`, `BINARY SEARCH` |
| Target QTY | `AFPO-PSMNG` | qty order, tidak diagregasi |
| Del QTY | `AFPO-WEMNG` | qty sudah di-GR |
| Progres | `WEMNG / PSMNG × 100` | di-clamp ke maks 100 |
| Sloc | `AFPO-LGORT` | |
| (expand) BOM | `AFKO-STLNR` → `STPO` | |

**JOIN ke AFKO ada untuk satu alasan saja: `STLNR`.** Semua field lain dari AFPO.

### 4.2 Komponen BOM (expand baris)

Kolom "BOM numb." di COOIS adalah **`STLNR` yang sudah melekat di order**, bukan hasil lookup ulang ke Material Master. `STPO` dicari persis berdasarkan `STLNR` itu — tidak ada query `MAST`, tidak ada deteksi Plant/Alternative.

Order dengan `STLNR` kosong (item dagang/pembelian) menampilkan pesan jelas, bukan error.

### 4.3 Tab Riwayat Pergerakan

```abap
SELECT ... FROM mseg
  WHERE kdauf = lv_so AND kdpos = lv_item AND ( <7 lokasi> ).
" lalu MKPF FOR ALL ENTRIES utk budat/cpudt/cputm/usnam
```

**Penggabungan pasangan OUT+IN.** Satu material document transfer biasanya punya 2 baris MSEG: `SHKZG='H'` (kredit/keluar) dan `SHKZG='S'` (debit/masuk). Keduanya digabung jadi satu baris `ty_hist_pair` bertipe "Dari → Ke".

Mekanismenya: sort `BY mblnr mjahr matnr charg shkzg` (dengan urutan itu `H` pasti tepat sebelum `S`), lalu `WHILE` dengan look-ahead satu baris — kalau key baris berikutnya sama, itu pasangannya dan indeks di-skip. Baris tanpa pasangan (GR/GI biasa) tetap tampil dengan `is_paired = abap_false` supaya tidak ada data hilang.

**Pemetaan movement type → badge** (`~468`):

| BwArt | Label | Kelas |
|---|---|---|
| `301` / `302` | Cross Plant / Cross Plant Rev | `mv-blue` |
| `311` / `312` | In Plant / In Plant Rev | `mv-yellow` |
| `321` / `322` | Release QI / QI Reverse | `mv-purple` |
| `411` / `412` | To Free Stock / Free Rev | `mv-green` |
| `413` / `414` | To SO Stock / SO Stock Rev | `mv-green` |
| `101` | Goods Receipt | `mv-green` |
| `261` | GI to Order | `mv-red` |
| `601` | Delivery | `mv-red` |
| lainnya | kode mentah | `mv-gray` |

Urutan akhir: `cpudt DESC, cputm DESC, mblnr DESC` (terbaru dulu).

### 4.4 Tab Stok Saat Ini

```abap
SELECT matnr werks lgort charg kalab kains kaspe FROM mska
  WHERE vbeln = lv_so AND posnr = lv_item AND sobkz = 'E'
    AND ( <7 lokasi> ).
```

| Kolom UI | Sumber MSKA |
|---|---|
| Unrestr. | `KALAB` |
| Qual.Insp | `KAINS` |
| Blocked | `KASPE` |

Baris dengan **ketiga kolom = 0 dibuang** (`CONTINUE`). UoM diambil dari `MARA-MEINS`, nama dari `MAKT`.

> **Catatan:** tipe `ty_stok` punya field `umlme` (in-transit) dan `source` (`'MSKA'`/`'MARD'`), tapi **MARD tidak pernah di-query** — komentar di `~514` menyebut rencana menampilkan free stock, implementasinya belum ada. `source` selalu `'MSKA'`, `umlme` selalu 0.

### 4.5 Tab Info Order

Empat `SELECT SINGLE` ringan, hanya jalan setelah SO+Item terkonfirmasi:

| Tabel | Field | Dipakai untuk |
|---|---|---|
| `VBAK` | `erdat auart kunnr netwr waerk bstnk` | header SO |
| `KNA1` | `name1 ort01 land1` | data customer |
| `VBUK` | `gbstk` | Status SO |
| `VBUP` | `gbsta` | Status Item |

Pemetaan domain `STATV`: `A` = Belum Diproses, `B` = Sebagian Diproses, `C` = Selesai Diproses, lainnya = Tidak Diketahui.

> ⚠️ **`VBUK`/`VBUP` sekarang dead code.** Commit `b2a039f` ("Remove status fields from Sales Order and Item sections") menghapus **tampilan** Status SO & Status Item dari tab Info Order, tapi meninggalkan dua `SELECT SINGLE` + dua blok `CASE` di ABAP. Keduanya tetap dieksekusi tiap load dan hasilnya (`lv_hdr_stat_lbl`, `lv_itm_stat_lbl`) **tidak pernah dipakai**. Aman secara fungsional, tapi dua query sia-sia per request — hapus atau kembalikan tampilannya.
>
> ⚠️ Kalau tampilannya dikembalikan: pemetaan ini **langsung** dari `GBSTK`/`GBSTA`. Kalau "Overall Status" di VA03 ternyata berasal dari kombinasi status lain, label di sini bisa berbeda dari yang dilihat user di SAP GUI. Belum dikonfirmasi.

---

## 5. Form Transfer Posting (kolom kanan)

Mode tetap: **TP In Plant, movement type 311**. Radio "Cross Plant", checkbox "Free Stock" dan "To SO" ada di UI tapi `disabled` — penanda rencana, bukan fitur aktif.

### 5.1 Field kepala (berlaku untuk semua baris)

| Field | Nama form | Wajib | Dipakai di BAPI |
|---|---|---|---|
| From Plant | `trs_werks_f` | ✅ | `plant` + `move_plant` |
| From SLoc | `trs_lgort_f` | ✅ | `stge_loc` |
| To SLoc | `trs_lgort_t` | ✅ | `move_stloc` |
| Referal MatDoc | `trs_referal` | — | `header_txt` |
| NIK | `trs_pernr` | — | ❌ **tidak dipakai** |
| Good Recipient | `trs_kpd` | — | ❌ **tidak dipakai** |

Tiga field pertama di-`TRANSLATE ... TO UPPER CASE`.

### 5.2 Step 1 — Preview (`trs_step = 'preview'`)

Textarea `trs_matlist` diparse baris demi baris:
- pemisah **TAB** (paste dari Excel) atau **spasi** (fallback ketik manual)
- format `Material<TAB>Batch`, batch opsional
- baris kosong di-skip, `CONDENSE` di setiap potongan

Tiap baris divalidasi ke MSKA:

```abap
SELECT SINGLE ... FROM mska
  WHERE matnr = <r>-matnr AND werks = lv_trs_werks_f AND lgort = lv_trs_lgort_f
    AND [ charg = <r>-batch ]  AND sobkz = 'E' AND kalab > 0.
```

Batch kosong → ambil batch pertama yang ketemu. Ketemu → `is_valid = true`, `qty_tp` default = seluruh stok. Tidak ketemu → baris merah + `err_msg`, tidak bisa dicentang.

### 5.3 Step 2 — Posting (`trs_step = 'submit'`)

Form preview mengirim field **per baris** (`trs_sel_N`, `trs_matnr_N`, `trs_batch_N`, `trs_so_N`, `trs_item_N`, `trs_uom_N`, `trs_qty_N`), bukan tabel internal. Server merekonstruksinya dengan `DO 500 TIMES` + `CONCATENATE` nama field dinamis.

Struktur BAPI:

```abap
ls_gm_head-pstng_date = sy-datum.
ls_gm_head-doc_date   = sy-datum.
ls_gm_head-header_txt = lv_trs_referal.
ls_gm_head-pr_uname   = sy-uname.
ls_gm_code-gm_code    = '04'.

ls_gm_item-material_long = <matnr>.   " MATERIAL & MOVE_MAT sengaja kosong
ls_gm_item-move_type     = '311'.
ls_gm_item-plant / move_plant = <from plant>   " sama, In Plant
ls_gm_item-stge_loc      = <from sloc>.
ls_gm_item-move_stloc    = <to sloc>.
ls_gm_item-batch / move_batch = <batch>.
ls_gm_item-entry_qnt     = <qty>.
ls_gm_item-entry_uom     = CONVERSION_EXIT_CUNIT_INPUT( <uom> ).

" Stok SO:
ls_gm_item-spec_stock     = 'E'.
ls_gm_item-val_sales_ord  = <so>.      " BUKAN sales_ord
ls_gm_item-val_s_ord_item = <item>.    " BUKAN s_ord_item
```

Lalu `BAPI_GOODSMVT_CREATE` → cek `return` type `'E'` → kalau bersih, `BAPI_TRANSACTION_COMMIT WAIT='X'` → cek error lagi.

### 5.4 Warisan dari `YPPI013`

Blok posting Fase 4 **bukan tulisan dari nol** — ia meniru routine `SAVE3` (mode `r311`) di program `YPPI013`, transaksi transfer posting yang sudah dipakai sebelumnya.

> ⚠️ **`YPPI013` tidak ada di repository ini.** Satu-satunya jejaknya adalah komentar di `pelacakan.htm` itu sendiri. Semua yang ada di bagian ini adalah **klaim dari komentar kode**, bukan hasil diff terhadap sumber aslinya. Kalau perilaku posting ternyata berbeda dari YPPI013, mulailah menyelidik dari sini.
>
> Komentar aslinya pun berhati-hati: *"sebatas yang bisa diverifikasi dari kode"* — porting dilakukan dengan membaca kode YPPI013, bukan dokumentasi atau observasi runtime-nya. Celah masih mungkin ada.

#### Yang ditiru

| # | Pola | Kenapa penting |
|---|---|---|
| 1 | **`MATERIAL_LONG` diisi, `MATERIAL` (short) & `MOVE_MAT` dibiarkan kosong** | Kalau ikut mengisi `MATERIAL` yang 18-char, BAPI bisa menolak atau bentrok pada material bernomor panjang. Pola asli YPPI013 hanya mengisi versi `_LONG` |
| 2 | **`VAL_SALES_ORD` / `VAL_S_ORD_ITEM`, bukan `SALES_ORD` / `S_ORD_ITEM`** | Disebut komentar sebagai *"temuan eksplisit dari SAVE3"*. Nama field yang mirip ini gampang tertukar; yang versi `VAL_*` adalah yang benar untuk stok SO. Dipasang bersama `SPEC_STOCK = 'E'` |
| 3 | **Konversi UoM eksternal → internal (`CONVERSION_EXIT_CUNIT_INPUT`) sebelum masuk BAPI** | Kebalikan dari `CUNIT_OUTPUT` yang dipakai untuk tampilan (lihat D30). UI memegang `PC`, BAPI menuntut `ST` |
| 4 | **`GM_CODE = '04'`** | Kode transaksi goods movement untuk transfer posting |
| 5 | **Dua kali cek error: setelah `CREATE`, lalu setelah `COMMIT`** | `BAPI_GOODSMVT_CREATE` bisa lolos tapi commit-nya gagal. Cek sekali saja akan melaporkan "berhasil" untuk posting yang tidak pernah tersimpan |

#### Yang sengaja TIDAK diikutkan

| Bagian YPPI013 | Alasan tidak diport |
|---|---|
| **WM / Transfer Order** (`CREATE_TO_TP`) | Di luar cakupan Fase 4 |
| **Fallback MCHB** | Di luar cakupan Fase 4 |
| **Cetak smartform** | Di luar cakupan Fase 4 |
| **BDC `ZRMV_TIMEOUT`** | **Report-nya kosong — tidak melakukan apa pun.** Memanggilnya cuma menyalin cargo cult |

#### Yang sengaja dibedakan

| Field | Keputusan di sini | Alasan |
|---|---|---|
| `pstng_date` / `doc_date` | `sy-datum` (hari ini) | Sumber asli di YPPI013 disebut *"ambigu/bug"* — bukan pola yang layak ditiru |
| `header_txt` | `lv_trs_referal` (Referal MatDoc) | idem — keputusan eksplisit, bukan warisan |
| `pr_uname` | `sy-uname` | |

#### Yang murni baru (tidak ada padanannya di YPPI013)

YPPI013 adalah report ABAP dengan screen/ALV; `pelacakan.htm` adalah halaman BSP. Bagian berikut tidak punya asal-usul di sana dan harus dinilai sendiri:

- rekonstruksi baris dari field form dinamis (`DO 500 TIMES` + `CONCATENATE`)
- validasi preview terhadap `MSKA` (step 1)
- modal, `trsSubmitGuard()`, persist sessionStorage

---

## 6. Modal Transfer Posting

Preview dan hasil posting tampil sebagai **modal overlay**, bukan blok inline.

| Aspek | Implementasi |
|---|---|
| Posisi markup | **Top-level dokumen**, sebelum `<script>` — bukan di dalam `.list-container` |
| Kenapa top-level | `position:fixed` bisa terpotong ancestor ber-`transform`/`filter`; sekaligus membebaskan tabel 8 kolom dari lebar kolom 40% |
| Kondisi tampil | `IF lv_trs_preview = abap_true OR lv_trs_step = 'submit'.` |
| Isi | bercabang: step `preview` → tabel editable; step `submit` → kartu hasil |
| Menutup | tombol ✕, tombol Batal, klik backdrop, tombol Esc |

> **Kenapa ada `OR lv_trs_step = 'submit'`:** `lv_trs_preview` **hanya** di-set `abap_true` di dalam cabang `IF lv_trs_step = 'preview'`. Tanpa `OR` itu, hasil posting tidak akan pernah dirender — BAPI jalan, dokumen terbentuk, tapi layar balik ke form kosong tanpa pesan apa pun. Jangan hapus kondisi keduanya.

**Setelah posting sukses**, tombolnya `<a href="pelacakan.htm">` (GET) — bukan tombol close. Halaman itu hasil POST; kalau user cuma menutup modal lalu refresh, browser mengirim ulang form → **dokumen material dobel**. Navigasi ke URL bersih memutus jalur itu.

---

## 7. JavaScript

Semua inline di `<script>` akhir halaman. **Sengaja tidak memakai `js.js`** untuk tab (fungsi `switchTab()` di sana butuh wrapper `.detail-content` yang tidak ada di halaman ini).

| Fungsi | Guna |
|---|---|
| `pelTab(id, btn)` | Tab lokal — show/hide sederhana, data sudah dirender penuh server-side |
| `pelToggleBom(id)` / `pelCloseBom(id)` | Expand/collapse baris komponen BOM |
| `pelHistFilter()` | Filter client-side tab Riwayat (teks material + dropdown MvT), sekalian menyembunyikan grup tanggal yang jadi kosong |
| `trsModalClose()` | Tutup modal + lepas kunci scroll body |
| `trsSubmitGuard(f)` | Kunci form setelah submit pertama (anti double-post) |
| `toggleUserDropdown` / `userLogout` | Dropdown user + logout ke `index.htm?~logoff` |
| *(IIFE)* format angka | `toLocaleString('id-ID')`, mandiri dari `js.js` |
| *(IIFE)* persist form | sessionStorage, lihat bawah |

### Persist form kanan (sessionStorage)

Form kiri (Cari SO) dan form kanan (Transfer Posting) adalah **dua `<form>` terpisah** — submit form kiri me-reload halaman dan isi form kanan hilang. Solusinya auto-save tiap ketikan (debounce 200 ms) ke `sessionStorage` key `pelacakan_trs_form`.

Prioritas nilai saat restore:
1. Nilai yang server render (mis. setelah klik Preview) — **selalu menang**
2. Nilai dari sessionStorage
3. Kosong

`sessionStorage` dipilih (bukan `localStorage`) supaya draft hilang saat tab browser ditutup. Tombol Reset ikut menghapus key-nya.

> Selector reset link-nya `form.parentNode.querySelectorAll('a[href="pelacakan.htm"]')` — dibatasi ke parent `#trs-form` (`.list-container`), jadi link `pelacakan.htm` di dalam modal (yang berada di luar container itu) tidak ikut terjaring.

---

## 8. Riwayat Keputusan Desain

Kode ini penuh penanda `D##`. Yang paling penting untuk dipahami sebelum mengubah apa pun:

| Tanda | Keputusan |
|---|---|
| **Revisi 1 → 2** | Sumber data diganti dari agregasi net MSEG ke **AFPO per order** — satu baris = satu order, gaya COOIS |
| **D30** | `MEINS` tersimpan format **internal** (`ST`); wajib `CONVERSION_EXIT_CUNIT_OUTPUT` ke eksternal (`PC`) agar sama dengan COOIS. Tanpa ini satuan terlihat "salah" |
| **D32** | Kolom "BOM numb." di COOIS = field `STLNR` yang melekat di order, **bukan** re-lookup `MAST`. Lookup generik per-material bisa salah pilih `STLAN`/`STLAL` |
| **D33** | Koreksi D32: `STLNR` ada di **AFKO** (header order), bukan AFPO (item order). Aktivasi sempat gagal "no component STLNR". Dari sini muncul JOIN ke AFKO |
| **D34** | **Bug sy-tabix.** `LOOP ... INTO` + `MODIFY ... INDEX sy-tabix` rusak karena `READ TABLE` dan `CALL FUNCTION` di tengah loop ikut mengubah `sy-tabix` (system field global). Hasil enrichment tertulis ke baris salah. Diganti `ASSIGNING <fs>` |
| **D35 / D36** | Tab Info Order + Status SO/Item, semua `SELECT SINGLE` ringan |
| **D39** | Tab Riwayat & Stok — menjawab keterbatasan tab AFPO: begitu barang ditransfer via 301/311, order tidak berubah, jadi pergerakan pasca-receipt tidak terlihat |
| **D40** | Enhancement UI Riwayat: gabung pasangan OUT+IN, badge MvT berwarna, group tanggal, filter client-side |
| **D41** | Persist form kanan via sessionStorage |
| **D42** | Form Transfer Posting multi-material (Fase 3: preview) |
| **D43** | Fase 4: eksekusi `BAPI_GOODSMVT_CREATE` (port dari `YPPI013` SAVE3 mode r311, lihat §5.4) + modal |

---

## 9. Isu Terbuka

| # | Isu | Dampak |
|---|---|---|
| 1 | **Nama field huruf besar vs kecil.** Fase 4 mencari `'TRS_SEL_'`, `'TRS_MATNR_'` dst (uppercase); HTML merender `name="trs_sel_1"` (lowercase). Sisa file konsisten lowercase | Kalau `get_form_field` case-sensitive → semua baris terbaca kosong → selalu "Tidak ada baris valid yang dicentang". Gagalnya aman, tapi menyesatkan |
| 2 | **Tidak ada validasi ulang server-side saat submit.** `trs_qty_N`, `trs_matnr_N`, `trs_so_N` diambil apa adanya dari form dan langsung masuk BAPI | Qty di atas stok atau material yang diubah lewat devtools lolos ke BAPI. Atribut `max=` hanya client-side. Pertahanan terakhir = BAPI itu sendiri |
| 3 | **Tidak ada proteksi idempoten di server.** `trsSubmitGuard()` hanya client-side | Double-post masih mungkin via back/forward atau JS mati |
| 4 | `trs_pernr` (NIK) & `trs_kpd` (Good Recipient) diisi user tapi tidak masuk BAPI; `GR_RCPT` kosong | Data entry hilang saat posting. Sengaja atau terlewat? |
| 5 | Blok `IF ... CONTINUE ELSE CONTINUE` di dalam `DO 500 TIMES` — kedua cabang identik, "berhenti scan lebih awal" yang disebut komentar tidak terjadi | Fungsional benar, tapi selalu 500 iterasi × ~1–7 `get_form_field`. Komentarnya menyesatkan |
| 6 | `ty_stok-umlme` & `-source` dideklarasikan, MARD tidak pernah di-query | Free stock yang dijanjikan komentar `~514` belum ada |
| 7 | Asumsi `AFPO-LGORT` = "Stor. Loc." gaya COOIS; SLoc `22E3` tidak ada di konstanta `ZCL_CS_UTIL` | Belum dikonfirmasi ke user |
| 8 | Enam SLoc plant 2000 di-hardcode di tiga query terpisah | Ubah satu, lupa dua |
| 9 | **`YPPI013` tidak ada di repo ini.** Logic posting Fase 4 diklaim meniru `SAVE3` mode `r311` di sana, tapi klaim itu hanya hidup di komentar `pelacakan.htm` — tidak bisa di-diff terhadap sumber aslinya (§5.4) | Kalau posting berperilaku beda dari YPPI013, tidak ada acuan di repo untuk membandingkan. Porting juga dilakukan dari membaca kode, bukan observasi runtime — celah masih mungkin |

---

## 10. D44 — Halaman Ini Jadi `index.htm`

Isi lama `index.htm` (Dashboard Statistik & Grafik) **dipensiunkan** atas permintaan user; halaman pelacakan mengambil alih entry point aplikasi.

### Yang disesuaikan

| Item | Perubahan |
|---|---|
| Navbar halaman ini | Entri **"Dashboard" dihapus**. "Pelacakan" jadi entri pertama + `active`, href `index.htm` |
| Navbar halaman ini (D45) | Entri **"Monitoring" & "Riwayat" ikut dihapus** atas permintaan user — navbar tinggal **satu entri** |
| Navbar `monitoring` / `riwayat` / `transfer` | Tombol "Dashboard" (`&#9782;` → `index.htm`) diganti jadi **"Pelacakan"** (`&#128269;`), href tetap `index.htm` |
| Form action | `pelacakan.htm` → `index.htm` (form Cari SO, `#trs-form`, `#trs-preview-form`) |
| Link Reset & tombol modal | `pelacakan.htm` → `index.htm` |
| Selector reset sessionStorage | `a[href="pelacakan.htm"]` → `a[href="index.htm"]`. Tetap discope ke `form.parentNode`, jadi link navbar tidak ikut terjaring |
| `userLogout()` | **Tidak berubah** — tetap `index.htm?~logoff`, sekarang mendarat di halaman ini |

### Cadangan Dashboard

| Tempat | Keterangan |
|---|---|
| `index_backup.htm` | Salinan byte-identik `index.htm` lama (beda line-ending saja) — **untracked di git** |
| Git | Commit terakhir yang memuatnya: `b2a039f` |

> ⚠️ `index_backup.htm` belum masuk git. Kalau working directory hilang, satu-satunya cadangan Dashboard adalah riwayat git.

### Halaman tanpa navbar

`monitoring_bom.htm`, `monitoring_detail.htm`, `diag_movement.htm` tidak punya navbar sama sekali — tidak terpengaruh.

### D45 — Navigasi jadi satu arah

Setelah "Monitoring" & "Riwayat" dihapus dari navbar `index.htm`, arah navigasi jadi **tidak simetris**:

```
index.htm ──────────────────────────────►  (buntu, tidak menaut ke mana-mana)
                    ▲
                    │  tombol "Pelacakan"
                    │
     monitoring.htm ┼─ riwayat.htm ─ transfer.htm
        (ketiganya masih saling menaut satu sama lain)
```

| Fakta | Konsekuensi |
|---|---|
| `monitoring.htm`, `riwayat.htm`, `transfer.htm` **tetap ada dan tetap saling menaut** | Tidak ada yang rusak — halaman-halaman itu berfungsi normal |
| Dari `index.htm` **tidak ada jalan** ke ketiganya | User yang mendarat di entry point hanya bisa mengaksesnya via **URL langsung** |
| Ketiganya masih punya tombol "Pelacakan" → `index.htm` | Jalan **balik** ke entry point tetap ada |

> ⚠️ Ini keputusan sadar user, bukan kelalaian. Tapi efek praktisnya: `monitoring.htm` dan `riwayat.htm` jadi **tidak dapat ditemukan** oleh user yang masuk lewat entry point — nasib yang sama dengan `transfer.htm` sejak D25 dan `diag_movement.htm` / `maintenance.htm` yang memang tidak pernah ditautkan.

---

## 11. Duplikasi `index.htm` ↔ `pelacakan.htm`

`pelacakan.htm` **sengaja dipertahankan** (keputusan user) dan isinya identik dengan `index.htm` kecuali tiga hal:

1. blok komentar `D44` di header `index.htm`
2. susunan navbar (`pelacakan.htm` masih punya entri "Dashboard" dan "Pelacakan" terpisah)
3. self-reference form/link (`pelacakan.htm` vs `index.htm`)

> ⚠️ **Perbaikan bug wajib diterapkan ke KEDUA file.** Kalau tidak, keduanya akan menyimpang diam-diam — dan karena `pelacakan.htm` masih bisa diakses via URL langsung, user bisa saja memakai versi yang belum diperbaiki.
>
> ⚠️ **`STORE_KEY` sessionStorage sama di kedua file** (`'pelacakan_trs_form'`), jadi draft form Transfer Posting **terbagi** antara keduanya. Draft yang diketik di `index.htm` akan muncul di `pelacakan.htm`, dan sebaliknya.

Cara cepat memeriksa keduanya masih sinkron:

```bash
diff <(sed 's/index\.htm/@P@/g' index.htm) <(sed 's/pelacakan\.htm/@P@/g' pelacakan.htm)
```

Keluaran yang diharapkan: hanya blok komentar D44, dua baris navbar, dan satu baris `userLogout()` (artefak normalisasi — nilai sebenarnya sama).

---

## 12. Catatan untuk Pengembang

- **Cek sinkron dengan `pelacakan.htm`** setiap kali mengubah halaman ini (§11) — dua file, satu isi.
- **Diagnostics CSS palsu.** Editor melaporkan puluhan error `css-ruleorselectorexpected` / `css-rcurlyexpected` — itu linter CSS tersedak tag `<% %>` di dalam atribut `style=`. Pola lama di seluruh app ini, bukan kerusakan.
- **Cek balance sebelum aktivasi.** Struktur kontrol ABAP tersebar di banyak scriptlet `<% %>` multi-baris, jadi grep per-baris tidak berguna. Hitung token dari seluruh scriptlet gabungan: saat ini `IF 87 / ENDIF 87`, `ELSEIF 2`, `LOOP AT 20 / ENDLOOP 20`, `DO 1 / ENDDO 1`, `WHILE 1 / ENDWHILE 1`.
- **Nomor baris di dokumen ini mengacu ke `pelacakan.htm`.** Di `index.htm` semuanya bergeser **+17 baris** karena blok komentar D44 di header.
- **`CONCATENATE` butuh operand character-like.** Variabel `TYPE i` harus dikonversi dulu (`lv_idx_str = lv_line_idx. CONDENSE lv_idx_str.`) — kesalahan ini sempat memicu 8 error aktivasi sekaligus.
