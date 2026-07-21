# Analisis & Rekomendasi Diagram Laporan SO per SO-Item — `index2.htm`

> Pengembangan visualisasi untuk melihat data laporan Sales Order per SO+Item,
> memanfaatkan identitas index2 sebagai halaman ber-scope **MRP controller**.
> Dibuat: 2026-07-21 · Palet & aksesibilitas divalidasi dengan `dataviz` skill.
> Mockup visual: **`ZBSP_CS_APP/MIMEs/mockup-diagram-index2.html`** (buka di browser).

---

## 1. Ringkasan eksekutif

index2.htm sekarang menarik order per **tahap MRP** (Pembahanan WM/PN → Produksi
GA → Finish EB), tapi menyajikannya sebagai **tabel per tab** saja. Data itu punya
cerita alami yang belum tervisualkan: **seberapa jauh progres SO-item ini menembus
tiap tahap MRP**. Rekomendasi utama: tambahkan **satu band "Ringkasan SO-Item"
full-width di atas tab**, berisi (a) baris KPI, (b) **pipeline tahap MRP** (bullet
bar per tahap), dan (c) **komposisi stok per status**. Semuanya **HTML/CSS/SVG
murni yang dirender server-side dari ABAP** — tanpa library chart, tanpa MIME JS
tambahan, memakai ulang helper `css_pct()` & kelas `prog-*` yang sudah ada.

---

## 2. Data yang tersedia per SO+Item (sudah ada di flow logic)

| Sumber | Field kunci | Pertanyaan yang bisa dijawab | "Job" data | Bentuk tepat |
|---|---|---|---|---|
| AFPO⨝AFKO (`lt_ord`) | psmng (target), wemng (delivered), **dispo (MRP)**, pwerk | Seberapa jauh progres tiap tahap MRP? Target vs terkirim? | Progres/magnitudo per tahap **ber-urutan** | **Bullet bar** (ordinal ramp) |
| AFPO per order | matnr, psmng, wemng | Order mana yang tertinggal? | Magnitudo per item | Bullet list / bar |
| MSKA (`lt_stok`) | labst (Unrestr.), insme (QI), speme (Blocked) | Komposisi & kesehatan stok saat ini? | Part-to-whole + **status** | **Stacked bar** + palet status |
| MSEG (`lt_hist`) | budat, bwart, menge | Aktivitas pergerakan? | Peristiwa sepanjang waktu | Timeline / bar ringkas (opsional) |
| VBAK/VBUP | gbstk/gbsta (A/B/C) | Status header/item SO? | State tunggal | **Badge status** (bukan chart) |

**Catatan penting:** untuk pipeline 3-tahap, `ty_ord` perlu **menambah 1 field
`dispo`** dan menambahkannya di SELECT (`a~... k~dispo`). Perubahan sepele; tanpa
itu hanya bisa 2 tahap (per-plant). Mapping tahap (mengikuti `index_backup.htm`):

```
Pembahanan : dispo ∈ { WM1, WM2, PN1, PN2 }   (Plant 1000)
Produksi   : dispo ∈ { GA1, GA2 }             (Plant 2000)
Finish     : dispo ∈ { EB2 }                  (Plant 2000)
```

---

## 3. Konsep visual (diurut prioritas)

### ⭐ Konsep 1 — Pipeline Tahap MRP (UNGGULAN, jadi hero halaman)

**Menjawab:** "Progres SO-item ini di tiap tahap produksi MRP." Ini persis nilai
jual index2 yang belum tervisualkan.

**Bentuk:** tiga **bullet bar** horizontal ber-urutan (ordinal). Tiap bar = satu
tahap: track abu (= Σtarget/psmng tahap itu), fill (= Σdelivered/wemng), label %
+ angka. Warna fill pakai **ordinal ramp biru** (makin dalam tahap makin gelap) —
divalidasi lolos (lihat §5). Karena tahap **ber-urutan** (bukan identitas acak),
ordinal ramp lebih tepat daripada kategorikal.

```
RINGKASAN PROGRES  ── SO 10000021 / Item 10 · MEJA MAKAN JATI

 Pembahanan  ███████████████████████████  100%   100 / 100 PC
 (WM/PN)
 Produksi    █████████████████░░░░░░░░░░░   65%    65 / 100 PC
 (GA)
 Finish      █████░░░░░░░░░░░░░░░░░░░░░░░░   20%    20 / 100 PC
 (EB)
                                    ▲ tahap terjauh: Produksi
```

**Sumber ABAP:** loop `lt_ord`, akumulasi psmng/wemng ke 3 akumulator per
`dispo`, lalu `zcl_cs_util=>css_pct( )` untuk lebar fill — pola yang **sudah
dipakai** di tab Pembahanan/Produksi, tinggal diagregasi.

