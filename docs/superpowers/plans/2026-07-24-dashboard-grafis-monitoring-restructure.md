# Dashboard Grafis + Migrasi Pelacakan ke Monitoring — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pindahkan konten pelacakan SO+Item dari `index3a.htm` ke `monitoring.htm`, lalu tulis ulang `index3a.htm` menjadi Dashboard Grafis (tabel agregat per buyer + panel realtime).

**Architecture:** Tiga file BSP. `monitoring.htm` menerima konten pelacakan lama (rujukan diri diarahkan ulang). `index3a.htm` di-rewrite: query agregasi MSEG⨝MKPF dalam rentang tanggal, di-group per buyer, plus panel realtime yang polling JSON. `dash_feed.htm` adalah endpoint JSON kecil untuk feed realtime.

**Tech Stack:** SAP BSP (ABAP page with flow logic), HTML/CSS inline, JavaScript vanilla (tanpa library eksternal). Tabel SAP: MSEG, MKPF, VBAK, VBAP, KNA1, MARD/MCHB.

## Global Constraints

- Tanpa library JS/CSS eksternal — semua inline (konsisten dengan halaman existing).
- Sample customer `KUNNR = 2000000004` SELALU dikecualikan di semua agregasi & feed.
- Lokasi yang dipantau (Plant/SLoc): Pembahanan `1000/1D00`; Central Storage `2000/2KCS`; Machining `2000/2261,2262`; Banding `2000/22E2,22E3`; Sanding `2000/229K`.
- Tanggal rentang berbasis `MKPF-BUDAT`. Default 30 hari (`sy-datum - 30` s/d `sy-datum`).
- "Masuk ke lokasi" = baris `MSEG` sisi terima `SHKZG='S'`. Nilai sel = COUNT DISTINCT `(KDAUF,KDPOS)`.
- Verifikasi = aktivasi di SAP tanpa error + cek tampilan di browser. Commit dilakukan user via VSCode (langkah commit di bawah opsional).
- Tidak menyentuh `pelacakan.htm`, `index.htm`, `index2.htm`, `index3.htm`.

---

### Task 1: Migrasi konten pelacakan ke `monitoring.htm`

Isi lama `monitoring.htm` sudah di-backup oleh user. Task ini menjadikan `monitoring.htm` sebagai halaman pelacakan SO+Item (pindahan dari `index3a.htm` versi sekarang), termasuk penyesuaian rujukan diri & navbar dua entri.

**Files:**
- Modify: `ZBSP_CS_APP/Page with Flow Logic/monitoring.htm` (ganti total isinya)
- Sumber: `ZBSP_CS_APP/Page with Flow Logic/index3a.htm` (versi saat ini — snapshot sebelum di-rewrite di Task 3)

**Interfaces:**
- Produces: halaman `monitoring.htm` fungsional dengan form input SO+Item yang `action="monitoring.htm"`.

- [ ] **Step 1: Snapshot isi index3a.htm saat ini**

Salin SELURUH isi `index3a.htm` (versi sekarang, halaman pelacakan) menjadi isi baru `monitoring.htm`. Ini titik awal; sisa langkah menyesuaikan rujukan diri.

- [ ] **Step 2: Arahkan ulang semua rujukan diri ke monitoring.htm**

Ganti di `monitoring.htm`:
- Semua `action="index3.htm"` → `action="monitoring.htm"` (form Transfer Posting `id="trs-form"` dan form filter SO+Item).
- Link Reset dan `userLogout()` yang menunjuk `index3.htm`/`index.htm` → `monitoring.htm`.
- Selector reset sessionStorage `a[href="index3.htm"]` → `a[href="monitoring.htm"]`.

Cari dengan: `grep -n "index3.htm\|index.htm" monitoring.htm` lalu ganti yang merupakan rujukan-diri (BUKAN link navigasi ke Dashboard, lihat Step 3).

- [ ] **Step 3: Set navbar dua entri (Dashboard + Monitoring)**

Ganti blok `<div class="navbar">` di `monitoring.htm` menjadi:

```html
  <div class="navbar">
    <a href="index3a.htm" class="nav-btn"><span class="nav-icon">&#128202;</span>Dashboard</a>
    <a href="monitoring.htm" class="nav-btn active"><span class="nav-icon">&#128269;</span>Monitoring</a>
  </div>
```

