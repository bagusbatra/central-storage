# index3.htm Cockpit Aktual — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Repurpose index3.htm menjadi papan pantau ("cockpit") agregat real-time untuk admin Central Storage: filter + KPI aktual + live movement feed, dari data SAP S/4HANA 1809.

**Architecture:** Satu BSP page (flow logic ABAP inline, pola sama seperti index.htm) yang render server-side tiap request. Body pelacakan lama (filter SO/Item, 5 tab, form Transfer Posting, modal) diganti total oleh layout cockpit. Query dibatasi scope 7 SLoc + rentang tanggal untuk performa. Tanpa library chart — HTML/CSS/SVG saja.

**Tech Stack:** SAP BSP (ABAP `<%@ page language="abap" %>`), HTML/CSS/inline-JS, `zcl_cs_util`, S/4HANA 1809 (MSEG/MKPF via MATDOC compat view, MARD/MSKA, AFPO/AFKO, MCH1/MCHB).

## Testing adaptation (BACA DULU)

ABAP BSP tak punya unit-test lokal & tak bisa dijalankan di luar SAP. Maka:
- **UI (HTML/CSS/JS):** diverifikasi lewat **preview statis lokal** (`preview-index3-cockpit.html`, data dummy) — dibuka di browser. Ini test yang BISA dijalankan di luar SAP.
- **Logika ABAP (query/agregasi):** diverifikasi via **checklist aktivasi SE80** (syntax-check + aktivasi + eyeball data). Dijalankan oleh eksekutor di SAP. Bukan otomatis.
- Setiap task tetap diakhiri commit.

## Global Constraints

- Scope lokasi TETAP: Plant 1000 → SLoc `1D00`; Plant 2000 → `2KCS 2261 2262 22E2 22E3 229K`. Filter hanya mempersempit di dalam himpunan ini.
- **Tanpa library chart** — semua visual HTML/CSS/SVG server-rendered.
- Semua self-reference (form action, link, `userLogout`) → `index3.htm`.
- `MSEG`/`MKPF` di S/4 1809 = compat view atas `MATDOC`; query WAJIB berfilter `budat` (rentang) + `werks`/`lgort`, feed dibatasi **UP TO 200 ROWS**.
- Reuse `zcl_cs_util` (fmt_date) + pola badge `bwart` + kelas `.num-fmt` (format id-ID via JS) yang sudah ada di app.
- Rentang tanggal hanya memengaruhi Live Feed & KPI "gerakan"; KPI stok & Peta Stok pakai posisi saat ini.
- KPI Σ qty lintas material = indikatif (unit campur); metrik utama pakai *count*.
- Bahasa UI: Indonesia, konsisten dgn halaman lain.

---

## File Structure

- **Modify (repurpose):** `ZBSP_CS_APP/Page with Flow Logic/index3.htm` — satu-satunya file produksi. Body diganti; shell (header-bar/navbar/footer) & helper JS dipertahankan.
- **Create (alat bantu, bukan produksi):** `ZBSP_CS_APP/MIMEs/preview-index3-cockpit.html` — preview statis data dummy untuk verifikasi UI di browser sebelum port ke BSP.

Keputusan: **MVP inline di page** (bukan class), konsisten dgn index.htm yang seluruh ABAP-nya inline → satu file untuk di-paste ke SE80, minim friksi. Ekstraksi ke `ZCL_CS_COCKPIT` ditandai sebagai refaktor lanjutan (di luar plan ini).

---

## Task 1: Shell cockpit (strip body lama, siapkan kerangka)

**Files:**
- Modify: `ZBSP_CS_APP/Page with Flow Logic/index3.htm` (ganti seluruh isi)
- Test: buka di SE80 (aktivasi) — kerangka kosong render tanpa error

**Interfaces:**
- Produces: struktur file — blok ABAP `<% ... %>` (baris atas) untuk deklarasi+query nanti; shell HTML `.header-bar`/`.navbar`/`.content`/`.page-footer`; blok `<script>` dgn helper `userLogout()`, dropdown user, formatter `.num-fmt`. Task 2–4 menempel di penanda `<!-- COCKPIT-BODY -->`.

- [ ] **Step 1: Tulis kerangka baru index3.htm**

Ganti SELURUH isi file dengan kerangka minimal berikut (buang filter SO/Item, 5 tab, form transfer, modal). Simpan bagian `<style>` badge + `.num-fmt` + helper JS yang dipakai ulang.

