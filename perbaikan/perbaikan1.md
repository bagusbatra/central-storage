# Perbaikan #1 — Header & Summary Cards

**Target file**: `index2.htm` (UI) dan `dash_prod.htm` (endpoint JSON)
**Environment**: BSP SE80 SAP S/4HANA 1.8.0.9, self-contained (**tanpa** include, class Z terpisah, MIME object, atau CDN eksternal)
**Ruang lingkup**: bagian `main-header` dan `summary-cards` saja. Panel/section lain tidak disentuh.

---

## Konteks singkat (agar Claude Code paham tanpa membaca ulang percakapan)

- `dash_prod.htm` = endpoint JSON, dibagi `part=stock | hist | ops | komp | ops1`. Cache SHARED BUFFER `indx(zc)` TTL 300 dtk. ID cache: `DPRODST` (stock), `DPRODOP` (ops), `DPRODSI` (daftar SO+Item), `DPRODKM` (komponen+posisi).
- `index2.htm` = UI, memanggil `dash_prod.htm?part=...` secara asinkron. Kartu SO/BUYER/CONFIRMED sudah LIVE, sisanya masih DUMMY.
- Cakupan **6 storage location** (WAJIB, ketetapan user):
  - Machining Center: `2KCS` (storage awal), `2261`, `2262`
  - Edge Banding & Sanding: `22E2`, `22E3`, `229K`
- Sample customer `2000000004` selalu dibuang.
- Sumbu filter UI = **BUYER** (bukan SO).
- **Constraint mutlak**: tidak boleh menambah file baru (include/class/MIME/CDN). Semua perubahan **inline** di dalam `index2.htm` atau `dash_prod.htm`.

---

## 1. Header — bar full-bleed, background biru

### Kondisi sekarang
- Lokasi CSS: `index2.htm` baris ~149 (blok `.main-header`).
- Lokasi markup: `index2.htm` baris ~741 (`<header class="main-header">`).
- Tampilan: kartu putih terapung di dalam padding body, warna sama dengan kartu lain → tidak ada pemisah visual.

### Perubahan
Jadikan header **bar edge-to-edge** dengan background biru gelap. Area isi (`summary-cards` dst.) tetap di dalam padding.

**CSS baru** (ganti blok `.main-header` dan sekitarnya):

```css
/* body: hilangkan padding atas supaya header bisa full-bleed.
   Padding samping/bawah dipindah ke wrapper .content. */
body {
    padding: 0;
    /* properti body lain tetap: font-family, color, background, dll. */
}

.content {
    padding: 16px 20px 20px;   /* sama seperti padding body sebelumnya */
    display: flex;
    flex-direction: column;
    gap: 16px;
}

/* HEADER — bar biru full-width */
.main-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    background: #1e40af;              /* Blue-800 */
    color: #ffffff;
    padding: 14px 24px;
    border-radius: 0;                 /* full-bleed, tidak ada radius */
    border: none;
    margin: 0;                        /* rapat ke tepi viewport */
}
.header-left {
    display: flex;
    align-items: center;
    gap: 14px;
}
.logo-box {
    background: #b45309;              /* amber — tetap, kontras bagus di biru */
    color: white;
    width: 40px;
    height: 40px;
    border-radius: 6px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 20px;
}
.main-header h1 {
    font-size: 17px;
    font-weight: 700;
    color: #ffffff;
}
.main-header .subtitle {
    font-size: 9px;
    color: rgba(255, 255, 255, 0.7); /* abu terang di atas biru */
    letter-spacing: 0.5px;
    margin-top: 2px;
}
.header-right {
    text-align: right;
    font-size: 11px;
    color: #ffffff;
}
.flow-info {
    color: rgba(255, 255, 255, 0.75);
    margin-right: 15px;
}
.status-indicator {
    font-weight: 600;
    color: #ffffff;
}
/* Dot hijau tetap terlihat di atas biru — pastikan warna dot cukup terang.
   Kalau var --dot-green terlalu gelap, override lokal di sini. */
.main-header .status-indicator .dot.green {
    background: #4ade80;              /* hijau terang, kontras di biru */
}
```

