# Rekomendasi Refaktor `index.htm` (Pelacakan)

> Analisis pemecahan kode `ZBSP_CS_APP/Page with Flow Logic/index.htm` (1903 baris)
> agar lebih ringkas & mudah di-maintain, tetap 100% jalan di SE80.
> Dibuat: 2026-07-21

## Peta isi `index.htm` saat ini

| Blok | Baris | ± | Catatan |
|---|---|---|---|
| Deklarasi TYPES/DATA/CONSTANTS | 53–206 | ~150 | 5 struktur + banyak tabel |
| Input + validasi SO/Item | 209–273 | ~65 | |
| Query utama AFPO⨝AFKO + MAKT + BOM STPO | 275–370 | ~95 | |
| **Riwayat MSEG/MKPF (pairing OUT+IN)** | 372–532 | ~160 | logika paling berat |
| Stok MSKA | 534–605 | ~70 | |
| Parse textarea transfer | 611–788 | ~177 | |
| Eksekusi BAPI_GOODSMVT_CREATE | 790–962 | ~172 | |
| HTML head/style | 969–997 | ~30 | |
| **Tab Pembahanan** | 1069–1163 | ~95 | |
| **Tab Produksi** | 1165–1259 | ~95 | **hampir identik dgn Pembahanan** |
| Tab Riwayat / Stok / Info | 1261–1467 | ~205 | |
| Form TP kanan + Modal TP | 1472–1711 | ~240 | |
| JavaScript | 1713–1901 | ~190 | |

Total kira-kira: **~965 baris ABAP** + **~745 baris HTML** + **~190 baris JS**
dalam satu objek page. Itu yang membuatnya berat dibuka & di-maintain di SE80.

## Rekomendasi, diurut dari dampak terbesar

BSP menyediakan tiga mekanisme "pecah kode" yang tetap 100% jalan di SE80.
Diurutkan berdasar manfaat:

### 1. Pindahkan logika ABAP ke method class global (dampak terbesar) ⭐

~965 baris ABAP flow logic sebenarnya adalah *data-gathering* murni yang bisa
dipindah ke class `ZCL_CS_UTIL` (atau class baru `ZCL_CS_PELACAKAN`). Flow logic
di page tinggal jadi **pemanggilan method** — perkiraan turun dari ~965 baris
menjadi **~40–60 baris**.

Contoh bentuk akhir flow logic page:

```abap
lt_ord     = zcl_cs_pelacakan=>get_orders( io_so = lv_so io_item = lv_item ).
lt_bomcomp = zcl_cs_pelacakan=>get_bom( lt_ord ).
lt_hist    = zcl_cs_pelacakan=>get_history( io_so = lv_so io_item = lv_item ).
lt_stok    = zcl_cs_pelacakan=>get_stock( io_so = lv_so io_item = lv_item ).
```

**Method yang diusulkan:** `get_orders`, `get_bom`, `get_history` (bungkus seluruh
pairing MSEG baris 372–532), `get_stock`, `parse_transfer_list`,
`execute_posting` (bungkus BAPI baris 790–962). Struktur `ty_ord`,
`ty_hist_pair`, `ty_stok`, dst. jadi TYPES publik class.

**Kenapa ini yang paling penting:** komentar di file (baris 22–24) mencatat
`pelacakan.htm` **duplikat** isi halaman ini, dan *"Perbaikan bug WAJIB diterapkan
ke KEDUANYA, kalau tidak keduanya menyimpang diam-diam."* Kalau logika pindah ke
class, **kedua page memanggil method yang sama** — duplikasi hilang dan tidak
mungkin lagi menyimpang. Ini menyelesaikan masalah nyata, bukan sekadar kosmetik.

Repo sudah menuju arah ini: `ZBSP_CS_APP_V2/classes/ZCL_CS_SO_TRACER.abap`
(840 baris) adalah ekstraksi logika tracer dengan pola yang sama. Pola sudah
terbukti di codebase ini.