Sesuaikan `<title>` menjadi `Monitoring Material - Central Storage KMI 2` dan `<h1>` menjadi `Central Storage Monitoring`.

- [ ] **Step 4: Aktivasi & verifikasi di browser**

Aktifkan `monitoring.htm` di SAP (SE80 / transaksi BSP app). Buka di browser:
- Halaman tampil tanpa error aktivasi.
- Masukkan SO+Item yang valid → tab Info Order/Pembahanan/Produksi/Stok/Riwayat tampil seperti dulu di index3a.
- Submit/preview form Transfer Posting → URL tetap di `monitoring.htm` (bukan lompat ke index3.htm).
- Klik navbar "Dashboard" → menuju `index3a.htm`.

Expected: semua fungsi pelacakan bekerja identik dengan index3a lama, tanpa nyasar ke halaman lain.

- [ ] **Step 5: Commit (opsional — atau user via VSCode)**

```bash
git add "ZBSP_CS_APP/Page with Flow Logic/monitoring.htm"
git commit -m "feat: migrate SO+Item tracking content into monitoring.htm"
```

---

### Task 2: Endpoint JSON `dash_feed.htm`

Halaman BSP kecil yang mengembalikan N pergerakan barang terakhir sebagai JSON, untuk di-poll oleh dashboard.

**Files:**
- Create: `ZBSP_CS_APP/Page with Flow Logic/dash_feed.htm`

**Interfaces:**
- Produces: HTTP response `application/json`, array objek:
  `{ "waktu":"HH:MM", "matnr":"...", "maktx":"...", "from":"1000/1D00", "to":"2000/2KCS", "qty":"12 PC", "buyer":"...", "gerakan":"In Plant" }`
- Consumes (JS): dipanggil `fetch('dash_feed.htm')` oleh Task 4.

- [ ] **Step 1: Buat halaman dengan query pergerakan terakhir**

Buat `dash_feed.htm`. Di blok flow logic ABAP, ambil ~30 pergerakan terbaru pada SLoc yang dipantau, exclude sample customer:

```abap
<%@ page language="abap" %><%
DATA: lv_from TYPE mkpf-budat.
lv_from = sy-datum - 7.   " feed cukup 7 hari terakhir agar ringan

TYPES: BEGIN OF ty_feed,
         mblnr TYPE mseg-mblnr, mjahr TYPE mseg-mjahr, zeile TYPE mseg-zeile,
         budat TYPE mkpf-budat, cputm TYPE mkpf-cputm,
         bwart TYPE mseg-bwart, shkzg TYPE mseg-shkzg,
         matnr TYPE mseg-matnr, werks TYPE mseg-werks, lgort TYPE mseg-lgort,
         menge TYPE mseg-menge, meins TYPE mseg-meins,
         kdauf TYPE mseg-kdauf, kdpos TYPE mseg-kdpos,
       END OF ty_feed.
DATA: lt_feed TYPE TABLE OF ty_feed, ls_feed TYPE ty_feed.

SELECT m~mblnr m~mjahr m~zeile h~budat h~cputm m~bwart m~shkzg
       m~matnr m~werks m~lgort m~menge m~meins m~kdauf m~kdpos
  FROM mseg AS m INNER JOIN mkpf AS h ON m~mblnr = h~mblnr AND m~mjahr = h~mjahr
  INTO CORRESPONDING FIELDS OF TABLE lt_feed
  WHERE h~budat >= lv_from
    AND ( ( m~werks = '1000' AND m~lgort = '1D00' )
       OR ( m~werks = '2000' AND m~lgort IN ( '2KCS','2261','2262','22E2','22E3','229K' ) ) ).
SORT lt_feed BY budat DESCENDING cputm DESCENDING mblnr DESCENDING zeile DESCENDING.
%>
```

- [ ] **Step 2: Resolusi buyer + label gerakan + exclude sample customer**

Setelah SELECT, kumpulkan `kdauf` unik → `VBAK` → `KNA1-NAME1`; buang baris dengan `kunnr = '2000000004'`. Peta label bwart REUSE dari CASE existing di index3a (301=Cross Plant, 311=In Plant, 261=GI to Order, dst). Batasi hasil akhir 30 baris pertama.

