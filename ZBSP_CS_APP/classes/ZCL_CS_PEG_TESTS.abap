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
             material_sama_beda_item FOR TESTING.
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

ENDCLASS.
