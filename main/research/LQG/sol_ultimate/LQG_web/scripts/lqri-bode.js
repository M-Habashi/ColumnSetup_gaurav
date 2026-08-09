"use strict";

import { createStepResponse } from "./step-response.js?v=20260806-10";

const svgNamespace = "http://www.w3.org/2000/svg";

function svgNode(name, attributes = {}) {
  const node = document.createElementNS(svgNamespace, name);
  Object.entries(attributes).forEach(([key, value]) => node.setAttribute(key, value));
  return node;
}

export function initLqriBode(reportData) {
  const lab = document.getElementById("lqriTrackingBodeLab");
  if (!lab || !reportData?.lqri_design?.bode) return;

  const design = reportData.lqri_design;
  const data = design.bode;
  const frequencies = data.frequency_hz;
  const visible = new Set(["pid", "lqri"]);
  const updateStep = createStepResponse("lqriTracking", design.step, ["pid", "lqri"]);
  const box = { left: 66, right: 650, top: 26, bottom: 222 };
  const xMaximum = frequencies[frequencies.length - 1];
  const xScale = frequency => box.left + frequency / xMaximum * (box.right - box.left);
  const magnitudeScale = db => box.bottom - (db + 65) / 90 * (box.bottom - box.top);
  const phaseScale = degrees => box.bottom - (degrees + 540) / 540 * (box.bottom - box.top);
  const pathFrom = points => points.map((point, index) => `${index ? "L" : "M"}${point[0].toFixed(1)},${point[1].toFixed(1)}`).join(" ");

  function addLine(group, x1, y1, x2, y2, className = "damage-bode-gridline") {
    group.appendChild(svgNode("line", { x1, y1, x2, y2, class: className }));
  }

  function addText(group, x, y, value, anchor = "middle") {
    const label = svgNode("text", { x, y, "text-anchor": anchor });
    label.textContent = value;
    group.appendChild(label);
  }

  function drawGrid(group, yTicks, yMap, title, showFrequency) {
    [0, 10, 20, 30, 40, 50, 60, 70, 80].forEach(frequency => {
      const x = xScale(frequency);
      addLine(group, x, box.top, x, box.bottom);
      if (showFrequency) addText(group, x, box.bottom + 20, frequency);
    });
    yTicks.forEach(value => {
      const y = yMap(value);
      addLine(group, box.left, y, box.right, y);
      addText(group, box.left - 10, y + 4, value, "end");
    });
    addLine(group, box.left, box.top, box.left, box.bottom, "damage-bode-axis");
    addLine(group, box.left, box.bottom, box.right, box.bottom, "damage-bode-axis");
    addText(group, box.left, 16, title, "start");
    if (showFrequency) addText(group, (box.left + box.right) / 2, 260, "Frequency (Hz)");
  }

  function polar(magnitudeDb, phaseDegrees) {
    const magnitude = 10 ** (magnitudeDb / 20);
    const phase = phaseDegrees * Math.PI / 180;
    return { re: magnitude * Math.cos(phase), im: magnitude * Math.sin(phase) };
  }

  function unwrapPhase(values) {
    const phases = [];
    let offset = 0;
    let previous;
    values.forEach(value => {
      let phase = Math.atan2(value.im, value.re) * 180 / Math.PI;
      if (previous !== undefined) {
        const jump = phase + offset - previous;
        if (jump > 180) offset -= 360;
        if (jump < -180) offset += 360;
      }
      phase += offset;
      phases.push(phase);
      previous = phase;
    });
    return phases;
  }

  function interpolateSeries(key, condition) {
    const nominal = data.condition7k[key];
    const damaged = data.condition5k[key];
    const values = frequencies.map((frequency, index) => {
      const start = polar(nominal.magnitude_db[index], nominal.phase_deg[index]);
      const end = polar(damaged.magnitude_db[index], damaged.phase_deg[index]);
      return {
        re: start.re + condition * (end.re - start.re),
        im: start.im + condition * (end.im - start.im)
      };
    });
    return {
      magnitude: values.map(value => 20 * Math.log10(Math.max(Math.hypot(value.re, value.im), 1e-12))),
      phase: unwrapPhase(values)
    };
  }

  function conditionLabel(condition) {
    const stiffness = 7 - 2 * condition;
    const damage = Math.round(100 * (7 - stiffness) / 7);
    return `${stiffness.toFixed(1)}k (${damage}%)`;
  }

  function interpolateMargin(key, condition) {
    const values = design.margin[key];
    const position = condition * (values.length - 1);
    const lower = Math.floor(position);
    const upper = Math.min(lower + 1, values.length - 1);
    const fraction = position - lower;
    return values[lower] + fraction * (values[upper] - values[lower]);
  }

  function setCurveVisibility(key) {
    const suffix = key === "pid" ? "Pid" : "Lqri";
    const display = visible.has(key) ? "" : "none";
    document.getElementById(`lqriTrackingBodeMag${suffix}`).style.display = display;
    document.getElementById(`lqriTrackingBodePhase${suffix}`).style.display = display;
    document.getElementById(`lqriTrackingStep${suffix}`).style.display = display;
  }

  function update() {
    const condition = Number(document.getElementById("lqriTrackingPlantSlider").value);
    ["pid", "lqri"].forEach(key => {
      const response = interpolateSeries(key, condition);
      const suffix = key === "pid" ? "Pid" : "Lqri";
      document.getElementById(`lqriTrackingBodeMag${suffix}`).setAttribute("d", pathFrom(frequencies.map((frequency, index) => [xScale(frequency), magnitudeScale(response.magnitude[index])])));
      document.getElementById(`lqriTrackingBodePhase${suffix}`).setAttribute("d", pathFrom(frequencies.map((frequency, index) => [xScale(frequency), phaseScale(response.phase[index])])));
      setCurveVisibility(key);
    });
    document.getElementById("lqriTrackingPlantOut").textContent = conditionLabel(condition);
    document.getElementById("lqriTrackingPidNcfOut").textContent = interpolateMargin("pid", condition).toFixed(2);
    document.getElementById("lqriTrackingLqriNcfOut").textContent = interpolateMargin("lqri", condition).toFixed(2);
    updateStep(condition);
  }

  drawGrid(document.getElementById("lqriTrackingBodeMagGrid"), [-60, -45, -30, -15, 0, 15], magnitudeScale, "Magnitude (dB)", false);
  drawGrid(document.getElementById("lqriTrackingBodePhaseGrid"), [-540, -450, -360, -270, -180, -90, 0], phaseScale, "Phase (deg)", true);
  const qy = Number(design.qy).toPrecision(8);
  const qi = Number(design.qi).toPrecision(8);
  document.getElementById("lqriTrackingLegend").textContent = `LQRI (Qy = ${qy}, Qi = ${qi}, R = ${design.ru})`;
  document.getElementById("lqriTrackingPlantSlider").addEventListener("input", update);
  document.querySelectorAll("[data-lqri-series]").forEach(button => {
    button.addEventListener("click", () => {
      const key = button.dataset.lqriSeries;
      if (visible.has(key)) visible.delete(key); else visible.add(key);
      button.classList.toggle("is-active", visible.has(key));
      button.setAttribute("aria-pressed", String(visible.has(key)));
      setCurveVisibility(key);
    });
  });
  update();
}