```abap
<% DATA lv_cnt TYPE i.
   LOOP AT lt_feed INTO ls_feed.
     lv_cnt = lv_cnt + 1.
     IF lv_cnt > 30. EXIT. ENDIF.
     " resolve buyer via lookup table lt_buyer (dibangun dr VBAK/KNA1); skip jika sample
%>
```

(Bangun `lt_buyer` = internal table `kdauf → name1/kunnr` via SELECT batched `FOR ALL ENTRIES` seperti pola existing; `CHECK` buyer bukan sample.)

- [ ] **Step 3: Set content-type JSON & tulis array**

Set response ke JSON lalu tulis array di layout. Di BSP:

```abap
<% response->set_header_field( name = 'Content-Type' value = 'application/json; charset=utf-8' ). %>
```

Lalu tulis JSON manual (escape `"` pada teks) dengan loop, hasil akhir berupa `[ {...}, {...} ]`. Gunakan `cl_http_utility` / manual replace untuk escape bila perlu.

⚠️ Asumsi: `response->set_header_field` tersedia di konteks page ini. Bila aktivasi/runtime menolak, alternatif: set via `runtime->server->response->set_content_type( 'application/json' )`. Konfirmasi saat aktivasi.

- [ ] **Step 4: Aktivasi & verifikasi**

Buka `dash_feed.htm` langsung di browser.
Expected: keluar teks JSON valid (array objek), bukan HTML. Tempel ke validator JSON / cek `JSON.parse` di console. Pastikan tidak ada baris buyer sample (2000000004).

- [ ] **Step 5: Commit (opsional)**

```bash
git add "ZBSP_CS_APP/Page with Flow Logic/dash_feed.htm"
git commit -m "feat: add dash_feed.htm JSON endpoint for realtime movement feed"
```

---

### Task 3: Rewrite `index3a.htm` — data layer + render statis dashboard

Ganti isi `index3a.htm` (pelacakan) dengan Dashboard Grafis: filter tanggal, query agregasi per buyer, KPI bar ringkas, tabel per buyer, navbar dua entri. Panel realtime ditambahkan di Task 4.

**Files:**
- Modify: `ZBSP_CS_APP/Page with Flow Logic/index3a.htm` (ganti total)

**Interfaces:**
- Consumes: form field `date_from`, `date_to` (format `YYYYMMDD`).
- Produces: elemen DOM `<tbody id="buyer-rows">` (tabel per buyer) dan container `<div id="feed-list">` (diisi Task 4).

- [ ] **Step 1: Header, filter tanggal, konstanta**

Tulis blok ABAP awal: baca `date_from`/`date_to` dari form; default 30 hari.

```abap
<%@ page language="abap" %><%
CONSTANTS lc_sample TYPE kna1-kunnr VALUE '2000000004'.
DATA: lv_from TYPE mkpf-budat, lv_to TYPE mkpf-budat,
      lv_s_from TYPE string, lv_s_to TYPE string.
lv_s_from = request->get_form_field( 'date_from' ).
lv_s_to   = request->get_form_field( 'date_to' ).
IF lv_s_from IS NOT INITIAL AND lv_s_to IS NOT INITIAL.
  lv_from = lv_s_from. lv_to = lv_s_to.
ELSE.
  lv_to = sy-datum. lv_from = sy-datum - 30.
ENDIF.
%>
```

- [ ] **Step 2: Query pergerakan masuk + QI dalam rentang**

```abap
<% TYPES: BEGIN OF ty_mv,
            matnr TYPE mseg-matnr, werks TYPE mseg-werks, lgort TYPE mseg-lgort,
            bwart TYPE mseg-bwart, insmk TYPE mseg-insmk,
            kdauf TYPE mseg-kdauf, kdpos TYPE mseg-kdpos,
          END OF ty_mv.
   DATA: lt_mv TYPE TABLE OF ty_mv, ls_mv TYPE ty_mv.
   SELECT m~matnr m~werks m~lgort m~bwart m~insmk m~kdauf m~kdpos
     FROM mseg AS m INNER JOIN mkpf AS h ON m~mblnr = h~mblnr AND m~mjahr = h~mjahr
     INTO CORRESPONDING FIELDS OF TABLE lt_mv
     WHERE h~budat BETWEEN lv_from AND lv_to
       AND m~kdauf <> ''
       AND ( ( m~shkzg = 'S'
               AND ( ( m~werks = '1000' AND m~lgort = '1D00' )
                  OR ( m~werks = '2000' AND m~lgort IN ( '2KCS','2261','2262','22E2','22E3','229K' ) ) ) )
          OR ( m~bwart IN ( '321','322' ) ) ).   " QI: lihat asumsi
%>
```

