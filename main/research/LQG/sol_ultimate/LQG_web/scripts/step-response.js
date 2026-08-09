"use strict";

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

function addPlotClip(prefix, grid, box, paths) {
  const clipId = `${prefix}StepClip`;
  const definitions = svgNode("defs");
  const clip = svgNode("clipPath", { id: clipId });
  clip.appendChild(svgNode("rect", { x: box.left, y: box.top, width: box.right - box.left, height: box.bottom - box.top }));
  definitions.appendChild(clip);
  grid.closest("svg").prepend(definitions);
  paths.forEach(path => path.setAttribute("clip-path", `url(#${clipId})`));
}

export function createStepResponse(prefix, data, series) {
  if (!data?.time_s) return () => {};
  const time = data.time_s;
  const box = { left: 66, right: 650, top: 26, bottom: 222 };
  const allValues = [0, 1];
  [data.condition7k, data.condition5k].forEach(condition => {
    series.forEach(key => allValues.push(...condition[key]));
  });
  const rawMaximum = Math.max(...allValues);
  const yMinimum = 0;
  const yMaximum = 1.08 * Math.max(1, rawMaximum);
  const xScale = value => box.left + value / time[time.length - 1] * (box.right - box.left);
  const yScale = value => box.bottom - (value - yMinimum) / (yMaximum - yMinimum) * (box.bottom - box.top);
  const pathFrom = points => points.map((point, index) => `${index ? "L" : "M"}${point[0].toFixed(1)},${point[1].toFixed(1)}`).join(" ");
  const grid = document.getElementById(`${prefix}StepGrid`);
  const paths = series.map(key => document.getElementById(`${prefix}Step${key[0].toUpperCase()}${key.slice(1)}`));
  addPlotClip(prefix, grid, box, paths);

  for (let index = 0; index <= 5; index += 1) {
    const timeValue = index * time[time.length - 1] / 5;
    const x = xScale(timeValue);
    grid.appendChild(svgNode("line", { x1: x, y1: box.top, x2: x, y2: box.bottom, class: "damage-bode-gridline" }));
    addText(grid, x, box.bottom + 20, timeValue.toFixed(timeValue < 2 ? 1 : 0));
  }
  for (let index = 0; index <= 4; index += 1) {
    const value = yMinimum + index * (yMaximum - yMinimum) / 4;
    const y = yScale(value);
    grid.appendChild(svgNode("line", { x1: box.left, y1: y, x2: box.right, y2: y, class: "damage-bode-gridline" }));
    addText(grid, box.left - 10, y + 4, value.toFixed(2), "end");
  }
  grid.appendChild(svgNode("line", { x1: box.left, y1: box.top, x2: box.left, y2: box.bottom, class: "damage-bode-axis" }));
  grid.appendChild(svgNode("line", { x1: box.left, y1: box.bottom, x2: box.right, y2: box.bottom, class: "damage-bode-axis" }));
  addText(grid, box.left, 16, "Unit-step response", "start");
  addText(grid, (box.left + box.right) / 2, 260, "Time (s)");

  return condition => {
    series.forEach(key => {
      const start = data.condition7k[key];
      const end = data.condition5k[key];
      const values = start.map((value, index) => value + condition * (end[index] - value));
      const suffix = `${key[0].toUpperCase()}${key.slice(1)}`;
      const points = time.map((value, index) => [xScale(value), yScale(values[index])]);
      document.getElementById(`${prefix}Step${suffix}`).setAttribute("d", pathFrom(points));
    });
  };
}

export function createParametricStepResponse(prefix, data) {
  if (!data?.time_s) return () => {};
  const time = data.time_s;
  const alphaGrid = data.alpha;
  const box = { left: 66, right: 650, top: 26, bottom: 222 };
  const allValues = [0, 1, ...data.condition7k.flat(), ...data.condition5k.flat()];
  const rawMaximum = Math.max(...allValues);
  const yMinimum = 0;
  const yMaximum = 1.08 * Math.max(1, rawMaximum);
  const xScale = value => box.left + value / time[time.length - 1] * (box.right - box.left);
  const yScale = value => box.bottom - (value - yMinimum) / (yMaximum - yMinimum) * (box.bottom - box.top);
  const pathFrom = values => values.map((value, index) => `${index ? "L" : "M"}${xScale(time[index]).toFixed(1)},${yScale(value).toFixed(1)}`).join(" ");
  const grid = document.getElementById(`${prefix}StepGrid`);
  const paths = [document.getElementById(`${prefix}StepReference`), document.getElementById(`${prefix}StepLive`)];
  addPlotClip(prefix, grid, box, paths);

  for (let index = 0; index <= 5; index += 1) {
    const value = index * time[time.length - 1] / 5;
    const x = xScale(value);
    grid.appendChild(svgNode("line", { x1: x, y1: box.top, x2: x, y2: box.bottom, class: "damage-bode-gridline" }));
    addText(grid, x, box.bottom + 20, value.toFixed(1));
  }
  for (let index = 0; index <= 4; index += 1) {
    const value = yMinimum + index * (yMaximum - yMinimum) / 4;
    const y = yScale(value);
    grid.appendChild(svgNode("line", { x1: box.left, y1: y, x2: box.right, y2: y, class: "damage-bode-gridline" }));
    addText(grid, box.left - 10, y + 4, value.toFixed(2), "end");
  }
  grid.appendChild(svgNode("line", { x1: box.left, y1: box.top, x2: box.left, y2: box.bottom, class: "damage-bode-axis" }));
  grid.appendChild(svgNode("line", { x1: box.left, y1: box.bottom, x2: box.right, y2: box.bottom, class: "damage-bode-axis" }));
  addText(grid, box.left, 16, "Closed-loop unit-step response", "start");
  addText(grid, (box.left + box.right) / 2, 260, "Time (s)");
  const reference = data.condition7k.map(row => row[row.length - 1]);
  document.getElementById(`${prefix}StepReference`).setAttribute("d", pathFrom(reference));

  return (condition, alpha) => {
    const position = (alpha - alphaGrid[0]) / (alphaGrid[alphaGrid.length - 1] - alphaGrid[0]) * (alphaGrid.length - 1);
    const lower = Math.max(0, Math.min(Math.floor(position), alphaGrid.length - 1));
    const upper = Math.min(lower + 1, alphaGrid.length - 1);
    const fraction = position - lower;
    const responseAt = matrix => matrix.map(row => row[lower] + fraction * (row[upper] - row[lower]));
    const nominal = responseAt(data.condition7k);
    const damaged = responseAt(data.condition5k);
    const live = nominal.map((value, index) => value + condition * (damaged[index] - value));
    document.getElementById(`${prefix}StepLive`).setAttribute("d", pathFrom(live));
  };
}