### Konsep 2 — Target vs Delivered per Order (bullet list)

**Menjawab:** "Order/material mana yang menahan progres?" Satu bullet bar per
baris `lt_ord` (material), disusun dalam tahap. Bagus sebagai **detail di bawah
pipeline** atau isi tab. Reuse penuh kelas `prog-*` yang ada. Emphasis: baris
paling tertinggal disorot, sisanya redup (pola "emphasis" dataviz).

### Konsep 3 — Komposisi Stok per Status (stacked bar + palet status)

**Menjawab:** "Stok SO-item ini sekarang di mana & sehat tidak?" Satu **stacked
bar horizontal** per lokasi (atau total): segmen Unrestricted / Quality-Insp /
Blocked. Ini **part-to-whole + status**, jadi pakai **palet status** (bukan
kategorikal): hijau `good` / kuning `warning` / merah `critical`, **selalu dengan
ikon + label** (status tak boleh warna-saja).

```
STOK SAAT INI (MSKA)                     total 320 PC
 2000/2KCS  ██████████████░░░░░░░░  ✔210 Unr · ⚠80 QI · ⛔30 Blk
 1000/1D00  ████████████████████    ✔100 Unr
            └ hijau=bebas  kuning=inspeksi  merah=blokir
```

**Sumber ABAP:** `lt_stok` sudah punya labst/insme/speme — tinggal jumlahkan &
hitung lebar segmen. Gap 2px antar segmen (spek mark dataviz).

### Konsep 4 — Ringkasan Pergerakan (OPSIONAL, prioritas rendah)

Bar ringkas qty per jenis gerakan (301/311/321…) atau strip timeline dari
`lt_hist`. **Rekomendasi: tunda.** Jenis gerakan bisa >7 kelas → aturan dataviz
menyarankan tabel, dan tab Riwayat sudah menyajikannya dengan badge berwarna.
Kalau nanti diinginkan, pakai **satu hue (sequential) diurut qty**, bukan pelangi.

---

## 4. Rekomendasi Layout UI

**Pola: KPI & ringkasan di atas, detail (tab) di bawah** — pola dashboard baku,
paling mudah dipindai. Band ringkasan **full-width** (membentang di atas split
2-kolom) supaya chart punya ruang lebar & legibel; form Transfer Posting di kanan
tak terganggu.

```
┌────────────────────────────────────────────────────────────────────┐
│ [ Filter: No SO | No Item | CARI DATA ]                             │
├────────────────────────────────────────────────────────────────────┤
│ RINGKASAN SO-ITEM  (band baru, full-width)                          │
│ ┌── KPI row ─────────────────────────────────────────────────────┐ │
│ │  Total Order   Total Target   Total Delivered   Progres ◑ 62%  │ │
│ │      7           300 PC          185 PC          (ring mini)    │ │
│ └────────────────────────────────────────────────────────────────┘ │
│ ┌── Pipeline Tahap MRP (Konsep 1) ──┐ ┌── Komposisi Stok (K3) ──┐ │
│ │ Pembahanan ██████████ 100%        │ │ 2KCS ███████ ✔⚠⛔        │ │
│ │ Produksi   ██████░░░░  65%        │ │ 1D00 ██████  ✔          │ │
│ │ Finish     ██░░░░░░░░  20%        │ │                          │ │
│ └───────────────────────────────────┘ └──────────────────────────┘ │
├───────────────────────────────────┬────────────────────────────────┤
│ [Pembahanan][Produksi][Riwayat]   │  TRANSFER POSTING (tetap)      │
│ [Stok][Info]   ← tab detail lama  │  (tak berubah)                 │
│ …tabel detail…                    │                                │
└───────────────────────────────────┴────────────────────────────────┘
```

- **Muncul hanya saat `lv_so_found = abap_true`** (sama seperti blok tab). Saat
  kosong/belum cari → band disembunyikan, empty-state lama tetap.
- **Responsif:** dua kartu bawah `display:flex; flex-wrap:wrap` → menumpuk di
  layar sempit. Bar horizontal aman untuk label panjang.
- **Light/dark:** semua warna via CSS custom properties + `@media
  (prefers-color-scheme)` (lihat §5) — dark mode di-*step* ulang, bukan flip.

---

## 5. Palet & aksesibilitas (divalidasi, bukan dikira-kira)

**Pipeline tahap (ordinal ramp biru)** — sudah dijalankan lewat validator dataviz:

