# index2.htm — Detail Komponen aktif + tata letak satu baris

Tanggal: 2026-08-03
Berkas terdampak: `ZBSP_CS_APP/Page with Flow Logic/index2.htm`, `dash_prod.htm`

## Masalah

Tiga hal, semuanya di paruh bawah `index2.htm`:

1. Panel **Sales Order** dan **Detail Komponen** bertumpuk ke bawah, masing-masing
   pendek (320px / 350px). Ruang layar terbuang, data yang terlihat sedikit.
2. Tabel **Detail Komponen** masih memakai `COMPONENT_DATA` — 14 baris dummy
   bernama "Nordic Living" dan "Westfield Home". Tab Dikerjakan/Antri/Selesai
   memfilter data palsu.
3. Kartu SO tidak bisa diklik. Tidak ada cara menyempitkan tabel komponen ke
   satu Sales Order.

## Keputusan yang diambil

| # | Keputusan | Alasan |
|---|---|---|
| D1 | Status komponen dari **konfirmasi operasi (AFRU)**, bukan posisi SLoc | Ditetapkan user. Paling dekat dengan arti "dikerjakan" di lantai produksi |
| D2 | Satu baris = satu **komponen**, bisa dibentangkan | Ditetapkan user |
| D3 | Isi baris bentang = **TAHAP (order)**, bukan VORNR | Lihat "Temuan yang mengubah desain" |
| D4 | Muat ringkasan dulu (400 komponen), rincian saat dibentangkan | Ditetapkan user. Halaman ini pernah timeout; batas wajib ada |
| D5 | Lebar 1fr : 2fr, tinggi kunci 560px | Ditetapkan user |
| D6 | Tab default **Dikerjakan** | Ditetapkan user |

## Temuan yang mengubah desain

`diag_routing.htm` bagian B (dijalankan 2026-07-30 atas SO 10446), dicatat di
`report/CHECKPOINT.md:67` dan `routing_map.htm:12-19`:

> Maksimum **2 operasi per order**; **86,1% order hanya punya 1 operasi**;
> tidak ada order dengan ≥3 operasi. Alur Machining → Edge Banding **bukan**
> routing multi-operasi dalam satu order, melainkan **rangkaian order terpisah**
> — satu order per komponen per tahap.

Dua akibatnya:

- Baris bentang yang diisi VORNR akan berisi satu baris saja pada 86% kasus —
  tidak berguna. Diisi **tahap/order**, ia menjadi peta perjalanan komponen.
- Pemetaan komponen ke center **tidak perlu menebak dari nama work center**.
  `AFKO-DISPO` sudah menyatakannya.

## Model data

**Komponen** = `VBELN + POSNR + MATNR` (aturan tetap halaman ini, lihat memory
`central-storage-index2-scope-rule`). Daftarnya sudah dihitung `part=stock` dan
tersimpan di SHARED BUFFER `indx(zc)` ID `DPRODKM`. Endpoint baru MEMBACANYA —
tidak menembak MSKA untuk kedua kalinya.

**Order komponen**: `AFPO-KDAUF = VBELN`, `AFPO-KDPOS = POSNR`,
`AFPO-MATNR = MATNR` → `AUFNR`, join `AFKO` untuk `AUFPL` dan `DISPO`.
Satu komponen bisa punya beberapa order (satu per tahap).

**Tahap** dari `AFPO-PWERK` + `AFKO-DISPO` — konvensi `routing_map.htm:31-33`,
plant SELALU dipasangkan dengan DISPO:

| seq | Tahap | PWERK | DISPO |
|---|---|---|---|
| 1 | Pembahanan | 1000 | WM1, WM2, PN1, PN2 |
| 2 | **Machining Center** | 2000 | GA1, GA2 |
| 3 | **Edge Banding** | 2000 | EB2 |
| 0 | (lain) | — | selain di atas |

Sanding (SLoc 229K) TIDAK punya DISPO — tidak ada order yang memetakan ke sana.
Tombol center "Edge Banding & Sanding" karena itu hanya mencakup **EB2**. Ini
ditulis apa adanya di kaki tabel, bukan didiamkan.

**Status operasi** — rumus baku, disalin dari `diag_routing.htm:355-365`
(dipakai juga `routing_map.htm` dan `part=ops`). Kalau rumus berubah, ubah di
KEEMPAT tempat:

```
ΣAFRU-LMNGA = 0                        -> antri
0 < ΣLMNGA < AFVV-MGVRG                -> dikerjakan
ΣLMNGA >= MGVRG  atau  AFRU-AUERU='X'  -> selesai
```

Baris `AFRU-STOKZ='X'` (dibatalkan) dibuang dulu; kalau tidak, qty ganda.
AFRU dicocokkan ke operasi lewat `AUFNR + VORNR`.

**Status komponen** = rekap operasi komponen itu **di tahap center yang sedang
dipilih**:

- `tot = 0` → komponen tidak muncul di daftar center itu; dicacah sebagai `nook`
  dan dilaporkan di kaki tabel
- `conf = tot` → **SELESAI**
- `conf > 0` atau `act > 0` → **DIKERJAKAN**
- selain itu → **ANTRI**

`pct = conf * 100 / tot`. Work center aktif = `ARBPL` operasi pertama yang belum
confirmed (urut VORNR); kalau semua sudah confirmed, ARBPL operasi terakhir.
`AFVC-ARBID` → `CRHD-OBJID` (OBJTY='A') → `CRHD-ARBPL`.

## Peringatan yang WAJIB tampil di UI

