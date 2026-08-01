# Pemeriksa struktur berkas BSP (Page with Flow Logic).
#
#   python scripts/check_bsp.py "ZBSP_CS_APP/Page with Flow Logic/index2.htm"
#
# Memeriksa hal-hal yang pernah benar-benar merusak halaman di repo ini:
#   1. delimiter BSP nyasar di dalam blok ABAP -> scriptlet terpotong di
#      tengah, aktivasi gagal "Closing without opening"
#   2. pasangan <% %>, <%-- --%>, LOOP/ENDLOOP, IF/ENDIF, CASE/ENDCASE
#   3. keseimbangan <div> dan <span>
#   4. tag HTML literal di komentar ABAP -> parser HTML editor mengira ada
#      blok terbuka dan memparse sisa berkas sebagai bahasa lain
#
# Penyebutan tag di dalam KOMENTAR (CSS, HTML, BSP) sengaja dibuang lebih
# dulu supaya tidak menghasilkan alarm palsu.
#
# BATAS METODE — baca sebelum percaya hasilnya:
#   Hitungan div/span hanya sahih untuk halaman yang markup-nya TIDAK
#   dipecah lintas cabang ABAP. monitoring.htm, misalnya, membuka <div> di
#   satu cabang IF dan menutupnya di cabang lain; hitungan mentahnya wajar
#   tidak seimbang dan itu BUKAN cacat. Untuk halaman semacam itu, andalkan
#   simulasi alur render, bukan skrip ini.
import re
import sys

path = sys.argv[1]
raw = open(path, encoding='utf-8').read()

# blok ABAP utama = setelah direktif baris 1, sampai %> pertama.
# Dipakai HANYA untuk deteksi delimiter nyasar di prolog.
abap = '\n'.join(raw.split('\n')[1:]).split('%>')[0]

# SELURUH baris yang berada di dalam scriptlet, beserta nomor barisnya.
#
# Percobaan sebelumnya memeriksa `abap` saja — dan itu berarti hanya blok
# PERTAMA. dash_prod.htm menutup scriptlet di tengah (untuk mengirim cache
# lebih awal), sehingga sebagian besar berkasnya tidak pernah diperiksa dan
# bug komentar di baris 215 lolos sampai SE80. Sekarang seluruh scriptlet
# ditelusuri, dengan nomor baris yang sebenarnya.
abap_lines = []
_inside = False
for _idx, _line in enumerate(raw.split('\n'), start=1):
    _began_inside = _inside
    _rest = _line
    while True:
        if not _inside:
            _j = _rest.find('<%')
            if _j < 0:
                break
            _inside = True
            _rest = _rest[_j + 2:]
        else:
            _j = _rest.find('%>')
            if _j < 0:
                break
            _inside = False
            _rest = _rest[_j + 2:]
    if _began_inside:
        abap_lines.append((_idx, _line))

# versi tanpa komentar, khusus untuk menghitung tag HTML
no_comment = re.sub(r'<%--.*?--%>', '', raw, flags=re.S)
no_comment = re.sub(r'<!--.*?-->', '', no_comment, flags=re.S)
no_comment = re.sub(r'/\*.*?\*/', '', no_comment, flags=re.S)

ok = True


def chk(label, a, b):
    global ok
    good = (a == b)
    ok = ok and good
    print(('OK   ' if good else 'GAGAL') + ' {}: {} / {}'.format(label, a, b))


stray = re.findall(r'<%|%>', abap[2:])
if stray:
    ok = False
    print('GAGAL delimiter nyasar di blok ABAP: {}'.format(stray))
else:
    print('OK    delimiter nyasar di blok ABAP: tidak ada')

# Kata kunci ABAP dihitung HANYA dari isi scriptlet <% ... %>, bukan dari
# seluruh berkas. Percobaan sebelumnya menghitung dari seluruh berkas lalu
# membuang komentar ekor ABAP ("..." sampai akhir baris) — dan itu MERUSAK
# atribut HTML, membuat IF/ENDIF meleset di routing_map.htm & diag_routing.htm.
# <%-- komentar --%>, <%= ekspresi %>, dan <%@ direktif %> dikecualikan.
scriptlets = re.findall(r'<%(?![-=@])(.*?)%>', raw, flags=re.S)
code = '\n'.join(scriptlets)
# Dalam ABAP: baris diawali * = komentar; " = komentar sampai akhir baris.
_cl = []
for l in code.split('\n'):
    if l.lstrip().startswith('*'):
        continue
    _cl.append(re.sub(r'".*$', '', l))
code = '\n'.join(_cl)
code = re.sub(r'TO\s+(UPPER|LOWER)\s+CASE', '', code)

chk('<% vs %>',         raw.count('<%'), raw.count('%>'))
chk('<%-- vs --%>',     raw.count('<%--'), raw.count('--%>'))
chk('LOOP vs ENDLOOP',  len(re.findall(r'\bLOOP AT\b', code)), len(re.findall(r'\bENDLOOP\b', code)))
chk('IF vs ENDIF',      len(re.findall(r'(?<![A-Z])IF ', code)), len(re.findall(r'\bENDIF\b', code)))
chk('CASE vs ENDCASE',  len(re.findall(r'\bCASE\b', code)), len(re.findall(r'\bENDCASE\b', code)))
chk('<div vs </div>',   len(re.findall(r'<div\b', no_comment)), len(re.findall(r'</div>', no_comment)))
chk('<span vs </span>', len(re.findall(r'<span\b', no_comment)), len(re.findall(r'</span>', no_comment)))

