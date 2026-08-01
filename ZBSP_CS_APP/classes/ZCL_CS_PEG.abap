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

    " Bentuk SATU simpul akar dari lt_prod dan telusuri anak-anaknya lewat
    " descend( ). Dipakai baik utk akar normal (Langkah 4 assemble) maupun
    " akar fallback (K3: pohon tidak boleh kosong diam-diam bila siklus
    " membuat deteksi akar normal tidak menemukan kandidat sama sekali) —
    " supaya blok pembentukan simpul tidak disalin dua kali.
    CLASS-METHODS build_root
      IMPORTING is_prod    TYPE ty_prod
                it_prod    TYPE tt_prod
                it_res_agg TYPE tt_res
                iv_note    TYPE string OPTIONAL
      CHANGING  ct_node    TYPE tt_node
                ct_seen    TYPE string_table.

ENDCLASS.

CLASS zcl_cs_peg IMPLEMENTATION.

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

  METHOD build_root.
    DATA: ls_node TYPE ty_node,
          lt_path TYPE string_table.

    CLEAR ls_node.
    ls_node-node_key = is_prod-kdpos && '/' && is_prod-matnr.
    ls_node-kdpos    = is_prod-kdpos.
    ls_node-matnr    = is_prod-matnr.
    ls_node-aufnr    = is_prod-aufnr.
    ls_node-qty_out  = is_prod-psmng.
    ls_node-dispo    = is_prod-dispo.
    ls_node-note     = iv_note.
    stn_of_order( EXPORTING iv_pwerk = is_prod-pwerk iv_dispo = is_prod-dispo
                  IMPORTING ev_seq   = ls_node-stn_seq
                            ev_txt   = ls_node-stn_txt
                            ev_in_scope = ls_node-in_scope ).
    APPEND ls_node TO ct_node.
    APPEND is_prod-matnr TO ct_seen.

    CLEAR lt_path.
    APPEND is_prod-matnr TO lt_path.
    descend( EXPORTING is_parent  = ls_node
                       it_prod    = it_prod
                       it_res_agg = it_res_agg
                       it_path    = lt_path
             CHANGING  ct_node    = ct_node
                       ct_seen    = ct_seen ).
  ENDMETHOD.

  METHOD assemble.
    DATA: lt_res_agg TYPE tt_res,
          ls_res     TYPE ty_res,
          ls_ord     TYPE ty_ord,
          lt_seen    TYPE string_table.
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
    "     Kunci HARUS (matnr, kdpos) milik order YANG MENGONSUMSI komponen
    "     itu — bukan kdpos komponennya sendiri. Kalau hanya matnr, material
    "     yang jadi AKAR di satu item SO tapi jadi KOMPONEN di item SO lain
    "     akan salah dikira "terpakai" di kedua tempat, sehingga item
    "     pertama kehilangan akarnya (lihat tes
    "     akar_di_satu_item_komponen_di_lain).
    TYPES: BEGIN OF ty_used,
             matnr TYPE matnr,
             kdpos TYPE afpo-kdpos,
           END OF ty_used.
    DATA: lt_used TYPE STANDARD TABLE OF ty_used WITH DEFAULT KEY,
          ls_used TYPE ty_used.
    LOOP AT lt_res_agg INTO ls_res.
      READ TABLE lt_prod TRANSPORTING NO FIELDS WITH KEY matnr = ls_res-matnr.
      IF sy-subrc = 0.        " hanya yg punya order pembuat (spec K4)
        READ TABLE it_ord INTO ls_ord WITH KEY aufnr = ls_res-aufnr.
        IF sy-subrc = 0.
          CLEAR ls_used.
          ls_used-matnr = ls_res-matnr.
          ls_used-kdpos = ls_ord-kdpos.   " kdpos order PENGONSUMSI
          APPEND ls_used TO lt_used.
        ENDIF.
      ENDIF.
    ENDLOOP.
    SORT lt_used BY matnr kdpos.
    DELETE ADJACENT DUPLICATES FROM lt_used COMPARING matnr kdpos.

    " --- 4. Akar = order yang materialnya tidak dipakai order lain ---
    LOOP AT lt_prod ASSIGNING <p>.
      READ TABLE lt_used TRANSPORTING NO FIELDS
        WITH KEY matnr = <p>-matnr kdpos = <p>-kdpos BINARY SEARCH.
      IF sy-subrc = 0.
        CONTINUE.             " bukan akar, dia dipakai order lain
      ENDIF.
      build_root( EXPORTING is_prod    = <p>
                            it_prod    = lt_prod
                            it_res_agg = lt_res_agg
                  CHANGING  ct_node    = rt_node
                            ct_seen    = lt_seen ).
    ENDLOOP.

    " --- 5. K3: pohon tidak boleh kosong diam-diam ---
    "     Kalau lt_prod tidak kosong tapi Langkah 4 tidak menemukan SATU
    "     PUN kandidat akar (mis. siklus tertutup A<->B: A "dipakai" B dan
    "     B "dipakai" A, jadi keduanya tersisih), jangan biarkan rt_node
    "     kosong tanpa penjelasan. Perlakukan SEMUA order pembuat sbg akar
    "     fallback; descend( )-lah yang lantas menghentikan rekursinya
    "     lewat penjaga siklus (note 'rekursi dihentikan').
    IF rt_node IS INITIAL AND lt_prod IS NOT INITIAL.
      LOOP AT lt_prod ASSIGNING <p>.
        build_root( EXPORTING is_prod    = <p>
                              it_prod    = lt_prod
                              it_res_agg = lt_res_agg
                              iv_note    = 'akar tidak terdeteksi (kemungkinan siklus)'
                    CHANGING  ct_node    = rt_node
                              ct_seen    = lt_seen ).
      ENDLOOP.
    ENDIF.
  ENDMETHOD.

  METHOD build.
    CLEAR: et_node, et_stn, et_wc, et_opm, ev_trunc.
  ENDMETHOD.

ENDCLASS.
