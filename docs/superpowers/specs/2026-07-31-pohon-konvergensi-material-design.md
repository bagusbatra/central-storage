# Pohon Konvergensi Material di Peta Perjalanan SO

Tanggal: 2026-07-31
Halaman terdampak: `ZBSP_CS_APP/Page with Flow Logic/routing_map.htm`
Objek baru: class `ZCL_CS_PEG`

## 1. Masalah

`routing_map.htm` saat ini menggambar perjalanan komponen sebagai rantai stasiun
lurus: satu komponen bergerak dari Pembahanan ke Sanding tanpa berubah jumlah.
Kenyataannya material **menyusut lewat penggabungan**: 20 komponen dari
Pembahanan digabung 5:1 di Machining jadi 4, digabung 2:1 di Edge Banding jadi 2,
lalu digabung lagi di Sanding jadi 1.

Akibatnya rantai lurus itu salah menggambarkan proses, dan tidak bisa menjawab
pertanyaan yang paling sering muncul: **kenapa sebuah tahap belum bisa jalan.**
Bentuk data yang benar adalah pohon konvergensi, bukan rantai.

## 2. Tujuan

Halaman harus menjawab, untuk satu SO (opsional per item):

> Proses ini tertahan oleh komponen yang mana, dan komponen itu sekarang
> bagaimana keadaannya.

Bukan sekadar melacak posisi barang, dan bukan sekadar menghitung persentase
progres — dua alternatif itu ditolak eksplisit saat brainstorming.

## 3. Sumber data

Struktur pohonnya sudah ada di SAP dan sudah pernah dipakai aplikasi ini:

- Sebuah order **menghasilkan** satu material: `AFPO-MATNR`, qty `AFPO-PSMNG`
- Order yang sama **memakan** komponen: `RESB` per `AUFNR` —
  `MATNR`, `BDMNG` (butuh berapa), `ENMNG` (sudah ditarik berapa), `XLOEK`
- Rasio gabung = `BDMNG / PSMNG` (inilah angka "5 : 1")
- Sisi pohon: order B adalah **anak** order A bila `AFPO(B)-MATNR` muncul di
  `RESB(A)-MATNR` dalam SO+Item yang sama

`monitoring.htm` sudah memakai pola ini dan meninggalkan satu pelajaran mahal
yang WAJIB diikuti: **jangan memfilter `XLOEK = space` di WHERE.** Order yang
sudah TECO umumnya punya `XLOEK = 'X'` sebagai penutupan administratif
reservasi, bukan tanda barangnya belum dipakai. Filter itu dulu membuat order
yang sudah tuntas malah tampil "Tidak Ada Data" (perbaikan D48).

## 4. Keputusan yang sudah diambil

| # | Keputusan | Alasan |
|---|---|---|
| K1 | Fokus halaman = **diagnosa hambatan**, bukan pelacakan posisi atau progres | Dipilih user dari 3 opsi |
| K2 | Arti "stok 0" dibedakan lewat **`RESB-ENMNG`** | Tanpa ini, order yang sudah selesai tampak seperti tertahan — alarm palsu |
| K3 | **Semua order** SO+Item masuk pohon, tanpa filter DISPO; yang di luar 7 DISPO baku ditandai, dan disembunyikan/ditampilkan lewat kontrol JS | Filter DISPO memotong pohon persis di lapis konvergensi teratas (Plant 2000 hanya punya GA1/GA2/EB2) |
| K4 | **Barang beli dibuang** dari pohon; hanya komponen yang punya order pembuat jadi cabang | Dipilih user. Konsekuensi diterima: lihat R3 |
| K5 | Logika pegging tinggal di **class baru `ZCL_CS_PEG`**, halaman hanya menyajikan | `routing_map.htm` sudah 1.128 baris; `ZCL_CS_UTIL` dipakai halaman lain sehingga aktivasi ulangnya berisiko tanpa perlu |
| K6 | Tampilan: **kartu stasiun berpanah sebagai ringkasan sebaris di atas + tabel pohon sebagai tampilan utama** | Dipilih user dari 3 bentuk |
| K7 | Arah pohon: **produk akhir di atas, bahan mentah di bawah** (arah eksplosi BOM) | Cocok dengan pertanyaan "kenapa *ini* belum jadi" |
| K8 | Kartu stasiun **bisa diklik** dan membuka panel rincian | Permintaan user |

