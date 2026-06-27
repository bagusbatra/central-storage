/* =======================================================================
   Dashboard Central Storage KMI 2 — Plant 2000
   Shared JS for index.htm & monitoring.htm
   Data variables (weekLabels, doneCounts, dll.) dideklarasikan sebagai
   inline <script> di index.htm karena mengandung nilai <%= %> dari ABAP.
   ======================================================================= */

var barState = [];
var hoveredBar = -1;

/* ===== Monitoring shared state ===== */
var rowsPerPage = 5;
var currentPage = 1;
var soCards = [];
var currentActiveVBELN = null;
var currentActiveBOMId = null;

/* ------------------------------------------------------------------
   Helper: rounded rectangle (semua sudut)
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
   Helper: rounded top corners saja (untuk segment teratas stacked bar)
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
   Drill-down: klik bar → buka monitoring.htm dengan filter tanggal
   weekDates[weekIdx] berformat YYYYMMDD (Senin awal minggu)
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
   Stacked bar chart: Selesai (hijau) / Proses (biru) / Belum (abu)
   Sumber data: weekLabels, weekDates, doneCounts, inprogCounts, noprodCounts
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

  /* Hitung total per minggu dan nilai maksimum */
  var totals = [], max = 0;
  for (var i = 0; i < n; i++) {
    totals[i] = doneCounts[i] + inprogCounts[i] + noprodCounts[i];
    if (totals[i] > max) max = totals[i];
  }
  if (max === 0) max = 1;
  var tickStep = Math.ceil(max / 5);
  var tickMax  = tickStep * 5;
  if (tickMax === 0) tickMax = 5;

  /* Garis grid horizontal + label Y */
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
    var total  = totals[i];
    var bx     = padL + i * slotW + (slotW - barW) / 2;
    var baseY  = padT + chartH;
    var cx     = bx + barW / 2;
    barState.push({ x: bx, w: barW, idx: i, cx: cx, total: total, done: doneCounts[i], inprog: inprogCounts[i], noprod: noprodCounts[i], label: weekLabels[i] });

    /* Tinggi masing-masing segment */
    var np_h = noprodCounts[i] > 0 ? (noprodCounts[i] / tickMax) * chartH : 0;
    var ip_h = inprogCounts[i] > 0 ? (inprogCounts[i] / tickMax) * chartH : 0;
    var dn_h = doneCounts[i]   > 0 ? (doneCounts[i]   / tickMax) * chartH : 0;

    /* Tentukan segment paling atas (dapat rounded top) */
    var topSeg = 0;
    if (doneCounts[i]    > 0) topSeg = 1;
    else if (inprogCounts[i] > 0) topSeg = 2;
    else if (noprodCounts[i] > 0) topSeg = 3;

    /* Gambar dari bawah ke atas: abu → biru → hijau */
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

    /* Badge angka total di atas bar */
    if (total > 0) {
      var topY = padT + chartH - (total / tickMax) * chartH;
      ctx.font  = 'bold 12px Segoe UI, Arial, sans-serif';
      var bTxt  = String(total);
      var bW    = ctx.measureText(bTxt).width + 14;
      var bH    = 20;
      var bX    = cx - bW / 2;
      var bY    = topY - bH - 6;
      drawRoundRect(ctx, bX, bY, bW, bH, 10);
      ctx.fillStyle = '#1e3a8a'; ctx.fill();
      ctx.fillStyle = '#ffffff'; ctx.textAlign = 'center';
      ctx.fillText(bTxt, cx, bY + bH - 5);
    }

    /* Marker garis tipis untuk bar kosong */
    if (total === 0) {
      ctx.beginPath(); ctx.strokeStyle = '#e5e7eb'; ctx.lineWidth = 1;
      ctx.moveTo(cx, padT + chartH - 4); ctx.lineTo(cx, padT + chartH); ctx.stroke();
    }

    /* Label X: "Minggu" + DD/MM dua baris */
    ctx.fillStyle = '#6b7280';
    ctx.font = '9px Segoe UI, Arial, sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText('Minggu', cx, padT + chartH + 14);
    ctx.font = 'bold 10px Segoe UI, Arial, sans-serif';
    ctx.fillStyle = '#374151';
    ctx.fillText(weekLabels[i], cx, padT + chartH + 26);
  }

  /* Tooltip on hover */
  if (hoveredBar >= 0 && hoveredBar < n) {
    var d = barState[hoveredBar];
    var lines = [
      'Minggu ' + d.label,
      'Selesai: ' + d.done,
      'Proses:   ' + d.inprog,
      'Belum:     ' + d.noprod,
      'Total:     ' + d.total
    ];
    ctx.font = '12px Segoe UI, Arial, sans-serif';
    var tw = 0;
    for (var li = 0; li < lines.length; li++) {
      var lw = ctx.measureText(lines[li]).width;
      if (lw > tw) tw = lw;
    }
    var th = lines.length * 20 + 12;
    tw += 24;
    var tx = d.cx + d.w / 2 + 8;
    var ty = padT + chartH - (d.total / tickMax) * chartH - th - 4;
    if (ty < padT) ty = padT + 4;
    if (tx + tw > W - padR) tx = d.cx - d.w / 2 - tw - 8;

    /* Background */
    drawRoundRect(ctx, tx, ty, tw, th, 6);
    ctx.fillStyle = '#1f2937'; ctx.fill();

    /* Arrow pointing down to bar */
    ctx.beginPath();
    ctx.moveTo(tx + tw / 2 - 6, ty + th);
    ctx.lineTo(tx + tw / 2, ty + th + 7);
    ctx.lineTo(tx + tw / 2 + 6, ty + th);
    ctx.fillStyle = '#1f2937'; ctx.fill();

    /* Text lines */
    ctx.fillStyle = '#ffffff';
    ctx.textAlign = 'left';
    for (var li = 0; li < lines.length; li++) {
      var isFirst = (li === 0);
      ctx.font = isFirst ? 'bold 12px Segoe UI, Arial, sans-serif' : '12px Segoe UI, Arial, sans-serif';
      ctx.fillStyle = isFirst ? '#93c5fd' : '#ffffff';
      ctx.fillText(lines[li], tx + 12, ty + 20 + li * 20);
    }
  }
}