⚠️ Asumsi movement type QI = `321/322`. Bila hasil kolom QI kosong padahal ada data, sesuaikan set movement type (lihat spec §9). Simpan sebagai catatan komentar di kode seperti gaya "⚠️" existing.

- [ ] **Step 3: Resolusi buyer (exclude sample) & bangun sel agregasi**

Kumpulkan `kdauf` unik → `VBAK` (`vbeln`,`kunnr`) → buang `kunnr = lc_sample` → `KNA1` (`name1`). Klasifikasikan tiap baris `lt_mv` ke kolom (pmb/cs/mach/band/sand/qi1000/qi2000), lalu bangun tabel unik `(buyer, kolom, kdauf, kdpos)` dan hitung distinct per `(buyer, kolom)`.

```abap
<% TYPES: BEGIN OF ty_cell, buyer TYPE kna1-name1, col TYPE i,
            kdauf TYPE mseg-kdauf, kdpos TYPE mseg-kdpos, END OF ty_cell.
   DATA: lt_cell TYPE TABLE OF ty_cell, ls_cell TYPE ty_cell.
   " col: 1=pmb 2=cs 3=mach 4=band 5=sand 6=qi1000 7=qi2000
   " (loop lt_mv: tentukan col dari werks/lgort/bwart; skip jika buyer sample)
   TYPES: BEGIN OF ty_row, buyer TYPE kna1-name1,
            c1 TYPE i, c2 TYPE i, c3 TYPE i, c4 TYPE i, c5 TYPE i, c6 TYPE i, c7 TYPE i,
          END OF ty_row.
   DATA: lt_row TYPE TABLE OF ty_row, ls_row TYPE ty_row.
%>
```

Setelah `lt_cell` terisi: `SORT lt_cell BY buyer col kdauf kdpos.` → `DELETE ADJACENT DUPLICATES FROM lt_cell COMPARING ALL FIELDS.` → loop hitung ke `lt_row` (increment `c1..c7` sesuai `col`), `SORT lt_row BY buyer`.

- [ ] **Step 4: Markup — navbar, filter, KPI bar, tabel per buyer**

Tulis layout HTML. Navbar dua entri (Dashboard active):

```html
  <div class="navbar">
    <a href="index3a.htm" class="nav-btn active"><span class="nav-icon">&#128202;</span>Dashboard</a>
    <a href="monitoring.htm" class="nav-btn"><span class="nav-icon">&#128269;</span>Monitoring</a>
  </div>
```

Form filter tanggal (`action="index3a.htm"`, method GET) dengan dua `<input type="date" name="date_from/date_to">` + tombol Terapkan (prefill `lv_from`/`lv_to` format `YYYY-MM-DD`).

KPI bar ringan (CSS murni): 7 angka total per kolom (jumlahkan `c1..c7` lintas buyer) + bar proporsional `width` %.

Tabel: `<tbody id="buyer-rows">` loop `lt_row` → `<tr>` nama buyer + 7 sel. Header kolom: Pembahanan · Central Storage · Machining · Banding · Sanding · QI 1000 · QI 2000. REUSE kelas CSS kartu/tabel dari halaman existing.

- [ ] **Step 5: Aktivasi & verifikasi**

Aktifkan `index3a.htm`. Buka di browser.
Expected:
- Halaman tampil tanpa error; default menampilkan 30 hari terakhir.
- Tabel per buyer terisi; TIDAK ada baris buyer sample.
- Ubah filter tanggal → angka berubah sesuai rentang.
- Navbar "Monitoring" → menuju `monitoring.htm`.

- [ ] **Step 6: Commit (opsional)**

```bash
git add "ZBSP_CS_APP/Page with Flow Logic/index3a.htm"
git commit -m "feat: rewrite index3a.htm as graphical dashboard (per-buyer aggregation)"
```

---

### Task 4: `index3a.htm` — panel realtime (polling `dash_feed.htm`)

Tambahkan panel pergerakan barang realtime yang auto-update tiap 15 detik tanpa reload.