## 5. Arsitektur

```
routing_map.htm  ──panggil──>  ZCL_CS_PEG=>build( )
   (penyajian)                    (pegging + stok + status)
```

Halaman tidak lagi memuat query pegging. Query stok (MSKA / MARD / T001L) ikut
pindah ke class supaya status kesiapan dihitung di satu tempat saja.

### Kontrak

```abap
zcl_cs_peg=>build(
  EXPORTING iv_vbeln = <no SO>            " wajib
            iv_posnr = <item SO>          " opsional; kosong = semua item
            iv_maxord = 800               " pengaman, lihat R7
  IMPORTING et_node  = <baris pohon, sudah urut & berlevel>
            et_stn   = <ringkasan per stasiun untuk kartu atas>
            et_wc    = <work center per stasiun untuk panel>
            ev_trunc = <abap_bool: hasil dipotong batas order> ).
```

### Struktur satu baris `et_node`

| Field | Isi |
|---|---|
| `level`, `has_child`, `node_key`, `parent_key` | struktur pohon + kait collapse JS |
| `kdpos`, `matnr`, `maktx` | identitas komponen |
| `aufnr`, `stn_seq`, `stn_txt`, `dispo`, `in_scope` | order pembuat & stasiunnya; `in_scope` = DISPO termasuk 7 nilai baku |
| `bdmng`, `enmng`, `qty_out`, `ratio_txt` | butuh, sudah ditarik, output order induk, rasio gabung ("5 : 1") |
| `stok_so`, `stok_free` | real stock, dipisah SO-stock vs stok bebas |
| `status` | `USED` / `PARTIAL` / `READY` / `SHORT` / `MISSING` |
| `dup_of` | terisi bila komponen ini sudah muncul di cabang lain |
| `note` | catatan kasus khusus (lihat bagian 8) |

## 6. Algoritma

1. Ambil **semua** order SO+Item (`AFPO ⨝ AFKO`), tanpa filter DISPO. Tetapkan
   `in_scope` = DISPO termasuk `WM1/WM2/PN1/PN2` (Plant 1000) atau
   `GA1/GA2/EB2` (Plant 2000), dengan plant SELALU dipasangkan dengan DISPO.
2. Ambil `RESB` untuk semua `AUFNR` — **tanpa `XLOEK` di WHERE**. Agregasi per
   (`aufnr`, `matnr`) jadi Σ`bdmng`, Σ`enmng`, `any_open` (true bila minimal
   satu baris `XLOEK <> 'X'`).
3. Bangun indeks `matnr → order pembuat` dari daftar order. Bila satu material
   punya beberapa order (batch terpisah), qty-nya diagregasi jadi satu simpul.
4. Bentuk sisi pohon: untuk tiap order O dan tiap komponen K di `RESB(O)`, bila
   K punya order pembuat maka K jadi anak O. Bila tidak (barang beli), dibuang
   (K4).
5. Tentukan akar: order yang materialnya tidak pernah muncul di `RESB` order
   lain dalam SO+Item itu. Boleh lebih dari satu.
6. Telusuri turun (DFS) dari tiap akar, catat `level`, dengan penjaga siklus:
   bila sebuah `matnr` sudah ada di jalur leluhurnya, penelusuran berhenti dan
   baris ditandai. Batas kedalaman 10.
7. Tempel stok per `matnr` (MSKA SO-stock + MARD stok bebas), lalu tetapkan
   status.

### Aturan status (K2)

```
USED     ENMNG >= BDMNG                    sudah dipakai naik ke induk
PARTIAL  0 < ENMNG < BDMNG                 sebagian; sisa = BDMNG - ENMNG
READY    ENMNG < BDMNG, stok >= sisa       siap dipakai
SHORT    ENMNG < BDMNG, 0 < stok < sisa    kurang sekian
MISSING  ENMNG = 0, stok = 0               penahan sejati
```

