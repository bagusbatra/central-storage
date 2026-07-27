# Design — Panel "Bahan Masuk" + "Buyer" di `index.htm`

Tanggal: 2026-07-27
Halaman: `ZBSP_CS_APP/Page with Flow Logic/index.htm`
Referensi visual: `prototype.html`

## Tujuan
Menambah dua panel di atas kartu KPI pada Dashboard grafis (`index.htm`):
1. **Bahan Masuk** — daftar stok material di Central Storage (Plant 2000 / SLoc 2KCS),
   logika stok **sama persis** dengan klik kartu KPI Central Storage (`dash_detail.htm?sec=2`),
   diperkaya kolom Progres & End Date.
2. **Buyer** — ranking buyer yang punya real stock di 2KCS.

## Scope data
Plant `2000` / SLoc `2KCS` saja. Sumber stok = **MSKA** (SO-stock, `sobkz='E'`, unrestricted `KALAB>0`)
+ **MARD** (free stock, unrestricted `LABST>0`). Sample customer `2000000004` dibuang via VBAK.
Ini identik dengan cabang `sec=2` di `dash_detail.htm`.

## Endpoint baru: `dash_cs.htm`
Satu JSON untuk kedua panel (menghindari logika kembar di dua tempat):

```json
{
  "rows": [
    {"matnr","maktx","so","item","qty","prog","enddate"}
  ],
  "buyers": [
    {"buyer","so_count","mat_count"}
  ]
}
```

### rows (panel Bahan Masuk)
- Satu baris per (matnr, vbeln, posnr) hasil agregasi (COLLECT) MSKA + MARD.
- Baris free-stock (MARD, tanpa SO) tetap ditampilkan: `so`/`item`/`prog`/`enddate` kosong.
- `qty` = qty base UoM (MARA-MEINS), format id (buang nol desimal berlebih) + satuan.
- `prog` = Σ`AFPO-WEMNG` / Σ`AFPO-PSMNG` × 100 (int, cap 100), di-scope
  `kdauf=vbeln AND kdpos=posnr AND matnr=matnr AND pwerk=2000` (AFPO⨝AFKO). Kosong bila tak ada order.
- `enddate` = `MAX(AFKO-GLTRP)` order yang cocok, format `YYYY-MM-DD`. Kosong bila tak ada order.

### buyers (panel Buyer)
- Hanya dari SO-stock rows (free-stock "(stok bebas)" **dikecualikan** dari ranking).
- `so_count` = COUNT DISTINCT vbeln per buyer.
- `mat_count` = COUNT DISTINCT matnr per buyer.
- Urut `mat_count` desc, lalu `so_count` desc.

Pola query & konversi (CONVERSION_EXIT_MATN1_OUTPUT / CUNIT_OUTPUT, FOR ALL ENTRIES batched,
escape JSON `\`, `"`, CR/LF/TAB, `set_header_field` Content-Type JSON) **meniru `dash_detail.htm`/`dash_so.htm`**.

## UI di `index.htm`
- Baris `.cs-row` (flex) **di atas** `.kpi-bar`: **Bahan Masuk** (flex 2) + **Buyer** (flex 1).
- CSS baru mengikuti gaya `.kpi-card`/`.kpi-detail` (plain CSS, **bukan** Tailwind — lingkungan no-CDN).
- **Bahan Masuk**: tabel scroll `max-height:300px`, kolom
  `Material · Deskripsi · No.SO/Item · Qty · Progres (bar+%) · End Date`.
  No.SO memakai class `.so-link` yang sudah ada → `openSo(so, 2, item, mat, false)` (buka side-panel progres SO).
- **Buyer**: tabel `# · Buyer · Total SO · Jenis Material`.
- Keduanya diisi via `fetch('dash_cs.htm')` saat load + **auto-refresh 60 dtk** (interval sendiri).
  Skeleton (`skelRows()`) saat load. Tombol Refresh yang ada ikut memicu `loadCs()`.

## Tidak diubah
Blok ABAP KPI di `index.htm`, `dash_kpi/detail/so/feed.htm`, ticker, drill-down, side-panel SO.
Murni penambahan (endpoint baru + HTML/CSS/JS di index.htm).
