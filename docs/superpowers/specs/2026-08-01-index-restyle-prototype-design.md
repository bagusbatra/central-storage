# Restyle `index.htm` ke bahasa visual `reference/prototype-ui`

Tanggal: 2026-08-01
Status: disetujui, siap dikerjakan

## Tujuan

`index.htm` (Central Storage Dashboard) memakai bahasa visual yang sama dengan
prototipe di `reference/prototype-ui`, sehingga sekeluarga dengan `index2.htm`
yang sudah lebih dulu diporting dari prototipe yang sama.

**Restyle, bukan restrukturisasi.** Seluruh isi dan fitur `index.htm` tetap:
7 kartu KPI stok per SLoc, panel Bahan Masuk / Buyer / Sales Order, drill-down
`kpi-detail`, modal SO Item, panel geser SO, dan ticker pergerakan barang.
Yang berubah hanya lapisan presentasi.

## Keputusan yang sudah diambil

1. **Cakupan**: restyle saja — isi & fitur tidak diubah.
2. **File**: `index.htm` saja. `monitoring.htm` menyusul di putaran terpisah
   setelah bahasa visualnya terbukti pas.
3. **Aksen merek**: amber `#b45309` menggantikan biru sebagai warna merek.
   Biru `#2563eb` turun pangkat jadi warna status (progress bar, tautan,
   focus ring).

## Batasan yang menentukan pendekatan

- `MIMEs/css/style.css` (699 baris) **dipakai bersama** oleh `index.htm`,
  `monitoring.htm`, dan `diag_routing.htm`. Di sanalah `.header-bar`,
  `.navbar`, `body`, `.filter-btn`, `.legend-item` didefinisikan. File itu
  **tidak boleh disentuh** — dua halaman lain akan ikut berubah.
- Ada tabrakan nama antara prototipe dan `style.css`: `.filter-btn` dan
  `.legend-item` sudah terpakai dengan arti berbeda.
- Prototipe memuat Font Awesome dari CDN. **Tidak tersedia di jaringan SAP.**
  Ikon harus inline SVG, seperti pola `.ic` yang sudah dipakai `index.htm`.
- `index.htm` berisi tag ABAP `<%= %>` sehingga tidak bisa dibuka langsung
  di browser.

## Pendekatan

`index.htm` **sudah punya** blok CSS ber-scope halaman di baris 290–460,
bertajuk *"REDESAIN Production Pipeline (scope: index.htm)"*, lengkap dengan
lapisan token `:root` sendiri dan ~90 aturan turunan yang memang ditulis untuk
menang atas `css/style.css` tanpa mengubahnya.

Pekerjaan ini **menyetel ulang lapisan token itu dan menambah aturan komponen
di bawahnya**. Karena blok itu inline di `index.htm`, scoping sudah terjamin —
tidak perlu kelas `body.ui-proto` maupun stylesheet baru.

Alternatif yang ditolak:

- **Mengedit `MIMEs/css/style.css` langsung** — efek samping ke `monitoring.htm`
  dan `diag_routing.htm`, bertentangan dengan keputusan #2.
- **File `MIMEs/css/proto.css` terpisah** — perlu objek MIME baru diangkut ke
  SAP plus disiplin cache-buster `?r=`, tanpa keuntungan nyata dibanding inline
  yang sudah jadi pola repo.

## Rancangan per bagian

### 1. Lapisan token (baris 293–300)

Nama variabel **dipertahankan** supaya ~90 aturan turunan ikut berubah tanpa
disentuh satu per satu. Hanya nilainya yang diganti.

| Token | Sekarang | Jadi | Asal di prototipe |
|---|---|---|---|
| `--canvas` | `#E9EDF3` | `#f0f4f8` | `--bg-main` |
| `--ink` | `#1B2430` | `#334155` | `--text-main` |
| `--muted` | `#6B7482` | `#64748b` | `--text-muted` |
| `--faint` | `#98A2B2` | `#94a3b8` | — |
| `--hair` | `#E1E6EE` | `#e2e8f0` | `--border-color` |
| `--hair2` | `#EEF1F6` | `#f1f5f9` | garis baris tabel |
| `--primary` | `#2F6FED` | `#2563eb` | `--color-blue` |
| `--good` | `#16A34A` | `#10b981` | `--color-green` |
| `--warn` | `#D97706` | `#f59e0b` | `--color-orange` |
| `--crit` | `#DC2626` | `#ef4444` | `--color-red` |
| `--cs-shadow` | 2 lapis bayangan | `none` | prototipe rata, border 1px saja |

Token baru: `--brand:#b45309`, `--brand-soft:#fef3c7`, `--radius:8px`,
`--th-bg:#f8fafc`.

Tujuh warna tahap (`--s-bahan … --s-qi`) **tetap tidak diubah**. Prototipe
tidak punya padanannya, dan warna itu memikul informasi nyata: identitas 7
SLoc, dipakai ulang pada bar `.sm-cell` di modal SO Item. Menyeragamkannya
akan menghapus makna, bukan menyamakan tampilan.

### 2. Rangka halaman

- `body`: `padding:16px`, `font-size:13px`, `background:var(--canvas)`.
- `.content`: `padding:0`, `max-width:1400px`, `margin:0 auto`,
  `display:flex; flex-direction:column; gap:16px`.
  Prototipe mengatur ritme vertikal lewat `gap`, bukan `margin-bottom` per
  blok; margin lama pada `.cs-row`, `.kpi-bar`, `.kpi-detail` dinolkan.