```abap
<%@ page language="abap" %>
<%
*&---------------------------------------------------------------------*
*& BSP Page — index3.htm : COCKPIT AKTUAL Central Storage
*&---------------------------------------------------------------------*
*& Papan pantau agregat real-time (bukan lookup per-SO). Body pelacakan
*& lama diganti total. Scope 7 SLoc; filter mempersempit. Server-render.
*& Lihat SPEC-INDEX3-COCKPIT.md.
*&---------------------------------------------------------------------*
DATA: lv_layout_user TYPE string,
      lv_ts_date     TYPE string,
      lv_ts_time     TYPE string.
lv_layout_user = sy-uname.

" ===== COCKPIT-ABAP: deklarasi & query (diisi Task 2-4) =====

lv_ts_date = zcl_cs_util=>fmt_date( sy-datum ).
lv_ts_time = sy-uzeit(2) && ':' && sy-uzeit+2(2).
%>
<!DOCTYPE html>
<html lang="id">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Cockpit Aktual - Central Storage KMI 2</title>
  <link rel="stylesheet" href="css/style.css?r=12">
  <style>
    .mv-badge { display:inline-block; padding:2px 8px; border-radius:10px; font-size:0.72rem; font-weight:600; white-space:nowrap; }
    .mv-blue{background:#dbeafe;color:#1e40af;} .mv-yellow{background:#fef3c7;color:#92400e;}
    .mv-purple{background:#ede9fe;color:#5b21b6;} .mv-green{background:#dcfce7;color:#15803d;}
    .mv-red{background:#fee2e2;color:#991b1b;} .mv-gray{background:#f3f4f6;color:#4b5563;}
    /* COCKPIT-CSS: diisi Task 2-4 */
  </style>
</head>
<body>
  <div class="header-bar">
    <div class="header-title">
      <h1>Central Storage — Cockpit Aktual</h1>
      <p>Papan pantau pergerakan &amp; stok aktual &#8212; Plant 1000/2000 Surabaya</p>
    </div>
    <div class="header-user" onclick="toggleUserDropdown(event)"><span>User SAP: <%= lv_layout_user %></span>
      <div class="user-dropdown" id="user-dropdown">
        <div class="dropdown-userinfo"><%= lv_layout_user %></div>
        <div class="dropdown-divider"></div>
        <a href="javascript:void(0)" onclick="userLogout()">&#10007; Logout</a>
      </div>
    </div>
  </div>

  <div class="navbar">
    <a href="index.htm" class="nav-btn"><span class="nav-icon">&#128269;</span>Pelacakan</a>
    <a href="index3.htm" class="nav-btn active"><span class="nav-icon">&#128202;</span>Cockpit</a>
  </div>

  <div class="content">
    <!-- COCKPIT-BODY -->
  </div>

  <script>
    function toggleUserDropdown(e){ e.stopPropagation(); var dd=document.getElementById('user-dropdown'); if(dd) dd.classList.toggle('open'); }
    document.addEventListener('click', function(e){ var dd=document.getElementById('user-dropdown'); var hu=document.querySelector('.header-user'); if(dd&&hu&&!hu.contains(e.target)){ dd.classList.remove('open'); } });
    function userLogout(){ window.location.href='index3.htm?~logoff'; }
    document.querySelectorAll('.num-fmt').forEach(function(el){ var v=parseFloat(el.textContent.trim()); if(!isNaN(v)){ el.textContent=v.toLocaleString('id-ID',{minimumFractionDigits:0,maximumFractionDigits:3}); } });
    /* COCKPIT-JS: diisi Task 4 */
  </script>
  <div class="page-footer">Data per: <%= lv_ts_date %> <%= lv_ts_time %> WIB &bull; User: <%= lv_layout_user %></div>
</body>
</html>
```

- [ ] **Step 2: Verifikasi UI shell (lokal)**

Belum ada preview file; verifikasi ringan: pastikan tidak ada tag ABAP tak tertutup — hitung `<%` vs `%>` seimbang.
Run: `grep -c '<%' "ZBSP_CS_APP/Page with Flow Logic/index3.htm"; grep -c '%>' "ZBSP_CS_APP/Page with Flow Logic/index3.htm"`
Expected: dua angka sama (mis. 4 dan 4).

- [ ] **Step 3: Verifikasi aktivasi (SE80 — manual)**

Checklist untuk eksekutor di SAP:
1. Aktifkan index3.htm di SE80 → **tanpa error syntax**.
2. Jalankan → tampil header "Cockpit Aktual", navbar 2 entri (Cockpit aktif), footer timestamp. Body kosong.
Expected: halaman render, navbar & footer benar.

- [ ] **Step 4: Commit**

```bash
git add "ZBSP_CS_APP/Page with Flow Logic/index3.htm"
git commit -m "feat(index3): repurpose jadi shell cockpit aktual"
```

---

## Task 2: Filter bar (plant + SLoc + rentang tanggal)

**Files:**
- Modify: `ZBSP_CS_APP/Page with Flow Logic/index3.htm` (blok COCKPIT-ABAP + COCKPIT-BODY + COCKPIT-CSS)

