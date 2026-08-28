"use strict";

const SVG_NS = "http://www.w3.org/2000/svg";

function exampleSeries(condition) {
  const points = 241;
  const measured = [];
  const command = [];
  const desired = [];
  const damping = 3.25 - 0.9 * condition;
  const frequency = 10.4 - 2.1 * condition;

  for (let index = 0; index < points; index += 1) {
    const time = 2.2 * index / (points - 1);
    const response = 1 - Math.exp(-damping * time) * (Math.cos(frequency * time) + 0.18 * Math.sin(frequency * time));
    const requested = 1 + (1.2 + 0.35 * condition) * Math.exp(-7.4 * time) - 0.22 * Math.exp(-2.8 * time) * Math.sin(8.5 * time);
    measured.push({ x: time, y: response });
    command.push({ x: time, y: requested });
    desired.push({ x: time, y: 1 });
  }

  return [
    { id: "desired", label: "Desired", color: "#F3F0E8", dashed: true, points: desired },
    { id: "measured", label: "Measured", color: "#007CA8", dashed: false, points: measured },
    { id: "command", label: "Command", color: "#AC6420", dashed: true, points: command }
  ];
}

function tickValues(min, max, count) {
  return Array.from({ length: count }, (_, index) => min + (max - min) * index / (count - 1));
}

function formatTick(value, span) {
  if (Math.abs(value) < 1e-10) return "0";
  const decimals = span < 1 ? 2 : span < 5 ? 1 : 0;
  return value.toFixed(decimals);
}

function pathFrom(points, scaleX, scaleY) {
  return points.map((point, index) => `${index === 0 ? "M" : "L"}${scaleX(point.x).toFixed(2)},${scaleY(point.y).toFixed(2)}`).join(" ");
}

