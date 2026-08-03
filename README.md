# Central Storage Production Dashboard — KMI 2 (Plant 2000)

Aplikasi **SAP BSP (Business Server Pages)** berbasis ABAP untuk memonitor
progres produksi di **Central Storage KMI 2 — Plant 2000 Surabaya**.

Repo ini menyimpan **sumber**-nya, bukan aplikasi yang berjalan. Berkasnya
disalin ke SE80/SE24 lalu diaktifkan di sana.

Akses aplikasi: `http://<server>:<port>/sap/bc/bsp/sap/zbsp_cs_app/index.htm`

---

## Aturan folder — baca sebelum mengubah apa pun

Satu aturan yang menentukan segalanya:

> **`ZBSP_CS_APP/` adalah cermin objek SAP.**
> Apa pun di dalamnya ada, atau akan ada, sebagai objek di sistem.
> Apa pun di `reference/` **tidak** diaktifkan.

| Folder | Isi | Diaktifkan di SAP? |
|---|---|---|
| `ZBSP_CS_APP/Page with Flow Logic/` | Halaman BSP — **Dashboard Production saja** (`index2.htm` + `dash_prod.htm` + 13 Page Fragment) | **Ya** |
| `ZBSP_CS_APP/Page with Flow_Logic/` | Halaman BSP lainnya (`index.htm`, `monitoring.htm`, `dash_*.htm`, `diag_routing.htm`, `routing_map.htm`, `main.htm`) | **Ya** |
| `ZBSP_CS_APP/classes/` | Global class (SE24) | **Ya** |
| `ZBSP_CS_APP/MIMEs/` | Gambar yang dipakai halaman | **Ya** |
| `ZBSP_CS_APP/report/CHECKPOINT.md` | Status tiap jalur pengembangan | — |
| `ZBSP_CS_APP/report/daily/` | Catatan harian perubahan | — |
| `reference/` | Bahan rujukan, tidak dipelihara | **Tidak** |
| `docs/superpowers/` | Spec & rencana implementasi | — |
| `scripts/` | Alat bantu pemeriksaan | — |

**Menambah berkas baru?** Tanyakan satu hal: apakah ini akan diaktifkan di SAP?
Kalau ya → `ZBSP_CS_APP/`. Kalau tidak — mockup, salinan, eksperimen, versi
lama → `reference/`.

Jangan menaruh mockup di dalam `Page with Flow Logic/`. Itu pernah terjadi
(`prototype.html`) dan membuat orang mengira ada halaman BSP yang belum
diaktifkan.

> ⚠️ **Dua folder itu namanya cuma beda satu karakter** — spasi lawan garis
> bawah. Pemisahannya murni penataan repo: **di SAP seluruh halaman berada
> datar dalam satu aplikasi BSP**, jadi folder tidak memengaruhi
> `<%@include%>`, tautan antar-halaman, maupun aktivasi. Kalau nama ini
> membingungkan, ganti saja — tidak ada kode yang bergantung padanya.

## Isi `reference/`

| Folder | Isi | Kenapa disimpan |
|---|---|---|
| `backup-pages/` | 13 halaman BSP versi lama | Rujukan cara pengambilan data — banyak pola query yang masih dipakai berasal dari sini |
| `v2-so-tracer/` | `ZCL_CS_SO_TRACER` + report + tutorial | Eksperimen penelusuran SO, belum dipakai |
| `prototype-ui/` | Mockup UI statis (HTML/CSS/JS) | Acuan tampilan. `index.html` = prototype yang sedang dipakai; `prototype-lama.html` = pendahulunya |

Berkas di sini **tidak dipelihara**. Jangan memperbaiki bug di sini — kalau
sebuah pola diambil dari sini, salin ke berkas aktif lalu perbaiki di sana.

---

## Memulai

1. Baca `ZBSP_CS_APP/report/CHECKPOINT.md` — status tiap jalur pengembangan: apa yang
   sudah jalan, apa yang masih dummy, apa yang terhalang, dan jebakan yang
   sudah pernah memakan korban
2. Baca catatan harian terbaru di `ZBSP_CS_APP/report/daily/`
3. Sebelum menempel berkas `.htm` ke SE80, jalankan:

   ```
   python scripts/check_bsp.py "ZBSP_CS_APP/Page with Flow Logic/<berkas>.htm"
   ```

   Menangkap kesalahan yang sudah berkali-kali memakan waktu: delimiter BSP
   nyasar di komentar ABAP, blok `LOOP`/`IF`/`CASE` yang tidak berpasangan, dan
   tag HTML utuh di komentar. **Bukan** pengganti syntax check ABAP — hanya SAP
   yang bisa memutuskan itu.

## Dua hal yang mengikat seluruh aplikasi

**Urutan aktivasi:** class dulu, baru halaman. `ZCL_CS_UTIL` dan `ZCL_CS_PEG`
harus aktif di SE24 sebelum halaman BSP yang memanggilnya diaktifkan.

**Jaringan SAP tertutup:** tidak ada CDN, font eksternal, atau JS dari domain
luar yang akan termuat. Semua harus inline — ikon memakai `symbol` SVG di dalam
berkas.

---

## Halaman

| Berkas | Isi |
|---|---|
| `index.htm` | Dashboard Central Storage — stok per bagian, ranking buyer, sales order, feed pergerakan barang realtime |
| `index2.htm` | Dashboard Production — filter buyer, lintasan produksi 2 center, peta work center, SO/PLO, detail komponen |
| `monitoring.htm` | Pelacakan material per SO+Item, status komponen BOM berbasis RESB |
| `routing_map.htm` | Peta perjalanan SO — rantai stasiun, dot map operasi, stok real per stasiun |
| `diag_routing.htm` | Diagnostik routing Fase 0 (read-only, sekali pakai) |
| `dash_*.htm` | Endpoint JSON untuk panel-panel `index.htm` |
| `main.htm` | Flow logic inisialisasi (autentikasi) |

Status rinci tiap halaman ada di `ZBSP_CS_APP/report/CHECKPOINT.md`.

## Teknologi

- **Bahasa:** SAP ABAP (BSP Page with Flow Logic) + global class SE24
- **Frontend:** HTML5, CSS3, JS murni — tanpa library eksternal
- **Tabel SAP utama:** VBAK, VBAP, AFKO, AFPO, AFVC, AFVV, AFRU, RESB, MSKA,
  MARD, MAKT, CRHD, CRTX, T001L
- **Plant:** 1000 (Pembahanan) & 2000 (Produksi, Surabaya)
