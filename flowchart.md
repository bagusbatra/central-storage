# Flowchart — Monitoring Production (Central Storage)

> Diagram alur sistem secara detail mencakup BSP Application dan ABAP Report.

---

## Daftar Isi

1. [Flowchart Sistem Utama](#1-flowchart-sistem-utama)
2. [Flowchart BSP — index.htm](#2-flowchart-bsp--indexhtm)
3. [Flowchart BSP — main.htm (Detail)](#3-flowchart-bsp--mainhtm-detail)
4. [Flowchart ABAP Report — ZMON_CNC_KMI2](#4-flowchart-abap-report--zmon_cnc_kmi2)
5. [Flowchart Database Query](#5-flowchart-database-query)
6. [Flowchart Progress Bar Logic](#6-flowchart-progress-bar-logic)
7. [Flowchart JavaScript Filter (Client-side)](#7-flowchart-javascript-filter-client-side)
8. [Flowchart Error Handling](#8-flowchart-error-handling)
9. [Activity Diagram — BSP Path](#9-activity-diagram--bsp-path)
10. [Activity Diagram — Report Path](#10-activity-diagram--report-path)
11. [State Diagram — Halaman main.htm](#11-state-diagram--halaman-mainhtm)
12. [Timeline — Request/Response Lifecycle](#12-timeline--requestresponse-lifecycle)

---

## 1. Flowchart Sistem Utama

```mermaid
flowchart TD
  START([Start]) --> CHOICE{Metode Akses?}

  CHOICE -->|"Web Browser via URL<br/>SECE / SICF"| BSP_PATH
  CHOICE -->|"SAP GUI via SE38<br/>atau SA38"| REPORT_PATH

  %% ── BSP PATH ──
  subgraph BSP_PATH["BSP Application (SE80) — ZCNC_MONITOR_BS"]
    direction TB
    B1["index.htm<br/>Halaman Form Pencarian"] --> B2["User mengisi:<br/>vbeln + posnr"]
    B2 --> B3["Klik tombol<br/>Search Production Data"]
    B3 --> B4["Form submit method=GET<br/>action=main.htm"]
    B4 --> B5["main.htm menerima parameter<br/>request->get_form_field()"]
    B5 --> B6{"Parameter vbeln<br/>ada isinya?"}
    B6 -->|"Ya"| B7["SELECT query ke 6 tabel SAP<br/>AFPO + AFKO + AFVC + CRHD + MARC + MAKT"]
    B6 -->|"Tidak / Kosong"| B8["SELECT tanpa kondisi<br/>→ dataset kosong"]
    B7 --> B9{"Data ditemukan?"}
    B8 --> B9
    B9 -->|"Ya — lt_data IS NOT INITIAL"| B10["LOOP AT lt_data<br/>hitung progress per baris"]
    B9 -->|"Tidak — lt_data IS INITIAL"| B11["Render baris empty state<br/>colspan=10 pesan error"]
    B10 --> B12["Render tabel lengkap:<br/>- 10 kolom data<br/>- Progress bar + %<br/>- data-wc & data-mrp"]
    B11 --> B13["Render tabel dengan<br/>1 baris empty state"]
    B12 --> B14["JavaScript buildDropdowns()<br/>dari data-wc & data-mrp"]
    B13 --> B14
    B14 --> B15["Tampilkan halaman<br/>lengkap ke user"]
  end

  %% ── REPORT PATH ──
  subgraph REPORT_PATH["ABAP Report (SE38) — ZMON_CNC_KMI2"]
    direction TB
    R1["START-OF-SELECTION event"] --> R2["Tampilkan Selection Screen:<br/>p_vbeln (wajib)<br/>p_posnr (opsional)<br/>p_werks (default 2000)<br/>s_arbpl (opsional)"]
    R2 --> R3["User isi parameter + F8"]
    R3 --> R4{"Input p_vbeln<br/>terisi?"}
    R4 -->|"Ya"| R5["PERFORM get_data"]
    R4 -->|"Tidak"| R6["Selection screen error<br/>(OBLIGATORY field)"]
    R6 --> R2
    R5 --> R7["PERFORM calculate_progress"]
    R7 --> R8["PERFORM display_alv<br/>CL_SALV_TABLE=>FACTORY"]
    R8 --> R9{"TRY ... CATCH<br/>cx_salv_msg?"}
    R9 -->|"No error"| R10["lo_alv->display()<br/>Tampilkan ALV Grid"]
    R9 -->|"Error"| R11["CATCH — tidak ada<br/>pesan error ke user<br/>(silent catch)"]
    R10 --> R12["User interaksi dengan ALV:<br/>sort, filter, export, print"]
    R11 --> END_REPORT([End Report])
    R12 --> END_REPORT
  end

  BSP_PATH --> END([Selesai])
```

---

## 2. Flowchart BSP — index.htm

```mermaid
flowchart TD
  START([User request index.htm]) --> PARSE["BSP Runtime parse halaman<br/>(tidak ada kode ABAP)"]
  PARSE --> HTML["Render HTML statis:<br/>Header + Form + Footer"]
  HTML --> DISPLAY["Tampilkan di browser"]

  USER_FORM["User lihat form:"] --> INPUT1["Isi Sales Order (vbeln)"]
  INPUT1 --> INPUT2["Isi Item (posnr)"]
  INPUT2 --> SUBMIT["Klik Search Production Data"]

  SUBMIT --> VALIDATE{"Client-side<br/>HTML5 validation?"}
  VALIDATE -->|"Browser validation<br/>(jika ada required)"| VALID_PASS["Browser tidak submit<br/>jika required kosong"]
  VALIDATE -->|"Tidak ada required attribute"| SUBMIT_OK["Form submit via GET"]

  SUBMIT_OK --> URL["Browser navigate ke:<br/>main.htm?vbeln=xxx&amp;posnr=xxx"]
  URL --> BROWSER["Browser kirim HTTP GET request<br/>ke server SAP"]

  VALID_PASS --> INPUT1
```

### Detail Form HTML (index.htm baris 144–155)

```html
<form method="get" action="main.htm">
  <input type="text" name="vbeln" placeholder="e.g. 4500001234">
  <input type="text" name="posnr" placeholder="e.g. 000010">
  <input type="submit" value="Search Production Data">
</form>
```

**Catatan:** Tidak ada `required` attribute → browser tidak akan memvalidasi. Semua data dikirim apa adanya.

---

## 3. Flowchart BSP — main.htm (Detail)

### 3a. ABAP Processing Phase

```mermaid
flowchart TD
  REQ(["HTTP GET Request<br/>?vbeln=&posnr="]) --> BSP_START
  subgraph BSP_START["BSP Runtime Processing"]
    direction TB
    A["<%@ page language='abap' %>"] --> B["TYPES: ty_data<br/>9 fields"]
    B --> C["DATA: lt_data, ls_data<br/>lv_vbeln, lv_posnr"]
    C --> D["request->get_form_field('vbeln')"]
    D --> E["request->get_form_field('posnr')"]
    E --> F["SELECT ... (lihat flowchart 5)"]
    F --> G{"sy-subrc = 0?<br/>Data found?"}
    G -->|Yes| H["LOOP AT lt_data INTO ls_data"]
    G -->|No| I["lt_data tetap INITIAL"]
    H --> J["Hitung progress %<br/>psmng = 0? → 0%<br/>psmng > 0? → wemng/psmng*100"]
    J --> K["Tentukan CSS class:<br/>pct-zero/low/mid/high/full"]
    K --> L["Render baris &lt;tr&gt;<br/>dengan data-wc & data-mrp"]
    L --> H
    H -->|EXIT| M["Cek lt_data IS INITIAL"]
    I --> M
    M -->|INITIAL| N["Render empty state row"]
    M -->|NOT INITIAL| O["Semua baris sudah di-render"]
    N --> P["Lanjut ke HTML rendering"]
    O --> P
  end
  P --> HTML_OUT
```

### 3b. HTML + CSS + JS Rendering Phase

```mermaid
flowchart LR
  subgraph HTML_OUT["HTML Rendering (baris 57–598)"]
    direction TB
    H1["Top Header:<br/>Logo + Judul + New Search button"]
    H2["Top Bar:<br/>Filter Tags (SO# + Item#)<br/>Badge Record Count"]
    H3["Filter Panel:<br/>Work Center dropdown<br/>MRP dropdown<br/>Reset button<br/>Filter info text"]
    H4["Table Card:<br/>10-column table<br/>Sticky header<br/>Scrollable body"]
    H5["Page Footer"]
  end

  subgraph JS_EXEC["JavaScript Execution (baris 600–679)"]
    direction TB
    J1["window.onload<br/>buildDropdowns()"]
    J2["Query semua &lt;tr data-wc&gt;"]
    J3["Kumpulkan unique WC + MRP"]
    J4["Sort alphabetically"]
    J5["Buat &lt;option&gt; element<br/>append ke &lt;select&gt;"]
    J6["Siap: user bisa filter"]
  end

  H4 --> J1 --> J2 --> J3 --> J4 --> J5 --> J6
```

### 3c. User Interaction (Post-Render)

```mermaid
flowchart TD
  USER(["User melihat halaman<br/>hasil"]) --> OPTIONS{"Aksi user?"}

  OPTIONS -->|"Filter Work Center"| F1["Pilih value di dropdown<br/>#filter-wc"]
  OPTIONS -->|"Filter MRP Controller"| F2["Pilih value di dropdown<br/>#filter-mrp"]
  OPTIONS -->|"Reset Filter"| F3["Klik tombol Reset Filter"]
  OPTIONS -->|"New Search"| F4["Klik tombol ← New Search"]
  OPTIONS -->|"Scroll data"| F5["Scroll tabel vertikal<br/>header tetap (sticky)"]

  F1 --> APPLY["onchange → applyFilters()"]
  F2 --> APPLY
  F3 --> RESET["resetFilters()<br/>→ set value = ''"]
  RESET --> APPLY

  APPLY --> A1["Baca selWC & selMRP"]
  A1 --> A2["Iterasi semua &lt;tr data-wc&gt;"]
  A2 --> MATCH{"data-wc == selWC<br/>(atau selWC kosong)<br/>AND<br/>data-mrp == selMRP<br/>(atau selMRP kosong)"}

  MATCH -->|"Ya"| SHOW["Hapus class 'hidden-row'<br/>visible++"]
  MATCH -->|"Tidak"| HIDE["Tambah class 'hidden-row'"]

  SHOW --> NEXT{Masih ada row<br/>lain?}
  HIDE --> NEXT
  NEXT -->|"Ya"| A2
  NEXT -->|"Tidak"| UPDATE["Update badge: visible + ' Record(s)' "]
  UPDATE --> CHECK{"visible = 0?"}
  CHECK -->|"Ya"| NOMSG["Tampilkan #no-filter-msg"]
  CHECK -->|"Tidak"| HIDEMSG["Sembunyikan #no-filter-msg"]
  NOMSG --> DONE
  HIDEMSG --> DONE

  F4 --> NAV["window.location = 'index.htm'<br/>GET request baru"]

  DONE(["Filter applied"])
```

---

## 4. Flowchart ABAP Report — ZMON_CNC_KMI2

### 4a. Report Lifecycle Penuh

```mermaid
flowchart TD
  EXECUTE(["User execute program<br/>via SE38 / SA38"]) --> LOAD["Report Load:<br/>LOAD-OF-PROGRAM"]
  LOAD --> INIT["INITIALIZATION:<br/>Set default values"]
  INIT --> SS["Selection Screen:<br/>PBO (Process Before Output)"]
  SS --> DISPLAY_SS["Tampilkan screen 100<br/>(standard selection screen)"]
  DISPLAY_SS --> USER_INPUT["User isi parameter:<br/>p_vbeln, p_posnr, p_werks, s_arbpl"]
  USER_INPUT --> USER_F8["User tekan F8 (Execute)"]
  USER_F8 --> PAI["PAI (Process After Input)"]

  PAI --> VALID{"p_vbeln<br/>OBLIGATORY terisi?"}
  VALID -->|"Ya"| SOS["START-OF-SELECTION"]
  VALID -->|"Tidak"| ERROR["E-Message:<br/>'Enter Sales Order'"] --> SS

  SOS --> CALL_GD["PERFORM get_data"]
  CALL_GD --> GD["FORM get_data<br/>(Lihat flowchart 4b)"]
  GD --> CALL_CP["PERFORM calculate_progress"]
  CALL_CP --> CP["FORM calculate_progress<br/>(Lihat flowchart 4c)"]
  CP --> CALL_DA["PERFORM display_alv"]
  CALL_DA --> DA["FORM display_alv<br/>(Lihat flowchart 4d)"]

  DA --> ALV["ALV Grid ditampilkan"]
  ALV --> USER_ALV{"User interaksi<br/>dengan ALV"}

  USER_ALV -->|"Sort kolom"| ALV_SORT["Klik header → sort asc/desc"]
  USER_ALV -->|"Filter"| ALV_FILTER["Klik filter icon → input value"]
  USER_ALV -->|"Export"| ALV_EXPORT["Klik spreadsheet icon<br/>→ Excel / CSV / HTML"]
  USER_ALV -->|"Layout"| ALV_LAYOUT["Klik layout icon<br/>→ save/load layout"]
  USER_ALV -->|"Print"| ALV_PRINT["Klik print icon"]
  USER_ALV -->|"Back / F3 / Exit"| ALV_EXIT

  ALV_SORT --> ALV
  ALV_FILTER --> ALV
  ALV_EXPORT --> ALV
  ALV_LAYOUT --> ALV
  ALV_PRINT --> ALV

  ALV_EXIT --> END_PGM([Program selesai])
```

### 4b. FORM get_data (Detail)

```mermaid
flowchart TD
  START_GD(["PERFORM get_data"]) --> OPEN_SQL["SELECT statement:<br/>9 fields dari 6 tabel"]
  OPEN_SQL --> JOIN_1["AFPO → AFKO<br/>INNER JOIN aufnr"]
  JOIN_1 --> JOIN_2["AFKO → AFVC<br/>INNER JOIN aufpl"]
  JOIN_2 --> JOIN_3["AFVC → CRHD<br/>INNER JOIN arbid = objid"]
  JOIN_3 --> JOIN_4["AFPO → MARC<br/>INNER JOIN matnr<br/>+ werks = @p_werks"]
  JOIN_4 --> JOIN_5["AFPO → MAKT<br/>LEFT JOIN matnr<br/>+ spras = @sy-langu"]

  JOIN_5 --> WHERE_1["WHERE kdauf = @p_vbeln"]
  WHERE_1 --> WHERE_2{"p_posnr IS INITIAL?"}
  WHERE_2 -->|"Ya"| WHERE_3["(TANPA filter posnr)"]
  WHERE_2 -->|"Tidak"| WHERE_4["AND kdpos = @p_posnr"]

  WHERE_3 --> WHERE_5["AND d~werks = @p_werks"]
  WHERE_4 --> WHERE_5
  WHERE_5 --> WHERE_6{"s_arbpl kosong?"}
  WHERE_6 -->|"Tidak"| WHERE_7["AND d~arbpl IN @s_arbpl"]
  WHERE_6 -->|"Ya"| WHERE_8["(TANPA filter arbpl)"]
  WHERE_7 --> INTO["INTO TABLE @gt_data"]
  WHERE_8 --> INTO

  INTO --> CHECK_SY{"sy-subrc = 0?"}

  CHECK_SY -->|"0"| SUCCESS["gt_data berisi N records"]
  CHECK_SY -->|"4"| EMPTY["gt_data kosong<br/>(tidak ada data)"]

  SUCCESS --> END_GD([END FORM])
  EMPTY --> END_GD
```

### 4c. FORM calculate_progress (Detail)

```mermaid
flowchart TD
  START_CP(["PERFORM calculate_progress"]) --> FS["FIELD-SYMBOLS: &lt;fs&gt; TYPE ty_data"]
  FS --> LOOP_START["LOOP AT gt_data ASSIGNING &lt;fs&gt;"]

  LOOP_START --> CHECK_TARGET{"&lt;fs&gt;-target > 0"}
  CHECK_TARGET -->|"Ya"| CALC["&lt;fs&gt;-progress =<br/>( &lt;fs&gt;-done / &lt;fs&gt;-target ) × 100"]
  CHECK_TARGET -->|"Tidak"| SET_ZERO["&lt;fs&gt;-progress = 0"]

  CALC --> LOOP_NEXT["CONTINUE — next record"]
  SET_ZERO --> LOOP_NEXT

  LOOP_NEXT --> LOOP_CHECK{"Masih ada record?"}
  LOOP_CHECK -->|"Ya"| LOOP_START
  LOOP_CHECK -->|"Tidak"| END_CP([END FORM])
```

### 4d. FORM display_alv (Detail)

```mermaid
flowchart TD
  START_DA(["PERFORM display_alv"]) --> TRY_START["TRY"]
  TRY_START --> FACTORY["cl_salv_table=>factory(<br/>IMPORTING r_salv_table<br/>CHANGING t_table = gt_data)"]

  FACTORY --> GET_COL["lo_columns = lo_alv->get_columns()"]
  GET_COL --> COL_PROGRESS["lo_column ?= lo_columns->get_column('PROGRESS')"]
  COL_PROGRESS --> SET_SHORT["set_short_text('Prog%')"]
  SET_SHORT --> SET_MEDIUM["set_medium_text('Progress %')"]
  SET_MEDIUM --> SET_LONG["set_long_text('Production Progress %')"]

  SET_LONG --> DISPLAY["lo_alv->display()"]
  DISPLAY --> CATCH{"CATCH cx_salv_msg"}
  CATCH -->|"No exception"| SUCCESS_END["ALV ditampilkan"]
  CATCH -->|"Exception"| SILENT["Silent catch —<br/>tidak ada pesan error"]

  SUCCESS_END --> END_DA([END FORM])
  SILENT --> END_DA
```

---

## 5. Flowchart Database Query

### 5a. Query Execution Plan

```mermaid
flowchart TD
  QSTART(["SELECT dari AFPO (a)"]) --> ACCESS{"Metode access<br/>AFPO"}

  ACCESS -->|"Index pada (kdauf, kdpos)"| INDEX_SCAN["INDEX RANGE SCAN<br/>AFPO~KDDUA<br/>kdauf = X, kdpos = Y"]
  ACCESS -->|"Full table scan<br/>(tanpa index)"| FULL_SCAN["FULL TABLE SCAN<br/>AFPO — filter kdauf + kdpos<br/>setelah scan"]

  INDEX_SCAN --> ROW["Satu/beberapa row<br/>dari AFPO"]
  FULL_SCAN --> ROW

  ROW --> JOIN_AFKO["Untuk setiap row AFPO:<br/>INNER JOIN AFKO (b)"]
  JOIN_AFKO --> AFKO_ACCESS{"Access AFKO via?"}
  AFKO_ACCESS -->|"Primary Key aufnr"| AFKO_PK["INDEX UNIQUE SCAN<br/>AFKO~0 (aufnr)"]
  AFKO_ACCESS -->|"Lainnya"| AFKO_OTHER

  AFKO_PK --> JOIN_AFVC["INNER JOIN AFVC (c)"]
  AFKO_OTHER --> JOIN_AFVC
  JOIN_AFVC --> AFVC_ACCESS{"Access AFVC via?"}
  AFVC_ACCESS -->|"Primary Key aufpl"| AFVC_PK["INDEX UNIQUE SCAN<br/>AFVC~0 (aufpl)"]

  AFVC_PK --> JOIN_CRHD["INNER JOIN CRHD (d)"]
  JOIN_CRHD --> CRHD_ACCESS{"Access CRHD via?"}
  CRHD_ACCESS -->|"Primary Key objid"| CRHD_PK["INDEX UNIQUE SCAN<br/>CRHD~0 (objid)"]

  CRHD_PK --> JOIN_MARC["INNER JOIN MARC (f)"]
  JOIN_MARC --> MARC_ACCESS{"Access MARC via?"}
  MARC_ACCESS -->|"Primary Key<br/>matnr + werks"| MARC_PK["INDEX UNIQUE SCAN<br/>MARC~0 (matnr + werks = 2000)"]

  MARC_PK --> JOIN_MAKT["LEFT JOIN MAKT (e)"]
  JOIN_MAKT --> MAKT_ACCESS{"Access MAKT via?"}
  MAKT_ACCESS -->|"Primary Key<br/>matnr + spras"| MAKT_PK["INDEX UNIQUE SCAN<br/>MAKT~0 (matnr + spras)"]

  MAKT_PK --> RESULT["Hasil akhir:<br/>1 row per operation<br/>per production order"]

  RESULT --> NOTE1["Catatan:<br/>JOIN AFKO-AFVC bisa<br/>menghasilkan MULTIPLE ROWS<br/>jika 1 order punya >1 operation<br/>(routing multi-step)"]

  join_style fill:#e1f5fe,stroke:#0288d1
  access_style fill:#fff3e0,stroke:#ff9800
  result_style fill:#e8f5e9,stroke:#43a047

  class JOIN_AFKO,JOIN_AFVC,JOIN_CRHD,JOIN_MARC,JOIN_MAKT join_style
  class ACCESS,AFKO_ACCESS,AFVC_ACCESS,CRHD_ACCESS,MARC_ACCESS,MAKT_ACCESS access_style
  class RESULT,NOTE1 result_style
```

### 5b. Data Flow Diagram (DFD Level 0)

```mermaid
flowchart LR
  USER([User]) ---|"Input: vbeln, posnr<br/>Output: Table/ALV"| SYSTEM

  subgraph SYSTEM["Sistem Monitoring Production"]
    direction TB
    P1["Proses 1:<br/>Terima Input"]
    P2["Proses 2:<br/>Query Database"]
    P3["Proses 3:<br/>Hitung Progress"]
    P4["Proses 4:<br/>Tampilkan Hasil"]
  end

  SYSTEM ---|"Query"| DATABASE

  subgraph DATABASE["SAP HANA Database"]
    D1[(AFPO)]
    D2[(AFKO)]
    D3[(AFVC)]
    D4[(CRHD)]
    D5[(MARC)]
    D6[(MAKT)]
  end

  %% Data stores ke proses
  D1 ---|"kdauf, kdpos, aufnr, matnr, psmng, wemng"| P2
  D2 ---|"aufnr, aufpl"| P2
  D3 ---|"aufpl, arbid"| P2
  D4 ---|"objid, arbpl, werks"| P2
  D5 ---|"matnr, werks, dispo"| P2
  D6 ---|"matnr, spras, maktx"| P2

  P1 -->|"vbeln, posnr"| P2
  P2 -->|"Dataset mentah"| P3
  P3 -->|"Progress % dihitung"| P4
  P4 -->|"Tabel + Progress Bar"| USER
```

### 5c. Data Flow Diagram (DFD Level 1 — Proses Query)

```mermaid
flowchart TD
  INPUT(["Input: vbeln, posnr, werks"]) --> SELECT["SELECT + JOIN"]
  SELECT --> FILTER_WC{"Filter Work<br/>Center?"}
  FILTER_WC -->|"BSP: hardcoded werks=2000<br/>Report: parameter p_werks"| FILTER_ARBPL
  FILTER_WC -->|"BSP: semua WC<br/>Report: s_arbpl"| FILTER_ARBPL

  FILTER_ARBPL["WHERE d~werks = X<br/>AND d~arbpl IN s_arbpl"]

  FILTER_ARBPL --> JOIN_RESULT["6 Table JOIN Result"]

  JOIN_RESULT --> DATA_TEMP[(Internal Table<br/>lt_data / gt_data<br/>Semua field)]

  DATA_TEMP --> PROGRESS["Hitung Progress:<br/>wemng / psmng × 100"]
  PROGRESS --> OUTPUT_TEMP[(Internal Table<br/>+ progress field)]

  OUTPUT_TEMP --> RENDER["Render ke:<br/>BSP: HTML table<br/>Report: ALV Grid"]
```

---

## 6. Flowchart Progress Bar Logic

```mermaid
flowchart TD
  START_PROG(["Hitung progress untuk<br/>setiap record"]) --> LOAD_DATA["LOAD DATA:<br/>qty_total = ls_data-qty_total<br/>qty_gr = ls_data-qty_gr"]

  LOAD_DATA --> DECIDE{"qty_total > 0?"}

  DECIDE -->|"Ya"| CALC_PROG["progress =<br/>(qty_gr / qty_total) × 100"]
  DECIDE -->|"Tidak"| ZERO_PROG["progress = 0<br/>Division by zero protection"]

  CALC_PROG --> CLAMP{"progress > 100?"}
  CLAMP -->|"Ya"| CLAMP_100["bar_width = 100"]
  CLAMP -->|"Tidak"| CLAMP_SKIP["bar_width = progress"]
  ZERO_PROG --> CLAMP_SKIP

  CLAMP_100 --> CLASSIFY
  CLAMP_SKIP --> CLASSIFY

  CLASSIFY{"Klasifikasi CSS class<br/>berdasarkan progress"}

  CLASSIFY -->|"progress = 0"| ZERO["bar_class = 'pct-zero'<br/>pct_class = 'pct-zero'"]
  CLASSIFY -->|"0 < progress < 40"| LOW["bar_class = 'pct-low'<br/>pct_class = 'pct-low'"]
  CLASSIFY -->|"40 ≤ progress < 70"| MID["bar_class = 'pct-mid'<br/>pct_class = 'pct-mid'"]
  CLASSIFY -->|"70 ≤ progress < 100"| HIGH["bar_class = 'pct-high'<br/>pct_class = 'pct-high'"]
  CLASSIFY -->|"progress ≥ 100"| FULL["bar_class = 'pct-full'<br/>pct_class = 'pct-full'"]

  ZERO --> RENDER_BAR["RENDER:<br/>&lt;div class='progress-bar-fill {class}'<br/>style='width:{bar_width}%'&gt;<br/>...progress%"]
  LOW --> RENDER_BAR
  MID --> RENDER_BAR
  HIGH --> RENDER_BAR
  FULL --> RENDER_BAR

  RENDER_BAR --> DONE_PROG(["END — lanjut record berikutnya"])
```

### CSS Class Visual Reference

| CSS Class | Bar Background | Bar Box Shadow | Text Color | Text Badge |
|-----------|---------------|----------------|------------|------------|
| `pct-zero` | `#d1d5db` (abu-abu) | None | `#9ca3af` | - |
| `pct-low` | `linear-gradient(90deg, #86efac, #4ade80)` | None | `#16a34a` | - |
| `pct-mid` | `linear-gradient(90deg, #22c55e, #16a34a)` | None | `#15803d` | - |
| `pct-high` | `linear-gradient(90deg, #16a34a, #15803d)` | None | `#15803d` | - |
| `pct-full` | `linear-gradient(90deg, #0f766e, #15803d)` | `0 0 8px rgba(21,128,61,0.5)` | `#14532d` | `bg #dcfce7`, `border #86efac`, `border-radius 6px` |

---

## 7. Flowchart JavaScript Filter (Client-side)

### 7a. buildDropdowns() — Initialization

```mermaid
flowchart TD
  TRIGGER(["window.onload"]) --> QS["document.querySelectorAll<br/>('#table-body tr[data-wc]')"]
  QS --> INIT["wcSet = {}<br/>mrpSet = {}"]
  INIT --> LOOP["Iterasi setiap row"]

  LOOP --> GET_ATTR["wc = row.getAttribute('data-wc')<br/>mrp = row.getAttribute('data-mrp')"]
  GET_ATTR --> CLEAN["Trim whitespace"]
  CLEAN --> ADD_WC{"wc bukan<br/>empty string?"}
  ADD_WC -->|"Ya"| WCSET["wcSet[wc] = true"]
  ADD_WC -->|"Tidak"| SKIP_WC
  WCSET --> ADD_MRP{"mrp bukan<br/>empty string?"}
  SKIP_WC --> ADD_MRP
  ADD_MRP -->|"Ya"| MRPSET["mrpSet[mrp] = true"]
  ADD_MRP -->|"Tidak"| SKIP_MRP
  MRPSET --> NEXT_LOOP{"Masih ada row?"}
  SKIP_MRP --> NEXT_LOOP
  NEXT_LOOP -->|"Ya"| LOOP
  NEXT_LOOP -->|"Tidak"| SORTING

  %% SORTING
  SORTING --> WC_SELECT["document.getElementById('filter-wc')"]
  SORTING --> MRP_SELECT["document.getElementById('filter-mrp')"]

  WC_SORT["Object.keys(wcSet).sort()"] --> WC_ITER["forEach → buat &lt;option&gt;"]
  MRP_SORT["Object.keys(mrpSet).sort()"] --> MRP_ITER["forEach → buat &lt;option&gt;"]

  WC_ITER --> WC_APPEND["opt.value = val<br/>opt.textContent = val<br/>wcSelect.appendChild(opt)"]
  MRP_ITER --> MRP_APPEND["opt.value = val<br/>opt.textContent = val<br/>mrpSelect.appendChild(opt)"]

  WC_APPEND --> DONE_BD(["Selesai: dropdown terisi"])
  MRP_APPEND --> DONE_BD
```

### 7b. applyFilters() — Execution

```mermaid
flowchart TD
  TRIGGER_AF(["onchange event<br/>dari dropdown"]) --> GET_VAL["selWC = #filter-wc.value.trim()<br/>selMRP = #filter-mrp.value.trim()"]
  GET_VAL --> ROWS["rows = querySelectorAll<br/>('#table-body tr[data-wc]')"]
  ROWS --> INIT_VIS["visible = 0"]
  INIT_VIS --> ROW_LOOP["Iterasi setiap row"]

  ROW_LOOP --> GET_RD["wc = row.getAttribute('data-wc')<br/>mrp = row.getAttribute('data-mrp')"]
  GET_RD --> MATCH_WC{"selWC === ''<br/>ATAU<br/>wc === selWC?"}
  MATCH_WC -->|"Tidak"| HIDE_ROW["row.classList.add('hidden-row')"]
  MATCH_WC -->|"Ya"| MATCH_MRP{"selMRP === ''<br/>ATAU<br/>mrp === selMRP?"}

  MATCH_MRP -->|"Tidak"| HIDE_ROW
  MATCH_MRP -->|"Ya"| SHOW_ROW["row.classList.remove('hidden-row')<br/>visible++"]

  SHOW_ROW --> ROW_CHECK{"Masih ada row?"}
  HIDE_ROW --> ROW_CHECK
  ROW_CHECK -->|"Ya"| ROW_LOOP
  ROW_CHECK -->|"Tidak"| UPDATE_BADGE["badge-count.textContent =<br/>visible + ' Record(s) Found'"]

  UPDATE_BADGE --> CHECK_VIS{"visible === 0?"}
  CHECK_VIS -->|"Ya"| SHOW_NOMSG["no-filter-msg.style.display = 'block'"]
  CHECK_VIS -->|"Tidak"| HIDE_NOMSG["no-filter-msg.style.display = 'none'"]

  SHOW_NOMSG --> UPDATE_INFO
  HIDE_NOMSG --> UPDATE_INFO

  UPDATE_INFO["filter-info.textContent =<br/>'Filtered by WC: xx, MRP: yy'"]
  UPDATE_INFO --> DONE_AF(["Filter applied"])
```

### 7c. resetFilters() — Execution

```mermaid
flowchart TD
  TRIGGER_RF(["onclick Reset button<br/>dari user"]) --> RESET_WC["#filter-wc.value = ''"]
  RESET_WC --> RESET_MRP["#filter-mrp.value = ''"]
  RESET_MRP --> CALL_AF["applyFilters()<br/>(semua baris tampil)"]
  CALL_AF --> DONE_RF(["All records visible kembali"])
```

---

## 8. Flowchart Error Handling

```mermaid
flowchart TD
  ERROR_START([Error terjadi]) --> ERROR_TYPE{"Tipe Error?"}

  ERROR_TYPE -->|"Parameter vbeln kosong<br/>(BSP)"| E1["SELECT dengan nilai kosong<br/>→ tidak ada data<br/>→ empty state ditampilkan"]
  ERROR_TYPE -->|"Parameter vbeln kosong<br/>(Report)"| E2["OBLIGATORY akan mencegah<br/>execution — user tetap<br/>di selection screen"]
  ERROR_TYPE -->|"Data tidak ditemukan<br/>(BSP)"| E3["lt_data IS INITIAL<br/>→ baris empty state<br/>colspan=10:<br/>'No production data found'"]
  ERROR_TYPE -->|"Data tidak ditemukan<br/>(Report)"| E4["gt_data kosong<br/>→ ALV tampil dengan<br/>tabel kosong<br/>(0 records)"]
  ERROR_TYPE -->|"ALV error<br/>(Report)"| E5["CATCH cx_salv_msg<br/>→ silent<br/>(tidak ada pesan)"]
  ERROR_TYPE -->|"CSS class tidak match"| E6["Default: pct-zero<br/>→ progress bar abu-abu<br/>(tidak krusial)"]
  ERROR_TYPE -->|"Division by zero"| E7["IF qty_total > 0 check<br/>→ progress = 0<br/>aman dari error"]
  ERROR_TYPE -->|"HTTP error 404<br/>BSP not found"| E8["SICF service tidak aktif<br/>→ periksa SICF activation"]
  ERROR_TYPE -->|"No authorization"| E9["SAP short dump<br/>atau access denied<br/>→ periksa role/authorization"]

  E1 --> E1_RES["User lihat: tabel kosong<br/>+ pesan no data"]
  E2 --> E2_RES["User tetap di screen<br/>sampai isi vbeln"]
  E3 --> E3_RES(["User lihat ikon 📊<br/>dan pesan error"])
  E4 --> E4_RES(["User lihat ALV kosong"])
  E5 --> E5_RES(["Program selesai tanpa ALV"])
  E6 --> E6_RES(["Bar berwarna abu-abu"])
  E7 --> E7_RES(["Progress = 0%"])
  E8 --> E8_RES(["Browser 404 error"])
  E9 --> E9_RES(["SAP GUI error / dump"])
```

---

## 9. Activity Diagram — BSP Path

```mermaid
stateDiagram-v2
  [*] --> Idle
  Idle --> FormDisplayed: GET index.htm
  FormDisplayed --> FillingForm: User input vbeln+posnr
  FillingForm --> SubmittingForm: Klik Search
  SubmittingForm --> ProcessingBSP: GET main.htm?vbeln&posnr

  state ProcessingBSP {
    [*] --> ParseABAP
    ParseABAP --> GetParameter
    GetParameter --> SelectQuery
    SelectQuery --> LoopData
    LoopData --> RenderTable
    RenderTable --> ExecuteJS
    ExecuteJS --> [*]
  }

  ProcessingBSP --> ResultDisplayed: HTML response
  ResultDisplayed --> Filtering: Pilih dropdown
  ResultDisplayed --> GoBack: Klik New Search
  Filtering --> ResultDisplayed: applyFilters()
  GoBack --> FormDisplayed
```

---

## 10. Activity Diagram — Report Path

```mermaid
stateDiagram-v2
  [*] --> Idle
  Idle --> SelectionScreen: SE38 → Execute
  SelectionScreen --> FillingScreen: User input parameters
  FillingScreen --> ValidatingInput: F8
  ValidatingInput --> Error: Input tidak valid
  ValidatingInput --> ExecutingReport: Input valid

  state ExecutingReport {
    [*] --> GetData
    GetData --> CalculateProgress
    CalculateProgress --> DisplayALV
    DisplayALV --> [*]
  }

  Error --> SelectionScreen: Kembali
  ExecutingReport --> ALVDisplayed: ALV Grid muncul
  ALVDisplayed --> Interacting: User sort/filter/export
  Interacting --> ALVDisplayed
  ALVDisplayed --> [*]: F3 / Exit
```

---

## 11. State Diagram — Halaman main.htm

```mermaid
stateDiagram-v2
  [*] --> Loading
  Loading --> EmptyData: lt_data INITIAL
  Loading --> DataLoaded: lt_data NOT INITIAL

  EmptyData --> DisplayEmpty: Render empty state row
  DataLoaded --> DisplayTable: Render full table + progress bars

  DisplayEmpty --> JSInitialized: buildDropdowns() (0 option)
  DisplayTable --> JSInitialized: buildDropdowns() (N options)

  JSInitialized --> Interactive: Halaman siap

  state Interactive {
    [*] --> AllRows
    AllRows --> FilteredWC: Pilih Work Center
    AllRows --> FilteredMRP: Pilih MRP
    AllRows --> FilteredBoth: Pilih WC + MRP
    FilteredWC --> AllRows: Reset / "All WC"
    FilteredMRP --> AllRows: Reset / "All MRP"
    FilteredBoth --> AllRows: Reset Filter
    FilteredWC --> FilteredBoth: Pilih MRP juga
    FilteredMRP --> FilteredBoth: Pilih WC juga
    FilteredBoth --> FilteredWC: Reset MRP ke "All MRP"
    FilteredBoth --> FilteredMRP: Reset WC ke "All WC"
  }

  Interactive --> NavigateAway: Klik New Search
  NavigateAway --> [*]: GET index.htm
```

---

## 12. Timeline — Request/Response Lifecycle

### BSP Path — Timing Diagram

```
index.htm                          main.htm
   │                                  │
   ├── [t=0] User request index.htm  │
   ├── [t=1] Server parse (no ABAP)  │
   ├── [t=2] Render HTML + CSS       │
   ├── [t=3] HTTP Response           │
   │◄─────────────────────────────────┤
   │                                  │
   ├── [t=4] Browser display form    │
   ├── [t=5] User input + submit     │
   │                                  │
   │   GET ?vbeln=&posnr=            │
   ├─────────────────────────────────►│
   │                                  ├── [t=6] BSP Runtime parsing
   │                                  ├── [t=7] request->get_form_field
   │                                  ├── [t=8] SELECT + 5 JOIN
   │                                  ├── [t=9] LOOP + progress calc
   │                                  ├── [t=10] Render HTML + table
   │                                  ├── [t=11] Embed JS
   │                                  ├── [t=12] HTTP Response
   │◄─────────────────────────────────┤
   │                                  │
   ├── [t=13] Browser render table   │
   ├── [t=14] onload → buildDropdowns│
   ├── [t=15] Interactive            │
```

### Report Path — Timing Diagram

```
ZMON_CNC_KMI2
   │
   ├── [t=0] SE38 → Execute
   ├── [t=1] LOAD-OF-PROGRAM
   ├── [t=2] INITIALIZATION
   ├── [t=3] Selection Screen PBO
   ├── [t=4] Display screen → User input
   ├── [t=5] F8 → PAI
   ├── [t=6] START-OF-SELECTION
   ├── [t=7] get_data() → SELECT
   ├── [t=8] calculate_progress() → LOOP
   ├── [t=9] display_alv() → SALV
   ├── [t=10] ALV Grid displayed
   ├── [t=11] User interacts (sort/filter)
   ├── [t=12] F3 → END-OF-SELECTION
   └── [t=13] Program end
```

---

## Index Flowchart

| Diagram | Halaman | Deskripsi |
|---------|---------|-----------|
| 1 | [Sistem Utama](#1-flowchart-sistem-utama) | Percabangan BSP vs Report dari awal hingga akhir |
| 2 | [index.htm](#2-flowchart-bsp--indexhtm) | Form pencarian dan submit flow |
| 3a | [main.htm ABAP](#3a-abap-processing-phase) | Server-side ABAP processing |
| 3b | [main.htm HTML+JS](#3b-html--css--js-rendering-phase) | Client-side rendering |
| 3c | [main.htm Interaksi](#3c-user-interaction-post-render) | User action setelah load |
| 4a | [Report Lifecycle](#4a-report-lifecycle-penuh) | Full ABAP report lifecycle |
| 4b | [get_data](#4b-form-get_data-detail) | Detail form get_data |
| 4c | [calculate_progress](#4c-form-calculate_progress-detail) | Detail form calculate_progress |
| 4d | [display_alv](#4d-form-display_alv-detail) | Detail form display_alv |
| 5a | [Query Plan](#5a-query-execution-plan) | Database query execution |
| 5b | [DFD Level 0](#5b-data-flow-diagram-dfd-level-0) | Data flow diagram |
| 5c | [DFD Level 1](#5c-data-flow-diagram-dfd-level-1--proses-query) | Data flow detail query |
| 6 | [Progress Bar](#6-flowchart-progress-bar-logic) | Progress bar classification |
| 7a | [buildDropdowns](#7a-builddropdowns--initialization) | JS init function |
| 7b | [applyFilters](#7b-applyfilters--execution) | JS filter function |
| 7c | [resetFilters](#7c-resetfilters--execution) | JS reset function |
| 8 | [Error Handling](#8-flowchart-error-handling) | Semua skenario error |
| 9 | [Activity BSP](#9-activity-diagram--bsp-path) | State machine BSP |
| 10 | [Activity Report](#10-activity-diagram--report-path) | State machine Report |
| 11 | [State main.htm](#11-state-diagram--halaman-mainhtm) | UI state diagram |
| 12 | [Timeline](#12-timeline--requestresponse-lifecycle) | Request/response timing |
