# Pohon Konvergensi Material — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mengganti rantai stasiun lurus di `routing_map.htm` dengan pohon konvergensi material berbasis pegging RESB, supaya halaman bisa menjawab "proses ini tertahan komponen yang mana".

**Architecture:** Logika pegging + stok + status pindah ke class baru `ZCL_CS_PEG`. Class dipecah dua lapis: `assemble( )` adalah fungsi **murni** (tabel masuk → tabel pohon keluar, tanpa akses database) sehingga bisa diuji dengan ABAP Unit; `build( )` adalah selubung tipis yang membaca database lalu memanggil `assemble( )`. `routing_map.htm` tinggal memanggil `build( )` dan menggambar.

**Tech Stack:** ABAP (SE24 global class + ABAP Unit), BSP Page with Flow Logic (SE80), HTML/CSS/JS tanpa resource eksternal.

## Global Constraints

Nilai-nilai berikut disalin verbatim dari spec dan berlaku di SEMUA task:

- **Jangan** memfilter `XLOEK = space` di WHERE saat SELECT `RESB` — ambil semua baris, lacak `any_open` (pelajaran D48 `monitoring.htm`).
- Plant SELALU dipasangkan dengan DISPO: Plant `1000` → `WM1, WM2, PN1, PN2`; Plant `2000` → `GA1, GA2, EB2`. Jangan pakai daftar DISPO datar.
- Rumus status operasi (dipakai `diag_routing.htm` & `index2.htm`, jangan bikin varian): `ΣAFRU-LMNGA = 0` → queue · `0 < ΣLMNGA < AFVV-MGVRG` → active · `ΣLMNGA >= MGVRG` atau `AUERU='X'` → confirmed. Baris `AFRU` `STOKZ='X'` dibuang lebih dulu. `AFRU` dicocokkan ke operasi lewat `AUFNR + VORNR`.
- Status kesiapan komponen memakai **`stok_so` saja** (MSKA). `stok_free` (MARD) ditampilkan tapi tidak menentukan status.
- Stasiun: `1` Pembahanan (Plant 1000 **hanya** DISPO WM1/WM2/PN1/PN2; Plant 1000 ber-DISPO lain jatuh ke stasiun 9) · `2` Central Storage (titik stok, 2KCS, tanpa nomor) · `3` Machining (GA1/GA2; SLoc 2261, 2262) · `4` Edge Banding (EB2; SLoc 22E2, 22E3) · `5` Sanding (SLoc 229K) · `9` Lainnya. `seq` = urutan internal; nomor yang TAMPIL: 1, (kosong), 2, 3, 4, (kosong).
- `level` akar = 0. Batas kedalaman DFS = 10. Batas order default `iv_maxord` = 800.
- Teks dari SAP (`MAKTX`, `KTEXT`) dibungkus `cl_http_utility=>escape_html( )` saat dirender.
- Tidak ada resource eksternal (font/CDN) — ikon berupa `<symbol>` SVG inline.
- Form/link GET WAJIB `action="routing_map.htm"` eksplisit (bug lama: action kosong mengembalikan seluruh data).
- Jangan menjumlahkan qty lintas material (campur UoM). Angka ringkasan stasiun = COUNT material.
- Setiap pencarian order pembuat di `lt_prod`/`it_prod` WAJIB memakai kunci **(matnr, kdpos)**, bukan matnr saja — `assemble( )` bisa dipanggil untuk seluruh item SO sekaligus.
- **Pohon tidak boleh kosong secara diam-diam.** Bila ada order tetapi deteksi akar tidak menemukan satu pun (khas pada siklus RESB tertutup), SEMUA order pembuat diperlakukan sebagai akar dan diberi `note` = `'akar tidak terdeteksi (kemungkinan siklus)'`. Penjaga siklus di `descend( )` yang menghentikan rekursinya. Halaman kosong tanpa penjelasan adalah cacat, bukan hasil yang sah.

## Cara Verifikasi di Proyek Ini

Proyek ini **tidak punya test runner lokal** — ABAP hanya bisa dijalankan di sistem SAP. Karena itu tiap task memakai tiga lapis verifikasi, dan semuanya harus disebut hasilnya, bukan diasumsikan:

1. **ABAP Unit** (task 1–4, logika murni). Dijalankan manusia di SE24: buka class → `Ctrl+Shift+F10`. Agen TIDAK bisa menjalankannya; agen berhenti dan meminta hasilnya.
2. **Pemeriksaan struktur lokal** (task 5–9, file BSP). Skrip Python di bawah, dijalankan agen sendiri.
3. **Uji data nyata** (task 5–9). Jalankan halaman dengan **SO 10446**. Angka acuan dari `diag_routing.htm`: 36 order, 2 item SO, 35 material, 41 operasi, 26 confirmed / 5 active / 10 queue.

Skrip pemeriksaan struktur — simpan sekali di Task 5, dipakai ulang task berikutnya:

```python
# scripts/check_bsp.py  — jalankan: python scripts/check_bsp.py <file.htm>
import re, sys
p = sys.argv[1]
raw = open(p, encoding='utf-8').read()
head = '\n'.join(raw.split('\n')[1:]).split('%>')[0]   # lewati direktif baris 1
bad = re.findall(r'<%|%>', head[2:])
ok = True
def chk(label, a, b):
    global ok
    good = (a == b)
    ok = ok and good
    print(('OK   ' if good else 'GAGAL') + f' {label}: {a} / {b}')
print(('OK    delimiter nyasar di blok ABAP: tidak ada') if not bad
      else f'GAGAL delimiter nyasar di blok ABAP: {bad}')
ok = ok and not bad
chk('<% vs %>',        raw.count('<%'), raw.count('%>'))
chk('<%-- vs --%>',    raw.count('<%--'), raw.count('--%>'))
chk('LOOP vs ENDLOOP', len(re.findall(r'\bLOOP AT\b', raw)), len(re.findall(r'\bENDLOOP\b', raw)))
chk('IF vs ENDIF',     len(re.findall(r'(?<![A-Z])IF ', raw)), len(re.findall(r'\bENDIF\b', raw)))
chk('CASE vs ENDCASE', len(re.findall(r'\bCASE\b', raw)), len(re.findall(r'\bENDCASE\b', raw)))
chk('<div vs </div>',  len(re.findall(r'<div\b', raw)), len(re.findall(r'</div>', raw)))
chk('<span vs </span>',len(re.findall(r'<span\b', raw)), len(re.findall(r'</span>', raw)))
sys.exit(0 if ok else 1)
```

Catatan: error CSS `property value expected` dari linter IDE pada baris berisi `style="width:<%= ... %>%"` adalah **false positive** — linter tidak mengenal tag output BSP. Abaikan.

## Struktur File

| File | Tanggung jawab |
|---|---|
| `ZBSP_CS_APP/classes/ZCL_CS_PEG.abap` (baru) | Seluruh logika: tipe publik, pemetaan stasiun, `assemble( )` murni, `build( )` selubung DB |
| `ZBSP_CS_APP/classes/ZCL_CS_PEG_TESTS.abap` (baru) | Local test class ABAP Unit — ditempel ke tab "Local Test Classes" di SE24, bukan file terpisah di SAP |
| `ZBSP_CS_APP/Page with Flow Logic/routing_map.htm` (ubah) | Hanya penyajian: panggil `build( )`, gambar ringkasan + pohon + panel + kontrol JS |
| `scripts/check_bsp.py` (baru) | Pemeriksaan struktur file BSP |

Alasan pemisahan `assemble( )` / `build( )`: algoritma pohon adalah bagian yang paling mudah salah (siklus, duplikat, akar ganda) sekaligus paling mudah diuji **kalau** tidak menyentuh database. Memisahkannya membuat task 2–4 punya tes sungguhan, bukan sekadar "aktifkan dan lihat".

**Refinement terhadap spec bagian 5:** kontrak `build( )` bertambah satu parameter keluaran `et_opm` (operasi per material per stasiun) yang dibutuhkan panel rincian di spec 7.4. Spec menyebut `et_wc` saja; `et_wc` tetap ada untuk daftar work center, `et_opm` untuk pengelompokan Antre/Diproses/Selesai.

---

### Task 1: Kerangka class + tipe publik

**Files:**
- Create: `ZBSP_CS_APP/classes/ZCL_CS_PEG.abap`
- Create: `ZBSP_CS_APP/classes/ZCL_CS_PEG_TESTS.abap`

**Interfaces:**
- Consumes: —
- Produces: tipe `ty_ord/tt_ord`, `ty_res/tt_res`, `ty_stk/tt_stk`, `ty_makt/tt_makt`, `ty_node/tt_node`, `ty_stn/tt_stn`, `ty_wc/tt_wc`, `ty_opm/tt_opm`; method `stn_of_order( )`, `assemble( )`, `build( )`. Semua task berikutnya memakai nama-nama ini persis.

- [ ] **Step 1: Tulis file class dengan tipe + signature, implementasi kosong**

```abap
*&---------------------------------------------------------------------*
*& Global Class ZCL_CS_PEG — Pohon Konvergensi Material (pegging RESB)
*&---------------------------------------------------------------------*
*& PENTING (deployment): buat & aktifkan di SE24 dengan nama ZCL_CS_PEG
*& SEBELUM mengaktifkan routing_map.htm. Package & transport sama dengan
*& ZBSP_CS_APP.
*&
*& Dua lapis:
*&   assemble( ) — FUNGSI MURNI. Tabel masuk -> tabel pohon keluar. TIDAK
*&                 menyentuh database sama sekali, sehingga bisa diuji
*&                 ABAP Unit. Semua aturan pohon & status ada di sini.
*&   build( )    — selubung tipis: baca DB, panggil assemble( ).
*& Kalau menambah aturan, taruh di assemble( ) supaya ikut teruji.
*&
*& Spec: docs/superpowers/specs/2026-07-31-pohon-konvergensi-material-design.md
*&---------------------------------------------------------------------*
CLASS zcl_cs_peg DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.

    " ---------- MASUKAN assemble( ) ----------
    TYPES: BEGIN OF ty_ord,
             aufnr TYPE afko-aufnr,
             matnr TYPE matnr,
             kdpos TYPE afpo-kdpos,
             psmng TYPE p LENGTH 15 DECIMALS 3,
             wemng TYPE p LENGTH 15 DECIMALS 3,
             pwerk TYPE afpo-pwerk,
             dispo TYPE afko-dispo,
             aufpl TYPE afko-aufpl,
           END OF ty_ord,
           tt_ord TYPE STANDARD TABLE OF ty_ord WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_res,
             aufnr    TYPE afko-aufnr,
             matnr    TYPE matnr,
             bdmng    TYPE p LENGTH 15 DECIMALS 3,
             enmng    TYPE p LENGTH 15 DECIMALS 3,
             any_open TYPE abap_bool,
           END OF ty_res,
           tt_res TYPE STANDARD TABLE OF ty_res WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_stk,
             kdpos     TYPE afpo-kdpos,
             matnr     TYPE matnr,
             stok_so   TYPE p LENGTH 15 DECIMALS 3,
             stok_free TYPE p LENGTH 15 DECIMALS 3,
           END OF ty_stk,
           tt_stk TYPE STANDARD TABLE OF ty_stk WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_makt,
             matnr TYPE matnr,
             maktx TYPE makt-maktx,
           END OF ty_makt,
           tt_makt TYPE STANDARD TABLE OF ty_makt WITH DEFAULT KEY.

    " ---------- KELUARAN ----------
    TYPES: BEGIN OF ty_node,
             node_key   TYPE string,
             parent_key TYPE string,
             level      TYPE i,
             has_child  TYPE abap_bool,
             kdpos      TYPE afpo-kdpos,
             matnr      TYPE matnr,
             maktx      TYPE string,
             aufnr      TYPE afko-aufnr,
             stn_seq    TYPE i,
             stn_txt    TYPE string,
             dispo      TYPE afko-dispo,
             in_scope   TYPE abap_bool,
             bdmng      TYPE p LENGTH 15 DECIMALS 3,
             enmng      TYPE p LENGTH 15 DECIMALS 3,
             qty_out    TYPE p LENGTH 15 DECIMALS 3,
             ratio_txt  TYPE string,
             stok_so    TYPE p LENGTH 15 DECIMALS 3,
             stok_free  TYPE p LENGTH 15 DECIMALS 3,
             status     TYPE string,
             dup_of     TYPE string,
             note       TYPE string,
           END OF ty_node,
           tt_node TYPE STANDARD TABLE OF ty_node WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_stn,
             seq       TYPE i,
             no        TYPE string,
             tx        TYPE string,
             kind      TYPE c LENGTH 1,   " P = proses, S = titik stok
             loc       TYPE string,
             mat_cnt   TYPE i,
             ratio_txt TYPE string,
             is_hold   TYPE abap_bool,
           END OF ty_stn,
           tt_stn TYPE STANDARD TABLE OF ty_stn WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_wc,
             stn_seq    TYPE i,
             arbpl      TYPE crhd-arbpl,
             ktext      TYPE string,
             cnt_queue  TYPE i,
             cnt_active TYPE i,
             cnt_conf   TYPE i,
           END OF ty_wc,
           tt_wc TYPE STANDARD TABLE OF ty_wc WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_opm,
             stn_seq   TYPE i,
             matnr     TYPE matnr,
             maktx     TYPE string,
             arbpl     TYPE crhd-arbpl,
             aufnr     TYPE afko-aufnr,
             qty_order TYPE p LENGTH 15 DECIMALS 3,
             stok_so   TYPE p LENGTH 15 DECIMALS 3,
             op_status TYPE string,   " queue | active | confirmed
           END OF ty_opm,
           tt_opm TYPE STANDARD TABLE OF ty_opm WITH DEFAULT KEY.

    CONSTANTS: c_max_depth TYPE i VALUE 10.

    " SATU-SATUNYA tempat rumus status operasi hidup. diag_routing.htm,
    " index2.htm & class ini WAJIB memanggil method ini, jangan menyalin
    " percabangannya lagi (Task 11 mengalihkan index2.htm ke sini).
    CLASS-METHODS op_status
      IMPORTING iv_lmnga         TYPE p LENGTH 15 DECIMALS 3
                iv_mgvrg         TYPE p LENGTH 15 DECIMALS 3
                iv_aueru         TYPE c LENGTH 1
      RETURNING VALUE(rv_status) TYPE string.

    " Pemetaan order -> stasiun. Plant SELALU dipasangkan dgn DISPO.
    CLASS-METHODS stn_of_order
      IMPORTING iv_pwerk        TYPE afpo-pwerk
                iv_dispo        TYPE afko-dispo
      EXPORTING ev_seq          TYPE i
                ev_txt          TYPE string
                ev_in_scope     TYPE abap_bool.

    " FUNGSI MURNI — tanpa akses database.
    CLASS-METHODS assemble
      IMPORTING it_ord         TYPE tt_ord
                it_res         TYPE tt_res
                it_stk         TYPE tt_stk
                it_makt        TYPE tt_makt
      RETURNING VALUE(rt_node) TYPE tt_node.

    CLASS-METHODS build
      IMPORTING iv_vbeln  TYPE vbak-vbeln
                iv_posnr  TYPE afpo-kdpos OPTIONAL
                iv_maxord TYPE i DEFAULT 800
      EXPORTING et_node   TYPE tt_node
                et_stn    TYPE tt_stn
                et_wc     TYPE tt_wc
                et_opm    TYPE tt_opm
                ev_trunc  TYPE abap_bool.

ENDCLASS.

CLASS zcl_cs_peg IMPLEMENTATION.

  METHOD op_status.
  ENDMETHOD.

  METHOD stn_of_order.
    CLEAR: ev_seq, ev_txt, ev_in_scope.
  ENDMETHOD.

  METHOD assemble.
  ENDMETHOD.

  METHOD build.
    CLEAR: et_node, et_stn, et_wc, et_opm, ev_trunc.
  ENDMETHOD.

ENDCLASS.
```

