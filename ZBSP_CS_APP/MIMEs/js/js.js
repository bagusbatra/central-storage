/* =======================================================================
   Dashboard Central Storage KMI 2 — Plant 2000
   Shared JS: index.htm & monitoring.htm
   Data ABAP (weekLabels, doneCounts, dll.) di-inject via inline <script>
   di index.htm karena mengandung nilai <%= %> dari ABAP server-side.
   ======================================================================= */

/** Tunda eksekusi fn hingga delay ms setelah panggilan terakhir (anti-flicker resize) */
function debounce(fn, delay) {
  var t;
  return function() { clearTimeout(t); t = setTimeout(fn, delay); };
}

var barState   = [];
var hoveredBar = -1;

/* ===== State monitoring (sidebar paginasi & panel aktif) ===== */
var rowsPerPage        = 5;
var currentPage        = 1;
var soCards            = [];
var currentActiveVBELN = null;
var currentActiveBOMId = null;
var soDetailCache      = {}; /* cache HTML detail per vbeln */

/* ------------------------------------------------------------------
   Helper: kotak dengan sudut bulat semua sisi (canvas 2D)
   ------------------------------------------------------------------ */
function drawRoundRect(ctx, x, y, w, h, r) {
  if (w < 2 * r) r = w / 2;
  if (h < 2 * r) r = h / 2;
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y,     x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x,     y + h, r);
  ctx.arcTo(x,     y + h, x,     y,     r);
  ctx.arcTo(x,     y,     x + r, y,     r);
  ctx.closePath();
}

/* ------------------------------------------------------------------
   Helper: sudut bulat hanya di atas (untuk segment teratas stacked bar)
   ------------------------------------------------------------------ */
function drawRoundTop(ctx, x, y, w, h, r) {
  if (h <= 0) return;
  if (w < 2 * r) r = w / 2;
  if (h < r) r = h;
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y,     x + w, y + h, r);
  ctx.lineTo(x + w, y + h);
  ctx.lineTo(x,     y + h);
  ctx.arcTo(x,      y,     x + r, y,     r);
  ctx.closePath();
}

/* ------------------------------------------------------------------
   Drill-down: klik bar → navigasi ke monitoring.htm dengan rentang
   tanggal minggu yang diklik (weekDates berformat YYYYMMDD)
   ------------------------------------------------------------------ */
function drillDown(weekIdx) {
  var wdate = weekDates[weekIdx];
  if (!wdate) return;
  var y  = parseInt(wdate.substr(0, 4), 10);
  var mo = parseInt(wdate.substr(4, 2), 10) - 1;
  var dy = parseInt(wdate.substr(6, 2), 10);
  var dtFrom = new Date(y, mo, dy);
  var dtTo   = new Date(dtFrom.getTime() + 6 * 24 * 60 * 60 * 1000);
  function p2(v) { return v < 10 ? '0' + v : '' + v; }
  var fromStr = dtFrom.getFullYear() + '-' + p2(dtFrom.getMonth() + 1) + '-' + p2(dtFrom.getDate());
  var toStr   = dtTo.getFullYear()   + '-' + p2(dtTo.getMonth()   + 1) + '-' + p2(dtTo.getDate());
  window.location.href = 'monitoring.htm?date_from=' + fromStr + '&date_to=' + toStr + '&search_btn=X';
}

/* ------------------------------------------------------------------
   Stacked bar chart (index.htm) — Selesai / Proses / Belum per minggu.
   canvas.width dihitung dari lebar parent setiap render agar responsif
   saat window di-resize (dipanggil ulang oleh resize handler).
   ------------------------------------------------------------------ */
