*&---------------------------------------------------------------------*
*& Report  ZTEST_SO_TRACE_RECURSIVE
*&---------------------------------------------------------------------*
*& Tujuan   : Menelusuri "kesehatan" sebuah Sales Order (SO) dengan cara
*&            menelusuri rantai Production Order + komponen BOM-nya secara
*&            REKURSIF, meniru pola kerja manual di tcode:
*&              - COOIS  (cari production order per SO / SO item)
*&              - CS03   (explode BOM 1 level)
*&              - MB52   (cek stok unrestricted per plant)
*&
*& Sifat    : PURE READ-ONLY. Tidak ada INSERT / UPDATE / DELETE / MODIFY
*&            ke tabel database manapun. Aman dijalankan di sistem apapun.
*&
*&---------------------------------------------------------------------*
*& RIWAYAT OPTIMASI
*&---------------------------------------------------------------------*
*& VERSI 1 (baseline)            : 27,2 detik. 147x BOM explosion, 188x cari order.
*& VERSI 2 -- OPTIMASI CACHE     :  8,28 detik. Order-level memoization +
*&                                  BOM-explosion cache.
*& VERSI 3 -- OPTIMASI PRELOAD   : versi ini.
*&
*& Yang ditambahkan di VERSI 3 (cari tanda "-- OPTIMASI PRELOAD --"):
*&   Method GET_ORDERS dulu query ke database SETIAP KALI sebuah komponen BOM
*&   ditemukan, untuk bertanya "material ini punya production order sendiri?".
*&   Hasilnya: 42 query kecil-kecil ke AFPO/AFKO/AUFK untuk 1 SO saja.
*&
*&   Padahal SEMUA order yang mungkin relevan punya scope yang SAMA: difilter
*&   AFPO-KDAUF + AFPO-KDPOS, tanpa filter material. Artinya seluruh order itu
*&   bisa ditarik SEKALI SAJA di awal, sebelum rekursi mulai.
*&
*&   Jadi sekarang:
*&     - PRELOAD_ALL_ORDERS() -> 1x query besar di awal, hasilnya disimpan di
*&       MT_ALL_ORD (sorted table, key MATNR).
*&     - GET_ORDERS()         -> TIDAK query database lagi sama sekali. Cuma
*&       lookup ke MT_ALL_ORD di memory.
*&
*& LOGIKA BISNIS TIDAK BERUBAH SAMA SEKALI. Query yang dipakai PRELOAD identik
*& dengan query GET_ORDERS versi lama (saat IV_MATNR kosong), termasuk cara
*& ambil system status (JEST/TJ02T) dan fallback MRP controller (MARC).
*& Yang berubah cuma CARA mengambil datanya, bukan DATA yang diambil.
*&---------------------------------------------------------------------*
*&
*& !!! PENTING !!!
*& Semua baris yang diberi tanda "ASUMSI:" adalah tebakan nama tabel/field/
*& FM berdasarkan SAP standar. WAJIB diverifikasi di sistem Anda sendiri
*& lewat SE11 (tabel) / SE37 (function module).
*& Rangkuman lengkap semua ASUMSI ada di TUTORIAL_ZTEST_SO_TRACE.md
*&---------------------------------------------------------------------*
REPORT ztest_so_trace_recursive LINE-SIZE 250 NO STANDARD PAGE HEADING.

*&---------------------------------------------------------------------*
*& TYPES
*&---------------------------------------------------------------------*

* Satu baris hasil pencarian production order (hasil "COOIS-equivalent")
TYPES: BEGIN OF ty_ord,
         aufnr TYPE afpo-aufnr,   " Nomor production order
         posnr TYPE afpo-posnr,   " Item order (biasanya 0001)
         matnr TYPE afpo-matnr,   " Material yang diproduksi order ini
         dwerk TYPE afpo-dwerk,   " Plant order item
         psmng TYPE afpo-psmng,   " ASUMSI: Target Qty  (order item quantity)
         wemng TYPE afpo-wemng,   " ASUMSI: Delivered Qty (qty yang sudah GR)
         meins TYPE afpo-meins,   " Satuan
         dispo TYPE afko-dispo,   " ASUMSI: MRP Controller di header order
         stlnr TYPE afko-stlnr,   " ASUMSI: Nomor BOM yang dipakai order
         stlal TYPE afko-stlal,   " ASUMSI: Alternative BOM
         objnr TYPE aufk-objnr,   " Object number -> kunci ke tabel status JEST
         werks TYPE aufk-werks,   " Plant header order (cadangan kalau DWERK kosong)
         sysst(60) TYPE c,        " Gabungan semua system status aktif (CRTD REL ...)
       END OF ty_ord.
TYPES: tt_ord TYPE STANDARD TABLE OF ty_ord WITH DEFAULT KEY.

*-- OPTIMASI PRELOAD --------------------------------------------------*
* Tabel penampung SELURUH order milik SO+Item ini, hasil 1x query di awal.
* Key MATNR sengaja NON-UNIQUE.
*   Requirement bilang: 1 material = maksimal 1 order aktif per SO+Item.
*   Tapi kalau ternyata di data nyata ada anomali (2 order untuk material yang
*   sama), UNIQUE KEY akan bikin program DUMP. NON-UNIQUE tidak. Lebih baik
*   program tetap jalan dan menampilkan dua-duanya daripada mati mendadak.
TYPES: tt_ord_sorted TYPE SORTED TABLE OF ty_ord
                     WITH NON-UNIQUE KEY matnr.
*----------------------------------------------------------------------*

* Satu komponen hasil BOM explosion 1 level
TYPES: BEGIN OF ty_comp,
         idnrk TYPE matnr,        " Material komponen
         maktx TYPE makt-maktx,   " Deskripsi
         werks TYPE werks_d,      " Plant komponen
         menge TYPE menge_d,      " Qty komponen SUDAH dikali qty order induk
         meins TYPE meins,        " Satuan
       END OF ty_comp.
TYPES: tt_comp TYPE STANDARD TABLE OF ty_comp WITH DEFAULT KEY.

* Satu node di pohon hasil telusur (ini yang dicetak ke layar)
TYPES: BEGIN OF ty_node,
         idx        TYPE i,          " Nomor urut node
         level      TYPE i,          " Kedalaman: 0, 1, 2, ...
         ntype(12)  TYPE c,          " 'ORDER' / 'BAHANBAKU' / 'REF' / 'WARNING'
         aufnr      TYPE aufnr,      " Nomor order (kosong kalau bahan baku)
         matnr      TYPE matnr,
         maktx      TYPE makt-maktx,
         werks      TYPE werks_d,
         dispo      TYPE dispo,      " MRP Controller
         target     TYPE menge_d,    " Target Qty
         avail      TYPE menge_d,    " Delivered Qty (ORDER) / Stok Unrestricted (BAHAN BAKU)
         meins      TYPE meins,
         status(14) TYPE c,          " 'SELESAI' / 'BELUM SELESAI' / 'TERSEDIA' / ...
         sysst(60)  TYPE c,          " System status SAP (khusus ORDER)
         stlnr      TYPE stnum,      " Nomor BOM (khusus ORDER)
         parent     TYPE i,          " idx node induk (0 = akar)
         remark(70) TYPE c,          " Keterangan / warning / rujukan node REF
       END OF ty_node.
TYPES: tt_node TYPE STANDARD TABLE OF ty_node WITH DEFAULT KEY.

* Jalur rekursi saat ini -> dipakai untuk deteksi circular BOM
TYPES: tt_path TYPE STANDARD TABLE OF matnr WITH DEFAULT KEY.

*-- OPTIMASI CACHE ----------------------------------------------------*
* Memo hasil penelusuran 1 production order (beserta SELURUH sub-tree-nya).
*   OK  = 'X' -> order ini DAN semua turunannya (sampai bahan baku paling
*                bawah) sudah selesai / stoknya tersedia
*   IDX = nomor node tempat order ini PERTAMA KALI dicatat
TYPES: BEGIN OF ty_memo,
         aufnr TYPE aufnr,
         ok    TYPE abap_bool,
         idx   TYPE i,
       END OF ty_memo.