- [ ] **Step 2: Tulis test class dengan satu tes yang PASTI gagal**

File `ZBSP_CS_APP/classes/ZCL_CS_PEG_TESTS.abap` — isinya ditempel ke SE24 tab **Local Test Classes**, bukan dibuat sebagai class global sendiri:

```abap
*&---------------------------------------------------------------------*
*& Local Test Classes untuk ZCL_CS_PEG
*&---------------------------------------------------------------------*
*& TEMPEL isi file ini ke SE24 -> ZCL_CS_PEG -> Goto -> Local Definitions/
*& Implementations -> "Local Test Classes". Jalankan Ctrl+Shift+F10.
*& Semua tes memakai assemble( ) yang MURNI -> tidak butuh data di DB.
*&---------------------------------------------------------------------*
CLASS ltc_peg DEFINITION FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS: ord IMPORTING iv_aufnr TYPE string
                           iv_matnr TYPE string
                           iv_psmng TYPE i
                           iv_pwerk TYPE string DEFAULT '2000'
                           iv_dispo TYPE string DEFAULT 'GA1'
                 RETURNING VALUE(rs) TYPE zcl_cs_peg=>ty_ord.
    METHODS: res IMPORTING iv_aufnr TYPE string
                           iv_matnr TYPE string
                           iv_bdmng TYPE i
                           iv_enmng TYPE i DEFAULT 0
                 RETURNING VALUE(rs) TYPE zcl_cs_peg=>ty_res.

    METHODS: stasiun_dari_plant_dispo FOR TESTING,
             rumus_status_operasi FOR TESTING.
ENDCLASS.

CLASS ltc_peg IMPLEMENTATION.

  METHOD ord.
    rs-aufnr = iv_aufnr. rs-matnr = iv_matnr. rs-psmng = iv_psmng.
    rs-pwerk = iv_pwerk. rs-dispo = iv_dispo. rs-kdpos = '000010'.
  ENDMETHOD.

  METHOD res.
    rs-aufnr = iv_aufnr. rs-matnr = iv_matnr.
    rs-bdmng = iv_bdmng. rs-enmng = iv_enmng.
  ENDMETHOD.

  METHOD rumus_status_operasi.
    " Rumus BAKU (Global Constraint). Batasnya diuji persis di titik ganti.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_cs_peg=>op_status( iv_lmnga = 0 iv_mgvrg = 10 iv_aueru = ' ' )
      exp = 'queue' msg = 'LMNGA 0 -> queue' ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_cs_peg=>op_status( iv_lmnga = 4 iv_mgvrg = 10 iv_aueru = ' ' )
      exp = 'active' msg = '0 < LMNGA < MGVRG -> active' ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_cs_peg=>op_status( iv_lmnga = 10 iv_mgvrg = 10 iv_aueru = ' ' )
      exp = 'confirmed' msg = 'LMNGA = MGVRG -> confirmed (batas bawah)' ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_cs_peg=>op_status( iv_lmnga = 0 iv_mgvrg = 10 iv_aueru = 'X' )
      exp = 'confirmed' msg = 'AUERU X menang atas qty' ).
    " MGVRG 0: tanpa qty rencana, perbandingan qty TIDAK berlaku
    cl_abap_unit_assert=>assert_equals(
      act = zcl_cs_peg=>op_status( iv_lmnga = 0 iv_mgvrg = 0 iv_aueru = ' ' )
      exp = 'queue' msg = 'MGVRG 0 tanpa konfirmasi -> queue' ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_cs_peg=>op_status( iv_lmnga = 5 iv_mgvrg = 0 iv_aueru = ' ' )
      exp = 'active' msg = 'MGVRG 0 tapi ada konfirmasi -> active, BUKAN confirmed' ).
  ENDMETHOD.

  METHOD stasiun_dari_plant_dispo.
    DATA: lv_seq TYPE i, lv_txt TYPE string, lv_in TYPE abap_bool.

    " Plant 1000 apa pun DISPO-nya -> stasiun 1 Pembahanan (digabung)
    zcl_cs_peg=>stn_of_order( EXPORTING iv_pwerk = '1000' iv_dispo = 'PN1'
                              IMPORTING ev_seq = lv_seq ev_txt = lv_txt
                                        ev_in_scope = lv_in ).
    cl_abap_unit_assert=>assert_equals( act = lv_seq exp = 1 msg = 'Plant 1000 -> stasiun 1' ).
    cl_abap_unit_assert=>assert_equals( act = lv_in  exp = abap_true ).

    zcl_cs_peg=>stn_of_order( EXPORTING iv_pwerk = '2000' iv_dispo = 'GA2'
                              IMPORTING ev_seq = lv_seq ev_in_scope = lv_in ).
    cl_abap_unit_assert=>assert_equals( act = lv_seq exp = 3 msg = 'GA2 -> Machining' ).

    zcl_cs_peg=>stn_of_order( EXPORTING iv_pwerk = '2000' iv_dispo = 'EB2'
                              IMPORTING ev_seq = lv_seq ).
    cl_abap_unit_assert=>assert_equals( act = lv_seq exp = 4 msg = 'EB2 -> Edge Banding' ).

    " Plant 1000 ber-DISPO asing -> stasiun 9, BUKAN Pembahanan
    zcl_cs_peg=>stn_of_order( EXPORTING iv_pwerk = '1000' iv_dispo = 'ZZ9'
                              IMPORTING ev_seq = lv_seq ev_in_scope = lv_in ).
    cl_abap_unit_assert=>assert_equals( act = lv_seq exp = 9
      msg = 'Plant 1000 + DISPO asing -> Lainnya, bukan Pembahanan' ).
    cl_abap_unit_assert=>assert_equals( act = lv_in exp = abap_false ).

    " DISPO di luar 7 nilai baku -> stasiun 9, in_scope false
    zcl_cs_peg=>stn_of_order( EXPORTING iv_pwerk = '2000' iv_dispo = 'ZZ9'
                              IMPORTING ev_seq = lv_seq ev_in_scope = lv_in ).
    cl_abap_unit_assert=>assert_equals( act = lv_seq exp = 9 msg = 'DISPO asing -> Lainnya' ).
    cl_abap_unit_assert=>assert_equals( act = lv_in  exp = abap_false ).
  ENDMETHOD.

ENDCLASS.
```

- [ ] **Step 3: Minta user membuat class di SE24 & menjalankan tes**

Berhenti di sini dan minta user:
1. SE24 → buat class `ZCL_CS_PEG` → tempel isi `ZCL_CS_PEG.abap` → aktifkan
2. Goto → Local Definitions/Implementations → Local Test Classes → tempel isi `ZCL_CS_PEG_TESTS.abap` → aktifkan
3. `Ctrl+Shift+F10`

Hasil yang diharapkan: **GAGAL** pada `rumus_status_operasi` dan `stasiun_dari_plant_dispo` ("Plant 1000 -> stasiun 1", act = 0 exp = 1). Kalau yang muncul syntax error, laporkan pesannya — jangan lanjut.

- [ ] **Step 4: Implementasikan `op_status( )` dan `stn_of_order( )`**

Ganti kedua method kosong dengan:

```abap
  METHOD op_status.
    " RUMUS BAKU — disalin dari diag_routing.htm:355-365 dan menjadi
    " SATU-SATUNYA salinan yang hidup. Pemanggil (build(), index2.htm)
    " tidak boleh menulis ulang percabangan ini.
    IF iv_aueru = 'X'
       OR ( iv_mgvrg > 0 AND iv_lmnga >= iv_mgvrg ).
      rv_status = 'confirmed'.
    ELSEIF iv_lmnga > 0.
      rv_status = 'active'.
    ELSE.
      rv_status = 'queue'.
    ENDIF.
  ENDMETHOD.
```

```abap
  METHOD stn_of_order.
    CLEAR: ev_seq, ev_txt, ev_in_scope.

    IF iv_pwerk = '1000'.
      " Plant 1000 DIGABUNG jadi satu stasiun (WM1/WM2 = pembahanan,
      " PN1/PN2 = panel & pressing tidak lagi dipisah).
      " TAPI hanya untuk 4 DISPO baku itu: order Plant 1000 ber-DISPO lain
      " kemungkinan milik unit lain (Chair/Metal/Painting), jadi jatuh ke
      " stasiun 9 'Lainnya' — menaruhnya di Pembahanan akan mengklaim ia
      " bagian alur Wood Furniture padahal belum tentu. (Putusan user
      " 2026-07-31 saat review Task 1: spec yang berlaku, bukan rencana.)
      IF iv_dispo = 'WM1' OR iv_dispo = 'WM2'
      OR iv_dispo = 'PN1' OR iv_dispo = 'PN2'.
        ev_seq = 1. ev_txt = 'Pembahanan'. ev_in_scope = abap_true.
        RETURN.
      ENDIF.
    ENDIF.

    IF iv_pwerk = '2000'.
      CASE iv_dispo.
        WHEN 'GA1' OR 'GA2'.
          ev_seq = 3. ev_txt = 'Machining'.    ev_in_scope = abap_true. RETURN.
        WHEN 'EB2'.
          ev_seq = 4. ev_txt = 'Edge Banding'. ev_in_scope = abap_true. RETURN.
      ENDCASE.
    ENDIF.

    " Di luar 7 nilai baku: TETAP ditampilkan (spec K3) tapi ditandai.
    ev_seq = 9. ev_txt = 'Lainnya'. ev_in_scope = abap_false.
  ENDMETHOD.
```

- [ ] **Step 5: Minta user menjalankan tes lagi**

Hasil yang diharapkan: `rumus_status_operasi` dan `stasiun_dari_plant_dispo` **LULUS**. Kalau masih gagal, laporkan assertion mana dan angkanya.

- [ ] **Step 6: Commit**

```bash
git add "ZBSP_CS_APP/classes/ZCL_CS_PEG.abap" "ZBSP_CS_APP/classes/ZCL_CS_PEG_TESTS.abap"
git commit -m "feat(peg): kerangka ZCL_CS_PEG + pemetaan order ke stasiun

Plant 1000 digabung jadi satu stasiun Pembahanan; DISPO di luar 7 nilai
baku dipetakan ke stasiun 9 Lainnya dan ditandai in_scope=false.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: `assemble( )` — sisi pohon & akar

**Files:**
- Modify: `ZBSP_CS_APP/classes/ZCL_CS_PEG.abap` (method `assemble`)
- Modify: `ZBSP_CS_APP/classes/ZCL_CS_PEG_TESTS.abap` (tambah tes)

**Interfaces:**
- Consumes: `ty_ord`, `ty_res`, `ty_node`, `stn_of_order( )` dari Task 1
- Produces: `assemble( )` yang mengisi `node_key`, `parent_key`, `matnr`, `aufnr`, `kdpos`, `stn_seq`, `stn_txt`, `dispo`, `in_scope`, `bdmng`, `enmng`, `qty_out`. Field `level`, `has_child`, `status`, `ratio_txt`, `dup_of`, `note`, `stok_*`, `maktx` BELUM diisi (task 3–4).

- [ ] **Step 0: Pindahkan deklarasi tipe internal ke `PRIVATE SECTION`**

`assemble( )` dan `descend( )` (Task 3) sama-sama memakai `ty_prod`, jadi tipenya
harus di level class, bukan di dalam method. Tambahkan blok ini ke
`ZCL_CS_PEG.abap` tepat sebelum `ENDCLASS.` bagian DEFINITION:

```abap
  PRIVATE SECTION.
    TYPES: BEGIN OF ty_prod,
             matnr TYPE matnr,
             kdpos TYPE afpo-kdpos,
             aufnr TYPE afko-aufnr,
             psmng TYPE p LENGTH 15 DECIMALS 3,
             pwerk TYPE afpo-pwerk,
             dispo TYPE afko-dispo,
           END OF ty_prod,
           tt_prod TYPE STANDARD TABLE OF ty_prod WITH DEFAULT KEY.
```

- [ ] **Step 1: Tulis tes yang gagal — konvergensi sederhana & akar**

Tambahkan di `PRIVATE SECTION` `ltc_peg`: `METHODS: pohon_konvergensi FOR TESTING.` lalu implementasinya:

```abap
  METHOD pohon_konvergensi.
    " PANEL (order O2, output 4) memakan 20 KAKI (order O1) -> rasio 5:1
    DATA: lt_ord TYPE zcl_cs_peg=>tt_ord,
          lt_res TYPE zcl_cs_peg=>tt_res,
          lt_stk TYPE zcl_cs_peg=>tt_stk,
          lt_mkt TYPE zcl_cs_peg=>tt_makt,
          lt_nod TYPE zcl_cs_peg=>tt_node.

    APPEND ord( iv_aufnr = 'O1' iv_matnr = 'KAKI'  iv_psmng = 20
                iv_pwerk = '1000' iv_dispo = 'PN1' ) TO lt_ord.
    APPEND ord( iv_aufnr = 'O2' iv_matnr = 'PANEL' iv_psmng = 4 ) TO lt_ord.
    APPEND res( iv_aufnr = 'O2' iv_matnr = 'KAKI' iv_bdmng = 20 ) TO lt_res.

    lt_nod = zcl_cs_peg=>assemble( it_ord = lt_ord it_res = lt_res
                                   it_stk = lt_stk it_makt = lt_mkt ).

    cl_abap_unit_assert=>assert_equals(
      act = lines( lt_nod ) exp = 2 msg = 'akar PANEL + anak KAKI' ).

    " baris pertama = akar (PANEL), tidak punya induk
    READ TABLE lt_nod INDEX 1 INTO DATA(ls_root).
    cl_abap_unit_assert=>assert_equals( act = ls_root-matnr exp = 'PANEL' ).
    cl_abap_unit_assert=>assert_initial( act = ls_root-parent_key ).
    cl_abap_unit_assert=>assert_equals( act = ls_root-stn_seq exp = 3 ).

    READ TABLE lt_nod INDEX 2 INTO DATA(ls_kid).
    cl_abap_unit_assert=>assert_equals( act = ls_kid-matnr exp = 'KAKI' ).
    cl_abap_unit_assert=>assert_equals( act = ls_kid-parent_key exp = ls_root-node_key ).
    cl_abap_unit_assert=>assert_equals( act = ls_kid-bdmng exp = 20 ).
    cl_abap_unit_assert=>assert_equals( act = ls_kid-qty_out exp = 20
      msg = 'qty_out anak = PSMNG order pembuatnya' ).
    cl_abap_unit_assert=>assert_equals( act = ls_kid-stn_seq exp = 1 ).
  ENDMETHOD.
