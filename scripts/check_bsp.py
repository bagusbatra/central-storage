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

# Untuk hitungan kata kunci ABAP: buang baris komentar, dan buang
# "TO UPPER/LOWER CASE" yang bukan pernyataan CASE.
code = '\n'.join(
    l for l in raw.split('\n')
    if not (l.lstrip().startswith('*&') or l.lstrip().startswith('*')
            or l.lstrip().startswith('"'))
)
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

sys.exit(0 if ok else 1)
