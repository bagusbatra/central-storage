*&---------------------------------------------------------------------*
*& Report  ZCS_JOB_UPDATE_SO_STATUS
*&---------------------------------------------------------------------*
*& BACKGROUND JOB - dijadwalkan tiap 15 menit lewat SM36.
*&
*& Tugasnya MURNI ORKESTRASI:
*&   1. Ambil lock global (cegah 2 job jalan bersamaan)
*&   2. Cari semua SO+Item yang masih eligible dipantau
*&   3. Untuk tiap SO+Item: panggil ZCL_CS_SO_TRACER->TRACE()
*&   4. Simpan hasilnya ke ZCS_SO_STATUS (MODIFY = insert kalau baru, update kalau ada)
*&   5. Tandai SO yang sudah tidak eligible lagi sebagai CLOSED
*&   6. Lepas lock, cetak summary ke job log
*&
*& TIDAK ADA LOGIKA BISNIS di program ini. Definisi "SELESAI / BELUM SELESAI"
*& SEPENUHNYA milik ZCL_CS_SO_TRACER. Program ini cuma menanyakan dan mencatat.
*&
*& Satu-satunya tabel yang DITULIS: ZCS_SO_STATUS (milik sendiri).
*& Tabel SAP standar (VBAK/VBAP/VBUP/KNA1/AFPO/...) HANYA DIBACA.
*&
*& TIDAK ADA SELECTION-SCREEN. Program ini murni untuk background job.
*&---------------------------------------------------------------------*
REPORT zcs_job_update_so_status LINE-SIZE 200 NO STANDARD PAGE HEADING.

*&---------------------------------------------------------------------*
*& TYPES
*&---------------------------------------------------------------------*

* Satu SO+Item yang masih layak dipantau
TYPES: BEGIN OF ty_elig,
         vbeln TYPE vbak-vbeln,
         posnr TYPE vbap-posnr,
         kunnr TYPE vbak-kunnr,
         vdatu TYPE vbak-vdatu,
         name1 TYPE kna1-name1,
       END OF ty_elig.

* Sengaja NON-UNIQUE: kalau data punya anomali (duplikat vbeln+posnr), tabel
* dengan UNIQUE KEY akan bikin program DUMP saat SELECT. Lebih baik jalan terus.
TYPES: tt_elig TYPE SORTED TABLE OF ty_elig WITH NON-UNIQUE KEY vbeln posnr.

*&---------------------------------------------------------------------*
*& GLOBAL DATA
*&---------------------------------------------------------------------*
DATA: gt_elig    TYPE tt_elig,
      gv_locked  TYPE abap_bool,     " lock berhasil diambil?
      gv_us_all  TYPE i,             " total runtime seluruh job (mikrodetik)
      gv_n_ok    TYPE i,             " SO sukses ditelusuri
      gv_n_err   TYPE i,             " SO gagal (dilewati, tidak menghentikan job)
      gv_n_close TYPE i.             " SO yang baru terdeteksi closed

*&---------------------------------------------------------------------*
*& MAIN
*&---------------------------------------------------------------------*
START-OF-SELECTION.

  PERFORM run_job.

*&---------------------------------------------------------------------*
*& RUN_JOB
*&---------------------------------------------------------------------*
FORM run_job.

  DATA: lv_t1 TYPE i,
        lv_t2 TYPE i.

  GET RUN TIME FIELD lv_t1.

  WRITE: / '=== ZCS_JOB_UPDATE_SO_STATUS ==='.
  WRITE: / 'Mulai :', sy-datum, sy-uzeit, '  User:', sy-uname, '  Client:', sy-mandt.
  SKIP.

  " ---------- 1. Ambil lock ----------
  PERFORM acquire_lock.
  IF gv_locked <> abap_true.
    " Lock dipegang proses lain -> job sebelumnya kemungkinan MASIH JALAN.
    " Ini BUKAN error. Selesai baik-baik, biarkan job yang sedang jalan itu
    " menyelesaikan pekerjaannya. Job berikutnya (15 menit lagi) akan coba lagi.
    WRITE: / 'INFO: Job lain sedang berjalan (lock dipegang proses lain).'.
    WRITE: / 'INFO: Run kali ini DILEWATI supaya tidak overlap. Bukan error.'.
    WRITE: / 'INFO: Kalau ini terus terjadi, berarti 1 run butuh lebih dari 15 menit'.
    WRITE: / '      -> perlebar interval job-nya, atau kurangi jumlah SO yang dipantau.'.
    RETURN.
  ENDIF.
  WRITE: / 'Lock EZCS_SO_JOB berhasil diambil.'.

  " ---------- 2. Cari SO+Item yang eligible ----------
  PERFORM select_eligible.

  DATA: lv_cnt TYPE i.
  DESCRIBE TABLE gt_elig LINES lv_cnt.
  WRITE: / 'SO+Item eligible ditemukan:', lv_cnt LEFT-JUSTIFIED.
  SKIP.

  " ---------- 3+4. Telusuri tiap SO, simpan hasilnya ----------
  PERFORM process_eligible.

  " ---------- 5. Deteksi SO yang baru saja closed ----------
  PERFORM detect_closed.

  " ---------- 6. Lepas lock ----------
  PERFORM release_lock.

  GET RUN TIME FIELD lv_t2.
  gv_us_all = lv_t2 - lv_t1.

  PERFORM print_summary.