```

- [ ] **Step 2: Minta user menjalankan tes**

Hasil yang diharapkan: **GAGAL** — `lines( lt_nod )` = 0, exp 2.

- [ ] **Step 3: Implementasikan sisi pohon & akar**

```abap
  METHOD assemble.
    DATA: lt_res_agg TYPE tt_res,
          ls_res     TYPE ty_res,
          ls_ord     TYPE ty_ord,
          ls_node    TYPE ty_node.
    FIELD-SYMBOLS <r> TYPE ty_res.

    " --- 1. Agregasi RESB per (aufnr, matnr) ---
    "     Satu komponen bisa punya >1 baris RESB di order yang sama.
    LOOP AT it_res INTO ls_res.
      READ TABLE lt_res_agg ASSIGNING <r>
        WITH KEY aufnr = ls_res-aufnr matnr = ls_res-matnr.
      IF sy-subrc <> 0.
        APPEND INITIAL LINE TO lt_res_agg ASSIGNING <r>.
        <r>-aufnr = ls_res-aufnr. <r>-matnr = ls_res-matnr.
      ENDIF.
      <r>-bdmng = <r>-bdmng + ls_res-bdmng.
      <r>-enmng = <r>-enmng + ls_res-enmng.
      IF ls_res-any_open = abap_true.
        <r>-any_open = abap_true.
      ENDIF.
    ENDLOOP.

    " --- 2. Indeks material -> order pembuat ---
    "     Bila satu material punya >1 order (batch terpisah), qty diagregasi
    "     jadi SATU simpul (spec bagian 6 langkah 3).
    "     ⚠️ Tipe ty_prod/tt_prod dideklarasikan di PRIVATE SECTION (Task 3),
    "        BUKAN di dalam method ini — descend( ) juga memakainya. Jangan
    "        mendeklarasikannya dua kali; itu syntax error.
    DATA: lt_prod TYPE tt_prod.
    FIELD-SYMBOLS <p> TYPE ty_prod.

    LOOP AT it_ord INTO ls_ord.
      READ TABLE lt_prod ASSIGNING <p>
        WITH KEY matnr = ls_ord-matnr kdpos = ls_ord-kdpos.
      IF sy-subrc <> 0.
        APPEND INITIAL LINE TO lt_prod ASSIGNING <p>.
        <p>-matnr = ls_ord-matnr. <p>-kdpos = ls_ord-kdpos.
        <p>-aufnr = ls_ord-aufnr. <p>-pwerk = ls_ord-pwerk.
        <p>-dispo = ls_ord-dispo.
      ENDIF.
      <p>-psmng = <p>-psmng + ls_ord-psmng.
    ENDLOOP.

    " --- 3. Material yang DIPAKAI order lain (utk menentukan akar) ---
    DATA: lt_used TYPE STANDARD TABLE OF matnr WITH DEFAULT KEY.
    LOOP AT lt_res_agg INTO ls_res.
      READ TABLE lt_prod TRANSPORTING NO FIELDS WITH KEY matnr = ls_res-matnr.
      IF sy-subrc = 0.        " hanya yg punya order pembuat (spec K4)
        APPEND ls_res-matnr TO lt_used.
      ENDIF.
    ENDLOOP.
    SORT lt_used. DELETE ADJACENT DUPLICATES FROM lt_used.

    " --- 4. Akar = order yang materialnya tidak dipakai order lain ---
    DATA: lv_key TYPE string.
    LOOP AT lt_prod ASSIGNING <p>.
      READ TABLE lt_used TRANSPORTING NO FIELDS
        WITH KEY table_line = <p>-matnr BINARY SEARCH.
      IF sy-subrc = 0.
        CONTINUE.             " bukan akar, dia dipakai order lain
      ENDIF.
      CLEAR ls_node.
      lv_key = <p>-kdpos && '/' && <p>-matnr.
      ls_node-node_key = lv_key.
      ls_node-kdpos    = <p>-kdpos.
      ls_node-matnr    = <p>-matnr.
      ls_node-aufnr    = <p>-aufnr.
      ls_node-qty_out  = <p>-psmng.
      ls_node-dispo    = <p>-dispo.
      stn_of_order( EXPORTING iv_pwerk = <p>-pwerk iv_dispo = <p>-dispo
                    IMPORTING ev_seq   = ls_node-stn_seq
                              ev_txt   = ls_node-stn_txt
                              ev_in_scope = ls_node-in_scope ).
      APPEND ls_node TO rt_node.

      " anak-anaknya ditelusuri di Task 3 (DFS). Sementara: satu tingkat.
      LOOP AT lt_res_agg INTO ls_res WHERE aufnr = <p>-aufnr.
        " kdpos WAJIB ikut jadi kunci: lt_prod berkunci (matnr, kdpos), dan
        " assemble( ) bisa dipanggil utk SELURUH item SO sekaligus (iv_posnr
        " opsional). Tanpa kdpos, anak bisa nyantol ke order induk milik item
        " lain yang kebetulan memakai material sama.
        READ TABLE lt_prod ASSIGNING FIELD-SYMBOL(<c>)
          WITH KEY matnr = ls_res-matnr kdpos = <p>-kdpos.
        IF sy-subrc <> 0.
          CONTINUE.           " barang beli -> dibuang (spec K4)
        ENDIF.
        CLEAR ls_node.
        ls_node-node_key   = <c>-kdpos && '/' && <c>-matnr.
        ls_node-parent_key = lv_key.
        ls_node-kdpos      = <c>-kdpos.
        ls_node-matnr      = <c>-matnr.
        ls_node-aufnr      = <c>-aufnr.
        ls_node-qty_out    = <c>-psmng.
        ls_node-bdmng      = ls_res-bdmng.
        ls_node-enmng      = ls_res-enmng.
        ls_node-dispo      = <c>-dispo.
        stn_of_order( EXPORTING iv_pwerk = <c>-pwerk iv_dispo = <c>-dispo
                      IMPORTING ev_seq   = ls_node-stn_seq
                                ev_txt   = ls_node-stn_txt
                                ev_in_scope = ls_node-in_scope ).
        APPEND ls_node TO rt_node.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.
```

- [ ] **Step 4: Minta user menjalankan tes**

Hasil yang diharapkan: `pohon_konvergensi` **LULUS**, `stasiun_dari_plant_dispo` tetap lulus.

- [ ] **Step 5: Commit**

```bash
git add "ZBSP_CS_APP/classes/ZCL_CS_PEG.abap" "ZBSP_CS_APP/classes/ZCL_CS_PEG_TESTS.abap"
git commit -m "feat(peg): sisi pohon & deteksi akar dari pegging RESB

Barang beli (komponen tanpa order pembuat) dibuang sesuai keputusan K4.
Material dgn >1 order pembuat diagregasi jadi satu simpul.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: `assemble( )` — DFS berlevel, siklus, duplikat

**Files:**
- Modify: `ZBSP_CS_APP/classes/ZCL_CS_PEG.abap` (method `assemble`)
- Modify: `ZBSP_CS_APP/classes/ZCL_CS_PEG_TESTS.abap`

**Interfaces:**
- Consumes: `assemble( )` dari Task 2
- Produces: `assemble( )` yang mengisi `level` (akar = 0), `has_child`, `dup_of`, dan `note` = `'rekursi dihentikan'` / `'batas kedalaman'`. Urutan `rt_node` = urutan DFS (induk lalu anak-anaknya).

- [ ] **Step 1: Tulis tes — tiga tingkat, duplikat, siklus**

```abap
  METHOD pohon_tiga_tingkat.
    " PINTU(1) <- DAUN(2) <- PANEL(4) <- KAKI(20)
    DATA: lt_ord TYPE zcl_cs_peg=>tt_ord, lt_res TYPE zcl_cs_peg=>tt_res,
          lt_stk TYPE zcl_cs_peg=>tt_stk, lt_mkt TYPE zcl_cs_peg=>tt_makt,
          lt_nod TYPE zcl_cs_peg=>tt_node.

    APPEND ord( iv_aufnr = 'O1' iv_matnr = 'KAKI'  iv_psmng = 20
                iv_pwerk = '1000' iv_dispo = 'PN1' ) TO lt_ord.
    APPEND ord( iv_aufnr = 'O2' iv_matnr = 'PANEL' iv_psmng = 4 ) TO lt_ord.
    APPEND ord( iv_aufnr = 'O3' iv_matnr = 'DAUN'  iv_psmng = 2
                iv_dispo = 'EB2' ) TO lt_ord.
    APPEND ord( iv_aufnr = 'O4' iv_matnr = 'PINTU' iv_psmng = 1
                iv_dispo = 'ZZ9' ) TO lt_ord.
    APPEND res( iv_aufnr = 'O2' iv_matnr = 'KAKI'  iv_bdmng = 20 ) TO lt_res.
    APPEND res( iv_aufnr = 'O3' iv_matnr = 'PANEL' iv_bdmng = 4 )  TO lt_res.
    APPEND res( iv_aufnr = 'O4' iv_matnr = 'DAUN'  iv_bdmng = 2 )  TO lt_res.

    lt_nod = zcl_cs_peg=>assemble( it_ord = lt_ord it_res = lt_res
                                   it_stk = lt_stk it_makt = lt_mkt ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_nod ) exp = 4 ).

    " urutan DFS: PINTU(0) DAUN(1) PANEL(2) KAKI(3)
    DATA(lt_exp_mat) = VALUE string_table(
      ( `PINTU` ) ( `DAUN` ) ( `PANEL` ) ( `KAKI` ) ).
    DATA lv_i TYPE i.
    LOOP AT lt_nod INTO DATA(ls_n).
      lv_i = sy-tabix.
      READ TABLE lt_exp_mat INDEX lv_i INTO DATA(lv_exp).
      cl_abap_unit_assert=>assert_equals( act = ls_n-matnr exp = lv_exp
        msg = |urutan DFS baris { lv_i }| ).
      DATA(lv_lvl) = lv_i - 1.
      cl_abap_unit_assert=>assert_equals( act = ls_n-level exp = lv_lvl
        msg = |level baris { lv_i }| ).
    ENDLOOP.

    READ TABLE lt_nod INDEX 1 INTO ls_n.
    cl_abap_unit_assert=>assert_equals( act = ls_n-has_child exp = abap_true ).
    cl_abap_unit_assert=>assert_equals( act = ls_n-in_scope exp = abap_false
      msg = 'DISPO ZZ9 di luar scope tapi TETAP masuk pohon (K3)' ).
    READ TABLE lt_nod INDEX 4 INTO ls_n.
    cl_abap_unit_assert=>assert_equals( act = ls_n-has_child exp = abap_false ).
  ENDMETHOD.

  METHOD komponen_dipakai_dua_induk.
    " SEKAT dipakai PANEL dan DAUN -> muncul 2x, yang kedua ber-dup_of
    DATA: lt_ord TYPE zcl_cs_peg=>tt_ord, lt_res TYPE zcl_cs_peg=>tt_res,
          lt_stk TYPE zcl_cs_peg=>tt_stk, lt_mkt TYPE zcl_cs_peg=>tt_makt,
          lt_nod TYPE zcl_cs_peg=>tt_node.

    APPEND ord( iv_aufnr = 'O1' iv_matnr = 'SEKAT' iv_psmng = 10
                iv_pwerk = '1000' iv_dispo = 'PN1' ) TO lt_ord.
    APPEND ord( iv_aufnr = 'O2' iv_matnr = 'PANEL' iv_psmng = 4 ) TO lt_ord.
    APPEND ord( iv_aufnr = 'O3' iv_matnr = 'DAUN'  iv_psmng = 2
                iv_dispo = 'EB2' ) TO lt_ord.
    APPEND res( iv_aufnr = 'O2' iv_matnr = 'SEKAT' iv_bdmng = 6 ) TO lt_res.
    APPEND res( iv_aufnr = 'O3' iv_matnr = 'SEKAT' iv_bdmng = 4 ) TO lt_res.
    APPEND res( iv_aufnr = 'O3' iv_matnr = 'PANEL' iv_bdmng = 4 ) TO lt_res.

    lt_nod = zcl_cs_peg=>assemble( it_ord = lt_ord it_res = lt_res
                                   it_stk = lt_stk it_makt = lt_mkt ).

    DATA lv_cnt TYPE i.
    DATA lv_dup TYPE i.
    LOOP AT lt_nod INTO DATA(ls_n) WHERE matnr = 'SEKAT'.
      lv_cnt = lv_cnt + 1.
      IF ls_n-dup_of IS NOT INITIAL.
        lv_dup = lv_dup + 1.
      ENDIF.
    ENDLOOP.
    cl_abap_unit_assert=>assert_equals( act = lv_cnt exp = 2
      msg = 'SEKAT muncul di dua cabang' ).
    cl_abap_unit_assert=>assert_equals( act = lv_dup exp = 1
      msg = 'kemunculan kedua ditandai dup_of' ).
  ENDMETHOD.

  METHOD siklus_dihentikan.
    " A memakan B, B memakan A -> harus berhenti, tidak menggantung
    DATA: lt_ord TYPE zcl_cs_peg=>tt_ord, lt_res TYPE zcl_cs_peg=>tt_res,
          lt_stk TYPE zcl_cs_peg=>tt_stk, lt_mkt TYPE zcl_cs_peg=>tt_makt,
          lt_nod TYPE zcl_cs_peg=>tt_node.

    APPEND ord( iv_aufnr = 'OA' iv_matnr = 'A' iv_psmng = 1 ) TO lt_ord.
    APPEND ord( iv_aufnr = 'OB' iv_matnr = 'B' iv_psmng = 1 ) TO lt_ord.
    APPEND res( iv_aufnr = 'OA' iv_matnr = 'B' iv_bdmng = 1 ) TO lt_res.
    APPEND res( iv_aufnr = 'OB' iv_matnr = 'A' iv_bdmng = 1 ) TO lt_res.

    lt_nod = zcl_cs_peg=>assemble( it_ord = lt_ord it_res = lt_res
                                   it_stk = lt_stk it_makt = lt_mkt ).

    cl_abap_unit_assert=>assert_true( xsdbool( lines( lt_nod ) > 0 )
      msg = 'siklus tidak boleh menghasilkan pohon kosong' ).
    cl_abap_unit_assert=>assert_true( xsdbool( lines( lt_nod ) < 30 )
      msg = 'siklus harus berhenti, bukan meledak' ).
    DATA lv_ada TYPE abap_bool.
    LOOP AT lt_nod INTO DATA(ls_n) WHERE note CS 'rekursi'.
      lv_ada = abap_true.
    ENDLOOP.
    cl_abap_unit_assert=>assert_equals( act = lv_ada exp = abap_true
      msg = 'baris pemutus siklus harus ditandai' ).
  ENDMETHOD.
```

Tambahkan ketiganya ke `PRIVATE SECTION`:
```abap
    METHODS: pohon_tiga_tingkat FOR TESTING,
             komponen_dipakai_dua_induk FOR TESTING,
             siklus_dihentikan FOR TESTING.
```