### 3. Header & navbar

`.header-bar` berubah dari pita biru tua *full-bleed* menjadi kartu putih:
border 1px `--hair`, radius `--radius`, padding `12px 20px`, tanpa bayangan.
`display:table` diganti `display:flex` (dan `.header-title` / `.header-user`
dari `table-cell` ke item flex).

Isi header mengikuti `.main-header` prototipe:

- `logo-box` 36×36, `background:var(--brand)`, radius 6px, ikon pabrik inline SVG
- `h1` 16px / 700
- subtitle 9px, uppercase, `letter-spacing:.5px`, `--muted`

`.header-user` disetel ulang agar terbaca di latar terang: pil abu
(`#f1f5f9`) dengan teks `--ink`, bukan putih-transparan di atas biru.

`.navbar` jadi bilah tab: latar transparan, aktif = teks `--brand`, latar
`--brand-soft`, garis bawah `--brand`.

### 4. Tujuh kartu KPI

- `.kpi-bar`: `flex-wrap` → `display:grid; grid-template-columns:repeat(7,1fr);
  gap:12px`. (Prototipe pakai grid 6 kolom; di sini 7 kartu.)
- `.kpi-card`: padding 12px, radius `--radius`, border 1px `--hair`, tanpa
  bayangan. Hover tidak lagi mengangkat kartu (`transform:translateY` dibuang);
  cukup border menggelap — prototipe tidak memakai efek angkat.
- `.kpi-label` 10px/600, `.kpi-value` 24px/700, `.kpi-cap` 10px,
  `.kpi-track` tinggi 6px radius 3px.
- Chip warna `::before` **tetap**. Itu padanan informatif dari
  `.icon-top-right` prototipe, dan menandai tahap SLoc.

### 5. Tabel & panel

Satu anatomi tabel prototipe (`.component-table`) diterapkan ke keempat tabel
yang ada — `.cs-panel`, `.kpi-detail`, `.so-table`, `.sm-dtab`:

- `th`: latar `--th-bg`, 10px/600, `--muted`, sticky, border-bottom `--hair`
- `td`: 11px, padding `10px 12px`, border-bottom `--hair2`

`.cs-panel` jadi kartu rata: border 1px `--hair`, radius `--radius`, tanpa
bayangan.

### 6. Badge & kontrol

- `.cs-days`, `.soi-st` mengikuti geometri `.status-badge` prototipe:
  padding `3px 8px`, radius 4px, 10px, border 1px sewarna.
- `.kpi-refresh-btn`, `.cs-pg-btn`, `.dd-search`, `.so-search`, `.dd-f select`,
  `.cs-itembtn`: 11px, radius 4px, border `--hair`; focus ring biru
  (`--primary`).
- `.cs-fchip` mengikuti `.filter-btn.active` prototipe: latar `--brand-soft`,
  border `#d97706`, teks `--brand`.

### 7. Ticker & modal

Ticker **tetap gelap** (`#0f172a`). Prototipe tidak punya elemen ini, dan
kontras gelap itulah yang membuatnya terbaca sebagai bilah sistem yang
menempel di dasar layar. Hanya label kiri diganti dari `#1e3a8a` ke
`--brand` agar sewarna merek.

`.soi-modal` dan `.so-panel`: radius diturunkan ke `--radius`, header latar
`--th-bg`, seluruh border memakai token.

## Di luar cakupan

- `MIMEs/css/style.css`
- `monitoring.htm`, `diag_routing.htm`, `index2.htm`
- Endpoint `dash_cs.htm`, `dash_detail.htm`, `dash_feed.htm`, `dash_kpi.htm`
  (JSON murni, nol markup)
- Seluruh logika ABAP dan query
- Seluruh perilaku JavaScript

Perubahan markup **hanya** di dalam `.header-bar` (logo-box + subtitle).
Sisanya murni CSS — panel yang dirakit JavaScript ikut berubah tanpa disentuh,
sehingga tidak ada risiko memutus AJAX.

## Verifikasi

Repo ini tidak punya test runner, dan `index.htm` tidak bisa dibuka langsung
di browser karena berisi tag `<%= %>`.

Verifikasi dilakukan lewat **harness pratinjau statis** di direktori scratchpad:
salinan `index.htm` dengan tag ABAP diganti angka contoh dan respons `dash_*`
dipalsukan, sehingga hasilnya bisa dilihat sebagai gambar sebelum diaktifkan di
SAP. Harness tidak masuk repo.

Cek yang harus lolos:

1. Header tampil sebagai kartu putih dengan logo-box amber; dropdown user masih
   terbuka saat diklik.
2. Tujuh kartu KPI sebaris dalam grid, chip warna tahap masih terlihat berbeda
   satu sama lain.
3. Panel Bahan Masuk / Buyer / Sales Order terisi, dasar Bahan Masuk dan Sales
   Order masih sejajar (perilaku `--cs-h-buyer` / `--cs-h-so` tidak rusak).
4. Klik kartu KPI membuka `kpi-detail`; tabelnya memakai anatomi baru.
5. Ticker tetap menempel di dasar layar dan tidak menutupi konten.
6. `monitoring.htm` dan `diag_routing.htm` tidak berubah sama sekali —
   dipastikan lewat `git diff` yang hanya menyentuh `index.htm`.
