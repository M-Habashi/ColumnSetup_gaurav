"use strict";

const NS = "http://www.w3.org/2000/svg";
const PALETTE = ["#4477AA", "#EE6677", "#228833", "#CCBB44"];
const DASHES = ["", "10 5", "3 4", "12 4 3 4"];
const MARGIN = { left: 86, right: 28, top: 24, bottom: 68 };

function svgElement(name, attributes = {}) {
  const node = document.createElementNS(NS, name);
  Object.entries(attributes).forEach(([key, value]) => node.setAttribute(key, value));
  return node;
}

function finiteExtent(values) {
  let min = Infinity;
  let max = -Infinity;
  values.forEach(value => {
    if (!Number.isFinite(value)) return;
    min = Math.min(min, value);
    max = Math.max(max, value);
  });
  return Number.isFinite(min) ? [min, max] : [-1, 1];
}

function paddedDomain(values) {
  let [min, max] = finiteExtent(values);
  const span = max - min || Math.max(Math.abs(max), 1);
  min -= span * 0.07;
  max += span * 0.07;
  return [min, max];
}

function ticks([min, max], count = 6) {
  const raw = Math.abs(max - min) / count || 1;
  const power = 10 ** Math.floor(Math.log10(raw));
  const scaled = raw / power;
  const step = (scaled <= 1 ? 1 : scaled <= 2 ? 2 : scaled <= 5 ? 5 : 10) * power;
  const start = Math.ceil(min / step) * step;
  const values = [];
  for (let value = start; value <= max + step * 1e-8; value += step) values.push(value);
  return { values, step };
}

function formatTick(value, step) {
  const decimals = Math.max(0, -Math.floor(Math.log10(Math.abs(step) || 1)));
  return value.toFixed(Math.min(4, decimals));
}

function buildTree(entries) {
  const root = { folders: new Map(), files: [] };
  entries.forEach(entry => {
    const parts = entry.path.split("/");
    let branch = root;
    parts.slice(0, -1).forEach(part => {
      if (!branch.folders.has(part)) branch.folders.set(part, { folders: new Map(), files: [] });
      branch = branch.folders.get(part);
    });
    branch.files.push(entry);
  });
  return root;
}

function treeMarkup(branch, depth = 0) {
  const folders = [...branch.folders.entries()].sort(([a], [b]) => a.localeCompare(b));
  const files = [...branch.files].sort((a, b) => a.name.localeCompare(b.name));
  return [
    ...folders.map(([name, child]) => `
      <details class="tree-folder" ${depth === 0 ? "open" : ""}>
        <summary role="treeitem"><span class="folder-mark" aria-hidden="true"></span><span>${name}</span><span class="folder-count">${countFiles(child)}</span></summary>
        <div role="group">${treeMarkup(child, depth + 1)}</div>
      </details>`),
    ...files.map(file => `
      <label class="tree-file" role="treeitem" data-search="${file.path.toLowerCase()}">
        <input type="checkbox" value="${file.id}" ${file.available ? "" : "disabled"}>
        <span class="file-mark" aria-hidden="true">MAT</span>
        <span class="file-name" title="${file.path}">${file.name}</span>
        ${file.available ? "" : `<span class="file-error" title="${file.error || "Unavailable"}">!</span>`}
      </label>`)
  ].join("");
}

function countFiles(branch) {
  return branch.files.length + [...branch.folders.values()].reduce((sum, child) => sum + countFiles(child), 0);
}

