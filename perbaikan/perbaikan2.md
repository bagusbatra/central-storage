# Perbaikan #2 — Summary Cards: tiga kartu diganti

**Target file**: UI fragment `cs2_body.htm`, `cs2_css_base.htm`, `cs2_js_kpi.htm`; endpoint `dash_prod.htm` + fragment `dp_*.htm`
**Environment**: BSP SE80 SAP S/4HANA 1.8.0.9, self-contained (**tanpa** include, class Z terpisah, MIME object, atau CDN eksternal)
**Ruang lingkup**: section `summary-cards` saja. Kartu **BUYER** dan **SALES ORDER** tidak disentuh. Panel/section lain tidak disentuh.
**Status**: FINAL — seluruh butir 1, 2, 3 sudah disepakati. Dokumen siap dipakai sebagai acuan implementasi.

---

## Konteks singkat (agar Claude Code paham tanpa membaca ulang percakapan)

- Sejak refactor 2026-08-03, `index2.htm` hanya RANGKA. Isi tersebar di fragment:
  - `cs2_body.htm` — markup seluruh halaman (termasuk `summary-cards`)
  - `cs2_css_base.htm` — CSS kartu & grid `summary-cards`
  - `cs2_js_kpi.htm` — pengambilan angka + tooltip, `loadKpi()` (satu-satunya pemanggil endpoint)
  - `dash_prod.htm` + `dp_*.htm` — endpoint JSON (`part=stock | ops | hist | komp`)
- **Lokasi markup kartu**: `cs2_body.htm:30-59`. Grid 5 kolom: `cs2_css_base.htm:123` (`repeat(5, 1fr)`).
- **Lokasi JS**: `cs2_js_kpi.htm` — handler `part=stock` (baris 204-291) & handler `part=ops` (baris 296-325).
- **Sumber data tiga kartu yang diganti saat ini**:
  - **OPERASI SELESAI** ← `part=ops` (`dp_ops.htm`): rantai AFKO→AFVC→AFVV→AFRU, hitung `conf/total/pct/act/queue/ord/trunc`. Berat; dibatasi `lc_maxord`.
  - **DI PRODUKSI** ← `part=stock` (`dp_stock.htm`): `lv_prod` = komponen dengan `moved=abap_true` (stok di luar 2KCS). Field JSON: `prod`.
  - **SELESAI PROD.** ← `part=stock`: `lv_done_real` = AFPO `WEMNG≥PSMNG` DAN lepas dari 8 SLoc. Field JSON: `done_real` (field lama `done` masih dikirim untuk pembanding).
- **Data jadwal yang sudah ada di sistem**: `AFKO-GSTRP` (Bas. start date) dipakai `part=komp` (`dp_komp.htm` → `lt_kord`) dan `dd` dihitung `sy-datum - gstrp` di `dp_komp_out.htm:73` (`dd>0` = terlambat mulai). Di cakupan dashboard **utuh** data ini BELUM dihitung — hanya tersedia saat discope ke satu SO.
- **Cakupan SLoc TERKINI (8, bukan 6)** — diperluas 2026-08-03:
  - IN: `2KCS`
  - Machining: antri `2261` → selesai `2262`
  - Banding: antri `22EK`/`22E2` → selesai `22E3`
  - Sanding: antri `229K` → selesai `2292`
  - Sumber: `dash_prod.htm:174-177`.
- **Constraint mutlak**: tidak boleh menambah file baru. Semua perubahan inline di fragment yang sudah ada. Filter sample customer `2000000004` wajib. Satu "komponen" = `VBELN+POSNR+MATNR` unik.

---

## Peta kartu sekarang → target

| Posisi | Sekarang | Menjadi | Sumber data baru |
|---|---|---|---|
| 1 | BUYER | **tetap** | — |
| 2 | SALES ORDER | **tetap** | — |
| 3 | OPERASI SELESAI | **MULAI MINGGU INI** | diskusi (lihat bagian 1) |
| 4 | DI PRODUKSI | **TERLAMBAT MULAI** | GSTRP vs posisi stok (bagian 2) |
| 5 | SELESAI PROD. | **SIAP LANJUT** | mcd+bdd+sdd (usulan, bagian 3) |