| Tahap | Light | Dark |
|---|---|---|
| Pembahanan | `#86b6ef` | `#6da7ec` |
| Produksi | `#3987e5` | `#3987e5` |
| Finish | `#1c5cab` | `#184f95` |

> `node validate_palette.js "#86b6ef,#3987e5,#1c5cab" --ordinal --mode light`
> → **ALL CHECKS PASS** (monotone L, gap ≥0.06, ujung terang 2.06:1). Dark idem.

**Stok (palet status — fixed, tak di-tema):** good `#0ca30c` · warning `#fab219`
· critical `#d03b3b`. **Wajib** ikon + label (✔/⚠/⛔) karena di surface terang
warning sub-3:1 — mitigasi resmi dataviz.

**Aturan yang dipatuhi:**
- Teks (angka/label) pakai ink token (`#0b0b0b` / `#52514e`), **bukan** warna seri.
- Progres pakai `font-variant-numeric: tabular-nums` di kolom angka.
- Bar tipis, ujung membulat 4px nempel baseline, gap 2px antar segmen.
- **Hero number** progres keseluruhan ≥48px, sans sistem.
- Ada **table view** (tab detail lama = tabelnya) → identitas tak pernah warna-saja.
- Satu seri = tanpa kotak legend (judul sudah menamai); status = legend + ikon.

---

## 6. Kelayakan teknis di BSP / SE80

| Aspek | Keputusan |
|---|---|
| **Rendering** | 100% server-side: lebar bar/segmen dihitung ABAP → ditulis ke `style="width:..%"`. Persis pola `prog-fill` yang sudah jalan. |
| **Library chart** | **Tidak ada.** Bullet/stacked/ring cukup `<div>`+CSS & sedikit inline `<svg>` untuk ring. Tak menambah MIME JS, tak melanggar prinsip "JS mandiri". |
| **Reuse** | `zcl_cs_util=>css_pct/prog_bar_class/prog_txt_class` dipakai ulang; CSS `.prog-*` sudah ada di `style.css`. |
| **Perubahan data** | Hanya **tambah `dispo` ke `ty_ord` + SELECT** (untuk 3 tahap). Agregasi = 1 loop ringan atas `lt_ord`/`lt_stok` yang sudah di memori. Nol query tambahan. |
| **Sinkronisasi** | Band ini **khusus index2** (berbasis MRP). Jangan port mentah ke index.htm/pelacakan.htm (itu SLoc). Idealnya logika agregasi taruh di method class → lihat `REKOMENDASI-REFAKTOR-INDEX.md`. |

**Snippet agregasi (inti, ~15 baris):**
```abap
TYPES: BEGIN OF ty_stage, key TYPE string, tgt TYPE p LENGTH 15 DECIMALS 3,
         del TYPE p LENGTH 15 DECIMALS 3, END OF ty_stage.
DATA lt_stage TYPE TABLE OF ty_stage.   " 3 baris: PMB / PRD / FIN
LOOP AT lt_ord INTO ls_ord.
  CASE ls_ord-dispo.
    WHEN 'WM1' OR 'WM2' OR 'PN1' OR 'PN2'. lv_k = 'PMB'.
    WHEN 'GA1' OR 'GA2'.                   lv_k = 'PRD'.
    WHEN 'EB2'.                            lv_k = 'FIN'.
  ENDCASE.
  READ TABLE lt_stage ASSIGNING <st> WITH KEY key = lv_k.
  <st>-tgt = <st>-tgt + ls_ord-psmng.  <st>-del = <st>-del + ls_ord-wemng.
ENDLOOP.
" lv_pct = css_pct( del / tgt * 100 ) → lebar fill bullet
```

---

## 7. Rekomendasi bertahap

| Fase | Isi | Effort | Nilai |
|---|---|---|---|
| **MVP** | KPI row + **Pipeline Tahap MRP** (Konsep 1) | ½ hari | ★★★★★ |
| Fase 2 | **Komposisi Stok** (Konsep 3) | ¼ hari | ★★★★ |
| Fase 3 | Bullet per-order + emphasis (Konsep 2) | ¼ hari | ★★★ |
| Nanti | Ringkasan pergerakan (Konsep 4) | — | ★★ |

**Saran:** kerjakan MVP dulu — itu yang paling menjawab "melihat data laporan SO
per item" dan langsung menonjolkan keunikan index2. Sisanya inkremental.

---

## 8. Langkah berikutnya

1. Buka **`MIMEs/mockup-diagram-index2.html`** di browser untuk melihat wujud
   nyata UI (data dummy, palet tervalidasi, light/dark).
2. Setujui konsep & fase → saya susun rencana implementasi dan terapkan ke
   index2.htm (menambah `dispo` ke `ty_ord`, band ringkasan, CSS band).