**Interfaces:**
- Consumes: kerangka Task 1 (penanda COCKPIT-*).
- Produces: variabel ABAP siap dipakai Task 3–4: `lr_werks TYPE RANGE OF werks_d`, `lr_lgort TYPE RANGE OF lgort_d`, `lv_from TYPE sy-datum`, `lv_to TYPE sy-datum`, `lv_f_plant/lv_f_range/lv_f_from/lv_f_to TYPE string`, `lt_lgort_all` (7 SLoc + status tercentang).

- [ ] **Step 1: Tambah pembacaan form + bangun scope (COCKPIT-ABAP)**

Sisipkan menggantikan komentar `" ===== COCKPIT-ABAP ...`:

```abap
DATA: lv_f_plant   TYPE string,
      lv_f_range   TYPE string,
      lv_f_from    TYPE string,
      lv_f_to      TYPE string,
      lv_f_applied TYPE string.
lv_f_plant   = request->get_form_field( 'f_plant' ).
lv_f_range   = request->get_form_field( 'f_range' ).
lv_f_from    = request->get_form_field( 'f_from' ).
lv_f_to      = request->get_form_field( 'f_to' ).
lv_f_applied = request->get_form_field( 'f_applied' ).
IF lv_f_range IS INITIAL. lv_f_range = 'today'. ENDIF.

" --- Range plant ---
DATA: lr_werks TYPE RANGE OF werks_d,
      ls_werks LIKE LINE OF lr_werks.
IF lv_f_plant = '1000' OR lv_f_plant = '2000'.
  ls_werks-sign = 'I'. ls_werks-option = 'EQ'. ls_werks-low = lv_f_plant.
  APPEND ls_werks TO lr_werks.
ELSE.
  ls_werks-sign = 'I'. ls_werks-option = 'EQ'.
  ls_werks-low = '1000'. APPEND ls_werks TO lr_werks.
  ls_werks-low = '2000'. APPEND ls_werks TO lr_werks.
ENDIF.

" --- Daftar 7 SLoc + status tercentang (utk UI & range) ---
TYPES: BEGIN OF ty_lg, lgort TYPE lgort_d, werks TYPE werks_d, on TYPE abap_bool, END OF ty_lg.
DATA: lt_lgort_all TYPE TABLE OF ty_lg,
      ls_lg        TYPE ty_lg,
      lv_fld       TYPE string,
      lv_val       TYPE string.
DEFINE add_lg.
  CLEAR ls_lg. ls_lg-lgort = &1. ls_lg-werks = &2. APPEND ls_lg TO lt_lgort_all.
END-OF-DEFINITION.
add_lg '1D00' '1000'. add_lg '2KCS' '2000'. add_lg '2261' '2000'.
add_lg '2262' '2000'. add_lg '22E2' '2000'. add_lg '22E3' '2000'. add_lg '229K' '2000'.

DATA: lr_lgort TYPE RANGE OF lgort_d,
      ls_lgort LIKE LINE OF lr_lgort.
FIELD-SYMBOLS <lg> TYPE ty_lg.
LOOP AT lt_lgort_all ASSIGNING <lg>.
  IF lv_f_applied IS INITIAL.
    <lg>-on = abap_true.                      " load pertama: semua aktif
  ELSE.
    CONCATENATE 'f_lg_' <lg>-lgort INTO lv_fld.
    lv_val = request->get_form_field( lv_fld ).
    IF lv_val = 'X'. <lg>-on = abap_true. ENDIF.
  ENDIF.
  " hormati filter plant utk daftar SLoc juga
  IF ( lv_f_plant = '1000' AND <lg>-werks <> '1000' ) OR
     ( lv_f_plant = '2000' AND <lg>-werks <> '2000' ).
    <lg>-on = abap_false.
  ENDIF.
  IF <lg>-on = abap_true.
    ls_lgort-sign = 'I'. ls_lgort-option = 'EQ'. ls_lgort-low = <lg>-lgort.
    APPEND ls_lgort TO lr_lgort.
  ENDIF.
ENDLOOP.

" --- Rentang tanggal (utk feed & KPI gerakan) ---
DATA: lv_from TYPE sy-datum, lv_to TYPE sy-datum.
lv_to = sy-datum.
CASE lv_f_range.
  WHEN '7'.  lv_from = sy-datum - 7.
  WHEN '30'. lv_from = sy-datum - 30.
  WHEN 'custom'.
    IF lv_f_from IS NOT INITIAL. lv_from = lv_f_from(8). ELSE. lv_from = sy-datum. ENDIF.
    IF lv_f_to   IS NOT INITIAL. lv_to   = lv_f_to(8).   ENDIF.
  WHEN OTHERS. lv_from = sy-datum.   " today
ENDCASE.
```

- [ ] **Step 2: Tambah HTML filter bar (COCKPIT-BODY)**

Ganti `<!-- COCKPIT-BODY -->` dengan (filter + placeholder modul):