- [ ] **Step 2: Minta user menjalankan tes**

Hasil yang diharapkan: ketiganya **GAGAL** (`pohon_tiga_tingkat` hanya menghasilkan 2 baris karena Task 2 baru satu tingkat; `siklus_dihentikan` bisa gagal atau hang — kalau hang, hentikan dan laporkan, itu berarti guard-nya belum ada).

- [ ] **Step 3: Ganti bagian penelusuran dengan DFS rekursif**

Ganti blok "anak-anaknya ditelusuri di Task 3" pada `assemble( )` dengan pemanggilan helper baru. Tambahkan di `PRIVATE SECTION` class:

```abap
  PRIVATE SECTION.
    TYPES: BEGIN OF ty_prod,
             matnr TYPE matnr,
             kdpos TYPE afpo-kdpos,
             aufnr TYPE afko-aufnr,
             psmng TYPE p LENGTH 15 DECIMALS 3,
             pwerk TYPE afpo-pwerk,
             dispo TYPE afko-dispo,
           END OF ty_prod,
           tt_prod TYPE STANDARD TABLE OF ty_prod WITH DEFAULT KEY.

    " Telusuri satu cabang ke bawah. it_path = daftar matnr leluhur, dipakai
    " sebagai penjaga siklus. ct_seen = matnr yang sudah pernah muncul di
    " pohon (untuk dup_of).
    CLASS-METHODS descend
      IMPORTING is_parent  TYPE ty_node
                it_prod    TYPE tt_prod
                it_res_agg TYPE tt_res
                it_path    TYPE string_table
      CHANGING  ct_node    TYPE tt_node
                ct_seen    TYPE string_table.
```

Implementasinya:

```abap
  METHOD descend.
    DATA: ls_res  TYPE ty_res,
          ls_node TYPE ty_node,
          lt_path TYPE string_table,
          lv_key  TYPE string.
    FIELD-SYMBOLS <par> TYPE ty_node.

    IF is_parent-level >= c_max_depth.
      READ TABLE ct_node ASSIGNING <par> WITH KEY node_key = is_parent-node_key.
      IF sy-subrc = 0.
        <par>-note = 'batas kedalaman'.
      ENDIF.
      RETURN.
    ENDIF.

    LOOP AT it_res_agg INTO ls_res WHERE aufnr = is_parent-aufnr.

      " kdpos ikut jadi kunci — lihat alasannya di assemble( ).
      READ TABLE it_prod ASSIGNING FIELD-SYMBOL(<c>)
        WITH KEY matnr = ls_res-matnr kdpos = is_parent-kdpos.
      IF sy-subrc <> 0.
        CONTINUE.                       " barang beli -> dibuang (K4)
      ENDIF.

      " penjaga siklus: material ini sudah ada di jalur leluhurnya?
      READ TABLE it_path TRANSPORTING NO FIELDS
        WITH KEY table_line = <c>-matnr.
      IF sy-subrc = 0.
        READ TABLE ct_node ASSIGNING <par> WITH KEY node_key = is_parent-node_key.
        IF sy-subrc = 0.
          <par>-note = 'rekursi dihentikan'.
        ENDIF.
        CONTINUE.
      ENDIF.

      CLEAR ls_node.
      lv_key = <c>-kdpos && '/' && <c>-matnr && '/' && is_parent-node_key.
      ls_node-node_key   = lv_key.
      ls_node-parent_key = is_parent-node_key.
      ls_node-level      = is_parent-level + 1.
      ls_node-kdpos      = <c>-kdpos.
      ls_node-matnr      = <c>-matnr.
      ls_node-aufnr      = <c>-aufnr.
      ls_node-qty_out    = <c>-psmng.
      ls_node-bdmng      = ls_res-bdmng.
      ls_node-enmng      = ls_res-enmng.
      ls_node-dispo      = <c>-dispo.
      stn_of_order( EXPORTING iv_pwerk = <c>-pwerk iv_dispo = <c>-dispo
                    IMPORTING ev_seq   = ls_node-stn_seq
                              ev_txt   = ls_node-stn_txt
                              ev_in_scope = ls_node-in_scope ).

      " sudah pernah muncul di cabang lain? -> tandai dup_of
      READ TABLE ct_seen TRANSPORTING NO FIELDS
        WITH KEY table_line = <c>-matnr.
      IF sy-subrc = 0.
        ls_node-dup_of = <c>-matnr.
      ELSE.
        APPEND <c>-matnr TO ct_seen.
      ENDIF.

      " induk terbukti punya anak
      READ TABLE ct_node ASSIGNING <par> WITH KEY node_key = is_parent-node_key.
      IF sy-subrc = 0.
        <par>-has_child = abap_true.
      ENDIF.

      APPEND ls_node TO ct_node.

      lt_path = it_path.
      APPEND <c>-matnr TO lt_path.
      descend( EXPORTING is_parent  = ls_node
                         it_prod    = it_prod
                         it_res_agg = it_res_agg
                         it_path    = lt_path
               CHANGING  ct_node    = ct_node
                         ct_seen    = ct_seen ).
    ENDLOOP.
  ENDMETHOD.
```

Lalu di `assemble( )`, ganti `LOOP AT lt_res_agg ... ENDLOOP` (blok anak satu tingkat dari Task 2) dengan:

```abap
      APPEND ls_node TO rt_node.
      APPEND <p>-matnr TO lt_seen.
      CLEAR lt_path.
      APPEND <p>-matnr TO lt_path.
      descend( EXPORTING is_parent  = ls_node
                         it_prod    = lt_prod
                         it_res_agg = lt_res_agg
                         it_path    = lt_path
               CHANGING  ct_node    = rt_node
                         ct_seen    = lt_seen ).
```

dan tambahkan deklarasi di awal `assemble( )`:
```abap
    DATA: lt_path TYPE string_table,
          lt_seen TYPE string_table.
```

**Penting:** akar mendapat `level = 0` — `ls_node-level` tidak diisi untuk akar sehingga bernilai 0 secara default. Jangan menambah `ls_node-level = 1`.

- [ ] **Step 4: Minta user menjalankan tes**

Hasil yang diharapkan: kelima tes **LULUS** (`stasiun_dari_plant_dispo`, `pohon_konvergensi`, `pohon_tiga_tingkat`, `komponen_dipakai_dua_induk`, `siklus_dihentikan`).

Kalau `siklus_dihentikan` hang: berarti `it_path` tidak diteruskan dengan benar ke rekursi. Periksa bahwa `lt_path` disalin dari `it_path` **sebelum** `APPEND`, bukan dipakai bersama.

- [ ] **Step 5: Commit**

```bash
git add "ZBSP_CS_APP/classes/ZCL_CS_PEG.abap" "ZBSP_CS_APP/classes/ZCL_CS_PEG_TESTS.abap"
git commit -m "feat(peg): DFS berlevel dgn penjaga siklus & penanda duplikat

Akar level 0, batas kedalaman 10. Material yang sudah muncul di cabang lain
ditandai dup_of supaya stoknya tidak dibaca dua kali.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: `assemble( )` — status kesiapan, rasio, maktx, catatan

**Files:**
- Modify: `ZBSP_CS_APP/classes/ZCL_CS_PEG.abap`
- Modify: `ZBSP_CS_APP/classes/ZCL_CS_PEG_TESTS.abap`

**Interfaces:**
- Consumes: `assemble( )` dari Task 3
- Produces: `assemble( )` yang mengisi `status` (`USED`/`PARTIAL`/`READY`/`SHORT`/`MISSING`), `ratio_txt`, `stok_so`, `stok_free`, `maktx`, dan `note` = `'tidak ada komponen produksi'`.

- [ ] **Step 1: Tulis tes lima status + rasio + catatan barang beli**

```abap
  METHOD status_kesiapan.
    DATA: lt_ord TYPE zcl_cs_peg=>tt_ord, lt_res TYPE zcl_cs_peg=>tt_res,
          lt_stk TYPE zcl_cs_peg=>tt_stk, lt_mkt TYPE zcl_cs_peg=>tt_makt,
          lt_nod TYPE zcl_cs_peg=>tt_node, ls_stk TYPE zcl_cs_peg=>ty_stk.

    APPEND ord( iv_aufnr = 'O0' iv_matnr = 'INDUK' iv_psmng = 4 ) TO lt_ord.
    " lima anak, satu per status
    APPEND ord( iv_aufnr = 'A' iv_matnr = 'M_USED'    iv_psmng = 20
                iv_pwerk = '1000' iv_dispo = 'PN1' ) TO lt_ord.
    APPEND ord( iv_aufnr = 'B' iv_matnr = 'M_PARTIAL' iv_psmng = 20
                iv_pwerk = '1000' iv_dispo = 'PN1' ) TO lt_ord.
    APPEND ord( iv_aufnr = 'C' iv_matnr = 'M_READY'   iv_psmng = 20
                iv_pwerk = '1000' iv_dispo = 'PN1' ) TO lt_ord.
    APPEND ord( iv_aufnr = 'D' iv_matnr = 'M_SHORT'   iv_psmng = 20
                iv_pwerk = '1000' iv_dispo = 'PN1' ) TO lt_ord.
    APPEND ord( iv_aufnr = 'E' iv_matnr = 'M_MISSING' iv_psmng = 20
                iv_pwerk = '1000' iv_dispo = 'PN1' ) TO lt_ord.

    APPEND res( iv_aufnr = 'O0' iv_matnr = 'M_USED'    iv_bdmng = 20 iv_enmng = 20 ) TO lt_res.
    APPEND res( iv_aufnr = 'O0' iv_matnr = 'M_PARTIAL' iv_bdmng = 20 iv_enmng = 8 )  TO lt_res.
    APPEND res( iv_aufnr = 'O0' iv_matnr = 'M_READY'   iv_bdmng = 20 iv_enmng = 0 )  TO lt_res.
    APPEND res( iv_aufnr = 'O0' iv_matnr = 'M_SHORT'   iv_bdmng = 20 iv_enmng = 0 )  TO lt_res.
    APPEND res( iv_aufnr = 'O0' iv_matnr = 'M_MISSING' iv_bdmng = 20 iv_enmng = 0 )  TO lt_res.

    ls_stk-kdpos = '000010'.
    ls_stk-matnr = 'M_READY'. ls_stk-stok_so = 20. APPEND ls_stk TO lt_stk.
    ls_stk-matnr = 'M_SHORT'. ls_stk-stok_so = 5.  APPEND ls_stk TO lt_stk.
    CLEAR ls_stk-stok_so.
    " stok BEBAS tidak boleh mengubah status (Global Constraint)
    ls_stk-matnr = 'M_MISSING'. ls_stk-stok_free = 999. APPEND ls_stk TO lt_stk.

    lt_nod = zcl_cs_peg=>assemble( it_ord = lt_ord it_res = lt_res
                                   it_stk = lt_stk it_makt = lt_mkt ).

    DATA lv_st TYPE string.
    LOOP AT lt_nod INTO DATA(ls_n) WHERE matnr CP 'M_*'.
      CASE ls_n-matnr.
        WHEN 'M_USED'.    lv_st = 'USED'.
        WHEN 'M_PARTIAL'. lv_st = 'PARTIAL'.
        WHEN 'M_READY'.   lv_st = 'READY'.
        WHEN 'M_SHORT'.   lv_st = 'SHORT'.
        WHEN 'M_MISSING'. lv_st = 'MISSING'.
      ENDCASE.
      cl_abap_unit_assert=>assert_equals( act = ls_n-status exp = lv_st
        msg = |status { ls_n-matnr }| ).
    ENDLOOP.

    " rasio: butuh 20 utk output induk 4 -> '5 : 1'
    READ TABLE lt_nod INTO ls_n WITH KEY matnr = 'M_USED'.
    cl_abap_unit_assert=>assert_equals( act = ls_n-ratio_txt exp = '5 : 1' ).
  ENDMETHOD.

  METHOD semua_komponen_barang_beli.
    " INDUK hanya memakan SEKRUP (tidak punya order pembuat)
    DATA: lt_ord TYPE zcl_cs_peg=>tt_ord, lt_res TYPE zcl_cs_peg=>tt_res,
          lt_stk TYPE zcl_cs_peg=>tt_stk, lt_mkt TYPE zcl_cs_peg=>tt_makt,
          lt_nod TYPE zcl_cs_peg=>tt_node.

    APPEND ord( iv_aufnr = 'O0' iv_matnr = 'INDUK' iv_psmng = 4 ) TO lt_ord.
    APPEND res( iv_aufnr = 'O0' iv_matnr = 'SEKRUP' iv_bdmng = 80 ) TO lt_res.

    lt_nod = zcl_cs_peg=>assemble( it_ord = lt_ord it_res = lt_res
                                   it_stk = lt_stk it_makt = lt_mkt ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_nod ) exp = 1 ).
    READ TABLE lt_nod INDEX 1 INTO DATA(ls_n).
    cl_abap_unit_assert=>assert_equals( act = ls_n-note exp = 'tidak ada komponen produksi'
      msg = 'daun yg semua komponennya barang beli WAJIB ditandai (R3)' ).
  ENDMETHOD.

  METHOD order_tanpa_resb.
    " R2: order sama sekali tanpa baris RESB -> catatan BERBEDA dari R3
    DATA: lt_ord TYPE zcl_cs_peg=>tt_ord, lt_res TYPE zcl_cs_peg=>tt_res,
          lt_stk TYPE zcl_cs_peg=>tt_stk, lt_mkt TYPE zcl_cs_peg=>tt_makt,
          lt_nod TYPE zcl_cs_peg=>tt_node.

    APPEND ord( iv_aufnr = 'O0' iv_matnr = 'SOLO' iv_psmng = 4 ) TO lt_ord.

    lt_nod = zcl_cs_peg=>assemble( it_ord = lt_ord it_res = lt_res
                                   it_stk = lt_stk it_makt = lt_mkt ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_nod ) exp = 1 ).
    READ TABLE lt_nod INDEX 1 INTO DATA(ls_s).
    cl_abap_unit_assert=>assert_equals( act = ls_s-note exp = 'tanpa komponen'
      msg = 'order tanpa RESB ditandai berbeda dari yg komponennya barang beli (R2)' ).
  ENDMETHOD.
```

Tambahkan ke `PRIVATE SECTION`:
```abap
    METHODS: status_kesiapan FOR TESTING,
             semua_komponen_barang_beli FOR TESTING,
             order_tanpa_resb FOR TESTING.
