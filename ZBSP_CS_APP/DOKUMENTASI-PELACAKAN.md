# Dokumentasi `pelacakan.htm` — Pelacakan Material per SO+Item

Halaman BSP mandiri untuk **melacak satu pasang Sales Order + Item** dari sisi order produksi, pergerakan barang, dan posisi stok — plus form **Transfer Posting (MvT 311)** multi-material.

> Lokasi: `ZBSP_CS_APP/Page with Flow Logic/pelacakan.htm` (±1.884 baris)
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
| **Navigasi** | Punya entri navbar sendiri (`Pelacakan`), tapi **tidak ditautkan dari halaman lain** — hanya bisa diakses via URL langsung |

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

> ⚠️ Ini pemetaan **langsung** dari `GBSTK`/`GBSTA`. Kalau "Overall Status" di VA03 ternyata berasal dari kombinasi status lain, label di sini bisa berbeda dari yang dilihat user di SAP GUI. Belum dikonfirmasi.

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

**Direplikasi dari `YPPI013` (SAVE3, mode r311)** sebatas yang bisa diverifikasi dari kodenya. **Tidak** termasuk: WM/Transfer Order (`CREATE_TO_TP`), fallback MCHB, cetak smartform, dan BDC `ZRMV_TIMEOUT` (report-nya kosong, tidak melakukan apa pun).

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
| **D43** | Fase 4: eksekusi `BAPI_GOODSMVT_CREATE` + modal |

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

---

## 10. Catatan untuk Pengembang

- **Halaman ini belum masuk git** (untracked saat dokumen ini ditulis) dan belum dicatat di `DOKUMENTASI-SUMBER-DATA.md` / `DOKUMENTASI-FITUR-ELEMEN.md`.
- **Diagnostics CSS palsu.** Editor melaporkan puluhan error `css-ruleorselectorexpected` / `css-rcurlyexpected` — itu linter CSS tersedak tag `<% %>` di dalam atribut `style=`. Pola lama di seluruh app ini, bukan kerusakan.
- **Cek balance sebelum aktivasi.** Struktur kontrol ABAP tersebar di banyak scriptlet `<% %>` multi-baris, jadi grep per-baris tidak berguna. Hitung token dari seluruh scriptlet gabungan: saat ini `IF 89 / ENDIF 89`, `LOOP AT 20 / ENDLOOP 20`, `DO 1 / ENDDO 1`.
- **`CONCATENATE` butuh operand character-like.** Variabel `TYPE i` harus dikonversi dulu (`lv_idx_str = lv_line_idx. CONDENSE lv_idx_str.`) — kesalahan ini sempat memicu 8 error aktivasi sekaligus.