function drawBarChart() {
  var canvas = document.getElementById('barChart');
  if (!canvas || !canvas.getContext) return;
  canvas.width = canvas.parentElement ? canvas.parentElement.clientWidth - 48 : 500;
  var ctx    = canvas.getContext('2d');
  var W = canvas.width, H = canvas.height;
  var padL = 46, padR = 20, padT = 36, padB = 50;
  var chartW = W - padL - padR;
  var chartH = H - padT - padB;
  var n = weekLabels.length;

  ctx.fillStyle = '#ffffff';
  ctx.fillRect(0, 0, W, H);

  if (n === 0) {
    ctx.fillStyle = '#9ca3af';
    ctx.font = '13px Segoe UI, Arial, sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText('Belum ada data untuk ditampilkan', W / 2, H / 2);
    return;
  }

  var totals = [], max = 0;
  for (var i = 0; i < n; i++) {
    totals[i] = doneCounts[i] + inprogCounts[i] + noprodCounts[i];
    if (totals[i] > max) max = totals[i];
  }
  if (max === 0) max = 1;
  var tickStep = Math.ceil(max / 5);
  var tickMax  = tickStep * 5;
  if (tickMax === 0) tickMax = 5;

  for (var t = 0; t <= 5; t++) {
    var yv = tickMax * t / 5;
    var yp = padT + chartH - (yv / tickMax) * chartH;
    ctx.beginPath();
    ctx.strokeStyle = t === 0 ? '#d1d5db' : '#f0f0f0';
    ctx.lineWidth = 1;
    ctx.moveTo(padL, yp); ctx.lineTo(padL + chartW, yp); ctx.stroke();
    ctx.fillStyle = '#9ca3af';
    ctx.font = '11px Segoe UI, Arial, sans-serif';
    ctx.textAlign = 'right';
    ctx.fillText(Math.round(yv), padL - 8, yp + 4);
  }

  var slotW = chartW / n;
  var barW  = Math.min(slotW * 0.62, 56);
  barState  = [];

  for (var i = 0; i < n; i++) {
    var total = totals[i];
    var bx    = padL + i * slotW + (slotW - barW) / 2;
    var baseY = padT + chartH;
    var cx    = bx + barW / 2;
    barState.push({ x: bx, w: barW, idx: i, cx: cx, total: total,
      done: doneCounts[i], inprog: inprogCounts[i], noprod: noprodCounts[i],
      label: weekLabels[i], wdate: weekDates[i] });

    var np_h = noprodCounts[i] > 0 ? (noprodCounts[i] / tickMax) * chartH : 0;
    var ip_h = inprogCounts[i] > 0 ? (inprogCounts[i] / tickMax) * chartH : 0;
    var dn_h = doneCounts[i]   > 0 ? (doneCounts[i]   / tickMax) * chartH : 0;

    var topSeg = 0;
    if (doneCounts[i]      > 0) topSeg = 1;
    else if (inprogCounts[i] > 0) topSeg = 2;
    else if (noprodCounts[i] > 0) topSeg = 3;

    var curY = baseY;
    if (np_h > 0) {
      curY -= np_h;
      if (topSeg === 3) { drawRoundTop(ctx, bx, curY, barW, np_h, 5); }
      else { ctx.beginPath(); ctx.rect(bx, curY, barW, np_h); }
      ctx.fillStyle = '#d1d5db'; ctx.fill();
    }
    if (ip_h > 0) {
      curY -= ip_h;
      if (topSeg === 2) { drawRoundTop(ctx, bx, curY, barW, ip_h, 5); }
      else { ctx.beginPath(); ctx.rect(bx, curY, barW, ip_h); }
      ctx.fillStyle = '#3b82f6'; ctx.fill();
    }
    if (dn_h > 0) {
      curY -= dn_h;
      drawRoundTop(ctx, bx, curY, barW, dn_h, 5);
      ctx.fillStyle = '#10b981'; ctx.fill();
    }

    if (total > 0) {
      var topY = padT + chartH - (total / tickMax) * chartH;
      ctx.font = 'bold 12px Segoe UI, Arial, sans-serif';
      var bTxt = String(total);
      var bW   = ctx.measureText(bTxt).width + 14;
      var bH   = 20;
      var bX   = cx - bW / 2;
      var bY   = topY - bH - 6;
      drawRoundRect(ctx, bX, bY, bW, bH, 10);
      ctx.fillStyle = '#1e3a8a'; ctx.fill();
      ctx.fillStyle = '#ffffff'; ctx.textAlign = 'center';
      ctx.fillText(bTxt, cx, bY + bH - 5);
    }

    if (total === 0) {
      ctx.beginPath(); ctx.strokeStyle = '#e5e7eb'; ctx.lineWidth = 1;
      ctx.moveTo(cx, padT + chartH - 4); ctx.lineTo(cx, padT + chartH); ctx.stroke();
    }

    ctx.fillStyle = '#6b7280';
    ctx.font = '9px Segoe UI, Arial, sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText('Minggu', cx, padT + chartH + 14);
    ctx.font = 'bold 10px Segoe UI, Arial, sans-serif';
    ctx.fillStyle = '#374151';
    ctx.fillText(weekLabels[i], cx, padT + chartH + 26);
  }

  /* Tooltip saat hover bar — posisi di atas bar, panah mengarah ke bawah */
  if (hoveredBar >= 0 && hoveredBar < n) {
    var d    = barState[hoveredBar];
    var yyyy = parseInt(d.wdate.substr(0, 4), 10);
    var mm   = parseInt(d.wdate.substr(4, 2), 10) - 1;
    var dd   = parseInt(d.wdate.substr(6, 2), 10);
    var dtF  = new Date(yyyy, mm, dd);
    var dtT  = new Date(dtF.getTime() + 6 * 24 * 60 * 60 * 1000);
    function p2(v) { return v < 10 ? '0' + v : '' + v; }
    var rangeStr = p2(dtF.getDate()) + '/' + p2(dtF.getMonth() + 1) +
                   ' – ' + p2(dtT.getDate()) + '/' + p2(dtT.getMonth() + 1);
    var rate = d.total > 0 ? Math.round(d.done / d.total * 100) : 0;

    var lines = [
      rangeStr,
      'Total SO   : ' + d.total,
      'Selesai     : ' + d.done + '  (' + rate + '%)',
      'Proses      : ' + d.inprog,
      'Belum       : ' + d.noprod
    ];

    ctx.font = '12px Segoe UI, Arial, sans-serif';
    var ttw = 0;
    for (var li = 0; li < lines.length; li++) {
      ctx.font = li === 0 ? 'bold 12px Segoe UI, Arial, sans-serif' : '12px Segoe UI, Arial, sans-serif';
      var lw = ctx.measureText(lines[li]).width;
      if (lw > ttw) ttw = lw;
    }
    var tth = lines.length * 20 + 16;
    ttw += 28;

    /* Posisi: di atas puncak bar, horizontal center pada bar */
    var barTopY = padT + chartH - (d.total > 0 ? (d.total / tickMax) * chartH : 0);
    var tx = d.cx - ttw / 2;
    var ty = barTopY - tth - 14;
    if (ty < padT + 4) ty = padT + 4;
    if (tx < padL)     tx = padL;
    if (tx + ttw > W - padR) tx = W - padR - ttw;

    /* Kotak tooltip */
    drawRoundRect(ctx, tx, ty, ttw, tth, 7);
    ctx.fillStyle = '#1f2937'; ctx.fill();

    /* Panah ke bawah mengarah ke bar */
    var arrowX = Math.max(tx + 12, Math.min(d.cx, tx + ttw - 12));
    ctx.beginPath();
    ctx.moveTo(arrowX - 6, ty + tth);
    ctx.lineTo(arrowX,     ty + tth + 9);
    ctx.lineTo(arrowX + 6, ty + tth);
    ctx.fillStyle = '#1f2937'; ctx.fill();

    /* Teks */
    ctx.textAlign = 'left';
    for (var li = 0; li < lines.length; li++) {
      ctx.font      = li === 0 ? 'bold 12px Segoe UI, Arial, sans-serif' : '12px Segoe UI, Arial, sans-serif';
      ctx.fillStyle = li === 0 ? '#93c5fd'
                    : li === 2 ? '#86efac'
                    : '#ffffff';
      ctx.fillText(lines[li], tx + 12, ty + 18 + li * 20);
    }
  }
}