```

- [ ] **Step 2: Minta user menjalankan tes**

Hasil yang diharapkan: ketiga tes baru **GAGAL** (status & note masih kosong).

- [ ] **Step 3: Tambahkan lapis akhir di ujung `assemble( )`**

Sisipkan tepat sebelum `ENDMETHOD.` dari `assemble( )`:

```abap
    " --- 5. Lapis akhir: maktx, stok, rasio, status, catatan ---
    DATA: ls_stk2 TYPE ty_stk,
          ls_mkt  TYPE ty_makt,
          lv_sisa TYPE p LENGTH 15 DECIMALS 3,
          lv_rat  TYPE p LENGTH 15 DECIMALS 3.
    FIELD-SYMBOLS <n> TYPE ty_node.

    LOOP AT rt_node ASSIGNING <n>.

      READ TABLE it_makt INTO ls_mkt WITH KEY matnr = <n>-matnr.
      IF sy-subrc = 0.
        <n>-maktx = ls_mkt-maktx.
      ENDIF.

      READ TABLE it_stk INTO ls_stk2
        WITH KEY kdpos = <n>-kdpos matnr = <n>-matnr.
      IF sy-subrc = 0.
        <n>-stok_so   = ls_stk2-stok_so.
        <n>-stok_free = ls_stk2-stok_free.
      ENDIF.

      " Rasio gabung = BDMNG / PSMNG induk. Akar tidak punya bdmng.
      " qty_out INDUK dibaca dari baris induknya, bukan dari baris ini.
      IF <n>-bdmng > 0 AND <n>-parent_key IS NOT INITIAL.
        READ TABLE rt_node INTO DATA(ls_par)
          WITH KEY node_key = <n>-parent_key.
        IF sy-subrc = 0 AND ls_par-qty_out > 0.
          lv_rat = <n>-bdmng / ls_par-qty_out.
          <n>-ratio_txt = |{ lv_rat DECIMALS = 0 } : 1|.
        ELSE.
          <n>-ratio_txt = '—'.            " R8: hindari bagi nol
        ENDIF.
      ENDIF.

      " Status kesiapan — HANYA stok_so yang dipakai (Global Constraint).
      IF <n>-parent_key IS INITIAL.
        CLEAR <n>-status.                 " akar tidak dinilai kesiapannya
      ELSEIF <n>-enmng >= <n>-bdmng.
        <n>-status = 'USED'.
      ELSEIF <n>-enmng > 0.
        <n>-status = 'PARTIAL'.
      ELSE.
        lv_sisa = <n>-bdmng - <n>-enmng.
        IF <n>-stok_so >= lv_sisa.
          <n>-status = 'READY'.
        ELSEIF <n>-stok_so > 0.
          <n>-status = 'SHORT'.
        ELSE.
          <n>-status = 'MISSING'.
        ENDIF.
      ENDIF.

      " R2 & R3 — dua sebab daun yang HARUS dibedakan:
      "   ada baris RESB tapi semuanya barang beli -> 'tidak ada komponen produksi'
      "   tidak ada baris RESB sama sekali        -> 'tanpa komponen'
      IF <n>-has_child = abap_false AND <n>-note IS INITIAL.
        READ TABLE lt_res_agg TRANSPORTING NO FIELDS WITH KEY aufnr = <n>-aufnr.
        IF sy-subrc = 0.
          <n>-note = 'tidak ada komponen produksi'.
        ELSE.
          <n>-note = 'tanpa komponen'.
        ENDIF.
      ENDIF.

    ENDLOOP.
```

Perhatikan cabang `PARTIAL`: urutannya harus **sesudah** `USED` dan **sebelum** perbandingan stok, karena `0 < ENMNG < BDMNG` menang atas kondisi stok apa pun.

- [ ] **Step 4: Minta user menjalankan tes**

Hasil yang diharapkan: **kedelapan tes LULUS**. Perhatikan khusus `M_MISSING` yang punya `stok_free = 999` — kalau statusnya keluar `READY`, berarti `stok_free` ikut terpakai dan itu melanggar Global Constraint.

- [ ] **Step 5: Commit**

```bash
git add "ZBSP_CS_APP/classes/ZCL_CS_PEG.abap" "ZBSP_CS_APP/classes/ZCL_CS_PEG_TESTS.abap"
git commit -m "feat(peg): status kesiapan, rasio gabung, catatan kasus khusus

Status hanya memakai SO-stock; stok bebas ditampilkan tapi tidak menentukan.
Daun yang semua komponennya barang beli ditandai agar tidak terbaca lengkap.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 5: `build( )` — selubung database

**Files:**
- Modify: `ZBSP_CS_APP/classes/ZCL_CS_PEG.abap` (method `build`)
- Create: `scripts/check_bsp.py` (isi ada di bagian "Cara Verifikasi" di atas)

**Interfaces:**
- Consumes: `assemble( )` lengkap dari Task 4
- Produces: `build( )` yang mengisi `et_node` dan `ev_trunc`. `et_stn`, `et_wc`, `et_opm` diisi Task 6.

- [ ] **Step 1: Implementasikan `build( )`**

```abap
  METHOD build.
    CLEAR: et_node, et_stn, et_wc, et_opm, ev_trunc.

    DATA: lt_ord  TYPE tt_ord,
          lt_res  TYPE tt_res,
          lt_stk  TYPE tt_stk,
          lt_makt TYPE tt_makt.

    " --- 1. Order SO+Item. TANPA filter DISPO (spec K3): pohon tidak boleh
    "        terputus di lapis konvergensi yg DISPO-nya di luar 7 nilai baku.
    IF iv_posnr IS SUPPLIED AND iv_posnr IS NOT INITIAL.
      SELECT a~aufnr a~matnr a~kdpos a~psmng a~wemng a~pwerk k~dispo k~aufpl
        FROM afpo AS a INNER JOIN afko AS k ON a~aufnr = k~aufnr
        INTO CORRESPONDING FIELDS OF TABLE lt_ord
        WHERE a~kdauf = iv_vbeln AND a~kdpos = iv_posnr.
    ELSE.
      SELECT a~aufnr a~matnr a~kdpos a~psmng a~wemng a~pwerk k~dispo k~aufpl
        FROM afpo AS a INNER JOIN afko AS k ON a~aufnr = k~aufnr
        INTO CORRESPONDING FIELDS OF TABLE lt_ord
        WHERE a~kdauf = iv_vbeln.
    ENDIF.

    IF lt_ord IS INITIAL.
      RETURN.                       " R1: ditangani pemanggil sbg pesan kosong
    ENDIF.

    " R7: pengaman FOR ALL ENTRIES
    IF lines( lt_ord ) > iv_maxord.
      DATA(lv_cut) = iv_maxord + 1.
      DELETE lt_ord FROM lv_cut.
      ev_trunc = abap_true.
    ENDIF.

    " --- 2. RESB. JANGAN filter XLOEK di WHERE (D48) ---
    TYPES: BEGIN OF ty_resb_raw,
             aufnr TYPE resb-aufnr, matnr TYPE resb-matnr,
             bdmng TYPE resb-bdmng, enmng TYPE resb-enmng,
             xloek TYPE resb-xloek,
           END OF ty_resb_raw.
    DATA: lt_raw TYPE STANDARD TABLE OF ty_resb_raw WITH DEFAULT KEY,
          ls_raw TYPE ty_resb_raw,
          ls_res TYPE ty_res.

    SELECT aufnr matnr bdmng enmng xloek FROM resb
      INTO CORRESPONDING FIELDS OF TABLE lt_raw
      FOR ALL ENTRIES IN lt_ord
      WHERE aufnr = lt_ord-aufnr.
    DELETE lt_raw WHERE matnr IS INITIAL.

    LOOP AT lt_raw INTO ls_raw.
      CLEAR ls_res.
      ls_res-aufnr = ls_raw-aufnr.
      ls_res-matnr = ls_raw-matnr.
      ls_res-bdmng = ls_raw-bdmng.
      ls_res-enmng = ls_raw-enmng.
      IF ls_raw-xloek <> 'X'.
        ls_res-any_open = abap_true.
      ENDIF.
      APPEND ls_res TO lt_res.       " agregasi dilakukan assemble( )
    ENDLOOP.

    " --- 3. Teks material: gabungan material order + material RESB ---
    TYPES: BEGIN OF ty_mkey, matnr TYPE matnr, END OF ty_mkey.
    DATA: lt_mkey TYPE STANDARD TABLE OF ty_mkey WITH DEFAULT KEY,
          ls_mkey TYPE ty_mkey,
          ls_ord2 TYPE ty_ord.
    LOOP AT lt_ord INTO ls_ord2.
      ls_mkey-matnr = ls_ord2-matnr. APPEND ls_mkey TO lt_mkey.
    ENDLOOP.
    LOOP AT lt_res INTO ls_res.
      ls_mkey-matnr = ls_res-matnr.  APPEND ls_mkey TO lt_mkey.
    ENDLOOP.
    SORT lt_mkey BY matnr.
    DELETE ADJACENT DUPLICATES FROM lt_mkey COMPARING matnr.

    IF lt_mkey IS NOT INITIAL.
      SELECT matnr maktx FROM makt INTO TABLE lt_makt
        FOR ALL ENTRIES IN lt_mkey
        WHERE matnr = lt_mkey-matnr AND spras = sy-langu.
    ENDIF.

    " --- 4. Stok: MSKA (SO-stock) + MARD (stok bebas) ---
    TYPES: BEGIN OF ty_mska, matnr TYPE mska-matnr, posnr TYPE mska-posnr,
             kalab TYPE mska-kalab, kains TYPE mska-kains, kaspe TYPE mska-kaspe,
           END OF ty_mska.
    DATA: lt_mska TYPE STANDARD TABLE OF ty_mska WITH DEFAULT KEY,
          ls_mska TYPE ty_mska, ls_stk TYPE ty_stk.
    FIELD-SYMBOLS <s> TYPE ty_stk.

    SELECT matnr posnr kalab kains kaspe FROM mska
      INTO CORRESPONDING FIELDS OF TABLE lt_mska
      WHERE vbeln = iv_vbeln AND sobkz = 'E'
        AND ( kalab > 0 OR kains > 0 OR kaspe > 0 ).

    LOOP AT lt_mska INTO ls_mska.
      READ TABLE lt_stk ASSIGNING <s>
        WITH KEY kdpos = ls_mska-posnr matnr = ls_mska-matnr.
      IF sy-subrc <> 0.
        APPEND INITIAL LINE TO lt_stk ASSIGNING <s>.
        <s>-kdpos = ls_mska-posnr. <s>-matnr = ls_mska-matnr.
      ENDIF.
      <s>-stok_so = <s>-stok_so + ls_mska-kalab + ls_mska-kains + ls_mska-kaspe.
    ENDLOOP.

    TYPES: BEGIN OF ty_mard, matnr TYPE mard-matnr, labst TYPE mard-labst,
             insme TYPE mard-insme, speme TYPE mard-speme, END OF ty_mard.
    DATA: lt_mard TYPE STANDARD TABLE OF ty_mard WITH DEFAULT KEY,
          ls_mard TYPE ty_mard.
    IF lt_mkey IS NOT INITIAL.
      SELECT matnr labst insme speme FROM mard
        INTO CORRESPONDING FIELDS OF TABLE lt_mard
        FOR ALL ENTRIES IN lt_mkey
        WHERE matnr = lt_mkey-matnr
          AND ( labst > 0 OR insme > 0 OR speme > 0 ).
    ENDIF.

    " Stok bebas melekat ke MATERIAL, bukan item SO -> disalin ke tiap
    " (kdpos, matnr) yang memakai material itu, dan DILABELI terpisah di UI.
    DATA: lt_kd TYPE STANDARD TABLE OF afpo-kdpos WITH DEFAULT KEY.
    LOOP AT lt_ord INTO ls_ord2.
      APPEND ls_ord2-kdpos TO lt_kd.
    ENDLOOP.
    SORT lt_kd. DELETE ADJACENT DUPLICATES FROM lt_kd.

    LOOP AT lt_mard INTO ls_mard.
      LOOP AT lt_kd INTO DATA(lv_kd).
        READ TABLE lt_stk ASSIGNING <s>
          WITH KEY kdpos = lv_kd matnr = ls_mard-matnr.
        IF sy-subrc <> 0.
          APPEND INITIAL LINE TO lt_stk ASSIGNING <s>.
          <s>-kdpos = lv_kd. <s>-matnr = ls_mard-matnr.
        ENDIF.
        <s>-stok_free = <s>-stok_free
                      + ls_mard-labst + ls_mard-insme + ls_mard-speme.
      ENDLOOP.
    ENDLOOP.

    " --- 5. Rakit pohon ---
    et_node = assemble( it_ord = lt_ord it_res = lt_res
                        it_stk = lt_stk it_makt = lt_makt ).
  ENDMETHOD.
```

- [ ] **Step 2: Simpan skrip pemeriksa struktur**

Buat `scripts/check_bsp.py` dengan isi persis dari bagian "Cara Verifikasi di Proyek Ini" di atas.

- [ ] **Step 3: Minta user mengaktifkan class & menjalankan tes**

SE24 → aktifkan → `Ctrl+Shift+F10`. Hasil yang diharapkan: **kedelapan tes tetap LULUS** (tes hanya menyentuh `assemble( )`, jadi `build( )` tidak boleh mengubah hasilnya). Kalau ada syntax error, laporkan pesannya.

- [ ] **Step 4: Commit**

```bash
git add "ZBSP_CS_APP/classes/ZCL_CS_PEG.abap" scripts/check_bsp.py
git commit -m "feat(peg): build() selubung DB — order, RESB, MAKT, MSKA, MARD

RESB diambil tanpa filter XLOEK di WHERE (D48). Pengaman iv_maxord=800
menandai hasil terpotong lewat ev_trunc.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 6: `build( )` — ringkasan stasiun, work center, operasi per material

**Files:**
- Modify: `ZBSP_CS_APP/classes/ZCL_CS_PEG.abap` (method `build`)

**Interfaces:**
- Consumes: `et_node` dari Task 5
- Produces: `et_stn` (6 baris stasiun tetap: seq 1,2,3,4,5,9), `et_wc`, `et_opm` terisi. Dipakai Task 7 & 8.

- [ ] **Step 1: Tambahkan perakitan `et_stn` di ujung `build( )`**

```abap
    " --- 6. Ringkasan stasiun (kerangka TETAP, selalu 6 baris) ---
    DATA: ls_stn TYPE ty_stn.
    et_stn = VALUE tt_stn(
      ( seq = 1 no = '1' tx = 'Pembahanan'      kind = 'P' loc = 'Plant 1000' )
      ( seq = 2 no = ''  tx = 'Central Storage' kind = 'S' loc = '2000 / 2KCS' )
      ( seq = 3 no = '2' tx = 'Machining'       kind = 'P' loc = '2261, 2262' )
      ( seq = 4 no = '3' tx = 'Edge Banding'    kind = 'P' loc = '22E2, 22E3' )
      ( seq = 5 no = '4' tx = 'Sanding'         kind = 'P' loc = '229K' )
      ( seq = 9 no = ''  tx = 'Lainnya'         kind = 'S' loc = 'di luar jalur' ) ).

    " mat_cnt = COUNT material (bukan SUM qty — hindari campur UoM)
    " is_hold = ada simpul MISSING atau SHORT di stasiun itu
    " ratio_txt = angka bila SEMUA sisi masuk punya rasio sama;
    "             'bervariasi' bila berbeda. JANGAN merata-rata.
    FIELD-SYMBOLS: <st> TYPE ty_stn, <nd> TYPE ty_node.
    DATA: lt_seen_mat TYPE string_table,
          lv_seenkey  TYPE string,
          lv_ratio1   TYPE string,
          lv_varies   TYPE abap_bool.

    LOOP AT et_stn ASSIGNING <st>.
      CLEAR: lt_seen_mat, lv_ratio1, lv_varies.
      LOOP AT et_node ASSIGNING <nd> WHERE stn_seq = <st>-seq.

        lv_seenkey = <nd>-kdpos && '/' && <nd>-matnr.
        READ TABLE lt_seen_mat TRANSPORTING NO FIELDS
          WITH KEY table_line = lv_seenkey.
        IF sy-subrc <> 0.
          APPEND lv_seenkey TO lt_seen_mat.
          <st>-mat_cnt = <st>-mat_cnt + 1.
        ENDIF.

        IF <nd>-status = 'MISSING' OR <nd>-status = 'SHORT'.
          <st>-is_hold = abap_true.
        ENDIF.

        IF <nd>-ratio_txt IS NOT INITIAL AND <nd>-ratio_txt <> '—'.
          IF lv_ratio1 IS INITIAL.
            lv_ratio1 = <nd>-ratio_txt.
          ELSEIF lv_ratio1 <> <nd>-ratio_txt.
            lv_varies = abap_true.
          ENDIF.
        ENDIF.
      ENDLOOP.

      IF lv_varies = abap_true.
        <st>-ratio_txt = 'bervariasi'.
      ELSE.
        <st>-ratio_txt = lv_ratio1.
      ENDIF.
    ENDLOOP.
