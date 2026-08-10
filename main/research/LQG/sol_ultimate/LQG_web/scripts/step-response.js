"use strict";

import { attachAxisZoom, formatAxisTick, linearTicks, scaleLinear } from "./axis-zoom.js?v=20260808-1";

const svgNamespace = "http://www.w3.org/2000/svg";

function svgNode(name, attributes = {}) {
  const node = document.createElementNS(svgNamespace, name);
  Object.entries(attributes).forEach(([key, value]) => node.setAttribute(key, value));
  return node;
}

function addText(group, x, y, value, anchor = "middle") {
  const label = svgNode("text", { x, y, "text-anchor": anchor });
  label.textContent = value;
  group.appendChild(label);
}

function drawGrid(grid, box, domain, title) {
  grid.replaceChildren();
  linearTicks(domain.x, 5).forEach(value => {
    const x = scaleLinear(value, domain.x, [box.left, box.right]);
    grid.appendChild(svgNode("line", { x1: x, y1: box.top, x2: x, y2: box.bottom, class: "damage-bode-gridline" }));
    addText(grid, x, box.bottom + 20, formatAxisTick(value, domain.x[1] - domain.x[0]));
  });
  linearTicks(domain.y, 4).forEach(value => {
    const y = scaleLinear(value, domain.y, [box.bottom, box.top]);
    grid.appendChild(svgNode("line", { x1: box.left, y1: y, x2: box.right, y2: y, class: "damage-bode-gridline" }));
    addText(grid, box.left - 10, y + 4, formatAxisTick(value, domain.y[1] - domain.y[0]), "end");
  });
  if (domain.y[0] < 0 && domain.y[1] > 0) {
    const zeroY = scaleLinear(0, domain.y, [box.bottom, box.top]);
    grid.appendChild(svgNode("line", { x1: box.left, y1: zeroY, x2: box.right, y2: zeroY, class: "step-zero-line" }));
  }
  grid.appendChild(svgNode("line", { x1: box.left, y1: box.top, x2: box.left, y2: box.bottom, class: "damage-bode-axis" }));
  grid.appendChild(svgNode("line", { x1: box.left, y1: box.bottom, x2: box.right, y2: box.bottom, class: "damage-bode-axis" }));
  addText(grid, box.left, 16, title, "start");
  addText(grid, (box.left + box.right) / 2, 260, "Time (s)");
}

export function createStepResponse(prefix, data, series, options = {}) {
  if (!data?.time_s) return () => {};
  const time = data.time_s;
  const box = { left: 66, right: 650, top: 26, bottom: 222 };
  const allValues = [0, 1];
  const scaleConditions = options.scaleFromNominal ? [data.condition7k] : [data.condition7k, data.condition5k];
  scaleConditions.forEach(condition => {
    series.forEach(key => allValues.push(...condition[key], ...condition.command[key]));
  });
  const minimum = Math.min(0, ...allValues);
  const maximum = Math.max(1, ...allValues);
  const padding = 0.08 * (maximum - minimum);
  const domain = { x: [0, time[time.length - 1]], y: [minimum < 0 ? minimum - padding : 0, maximum + padding] };
  const grid = document.getElementById(`${prefix}StepGrid`);
  const svg = grid.closest("svg");
  const paths = series.flatMap(key => {
    const suffix = `${key[0].toUpperCase()}${key.slice(1)}`;
    return [document.getElementById(`${prefix}Step${suffix}`), document.getElementById(`${prefix}Step${suffix}Command`)];
  });
  let currentCondition = 0;

  function boundedValue(value) {
    const numeric = Number(value);
    if (!Number.isFinite(numeric)) return 0;
    const limit = options.valueLimit ?? Number.POSITIVE_INFINITY;
    return Math.max(-limit, Math.min(limit, numeric));
  }

  function render() {
    series.forEach(key => {
      const start = data.condition7k[key];
      const end = data.condition5k[key];
      let responseDrawing = false;
      const suffix = `${key[0].toUpperCase()}${key.slice(1)}`;
      const path = time.map((value, index) => {
        const rawResponse = start[index] + currentCondition * (end[index] - start[index]);
        if (options.breakOutsideDomain && (!Number.isFinite(rawResponse) || rawResponse < domain.y[0] || rawResponse > domain.y[1])) {
          responseDrawing = false;
          return "";
        }
        const response = boundedValue(rawResponse);
        const x = scaleLinear(value, domain.x, [box.left, box.right]);
        const y = scaleLinear(response, domain.y, [box.bottom, box.top]);
        const pathCommand = responseDrawing ? "L" : "M";
        responseDrawing = true;
        return `${pathCommand}${x.toFixed(1)},${y.toFixed(1)}`;
      }).filter(Boolean).join(" ");
      document.getElementById(`${prefix}Step${suffix}`).setAttribute("d", path);
      let commandDrawing = false;
      const commandPath = time.map((value, index) => {
        const startCommand = data.condition7k.command[key][index];
        const endCommand = data.condition5k.command[key][index];
        const rawCommand = startCommand + currentCondition * (endCommand - startCommand);
        if (options.breakOutsideDomain && (!Number.isFinite(rawCommand) || rawCommand < domain.y[0] || rawCommand > domain.y[1])) {
          commandDrawing = false;
          return "";
        }
        const command = boundedValue(rawCommand);
        const x = scaleLinear(value, domain.x, [box.left, box.right]);
        const y = scaleLinear(command, domain.y, [box.bottom, box.top]);
        const pathCommand = commandDrawing ? "L" : "M";
        commandDrawing = true;
        return `${pathCommand}${x.toFixed(1)},${y.toFixed(1)}`;
      }).filter(Boolean).join(" ");
      document.getElementById(`${prefix}Step${suffix}Command`).setAttribute("d", commandPath);
    });
  }

  drawGrid(grid, box, domain, "Unit-step response · dashed = command to plant");
  attachAxisZoom({
    svg,
    box,
    xDomain: domain.x,
    yDomain: domain.y,
    clipElements: paths,
    onChange: (x, y) => {
      domain.x = x;
      domain.y = y;
      drawGrid(grid, box, domain, "Unit-step response · dashed = command to plant");
      render();
    }
  });

  return condition => {
    currentCondition = condition;
    render();
  };
}

