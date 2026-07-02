# Hasil Review Sistem vs Tujuan (ide.md)

> Central Storage **Dashboard** — Decision Support System, Plant 2000 (KMI 2 Surabaya)
> Ditinjau: `classes/ZCL_CS_UTIL.abap`, `MIMEs/*` (js.js, style.css), `Page with Flow Logic/*.htm`
> Acuan garis merah: `ide.md` (v1.0) • Tanggal review: 2026-07-02

---

## 1. Ringkasan Eksekutif

Sistem saat ini adalah **dashboard monitoring produksi berbasis AFPO (target vs Goods Receipt)** yang matang secara teknis: arsitektur AJAX + lazy-load + prefetch, util terpusat (`ZCL_CS_UTIL`), filter GET idempotent, format angka lokal, aksesibilitas keyboard, empty-state, skeleton loading. Ini fondasi yang **kuat**.

Namun terhadap garis merah `ide.md`, ada **1 kesenjangan besar**: visi inti **"Dashboard perjalanan material lewat checkpoint 2KCS → 229K"** (Logic 2) **belum muncul di UI**. Engine-nya (`dot_stages`, `pipeline_slocs`) **sudah ditulis tapi jadi dead code** — halaman monitoring hanya menampilkan "Sloc Terkini" (snapshot lokasi stok), bukan progres bertahap antar-checkpoint. Akibatnya turunan visi (Bottleneck, Waiting Material, Attention Flag, definisi "Completed = sampai 229K") juga belum ada.

**Skor keselarasan garis besar: ~55%.** Fondasi & Logic 1 (Material Readiness) baik; Logic 2 (Checkpoint) & Logic 3 (History by 229K) + Action Center/KPI sesuai visi belum tercapai.

---

## 2. Peta Keselarasan terhadap ide.md

Legenda: 🟢 Sudah sejalan · 🟡 Perlu penyesuaian · 🔴 Berbeda / belum ada

| # | Elemen ide.md | Status | Kondisi saat ini |
|---|---------------|:---:|------------------|
| 1 | **DSS read-only** (bukan sistem transaksi) | 🟢 | Semua halaman hanya `SELECT`, tidak ada posting. Tepat. |
| 2 | **Scope Plant 2000** | 🟢 | `lc_plant = '2000'` konsisten di semua halaman + subquery VBAP. |
| 3 | **Logic 1 — Material Readiness (1D00 → 2KCS)** | 🟡 | `transfer.htm` mengimplementasikan ini (butuh vs stok 2KCS vs stok 1D00). Bagus, tapi berbasis **stok MARD 1D00**, bukan status checkpoint; dan sedang ada isu data (stok 1D00 = 0 → kosong). |
| 4 | **Logic 2 — Checkpoint Monitoring (2KCS→2261→2262→22F2→22F3→229K)** | 🔴 | **Kesenjangan utama.** Engine `dot_stages`/`pipeline_slocs` ada di util **tapi tidak dipanggil di halaman manapun**. `monitoring_bom.htm` menampilkan **"Sloc Terkini"** (lokasi stok kini), bukan progres tahap checkpoint. Bottleneck per checkpoint mustahil tanpa ini. |
| 5 | **Logic 3 — History (SO selesai bila semua material sampai 229K)** | 🔴 | `riwayat.htm` mendefinisikan "selesai" = **item GR 100% (AFPO)**, bukan "sampai 229K". `index_oldcard` pakai definisi lain lagi (VBAK `LFSTK/GBSTK='C'`). Tiga definisi "selesai" berbeda antar-halaman. |
| 6 | **Hierarki SO → Item → BOM → Checkpoint → Movement History** | 🟡 | SO→Item→BOM lengkap. **Checkpoint** & **Movement History** (timeline MSEG/MKPF) belum jadi lapisan; hanya snapshot sloc. |
| 7 | **Bar Progress (level tinggi)** | 🟢 | Progress bar per SO/item ada (rata-rata pct item), warna terpusat via `ZCL_CS_UTIL`. |
| 8 | **Dot Progress (posisi checkpoint per material)** | 🔴 | Konsep persis ada di `dot_stages` (4 titik, hijau/kuning/abu/merah) namun **tidak dirender**. |
| 9 | **Business Status** (Inbound/Production/Completed) | 🔴 | Tidak ada. Status kini: Selesai/Proses/Belum Produksi (produksi-sentris). |
| 10 | **Operational Status** (Waiting Material, Ready to Start, In Process, Waiting Next Process, Hold, Completed) | 🔴 | Tidak ada. Hanya status sistem order dari JEST (Dibuat/Diproses/Dikonfirmasi/Selesai Teknis). |
| 11 | **Attention Flag** | 🔴 | Belum ada engine peringatan SO butuh perhatian. |
| 12 | **Action Center** (follow-up / tertahan / Ready Assy / Completed) | 🟡 | Sebagian: dashboard punya "SO Tertua Belum Selesai" + "SO Terbaru" + customer box; `transfer.htm` = follow-up ke 1D00. Belum ada panel Action Center terpadu "apa yang harus dikerjakan sekarang". |
| 13 | **KPI ide.md** (SO Aktif, Waiting Material, Production, Completed Today, Material Delay, Bottleneck, Lead Time) | 🟡 | Ada: ~SO Aktif (Total SO), Production (parsial), **Lead Time** 🟢, + ekstra bagus (OTD, Backlog). **Belum**: Waiting Material, Completed Today, Material Delay, **Bottleneck**. |
| 14 | **Drill-down hingga Movement History** | 🟡 | Drill-down ke BOM/komponen + tanggal order ada; timeline gerakan mentah (MSEG/MKPF) belum. |
| 15 | **Filosofi "apa yang harus dikerjakan admin?"** | 🟡 | Sebagian terjawab (backlog, transfer). Belum menjadi orientasi utama UI (masih "apa yang terjadi di produksi"). |