**Perubahan markup**: bungkus semua elemen setelah `</header>` sampai sebelum `</body>` dengan `<main class="content"> ... </main>`. Jangan pindahkan `<header>` — biarkan di luar `.content` supaya full-bleed.

Struktur akhir:
```html
<body>
    <header class="main-header"> ... </header>
    <main class="content">
        <section class="summary-cards"> ... </section>
        <section class="filter-section"> ... </section>
        <!-- section lain -->
    </main>
    <!-- svg symbol defs, script, dst tetap di posisi asal -->
</body>
```

### Checklist header
- [ ] `body` padding di-nol-kan
- [ ] Wrapper `<main class="content">` dibuat mengelilingi semua section (kecuali header)
- [ ] `.main-header` background `#1e40af`, `border-radius: 0`, `border: none`
- [ ] Teks header (`h1`, `subtitle`, `flow-info`, `status-indicator`) diberi warna putih / rgba putih
- [ ] Dot status di header pakai hijau terang (`#4ade80`)
- [ ] `logo-box` tetap `#b45309` (tidak diubah)

---

## 2. Kartu CONFIRMED — rename + tooltip baru

### Keputusan
- **Definisi tetap** = operasi (AFVC row) yang statusnya selesai (`AUERU='X'` atau `ΣLMNGA ≥ MGVRG`). **Tidak** menambah query baru.
- **Label kartu** diubah dari `CONFIRMED` menjadi `OPERASI SELESAI` — jujur pada apa yang dihitung.
- **Sub-teks** disederhanakan; peringatan pembatasan (`trunc=1`) pindah ke tooltip + ikon warning kecil.
- **Tooltip** ditulis ulang: bahasa mudah, satuan eksplisit, tetap profesional.

### Perubahan pada `index2.htm`

**Markup kartu** (cari `<div class="card-title">CONFIRMED`, ganti seluruh `<div class="card">` untuk CONFIRMED):

```html
<div class="card">
    <div class="card-title">OPERASI SELESAI
        <span class="tip-anchor icon-top-right" data-tip="
            <span class='ct-h'>Operasi Selesai</span>
            <span class='ct-r'>Persentase langkah pengerjaan (<b>operasi</b>) yang sudah dikonfirmasi selesai oleh operator lantai produksi, dihitung dari seluruh operasi milik order produksi yang terkait Sales Order dalam cakupan.</span>
            <span class='ct-r'><b>Satuan</b>: operasi (satu operasi = satu langkah pengerjaan di satu work center). Satu komponen bisa punya banyak operasi berurutan.</span>
            <span class='ct-r'><b>Status per operasi</b>:<br>
            &bull; Selesai &mdash; qty konfirmasi &ge; qty target, atau operator menandai final<br>
            &bull; Sedang dikerjakan &mdash; sudah ada qty konfirmasi tapi belum penuh<br>
            &bull; Antre &mdash; belum ada konfirmasi sama sekali</span>
            <span class='ct-src'>AFRU vs AFVV &middot; baris STOKZ=X dibuang</span>
            <span class='ct-warn'>Angka ini berbicara tentang <b>langkah pengerjaan</b>, bukan <b>komponen yang selesai jadi</b>. Satu komponen dengan 5 operasi baru selesai jika kelimanya selesai.</span>
            <span class='ct-warn' id='tip-conf-trunc' style='display:none'>⚠️ Order melampaui batas 1.500 &mdash; persentase dihitung dari 1.500 order teratas. Indikatif, bukan final.</span>
        "><svg class="ic"><use xlink:href="#fa-circle-check"></use></svg></span>
    </div>
    <div class="card-value color-green">
        <span id="kpi-conf">-</span> <span class="unit">%</span>
        <span id="kpi-conf-warn" class="trunc-warn" style="display:none" title="Data dibatasi — lihat tooltip">⚠</span>
    </div>
    <div class="card-sub" id="kpi-conf-sub">memuat&hellip;</div>
</div>
```

**CSS tambahan** (letakkan bersama CSS card lainnya):
```css
.trunc-warn {
    font-size: 12px;
    color: #d97706;
    margin-left: 4px;
    cursor: help;
}
```