Perbandingan stok vs `BDMNG` **selalu dalam material yang sama**, jadi aman dari
campur UoM.

**`stok` dalam aturan di atas = `stok_so` saja (MSKA SO-stock).** Stok bebas
(MARD) tetap ditampilkan di kolomnya sendiri tetapi **tidak ikut menentukan
status**, karena barang itu milik material, bukan milik SO ini — mengikutkannya
akan membuat sebuah proses tampak "siap" memakai barang yang belum tentu
dialokasikan untuknya. Aturan yang sama sudah dipakai `routing_map.htm` saat
menjumlahkan "stok SO" di kepala komponen.

**Penempatan stasiun sebuah simpul** diambil dari order pembuatnya (plant +
DISPO). Bila DISPO-nya di luar 7 nilai baku, `stn_seq` diisi 9 dan `stn_txt`
= "Lainnya", dan `in_scope` = false.

**`level` akar = 0**, bertambah 1 tiap turun satu tingkat.

## 7. Tampilan

### 7.1 Ringkasan — kartu stasiun berpanah

Baris kartu seperti yang sudah ada, tapi angkanya berubah arti: **jumlah
material** di stasiun itu (COUNT simpul pohon yang order pembuatnya ada di
stasiun tsb — COUNT, bukan SUM qty, supaya tidak mencampur UoM), plus rasio
gabungnya. Stasiun yang tertahan diberi latar merah.

**Rasio di kartu stasiun** dihitung dari sisi-sisi pohon yang masuk ke stasiun
itu. Karena satu stasiun bisa memuat beberapa komponen dengan rasio berbeda,
aturannya: bila semua sisi punya rasio sama, tampilkan angkanya ("gabung 5 : 1");
bila berbeda-beda, tampilkan **"gabung bervariasi"** dan rasio per komponen
dibaca di tabel pohon. Jangan menampilkan rata-rata — angka itu tidak punya arti
fisik.

"Tertahan" untuk pewarnaan kartu = stasiun punya minimal satu simpul berstatus
`MISSING` atau `SHORT`.

### 7.2 Tampilan utama — tabel pohon

Kolom: Komponen (indentasi + caret) · Stasiun · Order · Butuh · Dipakai · Stok ·
Status. Baris teratas produk akhir; makin menjorok makin ke hulu. Rasio gabung
ditulis di sebelah nama komponen.

### 7.3 Kontrol hide/unhide (JS, client-side)

- Hanya penahan
- Sembunyikan yang sudah dipakai
- Sembunyikan di luar scope DISPO
- Lipat semua / buka semua
- Caret per baris untuk melipat cabang

### 7.4 Panel rincian saat kartu diklik (K8)

Panel terbuka di bawah baris kartu, di atas tabel pohon. Semua panel
di-*render* di muka dalam keadaan tersembunyi lalu dibuka JS — tidak perlu
endpoint AJAX baru, karena datanya sudah ada di halaman.

**Stasiun proses** (Pembahanan / Machining / Edge Banding / Sanding):

- Material dikelompokkan **Antre / Diproses / Selesai**, memakai rumus status
  operasi yang sudah dipakai (`ΣAFRU-LMNGA` vs `AFVV-MGVRG`, baris `STOKZ='X'`
  dibuang) — tidak ada definisi status baru
- Tiap baris: material, work center, qty order, real stok
- Di bawahnya: daftar **work center di stasiun itu** beserta bebannya, diwarnai
  seperti heatmap `index2.htm`

**Central Storage:**

- Hanya daftar material yang stoknya ada di 2KCS
- Kolom **proses selanjutnya**: stasiun tujuan + nomor order induk + qty yang
  dibutuhkan, diambil dari pohon pegging
- Material berstok yang tidak dipakai order mana pun di SO ini tetap
  ditampilkan dengan keterangan apa adanya

## 8. Kasus sulit & penanganan error

