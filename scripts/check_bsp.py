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

# blok ABAP utama = setelah direktif baris 1, sampai %> pertama
abap = '\n'.join(raw.split('\n')[1:]).split('%>')[0]

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
for i in range(1, len(_lines) - 1):
    cur = _lines[i].strip()
    if not cur or _is_cmt(cur):
        continue
    if not (_is_cmt(_lines[i - 1]) and _is_cmt(_lines[i + 1])):
        continue
    if '=' in cur or '(' in cur or "'" in cur:
        continue
    if re.split(r'[\s:.]', cur)[0].upper() in KEYWORDS:
        continue
    orphan.append((i + 2, cur[:60]))

if orphan:
    ok = False
    print('GAGAL komentar ABAP tanpa tanda kutip pembuka:')
    for ln, txt in orphan:
        print('      baris {}: {}'.format(ln, txt))
else:
    print('OK    komentar ABAP tanpa tanda kutip pembuka: tidak ada')

sys.exit(0 if ok else 1)
