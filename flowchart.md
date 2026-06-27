# Flowchart Aplikasi Central Storage Production Dashboard

## 1. Flow Aplikasi Keseluruhan

```mermaid
flowchart TD
    Start(["User Akses BSP Aplikasi"]) --> main["main.htm: Initialization"]
    main --> auth{User SAP\nsy-uname terisi?}
    auth -- Tidak --> vhost[vhost_authentication]
    vhost --> Return([RETURN])
    auth -- Ya --> Dashboard["index.htm: Dashboard"] & Monitoring["monitoring.htm: Monitoring"]
    Dashboard -- Klik bar grafik --> Monitoring
    Monitoring -- Navigasi navbar --> Dashboard
```

---

## 2. Flow Dashboard — index.htm

```mermaid
flowchart TD
    StartIdx([Load index.htm]) --> A[Set sy-uname]
    A --> B[Request form field 'period']
    
    B --> C{period = ?}
    C -- "='7'" --> C7[7 Hari Terakhir]
    C -- "='90'" --> C90[90 Hari Terakhir]
    C -- else (default) --> C30[30 Hari Terakhir]
    
    C7 & C30 & C90 --> D[Hitung lv_dfrom = sy-datum - days,\nlv_dto = sy-datum]
    
    D --> E1["Query 1: SELECT 10 SO terbaru\nFROM vbak → lt_recent\nSORT DESC, DELETE from 11"]
    E1 --> E2["Query 2: SELECT vbeln, erdat,\nkunnr, auart FROM vbak → lt_vbak"]
    E2 --> F{lt_vbak IS NOT INITIAL?}
    
    F -- Tidak (data kosong) --> SkipQ[Lewati semua query item]
    F -- Ya --> G[SELECT vbeln, posnr\nFROM vbap WHERE werks='2000'\nFOR ALL ENTRIES → lt_vbap]
    
    G --> H["Prune lt_vbak:\nHapus SO tanpa item Plant 2000"]
    H --> I[Hitung lv_total_so, lv_total_item]
    I --> J{lt_vbap IS NOT INITIAL?}
    
    J -- Tidak --> SkipAFPO
    J -- Ya --> K[SELECT kdauf, kdpos, psmng, wemng\nFROM afpo FOR ALL ENTRIES → lt_afpo]
    
    K --> L[LOOP lt_vbap → klasifikasi item]
    SkipAFPO --> L
    
    L --> M{Klasifikasi Item:\nREAD afpo + sy-subrc=0\nAND psmng > 0?}
    
    M -- Tidak → ELSE --> N3[noprod += 1\nlv_is_done = 3]
    M -- Ya --> N{pct = wemng/psmng*100\npct >= 100?}
    N -- Ya --> N1[done += 1\nlv_is_done = 1]
    N -- Tidak --> N2[inprog += 1\nlv_is_done = 2]
    
    N1 & N2 & N3 --> O[READ/MODIFY/APPEND\nke lt_so_prog per SO]
    O --> P["Hitung per-SO rate:\nrate = done/total*100"]

    P --> Q["Hitung overall rate:\nlv_rate = lv_done/lv_total_item*100"]
    
    Q --> R["Agregasi Mingguan:\nLOOP lt_vbak → lt_mth"]
    R --> SkipQ
    
    SkipQ --> S[Penentuan KPI Threshold]
    
    S --> T{lv_total_item = 0?}
    T -- Ya --> TGray["warna: gray\ntidak ada alert"]

    T -- Tidak --> U{lv_rate >= 80?}
    U -- Ya --> TGreen["warna: hijau\ntidak ada alert"]

    U -- Tidak --> V{lv_rate >= 50?}
    V -- Ya --> TAmber["warna: amber\nalert: perhatian"]
    V -- Tidak --> TRed["warna: merah\nalert: KRITIS"]
    
    TGray & TGreen & TAmber & TRed --> W["Build JSON arrays:\nlv_jmonths, lv_jdone, dll."]
    
    W --> X[RENDER HTML + CHART JS]
    
    X --> Y{Ada bar chart data?}
    Y -- Ya --> Z[Draw bar chart + donut chart\nHapus skeleton loading]
    Y -- Tidak --> Z2[Draw empty state charts\nHapus skeleton loading]
    
    Z & Z2 --> Z3["Bar chart click -> drillDown()"]
    
    Z3 --> AA["Jika klik bar minggu ke-n:\nRedirect ke monitoring.htm\ndengan filter tanggal minggu tersebut"]
```