# Field-symbol ABAP <fs> bukan tag HTML -> dikecualikan.
FS = re.compile(r'^<(n|st|ra|sk|nd|mu|w|c|p|k|s|o|pc|wa|sm|par|fs|bc|ord)>$')
abap_code_only = '\n'.join(
    l for l in abap.split('\n')
    if not (l.lstrip().startswith('*&') or l.lstrip().startswith('"'))
)
tags_in_comment = set(re.findall(r'<[a-zA-Z][a-zA-Z0-9]*>', abap)) \
    - set(re.findall(r'<[a-zA-Z][a-zA-Z0-9]*>', abap_code_only))
tags_in_comment = set(t for t in tags_in_comment if not FS.match(t))
if tags_in_comment:
    ok = False
    print('GAGAL tag HTML literal di komentar ABAP: {}'.format(', '.join(sorted(tags_in_comment))))
    print('      (tulis tanpa kurung sudut - mis. "script", bukan tag utuh)')
else:
    print('OK    tag HTML literal di komentar ABAP: tidak ada')

# Komentar ABAP yang KEHILANGAN tanda kutip pembukanya. Terjadi 2026-08-01
# (index2.htm baris 62) dan menggagalkan aktivasi dengan pesan menyesatkan:
# "statement DAFTAR is not expected".
#
# Ciri yang dipakai: baris BUKAN komentar tetapi DIAPIT komentar di atas dan
# di bawahnya, isinya berupa prosa (tanpa '=', '(', tanda kutip), dan kata
# pertamanya bukan kata kunci ABAP.
#
# Percobaan pertama memakai syarat "tidak diakhiri titik" dan itu JUSTRU
# meleset — baris yang rusak kebetulan berakhir dengan titik. Syarat itu
# juga menandai baris lanjutan pernyataan multi-baris di routing_map.htm
# sebagai cacat padahal sehat.
KEYWORDS = set("""DATA TYPES CONSTANTS FIELD-SYMBOLS CLEAR REFRESH FREE APPEND
INSERT MODIFY DELETE READ LOOP ENDLOOP SORT COLLECT SELECT ENDSELECT IF ELSE
ELSEIF ENDIF CASE WHEN ENDCASE DO ENDDO WHILE ENDWHILE CHECK EXIT CONTINUE
RETURN CALL PERFORM FORM ENDFORM METHOD ENDMETHOD CLASS ENDCLASS MOVE ADD
SUBTRACT MULTIPLY DIVIDE CONCATENATE SPLIT REPLACE TRANSLATE CONDENSE SHIFT
DESCRIBE ASSIGN UNASSIGN CREATE RAISE MESSAGE EXPORT IMPORT GET SET COMMIT
ROLLBACK TRY CATCH ENDTRY WRITE SKIP ULINE FORMAT""".split())


def _is_cmt(t):
    t = t.strip()
    return t.startswith('*&') or t.startswith('*') or t.startswith('"')


_lines = abap.split('\n')
orphan = []
for k in range(1, len(abap_lines) - 1):
    lineno, txt = abap_lines[k]
    cur = txt.strip()
    if not cur or _is_cmt(cur):
        continue
    if not (_is_cmt(abap_lines[k - 1][1]) and _is_cmt(abap_lines[k + 1][1])):
        continue
    if '=' in cur or '(' in cur or "'" in cur:
        continue
    # Baris lanjutan deklarasi (DATA:/CONSTANTS:/TYPES: berkoma) sering
    # terapit komentar dan bukan cacat. Ciri: mengandung ' TYPE ' atau
    # diakhiri koma.
    if ' TYPE ' in cur.upper() or cur.endswith(','):
        continue
    if re.split(r'[\s:.]', cur)[0].upper() in KEYWORDS:
        continue
    orphan.append((lineno, cur[:60]))

if orphan:
    ok = False
    print('GAGAL komentar ABAP tanpa tanda kutip pembuka:')
    for ln, txt in orphan:
        print('      baris {}: {}'.format(ln, txt))
else:
    print('OK    komentar ABAP tanpa tanda kutip pembuka: tidak ada')

# Komentar '*' yang TIDAK di kolom 1. ABAP hanya menganggap * sebagai
# komentar bila berada di kolom pertama; kalau menjorok, ia dibaca sebagai
# pernyataan dan aktivasi gagal ("statement *&---...--* is invalid").
# Terjadi 2026-08-01 di dash_prod.htm baris 215.
indented_star = []
for lineno, line in abap_lines:
    if line[:1] in (' ', '\t') and line.lstrip().startswith('*'):
        indented_star.append((lineno, line.strip()[:50]))
if indented_star:
    ok = False
    print('GAGAL komentar * tidak di kolom 1 (ABAP membacanya sbg pernyataan):')
    for ln, txt in indented_star:
        print('      baris {}: {}'.format(ln, txt))
    print('      (pakai " untuk komentar yang menjorok)')
else:
    print('OK    komentar * di kolom 1: ya')

sys.exit(0 if ok else 1)