**JavaScript** — pada fungsi yang meng-handle response `part=ops`:
- Sub-teks baru: `` `${conf} dari ${total} operasi` `` (contoh: `648 dari 1.989 operasi`)
- Kalau `data.trunc === 1`:
  - Tampilkan `#kpi-conf-warn` (`style.display = 'inline'`)
  - Tampilkan `#tip-conf-trunc` di tooltip (`style.display = 'block'`)
- Kalau `data.trunc === 0`: sembunyikan keduanya.

### Perubahan pada `dash_prod.htm`
**Tidak ada perubahan** di endpoint. Semua data (`conf`, `total`, `trunc`) sudah tersedia di response `part=ops`.

### Checklist CONFIRMED
- [ ] Label kartu diganti `OPERASI SELESAI`
- [ ] Tooltip ditulis ulang sesuai teks di atas
- [ ] Sub-teks disederhanakan (hanya `X dari Y operasi`)
- [ ] Warning `trunc` pindah ke ikon ⚠️ + baris di tooltip
- [ ] JS meng-handle `data.trunc` untuk show/hide warning

---

## 3. Kartu DI PRODUKSI — sub-teks dua baris + tooltip baru

### Keputusan
- **Definisi tetap** = komponen (SO+Item+Material unik) yang punya stok di `2261`, `2262`, `22E2`, `22E3`, `229K` (SLoc proses, di luar `2KCS`).
- **Basis**: saldo stok MSKA saat ini, sudah dihitung di `part=stock`. Tidak ada query baru.
- **Sub-teks dua baris**:
  - Baris 1: rasio thd total komponen — `dari N komp (P%)`
  - Baris 2: breakdown per center — `MC: A · EB: B`

### Perubahan pada `dash_prod.htm` (endpoint `part=stock`)

Tambahkan field baru di response JSON. Di kode saat ini variabel-variabel ini **sudah dihitung** tapi belum di-expose:

- `mcq` (`lv_mc_q`) — komp masih di 2KCS = queue Machining
- `mcp` (`lv_mc_p`) — komp di 2261/2262 = di Machining
- `ebq` (`lv_eb_q`) — komp yang sudah lewat MC, masuk queue EB
- `ebp` (`lv_eb_p`) — komp di 22E2/22E3/229K = di EB
- `komp` — total komponen unik di cakupan

`prod` (jumlah komp di MC + EB) sudah dikirim, tinggal dipakai UI.

**Pastikan field-field ini sudah ada di string JSON akhir** (cari blok `lv_json = ...` di `part=stock`, sekitar baris 1180-1201). Kalau `mcp`, `ebp`, `komp` sudah termasuk, tidak perlu perubahan endpoint. Kalau belum, tambahkan.

### Perubahan pada `index2.htm`

**Markup kartu** (ganti kartu DI PRODUKSI):

```html
<div class="card">
    <div class="card-title">DI PRODUKSI
        <span class="tip-anchor icon-top-right" data-tip="
            <span class='ct-h'>Komponen di Lantai Produksi</span>
            <span class='ct-r'>Jumlah komponen unik yang stok fisiknya sedang berada di area proses (bukan di storage awal 2KCS). Menunjukkan seberapa banyak barang yang sudah bergerak dan sedang dikerjakan.</span>
            <span class='ct-r'><b>Satuan</b>: komponen unik (kombinasi Sales Order + Item + Material). Material yang sama muncul di dua SO dihitung dua kali; material yang stoknya terpecah antar SLoc dihitung sekali.</span>
            <span class='ct-r'><b>Yang masuk hitungan</b>: komponen yang punya stok di 2261, 2262 (Machining), 22E2, 22E3, 229K (Edge Banding &amp; Sanding). Komponen yang stoknya terpecah &mdash; sebagian masih 2KCS, sebagian sudah bergerak &mdash; tetap dihitung di sini. Begitu ada bagian yang jalan, komponen itu bukan lagi diam menunggu.</span>
            <span class='ct-r'><b>Yang tidak masuk</b>: komponen yang seluruh stoknya masih di 2KCS (belum bergerak sama sekali).</span>
            <span class='ct-src'>Saldo stok saat ini MSKA</span>
        "><svg class="ic"><use xlink:href="#fa-gear"></use></svg></span>
    </div>
    <div class="card-value color-blue" id="kpi-prod">-</div>
    <div class="card-sub" id="kpi-prod-sub">memuat&hellip;</div>
    <div class="card-sub card-sub-2" id="kpi-prod-sub2">&nbsp;</div>
</div>
```