```html
    <div class="filter-card">
      <form method="get" action="index3.htm">
        <input type="hidden" name="f_applied" value="X">
        <div class="filter-form" style="align-items:flex-end; gap:14px;">
          <div class="form-group">
            <label>Plant</label>
            <select name="f_plant">
              <option value="" <% IF lv_f_plant IS INITIAL. %>selected<% ENDIF. %>>Semua</option>
              <option value="1000" <% IF lv_f_plant = '1000'. %>selected<% ENDIF. %>>1000</option>
              <option value="2000" <% IF lv_f_plant = '2000'. %>selected<% ENDIF. %>>2000</option>
            </select>
          </div>
          <div class="form-group" style="flex:1;">
            <label>SLoc</label>
            <div style="display:flex; gap:10px; flex-wrap:wrap; padding-top:4px;">
              <% LOOP AT lt_lgort_all ASSIGNING <lg>. %>
              <label style="font-size:0.8rem; display:inline-flex; gap:4px; align-items:center;">
                <input type="checkbox" name="f_lg_<%= <lg>-lgort %>" value="X" <% IF <lg>-on = abap_true. %>checked<% ENDIF. %>><%= <lg>-lgort %>
              </label>
              <% ENDLOOP. %>
            </div>
          </div>
          <div class="form-group">
            <label>Rentang</label>
            <select name="f_range" onchange="cockToggleCustom(this)">
              <option value="today"  <% IF lv_f_range = 'today'.  %>selected<% ENDIF. %>>Hari ini</option>
              <option value="7"      <% IF lv_f_range = '7'.      %>selected<% ENDIF. %>>7 hari</option>
              <option value="30"     <% IF lv_f_range = '30'.     %>selected<% ENDIF. %>>30 hari</option>
              <option value="custom" <% IF lv_f_range = 'custom'. %>selected<% ENDIF. %>>Custom</option>
            </select>
          </div>
          <div class="form-group" id="cock-custom" style="<% IF lv_f_range <> 'custom'. %>display:none;<% ENDIF. %>">
            <label>Dari / Sampai</label>
            <div style="display:flex; gap:4px;">
              <input type="date" name="f_from" value="<%= lv_f_from %>">
              <input type="date" name="f_to"   value="<%= lv_f_to %>">
            </div>
          </div>
          <div class="btn-submit"><button type="submit">Terapkan</button></div>
        </div>
      </form>
    </div>

    <!-- COCKPIT-KPI -->
    <!-- COCKPIT-FEED -->
```

- [ ] **Step 3: Tambah JS toggle custom (COCKPIT-JS)**

Ganti `/* COCKPIT-JS ... */`:

```javascript
    function cockToggleCustom(sel){ var c=document.getElementById('cock-custom'); if(c){ c.style.display = (sel.value==='custom') ? '' : 'none'; } }
```

- [ ] **Step 4: Verifikasi (lokal + SE80)**

Lokal: `<%`/`%>` seimbang (`grep -c`).
SE80 (manual): aktifkan → filter bar tampil (Plant dropdown, 7 checkbox SLoc, Rentang, tombol Terapkan). Pilih Plant 2000 + Terapkan → hanya SLoc plant 2000 tetap relevan; nilai filter dipertahankan setelah reload. Pilih Custom → field tanggal muncul.

- [ ] **Step 5: Commit**

```bash
git add "ZBSP_CS_APP/Page with Flow Logic/index3.htm"
git commit -m "feat(index3): filter bar plant/SLoc/rentang + bangun scope"
```

---

## Task 3: Modul A — Header KPI Aktual

**Files:**
- Modify: `ZBSP_CS_APP/Page with Flow Logic/index3.htm` (COCKPIT-ABAP tambahan + COCKPIT-KPI + COCKPIT-CSS)

**Interfaces:**
- Consumes: `lr_werks`, `lr_lgort`, `lv_from`, `lv_to` (Task 2).
- Produces: skalar KPI `lv_kpi_pos TYPE i` (posisi stok aktif), `lv_kpi_unr TYPE p`, `lv_kpi_docs TYPE i`, `lv_kpi_lines TYPE i`, `lv_kpi_pmb/prd/fin TYPE i`, `lv_kpi_exp TYPE i`, `lv_kpi_blk TYPE i`.

- [ ] **Step 1: Tambah agregasi KPI (COCKPIT-ABAP, setelah blok rentang tanggal)**