* Cache hasil BOM explosion. Key sengaja MENYERTAKAN QTY -- lihat penjelasan
* panjang di METHOD explode_bom.
TYPES: BEGIN OF ty_cache_bom,
         matnr TYPE matnr,
         werks TYPE werks_d,
         capid TYPE capid,
         stlan TYPE stlan,
         qty   TYPE menge_d,
         comps TYPE tt_comp,      " hasil explode, disimpan apa adanya
       END OF ty_cache_bom.
*----------------------------------------------------------------------*

* --- Cache lain ---
TYPES: BEGIN OF ty_cache_stock,
         matnr TYPE matnr,
         werks TYPE werks_d,
         labst TYPE menge_d,
       END OF ty_cache_stock.

TYPES: BEGIN OF ty_cache_makt,
         matnr TYPE matnr,
         maktx TYPE makt-maktx,
       END OF ty_cache_makt.

*&---------------------------------------------------------------------*
*& SELECTION SCREEN
*&---------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE text-b01.
PARAMETERS: p_vbeln TYPE vbap-vbeln OBLIGATORY,   " SO Number
            p_posnr TYPE vbap-posnr OBLIGATORY,   " SO Item (ketik 10, jadi 000010)
            p_depth TYPE i DEFAULT 10.            " Max recursion depth (safety guard)
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE text-b02.
PARAMETERS: p_bom_fm RADIOBUTTON GROUP g1 DEFAULT 'X',  " FM CS_BOM_EXPL_MAT_V2
            p_bom_tb RADIOBUTTON GROUP g1.              " Baca tabel MAST/STAS/STPO
PARAMETERS: p_capid TYPE capid   DEFAULT 'PP01',  " ASUMSI: application PP01 = BOM produksi
            p_stlan TYPE stlan   DEFAULT '1'.     " ASUMSI: BOM usage 1 = produksi
SELECTION-SCREEN END OF BLOCK b2.

SELECTION-SCREEN BEGIN OF BLOCK b3 WITH FRAME TITLE text-b03.
PARAMETERS: p_omemo AS CHECKBOX DEFAULT 'X',      " Order-level memoization
            p_bomc  AS CHECKBOX DEFAULT 'X',      " Cache BOM explosion per material
            p_cache AS CHECKBOX DEFAULT 'X',      " Cache stok + deskripsi material
            p_trace AS CHECKBOX DEFAULT ' '.      " Cetak log detail tiap langkah
SELECTION-SCREEN END OF BLOCK b3.

*&---------------------------------------------------------------------*
*& LOCAL CLASS: LCL_TRACER
*&---------------------------------------------------------------------*
CLASS lcl_tracer DEFINITION.

  PUBLIC SECTION.
    METHODS:
      run,
      display.

  PRIVATE SECTION.
    DATA: mt_node TYPE tt_node,
          mv_idx  TYPE i.

*-- OPTIMASI PRELOAD --------------------------------------------------*
    " SELURUH order milik SO+Item ini. Diisi SEKALI di awal oleh
    " PRELOAD_ALL_ORDERS, lalu jadi satu-satunya sumber data GET_ORDERS.
    DATA: mt_all_ord TYPE tt_ord_sorted.
*----------------------------------------------------------------------*

    " --- cache ---
    DATA: mt_c_stock TYPE SORTED TABLE OF ty_cache_stock
                          WITH UNIQUE KEY matnr werks,
          mt_c_makt  TYPE SORTED TABLE OF ty_cache_makt
                          WITH UNIQUE KEY matnr,
          mt_c_order TYPE SORTED TABLE OF ty_memo
                          WITH UNIQUE KEY aufnr,
          mt_c_bom   TYPE SORTED TABLE OF ty_cache_bom
                          WITH UNIQUE KEY matnr werks capid stlan qty.

    " --- pengukuran performa (mikrodetik) ---
    DATA: mv_us_total TYPE i,
*-- OPTIMASI PRELOAD --
          mv_us_pre   TYPE i,   " waktu 1x query besar di awal
          mv_n_pre    TYPE i,   " jumlah order yang berhasil di-preload
*----------------------------------------------------------------------*
          mv_us_ord   TYPE i,   " sekarang: waktu LOOKUP MEMORY (bukan query DB)
          mv_us_bom   TYPE i,
          mv_us_stk   TYPE i,
          mv_us_resb  TYPE i,
          mv_n_ord    TYPE i,   " berapa kali get_orders dipanggil
          mv_n_bom    TYPE i,   " berapa kali BOM explosion BENERAN jalan
          mv_n_stk    TYPE i,
          mv_n_resb   TYPE i,
          mv_h_stk    TYPE i,   " cache hit stok
          mv_h_makt   TYPE i,   " cache hit deskripsi material
          mv_h_omemo  TYPE i,   " cache hit ORDER-LEVEL
          mv_h_bomc   TYPE i.   " cache hit BOM per material

    METHODS:
*-- OPTIMASI PRELOAD --
      preload_all_orders,
*----------------------------------------------------------------------*

      get_orders
        IMPORTING iv_matnr TYPE matnr OPTIONAL
        EXPORTING et_ord   TYPE tt_ord,

      process_order
        IMPORTING is_ord       TYPE ty_ord
                  iv_level     TYPE i
                  iv_parent    TYPE i
                  it_path      TYPE tt_path
        RETURNING VALUE(rv_ok) TYPE abap_bool,

      explode_bom
        IMPORTING iv_matnr TYPE matnr
                  iv_werks TYPE werks_d
                  iv_qty   TYPE menge_d
        EXPORTING et_comp  TYPE tt_comp,

      explode_bom_fm
        IMPORTING iv_matnr TYPE matnr
                  iv_werks TYPE werks_d
                  iv_qty   TYPE menge_d
        EXPORTING et_comp  TYPE tt_comp,

      explode_bom_table
        IMPORTING iv_matnr TYPE matnr
                  iv_werks TYPE werks_d
                  iv_qty   TYPE menge_d
        EXPORTING et_comp  TYPE tt_comp,

      get_stock
        IMPORTING iv_matnr        TYPE matnr
                  iv_werks        TYPE werks_d
        RETURNING VALUE(rv_stock) TYPE menge_d,

      get_resb_qty
        IMPORTING iv_aufnr      TYPE aufnr
                  iv_matnr      TYPE matnr
        RETURNING VALUE(rv_qty) TYPE menge_d,

      get_maktx
        IMPORTING iv_matnr        TYPE matnr
        RETURNING VALUE(rv_maktx) TYPE maktx,

      add_node
        IMPORTING is_node       TYPE ty_node
        RETURNING VALUE(rv_idx) TYPE i,

      log
        IMPORTING iv_text TYPE string.

ENDCLASS.                    "lcl_tracer DEFINITION


CLASS lcl_tracer IMPLEMENTATION.

*&---------------------------------------------------------------------*
*& RUN - titik masuk.
*&---------------------------------------------------------------------*
  METHOD run.

    DATA: lt_ord  TYPE tt_ord,
          ls_ord  TYPE ty_ord,
          lt_path TYPE tt_path,
          lv_ok   TYPE abap_bool,
          lv_t1   TYPE i,
          lv_t2   TYPE i.

    GET RUN TIME FIELD lv_t1.

*-- OPTIMASI PRELOAD --------------------------------------------------*
    " ---------- Tarik SEMUA order milik SO+Item ini, SEKALI SAJA ----------
    " Ini HARUS dipanggil sebelum apapun. Setelah ini, GET_ORDERS tidak akan
    " menyentuh database lagi.
    me->preload_all_orders( ).