**CSS tambahan**:
```css
.card-sub-2 {
    font-size: 10px;
    color: var(--text-muted);
    margin-top: 2px;
}
```

**JavaScript** — pada handler response `part=stock`:
- `#kpi-prod` = `data.prod`
- `#kpi-prod-sub` = `` `dari ${data.komp} komp (${pct}%)` `` di mana `pct = Math.round(data.prod * 100 / data.komp)`
- `#kpi-prod-sub2` = `` `MC: ${data.mcp} · EB: ${data.ebp}` ``

Format angka ribuan pakai separator titik (`1.234`) sesuai gaya lokal — kalau helper `fmt()` sudah ada di file, pakai itu.

### Checklist DI PRODUKSI
- [ ] Field `komp`, `mcp`, `ebp` sudah ada di JSON `part=stock` (verifikasi)
- [ ] Sub-teks baris 1: `dari N komp (P%)`
- [ ] Sub-teks baris 2: `MC: A · EB: B`
- [ ] Tooltip ditulis ulang sesuai teks di atas
- [ ] CSS `.card-sub-2` ditambahkan

---

## 4. Kartu SELESAI PROD. — redefinisi (Opsi B, Tafsir X)

### Definisi bisnis
Komponen dinyatakan **selesai produksi** kalau **DUA syarat** terpenuhi:

1. **Order delivered penuh** — di AFPO, `WEMNG ≥ PSMNG` (qty diterima ≥ qty target).
2. **Stok kosong di SEMUA 6 SLoc** — tidak ada saldo lagi di `2KCS`, `2261`, `2262`, `22E2`, `22E3`, `229K`.

Komponen semacam ini artinya sudah keluar dari sistem yang kita monitor — lanjut ke jalur berikutnya.

### Perubahan pada `dash_prod.htm` (endpoint `part=stock`)

Tambahkan **satu SELECT** ke AFPO+AFKO, letakkan **setelah** `lt_stok` dan `lt_vbak` sudah terbentuk (sekitar baris 850–880, sebelum blok agregasi buyer). Alasan lokasi: `lt_stok` dan `lt_vbak` sudah in-memory, jadi tidak perlu query ulang.

**Skema penambahan**:

