# Planning — Logic 2: Checkpoint Monitoring
## Bagian: Kriteria Filter Unit "Wood Furniture"

> Status dokumen: **DRAFT / PLAN**. Disusun dari hasil verifikasi manual di SAP
> (SE11/SE16, CO03, CR03) pada 2026-07-11. Bagian ini adalah **fondasi filter
> scope**, ditulis SEBELUM desain checkpoint sequence penuh — karena tanpa
> filter ini benar, seluruh Logic 2 bisa salah sasaran (ikut memproses order
> yang sebenarnya di luar tanggung jawab Central Storage).

---

## 0. Latar Belakang & Tujuan Filter

`ide.md` §3 (Scope) menyatakan Central Storage hanya bertanggung jawab atas
**Plant 2000**. Riset lanjutan (2026-07-11) menemukan bahwa di dalam Plant
2000 sendiri ada **beberapa Unit bisnis berbeda** (Wood Furniture, Metal
Surabaya, Chair, dll — lihat tabel Cost Center lengkap di §2), masing-masing
dengan skema Cost Center sendiri. **Central Storage hanya relevan untuk Unit
"WOOD FURNITURE"** — unit lain (meski sama-sama Plant 2000) berada di luar
scope dashboard ini.

Tujuan bagian ini: definisikan kriteria teknis untuk memfilter **hanya**
order/material yang termasuk Unit Wood Furniture, sebelum checkpoint
sequence (Logic 2) diproses.

---

## 1. Temuan Verifikasi (bukti lapangan)

4 sampel diuji manual via `CO03` → `Operations` → catat Work Center →
`CR03` → tab `Costing` → catat Cost Center:

| # | Order | Material | Plant | Cost Center | Deskripsi | Match Unit Wood Furniture? |
|---|---|---|---|---|---|---|
| 1 | 181000028030 | Drawer component | 2000 | `1111071000` | DRW Machining | ❌ Tidak (unit Drawer, prefix 1111) |
| 2 | 181000027750 | Drawer assembly | 1000 | `1111073002` | DRW Assembly Line 1 | ❌ Tidak |
| 3 | 161000477282 | Wood Engineering | 1000 | `1111021001` | WE Cutting | ❌ Tidak (unit KMI 1) |
| 4 | 225100245269 | Solid Panel | **2000** | **`1131100001`** | **LINE A** | ✅ **Ya** |

**Kesimpulan:** relasi `Work Center → Cost Center` (via `CR03` tab Costing)
adalah sumber yang **valid dan reliable** untuk menentukan Unit — tapi
**bukan semua order di Plant 2000 otomatis termasuk Wood Furniture**. Filter
eksplisit wajib diterapkan, tidak bisa asumsi "Plant = 2000" saja cukup.

---

## 2. Daftar Cost Center Unit Wood Furniture (whitelist)

Sumber: data referensi cost center perusahaan (bukan dari SAP query, dari
dokumen internal — perlu di-hardcode sebagai konstanta/tabel Z kecil karena
jarang berubah, 10 baris saja).

| Section | Line | Cost Center |
|---|---|---|
| Machining | Line A | `1131100001` |
| Machining | Line B | `1131100002` |
| Machining | Line C | `1131100003` |
| Edge Banding | - | `1131200000` |
| Pre Assembly | - | `1131300000` |
| Assembly | Lifter A | `1131400001` |
| Assembly | Lifter B | `1131400002` |
| Assembly | Lifter C | `1131400003` |
| Central Storage | - | `1131500000` |
| Sample Maker | - | `1131600000` |

**Ini WHITELIST tertutup** — cost center di luar 10 kode ini (termasuk
`1111...` DRW/WE, `1133...` Metal Surabaya, `1134...` Chair, dst) dianggap
**di luar scope**, bukan error, bukan perlu fallback rumit — cukup
di-exclude dari checkpoint dashboard.

---

## 3. Level Penerapan Filter — KEPUTUSAN FINAL (2026-07-11)

