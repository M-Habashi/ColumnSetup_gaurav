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
  grid.appendChild(svgNode("line", { x1: box.left, y1: box.top, x2: box.left, y2: box.bottom, class: "damage-bode-axis" }));
  grid.appendChild(svgNode("line", { x1: box.left, y1: box.bottom, x2: box.right, y2: box.bottom, class: "damage-bode-axis" }));
  addText(grid, box.left, 16, title, "start");
  addText(grid, (box.left + box.right) / 2, 260, "Time (s)");
}

export function createStepResponse(prefix, data, series) {
  if (!data?.time_s) return () => {};
  const time = data.time_s;
  const box = { left: 66, right: 650, top: 26, bottom: 222 };
  const allValues = [0, 1];
  [data.condition7k, data.condition5k].forEach(condition => {
    series.forEach(key => allValues.push(...condition[key]));
  });
  const domain = { x: [0, time[time.length - 1]], y: [0, 1.08 * Math.max(1, ...allValues)] };
  const grid = document.getElementById(`${prefix}StepGrid`);
  const svg = grid.closest("svg");
  const paths = series.map(key => document.getElementById(`${prefix}Step${key[0].toUpperCase()}${key.slice(1)}`));
  let currentCondition = 0;

  function render() {
    series.forEach(key => {
      const start = data.condition7k[key];
      const end = data.condition5k[key];
      const suffix = `${key[0].toUpperCase()}${key.slice(1)}`;
      const path = time.map((value, index) => {
        const response = start[index] + currentCondition * (end[index] - start[index]);
        const x = scaleLinear(value, domain.x, [box.left, box.right]);
        const y = scaleLinear(response, domain.y, [box.bottom, box.top]);
        return `${index ? "L" : "M"}${x.toFixed(1)},${y.toFixed(1)}`;
      }).join(" ");
      document.getElementById(`${prefix}Step${suffix}`).setAttribute("d", path);
    });
  }

  drawGrid(grid, box, domain, "Unit-step response");
  attachAxisZoom({
    svg,
    box,
    xDomain: domain.x,
    yDomain: domain.y,
    clipElements: paths,
    onChange: (x, y) => {
      domain.x = x;
      domain.y = y;
      drawGrid(grid, box, domain, "Unit-step response");
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