/* ------------------------------------------------------------------
   Donut chart (index.htm) — distribusi status item produksi.
   Dimensi canvas disesuaikan dengan lebar parent tiap render (responsif).
   ------------------------------------------------------------------ */
function drawDonutChart() {
  var canvas = document.getElementById('donutChart');
  if (!canvas || !canvas.getContext) return;

  /* Ukuran responsif: ambil dari lebar parent, cap 220px */
  var parent = canvas.parentElement;
  var size   = parent ? Math.min(parent.clientWidth - 32, 220) : 200;
  canvas.width  = size;
  canvas.height = size;

  var ctx   = canvas.getContext('2d');
  var W = canvas.width, H = canvas.height;
  var cx = W / 2, cy = H / 2;
  var R    = Math.min(W, H) / 2 - 12;
  var hole = R * 0.56;
  var total = doneCount + progCount + noprodCount;

  ctx.clearRect(0, 0, W, H);

  if (total === 0) {
    ctx.beginPath(); ctx.arc(cx, cy, R, 0, Math.PI * 2);
    ctx.fillStyle = '#f3f4f6'; ctx.fill();
    ctx.beginPath(); ctx.arc(cx, cy, hole, 0, Math.PI * 2);
    ctx.fillStyle = '#ffffff'; ctx.fill();
    ctx.fillStyle = '#9ca3af';
    ctx.font = '11px Segoe UI, Arial, sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText('Tidak ada data', cx, cy + 4);
    return;
  }

  var segs = [
    { val: doneCount,   color: '#10b981' },
    { val: progCount,   color: '#3b82f6' },
    { val: noprodCount, color: '#d1d5db' }
  ];
  var angle = -Math.PI / 2;
  for (var i = 0; i < segs.length; i++) {
    if (segs[i].val === 0) continue;
    var sweep = (segs[i].val / total) * Math.PI * 2;
    ctx.beginPath(); ctx.moveTo(cx, cy);
    ctx.arc(cx, cy, R, angle, angle + sweep);
    ctx.closePath(); ctx.fillStyle = segs[i].color; ctx.fill();
    angle += sweep;
  }

  ctx.beginPath(); ctx.arc(cx, cy, hole, 0, Math.PI * 2);
  ctx.fillStyle = '#ffffff'; ctx.fill();

  var pct = Math.round(doneCount / total * 100);
  ctx.fillStyle = '#1e3a8a';
  ctx.font = 'bold 26px Segoe UI, Arial, sans-serif';
  ctx.textAlign = 'center';
  ctx.fillText(pct + '%', cx, cy + 5);
  ctx.fillStyle = '#9ca3af';
  ctx.font = '11px Segoe UI, Arial, sans-serif';
  ctx.fillText('selesai', cx, cy + 20);
}

