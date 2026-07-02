# Central Storage Control Tower

## Hasil Brainstorming Proyek

> Versi: 1.0

# 1. Latar Belakang

Saat ini proses monitoring material masih mengandalkan beberapa T-Code
SAP seperti **COOIS**, **MB51**, dan laporan SAP lainnya.

Admin Central Storage harus membuka beberapa transaksi SAP untuk
mengetahui: - Material sudah datang atau belum. - Material sedang berada
di proses apa. - Material sudah sampai Ready Assy atau belum. - Sales
Order (SO) mana yang perlu di-follow up.

Oleh karena itu dibangun sistem berbasis **BSP SAP S/4HANA versi
1.8.0.9** yang berfungsi sebagai **Central Storage Control Tower**.

Sistem ini **bukan sistem transaksi**, melainkan **Decision Support
System** untuk Admin Central Storage.

# 2. Tujuan

-   Monitoring end-to-end perjalanan material.
-   Mempermudah monitoring Sales Order.
-   Mempermudah follow up.
-   Memberikan prioritas pekerjaan.
-   Menampilkan bottleneck.
-   Menjadi Control Tower Central Storage.

# 3. User

-   Admin Central Storage
-   Plant 2000

# 4. Scope

``` text
Plant 1000 / SLoc 1D00
        │
        ▼
Plant 2000 / SLoc 2KCS
        │
        ▼
Checkpoint Central Storage
        │
        ▼
SLoc 229K (Ready Assy)
        │
        ▼
History
```

Tahapan setelah **229K** berada di luar tanggung jawab Central Storage.

# 5. Filosofi

Dashboard tidak dibuat untuk menggantikan SAP.

Dashboard dibuat untuk menjawab:

> Apa yang harus dikerjakan Admin Central Storage saat ini?

Bukan hanya:

> Apa yang sedang terjadi di produksi?

# 6. Logic Sistem

## Logic 1 - Material Readiness

Tujuan: - Memastikan seluruh material untuk SO sudah tiba di **2KCS**. -
Jika belum lengkap maka Admin melakukan follow up ke Plant 1000 SLoc
1D00.

## Logic 2 - Production Checkpoint Monitoring

Dimulai ketika seluruh material sudah berada di **2KCS**.

Dashboard hanya memonitor checkpoint yang menjadi tanggung jawab Central
Storage.

### Routing

Setiap material dapat memiliki routing berbeda.

Contoh:

-   2KCS → Machining → Laminating → Ready Assy
-   2KCS → Laminating → Ready Assy
-   2KCS → Machining → Painting → Ready Assy

Dashboard tidak boleh mengasumsikan semua material melewati proses yang
sama.

## Checkpoint Central Storage

  Checkpoint        Storage Location
  ----------------- ------------------
  Central Storage   2KCS
  Machining IN      2261
  Machining OUT     2262
  Laminating IN     22F2
  Laminating OUT    22F3
  Ready Assy        229K

### Catatan

Material dapat melewati Storage Location lain di luar tanggung jawab
Central Storage.

Dashboard mengabaikan checkpoint tersebut.

Semua routing pada akhirnya wajib melewati **229K**.

## Logic 3 - History

SO dianggap selesai apabila seluruh material sudah mencapai **229K**.

# 7. Hierarki Data

``` text
Sales Order
└── SO Item
    └── BOM
        └── Checkpoint
            └── Movement History
```

# 8. Progress

## Bar Progress

-   Progress level tinggi.
-   Menunjukkan output proses.

## Dot Progress

-   Progress paling detail.
-   Menunjukkan posisi checkpoint setiap material.

# 9. Status

## Business Status

-   Inbound
-   Production
-   Completed

## Operational Status

-   Waiting Material
-   Ready to Start
-   In Process
-   Waiting Next Process
-   Hold
-   Completed

## Attention Flag

Memberikan warning terhadap SO yang membutuhkan perhatian.

# 10. Action Center

Dashboard harus mampu menunjukkan:

-   SO yang perlu follow up.
-   SO yang tertahan.
-   SO Ready Assy.
-   SO Completed.

# 11. KPI

-   SO Aktif
-   Waiting Material
-   Production
-   Completed Today
-   Material Delay
-   Bottleneck
-   Lead Time

# 12. Business Rules

1.  Dashboard hanya memonitor checkpoint Central Storage.
2.  Storage Location di luar scope diabaikan.
3.  Semua routing harus berakhir di 229K.
4.  Dashboard hanya membaca data SAP.
5.  Dashboard merupakan Decision Support System.

# 13. Pengembangan Selanjutnya

-   Master Checkpoint
-   Progress Engine
-   Routing Engine
-   Attention Engine
-   KPI Dashboard
-   UI/UX
-   Drill Down hingga Movement History

# Kesimpulan

Central Storage Control Tower merupakan Decision Support System yang
memberikan visibilitas end-to-end terhadap perjalanan material dalam
lingkup Central Storage, mulai dari Plant 1000 SLoc 1D00 hingga material
mencapai SLoc 229K (Ready Assy), sekaligus membantu Admin menentukan
prioritas pekerjaan, melakukan follow up, memonitor checkpoint, dan
mengevaluasi performa operasional.