Cost Center menempel ke **Work Center**, dan Work Center menempel ke
**operasi** (`AFVC`), bukan ke order secara keseluruhan. Satu production
order bisa punya >1 operasi dengan Work Center berbeda (lihat order
`181000028030` di riset sebelumnya: operasi `0010` di `WC107`/Drawer,
operasi `0020` di `WC110` — dua unit berbeda dalam 1 order).

**Keputusan: bukan Opsi A (operasi pertama) atau Opsi B (salah satu
operasi) murni — melainkan pendekatan HYBRID:**

- **Inklusi order**: order tetap ditampilkan di dashboard selama **minimal
  satu** operasinya masuk whitelist Wood Furniture (mirip semangat Opsi B —
  tidak ada order relevan yang hilang dari radar).
- **Kedalaman detail render bersifat PER-OPERASI, bukan per-order**:
  - Operasi dengan Cost Center **masuk whitelist** → render detail penuh
    (posisi checkpoint, Line A/B/C/Lifter, dot progress, dsb).
  - Operasi dengan Cost Center **di luar whitelist** → render **status
    ringkas saja** (mis. "Diproses di unit lain"), TANPA breakdown
    checkpoint/line — karena itu bukan tanggung jawab Admin Central Storage.

**Alasan:** selaras filosofi `ide.md` ("apa yang harus dikerjakan Admin
Central Storage saat ini") — Admin perlu tahu SEMUA material terkait SO
ada di radar (tidak hilang), tapi detail teknis hanya relevan untuk tahap
yang jadi tanggung jawabnya.

**Konsekuensi desain:** klasifikasi whitelist tetap dihitung **per operasi**
(query `AFVC` per order, bukan cuma operasi pertama), tapi hasilnya dipakai
untuk **menentukan level detail tampilan**, bukan untuk exclude/include
order secara keseluruhan.

---

## 4. Sketsa Teknis (ABAP, level konsep — BELUM final)

```abap
" Konstanta whitelist (10 cost center Wood Furniture)
CONSTANTS: BEGIN OF gc_wf_cc,
             line_a    TYPE kostl VALUE '1131100001',
             line_b    TYPE kostl VALUE '1131100002',
             line_c    TYPE kostl VALUE '1131100003',
             edgeband  TYPE kostl VALUE '1131200000',
             preassy   TYPE kostl VALUE '1131300000',
             lifter_a  TYPE kostl VALUE '1131400001',
             lifter_b  TYPE kostl VALUE '1131400002',
             lifter_c  TYPE kostl VALUE '1131400003',
             cstorage  TYPE kostl VALUE '1131500000',
             sample    TYPE kostl VALUE '1131600000',
           END OF gc_wf_cc.
" (atau RANGES/tabel internal, lebih rapi utk WHERE ... IN)

" 1. Ambil operasi pertama dari order (scope: PER-ITEM, keputusan 2026-07-13)
SELECT SINGLE aufpl FROM afko
  INTO lv_aufpl
  WHERE aufnr = <aufnr order utama item ini>.

" Field yang benar adalah ARBID (bukan ARBPL!) -- terverifikasi SE11
" 2026-07-13, pesan error "String ARBPL not found" membuktikan field
" tsb tidak ada. ARBID bertipe CR_OBJID (NUMC 8), SAMA PERSIS dengan
" CRHD-OBJID/CRCO-OBJID -- artinya bisa langsung join ke CRCO TANPA
" lewat CRHD sama sekali (CRHD jadi opsional, cuma perlu kalau mau
" tampilkan kode Work Center spt "WC107" untuk display/debug).
SELECT SINGLE arbid FROM afvc
  INTO lv_arbid
  WHERE aufpl = lv_aufpl
  ORDER BY vornr ASCENDING.  " operasi terkecil nomornya = pertama

" 2. ARBID -> Cost Center via CRCO LANGSUNG (skip CRHD)
"    Filter tanggal LENGKAP (begda + endda) -- CRCO time-dependent,
"    terbukti ada >1 periode validitas saat cek KS03 sebelumnya
"    (popup "Analysis Time Frame" dgn 2 baris berbeda).
SELECT SINGLE kostl FROM crco
  INTO lv_kostl
  WHERE objid = lv_arbid
    AND kokrs = 'PC01'
    AND begda <= sy-datum
    AND endda >= sy-datum.

" 3. Filter
IF lv_kostl NOT IN <whitelist>.
  " badge netral "Unit lain" -- TIDAK exclude order, sesuai keputusan §3
ENDIF.
```

**✅ Update 2026-07-13 (revisi kedua):** ditemukan kesalahan asumsi nama
field (`ARBPL` ternyata tidak ada di `AFVC`, yang benar `ARBID`) — bukti
lagi kenapa **setiap** field wajib dicek SE11 langsung, tidak cukup
"pengetahuan umum SAP". Sekaligus ditemukan **penyederhanaan**: karena
`ARBID` sudah bertipe `OBJID` yang sama dengan `CRCO-OBJID`, join ke `CRHD`
**tidak wajib** untuk mendapat Cost Center — cukup 2 tabel (`AFVC` →
`CRCO`), bukan 3. Filter tanggal validitas `CRCO` juga dilengkapi
(`begda` + `endda`, sebelumnya cuma `endda`).

**✅ Keputusan scope (2026-07-13): PER-ITEM.** Badge Line dihitung 1x per
item SO (dari order utamanya), BUKAN per-komponen/drill ke HALB. Lebih
simpel, cukup untuk tujuan "tahu Line penanggung jawab", dan konsisten
dengan cara 4 sampel di §1 diverifikasi (semua di level order/item, bukan
drill ke sub-komponen).

---

## 5. Fase 0 — Checklist Verifikasi Sebelum Coding

- [x] ~~Putuskan Opsi A vs B (§3)~~ — **SELESAI**: keputusan hybrid, lihat §3
- [x] ~~Konfirmasi tabel penghubung Work Center ↔ Cost Center~~ —
      **SELESAI 2026-07-13**: `CRCO` terverifikasi via SE11, field
      `OBJID/KOKRS/KOSTL` ada. Sisa kecil: relasi `CRHD`, cek saat coding.
- [x] ~~Verifikasi ulang nama SLoc checkpoint~~ — **SELESAI, lihat §7 (temuan
      kritis)**. Peta `ide.md` terbukti usang; premis checkpoint sequence
      tetap perlu dipertimbangkan ulang sebelum lanjut.
- [ ] Uji filter ini ke sample order lain (di luar 4 yang sudah dites) untuk
      pastikan tidak ada Unit lain yang kebetulan lolos filter/tidak
      sengaja ke-exclude

---

## 7. TEMUAN KRITIS (2026-07-13) — Checkpoint Sequence TIDAK Seragam Antar Material

> **Status: mengubah arah desain Logic 2 secara mendasar.** Bagian ini
> ditulis SETELAH §1–6, sebagai hasil verifikasi lanjutan terhadap peta
> checkpoint `ide.md`. Dibaca SEBELUM memulai desain checkpoint sequence.

### 7.1 Verifikasi Nama SLoc via T001L

Kelima checkpoint di `ide.md` §6 dicek langsung ke `T001L` (Plant 2000):

| SLoc | Asumsi `ide.md` | **Nama Aktual (T001L)** | Status |
|---|---|---|---|
| `2KCS` | Central Storage | Central Storage | ✅ Cocok |
| `2261` | Machining IN | Machining D-IN | ✅ Cocok (+"D") |
| `2262` | Machining OUT | Machining D-OUT | ✅ Cocok |
| `22F2` | Laminating IN | **Color Room** | ❌ **Meleset total** |
| `22F3` | Laminating OUT | **CG Packing Area** | ❌ **Meleset total** |
| `229K` | **Ready Assy** (titik akhir!) | **Sanding D-IN** | ❌ **Meleset total, dan bukan titik akhir** |

Ditemukan juga SLoc proses **yang sama sekali tidak ada** di peta `ide.md`:
`2291` Pre-Assy D-IN, `2292` Sanding D-OUT, `2293` Assembly D-IN, `2294`
Assembly D-OUT, `22E2` Banding D-IN, `22EK` EBD Karantina.

**Kesimpulan awal:** peta checkpoint `ide.md` §6 sudah usang, minimal 3 dari
5 titik keliru. (Bagian ini yang tadinya diperkirakan cukup diperbaiki
dengan "peta baru" — lihat §7.2 kenapa itu ternyata tidak cukup.)

### 7.2 Bukti Jejak Kronologis — Sequence Berbeda per Jenis Material

Untuk memastikan urutan checkpoint yang benar (bukan cuma nama), ditelusuri
**jejak kronologis MSEG** (bukan snapshot MARD) untuk material
`20029618` (SOLID PNLMHN), order `225100245269` (SO 10469, order **sudah
TECO** — riwayat lengkap):

```
101 (GR)  →  2262 (Machining D-OUT)
321       →  2262 → 2262 (reklasifikasi kualitas, sloc sama)
301/311   →  2262 → 229K (Sanding D-IN)
261       →  229K → (dikonsumsi ke order lain)
```

**Cuma 2 checkpoint** (`2262 → 229K`) untuk material ini, langsung
dikonsumsi dari `229K` — BUKAN melalui rute panjang
`2261→22E2→229K→2293→...` yang terlihat di data BOM material *lain*
(drawer/kayu solid kompleks, lihat data mentah 2026-07-13 di riwayat chat).

**Material hardware/consumable** (mis. sekrup `RHSSCR00102`) bahkan **tidak
melalui checkpoint sama sekali** — cuma `261` (Goods Issue langsung ke
order) di titik manapun dibutuhkan, tanpa `311`/`301` antar-SLoc.

### 7.3 Kesimpulan — Premis "1 Checkpoint Sequence Tetap" TIDAK VALID

`ide.md` §6 (Logic 2) mengasumsikan **satu urutan checkpoint seragam**
berlaku untuk semua material (`2261→2262→22F2→22F3→229K`). Bukti lapangan
menunjukkan:

1. Rute **berbeda-beda per jenis/kompleksitas material** (solid panel:
   2 titik; komponen drawer kompleks: 5+ titik; hardware: 0 titik/langsung
   konsumsi).
2. `229K` bukan titik akhir ("Ready Assy") — material bisa **dikonsumsi
   langsung** dari sana ke order lain, bertentangan dengan definisi
   `ide.md` bahwa SO baru "selesai" setelah sampai `229K`.
3. Ini **konsisten** dengan catatan yang SUDAH ADA di kode
   `monitoring_bom.htm` (lihat `reference.md` §7): *"Rute internal Plant
   2000 dinamis per material (banyak sloc; mvt 311/261/101) → TIDAK
   dilacak sebagai tahap/%"* — keputusan desain "Sloc Terkini" (snapshot,
   bukan sequence) yang sudah diimplementasikan **ternyata sudah tepat**
   menghindari masalah ini sejak awal, bukan sekadar jalan pintas.