Grid tetap `repeat(5, 1fr)` — jumlah kartu tidak berubah.

---

## 1. Kartu OPERASI SELESAI → MULAI MINGGU INI

### Kondisi sekarang
- Markup `cs2_body.htm:43-47` (kartu ke-3): nilai persen `#kpi-conf`, sub-teks `#kpi-conf-sub`, ikon peringatan `#kpi-conf-warn`, tooltip ber-id `#tip-conf`.
- Data `part=ops` dari `dp_ops.htm`. Seluruh rantai operasi ini **tidak dipakai lagi** oleh kartu ini setelah diganti.
- JS `cs2_js_kpi.htm:296-325`: handler `part=ops` (isi `kpi-conf`, `kpi-conf-sub`, show/hide `trunc`).

### Definisi yang diusulkan
Jumlah komponen yang **mulai dikerjakan dalam minggu berjalan** (Senin–Minggu).

### Pilihan sumber data — ✅ **DIPUTUSKAN: Opsi A (GSTRP / jadwal)**
Pertanyaan awal: "mulai" diukur dari **jadwal** atau dari **kenyataan di lantai**? → **Jadwal (Opsi A)**.

**Opsi A — GSTRP (Bas. start date) jatuh minggu ini ✔ TERPILIH**
- Komponen yang `GSTRP` order pertama/paling awalnya berada di rentang minggu berjalan.
- Konsisten dengan bahasa "Bas. start date" yang sudah dipakai tabel Detail Komponen.
- Implementasi paling murah: satu SELECT AFPO+AFKO di `part=stock` (pola sama seperti `lt_afpo_done` / `lt_kord`), lalu ambil `MIN(GSTRP)` per komponen.
- Makna: "komponen yang **terjadwal mulai** minggu ini".

~~Opsi B — MSEG gerakan keluar 2KCS minggu ini~~ (tidak dipilih)
- ~~Komponen yang gerakan pertamanya keluar dari `2KCS` (atau masuk SLoc proses pertama) terjadi dalam 7 hari terakhir.~~
- ~~Menjawab "benar-benar mulai dikerjakan", bukan jadwal.~~
- ~~Lebih berat: scan MSEG + perlu tanggal gerakan per komponen (query tambahan di `part=hist` yang sudah ada bisa diperluas).~~

**Butir diskusi tersisa (belum diputuskan):**
1. ✅ **Sumber data**: Opsi A (GSTRP/jadwal) — **DIPUTUSKAN**
2. ✅ **Basis hitungan**: **komponen** (VBELN+POSNR+MATNR unik, dihitung sekali walau punya banyak order) — **DIPUTUSKAN**
3. ✅ **Definisi "awal minggu"**: **Senin 00:00 s.d. Minggu 24:00** (minggu kalender) — **DIPUTUSKAN**
4. ✅ **Sub-teks**: `N komponen terjadwal minggu ini` — **DIPUTUSKAN**

### Definisi final (semua butir sudah disepakati)
> **MULAI MINGGU INI** = jumlah **komponen unik** (SO + Item + Material) yang **base start date (`AFKO-GSTRP`) order paling awalnya** jatuh dalam **minggu kalender berjalan (Senin 00:00 – Minggu 24:00)**. Menjawab: *"komponen mana yang terjadwal mulai minggu ini."*