```

- [ ] **Step 2: Tambahkan perakitan `et_opm` & `et_wc`**

```abap
    " --- 7. Operasi per material (panel rincian) + beban work center ---
    "     Status operasi memakai rumus BAKU (Global Constraint), bukan varian.
    DATA: lt_opl TYPE STANDARD TABLE OF ty_ord WITH DEFAULT KEY.
    lt_opl = lt_ord.
    DELETE lt_opl WHERE aufpl IS INITIAL.

    IF lt_opl IS NOT INITIAL.

      TYPES: BEGIN OF ty_op, aufpl TYPE afvc-aufpl, aplzl TYPE afvc-aplzl,
               vornr TYPE afvc-vornr, arbid TYPE afvc-arbid, END OF ty_op.
      DATA: lt_op TYPE STANDARD TABLE OF ty_op WITH DEFAULT KEY, ls_op TYPE ty_op.
      SELECT aufpl aplzl vornr arbid FROM afvc
        INTO CORRESPONDING FIELDS OF TABLE lt_op
        FOR ALL ENTRIES IN lt_opl WHERE aufpl = lt_opl-aufpl.

      TYPES: BEGIN OF ty_vv, aufpl TYPE afvv-aufpl, aplzl TYPE afvv-aplzl,
               mgvrg TYPE afvv-mgvrg, END OF ty_vv.
      DATA: lt_vv TYPE STANDARD TABLE OF ty_vv WITH DEFAULT KEY, ls_vv TYPE ty_vv.
      IF lt_op IS NOT INITIAL.
        SELECT aufpl aplzl mgvrg FROM afvv INTO CORRESPONDING FIELDS OF TABLE lt_vv
          FOR ALL ENTRIES IN lt_op WHERE aufpl = lt_op-aufpl AND aplzl = lt_op-aplzl.
        SORT lt_vv BY aufpl aplzl.
      ENDIF.

      TYPES: BEGIN OF ty_ru, aufnr TYPE afru-aufnr, vornr TYPE afru-vornr,
               lmnga TYPE afru-lmnga, stokz TYPE afru-stokz,
               aueru TYPE afru-aueru, END OF ty_ru.
      DATA: lt_ru TYPE STANDARD TABLE OF ty_ru WITH DEFAULT KEY, ls_ru TYPE ty_ru.
      SELECT aufnr vornr lmnga stokz aueru FROM afru
        INTO CORRESPONDING FIELDS OF TABLE lt_ru
        FOR ALL ENTRIES IN lt_opl WHERE aufnr = lt_opl-aufnr.
      DELETE lt_ru WHERE stokz = 'X'.       " buang yg dibatalkan (qty ganda)

      TYPES: BEGIN OF ty_ruagg, aufnr TYPE afru-aufnr, vornr TYPE afru-vornr,
               lmnga TYPE p LENGTH 15 DECIMALS 3, aueru TYPE c LENGTH 1,
             END OF ty_ruagg.
      DATA: lt_ruagg TYPE STANDARD TABLE OF ty_ruagg WITH DEFAULT KEY,
            ls_ruagg TYPE ty_ruagg.
      FIELD-SYMBOLS <ra> TYPE ty_ruagg.
      LOOP AT lt_ru INTO ls_ru.
        READ TABLE lt_ruagg ASSIGNING <ra>
          WITH KEY aufnr = ls_ru-aufnr vornr = ls_ru-vornr.
        IF sy-subrc <> 0.
          APPEND INITIAL LINE TO lt_ruagg ASSIGNING <ra>.
          <ra>-aufnr = ls_ru-aufnr. <ra>-vornr = ls_ru-vornr.
        ENDIF.
        <ra>-lmnga = <ra>-lmnga + ls_ru-lmnga.
        IF ls_ru-aueru = 'X'.
          <ra>-aueru = 'X'.
        ENDIF.
      ENDLOOP.
      SORT lt_ruagg BY aufnr vornr.

      " master work center
      TYPES: BEGIN OF ty_arb, arbid TYPE afvc-arbid, END OF ty_arb.
      DATA: lt_arb TYPE STANDARD TABLE OF ty_arb WITH DEFAULT KEY, ls_arb TYPE ty_arb.
      LOOP AT lt_op INTO ls_op.
        IF ls_op-arbid IS NOT INITIAL.
          ls_arb-arbid = ls_op-arbid. APPEND ls_arb TO lt_arb.
        ENDIF.
      ENDLOOP.
      SORT lt_arb BY arbid. DELETE ADJACENT DUPLICATES FROM lt_arb COMPARING arbid.

      TYPES: BEGIN OF ty_crhd, objid TYPE crhd-objid, arbpl TYPE crhd-arbpl, END OF ty_crhd.
      DATA: lt_crhd TYPE STANDARD TABLE OF ty_crhd WITH DEFAULT KEY, ls_crhd TYPE ty_crhd.
      TYPES: BEGIN OF ty_crtx, objid TYPE crtx-objid, ktext TYPE crtx-ktext, END OF ty_crtx.
      DATA: lt_crtx TYPE STANDARD TABLE OF ty_crtx WITH DEFAULT KEY, ls_crtx TYPE ty_crtx.
      IF lt_arb IS NOT INITIAL.
        SELECT objid arbpl FROM crhd INTO CORRESPONDING FIELDS OF TABLE lt_crhd
          FOR ALL ENTRIES IN lt_arb WHERE objty = 'A' AND objid = lt_arb-arbid.
        SORT lt_crhd BY objid. DELETE ADJACENT DUPLICATES FROM lt_crhd COMPARING objid.
        SELECT objid ktext FROM crtx INTO CORRESPONDING FIELDS OF TABLE lt_crtx
          FOR ALL ENTRIES IN lt_arb
          WHERE objty = 'A' AND objid = lt_arb-arbid AND spras = sy-langu.
        SORT lt_crtx BY objid. DELETE ADJACENT DUPLICATES FROM lt_crtx COMPARING objid.
      ENDIF.

      " rakit et_opm + et_wc
      DATA: ls_opm TYPE ty_opm, ls_wc TYPE ty_wc, lv_seq TYPE i,
            lv_txt TYPE string, lv_in TYPE abap_bool, lv_mgvrg TYPE afvv-mgvrg.
      FIELD-SYMBOLS <w> TYPE ty_wc.

      LOOP AT lt_opl INTO ls_ord2.
        stn_of_order( EXPORTING iv_pwerk = ls_ord2-pwerk iv_dispo = ls_ord2-dispo
                      IMPORTING ev_seq = lv_seq ev_txt = lv_txt ev_in_scope = lv_in ).

        LOOP AT lt_op INTO ls_op WHERE aufpl = ls_ord2-aufpl.

          CLEAR lv_mgvrg.
          READ TABLE lt_vv INTO ls_vv
            WITH KEY aufpl = ls_op-aufpl aplzl = ls_op-aplzl BINARY SEARCH.
          IF sy-subrc = 0.
            lv_mgvrg = ls_vv-mgvrg.
          ENDIF.

          CLEAR ls_ruagg.
          READ TABLE lt_ruagg INTO ls_ruagg
            WITH KEY aufnr = ls_ord2-aufnr vornr = ls_op-vornr BINARY SEARCH.

          CLEAR ls_opm.
          ls_opm-stn_seq   = lv_seq.
          ls_opm-matnr     = ls_ord2-matnr.
          ls_opm-aufnr     = ls_ord2-aufnr.
          ls_opm-qty_order = ls_ord2-psmng.

          READ TABLE lt_makt INTO DATA(ls_mk) WITH KEY matnr = ls_ord2-matnr.
          IF sy-subrc = 0.
            ls_opm-maktx = ls_mk-maktx.
          ENDIF.
          READ TABLE lt_stk INTO DATA(ls_sk)
            WITH KEY kdpos = ls_ord2-kdpos matnr = ls_ord2-matnr.
          IF sy-subrc = 0.
            ls_opm-stok_so = ls_sk-stok_so.
          ENDIF.
          READ TABLE lt_crhd INTO ls_crhd WITH KEY objid = ls_op-arbid BINARY SEARCH.
          IF sy-subrc = 0.
            ls_opm-arbpl = ls_crhd-arbpl.
          ENDIF.

          " Rumus TIDAK ditulis ulang di sini — panggil sumber tunggalnya.
          ls_opm-op_status = op_status( iv_lmnga = ls_ruagg-lmnga
                                        iv_mgvrg = lv_mgvrg
                                        iv_aueru = ls_ruagg-aueru ).
          APPEND ls_opm TO et_opm.

          " beban work center
          IF ls_opm-arbpl IS NOT INITIAL.
            READ TABLE et_wc ASSIGNING <w>
              WITH KEY stn_seq = lv_seq arbpl = ls_opm-arbpl.
            IF sy-subrc <> 0.
              APPEND INITIAL LINE TO et_wc ASSIGNING <w>.
              <w>-stn_seq = lv_seq. <w>-arbpl = ls_opm-arbpl.
              READ TABLE lt_crtx INTO ls_crtx WITH KEY objid = ls_op-arbid BINARY SEARCH.
              IF sy-subrc = 0.
                <w>-ktext = ls_crtx-ktext.
              ENDIF.
            ENDIF.
            CASE ls_opm-op_status.
              WHEN 'confirmed'. <w>-cnt_conf   = <w>-cnt_conf   + 1.
              WHEN 'active'.    <w>-cnt_active = <w>-cnt_active + 1.
              WHEN OTHERS.      <w>-cnt_queue  = <w>-cnt_queue  + 1.
            ENDCASE.
          ENDIF.
        ENDLOOP.
      ENDLOOP.
    ENDIF.
```

- [ ] **Step 3: Minta user mengaktifkan & menjalankan tes**

Hasil yang diharapkan: kedelapan tes tetap **LULUS**.

- [ ] **Step 4: Commit**

```bash
git add "ZBSP_CS_APP/classes/ZCL_CS_PEG.abap"
git commit -m "feat(peg): ringkasan stasiun, beban work center, operasi per material

Rasio stasiun: angka bila seragam, 'bervariasi' bila tidak — tidak dirata-rata
karena rata-rata rasio tidak punya arti fisik.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 7: `routing_map.htm` — ringkasan kartu + tabel pohon

**Files:**
- Modify: `ZBSP_CS_APP/Page with Flow Logic/routing_map.htm`

**Interfaces:**
- Consumes: `zcl_cs_peg=>build( )` lengkap
- Produces: halaman yang menggambar `et_stn` sebagai kartu berpanah dan `et_node` sebagai tabel pohon. Panel rincian & kontrol JS menyusul di Task 8 & 9.

- [ ] **Step 1: Ganti blok ABAP halaman**

Buang seluruh query di blok ABAP `routing_map.htm` (order, RESB, AFVC/AFVV/AFRU, CRHD/CRTX, MSKA/MARD/T001L) dan gantikan dengan pemanggilan class. Sisakan: pembacaan input `so`/`item`, konversi ALPHA, nama buyer, dan cap waktu.

```abap
DATA: lt_node TYPE zcl_cs_peg=>tt_node,
      lt_stn  TYPE zcl_cs_peg=>tt_stn,
      lt_wc   TYPE zcl_cs_peg=>tt_wc,
      lt_opm  TYPE zcl_cs_peg=>tt_opm,
      lv_trunc TYPE abap_bool.

IF lv_so IS NOT INITIAL.
  zcl_cs_peg=>build( EXPORTING iv_vbeln = lv_so
                               iv_posnr = lv_pos
                     IMPORTING et_node  = lt_node
                               et_stn   = lt_stn
                               et_wc    = lt_wc
                               et_opm   = lt_opm
                               ev_trunc = lv_trunc ).
  IF lt_node IS INITIAL.
    lv_msg = 'Tidak ada order produksi untuk SO ini.'.
  ENDIF.
ENDIF.
```

- [ ] **Step 2: Gambar ringkasan kartu stasiun**

Ganti blok `<div class="chain">` yang ada sekarang. Kelas CSS `.stn`, `.stn-head`, `.stn-no`, `.stn-no-store`, `.stn-name`, `.stn-loc`, `.arrow` SUDAH ADA di file — pakai ulang, jangan bikin baru.

```html
<div class="chain">
<% DATA lv_arrow TYPE abap_bool.
   FIELD-SYMBOLS <st> TYPE zcl_cs_peg=>ty_stn.
   LOOP AT lt_stn ASSIGNING <st>.
     " stasiun 9 'Lainnya' hanya muncul bila memang terpakai
     IF <st>-seq = 9 AND <st>-mat_cnt = 0.
       CONTINUE.
     ENDIF.
     IF lv_arrow = abap_true. %>
  <span class="arrow"><svg viewBox="0 0 32 16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="2" y1="8" x2="24" y2="8"/><polyline points="19 3 25 8 19 13"/></svg></span>
<%   ENDIF.
     lv_arrow = abap_true. %>
  <div class="stn<% IF <st>-kind = 'S'. %> is-store<% ENDIF. %><% IF <st>-is_hold = abap_true. %> is-hold<% ENDIF. %>"
       onclick="stnPanel(<%= <st>-seq %>)">
    <div class="stn-head">
      <% IF <st>-no IS NOT INITIAL. %>
      <span class="stn-no"><%= <st>-no %></span>
      <% ELSE. %>
      <span class="stn-no stn-no-store"></span>
      <% ENDIF. %>
      <span class="stn-name"><%= <st>-tx %></span>
    </div>
    <div class="stn-loc"><%= <st>-loc %></div>
    <div class="stn-qty"><%= <st>-mat_cnt %></div>
    <div class="stn-cap">material</div>
    <% IF <st>-ratio_txt IS NOT INITIAL. %>
    <div class="stn-ratio">gabung <%= <st>-ratio_txt %></div>
    <% ENDIF. %>
  </div>
<% ENDLOOP. %>
</div>
```

