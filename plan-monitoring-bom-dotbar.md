# Planning — Dot-bar Perjalanan Sloc di `monitoring_bom.htm` (tab Item & BOM)

> Mengganti **progress bar % pada baris KOMPONEN (RESB)** di tab Item & BOM dengan
> **dot-bar 4 titik** yang melacak perjalanan fisik material melewati sloc-sloc Plant 2000:
> `1D00 → 2KCS → 2261 → 2262 → 22F2 → 22F3 → 229K`.
> Status dokumen: **DRAFT / PLAN — untuk didiskusikan**. Disusun setelah tanya-jawab (lihat §1).

---

## 0. Koordinasi antar-plan (baca sebelum implementasi)

> Plan ini berjalan berdampingan dengan **`plan-monitoring-detail-butuh-dikirim.md`** (tab "Butuh Dikirim").
> Keduanya **aman dikembangkan bersamaan**, tetapi menyentuh file yang sama & berbagi konsep pipeline
> `1D00 → 2KCS → 2261 → 2262 → 22F2 → 22F3 → 229K`. Titik yang **wajib dikoordinasikan**:

| # | Titik singgung | Aturan koordinasi |
|---|----------------|-------------------|
| 1 | **`monitoring_bom.htm` (file sama)** | Butuh Dikirim menambah cabang **`mode=kirim`**; dot-bar mengubah **path default (Item & BOM)**. Buat skeleton `IF lv_mode='kirim' … ELSE … ENDIF` dulu, dot-bar mengedit **di dalam `ELSE`**. |
| 2 | **CONSTANTS** | **Satu blok gabungan.** Hindari deklarasi ganda `lc_horizon` (dobel = gagal aktivasi). `lc_plant '2000'` yang sudah ada dipakai ulang. |
| 3 | **Definisi "sudah masuk 2KCS"** | **HARUS identik** di kedua fitur. Konsistensi kunci: material yang muncul di tab **Butuh Dikirim** = **titik-1 MERAH** di dot-bar (belum sampai 2KCS). Beda definisi → tampilan kontradiktif. |
| 4 | **Logika MSEG⨝MKPF net-reversal** | Pusatkan ke **`ZCL_CS_UTIL`** (dipakai kedua plan). Sekali tulis, hindari drift. |
| 5 | **Beban query** | Dot-bar menambah MSEG+MARD ke path default yang sudah berat; Butuh Dikirim lazy (request terpisah). Pertimbangkan cache INDX pola `transfer.htm` untuk path default. |
| 6 | **`reference.md` + cache-buster** | Gabung jadi **satu** pembaruan doc & satu kali bump versi (`js.js`/`style.css`/`monitoring.htm`). |

**Hubungan konseptual:** Butuh Dikirim = tahap *sebelum* 2KCS (titik-1 merah); dot-bar = perjalanan *setelah* 2KCS. Dua sisi dari pipeline yang sama.

---

## 1. Keputusan Requirement (hasil konfirmasi)

| # | Aspek | Keputusan |
|---|-------|-----------|
| Q1 | **Baris target** | **Baris komponen (RESB)** — kolom "Progres" di tabel komponen dalam (`cois-table`). Progres GR order lama diganti dot-bar. |
| Q2 | **Sumber data** | **Riwayat gerakan MSEG⨝MKPF** — akumulasi qty (net reversal `SHKZG`) yang PERNAH masuk tiap sloc. Bukan stok MARD saat ini. |
| Q3 | **Acuan "penuh" (100%)** | **Qty yang masuk 2KCS** (input pipeline). Tiap tahap HIJAU bila seluruh qty itu sudah lewat, KUNING bila baru sebagian. |
| Q4 | **SO 100%** | Semua material sampai 229K → **dot 4 hijau**. Ini keluaran alami dot-bar (bukan cabang terpisah) → "hanya menyesuaikan saja". |