### Detail Sub-Flow: Klasifikasi Item

```mermaid
flowchart LR
    StartItem(["Per Item di lt_vbap"]) --> ReadAfpo["READ TABLE lt_afpo\nBINARY SEARCH\nBY kdauf = vbeln, kdpos = posnr"]
    ReadAfpo --> Found{Found AND\npsmng > 0?}
    Found -- Yes --> Calc["pct = wemng/psmng*100"]
    Calc --> Full{pct >= 100%?}
    Full -- Yes --> Done["Status: SELESAI\ndone++"]
    Full -- No --> InProg["Status: PROSES\ninprog++"]
    Found -- No --> NoProd["Status: NO PROD\nnoprod++"]
```

### Detail Sub-Flow: Agregasi Mingguan

```mermaid
flowchart TD
    StartWeek(["LOOP lt_vbak"]) --> Week["lv_weekday = erdat mod 7\nlv_week_mon = erdat - weekday"]
    Week --> Mth["Format month key: YYYYMMDD"]
    Mth --> ReadMth{READ lt_mth\nBY month = lv_mm?}
    ReadMth -- Found --> Update["Akumulasi done/inprog/noprod\nMODIFY lt_mth"]
    ReadMth -- Not Found --> Append["Buat entry baru\nAPPEND lt_mth"]
    Update & Append --> Next[Next iteration]
```

### Detail Sub-Flow: 5 SO Paling Lambat (Rendering)

```mermaid
flowchart TD
    StartRender(["Rendering tabel"]) --> Sort["SORT lt_so_prog\nBY rate ASCENDING"]
    Sort --> Loop["LOOP lt_so_prog\nlv_sp_cnt = 1 to 5"]
    Loop --> Class{rate >= 80?}
    Class -- Ya --> Green["warna: #10b981"]
    Class -- Tidak --> Amber{rate >= 50?}
    Amber -- Ya --> Oren["warna: #f59e0b"]
    Amber -- Tidak --> Merah["warna: #ef4444"]
    Green & Oren & Merah --> Render["Render baris tabel\n+ progress bar"]
    Render --> NextItem["Next item / EXIT"]
```

---

## 3. Flow Monitoring — monitoring.htm

```mermaid
flowchart TD
    StartMon(["Load monitoring.htm"]) --> Init["Set sy-uname\nGet form fields:\nso_num, cust_num,\ndate_from, date_to"]
    
    Init --> DFrom{date_from\nterisi & length=10?}
    DFrom -- Ya --> ParseFrom[Parse ke internal SAP\nYYYYMMDD]
    DFrom -- Tidak --> DefFrom[lv_erdat_from =\nsy-datum - 30]
    
    Init --> DTo{date_to\nterisi & length=10?}
    DTo -- Ya --> ParseTo[Parse ke internal SAP\nYYYYMMDD]
    DTo -- Tidak --> DefTo[lv_erdat_to = sy-datum]
    
    ParseFrom & DefFrom --> Search{search_btn terisi\nATAU so_num terisi\nATAU cust_num terisi?}
    ParseTo & DefTo --> Search
    
    Search -- Tidak --> SkipSearch[lv_is_srch = false\nLewati query DB]
    Search -- Ya --> DoSearch
    
    DoSearch --> FSo{so_num terisi?}
    FSo -- Ya --> AlphaSO["ALPHA_INPUT conversion\nls_vbeln-sign=I, option=EQ\nAPPEND TO lr_vbeln"]
    FSo -- Tidak --> SkipSO
    
    DoSearch --> FCust{cust_num terisi?}
    FCust -- Ya --> AlphaCust["ALPHA_INPUT conversion\nls_kunnr-sign=I, option=EQ\nAPPEND TO lr_kunnr"]
    FCust -- Tidak --> SkipCust
    
    AlphaSO & SkipSO --> SOQuery[SELECT * FROM vbak\nWHERE erdat BETWEEN\nAND vbeln IN lr_vbeln\nAND kunnr IN lr_kunnr\nAND subquery werks='2000'\n→ lt_local_hdr]
    AlphaCust & SkipCust --> SOQuery
    
    SOQuery --> H{lt_local_hdr\nIS NOT INITIAL?}
    
    H -- Tidak --> SkipItem[Lewati query item]
    H -- Ya --> ItemQ[SELECT * FROM vbap\nFOR ALL ENTRIES\nWHERE werks='2000'\n→ lt_temp_vbap]
    
    ItemQ --> I{lt_temp_vbap\nIS NOT INITIAL?}
    I -- Ya --> AfpoQ[SELECT * FROM afpo\nFOR ALL ENTRIES\n→ lt_afpo_pre\nSORT BY kdauf kdpos]
    I -- Tidak --> SkipAfpoQ
    
    AfpoQ & SkipAfpoQ --> LoopItem["LOOP lt_temp_vbap:\nTransform ke ty_local_item\nREAD afpo_pre BINARY SEARCH\n→ psmng, wemng\nAPPEND lt_local_item"]
    
    LoopItem --> J{lt_local_item\nIS NOT INITIAL?}
    
    J -- Ya --> MastQ[SELECT * FROM mast\nFOR ALL ENTRIES\nWHERE werks='2000'\n→ lt_mast_pre]
    MastQ --> K{lt_mast_pre\nIS NOT INITIAL?}
    K -- Ya --> StpoQ[SELECT * FROM stpo\nFOR ALL ENTRIES\n→ lt_stpo_pre]
    K -- Tidak --> SkipBOM
    StpoQ --> L{lt_stpo_pre\nIS NOT INITIAL?}
    L -- Ya --> MaktQ[SELECT * FROM makt\nFOR ALL ENTRIES\n→ lt_makt_pre\nSORT BY matnr]
    L -- Tidak --> SkipBOM
    MaktQ --> SkipBOM
    
    J -- Tidak --> SkipBOM
    
    SkipItem & SkipBOM --> RenderMon[RENDER HTML]
    SkipSearch --> RenderMon
```