/* ------------------------------------------------------------------
   Donut chart: Selesai / Proses / Belum
   Sumber data: doneCount, progCount, noprodCount
   ------------------------------------------------------------------ */
function drawDonutChart() {
  var canvas = document.getElementById('donutChart');
  if (!canvas || !canvas.getContext) return;
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

/* ===== Monitoring functions ===== */
function renderPagination() {
  var totalPages = Math.ceil(soCards.length / rowsPerPage) || 1;
  if (currentPage > totalPages) currentPage = totalPages;
  if (currentPage < 1) currentPage = 1;

  var startIndex = (currentPage - 1) * rowsPerPage;
  var endIndex = startIndex + rowsPerPage;

  for (var i = 0; i < soCards.length; i++) {
    if (i >= startIndex && i < endIndex) {
      soCards[i].style.display = 'block';
    } else {
      soCards[i].style.display = 'none';
    }
  }

  document.getElementById('page-indicator').innerText = currentPage + ' / ' + totalPages;
  document.getElementById('btn-prev').disabled = (currentPage === 1);
  document.getElementById('btn-next').disabled = (currentPage === totalPages);
}

function changePage(direction) {
  currentPage += direction;
  renderPagination();
}

function viewDetails(vbeln) {
  if (currentActiveVBELN) {
    var oldRow = document.getElementById('row-' + currentActiveVBELN);
    if (oldRow) oldRow.classList.remove('active');
    var oldPanel = document.getElementById('panel-' + currentActiveVBELN);
    if (oldPanel) oldPanel.classList.remove('active');
  }
  if (currentActiveBOMId) {
    hideBOMRow(currentActiveBOMId);
  }
  currentActiveVBELN = vbeln;
  document.getElementById('row-' + vbeln).classList.add('active');
  document.getElementById('placeholder-msg').style.display = 'none';
  document.getElementById('panel-' + vbeln).classList.add('active');
}

function toggleBOMRow(bomId) {
  var trContainer = document.getElementById('bom-row-' + bomId);
  var wrapper = document.getElementById('wrapper-' + bomId);

  if (trContainer.style.display === 'none') {
    if (currentActiveBOMId && currentActiveBOMId !== bomId) {
      hideBOMRow(currentActiveBOMId);
    }
    trContainer.style.display = 'table-row';
    wrapper.style.display = 'block';
    currentActiveBOMId = bomId;
  } else {
    hideBOMRow(bomId);
  }
}

function hideBOMRow(bomId) {
  var trContainer = document.getElementById('bom-row-' + bomId);
  var wrapper = document.getElementById('wrapper-' + bomId);
  if (trContainer) trContainer.style.display = 'none';
  if (wrapper) wrapper.style.display = 'none';
  if (currentActiveBOMId === bomId) currentActiveBOMId = null;
}

/* ------------------------------------------------------------------
   Entry point: gambar chart / init monitoring setelah DOM siap
   ------------------------------------------------------------------ */
window.onload = function() {
  /* Monitoring page — collect SO cards */
  var soViewport = document.getElementById('so-list-viewport');
  if (soViewport) {
    var elements = document.getElementsByTagName('div');
    for (var i = 0; i < elements.length; i++) {
      if (elements[i].getAttribute('data-type') === 'so-card') {
        soCards.push(elements[i]);
      }
    }
    renderPagination();
    return;
  }

  /* Index page — draw charts */
  drawBarChart();
  drawDonutChart();
  document.body.classList.remove('page-loading');

  var bc = document.getElementById('barChart');
  if (bc) {
    bc.addEventListener('mousemove', function(e) {
      var rect  = bc.getBoundingClientRect();
      var scale = bc.width / rect.width;
      var mx    = (e.clientX - rect.left) * scale;
      var found = -1;
      for (var i = 0; i < barState.length; i++) {
        if (mx >= barState[i].x && mx <= barState[i].x + barState[i].w) {
          found = i;
          break;
        }
      }
      if (found !== hoveredBar) {
        hoveredBar = found;
        bc.style.cursor = found >= 0 ? 'pointer' : 'default';
        drawBarChart();
      }
    });

    bc.addEventListener('mouseout', function() {
      if (hoveredBar >= 0) {
        hoveredBar = -1;
        bc.style.cursor = 'default';
        drawBarChart();
      }
    });

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