```abap
" ===== KPI AGGREGATION =====
DATA: lv_kpi_pos   TYPE i,
      lv_kpi_unr   TYPE p LENGTH 15 DECIMALS 3,
      lv_kpi_docs  TYPE i,
      lv_kpi_lines TYPE i,
      lv_kpi_pmb   TYPE i,
      lv_kpi_prd   TYPE i,
      lv_kpi_fin   TYPE i,
      lv_kpi_exp   TYPE i,
      lv_kpi_blk   TYPE i.

" --- Stok (MARD free + MSKA SO-stock) posisi saat ini ---
DATA: BEGIN OF ls_mard_k, werks TYPE werks_d, lgort TYPE lgort_d,
        labst TYPE labst, speme TYPE speme, END OF ls_mard_k,
      lt_mard_k LIKE TABLE OF ls_mard_k.
SELECT werks lgort labst speme FROM mard INTO TABLE lt_mard_k
  WHERE werks IN lr_werks AND lgort IN lr_lgort.
LOOP AT lt_mard_k INTO ls_mard_k.
  IF ls_mard_k-labst > 0 OR ls_mard_k-speme > 0. lv_kpi_pos = lv_kpi_pos + 1. ENDIF.
  lv_kpi_unr = lv_kpi_unr + ls_mard_k-labst.
  IF ls_mard_k-speme > 0. lv_kpi_blk = lv_kpi_blk + 1. ENDIF.
ENDLOOP.
DATA: BEGIN OF ls_mska_k, werks TYPE werks_d, lgort TYPE lgort_d,
        kalab TYPE kalab, kaspe TYPE kaspe, END OF ls_mska_k,
      lt_mska_k LIKE TABLE OF ls_mska_k.
SELECT werks lgort kalab kaspe FROM mska INTO TABLE lt_mska_k
  WHERE werks IN lr_werks AND lgort IN lr_lgort AND sobkz = 'E'.
LOOP AT lt_mska_k INTO ls_mska_k.
  IF ls_mska_k-kalab > 0 OR ls_mska_k-kaspe > 0. lv_kpi_pos = lv_kpi_pos + 1. ENDIF.
  lv_kpi_unr = lv_kpi_unr + ls_mska_k-kalab.
  IF ls_mska_k-kaspe > 0. lv_kpi_blk = lv_kpi_blk + 1. ENDIF.
ENDLOOP.

" --- Gerakan dalam rentang (MSEG join MKPF) ---
SELECT COUNT( DISTINCT m~mblnr ) FROM mseg AS m
  INNER JOIN mkpf AS k ON m~mblnr = k~mblnr AND m~mjahr = k~mjahr
  INTO lv_kpi_docs
  WHERE k~budat BETWEEN lv_from AND lv_to
    AND m~werks IN lr_werks AND m~lgort IN lr_lgort.
SELECT COUNT(*) FROM mseg AS m
  INNER JOIN mkpf AS k ON m~mblnr = k~mblnr AND m~mjahr = k~mjahr
  INTO lv_kpi_lines
  WHERE k~budat BETWEEN lv_from AND lv_to
    AND m~werks IN lr_werks AND m~lgort IN lr_lgort.

" --- Order WIP per tahap MRP (AFPO join AFKO, wemng<psmng) ---
DATA: BEGIN OF ls_ord_k, pwerk TYPE afpo-pwerk, dispo TYPE afko-dispo, END OF ls_ord_k,
      lt_ord_k LIKE TABLE OF ls_ord_k.
SELECT a~pwerk k~dispo FROM afpo AS a INNER JOIN afko AS k ON a~aufnr = k~aufnr
  INTO TABLE lt_ord_k
  WHERE a~pwerk IN lr_werks
    AND a~wemng < a~psmng
    AND k~dispo IN ( 'WM1','WM2','PN1','PN2','GA1','GA2','EB2' ).
LOOP AT lt_ord_k INTO ls_ord_k.
  CASE ls_ord_k-dispo.
    WHEN 'WM1' OR 'WM2' OR 'PN1' OR 'PN2'. lv_kpi_pmb = lv_kpi_pmb + 1.
    WHEN 'GA1' OR 'GA2'.                   lv_kpi_prd = lv_kpi_prd + 1.
    WHEN 'EB2'.                            lv_kpi_fin = lv_kpi_fin + 1.
  ENDCASE.
ENDLOOP.

" --- Batch mendekati kadaluarsa (<=30 hari) yang ada stok ---
DATA lv_exp_to TYPE sy-datum.
lv_exp_to = sy-datum + 30.
SELECT COUNT(*) FROM mch1 AS c INNER JOIN mchb AS b
    ON c~matnr = b~matnr AND c~charg = b~charg
  INTO lv_kpi_exp
  WHERE c~vfdat BETWEEN sy-datum AND lv_exp_to
    AND b~clabs > 0
    AND b~werks IN lr_werks AND b~lgort IN lr_lgort.
```

- [ ] **Step 2: Tambah HTML KPI row (ganti `<!-- COCKPIT-KPI -->`)**

