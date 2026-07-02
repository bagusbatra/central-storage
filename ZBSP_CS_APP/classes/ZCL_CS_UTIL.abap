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

    " Kuantitas material (base unit) untuk perhitungan dot-bar perjalanan sloc.
    TYPES ty_qty TYPE p LENGTH 15 DECIMALS 3.

    " Hasil dot-bar: 4 kelas warna titik + info tampilan. d1..d4 = kelas CSS
    " ('dot-grey'/'dot-red'/'dot-yellow'/'dot-green'). Lihat dot_stages.
    TYPES: BEGIN OF ty_dotbar,
             d1       TYPE string,       " titik 1 (2KCS→2261)
             d2       TYPE string,       " titik 2 (2261→2262)
             d3       TYPE string,       " titik 3 (22F2→22F3)
             d4       TYPE string,       " titik 4 (229K)
             pct      TYPE i,            " persen tahap frontier (0/20/40/60/80/100)
             sloc_lbl TYPE string,       " sloc terjauh yang dicapai (tooltip)
             all_done TYPE abap_bool,    " abap_true bila seluruh qty sampai 229K
           END OF ty_dotbar.

    " Range sloc untuk WHERE lgort IN ( … ) — dipakai halaman saat baca MSEG.
    TYPES ty_lgort_range TYPE RANGE OF lgort_d.

    " Kode status item produksi — satu sumber kebenaran untuk klasifikasi.
    CONSTANTS: gc_st_done   TYPE i VALUE 1,   " Selesai (GR >= target)
               gc_st_inprog TYPE i VALUE 2,   " Proses  (ada target, GR < target)
               gc_st_noprod TYPE i VALUE 3.   " Belum Produksi (tanpa order / target 0)

    " Pipeline sloc perjalanan material di Plant 2000 (URUT) + sumber 1000/1D00.
    " Satu sumber kebenaran untuk dot-bar & tab transfer/butuh-dikirim.
    CONSTANTS: gc_plant_2000 TYPE werks_d VALUE '2000',
               gc_plant_1000 TYPE werks_d VALUE '1000',
               gc_sloc_1d00  TYPE lgort_d VALUE '1D00',   " sumber (Plant 1000)
               gc_sloc_2kcs  TYPE lgort_d VALUE '2KCS',   " s0  0%  (masuk pipeline)
               gc_sloc_2261  TYPE lgort_d VALUE '2261',   " s1  20%
               gc_sloc_2262  TYPE lgort_d VALUE '2262',   " s2  40%
               gc_sloc_22f2  TYPE lgort_d VALUE '22F2',   " s3  60%
               gc_sloc_22f3  TYPE lgort_d VALUE '22F3',   " s4  80%
               gc_sloc_229k  TYPE lgort_d VALUE '229K'.   " s5  100% (akhir)

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

    "! Range 6 sloc pipeline Plant 2000 (URUT 2KCS..229K) untuk WHERE lgort IN.
    "! Dipakai halaman saat SELECT MSEG penerimaan antar-sloc.
    CLASS-METHODS pipeline_slocs
      RETURNING VALUE(rt_lgort) TYPE ty_lgort_range.

    "! Dot-bar perjalanan material melewati sloc Plant 2000
    "! (2KCS→2261→2262→22F2→22F3→229K). Memetakan qty NET yang PERNAH MASUK tiap
    "! sloc → 4 kelas warna titik. Lihat plan-monitoring-bom-dotbar.md.
    "!
    "! MODEL: reached[s] = max( qty_masuk_s , reached[s+1] ) — kumulatif dari hilir,
    "! monotonik & tahan anomali; berarti "qty yang pernah mencapai minimal tahap s".
    "! Acuan penuh R = qty masuk 2KCS (dinaikkan bila hilir lebih besar). Tiap tahap
    "! HIJAU bila reached>=R (seluruh qty lewat), KUNING bila sebagian, ABU bila 0.
    "! Berbasis HISTORI (bukan stok kini) → material yang sudah melewati 229K tetap
    "! 4 hijau walau stok sudah pindah lagi.
    "!
    "! PENTING: pemanggil bertanggung jawab menghitung iv_q_* = penerimaan NET ke
    "! tiap sloc (net reversal SHKZG saja, BUKAN dikurangi arus keluar ke hilir).
    "! Semantik gerakan (mvt 311? arah SHKZG?) diverifikasi di halaman (Fase 0).
    "!
    "! @parameter iv_q_2kcs  | Qty net masuk 2KCS (acuan pipeline / 100%)
    "! @parameter iv_q_2261  | Qty net masuk 2261
    "! @parameter iv_q_2262  | Qty net masuk 2262
    "! @parameter iv_q_22f2  | Qty net masuk 22F2
    "! @parameter iv_q_22f3  | Qty net masuk 22F3
    "! @parameter iv_q_229k  | Qty net masuk 229K
    "! @parameter iv_at_1d00 | abap_true bila material masih ada di 1000/1D00
    "!                         (menentukan titik-1 MERAH saat belum masuk 2KCS)
    "! @parameter rs_dot     | Kelas warna 4 titik + info tampilan (ty_dotbar)
    CLASS-METHODS dot_stages
      IMPORTING iv_q_2kcs     TYPE ty_qty
                iv_q_2261     TYPE ty_qty
                iv_q_2262     TYPE ty_qty
                iv_q_22f2     TYPE ty_qty
                iv_q_22f3     TYPE ty_qty
                iv_q_229k     TYPE ty_qty
                iv_at_1d00    TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(rs_dot) TYPE ty_dotbar.

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

  METHOD pipeline_slocs.
    DATA ls_r LIKE LINE OF rt_lgort.
    ls_r-sign = 'I'. ls_r-option = 'EQ'.
    ls_r-low = gc_sloc_2kcs. APPEND ls_r TO rt_lgort.
    ls_r-low = gc_sloc_2261. APPEND ls_r TO rt_lgort.
    ls_r-low = gc_sloc_2262. APPEND ls_r TO rt_lgort.
    ls_r-low = gc_sloc_22f2. APPEND ls_r TO rt_lgort.
    ls_r-low = gc_sloc_22f3. APPEND ls_r TO rt_lgort.
    ls_r-low = gc_sloc_229k. APPEND ls_r TO rt_lgort.
  ENDMETHOD.

  METHOD dot_stages.
    DATA: lv_r     TYPE ty_qty,   " acuan penuh (qty masuk 2KCS, dinaikkan bila hilir >)
          lv_r2261 TYPE ty_qty,   " reached[2261] = pernah mencapai minimal 2261
          lv_r2262 TYPE ty_qty,
          lv_r22f2 TYPE ty_qty,
          lv_r22f3 TYPE ty_qty,
          lv_r229k TYPE ty_qty.

    " Kumulatif "pernah mencapai minimal tahap ini" dari hilir ke hulu.
    " qty hilir yang lebih besar menyiratkan qty itu pasti sudah melewati tahap hulu.
    lv_r229k = iv_q_229k.
    lv_r22f3 = iv_q_22f3. IF lv_r229k > lv_r22f3. lv_r22f3 = lv_r229k. ENDIF.
    lv_r22f2 = iv_q_22f2. IF lv_r22f3 > lv_r22f2. lv_r22f2 = lv_r22f3. ENDIF.
    lv_r2262 = iv_q_2262. IF lv_r22f2 > lv_r2262. lv_r2262 = lv_r22f2. ENDIF.
    lv_r2261 = iv_q_2261. IF lv_r2262 > lv_r2261. lv_r2261 = lv_r2262. ENDIF.
    lv_r     = iv_q_2kcs. IF lv_r2261 > lv_r.     lv_r     = lv_r2261. ENDIF.

    " Default: semua abu-abu.
    rs_dot-d1 = 'dot-grey'. rs_dot-d2 = 'dot-grey'.
    rs_dot-d3 = 'dot-grey'. rs_dot-d4 = 'dot-grey'.
    rs_dot-pct = 0.

    " Belum pernah masuk 2KCS → titik-1 merah bila masih di 1D00, sisanya abu.
    IF lv_r <= 0.
      IF iv_at_1d00 = abap_true.
        rs_dot-d1       = 'dot-red'.
        rs_dot-sloc_lbl = '1D00'.
      ENDIF.
      RETURN.
    ENDIF.

    " Titik 1 (2KCS→2261): hijau bila SELURUH qty maju ke 2261; else kuning.
    IF lv_r2261 >= lv_r. rs_dot-d1 = 'dot-green'.
    ELSE.                rs_dot-d1 = 'dot-yellow'.
    ENDIF.

    " Titik 2 (2261→2262): hijau bila penuh di 2262; kuning bila sebagian di 2261.
    IF     lv_r2262 >= lv_r. rs_dot-d2 = 'dot-green'.
    ELSEIF lv_r2261 >  0.    rs_dot-d2 = 'dot-yellow'.
    ENDIF.

    " Titik 3 (22F2→22F3): hijau bila penuh di 22F3; kuning bila sebagian di 22F2.
    IF     lv_r22f3 >= lv_r. rs_dot-d3 = 'dot-green'.
    ELSEIF lv_r22f2 >  0.    rs_dot-d3 = 'dot-yellow'.
    ENDIF.

    " Titik 4 (229K): hijau bila penuh di 229K; kuning bila sebagian di 229K.
    IF     lv_r229k >= lv_r. rs_dot-d4 = 'dot-green'.
    ELSEIF lv_r229k >  0.    rs_dot-d4 = 'dot-yellow'.
    ENDIF.

    rs_dot-all_done = boolc( lv_r229k >= lv_r ).

    " Frontier (posisi terjauh) untuk label & persen tahap (tooltip).
    IF     lv_r229k > 0. rs_dot-pct = 100. rs_dot-sloc_lbl = '229K'.
    ELSEIF lv_r22f3 > 0. rs_dot-pct = 80.  rs_dot-sloc_lbl = '22F3'.
    ELSEIF lv_r22f2 > 0. rs_dot-pct = 60.  rs_dot-sloc_lbl = '22F2'.
    ELSEIF lv_r2262 > 0. rs_dot-pct = 40.  rs_dot-sloc_lbl = '2262'.
    ELSEIF lv_r2261 > 0. rs_dot-pct = 20.  rs_dot-sloc_lbl = '2261'.
    ELSE.                rs_dot-pct = 0.   rs_dot-sloc_lbl = '2KCS'.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
