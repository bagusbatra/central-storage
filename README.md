# Central Storage Production Dashboard — KMI 2 (Plant 2000)

Aplikasi **SAP BSP (Business Server Pages)** berbasis ABAP untuk memonitor dan menganalisis progres produksi di **Central Storage KMI 2 — Plant 2000 Surabaya**.

## Tujuan

Memberikan visibilitas real-time terhadap status produksi dari data *Sales Order* (SO) yang terdaftar di Plant 2000. Aplikasi ini menggantikan proses manual dengan dashboard visual yang terintegrasi langsung ke tabel SAP (VBAK, VBAP, AFPO, MAST, STPO, MAKT).

## Fitur

### 1. Dashboard Statistik (`index.htm`)
- **Ringkasan KPI**: Total Sales Order, Total Item Produksi, Item Selesai (GR 100%), dan Tingkat Penyelesaian (*completion rate*).
- **Filter Periode**: Tombol cepat 7 Hari / 30 Hari / 90 Hari.
- **Grafik Batang Mingguan**: Distribusi item (Selesai / Dalam Proses / Belum Produksi) per minggu.
- **Donut Chart**: Proporsi status produksi keseluruhan dengan persentase penyelesaian.
- **5 SO Terlambat**: Tabel 5 Sales Order dengan progres paling lambat (*bottom 5*).
- **10 SO Terbaru**: Daftar 10 Sales Order terbaru dengan nilai net dan mata uang.
- **Skeleton Loading**: Animasi *skeleton* selama data dimuat dari server.

### 2. Monitoring Detail (`monitoring.htm`)
- **Pencarian Multi-Kriteria**: Filter berdasarkan Nomor SO, Kode Customer, dan Rentang Tanggal.
- **Sidebar Daftar SO**: Daftar Sales Order dengan paginasi (5 per halaman), bisa diklik untuk melihat detail.
- **Panel Detail Item**: Tabel item produksi per SO dengan kolom Material #, Deskripsi, Kuantitas, Target Produksi, Hasil GR, dan Progress Bar.
- **Bill of Materials (BOM)**: *Expandable row* untuk setiap item yang menampilkan komponen rakitan dari tabel MAST/STPO lengkap dengan deskripsi material (MAKT) dan kuantitas kebutuhan.

### 3. Arsitektur ABAP
- **Query Teroptimasi**: SELECT kolom spesifik (bukan `*`), pruning SO tanpa item Plant 2000, *pre-fetch* AFPO/MAST/STPO/MAKT dengan `FOR ALL ENTRIES`.
- **RANGES Filter**: Penggunaan RANGES untuk filtering aman tanpa SQL Injection.
- **Konversi Tanggal**: Parsing input HTML `date` ke format internal SAP.
- **Autentikasi**: Validasi session user SAP via `sy-uname`.

## Teknologi

- **Bahasa**: SAP ABAP (BSP Page with Flow Logic)
- **Frontend**: HTML5, CSS3, Canvas API (chart murni tanpa library eksternal)
- **Database SAP**: VBAK, VBAP, AFPO, MAST, STPO, MAKT
- **Plant**: 2000 (Surabaya)

## Struktur File

```
ZBSP_CS_APP/
├── Page with Flow Logic/
│   ├── index.htm         # Dashboard utama — KPI, grafik, tabel
│   ├── main.htm          # Flow Logic inisialisasi (autentikasi)
│   └── monitoring.htm    # Halaman monitoring detail & BOM
└── MIMEs/
    ├── background.png    # Gambar latar
    └── logo.png          # Logo aplikasi
```

## Penggunaan

1. Deploy BSP aplikasi `ZBSP_CS_APP` di sistem SAP.
2. Akses via URL: `http://<server>:<port>/sap/bc/bsp/sap/zbsp_cs_app/index.htm`
3. Gunakan tombol periode untuk mengatur rentang data.
4. Klik bar pada grafik mingguan untuk *drill-down* ke halaman Monitoring.
5. Pada halaman Monitoring, pilih SO di sidebar, klik item untuk melihat BOM.