```abap
" ===== SELESAI PROD. — komponen yang delivered penuh & sudah lepas dari 6 SLoc
"
"  Definisi (ketetapan user 2026-08-03, Opsi B / Tafsir X):
"    komponen selesai = AFPO.WEMNG >= AFPO.PSMNG
"                       DAN tidak ada saldo di 6 SLoc cakupan.
"
"  Kenapa 6 SLoc (termasuk 2KCS): kalau order sudah dipenuhi tapi masih
"  ada sisa di 2KCS, itu sisa bahan yang tidak jadi dipakai — bukan
"  produksi yang sedang berjalan, tapi juga bukan "selesai bersih". Kita
"  pilih ketat: baru dihitung selesai kalau bersih dari SEMUA cakupan.
"
"  Filter dispo GA1/GA2/EB2 sama dengan part=ops — memastikan hanya order
"  yang lewat jalur produksi yang kita monitor.
"
"  Perkiraan beban: SO buyer nyata ~200-300, jadi range KDAUF sempit.
"  Satu SELECT AFKO+AFPO dengan filter ketat, diperkirakan < 1 dtk.

TYPES: BEGIN OF ty_afpo_done,
         kdauf TYPE afpo-kdauf,
         kdpos TYPE afpo-kdpos,
         matnr TYPE afpo-matnr,
       END OF ty_afpo_done.
DATA: lt_afpo_done TYPE STANDARD TABLE OF ty_afpo_done WITH DEFAULT KEY,
      ls_afpo_done TYPE ty_afpo_done.

" Range SO nyata (semua vbeln di lt_stok, sudah bebas sample customer)
DATA: lr_vbeln TYPE RANGE OF vbak-vbeln,
      ls_vbeln LIKE LINE OF lr_vbeln.
DATA lt_vbeln_uniq TYPE STANDARD TABLE OF vbak-vbeln WITH DEFAULT KEY.
LOOP AT lt_stok ASSIGNING <st>.
  APPEND <st>-vbeln TO lt_vbeln_uniq.
ENDLOOP.
SORT lt_vbeln_uniq. DELETE ADJACENT DUPLICATES FROM lt_vbeln_uniq.
LOOP AT lt_vbeln_uniq INTO DATA(lv_vb).
  ls_vbeln-sign = 'I'. ls_vbeln-option = 'EQ'. ls_vbeln-low = lv_vb.
  APPEND ls_vbeln TO lr_vbeln.
ENDLOOP.

DATA lv_done_real TYPE i.
IF lr_vbeln IS NOT INITIAL.
  SELECT a~kdauf a~kdpos a~matnr
    FROM afko AS k INNER JOIN afpo AS a ON a~aufnr = k~aufnr
    INTO TABLE lt_afpo_done
    WHERE a~kdauf IN lr_vbeln
      AND a~pwerk = lc_werks
      AND k~dispo IN ( 'GA1', 'GA2', 'EB2' )
      AND a~psmng > 0
      AND a~wemng >= a~psmng.

  " Buang yang MASIH punya stok di 6 SLoc — berarti belum selesai bersih.
  " lt_stok sudah sorted by vbeln posnr matnr lgort -> pakai BINARY SEARCH.
  DATA lv_still_in_stok TYPE abap_bool.
  LOOP AT lt_afpo_done INTO ls_afpo_done.
    lv_still_in_stok = abap_false.
    READ TABLE lt_stok TRANSPORTING NO FIELDS
      WITH KEY vbeln = ls_afpo_done-kdauf
               posnr = ls_afpo_done-kdpos
               matnr = ls_afpo_done-matnr
      BINARY SEARCH.
    IF sy-subrc = 0.
      lv_still_in_stok = abap_true.
    ENDIF.
    IF lv_still_in_stok = abap_false.
      lv_done_real = lv_done_real + 1.
    ENDIF.
  ENDLOOP.
ENDIF.
```

**Expose ke JSON** — tambahkan field `done_real` ke string `lv_json`:
```abap
" ... string JSON yang sudah ada ...
&& ',"done_real":' && |{ lv_done_real }|
" ... lanjutan ...
```

### Perubahan pada `index2.htm`

**Markup kartu** (ganti kartu SELESAI PROD.):

```html
<div class="card">
    <div class="card-title">SELESAI PROD.
        <span class="tip-anchor icon-top-right" data-tip="
            <span class='ct-h'>Komponen Selesai Produksi</span>
            <span class='ct-r'>Komponen yang order produksinya sudah dipenuhi penuh (qty diterima &ge; qty target) DAN stoknya sudah tidak ada lagi di enam SLoc yang kita pantau &mdash; artinya barangnya sudah lanjut ke jalur berikutnya di luar sistem ini.</span>
            <span class='ct-r'><b>Satuan</b>: komponen unik (Sales Order + Item + Material).</span>
            <span class='ct-r'><b>Dua syarat harus terpenuhi</b>:<br>
            1. <b>Order delivered penuh</b> &mdash; AFPO menunjukkan qty diterima (WEMNG) sudah mencapai atau melewati qty target (PSMNG).<br>
            2. <b>Stok kosong di 6 SLoc</b> &mdash; tidak ada saldo lagi di 2KCS, 2261, 2262, 22E2, 22E3, 229K.</span>
            <span class='ct-r'><b>Kenapa tidak semua komponen muncul di sini</b>: tidak semua komponen disiplin melewati enam SLoc ini &mdash; beberapa langsung diproses di jalur lain. Kartu ini hanya menghitung yang MEMANG lewat sini dan sudah keluar bersih.</span>
            <span class='ct-src'>AFKO + AFPO (WEMNG vs PSMNG), diverifikasi dengan MSKA (stok kosong di cakupan)</span>
        "><svg class="ic"><use xlink:href="#fa-square-check"></use></svg></span>
    </div>
    <div class="card-value color-green" id="kpi-done">-</div>
    <div class="card-sub" id="kpi-done-sub">memuat&hellip;</div>
</div>
```