/* ==================== Monitoring functions ==================== */

/** Baca nomor halaman aktif dari URL hash (#page=N), default 1 */
function getPageFromHash() {
  var match = window.location.hash.match(/page=(\d+)/);
  return match ? Math.max(1, parseInt(match[1], 10)) : 1;
}

/** Render paginasi sidebar SO dan perbarui URL hash */
function renderPagination() {
  var totalPages = Math.ceil(soCards.length / rowsPerPage) || 1;
  if (currentPage > totalPages) currentPage = totalPages;
  if (currentPage < 1) currentPage = 1;

  var startIndex = (currentPage - 1) * rowsPerPage;
  var endIndex   = startIndex + rowsPerPage;

  for (var i = 0; i < soCards.length; i++) {
    soCards[i].style.display = (i >= startIndex && i < endIndex) ? 'block' : 'none';
  }

  document.getElementById('page-indicator').innerText = currentPage + ' / ' + totalPages;
  document.getElementById('btn-prev').disabled = (currentPage === 1);
  document.getElementById('btn-next').disabled = (currentPage === totalPages);

  /* Simpan halaman aktif di URL hash agar state bertahan saat back/forward */
  history.replaceState(null, '', window.location.pathname + window.location.search + '#page=' + currentPage);
}

/** Navigasi paginasi: direction +1 (next) atau -1 (prev) */
function changePage(direction) {
  currentPage += direction;
  renderPagination();
}