### Detail Sub-Flow: Item Progress Bar

```mermaid
flowchart TD
    StartItemRow([LOOP lt_local_item\nWHERE vbeln = header]) --> HasItem{Ada item?}
    HasItem -- Ya --> Psmng{psmng > 0?}
    Psmng -- Ya --> CalcProg[lv_prog = wemng/psmng*100]
    CalcProg --> Cap{lv_prog > 100?}
    Cap -- Ya --> Cap100[Cap ke 100%]
    Cap -- Tidak --> Color{lv_prog = 100?}
    Color -- 100% --> Green[bg-green\ntxt-green]
    Color -- >= 50% --> Blue[bg-blue\ntxt-blue]
    Color -- < 50% --> Amber[bg-amber\ntxt-amber]
    Cap100 & Green & Blue & Amber --> RenderBar[Render progress bar]
    Psmng -- Tidak --> NoProd["Render: No Prod"]
    RenderBar & NoProd --> NextRow[Row click → BOM]
```

### Detail Sub-Flow: BOM Expandable

```mermaid
flowchart TD
    StartBOM(["Klik baris item"]) --> Toggle{Baris BOM\nsedang terbuka?}
    Toggle -- "Ya, sama" --> Close["Sembunyikan BOM"]
    Toggle -- "Ya, beda" --> CloseOther["Sembunyikan BOM lain\n+ Buka BOM baru"]
    Toggle -- Tidak --> Open["Buka BOM"]
    
    Open & CloseOther --> RenderBOM["Render konten BOM"]
    
    RenderBOM --> Mast{Ada lt_mast_pre\nWHERE matnr = matnr_item?}
    Mast -- Ya --> Stpo["LOOP mast_pre -> LOOP stpo_pre\nWHERE stlnr = mast_stlnr\n-> lt_local_bom"]
    Stpo --> Makt{Ada lt_makt_pre?}
    Makt -- Ya --> ReadMakt["READ makt_pre\nBINARY SEARCH\nBY matnr = idnrk"]
    ReadMakt --> RowBOM["Render baris BOM:\nidnrk, maktx, menge, meins"]
    Makt -- Tidak --> RowBOM
    Mast -- Tidak --> EmptyBOM["Tampilkan:\n\"BOM data kosong\""]
    RowBOM & EmptyBOM --> DoneBOM(["Selesai"])
```

### Detail Sub-Flow: Pagination (Frontend JS)