**JavaScript** — pada handler response `part=stock`:
- `#kpi-done` = `data.done_real`
- `#kpi-done-sub` = `komponen keluar dari 6 SLoc`

### Checklist SELESAI PROD.
- [ ] Blok ABAP baru ditambahkan di `part=stock` (setelah `lt_stok` & `lt_vbak` siap, sebelum agregasi buyer)
- [ ] Field `done_real` ditambahkan ke JSON output
- [ ] Field lama `done` (dari `at_sd` = stok di 229K) boleh dihapus, atau **dipertahankan** sebagai field cadangan (rekomendasi: pertahankan sementara untuk perbandingan, hapus setelah user PPIC memverifikasi angka baru masuk akal)
- [ ] Tooltip ditulis ulang sesuai teks di atas
- [ ] JS pakai `data.done_real` (bukan `data.done`)
- [ ] Sub-teks: `komponen keluar dari 6 SLoc`

---

## 5. Kartu BOTTLENECK — pending

Tidak ada perubahan pada sesi ini. Biarkan sebagai dummy (`EBS-13` / `Edge Band & Sand 13`). Akan dibahas terpisah.

---

## Ringkasan file yang disentuh

| File | Bagian | Jenis perubahan |
|---|---|---|
| `index2.htm` | CSS `.main-header` + sekitarnya | Rewrite (bar biru full-bleed) |
| `index2.htm` | `<body>`, wrapper `<main class="content">` | Restrukturisasi |
| `index2.htm` | CSS: tambahan `.trunc-warn`, `.card-sub-2` | Tambah |
| `index2.htm` | Markup kartu CONFIRMED, DI PRODUKSI, SELESAI PROD | Rewrite |
| `index2.htm` | JS handler `part=stock` & `part=ops` | Update mapping field & sub-teks |
| `dash_prod.htm` | `part=stock` blok baru SELESAI PROD | Tambah 1 SELECT + hitung `lv_done_real` |
| `dash_prod.htm` | String JSON `part=stock` | Tambah field `done_real` (verifikasi juga `komp`, `mcp`, `ebp` ada) |

## Yang **TIDAK** boleh berubah pada sesi ini

- Cakupan 6 SLoc (2KCS, 2261, 2262, 22E2, 22E3, 229K)
- Filter sample customer `2000000004`
- Batas `lc_maxord = 1500`, `lc_maxso = 500`, `lc_maxkmp = 400`, `lc_maxkm2 = 2000`
- TTL cache 300 dtk & mekanisme SHARED BUFFER `indx(zc)`
- Struktur `part=stock | hist | ops | komp | ops1`
- Kartu BUYER, SALES ORDER (definisi sudah sesuai, tidak disentuh)
- Section FILTER BUYER, WIP per Center, daftar SO, tabel Detail Komponen
- Kartu BOTTLENECK (masih dummy)

## Verifikasi pasca-perubahan

1. Header tampak bar biru penuh dari kiri ke kanan, teks putih terbaca jelas
2. Kartu CONFIRMED menampilkan `X dari Y operasi`; kalau ada `trunc`, ikon ⚠️ muncul di samping nilai
3. Kartu DI PRODUKSI menampilkan dua baris sub-teks (rasio + MC/EB)
4. Kartu SELESAI PROD. menampilkan angka baru (`done_real`) dan sub-teks `komponen keluar dari 6 SLoc`. Bandingkan sebentar dengan angka lama (dari `data.done`) untuk sanity check — angka baru biasanya lebih besar
5. Cache dibersihkan setidaknya sekali dengan `?fresh=1` untuk memastikan cache lama tidak menampilkan hasil basi
6. Buka DevTools Network — pastikan tidak ada request ke domain luar (CDN)
7. Buka source view di SE80 — pastikan file yang berubah hanya `index2.htm` dan `dash_prod.htm`, tidak ada file baru
