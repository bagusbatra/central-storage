# Spec Desain — index3.htm: Cockpit Aktual Central Storage

> BSP page (SE80) sebagai papan pantau real-time admin Central Storage.
> Sumber data: SAP S/4HANA 1809 (data yang sudah ada). Tanpa library chart.
> Tanggal: 2026-07-22 · Status: disetujui untuk dilanjut ke rencana implementasi.

---

## 1. Tujuan & konteks

index3.htm saat ini **byte-identik dengan index.htm** (halaman pelacakan per
SO+Item). Halaman ini **direpurpose total** menjadi **cockpit agregat** yang
menjawab 4 pertanyaan admin dalam hitungan detik — bukan lagi lookup per-SO:

1. Barang apa ada di mana, berapa? (stok aktual)
2. Apa yang hari ini/barusan bergerak? (pergerakan aktual)
3. Masalah apa yang perlu ditindak? (kadaluarsa/blokir/mengendap) — *fase lanjutan*
4. Progres produksi sampai mana? — *fase lanjutan*

**Keputusan arah (disetujui user):** fokus **Cockpit Aktual** = modul **A + C + B**;
cakupan **bisa difilter** (default semua, ada filter plant + SLoc + rentang tanggal).

**Yang diganti:** seluruh body pelacakan lama index3 (filter SO/Item, 5 tab,
form Transfer Posting, modal) **dihapus/diganti** oleh layout cockpit. Yang
**dipertahankan**: shell header-bar, navbar, footer, dan helper yang bisa dipakai
ulang (formatter `.num-fmt`, pemetaan badge `bwart`, `zcl_cs_util`).

---

## 2. Ruang lingkup

| Fase | Isi | Status spec ini |
|---|---|---|
| **MVP** | Filter + Modul A (KPI) + Modul C (Live Feed) | **in-scope** |
| Fase 2 | Modul B (Peta Stok + drill) | in-scope (desain) |
| Fase 3 | Tab Alert (E) & WIP MRP (D) | out-of-scope (disebut saja) |

---

## 3. Konstanta scope (dari index.htm, dipertahankan)

```
Plant 1000 -> SLoc 1D00
Plant 2000 -> SLoc 2KCS, 2261, 2262, 22E2, 22E3, 229K
```
Filter mempersempit di dalam himpunan 7 lokasi ini (tidak melampaui).

---

## 4. Layout

```
┌───────────────────────────────────────────────────────────────┐
│ header-bar (judul + user dropdown)                            │
│ navbar: [Pelacakan → index.htm]  [Cockpit → index3.htm aktif] │
├───────────────────────────────────────────────────────────────┤
│ FILTER (GET, action="index3.htm"):                            │
│   Plant [Semua▾] · SLoc [☑7 lokasi] · Rentang [Hari ini▾]     │
│   [custom: dari/sampai] · ⟳ Auto-refresh [▢ 60s] · [Terapkan] │
├───────────────────────────────────────────────────────────────┤
│ (A) KPI ROW — 5 kartu                                         │
├──────────────────────────────┬────────────────────────────────┤
│ (C) LIVE MOVEMENT FEED  ~55%  │ (B) PETA STOK  ~45%            │
│                               │                                │
└──────────────────────────────┴────────────────────────────────┘
│ footer: Data per: <tanggal jam> WIB · User                    │
```
Responsif: dua kolom → menumpuk (`flex-wrap`) di layar sempit.

---

## 5. Filter bar

| Field | Nama form | Nilai | Default |
|---|---|---|---|
| Plant | `f_plant` | '' / '1000' / '2000' | '' (semua) |
| SLoc | `f_lgort` (checkbox multi) | subset 7 lokasi | semua tercentang |
| Rentang | `f_range` | 'today' / '7' / '30' / 'custom' | 'today' |
| Dari/Sampai | `f_from` / `f_to` | tanggal (YYYYMMDD) | — (aktif jika 'custom') |
| Auto-refresh | `f_ar` (JS) | detik (0=off, 30/60/120) | off |

- ABAP menerjemahkan `f_range` → `lv_from`..`lv_to` (rentang `budat`).
- SLoc terpilih → build `lr_lgort` (range) untuk WHERE.
- Rentang tanggal **hanya** memengaruhi Modul C & KPI "gerakan"; Modul B & KPI stok
  memakai posisi **saat ini**.
- ⚠️ `action="index3.htm"` eksplisit (hindari form-action bug — lihat catatan repo).

---

## 6. Modul A — Header KPI Aktual (5 kartu)

| Kartu | Metrik | Sumber & query (scope = plant+SLoc) | Catatan |
|---|---|---|---|
| **Posisi Stok Aktif** | jml baris stok qty>0 (hero) + Σ qty unrestricted | MARD (LABST/INSME/SPEME/UMLME) + MSKA (KALAB/KAINS/KASPE) | Σ qty lintas material = **indikatif** (unit campur); count baris lebih akurat |
| **Gerakan (rentang)** | jml dokumen (distinct MBLNR) + jml baris | MSEG WHERE budat∈[from..to] AND werks/lgort∈scope | inti "aktual" |
| **Order per Tahap** | mini PMB / PRD / FIN (count) | AFPO⨝AFKO, `wemng<psmng` (WIP), map dispo→tahap | status presisi (JEST TECO/DLV) = enhancement |
| **⚠ Mau Kadaluarsa** | jml batch VFDAT ≤ 30 hari yang ada stok | MCH1 (VFDAT) ⨝ MCHB (CLABS>0) scope | warna status warning |
| **⛔ Blocked** | jml baris + Σ SPEME/KASPE | MARD SPEME>0 / MSKA KASPE>0 | warna status critical |

