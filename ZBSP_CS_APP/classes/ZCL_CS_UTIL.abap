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
*&
*&---------------------------------------------------------------------*
*& REVISI FASE-1 (Checkpoint Engine) — pipeline FINAL 4 titik
*&---------------------------------------------------------------------*
*& Hasil diagnostik diag_movement.htm (section B2 & D) mengunci mapping berikut.
*& 22F2 & 22F3 TERBUKTI BUKAN rute Wood Furniture → DIKELUARKAN dari pipeline.
*&
*&   CP1 "Diterima 2KCS"    : net masuk lgort=2KCS (301/311, SHKZG 'S') dari Plant
*&                            1000 mana pun, DIKURANGI 'H' keluar balik ke 1000.
*&   CP2 "Masuk Machining"  : net masuk lgort=2261 dgn umlgo=2KCS (301/311).
*&   CP3 "Keluar Machining" : GR bwart 101 di lgort=2262 (SHKZG 'S'), order-nya
*&                            harus lolos whitelist WF (wf_order_filter).
*&   CP4 "Selesai (229K)"   : net masuk lgort=229K dari SUMBER MANAPUN (umlgo apa
*&                            saja; 229K menerima dari 2262/22E2/2291/2292/2293/…),
*&                            301/311 'S', DIKURANGI 'H' keluar dari 229K.
*&
*& ATURAN GLOBAL: bwart '321' SELALU di-exclude — itu pelepasan Quality Inspection
*& (lgort = umlgo pada baris tsb), bukan perpindahan fisik.
*&
*& "SELESAI" kini berbasis CP4, bukan lagi AFPO GR% (wemng>=psmng):
*&   item SO selesai  ⇔  SETIAP komponen (RESB) punya net qty 229K >= bdmng-nya.
*& Mesinnya: item_cp_status( ) — dipanggil index/monitoring/riwayat/monitoring_detail.
*& item_status( )/item_pct( ) yang lama SUDAH DIHAPUS agar tak ada definisi ganda.
*&
*&---------------------------------------------------------------------*
*& REVISI FASE-2 — QTY PIPELINE DIPILAH PER SO+ITEM (bukan lagi per material)
*&---------------------------------------------------------------------*
*& Batas lama ("qty 229K per material & global → angka = BATAS ATAS") SUDAH TIDAK
*& BERLAKU. Diagnostik diag_movement section E membuktikan: 99.9% baris transfer
*& pipeline (301/311) membawa KDAUF + KDPOS + SOBKZ='E' (sales-order stock /
*& make-to-order). Artinya tiap gerakan TAHU miliknya SO+item mana.
*&
*& Seluruh qty checkpoint kini dihitung oleh SATU mesin: cp_qty( ), yang memfilter
*&   kdauf = SO, kdpos = item SO, sobkz = 'E'
*& pada keempat checkpoint. Tidak ada lagi angka "milik material" yang dipakai
*& bersama beberapa SO.
*&
*& 0.1% SISANYA (baris tanpa KDAUF / bukan SOBKZ 'E' = stok anonim) TIDAK
*& di-fallback diam-diam ke perhitungan global lama — itu akan mengembalikan
*& masalah "batas atas" tanpa disadari pemakai. Material seperti itu ditandai
*& nodata → dot-bar ABU-ABU "Data Tidak Lengkap", dan itemnya berstatus
*& gc_st_nodata (BUKAN done, BUKAN diam-diam "belum produksi").
*&
*& ⚠️ KONSEKUENSI YANG BELUM DIKERJAKAN: SOBKZ='E' berarti stok fisiknya ada di
*& MSKA (per SO+item), BUKAN MARD. Semua pembacaan stok di app ini (SLoc Terkini,
*& Stok 2KCS/1D00 di transfer.htm, flag iv_at_1d00) masih memakai MARD → berpotensi
*& nol/tak lengkap. BELUM diverifikasi & BELUM diperbaiki — jangan anggap benar.
*&---------------------------------------------------------------------*
*& REVISI FASE-3 (D7, v2) — pmb_output_status( ): nasib MATERIAL KOMPONEN
*&---------------------------------------------------------------------*
*& Dipakai monitoring_bom.htm tab "Butuh Dikirim" (mode=kirim), TIAP baris
*& material komponen (bukan hanya yang order-nya 100%) — pengguna ingin tahu
*& nasib FISIK material itu: sudah GR berapa, masih di QC berapa, sudah
*& dikonsumsi ke proses lanjutan berapa (dan oleh order mana), sudah dikirim
*& fisik ke SLoc lain berapa (dan ke mana), sisa tersedia berapa.
*&
*& v1 (dihapus) keliru men-scope ke AUFNR order & threshold 100% AFPO-WEMNG.
*& Bukti dari user (MB51/MB52 riil): AFPO-WEMNG order (mis. 67/192 = 34.9%)
*& TIDAK merepresentasikan qty GR aktual material (yang ternyata sudah 192,
*& 100% GR + 100% lolos QC) — keduanya basis data BEDA (AFPO header vs MSEG
*& histori riil). v2 TIDAK LAGI bergantung pada AFPO-PSMNG/WEMNG SAMA SEKALI;
*& murni menelusuri MSEG milik MATERIAL KOMPONEN itu, discope SO+item+
*& SOBKZ='E' (pola sama dgn cp_qty), dan SELALU dihitung/ditampilkan apa pun
*& progres order-nya.
*&
*& Ditelusuri dari MSEG⨝MKPF, key = (kdauf, kdpos, matnr KOMPONEN):
*&   1) GR (bwart 101)     : SHKZG 'S' menambah qty_gr; INSMK='X' → qty_qc,
*&                           selain itu → qty_wait. src_lgort = LGORT baris ini.
*&   2) QI release (321)   : baris SHKZG 'H' sebesar MENGE → qty_qc dikurangi,
*&                           qty_wait ditambah.
*&   3) Konsumsi (261)     : GOODS ISSUE ke order LAIN (bukan transfer
*&                           lokasi!) di src_lgort, baris SHKZG 'H' →
*&                           qty_wait dikurangi, qty_used ditambah.
*&                           Order konsumen = MSEG-AUFNR baris 261 itu
*&                           SENDIRI (field ini memang terisi utk goods
*&                           issue ke order — tak perlu ditelusuri lewat
*&                           RESB-RSNUM).
*&   4) Transfer (301/311) : baris SHKZG 'H' DI src_lgort → qty_wait dikurangi,
*&                           qty_sent ditambah; UMLGO/UMWRK = tujuan (t_dest).
*&
*& qty_gr = qty_qc + qty_wait + qty_used + qty_sent (kira-kira; retur/pembulatan
*& bisa membuat sedikit meleset, sudah dijepit non-negatif per kategori).
*&---------------------------------------------------------------------*
CLASS zcl_cs_util DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    " Persentase progres 0..100(+); presisi 2 desimal cukup untuk ambang.
    TYPES ty_pct TYPE p LENGTH 8 DECIMALS 2.

    " Kuantitas material (base unit) untuk perhitungan dot-bar perjalanan sloc.
    TYPES ty_qty TYPE p LENGTH 15 DECIMALS 3.

    " Hasil dot-bar: 4 kelas warna titik + info tampilan. d1..d4 = kelas CSS
    " ('dot-grey'/'dot-red'/'dot-yellow'/'dot-green'). Lihat dot_stages.
    " d1..d4 = CP1..CP4 pipeline final (2KCS / 2261 / 2262-GR / 229K).
    TYPES: BEGIN OF ty_dotbar,
             d1       TYPE string,       " CP1 Diterima 2KCS
             d2       TYPE string,       " CP2 Masuk Machining (2261)
             d3       TYPE string,       " CP3 Keluar Machining (GR 101 @2262)
             d4       TYPE string,       " CP4 Selesai (229K)
             pct      TYPE i,            " persen tahap frontier (0/25/50/75/100)
             sloc_lbl TYPE string,       " checkpoint terjauh yang dicapai (tooltip)
             all_done TYPE abap_bool,    " abap_true bila qty acuan penuh sampai 229K
             " DATA TIDAK LENGKAP: material ini punya gerakan pipeline TANPA
             " KDAUF/SOBKZ='E' → qty-nya tak bisa dipilah per SO. 4 titik ABU,
             " pct 0. SENGAJA tidak jatuh balik ke angka global (lihat header).
             nodata   TYPE abap_bool,
             note     TYPE string,       " alasan, untuk tooltip
           END OF ty_dotbar.

    " Range sloc untuk WHERE lgort IN ( … ) — dipakai halaman saat baca MSEG.
    TYPES ty_lgort_range TYPE RANGE OF lgort_d.

    " Range movement type untuk WHERE bwart IN ( … ).
    TYPES ty_bwart_range TYPE RANGE OF bwart.

    " Range MRP controller (AFKO-DISPO) untuk WHERE dispo IN ( … ) — scope 3 tahap
    " Wood Furniture (Pembahanan / Produksi / Finish). Lihat wf_dispo_range( ).
    TYPES ty_dispo_range TYPE RANGE OF afko-dispo.

    " Daftar order untuk wf_order_filter (in & out). SORTED+UNIQUE → pemanggil bisa
    " READ TABLE … WITH TABLE KEY aufnr tanpa SORT/dedup sendiri.
    TYPES: BEGIN OF ty_aufnr_line,
             aufnr TYPE aufnr,
           END OF ty_aufnr_line.
    TYPES ty_aufnr_tab TYPE SORTED TABLE OF ty_aufnr_line WITH UNIQUE KEY aufnr.

    " INPUT item_cp_status: baris AFPO MENTAH (per order, belum diagregasi).
    " Satu item SO (kdauf/kdpos) boleh muncul >1 kali bila punya >1 order produksi.
    TYPES: BEGIN OF ty_itm_line,
             kdauf TYPE afpo-kdauf,
             kdpos TYPE afpo-kdpos,
             aufnr TYPE afpo-aufnr,
           END OF ty_itm_line.
    TYPES ty_itm_tab TYPE TABLE OF ty_itm_line.

    " === MESIN QTY CHECKPOINT (cp_qty) — per SO+ITEM+MATERIAL ===
    " INPUT: satu baris per (item SO, komponen). need = SUM(RESB-BDMNG) komponen itu.
    TYPES: BEGIN OF ty_cpkey,
             kdauf TYPE afpo-kdauf,
             kdpos TYPE afpo-kdpos,
             matnr TYPE resb-matnr,
             need  TYPE ty_qty,
           END OF ty_cpkey.
    TYPES ty_cpkey_tab TYPE SORTED TABLE OF ty_cpkey
                       WITH UNIQUE KEY kdauf kdpos matnr.

    " INPUT tambahan: peta order → item SO. Dipakai HANYA untuk baris GR 101 yang
    " KDAUF-nya kosong — baris itu masih bisa diikat ke item lewat AUFNR (cara lama).
    TYPES: BEGIN OF ty_ordmap,
             aufnr TYPE afpo-aufnr,
             kdauf TYPE afpo-kdauf,
             kdpos TYPE afpo-kdpos,
           END OF ty_ordmap.
    TYPES ty_ordmap_tab TYPE SORTED TABLE OF ty_ordmap WITH UNIQUE KEY aufnr.

    " OUTPUT cp_qty: qty NET tiap checkpoint, sudah ter-scope ke SO+item ini.
    TYPES: BEGIN OF ty_cpqty,
             kdauf   TYPE afpo-kdauf,
             kdpos   TYPE afpo-kdpos,
             matnr   TYPE resb-matnr,
             need    TYPE ty_qty,
             q2kcs   TYPE ty_qty,    " CP1
             q2261   TYPE ty_qty,    " CP2
             q2262   TYPE ty_qty,    " CP3 (GR 101)
             q229k   TYPE ty_qty,    " CP4
             last_in TYPE d,         " budat TERAKHIR masuk 229K ('S') — utk fin_date
             " abap_true bila material ini punya gerakan pipeline TANPA kdauf atau
             " bukan SOBKZ='E' → qty tak bisa dipilah per SO → JANGAN dipercaya.
             nodata  TYPE abap_bool,
           END OF ty_cpqty.
    TYPES ty_cpqty_tab TYPE SORTED TABLE OF ty_cpqty
                       WITH UNIQUE KEY kdauf kdpos matnr.

    " OUTPUT item_cp_status: status "selesai" per item SO, basis checkpoint 229K.
    TYPES: BEGIN OF ty_itmcp_line,
             kdauf    TYPE afpo-kdauf,
             kdpos    TYPE afpo-kdpos,
             code     TYPE i,        " gc_st_done/inprog/noprod/nodata
             pct      TYPE ty_pct,   " rata-rata progres komponen (0..100)
             tot_cmp  TYPE i,        " jumlah komponen (material unik) item ini
             done_cmp TYPE i,        " komponen yang sudah terpenuhi di 229K
             nodat_cmp TYPE i,       " komponen yang datanya tak bisa dipilah per SO
             " TANGGAL SELESAI AKTUAL (MKPF-BUDAT) = saat komponen TERAKHIR sampai
             " 229K → dipakai OTD & lead time, MENGGANTIKAN "tanggal GR 101 terakhir".
             " Hanya diisi bila code = gc_st_done. Item belum selesai → kosong.
             fin_date TYPE d,
           END OF ty_itmcp_line.
    TYPES ty_itmcp_tab TYPE SORTED TABLE OF ty_itmcp_line WITH UNIQUE KEY kdauf kdpos.

    " === D7 (v2): pmb_output_status — nasib fisik MATERIAL KOMPONEN =========
    " INPUT: satu baris per (item SO, material komponen) yang mau ditelusuri.
    " Key SENGAJA berbasis MATERIAL, BUKAN aufnr — status ini tentang nasib
    " material itu sendiri (bisa muncul di >1 order komponen), TIDAK bergantung
    " pada AFPO-PSMNG/WEMNG order manapun (lihat catatan v1→v2 di header).
    TYPES: BEGIN OF ty_pmbkey,
             kdauf TYPE afpo-kdauf,
             kdpos TYPE afpo-kdpos,
             matnr TYPE resb-matnr,
           END OF ty_pmbkey.
    TYPES ty_pmbkey_tab TYPE SORTED TABLE OF ty_pmbkey WITH UNIQUE KEY kdauf kdpos matnr.

    " Satu baris tujuan pengiriman fisik (301/311) — bisa >1 bila dikirim ke
    " lebih dari 1 SLoc.
    TYPES: BEGIN OF ty_pmbdest,
             werks   TYPE mseg-umwrk,
             lgort   TYPE mseg-lgort,
             qty     TYPE ty_qty,
             last_dt TYPE d,
           END OF ty_pmbdest.
    TYPES ty_pmbdest_tab TYPE STANDARD TABLE OF ty_pmbdest WITH DEFAULT KEY.

    " Satu baris order TUJUAN KONSUMSI (261, goods issue ke reservasi order
    " lain) — bisa >1 bila dikonsumsi bertahap oleh order yang sama atau beda.
    TYPES: BEGIN OF ty_pmbused,
             aufnr   TYPE resb-aufnr,
             qty     TYPE ty_qty,
             last_dt TYPE d,
           END OF ty_pmbused.
    TYPES ty_pmbused_tab TYPE STANDARD TABLE OF ty_pmbused WITH DEFAULT KEY.

    " OUTPUT pmb_output_status: qty_qc + qty_wait + qty_used + qty_sent SEHARUSNYA
    " ≈ qty_gr (bisa sedikit meleset krn retur/pembulatan, sudah dijepit ≥0).
    TYPES: BEGIN OF ty_pmbstatus,
             kdauf     TYPE afpo-kdauf,
             kdpos     TYPE afpo-kdpos,
             matnr     TYPE resb-matnr,
             src_lgort TYPE mseg-lgort,     " SLoc penerimaan GR (kosong bila blm GR)
             qty_gr    TYPE ty_qty,         " total pernah di-GR (konteks/cross-check)
             qty_qc    TYPE ty_qty,         " masih di Quality Inspection
             qty_wait  TYPE ty_qty,         " tersedia (unrestricted), blm dipakai/kirim
             qty_used  TYPE ty_qty,         " sudah dikonsumsi (GI 261) ke order lanjutan
             qty_sent  TYPE ty_qty,         " sudah ditransfer fisik (301/311)
             t_used    TYPE ty_pmbused_tab, " rincian order yg mengkonsumsi
             t_dest    TYPE ty_pmbdest_tab, " rincian tujuan pengiriman fisik
           END OF ty_pmbstatus.
    TYPES ty_pmbstatus_tab TYPE SORTED TABLE OF ty_pmbstatus WITH UNIQUE KEY kdauf kdpos matnr.

    " Kode status item produksi — satu sumber kebenaran untuk klasifikasi.
    " ⚠️ gc_st_nodata WAJIB ditangani EKSPLISIT oleh pemanggil. Kalau dibiarkan
    " jatuh ke "WHEN OTHERS" (= Belum Produksi), item yang datanya bermasalah akan
    " terlihat seperti item normal yang belum mulai — persis penyesatan yang mau
    " dihindari. Tampilkan sebagai "Data Tidak Lengkap" (abu-abu).
    CONSTANTS: gc_st_done   TYPE i VALUE 1,   " Selesai (semua komponen sampai 229K)
               gc_st_inprog TYPE i VALUE 2,   " Proses  (ada kebutuhan, belum penuh)
               gc_st_noprod TYPE i VALUE 3,   " Belum Produksi (tanpa order/komponen)
               gc_st_nodata TYPE i VALUE 4.   " Data Tidak Lengkap (gerakan tanpa KDAUF/SOBKZ E)

    " Pipeline sloc perjalanan material di Plant 2000 (URUT) + sumber 1000/1D00.
    " Satu sumber kebenaran untuk dot-bar & tab transfer/butuh-dikirim.
    " PIPELINE FINAL = 4 CHECKPOINT: 2KCS → 2261 → 2262(GR) → 229K.
    CONSTANTS: gc_plant_2000 TYPE werks_d VALUE '2000',
               gc_plant_1000 TYPE werks_d VALUE '1000',
               gc_sloc_1d00  TYPE lgort_d VALUE '1D00',   " sumber (Plant 1000)
               gc_sloc_2kcs  TYPE lgort_d VALUE '2KCS',   " CP1   0% (masuk pipeline)
               gc_sloc_2261  TYPE lgort_d VALUE '2261',   " CP2  25% (masuk Machining)
               gc_sloc_2262  TYPE lgort_d VALUE '2262',   " CP3  50% (GR keluar Machining)
               gc_sloc_229k  TYPE lgort_d VALUE '229K'.   " CP4 100% (selesai)

    " ⚠️ BUKAN PIPELINE. Diagnostik diag_movement (section B2 & D) membuktikan 22F2
    " (Color Room) & 22F3 (CG Packing Area) BUKAN rute Wood Furniture. Konstanta
    " DIPERTAHANKAN hanya sebagai penanda "sudah diperiksa, sengaja dikecualikan"
    " (dirujuk catatan wf_route_status). JANGAN masukkan ke pipeline_slocs /
    " dot_stages / definisi selesai.
    CONSTANTS: gc_sloc_22f2 TYPE lgort_d VALUE '22F2',
               gc_sloc_22f3 TYPE lgort_d VALUE '22F3'.

    " SLoc proses lain di Plant 2000 (dipakai wf_route_status — "Status SLoc
    " Sederhana", plan §11.2). Nama asli dari T001L.
    CONSTANTS: gc_sloc_22e2 TYPE lgort_d VALUE '22E2',   " Banding D-IN
               gc_sloc_22ek TYPE lgort_d VALUE '22EK',   " EBD Karantina
               gc_sloc_2291 TYPE lgort_d VALUE '2291',   " Pre-Assy D-IN
               gc_sloc_2292 TYPE lgort_d VALUE '2292',   " Sanding D-OUT
               gc_sloc_2293 TYPE lgort_d VALUE '2293',   " Assembly D-IN
               gc_sloc_2294 TYPE lgort_d VALUE '2294'.   " Assembly D-OUT

    " === Movement type & arah — satu sumber kebenaran (hasil Fase 0) ===
    " Transfer pipeline memakai 301 (antar-plant) ATAU 311 (antar-sloc).
    " GR produksi (CP3) memakai 101. 321 = pelepasan Quality Inspection: lgort=umlgo,
    " BUKAN perpindahan fisik → SELALU di-exclude dari perhitungan checkpoint.
    CONSTANTS: gc_bwart_301 TYPE bwart  VALUE '301',   " transfer antar-plant
               gc_bwart_311 TYPE bwart  VALUE '311',   " transfer antar-sloc
               gc_bwart_gr  TYPE bwart  VALUE '101',   " goods receipt order produksi
               gc_bwart_qi  TYPE bwart  VALUE '321',   " QI release — EXCLUDE selalu
               gc_shkzg_s   TYPE shkzg  VALUE 'S',     " debit  = MASUK
               gc_shkzg_h   TYPE shkzg  VALUE 'H'.     " kredit = KELUAR

    " Special stock indicator 'E' = SALES-ORDER STOCK (make-to-order). Baris MSEG
    " ber-SOBKZ 'E' membawa KDAUF/KDPOS → gerakan TAHU miliknya SO+item mana.
    " Inilah yang memungkinkan qty pipeline dipilah per SO (verifikasi: 99.9%).
    CONSTANTS: gc_sobkz_e TYPE sobkz VALUE 'E'.

    " D7: indikator jenis stok (MSEG-INSMK) saat GR — 'X' = masuk Quality
    " Inspection stock (belum released), bukan langsung unrestricted.
    CONSTANTS: gc_insmk_qi TYPE mseg-insmk VALUE 'X'.

    " D7: movement type "Goods Issue utk order" — material KELUAR dari stok
    " karena DIKONSUMSI sbg komponen order lain, BUKAN transfer lokasi fisik
    " (beda konsep dgn 301/311). Baris ini membawa MSEG-AUFNR = order konsumen.
    CONSTANTS: gc_bwart_gi TYPE bwart VALUE '261'.

    " Label status rute (dipusatkan agar pemanggil tak membandingkan literal).
    CONSTANTS: gc_route_out   TYPE string VALUE 'Di Luar Rute Wood Furniture',
               gc_route_notin TYPE string VALUE 'Belum Masuk Central Storage'.

    " === Unit "WOOD FURNITURE" — filter scope Central Storage ===
    " Cost Center menempel ke Work Center, bukan ke order:
    "   AFKO-AUFPL → AFVC (operasi, field ARBID) → CRCO-OBJID → CRCO-KOSTL.
    " WHITELIST TERTUTUP 10 kode (plan-checkpoint-wood-furniture-filter.md §2).
    " Cost center di luar daftar ini (1111.. DRW/WE, 1133.. Metal SBY, 1134.. Chair)
    " = DI LUAR SCOPE — bukan error: order tetap tampil, hanya diberi badge netral (§3).
    CONSTANTS: gc_kokrs TYPE kokrs VALUE 'PC01'.   " controlling area (CRCO-KOKRS)
    CONSTANTS: gc_cc_line_a   TYPE kostl VALUE '1131100001',   " Machining — Line A
               gc_cc_line_b   TYPE kostl VALUE '1131100002',   " Machining — Line B
               gc_cc_line_c   TYPE kostl VALUE '1131100003',   " Machining — Line C
               gc_cc_edgeband TYPE kostl VALUE '1131200000',   " Edge Banding
               gc_cc_preassy  TYPE kostl VALUE '1131300000',   " Pre Assembly
               gc_cc_lifter_a TYPE kostl VALUE '1131400001',   " Assembly — Lifter A
               gc_cc_lifter_b TYPE kostl VALUE '1131400002',   " Assembly — Lifter B
               gc_cc_lifter_c TYPE kostl VALUE '1131400003',   " Assembly — Lifter C
               gc_cc_cstorage TYPE kostl VALUE '1131500000',   " Central Storage
               gc_cc_sample   TYPE kostl VALUE '1131600000'.   " Sample Maker

    " ⚠️ item_status( ) & item_pct( ) — basis AFPO GR% (wemng>=psmng) — DIHAPUS pada
    "    revisi Fase-1. Seluruh halaman (index/monitoring/riwayat/monitoring_detail)
    "    sudah memakai item_cp_status( ) / item_status_cp( ) berbasis checkpoint 229K.
    "    Sengaja tidak ditinggalkan sebagai deprecated agar tidak ada dua definisi
    "    "selesai" yang bisa terpakai lagi tanpa sengaja.

    "! === DEFINISI "SELESAI" YANG BERLAKU (basis CP4 / 229K) ===
    "! Klasifikasi status dari (qty DIBUTUHKAN, qty NET yang sampai 229K).
    "!
    "! Dipakai di 2 tingkat, dengan pasangan angka yang berbeda:
    "!   • KOMPONEN : iv_need = RESB-BDMNG      , iv_q_229k = net qty 229K material itu
    "!   • ITEM SO  : item SELESAI ⇔ SEMUA komponennya selesai. Pemanggil menghitung
    "!               per komponen lalu me-AND-kan — BUKAN menjumlahkan qty lintas
    "!               material (qty beda material tak boleh dijumlahkan).
    "!
    "! need<=0 (belum ada kebutuhan/order) → noprod | q229k>=need → done | else inprog.
    "! @parameter iv_need   | Qty dibutuhkan (RESB-BDMNG), dalam satuan MSEG-MENGE
    "! @parameter iv_q_229k | Qty NET yang sudah masuk 229K (masuk 'S' − keluar 'H')
    CLASS-METHODS item_status_cp
      IMPORTING iv_need        TYPE ty_qty
                iv_q_229k      TYPE ty_qty
      RETURNING VALUE(rv_code) TYPE i.

    "! Persentase progres berbasis CP4 = q229k/need*100, dibatasi 0..100.
    "! need<=0 → 0. Negatif (retur > masuk) dijepit ke 0.
    CLASS-METHODS item_pct_cp
      IMPORTING iv_need       TYPE ty_qty
                iv_q_229k     TYPE ty_qty
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

    "! Range 4 sloc pipeline Plant 2000 (URUT 2KCS/2261/2262/229K) utk WHERE lgort IN.
    "! Dipakai halaman saat SELECT MSEG gerakan checkpoint.
    "! CATATAN: 22F2/22F3 SENGAJA TIDAK ADA di sini (bukan rute Wood Furniture).
    CLASS-METHODS pipeline_slocs
      RETURNING VALUE(rt_lgort) TYPE ty_lgort_range.

    "! Range movement type transfer pipeline (301, 311) untuk WHERE bwart IN.
    "! GR (101) TIDAK termasuk — itu checkpoint tersendiri (CP3). 321 tak pernah masuk.
    CLASS-METHODS transfer_bwarts
      RETURNING VALUE(rt_bwart) TYPE ty_bwart_range.

    "! Range MRP controller (AFKO-DISPO) untuk WHERE dispo IN — scope 3 tahap Wood
    "! Furniture. HANYA order yang melewati salah satu MRP ini yang ikut diambil:
    "!   • Pembahanan : WM1 WM2 PN1 PN2
    "!   • Produksi   : GA1 GA2
    "!   • Ready Assy (dulu "Finish") : EB2 CH1
    "! Menggantikan penyaringan cost-center (wf_order_filter) di cabang "Butuh
    "! Dikirim": DISPO menyatakan langsung tahap WF di header order, sedangkan
    "! whitelist cost-center bias ke unit perakitan sehingga bisa membuang order
    "! Pembahanan (operasi pertamanya di luar 10 cost center itu).
    CLASS-METHODS wf_dispo_range
      RETURNING VALUE(rt_dispo) TYPE ty_dispo_range.

    "! Dot-bar perjalanan material melewati 4 CHECKPOINT pipeline final:
    "!   d1 2KCS → d2 2261 → d3 GR 101 @2262 → d4 229K.
    "! Memetakan qty NET tiap checkpoint → 4 kelas warna titik.
    "!
    "! MODEL: reached[s] = max( qty_s , reached[s+1] ) — kumulatif dari hilir,
    "! monotonik & tahan anomali; berarti "qty yang pernah mencapai minimal CP-s".
    "! (Qty yang sudah sampai 229K PASTI pernah lewat 2KCS, walau dokumennya hilang.)
    "!
    "! ACUAN PENUH R:
    "!   • iv_q_need > 0  → R = iv_q_need (qty DIBUTUHKAN, mis. RESB-BDMNG).
    "!     Inilah pemakaian normal: titik HIJAU = kebutuhan terpenuhi di tahap itu.
    "!   • iv_q_need <= 0 → fallback R = qty masuk 2KCS (dinaikkan bila hilir lebih
    "!     besar). Dipakai bila pemanggil tak tahu kebutuhannya; artinya bergeser jadi
    "!     "seluruh qty yang MASUK pipeline sudah maju", bukan "kebutuhan terpenuhi".
    "!
    "! Tiap titik: HIJAU bila reached>=R | KUNING bila reached>0 (sebagian) | ABU bila 0.
    "! Berbasis HISTORI (bukan stok kini) → material yang sudah lewat 229K tetap
    "! 4 hijau walau stoknya sudah pindah lagi.
    "!
    "! PENTING: pemanggil menghitung iv_q_* = qty NET tiap checkpoint sesuai definisi
    "! CP1..CP4 di header file (301/311 vs GR 101, net SHKZG, exclude 321).
    "!
    "! Qty iv_q_* WAJIB berasal dari cp_qty( ) — sudah ter-scope ke SO+item.
    "! JANGAN hitung sendiri dari MSEG per material: itu mengembalikan angka global
    "! yang dipakai bersama beberapa SO (masalah "batas atas" yang sudah dibuang).
    "!
    "! @parameter iv_q_2kcs    | CP1 net masuk 2KCS (SO+item ini)
    "! @parameter iv_q_2261    | CP2 net masuk 2261 (umlgo=2KCS)
    "! @parameter iv_q_2262_gr | CP3 qty GR 101 di 2262
    "! @parameter iv_q_229k    | CP4 net masuk 229K (sumber mana pun)
    "! @parameter iv_q_need    | Qty dibutuhkan (RESB-BDMNG). 0 = pakai fallback.
    "! @parameter iv_at_1d00   | abap_true bila material masih ada di 1000/1D00
    "!                           (menentukan titik-1 MERAH saat belum masuk 2KCS)
    "! @parameter iv_nodata    | abap_true (dari cp_qty) bila qty TAK BISA dipilah
    "!                           per SO → 4 titik ABU + note. TIDAK ada fallback
    "!                           diam-diam ke angka global.
    "! @parameter rs_dot       | Kelas warna 4 titik + info tampilan (ty_dotbar)
    CLASS-METHODS dot_stages
      IMPORTING iv_q_2kcs     TYPE ty_qty
                iv_q_2261     TYPE ty_qty
                iv_q_2262_gr  TYPE ty_qty
                iv_q_229k     TYPE ty_qty
                iv_q_need     TYPE ty_qty  DEFAULT 0
                iv_at_1d00    TYPE abap_bool DEFAULT abap_false
                iv_nodata     TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(rs_dot) TYPE ty_dotbar.

    "! ⭐ MESIN QTY CHECKPOINT — satu-satunya tempat qty CP1..CP4 dihitung.
    "! Menggantikan perhitungan per-material yang dulu tersebar di halaman.
    "!
    "! SCOPE PRESISI: tiap baris MSEG difilter kdauf = SO, kdpos = item, sobkz = 'E'
    "! (sales-order stock). Jadi qty yang dikembalikan MILIK item SO itu saja —
    "! bukan angka material yang dipakai bersama beberapa SO.
    "!
    "! Definisi checkpoint (identik dgn header file; 321 tak pernah ikut):
    "!   CP1 2KCS : lgort=2KCS. 'S' menambah. 'H' HANYA mengurangi bila umwrk=1000
    "!              (retur ke plant asal). 'H' ke hilir = kemajuan → diabaikan.
    "!   CP2 2261 : lgort=2261 DAN umlgo=2KCS, net S−H.
    "!   CP3 2262 : GR bwart 101 di lgort=2262. Baris ber-KDAUF → dipakai filter
    "!              kdauf/kdpos (sama seperti 3 titik lain). Baris TANPA kdauf →
    "!              masih diikat ke item lewat AUFNR (it_ordmap) + whitelist WF
    "!              (cara lama, DIPERTAHANKAN sebagai tambahan, bukan pengganti).
    "!   CP4 229K : lgort=229K, umlgo mana pun, net S−H.
    "!
    "! NODATA (0.1%): bila material punya baris pipeline TANPA kdauf atau bukan
    "! sobkz 'E', key-nya ditandai nodata = abap_true. Pemanggil WAJIB menampilkan
    "! "Data Tidak Lengkap" — DILARANG jatuh balik ke perhitungan global.
    "!
    "! Batched: satu SELECT MSEG⨝MKPF untuk SELURUH key (FOR ALL ENTRIES) — aman
    "! dipanggil dari halaman daftar (index/monitoring) yang memuat ratusan item.
    "!
    "! @parameter it_key    | (kdauf, kdpos, matnr, need) per komponen item SO
    "! @parameter it_ordmap | order → item SO; hanya utk baris GR 101 tanpa KDAUF
    "! @parameter rt_qty    | qty CP1..CP4 + last_in + flag nodata, per key
    CLASS-METHODS cp_qty
      IMPORTING it_key        TYPE ty_cpkey_tab
                it_ordmap     TYPE ty_ordmap_tab OPTIONAL
      RETURNING VALUE(rt_qty) TYPE ty_cpqty_tab.

    "! Filter order produksi → hanya yang UNIT-nya Wood Furniture (whitelist §2).
    "! Rantai: AFKO-AUFPL → AFVC (operasi PERTAMA, ARBID) → CRCO (objid=arbid,
    "! kokrs=gc_kokrs, begda/endda valid hari ini) → KOSTL → wf_line_name( ) <> ''.
    "!
    "! Dipusatkan di sini karena rantai ini dibutuhkan oleh CP3 (GR 101 hanya dihitung
    "! bila order-nya WF) dan oleh badge Line — sebelumnya disalin di tiap halaman.
    "! Batched (FOR ALL ENTRIES), aman untuk ratusan order sekaligus.
    "!
    "! Order TANPA routing (AFVC kosong) atau TANPA cost center valid hari ini
    "! (CRCO begda/endda) → TIDAK dianggap WF (default aman: lebih baik kurang
    "! daripada salah klaim).
    "!
    "! @parameter it_aufnr | Daftar order yang mau dinilai (boleh kosong)
    "! @parameter rt_aufnr | Sub-himpunan yang LOLOS whitelist WF (sorted, unique)
    CLASS-METHODS wf_order_filter
      IMPORTING it_aufnr        TYPE ty_aufnr_tab
      RETURNING VALUE(rt_aufnr) TYPE ty_aufnr_tab.

    "! ⭐ MESIN "SELESAI" BARU (CP4) — dipakai index/monitoring/riwayat/detail.
    "! Menghitung status & progres SETIAP item SO dari checkpoint 229K, MENGGANTIKAN
    "! basis AFPO GR% (wemng>=psmng).
    "!
    "! ATURAN: item SELESAI ⇔ SETIAP komponennya (material unik di RESB seluruh order
    "! item tsb) punya net qty 229K >= SUM(BDMNG)-nya. Satu komponen kurang → item
    "! masih PROSES. Item tanpa order / tanpa komponen → BELUM PRODUKSI.
    "! Progres item = RATA-RATA item_pct_cp tiap komponen (bukan rasio done/total).
    "!
    "! Query di dalam (semua batched): RESB (komponen per order) → cp_qty( ) (qty
    "! CP1..CP4 ter-scope kdauf/kdpos/sobkz='E').
    "!
    "! PRESISI PER SO (revisi Fase-2): qty TIDAK lagi per material & global. Batas
    "! lama ("angka = BATAS ATAS, satu material dipakai beberapa SO melihat angka
    "! yang sama") SUDAH TIDAK BERLAKU — tiap gerakan kini diklaim oleh SO+item
    "! pemiliknya lewat KDAUF/KDPOS.
    "!
    "! ⚠️ Item yang punya komponen ber-nodata (gerakan tanpa KDAUF/SOBKZ='E') →
    "! code = gc_st_nodata. Pemanggil WAJIB menampilkannya sebagai "Data Tidak
    "! Lengkap", JANGAN biarkan jatuh ke WHEN OTHERS (= "Belum Produksi").
    "!
    "! @parameter it_item | Baris AFPO mentah (kdauf, kdpos, aufnr) — boleh duplikat item
    "! @parameter rt_item | Status per item SO (sorted by kdauf/kdpos, unique)
    CLASS-METHODS item_cp_status
      IMPORTING it_item        TYPE ty_itm_tab
      RETURNING VALUE(rt_item) TYPE ty_itmcp_tab.

    "! Nama Line/Section Unit Wood Furniture dari Cost Center (whitelist §2).
    "! Satu sumber kebenaran untuk filter scope Unit.
    "! Cost center DI LUAR whitelist → mengembalikan string KOSONG; pemanggil
    "! yang memutuskan tampilan (badge netral "Unit lain"), bukan method ini.
    "! @parameter iv_kostl | Cost center dari CRCO-KOSTL (operasi pertama order)
    "! @parameter rv_name  | 'Line A'/'Lifter B'/… atau '' bila di luar whitelist
    CLASS-METHODS wf_line_name
      IMPORTING iv_kostl       TYPE kostl
      RETURNING VALUE(rv_name) TYPE string.

    "! "Status SLoc Sederhana" (plan §11.2) — lookup STATIS SLoc → label status
    "! posisi material di rute Wood Furniture. MURNI presentational: tidak ada
    "! query; sumber lgort dari lt_curloc (MARD) yang sudah di-fetch.
    "! SLoc di luar rute → gc_route_out (default aman).
    "! CATATAN: kasus "belum masuk Plant 2000" (werks=1000/1D00) TIDAK ditangani
    "! di sini — method ini hanya menerima lgort, tak tahu werks. Pemanggil yang
    "! mengecek werks lebih dulu dan memakai gc_route_notin.
    "! @parameter iv_lgort  | Storage location (MARD-LGORT)
    "! @parameter rv_status | Label status; gc_route_out bila di luar rute
    CLASS-METHODS wf_route_status
      IMPORTING iv_lgort         TYPE lgort_d
      RETURNING VALUE(rv_status) TYPE string.

    "! ⭐ D7 (v2): NASIB FISIK material komponen — GR / QC / dikonsumsi / dikirim.
    "! Menelusuri MSEG⨝MKPF (bwart 101/321/261/301/311), discope SO+item+
    "! SOBKZ='E' (pola sama dgn cp_qty), key = MATERIAL (bukan order/aufnr —
    "! lihat catatan v1→v2 di header REVISI FASE-3: AFPO-PSMNG/WEMNG order
    "! TERBUKTI tidak merepresentasikan qty GR aktual material, jadi status ini
    "! SENGAJA independen dari progres AFPO order manapun & SELALU dihitung,
    "! bukan cuma saat order 100%).
    "!
    "! Kategori hasil:
    "!   qty_gr   : total pernah di-GR (konteks/cross-check thd Target Qty tabel)
    "!   qty_qc   : masih di Quality Inspection (GR dgn INSMK='X', blm dirilis 321)
    "!   qty_wait : tersedia (unrestricted), belum dipakai maupun dikirim
    "!   qty_used : sudah DIKONSUMSI (GI 261) sbg komponen order lain — rincian
    "!              order konsumen ada di t_used (dibaca LANGSUNG dari
    "!              MSEG-AUFNR baris 261, bukan lewat RESB-RSNUM)
    "!   qty_sent : sudah ditransfer FISIK (301/311) ke SLoc lain — rincian
    "!              tujuan ada di t_dest (UMWRK/UMLGO baris transfer)
    "! src_lgort = SLoc penerimaan GR (dibaca dari data GR itu sendiri, TIDAK
    "! diasumsikan/dihardcode — beda material/order bisa GR ke SLoc berbeda).
    "!
    "! Batched (FOR ALL ENTRIES atas MATNR unik) — panggil utk SEMUA material
    "! komponen yang sedang ditampilkan di tab Butuh Dikirim, TIDAK PERLU
    "! menunggu order 100% (beda dgn v1).
    "!
    "! @parameter it_key    | (kdauf, kdpos, matnr) per material komponen
    "! @parameter rt_status | Pemilahan qty_gr/qc/wait/used/sent + t_used/t_dest
    CLASS-METHODS pmb_output_status
      IMPORTING it_key           TYPE ty_pmbkey_tab
      RETURNING VALUE(rt_status) TYPE ty_pmbstatus_tab.