*----------------------------------------------------------------------*

    " ---------- LEVEL 0 : semua order milik SO + SO item ----------
    me->get_orders( IMPORTING et_ord = lt_ord ).

    IF lt_ord IS INITIAL.
      GET RUN TIME FIELD lv_t2.
      mv_us_total = lv_t2 - lv_t1.
      RETURN.
    ENDIF.

    " Spec: urutkan hasil level 0 berdasarkan MRP Controller ascending
    SORT lt_ord BY dispo ASCENDING aufnr ASCENDING.

    LOOP AT lt_ord INTO ls_ord.
      CLEAR lt_path.
      lv_ok = me->process_order( is_ord    = ls_ord
                                 iv_level  = 0
                                 iv_parent = 0
                                 it_path   = lt_path ).
    ENDLOOP.

    GET RUN TIME FIELD lv_t2.
    mv_us_total = lv_t2 - lv_t1.

  ENDMETHOD.                    "run

*&---------------------------------------------------------------------*
*-- OPTIMASI PRELOAD --------------------------------------------------*
*& PRELOAD_ALL_ORDERS - 1x query besar di awal, menggantikan 42x query kecil
*&
*& Query di sini IDENTIK dengan GET_ORDERS versi lama saat IV_MATNR kosong:
*& AFPO JOIN AFKO JOIN AUFK, filter KDAUF + KDPOS + LOEKZ = space, TANPA
*& filter material. Pengolahan system status (JEST/TJ02T) dan fallback MRP
*& controller (MARC) juga sama persis -- bedanya dikerjakan sekaligus untuk
*& SEMUA order, bukan diulang per order.
*&---------------------------------------------------------------------*
  METHOD preload_all_orders.

    DATA: lt_ord   TYPE tt_ord,
          lt_jest  TYPE STANDARD TABLE OF jest WITH DEFAULT KEY,
          ls_jest  TYPE jest,
          lv_t1    TYPE i,
          lv_t2    TYPE i,
          lv_txt   TYPE tj02t-txt04,
          lv_dispo TYPE dispo.

    FIELD-SYMBOLS: <fs_ord> TYPE ty_ord.

    GET RUN TIME FIELD lv_t1.

    " -------------------------------------------------------------------
    " ASUMSI #1 - Link SO -> Production Order lewat tabel AFPO:
    "   AFPO-KDAUF = Sales Order number
    "   AFPO-KDPOS = Sales Order item
    "   AFPO-PSMNG = Target / order item quantity
    "   AFPO-WEMNG = Delivered quantity (hasil GR)
    " ASUMSI #2 - AFKO-DISPO = MRP Controller, AFKO-STLNR = nomor BOM order.
    " ASUMSI #3 - AUFK-LOEKZ = 'X' berarti order sudah dihapus -> dibuang.
    "
    " INI SATU-SATUNYA tempat order diambil dari database. Tidak ada lagi
    " SELECT order di manapun setelah ini.
    " -------------------------------------------------------------------
    SELECT a~aufnr a~posnr a~matnr a~dwerk a~psmng a~wemng a~meins
           k~dispo k~stlnr k~stlal
           u~objnr u~werks
      FROM afpo AS a
      INNER JOIN afko AS k ON k~aufnr = a~aufnr
      INNER JOIN aufk AS u ON u~aufnr = a~aufnr
      INTO CORRESPONDING FIELDS OF TABLE lt_ord
      WHERE a~kdauf = p_vbeln
        AND a~kdpos = p_posnr
        AND u~loekz = space.

    IF lt_ord IS INITIAL.
      GET RUN TIME FIELD lv_t2.
      mv_us_pre = lv_t2 - lv_t1.
      RETURN.
    ENDIF.

    " ---------- System status SEMUA order sekaligus (JEST + TJ02T) ----------
    " ASUMSI #4 - JEST-INACT = space -> status AKTIF.
    "             JEST-STAT diawali 'I' -> system status ('E' = user status,
    "             diabaikan). Teks pendeknya di TJ02T-TXT04.
    SELECT * FROM jest
      INTO TABLE lt_jest
      FOR ALL ENTRIES IN lt_ord
      WHERE objnr = lt_ord-objnr
        AND inact = space.

    LOOP AT lt_jest INTO ls_jest.
      CHECK ls_jest-stat(1) = 'I'.

      CLEAR lv_txt.
      SELECT SINGLE txt04 FROM tj02t INTO lv_txt
        WHERE istat = ls_jest-stat
          AND spras = sy-langu.
      IF lv_txt IS INITIAL.
        SELECT SINGLE txt04 FROM tj02t INTO lv_txt
          WHERE istat = ls_jest-stat
            AND spras = 'E'.
      ENDIF.
      CHECK lv_txt IS NOT INITIAL.

      LOOP AT lt_ord ASSIGNING <fs_ord> WHERE objnr = ls_jest-objnr.
        IF <fs_ord>-sysst IS INITIAL.
          <fs_ord>-sysst = lv_txt.
        ELSE.
          CONCATENATE <fs_ord>-sysst lv_txt
            INTO <fs_ord>-sysst SEPARATED BY space.
        ENDIF.
      ENDLOOP.
    ENDLOOP.

    " ---------- Plant & MRP Controller, sekaligus untuk semua order ----------
    LOOP AT lt_ord ASSIGNING <fs_ord>.
      IF <fs_ord>-dwerk IS INITIAL.
        <fs_ord>-dwerk = <fs_ord>-werks.
      ENDIF.

      " ASUMSI #5 - MARC-DISPO = MRP Controller di material master.
      IF <fs_ord>-dispo IS INITIAL AND <fs_ord>-matnr IS NOT INITIAL.
        CLEAR lv_dispo.
        SELECT SINGLE dispo FROM marc INTO lv_dispo
          WHERE matnr = <fs_ord>-matnr
            AND werks = <fs_ord>-dwerk.
        <fs_ord>-dispo = lv_dispo.
      ENDIF.
    ENDLOOP.

    " ---------- Simpan ke sorted table (key MATNR, NON-UNIQUE) ----------
    mt_all_ord = lt_ord.
    DESCRIBE TABLE mt_all_ord LINES mv_n_pre.

    GET RUN TIME FIELD lv_t2.
    mv_us_pre = lv_t2 - lv_t1.

  ENDMETHOD.                    "preload_all_orders
*----------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*& GET_ORDERS - "COOIS-equivalent"
*&
*-- OPTIMASI PRELOAD --
*& SUDAH TIDAK QUERY DATABASE LAGI. Semua data sudah ada di MT_ALL_ORD hasil
*& PRELOAD_ALL_ORDERS. Method ini sekarang murni lookup memory.
*&   IV_MATNR kosong -> kembalikan SEMUA order (dipakai Level 0)
*&   IV_MATNR diisi  -> kembalikan order milik material itu saja (dipakai rekursi)
*&
*& Hasilnya sama persis dengan versi lama: dulu database yang memfilter
*& "KDAUF + KDPOS + MATNR", sekarang MT_ALL_ORD sudah terfilter KDAUF + KDPOS
*& sejak preload, tinggal disaring per MATNR di memory.
*&---------------------------------------------------------------------*
  METHOD get_orders.

    DATA: ls_ord TYPE ty_ord,
          lv_t1  TYPE i,
          lv_t2  TYPE i.

    CLEAR et_ord.
    GET RUN TIME FIELD lv_t1.
    ADD 1 TO mv_n_ord.

    IF iv_matnr IS INITIAL.
      " Level 0: semua order milik SO+Item ini
      et_ord = mt_all_ord.
    ELSE.
      " Rekursi: apakah material ini punya production order sendiri?
      " MT_ALL_ORD adalah SORTED TABLE dengan key MATNR, jadi LOOP ... WHERE
      " matnr = ... otomatis dioptimasi (binary search), bukan scan penuh.
      LOOP AT mt_all_ord INTO ls_ord WHERE matnr = iv_matnr.
        APPEND ls_ord TO et_ord.
      ENDLOOP.
    ENDIF.

    GET RUN TIME FIELD lv_t2.
    mv_us_ord = mv_us_ord + lv_t2 - lv_t1.

  ENDMETHOD.                    "get_orders