ENDFORM.

*&---------------------------------------------------------------------*
*& ACQUIRE_LOCK
*& Lock object EZCS_SO_JOB: parameter lock HANYA MANDT -> ini lock GLOBAL
*& per client, bukan per-baris. Artinya: hanya SATU job yang boleh jalan
*& dalam satu client pada satu waktu. Persis yang kita mau.
*&---------------------------------------------------------------------*
FORM acquire_lock.

  CLEAR gv_locked.

  " -------------------------------------------------------------------
  " CATATAN: FM ENQUEUE/DEQUEUE di-generate otomatis oleh SAP dari lock
  " object. Parameter MANDT dan MODE_ZCS_SO_STATUS punya nilai default
  " (sy-mandt dan 'E'), jadi SENGAJA TIDAK diisi -- supaya kode ini tidak
  " tergantung pada nama parameter yang bisa beda-beda.
  "
  " _SCOPE = '1' artinya: lock ini milik PROGRAM ini, dan akan dilepas oleh
  " DEQUEUE yang kita panggil sendiri (atau otomatis saat program berakhir).
  " JANGAN pakai default '2' -- itu menyerahkan lock ke update task, dan
  " program ini tidak punya update task.
  " -------------------------------------------------------------------
  CALL FUNCTION 'ENQUEUE_EZCS_SO_JOB'
    EXPORTING
      _scope         = '1'
    EXCEPTIONS
      foreign_lock   = 1
      system_failure = 2
      OTHERS         = 3.

  IF sy-subrc = 0.
    gv_locked = abap_true.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& RELEASE_LOCK
*&
*& SOAL "BAGAIMANA KALAU PROGRAM MATI MENDADAK (SHORT DUMP)?"
*& ABAP TIDAK punya event END-OF-PROGRAM, jadi tidak ada tempat untuk
*& menaruh "pembersih" seperti di bahasa lain.
*&
*& Tapi ini BUKAN masalah: dengan _SCOPE = '1', SAP otomatis melepas SEMUA
*& lock milik sebuah program begitu program itu berakhir -- termasuk kalau
*& berakhirnya karena short dump, dibunuh lewat SM50, atau server restart.
*& Lock TIDAK akan macet selamanya.
*&
*& Kalau Anda ragu lock masih nyangkut, cek manual di tcode SM12 (Display
*& and Delete Locks) -> cari lock table ZCS_SO_STATUS. Kalau ada padahal
*& tidak ada job yang jalan, boleh dihapus manual dari situ.
*&---------------------------------------------------------------------*
FORM release_lock.

  CHECK gv_locked = abap_true.

  CALL FUNCTION 'DEQUEUE_EZCS_SO_JOB'
    EXPORTING
      _scope = '1'.

  CLEAR gv_locked.
  WRITE: / 'Lock EZCS_SO_JOB dilepas.'.

ENDFORM.