Bentuk: KPI row (reuse pola `.so-kpi`/tile dari index2), hero number ≥ 40px,
kartu alert (Expiry/Blocked) memakai palet status (warning `#fab219`,
critical `#d03b3b`) + ikon.

---

## 7. Modul C — Live Movement Feed

Tabel pergerakan MSEG+MKPF dalam rentang & scope, **terbaru dulu**.

- **Query:** `MSEG` WHERE `budat`∈[from..to] AND `werks`/`lgort`∈scope; join `MKPF`
  (budat/cputm/usnam) FOR ALL ENTRIES; `SORT BY cpudt DESC cputm DESC`;
  **LIMIT ~200 baris** (UP TO 200 ROWS) untuk jaga performa.
- **Kolom:** Waktu · Jenis (badge `bwart` — reuse pemetaan label/warna yang sudah
  ada di tab Riwayat) · Material (+maktx) · Batch · Dari→Ke (werks/lgort, pakai
  SHKZG H/S) · Qty+unit · User.
- **Filter cepat client-side** (tanpa reload): cari material + dropdown bwart —
  reuse `pelHistFilter()` yang sudah ada.
- **Auto-refresh:** toggle → `setInterval(()=>location.reload(), N*1000)` atau
  `<meta http-equiv="refresh">`. Off secara default.

---

## 8. Modul B — Peta Stok (matriks SLoc × status) — Fase 2

- **Bentuk:** baris = SLoc dalam scope; kolom = **Unrestricted / QI / Blocked /
  In-transit**; sel = Σ qty (heatmap intensitas + palet status). Baris "Total".
- **Query:** agregasi per (werks,lgort) dari **MARD** (free: LABST/INSME/SPEME/UMLME)
  **+ MSKA** (SO-stock: KALAB/KAINS/KASPE) — dua jenis stok berbeda, tidak dobel.
- **Drill:** klik sel → daftar material+batch di SLoc+status itu (MCHB/MSKA level
  batch). Render server-side saat load (semua sel sudah ada), show/hide via JS.

---

## 9. Data flow & performa (S/4HANA 1809)

- **Aktual = server-render tiap request.** Auto-refresh = reload ringan (tanpa
  websocket).
- `MSEG`/`MKPF` di S/4 1809 = **compatibility view atas `MATDOC`**. Query WAJIB
  berfilter `budat` + `werks/lgort` dan dibatasi barisnya. Untuk agregasi berat,
  opsi optimasi: **CDS custom `ZCS_*`** atau CDS rilis `I_MaterialDocumentItem` /
  `I_MaterialStock`.
- Stok (`MARD`/`MSKA`/`MCHB`) dibaca per request → nilai saat ini.
- Agregasi di ABAP; **tanpa library chart** (HTML/CSS/SVG), reuse `zcl_cs_util`
  (fmt_date, css_pct, badge) + kelas `.num-fmt` (format id-ID via JS).
- **Idealnya** query berat ditaruh di **method class** (`ZCL_CS_COCKPIT` /
  `ZCL_CS_UTIL`) — sekaligus langkah refaktor (lihat REKOMENDASI-REFAKTOR-INDEX.md).

---

## 10. Catatan deployment SE80 BSP

- Semua self-reference (form action, link, `userLogout`) → `index3.htm`.
- Tidak butuh STORE_KEY (form Transfer Posting dibuang di cockpit).
- Navbar: tambah entri "Cockpit" (aktif) + "Pelacakan" (→ index.htm) agar bisa
  pindah. index.htm/index2 tidak diubah oleh pekerjaan ini.
- Teks unit campur (KPI Σ qty) diberi tooltip "indikatif, lintas material".

---

## 11. Asumsi & pertanyaan terbuka

1. **"Order aktif"** diproksikan `wemng<psmng`. Kalau butuh presisi (kecualikan
   TECO/DLV), perlu join status order (JEST/`I_ManufacturingOrder`) — enhancement.
2. **KPI Σ qty** lintas material beda unit = indikatif; metrik utama pakai *count*.
3. **In-transit** (UMLME/UMLMC) ditampilkan di Peta Stok; sumber MARD.
4. **Autorisasi/scope user** (mis. admin hanya boleh plant tertentu) belum
   didefinisikan — asumsi semua admin lihat 7 lokasi.
5. Batas 200 baris feed = angka awal; bisa disetel.

---

## 12. Bertahap (untuk rencana implementasi)

1. **MVP:** shell cockpit + filter + Modul A + Modul C.
2. **Fase 2:** Modul B (matriks + drill).
3. **Fase 3:** tab Alert (E) & WIP MRP (D).