/** Muat detail panel SO via AJAX; gunakan cache jika tersedia */
function viewDetails(vbeln) {
  if (currentActiveVBELN) {
    var oldRow = document.getElementById('row-' + currentActiveVBELN);
    if (oldRow) oldRow.classList.remove('active');
  }
  currentActiveVBELN = vbeln;
  currentActiveBOMId = null;
  document.getElementById('row-' + vbeln).classList.add('active');

  var container = document.getElementById('main-panel-container');

  /* Sajikan dari cache jika sudah pernah dimuat */
  if (soDetailCache[vbeln]) {
    container.innerHTML = soDetailCache[vbeln];
    formatNumbers(container);
    enhanceA11y(container);
    return;
  }

  /* Skeleton loading — tampil selama server memproses ABAP query */
  container.innerHTML =
    '<div class="detail-content active">' +
    '  <div class="detail-header"><div class="skel-line skel-title"></div></div>' +
    '  <div class="skel-table">' +
    '    <div class="skel-thead"></div>' +
    '    <div class="skel-row"></div>' +
    '    <div class="skel-row"></div>' +
    '    <div class="skel-row" style="width:80%"></div>' +
    '    <div class="skel-row" style="width:60%"></div>' +
    '  </div>' +
    '</div>';

  var xhr = new XMLHttpRequest();
  xhr.open('GET', 'monitoring_detail.htm?vbeln=' + encodeURIComponent(vbeln), true);
  xhr.onload = function() {
    if (xhr.status === 200) {
      soDetailCache[vbeln] = xhr.responseText;
      container.innerHTML = xhr.responseText;
      formatNumbers(container);
      enhanceA11y(container);
      /* B1: biarkan tab default "Ringkasan" tampil (sesuai markup server);
         tidak lagi memaksa ke Item & BOM + buka semua BOM. */
    } else {
      container.innerHTML = '<div class="placeholder-ctx"><p style="color:#ef4444;">Gagal memuat data (HTTP ' + xhr.status + ').</p></div>';
    }
  };
  xhr.onerror = function() {
    container.innerHTML = '<div class="placeholder-ctx"><p style="color:#ef4444;">Error koneksi ke server.</p></div>';
  };
  xhr.send();
}

/** Toggle expand/collapse BOM row (server-rendered, no AJAX) */
function toggleBOMRow(bomId) {
  var trContainer = document.getElementById('bom-row-' + bomId);
  var wrapper     = document.getElementById('wrapper-' + bomId);
  if (!trContainer || !wrapper) return;

  if (!wrapper.classList.contains('bom-open')) {
    if (currentActiveBOMId && currentActiveBOMId !== bomId && currentActiveBOMId !== '*') {
      hideBOMRow(currentActiveBOMId);
    }
    openBOMRow(trContainer, wrapper, bomId);
  } else {
    hideBOMRow(bomId);
  }
}

function openBOMRow(trContainer, wrapper, bomId) {
  trContainer.style.display = 'table-row';
  void wrapper.offsetHeight;
  wrapper.classList.add('bom-open');
  currentActiveBOMId = (currentActiveBOMId === '*') ? '*' : bomId;
}

function hideBOMRow(bomId) {
  var wrapper     = document.getElementById('wrapper-' + bomId);
  var trContainer = document.getElementById('bom-row-' + bomId);
  if (!wrapper) return;
  wrapper.classList.remove('bom-open');
  setTimeout(function() {
    if (trContainer && !wrapper.classList.contains('bom-open')) {
      trContainer.style.display = 'none';
    }
  }, 330);
  if (currentActiveBOMId === bomId) currentActiveBOMId = null;
}

/* ------------------------------------------------------------------
   Material Tooltip — muncul saat klik kode material di tabel BOM.
   Data stok (MARD) dan open PO (EKPO) diembed sebagai data attributes
   oleh ABAP, sehingga tidak perlu request tambahan ke server.
   ------------------------------------------------------------------ */
var matTooltipEl  = null; /** elemen tooltip aktif */
var matTooltipSrc = null; /** <code> element yang membuka tooltip */

