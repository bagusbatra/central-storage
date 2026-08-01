# Pemeriksa struktur berkas BSP — jalankan: python scripts/check_bsp.py <file.htm>
import re, sys
p = sys.argv[1]
raw = open(p, encoding='utf-8').read()
head = '\n'.join(raw.split('\n')[1:]).split('%>')[0]   # lewati direktif baris 1
bad = re.findall(r'<%|%>', head[2:])
ok = True
def chk(label, a, b):
    global ok
    good = (a == b); ok = ok and good
    print(('OK   ' if good else 'GAGAL') + f' {label}: {a} / {b}')
print('OK    delimiter nyasar di blok ABAP: tidak ada' if not bad
      else f'GAGAL delimiter nyasar di blok ABAP: {bad}')
ok = ok and not bad
chk('<% vs %>',        raw.count('<%'), raw.count('%>'))
chk('<%-- vs --%>',    raw.count('<%--'), raw.count('--%>'))
chk('LOOP vs ENDLOOP', len(re.findall(r'\bLOOP AT\b', raw)), len(re.findall(r'\bENDLOOP\b', raw)))
chk('IF vs ENDIF',     len(re.findall(r'(?<![A-Z])IF ', raw)), len(re.findall(r'\bENDIF\b', raw)))
chk('CASE vs ENDCASE', len(re.findall(r'\bCASE\b', raw)), len(re.findall(r'\bENDCASE\b', raw)))
chk('<div vs </div>',  len(re.findall(r'<div\b', raw)), len(re.findall(r'</div>', raw)))
chk('<span vs </span>',len(re.findall(r'<span\b', raw)), len(re.findall(r'</span>', raw)))
sys.exit(0 if ok else 1)
