# Entity Relationship Diagram — Central Storage Production Dashboard

## 1. Diagram ERD — Tabel SAP dan Struktur ABAP

```mermaid
erDiagram
    VBAK ||--o{ VBAP : "vbeln"
    VBAP ||--o{ AFPO : "kdauf=vbeln, kdpos=posnr"
    VBAP ||--o{ MAST : "matnr, werks"
    MAST ||--o{ STPO : "stlnr"
    STPO }o--|| MAKT : "idnrk=matnr, spras=sy-langu"

    VBAK {
        vbeln CHAR(10) PK "Sales Document Number"
        erdat DATS "Creation Date"
        kunnr CHAR(10) "Customer Code"
        auart CHAR(4) "Sales Document Type"
        netwr CURR "Net Value"
        waerk CHAR(5) "Currency"
    }

    VBAP {
        vbeln CHAR(10) PK,FK "Sales Document Number"
        posnr NUMC(6) PK "Item Number"
        matnr CHAR(40) "Material Number"
        arktx CHAR(40) "Material Description (Item Text)"
        kwmeng QUAN "Order Quantity"
        vrkme CHAR(3) "Sales Unit"
        werks CHAR(4) "Plant (filter = 2000)"
    }

    AFPO {
        kdauf CHAR(10) PK,FK "Sales Order (vbeln)"
        kdpos NUMC(6) PK,FK "Item Number (posnr)"
        psmng QUAN "Total Planned Qty"
        wemng QUAN "Goods Receipt Qty"
    }

    MAST {
        matnr CHAR(40) PK,FK "Material"
        werks CHAR(4) PK "Plant"
        stlan CHAR(1) PK "BOM Usage"
        stlal CHAR(2) PK "Alternative BOM"
        stlnr CHAR(8) "BOM Internal Number"
    }

    STPO {
        stlnr CHAR(8) PK,FK "BOM Internal Number"
        stlkn NUMC(8) PK "BOM Item Node"
        idnrk CHAR(40) FK "Component Material"
        menge QUAN "Component Quantity"
        meins CHAR(3) "Component Unit of Measure"
    }

    MAKT {
        matnr CHAR(40) PK,FK "Material Number"
        spras CHAR(1) PK "Language Key"
        maktx CHAR(40) "Material Description"
    }
```

---

## 2. Struktur Internal ABAP (Logical View)

Struktur data *custom* yang didefinisikan dalam kode ABAP sebagai turunan/logical view dari tabel-tabel SAP.

### 2.1 `ty_so_prog` — Progress per Sales Order (index.htm:15-25)

```mermaid
classDiagram
    class ty_so_prog {
        +vbeln  [vbak-vbeln]   Sales Order Number
        +kunnr  [vbak-kunnr]   Customer Code
        +auart  [vbak-auart]   SO Type
        +erdat  [string]       Creation Date (DD/MM/YYYY)
        +total  [i]            Total Items
        +done   [i]            Completed Items (GR >= 100%)
        +inprog [i]            In-Progress Items
        +noprod [i]            Not Yet Produced Items
        +rate   [p L8 D1]      Completion Rate (%)
    }
```

**Sumber data**: `LOOP lt_vbap` + `READ lt_afpo BINARY SEARCH` + agregasi.

### 2.2 `ty_mth` — Agregasi Mingguan (index.htm:6-13)

```mermaid
classDiagram
    class ty_mth {
        +month  [string]   YYYYMMDD (Monday of week)
        +label  [string]   Display Label (DD/MM)
        +wdate  [string]   Week Date String
        +done   [i]        Completed Items
        +inprog [i]        In-Progress Items
        +noprod [i]        Not-Yet-Produced Items
    }
```

**Sumber data**: `LOOP lt_vbak` → hitung `lv_weekday`, `lv_week_mon` → akumulasi dari `ty_so_prog`.

### 2.3 `ty_local_item` — Detail Item Produksi (monitoring.htm:7-16)

```mermaid
classDiagram
    class ty_local_item {
        +vbeln  [vbap-vbeln]    Sales Order Number
        +posnr  [vbap-posnr]    Item Number
        +matnr  [vbap-matnr]    Material Number
        +arktx  [vbap-arktx]    Material Description
        +kwmeng [vbap-kwmeng]   Order Quantity
        +vrkme  [vbap-vrkme]    Sales Unit
        +psmng  [afpo-psmng]    Total Planned Qty (target)
        +wemng  [afpo-wemng]    Goods Receipt Qty (hasil)
    }
```

**Sumber data**: `VBAP` + `READ lt_afpo_pre BINARY SEARCH`.

---

## 3. Diagram Hubungan Lengkap

