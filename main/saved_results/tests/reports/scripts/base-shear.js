"use strict";

import {
  DEFAULT_COLORS, escapeHtml, visiblePath, formatFactor, rgba,
  lowerBound, upperBound, buildTree, treeMarkup
} from "./hysteresis-explorer.js?v=20261027-3";

const AXIS = { gridcolor: "#30322d", zerolinecolor: "#777a70", linecolor: "#4a4c46", mirror: true, autorange: true };

function peakAbs(values) {
  return values.reduce((peak, value) => Math.max(peak, Math.abs(value)), 0);
}

function layout(plot, xTitle, yTitle, revision) {
  return {
    paper_bgcolor: "#141412",
    plot_bgcolor: "#141412",
    font: { color: "#d6d4cb", family: "IBM Plex Sans, sans-serif", size: 12 },
    margin: plot.clientWidth < 560 ? { l: 64, r: 12, t: 64, b: 60 } : { l: 82, r: 24, t: 72, b: 68 },
    showlegend: true,
    legend: { orientation: "h", x: 0, y: 1, yanchor: "bottom" },
    hovermode: "closest",
    uirevision: revision,
    xaxis: { ...AXIS, title: { text: xTitle, standoff: 16 } },
    yaxis: { ...AXIS, title: { text: yTitle, standoff: 16 } }
  };
}