**Biaya runtime:** dapat diabaikan — SELECT-nya sama persis, cuma dibungkus
method. Justru lebih optimal karena bisa dites & di-reuse.

### 2. Pecah HTML jadi BSP Page Fragment via `<%@ include %>`

Tiap tab dijadikan **Page Fragment** (tipe page "Page Fragment" di dalam aplikasi
BSP yang sama), lalu di-include:

```abap
<%@ include file="tab_orders.htm" %>
<%@ include file="tab_history.htm" %>
<%@ include file="modal_transfer.htm" %>
```

Fragment ikut melihat semua variabel page (`lt_ord`, `ls_hist`, dll.) karena
include-nya *compile-time inlining*.

**Poin penting — hilangkan duplikasi tab:** Tab Pembahanan (1069–1163) dan
Produksi (1165–1259) **nyaris identik**; bedanya cuma `pwerk = lc_werks_1000` vs
`lc_werks_2000` dan teks empty-state. Keduanya (~190 baris) bisa jadi **satu
fragment** yang dipanggil dua kali dengan variabel plant di-set sebelum include.
Langsung hemat ~95 baris + hilang satu sumber bug ganda.

**Biaya runtime: NOL.** Fragment di-*inline* saat generate — kode ter-generate
identik dengan sekarang. Tidak ada request tambahan, tidak ada overhead.

### 3. Eksternalkan JS (dan CSS inline) ke MIME object

~190 baris JS (baris 1713–1901) tidak mengandung ABAP sama sekali → pindahkan ke
`MIMEs/js/pelacakan.js`, panggil dengan `<script src="js/pelacakan.js"></script>`.
Blok `<style>` mv-badge (976–996) pindah ke `css/style.css`.

**Ini malah lebih cepat**, bukan cuma lebih pendek: file JS/CSS di-cache browser,
HTML yang dikirim tiap request jadi lebih kecil.

## Target struktur akhir

```
ZCL_CS_PELACAKAN (class baru)   ← ~900 baris logika (dipakai index.htm & pelacakan.htm)
index.htm                        ← ~250 baris (flow logic ~50 + shell HTML + include)
  ├─ <%@ include tab_orders.htm    %>   ← 1 fragment, dipanggil 2×
  ├─ <%@ include tab_history.htm   %>
  ├─ <%@ include tab_stock.htm     %>
  ├─ <%@ include tab_info.htm      %>
  ├─ <%@ include form_transfer.htm %>
  └─ <%@ include modal_transfer.htm%>
MIMEs/js/pelacakan.js            ← ~190 baris JS
```

Perkiraan: page `index.htm` sendiri turun dari **1903 → ~250 baris**, tiap
fragment 80–160 baris, dan bonus terbesar `pelacakan.htm` ikut ramping karena
berbagi class yang sama.

## Catatan penting / gotcha

- **Fragment vs class — beda tujuan.** Fragment cuma memecah *tampilan* (2 file
  BSP masih punya HTML duplikat masing-masing). Yang benar-benar menyembuhkan
  masalah "dua file menyimpang" adalah **class (poin 1)**. Kalau hanya sempat
  satu, pilih poin 1.
- **Fragment harus di aplikasi BSP yang sama** dan bertipe "Page Fragment" (tanpa
  flow logic sendiri) — variabel page induk otomatis terlihat.
- **Urutan aktivasi di SE80:** class dulu (`ZCL_CS_PELACAKAN`) → aktifkan &
  assign ke package/transport yang sama → baru page & fragment. Sama seperti
  catatan deployment `ZCL_CS_UTIL` yang sudah ada.
- **Prioritas realistis:** #2 dan #3 cepat & berisiko rendah (murni pindah teks).
  #1 paling berdampak tapi perlu tes ulang query. Urutan kerja yang disarankan:
  **#3 → #2 → #1**.