```mermaid
erDiagram
    VBAK ||--o{ VBAP : "1 SO memiliki N item"
    VBAP ||--o{ AFPO : "1 item SO bisa punya\n0..N production order"
    VBAP ||--o{ MAST : "1 material memiliki\n0..N BOM Link"
    MAST ||--o{ STPO : "1 BOM Header memiliki\nN komponen"
    STPO }o--|| MAKT : "N komponen material\nmemiliki 1 deskripsi"

    VBAK {
        string vbeln "[PK] Nomor SO"
        string erdat "Tanggal Buat"
        string kunnr "Customer"
        string auart "Tipe SO"
        string netwr "Nilai"
        string waerk "Mata Uang"
    }

    VBAP {
        string vbeln "[PK][FK] Nomor SO"
        string posnr "[PK] Item"
        string matnr "Material"
        string arktx "Deskripsi"
        string kwmeng "Qty Pesanan"
        string vrkme "Satuan"
        string werks "Plant=2000"
    }

    AFPO {
        string kdauf "[PK][FK] SO (vbeln)"
        string kdpos "[PK][FK] Item (posnr)"
        string psmng "Target Produksi"
        string wemng "Hasil GR"
    }

    MAST {
        string matnr "[PK][FK] Material"
        string werks "[PK] Plant=2000"
        string stlnr "[FK] No BOM"
    }

    STPO {
        string stlnr "[PK][FK] No BOM"
        string stlkn "[PK] Item BOM"
        string idnrk "[FK] Material Komponen"
        string menge "Qty Komponen"
        string meins "Satuan"
    }

    MAKT {
        string matnr "[PK][FK] Material Komponen"
        string spras "[PK] Bahasa"
        string maktx "Deskripsi Material"
    }
```

### 3.1 Kardinalitas Relasi

| Relasi | Dari | Ke | Kardinalitas | Penjelasan |
|--------|------|----|--------------|------------|
| R1 | VBAK | VBAP | **1:N** | Satu Sales Order memiliki banyak item |
| R2 | VBAP | AFPO | **1:0..N** | Satu item SO bisa memiliki 0, 1, atau lebih production order. Di kode, produksi diakumulasi dari `psmng`/`wemng` |
| R3 | VBAP | MAST | **1:0..1** | Satu material bisa memiliki 0 atau 1+ BOM (filter `werks='2000'`). Di kode diambil semua `lt_mast_pre` |
| R4 | MAST | STPO | **1:N** | Satu BOM header memiliki banyak komponen |
| R5 | STPO | MAKT | **N:1** | Banyak baris BOM mengacu ke material yang sama; deskripsi dibaca via `READ TABLE ... BINARY SEARCH BY matnr = idnrk` |

---

## 4. Alur Data dan Dependency Query

```mermaid
flowchart LR
    subgraph SAP_TABLES["Tabel SAP"]
        VBAK
        VBAP
        AFPO
        MAST
        STPO
        MAKT
    end

    subgraph INDEX["index.htm — Dashboard"]
        direction TB
        I1["SELECT vbeln, erdat, kunnr, auart, netwr, waerk<br/>FROM vbak<br/>WHERE erdat BETWEEN ...<br/>AND vbeln IN (SELECT vbeln FROM vbap WHERE werks='2000')<br/>→ lt_recent (10 SO terbaru)"]
        I2["SELECT vbeln, erdat, kunnr, auart<br/>FROM vbak<br/>WHERE erdat BETWEEN ...<br/>→ lt_vbak"]
        I3["SELECT vbeln, posnr<br/>FROM vbap<br/>FOR ALL ENTRIES IN lt_vbak<br/>WHERE werks='2000'<br/>→ lt_vbap"]
        I4["SELECT kdauf, kdpos, psmng, wemng<br/>FROM afpo<br/>FOR ALL ENTRIES IN lt_vbap<br/>WHERE kdauf = vbeln AND kdpos = posnr<br/>→ lt_afpo"]
    end

    subgraph MONITOR["monitoring.htm — Monitoring Detail"]
        direction TB
        M1["SELECT * FROM vbak<br/>WHERE erdat BETWEEN ...<br/>AND vbeln IN lr_vbeln<br/>AND kunnr IN lr_kunnr<br/>AND vbeln IN (SELECT vbeln FROM vbap WHERE werks='2000')<br/>→ lt_local_hdr"]
        M2["SELECT * FROM vbap<br/>FOR ALL ENTRIES IN lt_local_hdr<br/>WHERE werks='2000'<br/>→ lt_temp_vbap"]
        M3["SELECT * FROM afpo<br/>FOR ALL ENTRIES IN lt_temp_vbap<br/>WHERE kdauf = vbeln AND kdpos = posnr<br/>→ lt_afpo_pre"]
        M4["SELECT * FROM mast<br/>FOR ALL ENTRIES IN lt_local_item<br/>WHERE matnr = matnr AND werks='2000'<br/>→ lt_mast_pre"]
        M5["SELECT * FROM stpo<br/>FOR ALL ENTRIES IN lt_mast_pre<br/>WHERE stlnr = stlnr<br/>→ lt_stpo_pre"]
        M6["SELECT * FROM makt<br/>FOR ALL ENTRIES IN lt_stpo_pre<br/>WHERE matnr = idnrk AND spras = sy-langu<br/>→ lt_makt_pre"]
    end

    I1 --> VBAK
    I2 --> VBAK
    I3 --> VBAP
    I4 --> AFPO

    M1 --> VBAK
    M2 --> VBAP
    M3 --> AFPO
    M4 --> MAST
    M5 --> STPO
    M6 --> MAKT
```