---

## 3. Yang Sudah Baik (pertahankan)

- **Arsitektur performa front-end**: detail via AJAX (`monitoring_detail.htm`), tab berat Item&BOM lazy-load + **prefetch idle** + cache per-SO (`monitoring_bom.htm`), kartu backlog berat di-load asinkron (`index_oldcard.htm`). Pola ini tepat sasaran.
- **`ZCL_CL_UTIL` sebagai satu sumber kebenaran** untuk warna progres, format tanggal, konstanta plant/sloc/checkpoint. Sangat baik untuk konsistensi.
- **Agregasi AFPO per item (COLLECT)** — 1 item bisa >1 order produksi; sudah ditangani konsisten di semua halaman.
- **Kolom eksplisit** di sebagian besar SELECT (bukan `SELECT *`), guard `IS NOT INITIAL` sebelum `FOR ALL ENTRIES`.
- **UX detail**: filter GET (bookmarkable), empty-state informatif, skeleton, format angka id-ID, a11y keyboard, cegah double-submit.
- **`transfer.htm`** kini teroptimasi: JOIN MSEG⨝MKPF berfilter tanggal di DB, cache snapshot INDX, pagination server-side.

---

## 4. Rekomendasi — 4 Pilar

### 4.1 🚀 Load Cepat (Performance)

1. **Progress/Checkpoint Engine sebagai Z-table (precompute)** — rekomendasi terpenting, sekaligus menutup gap Logic 2.
   Buat job background (mis. tiap 10–15 mnt) yang menghitung posisi checkpoint tiap material/SO dari MSEG satu kali, simpan ke **Z-table** ber-indeks. Semua halaman lalu **membaca ringan** dari Z-table (bukan scan MSEG saat request). Ini memangkas query terberat **dan** menghidupkan dot-progress + bottleneck.
2. **Perluas pola cache snapshot** (yang sudah dipakai `transfer.htm`) ke **KPI dashboard `index.htm`** (query OTD/Lead Time berbasis MSEG/MKPF per AUFNR paling mahal). TTL 5–10 mnt via cluster INDX atau Z-table.
3. **Indeks sekunder DB** (koordinasi Basis): `MSEG` pada `AUFNR` dan `(MATNR,BWART,WERKS,LGORT)`; `RESB` pada `(WERKS,XLOEK,KZEAR)`. Kode sudah mengandalkan ini (lihat komentar di `index.htm`).
4. **Kurangi payload HTML**: banyak *inline style* berulang (index/oldcard/transfer) memperbesar halaman. Pindahkan ke kelas CSS (style.css baru 664 baris, masih sehat) → transfer byte lebih kecil + render lebih cepat.
5. **Pagination server-side** untuk daftar SO panjang di `monitoring.htm`/`riwayat.htm` (kini semua baris dirender lalu disembunyikan via JS) — samakan dengan pola `transfer.htm`.

### 4.2 🎯 UI Efektif

1. **Wujudkan Dot Progress checkpoint** (pakai `dot_stages` yang sudah ada) di sidebar SO & baris item — visualisasi "di mana material saya" (2KCS→229K) langsung terbaca. Ini pembeda Dashboard vs dashboard biasa.
2. **Papan Bottleneck**: satu kartu/heatmap "berapa material menumpuk di tiap checkpoint" (2261/2262/22F2/22F3) — turunan langsung dari engine checkpoint.
3. **Konsistenkan definisi "Selesai"** secara visual & warna lintas halaman (lihat 4.4).
4. Untuk chart, jika ada penambahan/perubahan, ikuti panduan design-system agar konsisten light/dark & aksesibel.