**Cara menghitung di `part=stock` (`dp_stock.htm`)** — pola menyalin `lt_afpo_done` (baris 260-313):
1. Dari `lt_soit` (sudah ada) bangun range `lr_dvbeln`.
2. SELECT `AFPO` (kdauf, kdpos, matnr) JOIN `AFKO` (gstrp, dispo) → `WHERE a~kdauf IN lr_dvbeln AND a~pwerk = lc_werks AND k~dispo IN ('GA1','GA2','EB2') AND k~gstrp IS NOT INITIAL`.
3. Per komponen (`kdauf kdpos matnr`) ambil **`MIN(gstrp)`** = tanggal mulai terawal.
4. Hitung minggu berjalan: **Senin** = `sy-datum - ( ( sy-datum+6 ) MOD 7 )` (modulo hari kerja, Senin=1), **Minggu** = Senin + 6. Filter `MIN(gstrp) >= senin AND MIN(gstrp) <= senin + 6`.
5. Komponen tanpa GSTRP diabaikan; yang `moved=true` **tetap dihitung** (kartu ini berbasis jadwal, bukan posisi).
6. Ekspos field JSON `week_start`.

### Perubahan teknis (berdasarkan Opsi A)
- **Markup** `cs2_body.htm:41-47`: ganti kartu OPERASI SELESAI → MULAI MINGGU INI. Hapus `#kpi-conf-warn`, `#tip-conf`, elemen `<span class="unit">%</span>`. Nilai kartu jadi angka bulat, bukan persen.
- **JS** `cs2_js_kpi.htm:296-325`: hapus seluruh handler `part=ops` (atau setel `#kpi-minggu` dari field baru di `part=stock`). Endpoint `part=ops` dibiarkan utuh (lihat "Yang TIDAK boleh berubah") sampai diputuskan.
- **Endpoint** `dp_stock.htm`: tambah blok hitung `week_start` (SELECT AFPO+AFKO, `MIN(GSTRP)` per komponen, filter Senin–Minggu). Ekspos field `week_start` di JSON `part=stock` (`dp_stock_so.htm` blok `lv_json`).
- **CSS**: tidak perlu (grid tetap 5 kolom; hapus class `color-green` pada kartu ini kalau nilai bukan lagi persen).

### Checklist
- [ ] Label kartu `MULAI MINGGU INI` + tooltip baru (definisi: MIN(GSTRP) per komponen jatuh minggu berjalan)
- [ ] Blok ABAP hitung `week_start` di `dp_stock.htm` (SELECT AFPO+AFKO, `MIN(GSTRP)`, filter Senin–Minggu)
- [ ] Field JSON `week_start` di `dp_stock_so.htm`
- [ ] JS pakai field baru (handler `part=ops` dihapus/dipindah)
- [ ] Sub-teks: `N komponen terjadwal minggu ini`
- [ ] Verifikasi dengan data nyata

---

## 2. Kartu DI PRODUKSI → TERLAMBAT MULAI

### Kondisi sekarang
- Markup `cs2_body.htm:48-53` (kartu ke-4): `#kpi-prod`, sub-teks 2 baris `#kpi-prod-sub` (`dari N komp (P%)`) dan `#kpi-prod-sub2` (`MC: A · EB: B`).
- Data `part=stock` dari `dp_stock.htm:195-207` (`lv_prod` dari `moved`). Field JSON: `prod`.

### Definisi final (semua butir sudah disepakati)
> **TERLAMBAT MULAI** = jumlah **komponen unik** (SO + Item + Material) yang **base start date (`AFKO-GSTRP`) sudah lewat dari hari ini** (`GSTRP < sy-datum`) **TAPI belum mulai dikerjakan** — seluruh stoknya masih di `2KCS` (`moved=abap_false`, belum keluar storage, belum ada konfirmasi operasi). Komponen **tanpa GSTRP diabaikan**.

- `GSTRP` = `AFKO-GSTRP` (Bas. start date), acuan **mulai**, bukan selesai (sama seperti tabel Detail Komponen).
- "Terlambat mulai" ≠ "terlambat selesai". Ini menjawab pertanyaan operasional: *"barang apa yang seharusnya sudah mulai tapi masih menganggur di 2KCS?"*
- **Batas terlambat**: `GSTRP < hari ini` (tanpa ambang hari tambahan).

