CLASS zcl_cs_so_tracer DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES: BEGIN OF ty_node,
             idx        TYPE i,
             level      TYPE i,
             ntype(12)  TYPE c,
             aufnr      TYPE aufnr,
             matnr      TYPE matnr,
             maktx      TYPE makt-maktx,
             werks      TYPE werks_d,
             dispo      TYPE dispo,
             target     TYPE menge_d,
             avail      TYPE menge_d,
             meins      TYPE meins,
             status(14) TYPE c,
             sysst(60)  TYPE c,
             stlnr      TYPE stnum,
             parent     TYPE i,
             remark(70) TYPE c,
           END OF ty_node.

    TYPES: tt_node TYPE STANDARD TABLE OF ty_node WITH DEFAULT KEY.

    METHODS trace
      IMPORTING
        iv_vbeln       TYPE vbeln_va
        iv_posnr       TYPE posnr_va
        iv_max_depth   TYPE i         DEFAULT 10
        iv_capid       TYPE capid     DEFAULT 'PP01'
        iv_stlan       TYPE stlan     DEFAULT '1'
        iv_use_omemo   TYPE abap_bool DEFAULT abap_true
        iv_use_bomc    TYPE abap_bool DEFAULT abap_true
        iv_use_cache   TYPE abap_bool DEFAULT abap_true
      EXPORTING
        et_node        TYPE tt_node
        ev_status      TYPE char14
        ev_total_node  TYPE i
        ev_node_belum  TYPE i
        ev_duration_us TYPE i.

    METHODS node_to_string
      IMPORTING
        is_node        TYPE ty_node
      RETURNING
        VALUE(rv_text) TYPE string.

  PRIVATE SECTION.

    TYPES: BEGIN OF ty_ord,
             aufnr TYPE afpo-aufnr,
             posnr TYPE afpo-posnr,
             matnr TYPE afpo-matnr,
             dwerk TYPE afpo-dwerk,
             psmng TYPE afpo-psmng,
             wemng TYPE afpo-wemng,
             meins TYPE afpo-meins,
             dispo TYPE afko-dispo,
             stlnr TYPE afko-stlnr,
             stlal TYPE afko-stlal,
             objnr TYPE aufk-objnr,
             werks TYPE aufk-werks,
             sysst(60) TYPE c,
           END OF ty_ord.
    TYPES: tt_ord TYPE STANDARD TABLE OF ty_ord WITH DEFAULT KEY.

    TYPES: tt_ord_sorted TYPE SORTED TABLE OF ty_ord WITH NON-UNIQUE KEY matnr.

    TYPES: BEGIN OF ty_comp,
             idnrk TYPE matnr,
             maktx TYPE makt-maktx,
             werks TYPE werks_d,
             menge TYPE menge_d,
             meins TYPE meins,
           END OF ty_comp.
    TYPES: tt_comp TYPE STANDARD TABLE OF ty_comp WITH DEFAULT KEY.

    TYPES: tt_path TYPE STANDARD TABLE OF matnr WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_memo,
             aufnr TYPE aufnr,
             ok    TYPE abap_bool,
             idx   TYPE i,
           END OF ty_memo.

    TYPES: BEGIN OF ty_cache_bom,
             matnr TYPE matnr,
             werks TYPE werks_d,
             capid TYPE capid,
             stlan TYPE stlan,
             qty   TYPE menge_d,
             comps TYPE tt_comp,
           END OF ty_cache_bom.

    TYPES: BEGIN OF ty_cache_stock,
             matnr TYPE matnr,
             werks TYPE werks_d,
             labst TYPE menge_d,
           END OF ty_cache_stock.

    TYPES: BEGIN OF ty_cache_makt,
             matnr TYPE matnr,
             maktx TYPE makt-maktx,
           END OF ty_cache_makt.

    DATA: mv_vbeln TYPE vbeln_va,
          mv_posnr TYPE posnr_va,
          mv_depth TYPE i,
          mv_capid TYPE capid,
          mv_stlan TYPE stlan,
          mv_omemo TYPE abap_bool,
          mv_bomc  TYPE abap_bool,
          mv_cache TYPE abap_bool.

    DATA: mt_node    TYPE tt_node,
          mv_idx     TYPE i,
          mt_all_ord TYPE tt_ord_sorted.

    DATA: mt_c_stock TYPE SORTED TABLE OF ty_cache_stock
                          WITH UNIQUE KEY matnr werks,
          mt_c_makt  TYPE SORTED TABLE OF ty_cache_makt
                          WITH UNIQUE KEY matnr,
          mt_c_order TYPE SORTED TABLE OF ty_memo
                          WITH UNIQUE KEY aufnr,
          mt_c_bom   TYPE SORTED TABLE OF ty_cache_bom
                          WITH UNIQUE KEY matnr werks capid stlan qty.

    DATA: mv_us_total TYPE i,
          mv_us_pre   TYPE i,
          mv_us_ord   TYPE i,
          mv_us_bom   TYPE i,
          mv_us_stk   TYPE i,
          mv_us_resb  TYPE i,
          mv_n_pre    TYPE i,
          mv_n_ord    TYPE i,
          mv_n_bom    TYPE i,
          mv_n_stk    TYPE i,
          mv_n_resb   TYPE i,
          mv_h_stk    TYPE i,
          mv_h_makt   TYPE i,
          mv_h_omemo  TYPE i,
          mv_h_bomc   TYPE i.

    METHODS:
      reset_state,

      preload_all_orders,

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
        RETURNING VALUE(rv_idx) TYPE i.