*&---------------------------------------------------------------------*
*& SELECT_ELIGIBLE - cari SO+Item yang masih layak dipantau
*&---------------------------------------------------------------------*
FORM select_eligible.

  DATA: lv_maxdate TYPE sy-datum,
        lt_kunnr   TYPE STANDARD TABLE OF kna1-kunnr WITH DEFAULT KEY,
        lt_kna1    TYPE SORTED TABLE OF kna1 WITH NON-UNIQUE KEY kunnr,
        ls_kna1    TYPE kna1.

  FIELD-SYMBOLS: <fs_elig> TYPE ty_elig.

  CLEAR gt_elig.

  " Batas atas: 180 hari ke depan.
  " CATATAN: kondisi "<= hari ini + 180" OTOMATIS ikut menangkap SO yang
  " delivery date-nya SUDAH LEWAT (terlambat), karena tanggal lampau pasti
  " lebih kecil dari batas ini. Jadi TIDAK perlu batas bawah terpisah.
  lv_maxdate = sy-datum + 180.

  " -------------------------------------------------------------------
  " ASUMSI-A -> VBUP-GBSTA <> 'C'
  "   VBUP = tabel status per ITEM sales document.
  "   GBSTA = Overall processing status.
  "   Anda sudah verifikasi lewat VA03 bahwa status item SO 10478/10 = 'Open',
  "   TAPI KODE HURUFNYA belum diverifikasi.
  "
  "   >>> WAJIB DICEK: SE11 -> tabel VBUP -> field GBSTA -> double-click
  "       domainnya -> tab "Value Range" -> pastikan 'C' = "Completely
  "       processed". Biasanya: A = Not processed, B = Partially processed,
  "       C = Completely processed.
  "       Kalau di sistem Anda kodenya BEDA, ganti 'C' di bawah ini.
  "
  " ASUMSI-B -> VBAK-VDATU <= lv_maxdate
  "   VDATU = Requested delivery date. SUDAH ANDA VERIFIKASI (26.08.2026
  "   cocok dengan Req.Deliv.Date di VA03). Ini aman.
  "
  " ASUMSI-C -> VBAK-KUNNR = Sold-To Party
  "   Di SAP standar, VBAK-KUNNR memang ada dan berisi Sold-To Party.
  "   TAPI kalau saat ACTIVATE muncul error "Field KUNNR is unknown", berarti
  "   sistem Anda tidak punya field itu di VBAK. FALLBACK-nya: ambil dari
  "   tabel VBPA (partner function) dengan filter PARVW = 'AG' (= Sold-To).
  "
  "   Cara pakai fallback:
  "     1. Hapus "k~kunnr" dari SELECT list di bawah.
  "     2. Setelah SELECT ini, tambahkan:
  "
  "        DATA: lt_vbpa TYPE SORTED TABLE OF vbpa WITH NON-UNIQUE KEY vbeln,
  "              ls_vbpa TYPE vbpa.
  "        IF gt_elig IS NOT INITIAL.
  "          SELECT * FROM vbpa INTO TABLE lt_vbpa
  "            FOR ALL ENTRIES IN gt_elig
  "            WHERE vbeln = gt_elig-vbeln
  "              AND parvw = 'AG'.       " AG = Sold-To Party
  "          LOOP AT gt_elig ASSIGNING <fs_elig>.
  "            READ TABLE lt_vbpa INTO ls_vbpa
  "              WITH KEY vbeln = <fs_elig>-vbeln.
  "            IF sy-subrc = 0.
  "              <fs_elig>-kunnr = ls_vbpa-kunnr.
  "            ENDIF.
  "          ENDLOOP.
  "        ENDIF.
  "
  "   (VBPA punya POSNR juga -- partner bisa beda per item. Untuk Sold-To,
  "    biasanya cukup di level header, POSNR = '000000'.)
  " -------------------------------------------------------------------
  SELECT k~vbeln p~posnr k~kunnr k~vdatu
    FROM vbak AS k
    INNER JOIN vbap AS p ON p~vbeln = k~vbeln
    INNER JOIN vbup AS u ON u~vbeln = p~vbeln
                        AND u~posnr = p~posnr
    INTO CORRESPONDING FIELDS OF TABLE gt_elig
    WHERE u~gbsta <> 'C'
      AND k~vdatu <= lv_maxdate
      AND p~abgru = space.

  "--------------------------------------------------------------------
  " OPSIONAL - kalau Anda mau MEMBUANG item yang sudah di-reject:
  "   VBAP-ABGRU = reason for rejection. Kalau terisi, item itu dibatalkan.
  "   Tambahkan ke WHERE di atas:  AND p~abgru = space.
  "   Saya SENGAJA tidak menambahkannya karena Anda tidak memintanya --
  "   pertimbangkan sendiri apakah item yang di-reject masih perlu dipantau.
  "--------------------------------------------------------------------

  IF gt_elig IS INITIAL.
    RETURN.
  ENDIF.

  " ---------- Nama customer dari KNA1 ----------
  " Dilakukan TERPISAH (bukan LEFT OUTER JOIN) supaya SO tanpa master customer
  " tetap ikut terproses, cuma NAME1-nya kosong.
  LOOP AT gt_elig ASSIGNING <fs_elig>.
    CHECK <fs_elig>-kunnr IS NOT INITIAL.
    APPEND <fs_elig>-kunnr TO lt_kunnr.
  ENDLOOP.

  IF lt_kunnr IS NOT INITIAL.
    SORT lt_kunnr.
    DELETE ADJACENT DUPLICATES FROM lt_kunnr.

    SELECT * FROM kna1 INTO TABLE lt_kna1
      FOR ALL ENTRIES IN gt_elig
      WHERE kunnr = gt_elig-kunnr.

    LOOP AT gt_elig ASSIGNING <fs_elig>.
      CHECK <fs_elig>-kunnr IS NOT INITIAL.
      READ TABLE lt_kna1 INTO ls_kna1 WITH KEY kunnr = <fs_elig>-kunnr.
      IF sy-subrc = 0.
        <fs_elig>-name1 = ls_kna1-name1.
      ENDIF.
    ENDLOOP.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& PROCESS_ELIGIBLE - loop tiap SO, panggil class, simpan hasil
