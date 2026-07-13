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

" 1. Ambil operasi pertama (Opsi A) dari order
SELECT SINGLE arbpl FROM afvc
  INTO lv_arbpl
  WHERE aufpl = <plan order routing dari AFKO-AUFPL>
  ORDER BY vornr ASCENDING.  " operasi terkecil nomornya = pertama

" 2. Cari Cost Center dari Work Center (TABEL PERSIS BELUM DIVERIFIKASI —
"    kandidat: CRCO, join ke CRHD via OBJID. WAJIB cek SE11 dulu sebelum
"    dipakai — pola kesalahan tebak-field sebelumnya (AFKO/AUFK-WERKS)
"    menunjukkan field/tabel SAP tidak selalu sesuai dugaan awal.)
SELECT SINGLE kostl FROM crco
  INTO lv_kostl
  WHERE objid = <objid dari CRHD utk arbpl/werks ini>
    AND ... " kondisi validity date

" 3. Filter
IF lv_kostl NOT IN <whitelist>.
  " exclude dari checkpoint dashboard — order ini di luar scope
ENDIF.
```

**⚠️ Catatan jujur:** query di langkah 2 (Work Center → Cost Center) masih
**dugaan struktur tabel**, belum diverifikasi seperti field lain sebelumnya.
Riset manual kita selama ini selalu lewat transaksi `CR03` (UI), bukan query
tabel langsung — jadi nama tabel `CRCO`/`CRHD` di atas **wajib dicek dulu
via SE11** sebelum dipakai di kode nyata, sesuai pola kerja yang sudah
terbukti perlu di project ini (banyak kali salah tebak field/tabel di
langkah-langkah sebelumnya).

---

## 5. Fase 0 — Checklist Verifikasi Sebelum Coding

- [x] ~~Putuskan Opsi A vs B (§3)~~ — **SELESAI**: keputusan hybrid, lihat §3
- [ ] **Konfirmasi tabel penghubung Work Center ↔ Cost Center** via SE11
      (kandidat: `CRCO`, cek field persis + relasi ke `CRHD`/`ARBPL`)
- [ ] **Verifikasi ulang nama SLoc checkpoint** (`2261/2262/22F2/22F3/229K`)
      via `T001L` — ditemukan `22F3` = "CG Packing Area" di sistem nyata,
      BUKAN "Laminating OUT" seperti asumsi `ide.md`. Peta checkpoint perlu
      dikonfirmasi ulang SEMUANYA sebelum Logic 2 checkpoint sequence
      didesain, supaya tidak salah fondasi dari awal. *(Item terpisah,
      di luar cakupan filter Unit ini, tapi prasyarat sebelum Logic 2 lanjut)*
- [ ] Uji filter ini ke sample order lain (di luar 4 yang sudah dites) untuk
      pastikan tidak ada Unit lain yang kebetulan lolos filter/tidak
      sengaja ke-exclude

---

## 6. Belum Termasuk di Dokumen Ini

- Desain checkpoint sequence itu sendiri (dot progress, urutan SLoc) — plan
  terpisah, menunggu Fase 0 §5 selesai
- UI/tampilan bagaimana info Line ditampilkan di dashboard — menyusul
  setelah query dasar teruji