```html
    <div class="cock-kpi">
      <div class="cock-tile">
        <div class="cock-tile-l">Posisi Stok Aktif</div>
        <div class="cock-tile-v"><%= lv_kpi_pos %> <small>baris</small></div>
        <div class="cock-tile-s" title="Indikatif, lintas material (unit campur)">&Sigma; unrestr <span class="num-fmt"><%= lv_kpi_unr %></span></div>
      </div>
      <div class="cock-tile">
        <div class="cock-tile-l">Gerakan (rentang)</div>
        <div class="cock-tile-v"><%= lv_kpi_docs %> <small>dok</small></div>
        <div class="cock-tile-s"><%= lv_kpi_lines %> baris</div>
      </div>
      <div class="cock-tile">
        <div class="cock-tile-l">Order WIP per Tahap</div>
        <div class="cock-tile-v" style="font-size:1.1rem;">
          PMB <%= lv_kpi_pmb %> &middot; PRD <%= lv_kpi_prd %> &middot; FIN <%= lv_kpi_fin %>
        </div>
      </div>
      <div class="cock-tile cock-warn">
        <div class="cock-tile-l">&#9888; Mau Kadaluarsa</div>
        <div class="cock-tile-v"><%= lv_kpi_exp %> <small>batch</small></div>
        <div class="cock-tile-s">&le; 30 hari</div>
      </div>
      <div class="cock-tile cock-crit">
        <div class="cock-tile-l">&#9940; Blocked</div>
        <div class="cock-tile-v"><%= lv_kpi_blk %> <small>baris</small></div>
      </div>
    </div>
```

- [ ] **Step 3: Tambah CSS KPI (ganti `/* COCKPIT-CSS ... */`)**

```css
    .cock-kpi { display:grid; grid-template-columns:repeat(5,1fr); gap:12px; margin-bottom:18px; }
    .cock-tile { background:#f9fafb; border:1px solid #eef0f2; border-radius:10px; padding:12px 14px; }
    .cock-tile-l { font-size:0.66rem; letter-spacing:0.4px; color:#9ca3af; text-transform:uppercase; }
    .cock-tile-v { font-size:1.6rem; font-weight:700; margin-top:3px; font-variant-numeric:tabular-nums; }
    .cock-tile-v small { font-size:0.72rem; font-weight:600; color:#6b7280; }
    .cock-tile-s { font-size:0.72rem; color:#6b7280; margin-top:2px; }
    .cock-warn { border-color:#fde68a; background:#fffbeb; }
    .cock-crit { border-color:#fecaca; background:#fef2f2; }
    @media (max-width:820px){ .cock-kpi{ grid-template-columns:repeat(2,1fr);} }
```

- [ ] **Step 4: Verifikasi (SE80 — manual)**

Checklist: aktifkan → 5 kartu KPI render. Bandingkan angka:
- "Gerakan (rentang)" dgn hasil MB51/COOIS untuk tanggal & lokasi sama.
- "Blocked" dgn stok blocked di MMBE lokasi tsb.
- "Order WIP" dgn COOIS (order belum GR penuh) per MRP.
⚠️ Jika ada field tak dikenal saat aktivasi (mis. `speme`/`kaspe`/`vfdat`), laporkan nama field — sesuaikan.

- [ ] **Step 5: Commit**

```bash
git add "ZBSP_CS_APP/Page with Flow Logic/index3.htm"
git commit -m "feat(index3): modul A - header KPI aktual"
```

---

## Task 4: Modul C — Live Movement Feed

**Files:**
- Modify: `ZBSP_CS_APP/Page with Flow Logic/index3.htm` (COCKPIT-ABAP tambahan + COCKPIT-FEED + COCKPIT-CSS + COCKPIT-JS)

**Interfaces:**
- Consumes: `lr_werks`, `lr_lgort`, `lv_from`, `lv_to`.
- Produces: `lt_feed` (baris pergerakan siap render) + UI feed dgn filter client-side.

- [ ] **Step 1: Tambah query feed + enrich (COCKPIT-ABAP, setelah KPI)**

