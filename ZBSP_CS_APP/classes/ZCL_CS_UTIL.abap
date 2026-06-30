*&---------------------------------------------------------------------*
*& Global Class ZCL_CS_UTIL — Helper Central Storage Dashboard
*&---------------------------------------------------------------------*
*& PENTING (deployment):
*&  - Ini adalah SUMBER class global. Buat & aktifkan di SE24 (atau ADT)
*&    dengan nama ZCL_CS_UTIL SEBELUM mengaktifkan halaman BSP, karena
*&    monitoring.htm & monitoring_detail.htm memanggilnya.
*&  - Tetapkan ke package & transport yang sama dengan ZBSP_CS_APP.
*&
*& Tujuan (D1): satu sumber kebenaran untuk pemetaan persentase progres
*& ke kelas warna CSS, menggantikan logika 100/70/45/20 yang sebelumnya
*& diduplikasi di 4 titik ABAP. Ambang & warna cukup diubah di sini.
*&
*& Catatan: kasus "belum produksi" (prog-black / txt-black) bersifat
*& kontekstual (psmng=0 / semua item noprod) dan tetap ditangani pemanggil;
*& method di sini murni memetakan persentase → warna untuk item ber-produksi.
*&---------------------------------------------------------------------*
CLASS zcl_cs_util DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    " Persentase progres 0..100(+); presisi 2 desimal cukup untuk ambang.
    TYPES ty_pct TYPE p LENGTH 8 DECIMALS 2.

    " Kode status item produksi — satu sumber kebenaran untuk klasifikasi.
    CONSTANTS: gc_st_done   TYPE i VALUE 1,   " Selesai (GR >= target)
               gc_st_inprog TYPE i VALUE 2,   " Proses  (ada target, GR < target)
               gc_st_noprod TYPE i VALUE 3.   " Belum Produksi (tanpa order / target 0)

    "! Klasifikasi status item dari TOTAL target & TOTAL GR (sudah diagregasi
    "! per item SO — satu item bisa punya >1 order produksi). Pastikan
    "! iv_psmng/iv_wemng adalah JUMLAH seluruh order produksi item tsb.
    "! psmng>0 & GR>=target → done | psmng>0 & GR<target → inprog | else noprod.
    CLASS-METHODS item_status
      IMPORTING iv_psmng       TYPE afpo-psmng
                iv_wemng       TYPE afpo-wemng
      RETURNING VALUE(rv_code) TYPE i.

    "! Persentase progres SATU item = wemng/psmng*100, dibatasi maks 100.
    "! psmng=0 (belum produksi) → 0. Dipakai untuk MERATA-RATA progres per SO
    "! (jumlahkan hasil ini lalu bagi jumlah item) — bukan rasio done/total.
    CLASS-METHODS item_pct
      IMPORTING iv_psmng      TYPE afpo-psmng
                iv_wemng      TYPE afpo-wemng
      RETURNING VALUE(rv_pct) TYPE ty_pct.

    "! Persentase → string lebar CSS yang aman lokal: dibatasi 0..100, dan
    "! pemisah desimal DIPAKSA titik (mencegah "width:66,7%" yang invalid di
    "! sistem dgn notasi koma). Dipakai pada style="width:...%".
    CLASS-METHODS css_pct
      IMPORTING iv_pct         TYPE ty_pct
      RETURNING VALUE(rv_text) TYPE string.

    "! Kelas warna BAR progres dari persentase.
    "! >=100 prog-green | >70 prog-blue | >45 prog-yellow | >20 prog-orange | else prog-red
    CLASS-METHODS prog_bar_class
      IMPORTING iv_pct          TYPE ty_pct
      RETURNING VALUE(rv_class) TYPE string.

    "! Kelas warna TEKS persentase, selaras dengan prog_bar_class.
    "! >=100 txt-green | >70 txt-blue | >45/ >20 txt-amber | else txt-red
    CLASS-METHODS prog_txt_class
      IMPORTING iv_pct          TYPE ty_pct
      RETURNING VALUE(rv_class) TYPE string.

    "! Format DATS (YYYYMMDD) → 'DD/MM/YYYY'. Tanggal kosong → string kosong. (D6)
    CLASS-METHODS fmt_date
      IMPORTING iv_date        TYPE d
      RETURNING VALUE(rv_text) TYPE string.

ENDCLASS.

CLASS zcl_cs_util IMPLEMENTATION.

  METHOD item_status.
    DATA lv_pct TYPE ty_pct.
    IF iv_psmng > 0.
      lv_pct = iv_wemng * 100 / iv_psmng.
      IF lv_pct >= 100. rv_code = gc_st_done.
      ELSE.             rv_code = gc_st_inprog.
      ENDIF.
    ELSE.
      rv_code = gc_st_noprod.
    ENDIF.
  ENDMETHOD.

  METHOD item_pct.
    IF iv_psmng > 0.
      rv_pct = iv_wemng * 100 / iv_psmng.
      IF rv_pct > 100. rv_pct = 100. ENDIF.
    ELSE.
      rv_pct = 0.
    ENDIF.
  ENDMETHOD.

  METHOD css_pct.
    DATA lv_w TYPE ty_pct.
    lv_w = iv_pct.
    IF lv_w > 100. lv_w = 100. ENDIF.
    IF lv_w < 0.   lv_w = 0.   ENDIF.
    rv_text = lv_w.
    REPLACE ALL OCCURRENCES OF ',' IN rv_text WITH '.'.
    CONDENSE rv_text.
  ENDMETHOD.

  METHOD prog_bar_class.
    IF     iv_pct >= 100. rv_class = 'prog-green'.
    ELSEIF iv_pct >  70.  rv_class = 'prog-blue'.
    ELSEIF iv_pct >  45.  rv_class = 'prog-yellow'.
    ELSEIF iv_pct >  20.  rv_class = 'prog-orange'.
    ELSE.                 rv_class = 'prog-red'.
    ENDIF.
  ENDMETHOD.

  METHOD prog_txt_class.
    IF     iv_pct >= 100. rv_class = 'txt-green'.
    ELSEIF iv_pct >  70.  rv_class = 'txt-blue'.
    ELSEIF iv_pct >  45.  rv_class = 'txt-amber'.
    ELSEIF iv_pct >  20.  rv_class = 'txt-amber'.
    ELSE.                 rv_class = 'txt-red'.
    ENDIF.
  ENDMETHOD.

  METHOD fmt_date.
    IF iv_date IS INITIAL.
      RETURN.
    ENDIF.
    rv_text = iv_date+6(2) && '/' && iv_date+4(2) && '/' && iv_date(4).
  ENDMETHOD.

ENDCLASS.