```mermaid
flowchart TD
    StartPage(["window.onload"]) --> Collect["Kumpulkan semua\nelement data-type=so-card"]
    Collect --> Render["Hitung totalPages =\nceil(cards.length/5)"]
    
    Render --> Show["Sembunyikan semua kartu\nTampilkan hanya index\n(startIndex..endIndex)"]
    Show --> Prev{currentPage = 1?}
    Prev -- Ya --> DisPrev[Disable Prev button]
    Prev -- Tidak --> EnaPrev[Enable Prev button]
    Show --> Next{currentPage =\ntotalPages?}
    Next -- Ya --> DisNext[Disable Next button]
    Next -- Tidak --> EnaNext[Enable Next button]
    DisPrev & EnaPrev & DisNext & EnaNext --> Done([Selesai])
```

---

## 4. Flow Navigasi Antar Halaman

```mermaid
flowchart LR
    subgraph Nav["Navigasi User"]
        DashNav["Klik Dashboard\ndi navbar"] --> idx[index.htm]
        MonNav["Klik Monitoring\ndi navbar"] --> mon[monitoring.htm]
    end
    
    subgraph Drill["Drill-down dari Grafik"]
        Bar["Klik bar di chart mingguan"] --> CalcDate["Hitung dari/tanggal\nuntuk minggu tersebut"]
        CalcDate --> Redir["Redirect ke\nmonitoring.htm\ndengan date_from & date_to"]
    end
    
    subgraph Search["Pencarian Monitoring"]
        SearchForm["Isi filter SO/Customer/Tanggal\n+ klik Cari"] --> Post["POST ke monitoring.htm\ndiri sendiri"]
        Post --> Process["Proses query DB\n+ render hasil"]
    end
```

---

## 5. Flow Data & Dependency Antar Tabel SAP

```mermaid
flowchart TD
    subgraph TabelSAP["Tabel SAP"]
        VBAK["VBAK\nSales Order Header"]
        VBAP["VBAP\nSales Order Item"]
        AFPO["AFPO\nOrder Produksi"]
        MAST["MAST\nBOM Link"]
        STPO["STPO\nBOM Item"]
        MAKT["MAKT\nMaterial Description"]
    end
    
    subgraph Index["index.htm"]
        Q1["Query 1:\n10 SO terbaru"] --> VBAK
        Q2["Query 2:\nVBAK by date range"] --> VBAK
        Q3["VBAP by VBAK\nwerks=2000"] --> VBAP
        Q4["AFPO by VBAP\nkdauf, kdpos"] --> AFPO
    end
    
    subgraph Monitoring["monitoring.htm"]
        QM1["VBAK by filter"] --> VBAK
        QM2["VBAP by VBAK\nwerks=2000"] --> VBAP
        QM3["AFPO by VBAP"] --> AFPO
        QM4["MAST by VBAP.matnr\nwerks=2000"] --> MAST
        QM5["STPO by MAST.stlnr"] --> STPO
        QM6["MAKT by STPO.idnrk"] --> MAKT
    end
    
    subgraph Output["Output"]
        idx["Dashboard:\nKPI + Grafik +\nTabel SO"]
        mon["Halaman Monitoring:\nFilter + Detail Item + BOM"]
    end
    
    Q1 & Q2 & Q3 & Q4 --> idx
    QM1 & QM2 & QM3 & QM4 & QM5 & QM6 --> mon
```

---

## 6. Flow Error / Edge Cases

```mermaid
flowchart TD
    subgraph DashEC["Dashboard Edge Cases"]
        EC1["Tidak ada SO dalam periode"] --> EC1a["KPI: gray\nrate = 0%\nTabel: Tidak ada data\nChart: empty state"]
        EC2["Tidak ada item Plant 2000"] --> EC2a["Setelah pruning\nlt_vbak kosong\nsama seperti EC1"]
        EC3["Semua item selesai 100%"] --> EC3a["cpl = hijau\nrate = 100%\ndonut: 100% hijau"]
        EC4["Tidak ada produksi sama sekali"] --> EC4a["cpl = merah\nrate = 0%\nalert KRITIS"]
    end
    
    subgraph MonEC["Monitoring Edge Cases"]
        EC5["Tidak ada hasil pencarian"] --> EC5a["Pesan: Tidak ada SO\ncocok + placeholder"]
        EC6["Item tanpa target produksi"] --> EC6a["psmng=0 / wemng=0\ntampil No Prod"]
        EC7["Item tanpa BOM"] --> EC7a["BOM expand:\nBOM data kosong"]
        EC8["Pencarian tanpa parameter"] --> EC8a["Query tidak dijalankan\nHalaman kosong\n+ placeholder"]
    end
```