*&---------------------------------------------------------------------*
FORM process_eligible.

  DATA: lo_tracer TYPE REF TO zcl_cs_so_tracer,
        lo_err    TYPE REF TO cx_root,
        ls_elig   TYPE ty_elig,
        ls_row    TYPE zcs_so_status,
        lt_node   TYPE zcl_cs_so_tracer=>tt_node,
        lv_status TYPE char14,
        lv_total  TYPE i,
        lv_belum  TYPE i,
        lv_us     TYPE i,
        lv_msg    TYPE string,
        lv_sec    TYPE i,
        lv_ms     TYPE p DECIMALS 1,
        lv_f      TYPE f.

  CHECK gt_elig IS NOT INITIAL.

  " SATU instance saja, dipakai ulang untuk semua SO.
  " Aman: method TRACE memanggil RESET_STATE di baris pertamanya, jadi cache &
  " node dari SO sebelumnya dibersihkan. Tidak ada data nyasar antar SO.
  CREATE OBJECT lo_tracer.

  LOOP AT gt_elig INTO ls_elig.

    CLEAR: ls_row, lt_node, lv_status, lv_total, lv_belum, lv_us, lv_msg.

    " ---------- Panggil class, dibungkus jaring pengaman ----------
    " Kenapa CX_ROOT (bukan exception spesifik)? Karena TRACE memanggil FM
    " CS_BOM_EXPL_MAT_V2 dan belasan SELECT -- data yang tidak terduga bisa
    " memicu bermacam error. Satu SO bermasalah TIDAK BOLEH menghentikan
    " seluruh job.
    "
    " JUJUR SOAL BATASNYA: TRY...CATCH hanya menangkap exception yang memang
    " CATCHABLE. Short dump keras seperti TIME_OUT (job kehabisan waktu) atau
    " kehabisan memori TIDAK bisa ditangkap di sini -- job akan mati, dan lock
    " dilepas otomatis oleh SAP (lihat komentar di RELEASE_LOCK).
    TRY.
        lo_tracer->trace(
          EXPORTING
            iv_vbeln       = ls_elig-vbeln
            iv_posnr       = ls_elig-posnr
          IMPORTING
            et_node        = lt_node
            ev_status      = lv_status
            ev_total_node  = lv_total
            ev_node_belum  = lv_belum
            ev_duration_us = lv_us ).

        ADD 1 TO gv_n_ok.

        ls_row-status     = lv_status.
        ls_row-total_node = lv_total.
        ls_row-node_belum = lv_belum.
        CLEAR: ls_row-error_flag, ls_row-error_msg.

      CATCH cx_root INTO lo_err.
        ADD 1 TO gv_n_err.

        lv_msg = lo_err->get_text( ).

        " STATUS / TOTAL_NODE / NODE_BELUM sengaja DIBIARKAN KOSONG.
        " Lebih baik kosong + ditandai error, daripada mengisi angka palsu
        " yang nanti dikira orang sebagai hasil hitungan beneran.
        CLEAR: ls_row-status, ls_row-total_node, ls_row-node_belum.
        ls_row-error_flag = 'X'.
        ls_row-error_msg  = lv_msg.      " otomatis terpotong di 100 karakter

        WRITE: / 'ERROR pada SO', ls_elig-vbeln, 'item', ls_elig-posnr, ':'.
        WRITE: /   '        ', ls_row-error_msg.
    ENDTRY.

    " ---------- Susun baris untuk Z-table ----------
    ls_row-vbeln     = ls_elig-vbeln.
    ls_row-posnr     = ls_elig-posnr.
    ls_row-kunnr     = ls_elig-kunnr.
    ls_row-name1     = ls_elig-name1.
    ls_row-delv_date = ls_elig-vdatu.

    " SO ini BARU SAJA dikonfirmasi masih eligible -> aktif
    ls_row-active_flag = 'X'.
    CLEAR ls_row-closed_date.      " masih aktif, belum closed

    ls_row-run_date = sy-datum.
    ls_row-run_time = sy-uzeit.

    " mikrodetik -> detik (dibulatkan)
    lv_sec = lv_us / 1000000.
    ls_row-calc_duration = lv_sec.

    " MODIFY = update kalau key-nya sudah ada, insert kalau belum.
    " Satu-satunya tabel yang ditulis program ini.
    MODIFY zcs_so_status FROM ls_row.

    IF sy-subrc <> 0.
      WRITE: / 'GAGAL MODIFY ZCS_SO_STATUS untuk SO', ls_elig-vbeln,
               'item', ls_elig-posnr.
    ENDIF.

    " Log per SO, biar kelihatan di job log kalau ada yang lambat
    lv_f  = lv_us.
    lv_ms = lv_f / 1000.
    WRITE: / 'SO', ls_elig-vbeln, 'item', ls_elig-posnr,
             '->', lv_status,
             '| node:', lv_total LEFT-JUSTIFIED,
             '| belum:', lv_belum LEFT-JUSTIFIED,
             '|', lv_ms, 'ms'.

  ENDLOOP.

  COMMIT WORK.