ENDCLASS.

CLASS zcl_cs_util IMPLEMENTATION.

  METHOD item_status_cp.
    " Definisi "selesai" YANG BERLAKU: qty net sampai 229K >= qty dibutuhkan.
    IF iv_need <= 0.
      rv_code = gc_st_noprod.       " belum ada kebutuhan → belum produksi
    ELSEIF iv_q_229k >= iv_need.
      rv_code = gc_st_done.
    ELSE.
      rv_code = gc_st_inprog.
    ENDIF.
  ENDMETHOD.

  METHOD item_pct_cp.
    IF iv_need <= 0.
      rv_pct = 0.
      RETURN.
    ENDIF.
    rv_pct = iv_q_229k * 100 / iv_need.
    " Retur (H) bisa membuat net negatif — jepit ke 0..100.
    IF rv_pct > 100. rv_pct = 100. ENDIF.
    IF rv_pct < 0.   rv_pct = 0.   ENDIF.
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
    " 4 checkpoint final. 22F2/22F3 SENGAJA TIDAK ADA (bukan rute Wood Furniture).
    DATA ls_r LIKE LINE OF rt_lgort.
    ls_r-sign = 'I'. ls_r-option = 'EQ'.
    ls_r-low = gc_sloc_2kcs. APPEND ls_r TO rt_lgort.
    ls_r-low = gc_sloc_2261. APPEND ls_r TO rt_lgort.
    ls_r-low = gc_sloc_2262. APPEND ls_r TO rt_lgort.
    ls_r-low = gc_sloc_229k. APPEND ls_r TO rt_lgort.
  ENDMETHOD.

  METHOD transfer_bwarts.
    DATA ls_b LIKE LINE OF rt_bwart.
    ls_b-sign = 'I'. ls_b-option = 'EQ'.
    ls_b-low = gc_bwart_301. APPEND ls_b TO rt_bwart.
    ls_b-low = gc_bwart_311. APPEND ls_b TO rt_bwart.
  ENDMETHOD.

  METHOD wf_dispo_range.
    " Satu sumber kebenaran daftar MRP controller (AFKO-DISPO) tahap Wood Furniture.
    DATA ls_r LIKE LINE OF rt_dispo.
    ls_r-sign = 'I'. ls_r-option = 'EQ'.
    " Tahap 1 — Pembahanan
    ls_r-low = 'WM1'. APPEND ls_r TO rt_dispo.
    ls_r-low = 'WM2'. APPEND ls_r TO rt_dispo.
    ls_r-low = 'PN1'. APPEND ls_r TO rt_dispo.
    ls_r-low = 'PN2'. APPEND ls_r TO rt_dispo.
    " Tahap 2 — Produksi
    ls_r-low = 'GA1'. APPEND ls_r TO rt_dispo.
    ls_r-low = 'GA2'. APPEND ls_r TO rt_dispo.
    " Tahap 3 — Ready Assy (dulu "Finish")
    ls_r-low = 'EB2'. APPEND ls_r TO rt_dispo.
    ls_r-low = 'CH1'. APPEND ls_r TO rt_dispo.   " D29: ditambahkan atas permintaan user
  ENDMETHOD.

  METHOD dot_stages.
    DATA: lv_r     TYPE ty_qty,   " acuan penuh (kebutuhan, atau fallback qty 2KCS)
          lv_r2261 TYPE ty_qty,   " reached[CP2] = pernah mencapai minimal 2261
          lv_r2262 TYPE ty_qty,   " reached[CP3] = pernah ter-GR keluar Machining
          lv_r229k TYPE ty_qty,   " reached[CP4]
          lv_r2kcs TYPE ty_qty.   " reached[CP1]

    " Kumulatif "pernah mencapai minimal checkpoint ini", dari hilir ke hulu.
    " Qty hilir yang lebih besar menyiratkan qty itu PASTI sudah melewati hulu.
    lv_r229k = iv_q_229k.
    lv_r2262 = iv_q_2262_gr. IF lv_r229k > lv_r2262. lv_r2262 = lv_r229k. ENDIF.
    lv_r2261 = iv_q_2261.    IF lv_r2262 > lv_r2261. lv_r2261 = lv_r2262. ENDIF.
    lv_r2kcs = iv_q_2kcs.    IF lv_r2261 > lv_r2kcs. lv_r2kcs = lv_r2261. ENDIF.

    " Acuan penuh: kebutuhan bila diketahui, else qty yang masuk pipeline.
    IF iv_q_need > 0.
      lv_r = iv_q_need.
    ELSE.
      lv_r = lv_r2kcs.
    ENDIF.

    " Default: semua abu-abu.
    rs_dot-d1 = 'dot-grey'. rs_dot-d2 = 'dot-grey'.
    rs_dot-d3 = 'dot-grey'. rs_dot-d4 = 'dot-grey'.
    rs_dot-pct = 0.

    " DATA TIDAK LENGKAP → berhenti di sini: 4 titik abu, TANPA angka.
    " Sengaja TIDAK jatuh balik ke perhitungan global per-material: itu akan
    " menampilkan angka "batas atas" yang tampak sah padahal bisa milik SO lain.
    IF iv_nodata = abap_true.
      rs_dot-nodata   = abap_true.
      rs_dot-sloc_lbl = '?'.
      rs_dot-note     = 'Data Tidak Lengkap — material ini punya gerakan pipeline tanpa KDAUF/SOBKZ=E, jadi qty-nya tidak bisa dipastikan milik SO+item ini. Angka sengaja TIDAK ditampilkan daripada menampilkan angka yang mungkin milik SO lain.'.
      RETURN.
    ENDIF.

    " Belum pernah masuk pipeline sama sekali → titik-1 MERAH bila stok masih
    " menunggu di 1D00 (Plant 1000), sisanya abu.
    IF lv_r <= 0 OR lv_r2kcs <= 0.
      IF iv_at_1d00 = abap_true.
        rs_dot-d1       = 'dot-red'.
        rs_dot-sloc_lbl = gc_sloc_1d00.
      ENDIF.
      RETURN.
    ENDIF.

    " Tiap titik: HIJAU bila acuan terpenuhi, KUNING bila baru sebagian, ABU bila 0.
    IF     lv_r2kcs >= lv_r. rs_dot-d1 = 'dot-green'.
    ELSEIF lv_r2kcs >  0.    rs_dot-d1 = 'dot-yellow'.
    ENDIF.

    IF     lv_r2261 >= lv_r. rs_dot-d2 = 'dot-green'.
    ELSEIF lv_r2261 >  0.    rs_dot-d2 = 'dot-yellow'.
    ENDIF.

    IF     lv_r2262 >= lv_r. rs_dot-d3 = 'dot-green'.
    ELSEIF lv_r2262 >  0.    rs_dot-d3 = 'dot-yellow'.
    ENDIF.

    IF     lv_r229k >= lv_r. rs_dot-d4 = 'dot-green'.
    ELSEIF lv_r229k >  0.    rs_dot-d4 = 'dot-yellow'.
    ENDIF.

    " SELESAI = acuan penuh sudah sampai 229K (definisi CP4, selaras item_status_cp).
    rs_dot-all_done = boolc( lv_r229k >= lv_r ).

    " Frontier (checkpoint terjauh yang tersentuh) untuk label & tooltip.
    IF     lv_r229k > 0. rs_dot-pct = 100. rs_dot-sloc_lbl = gc_sloc_229k.
    ELSEIF lv_r2262 > 0. rs_dot-pct = 75.  rs_dot-sloc_lbl = gc_sloc_2262.
    ELSEIF lv_r2261 > 0. rs_dot-pct = 50.  rs_dot-sloc_lbl = gc_sloc_2261.
    ELSE.                rs_dot-pct = 25.  rs_dot-sloc_lbl = gc_sloc_2kcs.
    ENDIF.
  ENDMETHOD.

  METHOD cp_qty.
    " Satu-satunya tempat qty CP1..CP4 dihitung. Dokumentasi lengkap di deklarasi.
    TYPES: BEGIN OF lty_mat,
             matnr TYPE resb-matnr,
           END OF lty_mat,
           BEGIN OF lty_mv,
             matnr TYPE mseg-matnr,
             aufnr TYPE mseg-aufnr,
             lgort TYPE mseg-lgort,
             umlgo TYPE mseg-umlgo,
             umwrk TYPE mseg-umwrk,
             bwart TYPE mseg-bwart,
             shkzg TYPE mseg-shkzg,
             menge TYPE mseg-menge,
             kdauf TYPE mseg-kdauf,
             kdpos TYPE mseg-kdpos,
             sobkz TYPE mseg-sobkz,
             budat TYPE mkpf-budat,
           END OF lty_mv,
           BEGIN OF lty_bad,          " material yang punya baris "anonim"
             matnr TYPE mseg-matnr,
           END OF lty_bad.

    DATA: lt_mat  TYPE TABLE OF lty_mat, ls_mat TYPE lty_mat,
          lt_mv   TYPE TABLE OF lty_mv,  ls_mv  TYPE lty_mv,
          lt_bad  TYPE SORTED TABLE OF lty_bad WITH UNIQUE KEY matnr,
          ls_bad  TYPE lty_bad,
          lt_ord  TYPE ty_aufnr_tab,
          ls_ord  TYPE ty_aufnr_line,
          lt_wf   TYPE ty_aufnr_tab,
          ls_key  TYPE ty_cpkey,
          ls_out  TYPE ty_cpqty,
          ls_omap TYPE ty_ordmap,
          lr_bw   TYPE ty_bwart_range,
          lr_slo  TYPE ty_lgort_range,
          ls_bw   LIKE LINE OF lr_bw,
          lv_q    TYPE ty_qty,
          lv_kdauf TYPE afpo-kdauf,
          lv_kdpos TYPE afpo-kdpos.

    FIELD-SYMBOLS <o> TYPE ty_cpqty.

    IF it_key IS INITIAL.
      RETURN.
    ENDIF.

    " Kerangka hasil (semua key ikut, walau nanti qty-nya 0).
    LOOP AT it_key INTO ls_key.
      CLEAR ls_out.
      ls_out-kdauf = ls_key-kdauf.
      ls_out-kdpos = ls_key-kdpos.
      ls_out-matnr = ls_key-matnr.
      ls_out-need  = ls_key-need.
      INSERT ls_out INTO TABLE rt_qty.

      ls_mat-matnr = ls_key-matnr.
      APPEND ls_mat TO lt_mat.
    ENDLOOP.
    SORT lt_mat BY matnr.
    DELETE ADJACENT DUPLICATES FROM lt_mat COMPARING matnr.

    " SATU query untuk seluruh key. Sengaja di-FAE atas MATNR saja (bukan
    " matnr+kdauf+kdpos): baris "anonim" (kdauf kosong) harus IKUT tertarik supaya
    " bisa DIDETEKSI — kalau kdauf ikut di WHERE, baris itu hilang tanpa jejak dan
    " kita akan menyangka datanya bersih.
    lr_slo = pipeline_slocs( ).                 " 2KCS/2261/2262/229K
    lr_bw  = transfer_bwarts( ).                " 301/311
    ls_bw-sign = 'I'. ls_bw-option = 'EQ'.
    ls_bw-low  = gc_bwart_gr.                   " + 101 (CP3)
    APPEND ls_bw TO lr_bw.

    SELECT m~matnr m~aufnr m~lgort m~umlgo m~umwrk m~bwart m~shkzg m~menge
           m~kdauf m~kdpos m~sobkz k~budat
      FROM mseg AS m INNER JOIN mkpf AS k
        ON m~mblnr = k~mblnr AND m~mjahr = k~mjahr
      INTO TABLE lt_mv
      FOR ALL ENTRIES IN lt_mat
      WHERE m~matnr = lt_mat-matnr
        AND m~werks = gc_plant_2000
        AND m~lgort IN lr_slo
        AND m~bwart IN lr_bw.
    IF lt_mv IS INITIAL.
      RETURN.
    ENDIF.

    " Order WF — hanya dipakai untuk baris GR 101 yang TIDAK membawa kdauf.
    LOOP AT lt_mv INTO ls_mv.
      IF ls_mv-bwart <> gc_bwart_gr OR ls_mv-aufnr IS INITIAL. CONTINUE. ENDIF.
      IF ls_mv-kdauf IS NOT INITIAL. CONTINUE. ENDIF.   " sudah bisa dipetakan langsung
      ls_ord-aufnr = ls_mv-aufnr.
      INSERT ls_ord INTO TABLE lt_ord.
    ENDLOOP.
    IF lt_ord IS NOT INITIAL.
      lt_wf = wf_order_filter( lt_ord ).
    ENDIF.

    LOOP AT lt_mv INTO ls_mv.

      " --- 1. DETEKSI ANONIM (0.1%) -------------------------------------------
      " Baris TRANSFER tanpa kdauf / bukan sobkz 'E' → material ini tidak bisa
      " dipilah per SO. Ditandai, BUKAN diabaikan diam-diam.
      " GR 101 dikecualikan dari deteksi: ia punya AUFNR, jadi tetap bisa diikat
      " ke item lewat it_ordmap walau kdauf-nya kosong.
      IF ls_mv-bwart <> gc_bwart_gr.
        IF ls_mv-kdauf IS INITIAL OR ls_mv-sobkz <> gc_sobkz_e.
          ls_bad-matnr = ls_mv-matnr.
          INSERT ls_bad INTO TABLE lt_bad.
          CONTINUE.       " tak boleh diakui ke SO mana pun
        ENDIF.
      ENDIF.

      " --- 2. TENTUKAN PEMILIK BARIS (SO + item) ------------------------------
      CLEAR: lv_kdauf, lv_kdpos.
      IF ls_mv-kdauf IS NOT INITIAL.
        lv_kdauf = ls_mv-kdauf.
        lv_kdpos = ls_mv-kdpos.
      ELSEIF ls_mv-bwart = gc_bwart_gr AND ls_mv-aufnr IS NOT INITIAL.
        " GR 101 tanpa kdauf → cara lama: AUFNR harus lolos whitelist WF, lalu
        " dipetakan ke item SO lewat it_ordmap.
        READ TABLE lt_wf TRANSPORTING NO FIELDS WITH TABLE KEY aufnr = ls_mv-aufnr.
        IF sy-subrc <> 0. CONTINUE. ENDIF.            " order non-WF
        READ TABLE it_ordmap INTO ls_omap WITH TABLE KEY aufnr = ls_mv-aufnr.
        IF sy-subrc <> 0. CONTINUE. ENDIF.            " order di luar cakupan
        lv_kdauf = ls_omap-kdauf.
        lv_kdpos = ls_omap-kdpos.
      ELSE.
        CONTINUE.
      ENDIF.

      READ TABLE rt_qty ASSIGNING <o>
        WITH TABLE KEY kdauf = lv_kdauf kdpos = lv_kdpos matnr = ls_mv-matnr.
      IF sy-subrc <> 0. CONTINUE. ENDIF.   " baris milik item lain → bukan urusan kita

      " --- 3. AKUMULASI PER CHECKPOINT ----------------------------------------
      lv_q = ls_mv-menge.
      IF ls_mv-shkzg = gc_shkzg_h.
        lv_q = 0 - lv_q.
      ENDIF.

      IF ls_mv-bwart = gc_bwart_gr.
        " CP3 — GR keluar Machining
        IF ls_mv-lgort = gc_sloc_2262.
          <o>-q2262 = <o>-q2262 + lv_q.
        ENDIF.
      ELSE.
        CASE ls_mv-lgort.
          WHEN gc_sloc_2kcs.
            " CP1 — 'H' hanya dikurangi bila retur balik ke Plant 1000.
            IF ls_mv-shkzg = gc_shkzg_s.
              <o>-q2kcs = <o>-q2kcs + lv_q.
            ELSEIF ls_mv-umwrk = gc_plant_1000.
              <o>-q2kcs = <o>-q2kcs + lv_q.       " lv_q sudah negatif
            ENDIF.
          WHEN gc_sloc_2261.
            IF ls_mv-umlgo = gc_sloc_2kcs.
              <o>-q2261 = <o>-q2261 + lv_q.
            ENDIF.
          WHEN gc_sloc_229k.
            <o>-q229k = <o>-q229k + lv_q.
            IF ls_mv-shkzg = gc_shkzg_s AND ls_mv-budat > <o>-last_in.
              <o>-last_in = ls_mv-budat.
            ENDIF.
        ENDCASE.
      ENDIF.
    ENDLOOP.

    " --- 4. Tandai key yang materialnya punya baris anonim -----------------------
    IF lt_bad IS NOT INITIAL.
      LOOP AT rt_qty ASSIGNING <o>.
        READ TABLE lt_bad TRANSPORTING NO FIELDS
          WITH TABLE KEY matnr = <o>-matnr.
        IF sy-subrc = 0.
          <o>-nodata = abap_true.
        ENDIF.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.

  METHOD wf_order_filter.
    " Rantai order → cost center → whitelist WF. Batched; lihat dokumentasi di atas.
    TYPES: BEGIN OF lty_auf,
             aufnr TYPE afko-aufnr,
             aufpl TYPE afko-aufpl,
           END OF lty_auf,
           BEGIN OF lty_aufpl,
             aufpl TYPE afko-aufpl,
           END OF lty_aufpl,
           BEGIN OF lty_afvc,
             aufpl TYPE afvc-aufpl,
             vornr TYPE afvc-vornr,
             arbid TYPE afvc-arbid,
           END OF lty_afvc,
           BEGIN OF lty_arbid,
             arbid TYPE afvc-arbid,
           END OF lty_arbid,
           BEGIN OF lty_crco,
             objid TYPE crco-objid,
             kostl TYPE crco-kostl,
           END OF lty_crco.

    DATA: lt_auf   TYPE TABLE OF lty_auf,   ls_auf   TYPE lty_auf,
          lt_aufpl TYPE TABLE OF lty_aufpl, ls_aufpl TYPE lty_aufpl,
          lt_afvc  TYPE TABLE OF lty_afvc,  ls_afvc  TYPE lty_afvc,
          lt_arbid TYPE TABLE OF lty_arbid, ls_arbid TYPE lty_arbid,
          lt_crco  TYPE TABLE OF lty_crco,  ls_crco  TYPE lty_crco,
          ls_out   TYPE ty_aufnr_line,
          lv_prev  TYPE afko-aufpl,
          lv_name  TYPE string.

    IF it_aufnr IS INITIAL.
      RETURN.
    ENDIF.

    " 1. Order → routing (AUFPL). Order tanpa routing tak bisa dinilai → bukan WF.
    SELECT aufnr aufpl FROM afko INTO TABLE lt_auf
      FOR ALL ENTRIES IN it_aufnr
      WHERE aufnr = it_aufnr-aufnr.
    IF lt_auf IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT lt_auf INTO ls_auf.
      IF ls_auf-aufpl IS INITIAL. CONTINUE. ENDIF.
      ls_aufpl-aufpl = ls_auf-aufpl.
      APPEND ls_aufpl TO lt_aufpl.
    ENDLOOP.
    SORT lt_aufpl BY aufpl.
    DELETE ADJACENT DUPLICATES FROM lt_aufpl COMPARING aufpl.
    IF lt_aufpl IS INITIAL.
      RETURN.
    ENDIF.

    " 2. Routing → operasi. Operasi PERTAMA = vornr terkecil (VORNR zero-padded,
    "    jadi urutan leksikografis = urutan numerik).
    SELECT aufpl vornr arbid FROM afvc INTO TABLE lt_afvc
      FOR ALL ENTRIES IN lt_aufpl
      WHERE aufpl = lt_aufpl-aufpl.
    SORT lt_afvc BY aufpl ASCENDING vornr ASCENDING.

    LOOP AT lt_afvc INTO ls_afvc.
      IF ls_afvc-aufpl = lv_prev. CONTINUE. ENDIF.   " bukan operasi pertama
      lv_prev = ls_afvc-aufpl.
      IF ls_afvc-arbid IS INITIAL. CONTINUE. ENDIF.
      ls_arbid-arbid = ls_afvc-arbid.
      APPEND ls_arbid TO lt_arbid.
    ENDLOOP.
    SORT lt_arbid BY arbid.
    DELETE ADJACENT DUPLICATES FROM lt_arbid COMPARING arbid.
    IF lt_arbid IS INITIAL.
      RETURN.
    ENDIF.

    " 3. Work center (ARBID = CRCO-OBJID) → cost center valid HARI INI.
    SELECT objid kostl FROM crco INTO TABLE lt_crco
      FOR ALL ENTRIES IN lt_arbid
      WHERE objid = lt_arbid-arbid
        AND kokrs = gc_kokrs
        AND begda <= sy-datum
        AND endda >= sy-datum.
    SORT lt_crco BY objid.

    " 4. Order LOLOS bila cost center operasi pertamanya ada di whitelist.
    LOOP AT lt_auf INTO ls_auf.
      IF ls_auf-aufpl IS INITIAL. CONTINUE. ENDIF.
      READ TABLE lt_afvc INTO ls_afvc
        WITH KEY aufpl = ls_auf-aufpl BINARY SEARCH.   " = operasi pertama
      IF sy-subrc <> 0 OR ls_afvc-arbid IS INITIAL. CONTINUE. ENDIF.
      READ TABLE lt_crco INTO ls_crco
        WITH KEY objid = ls_afvc-arbid BINARY SEARCH.
      IF sy-subrc <> 0. CONTINUE. ENDIF.
      lv_name = wf_line_name( ls_crco-kostl ).
      IF lv_name IS INITIAL. CONTINUE. ENDIF.          " di luar whitelist WF
      ls_out-aufnr = ls_auf-aufnr.
      INSERT ls_out INTO TABLE rt_aufnr.                " sorted-unique → auto dedup
    ENDLOOP.
  ENDMETHOD.

  METHOD item_cp_status.
    " Lihat dokumentasi lengkap di deklarasi. Ringkas: RESB → kebutuhan per komponen,
    " MSEG → net qty 229K per material, lalu item SELESAI ⇔ SEMUA komponen terpenuhi.
    TYPES: BEGIN OF lty_resb,
             aufnr TYPE resb-aufnr,
             matnr TYPE resb-matnr,
             bdmng TYPE resb-bdmng,
           END OF lty_resb,
           BEGIN OF lty_mat,
             matnr TYPE resb-matnr,
           END OF lty_mat.

    DATA: lt_ord   TYPE ty_aufnr_tab,
          ls_ord   TYPE ty_aufnr_line,
          lt_resb  TYPE TABLE OF lty_resb,  ls_resb  TYPE lty_resb,
          lt_key   TYPE ty_cpkey_tab,       ls_key   TYPE ty_cpkey,
          lt_omap  TYPE ty_ordmap_tab,      ls_omap  TYPE ty_ordmap,
          lt_qty   TYPE ty_cpqty_tab,       ls_qty   TYPE ty_cpqty,
          ls_itm   TYPE ty_itm_line,
          ls_out   TYPE ty_itmcp_line,
          lv_code  TYPE i,
          lv_idx   TYPE i,
          lv_sum   TYPE ty_pct.

    FIELD-SYMBOLS: <n>   TYPE ty_cpkey,
                   <o>   TYPE ty_itmcp_line.

    IF it_item IS INITIAL.
      RETURN.
    ENDIF.

    " Kerangka hasil: SEMUA item ikut, termasuk yang tanpa order (→ noprod).
    LOOP AT it_item INTO ls_itm.
      READ TABLE rt_item TRANSPORTING NO FIELDS
        WITH TABLE KEY kdauf = ls_itm-kdauf kdpos = ls_itm-kdpos.
      IF sy-subrc <> 0.
        CLEAR ls_out.
        ls_out-kdauf = ls_itm-kdauf.
        ls_out-kdpos = ls_itm-kdpos.
        ls_out-code  = gc_st_noprod.
        INSERT ls_out INTO TABLE rt_item.
      ENDIF.
      IF ls_itm-aufnr IS NOT INITIAL.
        ls_ord-aufnr = ls_itm-aufnr.
        INSERT ls_ord INTO TABLE lt_ord.   " sorted-unique

        " Peta order → item SO (dipakai cp_qty utk baris GR 101 tanpa KDAUF).
        CLEAR ls_omap.
        ls_omap-aufnr = ls_itm-aufnr.
        ls_omap-kdauf = ls_itm-kdauf.
        ls_omap-kdpos = ls_itm-kdpos.
        INSERT ls_omap INTO TABLE lt_omap.
      ENDIF.
    ENDLOOP.

    IF lt_ord IS INITIAL.
      RETURN.   " tak ada order sama sekali → semua item noprod
    ENDIF.

    " 1. Komponen tiap order (reservasi aktif saja).
    SELECT aufnr matnr bdmng FROM resb INTO TABLE lt_resb
      FOR ALL ENTRIES IN lt_ord
      WHERE aufnr = lt_ord-aufnr
        AND xloek = ' '.
    DELETE lt_resb WHERE matnr IS INITIAL.
    IF lt_resb IS INITIAL.
      RETURN.   " order ada tapi tanpa komponen → tetap noprod
    ENDIF.
    SORT lt_resb BY aufnr.

    " 2. Kebutuhan per (item, komponen) = SUM(bdmng) seluruh order item tsb.
    "    Dijumlahkan PER MATERIAL, bukan per baris RESB — satu material bisa muncul
    "    di beberapa order item yang sama.
    LOOP AT it_item INTO ls_itm.
      IF ls_itm-aufnr IS INITIAL. CONTINUE. ENDIF.
      " lt_resb terurut BY aufnr → binary search + LOOP FROM index. Sengaja BUKAN
      " "LOOP AT … WHERE aufnr = …": itu scan penuh per item → O(item × RESB), berat
      " di index.htm yang memuat ratusan SO sekaligus.
      READ TABLE lt_resb TRANSPORTING NO FIELDS
        WITH KEY aufnr = ls_itm-aufnr BINARY SEARCH.
      IF sy-subrc <> 0. CONTINUE. ENDIF.
      lv_idx = sy-tabix.

      LOOP AT lt_resb INTO ls_resb FROM lv_idx.
        IF ls_resb-aufnr <> ls_itm-aufnr. EXIT. ENDIF.   " keluar begitu ganti order
        READ TABLE lt_key ASSIGNING <n>
          WITH TABLE KEY kdauf = ls_itm-kdauf
                         kdpos = ls_itm-kdpos
                         matnr = ls_resb-matnr.
        IF sy-subrc = 0.
          <n>-need = <n>-need + ls_resb-bdmng.
        ELSE.
          CLEAR ls_key.
          ls_key-kdauf = ls_itm-kdauf.
          ls_key-kdpos = ls_itm-kdpos.
          ls_key-matnr = ls_resb-matnr.
          ls_key-need  = ls_resb-bdmng.
          INSERT ls_key INTO TABLE lt_key.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
    IF lt_key IS INITIAL.
      RETURN.
    ENDIF.

    " 3. QTY CHECKPOINT — per SO+ITEM+MATERIAL (bukan lagi per material global).
    "    Seluruh query MSEG ada di cp_qty( ); di sinilah presisi per-SO didapat.
    lt_qty = cp_qty( it_key = lt_key it_ordmap = lt_omap ).

    " 4. Nilai tiap komponen, lalu AND-kan ke itemnya.
    LOOP AT lt_qty INTO ls_qty.
      READ TABLE rt_item ASSIGNING <o>
        WITH TABLE KEY kdauf = ls_qty-kdauf kdpos = ls_qty-kdpos.
      IF sy-subrc <> 0. CONTINUE. ENDIF.

      <o>-tot_cmp = <o>-tot_cmp + 1.

      " Komponen yang qty-nya TIDAK bisa dipilah per SO: jangan dinilai sama sekali.
      " Tidak dihitung "selesai", tidak pula diberi persentase palsu dari angka global.
      IF ls_qty-nodata = abap_true.
        <o>-nodat_cmp = <o>-nodat_cmp + 1.
        CONTINUE.
      ENDIF.

      lv_code = item_status_cp( iv_need = ls_qty-need iv_q_229k = ls_qty-q229k ).
      IF lv_code = gc_st_done.
        <o>-done_cmp = <o>-done_cmp + 1.
      ENDIF.
      " pct disimpan sementara sbg TOTAL; dibagi jumlah komponen di langkah 5.
      <o>-pct = <o>-pct + item_pct_cp( iv_need = ls_qty-need iv_q_229k = ls_qty-q229k ).

      " Tanggal selesai item = saat komponen TERAKHIR sampai 229K → ambil budat
      " TERBESAR di antara komponen. (Hanya dipertahankan bila item benar selesai.)
      IF ls_qty-last_in > <o>-fin_date.
        <o>-fin_date = ls_qty-last_in.
      ENDIF.
    ENDLOOP.

    " 5. Finalisasi: rata-ratakan pct & tetapkan kode status item.
    LOOP AT rt_item ASSIGNING <o>.
      IF <o>-tot_cmp <= 0.
        <o>-code = gc_st_noprod.   " tanpa komponen → belum produksi
        <o>-pct  = 0.
        CLEAR <o>-fin_date.
        CONTINUE.
      ENDIF.

      " Ada komponen yang datanya tak bisa dipilah per SO → status item TIDAK BISA
      " ditentukan. Sengaja BUKAN "belum produksi" (menyesatkan) & BUKAN "selesai".
      IF <o>-nodat_cmp > 0.
        <o>-code = gc_st_nodata.
        <o>-pct  = 0.
        CLEAR <o>-fin_date.
        CONTINUE.
      ENDIF.

      lv_sum = <o>-pct.
      <o>-pct = lv_sum / <o>-tot_cmp.
      IF <o>-done_cmp >= <o>-tot_cmp.
        <o>-code = gc_st_done.     " SEMUA komponen sampai 229K
      ELSE.
        <o>-code = gc_st_inprog.
        CLEAR <o>-fin_date.        " belum selesai → tak punya tanggal selesai
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD wf_line_name.
    " Whitelist TERTUTUP — di luar 10 kode ini → '' (pemanggil beri badge netral).
    CASE iv_kostl.
      WHEN gc_cc_line_a.   rv_name = 'Line A'.
      WHEN gc_cc_line_b.   rv_name = 'Line B'.
      WHEN gc_cc_line_c.   rv_name = 'Line C'.
      WHEN gc_cc_edgeband. rv_name = 'Edge Banding'.
      WHEN gc_cc_preassy.  rv_name = 'Pre Assembly'.
      WHEN gc_cc_lifter_a. rv_name = 'Lifter A'.
      WHEN gc_cc_lifter_b. rv_name = 'Lifter B'.
      WHEN gc_cc_lifter_c. rv_name = 'Lifter C'.
      WHEN gc_cc_cstorage. rv_name = 'Central Storage'.
      WHEN gc_cc_sample.   rv_name = 'Sample Maker'.
      WHEN OTHERS.         CLEAR rv_name.
    ENDCASE.
  ENDMETHOD.

  METHOD wf_route_status.
    " Lookup STATIS SLoc → status sederhana (plan §11.2). Tanpa query.
    "
    " ⚠️ SENGAJA TIDAK DIPETAKAN: gc_sloc_22f2 (Color Room) & gc_sloc_22f3
    "    (CG Packing Area). BELUM diverifikasi apakah termasuk rute Wood
    "    Furniture — keduanya muncul di BOM CAMPURAN (komponen WF *dan* Chair).
    "    Dibiarkan jatuh ke WHEN OTHERS = gc_route_out (DEFAULT AMAN) agar tidak
    "    salah klaim status. JANGAN tambahkan ke CASE ini tanpa verifikasi dulu.
    CASE iv_lgort.
      WHEN gc_sloc_2kcs. rv_status = 'Baru Masuk Central Storage'.
      WHEN gc_sloc_2261. rv_status = 'Sedang di Machining'.
      WHEN gc_sloc_2262. rv_status = 'Sedang di Machining'.
      WHEN gc_sloc_22e2. rv_status = 'Sedang di Edge Banding'.
      WHEN gc_sloc_22ek. rv_status = 'Sedang di Edge Banding'.
      WHEN gc_sloc_2291. rv_status = 'Sedang di Sanding'.
      WHEN gc_sloc_2292. rv_status = 'Sedang di Sanding'.
      WHEN gc_sloc_2293. rv_status = 'Sedang di Assembly'.
      WHEN gc_sloc_2294. rv_status = 'Sedang di Assembly'.
      WHEN gc_sloc_229k. rv_status = 'Sampai Batas Akhir (229K)'.
      WHEN OTHERS.       rv_status = gc_route_out.
    ENDCASE.
  ENDMETHOD.

  METHOD pmb_output_status.
    " D7 (v2, disederhanakan). Lihat dokumentasi lengkap di deklarasi & header
    " REVISI FASE-3. Ringkas: telusuri MSEG⨝MKPF (101 GR / 321 QI-release /
    " 261 konsumsi / 301+311 transfer keluar), discope SO+item+SOBKZ='E',
    " key = MATERIAL (bukan order) — lalu pilah qty ke qty_qc/qty_wait/
    " qty_used/qty_sent.
    "
    " Order KONSUMEN (261) dibaca LANGSUNG dari MSEG-AUFNR baris itu sendiri —
    " field ini memang terisi utk goods issue ke order (261), TIDAK perlu
    " ditelusuri lewat RESB-RSNUM (versi sebelumnya sempat memakai RSNUM,
    " disederhanakan krn AUFNR sudah cukup & lebih langsung).
    TYPES: BEGIN OF lty_mat,
             matnr TYPE resb-matnr,
           END OF lty_mat,
           BEGIN OF lty_mv,
             matnr TYPE mseg-matnr,
             werks TYPE mseg-werks,
             lgort TYPE mseg-lgort,
             umlgo TYPE mseg-umlgo,
             umwrk TYPE mseg-umwrk,
             aufnr TYPE mseg-aufnr,
             bwart TYPE mseg-bwart,
             shkzg TYPE mseg-shkzg,
             menge TYPE mseg-menge,
             kdauf TYPE mseg-kdauf,
             kdpos TYPE mseg-kdpos,
             sobkz TYPE mseg-sobkz,
             insmk TYPE mseg-insmk,
             budat TYPE mkpf-budat,
           END OF lty_mv.

    DATA: lt_mat TYPE TABLE OF lty_mat, ls_mat TYPE lty_mat,
          lt_mv  TYPE TABLE OF lty_mv,  ls_mv  TYPE lty_mv,
          ls_key TYPE ty_pmbkey,
          ls_out TYPE ty_pmbstatus,
          lr_bw  TYPE ty_bwart_range,
          ls_bw  LIKE LINE OF lr_bw.

    FIELD-SYMBOLS: <o> TYPE ty_pmbstatus,
                   <d> TYPE ty_pmbdest,
                   <u> TYPE ty_pmbused.

    IF it_key IS INITIAL.
      RETURN.
    ENDIF.

    " Kerangka hasil + driver material unik.
    LOOP AT it_key INTO ls_key.
      CLEAR ls_out.
      ls_out-kdauf = ls_key-kdauf.
      ls_out-kdpos = ls_key-kdpos.
      ls_out-matnr = ls_key-matnr.
      INSERT ls_out INTO TABLE rt_status.

      ls_mat-matnr = ls_key-matnr.
      APPEND ls_mat TO lt_mat.
    ENDLOOP.
    SORT lt_mat BY matnr.
    DELETE ADJACENT DUPLICATES FROM lt_mat COMPARING matnr.

    lr_bw = transfer_bwarts( ).                        " 301/311
    ls_bw-sign = 'I'. ls_bw-option = 'EQ'.
    ls_bw-low  = gc_bwart_gr. APPEND ls_bw TO lr_bw.    " +101
    ls_bw-low  = gc_bwart_qi. APPEND ls_bw TO lr_bw.    " +321
    ls_bw-low  = gc_bwart_gi. APPEND ls_bw TO lr_bw.    " +261

    SELECT m~matnr m~werks m~lgort m~umlgo m~umwrk m~aufnr m~bwart m~shkzg
           m~menge m~kdauf m~kdpos m~sobkz m~insmk k~budat
      FROM mseg AS m INNER JOIN mkpf AS k
        ON m~mblnr = k~mblnr AND m~mjahr = k~mjahr
      INTO TABLE lt_mv
      FOR ALL ENTRIES IN lt_mat
      WHERE m~matnr = lt_mat-matnr
        AND m~bwart IN lr_bw.
    IF lt_mv IS INITIAL.
      RETURN.
    ENDIF.

    " --- 1. GR (101): tentukan src_lgort (dibaca dari data) + qty_gr + pilah
    "        ke qty_qc (INSMK='X') vs qty_wait (langsung unrestricted). -------
    LOOP AT lt_mv INTO ls_mv WHERE bwart = gc_bwart_gr.
      IF ls_mv-kdauf IS INITIAL OR ls_mv-sobkz <> gc_sobkz_e. CONTINUE. ENDIF.
      READ TABLE rt_status ASSIGNING <o>
        WITH TABLE KEY kdauf = ls_mv-kdauf kdpos = ls_mv-kdpos matnr = ls_mv-matnr.
      IF sy-subrc <> 0. CONTINUE. ENDIF.

      IF <o>-src_lgort IS INITIAL.
        <o>-src_lgort = ls_mv-lgort.
      ENDIF.

      IF ls_mv-shkzg = gc_shkzg_s.
        <o>-qty_gr = <o>-qty_gr + ls_mv-menge.
        IF ls_mv-insmk = gc_insmk_qi.
          <o>-qty_qc   = <o>-qty_qc   + ls_mv-menge.
        ELSE.
          <o>-qty_wait = <o>-qty_wait + ls_mv-menge.
        ENDIF.
      ELSEIF ls_mv-shkzg = gc_shkzg_h.
        " Retur GR (jarang).
        <o>-qty_gr = <o>-qty_gr - ls_mv-menge.
        IF ls_mv-insmk = gc_insmk_qi.
          <o>-qty_qc   = <o>-qty_qc   - ls_mv-menge.
        ELSE.
          <o>-qty_wait = <o>-qty_wait - ls_mv-menge.
        ENDIF.
      ENDIF.
    ENDLOOP.

    " --- 2. QI release (321): baris 'H' = keluar dari Quality Insp sebesar
    "        MENGE. Tidak butuh AUFNR — sudah dikunci oleh key (kdauf,kdpos,
    "        matnr) yang sama dgn GR. -----------------------------------------
    LOOP AT lt_mv INTO ls_mv WHERE bwart = gc_bwart_qi AND shkzg = gc_shkzg_h.
      IF ls_mv-kdauf IS INITIAL OR ls_mv-sobkz <> gc_sobkz_e. CONTINUE. ENDIF.
      READ TABLE rt_status ASSIGNING <o>
        WITH TABLE KEY kdauf = ls_mv-kdauf kdpos = ls_mv-kdpos matnr = ls_mv-matnr.
      IF sy-subrc <> 0. CONTINUE. ENDIF.
      <o>-qty_qc   = <o>-qty_qc   - ls_mv-menge.
      <o>-qty_wait = <o>-qty_wait + ls_mv-menge.
    ENDLOOP.

    " --- 3. Konsumsi (261, Goods Issue ke order lain) DI src_lgort: qty_wait
    "        berkurang, qty_used bertambah. Order konsumen = MSEG-AUFNR baris
    "        ini LANGSUNG (261 memang mengisi field ini), TANPA perlu
    "        menelusuri RESB-RSNUM. -----------------------------------------
    LOOP AT lt_mv INTO ls_mv WHERE bwart = gc_bwart_gi.
      IF ls_mv-kdauf IS INITIAL OR ls_mv-sobkz <> gc_sobkz_e. CONTINUE. ENDIF.
      READ TABLE rt_status ASSIGNING <o>
        WITH TABLE KEY kdauf = ls_mv-kdauf kdpos = ls_mv-kdpos matnr = ls_mv-matnr.
      IF sy-subrc <> 0. CONTINUE. ENDIF.
      IF <o>-src_lgort IS NOT INITIAL AND ls_mv-lgort <> <o>-src_lgort. CONTINUE. ENDIF.

      IF ls_mv-shkzg = gc_shkzg_h.
        <o>-qty_wait = <o>-qty_wait - ls_mv-menge.
        <o>-qty_used = <o>-qty_used + ls_mv-menge.

        READ TABLE <o>-t_used ASSIGNING <u> WITH KEY aufnr = ls_mv-aufnr.
        IF sy-subrc = 0.
          <u>-qty = <u>-qty + ls_mv-menge.
          IF ls_mv-budat > <u>-last_dt. <u>-last_dt = ls_mv-budat. ENDIF.
        ELSE.
          APPEND INITIAL LINE TO <o>-t_used ASSIGNING <u>.
          <u>-aufnr   = ls_mv-aufnr.   " kosong bila baris 261 ini tak ber-AUFNR
          <u>-qty     = ls_mv-menge.
          <u>-last_dt = ls_mv-budat.
        ENDIF.
      ELSEIF ls_mv-shkzg = gc_shkzg_s.
        " Retur GI (jarang) — batalkan sebagian konsumsi.
        <o>-qty_wait = <o>-qty_wait + ls_mv-menge.
        <o>-qty_used = <o>-qty_used - ls_mv-menge.
      ENDIF.
    ENDLOOP.

    " --- 4. Transfer keluar fisik (301/311) DI src_lgort: qty_wait berkurang,
    "        qty_sent bertambah. UMWRK/UMLGO baris ini = tujuan. -------------
    LOOP AT lt_mv INTO ls_mv WHERE ( bwart = gc_bwart_301 OR bwart = gc_bwart_311 ).
      IF ls_mv-kdauf IS INITIAL OR ls_mv-sobkz <> gc_sobkz_e. CONTINUE. ENDIF.
      READ TABLE rt_status ASSIGNING <o>
        WITH TABLE KEY kdauf = ls_mv-kdauf kdpos = ls_mv-kdpos matnr = ls_mv-matnr.
      IF sy-subrc <> 0. CONTINUE. ENDIF.
      IF <o>-src_lgort IS INITIAL OR ls_mv-lgort <> <o>-src_lgort. CONTINUE. ENDIF.

      IF ls_mv-shkzg = gc_shkzg_h.
        <o>-qty_wait = <o>-qty_wait - ls_mv-menge.
        <o>-qty_sent = <o>-qty_sent + ls_mv-menge.

        READ TABLE <o>-t_dest ASSIGNING <d>
          WITH KEY werks = ls_mv-umwrk lgort = ls_mv-umlgo.
        IF sy-subrc = 0.
          <d>-qty = <d>-qty + ls_mv-menge.
          IF ls_mv-budat > <d>-last_dt. <d>-last_dt = ls_mv-budat. ENDIF.
        ELSE.
          APPEND INITIAL LINE TO <o>-t_dest ASSIGNING <d>.
          <d>-werks   = ls_mv-umwrk.
          <d>-lgort   = ls_mv-umlgo.
          <d>-qty     = ls_mv-menge.
          <d>-last_dt = ls_mv-budat.
        ENDIF.
      ELSEIF ls_mv-shkzg = gc_shkzg_s.
        " Retur balik ke src_lgort (jarang) — batalkan sebagian pengiriman.
        <o>-qty_wait = <o>-qty_wait + ls_mv-menge.
        <o>-qty_sent = <o>-qty_sent - ls_mv-menge.
      ENDIF.
    ENDLOOP.

    " --- 5. Jepit non-negatif (retur/pembulatan bisa membuat net sedikit minus) ---
    LOOP AT rt_status ASSIGNING <o>.
      IF <o>-qty_gr   < 0. <o>-qty_gr   = 0. ENDIF.
      IF <o>-qty_qc   < 0. <o>-qty_qc   = 0. ENDIF.
      IF <o>-qty_wait < 0. <o>-qty_wait = 0. ENDIF.
      IF <o>-qty_used < 0. <o>-qty_used = 0. ENDIF.
      IF <o>-qty_sent < 0. <o>-qty_sent = 0. ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