export async function initHysteresisExplorer(container) {
  const svg = container.querySelector("#hysteresisPlot");
  const tree = container.querySelector("#fileTree");
  const legend = container.querySelector("#plotLegend");
  const empty = container.querySelector("#plotEmpty");
  const summary = container.querySelector("#plotSummary");
  const details = container.querySelector("#selectedDetails");
  const count = container.querySelector("#selectionCount");
  const zoomButton = container.querySelector("#zoomButton");
  const resetView = container.querySelector("#resetView");
  const state = { manifest: [], selected: new Map(), hidden: new Set(), domain: null, zooming: false, drag: null };

  const response = await fetch("data/test-manifest.json", { cache: "no-store" });
  if (!response.ok) throw new Error(`Could not load test manifest: ${response.status}`);
  const manifest = await response.json();
  state.manifest = manifest.files;
  tree.innerHTML = treeMarkup(buildTree(manifest.files));

  async function setSelected(id, selected) {
    if (!selected) {
      state.selected.delete(id);
      state.hidden.delete(id);
      state.domain = null;
      render();
      return;
    }
    const entry = state.manifest.find(file => file.id === id);
    const checkbox = tree.querySelector(`input[value="${CSS.escape(id)}"]`);
    checkbox.disabled = true;
    checkbox.closest(".tree-file").classList.add("is-loading");
    try {
      const response = await fetch(entry.data, { cache: "no-store" });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      state.selected.set(id, { ...entry, ...(await response.json()) });
      state.domain = null;
    } catch (error) {
      checkbox.checked = false;
      alert(`Could not load ${entry.path}: ${error.message}`);
    } finally {
      checkbox.disabled = false;
      checkbox.closest(".tree-file").classList.remove("is-loading");
      render();
    }
  }

  tree.addEventListener("change", event => {
    if (event.target.matches('input[type="checkbox"]')) setSelected(event.target.value, event.target.checked);
  });

  container.querySelector("#fileSearch").addEventListener("input", event => {
    const query = event.target.value.trim().toLowerCase();
    tree.querySelectorAll(".tree-file").forEach(row => row.hidden = query && !row.dataset.search.includes(query));
    tree.querySelectorAll("details").forEach(folder => { if (query) folder.open = true; });
  });
  container.querySelector("#expandAll").addEventListener("click", () => {
    const folders = [...tree.querySelectorAll("details")];
    const open = folders.some(folder => !folder.open);
    folders.forEach(folder => folder.open = open);
  });
  container.querySelector("#clearAll").addEventListener("click", () => {
    tree.querySelectorAll('input[type="checkbox"]:checked').forEach(input => input.checked = false);
    state.selected.clear(); state.hidden.clear(); state.domain = null; render();
  });
  zoomButton.addEventListener("click", () => {
    state.zooming = !state.zooming;
    zoomButton.setAttribute("aria-pressed", String(state.zooming));
    container.querySelector("#plotShell").classList.toggle("is-zooming", state.zooming);
  });
  resetView.addEventListener("click", () => { state.domain = null; render(); });
  window.addEventListener("resize", render, { passive: true });

  function render() {
    const selected = [...state.selected.values()];
    count.textContent = `${selected.length} selected`;
    empty.hidden = selected.length > 0;
    summary.textContent = selected.length ? `${selected.length} test${selected.length === 1 ? "" : "s"} on shared axes` : "Select a test file to begin.";
    renderLegend(selected);
    renderDetails(selected);
    draw(selected.filter(file => !state.hidden.has(file.id)));
  }

  function renderLegend(selected) {
    legend.innerHTML = selected.map((file, index) => {
      const color = PALETTE[index % PALETTE.length];
      const dash = DASHES[Math.floor(index / PALETTE.length) % DASHES.length];
      return `<button class="legend-item" type="button" data-id="${file.id}" aria-pressed="${!state.hidden.has(file.id)}" style="--series:${color};--dash:${dash || "none"}">
        <svg viewBox="0 0 30 8" aria-hidden="true"><line x1="1" y1="4" x2="29" y2="4"></line></svg><span>${file.name}</span>
      </button>`;
    }).join("");
    legend.querySelectorAll("button").forEach(button => button.addEventListener("click", () => {
      state.hidden.has(button.dataset.id) ? state.hidden.delete(button.dataset.id) : state.hidden.add(button.dataset.id);
      render();
    }));
  }

  function renderDetails(selected) {
    details.innerHTML = selected.length ? selected.map((file, index) => `
      <div class="selected-file" style="--series:${PALETTE[index % PALETTE.length]}">
        <strong>${file.name}</strong><span>${file.path}</span>
        <dl><div><dt>Samples</dt><dd>${Number(file.sample_count).toLocaleString()}</dd></div><div><dt>Rendered</dt><dd>${file.x.length.toLocaleString()}</dd></div><div><dt>Rate</dt><dd>${Number(file.fs).toLocaleString()} Hz</dd></div></dl>
      </div>`).join("") : '<p class="muted-copy">No files selected.</p>';
  }

  function draw(visible) {
    svg.replaceChildren();
    if (!visible.length) {
      resetView.hidden = state.domain === null;
      return;
    }
    const viewWidth = 900, viewHeight = 590;
    const width = viewWidth - MARGIN.left - MARGIN.right;
    const height = viewHeight - MARGIN.top - MARGIN.bottom;
    const domain = state.domain || {
      x: paddedDomain(visible.flatMap(file => file.x)),
      y: paddedDomain(visible.flatMap(file => file.y))
    };
    const xScale = value => MARGIN.left + (value - domain.x[0]) / (domain.x[1] - domain.x[0]) * width;
    const yScale = value => MARGIN.top + height - (value - domain.y[0]) / (domain.y[1] - domain.y[0]) * height;
    const xTicks = ticks(domain.x), yTicks = ticks(domain.y);

    const grid = svgElement("g", { class: "plot-grid" });
    xTicks.values.forEach(value => {
      const x = xScale(value);
      grid.append(svgElement("line", { x1: x, y1: MARGIN.top, x2: x, y2: MARGIN.top + height, class: value === 0 ? "plot-zero-line" : "plot-grid-line" }));
      const label = svgElement("text", { x, y: MARGIN.top + height + 25, class: "plot-tick-label", "text-anchor": "middle" });
      label.textContent = formatTick(value, xTicks.step); grid.append(label);
    });
    yTicks.values.forEach(value => {
      const y = yScale(value);
      grid.append(svgElement("line", { x1: MARGIN.left, y1: y, x2: MARGIN.left + width, y2: y, class: value === 0 ? "plot-zero-line" : "plot-grid-line" }));
      const label = svgElement("text", { x: MARGIN.left - 12, y: y + 4, class: "plot-tick-label", "text-anchor": "end" });
      label.textContent = formatTick(value, yTicks.step); grid.append(label);
    });
    svg.append(grid);
    svg.append(svgElement("rect", { x: MARGIN.left, y: MARGIN.top, width, height, class: "plot-frame" }));

    visible.forEach(file => {
      const index = [...state.selected.keys()].indexOf(file.id);
      let path = "";
      for (let i = 0; i < Math.min(file.x.length, file.y.length); i += 1) {
        if (!Number.isFinite(file.x[i]) || !Number.isFinite(file.y[i])) continue;
        path += `${path ? "L" : "M"}${xScale(file.x[i]).toFixed(2)},${yScale(file.y[i]).toFixed(2)}`;
      }
      svg.append(svgElement("path", { d: path, class: "plot-series", stroke: PALETTE[index % PALETTE.length], opacity: "0.7", "stroke-dasharray": DASHES[Math.floor(index / PALETTE.length) % DASHES.length] }));
    });

    const xLabel = svgElement("text", { x: MARGIN.left + width / 2, y: viewHeight - 18, class: "plot-axis-label", "text-anchor": "middle" });
    xLabel.textContent = "Filtered measured displacement, dm (mm)"; svg.append(xLabel);
    const yLabel = svgElement("text", { x: 20, y: MARGIN.top + height / 2, class: "plot-axis-label", "text-anchor": "middle", transform: `rotate(-90 20 ${MARGIN.top + height / 2})` });
    yLabel.textContent = "Measured force, fm (N)"; svg.append(yLabel);
    const hit = svgElement("rect", { x: MARGIN.left, y: MARGIN.top, width, height, class: "plot-hit-area" });
    svg.append(hit);
    const selection = svgElement("rect", { class: "zoom-selection", hidden: "" }); svg.append(selection);

    hit.addEventListener("pointerdown", event => {
      if (!state.zooming) return;
      hit.setPointerCapture(event.pointerId);
      const point = pointer(event); state.drag = point;
      Object.entries({ x: point.x, y: point.y, width: 0, height: 0 }).forEach(([key, value]) => selection.setAttribute(key, value));
      selection.removeAttribute("hidden");
    });
    hit.addEventListener("pointermove", event => {
      if (!state.drag) return;
      const point = pointer(event);
      selection.setAttribute("x", Math.min(state.drag.x, point.x)); selection.setAttribute("y", Math.min(state.drag.y, point.y));
      selection.setAttribute("width", Math.abs(point.x - state.drag.x)); selection.setAttribute("height", Math.abs(point.y - state.drag.y));
    });
    hit.addEventListener("pointerup", finishZoom);
    hit.addEventListener("pointercancel", () => { state.drag = null; selection.setAttribute("hidden", ""); });

    function pointer(event) {
      const rect = svg.getBoundingClientRect();
      return { x: (event.clientX - rect.left) * viewWidth / rect.width, y: (event.clientY - rect.top) * viewHeight / rect.height };
    }
    function finishZoom(event) {
      if (!state.drag) return;
      const point = pointer(event); const start = state.drag; state.drag = null; selection.setAttribute("hidden", "");
      if (Math.abs(point.x - start.x) < 8 || Math.abs(point.y - start.y) < 8) return;
      const invertX = value => domain.x[0] + (value - MARGIN.left) / width * (domain.x[1] - domain.x[0]);
      const invertY = value => domain.y[1] - (value - MARGIN.top) / height * (domain.y[1] - domain.y[0]);
      state.domain = { x: [invertX(Math.min(start.x, point.x)), invertX(Math.max(start.x, point.x))], y: [invertY(Math.max(start.y, point.y)), invertY(Math.min(start.y, point.y))] };
      resetView.hidden = false; render();
    }
    resetView.hidden = state.domain === null;
  }

  render();
}