ENDCLASS.

CLASS zcl_cs_so_tracer IMPLEMENTATION.

  METHOD trace.

    DATA: lt_ord   TYPE tt_ord,
          ls_ord   TYPE ty_ord,
          ls_node  TYPE ty_node,
          lt_path  TYPE tt_path,
          lv_ok    TYPE abap_bool,
          lv_ord   TYPE i,
          lv_raw   TYPE i,
          lv_bad   TYPE i,
          lv_t1    TYPE i,
          lv_t2    TYPE i.

    CLEAR: et_node, ev_status, ev_total_node, ev_node_belum, ev_duration_us.

    me->reset_state( ).

    mv_vbeln = iv_vbeln.
    mv_posnr = iv_posnr.
    mv_depth = iv_max_depth.
    mv_capid = iv_capid.
    mv_stlan = iv_stlan.
    mv_omemo = iv_use_omemo.
    mv_bomc  = iv_use_bomc.
    mv_cache = iv_use_cache.

    IF mv_depth <= 0 OR mv_depth > 30.
      mv_depth = 10.
    ENDIF.

    GET RUN TIME FIELD lv_t1.

    me->preload_all_orders( ).

    me->get_orders( IMPORTING et_ord = lt_ord ).

    IF lt_ord IS NOT INITIAL.

      SORT lt_ord BY dispo ASCENDING aufnr ASCENDING.

      LOOP AT lt_ord INTO ls_ord.
        CLEAR lt_path.
        lv_ok = me->process_order( is_ord    = ls_ord
                                   iv_level  = 0
                                   iv_parent = 0
                                   it_path   = lt_path ).
      ENDLOOP.

    ENDIF.

    GET RUN TIME FIELD lv_t2.
    mv_us_total = lv_t2 - lv_t1.

    LOOP AT mt_node INTO ls_node.

      CASE ls_node-ntype.
        WHEN 'ORDER'.
          ADD 1 TO lv_ord.
          IF ls_node-status <> 'SELESAI'.
            ADD 1 TO lv_bad.
          ENDIF.

        WHEN 'BAHANBAKU'.
          ADD 1 TO lv_raw.
          IF ls_node-status <> 'TERSEDIA'.
            ADD 1 TO lv_bad.
          ENDIF.

        WHEN 'REF'.
          IF ls_node-status <> 'SELESAI'.
            ADD 1 TO lv_bad.
          ENDIF.

        WHEN OTHERS.
      ENDCASE.

    ENDLOOP.

    ev_total_node = lv_ord + lv_raw.
    ev_node_belum = lv_bad.

    IF lv_bad = 0.
      ev_status = 'SELESAI'.
    ELSE.
      ev_status = 'BELUM SELESAI'.
    ENDIF.

    ev_duration_us = mv_us_total.
    et_node        = mt_node.

  ENDMETHOD.

  METHOD reset_state.

    CLEAR: mt_node,
           mv_idx,
           mt_all_ord,
           mt_c_stock,
           mt_c_makt,
           mt_c_order,
           mt_c_bom.

    CLEAR: mv_us_total, mv_us_pre, mv_us_ord, mv_us_bom, mv_us_stk, mv_us_resb,
           mv_n_pre, mv_n_ord, mv_n_bom, mv_n_stk, mv_n_resb,
           mv_h_stk, mv_h_makt, mv_h_omemo, mv_h_bomc.

  ENDMETHOD.

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

    SELECT a~aufnr a~posnr a~matnr a~dwerk a~psmng a~wemng a~meins
           k~dispo k~stlnr k~stlal
           u~objnr u~werks
      FROM afpo AS a
      INNER JOIN afko AS k ON k~aufnr = a~aufnr
      INNER JOIN aufk AS u ON u~aufnr = a~aufnr
      INTO CORRESPONDING FIELDS OF TABLE lt_ord
      WHERE a~kdauf = mv_vbeln
        AND a~kdpos = mv_posnr
        AND u~loekz = space.

    IF lt_ord IS INITIAL.
      GET RUN TIME FIELD lv_t2.
      mv_us_pre = lv_t2 - lv_t1.
      RETURN.
    ENDIF.

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

    LOOP AT lt_ord ASSIGNING <fs_ord>.
      IF <fs_ord>-dwerk IS INITIAL.
        <fs_ord>-dwerk = <fs_ord>-werks.
      ENDIF.

      IF <fs_ord>-dispo IS INITIAL AND <fs_ord>-matnr IS NOT INITIAL.
        CLEAR lv_dispo.
        SELECT SINGLE dispo FROM marc INTO lv_dispo
          WHERE matnr = <fs_ord>-matnr
            AND werks = <fs_ord>-dwerk.
        <fs_ord>-dispo = lv_dispo.
      ENDIF.
    ENDLOOP.

    mt_all_ord = lt_ord.
    DESCRIBE TABLE mt_all_ord LINES mv_n_pre.

    GET RUN TIME FIELD lv_t2.
    mv_us_pre = lv_t2 - lv_t1.

  ENDMETHOD.

  METHOD get_orders.

    DATA: ls_ord TYPE ty_ord,
          lv_t1  TYPE i,
          lv_t2  TYPE i.

    CLEAR et_ord.
    GET RUN TIME FIELD lv_t1.
    ADD 1 TO mv_n_ord.

    IF iv_matnr IS INITIAL.
      et_ord = mt_all_ord.
    ELSE.
      LOOP AT mt_all_ord INTO ls_ord WHERE matnr = iv_matnr.
        APPEND ls_ord TO et_ord.
      ENDLOOP.
    ENDIF.

    GET RUN TIME FIELD lv_t2.
    mv_us_ord = mv_us_ord + lv_t2 - lv_t1.

  ENDMETHOD.

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
          lv_target   TYPE menge_d.

    IF mv_omemo = abap_true.
      READ TABLE mt_c_order INTO ls_memo
        WITH TABLE KEY aufnr = is_ord-aufnr.
      IF sy-subrc = 0.
        ADD 1 TO mv_h_omemo.

        CLEAR lv_idxc.
        lv_idxc = ls_memo-idx.
        CONDENSE lv_idxc.

        CLEAR ls_ref.
        ls_ref-level  = iv_level.
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

        IF ls_memo-ok = abap_true.
          ls_ref-status = 'SELESAI'.
        ELSE.
          ls_ref-status = 'BELUM SELESAI'.
        ENDIF.

        CONCATENATE 'Sudah ditelusuri di node #' lv_idxc
                    ' - lihat baris tsb untuk detail'
          INTO ls_ref-remark.

        lv_dummy = me->add_node( ls_ref ).

        rv_ok = ls_memo-ok.
        RETURN.
      ENDIF.
    ENDIF.

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

    IF is_ord-wemng >= is_ord-psmng AND is_ord-psmng > 0.
      ls_node-status = 'SELESAI'.
      rv_ok = abap_true.
    ELSE.
      ls_node-status = 'BELUM SELESAI'.
      rv_ok = abap_false.
    ENDIF.

    lv_self = me->add_node( ls_node ).

    IF iv_level >= mv_depth.
      CLEAR ls_warn.
      ls_warn-level  = iv_level + 1.
      ls_warn-ntype  = 'WARNING'.
      ls_warn-parent = lv_self.
      ls_warn-status = 'STOP'.
      ls_warn-remark = 'MAX RECURSION DEPTH TERCAPAI - penelusuran dihentikan'.
      lv_dummy = me->add_node( ls_warn ).

      RETURN.
    ENDIF.

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

      RETURN.
    ENDIF.

    lt_path = it_path.
    APPEND is_ord-matnr TO lt_path.

    me->explode_bom( EXPORTING iv_matnr = is_ord-matnr
                               iv_werks = is_ord-dwerk
                               iv_qty   = is_ord-psmng
                     IMPORTING et_comp  = lt_comp ).

    LOOP AT lt_comp INTO ls_comp.

      me->get_orders( EXPORTING iv_matnr = ls_comp-idnrk
                      IMPORTING et_ord   = lt_sub ).

      IF lt_sub IS NOT INITIAL.
        SORT lt_sub BY dispo ASCENDING aufnr ASCENDING.
        LOOP AT lt_sub INTO ls_sub.
          lv_child = me->process_order( is_ord    = ls_sub
                                        iv_level  = iv_level + 1
                                        iv_parent = lv_self
                                        it_path   = lt_path ).
          IF lv_child <> abap_true.
            rv_ok = abap_false.
          ENDIF.
        ENDLOOP.

      ELSE.
        CLEAR ls_leaf.
        ls_leaf-level  = iv_level + 1.
        ls_leaf-ntype  = 'BAHANBAKU'.
        ls_leaf-matnr  = ls_comp-idnrk.
        ls_leaf-maktx  = ls_comp-maktx.
        ls_leaf-werks  = ls_comp-werks.
        ls_leaf-meins  = ls_comp-meins.
        ls_leaf-parent = lv_self.

        lv_target = me->get_resb_qty( iv_aufnr = is_ord-aufnr
                                      iv_matnr = ls_comp-idnrk ).
        IF lv_target > 0.
          ls_leaf-target = lv_target.
        ELSE.
          ls_leaf-target = ls_comp-menge.
          ls_leaf-remark = 'Qty dari BOM (tidak ada reservation)'.
        ENDIF.

        ls_leaf-avail = me->get_stock( iv_matnr = ls_comp-idnrk
                                       iv_werks = ls_comp-werks ).

        IF ls_leaf-avail >= ls_leaf-target AND ls_leaf-target > 0.
          ls_leaf-status = 'TERSEDIA'.
        ELSE.
          ls_leaf-status = 'BELUM'.
          rv_ok = abap_false.
        ENDIF.

        lv_dummy = me->add_node( ls_leaf ).
      ENDIF.

    ENDLOOP.

    IF mv_omemo = abap_true.
      CLEAR ls_memo.
      ls_memo-aufnr = is_ord-aufnr.
      ls_memo-ok    = rv_ok.
      ls_memo-idx   = lv_self.
      INSERT ls_memo INTO TABLE mt_c_order.
    ENDIF.

  ENDMETHOD.

  METHOD explode_bom.

    DATA: ls_cbom TYPE ty_cache_bom,
          lv_t1   TYPE i,
          lv_t2   TYPE i.

    CLEAR et_comp.
    GET RUN TIME FIELD lv_t1.

    IF mv_bomc = abap_true.
      READ TABLE mt_c_bom INTO ls_cbom
        WITH TABLE KEY matnr = iv_matnr
                       werks = iv_werks
                       capid = mv_capid
                       stlan = mv_stlan
                       qty   = iv_qty.
      IF sy-subrc = 0.
        ADD 1 TO mv_h_bomc.
        et_comp = ls_cbom-comps.
        GET RUN TIME FIELD lv_t2.
        mv_us_bom = mv_us_bom + lv_t2 - lv_t1.
        RETURN.
      ENDIF.
    ENDIF.

    ADD 1 TO mv_n_bom.

    me->explode_bom_fm( EXPORTING iv_matnr = iv_matnr
                                  iv_werks = iv_werks
                                  iv_qty   = iv_qty
                        IMPORTING et_comp  = et_comp ).

    IF mv_bomc = abap_true.
      CLEAR ls_cbom.
      ls_cbom-matnr = iv_matnr.
      ls_cbom-werks = iv_werks.
      ls_cbom-capid = mv_capid.
      ls_cbom-stlan = mv_stlan.
      ls_cbom-qty   = iv_qty.
      ls_cbom-comps = et_comp.
      INSERT ls_cbom INTO TABLE mt_c_bom.
    ENDIF.

    GET RUN TIME FIELD lv_t2.
    mv_us_bom = mv_us_bom + lv_t2 - lv_t1.

  ENDMETHOD.

  METHOD explode_bom_fm.

    DATA: lt_stb    TYPE STANDARD TABLE OF stpox WITH DEFAULT KEY,
          ls_stb    TYPE stpox,
          lt_matcat TYPE STANDARD TABLE OF cscmat WITH DEFAULT KEY,
          ls_comp   TYPE ty_comp,
          lv_emeng  TYPE bstmg.

    CLEAR et_comp.

    lv_emeng = iv_qty.

    CALL FUNCTION 'CS_BOM_EXPL_MAT_V2'
      EXPORTING
        capid                 = mv_capid
        datuv                 = sy-datum
        emeng                 = lv_emeng
        mehrs                 = ' '
        mtnrv                 = iv_matnr
        stlan                 = mv_stlan
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
      RETURN.
    ENDIF.

    LOOP AT lt_stb INTO ls_stb.

      CHECK ls_stb-postp = 'L'.
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

  ENDMETHOD.

  METHOD get_stock.

    DATA: ls_cache TYPE ty_cache_stock,
          lv_labst TYPE menge_d,
          lv_t1    TYPE i,
          lv_t2    TYPE i.

    CLEAR rv_stock.

    IF mv_cache = abap_true.
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

    SELECT SUM( labst ) FROM mard INTO lv_labst
      WHERE matnr = iv_matnr
        AND werks = iv_werks.

    rv_stock = lv_labst.

    GET RUN TIME FIELD lv_t2.
    mv_us_stk = mv_us_stk + lv_t2 - lv_t1.

    IF mv_cache = abap_true.
      CLEAR ls_cache.
      ls_cache-matnr = iv_matnr.
      ls_cache-werks = iv_werks.
      ls_cache-labst = rv_stock.
      INSERT ls_cache INTO TABLE mt_c_stock.
    ENDIF.

  ENDMETHOD.

  METHOD get_resb_qty.

    DATA: lv_bdmng TYPE menge_d,
          lv_t1    TYPE i,
          lv_t2    TYPE i.

    CLEAR rv_qty.
    GET RUN TIME FIELD lv_t1.
    ADD 1 TO mv_n_resb.

    SELECT SUM( bdmng ) FROM resb INTO lv_bdmng
      WHERE aufnr = iv_aufnr
        AND matnr = iv_matnr
        AND xloek = space.

    rv_qty = lv_bdmng.

    GET RUN TIME FIELD lv_t2.
    mv_us_resb = mv_us_resb + lv_t2 - lv_t1.

  ENDMETHOD.

  METHOD get_maktx.

    DATA: ls_cache TYPE ty_cache_makt.

    CLEAR rv_maktx.
    CHECK iv_matnr IS NOT INITIAL.

    IF mv_cache = abap_true.
      READ TABLE mt_c_makt INTO ls_cache WITH TABLE KEY matnr = iv_matnr.
      IF sy-subrc = 0.
        ADD 1 TO mv_h_makt.
        rv_maktx = ls_cache-maktx.
        RETURN.
      ENDIF.
    ENDIF.

    SELECT SINGLE maktx FROM makt INTO rv_maktx
      WHERE matnr = iv_matnr
        AND spras = sy-langu.

    IF mv_cache = abap_true.
      CLEAR ls_cache.
      ls_cache-matnr = iv_matnr.
      ls_cache-maktx = rv_maktx.
      INSERT ls_cache INTO TABLE mt_c_makt.
    ENDIF.

  ENDMETHOD.

  METHOD add_node.

    DATA: ls_node TYPE ty_node.

    ADD 1 TO mv_idx.
    ls_node     = is_node.
    ls_node-idx = mv_idx.
    APPEND ls_node TO mt_node.
    rv_idx = mv_idx.

  ENDMETHOD.

  METHOD node_to_string.

    DATA: lv_idx(10)  TYPE c,
          lv_lvl(5)   TYPE c,
          lv_par(10)  TYPE c,
          lv_tgt(20)  TYPE c,
          lv_avl(20)  TYPE c,
          lv_sep(3)   TYPE c VALUE ' | '.

    lv_idx = is_node-idx.    CONDENSE lv_idx.
    lv_lvl = is_node-level.  CONDENSE lv_lvl.
    lv_par = is_node-parent. CONDENSE lv_par.

    WRITE is_node-target TO lv_tgt.  CONDENSE lv_tgt.
    WRITE is_node-avail  TO lv_avl.  CONDENSE lv_avl.

    CONCATENATE lv_idx
                lv_lvl
                is_node-ntype
                is_node-aufnr
                is_node-matnr
                is_node-maktx
                is_node-werks
                is_node-dispo
                lv_tgt
                lv_avl
                is_node-meins
                is_node-status
                is_node-sysst
                is_node-remark
                lv_par
      INTO rv_text SEPARATED BY lv_sep.

  ENDMETHOD.

ENDCLASS.
