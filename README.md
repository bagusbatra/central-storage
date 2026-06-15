# Central Storage — Monitoring Production

> **Sistem Monitoring Produksi berbasis Sales Order**  
> Platform: SAP S/4HANA 1.8.0.9  
> Komponen: BSP Application (SE80) + ABAP Report (SE38)  
> BSP App: `ZCNC_MONITOR_BS`

---

## Daftar Isi

1. [Struktur Proyek](#struktur-proyek)
2. [Arsitektur Sistem](#arsitektur-sistem)
3. [BSP Application — index.htm](#bsp-application--indexhtm)
4. [BSP Application — main.htm](#bsp-application--mainhtm)
5. [ABAP Report — ZMON_CNC_KMI2](#abap-report--zmon_cnc_kmi2)
6. [Database Query & Tabel SAP](#database-query--tabel-sap)
7. [Alur Data Lengkap](#alur-data-lengkap)
8. [Perhitungan Progress](#perhitungan-progress)
9. [User Interface & CSS Architecture](#user-interface--css-architecture)
10. [Client-side JavaScript (main.htm)](#client-side-javascript-mainhtm)
11. [Perbandingan BSP vs Report](#perbandingan-bsp-vs-report)
12. [Panduan Deployment](#panduan-deployment)
13. [Customization Guide](#customization-guide)
14. [Performa & Optimasi](#performa--optimasi)
15. [Keamanan](#keamanan)
16. [Troubleshooting](#troubleshooting)
17. [Catatan Implementasi](#catatan-implementasi)

---

## Struktur Proyek

```
D:\DEV\Central Storage\
├── index.htm              # BSP Page — Halaman pencarian utama
├── main.htm               # BSP Page — Halaman hasil + tabel + filter
├── ZMON_CNC_KMI2.htm      # ABAP Report — ALV Grid (program final)
├── copy.htm               # ABAP Report — Duplikat ZMON_CNC_KMI2 (draft/backup)
├── README.md              # Dokumentasi ini
├── flowchart.md           # Diagram alur sistem
└── erd.md                 # Entity Relationship Diagram
```

### Status File

| File | Ukuran (baris) | Status | Keterangan |
|------|---------------|--------|------------|
| `index.htm` | 161 | **Produksi** | Halaman landing, form pencarian |
| `main.htm` | 682 | **Produksi** | Halaman hasil, query + render + JS filter |
| `ZMON_CNC_KMI2.htm` | 145 | **Produksi** | Report ALV standalone |
| `copy.htm` | 145 | **Draft/Backup** | Identik dengan ZMON_CNC_KMI2 |

---

## Arsitektur Sistem

### Diagram Arsitektur

```
┌──────────────────────────────────────────────────────────┐
│                   SAP S/4HANA 1.8.0.9                    │
│                                                          │
│  ┌──────────────────────────┐  ┌──────────────────────┐  │
│  │   BSP Application        │  │  ABAP Report          │  │
│  │   ZCNC_MONITOR_BS        │  │  ZMON_CNC_KMI2        │  │
│  │                          │  │                       │  │
│  │  ┌────────┐ ┌────────┐  │  │  SE38 / SA38          │  │
│  │  │index   │ │main    │  │  │  Execution             │  │
│  │  │ .htm   │ │ .htm   │  │  │                       │  │
│  │  └───┬────┘ └───┬────┘  │  │  ┌───────────────┐   │  │
│  │      │  GET ?   │       │  │  │ Selection      │   │  │
│  │      └──────────┘       │  │  │ Screen         │   │  │
│  │                         │  │  │ vbeln, posnr,  │   │  │
│  │  Akses via:             │  │  │ werks, arbpl   │   │  │
│  │  /sap/bc/bsp/sap/       │  │  └───────┬───────┘   │  │
│  │  ZCNC_MONITOR_BS/       │  │          │           │  │
│  │  index.htm              │  │          ▼           │  │
│  └──────────────────────────┘  │  ┌───────────────┐   │  │
│                                │  │ get_data()    │   │  │
│                                │  │ calculate_    │   │  │
│                                │  │ progress()    │   │  │
│                                │  │ display_alv() │   │  │
│                                │  └───────────────┘   │  │
│                                └──────────────────────┘  │
│                                       │                  │
│                                       ▼                  │
│  ┌─────────────────────────────────────────────────────┐  │
│  │              Database Layer (SAP HANA)               │  │
│  │                                                      │  │
│  │  AFPO ⬄ AFKO ⬄ AFVC ⬄ CRHD ⬄ MARC ⬄ MAKT          │  │
│  └──────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

### Komponen Utama

1. **BSP Application ZCNC_MONITOR_BS** — 2 halaman (index.htm + main.htm)
2. **ABAP Report ZMON_CNC_KMI2** — Program mandiri dengan selection screen + ALV
3. **SAP HANA Database** — 6 tabel SAP di-join untuk mengambil data produksi

---

## BSP Application — index.htm

### Informasi File

| Atribut | Nilai |
|---------|-------|
| **File** | `index.htm` |
| **Page Directive** | `<%@ page language="abap" %>` |
| **Layout** | Single card centered (max-width 560px) |
| **Fungsi** | Halaman landing untuk input Sales Order & Item |
| **Request Method** | GET ke `main.htm` |
| **Parameter Dikirim** | `vbeln`, `posnr` |

### ABAP Code (index.htm)

File `index.htm` menggunakan BSP directive `<%@ page language="abap" %>` yang menandakan bahwa halaman ini diproses oleh BSP runtime ABAP. Namun pada file ini **tidak ada kode ABAP eksekusi** — hanya berisi HTML/CSS murni. Semua pemrosesan terjadi di sisi klien (form submission).

### Form Fields

| Field Name | Label | Tipe Input | Placeholder | ABAP Data Type |
|-----------|-------|------------|-------------|----------------|
| `vbeln` | Sales Order | `text` | `4500001234` | `vbeln_va` |
| `posnr` | Item | `text` | `000010` | `posnr_va` |

### CSS Breakdown (index.htm)

| CSS Class | Fungsi |
|-----------|--------|
| `.header` | Container logo + judul, flexbox, max-width 560px |
| `.card` | Kartu putih dengan border-radius 16px, shadow |
| `.form-group` | Wrapper per field, margin-bottom 18px |
| `.form-group label` | Label uppercase, tracking 0.05em, warna teal |
| `.form-group input[type="text"]` | Input dengan border teal, background hijau sangat muda |
| `.btn-search` | Tombol gradient teal-to-green, full-width |
| `.footer` | Footer tipis di bawah |

### Akses URL

```
http://<server>:<port>/sap/bc/bsp/sap/ZCNC_MONITOR_BS/index.htm
```

---

## BSP Application — main.htm

### Informasi File

| Atribut | Nilai |
|---------|-------|
| **File** | `main.htm` |
| **Page Directive** | `<%@ page language="abap" %>` |
| **Layout** | Full-page dengan header + tabel scrollable |
| **Fungsi** | Eksekusi query, render tabel produksi, progress bar, filter |
| **Parameter Diterima** | `vbeln`, `posnr` via GET |
| **Total Baris** | 682 baris (ABAP + HTML + CSS + JS) |

### ABAP Code Analysis (main.htm, baris 1–56)

#### Bagian 1: Deklarasi Tipe & Data (baris 3–20)

```abap
TYPES: BEGIN OF ty_data,
         vbeln    TYPE afpo-kdauf,      " Sales Order Document
         posnr    TYPE afpo-kdpos,      " Sales Order Item
         aufnr    TYPE afpo-aufnr,      " Production Order
         matnr    TYPE afpo-matnr,      " Material Number
         maktx    TYPE makt-maktx,      " Material Description
         arbpl    TYPE crhd-arbpl,      " Work Center
         dispo    TYPE marc-dispo,      " MRP Controller
         qty_total TYPE afpo-psmng,     " Total Order Qty
         qty_gr    TYPE afpo-wemng,     " Goods Receipt Qty
       END OF ty_data.
DATA: lt_data TYPE STANDARD TABLE OF ty_data,
      ls_data TYPE ty_data.
DATA: lv_vbeln TYPE afpo-kdauf,
      lv_posnr TYPE afpo-kdpos.
```

**Detail tipe data SAP:**

| Field ABAP | Tipe SAP | Domain | Panjang | Deskripsi |
|-----------|----------|--------|---------|-----------|
| `vbeln` | `afpo-kdauf` | `VBELN` | CHAR 10 | Sales and Distribution Document Number |
| `posnr` | `afpo-kdpos` | `POSNR` | NUMC 6 | Item Number of Sales Document |
| `aufnr` | `afpo-aufnr` | `AUFNR` | CHAR 12 | Order Number |
| `matnr` | `afpo-matnr` | `MATNR` | CHAR 40 | Material Number |
| `maktx` | `makt-maktx` | `MAKTX` | CHAR 40 | Material Description |
| `arbpl` | `crhd-arbpl` | `ARBPL` | CHAR 8 | Work Center |
| `dispo` | `marc-dispo` | `DISPO` | CHAR 3 | MRP Controller |
| `qty_total` | `afpo-psmng` | `MENG13` | QUAN 13 | Total quantity in sales units |
| `qty_gr` | `afpo-wemng` | `MENG13` | QUAN 13 | Quantity of goods received |

#### Bagian 2: Tangkap Parameter (baris 22–25)

```abap
lv_vbeln = request->get_form_field( 'vbeln' ).
lv_posnr = request->get_form_field( 'posnr' ).
```

Menggunakan object **`request`** bawaan BSP yang menyediakan method `get_form_field( name )` untuk membaca parameter HTTP GET/POST.

#### Bagian 3: SELECT Statement (baris 27–55)

```abap
SELECT
    a~kdauf  AS vbeln,
    a~kdpos  AS posnr,
    a~aufnr,
    a~matnr,
    e~maktx,
    d~arbpl,
    f~dispo,
    a~psmng  AS qty_total,
    a~wemng  AS qty_gr
FROM afpo AS a
INNER JOIN afko AS b   ON a~aufnr = b~aufnr
INNER JOIN afvc AS c   ON b~aufpl = c~aufpl
INNER JOIN crhd AS d   ON c~arbid = d~objid   AND d~werks = '2000'
INNER JOIN marc AS f   ON a~matnr = f~matnr    AND f~werks = '2000'
LEFT  JOIN makt AS e   ON a~matnr = e~matnr    AND e~spras = @sy-langu
WHERE  a~kdauf = @lv_vbeln
  AND  a~kdpos = @lv_posnr
  AND  d~werks = '2000'.
```

**Penjelasan Join:**

| Join | Tabel | Alias | Key | Tujuan |
|------|-------|-------|-----|--------|
| INNER JOIN | AFKO → AFVC | b → c | `b~aufpl = c~aufpl` | Hubungkan production order ke operation routing |
| INNER JOIN | AFVC → CRHD | c → d | `c~arbid = d~objid` | Dapatkan work center dari operation |
| INNER JOIN | AFPO → MARC | a → f | `a~matnr = f~matnr` | Dapatkan MRP controller per plant |
| LEFT JOIN | AFPO → MAKT | a → e | `a~matnr = e~matnr` | Dapatkan deskripsi material (opsional) |

**Filter:**

| Filter | Kondisi | Keterangan |
|--------|---------|------------|
| Plant | `f~werks = '2000'` | Hardcoded di main.htm |
| Plant | `d~werks = '2000'` | Work Center harus di plant yang sama |
| Bahasa | `e~spras = @sy-langu` | Deskripsi material sesuai bahasa login user |
| Sales Order | `a~kdauf = @lv_vbeln` | Dari input user |
| Item | `a~kdpos = @lv_posnr` | Dari input user |

### HTML Rendering (baris 57–598)

#### Table Columns (10 kolom)

| # | Header | CSS Class | Data Source | Tipe Data |
|---|--------|-----------|-------------|-----------|
| 1 | Sales Doc | `col-vbeln` | `ls_data-vbeln` | CHAR 10 |
| 2 | Item | `center` | `ls_data-posnr` | NUMC 6 |
| 3 | Production Order | `col-aufnr` | `ls_data-aufnr` | CHAR 12 |
| 4 | Material | `col-matnr` | `ls_data-matnr` | CHAR 40 |
| 5 | Description | `col-desc` | `ls_data-maktx` | CHAR 40 |
| 6 | Work Center | `col-wc` | `ls_data-arbpl` | CHAR 8 |
| 7 | MRP | `col-mrp` | `ls_data-dispo` | CHAR 3 |
| 8 | Total Qty | `col-qty` | `ls_data-qty_total` | QUAN 13 |
| 9 | GR Qty | `col-qty` | `ls_data-qty_gr` | QUAN 13 |
| 10 | Progress | `col-progress` | Progress bar + % | Desimal |

#### ABAP Loop Rendering (baris 526–576)

```abap
LOOP AT lt_data INTO ls_data.
  DATA(lv_progress) = 0.
  IF ls_data-qty_total > 0.
    lv_progress = ( ls_data-qty_gr / ls_data-qty_total ) * 100.
  ENDIF.

  " CSS class untuk progress bar + text
  DATA(lv_bar_class) = 'pct-zero'.
  DATA(lv_pct_class) = 'pct-zero'.
  IF lv_progress >= 100.
    lv_bar_class = 'pct-full'.    " Hijau tua + glow
    lv_pct_class = 'pct-full'.
  ELSEIF lv_progress >= 70.
    lv_bar_class = 'pct-high'.    " Hijau tua
    lv_pct_class = 'pct-high'.
  ELSEIF lv_progress >= 40.
    lv_bar_class = 'pct-mid'.     " Hijau sedang
    lv_pct_class = 'pct-mid'.
  ELSEIF lv_progress > 0.
    lv_bar_class = 'pct-low'.     " Hijau muda
    lv_pct_class = 'pct-low'.
  ENDIF.

  " Clamp width ke 100%
  DATA(lv_bar_width) = lv_progress.
  IF lv_bar_width > 100.
    lv_bar_width = 100.
  ENDIF.
```

Setiap baris `<tr>` diberi **data attributes** untuk client-side filtering:
```html
<tr data-wc="<%= ls_data-arbpl %>" data-mrp="<%= ls_data-dispo %>">
```

#### Empty State (baris 578–587)

Jika `lt_data` kosong, tampilkan baris dengan pesan "No production data found for the given Sales Order and Item" (colspan=10).

---

## ABAP Report — ZMON_CNC_KMI2

### Informasi Program

| Atribut | Nilai |
|---------|-------|
| **Nama Program** | `ZMON_CNC_KMI2` |
| **Jenis** | Executable Program (REPORT) |
| **Fungsi** | Monitoring produksi via ALV Grid |
| **Author (dari nama)** | CNC/KMI — kemungkinan inisial developer |

### Selection Screen

```abap
PARAMETERS: p_vbeln TYPE vbeln_va OBLIGATORY.   " Wajib diisi
PARAMETERS: p_posnr TYPE posnr_va.                " Opsional
PARAMETERS: p_werks TYPE werks_d DEFAULT '2000'.  " Default plant

SELECT-OPTIONS: s_arbpl FOR crhd-arbpl.           " Multi-select work center
```

| Parameter | Tipe | Wajib | Default | Deskripsi |
|-----------|------|-------|---------|-----------|
| `p_vbeln` | `vbeln_va` (CHAR 10) | **Ya** | - | Sales Document |
| `p_posnr` | `posnr_va` (NUMC 6) | Tidak | - | Item Number (jika kosong, semua item) |
| `p_werks` | `werks_d` (CHAR 4) | Tidak | `2000` | Plant |
| `s_arbpl` | SELECT-OPTIONS | Tidak | - | Work Center (range/values) |

### Struktur Program (3 Form)

```
START-OF-SELECTION
    ├── PERFORM get_data
    │       └── SELECT 6 tabel JOIN → INTO gt_data
    ├── PERFORM calculate_progress
    │       └── LOOP gt_data → progress = done / target × 100
    └── PERFORM display_alv
            └── CL_SALV_TABLE=>FACTORY → DISPLAY
```

### Form: get_data

Perbedaan query dengan BSP (`main.htm`):

| Aspek | main.htm | ZMON_CNC_KMI2 |
|-------|----------|---------------|
| Plant filter | Hardcoded `'2000'` | Parameter `@p_werks` |
| Item filter | Exact match `a~kdpos = @lv_posnr` | Opsional dengan `IS INITIAL` check |
| Work Center filter | Tidak ada (semua WC) | SELECT-OPTIONS `s_arbpl` |

### Form: calculate_progress

```abap
LOOP AT gt_data ASSIGNING <fs>.
  IF <fs>-target > 0.
    <fs>-progress = ( <fs>-done / <fs>-target ) * 100.
  ELSE.
    <fs>-progress = 0.
  ENDIF.
ENDLOOP.
```

Menggunakan **FIELD-SYMBOLS** untuk modifikasi data langsung di internal table.

### Form: display_alv

Menggunakan **SALV** (`CL_SALV_TABLE`) — pendekatan ALV modern, lebih ringan dari ALV Grid (REUSE_ALV_GRID_DISPLAY).

```abap
cl_salv_table=>factory(
  IMPORTING r_salv_table = lo_alv
  CHANGING  t_table      = gt_data ).

lo_columns = lo_alv->get_columns( ).

" Costumize kolom PROGRESS
lo_column ?= lo_columns->get_column( 'PROGRESS' ).
lo_column->set_short_text( 'Prog%' ).
lo_column->set_medium_text( 'Progress %' ).
lo_column->set_long_text( 'Production Progress %' ).

lo_alv->display( ).
```

**Error handling:** CATCH `cx_salv_msg` — mengabaikan error jika SALV gagal.

---

## Database Query & Tabel SAP

### Diagram Join

```
                    ┌──────────────┐
                    │    AFPO      │ (a) — Production Order Item
                    │              │
                    │  kdauf  ─────┼── Sales Order
                    │  kdpos  ─────┼── Item
                    │  aufnr  ─────┼── Order Number (PK)
                    │  matnr  ─────┼── Material
                    │  psmng  ─────┼── Total Qty
                    │  wemng  ─────┼── GR Qty
                    └──────┬───────┘
                           │
              ┌────────────┼──────────────────┐
              │ aufnr      │ matnr             │ matnr
              ▼            ▼                   ▼
        ┌──────────┐ ┌──────────┐       ┌──────────┐
        │  AFKO    │ │  MARC    │       │  MAKT    │
        │  (b)     │ │  (f)     │       │  (e)     │
        │          │ │          │       │          │
        │ aufnr PK │ │ matnr PK │       │ matnr PK │
        │ aufpl    │ │ werks PK │       │ spras PK │
        └────┬─────┘ │ dispo    │       │ maktx    │
             │       └──────────┘       └──────────┘
             │ aufpl
             ▼
        ┌──────────┐
        │  AFVC    │
        │  (c)     │
        │          │
        │ aufpl PK │
        │ arbid    │
        └────┬─────┘
             │ arbid = objid
             ▼
        ┌──────────┐
        │  CRHD    │
        │  (d)     │
        │          │
        │ objid PK │
        │ arbpl    │
        │ werks    │
        └──────────┘
```

### Detail Tabel

#### AFPO — Production Order Item

| Field | Key | Domain | Length | Data Element | Deskripsi |
|-------|-----|--------|--------|-------------|-----------|
| `aufnr` | **PK** | AUFNR | CHAR 12 | AUFNR | Production Order |
| `kdauf` | | VBELN | CHAR 10 | VBELN_VA | Sales Order |
| `kdpos` | | POSNR | NUMC 6 | POSNR_VA | Sales Order Item |
| `matnr` | | MATNR | CHAR 40 | MATNR | Material Number |
| `psmng` | | MENG13 | QUAN 13 | PSMNG | Total qty in sales unit |
| `wemng` | | MENG13 | QUAN 13 | WEMNG | GR qty in sales unit |

#### AFKO — Production Order Header

| Field | Key | Domain | Length | Data Element | Deskripsi |
|-------|-----|--------|--------|-------------|-----------|
| `aufnr` | **PK** | AUFNR | CHAR 12 | AUFNR | Production Order |
| `aufpl` | | AUFPL | NUMC 12 | CO_AUFPL | Routing plan key |

#### AFVC — Operation within Order

| Field | Key | Domain | Length | Data Element | Deskripsi |
|-------|-----|--------|--------|-------------|-----------|
| `aufpl` | **PK** | AUFPL | NUMC 12 | CO_AUFPL | Routing plan key |
| `vornr` | **PK** | VORNR | CHAR 4 | VORNR | Operation number |
| `arbid` | | CR_OBJID | NUMC 8 | CR_OBJID | Work center object ID |

#### CRHD — Work Center

| Field | Key | Domain | Length | Data Element | Deskripsi |
|-------|-----|--------|--------|-------------|-----------|
| `objid` | **PK** | CR_OBJID | NUMC 8 | CR_OBJID | Object ID |
| `arbpl` | | ARBPL | CHAR 8 | ARBPL | Work Center |
| `werks` | | WERKS | CHAR 4 | WERKS_D | Plant |

#### MARC — Material Plant Data

| Field | Key | Domain | Length | Data Element | Deskripsi |
|-------|-----|--------|--------|-------------|-----------|
| `matnr` | **PK** | MATNR | CHAR 40 | MATNR | Material |
| `werks` | **PK** | WERKS | CHAR 4 | WERKS_D | Plant |
| `dispo` | | DISPO | CHAR 3 | DISPO | MRP Controller |

#### MAKT — Material Descriptions

| Field | Key | Domain | Length | Data Element | Deskripsi |
|-------|-----|--------|--------|-------------|-----------|
| `matnr` | **PK** | MATNR | CHAR 40 | MATNR | Material |
| `spras` | **PK** | SPRAS | LANG 1 | SPRAS | Language Key |
| `maktx` | | MAKTX | CHAR 40 | MAKTX | Material Description |

---

## Alur Data Lengkap

### Flow BSP (index.htm → main.htm)

```
[User]                             [SAP Server]
   │                                    │
   ├─ Buka http://.../index.htm ───────►│
   │◄─── Halaman form ──────────────────┤
   │                                    │
   ├─ Isi vbeln = "4500001234"          │
   ├─ Isi posnr = "000010"              │
   ├─ Klik "Search Production Data"     │
   │                                    │
   ├─ GET /main.htm?vbeln=4500001234&   │
   │        posnr=000010 ──────────────►│
   │                                    │
   │                     ┌──────────────┤
   │                     │ BSP Runtime  │
   │                     │ Parse ABAP   │
   │                     │ code         │
   │                     ├──────────────┤
   │                     │ request->    │
   │                     │ get_form_    │
   │                     │ field() × 2  │
   │                     ├──────────────┤
   │                     │ SELECT:      │
   │                     │ AFPO + 5     │
   │                     │ JOIN tables  │
   │                     ├──────────────┤
   │                     │ LOOP data:   │
   │                     │ hitung       │
   │                     │ progress %   │
   │                     │ tentukan CSS │
   │                     │ render HTML   │
   │                     └──────────────┤
   │                                    │
   │◄─── Halaman hasil ─────────────────┤
   │     - 10 kolom tabel               │
   │     - progress bar hijau           │
   │     - badge "X Record(s) Found"    │
   │     - dropdown filter WC & MRP     │
   │     - script buildDropdowns()      │
   │                                    │
   ├─ Pilih Work Center di dropdown ───►│
   │     (client-side, no request)      │
   │◄─── Tabel terfilter ───────────────┤
   │                                    │
   ├─ Klik "New Search" ───────────────►│
   │     (GET /index.htm)               │
```

### Flow Report ABAP (ZMON_CNC_KMI2)

```
[User]                             [SAP Server]
   │                                    │
   ├─ SE38 → ZMON_CNC_KMI2             │
   ├─ F8 (Execute) ───────────────────►│
   │                                    │
   │◄─── Selection Screen ─────────────┤
   │                                    │
   ├─ Isi p_vbeln = "4500001234"        │
   ├─ Isi p_posnr = "000010"            │
   ├─ Isi p_werks = "2000"              │
   ├─ Isi s_arbpl = option              │
   ├─ F8 ──────────────────────────────►│
   │                                    │
   │                     ┌──────────────┤
   │                     │ get_data()   │
   │                     │ SELECT...    │
   │                     │ INTO gt_data │
   │                     ├──────────────┤
   │                     │ calculate_   │
   │                     │ progress()   │
   │                     │ LOOP...      │
   │                     │ progress =   │
   │                     │ done/target  │
   │                     ├──────────────┤
   │                     │ display_alv()│
   │                     │ SALV TABLE   │
   │                     └──────────────┤
   │                                    │
   │◄─── ALV Grid ──────────────────────┤
   │     - Sorting by kolom             │
   │     - Filter by value              │
   │     - Export to Excel/CSV          │
   │     - Layout save                  │
```

---

## Perhitungan Progress

### Formula

```
Progress (%) = (Goods Receipt Quantity ÷ Total Order Quantity) × 100
```

### ABAP Implementation

```abap
DATA(lv_progress) = 0.
IF ls_data-qty_total > 0.
  lv_progress = ( ls_data-qty_gr / ls_data-qty_total ) * 100.
ENDIF.
```

### Classification & Visualization

| Progress Range | Kategori | CSS Class (bar) | CSS Class (text) | Warna Bar | Warna Text |
|--------------|----------|-----------------|-------------------|-----------|------------|
| **0%** | Belum mulai | `pct-zero` | `pct-zero` | Abu-abu `#d1d5db` | Abu-abu `#9ca3af` |
| **1% – 39%** | Early stage | `pct-low` | `pct-low` | Hijau muda gradient | Hijau `#16a34a` |
| **40% – 69%** | Progressing | `pct-mid` | `pct-mid` | Hijau sedang gradient | Hijau tua `#15803d` |
| **70% – 99%** | Hampir selesai | `pct-high` | `pct-high` | Hijau tua gradient | Hijau tua `#15803d` |
| **100%** | Selesai | `pct-full` | `pct-full` | Hijau tua + glow shadow | Hijau gelap `#14532d` + badge bg |

### Edge Cases

| Skenario | Perilaku |
|----------|----------|
| `qty_total = 0` | Progress = 0% (zero division protection) |
| `qty_total < qty_gr` | Bar width = 100% (clamped), progress > 100% tetap ditampilkan |
| Tidak ada data | Empty state dengan ikon 📊 |

---

## User Interface & CSS Architecture

### Color Palette

| Color | Hex | CSS Variable Equivalent | Penggunaan |
|-------|-----|------------------------|------------|
| Teal 700 | `#0f766e` | `--primary` | Header bg, label, link, border focus |
| Teal 800 | `#134e4a` | `--primary-dark` | Card title, input text |
| Teal 200 | `#99f6e4` | `--primary-light` | Border input, border badge |
| Teal 100 | `#ccfbf1` | `--primary-bg` | Badge bg, row hover, filter bg |
| Teal 50 | `#f0fdfa` | `--primary-surface` | Body bg, input bg |
| Green 600 | `#16a34a` | `--accent` | Gradient accent, MRP badge text |
| Green 700 | `#15803d` | `--accent-dark` | MRP badge border, progress high |
| Green 100 | `#dcfce7` | `--accent-bg` | MRP badge bg, progress full bg |
| White | `#ffffff` | `--white` | Card bg, table row odd |
| Gray 50 | `#f9fffe` | `--gray-even` | Table row even |
| Gray 900 | `#111827` | `--text-primary` | Cell text |

### Responsive Design

- Viewport meta: `width=device-width, initial-scale=1.0`
- Tabel: `min-width: 960px` dengan overflow-x auto
- Filter panel: flex-wrap untuk layar kecil
- Max-width 560px untuk halaman index (centered)
- Max-height 65vh untuk tabel (scrollable body)
- Font dalam rem/em units

### CSS Components Detail

| Component | CSS Properties Kunci |
|-----------|---------------------|
| Top Header | `linear-gradient(135deg, #0f766e, #16a34a)`, padding 18px 32px, box-shadow |
| Filter Tag | `border-radius: 20px`, bg teal-100, border teal-200, font-weight 600 |
| Badge Total | `margin-left: auto`, bg teal-700, text white, border-radius 20px |
| Filter Panel | Card putih dengan shadow, padding 14px 20px, flexbox |
| Select Dropdown | Custom arrow via SVG background-image, `appearance: none` |
| MRP Badge | `display: inline-block`, bg green-100, border green-400, border-radius 6px |
| Progress Bar | `height: 11px`, `border-radius: 99px`, overflow hidden |
| Empty State | `padding: 48px 24px`, text center, color gray-500, icon 2.4rem |
| Sticky Header | `position: sticky; top: 0; z-index: 10` |

### Data Attributes untuk Filter

```html
<tr data-wc="WC001" data-mrp="MRP1">
```

Digunakan oleh JavaScript untuk:
1. `buildDropdowns()` — mengumpulkan nilai unik
2. `applyFilters()` — mencocokkan nilai dengan selector

---

## Client-side JavaScript (main.htm)

### Fungsi #1: buildDropdowns()

**Dipanggil:** `onload` (baris 678)  
**Tujuan:** Membangun `<option>` dinamis untuk dropdown Work Center dan MRP

**Algoritma:**
1. Query semua `<tr>` dengan attribute `data-wc` dan `data-mrp`
2. Kumpulkan nilai unik ke dalam object Set (`wcSet`, `mrpSet`)
3. Sort alphabetically
4. Buat `<option>` element → append ke `<select>`

### Fungsi #2: applyFilters()

**Dipanggil:** `onchange` event pada kedua `<select>`  
**Tujuan:** Menyembunyikan/menampilkan baris tabel berdasarkan filter

**Algoritma:**
1. Baca nilai selected dari dropdown WC dan MRP
2. Iterasi semua `<tr>` dengan attribute `data-wc`
3. Jika `data-wc` cocok (atau filter kosong) DAN `data-mrp` cocok (atau filter kosong):
   - Hilangkan class `hidden-row`
   - Increment counter `visible`
4. Jika tidak cocok: tambahkan class `hidden-row`
5. Update badge count: `visible + ' Record(s) Found'`
6. Tampilkan/sembunyikan `#no-filter-msg`

### Fungsi #3: resetFilters()

**Dipanggil:** `onclick` pada tombol Reset  
**Tujuan:** Reset semua filter ke nilai default

**Algoritma:**
1. Set value kedua `<select>` ke `''` (All)
2. Panggil `applyFilters()`

### CSS untuk Filter

```css
tbody tr.hidden-row { display: none; }
```

---

## Perbandingan BSP vs Report

### Tabel Perbandingan Detail

| Aspek | BSP (`main.htm`) | Report (`ZMON_CNC_KMI2`) |
|-------|------------------|---------------------------|
| **Transaction Code** | `/sap/bc/bsp/sap/ZCNC_MONITOR_BS/main.htm` | SE38 → ZMON_CNC_KMI2 |
| **Akses** | Web Browser (HTTP/HTTPS) | SAP GUI |
| **Input Method** | Form HTML → GET parameter | Selection Screen (PARAMETERS + SELECT-OPTIONS) |
| **Plant** | Hardcoded `'2000'` | Parameter `p_werks` (default `2000`) |
| **Work Center Filter** | Client-side JS dropdown (semua WC) | Selection Screen `s_arbpl` (range/values) |
| **Item Filter** | Exact match | Optional (`IS INITIAL` → semua item) |
| **Output** | HTML Table + CSS + JS | ALV Grid (SALV) |
| **Progress Bar** | Custom CSS gradient + glow | Tidak ada (hanya angka di kolom) |
| **Filter (data)** | Client-side JavaScript | ALV built-in filter |
| **Sort** | Tidak ada (urut sesuai query) | ALV interactive sort (click header) |
| **Export** | Tidak ada (print via browser) | ALV export to Excel, CSV, HTML |
| **Layout Save** | Tidak ada | ALV layout bisa disave per user |
| **Error Handling** | Empty state row (colspan=10) | CATCH `cx_salv_msg` |
| **Logging** | Tidak ada | Tidak ada |
| **Performance** | Server-side render + client-side filter | Server-side processing + ALV di SAP GUI |
| **Mobile** | Responsive (viewport + flex) | Tidak (SAP GUI desktop) |
| **User Experience** | Modern UI, gradient, animasi | SAP standard ALV interface |

### Kelebihan Masing-masing

**BSP:**
- Akses via browser, tanpa SAP GUI
- UI modern dan user-friendly
- Responsive untuk mobile
- Filter cepat (client-side, no roundtrip)
- Progress bar visual

**ABAP Report:**
- Sorting, filter, find di ALV (built-in)
- Export ke Excel/Native format
- Layout bisa disimpan per user
- Tidak perlu web server mapping
- Lebih cepat untuk data besar (no HTTP rendering)

---

## Panduan Deployment

### Langkah 1: Buat BSP Application di SE80

1. Buka transaksi **SE80**
2. Pilih object type **BSP Application**
3. Klik kanan → **Create** → BSP Application
4. Nama: `ZCNC_MONITOR_BS`
5. Deskripsi: `Monitoring Production`
6. Package: `$TMP` (atau package development sesuai project)

### Langkah 2: Upload BSP Pages

1. Di SE80, buka BSP Application `ZCNC_MONITOR_BS`
2. Klik kanan → **Create** → **BSP Page**
3. Nama: `index.htm`
4. Copy paste konten dari `index.htm`
5. Ulangi untuk `main.htm`

### Langkah 3: Aktivasi BSP Application

1. Klik kanan BSP Application → **Activate**
2. Atau via **SICF**:
   - Buka SICF
   - Path: `default_host/sap/bc/bsp/sap`
   - Pilih `ZCNC_MONITOR_BS`
   - Klik **Activate Service**

### Langkah 4: Upload Logo

Upload logo perusahaan ke MIME Repository:
1. SE80 → MIME Repository
2. Path: `/sap/bc/bsp/sap/ZCNC_MONITOR_BS/`
3. Upload file `logo.png`

### Langkah 5: Deploy ABAP Report

1. Buka **SE38**
2. Nama program: `ZMON_CNC_KMI2`
3. Pilih **Source Code**
4. Copy paste konten dari `ZMON_CNC_KMI2.htm`
5. Klik **Activate** (Ctrl+F3)

### Langkah 6: Grant Akses

- Otorisasi: `S_TCODE` untuk SE38 + program
- BSP: `S_SERVICE` untuk service SICF
- Atau beri akses via Portal/PFCG role

### Konfigurasi IIS/Web Dispatcher (jika perlu)

Untuk akses BSP dari luar, pastikan:
1. SAP Web Dispatcher atau reverse proxy diarahkan ke application server
2. Path `/sap/bc/bsp/sap/ZCNC_MONITOR_BS/` diizinkan
3. SSL diaktifkan untuk koneksi HTTPS

---

## Customization Guide

### Mengganti Plant

**Di BSP (main.htm):**
Cari dan ubah di baris 48 dan 55:
```abap
AND f~werks = '2001'
AND d~werks = '2001'
```

**Di Report (ZMON_CNC_KMI2):**
User tinggal mengisi parameter `p_werks` saat eksekusi.

### Menambah Filter Baru

Contoh: filter Material Group (`MATKL` dari tabel MAKT/MARA)

1. Tambahkan field di `ty_data`:
   ```abap
   matkl TYPE mara-matkl,
   ```
2. JOIN table `MARA`:
   ```abap
   INNER JOIN mara AS g ON a~matnr = g~matnr
   ```
3. Tambahkan data attribute di `<tr>`:
   ```html
   data-matkl="<%= ls_data-matkl %>"
   ```
4. Tambahkan dropdown di filter panel HTML
5. Tambahkan logic di `buildDropdowns()` dan `applyFilters()`

### Menambah Kolom

1. Tambahkan field di `ty_data`
2. SELECT statement
3. Tambahkan `<th>` di tabel
4. Tambahkan `<td>` dengan output
5. Update colspan di empty state (baris 581: `colspan="11"`)

### Multiple Language Support

MAKT sudah menggunakan `sy-langu` (system language). Untuk judul/header BSP:
- Gunakan text pool
- Atau gunakan bahasa Inggris (seperti saat ini)

---

## Performa & Optimasi

### Potensi Bottleneck

| Issue | Risiko | Solusi |
|-------|--------|--------|
| **Full table scan AFPO** | Tinggi jika banyak data | Pastikan index `AFPO~KDDUA` (kdauf + kdpos) ada |
| **5 JOIN operations** | Sedang | Query hanya untuk 1 Sales Order + Item → terbatas |
| **CRHD join tanpa index** | Rendah | `arbid` adalah PK, join optimal |
| **MARC join per material** | Rendah | `matnr` + `werks` adalah PK |
| **Client-side filter** | Tidak ada (data sudah di-load) | Filter hanya menyembunyikan baris via CSS |

### Index yang Digunakan

| Tabel | Index | Fields | Exploitation |
|-------|-------|--------|-------------|
| AFPO | **AFPO~KDDUA** (jika ada) | `kdauf`, `kdpos` | **WHERE clause** |
| AFKO | **Primary** | `aufnr` | **INNER JOIN** |
| AFVC | **Primary** | `aufpl` | **INNER JOIN** |
| CRHD | **Primary** | `objid` | **INNER JOIN** |
| MARC | **Primary** | `matnr`, `werks` | **INNER JOIN** |
| MAKT | **Primary** | `matnr`, `spras` | **LEFT JOIN** |

### Rekomendasi

1. Tambahkan **secondary index** `AFPO~KDDUA` pada `kdauf` dan `kdpos` jika belum ada
2. Untuk data besar (>1000 record), pertimbangkan **pagination** di BSP
3. Gunakan **database hint** jika perlu
4. Untuk BSP, gunakan **buffering** jika data tidak berubah sering

### Query Execution Plan (estimated)

```
TABLE ACCESS (FULL) AFPO
  └─ FILTER (kdauf = X AND kdpos = Y)
     └─ NESTED LOOPS
        ├─ INDEX UNIQUE SCAN AFKO (aufnr = X)
        └─ NESTED LOOPS
           ├─ INDEX UNIQUE SCAN AFVC (aufpl = X)
           └─ INDEX UNIQUE SCAN CRHD (objid = X)
        ├─ INDEX UNIQUE SCAN MARC (matnr + werks = X)
        └─ INDEX UNIQUE SCAN MAKT (matnr + spras = X)
```

---

## Keamanan

### Identifikasi Risiko

| Risiko | Level | Penjelasan | Mitigasi |
|--------|-------|------------|----------|
| **No Input Validation** | **High** | Tidak ada validasi input di BSP | Tambahkan validasi ABAP (pattern check, alphanumeric) |
| **No Authorization Check** | **High** | Tidak ada AUTHORITY-CHECK | Tambahkan otorisasi di kedua program |
| **Hardcoded Credentials** | N/A | Tidak ada | - |
| **SQL Injection** | Low | ABAP Open SQL aman terhadap SQLi | Pastikan parameter tidak di-concatenate |
| **XSS (Cross-Site Scripting)** | **Medium** | Output data langsung di HTML | Gunakan `CL_HTTP_UTILITY=>ESCAPE_HTML` di BSP |
| **SAP GUI Access** | Medium | Report bisa diakses via SA38 | Batasi via otorisasi program |
| **BSP Access** | Medium | Siapa pun bisa akses URL | Proteksi via SICF service + autentikasi |

### Rekomendasi Keamanan

1. **AUTHORITY-CHECK** di main.htm (setelah parameter diambil):
   ```abap
   AUTHORITY-CHECK OBJECT 'S_BTCH_JOB' ID 'JOBNAME' FIELD 'ZMON_CNC_KMI2'.
   ```
2. **HTML Escape** output user-facing data:
   ```abap
   CALL METHOD cl_http_utility=>escape_html
     EXPORTING
       html = ls_data-maktx
     RECEIVING
       escaped = lv_maktx_escaped.
   ```
3. **Batasi via SICF** — hanya izinkan user tertentu

---

## Troubleshooting

### Error Umum

| Error | Cause | Solution |
|-------|-------|----------|
| `CX_SY_OPEN_SQL_DB` | Tabel SAP tidak ada/rusak | Cek via SE11 apakah tabel exist |
| **BSP tidak dapat diakses** | SICF service tidak aktif | Buka SICF → aktivasi `ZCNC_MONITOR_BS` |
| **No data found** | Sales Order tidak memiliki production order | Cek di tabel AFPO dengan SE16N |
| **ALV error `CX_SALV_MSG`** | Masalah dengan SALV framework | Cek versi SAP, minimal SAP_BASIS 7.00 |
| **Logo tidak muncul** | File tidak ada di MIME Repository | Upload logo ke MIME path yang benar |
| **`request->get_form_field` error** | BSP runtime error | Pastikan BSP page adalah `language="abap"` |
| **Angka progress >100%** | GR qty > order qty | Validasi data (GR over-delivery) |

### Debugging

**Untuk BSP:**
1. Aktifkan **BSP Debugging** di SE80
2. Atau tambahkan `BREAK-POINT` di kode ABAP
3. Gunakan `/h` di browser untuk HTTP debugging (SAP)

**Untuk Report:**
1. `/h` di command field SAP GUI
2. Tambahkan `BREAK username` di program
3. Gunakan SE38 → Display → Debugging

### Logging SAP

Cek di:
- **SM21** — System Log
- **ST22** — ABAP Runtime Errors
- **SLG1** — Application Log (jika diimplementasikan)
- **SICF Log** — trace HTTP request

---

## Catatan Implementasi

### Hardcode yang Perlu Disesuaikan

| Lokasi | Hardcode | Baris | Saran |
|--------|----------|-------|-------|
| `main.htm` | Plant `'2000'` | 48, 55 | Ubah jadi parameter atau konfigurasi |
| `main.htm` | Path logo | 136, 464 | Sesuaikan dengan BSP app name jika berbeda |
| `ZMON_CNC_KMI2` | Default plant `'2000'` | 16 | Sesuai kebutuhan |

### File Duplikat

`copy.htm` adalah duplikat identik `ZMON_CNC_KMI2.htm`.  
Kemungkinan digunakan sebagai draft atau backup. **Tidak perlu di-deploy.**

### Naming Convention

| Object | Nama | Catatan |
|--------|------|---------|
| BSP Application | `ZCNC_MONITOR_BS` | BS = BSP |
| ABAP Report | `ZMON_CNC_KMI2` | CNC/KMI = inisial developer |
| BSP Pages | `index.htm`, `main.htm` | Standar naming |

### Dikembangkan Untuk

- **SAP S/4HANA 1.8.0.9**
- Plant: **2000** (hardcoded di BSP)
- Bahasa: **Inggris** (UI) dengan multi-language support untuk data material
- Role: **Production Supervisor** (Dashboard)