### 7.4 Rekomendasi — Logic 2 Perlu Dipikir Ulang Konsepnya

**Bukan** "lanjutkan riset sampai ketemu peta checkpoint yang benar" —
karena kemungkinan besar **tidak ada satu peta tunggal** yang berlaku
universal. Opsi ke depan yang lebih realistis (perlu didiskusikan lebih
lanjut, BELUM diputuskan):

- **Opsi 1 — Pertahankan "Sloc Terkini" (snapshot), perkaya dengan Cost
  Center/Line** dari §1–4 dokumen ini. Tidak coba paksakan sequence/dot
  progress; cukup tunjukkan posisi kini + Line penanggung jawab.
- **Opsi 2 — Sequence per-BOM/routing**, bukan per-checkpoint universal:
  ambil urutan checkpoint dari **routing order itu sendiri** (`AFVC`
  operasi + `T001L` sloc tujuan tiap operasi bila ada), jadi tiap material
  punya "peta pribadi" sesuai routing-nya — jauh lebih kompleks, effort
  besar, belum tentu sepadan.
- **Opsi 3 — Skip Logic 2 versi "dot progress sequence" sepenuhnya**,
  fokuskan effort ke Action Center/Attention Flag (bagian lain `ide.md`
  yang juga belum ada) yang tidak bergantung pada premis sequence tetap.