export function initInteractivePlot(container, options = {}) {
  const svg = container.querySelector("[data-plot-svg]");
  const slider = container.querySelector("[data-condition-slider]");
  const conditionValue = container.querySelector("[data-condition-value]");
  const legend = container.querySelector("[data-plot-legend]");
  const zoomButton = container.querySelector('[data-plot-action="zoom"]');
  const resetButton = container.querySelector('[data-plot-action="reset"]');
  const shell = container.querySelector(".plot-shell");
  const seriesAdapter = options.series || exampleSeries;
  const fullDomain = { x: [0, 2.2], y: [-0.2, 2.35] };
  const viewDomain = { x: [...fullDomain.x], y: [...fullDomain.y] };
  const visible = new Map();
  const margin = { left: 68, right: 22, top: 24, bottom: 54 };
  const size = { width: 780, height: 390 };
  const plot = {
    x: margin.left,
    y: margin.top,
    width: size.width - margin.left - margin.right,
    height: size.height - margin.top - margin.bottom
  };
  let condition = Number(slider.value) / 100;
  let zoomMode = false;
  let dragStart = null;
  let frame = null;

  function currentSeries() {
    const series = seriesAdapter(condition);
    series.forEach(item => {
      if (!visible.has(item.id)) visible.set(item.id, true);
    });
    return series;
  }

  function scaleX(value) {
    return plot.x + (value - viewDomain.x[0]) / (viewDomain.x[1] - viewDomain.x[0]) * plot.width;
  }

  function scaleY(value) {
    return plot.y + plot.height - (value - viewDomain.y[0]) / (viewDomain.y[1] - viewDomain.y[0]) * plot.height;
  }

  function invertX(value) {
    return viewDomain.x[0] + (value - plot.x) / plot.width * (viewDomain.x[1] - viewDomain.x[0]);
  }

  function invertY(value) {
    return viewDomain.y[1] - (value - plot.y) / plot.height * (viewDomain.y[1] - viewDomain.y[0]);
  }

  function svgPoint(event) {
    const bounds = svg.getBoundingClientRect();
    return {
      x: (event.clientX - bounds.left) * size.width / bounds.width,
      y: (event.clientY - bounds.top) * size.height / bounds.height
    };
  }

  function insidePlot(point) {
    return point.x >= plot.x && point.x <= plot.x + plot.width && point.y >= plot.y && point.y <= plot.y + plot.height;
  }

  function updateLegend(series) {
    if (legend.childElementCount === series.length) {
      legend.querySelectorAll(".legend-item").forEach(button => {
        button.setAttribute("aria-pressed", String(visible.get(button.dataset.series)));
      });
      return;
    }

    legend.innerHTML = "";
    series.forEach(item => {
      const button = document.createElement("button");
      button.type = "button";
      button.className = "legend-item";
      button.dataset.series = item.id;
      button.setAttribute("aria-pressed", "true");
      button.innerHTML = `<span class="legend-line${item.dashed ? " is-dashed" : ""}" style="color:${item.color}"></span><span>${item.label}</span>`;
      button.addEventListener("click", () => {
        visible.set(item.id, !visible.get(item.id));
        render();
      });
      legend.append(button);
    });
  }

  function render() {
    const series = currentSeries();
    updateLegend(series);
    conditionValue.textContent = condition.toFixed(2);
    const xTicks = tickValues(viewDomain.x[0], viewDomain.x[1], 6);
    const yTicks = tickValues(viewDomain.y[0], viewDomain.y[1], 6);
    const xSpan = viewDomain.x[1] - viewDomain.x[0];
    const ySpan = viewDomain.y[1] - viewDomain.y[0];

    const verticalGrid = xTicks.map(value => `
      <line class="plot-grid-line" x1="${scaleX(value)}" y1="${plot.y}" x2="${scaleX(value)}" y2="${plot.y + plot.height}"></line>
      <text class="plot-tick-label" x="${scaleX(value)}" y="${plot.y + plot.height + 22}" text-anchor="middle">${formatTick(value, xSpan)}</text>
    `).join("");
    const horizontalGrid = yTicks.map(value => `
      <line class="${Math.abs(value) < ySpan / 1000 ? "plot-zero-line" : "plot-grid-line"}" x1="${plot.x}" y1="${scaleY(value)}" x2="${plot.x + plot.width}" y2="${scaleY(value)}"></line>
      <text class="plot-tick-label" x="${plot.x - 12}" y="${scaleY(value) + 4}" text-anchor="end">${formatTick(value, ySpan)}</text>
    `).join("");
    const paths = series.filter(item => visible.get(item.id)).map(item => `
      <path class="plot-series" d="${pathFrom(item.points, scaleX, scaleY)}" stroke="${item.color}"${item.dashed ? ' stroke-dasharray="8 6"' : ""}></path>
    `).join("");

    svg.innerHTML = `
      <defs><clipPath id="responsePlotClip"><rect x="${plot.x}" y="${plot.y}" width="${plot.width}" height="${plot.height}"></rect></clipPath></defs>
      ${verticalGrid}
      ${horizontalGrid}
      <line class="plot-axis-line" x1="${plot.x}" y1="${plot.y + plot.height}" x2="${plot.x + plot.width}" y2="${plot.y + plot.height}"></line>
      <line class="plot-axis-line" x1="${plot.x}" y1="${plot.y}" x2="${plot.x}" y2="${plot.y + plot.height}"></line>
      <g clip-path="url(#responsePlotClip)">${paths}</g>
      <text class="plot-axis-label" x="${plot.x + plot.width / 2}" y="${size.height - 12}" text-anchor="middle">Time (s)</text>
      <text class="plot-axis-label" transform="translate(17 ${plot.y + plot.height / 2}) rotate(-90)" text-anchor="middle">Normalized amplitude</text>
      <rect class="plot-hit-area" x="${plot.x}" y="${plot.y}" width="${plot.width}" height="${plot.height}"></rect>
      <rect class="zoom-selection" data-zoom-selection hidden></rect>
    `;
    legend.querySelectorAll(".legend-item").forEach(button => {
      button.setAttribute("aria-pressed", String(visible.get(button.dataset.series)));
    });
  }

  function scheduleRender() {
    if (frame) cancelAnimationFrame(frame);
    frame = requestAnimationFrame(() => {
      frame = null;
      render();
    });
  }

  function clearSelection() {
    const selection = svg.querySelector("[data-zoom-selection]");
    if (selection) selection.hidden = true;
    dragStart = null;
  }

  slider.addEventListener("input", () => {
    condition = Number(slider.value) / 100;
    scheduleRender();
  });

  zoomButton.addEventListener("click", () => {
    zoomMode = !zoomMode;
    zoomButton.setAttribute("aria-pressed", String(zoomMode));
    shell.classList.toggle("is-zooming", zoomMode);
    if (!zoomMode) clearSelection();
  });

  resetButton.addEventListener("click", () => {
    viewDomain.x = [...fullDomain.x];
    viewDomain.y = [...fullDomain.y];
    zoomMode = false;
    zoomButton.setAttribute("aria-pressed", "false");
    shell.classList.remove("is-zooming");
    resetButton.hidden = true;
    render();
  });

  svg.addEventListener("pointerdown", event => {
    if (!zoomMode) return;
    const point = svgPoint(event);
    if (!insidePlot(point)) return;
    dragStart = point;
    svg.setPointerCapture(event.pointerId);
    const selection = svg.querySelector("[data-zoom-selection]");
    selection.hidden = false;
    selection.setAttribute("x", point.x);
    selection.setAttribute("y", point.y);
    selection.setAttribute("width", 0);
    selection.setAttribute("height", 0);
  });

  svg.addEventListener("pointermove", event => {
    if (!dragStart) return;
    const point = svgPoint(event);
    const bounded = {
      x: Math.min(plot.x + plot.width, Math.max(plot.x, point.x)),
      y: Math.min(plot.y + plot.height, Math.max(plot.y, point.y))
    };
    const selection = svg.querySelector("[data-zoom-selection]");
    selection.setAttribute("x", Math.min(dragStart.x, bounded.x));
    selection.setAttribute("y", Math.min(dragStart.y, bounded.y));
    selection.setAttribute("width", Math.abs(bounded.x - dragStart.x));
    selection.setAttribute("height", Math.abs(bounded.y - dragStart.y));
  });

  function finishZoom(event) {
    if (!dragStart) return;
    const point = svgPoint(event);
    const bounded = {
      x: Math.min(plot.x + plot.width, Math.max(plot.x, point.x)),
      y: Math.min(plot.y + plot.height, Math.max(plot.y, point.y))
    };
    const width = Math.abs(bounded.x - dragStart.x);
    const height = Math.abs(bounded.y - dragStart.y);
    if (width >= 12 && height >= 12) {
      const x0 = invertX(Math.min(dragStart.x, bounded.x));
      const x1 = invertX(Math.max(dragStart.x, bounded.x));
      const y0 = invertY(Math.max(dragStart.y, bounded.y));
      const y1 = invertY(Math.min(dragStart.y, bounded.y));
      viewDomain.x = [x0, x1];
      viewDomain.y = [y0, y1];
      resetButton.hidden = false;
    }
    clearSelection();
    zoomMode = false;
    zoomButton.setAttribute("aria-pressed", "false");
    shell.classList.remove("is-zooming");
    render();
  }

  svg.addEventListener("pointerup", finishZoom);
  svg.addEventListener("pointercancel", () => {
    clearSelection();
    zoomMode = false;
    zoomButton.setAttribute("aria-pressed", "false");
    shell.classList.remove("is-zooming");
  });

  render();
}