**Ruang lingkup:** hanya path **Item & BOM default** (`monitoring_bom.htm?vbeln=…`, tanpa `mode`). Tidak menyentuh fallback BOM master (item tanpa order) — untuk item itu dot-bar tidak berlaku (tak ada komponen RESB). *→ konfirmasi §6-E.*

---

## 2. Pemetaan Sloc → 4 Titik (dot) — **PERLU KONFIRMASI**

Urutan pipeline (indeks tahap `s`): `s0=2KCS · s1=2261 · s2=2262 · s3=22F2 · s4=22F3 · s5=229K`.

| Posisi material (qty penuh) | % | Titik 1 | Titik 2 | Titik 3 | Titik 4 |
|---|---|---|---|---|---|
| Masih di 1D00 (belum masuk 2KCS) | — | 🔴 merah | ⚪ | ⚪ | ⚪ |
| 2KCS | 0 | 🟡 | ⚪ | ⚪ | ⚪ |
| 2261 | 20 | 🟢 | 🟡 | ⚪ | ⚪ |
| 2262 | 40 | 🟢 | 🟢 | ⚪ | ⚪ |
| 22F2 | 60 | 🟢 | 🟢 | 🟡 | ⚪ |
| 22F3 | 80 | 🟢 | 🟢 | 🟢 | ⚪ |
| 229K | 100 | 🟢 | 🟢 | 🟢 | 🟢 |

**Pasangan transisi tiap titik** (kuning = mulai / hijau = tuntas):
- Titik 1 — kuning saat **2KCS**, hijau saat **2261**.
- Titik 2 — kuning saat **2261**, hijau saat **2262**.
- Titik 3 — kuning saat **22F2**, hijau saat **22F3**.
- Titik 4 — hijau saat **229K** (tidak punya keadaan kuning eksplisit di aturan Anda → lihat keputusan §6-B).

> ⚠️ **Catat asimetri (sesuai aturan Anda):** saat material di **2262** (titik 2 hijau), **titik 3 tetap abu-abu** — baru kuning setelah **22F2**. Jadi ada 1 sloc "jeda" (2262→22F2) tanpa titik kuning berikutnya. Ini mengikuti aturan 6→7 apa adanya.

---

## 3. Model Perhitungan (inti — mohon divalidasi dengan 1 contoh nyata)

### 3.1 Data mentah per material komponen (dalam Plant 2000, horizon N hari)
Untuk tiap `matnr` komponen, hitung **qty net yang masuk** ke tiap sloc dari MSEG (baris penerimaan, net reversal via `SHKZG`):
```
q[2KCS], q[2261], q[2262], q[22F2], q[22F3], q[229K]
```
Plus (untuk titik-1 merah): apakah material **masih ada di 1D00** (MARD 1000/1D00 `labst>0`, atau qty masuk 2KCS = 0).

### 3.2 Qty "sudah mencapai tahap s atau lebih jauh" (kumulatif dari hilir)
Karena material mengalir berurutan, qty yang tercatat masuk sloc hilir pasti sudah melewati sloc hulu. Untuk tahan terhadap perpindahan lanjutan (aturan 1) dan reversal:
```
adv[229K] = q[229K]
adv[22F3] = q[22F3] + adv[229K]
adv[22F2] = q[22F2] + adv[22F3]
adv[2262] = q[2262] + adv[22F2]
adv[2261] = q[2261] + adv[2262]
adv[2KCS] = q[2KCS] + adv[2261]      " = total pernah masuk pipeline
```
`adv[s]` = total qty yang **pernah mencapai minimal sloc s**.

### 3.3 Acuan penuh
```
R = q[2KCS]          " Q3: qty masuk 2KCS = 100% (input pipeline)
```
> Alternatif bila `R` tak andal (mis. 2KCS di-bypass): `R = adv[2KCS]`. *→ konfirmasi §6-C.*