**KEPUTUSAN FINAL (2026-07-13): Opsi 1 dipilih.** Pertahankan pendekatan
"Sloc Terkini" (snapshot posisi, sudah terbukti solid di
`monitoring_bom.htm`), perkaya dengan info Line/Cost Center dari §1–4.
**Tidak** membangun dot-progress/sequence checkpoint — premisnya sudah
terbukti tidak berlaku universal (§7.1–7.3).

---

## 9. Rencana Implementasi Opsi 1

### 9.1 Tujuan

Tambahkan **kolom "Line"** (atau badge sejenis) di sebelah kolom "Sloc
Terkini" yang sudah ada di `monitoring_bom.htm`, menunjukkan Line/Section
Wood Furniture penanggung jawab komponen tsb — TANPA mengubah struktur
"Sloc Terkini" yang sudah berjalan.

### 9.2 Perubahan yang Dibutuhkan (level konsep)

**Scope: PER-ITEM** (keputusan final 2026-07-13, lihat §4).

1. Untuk tiap **item SO** (bukan per-komponen), ambil `aufnr` order
   utamanya (sudah tersedia di `monitoring_bom.htm`, field `ls_item_row-aufnr`).
2. Rantai query §4 (AFKO→AFVC→CRHD→CRCO) untuk dapat `KOSTL` dari operasi
   pertama order tsb.