*&---------------------------------------------------------------------*
*& PROCESS_ORDER - inti rekursi   (LOGIKA TIDAK BERUBAH)
*&   0. -- OPTIMASI CACHE -- order sudah pernah ditelusuri? -> node REF, keluar.
*&   1. catat order sebagai node
*&   2. explode BOM 1 level
*&   3. tiap komponen: punya order sendiri? -> rekursi. Tidak? -> bahan baku.
*&   4. -- OPTIMASI CACHE -- simpan status sub-tree ke memo
*&---------------------------------------------------------------------*
  METHOD process_order.

    DATA: ls_node     TYPE ty_node,
          lv_self     TYPE i,
          lv_dummy    TYPE i,
          lt_comp     TYPE tt_comp,
          ls_comp     TYPE ty_comp,
          lt_sub      TYPE tt_ord,
          ls_sub      TYPE ty_ord,
          lt_path     TYPE tt_path,
          ls_warn     TYPE ty_node,
          ls_leaf     TYPE ty_node,
          ls_ref      TYPE ty_node,
          ls_memo     TYPE ty_memo,
          lv_child    TYPE abap_bool,
          lv_idxc(10) TYPE c,
          lv_target   TYPE menge_d,
          lv_msg      TYPE string.

*-- OPTIMASI CACHE ----------------------------------------------------*
    " ---------- 0. Order ini sudah pernah ditelusuri tuntas? ----------
    IF p_omemo = 'X'.
      READ TABLE mt_c_order INTO ls_memo
        WITH TABLE KEY aufnr = is_ord-aufnr.
      IF sy-subrc = 0.
        ADD 1 TO mv_h_omemo.

        CLEAR lv_idxc.
        lv_idxc = ls_memo-idx.
        CONDENSE lv_idxc.

        CLEAR ls_ref.
        ls_ref-level  = iv_level.          " posisi kemunculan BARU ini
        ls_ref-ntype  = 'REF'.
        ls_ref-aufnr  = is_ord-aufnr.
        ls_ref-matnr  = is_ord-matnr.
        ls_ref-maktx  = me->get_maktx( is_ord-matnr ).
        ls_ref-werks  = is_ord-dwerk.
        ls_ref-dispo  = is_ord-dispo.
        ls_ref-target = is_ord-psmng.
        ls_ref-avail  = is_ord-wemng.
        ls_ref-meins  = is_ord-meins.
        ls_ref-sysst  = is_ord-sysst.
        ls_ref-parent = iv_parent.

        " Status DIAMBIL dari memo (status seluruh sub-tree), bukan dihitung ulang
        IF ls_memo-ok = 'X'.
          ls_ref-status = 'SELESAI'.
        ELSE.
          ls_ref-status = 'BELUM SELESAI'.
        ENDIF.

        " (tanpa SEPARATED BY: supaya '#' nempel ke angkanya -> "#12", bukan "# 12")
        CONCATENATE 'Sudah ditelusuri di node #' lv_idxc
                    ' - lihat baris tsb untuk detail'
          INTO ls_ref-remark.

        lv_dummy = me->add_node( ls_ref ).

        " TIDAK ada child yang ditambahkan di bawah node REF ini.
        rv_ok = ls_memo-ok.
        RETURN.
      ENDIF.
    ENDIF.
*----------------------------------------------------------------------*

    " ---------- 1. Catat order ini sebagai node ----------
    CLEAR ls_node.
    ls_node-level  = iv_level.
    ls_node-ntype  = 'ORDER'.
    ls_node-aufnr  = is_ord-aufnr.
    ls_node-matnr  = is_ord-matnr.
    ls_node-maktx  = me->get_maktx( is_ord-matnr ).
    ls_node-werks  = is_ord-dwerk.
    ls_node-dispo  = is_ord-dispo.
    ls_node-target = is_ord-psmng.
    ls_node-avail  = is_ord-wemng.
    ls_node-meins  = is_ord-meins.
    ls_node-sysst  = is_ord-sysst.
    ls_node-stlnr  = is_ord-stlnr.
    ls_node-parent = iv_parent.

    " Aturan status ORDER (TIDAK BERUBAH): SELESAI jika Delivered >= Target
    IF is_ord-wemng >= is_ord-psmng AND is_ord-psmng > 0.
      ls_node-status = 'SELESAI'.
      rv_ok = 'X'.
    ELSE.
      ls_node-status = 'BELUM SELESAI'.
      rv_ok = ' '.
    ENDIF.

    lv_self = me->add_node( ls_node ).

    CONCATENATE 'ORDER' is_ord-aufnr 'mat' is_ord-matnr
      INTO lv_msg SEPARATED BY space.
    me->log( lv_msg ).

    " ---------- 2. Guard: batas kedalaman rekursi ----------
    IF iv_level >= p_depth.
      CLEAR ls_warn.
      ls_warn-level  = iv_level + 1.
      ls_warn-ntype  = 'WARNING'.
      ls_warn-parent = lv_self.
      ls_warn-status = 'STOP'.
      ls_warn-remark = 'MAX RECURSION DEPTH TERCAPAI - penelusuran dihentikan'.
      lv_dummy = me->add_node( ls_warn ).

      " SENGAJA TIDAK disimpan ke memo: sub-tree belum tuntas ditelusuri, jadi
      " statusnya belum final. Kalau disimpan, status setengah jadi ini akan
      " "menular" ke cabang lain lewat node REF.
      RETURN.
    ENDIF.

    " ---------- 3. Guard: circular BOM ----------
    " Guard ini TETAP DIPERTAHANKAN. Order-level memo adalah guard TAMBAHAN,
    " bukan penggantinya: memo menangkap PENGULANGAN antar cabang, guard ini
    " menangkap LINGKARAN di dalam satu cabang menurun.
    READ TABLE it_path TRANSPORTING NO FIELDS
      WITH KEY table_line = is_ord-matnr.
    IF sy-subrc = 0.
      CLEAR ls_warn.
      ls_warn-level  = iv_level + 1.
      ls_warn-ntype  = 'WARNING'.
      ls_warn-matnr  = is_ord-matnr.
      ls_warn-parent = lv_self.
      ls_warn-status = 'STOP'.
      ls_warn-remark = 'CIRCULAR BOM - material sudah ada di jalur ini'.
      lv_dummy = me->add_node( ls_warn ).

      " Sama seperti di atas: TIDAK disimpan ke memo (sub-tree tidak tuntas).
      RETURN.
    ENDIF.

    lt_path = it_path.
    APPEND is_ord-matnr TO lt_path.

    " ---------- 4. Explode BOM 1 level ----------
    me->explode_bom( EXPORTING iv_matnr = is_ord-matnr
                               iv_werks = is_ord-dwerk
                               iv_qty   = is_ord-psmng
                     IMPORTING et_comp  = lt_comp ).

    " ---------- 5. Proses tiap komponen ----------
    LOOP AT lt_comp INTO ls_comp.

      " (a) Komponen ini punya production order SENDIRI di SO+item yang sama?
      "     (Sekarang ini lookup memory, bukan query DB -- lihat GET_ORDERS.)
      me->get_orders( EXPORTING iv_matnr = ls_comp-idnrk
                      IMPORTING et_ord   = lt_sub ).

      IF lt_sub IS NOT INITIAL.
        " (b) KETEMU order -> rekursi turun satu level
        SORT lt_sub BY dispo ASCENDING aufnr ASCENDING.
        LOOP AT lt_sub INTO ls_sub.
          lv_child = me->process_order( is_ord    = ls_sub
                                        iv_level  = iv_level + 1
                                        iv_parent = lv_self
                                        it_path   = lt_path ).
          " Status anak ikut menentukan status sub-tree order ini.
          IF lv_child <> 'X'.
            rv_ok = ' '.
          ENDIF.
        ENDLOOP.

      ELSE.
        " (c) TIDAK ada order -> ini BAHAN BAKU / BELI = leaf node
        CLEAR ls_leaf.
        ls_leaf-level  = iv_level + 1.
        ls_leaf-ntype  = 'BAHANBAKU'.
        ls_leaf-matnr  = ls_comp-idnrk.
        ls_leaf-maktx  = ls_comp-maktx.
        ls_leaf-werks  = ls_comp-werks.
        ls_leaf-meins  = ls_comp-meins.
        ls_leaf-parent = lv_self.

        " Target qty: utamakan Reservation (RESB) milik order induk.
        " Kalau tidak ada, fallback ke qty hasil BOM explosion. (TIDAK BERUBAH)
        lv_target = me->get_resb_qty( iv_aufnr = is_ord-aufnr
                                      iv_matnr = ls_comp-idnrk ).
        IF lv_target > 0.
          ls_leaf-target = lv_target.
        ELSE.
          ls_leaf-target = ls_comp-menge.
          ls_leaf-remark = 'Qty dari BOM (tidak ada reservation)'.
        ENDIF.

        " Stok unrestricted (MB52-equivalent). (TIDAK BERUBAH)
        ls_leaf-avail = me->get_stock( iv_matnr = ls_comp-idnrk
                                       iv_werks = ls_comp-werks ).

        IF ls_leaf-avail >= ls_leaf-target AND ls_leaf-target > 0.
          ls_leaf-status = 'TERSEDIA'.
        ELSE.
          ls_leaf-status = 'BELUM'.
          " Bahan baku kurang -> sub-tree order ini TIDAK selesai.
          rv_ok = ' '.
        ENDIF.

        lv_dummy = me->add_node( ls_leaf ).
      ENDIF.

    ENDLOOP.