/** Tampilkan atau toggle tooltip material. Toggle jika klik elemen yg sama. */
function showMatTooltip(el) {
  if (matTooltipEl) {
    var same = (matTooltipSrc === el);
    closeMatTooltip();
    if (same) return;
  }
  matTooltipSrc = el;

  var matnr = el.getAttribute('data-matnr') || '';
  var name  = el.getAttribute('data-name')  || '—';
  var need  = parseFloat(el.getAttribute('data-need')  || '0');
  var unit  = el.getAttribute('data-unit')  || '';
  var stock = parseFloat(el.getAttribute('data-stock') || '0');
  var po    = parseFloat(el.getAttribute('data-po')    || '0');
  var eta   = el.getAttribute('data-eta')   || '';

  var isOk  = stock >= need;
  var badge = isOk
    ? '<span class="mat-tt-ok">✓ Cukup</span>'
    : '<span class="mat-tt-warn">⚠ Kurang Stok</span>';

  function fmt(n) { return n.toLocaleString('id-ID', { maximumFractionDigits: 3 }); }

  var html =
    '<div class="mat-tooltip" id="mat-tt">' +
    '  <span class="mat-tt-close" onclick="closeMatTooltip()">×</span>' +
    '  <div class="mat-tt-code">' + matnr + '</div>' +
    '  <div class="mat-tt-name">' + name + '</div>' +
    '  <div class="mat-tt-divider"></div>' +
    '  <div class="mat-tt-row"><span>Dibutuhkan BOM</span><span>' + fmt(need) + ' ' + unit + '</span></div>' +
    '  <div class="mat-tt-row"><span>Stok tersedia</span><span>' + fmt(stock) + ' ' + unit + ' ' + badge + '</span></div>';

  if (po > 0) {
    html +=
    '  <div class="mat-tt-row"><span>Open PO masuk</span><span>' + fmt(po) + ' ' + unit;
    if (eta) html += ' <span class="mat-tt-eta">ETA ' + eta + '</span>';
    html += '</span></div>';
  } else {
    html += '  <div class="mat-tt-row"><span>Open PO masuk</span><span class="mat-tt-none">Tidak ada</span></div>';
  }

  html += '</div>';

  var wrap = document.createElement('div');
  wrap.innerHTML = html;
  var tt = wrap.firstChild;
  document.body.appendChild(tt);

  /* Posisi: di bawah element yang diklik, clamp agar tidak keluar layar */
  var rect = el.getBoundingClientRect();
  var ttW  = 272;
  var top  = rect.bottom + window.pageYOffset + 8;
  var left = rect.left   + window.pageXOffset;
  if (left + ttW > window.innerWidth - 12) left = window.innerWidth - ttW - 12;
  if (left < 8) left = 8;
  tt.style.top  = top  + 'px';
  tt.style.left = left + 'px';

  matTooltipEl = tt;

  /* Dismiss saat klik di luar tooltip — delay 10ms agar event ini tidak langsung men-dismiss */
  setTimeout(function() {
    document.addEventListener('click', closeOnOutside);
  }, 10);
}

/** Tutup tooltip material dan hapus listener */
function closeMatTooltip() {
  if (matTooltipEl) { matTooltipEl.remove(); matTooltipEl = null; }
  matTooltipSrc = null;
  document.removeEventListener('click', closeOnOutside);
}

/** Handler klik di luar tooltip — dipakai sebagai addEventListener callback */
function closeOnOutside(e) {
  if (matTooltipEl && !matTooltipEl.contains(e.target)) {
    closeMatTooltip();
  }
}

/* ------------------------------------------------------------------
   sortCol — Sort baris tabel detail (pasangan dataRow + bomRow)
   berdasarkan kolom yang diklik. Dipanggil dari <th onclick>.
   type: 'num' = numerik, 'str' = string lokal Indonesia
   ------------------------------------------------------------------ */
function sortCol(th, type) {
  var table = th.closest('table');
  if (!table) return;
  var tbody = table.querySelector('tbody');
  if (!tbody) return;
  var colIdx = [].indexOf.call(th.parentElement.children, th);

  /* Toggle arah: klik pertama = asc, klik berikutnya = desc */
  var asc = !th.classList.contains('sort-asc');
  var siblings = th.parentElement.querySelectorAll('.sort-th');
  for (var i = 0; i < siblings.length; i++) {
    siblings[i].classList.remove('sort-asc', 'sort-desc');
  }
  th.classList.add(asc ? 'sort-asc' : 'sort-desc');

  /* Kumpulkan pasangan [dataRow, bomRow?] — BOM row harus tetap di bawah datanya */
  var dataRows = tbody.querySelectorAll('tr.clickable-item-row');
  var pairs    = [];
  for (var i = 0; i < dataRows.length; i++) {
    var dr  = dataRows[i];
    var nr  = dr.nextElementSibling;
    var bom = (nr && nr.id && nr.id.indexOf('bom-row-') === 0) ? nr : null;
    pairs.push(bom ? [dr, bom] : [dr]);
  }

  /* Sort pasangan berdasarkan nilai sel kolom */
  pairs.sort(function(a, b) {
    var cellA = a[0].children[colIdx];
    var cellB = b[0].children[colIdx];
    var va = cellA ? (cellA.getAttribute('data-val') || cellA.innerText.trim()) : '';
    var vb = cellB ? (cellB.getAttribute('data-val') || cellB.innerText.trim()) : '';
    if (type === 'num') {
      return asc ? (parseFloat(va) || 0) - (parseFloat(vb) || 0)
                 : (parseFloat(vb) || 0) - (parseFloat(va) || 0);
    }
    return asc ? va.localeCompare(vb, 'id') : vb.localeCompare(va, 'id');
  });

  /* Re-append pasangan ke tbody dalam urutan baru */
  for (var i = 0; i < pairs.length; i++) {
    for (var j = 0; j < pairs[i].length; j++) {
      tbody.appendChild(pairs[i][j]);
    }
  }
}

