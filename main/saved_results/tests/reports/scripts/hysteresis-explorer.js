"use strict";

const DEFAULT_COLORS = ["#4477AA", "#EE6677", "#228833", "#CCBB44"];
const HEX_COLOR = /^#[0-9a-f]{6}$/i;
const FORCE_UNITS = {
  kN: { divisor: 1000, next: "kip" },
  kip: { divisor: 4448.2216152605, next: "kN" }
};

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, character => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
  })[character]);
}

function visibleName(value) {
  return String(value).trim().replace(/\.mat$/i, "");
}

function visiblePath(value) {
  return String(value).replace(/\.mat$/i, "");
}

function formatFactor(value) {
  const number = Number(value);
  return Number.isFinite(number)
    ? `${number.toLocaleString(undefined, { maximumFractionDigits: 3 })}×`
    : "—";
}

function rgba(hex, alpha) {
  const value = Number.parseInt(hex.slice(1), 16);
  return `rgba(${value >> 16},${value >> 8 & 255},${value & 255},${alpha})`;
}

function upperBound(values, limit) {
  let low = 0;
  let high = values.length;
  while (low < high) {
    const middle = (low + high) >> 1;
    if (values[middle] <= limit) low = middle + 1;
    else high = middle;
  }
  return low;
}

function lowerBound(values, limit) {
  let low = 0;
  let high = values.length;
  while (low < high) {
    const middle = (low + high) >> 1;
    if (values[middle] < limit) low = middle + 1;
    else high = middle;
  }
  return low;
}

function fullRange(files, key, divisor = 1) {
  let minimum = Infinity;
  let maximum = -Infinity;
  files.forEach(file => file[key].forEach(value => {
    if (!Number.isFinite(value)) return;
    value /= divisor;
    minimum = Math.min(minimum, value);
    maximum = Math.max(maximum, value);
  }));
  if (!Number.isFinite(minimum)) return null;
  const padding = minimum === maximum ? Math.max(Math.abs(minimum) * 0.06, 1) : (maximum - minimum) * 0.06;
  return [minimum - padding, maximum + padding];
}

