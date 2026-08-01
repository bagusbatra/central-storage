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
             rumus_status_operasi FOR TESTING,
             pohon_konvergensi FOR TESTING,
             material_sama_beda_item FOR TESTING,
             pohon_tiga_tingkat FOR TESTING,
             komponen_dipakai_dua_induk FOR TESTING,
             siklus_dihentikan FOR TESTING,
             akar_di_satu_item_komponen_di_lain FOR TESTING,
             batas_kedalaman_dihormati FOR TESTING.
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
    " qty pecahan TIDAK boleh dibulatkan sebelum dibandingkan
    cl_abap_unit_assert=>assert_equals(
      act = zcl_cs_peg=>op_status( iv_lmnga = '9.6' iv_mgvrg = '10.0' iv_aueru = ' ' )
      exp = 'active' msg = '9,6 dari 10 belum selesai — jangan dibulatkan' ).
  ENDMETHOD.

  METHOD stasiun_dari_plant_dispo.
    DATA: lv_seq TYPE i, lv_txt TYPE string, lv_in TYPE abap_bool.

    " Plant 1000 dgn DISPO baku -> stasiun 1 Pembahanan (digabung)
    zcl_cs_peg=>stn_of_order( EXPORTING iv_pwerk = '1000' iv_dispo = 'PN1'
                              IMPORTING ev_seq = lv_seq ev_txt = lv_txt
                                        ev_in_scope = lv_in ).
    cl_abap_unit_assert=>assert_equals( act = lv_seq exp = 1 msg = 'Plant 1000 -> stasiun 1' ).
    cl_abap_unit_assert=>assert_equals( act = lv_in  exp = abap_true ).

    " Plant 1000 ber-DISPO asing -> stasiun 9, BUKAN Pembahanan
    zcl_cs_peg=>stn_of_order( EXPORTING iv_pwerk = '1000' iv_dispo = 'ZZ9'
                              IMPORTING ev_seq = lv_seq ev_in_scope = lv_in ).
    cl_abap_unit_assert=>assert_equals( act = lv_seq exp = 9
      msg = 'Plant 1000 + DISPO asing -> Lainnya, bukan Pembahanan' ).
    cl_abap_unit_assert=>assert_equals( act = lv_in exp = abap_false ).

    zcl_cs_peg=>stn_of_order( EXPORTING iv_pwerk = '2000' iv_dispo = 'GA2'
                              IMPORTING ev_seq = lv_seq ev_in_scope = lv_in ).
    cl_abap_unit_assert=>assert_equals( act = lv_seq exp = 3 msg = 'GA2 -> Machining' ).

    zcl_cs_peg=>stn_of_order( EXPORTING iv_pwerk = '2000' iv_dispo = 'EB2'
                              IMPORTING ev_seq = lv_seq ).
    cl_abap_unit_assert=>assert_equals( act = lv_seq exp = 4 msg = 'EB2 -> Edge Banding' ).

    " DISPO di luar 7 nilai baku -> stasiun 9, in_scope false
    zcl_cs_peg=>stn_of_order( EXPORTING iv_pwerk = '2000' iv_dispo = 'ZZ9'
                              IMPORTING ev_seq = lv_seq ev_in_scope = lv_in ).
    cl_abap_unit_assert=>assert_equals( act = lv_seq exp = 9 msg = 'DISPO asing -> Lainnya' ).
    cl_abap_unit_assert=>assert_equals( act = lv_in  exp = abap_false ).
  ENDMETHOD.

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

  METHOD material_sama_beda_item.
    " Material sama dipakai dua item SO -> anak harus nyantol ke induk
    " milik ITEM-nya sendiri, bukan item tetangga.
    DATA: lt_ord TYPE zcl_cs_peg=>tt_ord, lt_res TYPE zcl_cs_peg=>tt_res,
          lt_stk TYPE zcl_cs_peg=>tt_stk, lt_mkt TYPE zcl_cs_peg=>tt_makt,
          lt_nod TYPE zcl_cs_peg=>tt_node,
          ls_o   TYPE zcl_cs_peg=>ty_ord,
          ls_r   TYPE zcl_cs_peg=>ty_res.

    " item 000010: PANEL10 <- KAKI
    ls_o = ord( iv_aufnr = 'O1' iv_matnr = 'KAKI' iv_psmng = 20
                iv_pwerk = '1000' iv_dispo = 'PN1' ).
    ls_o-kdpos = '000010'. APPEND ls_o TO lt_ord.
    ls_o = ord( iv_aufnr = 'O2' iv_matnr = 'PANEL10' iv_psmng = 4 ).
    ls_o-kdpos = '000010'. APPEND ls_o TO lt_ord.

    " item 000020: PANEL20 <- KAKI (material SAMA, order pembuat BEDA)
    ls_o = ord( iv_aufnr = 'O9' iv_matnr = 'KAKI' iv_psmng = 20
                iv_pwerk = '1000' iv_dispo = 'PN1' ).
    ls_o-kdpos = '000020'. APPEND ls_o TO lt_ord.
    ls_o = ord( iv_aufnr = 'O8' iv_matnr = 'PANEL20' iv_psmng = 4 ).
    ls_o-kdpos = '000020'. APPEND ls_o TO lt_ord.

    ls_r = res( iv_aufnr = 'O2' iv_matnr = 'KAKI' iv_bdmng = 20 ). APPEND ls_r TO lt_res.
    ls_r = res( iv_aufnr = 'O8' iv_matnr = 'KAKI' iv_bdmng = 20 ). APPEND ls_r TO lt_res.

    lt_nod = zcl_cs_peg=>assemble( it_ord = lt_ord it_res = lt_res
                                   it_stk = lt_stk it_makt = lt_mkt ).

    " anak KAKI di bawah PANEL20 harus memakai order O9, bukan O1
    DATA lv_ok TYPE abap_bool.
    LOOP AT lt_nod INTO DATA(ls_n)
      WHERE matnr = 'KAKI' AND kdpos = '000020'.
      cl_abap_unit_assert=>assert_equals( act = ls_n-aufnr exp = 'O9'
        msg = 'anak item 20 harus memakai order pembuat milik item 20' ).
      lv_ok = abap_true.
    ENDLOOP.
    cl_abap_unit_assert=>assert_equals( act = lv_ok exp = abap_true
      msg = 'anak KAKI utk item 20 harus ada di pohon' ).
  ENDMETHOD.

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
    " A memakan B, B memakan A -> keduanya "terpakai" sehingga deteksi akar
    " normal (Langkah 4 assemble) TIDAK menemukan kandidat sama sekali (K3:
    " pohon tidak boleh kosong diam-diam -> fallback Langkah 5 memperlakukan
    " SEMUA order pembuat sbg akar, lalu descend( ) yang menghentikan
    " rekursinya lewat penjaga siklus). Harus berhenti, tidak menggantung.
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

    DATA lv_ada_akar_fallback TYPE abap_bool.
    DATA lv_ada_rekursi TYPE abap_bool.
    LOOP AT lt_nod INTO DATA(ls_n).
      IF ls_n-note = 'akar tidak terdeteksi (kemungkinan siklus)'.
        lv_ada_akar_fallback = abap_true.
      ENDIF.
      IF ls_n-note = 'rekursi dihentikan'.
        lv_ada_rekursi = abap_true.
      ENDIF.
    ENDLOOP.
    cl_abap_unit_assert=>assert_equals( act = lv_ada_akar_fallback exp = abap_true
      msg = 'K3: deteksi akar normal gagal -> semua order pembuat jadi ' &&
            'akar fallback, ditandai catatannya' ).
    cl_abap_unit_assert=>assert_equals( act = lv_ada_rekursi exp = abap_true
      msg = 'penjaga siklus di descend( ) harus benar-benar tereksekusi ' &&
            'dan memutus rekursinya' ).
  ENDMETHOD.

  METHOD batas_kedalaman_dihormati.
    " Rantai lurus A11 <- A10 <- ... <- A0 (12 material, 11 tingkat
    " turunan) -- lebih dalam dari c_max_depth (10). descend( ) harus
    " memotongnya di level 10, menandai note 'batas kedalaman', dan TIDAK
    " pernah membangun simpul level 11 (A0 tidak boleh muncul).
    DATA: lt_ord TYPE zcl_cs_peg=>tt_ord, lt_res TYPE zcl_cs_peg=>tt_res,
          lt_stk TYPE zcl_cs_peg=>tt_stk, lt_mkt TYPE zcl_cs_peg=>tt_makt,
          lt_nod TYPE zcl_cs_peg=>tt_node.
    DATA: lv_i TYPE i, lv_matnr TYPE string, lv_matnr_child TYPE string,
          lv_aufnr TYPE string.

    " 12 order: O11 menghasilkan A11, O10 menghasilkan A10, ..., O0 -> A0.
    DO 12 TIMES.
      lv_i = 12 - sy-index.               " 11, 10, ..., 0
      lv_matnr = |A{ lv_i }|.
      lv_aufnr = |O{ lv_i }|.
      APPEND ord( iv_aufnr = lv_aufnr iv_matnr = lv_matnr iv_psmng = 1 )
        TO lt_ord.
    ENDDO.

    " 11 RESB: O11 memakan A10, O10 memakan A9, ..., O1 memakan A0.
    DO 11 TIMES.
      lv_i = 12 - sy-index.                " 11, 10, ..., 1
      lv_aufnr = |O{ lv_i }|.
      lv_matnr_child = |A{ lv_i - 1 }|.
      APPEND res( iv_aufnr = lv_aufnr iv_matnr = lv_matnr_child iv_bdmng = 1 )
        TO lt_res.
    ENDDO.

    lt_nod = zcl_cs_peg=>assemble( it_ord = lt_ord it_res = lt_res
                                   it_stk = lt_stk it_makt = lt_mkt ).

    DATA lv_ada_note TYPE abap_bool.
    DATA lv_max_lvl TYPE i.
    LOOP AT lt_nod INTO DATA(ls_n).
      IF ls_n-level > lv_max_lvl.
        lv_max_lvl = ls_n-level.
      ENDIF.
      IF ls_n-note = 'batas kedalaman'.
        lv_ada_note = abap_true.
      ENDIF.
    ENDLOOP.

    cl_abap_unit_assert=>assert_equals( act = lv_ada_note exp = abap_true
      msg = 'rantai > c_max_depth tingkat harus dipotong dgn note batas kedalaman' ).
    cl_abap_unit_assert=>assert_true(
      xsdbool( lv_max_lvl <= zcl_cs_peg=>c_max_depth )
      msg = 'level maksimum yang muncul tidak boleh melebihi c_max_depth' ).
  ENDMETHOD.

  METHOD akar_di_satu_item_komponen_di_lain.
    " Global Constraint (perbaikan Task 3 di luar brief): lt_used di
    " assemble( ) HARUS berkunci (matnr, kdpos) milik order PENGONSUMSI,
    " bukan matnr saja. Di sini material X adalah AKAR di item 000010
    " (tidak dikonsumsi siapa pun di item itu) tapi jadi KOMPONEN di item
    " 000020 (dikonsumsi order OY yang memproduksi Y). Kalau lt_used hanya
    " mengunci matnr, X akan salah dianggap "terpakai" secara global dan
    " kehilangan akarnya di item 000010 -- itu tepat bug yang diperbaiki.
    DATA: lt_ord TYPE zcl_cs_peg=>tt_ord, lt_res TYPE zcl_cs_peg=>tt_res,
          lt_stk TYPE zcl_cs_peg=>tt_stk, lt_mkt TYPE zcl_cs_peg=>tt_makt,
          lt_nod TYPE zcl_cs_peg=>tt_node,
          ls_o   TYPE zcl_cs_peg=>ty_ord.

    " item 000010: X diproduksi sendiri, TIDAK dikonsumsi siapa pun di
    " item ini -> X harus jadi akar.
    ls_o = ord( iv_aufnr = 'OX1' iv_matnr = 'X' iv_psmng = 5 ).
    ls_o-kdpos = '000010'. APPEND ls_o TO lt_ord.

    " item 000020: Y diproduksi order OY dan MENGONSUMSI X (RESB). Tidak
    " ada order yang memproduksi X di item 000020 -> X di sini dianggap
    " barang beli (K4), tapi kemunculannya di RESB inilah yang dulu
    " (secara salah) menandai X sebagai "terpakai" di SELURUH pohon.
    ls_o = ord( iv_aufnr = 'OY' iv_matnr = 'Y' iv_psmng = 3 ).
    ls_o-kdpos = '000020'. APPEND ls_o TO lt_ord.
    APPEND res( iv_aufnr = 'OY' iv_matnr = 'X' iv_bdmng = 3 ) TO lt_res.

    lt_nod = zcl_cs_peg=>assemble( it_ord = lt_ord it_res = lt_res
                                   it_stk = lt_stk it_makt = lt_mkt ).

    DATA lv_found TYPE abap_bool.
    LOOP AT lt_nod INTO DATA(ls_n)
      WHERE matnr = 'X' AND kdpos = '000010'.
      lv_found = abap_true.
      cl_abap_unit_assert=>assert_initial( act = ls_n-parent_key
        msg = 'X di item 000010 harus jadi AKAR (tidak punya induk)' ).
      cl_abap_unit_assert=>assert_equals( act = ls_n-level exp = 0
        msg = 'akar selalu level 0' ).
    ENDLOOP.
    cl_abap_unit_assert=>assert_equals( act = lv_found exp = abap_true
      msg = 'X harus TETAP muncul sbg akar item 000010 walau jadi ' &&
            'komponen di item 000020' ).
  ENDMETHOD.

ENDCLASS.