/* ------------------------------------------------------------------
   switchTab — ganti tab aktif di detail panel
   ------------------------------------------------------------------ */
function switchTab(tabId, btn) {
  var container = btn.closest('.detail-content');
  if (!container) return;
  container.querySelectorAll('.tab-pane').forEach(function(p) { p.classList.remove('active'); });
  container.querySelectorAll('.tab-btn').forEach(function(b) { b.classList.remove('active'); });
  var pane = document.getElementById(tabId);
  if (pane) pane.classList.add('active');
  btn.classList.add('active');
}

/* ------------------------------------------------------------------
   expandAllBOM / collapseAllBOM — buka/tutup semua BOM sekaligus
   ------------------------------------------------------------------ */
function expandAllBOM() {
  document.querySelectorAll('[id^="bom-row-"]').forEach(function(tr) {
    var id = tr.id.replace('bom-row-', '');
    var wrapper = document.getElementById('wrapper-' + id);
    if (!wrapper) return;
    tr.style.display = 'table-row';
    void wrapper.offsetHeight;
    wrapper.classList.add('bom-open');
  });
  currentActiveBOMId = '*';
}

function collapseAllBOM() {
  document.querySelectorAll('[id^="wrapper-"]').forEach(function(wrapper) {
    var id = wrapper.id.replace('wrapper-', '');
    var tr = document.getElementById('bom-row-' + id);
    wrapper.classList.remove('bom-open');
    setTimeout(function() {
      if (tr && !wrapper.classList.contains('bom-open')) { tr.style.display = 'none'; }
    }, 330);
  });
  currentActiveBOMId = null;
}

/* ==================== User dropdown (logout) ==================== */

/** Toggle user dropdown menu */
function toggleUserDropdown(e) {
  e.stopPropagation();
  var dd = document.getElementById('user-dropdown');
  if (dd) dd.classList.toggle('open');
}

/** Tutup dropdown saat klik di luar */
function closeUserDropdown(e) {
  var dd = document.getElementById('user-dropdown');
  var hu = document.querySelector('.header-user');
  if (dd && hu && !hu.contains(e.target)) {
    dd.classList.remove('open');
  }
}

/** Logout — redirect ke halaman logoff SAP */
function userLogout() {
  window.location.href = 'index.htm?~logoff';
}

/* ==================== Format angka (B6) ==================== */

/** Format satu elemen angka mentah ABAP ke format lokal id-ID (titik ribuan). */
function fmtCell(el, maxDec) {
  if (!el || el.getAttribute('data-fmt') === '1') return;
  var v = parseFloat(el.textContent.trim());
  if (isNaN(v)) return;
  el.textContent = v.toLocaleString('id-ID', { minimumFractionDigits: 0, maximumFractionDigits: maxDec });
  el.setAttribute('data-fmt', '1');
}

/** Format semua .cur-fmt (uang) & .num-fmt (kuantitas) di dalam root. */
function formatNumbers(root) {
  root = root || document;
  var cur = root.querySelectorAll('.cur-fmt');
  for (var i = 0; i < cur.length; i++) { fmtCell(cur[i], 2); }
  var num = root.querySelectorAll('.num-fmt');
  for (var j = 0; j < num.length; j++) { fmtCell(num[j], 3); }
}

/* ==================== Cegah double-submit (B7) ==================== */

/** Setelah form di-submit, nonaktifkan tombol submit (ditunda agar value tetap terkirim). */
function lockAllForms() {
  var forms = document.querySelectorAll('form');
  for (var i = 0; i < forms.length; i++) {
    forms[i].addEventListener('submit', function(ev) {
      var f = ev.currentTarget;
      setTimeout(function() {
        var btns = f.querySelectorAll('button[type="submit"], button:not([type])');
        for (var k = 0; k < btns.length; k++) { btns[k].disabled = true; btns[k].style.opacity = '0.6'; }
      }, 0);
    });
  }
}