### 4.3 🤝 UX Memudahkan User

1. **Action Center terpadu** (menjawab filosofi ide.md "apa yang harus dikerjakan admin sekarang"): satu halaman/panel mengelompokkan **Waiting Material** (perlu transfer 1D00→2KCS), **Hold/Tertahan**, **Ready Assy (229K) hari ini**, **Completed hari ini**. Menyatukan yang kini tersebar di dashboard + transfer.
2. **Attention Flag**: tandai SO berisiko (mis. lead time > target, macet di satu checkpoint > N hari, material delay) dengan lencana menonjol + alasan.
3. **Status operasional** ide.md (Waiting Material, In Process, Waiting Next Process, Hold, Completed) sebagai chip, diturunkan dari posisi checkpoint + ketersediaan material — lebih "actionable" daripada Selesai/Proses/Belum.
4. **Completed Today / Material Delay** sebagai KPI harian di dashboard.

### 4.4 ✅ Data Akurat

1. **Satukan definisi "SO Selesai"** — saat ini **tiga definisi berbeda**:
   - `riwayat.htm`: semua item GR 100% (AFPO wemng≥psmng)
   - `index_oldcard.htm`: VBAK `LFSTK/GBSTK = 'C'`
   - `ide.md`: **semua material mencapai 229K (Ready Assy)**
   Akibatnya satu SO bisa "selesai" di satu layar, "belum" di layar lain. Tetapkan **satu sumber kebenaran** (idealnya "sampai 229K" begitu checkpoint engine ada), lalu pakai konsisten.
2. **Verifikasi asumsi movement type (Fase 0)** yang masih ditandai "VERIFIKASI" di kode:
   - `transfer.htm`: transfer 1D00→2KCS = mvt **301** (cek MB51).
   - `dot_stages`/checkpoint: arah gerakan antar-sloc & netting `SHKZG` (mvt 311/261/101).
   Salah asumsi mvt → angka "sudah dikirim"/progres checkpoint keliru.
3. **Isu aktif `transfer.htm`** (sedang didiagnosa): filter "stok 1D00 = 0" menyembunyikan semua baris → indikasi stok sumber bernilai 0 / sloc `1D00` bukan lokasi stok sebenarnya. Perlu konfirmasi lokasi stok sumber sebelum poin filter diaktifkan lagi. (Lihat juga [known-issues] proyek.)
4. **KPI menyesuaikan periode**: pastikan semua KPI (OTD, Lead Time, Backlog) transparan basis periodenya agar tidak menyesatkan (isu KPI pernah tercatat di known-issues).

---

## 5. Prioritas (Roadmap Saran)

| Prio | Aksi | Menutup gap | Dampak |
|:---:|------|-------------|--------|
| **P0** | Verifikasi asumsi mvt & lokasi stok 1D00; selesaikan isu `transfer.htm` kosong | Data akurat #2,#3 | Kepercayaan data |
| **P0** | Satukan definisi "SO Selesai" (1 sumber kebenaran) | Logic 3, Data #1 | Konsistensi |
| **P1** | **Checkpoint/Progress Engine → Z-table + job**; render **Dot Progress** | Logic 2, Dot, Perf | Inti visi + performa |
| **P1** | Cache snapshot KPI dashboard (pola INDX transfer) | Perf | Load cepat |
| **P2** | **Action Center** + Attention Flag + status operasional | Action Center, Status | UX / filosofi DSS |
| **P2** | KPI baru: Bottleneck, Waiting Material, Completed Today, Material Delay | KPI ide.md | Kelengkapan visi |
| **P3** | Pagination server-side monitoring/riwayat; inline-style → CSS | Perf/UI | Perapian |
| **P3** | Drill-down Movement History (timeline MSEG/MKPF) | Hierarki #6 | Pengembangan lanjut |

---

## 6. Kesimpulan

Fondasi teknis sistem **solid** dan Logic 1 (Material Readiness) sudah berjalan. Untuk benar-benar menjadi **Dashboard** seperti `ide.md`, langkah paling strategis adalah **menghidupkan lapisan checkpoint (Logic 2)** — kebetulan engine-nya sudah ditulis di `ZCL_CS_UTIL` tinggal dirender, dan bila diwujudkan sebagai **Z-table precompute** akan sekaligus **mempercepat load** dan membuka **Bottleneck, Dot Progress, status operasional, dan Action Center**. Bersamaan itu, **menyatukan definisi "selesai"** dan **memverifikasi asumsi movement type** akan mengunci akurasi data.