---

## 5. Alur Klasifikasi Status Item (Business Logic)

Diagram ini menunjukkan bagaimana data dari **VBAK → VBAP → AFPO** diolah untuk menentukan status produksi setiap item.

```mermaid
flowchart TD
    START(["Loop lt_vbap (item)"]) --> READ_AFPO["READ TABLE lt_afpo<br/>BINARY SEARCH<br/>BY kdauf = vbeln<br/>   kdpos = posnr"]
    READ_AFPO --> FOUND{"sy-subrc = 0<br/>AND psmng > 0?"}
    FOUND -- Ya --> CALC["lv_pct = wemng / psmng * 100"]
    CALC --> PCT_CHECK{"lv_pct >= 100?"}
    PCT_CHECK -- Ya --> DONE["Status: SELESAI (GR 100%)<br/>done++, lv_is_done=1"]
    PCT_CHECK -- Tidak --> INPROG["Status: PROSES PRODUKSI<br/>inprog++, lv_is_done=2"]
    FOUND -- Tidak --> NOPROD["Status: BELUM PRODUKSI<br/>noprod++, lv_is_done=3"]
    
    DONE --> ACCUM["Akumulasi per SO<br/>READ/MODIFY lt_so_prog"]
    INPROG --> ACCUM
    NOPROD --> ACCUM
    
    ACCUM --> CALC_RATE["Hitung rate per SO<br/>rate = done/total*100"]
    CALC_RATE --> AGGR_WEEK["Agregasi mingguan<br/>→ lt_mth"]
```

---

## 6. Alur Relasi BOM (Bill of Materials)

Diagram navigasi dari item ke komponen BOM di halaman monitoring.

```mermaid
flowchart TD
    ITEM["Item Baris<br/>Material: ls_item_row-matnr"] --> FIND_MAST["LOOP lt_mast_pre<br/>WHERE matnr = ls_item_row-matnr"]
    FIND_MAST --> FOUND_MAST{"Ada MAST<br/>untuk material ini?"}
    FOUND_MAST -- Ya --> LOOP_STPO["LOOP lt_stpo_pre<br/>WHERE stlnr = ls_mast_pre-stlnr"]
    LOOP_STPO --> APPEND["APPEND ke lt_local_bom"]
    APPEND --> READ_MAKT["READ TABLE lt_makt_pre<br/>BINARY SEARCH<br/>BY matnr = ls_bom_row-idnrk"]
    READ_MAKT --> RENDER["Render BOM Table<br/>idnrk | maktx | menge/meins"]
    FOUND_MAST -- Tidak --> EMPTY["Tampilkan:<br/>'BOM data kosong'"]
```

---

## 7. Ringkasan Semua Entitas

### 7.1 Tabel SAP (Database)

| Tabel | PK | FK | Nama Lengkap | Peran dalam Aplikasi |
|-------|----|----|--------------|----------------------|
| VBAK | vbeln | — | Sales Document: Header Data | Header SO — data utama dashboard dan monitoring |
| VBAP | vbeln, posnr | VBAK.vbeln | Sales Document: Item Data | Item SO — filter Plant 2000, sumber material |
| AFPO | kdauf, kdpos | VBAP.vbeln/posnr | Production Order Item | Target/hasil produksi — penentu status progress |
| MAST | matnr, werks, stlan, stlal | VBAP.matnr | Material to BOM Link | Penghubung material ke BOM |
| STPO | stlnr, stlkn | MAST.stlnr | BOM Item | Daftar komponen rakitan |
| MAKT | matnr, spras | STPO.idnrk | Material Descriptions | Deskripsi material komponen BOM |

### 7.2 Struktur ABAP (In-Memory)

| Struktur | Didefinisikan di | Tujuan | Sumber Data |
|----------|------------------|--------|-------------|
| ty_mth | index.htm:6-13 | Agregasi mingguan untuk grafik bar | lt_vbak + lt_so_prog |
| ty_so_prog | index.htm:15-25 | Progress per SO untuk tabel 5 SO lambat | lt_vbap + lt_afpo |
| ty_local_item | monitoring.htm:7-16 | Detail item produksi untuk panel monitoring | VBAP + AFPO (pre-fetch) |
