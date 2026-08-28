"use strict";

const DEFAULT_COLORS = ["#4477AA", "#EE6677", "#228833", "#CCBB44"];

function rgba(hex, alpha) {
  const value = Number.parseInt(hex.slice(1), 16);
  return `rgba(${value >> 16},${value >> 8 & 255},${value & 255},${alpha})`;
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

function countFiles(branch) {
  return branch.files.length + [...branch.folders.values()].reduce((sum, child) => sum + countFiles(child), 0);
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

export async function initHysteresisExplorer(container) {
  const plot = container.querySelector("#hysteresisPlot");
  const tree = container.querySelector("#fileTree");
  const empty = container.querySelector("#plotEmpty");
  const summary = container.querySelector("#plotSummary");
  const details = container.querySelector("#selectedDetails");
  const count = container.querySelector("#selectionCount");
  const alphaSlider = container.querySelector("#alphaSlider");
  const alphaValue = container.querySelector("#alphaValue");
  const state = { manifest: [], selected: new Map(), alpha: Number(alphaSlider.value), frame: null };

  const response = await fetch("data/test-manifest.json", { cache: "no-store" });
  if (!response.ok) throw new Error(`Could not load test manifest: ${response.status}`);
  const manifest = await response.json();
  state.manifest = manifest.files;
  tree.innerHTML = treeMarkup(buildTree(manifest.files));

  async function setSelected(id, selected) {
    if (!selected) {
      state.selected.delete(id);
      render();
      return;
    }
    const entry = state.manifest.find(file => file.id === id);
    const checkbox = tree.querySelector(`input[value="${CSS.escape(id)}"]`);
    checkbox.disabled = true;
    checkbox.closest(".tree-file").classList.add("is-loading");
    try {
      const result = await fetch(entry.data, { cache: "no-store" });
      if (!result.ok) throw new Error(`HTTP ${result.status}`);
      state.selected.set(id, { ...entry, ...(await result.json()), color: DEFAULT_COLORS[state.selected.size % DEFAULT_COLORS.length] });
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
    state.selected.clear();
    render();
  });
  alphaSlider.addEventListener("input", () => {
    state.alpha = Number(alphaSlider.value);
    alphaValue.value = state.alpha.toFixed(2);
    if (state.frame) cancelAnimationFrame(state.frame);
    state.frame = requestAnimationFrame(() => {
      state.frame = null;
      render();
    });
  });
  details.addEventListener("input", event => {
    if (!event.target.matches('.series-color-picker input[type="color"]')) return;
    const file = state.selected.get(event.target.dataset.id);
    file.color = event.target.value;
    event.target.closest(".series-color-picker").style.setProperty("--series", file.color);
    Plotly.restyle(plot, { "line.color": rgba(file.color, state.alpha) }, [[...state.selected.keys()].indexOf(file.id)]);
  });

  function render() {
    const selected = [...state.selected.values()];
    count.textContent = `${selected.length} selected`;
    empty.hidden = selected.length > 0;
    summary.textContent = selected.length ? `${selected.length} test${selected.length === 1 ? "" : "s"} on shared axes` : "Select a test file to begin.";
    details.innerHTML = selected.length ? selected.map(file => `
      <div class="selected-file">
        <label class="series-color-picker" style="--series:${file.color}" title="Change trace color">
          <span class="sr-only">Choose color for ${file.name}</span>
          <input type="color" value="${file.color}" data-id="${file.id}" aria-label="Choose color for ${file.name}">
        </label>
        <strong>${file.name}</strong><span>${file.path}</span>
        <dl><div><dt>Samples</dt><dd>${Number(file.sample_count).toLocaleString()}</dd></div><div><dt>Rendered</dt><dd>${file.x.length.toLocaleString()}</dd></div><div><dt>Rate</dt><dd>${Number(file.fs).toLocaleString()} Hz</dd></div></dl>
      </div>`).join("") : '<p class="muted-copy">No files selected.</p>';

    const traces = selected.map(file => ({
      type: "scattergl",
      mode: "lines",
      uid: file.id,
      name: file.name,
      x: file.x,
      y: file.y,
      opacity: 0.7,
      line: {
        color: rgba(file.color, state.alpha),
        width: 1.5,
        dash: "solid"
      },
      hovertemplate: `${file.name}<br>dm %{x:.3f} mm<br>fm %{y:.1f} N<extra></extra>`
    }));

    Plotly.react(plot, traces, {
      paper_bgcolor: "#141412",
      plot_bgcolor: "#141412",
      font: { color: "#d6d4cb", family: "IBM Plex Sans, sans-serif", size: 12 },
      margin: { l: 82, r: 24, t: 24, b: 68 },
      showlegend: true,
      legend: { orientation: "h", x: 0, y: 1.02, yanchor: "bottom", itemclick: "toggle", itemdoubleclick: "toggleothers", uirevision: "hysteresis-series" },
      hovermode: "closest",
      dragmode: "zoom",
      uirevision: selected.map(file => file.id).join("|"),
      xaxis: { title: { text: "Filtered measured displacement, dm (mm)", standoff: 16 }, gridcolor: "#30322d", zerolinecolor: "#777a70", linecolor: "#4a4c46", mirror: true },
      yaxis: { title: { text: "Measured force, fm (N)", standoff: 16 }, gridcolor: "#30322d", zerolinecolor: "#777a70", linecolor: "#4a4c46", mirror: true }
    }, {
      responsive: true,
      scrollZoom: true,
      displaylogo: false,
      doubleClick: "reset+autosize",
      modeBarButtonsToRemove: ["select2d", "lasso2d"]
    });
  }

  window.addEventListener("resize", () => Plotly.Plots.resize(plot), { passive: true });
  render();
}