### Sumber data & cara menghitung
Data belum tersedia di cakupan dashboard utuh. Perlu satu SELECT baru di `part=stock` (`dp_stock.htm`), pola **menyalin `lt_afpo_done`** (baris 260-313):
1. Dari `lt_soit` (sudah ada) bangun range `lr_dvbeln`.
2. SELECT `AFPO` (kdauf, kdpos, matnr) JOIN `AFKO` (gstrp, dispo) → `WHERE a~kdauf IN lr_dvbeln AND a~pwerk = lc_werks AND k~dispo IN ('GA1','GA2','EB2') AND k~gstrp < sy-datum AND k~gstrp IS NOT INITIAL`.
3. Deduplikasi per komponen (`kdauf kdpos matnr`), ambil `MIN(gstrp)` per komponen.
4. Silangkan dengan `lt_kmp` (`moved=abap_false` = masih di 2KCS). Yang `moved=true` **tidak** dihitung — sudah mulai, tidak terlambat.
5. Hitung **distribusi keterlambatan** (`dd = sy-datum - MIN(gstrp)`):
   - `late13` = `1 ≤ dd ≤ 3`
   - `late47` = `4 ≤ dd ≤ 7`
   - `late7`  = `dd > 7`
6. Ekspos field JSON `late` (jumlah total) + `late13`, `late47`, `late7` (breakdown sub-teks).

### Perubahan
- **Markup** `cs2_body.htm:48-53`: ganti kartu DI PRODUKSI → TERLAMBAT MULAI. Warna `color-blue` → `color-red`/`color-amber` (kartu peringatan). Sub-teks baris 2 jadi breakdown telat.
- **JS** `cs2_js_kpi.htm:226-232`: ganti isi `#kpi-prod` → `d.late`; sub-teks baris 1 & 2 sesuai definisi final.
- **Endpoint** `dp_stock.htm`: tambah blok hitung `late` + `late13/late47/late7`; `dp_stock_so.htm`: tambah field JSON.

### Butir diskusi (semua sudah disepakati)
1. ✅ **Batas "terlambat"**: `GSTRP < hari ini` saja — **DIPUTUSKAN**
2. ✅ **Sub-teks**: breakdown `telat 1-3 · 4-7 · >7 hari` — **DIPUTUSKAN**
3. ✅ **Komponen tanpa `GSTRP`**: diabaikan — **DIPUTUSKAN**

### Checklist
- [ ] Label kartu `TERLAMBAT MULAI` + tooltip baru
- [ ] Blok ABAP `late` + `late13/late47/late7` ditambahkan di `dp_stock.htm` (pola `lt_afpo_done`)
- [ ] Field JSON `late`, `late13`, `late47`, `late7` di `dp_stock_so.htm`
- [ ] JS pakai `d.late` + breakdown sub-teks
- [ ] Warna kartu diganti menjadi warna peringatan
- [ ] Verifikasi: bandingkan manual dengan tabel Detail Komponen (kolom JADWAL) pada SO yang masih di 2KCS

---

## 3. Kartu SELESAI PROD. → SIAP LANJUT

### Kondisi sekarang
- Markup `cs2_body.htm:54-58` (kartu ke-5): `#kpi-done`, sub-teks `#kpi-done-sub`.
- Data `part=stock`: `lv_done_real` (`dp_stock.htm:232-313`), field JSON `done_real`. Field lama `done` masih dikirim untuk pembanding.

### Definisi final (semua butir sudah disepakati)
> **SIAP LANJUT** = jumlah **komponen unik** (SO + Item + Material) yang stoknya kini berada di **salah satu SLoc "selesai" tahap** (`2262` / `22E3` / `2292`) — pekerjaan tahap itu sudah beres dan barang **tinggal menunggu dipindah** ke proses berikutnya. Barang di `2292` (selesai Sanding, siap OUT) **ikut dihitung**.