export async function initBaseShear(container, { metadata, entries }) {
  const tree = container.querySelector("#bsFileTree");
  const search = container.querySelector("#bsFileSearch");
  const details = container.querySelector("#bsDetails");
  const count = container.querySelector("#bsSelectionCount");
  const timePlot = container.querySelector("#bsTimePlot");
  const loopPlot = container.querySelector("#bsLoopPlot");
  const loopSummary = container.querySelector("#bsLoopSummary");
  const alphaSlider = container.querySelector("#bsAlphaSlider");
  const alphaValue = container.querySelector("#bsAlphaValue");
  const articleId = container.closest(".report-article").id;
  const config = { responsive: true, scrollZoom: true, displaylogo: false, modeBarButtonsToRemove: ["select2d", "lasso2d"] };
  const selected = new Map();
  let timeWindow = null;
  let relayoutReady = false;
  let alpha = metadata.settings.density_alpha;
  let frame = null;
  alphaSlider.value = alpha;
  alphaValue.value = alpha.toFixed(2);

  const files = () => entries
    .filter(entry => !metadata.files[entry.path].archived)
    .map(entry => ({ ...entry, available: entry.base_shear_available, error: entry.base_shear_error || "No base shear for this test" }));
  const name = test => metadata.files[test.path].display_name;
  const color = index => DEFAULT_COLORS[index % DEFAULT_COLORS.length];

  function applySearch() {
    const query = search.value.trim().toLowerCase();
    tree.querySelectorAll(".tree-file").forEach(row => {
      row.hidden = Boolean(query) && !row.dataset.search.includes(query);
    });
    if (query) tree.querySelectorAll("details").forEach(folder => { folder.open = true; });
  }

  function renderTree() {
    const current = files();
    const view = { files: Object.fromEntries(current.map(entry => [entry.path, { ...metadata.files[entry.path], selected: selected.has(entry.path) }])) };
    tree.innerHTML = current.length ? treeMarkup(buildTree(current), view) : '<p class="tree-empty">No current files.</p>';
    applySearch();
  }

  function renderLoop() {
    const tests = [...selected.values()];
    const traces = tests.map((test, index) => {
      const start = timeWindow ? lowerBound(test.t, timeWindow[0]) : 0;
      const end = timeWindow ? upperBound(test.t, timeWindow[1]) : test.t.length;
      return {
        type: "scattergl", mode: "lines", name: name(test),
        x: test.x1.slice(start, end), y: test.vb.slice(start, end).map(value => value / 1000),
        opacity: 0.7, line: { color: rgba(color(index), alpha), width: 1.5 },
        hovertemplate: `${escapeHtml(name(test))}<br>x1_n %{x:.3f} mm<br>V_b %{y:.2f} kN<extra></extra>`
      };
    });
    loopSummary.textContent = timeWindow
      ? `Earthquake time ${timeWindow[0].toFixed(1)}–${timeWindow[1].toFixed(1)} s. Double-click the time history to show the full record.`
      : "Full record. Zoom the time history above to focus a time window.";
    Plotly.react(loopPlot, traces,
      layout(loopPlot, "First-floor displacement, x1_n (mm)", "Base shear, V_b (kN)", `${[...selected.keys()].join("|")}|${timeWindow}`),
      config);
  }

  function render() {
    const tests = [...selected.values()];
    count.textContent = `${tests.length} selected`;
    container.querySelectorAll(".bs-empty").forEach(empty => { empty.hidden = tests.length > 0; });
    details.innerHTML = tests.length ? tests.map((test, index) => {
      const vb = peakAbs(test.vb) / 1000;
      const fm = peakAbs(test.y) / 1000;
      return `
      <div class="selected-file">
        <span class="series-strip" style="--series:${color(index)}"></span>
        <strong>${escapeHtml(name(test))}</strong><span>Original: ${escapeHtml(visiblePath(test.path))}</span>
        <dl>
          <div><dt>Peak V_b</dt><dd>${vb.toFixed(1)} kN</dd></div>
          <div><dt>Peak fm</dt><dd>${fm.toFixed(2)} kN</dd></div>
          <div><dt>fm / V_b</dt><dd>${(100 * fm / vb).toFixed(0)}%</dd></div>
          <div><dt>Peak x1_n</dt><dd>${peakAbs(test.x1).toFixed(2)} mm</dd></div>
          <div><dt>EQ intensity</dt><dd>${formatFactor(test.intensity_factor)}</dd></div>
          <div><dt>corr(d_n, dm)</dt><dd>${test.dn_dm_corr.toFixed(2)}</dd></div>
        </dl>
      </div>`;
    }).join("") : '<p class="muted-copy">No files selected.</p>';

    const traces = tests.flatMap((test, index) => [
      {
        type: "scattergl", mode: "lines", name: `${name(test)} · V_b`,
        x: test.t, y: test.vb.map(value => value / 1000),
        line: { color: color(index), width: 1.2 },
        hovertemplate: `${escapeHtml(name(test))}<br>t %{x:.2f} s<br>V_b %{y:.2f} kN<extra></extra>`
      },
      {
        type: "scattergl", mode: "lines", name: `${name(test)} · fm`, visible: "legendonly",
        x: test.t, y: test.y.map(value => value / 1000),
        line: { color: color(index), width: 1, dash: "dot" },
        hovertemplate: `${escapeHtml(name(test))}<br>t %{x:.2f} s<br>fm %{y:.3f} kN<extra></extra>`
      }
    ]);
    Plotly.react(timePlot, traces,
      layout(timePlot, "Earthquake time (s)", "Force (kN)", [...selected.keys()].join("|")),
      config).then(() => {
      if (relayoutReady) return;
      relayoutReady = true;
      timePlot.on("plotly_relayout", event => {
        if (event["xaxis.autorange"]) timeWindow = null;
        else if ("xaxis.range[0]" in event) timeWindow = [event["xaxis.range[0]"], event["xaxis.range[1]"]];
        else if (event["xaxis.range"]) timeWindow = [...event["xaxis.range"]];
        else return;
        renderLoop();
      });
    });
    renderLoop();
  }

  async function select(path, checked) {
    timeWindow = null;
    if (!checked) {
      selected.delete(path);
      render();
      return;
    }
    const entry = entries.find(item => item.path === path);
    try {
      const response = await fetch(entry.data, { cache: "no-store" });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      selected.set(path, { ...(await response.json()), path });
    } catch (error) {
      alert(`Could not load ${visiblePath(path)}: ${error.message}`);
    }
    renderTree();
    render();
  }

  tree.addEventListener("change", event => {
    if (event.target.matches('input[type="checkbox"]')) select(event.target.value, event.target.checked);
  });
  search.addEventListener("input", applySearch);
  alphaSlider.addEventListener("input", () => {
    alpha = Number(alphaSlider.value);
    alphaValue.value = alpha.toFixed(2);
    cancelAnimationFrame(frame);
    frame = requestAnimationFrame(renderLoop);
  });
  container.querySelector("#bsClearAll").addEventListener("click", () => {
    selected.clear();
    timeWindow = null;
    renderTree();
    render();
  });
  window.addEventListener("articlechange", event => {
    if (event.detail !== articleId) return;
    renderTree();
    [timePlot, loopPlot].forEach(plot => { if (plot.data) Plotly.Plots.resize(plot); });
  });

  renderTree();
  const first = files().find(entry => entry.available);
  if (first) await select(first.path, true);
  else render();
}