*-- OPTIMASI CACHE ----------------------------------------------------*
    " ---------- 6. Simpan hasil penelusuran order ini ke memo ----------
    " Sampai di sini sub-tree order ini SUDAH tuntas (tidak ada bail-out karena
    " max depth / circular), jadi statusnya final dan aman dipakai ulang.
    IF p_omemo = 'X'.
      CLEAR ls_memo.
      ls_memo-aufnr = is_ord-aufnr.
      ls_memo-ok    = rv_ok.
      ls_memo-idx   = lv_self.
      INSERT ls_memo INTO TABLE mt_c_order.
    ENDIF.
*----------------------------------------------------------------------*

  ENDMETHOD.                    "process_order

*&---------------------------------------------------------------------*
*& EXPLODE_BOM - cek cache dulu, baru explode beneran  (TIDAK BERUBAH)
*&---------------------------------------------------------------------*
  METHOD explode_bom.

    DATA: ls_cbom TYPE ty_cache_bom,
          lv_t1   TYPE i,
          lv_t2   TYPE i.

    CLEAR et_comp.
    GET RUN TIME FIELD lv_t1.

*-- OPTIMASI CACHE ----------------------------------------------------*
    " CATATAN SOAL KEY: QTY sengaja IKUT jadi key (bukan "qty per unit"), karena:
    "   1. Komponen ber-flag FIXED QUANTITY (STPO-FMENG) TIDAK ikut naik saat
    "      qty order naik. Explode 1 unit lalu dikalikan -> SALAH untuk komponen ini.
    "   2. FM mengembalikan qty packed 3 desimal. Explode 1 unit MEMBULATKAN
    "      duluan -> komponen dengan pemakaian sangat kecil bisa jadi NOL.
    " Dengan qty ikut jadi key, hasil DIJAMIN identik dengan versi sebelumnya.
    IF p_bomc = 'X'.
      READ TABLE mt_c_bom INTO ls_cbom
        WITH TABLE KEY matnr = iv_matnr
                       werks = iv_werks
                       capid = p_capid
                       stlan = p_stlan
                       qty   = iv_qty.
      IF sy-subrc = 0.
        ADD 1 TO mv_h_bomc.
        et_comp = ls_cbom-comps.
        GET RUN TIME FIELD lv_t2.
        mv_us_bom = mv_us_bom + lv_t2 - lv_t1.
        RETURN.
      ENDIF.
    ENDIF.
*----------------------------------------------------------------------*

    " ---------- Explode beneran ----------
    ADD 1 TO mv_n_bom.

    IF p_bom_fm = 'X'.
      me->explode_bom_fm( EXPORTING iv_matnr = iv_matnr
                                    iv_werks = iv_werks
                                    iv_qty   = iv_qty
                          IMPORTING et_comp  = et_comp ).
    ELSE.
      me->explode_bom_table( EXPORTING iv_matnr = iv_matnr
                                       iv_werks = iv_werks
                                       iv_qty   = iv_qty
                             IMPORTING et_comp  = et_comp ).
    ENDIF.

    " Simpan hasilnya apa adanya (termasuk hasil KOSONG -- material tanpa BOM
    " juga layak di-cache, supaya tidak ditanyakan berulang).
    IF p_bomc = 'X'.
      CLEAR ls_cbom.
      ls_cbom-matnr = iv_matnr.
      ls_cbom-werks = iv_werks.
      ls_cbom-capid = p_capid.
      ls_cbom-stlan = p_stlan.
      ls_cbom-qty   = iv_qty.
      ls_cbom-comps = et_comp.
      INSERT ls_cbom INTO TABLE mt_c_bom.
    ENDIF.

    GET RUN TIME FIELD lv_t2.
    mv_us_bom = mv_us_bom + lv_t2 - lv_t1.

  ENDMETHOD.                    "explode_bom

*&---------------------------------------------------------------------*
*& EXPLODE_BOM_FM  (TIDAK BERUBAH)
*&---------------------------------------------------------------------*
  METHOD explode_bom_fm.

    DATA: lt_stb    TYPE STANDARD TABLE OF stpox WITH DEFAULT KEY,
          ls_stb    TYPE stpox,
          lt_matcat TYPE STANDARD TABLE OF cscmat WITH DEFAULT KEY,
          ls_comp   TYPE ty_comp,
          lv_emeng  TYPE bstmg.

    CLEAR et_comp.

    " -------------------------------------------------------------------
    " ASUMSI #6 - FM 'CS_BOM_EXPL_MAT_V2' = FM standar SAP untuk explode BOM.
    "   CAPID = 'PP01' -> BOM untuk produksi
    "   MEHRS = ' '    -> SINGLE LEVEL (sesuai spec)
    "   EMENG          -> hasil STB-MENGE otomatis sudah dikali qty ini
    "   STLAN = '1'    -> BOM usage produksi
    "   POSTP = 'L'    -> stock item (yang kita mau)
    " VERIFIKASI di SE37 -> CS_BOM_EXPL_MAT_V2.
    " -------------------------------------------------------------------
    lv_emeng = iv_qty.

    CALL FUNCTION 'CS_BOM_EXPL_MAT_V2'
      EXPORTING
        capid                 = p_capid
        datuv                 = sy-datum
        emeng                 = lv_emeng
        mehrs                 = ' '          " ' ' = SINGLE LEVEL
        mtnrv                 = iv_matnr
        stlan                 = p_stlan
        werks                 = iv_werks
      TABLES
        stb                   = lt_stb
        matcat                = lt_matcat
      EXCEPTIONS
        alt_not_found         = 1
        call_invalid          = 2
        material_not_found    = 3
        missing_authorization = 4
        no_bom_found          = 5
        no_plant_data         = 6
        no_suitable_bom_found = 7
        conversion_error      = 8
        OTHERS                = 9.

    IF sy-subrc <> 0.
      " Tidak ada BOM = wajar. Material ini memang tidak punya struktur di bawahnya.
      RETURN.
    ENDIF.

    LOOP AT lt_stb INTO ls_stb.

      CHECK ls_stb-postp = 'L'.          " stock item saja
      CHECK ls_stb-idnrk IS NOT INITIAL.

      CLEAR ls_comp.
      ls_comp-idnrk = ls_stb-idnrk.
      ls_comp-maktx = ls_stb-ojtxp.
      ls_comp-menge = ls_stb-menge.
      ls_comp-meins = ls_stb-meins.
      ls_comp-werks = iv_werks.

      IF ls_comp-maktx IS INITIAL.
        ls_comp-maktx = me->get_maktx( ls_comp-idnrk ).
      ENDIF.

      APPEND ls_comp TO et_comp.
    ENDLOOP.

  ENDMETHOD.                    "explode_bom_fm