| Tahap selesai | SLoc | Proses berikutnya |
|---|---|---|
| Machining selesai | `2262` | → Banding |
| Banding selesai | `22E3` | → Sanding |
| Sanding selesai | `2292` | → OUT / Storage |

- **Cukup posisi stok** — tidak perlu cek qty order (AFPO). Begitu stoknya sudah di SLoc selesai, tahapnya dianggap beres.
- **Deduplikasi per komponen unik**: satu komponen yang stoknya terpecah di dua/lebih SLoc selesai **dihitung sekali**. Nilai utama kartu = jumlah komponen unik; **breakdown per tahap tetap memakai `mcd/bdd/sdd` mentah** (bisa memuat angka ganda — itu wajar, keduanya menjawab pertanyaan berbeda).

### Keuntungan besar: datanya SUDAH ADA
Tiga angka ini sudah dihitung `part=stock` untuk Lintasan Produksi:
- `mcd` (komponen di 2262) — `dp_stock.htm:199`
- `bdd` (komponen di 22E3) — `dp_stock.htm:201`
- `sdd` (komponen di 2292) — `dp_stock.htm:203`

**Rumus final**:
- `siap` = jumlah komponen unik dengan `(s_262 OR s_e3 OR s_292)` = `abap_true` → **dihitung dari `lt_kmp` di `dp_stock.htm`** (loop, pakai bendera yang sudah ada, counter +1 saat bendera gabungan pertama terpenuhi per komponen).
- Sub-teks breakdown: `MC: mcd · Banding: bdd · Sanding: sdd`.

**Catatan**: `mcd + bdd + sdd` bisa lebih besar dari `siap` karena komponen terpecah dihitung ganda di breakdown. Nilai kartu utama pakai `siap` (dedup), bukan penjumlahan.

### Butir diskusi (semua sudah disepakati)
1. ✅ **Definisi "siap"**: cukup dari **posisi stok** (`mcd+bdd+sdd`), tanpa syarat qty order — **DIPUTUSKAN**
2. ✅ **Barang selesai Sanding (`2292`, siap OUT)**: **termasuk** — **DIPUTUSKAN**
3. ✅ **Deduplikasi lintas SLoc**: **per komponen unik** (hitung sekali walau stok terpecah) — **DIPUTUSKAN**
4. ✅ **Sub-teks**: breakdown per tahap `MC: A · Banding: B · Sanding: C` — **DIPUTUSKAN**
5. ✅ **Nasib `done_real`**: **tetap dikirim** sebagai pembanding; dipakai di tempat lain (`out` di Lintasan Produksi) → **jangan dihapus** — **DIPUTUSKAN**

### Perubahan
- **Markup** `cs2_body.htm:54-58`: ganti kartu SELESAI PROD. → SIAP LANJUT.
- **Endpoint** `dp_stock.htm`: hitung `siap` dari loop `lt_kmp` (`s_262 OR s_e3 OR s_292`); `dp_stock_so.htm`: tambah field `siap` ke JSON. `done_real` TETAP dikirim.
- **JS** `cs2_js_kpi.htm:238-244`: ganti `#kpi-done` → `d.siap`; sub-teks `MC: A · Banding: B · Sanding: C` memakai `d.mcd/d.bdd/d.sdd`.

### Checklist
- [ ] Label kartu `SIAP LANJUT` + tooltip baru
- [ ] Hitung `siap` (komponen unik) dari `lt_kmp` di `dp_stock.htm`
- [ ] Field JSON `siap` ditambahkan di `dp_stock_so.htm`
- [ ] `done_real` TIDAK dihapus (masih dipakai `out` di Lintasan Produksi)
- [ ] JS pakai `d.siap` + sub-teks breakdown `MC/Banding/Sanding`
- [ ] Verifikasi: nilai kartu ≤ `mcd+bdd+sdd`; kalau tidak ada stok terpecah, keduanya sama

---

## Ringkasan file yang disentuh

