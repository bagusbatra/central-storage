*&---------------------------------------------------------------------*
*& Report  ZTEST_CS_SO_TRACER_CLS
*&---------------------------------------------------------------------*
*& Program TEST untuk global class ZCL_CS_SO_TRACER.
*&
*& TUJUAN: membuktikan bahwa class global menghasilkan hasil YANG SAMA PERSIS
*& dengan report lama ZTEST_SO_TRACE_RECURSIVE, SEBELUM class ini dipercaya
*& dipakai di background job / BSP.
*&
*& Target pembanding (hasil report lama untuk SO 10478 / item 10):
*&   - Total node (ORDER + BAHAN BAKU) : 41
*&   - Node REF                        : 27
*&   - STATUS KESELURUHAN SO           : BELUM SELESAI
*&   - Durasi                          : sekitar 6-7 detik
*&
*& Program ini SENGAJA dibuat sesederhana mungkin: buat object, panggil TRACE,
*& loop hasilnya, cetak. Tidak ada logika bisnis apapun di sini -- SEMUA logika
*& ada di class. Kalau angka di bawah cocok, berarti refactor-nya benar.
*&
*& Sifat: PURE READ-ONLY.
*&---------------------------------------------------------------------*
REPORT ztest_cs_so_tracer_cls LINE-SIZE 400 NO STANDARD PAGE HEADING.

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE text-b01.
PARAMETERS: p_vbeln TYPE vbeln_va OBLIGATORY DEFAULT '0000010478',
            p_posnr TYPE posnr_va OBLIGATORY DEFAULT '10',
            p_depth TYPE i        DEFAULT 10.
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE text-b02.
* Semua ON = kondisi normal. Matikan salah satu untuk benchmark "sebelum vs sesudah".
PARAMETERS: p_omemo AS CHECKBOX DEFAULT 'X',   " order-level memoization
            p_bomc  AS CHECKBOX DEFAULT 'X',   " cache BOM explosion
            p_cache AS CHECKBOX DEFAULT 'X'.   " cache stok + deskripsi
SELECTION-SCREEN END OF BLOCK b2.

START-OF-SELECTION.

  DATA: lo_tracer  TYPE REF TO zcl_cs_so_tracer,
        lt_node    TYPE zcl_cs_so_tracer=>tt_node,
        ls_node    TYPE zcl_cs_so_tracer=>ty_node,
        lv_status  TYPE char14,
        lv_total   TYPE i,
        lv_belum   TYPE i,
        lv_us      TYPE i,
        lv_line    TYPE string,
        lv_ref     TYPE i,
        lv_warn    TYPE i,
        lv_ms      TYPE p DECIMALS 3,
        lv_f       TYPE f.

  CREATE OBJECT lo_tracer.

  " ---------- SATU-SATUNYA panggilan ke class ----------
  lo_tracer->trace(
    EXPORTING
      iv_vbeln       = p_vbeln
      iv_posnr       = p_posnr
      iv_max_depth   = p_depth
      iv_use_omemo   = p_omemo
      iv_use_bomc    = p_bomc
      iv_use_cache   = p_cache
    IMPORTING
      et_node        = lt_node
      ev_status      = lv_status
      ev_total_node  = lv_total
      ev_node_belum  = lv_belum
      ev_duration_us = lv_us ).

  " ---------- Cetak isi pohon ----------
  WRITE: / 'ISI ET_NODE (1 baris = 1 node, urut kemunculan):'.
  WRITE: / 'format: idx | lvl | tipe | order | material | desk | plant | mrp |',
           'target | ada | uom | status | sysstatus | remark | parent'.
  ULINE.

  LOOP AT lt_node INTO ls_node.
    lv_line = lo_tracer->node_to_string( ls_node ).
    WRITE: / lv_line.

    " hitung sendiri di sisi pemanggil, untuk mencocokkan dengan report lama
    IF ls_node-ntype = 'REF'.
      ADD 1 TO lv_ref.
    ELSEIF ls_node-ntype = 'WARNING'.
      ADD 1 TO lv_warn.
    ENDIF.
  ENDLOOP.

  ULINE.

  " ---------- Angka pembanding ----------
  SKIP.
  WRITE: / '=== HASIL (bandingkan dengan report lama ZTEST_SO_TRACE_RECURSIVE) ==='.
  SKIP.

  lv_f  = lv_us.
  lv_ms = lv_f / 1000.

  WRITE: / 'Total node (ORDER + BAHAN BAKU) :', lv_total LEFT-JUSTIFIED,
           '   <- harus 41'.
  WRITE: / 'Node REF                        :', lv_ref   LEFT-JUSTIFIED,
           '   <- harus 27'.
  WRITE: / 'Node WARNING                    :', lv_warn  LEFT-JUSTIFIED.
  WRITE: / 'Node belum selesai (incl. REF)  :', lv_belum LEFT-JUSTIFIED.
  WRITE: / 'STATUS KESELURUHAN SO           :', lv_status,
           '   <- harus BELUM SELESAI'.
  WRITE: / 'Durasi                          :', lv_ms, 'ms',
           '   <- harus sekitar 6000-7000 ms'.

  SKIP.
  IF lv_total = 41 AND lv_ref = 27 AND lv_status = 'BELUM SELESAI'.
    WRITE: / 'COCOK: class menghasilkan hasil yang sama dengan report lama.'.
  ELSE.
    WRITE: / 'TIDAK COCOK dengan angka acuan.'.
    WRITE: / 'Catatan: angka acuan (41/27/BELUM SELESAI) hanya berlaku untuk',
             'SO 10478 item 10 pada saat pengukuran dulu. Kalau Anda memakai SO',
             'lain -- atau data produksi sudah berubah sejak pengukuran itu --',
             'perbedaan ini WAJAR dan bukan berarti class-nya salah.'.
    WRITE: / 'Untuk membandingkan secara adil: jalankan ZTEST_SO_TRACE_RECURSIVE',
             'dan program ini BERURUTAN pada SO yang sama, lalu bandingkan.'.
  ENDIF.