```abap
" ===== LIVE MOVEMENT FEED =====
TYPES: BEGIN OF ty_feed,
         mblnr TYPE mseg-mblnr, mjahr TYPE mseg-mjahr,
         budat TYPE mkpf-budat, cputm TYPE mkpf-cputm, usnam TYPE mkpf-usnam,
         bwart TYPE mseg-bwart, shkzg TYPE mseg-shkzg,
         matnr TYPE mseg-matnr, maktx TYPE makt-maktx, charg TYPE mseg-charg,
         werks TYPE mseg-werks, lgort TYPE mseg-lgort,
         menge TYPE mseg-menge, meins TYPE mseg-meins,
         bwart_lbl TYPE string, bwart_cls TYPE string, budat_str TYPE string,
       END OF ty_feed.
DATA: lt_feed TYPE TABLE OF ty_feed, ls_feed TYPE ty_feed.
FIELD-SYMBOLS <f> TYPE ty_feed.

SELECT m~mblnr m~mjahr k~budat k~cputm k~usnam
       m~bwart m~shkzg m~matnr m~charg m~werks m~lgort m~menge m~meins
  FROM mseg AS m INNER JOIN mkpf AS k ON m~mblnr = k~mblnr AND m~mjahr = k~mjahr
  INTO CORRESPONDING FIELDS OF TABLE lt_feed
  UP TO 200 ROWS
  WHERE k~budat BETWEEN lv_from AND lv_to
    AND m~werks IN lr_werks AND m~lgort IN lr_lgort
  ORDER BY k~budat DESCENDING k~cputm DESCENDING m~mblnr DESCENDING m~zeile.

IF lt_feed IS NOT INITIAL.
  DATA: lt_feed_makt TYPE TABLE OF makt, ls_feed_makt TYPE makt.
  SELECT matnr maktx FROM makt INTO CORRESPONDING FIELDS OF TABLE lt_feed_makt
    FOR ALL ENTRIES IN lt_feed
    WHERE matnr = lt_feed-matnr AND spras = sy-langu.
  SORT lt_feed_makt BY matnr.
  LOOP AT lt_feed ASSIGNING <f>.
    READ TABLE lt_feed_makt INTO ls_feed_makt WITH KEY matnr = <f>-matnr BINARY SEARCH.
    IF sy-subrc = 0. <f>-maktx = ls_feed_makt-maktx. ENDIF.
    <f>-budat_str = zcl_cs_util=>fmt_date( <f>-budat ).
    CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
      EXPORTING input = <f>-meins IMPORTING output = <f>-meins.
    CASE <f>-bwart.
      WHEN '301'. <f>-bwart_lbl = 'Cross Plant'. <f>-bwart_cls = 'mv-blue'.
      WHEN '311'. <f>-bwart_lbl = 'In Plant'.    <f>-bwart_cls = 'mv-yellow'.
      WHEN '321'. <f>-bwart_lbl = 'Release QI'.  <f>-bwart_cls = 'mv-purple'.
      WHEN '101'. <f>-bwart_lbl = 'Goods Receipt'. <f>-bwart_cls = 'mv-green'.
      WHEN '261'. <f>-bwart_lbl = 'GI to Order'.  <f>-bwart_cls = 'mv-red'.
      WHEN '601'. <f>-bwart_lbl = 'Delivery'.     <f>-bwart_cls = 'mv-red'.
      WHEN OTHERS. <f>-bwart_lbl = <f>-bwart.     <f>-bwart_cls = 'mv-gray'.
    ENDCASE.
  ENDLOOP.
ENDIF.
```

- [ ] **Step 2: Tambah HTML feed (ganti `<!-- COCKPIT-FEED -->`)**

```html
    <div class="cock-panel">
      <div class="cock-panel-head">
        <div class="cock-panel-t">Live Movement Feed &middot; <%= lv_ts_date %></div>
        <div style="display:flex; gap:8px; align-items:center;">
          <input type="text" id="feed-search" placeholder="Cari material..." oninput="cockFeedFilter()" style="padding:5px 9px; border:1px solid #d1d5db; border-radius:5px; font-size:0.8rem;">
          <select id="feed-mvt" onchange="cockFeedFilter()" style="padding:5px 9px; border:1px solid #d1d5db; border-radius:5px; font-size:0.8rem;">
            <option value="">Semua MvT</option>
            <option value="301">301</option><option value="311">311</option>
            <option value="321">321</option><option value="101">101</option>
            <option value="261">261</option><option value="601">601</option>
          </select>
          <label style="font-size:0.75rem; color:#6b7280; display:inline-flex; gap:4px; align-items:center;">
            <input type="checkbox" id="feed-ar" onchange="cockAutoRefresh(this)">&#8635; 60s
          </label>
          <span id="feed-count" style="font-size:0.72rem; color:#9ca3af;"></span>
        </div>
      </div>
      <div style="overflow-x:auto;">
        <table class="data-table" style="font-size:0.8rem;">
          <thead><tr>
            <th>Waktu</th><th>Jenis</th><th>Material</th><th>Batch</th>
            <th>Lokasi</th><th style="text-align:right;">Qty</th><th>User</th>
          </tr></thead>
          <tbody>
            <% IF lt_feed IS INITIAL. %>
            <tr><td colspan="7" style="text-align:center;color:#9ca3af;padding:22px;">Tidak ada pergerakan pada rentang &amp; lokasi terpilih.</td></tr>
            <% ELSE.
                 LOOP AT lt_feed INTO ls_feed. %>
            <tr class="feed-row" data-mvt="<%= ls_feed-bwart %>" data-mat="<%= ls_feed-matnr %> <%= ls_feed-maktx %>">
              <td style="white-space:nowrap;"><%= ls_feed-budat_str %> <%= ls_feed-cputm(2) %>:<%= ls_feed-cputm+2(2) %></td>
              <td><span class="mv-badge <%= ls_feed-bwart_cls %>"><%= ls_feed-bwart %> &middot; <%= ls_feed-bwart_lbl %></span></td>
              <td><div style="font-family:monospace;"><%= ls_feed-matnr %></div><div style="font-size:0.72rem;color:#6b7280;"><%= ls_feed-maktx %></div></td>
              <td style="font-family:monospace;"><%= ls_feed-charg %></td>
              <td style="font-family:monospace;">
                <% IF ls_feed-shkzg = 'H'. %><span style="color:#dc2626;">&minus; <%= ls_feed-werks %>/<%= ls_feed-lgort %></span><% ELSE. %><span style="color:#15803d;">+ <%= ls_feed-werks %>/<%= ls_feed-lgort %></span><% ENDIF. %>
              </td>
              <td style="text-align:right;"><span class="num-fmt"><%= ls_feed-menge %></span> <%= ls_feed-meins %></td>
              <td><%= ls_feed-usnam %></td>
            </tr>
            <%   ENDLOOP.
                 ENDIF. %>
          </tbody>
        </table>
      </div>
    </div>
```