| File | Bagian | Jenis perubahan |
|---|---|---|
| `cs2_body.htm` | Markup kartu ke-3, 4, 5 di `summary-cards` | Rewrite (label + tooltip + id elemen) |
| `cs2_css_base.htm` | (opsional) warna kartu TERLAMBAT MULAI | Ubah kecil |
| `cs2_js_kpi.htm` | Handler `part=stock` (baris 226-244) & `part=ops` (baris 296-325) | Update mapping field; hapus handler ops |
| `dp_stock.htm` | Blok hitung `late` (bagian 2) | Tambah 1 SELECT + hitung |
| `dp_stock_so.htm` | String JSON `lv_json` (baris 260-286) | Tambah field `week_start`/`late`/`siap` |
| `dp_ops.htm` | — | **Tidak diubah** (endpoint dipertahankan) |

## Yang **TIDAK** boleh berubah pada sesi ini

- Cakupan 8 SLoc (2KCS, 2261, 2262, 22EK, 22E2, 22E3, 229K, 2292)
- Filter sample customer `2000000004`
- Batas `lc_maxord = 1500`, `lc_maxso = 500`, `lc_maxkmp = 400`, `lc_maxkm2 = 2000`
- TTL cache 300 dtk & mekanisme SHARED BUFFER `indx(zc)` (ID `DPRODST`, `DPRODOP`, `DPRODHI`, `DPRODKP`, `DPRODSI`, `DPRODKM`)
- Struktur `part=stock | ops | hist | komp` — **endpoint `part=ops` tetap ada** walau kartunya diganti (tidak merusak, tidak membuang kode)
- Kartu BUYER & SALES ORDER
- Section FILTER BUYER, Lintasan Produksi (WIP per Center), daftar SO, tabel Detail Komponen
- Field JSON `prod`, `done`, `done_real`, `mcd`, `bdd`, `sdd`, `out` — semuanya masih dipakai komponen UI lain

## Verifikasi pasca-perubahan

1. Grid `summary-cards` tetap 5 kartu, tidak ada kartu tersisa dengan label lama (OPERASI SELESAI / DI PRODUKSI / SELESAI PROD.)
2. Kartu MULAI MINGGU INI menampilkan angka bulat (bukan persen), tidak ada lagi ikon ⚠ trunc
3. Kartu TERLAMBAT MULAI menampilkan angka yang konsisten dengan tabel Detail Komponen (kolom JADWAL berlabel "terlambat N hari" pada komponen yang masih di 2KCS)
4. Kartu SIAP LANJUT = `mcd + bdd + sdd` dari response `part=stock`; Lintasan Produksi (kotak center & OUT) tetap menampilkan angka yang sama seperti sebelum perubahan
5. Cache dibersihkan setidaknya sekali dengan `?fresh=1`
6. DevTools Network — tidak ada request ke domain luar (CDN)
7. Source view di SE80 — hanya file dalam daftar "Ringkasan file" yang berubah; `dp_ops.htm` dan `dash_prod.htm` (rangka) tidak berubah isi

## Agenda diskusi dengan user (butir yang memblokir implementasi)

| # | Kartu | Keputusan yang diminta |
|---|---|---|
| 1 | MULAI MINGGU INI | ✅ **SELESAI**: Opsi A (GSTRP/jadwal) + basis komponen + Senin–Minggu + sub-teks `N komponen terjadwal minggu ini` |
| 2 | TERLAMBAT MULAI | ✅ **SELESAI**: `GSTRP < hari ini` + sub-teks breakdown `telat 1-3 · 4-7 · >7 hari` + tanpa GSTRP diabaikan |
| 3 | SIAP LANJUT | ✅ **SELESAI**: posisi stok cukup (tanpa syarat qty) + termasuk 2292 + per komponen unik + sub-teks breakdown per tahap; `done_real` tetap dikirim |

> Seluruh butir sudah final. Dokumen siap sebagai acuan implementasi.