Angka tabel ini **tidak akan sama** dengan kotak center di atasnya. Kotak center
berbasis **saldo stok MSKA**; tabel ini berbasis **konfirmasi operasi AFRU**.
Keduanya menjawab pertanyaan berbeda. Peringatan ini masuk ke tooltip judul
tabel — jangan dihapus supaya orang tidak menyangka keduanya harus cocok.

## Endpoint

Keduanya di `dash_prod.htm`, mengikuti pola yang sudah ada di sana.

### `?part=komp`

Parameter: `ctr` (`MC` | `EB`, default `MC`), `so`, `item`, `bid` (semuanya
opsional; `so`/`item`/`bid` menyempitkan cakupan).

Batas `lc_maxkmp = 400` komponen bila TIDAK discope; sisanya dicacah dan
dilaporkan lewat `more` — tidak dibuang diam-diam, sama seperti `solist_more`.
Bila discope (`so` atau `bid` terisi), batas dinaikkan ke 2000 dan cache
dilewati.

Cache SHARED BUFFER hanya untuk permintaan TANPA scope: ID `DPRODKPM` (MC) /
`DPRODKPE` (EB), TTL sama 300 detik.

```json
{"ok":1,"more":0,"nook":0,"ctr":"MC","rows":[
  {"so":"0000010446","item":"000010","mat":"30086010","txt":"RANGKA MEJA",
   "bid":"0000012345","buyer":"PT ...","st":"dikerjakan",
   "done":1,"tot":2,"wc":"MC12","pct":50}
],"ms":0}
```

Bila `DPRODKM` belum ada: `{"ok":0,"msg":"jalankan part=stock lebih dulu"}` —
dijawab jujur, bukan dengan nol yang menyesatkan (pola `part=hist`).

### `?part=ops1&so=&item=&mat=`

Rincian SATU komponen: seluruh tahapnya, termasuk Pembahanan di plant 1000 —
perjalanan penuh, bukan hanya center yang dipilih. Tidak di-cache (kecil, dan
hanya diminta saat satu baris dibentangkan).

```json
{"ok":1,"rows":[
  {"seq":1,"stg":"Pembahanan","aufnr":"000001234567","op":"0010",
   "wc":"WM01","st":"selesai","done":50,"need":50}
],"ms":0}
```

## Perubahan di index2.htm

**Tata letak.** Kedua `<section>` dibungkus `.so-detail-row`:
`display:grid; grid-template-columns:1fr 2fr; gap:16px`, turun ke satu kolom di
`max-width:1100px`. `.so-list-container` dan `.table-wrapper` sama-sama dikunci
560px / 470px sehingga dua panel rata.

**Kartu SO dapat diklik.** `selectedSO = {so, item}`; kartu terpilih memakai
kelas `.so-item-box.active` (border oranye, latar `#fffbeb`). Klik lagi untuk
melepas. Memilih SO memicu pengambilan ulang `part=komp` yang discope.

**Tabel.** `COMPONENT_DATA` dummy DIHAPUS seluruhnya. `selectedTab` default
`'dikerjakan'`, kelas `active` di HTML ikut pindah. Baris komponen diklik →
membentang; `part=ops1` diambil sekali lalu disimpan di objek barisnya sehingga
membuka-tutup berikutnya tidak meminta ulang.

**Filter mana yang di server, mana di browser:**

| Filter | Di mana | Alasan |
|---|---|---|
| center (MC/EB) | server | menentukan tahap mana yang dinilai |
| SO + Item | server | agar lepas dari batas 400 |
| buyer | server | agar lepas dari batas 400 |
| tab status | browser | instan, tanpa permintaan baru |
| kotak cari | browser | instan |

**Urutan pemanggilan.** `part=komp` HARUS berjalan setelah `part=stock` selesai
(butuh `DPRODKM`), jadi ia dipanggil di dalam callback `part=stock`, sejajar
dengan `part=hist`.

## Penanganan kegagalan

| Keadaan | Yang ditampilkan |
|---|---|
| `part=komp` gagal / tidak ok | baris "Gagal memuat data komponen" di badan tabel, bukan tabel kosong |
| `DPRODKM` belum ada | "Menunggu data stok…" lalu dicoba ulang sekali setelah `part=stock` |
| `more > 0` | pita kuning di kaki tabel: "Menampilkan 400 komponen pertama; N lainnya tidak dimuat." |
| `nook > 0` | teks kaki: "N komponen tidak punya order produksi di tahap ini." |
| `part=ops1` gagal | baris bentang berisi "Gagal memuat tahap" |

## Verifikasi

Halaman ini BSP ABAP dan hanya bisa dijalankan di server SAP — tidak ada
harness uji lokal. Verifikasi dilakukan user di SE80 setelah aktivasi:

1. `dash_prod.htm?part=stock` dijalankan dulu, lalu `?part=komp` membalas
   `ok:1` dengan `rows` terisi.
2. Jumlah baris tab Dikerjakan + Antri + Selesai = `rows.length`.
3. Klik satu kartu SO → seluruh baris tabel ber-`so` sama dengan kartu itu.
4. Bentang satu baris → `part=ops1` membalas tahap yang urut seq-nya.
5. Ganti center MC ↔ EB → tabel diambil ulang dan `nook` berubah.

## Yang SENGAJA tidak dikerjakan

- Kolom "QTY ROUTING" gaya prototype tidak dipertahankan apa adanya; K4 di
  `ROADMAP-index2-data.md:224` masih terbuka. Kolomnya diisi `op done/tot` +
  work center — informasi yang benar-benar ada.
- Kartu BOTTLENECK tetap dummy. Di luar cakupan permintaan ini.
- Peta Work Center tetap `Math.random()`. Di luar cakupan permintaan ini.