- [ ] **Step 3: Tambah CSS panel + JS filter/auto-refresh**

CSS (tambah di COCKPIT-CSS):
```css
    .cock-panel { background:#fff; border:1px solid #eef0f2; border-radius:10px; padding:14px 16px; }
    .cock-panel-head { display:flex; justify-content:space-between; align-items:center; gap:10px; margin-bottom:12px; flex-wrap:wrap; }
    .cock-panel-t { font-size:0.78rem; letter-spacing:0.4px; color:#374151; font-weight:700; text-transform:uppercase; }
    .feed-row:hover { background:#fafbfc; }
```
JS (tambah di COCKPIT-JS):
```javascript
    function cockFeedFilter(){
      var q=((document.getElementById('feed-search')||{}).value||'').trim().toLowerCase();
      var mv=(document.getElementById('feed-mvt')||{}).value||'';
      var n=0;
      document.querySelectorAll('.feed-row').forEach(function(r){
        var okm=!q||(r.getAttribute('data-mat')||'').toLowerCase().indexOf(q)>=0;
        var okv=!mv||r.getAttribute('data-mvt')===mv;
        var show=okm&&okv; r.style.display=show?'':'none'; if(show)n++;
      });
      var c=document.getElementById('feed-count'); if(c) c.textContent=(q||mv)?(n+' cocok'):'';
    }
    function cockAutoRefresh(cb){
      if(cb.checked){ window._cockAR=setTimeout(function(){ location.reload(); },60000); }
      else if(window._cockAR){ clearTimeout(window._cockAR); }
    }
```

- [ ] **Step 4: Verifikasi (SE80 — manual)**

Checklist: aktifkan → tabel feed tampil (terbaru dulu), badge bwart benar, "−/+" lokasi sesuai SHKZG. Ketik material di search → baris tersaring. Pilih MvT 311 → hanya 311. Centang auto-refresh → halaman reload ~60s. Ganti Rentang ke "7 hari" + Terapkan → feed & KPI gerakan ikut berubah. Bandingkan beberapa baris dgn MB51.

- [ ] **Step 5: Commit**

```bash
git add "ZBSP_CS_APP/Page with Flow Logic/index3.htm"
git commit -m "feat(index3): modul C - live movement feed + filter + auto-refresh"
```

---

## Self-Review (penulis plan)

**1. Spec coverage:**
- Filter plant/SLoc/rentang → Task 2 ✓
- Modul A (5 KPI) → Task 3 ✓ (stok, gerakan, order tahap, expiry, blocked)
- Modul C (feed + badge + filter + auto-refresh) → Task 4 ✓
- Modul B (Peta Stok) → **fase 2, sengaja di luar plan MVP** (sesuai §2 spec) ✓
- Scope 7 SLoc, no chart lib, self-ref index3.htm, MSEG via join budat+werks+lgort, UP TO 200 → Global Constraints + tasks ✓

**2. Placeholder scan:** tidak ada TBD/TODO; semua step berisi kode nyata. Penanda `COCKPIT-*` adalah anchor edit, bukan placeholder konten. ✓

**3. Type consistency:** `lr_werks`/`lr_lgort`/`lv_from`/`lv_to` didefinisikan Task 2, dipakai Task 3–4 dgn nama sama. `lt_feed`/`ty_feed` konsisten. `lv_kpi_*` konsisten Task 3. ✓

**Catatan risiko:** nama field stok (`speme/kaspe/vfdat/clabs`) & `COUNT( DISTINCT )` mengikuti konvensi ECC/S/4; jika sistem memakai model stok baru (NSDM) sepenuhnya, agregasi MARD/MCHB mungkin perlu CDS `I_MaterialStock` — sudah ditandai di spec §9 & checklist Task 3.

---

## Fase berikutnya (di luar plan ini)
- Modul B (Peta Stok matriks + drill) — spec §8.
- Tab Alert (E) & WIP MRP (D) — spec §12 fase 3.
- Refaktor query berat → `ZCL_CS_COCKPIT`.