*&---------------------------------------------------------------------*
*& EXPLODE_BOM_TABLE  (TIDAK BERUBAH)
*&---------------------------------------------------------------------*
  METHOD explode_bom_table.

    DATA: lv_stlnr  TYPE mast-stlnr,
          lv_stlal  TYPE mast-stlal,
          lv_bmeng  TYPE stko-bmeng,
          lt_stas   TYPE STANDARD TABLE OF stas WITH DEFAULT KEY,
          ls_stas   TYPE stas,
          lt_stlkn  TYPE STANDARD TABLE OF stlkn WITH DEFAULT KEY,
          ls_comp   TYPE ty_comp,
          lv_factor TYPE f.

    TYPES: BEGIN OF ty_stpo,
             idnrk TYPE stpo-idnrk,
             menge TYPE stpo-menge,
             meins TYPE stpo-meins,
             postp TYPE stpo-postp,
             stlkn TYPE stpo-stlkn,
           END OF ty_stpo.
    DATA: lt_stpo TYPE STANDARD TABLE OF ty_stpo WITH DEFAULT KEY,
          ls_stpo TYPE ty_stpo.

    CLEAR et_comp.

    " -------------------------------------------------------------------
    " ASUMSI #7 - Rantai tabel BOM standar SAP:
    "   MAST : material -> nomor BOM   (MATNR + WERKS + STLAN -> STLNR/STLAL)
    "   STKO : header BOM              (BMENG = base quantity BOM)
    "   STAS : item mana yang ikut alternatif ini (LKENZ = 'X' -> dihapus)
    "   STPO : detail item BOM         (IDNRK = komponen, MENGE = qty)
    "   STLTY = 'M' artinya BOM material.
    " -------------------------------------------------------------------
    SELECT SINGLE stlnr stlal FROM mast
      INTO (lv_stlnr, lv_stlal)
      WHERE matnr = iv_matnr
        AND werks = iv_werks
        AND stlan = p_stlan.
    IF sy-subrc <> 0 OR lv_stlnr IS INITIAL.
      RETURN.   " tidak punya BOM -> bukan error
    ENDIF.

    SELECT SINGLE bmeng FROM stko INTO lv_bmeng
      WHERE stlty = 'M'
        AND stlnr = lv_stlnr
        AND stlal = lv_stlal.
    IF sy-subrc <> 0 OR lv_bmeng <= 0.
      lv_bmeng = 1.
    ENDIF.

    SELECT * FROM stas INTO TABLE lt_stas
      WHERE stlty = 'M'
        AND stlnr = lv_stlnr
        AND stlal = lv_stlal
        AND lkenz = space.
    IF lt_stas IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT lt_stas INTO ls_stas.
      APPEND ls_stas-stlkn TO lt_stlkn.
    ENDLOOP.
    SORT lt_stlkn.
    DELETE ADJACENT DUPLICATES FROM lt_stlkn.

    " Ambil semua item BOM ini, lalu saring pakai daftar STLKN dari STAS.
    " (Sengaja TIDAK pakai FOR ALL ENTRIES pada tabel elementer, karena
    "  tidak semua release ABAP mendukung "lt_stlkn-table_line" di WHERE.)
    SELECT idnrk menge meins postp stlkn
      FROM stpo
      INTO TABLE lt_stpo
      WHERE stlty = 'M'
        AND stlnr = lv_stlnr.

    " dipaksa lewat float supaya base quantity besar (mis. BMENG = 1000)
    " tidak kehilangan presisi saat dibagi
    lv_factor = iv_qty.
    lv_factor = lv_factor / lv_bmeng.

    LOOP AT lt_stpo INTO ls_stpo.
      " item ini termasuk alternatif yang dipakai & belum dihapus?
      READ TABLE lt_stlkn TRANSPORTING NO FIELDS
        WITH KEY table_line = ls_stpo-stlkn BINARY SEARCH.
      CHECK sy-subrc = 0.

      CHECK ls_stpo-postp = 'L'.          " stock item saja
      CHECK ls_stpo-idnrk IS NOT INITIAL.

      CLEAR ls_comp.
      ls_comp-idnrk = ls_stpo-idnrk.
      ls_comp-menge = ls_stpo-menge * lv_factor.
      ls_comp-meins = ls_stpo-meins.
      ls_comp-werks = iv_werks.
      ls_comp-maktx = me->get_maktx( ls_stpo-idnrk ).
      APPEND ls_comp TO et_comp.
    ENDLOOP.

  ENDMETHOD.                    "explode_bom_table

*&---------------------------------------------------------------------*
*& GET_STOCK - "MB52-equivalent"  (TIDAK BERUBAH)
*&---------------------------------------------------------------------*
  METHOD get_stock.

    DATA: ls_cache TYPE ty_cache_stock,
          lv_labst TYPE menge_d,
          lv_t1    TYPE i,
          lv_t2    TYPE i.

    CLEAR rv_stock.

    IF p_cache = 'X'.
      READ TABLE mt_c_stock INTO ls_cache
        WITH TABLE KEY matnr = iv_matnr werks = iv_werks.
      IF sy-subrc = 0.
        ADD 1 TO mv_h_stk.
        rv_stock = ls_cache-labst.
        RETURN.
      ENDIF.
    ENDIF.

    GET RUN TIME FIELD lv_t1.
    ADD 1 TO mv_n_stk.

    " -------------------------------------------------------------------
    " ASUMSI #8 - Stok unrestricted diambil dari MARD-LABST.
    "   MARD-LABST = unrestricted use  <- INI yang dipakai
    "   MARD-INSME = Quality Inspection (TIDAK dihitung, sesuai spec)
    "   MARD-SPEME = Blocked            (TIDAK dihitung, sesuai spec)
    "
    "   KALAU STOK KELUAR 0 PADAHAL MB52 ADA ISINYA: kemungkinan besar bahan
    "   baku Anda disimpan sebagai SALES ORDER STOCK (special stock 'E', khas
    "   Make-To-Order) -> angkanya ada di MSKA-KALAB, bukan MARD.
    " -------------------------------------------------------------------
    SELECT SUM( labst ) FROM mard INTO lv_labst
      WHERE matnr = iv_matnr
        AND werks = iv_werks.

    rv_stock = lv_labst.

    "--------------------------------------------------------------------
    " OPSIONAL - Sales Order Stock (special stock E):
    "   DATA: lv_kalab TYPE menge_d.
    "   SELECT SUM( kalab ) FROM mska INTO lv_kalab
    "     WHERE matnr = iv_matnr
    "       AND werks = iv_werks
    "       AND vbeln = p_vbeln
    "       AND posnr = p_posnr.
    "   ADD lv_kalab TO rv_stock.
    "--------------------------------------------------------------------

    GET RUN TIME FIELD lv_t2.
    mv_us_stk = mv_us_stk + lv_t2 - lv_t1.

    IF p_cache = 'X'.
      CLEAR ls_cache.
      ls_cache-matnr = iv_matnr.
      ls_cache-werks = iv_werks.
      ls_cache-labst = rv_stock.
      INSERT ls_cache INTO TABLE mt_c_stock.
    ENDIF.

  ENDMETHOD.                    "get_stock