| Ref | Kasus | Penanganan |
|---|---|---|
| R1 | SO tanpa order sama sekali | Pesan kosong yang menyebut scope-nya |
| R2 | Order tanpa baris `RESB` | Jadi daun, `note` = "tanpa komponen" |
| R3 | **Semua komponennya barang beli** | Jadi daun, `note` = "tidak ada komponen produksi" — supaya tidak terbaca seolah sudah lengkap. Ini konsekuensi K4 |
| R4 | Siklus di `RESB` | Penelusuran berhenti, `note` = "rekursi dihentikan"; batas kedalaman 10 |
| R5 | Lebih dari satu akar | Beberapa pohon, masing-masing kartunya sendiri |
| R6 | Material dipakai >1 induk | Muncul di tiap cabang; kemunculan ke-2 dst diberi `dup_of` agar stok tidak dibaca dobel |
| R7 | SO raksasa | Batas `iv_maxord` (default 800) + `ev_trunc` yang ditampilkan sebagai peringatan di UI, meniru `maxord` di `diag_routing.htm`. `RESB FOR ALL ENTRIES` di ribuan order berbahaya |
| R8 | `PSMNG = 0` | Rasio tidak dihitung, tampil "—" (hindari bagi nol) |
| R9 | Teks dari SAP (`MAKTX`, `KTEXT`) | Dibungkus `cl_http_utility=>escape_html( )` |

## 9. Verifikasi

1. **SO 10446** sebagai kasus uji utama — dari `diag_routing.htm` sudah
   diketahui: 36 order, 2 item SO, 35 material, 41 operasi, 26 confirmed /
   5 active / 10 queue. Yang dicek: akar terdeteksi, tidak ada rekursi tak
   berujung, jumlah baris pohon masuk akal terhadap jumlah sisi.
2. **Silang-cek angka**: `ENMNG` per material dibandingkan dengan yang
   ditampilkan `monitoring.htm` untuk material sama.
3. **Kasus batas**: SO tanpa order; order ada tapi `RESB` kosong; satu item vs
   semua item; komponen yang dipakai dua induk.
4. **Kinerja**: ukur waktu render. Bila >5 detik, pindah ke pola cache/AJAX
   seperti `dash_cs.htm` (SHARED BUFFER `indx(zc)`, TTL 90 detik).
5. **Struktur halaman**: delimiter BSP seimbang, `LOOP/ENDLOOP`, `IF/ENDIF`,
   keseimbangan `<div>`, tipe field-symbol cocok dengan tabel yang ditelusuri.

## 10. Di luar cakupan

- **Stasiun sesudah Sanding** (Assembling / Finishing / Packing). Tidak punya
  DISPO maupun SLoc sendiri, jadi tidak bisa diturunkan dari data yang ada.
  Jalannya lewat pemetaan cost center work center (`map_sec`) sesuai
  rekomendasi `diag_routing.htm` bagian G & I — 64 cost center menunggu diberi
  nama grup. Pekerjaan terpisah.
- **Menampilkan barang beli** (K4). Datanya tetap terambil karena query `RESB`
  mengambil semua baris dan penyaringannya di ABAP, jadi menambahkannya sebagai
  toggle di kemudian hari biayanya hampir nol.
- **Klik kartu menyaring tabel pohon.** Ditawarkan, tidak diambil — pohon yang
  tersaring kehilangan konteks induk-anak. Bisa ditambahkan sebagai chip
  kontrol bila nanti dibutuhkan.

## 11. Referensi

- `diag_routing.htm` — bukti Fase 0: bagian B (routing 1–2 operasi per order,
  sehingga alur antar tahap berupa rangkaian order terpisah), bagian C (rumus
  status operasi), bagian G & I (pemetaan cost center)
- `monitoring.htm` D47/D48 — pola `RESB` dan larangan filter `XLOEK` di WHERE
- `index.htm` — definisi SLoc per bagian yang dipakai memetakan stok ke stasiun
- `index2.htm` — rumus status operasi yang sama; heatmap work center