export function createParametricStepResponse(prefix, data) {
  if (!data?.time_s) return () => {};
  const time = data.time_s;
  const alphaGrid = data.alpha;
  const box = { left: 66, right: 650, top: 26, bottom: 222 };
  const allValues = [0, 1, ...data.condition7k.flat(), ...data.condition5k.flat()];
  const domain = { x: [0, time[time.length - 1]], y: [0, 1.08 * Math.max(1, ...allValues)] };
  const grid = document.getElementById(`${prefix}StepGrid`);
  const svg = grid.closest("svg");
  const referencePath = document.getElementById(`${prefix}StepReference`);
  const livePath = document.getElementById(`${prefix}StepLive`);
  const reference = data.condition7k.map(row => row[row.length - 1]);
  let currentCondition = 0;
  let currentAlpha = alphaGrid[alphaGrid.length - 1];

  function pathFrom(values) {
    return values.map((value, index) => {
      const x = scaleLinear(time[index], domain.x, [box.left, box.right]);
      const y = scaleLinear(value, domain.y, [box.bottom, box.top]);
      return `${index ? "L" : "M"}${x.toFixed(1)},${y.toFixed(1)}`;
    }).join(" ");
  }

  function render() {
    const position = (currentAlpha - alphaGrid[0]) / (alphaGrid[alphaGrid.length - 1] - alphaGrid[0]) * (alphaGrid.length - 1);
    const lower = Math.max(0, Math.min(Math.floor(position), alphaGrid.length - 1));
    const upper = Math.min(lower + 1, alphaGrid.length - 1);
    const fraction = position - lower;
    const responseAt = matrix => matrix.map(row => row[lower] + fraction * (row[upper] - row[lower]));
    const nominal = responseAt(data.condition7k);
    const damaged = responseAt(data.condition5k);
    const live = nominal.map((value, index) => value + currentCondition * (damaged[index] - value));
    referencePath.setAttribute("d", pathFrom(reference));
    livePath.setAttribute("d", pathFrom(live));
  }

  drawGrid(grid, box, domain, "Closed-loop unit-step response");
  attachAxisZoom({
    svg,
    box,
    xDomain: domain.x,
    yDomain: domain.y,
    clipElements: [referencePath, livePath],
    onChange: (x, y) => {
      domain.x = x;
      domain.y = y;
      drawGrid(grid, box, domain, "Closed-loop unit-step response");
      render();
    }
  });
  render();

  return (condition, alpha) => {
    currentCondition = condition;
    currentAlpha = alpha;
    render();
  };
}