### 3.4 Status tiap tahap terhadap R
Untuk tiap sloc hilir `s` (2261..229K):
```
penuh(s)   := adv[s] >= R  (dan R>0)      " seluruh qty pipeline sudah lewat ≥ s
sebagian(s):= 0 < adv[s] < R              " baru sebagian
kosong(s)  := adv[s] = 0
```

### 3.5 Terjemahan ke 4 titik
Dengan `R>0` (material sudah masuk 2KCS):
| Titik | HIJAU bila | KUNING bila | ABU bila |
|-------|-----------|-------------|----------|
| 1 | `penuh(2261)` | selain itu (masih ada di 2KCS) | — (selalu ≥ kuning karena R>0) |
| 2 | `penuh(2262)` | `adv[2261] > 0` & belum penuh(2262) | `adv[2261] = 0` |
| 3 | `penuh(22F3)` | `adv[22F2] > 0` & belum penuh(22F3) | `adv[22F2] = 0` |
| 4 | `penuh(229K)` | `adv[229K] > 0` & belum penuh(229K) *(lihat §6-B)* | `adv[229K] = 0` |

Bila `R = 0` (belum pernah masuk 2KCS):
- Titik 1 = 🔴 **merah** bila masih ada stok di 1D00 (atau memang belum dikirim); titik 2–4 abu.
- Bila `R=0` & tak ada jejak 1D00 → semua abu (data tak diketahui). *→ konfirmasi §6-D.*

### 3.6 Contoh nyata (untuk validasi bersama)
Material X, horizon aktif. Gerakan net masuk: 2KCS=100, 2261=100, 2262=60, 22F2=0, 22F3=0, 229K=0.
```
R = 100
adv: 2261=160? -> TIDAK. adv[2261]=q2261+adv[2262]=100+60=160 ...
```
> ⚠️ **Isu model (penting untuk didiskusikan):** rumus kumulatif §3.2 **menjumlah** q antar-sloc, sehingga `adv[2261]` bisa **melebihi R** walau sebagian belum benar-benar sampai 2261. Untuk kasus "sebagian" (aturan 10) kita butuh definisi yang **tidak dobel-hitung**. Dua opsi:
> - **Opsi rumus A (arus keluar):** qty yang benar-benar sudah *melewati* sloc `s` = qty yang masuk sloc-sloc **setelah** `s`. Perlu pasangan "masuk vs keluar" tiap sloc (MSEG punya baris keluar `SHKZG='H'` & masuk `S`). Lebih akurat untuk parsial.
> - **Opsi rumus B (stok berjalan):** `reached_deepest` = sloc hilir terjauh dengan `q>0`; qty parsial diambil dari `q[sloc_terjauh]` vs R. Lebih sederhana, tapi kasar untuk aliran terpisah.
>
> **Rekomendasi:** setelah kita lihat struktur 1 dokumen 311 nyata (Fase 0), kunci salah satu. Plan default memakai **Opsi A** (paling jujur untuk aturan 10).

---

## 4. Perubahan Teknis

### 4.1 `monitoring_bom.htm` (path Item & BOM / `mode` kosong)
Konstanta baru:
```abap
CONSTANTS: lc_horizon TYPE i VALUE 90.
" Daftar sloc pipeline (urut) — pertimbangkan RANGE/konstanta terpisah:
"   2KCS, 2261, 2262, 22F2, 22F3, 229K   (semua werks 2000)
```
Tambahan langkah (setelah komponen RESB terkumpul, sebelum render):
1. Kumpulkan **distinct matnr** komponen RESB item SO ini.
2. `SELECT` MSEG⨝MKPF (pola sama transfer.htm langkah 5): `werks='2000'`, `lgort IN (6 sloc)`, `budat >= horizon`, ambil `matnr, lgort, menge, shkzg, budat`. Net reversal per (matnr,lgort).
3. (untuk merah) `SELECT` MARD 1000/1D00 `labst` per matnr komponen — atau reuse jejak "belum masuk 2KCS".
4. Hitung `q[]`, `adv[]`, `R`, lalu **4 kode warna titik** per matnr (method util diusulkan, §4.4).
5. Simpan hasil ke map per matnr → dipakai saat render baris komponen.