function validView(view) {
  return view && [view.x, view.y].every(range => Array.isArray(range)
    && range.length === 2 && range.every(Number.isFinite));
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

function treeMarkup(branch, metadata, depth = 0) {
  const folders = [...branch.folders.entries()].sort(([a], [b]) => a.localeCompare(b));
  const files = [...branch.files].sort((a, b) => metadata.files[a.path].display_name.localeCompare(metadata.files[b.path].display_name));
  return [
    ...folders.map(([name, child]) => `
      <details class="tree-folder" ${depth === 0 ? "open" : ""}>
        <summary role="treeitem"><span class="folder-mark" aria-hidden="true"></span><span>${escapeHtml(name)}</span><span class="folder-count">${countFiles(child)}</span></summary>
        <div role="group">${treeMarkup(child, metadata, depth + 1)}</div>
      </details>`),
    ...files.map(file => {
      const fileMetadata = metadata.files[file.path];
      const searchable = `${fileMetadata.display_name} ${file.path}`.toLowerCase();
      const title = fileMetadata.display_name === visibleName(file.name)
        ? visiblePath(file.path)
        : `${fileMetadata.display_name}\nOriginal: ${visiblePath(file.path)}`;
      const download = file.xlsx_available
        ? `<a class="file-download" href="${escapeHtml(file.xlsx)}" download="${escapeHtml(fileMetadata.display_name)}.xlsx" title="Download ${escapeHtml(fileMetadata.display_name)} as XLSX">XLSX</a>`
        : `<span class="file-download is-disabled" title="XLSX unavailable">XLSX</span>`;
      return `
      <div class="tree-file" role="treeitem" tabindex="0" data-path="${escapeHtml(file.path)}" data-search="${escapeHtml(searchable)}">
        <label class="tree-file-select" title="${escapeHtml(title)}">
          <input type="checkbox" value="${escapeHtml(file.path)}" ${fileMetadata.selected ? "checked" : ""} ${file.available ? "" : "disabled"}>
          <span class="file-name">${escapeHtml(fileMetadata.display_name)}</span>
          ${file.available ? "" : `<span class="file-error" title="${escapeHtml(file.error || "Unavailable")}">!</span>`}
        </label>
        ${download}
      </div>`;
    })
  ].join("");
}

function normalizeMetadata(source, manifest) {
  const alpha = Number(source?.settings?.density_alpha);
  const storedStart = source?.settings?.earthquake_time_start;
  const start = storedStart === null || storedStart === undefined ? NaN : Number(storedStart);
  const storedEnd = source?.settings?.earthquake_time_end ?? source?.settings?.earthquake_time_cutoff;
  const end = storedEnd === null || storedEnd === undefined ? NaN : Number(storedEnd);
  const timeStart = Number.isFinite(start) ? Math.max(0, start) : 0;
  const storedForceUnit = source?.settings?.force_unit;
  const forceUnit = storedForceUnit === "kip" ? "kip" : "kN";
  const storedView = validView(source?.settings?.custom_view) ? source.settings.custom_view : null;
  const customView = storedView && !["kN", "kip"].includes(storedForceUnit)
    ? { x: [...storedView.x], y: storedView.y.map(value => value / 1000) }
    : storedView;
  const metadata = {
    version: 1,
    report: source.report,
    settings: {
      density_alpha: Number.isFinite(alpha) ? Math.min(1, Math.max(0.1, alpha)) : 0.1,
      earthquake_time_start: timeStart,
      earthquake_time_end: Number.isFinite(end) ? Math.max(timeStart, end) : null,
      custom_view: customView,
      force_unit: forceUnit,
      archived_tree_collapsed: Boolean(source?.settings?.archived_tree_collapsed)
    },
    files: {}
  };

  manifest.forEach((entry, index) => {
    const stored = source?.files?.[entry.path] || {};
    const archived = Boolean(stored.archived);
    const storedDisplayName = typeof stored.display_name === "string" ? visibleName(stored.display_name) : "";
    metadata.files[entry.path] = {
      original_name: entry.name,
      original_path: entry.path,
      display_name: storedDisplayName || visibleName(entry.name),
      archived,
      selected: Boolean(stored.selected) && !archived && entry.available,
      color: typeof stored.color === "string" && HEX_COLOR.test(stored.color) ? stored.color.toUpperCase() : DEFAULT_COLORS[index % DEFAULT_COLORS.length],
      visible: stored.visible !== false
    };
  });
  return metadata;
}

export async function initHysteresisExplorer(container, initialMetadata) {
  const plot = container.querySelector("#hysteresisPlot");
  const fileLists = container.querySelector("#fileLists");
  const tree = container.querySelector("#fileTree");
  const archivedTree = container.querySelector("#archivedFileTree");
  const archivedTreeToggle = container.querySelector("#archivedTreeToggle");
  const currentFileCount = container.querySelector("#currentFileCount");
  const archivedFileCount = container.querySelector("#archivedFileCount");
  const metadataStatus = container.querySelector("#metadataStatus");
  const empty = container.querySelector("#plotEmpty");
  const summary = container.querySelector("#plotSummary");
  const details = container.querySelector("#selectedDetails");
  const count = container.querySelector("#selectionCount");
  const alphaSlider = container.querySelector("#alphaSlider");
  const alphaValue = container.querySelector("#alphaValue");
  const timeStartSlider = container.querySelector("#earthquakeTimeStartSlider");
  const timeEndSlider = container.querySelector("#earthquakeTimeEndSlider");
  const timeWindow = container.querySelector("#earthquakeTimeWindow");
  const timeValue = container.querySelector("#earthquakeTimeValue");
  const timeMax = container.querySelector("#earthquakeTimeMax");
  const contextMenu = document.getElementById("fileContextMenu");
  const contextMenuFile = document.getElementById("contextMenuFile");
  const archiveAction = contextMenu.querySelector('[data-action="archive"]');
  const renameDialog = document.getElementById("renameDialog");
  const renameForm = document.getElementById("renameForm");
  const renameInput = document.getElementById("renameInput");
  const renameOriginalName = document.getElementById("renameOriginalName");
  const metadataApi = document.body.dataset.reportMetadataApi || "api/report-metadata";
  const manifestResponse = await fetch("data/test-manifest.json", { cache: "no-store" });
  if (!manifestResponse.ok) throw new Error(`Could not load test manifest: ${manifestResponse.status}`);
  const manifest = await manifestResponse.json();
  const metadata = normalizeMetadata(initialMetadata, manifest.files);
  const state = {
    manifest: manifest.files,
    selected: new Map(),
    alpha: metadata.settings.density_alpha,
    timeStart: metadata.settings.earthquake_time_start,
    timeEnd: metadata.settings.earthquake_time_end ?? Infinity,
    customView: metadata.settings.custom_view,
    forceUnit: metadata.settings.force_unit,
    archivedTreeCollapsed: metadata.settings.archived_tree_collapsed,
    frame: null
  };
  let contextTargetPath = null;
  let renameTargetPath = null;
  let relayoutListenerReady = false;
  let saveTimer = null;
  let saveQueue = Promise.resolve();
  let metadataWritable = true;

  alphaSlider.value = state.alpha;
  alphaValue.value = state.alpha.toFixed(2);

  function entryForPath(path) {
    return state.manifest.find(entry => entry.path === path);
  }

  function checkboxForPath(path) {
    return fileLists.querySelector(`input[value="${CSS.escape(path)}"]`);
  }

  function syncSettings() {
    metadata.settings.density_alpha = state.alpha;
    metadata.settings.earthquake_time_start = state.timeStart;
    metadata.settings.earthquake_time_end = Number.isFinite(state.timeEnd) ? state.timeEnd : null;
    metadata.settings.custom_view = state.customView;
    metadata.settings.force_unit = state.forceUnit;
  }

  function persistMetadata() {
    if (!metadataWritable) return Promise.resolve();
    syncSettings();
    const payload = JSON.stringify(metadata);
    saveQueue = saveQueue.catch(() => {}).then(async () => {
      const response = await fetch(metadataApi, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: payload
      });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      metadataStatus.hidden = true;
    }).catch(error => {
      metadataWritable = false;
      metadataStatus.textContent = `State could not be saved (${error.message}). Start the report with serve_report.py.`;
      metadataStatus.classList.add("is-error");
      metadataStatus.hidden = false;
    });
    return saveQueue;
  }

  function scheduleMetadataSave(delay = 160) {
    clearTimeout(saveTimer);
    saveTimer = setTimeout(() => {
      saveTimer = null;
      persistMetadata();
    }, delay);
  }

  function resetViewState() {
    state.timeStart = 0;
    state.timeEnd = Infinity;
    state.customView = null;
    syncSettings();
  }

  function applySearch() {
    const query = container.querySelector("#fileSearch").value.trim().toLowerCase();
    fileLists.querySelectorAll(".tree-file").forEach(row => {
      row.hidden = Boolean(query) && !row.dataset.search.includes(query);
    });
    fileLists.querySelectorAll("details").forEach(folder => {
      if (query) folder.open = true;
    });
  }

  function renderTrees() {
    const current = state.manifest.filter(entry => !metadata.files[entry.path].archived);
    const archived = state.manifest.filter(entry => metadata.files[entry.path].archived);
    tree.innerHTML = current.length
      ? treeMarkup(buildTree(current), metadata)
      : '<p class="tree-empty">No current files.</p>';
    archivedTree.innerHTML = archived.length
      ? treeMarkup(buildTree(archived), metadata)
      : '<p class="tree-empty">No archived files.</p>';
    currentFileCount.textContent = current.length;
    archivedFileCount.textContent = archived.length;
    archivedTree.hidden = state.archivedTreeCollapsed;
    archivedTreeToggle.disabled = !archived.length;
    archivedTreeToggle.setAttribute("aria-expanded", String(!state.archivedTreeCollapsed));
    archivedTreeToggle.textContent = state.archivedTreeCollapsed ? "Expand" : "Collapse";
    applySearch();
  }

  function setRowLoading(path, loading) {
    const checkbox = checkboxForPath(path);
    if (!checkbox) return;
    checkbox.disabled = loading || !entryForPath(path).available;
    checkbox.closest(".tree-file").classList.toggle("is-loading", loading);
  }

  async function loadEntry(entry) {
    setRowLoading(entry.path, true);
    try {
      const response = await fetch(entry.data, { cache: "no-store" });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const data = await response.json();
      state.selected.set(entry.path, { ...data, ...entry });
      metadata.files[entry.path].selected = true;
    } finally {
      setRowLoading(entry.path, false);
    }
  }

  async function setSelected(path, selected) {
    const fileMetadata = metadata.files[path];
    if (!selected) {
      state.selected.delete(path);
      fileMetadata.selected = false;
      resetViewState();
      render();
      scheduleMetadataSave();
      return;
    }

    try {
      await loadEntry(entryForPath(path));
      resetViewState();
    } catch (error) {
      fileMetadata.selected = false;
      const checkbox = checkboxForPath(path);
      if (checkbox) checkbox.checked = false;
      alert(`Could not load ${visiblePath(path)}: ${error.message}`);
    }
    render();
    scheduleMetadataSave();
  }

  function closeContextMenu(returnFocus = false) {
    if (contextMenu.hidden) return;
    contextMenu.hidden = true;
    if (returnFocus && contextTargetPath) {
      fileLists.querySelector(`.tree-file[data-path="${CSS.escape(contextTargetPath)}"]`)?.focus();
    }
  }

  function openContextMenu(event, row) {
    event.preventDefault();
    contextTargetPath = row.dataset.path;
    const fileMetadata = metadata.files[contextTargetPath];
    contextMenuFile.textContent = fileMetadata.display_name;
    archiveAction.textContent = fileMetadata.archived ? "Restore" : "Archive";
    contextMenu.hidden = false;
    const rowRect = row.getBoundingClientRect();
    const requestedX = event.clientX || rowRect.left + 18;
    const requestedY = event.clientY || rowRect.top + 18;
    const left = Math.max(8, Math.min(requestedX, window.innerWidth - contextMenu.offsetWidth - 8));
    const top = Math.max(8, Math.min(requestedY, window.innerHeight - contextMenu.offsetHeight - 8));
    contextMenu.style.left = `${left}px`;
    contextMenu.style.top = `${top}px`;
    contextMenu.querySelector(".context-menu-item").focus();
  }

  function openRenameDialog(path) {
    renameTargetPath = path;
    const fileMetadata = metadata.files[path];
    renameInput.value = fileMetadata.display_name;
    renameInput.setCustomValidity("");
    renameOriginalName.textContent = `Original MAT: ${visiblePath(fileMetadata.original_path)}`;
    renameDialog.showModal();
    renameInput.focus();
    renameInput.select();
  }

  function toggleArchived(path) {
    const fileMetadata = metadata.files[path];
    fileMetadata.archived = !fileMetadata.archived;
    if (fileMetadata.archived) {
      fileMetadata.selected = false;
      state.selected.delete(path);
      resetViewState();
    }
    renderTrees();
    render();
    scheduleMetadataSave(0);
  }

  fileLists.addEventListener("change", event => {
    if (event.target.matches('input[type="checkbox"]')) setSelected(event.target.value, event.target.checked);
  });
  fileLists.addEventListener("contextmenu", event => {
    const row = event.target.closest(".tree-file");
    if (row) openContextMenu(event, row);
  });
  fileLists.addEventListener("keydown", event => {
    const row = event.target.closest(".tree-file");
    if (row && (event.key === "ContextMenu" || (event.shiftKey && event.key === "F10"))) openContextMenu(event, row);
  });
  document.addEventListener("pointerdown", event => {
    if (!contextMenu.contains(event.target)) closeContextMenu();
  });
  contextMenu.addEventListener("keydown", event => {
    const items = [...contextMenu.querySelectorAll(".context-menu-item")];
    const index = items.indexOf(document.activeElement);
    if (event.key === "Escape") {
      event.preventDefault();
      closeContextMenu(true);
    } else if (event.key === "ArrowDown") {
      event.preventDefault();
      items[(index + 1) % items.length].focus();
    } else if (event.key === "ArrowUp") {
      event.preventDefault();
      items[(index - 1 + items.length) % items.length].focus();
    } else if (event.key === "Home" || event.key === "End") {
      event.preventDefault();
      items[event.key === "Home" ? 0 : items.length - 1].focus();
    }
  });
  contextMenu.addEventListener("click", event => {
    const action = event.target.closest("[data-action]")?.dataset.action;
    if (!action || !contextTargetPath) return;
    closeContextMenu();
    if (action === "rename") openRenameDialog(contextTargetPath);
    if (action === "archive") toggleArchived(contextTargetPath);
  });
  window.addEventListener("blur", () => closeContextMenu());
  window.addEventListener("scroll", () => closeContextMenu(), true);

  renameForm.addEventListener("submit", event => {
    event.preventDefault();
    const displayName = visibleName(renameInput.value);
    if (!displayName) {
      renameInput.setCustomValidity("Enter a display name.");
      renameInput.reportValidity();
      return;
    }
    metadata.files[renameTargetPath].display_name = displayName;
    renameDialog.close();
    renderTrees();
    render();
    scheduleMetadataSave(0);
  });
  renameInput.addEventListener("input", () => renameInput.setCustomValidity(""));
  document.getElementById("renameCancel").addEventListener("click", () => renameDialog.close());

  container.querySelector("#fileSearch").addEventListener("input", applySearch);
  container.querySelector("#expandAll").addEventListener("click", event => {
    const folders = [...fileLists.querySelectorAll("details")];
    const open = folders.some(folder => !folder.open);
    folders.forEach(folder => { folder.open = open; });
    event.currentTarget.textContent = open ? "Collapse all" : "Expand all";
  });
  archivedTreeToggle.addEventListener("click", () => {
    state.archivedTreeCollapsed = !state.archivedTreeCollapsed;
    metadata.settings.archived_tree_collapsed = state.archivedTreeCollapsed;
    renderTrees();
    scheduleMetadataSave(0);
  });
  container.querySelector("#clearAll").addEventListener("click", () => {
    state.selected.clear();
    Object.values(metadata.files).forEach(file => { file.selected = false; });
    resetViewState();
    renderTrees();
    render();
    scheduleMetadataSave(0);
  });
  function updateTimeWindow(changedEnd) {
    let start = Number(timeStartSlider.value);
    let end = Number(timeEndSlider.value);
    if (changedEnd === "start") start = Math.min(start, end);
    else end = Math.max(start, end);
    state.timeStart = start;
    state.timeEnd = end;
    timeStartSlider.value = start;
    timeEndSlider.value = end;
    timeValue.value = `${start.toFixed(1)}–${end.toFixed(1)} s`;
    syncSettings();
    scheduleMetadataSave();
    if (state.frame) cancelAnimationFrame(state.frame);
    state.frame = requestAnimationFrame(() => {
      state.frame = null;
      render();
    });
  }
  timeStartSlider.addEventListener("input", () => updateTimeWindow("start"));
  timeEndSlider.addEventListener("input", () => updateTimeWindow("end"));
  timeStartSlider.addEventListener("change", () => scheduleMetadataSave(0));
  timeEndSlider.addEventListener("change", () => scheduleMetadataSave(0));
  alphaSlider.addEventListener("input", () => {
    state.alpha = Number(alphaSlider.value);
    alphaValue.value = state.alpha.toFixed(2);
    syncSettings();
    scheduleMetadataSave();
    if (state.frame) cancelAnimationFrame(state.frame);
    state.frame = requestAnimationFrame(() => {
      state.frame = null;
      render();
    });
  });
  alphaSlider.addEventListener("change", () => scheduleMetadataSave(0));
  details.addEventListener("input", event => {
    if (!event.target.matches('.series-color-picker input[type="color"]')) return;
    const path = event.target.dataset.path;
    metadata.files[path].color = event.target.value.toUpperCase();
    event.target.closest(".series-color-picker").style.setProperty("--series", metadata.files[path].color);
    const index = [...state.selected.keys()].indexOf(path);
    Plotly.restyle(plot, { "line.color": rgba(metadata.files[path].color, state.alpha) }, [index]);
    scheduleMetadataSave();
  });
  details.addEventListener("change", () => scheduleMetadataSave(0));

  function toggleForceUnit() {
    const previousUnit = FORCE_UNITS[state.forceUnit];
    state.forceUnit = previousUnit.next;
    const nextUnit = FORCE_UNITS[state.forceUnit];
    if (state.customView) {
      state.customView = {
        x: [...state.customView.x],
        y: state.customView.y.map(value => value * previousUnit.divisor / nextUnit.divisor)
      };
    }
    syncSettings();
    render();
    scheduleMetadataSave(0);
  }

  function bindForceUnitToggle() {
    const axisTitle = plot.querySelector(".ytitle");
    if (!axisTitle) return;
    const nextUnit = FORCE_UNITS[state.forceUnit].next;
    axisTitle.setAttribute("role", "button");
    axisTitle.setAttribute("tabindex", "0");
    axisTitle.setAttribute("aria-label", `Force axis in ${state.forceUnit}. Activate to convert to ${nextUnit}.`);
    axisTitle.onclick = toggleForceUnit;
    axisTitle.onkeydown = event => {
      if (event.key !== "Enter" && event.key !== " ") return;
      event.preventDefault();
      toggleForceUnit();
    };
  }

  function render() {
    const selected = [...state.selected.values()];
    const forceUnit = FORCE_UNITS[state.forceUnit];
    const fullView = selected.length ? { x: fullRange(selected, "x"), y: fullRange(selected, "y", forceUnit.divisor) } : null;
    const view = state.customView || fullView;
    const maximumTime = selected.length ? Math.max(...selected.map(file => file.t.at(-1))) : 0;
    const startTime = selected.length ? Math.min(Math.max(0, state.timeStart), maximumTime) : 0;
    const endTime = selected.length ? Math.max(startTime, Math.min(state.timeEnd, maximumTime)) : 0;
    [timeStartSlider, timeEndSlider].forEach(slider => {
      slider.disabled = !selected.length;
      slider.max = maximumTime || 1;
    });
    timeStartSlider.value = startTime;
    timeEndSlider.value = selected.length ? endTime : 0;
    timeValue.value = selected.length ? `${startTime.toFixed(1)}–${endTime.toFixed(1)} s` : "—";
    timeMax.textContent = selected.length ? `${maximumTime.toFixed(1)} s` : "—";
    const startPercent = maximumTime ? startTime / maximumTime * 100 : 0;
    const endPercent = maximumTime ? endTime / maximumTime * 100 : 0;
    timeWindow.style.left = `${startPercent}%`;
    timeWindow.style.right = `${100 - endPercent}%`;
    count.textContent = `${selected.length} selected`;
    empty.hidden = selected.length > 0;
    summary.textContent = selected.length ? `${selected.length} test${selected.length === 1 ? "" : "s"} on shared axes` : "Select a test file to begin.";
    details.innerHTML = selected.length ? selected.map(file => {
      const fileMetadata = metadata.files[file.path];
      return `
      <div class="selected-file">
        <label class="series-color-picker" style="--series:${fileMetadata.color}" title="Change trace color">
          <span class="sr-only">Choose color for ${escapeHtml(fileMetadata.display_name)}</span>
          <input type="color" value="${fileMetadata.color}" data-path="${escapeHtml(file.path)}" aria-label="Choose color for ${escapeHtml(fileMetadata.display_name)}">
        </label>
        <strong>${escapeHtml(fileMetadata.display_name)}</strong><span>Original: ${escapeHtml(visiblePath(fileMetadata.original_path))}</span>
        <dl><div><dt>EQ intensity</dt><dd>${formatFactor(file.intensity_factor)}</dd></div><div><dt>Time scale</dt><dd>${formatFactor(file.time_scale_factor)}</dd></div><div><dt>Date</dt><dd>${escapeHtml(file.test_date || "—")}</dd></div></dl>
      </div>`;
    }).join("") : '<p class="muted-copy">No files selected.</p>';

    const traces = selected.map(file => {
      const fileMetadata = metadata.files[file.path];
      const start = lowerBound(file.t, startTime);
      const end = upperBound(file.t, endTime);
      return {
        type: "scattergl",
        mode: "lines",
        uid: file.id,
        name: fileMetadata.display_name,
        x: file.x.slice(start, end),
        y: file.y.slice(start, end).map(value => value / forceUnit.divisor),
        visible: fileMetadata.visible ? true : "legendonly",
        opacity: 0.7,
        line: { color: rgba(fileMetadata.color, state.alpha), width: 1.5, dash: "solid" },
        hovertemplate: `${escapeHtml(fileMetadata.display_name)}<br>dm %{x:.3f} mm<br>fm %{y:.3f} ${state.forceUnit}<extra></extra>`
      };
    });

    Plotly.react(plot, traces, {
      paper_bgcolor: "#141412",
      plot_bgcolor: "#141412",
      font: { color: "#d6d4cb", family: "IBM Plex Sans, sans-serif", size: 12 },
      margin: { l: 82, r: 24, t: 72, b: 68 },
      showlegend: true,
      legend: { orientation: "h", x: 0, y: 1, yanchor: "bottom", itemclick: "toggle", itemdoubleclick: "toggleothers", uirevision: "hysteresis-series" },
      hovermode: "closest",
      dragmode: "zoom",
      uirevision: `${selected.map(file => file.path).join("|")}|${state.forceUnit}`,
      xaxis: { title: { text: "Filtered measured displacement, dm (mm)", standoff: 16 }, gridcolor: "#30322d", zerolinecolor: "#777a70", linecolor: "#4a4c46", mirror: true, ...(view ? { range: view.x, autorange: false } : { autorange: true }) },
      yaxis: { title: { text: `Measured force, fm (${state.forceUnit})`, standoff: 16 }, gridcolor: "#30322d", zerolinecolor: "#777a70", linecolor: "#4a4c46", mirror: true, ...(view ? { range: view.y, autorange: false } : { autorange: true }) }
    }, {
      responsive: true,
      scrollZoom: true,
      displaylogo: false,
      doubleClick: "reset+autosize",
      modeBarButtonsToRemove: ["select2d", "lasso2d"]
    }).then(() => {
      bindForceUnitToggle();
      if (relayoutListenerReady) return;
      relayoutListenerReady = true;
      plot.on("plotly_relayout", event => {
        if (event["xaxis.autorange"] || event["yaxis.autorange"]) {
          state.customView = null;
          syncSettings();
          render();
          scheduleMetadataSave();
          return;
        }
        const changedRange = Object.keys(event).some(key => key.startsWith("xaxis.range") || key.startsWith("yaxis.range"));
        if (!changedRange) return;
        state.customView = { x: [...plot._fullLayout.xaxis.range], y: [...plot._fullLayout.yaxis.range] };
        syncSettings();
        scheduleMetadataSave();
      });
      plot.on("plotly_restyle", () => requestAnimationFrame(() => {
        [...state.selected.keys()].forEach((path, index) => {
          metadata.files[path].visible = plot.data[index]?.visible !== "legendonly";
        });
        scheduleMetadataSave();
      }));
    });
  }

  renderTrees();
  const selectedEntries = state.manifest.filter(entry => metadata.files[entry.path].selected);
  await Promise.all(selectedEntries.map(async entry => {
    try {
      await loadEntry(entry);
    } catch {
      metadata.files[entry.path].selected = false;
    }
  }));
  renderTrees();
  render();
  scheduleMetadataSave(0);
  window.addEventListener("resize", () => Plotly.Plots.resize(plot), { passive: true });
}