ENDFORM.

*&---------------------------------------------------------------------*
*& DETECT_CLOSED - SO yang dulu aktif tapi sekarang sudah tidak eligible
*&---------------------------------------------------------------------*
FORM detect_closed.

  DATA: lt_active TYPE STANDARD TABLE OF zcs_so_status WITH DEFAULT KEY,
        ls_active TYPE zcs_so_status.

  " Semua yang MASIH ditandai aktif dari run-run sebelumnya
  SELECT * FROM zcs_so_status
    INTO TABLE lt_active
    WHERE active_flag = 'X'.

  IF lt_active IS INITIAL.
    RETURN.
  ENDIF.

  LOOP AT lt_active INTO ls_active.

    " Masih muncul di daftar eligible barusan? Kalau ya, biarkan saja.
    READ TABLE gt_elig TRANSPORTING NO FIELDS
      WITH KEY vbeln = ls_active-vbeln
               posnr = ls_active-posnr.
    CHECK sy-subrc <> 0.

    " Tidak ketemu -> SO ini sudah tidak eligible lagi (completed, atau
    " delivery date-nya sudah lewat 180 hari ke depan). Tandai closed.
    ls_active-active_flag = space.

    " HANYA isi CLOSED_DATE kalau masih kosong. Jangan menimpa tanggal yang
    " sudah tercatat dari run sebelumnya -- itu akan merusak riwayat.
    IF ls_active-closed_date IS INITIAL.
      ls_active-closed_date = sy-datum.
    ENDIF.

    MODIFY zcs_so_status FROM ls_active.
    IF sy-subrc = 0.
      ADD 1 TO gv_n_close.
      WRITE: / 'CLOSED: SO', ls_active-vbeln, 'item', ls_active-posnr,
               '-> tidak eligible lagi, ditandai closed', sy-datum.
    ENDIF.

  ENDLOOP.

  COMMIT WORK.

ENDFORM.

*&---------------------------------------------------------------------*
*& PRINT_SUMMARY - masuk ke Job Log (SM37)
*&---------------------------------------------------------------------*
FORM print_summary.

  DATA: lv_cnt TYPE i,
        lv_sec TYPE p DECIMALS 1,
        lv_f   TYPE f.

  DESCRIBE TABLE gt_elig LINES lv_cnt.

  lv_f   = gv_us_all.
  lv_sec = lv_f / 1000000.

  SKIP.
  ULINE.
  WRITE: / '=== SUMMARY ==='.
  WRITE: / 'SO+Item diproses      :', lv_cnt     LEFT-JUSTIFIED.
  WRITE: / '  sukses              :', gv_n_ok    LEFT-JUSTIFIED.
  WRITE: / '  error (dilewati)    :', gv_n_err   LEFT-JUSTIFIED.
  WRITE: / 'Baru terdeteksi CLOSED:', gv_n_close LEFT-JUSTIFIED.
  WRITE: / 'Total waktu job       :', lv_sec, 'detik'.
  WRITE: / 'Selesai               :', sy-datum, sy-uzeit.
  ULINE.

  IF gv_n_err > 0.
    WRITE: / 'PERHATIAN:', gv_n_err LEFT-JUSTIFIED,
             'SO gagal ditelusuri. Cari baris "ERROR pada SO" di atas,'.
    WRITE: / '           atau query ZCS_SO_STATUS WHERE ERROR_FLAG = ''X''.'.
  ENDIF.

ENDFORM.