**Files:**
- Modify: `ZBSP_CS_APP/Page with Flow Logic/index3a.htm`

**Interfaces:**
- Consumes: JSON dari `dash_feed.htm` (Task 2).
- Produces: DOM `<div id="feed-list">` terisi dinamis.

- [ ] **Step 1: Markup panel realtime**

Tambahkan di bawah tabel buyer:

```html
  <div class="list-container">
    <div style="display:flex;justify-content:space-between;align-items:center;">
      <div class="bom-title">&#9889; Pergerakan Barang (realtime)</div>
      <span id="feed-status" style="font-size:0.72rem;color:#9ca3af;">memuat&hellip;</span>
    </div>
    <div id="feed-list"></div>
  </div>
```

- [ ] **Step 2: JS polling + render + fallback**

```html
  <script>
  function renderFeed(rows){
    var el = document.getElementById('feed-list');
    if(!rows || !rows.length){ el.innerHTML = '<div style="color:#9ca3af;padding:8px;">Belum ada pergerakan.</div>'; return; }
    var h = '';
    rows.forEach(function(r){
      h += '<div class="feed-item"><span class="feed-time">'+r.waktu+'</span>'
        +  '<span class="feed-mat">'+r.matnr+' &middot; '+r.maktx+'</span>'
        +  '<span class="feed-move">'+r.from+' &rarr; '+r.to+'</span>'
        +  '<span class="feed-qty">'+r.qty+'</span>'
        +  '<span class="feed-buyer">'+r.buyer+'</span></div>';
    });
    el.innerHTML = h;
  }
  function loadFeed(){
    fetch('dash_feed.htm', {headers:{'Accept':'application/json'}})
      .then(function(r){ return r.json(); })
      .then(function(rows){ renderFeed(rows); document.getElementById('feed-status').textContent = 'diperbarui ' + new Date().toLocaleTimeString(); })
      .catch(function(){ document.getElementById('feed-status').textContent = 'gagal memuat (memakai data terakhir)'; });
  }
  loadFeed();
  setInterval(loadFeed, 15000);
  </script>
```

Tambahkan CSS ringan `.feed-item`/`.feed-time` dst mengikuti gaya existing.

- [ ] **Step 3: Aktivasi & verifikasi**

Aktifkan `index3a.htm` (+ pastikan `dash_feed.htm` aktif).
Expected:
- Panel realtime terisi daftar pergerakan; label "diperbarui HH:MM:SS" muncul.
- Diamkan 15 dtk → status ter-update lagi (cek Network tab: request `dash_feed.htm` berulang).
- Matikan sementara endpoint / rename → status "gagal memuat", data lama tetap tampil (tidak crash).

- [ ] **Step 4: Commit (opsional)**

```bash
git add "ZBSP_CS_APP/Page with Flow Logic/index3a.htm"
git commit -m "feat: add realtime movement feed panel with 15s polling"
```

---

## Self-Review

**Spec coverage:**
- Filter 30 hari + custom → Task 3 Step 1. ✔
- Total per lokasi (SO-Item unik) → Task 3 Step 2–3. ✔
- QI Plant 1000/2000 → Task 3 Step 2 (asumsi bwart 321/322 diflag). ✔
- Group by buyer + exclude 2000000004 → Task 3 Step 3. ✔
- Realtime tanpa refresh → Task 2 + Task 4. ✔
- UI ringan/cepat → tanpa library eksternal (Global Constraints); feed dibatasi 7 hari/30 baris. ✔
- Migrasi ke monitoring.htm + redirect rujukan diri → Task 1. ✔
- Navbar dua entri → Task 1 Step 3 + Task 3 Step 4. ✔
- pelacakan.htm diabaikan → Global Constraints. ✔

**Placeholder scan:** Kode inti (SELECT agregasi, polling JS, endpoint JSON) ditulis konkret. Boilerplate (CSS kartu/navbar) sengaja mengarahkan REUSE dari halaman existing karena polanya sudah ada di repo — bukan placeholder keputusan.

**Type consistency:** Kolom `col 1..7` konsisten antara `ty_cell` dan `c1..c7` di `ty_row` (Task 3 Step 3). Field JSON (`waktu/matnr/maktx/from/to/qty/buyer`) konsisten antara Task 2 (produce) dan Task 4 (consume).