/* ==================== Aksesibilitas keyboard (B9) ==================== */

/** Tandai baris yang bisa diklik agar bisa difokus & diaktifkan keyboard. */
function enhanceA11y(root) {
  root = root || document;
  var rows = root.querySelectorAll('.so-item-row, .clickable-item-row, tr[onclick]');
  for (var i = 0; i < rows.length; i++) {
    if (rows[i].getAttribute('data-a11y') === '1') continue;
    rows[i].setAttribute('tabindex', '0');
    rows[i].setAttribute('role', 'button');
    rows[i].setAttribute('data-a11y', '1');
  }
}

/** Esc menutup tooltip/dropdown; Enter/Space mengaktifkan elemen role=button. */
function handleGlobalKeydown(e) {
  if (e.key === 'Escape' || e.keyCode === 27) {
    closeMatTooltip();
    var dd = document.getElementById('user-dropdown');
    if (dd) dd.classList.remove('open');
    return;
  }
  if (e.key === 'Enter' || e.key === ' ' || e.keyCode === 13 || e.keyCode === 32) {
    var el = document.activeElement;
    if (el && el.getAttribute && el.getAttribute('role') === 'button' &&
        el.tagName !== 'BUTTON' && el.tagName !== 'A' && el.tagName !== 'INPUT') {
      e.preventDefault();
      el.click();
    }
  }
}

/* ------------------------------------------------------------------
   Entry point — inisialisasi setelah seluruh DOM siap
   ------------------------------------------------------------------ */
window.onload = function() {
  /* === Inisialisasi bersama (dipakai kedua halaman) === */
  lockAllForms();
  formatNumbers(document);
  enhanceA11y(document);
  document.addEventListener('click', closeUserDropdown);
  document.addEventListener('keydown', handleGlobalKeydown);

  var soViewport = document.getElementById('so-list-viewport');
  if (soViewport) {
    /* === Halaman list (Monitoring/Riwayat): kumpulkan SO card & init paginasi === */
    var ps = parseInt(soViewport.getAttribute('data-page-size'), 10);
    if (ps > 0) { rowsPerPage = ps; }
    var cards = document.querySelectorAll('[data-type="so-card"]');
    for (var i = 0; i < cards.length; i++) { soCards.push(cards[i]); }
    currentPage = getPageFromHash();
    renderPagination();
    return;
  }

  /* === Halaman Index: render chart & pasang event listener === */
  drawBarChart();
  drawDonutChart();
  document.body.classList.remove('page-loading');

  /* Gambar ulang saat window di-resize — debounce 200ms mencegah flicker */
  window.addEventListener('resize', debounce(function() {
    drawBarChart();
    drawDonutChart();
  }, 200));

  var bc = document.getElementById('barChart');
  if (bc) {
    /* Highlight bar saat hover */
    bc.addEventListener('mousemove', function(e) {
      var rect  = bc.getBoundingClientRect();
      var scale = bc.width / rect.width;
      var mx    = (e.clientX - rect.left) * scale;
      var found = -1;
      for (var i = 0; i < barState.length; i++) {
        if (mx >= barState[i].x && mx <= barState[i].x + barState[i].w) {
          found = i; break;
        }
      }
      if (found !== hoveredBar) {
        hoveredBar = found;
        bc.style.cursor = found >= 0 ? 'pointer' : 'default';
        drawBarChart();
      }
    });

    /* Reset hover saat mouse keluar dari canvas */
    bc.addEventListener('mouseout', function() {
      if (hoveredBar >= 0) {
        hoveredBar = -1;
        bc.style.cursor = 'default';
        drawBarChart();
      }
    });

    /* Drill-down ke monitoring.htm saat klik bar */
    bc.addEventListener('click', function(e) {
      var rect  = bc.getBoundingClientRect();
      var scale = bc.width / rect.width;
      var mx    = (e.clientX - rect.left) * scale;
      for (var i = 0; i < barState.length; i++) {
        if (mx >= barState[i].x && mx <= barState[i].x + barState[i].w) {
          drillDown(barState[i].idx);
          return;
        }
      }
    });
  }
};