*&---------------------------------------------------------------------*
*& GET_RESB_QTY  (TIDAK BERUBAH)
*&---------------------------------------------------------------------*
  METHOD get_resb_qty.

    DATA: lv_bdmng TYPE menge_d,
          lv_t1    TYPE i,
          lv_t2    TYPE i.

    CLEAR rv_qty.
    GET RUN TIME FIELD lv_t1.
    ADD 1 TO mv_n_resb.

    " -------------------------------------------------------------------
    " ASUMSI #9 - RESB = tabel reservation / kebutuhan komponen order.
    "   RESB-BDMNG = requirement quantity  <- target qty yang kita mau
    "   RESB-XLOEK = 'X' -> item reservation dihapus, jangan dihitung
    " -------------------------------------------------------------------
    SELECT SUM( bdmng ) FROM resb INTO lv_bdmng
      WHERE aufnr = iv_aufnr
        AND matnr = iv_matnr
        AND xloek = space.

    rv_qty = lv_bdmng.

    GET RUN TIME FIELD lv_t2.
    mv_us_resb = mv_us_resb + lv_t2 - lv_t1.

  ENDMETHOD.                    "get_resb_qty

*&---------------------------------------------------------------------*
*& GET_MAKTX  (TIDAK BERUBAH)
*&---------------------------------------------------------------------*
  METHOD get_maktx.

    DATA: ls_cache TYPE ty_cache_makt.

    CLEAR rv_maktx.
    CHECK iv_matnr IS NOT INITIAL.

    IF p_cache = 'X'.
      READ TABLE mt_c_makt INTO ls_cache WITH TABLE KEY matnr = iv_matnr.
      IF sy-subrc = 0.
        ADD 1 TO mv_h_makt.
        rv_maktx = ls_cache-maktx.
        RETURN.
      ENDIF.
    ENDIF.

    " ASUMSI #10 - MAKT = deskripsi material per bahasa (SPRAS).
    SELECT SINGLE maktx FROM makt INTO rv_maktx
      WHERE matnr = iv_matnr
        AND spras = sy-langu.

    IF p_cache = 'X'.
      CLEAR ls_cache.
      ls_cache-matnr = iv_matnr.
      ls_cache-maktx = rv_maktx.
      INSERT ls_cache INTO TABLE mt_c_makt.
    ENDIF.

  ENDMETHOD.                    "get_maktx

*&---------------------------------------------------------------------*
*& ADD_NODE
*&---------------------------------------------------------------------*
  METHOD add_node.

    DATA: ls_node TYPE ty_node.

    ADD 1 TO mv_idx.
    ls_node     = is_node.
    ls_node-idx = mv_idx.
    APPEND ls_node TO mt_node.
    rv_idx = mv_idx.

  ENDMETHOD.                    "add_node

*&---------------------------------------------------------------------*
*& LOG
*&---------------------------------------------------------------------*
  METHOD log.

    CHECK p_trace = 'X'.
    WRITE: / '[trace]', iv_text.

  ENDMETHOD.                    "log

*&---------------------------------------------------------------------*
*& DISPLAY - cetak pohon + summary + hasil pengukuran performa
*&           (STRUKTUR/KOLOM OUTPUT TIDAK BERUBAH; hanya ada 1 baris baru
*&            di blok performa: waktu PRELOAD)
*&---------------------------------------------------------------------*
  METHOD display.

    DATA: ls_node        TYPE ty_node,
          lv_matdis(60)  TYPE c,
          lv_tmp(40)     TYPE c,
          lv_off         TYPE i,
          lv_i           TYPE i,
          lv_ord         TYPE i,
          lv_raw         TYPE i,
          lv_ref         TYPE i,
          lv_warn        TYPE i,
          lv_bad         TYPE i,
          lv_bad_ref     TYPE i,
          lv_overall(14) TYPE c,
          lv_ms          TYPE p DECIMALS 3,
          lv_f           TYPE f,
          lv_pct         TYPE p DECIMALS 1,
          lv_type(12)    TYPE c,
          lv_aufnr(12)   TYPE c.

    " ================= HEADER =================
    FORMAT COLOR COL_HEADING.
    WRITE: / 'TELUSUR REKURSIF SALES ORDER'.
    FORMAT COLOR OFF.
    WRITE: / 'Sales Order  :', p_vbeln,
           / 'SO Item      :', p_posnr,
           / 'Max Depth    :', p_depth LEFT-JUSTIFIED.
    IF p_bom_fm = 'X'.
      WRITE: / 'Metode BOM   : FM CS_BOM_EXPL_MAT_V2 ( CAPID', p_capid,
               '/ STLAN', p_stlan, ')'.
    ELSE.
      WRITE: / 'Metode BOM   : Baca tabel MAST/STAS/STPO ( STLAN', p_stlan, ')'.
    ENDIF.

    IF p_omemo = 'X'.
      WRITE: / 'Order memo   : AKTIF'.
    ELSE.
      WRITE: / 'Order memo   : MATI'.
    ENDIF.
    IF p_bomc = 'X'.
      WRITE: / 'Cache BOM    : AKTIF'.
    ELSE.
      WRITE: / 'Cache BOM    : MATI'.
    ENDIF.
    IF p_cache = 'X'.
      WRITE: / 'Cache stok   : AKTIF'.
    ELSE.
      WRITE: / 'Cache stok   : MATI'.
    ENDIF.
    SKIP.

    IF mt_node IS INITIAL.
      FORMAT COLOR COL_NEGATIVE.
      WRITE: / 'TIDAK ADA PRODUCTION ORDER untuk SO', p_vbeln,
               'item', p_posnr, '.'.
      FORMAT COLOR OFF.
      WRITE: / 'Cek lagi: nomor SO benar? item benar (ketik 10 -> jadi 000010)?'.
      WRITE: / 'Cek manual di tcode COOIS pakai filter Sales Order yang sama.'.
      RETURN.
    ENDIF.

    " ================= TABEL POHON =================
    FORMAT COLOR COL_HEADING.
    WRITE: /(5)  '#',
            (3)  'LV',
            (12) 'TIPE',
            (12) 'ORDER',
            (46) 'MATERIAL (indent = level)',
            (30) 'DESKRIPSI',
            (5)  'PLNT',
            (5)  'MRP',
            (15) 'TARGET QTY',
            (15) 'QTY ADA',
            (4)  'UOM',
            (14) 'STATUS',
            (70) 'SYSTEM STATUS / KETERANGAN'.
    FORMAT COLOR OFF.
    ULINE.

    LOOP AT mt_node INTO ls_node.

      " Indentasi visual sesuai level
      CLEAR: lv_matdis, lv_tmp.
      lv_off = ls_node-level * 2.
      IF lv_off > 30.
        lv_off = 30.
      ENDIF.

      IF ls_node-level = 0.
        lv_tmp = ls_node-matnr.
      ELSE.
        CONCATENATE '+- ' ls_node-matnr INTO lv_tmp.
      ENDIF.
      lv_matdis+lv_off = lv_tmp.

      CASE ls_node-ntype.
        WHEN 'ORDER'.
          lv_type  = '[ORDER]'.
          lv_aufnr = ls_node-aufnr.
          ADD 1 TO lv_ord.
        WHEN 'BAHANBAKU'.
          lv_type  = '[BHN BAKU]'.
          lv_aufnr = '-'.
          ADD 1 TO lv_raw.
        WHEN 'REF'.
          lv_type  = '[SUDAH ADA]'.
          lv_aufnr = ls_node-aufnr.
          ADD 1 TO lv_ref.
        WHEN OTHERS.
          lv_type  = '[WARNING]'.
          lv_aufnr = '-'.
          ADD 1 TO lv_warn.
      ENDCASE.

      " ---- warna baris ----
      IF ls_node-ntype = 'WARNING'.
        FORMAT COLOR COL_TOTAL.

      ELSEIF ls_node-ntype = 'REF'.
        " Warna NETRAL: ini bukan hasil hitungan baru, cuma rujukan ke node lain.
        FORMAT COLOR COL_NORMAL.
        IF ls_node-status <> 'SELESAI'.
          ADD 1 TO lv_bad_ref.
        ENDIF.

      ELSEIF ls_node-status = 'SELESAI' OR ls_node-status = 'TERSEDIA'.
        FORMAT COLOR COL_POSITIVE.
      ELSE.
        FORMAT COLOR COL_NEGATIVE.
        ADD 1 TO lv_bad.
      ENDIF.

      WRITE: /(5)  ls_node-idx,
              (3)  ls_node-level,
              (12) lv_type,
              (12) lv_aufnr,
              (46) lv_matdis,
              (30) ls_node-maktx,
              (5)  ls_node-werks,
              (5)  ls_node-dispo,
              (15) ls_node-target,
              (15) ls_node-avail,
              (4)  ls_node-meins,
              (14) ls_node-status.

      IF ls_node-remark IS NOT INITIAL.
        WRITE: (70) ls_node-remark.
      ELSE.
        WRITE: (70) ls_node-sysst.
      ENDIF.

      FORMAT COLOR OFF.
    ENDLOOP.

    ULINE.

    " ================= SUMMARY =================
    SKIP.
    FORMAT COLOR COL_HEADING.
    WRITE: / 'SUMMARY'.
    FORMAT COLOR OFF.

    lv_i = lv_ord + lv_raw.
    WRITE: / 'Total node ditelusuri  :', lv_i    LEFT-JUSTIFIED,
             '  ( ORDER:', lv_ord LEFT-JUSTIFIED,
             ', BAHAN BAKU:', lv_raw LEFT-JUSTIFIED, ')'.

    IF lv_ref > 0.
      WRITE: / 'Node REF (rujukan)     :', lv_ref LEFT-JUSTIFIED,
               '  (order yang sudah ditelusuri di cabang lain - TIDAK dihitung ulang di atas)'.
    ENDIF.

    IF lv_warn > 0.
      FORMAT COLOR COL_TOTAL.
      WRITE: / 'Warning                :', lv_warn LEFT-JUSTIFIED,
               '  (circular BOM / max depth - lihat baris [WARNING] di atas)'.
      FORMAT COLOR OFF.
    ENDIF.

    lv_i = lv_bad + lv_bad_ref.
    IF lv_i = 0.
      lv_overall = 'SELESAI'.
      FORMAT COLOR COL_POSITIVE.
    ELSE.
      lv_overall = 'BELUM SELESAI'.
      FORMAT COLOR COL_NEGATIVE.
    ENDIF.
    WRITE: / 'STATUS KESELURUHAN SO  :', lv_overall.
    FORMAT COLOR OFF.

    IF lv_bad > 0.
      WRITE: / '                         ', lv_bad LEFT-JUSTIFIED,
               'node belum selesai / stok kurang.'.
    ENDIF.
    IF lv_bad_ref > 0.
      WRITE: / '                         ', lv_bad_ref LEFT-JUSTIFIED,
               'node REF menunjuk ke sub-tree yang belum selesai.'.
    ENDIF.
    IF lv_warn > 0.
      WRITE: / '                          HATI-HATI: pohon TIDAK lengkap',
               '(ada cabang yang dihentikan). Status di atas belum tentu final.'.
    ENDIF.

    " ================= RUNTIME =================
    SKIP.
    FORMAT COLOR COL_HEADING.
    WRITE: / 'PENGUKURAN PERFORMA  (GET RUN TIME FIELD, satuan mikrodetik)'.
    FORMAT COLOR OFF.

    lv_f  = mv_us_total.
    lv_ms = lv_f / 1000.
    WRITE: / 'Waktu TOTAL eksekusi        :', (12) lv_ms, 'ms',
             '  (', (12) mv_us_total, 'us )'.
    ULINE.