`onclick="stnPanel(...)"` di atas merujuk fungsi yang baru dibuat di Task 8.
Supaya halaman tidak melempar error JS di antara dua task, tambahkan stub ini
sekarang di blok `<script>`; Task 8 menggantinya dengan versi sungguhan:

```javascript
/* stub — diganti versi sungguhan di Task 8 */
function stnPanel(seq){ }
```

Tambahkan CSS baru (kelas `.stn-qty`, `.stn-cap`, `.stn-ratio`, `.is-hold` belum ada):

```css
    .stn-qty{ font-size:19px; font-weight:700; margin-top:5px; letter-spacing:-.02em; }
    .stn-cap{ font-size:9.5px; color:var(--faint); }
    .stn-ratio{ font-family:var(--mono); font-size:9px; color:var(--sub); margin-top:2px; }
    .stn.is-hold{ border-color:rgba(220,38,38,.45); background-color:rgba(220,38,38,.07); }
    .stn{ cursor:pointer; }
```

- [ ] **Step 3: Gambar tabel pohon**

```html
<div class="table-wrap">
  <table class="tree">
    <thead>
      <tr>
        <th>Komponen</th><th>Stasiun</th><th>Order</th>
        <th class="num">Butuh</th><th class="num">Dipakai</th><th class="num">Stok</th>
        <th>Status</th>
      </tr>
    </thead>
    <tbody id="treebody">
<% FIELD-SYMBOLS <nd> TYPE zcl_cs_peg=>ty_node.
   DATA: lv_pad TYPE i, lv_stat_tx TYPE string, lv_stat_cls TYPE string.
   LOOP AT lt_node ASSIGNING <nd>.
     lv_pad = <nd>-level * 22.
     CASE <nd>-status.
       WHEN 'USED'.    lv_stat_cls = 'used'.  lv_stat_tx = 'SUDAH DIPAKAI'.
       WHEN 'PARTIAL'. lv_stat_cls = 'part'.  lv_stat_tx = 'SEBAGIAN'.
       WHEN 'READY'.   lv_stat_cls = 'ready'. lv_stat_tx = 'SIAP DIPAKAI'.
       WHEN 'SHORT'.   lv_stat_cls = 'short'. lv_stat_tx = 'KURANG'.
       WHEN 'MISSING'. lv_stat_cls = 'miss'.  lv_stat_tx = 'BELUM ADA'.
       WHEN OTHERS.    lv_stat_cls = ''.      lv_stat_tx = ''.
     ENDCASE. %>
      <tr data-key="<%= <nd>-node_key %>" data-parent="<%= <nd>-parent_key %>"
          data-stn="<%= <nd>-stn_seq %>" data-status="<%= <nd>-status %>"
          data-scope="<%= <nd>-in_scope %>">
        <td>
          <span style="display:inline-block; width:<%= lv_pad %>px"></span>
          <% IF <nd>-has_child = abap_true. %>
          <span class="car" onclick="treeToggle(this)">&#9662;</span>
          <% ELSE. %>
          <span class="car"></span>
          <% ENDIF. %>
          <span class="mat"><%= <nd>-matnr %></span>
          <span class="mtx"><%= cl_http_utility=>escape_html( <nd>-maktx ) %></span>
          <% IF <nd>-ratio_txt IS NOT INITIAL. %>
          <span class="rat"><%= <nd>-ratio_txt %></span>
          <% ENDIF. %>
          <% IF <nd>-dup_of IS NOT INITIAL. %>
          <span class="tagdup" title="komponen ini juga dipakai cabang lain — stoknya sama, jangan dihitung dua kali">juga di cabang lain</span>
          <% ENDIF. %>
          <% IF <nd>-note IS NOT INITIAL. %>
          <span class="tagnote"><%= <nd>-note %></span>
          <% ENDIF. %>
        </td>
        <td><%= <nd>-stn_txt %><% IF <nd>-in_scope = abap_false. %> <span class="oos">luar scope</span><% ENDIF. %></td>
        <td class="mono dim"><%= <nd>-aufnr %></td>
        <td class="num"><%= <nd>-bdmng %></td>
        <td class="num"><%= <nd>-enmng %></td>
        <td class="num"><%= <nd>-stok_so %></td>
        <td><% IF lv_stat_tx IS NOT INITIAL. %><span class="pill <%= lv_stat_cls %>"><%= lv_stat_tx %></span><% ENDIF. %></td>
      </tr>
<% ENDLOOP. %>
    </tbody>
  </table>
</div>
```

CSS baru:

```css
    .table-wrap{ overflow-x:auto; }
    .tree{ width:100%; border-collapse:collapse; font-size:11.5px; }
    .tree th{ text-align:left; font-size:8.5px; letter-spacing:.09em; text-transform:uppercase;
              color:var(--faint); padding:6px 7px; border-bottom:1px solid var(--border); }
    .tree td{ padding:4px 7px; border-bottom:1px solid var(--border); }
    .tree td.num{ text-align:right; font-family:var(--mono); }
    .tree tbody tr:hover{ background-color:rgba(37,99,235,0.04); }
    .car{ display:inline-block; width:12px; color:var(--faint); cursor:pointer; }
    .mat{ font-family:var(--mono); font-weight:700; }
    .mtx{ color:var(--sub); margin-left:6px; }
    .rat{ font-family:var(--mono); font-size:9.5px; color:var(--faint); margin-left:6px; }
    .tagdup,.tagnote{ font-size:8.5px; border-radius:3px; padding:0 5px; margin-left:6px;
                      background-color:var(--surface2); color:var(--sub); }
    .oos{ font-size:8.5px; border:1px dashed var(--border2); border-radius:3px;
          padding:0 4px; color:var(--faint); }
    .pill{ display:inline-block; border-radius:4px; padding:1px 6px; font-size:9.5px; font-weight:700; }
    .pill.used{ background-color:rgba(107,123,143,.18); color:var(--slate); }
    .pill.part{ background-color:rgba(214,154,76,.22); color:#B57A2C; }
    .pill.ready{ background-color:rgba(22,163,74,.16); color:var(--green); }
    .pill.short{ background-color:rgba(220,38,38,.14); color:var(--red); }
    .pill.miss{ background-color:rgba(220,38,38,.28); color:var(--red); }
    .dim{ color:var(--faint); }
    .mono{ font-family:var(--mono); }
```

Tambahkan juga peringatan `ev_trunc` tepat di atas tabel:

```html
<% IF lv_trunc = abap_true. %>
<div class="warn">Hasil dipotong pada batas 800 order. Pohon mungkin tidak lengkap.</div>
<% ENDIF. %>
```
```css
    .warn{ font-size:11px; color:#9A6B25; background-color:rgba(214,154,76,.14);
           border:1px solid rgba(214,154,76,.4); border-radius:8px;
           padding:7px 11px; margin-bottom:10px; }
```

- [ ] **Step 4: Jalankan pemeriksaan struktur**

```bash
python scripts/check_bsp.py "ZBSP_CS_APP/Page with Flow Logic/routing_map.htm"
```
Semua baris harus `OK`. Kalau `<div vs </div>` tidak seimbang, cari blok `<% IF %>` yang membuka div tanpa menutupnya di cabang lain.

- [ ] **Step 5: Minta user mengaktifkan & menjalankan dengan SO 10446**

Yang dicek: halaman tampil tanpa dump; ada baris akar; jumlah baris pohon masuk akal (SO 10446 punya 35 material, jadi ratusan baris berarti ada duplikasi cabang yang tidak wajar — laporkan); kolom Butuh/Dipakai/Stok terisi angka, bukan kosong semua.

- [ ] **Step 6: Commit**

```bash
git add "ZBSP_CS_APP/Page with Flow Logic/routing_map.htm"
git commit -m "feat(routing_map): ringkasan stasiun + tabel pohon dari ZCL_CS_PEG

Seluruh query pegging/stok pindah ke class; halaman tinggal menyajikan.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 8: Panel rincian per stasiun

**Files:**
- Modify: `ZBSP_CS_APP/Page with Flow Logic/routing_map.htm`

**Interfaces:**
- Consumes: `lt_opm`, `lt_wc`, `lt_node`, `lt_stn`
- Produces: fungsi JS `stnPanel(seq)` yang membuka/menutup panel; panel di-*render* di muka dalam keadaan tersembunyi (tanpa AJAX).

- [ ] **Step 1: Render panel untuk tiap stasiun, tersembunyi**

Sisipkan tepat di bawah `</div>` penutup `.chain`:

```html
<% LOOP AT lt_stn ASSIGNING <st>.
     IF <st>-seq = 9 AND <st>-mat_cnt = 0.
       CONTINUE.
     ENDIF. %>
<div class="spanel" id="sp-<%= <st>-seq %>" style="display:none;">
  <div class="spanel-head">
    <% IF <st>-no IS NOT INITIAL. %><span class="stn-no"><%= <st>-no %></span>
    <% ELSE. %><span class="stn-no stn-no-store"></span><% ENDIF. %>
    <span class="stn-name"><%= <st>-tx %></span>
    <span class="dim mono" style="font-size:10px"><%= <st>-loc %></span>
    <span class="spanel-x" onclick="stnPanel(<%= <st>-seq %>)">&times;</span>
  </div>

<% IF <st>-kind = 'P'. %>
  <%-- STASIUN PROSES: material dikelompokkan antre / diproses / selesai --%>
  <% DATA: lv_grp TYPE string, lv_grp_lbl TYPE string, lv_ada TYPE abap_bool.
     FIELD-SYMBOLS <om> TYPE zcl_cs_peg=>ty_opm.
     DO 3 TIMES.
       CASE sy-index.
         WHEN 1. lv_grp = 'queue'.     lv_grp_lbl = 'Antre'.
         WHEN 2. lv_grp = 'active'.    lv_grp_lbl = 'Diproses'.
         WHEN 3. lv_grp = 'confirmed'. lv_grp_lbl = 'Selesai'.
       ENDCASE.
       CLEAR lv_ada.
       LOOP AT lt_opm TRANSPORTING NO FIELDS
         WHERE stn_seq = <st>-seq AND op_status = lv_grp.
         lv_ada = abap_true.
         EXIT.
       ENDLOOP.
       IF lv_ada = abap_false.
         CONTINUE.
       ENDIF. %>
  <div class="sgrp sgrp-<%= lv_grp %>">
    <div class="sgrp-l"><%= lv_grp_lbl %></div>
    <table class="stab">
      <tr><th>Material</th><th>Work center</th><th class="num">Qty order</th><th class="num">Real stok</th></tr>
<%     LOOP AT lt_opm ASSIGNING <om>
         WHERE stn_seq = <st>-seq AND op_status = lv_grp. %>
      <tr>
        <td><span class="mat"><%= <om>-matnr %></span>
            <div class="dim"><%= cl_http_utility=>escape_html( <om>-maktx ) %></div></td>
        <td class="mono"><%= <om>-arbpl %></td>
        <td class="num"><%= <om>-qty_order %></td>
        <td class="num"><%= <om>-stok_so %></td>
      </tr>
<%     ENDLOOP. %>
    </table>
  </div>
<%   ENDDO. %>

  <div class="sgrp">
    <div class="sgrp-l dim">Work center di stasiun ini</div>
    <div class="wcs">
<% FIELD-SYMBOLS <w> TYPE zcl_cs_peg=>ty_wc.
   DATA lv_wcls TYPE string.
   LOOP AT lt_wc ASSIGNING <w> WHERE stn_seq = <st>-seq.
     IF <w>-cnt_queue >= 13.
       lv_wcls = 'hot'.
     ELSEIF <w>-cnt_queue >= 6.
       lv_wcls = 'warm'.
     ELSE.
       lv_wcls = 'cool'.
     ENDIF. %>
      <div class="wc <%= lv_wcls %>" title="<%= cl_http_utility=>escape_html( <w>-ktext ) %>">
        <b><%= <w>-arbpl %></b> &middot; antre <%= <w>-cnt_queue %> &middot; proses <%= <w>-cnt_active %> &middot; selesai <%= <w>-cnt_conf %>
      </div>
<% ENDLOOP. %>
    </div>
  </div>

<% ELSE. %>
  <%-- TITIK STOK: material yang ada + proses selanjutnya dari pohon --%>
  <table class="stab">
    <tr><th>Material</th><th class="num">Real stok</th><th>Proses selanjutnya</th></tr>
<% DATA: lv_nx TYPE string, lv_nxq TYPE string.
   FIELD-SYMBOLS <n2> TYPE zcl_cs_peg=>ty_node.
   LOOP AT lt_node ASSIGNING <nd> WHERE stok_so > 0 OR stok_free > 0.
     CLEAR: lv_nx, lv_nxq.
     IF <nd>-parent_key IS NOT INITIAL.
       READ TABLE lt_node ASSIGNING <n2> WITH KEY node_key = <nd>-parent_key.
       IF sy-subrc = 0.
         lv_nx  = <n2>-stn_txt.
         lv_nxq = <n2>-aufnr && ' · butuh ' && |{ <nd>-bdmng DECIMALS = 0 }|.
       ENDIF.
     ELSE.
       lv_nx = 'tidak dipakai order mana pun'.
     ENDIF. %>
    <tr>
      <td><span class="mat"><%= <nd>-matnr %></span>
          <div class="dim"><%= cl_http_utility=>escape_html( <nd>-maktx ) %></div></td>
      <td class="num"><%= <nd>-stok_so %></td>
      <td><%= lv_nx %><div class="dim mono"><%= lv_nxq %></div></td>
    </tr>
<% ENDLOOP. %>
  </table>
<% ENDIF. %>
</div>
<% ENDLOOP. %>
```

CSS baru:

```css
    .spanel{ background-color:var(--surface); border:1px solid var(--border);
             border-radius:var(--radius-lg); padding:12px 14px; margin:10px 0 14px;
             box-shadow:var(--shadow); }
    .spanel-head{ display:flex; align-items:center; gap:8px; margin-bottom:10px;
                  padding-bottom:8px; border-bottom:1px solid var(--border); }
    .spanel-x{ margin-left:auto; cursor:pointer; color:var(--faint); font-size:15px; }
    .sgrp{ margin-bottom:11px; }
    .sgrp-l{ font-size:8.5px; letter-spacing:.1em; text-transform:uppercase;
             font-weight:700; margin-bottom:4px; color:var(--sub); }
    .sgrp-queue .sgrp-l{ color:var(--slate); }
    .sgrp-active .sgrp-l{ color:var(--blue); }
    .sgrp-confirmed .sgrp-l{ color:var(--green); }
    .stab{ width:100%; border-collapse:collapse; font-size:11px; }
    .stab th{ text-align:left; font-size:8px; letter-spacing:.08em; text-transform:uppercase;
              color:var(--faint); padding:3px 6px; border-bottom:1px solid var(--border); }
    .stab td{ padding:3px 6px; border-bottom:1px solid var(--border); }
    .stab td.num, .stab th.num{ text-align:right; font-family:var(--mono); }
    .wcs{ display:flex; flex-wrap:wrap; gap:5px; }
    .wc{ border:1px solid var(--border); border-radius:6px; padding:3px 7px;
         font-family:var(--mono); font-size:9.5px; }
    .wc.hot{ border-color:rgba(220,38,38,.5); background-color:rgba(220,38,38,.08); }
    .wc.warm{ border-color:rgba(214,154,76,.5); background-color:rgba(214,154,76,.10); }
    .wc.cool{ border-color:rgba(22,163,74,.4); background-color:rgba(22,163,74,.07); }
