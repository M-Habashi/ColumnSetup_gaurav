(() => {
  'use strict';

  const report = window.GPT564_REPORT;
  const $ = (id) => document.getElementById(id);
  const svgNS = 'http://www.w3.org/2000/svg';
  const colors = {
    desired: '#111111', command: '#ac6420', measured: '#007ca8',
    force: '#74058a', original: '#901500', proposed: '#39bf5e',
    muted: '#646464'
  };
  const chartDefs = [
    { id: 'tracking', wrap: 'trackingChart', legend: 'trackingLegend' },
    { id: 'osi', wrap: 'osiChart', legend: 'osiLegend' },
    { id: 'authority', wrap: 'authorityChart', legend: 'authorityLegend' }
  ];
  const state = {
    caseIndex: 0, full: [0, 1], view: [0, 1], charts: {}, hover: NaN,
    hidden: { tracking: new Set(), osi: new Set(), authority: new Set() }
  };

  if (!report || !Array.isArray(report.cases) || report.cases.length === 0) {
    $('dataStatus').textContent = 'Missing';
    $('dataMessage').textContent = 'report_data.js was not loaded. Run run_gpt5_6_4_validation.m, then reopen this report.';
    $('dataMessage').classList.add('is-visible');
    return;
  }

  const finite = (x) => Number.isFinite(x);
  const fmt = (x, digits = 3) => finite(x) ? Number(x).toFixed(digits) : '—';
  const esc = (x) => String(x).replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
  })[c]);
  const el = (name, attrs = {}) => {
    const node = document.createElementNS(svgNS, name);
    Object.entries(attrs).forEach(([key, value]) => node.setAttribute(key, value));
    return node;
  };
  const clamp = (x, lo, hi) => Math.min(Math.max(x, lo), hi);

  function lowerBound(a, x) {
    let lo = 0, hi = a.length;
    while (lo < hi) {
      const mid = (lo + hi) >> 1;
      if (a[mid] < x) lo = mid + 1; else hi = mid;
    }
    return lo;
  }

  function nearest(a, x) {
    if (!a.length) return -1;
    const i = lowerBound(a, x);
    if (i === 0) return 0;
    if (i === a.length) return a.length - 1;
    return Math.abs(a[i] - x) < Math.abs(a[i - 1] - x) ? i : i - 1;
  }

  function seriesFor(c, id) {
    if (id === 'tracking') {
      const t = c.tracking?.t || [];
      return [
        ['dd', 'Desired', t, c.tracking?.dd, colors.desired, true],
        ['dc', 'Command', t, c.tracking?.dc, colors.command],
        ['dm', 'Measured', t, c.tracking?.dm, colors.measured],
        ['dm_original', 'Original response', t, c.tracking?.dm_original, colors.original],
        ['dm_proposed', 'Proposed response', t, c.tracking?.dm_proposed, colors.proposed]
      ];
    }
    if (id === 'osi') {
      const t = c.osi?.t || [];
      return [
        ['original', 'Original OSI', t, c.osi?.original, colors.original],
        ['proposed', 'Proposed OSI', t, c.osi?.proposed, colors.proposed],
        ['true_b', 'True margin', t, c.osi?.true_b, colors.desired, true],
        ['proposed_st', 'Coherent evidence', t, c.osi?.proposed_st, colors.measured],
        ['proposed_res', 'Residual evidence', t, c.osi?.proposed_res, colors.force],
        ['target', 'Target', t, t.map(() => c.target), colors.muted, true]
      ];
    }
    const t = c.authority?.t || [];
    return [
      ['original', 'Original authority', t, c.authority?.original, colors.original],
      ['proposed', 'Proposed authority', t, c.authority?.proposed, colors.proposed],
      ['logged', 'Logged authority', t, c.authority?.logged, colors.measured],
      ['diag_gain', 'Diagnostic gain', t, c.authority?.diag_gain, colors.force, true, true]
    ];
  }

  function validSeries(c, id) {
    return seriesFor(c, id)
      .filter((s) => Array.isArray(s[2]) && Array.isArray(s[3]) && s[2].length && s[3].length)
      .map(([key, label, t, y, color, dashed = false, right = false]) => ({
        key, label, t, y, color, dashed, right
      }));
  }

  function allTimes(c) {
    const times = chartDefs.flatMap((d) => validSeries(c, d.id).flatMap((s) => [s.t[0], s.t[s.t.length - 1]]));
    return times.filter(finite);
  }

  function populateSummary() {
    const s = report.summary;
    $('dataStatus').textContent = 'Loaded';
    $('caseCount').textContent = String(report.cases.length);
    $('canonicalStatus').textContent = `${s.canonical_pass_count}/${s.canonical_total} pass`;
    $('scoreStatus').textContent = `${fmt(s.fabby_score)} > ${fmt(s.score_threshold, 0)}`;
    $('overallStatus').textContent = s.all_pass ? 'PASS' : 'FAIL';
    $('overallStatus').className = s.all_pass ? 'pass' : 'fail';
    $('generatedAt').textContent = report.generated_at;

    const rows = [
      ['Canonical FABLE suite', `${s.canonical_pass_count}/${s.canonical_total}`, `${s.canonical_total}/${s.canonical_total}`, s.canonical_pass_count === s.canonical_total],
      ['Fabby mean score', fmt(s.fabby_score), `> ${fmt(s.score_threshold, 0)}`, s.fabby_score > s.score_threshold],
      ['GDBqFpKb formal replay', `edges ${s.gdb_edge_latency_s.map((x) => fmt(x)).join(', ')} s`, 'each ≤ 2 s + recovery gates', s.gdb_pass],
      ['Calibration replay', `edges ${s.calibration_edge_latency_s.map((x) => fmt(x)).join(', ')} s`, 'each ≤ 2 s + smooth recovery', s.calibration_pass],
      ['Calibration authority step', `${fmt(s.original_max_step, 4)} → ${fmt(s.proposed_max_step, 4)}`, 'proposed ≤ 0.03', s.proposed_max_step <= 0.03],
      ['Overall acceptance', s.all_pass ? 'All gates pass' : 'One or more gates failed', 'all gates', s.all_pass]
    ];
    $('acceptanceBody').innerHTML = rows.map(([name, measured, acceptance, pass]) =>
      `<tr><td>${esc(name)}</td><td>${esc(measured)}</td><td>${esc(acceptance)}</td><td class="${pass ? 'pass' : 'fail'}">${pass ? 'PASS' : 'FAIL'}</td></tr>`
    ).join('');

    $('findingsList').innerHTML = [
      `The 37.7 s and 44.9 s calibration gain changes are now indicated after ${fmt(s.calibration_edge_latency_s[0])} s and ${fmt(s.calibration_edge_latency_s[1])} s.`,
      `Late authority travel falls from ${fmt(s.original_late_travel)} to ${fmt(s.proposed_late_travel)}, while the largest observed update falls from ${fmt(s.original_max_step, 4)} to ${fmt(s.proposed_max_step, 4)}.`,
      `Authority still recovers without a safety trigger: the calibration replay ends at ${fmt(s.proposed_final_authority)}, below the unstable full-authority endpoint but well above the 0.75 performance floor.`,
      'The OSI retains the two physical evidence branches and replaces the binary residual-fit gate with the continuous weight w = w_coh + 0.175 A(1 − w_coh).',
      'The regulator remains a multiplicative log-domain update with a bounded step. A 20 s low-activity release removes fast snap-back; the calibration profile only changes target, rate, upward boost, and step limit.',
      'Saved-record replays are counterfactual command comparisons. The ten FABLE cases are the closed-loop offline stability evidence; a physical rerun is still required before actuator deployment.'
    ].map((x) => `<li>${x}</li>`).join('');
  }

  function populateSelect() {
    $('caseSelect').innerHTML = report.cases.map((c, i) => {
      const prefix = c.kind === 'synthetic' ? `${i + 1}.` : 'Test ·';
      return `<option value="${i}">${esc(prefix)} ${esc(c.label)}</option>`;
    }).join('');
  }

  function updateCaseFacts(c) {
    const facts = [['Kind', c.kind], ['Target', fmt(c.target)]];
    const m = c.metrics || {};
    if ('proposed_pass' in m) facts.push(['Proposed', m.proposed_pass ? 'PASS' : 'FAIL']);
    if (finite(m.proposed_score)) facts.push(['Fabby', fmt(m.proposed_score, 2)]);
    if (Array.isArray(m.edge_latency_s)) facts.push(['Edge latency', `${m.edge_latency_s.map((x) => fmt(x)).join(', ')} s`]);
    if (finite(m.max_step)) facts.push(['Max Δa', fmt(m.max_step, 4)]);
    $('caseFacts').innerHTML = facts.map(([k, v]) => `<div><dt>${esc(k)}</dt><dd>${esc(v)}</dd></div>`).join('');
  }

  function makeLegend(def, series) {
    const parent = $(def.legend);
    parent.innerHTML = '';
    series.forEach((s) => {
      const b = document.createElement('button');
      b.type = 'button';
      b.dataset.key = s.key;
      b.setAttribute('aria-pressed', String(!state.hidden[def.id].has(s.key)));
      b.innerHTML = `<span class="legend-swatch${s.dashed ? ' is-dashed' : ''}" style="--series-color:${s.color}"></span>${esc(s.label)}`;
      b.addEventListener('click', () => {
        if (state.hidden[def.id].has(s.key)) state.hidden[def.id].delete(s.key);
        else state.hidden[def.id].add(s.key);
        b.setAttribute('aria-pressed', String(!state.hidden[def.id].has(s.key)));
        renderAll();
      });
      parent.appendChild(b);
    });
  }

  function extent(series, xDomain, right = false) {
    let lo = Infinity, hi = -Infinity;
    series.filter((s) => s.right === right && !state.hidden[state.activeChart].has(s.key)).forEach((s) => {
      const first = Math.max(0, lowerBound(s.t, xDomain[0]) - 1);
      const last = Math.min(s.t.length, lowerBound(s.t, xDomain[1]) + 1);
      const stride = Math.max(1, Math.ceil((last - first) / 2500));
      for (let i = first; i < last; i += stride) {
        const v = s.y[i];
        if (finite(v)) { lo = Math.min(lo, v); hi = Math.max(hi, v); }
      }
    });
    if (!finite(lo) || !finite(hi)) return [0, 1];
    if (lo === hi) { lo -= Math.max(0.1, Math.abs(lo) * 0.1); hi += Math.max(0.1, Math.abs(hi) * 0.1); }
    const pad = 0.08 * (hi - lo);
    return [lo - pad, hi + pad];
  }

  function pathData(s, xDomain, xMap, yMap) {
    const first = Math.max(0, lowerBound(s.t, xDomain[0]) - 1);
    const last = Math.min(s.t.length, lowerBound(s.t, xDomain[1]) + 1);
    const stride = Math.max(1, Math.ceil((last - first) / 2200));
    let d = '', drawing = false;
    for (let i = first; i < last; i += stride) {
      if (!finite(s.t[i]) || !finite(s.y[i])) { drawing = false; continue; }
      d += `${drawing ? 'L' : 'M'}${xMap(s.t[i]).toFixed(2)},${yMap(s.y[i]).toFixed(2)}`;
      drawing = true;
    }
    if (last - 1 > first && finite(s.t[last - 1]) && finite(s.y[last - 1])) {
      d += `L${xMap(s.t[last - 1]).toFixed(2)},${yMap(s.y[last - 1]).toFixed(2)}`;
    }
    return d;
  }

  function renderChart(def, c) {
    const wrap = $(def.wrap), svg = wrap.querySelector('svg');
    const W = Math.max(680, Math.round(wrap.clientWidth || 1200)), H = 278;
    const margin = { l: 62, r: def.id === 'authority' ? 58 : 20, t: 16, b: 34 };
    const pw = W - margin.l - margin.r, ph = H - margin.t - margin.b;
    const xDomain = state.view;
    const xMap = (x) => margin.l + (x - xDomain[0]) / (xDomain[1] - xDomain[0]) * pw;
    const series = validSeries(c, def.id);
    state.activeChart = def.id;
    const yDomain = extent(series, xDomain, false);
    const yRight = extent(series, xDomain, true);
    const yMap = (y) => margin.t + (yDomain[1] - y) / (yDomain[1] - yDomain[0]) * ph;
    const yrMap = (y) => margin.t + (yRight[1] - y) / (yRight[1] - yRight[0]) * ph;

    svg.setAttribute('viewBox', `0 0 ${W} ${H}`);
    svg.innerHTML = '';
    const clipId = `clip-${def.id}`;
    const defs = el('defs');
    const clip = el('clipPath', { id: clipId });
    clip.appendChild(el('rect', { x: margin.l, y: margin.t, width: pw, height: ph }));
    defs.appendChild(clip); svg.appendChild(defs);

    for (let i = 0; i <= 4; i++) {
      const gx = margin.l + pw * i / 4, gy = margin.t + ph * i / 4;
      svg.appendChild(el('line', { x1: gx, x2: gx, y1: margin.t, y2: margin.t + ph, stroke: '#e6e6e2', 'stroke-width': 1 }));
      svg.appendChild(el('line', { x1: margin.l, x2: margin.l + pw, y1: gy, y2: gy, stroke: '#e6e6e2', 'stroke-width': 1 }));
      const xt = el('text', { x: gx, y: H - 10, fill: '#555', 'font-size': 10, 'text-anchor': 'middle' });
      xt.textContent = fmt(xDomain[0] + (xDomain[1] - xDomain[0]) * i / 4, 1); svg.appendChild(xt);
      const yt = el('text', { x: margin.l - 9, y: gy + 3, fill: '#555', 'font-size': 10, 'text-anchor': 'end' });
      yt.textContent = fmt(yDomain[1] - (yDomain[1] - yDomain[0]) * i / 4, 3); svg.appendChild(yt);
      if (def.id === 'authority' && series.some((s) => s.right)) {
        const rt = el('text', { x: W - margin.r + 8, y: gy + 3, fill: colors.force, 'font-size': 10 });
        rt.textContent = fmt(yRight[1] - (yRight[1] - yRight[0]) * i / 4, 2); svg.appendChild(rt);
      }
    }

    const xLabel = el('text', { x: margin.l + pw / 2, y: H - 1, fill: '#555', 'font-size': 10, 'text-anchor': 'middle' });
    xLabel.textContent = 'Time (s)'; svg.appendChild(xLabel);
    const plot = el('g', { 'clip-path': `url(#${clipId})` });
    (c.events || []).forEach((event) => {
      if (!finite(event.t) || event.t < xDomain[0] || event.t > xDomain[1]) return;
      plot.appendChild(el('line', { x1: xMap(event.t), x2: xMap(event.t), y1: margin.t, y2: margin.t + ph, stroke: '#9b9b95', 'stroke-dasharray': '3 4' }));
    });
    series.forEach((s) => {
      if (state.hidden[def.id].has(s.key)) return;
      const path = el('path', {
        d: pathData(s, xDomain, xMap, s.right ? yrMap : yMap), fill: 'none', stroke: s.color,
        'stroke-width': s.key === 'dd' ? 2.6 : 1.8, 'stroke-linejoin': 'round', 'stroke-linecap': 'round'
      });
      if (s.dashed) path.setAttribute('stroke-dasharray', s.key === 'dd' ? '8 5' : '5 4');
      plot.appendChild(path);
    });
    const crosshair = el('line', { x1: margin.l, x2: margin.l, y1: margin.t, y2: margin.t + ph, stroke: '#333', 'stroke-width': 1, opacity: 0 });
    plot.appendChild(crosshair); svg.appendChild(plot);
    state.charts[def.id] = { def, wrap, svg, series, margin, pw, ph, xMap, xDomain, crosshair };
  }

  function renderAll() {
    const c = report.cases[state.caseIndex];
    chartDefs.forEach((def) => renderChart(def, c));
    $('viewStatus').textContent = `Shared view ${fmt(state.view[0], 2)}–${fmt(state.view[1], 2)} s`;
    if (finite(state.hover)) updateHover(state.hover);
  }

  function updateHover(time) {
    state.hover = clamp(time, state.view[0], state.view[1]);
    Object.values(state.charts).forEach((chart) => {
      const x = chart.xMap(state.hover);
      chart.crosshair.setAttribute('x1', x); chart.crosshair.setAttribute('x2', x);
      chart.crosshair.setAttribute('opacity', 0.75);
      const rows = chart.series.filter((s) => !state.hidden[chart.def.id].has(s.key)).map((s) => {
        const i = nearest(s.t, state.hover), value = i >= 0 ? s.y[i] : NaN;
        return `<div class="tooltip-row"><span class="tooltip-label">${esc(s.label)}</span><span class="tooltip-value">${fmt(value, 4)}</span></div>`;
      }).join('');
      const tip = chart.wrap.querySelector('.tooltip');
      tip.innerHTML = `<div class="tooltip-time">t = ${fmt(state.hover, 3)} s</div>${rows}`;
      tip.style.left = `${clamp(x + 10, 8, Math.max(8, chart.wrap.clientWidth - 286))}px`;
      tip.style.top = '10px'; tip.classList.add('is-visible');
    });
  }

  function hideHover() {
    state.hover = NaN;
    Object.values(state.charts).forEach((chart) => {
      chart.crosshair.setAttribute('opacity', 0);
      chart.wrap.querySelector('.tooltip').classList.remove('is-visible');
    });
  }

  function resetView() {
    state.view = [...state.full];
    hideHover(); renderAll();
  }

  function bindInteractions() {
    chartDefs.forEach((def) => {
      const svg = $(def.wrap).querySelector('svg');
      let drag = null;
      const timeFromEvent = (event) => {
        const chart = state.charts[def.id], rect = svg.getBoundingClientRect();
        const x = (event.clientX - rect.left) / rect.width * svg.viewBox.baseVal.width;
        return chart.xDomain[0] + (x - chart.margin.l) / chart.pw * (chart.xDomain[1] - chart.xDomain[0]);
      };
      svg.addEventListener('pointermove', (event) => {
        if (drag) {
          const chart = state.charts[def.id], rect = svg.getBoundingClientRect();
          const shift = -(event.clientX - drag.x) / rect.width * svg.viewBox.baseVal.width / chart.pw * drag.span;
          let lo = drag.view[0] + shift, hi = drag.view[1] + shift;
          if (lo < state.full[0]) { hi += state.full[0] - lo; lo = state.full[0]; }
          if (hi > state.full[1]) { lo -= hi - state.full[1]; hi = state.full[1]; }
          state.view = [lo, hi]; renderAll();
        } else updateHover(timeFromEvent(event));
      });
      svg.addEventListener('pointerleave', () => { if (!drag) hideHover(); });
      svg.addEventListener('pointerdown', (event) => {
        drag = { x: event.clientX, view: [...state.view], span: state.view[1] - state.view[0] };
        svg.classList.add('is-dragging'); svg.setPointerCapture(event.pointerId);
      });
      const endDrag = (event) => { drag = null; svg.classList.remove('is-dragging'); if (svg.hasPointerCapture(event.pointerId)) svg.releasePointerCapture(event.pointerId); };
      svg.addEventListener('pointerup', endDrag); svg.addEventListener('pointercancel', endDrag);
      svg.addEventListener('wheel', (event) => {
        event.preventDefault();
        const center = clamp(timeFromEvent(event), state.view[0], state.view[1]);
        const span = state.view[1] - state.view[0], total = state.full[1] - state.full[0];
        const next = clamp(span * Math.exp(event.deltaY * 0.0015), total / 200, total);
        const ratio = (center - state.view[0]) / span;
        let lo = center - ratio * next, hi = lo + next;
        if (lo < state.full[0]) { hi += state.full[0] - lo; lo = state.full[0]; }
        if (hi > state.full[1]) { lo -= hi - state.full[1]; hi = state.full[1]; }
        state.view = [lo, hi]; renderAll();
      }, { passive: false });
      svg.addEventListener('dblclick', resetView);
    });
  }

  function selectCase(index) {
    state.caseIndex = Number(index);
    const c = report.cases[state.caseIndex];
    $('caseTitle').textContent = c.label;
    $('caseSource').textContent = c.source;
    updateCaseFacts(c);
    const times = allTimes(c);
    state.full = [Math.min(...times), Math.max(...times)];
    if (!(state.full[1] > state.full[0])) state.full = [0, 1];
    state.view = [...state.full]; state.hover = NaN;
    chartDefs.forEach((def) => makeLegend(def, validSeries(c, def.id)));
    renderAll();
  }

  populateSummary();
  populateSelect();
  bindInteractions();
  $('caseSelect').addEventListener('change', (event) => selectCase(event.target.value));
  $('resetView').addEventListener('click', resetView);
  window.addEventListener('resize', () => renderAll());
  selectCase(0);
})();