*-- OPTIMASI PRELOAD --------------------------------------------------*
    " Baris BARU. Dulu: 42x query kecil-kecil selama rekursi.
    " Sekarang: 1x query besar di sini, sisanya lookup memory.
    lv_f  = mv_us_pre.
    lv_ms = lv_f / 1000.
    IF mv_us_total > 0.
      lv_f   = mv_us_pre.
      lv_pct = lv_f * 100 / mv_us_total.
    ENDIF.
    FORMAT COLOR COL_POSITIVE.
    WRITE: / '  PRELOAD semua order (1x)  :', (12) lv_ms, 'ms',
             '  |', (5) lv_pct, '%',
             '  |', (5) mv_n_pre, 'order ditarik sekaligus'.
    FORMAT COLOR OFF.
*----------------------------------------------------------------------*

    lv_f  = mv_us_ord.
    lv_ms = lv_f / 1000.
    IF mv_us_total > 0.
      lv_f   = mv_us_ord.
      lv_pct = lv_f * 100 / mv_us_total.
    ENDIF.
    WRITE: / '  Pencarian ORDER (lookup)  :', (12) lv_ms, 'ms',
             '  |', (5) lv_pct, '%',
             '  | dipanggil', (5) mv_n_ord, 'x  <- SUDAH BUKAN QUERY DB, cuma baca memory'.

    lv_f  = mv_us_bom.
    lv_ms = lv_f / 1000.
    IF mv_us_total > 0.
      lv_f   = mv_us_bom.
      lv_pct = lv_f * 100 / mv_us_total.
    ENDIF.
    WRITE: / '  BOM EXPLOSION (CS03)      :', (12) lv_ms, 'ms',
             '  |', (5) lv_pct, '%',
             '  | dipanggil', (5) mv_n_bom, 'x'.

    lv_f  = mv_us_stk.
    lv_ms = lv_f / 1000.
    IF mv_us_total > 0.
      lv_f   = mv_us_stk.
      lv_pct = lv_f * 100 / mv_us_total.
    ENDIF.
    WRITE: / '  CEK STOK (MB52)           :', (12) lv_ms, 'ms',
             '  |', (5) lv_pct, '%',
             '  | dipanggil', (5) mv_n_stk, 'x'.

    lv_f  = mv_us_resb.
    lv_ms = lv_f / 1000.
    IF mv_us_total > 0.
      lv_f   = mv_us_resb.
      lv_pct = lv_f * 100 / mv_us_total.
    ENDIF.
    WRITE: / '  BACA RESERVATION (RESB)   :', (12) lv_ms, 'ms',
             '  |', (5) lv_pct, '%',
             '  | dipanggil', (5) mv_n_resb, 'x'.

    ULINE.

    FORMAT COLOR COL_POSITIVE.
    WRITE: / 'Order-level cache HIT       :', (5) mv_h_omemo,
             'x  <-- sebanyak ini penelusuran sub-tree BERHASIL DIHINDARI'.
    WRITE: / 'BOM-explosion cache HIT     :', (5) mv_h_bomc,
             'x  (per material+plant+qty)'.
    FORMAT COLOR OFF.

    WRITE: / 'Cache hit stok              :', (5) mv_h_stk,
             'x  (query DB yang berhasil dihindari)'.
    WRITE: / 'Cache hit deskripsi materi  :', (5) mv_h_makt, 'x'.

  ENDMETHOD.                    "display

ENDCLASS.                    "lcl_tracer IMPLEMENTATION


*&---------------------------------------------------------------------*
*& MAIN
*&---------------------------------------------------------------------*
DATA: go_tracer TYPE REF TO lcl_tracer.

START-OF-SELECTION.

  IF p_depth <= 0 OR p_depth > 30.
    MESSAGE 'Max Recursion Depth harus antara 1 dan 30' TYPE 'E'.
  ENDIF.

  CREATE OBJECT go_tracer.
  go_tracer->run( ).
  go_tracer->display( ).