3. Kalau Cost Center masuk whitelist §2 → tampilkan badge Line (mis. "Line
   A", "Lifter B"). Kalau tidak → badge netral (mis. "Unit lain") TANPA
   detail lebih lanjut (selaras keputusan hybrid §3 — meski secara teknis
   scope final per-item, bukan per-operasi, penamaan "hybrid" tetap relevan
   untuk keputusan render detail vs ringkas).
4. Badge ditampilkan di **level item** (dekat judul item/BOM), BUKAN di
   tiap baris komponen RESB — beda dari "Sloc Terkini" yang memang per
   komponen.
5. Kolom/badge baru ini **read-only tambahan**, tidak mengubah logic "Sloc
   Terkini"/kolom lain yang sudah ada.

### 9.3 Prasyarat Sebelum Coding (Fase 0 — SEMUA SELESAI 2026-07-13)

- [x] Tabel `CRCO` terverifikasi (field `OBJID/KOKRS/KOSTL`)
- [x] Tabel `CRHD` terverifikasi (field `OBJID/ARBPL/WERKS_D`)
- [x] Field `AFKO-AUFPL` terverifikasi ("Routing number of operations")
- [x] Keputusan scope: **per-item** (bukan per-komponen)
- [ ] *(Opsional)* Wireframe/posisi badge — bisa langsung diputuskan saat
      coding, perubahan kecil

### 9.4 Uji Coba Setelah Implementasi

- Test ke SO `10469` (order `225100245269`, sudah TECO, cost center Line A
  terverifikasi §1) — badge harus muncul "Line A"
- Test ke SO yang komponennya termasuk Drawer/unit lain (mis. dari riset
  §1 sampel 1–3) — badge harus muncul netral, bukan Line A/B/C palsu

---

## 10. Belum Termasuk di Dokumen Ini

- UI/tampilan final badge Line (styling, posisi persis) — akan disusun
  saat implementasi §9
- Backlog jangka panjang (Action Center/Attention Flag, dll di luar scope
  dokumen ini)

---

## 11. PIVOT (2026-07-13) — Status SLoc Sederhana, Bukan Filter SO List

> Ditulis SETELAH badge Line/Unit (§9) selesai diimplementasikan &
> divalidasi. Sempat dipertimbangkan "Opsi B" (filter SO list berdasarkan
> Cost Center — SO di luar Wood Furniture disembunyikan dari sidebar),
> TAPI **dibatalkan** setelah klarifikasi kebutuhan sebenarnya lebih
> sederhana dari itu.

### 11.1 Kebutuhan Sebenarnya (klarifikasi 2026-07-13)

Bukan filter SO list, bukan drill detail komponen/BOM pihak lain. Yang
dibutuhkan: **status sederhana** posisi material yang masuk Central
Storage & diproses di SLoc Wood Furniture, sampai batas `229K` (sesuai
definisi `ide.md`, terlepas dari nuansa "229K bukan titik akhir sungguhan"
yang ditemukan di §7 — itu tetap dicatat sebagai keterbatasan, tapi
definisi bisnis `ide.md` yang dipakai apa adanya).

**Badge Line/Unit (§9) TETAP DIPAKAI**, sebagai tambahan di samping fitur
ini — bukan pengganti.

### 11.2 Desain — Perkaya "Sloc Terkini" yang Sudah Ada, Bukan Fitur Baru

**Tidak perlu query baru sama sekali.** Data `lt_curloc` (dari `MARD`) di
`monitoring_bom.htm` sudah ada. Cukup tambahkan **lapisan pemetaan**
(lookup SLoc → label status), murni presentational.

| SLoc | Nama Asli (T001L) | Status Sederhana |
|---|---|---|
| `2KCS` | Central Storage | "Baru Masuk Central Storage" |
| `2261` | Machining D-IN | "Sedang di Machining" |
| `2262` | Machining D-OUT | "Sedang di Machining" |
| `22E2` | Banding D-IN | "Sedang di Edge Banding" |
| `22EK` | EBD Karantina | "Sedang di Edge Banding" |
| `2291` | Pre-Assy D-IN | "Sedang di Sanding" |
| `2292` | Sanding D-OUT | "Sedang di Sanding" |
| `2293` | Assembly D-IN | "Sedang di Assembly" |
| `2294` | Assembly D-OUT | "Sedang di Assembly" |
| `229K` | Sanding D-IN | **"Sampai Batas Akhir (229K)"** |
| *(lainnya)* | — | "Di Luar Rute Wood Furniture" |
| *(tidak ada stok)* | — | Tetap "Tidak ada stok" (tidak berubah) |

**⚠️ Belum diverifikasi:** apakah `22F2` (Color Room) dan `22F3` (CG
Packing Area) termasuk rute Wood Furniture atau bukan — muncul di data BOM
campuran (ada di komponen Wood Furniture DAN Chair). **Default aman**:
KELUARKAN dari daftar whitelist route sampai diverifikasi (masuk kategori
"Di Luar Rute Wood Furniture"), supaya tidak salah klaim status kalau
ternyata itu punya unit lain.

### 11.3 Implementasi (level konsep)

1. Tambah method baru di `ZCL_CS_UTIL` (pola sama seperti
   `prog_bar_class`/`fmt_date`): `wf_route_status( iv_lgort ) RETURNING
   rv_status TYPE string` — lookup statis dari tabel di atas.
2. Di `monitoring_bom.htm`, panggil method ini untuk tiap `ls_curloc-lgort`
   yang sudah ada di loop rendering "Sloc Terkini", tampilkan status di
   SAMPING badge SLoc yang sudah ada (bukan menggantikan — supaya info
   detail SLoc mentah tetap ada untuk yang butuh).
3. **Highlight visual** untuk status "Sampai Batas Akhir (229K)" — mungkin
   warna hijau/badge berbeda, supaya menonjol sebagai penanda "beres" dari
   sisi Central Storage.
4. **Tidak ada query SQL baru.** Murni logic presentasi dari data yang
   sudah di-fetch.

### 11.4 Dibatalkan/Tidak Jadi Dikerjakan

- Filter SO list per Unit (dulu "Opsi B") — **dibatalkan**
- Cek performa 100+ SO — **tidak relevan lagi**, tidak ada query
  tambahan yang berat