Render: ganti blok kolom "Progres" di `cois-table` (baris komponen, sekitar baris 570–578 file saat ini) dengan **dot-bar** (4 `<span class="dot dot-…">`). Simpan `title=` berisi sloc terkini + qty untuk tooltip.

> **Path fallback BOM master (item tanpa order)** tidak berubah (tak ada RESB). Kolom item-level (luar) juga **tidak** diubah (Q1 = komponen saja).

### 4.2 CSS (`style.css`)
Tambah komponen dot-bar:
```css
.dotbar{display:inline-flex;gap:6px;align-items:center}
.dot{width:12px;height:12px;border-radius:50%;background:#e5e7eb} /* abu default */
.dot-red{background:#ef4444}
.dot-yellow{background:#f59e0b}
.dot-green{background:#22c55e}
/* opsional: garis penghubung antar-dot, label % kecil */
```
Bump cache-buster `style.css?r=` di semua halaman pemuat (atau minimal `monitoring.htm`).

### 4.3 `js.js`
Tidak ada logika baru wajib (dot dirender server-side). Opsional: tooltip hover (title sudah cukup). Fragment tetap lewat `formatNumbers()`.

### 4.4 `ZCL_CS_UTIL` (disarankan)
Tambah method murni untuk memetakan angka → warna titik agar teruji & reusable:
```abap
" iv_q_2kcs..iv_q_229k, RETURNING warna 4 titik (mis. string 4-char 'GGYX')
methods dot_stages IMPORTING ... RETURNING VALUE(rv_dots) TYPE string.
```
Sekaligus tempat memusatkan urutan sloc & ambang. (Konsisten pola `prog_bar_class` dsb.)

---

## 5. Asumsi & Verifikasi Sistem (Fase 0 — WAJIB sebelum kunci logika)

| # | Cek | Transaksi | Yang dicatat | Konsekuensi |
|---|-----|-----------|--------------|-------------|
| V1 | **Movement type antar-sloc** 2KCS→2261→…→229K | MB51 (werks 2000, per sloc) | 311? 313/315? Z? | Set filter `bwart` untuk "masuk sloc". Beda → sesuaikan. |
| V2 | **Arah baris MSEG** masuk sloc | SE16 MSEG 1 dokumen | baris `lgort=tujuan` → `SHKZG`=`S`? | Kunci definisi "qty masuk sloc s". |
| V3 | **Masuk 2KCS** dari 1D00 | MB51 | tetap 301 (seperti transfer.htm)? | Sumber `R = q[2KCS]`. |
| V4 | **UoM konsisten** antar sloc & vs RESB | MMBE/MM03 | sama? | Beda → konversi base unit; jangan campur. |
| V5 | **Keterkaitan SO** | MSEG `aufnr` pada 311? | biasanya kosong | Menentukan §6-A (per-material vs per-SO). |
| V6 | **Horizon cukup** | — | material lama (>90 hr) masih relevan? | Sesuaikan `lc_horizon`. |

---

## 6. Keputusan Terbuka (mari kita bahas — belum dikunci)