```

- [ ] **Step 2: Tambahkan JS pembuka panel**

```javascript
/* Panel stasiun: semua panel sudah dirender tersembunyi, JS hanya
   membuka/menutup. Membuka satu panel menutup yang lain. */
function stnPanel(seq){
  var all = document.getElementsByClassName('spanel');
  var target = document.getElementById('sp-' + seq);
  var wasOpen = target && target.style.display !== 'none';
  for (var i = 0; i < all.length; i++) { all[i].style.display = 'none'; }
  if (target && !wasOpen) { target.style.display = ''; }
}
```

- [ ] **Step 3: Jalankan pemeriksaan struktur**

```bash
python scripts/check_bsp.py "ZBSP_CS_APP/Page with Flow Logic/routing_map.htm"
```
Semua `OK`.

- [ ] **Step 4: Minta user mengaktifkan & menguji dengan SO 10446**

Yang dicek: klik tiap kartu membuka panelnya; kartu Central Storage menampilkan kolom "proses selanjutnya" berisi stasiun + order, bukan kosong; jumlah operasi di panel cocok dengan angka `diag_routing.htm` (41 operasi, 26 confirmed / 5 active / 10 queue) **untuk SO 10446** — kalau meleset jauh, laporkan angkanya.

- [ ] **Step 5: Commit**

```bash
git add "ZBSP_CS_APP/Page with Flow Logic/routing_map.htm"
git commit -m "feat(routing_map): panel rincian per stasiun

Stasiun proses: material dikelompokkan antre/diproses/selesai + beban WC.
Central Storage: material berstok + proses selanjutnya dari pohon pegging.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 9: Kontrol hide/unhide + lipat cabang

**Files:**
- Modify: `ZBSP_CS_APP/Page with Flow Logic/routing_map.htm`

**Interfaces:**
- Consumes: atribut `data-key`, `data-parent`, `data-status`, `data-scope` pada `<tr>` dari Task 7
- Produces: fungsi JS `treeFilter( )`, `treeToggle( )`, `treeExpandAll( )` — tidak dipakai task lain.

- [ ] **Step 1: Tambahkan baris chip kontrol di atas tabel**

```html
<div class="ctl" id="ctl">
  <button type="button" class="chip on" data-f="all"   onclick="treeFilter(this)">Semua</button>
  <button type="button" class="chip"    data-f="hold"  onclick="treeFilter(this)">Hanya penahan</button>
  <button type="button" class="chip"    data-f="unused" onclick="treeFilter(this)">Sembunyikan yang sudah dipakai</button>
  <button type="button" class="chip"    data-f="scope" onclick="treeFilter(this)">Sembunyikan di luar scope DISPO</button>
  <button type="button" class="chip"    onclick="treeExpandAll(false)">Lipat semua</button>
  <button type="button" class="chip"    onclick="treeExpandAll(true)">Buka semua</button>
</div>
```

```css
    .ctl{ display:flex; flex-wrap:wrap; gap:6px; margin:12px 0 8px; }
    .chip{ font-family:inherit; font-size:10.5px; color:var(--sub); background-color:transparent;
           border:1px solid var(--border); border-radius:6px; padding:3px 10px; cursor:pointer; }
    .chip:hover{ background-color:var(--surface2); }
    .chip.on{ background-color:var(--amber); color:#fff; border-color:var(--amber); font-weight:600; }
```

- [ ] **Step 2: Tambahkan JS**

```javascript
/* Kontrol pohon — seluruhnya client-side, tidak memanggil server.
   Baris membawa data-key / data-parent / data-status / data-scope.
   Aturan: baris disembunyikan bila (a) tidak lolos filter, ATAU
   (b) salah satu leluhurnya sedang dilipat. */
var treeMode = 'all';
var collapsed = {};

function treeRowPass(tr){
  var st = tr.getAttribute('data-status') || '';
  if (treeMode === 'hold')   { return st === 'MISSING' || st === 'SHORT'; }
  if (treeMode === 'unused') { return st !== 'USED'; }
  if (treeMode === 'scope')  { return tr.getAttribute('data-scope') === 'X'; }
  return true;
}

function treeHiddenByParent(tr, rows){
  var p = tr.getAttribute('data-parent');
  while (p) {
    if (collapsed[p]) { return true; }
    var found = null;
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].getAttribute('data-key') === p) { found = rows[i]; break; }
    }
    if (!found) { return false; }
    p = found.getAttribute('data-parent');
  }
  return false;
}

function treeApply(){
  var rows = document.getElementById('treebody').getElementsByTagName('tr');
  for (var i = 0; i < rows.length; i++) {
    var show = treeRowPass(rows[i]) && !treeHiddenByParent(rows[i], rows);
    rows[i].style.display = show ? '' : 'none';
  }
}

function treeFilter(btn){
  var b = document.getElementById('ctl').getElementsByTagName('button');
  for (var i = 0; i < b.length; i++) {
    if (b[i].getAttribute('data-f')) { b[i].className = 'chip'; }
  }
  btn.className = 'chip on';
  treeMode = btn.getAttribute('data-f');
  treeApply();
}

function treeToggle(caret){
  var tr = caret.parentNode.parentNode;
  var key = tr.getAttribute('data-key');
  collapsed[key] = !collapsed[key];
  caret.innerHTML = collapsed[key] ? '&#9656;' : '&#9662;';
  treeApply();
}

function treeExpandAll(open){
  var rows = document.getElementById('treebody').getElementsByTagName('tr');
  collapsed = {};
  for (var i = 0; i < rows.length; i++) {
    var c = rows[i].getElementsByClassName('car')[0];
    if (!c || !c.innerHTML) { continue; }
    if (!open) { collapsed[rows[i].getAttribute('data-key')] = true; }
    c.innerHTML = open ? '&#9662;' : '&#9656;';
  }
  treeApply();
}
```

**Catatan penting:** `data-scope` dirender dari `abap_bool`, yang menghasilkan `X` untuk true dan **string kosong** untuk false — karena itu perbandingannya `=== 'X'`, bukan `=== 'true'`.

- [ ] **Step 3: Jalankan pemeriksaan struktur**

```bash
python scripts/check_bsp.py "ZBSP_CS_APP/Page with Flow Logic/routing_map.htm"
```
Semua `OK`.

- [ ] **Step 4: Minta user mengaktifkan & menguji perilaku kontrol**

Yang dicek satu per satu dengan SO 10446:
1. "Hanya penahan" → hanya baris `BELUM ADA` / `KURANG` yang tampil
2. "Sembunyikan yang sudah dipakai" → baris `SUDAH DIPAKAI` hilang
3. "Sembunyikan di luar scope DISPO" → baris bertanda "luar scope" hilang
4. Klik caret pada baris berlevel 0 → seluruh anak-cucunya hilang; klik lagi → muncul
5. "Lipat semua" → hanya baris akar tersisa

- [ ] **Step 5: Commit**

```bash
git add "ZBSP_CS_APP/Page with Flow Logic/routing_map.htm"
git commit -m "feat(routing_map): kontrol filter & lipat cabang pohon

Seluruhnya client-side. Baris tersembunyi bila tidak lolos filter atau
salah satu leluhurnya sedang dilipat.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 10: Pembersihan & dokumentasi

**Files:**
- Modify: `ZBSP_CS_APP/Page with Flow Logic/routing_map.htm` (komentar header)
- Modify: `ZBSP_CS_APP/classes/ZCL_CS_PEG.abap` (komentar deployment)

**Interfaces:**
- Consumes: seluruh hasil Task 1–9
- Produces: —

- [ ] **Step 1: Perbarui komentar header `routing_map.htm`**

Ganti bagian "RANTAI STASIUN" dengan:

```
*& ===== PETA = POHON KONVERGENSI =====
*& Material MENYUSUT lewat penggabungan (mis. 20 -> 5:1 -> 4 -> 2:1 -> 2).
*& Karena itu bentuk datanya POHON, bukan rantai. Pohon dibangun dari pegging
*& RESB oleh ZCL_CS_PEG; halaman ini HANYA menyajikan.
*&
*& ⚠️ SELURUH logika ada di ZCL_CS_PEG. Jangan menambah query di halaman ini —
*&    kalau butuh data baru, tambahkan di class supaya ikut teruji ABAP Unit.
*& ⚠️ ZCL_CS_PEG HARUS aktif di SE24 SEBELUM halaman ini diaktifkan.
*&
*& Ringkasan atas = kartu stasiun berpanah (bisa diklik -> panel rincian).
*& Tampilan utama = tabel pohon; kontrol filter & lipat cabang client-side.
*&
*& ⚠️ Rantai berhenti di Sanding: tahap sesudahnya (Assembling/Finishing/
*&    Packing) tidak punya DISPO maupun SLoc sendiri. Untuk memunculkannya
*&    perlu pemetaan cost center work center (map_sec) — lihat diag_routing.htm
*&    bagian G & I.
*& ⚠️ Barang beli (komponen tanpa order pembuat) TIDAK masuk pohon. Kalau yang
*&    menahan produksi adalah lem/sekrup/engsel, halaman ini tidak melihatnya.
*&    Daun yang semua komponennya barang beli ditandai "tidak ada komponen
*&    produksi" sebagai peredam.
```

- [ ] **Step 2: Hapus kode mati**

Cari kelas CSS dan variabel ABAP yang tidak lagi dipakai setelah perombakan:

```bash
python - <<'PY'
import re
s = open(r'ZBSP_CS_APP/Page with Flow Logic/routing_map.htm', encoding='utf-8').read()
body = s[s.index('</style>'):]
for m in re.finditer(r'^\s*\.([a-z][\w-]*)', s[:s.index('</style>')], re.M):
    c = m.group(1)
    if not re.search(r'class="[^"]*\b' + re.escape(c) + r'\b', body) and (c + '<%') not in body:
        print('CSS mungkin mati:', c)
PY
```

Periksa tiap kandidat secara manual sebelum menghapus — kelas yang dirangkai lewat scriptlet (`class="stn<% IF ... %>"`) bisa muncul sebagai false positive.

- [ ] **Step 3: Jalankan pemeriksaan struktur terakhir**

```bash
python scripts/check_bsp.py "ZBSP_CS_APP/Page with Flow Logic/routing_map.htm"
```

- [ ] **Step 4: Minta user menjalankan verifikasi penutup**

1. SE24 → `ZCL_CS_PEG` → `Ctrl+Shift+F10` → **kedelapan tes lulus**
2. Halaman dengan **SO 10446**, item kosong → pohon tampil, tidak ada dump
3. Halaman dengan **SO 10446 item 000010** → hanya item itu
4. Halaman dengan SO yang tidak ada → pesan kosong, bukan dump
5. Ukur waktu muat. Kalau >5 detik, catat angkanya — pemindahan ke cache/AJAX (pola `dash_cs.htm`) jadi pekerjaan lanjutan, bukan bagian rencana ini

- [ ] **Step 5: Commit**

```bash
git add "ZBSP_CS_APP/Page with Flow Logic/routing_map.htm" "ZBSP_CS_APP/classes/ZCL_CS_PEG.abap"
git commit -m "docs(routing_map): perbarui header + bersihkan kode mati

Catat batas yang diketahui: rantai berhenti di Sanding, barang beli tidak
masuk pohon.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 11: `index2.htm` memakai `op_status( )` (hapus duplikasi rumus)

Ditambahkan atas keputusan user saat pre-flight: rumus status operasi tidak
boleh punya dua salinan hidup.

**Files:**
- Modify: `ZBSP_CS_APP/Page with Flow Logic/index2.htm`

**Interfaces:**
- Consumes: `zcl_cs_peg=>op_status( iv_lmnga, iv_mgvrg, iv_aueru )` dari Task 1
- Produces: —

- [ ] **Step 1: Ganti percabangan inline dengan pemanggilan class**

Di `index2.htm`, blok "DATA LIVE 2" memuat percabangan status operasi yang
disalin dari `diag_routing.htm`. Cari blok ini:

```abap
      IF ls_ruagg-aueru = 'X'
         OR ( lv_mgvrg > 0 AND ls_ruagg-lmnga >= lv_mgvrg ).
        lv_op_conf = lv_op_conf + 1.
      ELSEIF ls_ruagg-lmnga > 0.
        lv_op_act = lv_op_act + 1.
      ELSE.
        lv_op_queue = lv_op_queue + 1.
      ENDIF.
```

Ganti dengan:

```abap
      " Rumus status TIDAK ditulis ulang di sini — sumber tunggalnya
      " ZCL_CS_PEG=>op_status( ). Kalau rumus berubah, cukup ubah di sana.
      CASE zcl_cs_peg=>op_status( iv_lmnga = ls_ruagg-lmnga
                                  iv_mgvrg = lv_mgvrg
                                  iv_aueru = ls_ruagg-aueru ).
        WHEN 'confirmed'. lv_op_conf  = lv_op_conf  + 1.
        WHEN 'active'.    lv_op_act   = lv_op_act   + 1.
        WHEN OTHERS.      lv_op_queue = lv_op_queue + 1.
      ENDCASE.
```

- [ ] **Step 2: Perbarui komentar header `index2.htm`**

Blok komentar di header masih menyatakan rumus "disalin PERSIS dari
diag_routing.htm:355-365 ... kalau rumus berubah, ubah di KETIGA file".
Itu tidak berlaku lagi. Ganti kalimat tersebut dengan:

```
*&   RUMUS STATUS OPERASI: TIDAK ada di file ini. Sumber tunggalnya
*&   ZCL_CS_PEG=>op_status( ) — diuji ABAP Unit di sana. Jangan menyalin
*&   percabangannya kembali ke sini.
*&   ⚠️ ZCL_CS_PEG HARUS aktif di SE24 SEBELUM halaman ini diaktifkan.
```

- [ ] **Step 3: Jalankan pemeriksaan struktur**

```bash
python scripts/check_bsp.py "ZBSP_CS_APP/Page with Flow Logic/index2.htm"
```
Semua baris harus `OK`.

- [ ] **Step 4: Minta user mengaktifkan & membandingkan angka**

Buka `index2.htm` dan catat kartu **Confirmed** (persen + "X / Y op").
Angkanya harus **sama persis** dengan sebelum perubahan — ini refactor murni,
bukan perubahan perilaku. Kalau berubah, berarti percabangan lama dan
`op_status( )` tidak setara; laporkan kedua angkanya.

- [ ] **Step 5: Commit**

```bash
git add "ZBSP_CS_APP/Page with Flow Logic/index2.htm"
git commit -m "refactor(index2): pakai ZCL_CS_PEG=>op_status, hapus duplikasi rumus

Rumus status operasi kini punya satu salinan hidup yang teruji ABAP Unit.
diag_routing.htm dibiarkan apa adanya — halaman diagnosa sekali pakai.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```