- **A. Atribusi per-material vs per-SO.** Gerakan sloc (311) umumnya **tak** ber-`aufnr` → sulit memisah qty milik SO ini vs SO lain untuk material yang sama. **Usulan:** dot-bar mencerminkan perjalanan **material (matnr) secara agregat** di Plant 2000 (sama semangatnya dgn transfer.htm). Setuju? (Bila butuh per-SO, perlu sumber lain / asumsi tambahan.)
- **B. Titik 4 saat parsial.** Aturan Anda hanya menyebut titik 4 **hijau** (229K). Bila sebagian qty sudah di 229K tapi belum penuh → titik 4 **kuning** (ikut aturan 10) atau tetap **abu** sampai penuh? **Usulan:** kuning (konsisten aturan 10).
- **C. Acuan R.** `R = q[2KCS]` (input) vs `R = adv[2KCS]` (total pernah di pipeline). Bila ada retur/keluar dari 2KCS, mana yang jadi 100%? **Usulan:** `q[2KCS]` net.
- **D. Material belum masuk 2KCS & tak ada jejak 1D00.** Titik 1 merah hanya bila terbukti masih di 1D00? Atau merah untuk semua "belum masuk 2KCS"? **Usulan:** merah bila (belum masuk 2KCS) & (ada kebutuhan RESB atau stok 1D00); selain itu abu.
- **E. Item tanpa order (fallback BOM master).** Tak ada RESB → dot-bar tidak tampil (kolom kuantitas biasa). Setuju?
- **F. Rumus parsial A vs B (§3.6).** Pilih setelah Fase 0.
- **G. Hubungan dgn tab "Butuh Dikirim".** Rencana `plan-monitoring-detail-butuh-dikirim.md` masih berlaku terpisah? Atau dot-bar ini menggantikan sebagian niat itu? (Keduanya memakai sumber MSEG/sloc yang mirip → peluang berbagi util.)
- **H. Optimasi SO 100%.** Karena SO 100% = semua hijau, boleh **short-circuit**: bila seluruh item SO GR=target, render 4 hijau tanpa query MSEG (hemat). Terapkan? (menyelaraskan "SO 100% tanpa perubahan logic".)

---

## 7. Berkas yang Disentuh
| Berkas | Perubahan |
|--------|-----------|
| `Page with Flow Logic/monitoring_bom.htm` | Query MSEG⨝MKPF + MARD(1D00) untuk komponen; hitung dot; ganti render kolom Progres komponen → dot-bar. |
| `MIMEs/css/style.css` | Kelas `.dotbar/.dot/.dot-red/.dot-yellow/.dot-green`; bump `?r=`. |
| `ZCL_CS_UTIL` *(disarankan)* | Method `dot_stages(...)` + konstanta urutan sloc/ambang. |
| `reference.md` | Dokumentasikan model dot-bar + tabel sloc & matriks MSEG/MARD per halaman. |

---

## 8. Checklist Uji (setelah aktivasi)
- [ ] Baris komponen SO belum-100% menampilkan dot-bar 4 titik; SO 100% → 4 hijau.
- [ ] Titik & warna cocok dgn tabel §2 untuk beberapa material pada tiap tahap (2KCS/2261/2262/22F2/22F3/229K).
- [ ] Material yang **sudah melewati 229K** tetap tampil 4 hijau walau stok sloc sudah pindah (aturan 1 — berbasis histori MSEG).
- [ ] Kasus **parsial** (aturan 10): tahap belum lengkap tetap kuning; cocok dengan qty nyata (uji 1 material split).
- [ ] Material masih di 1D00 (belum 2KCS) → titik 1 merah.
- [ ] Reversal (302/pembatalan) mengurangi qty tahap terkait (net `SHKZG`).
- [ ] UoM per material benar; tak ada penjumlahan lintas satuan.
- [ ] Tak ada full-scan berat (ST05); tab Item & BOM tak melambat berarti.
- [ ] Cache-buster CSS naik; tooltip sloc/qty tampil.

---

## 9. Urutan Implementasi
1. **Fase 0** — verifikasi V1–V6 (movement type antar-sloc & arah `SHKZG` paling kritis).
2. Kunci keputusan §6 (A–H) bersama.
3. `ZCL_CS_UTIL=>dot_stages` + unit sanity (tabel §2).
4. `monitoring_bom.htm` — query MSEG/MARD + hitung + render dot-bar.
5. CSS dot-bar + cache-buster.
6. Uji (Checklist §8) & validasi angka vs MB51/MMBE.
7. `reference.md`.
