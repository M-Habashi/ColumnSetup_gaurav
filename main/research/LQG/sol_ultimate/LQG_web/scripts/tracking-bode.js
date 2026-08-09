"use strict";

import { attachAxisZoom, formatAxisTick, linearTicks, scaleLinear } from "./axis-zoom.js?v=20260808-1";
import { createStepResponse } from "./step-response.js?v=20260808-1";

const svgNamespace = "http://www.w3.org/2000/svg";

function svgNode(name, attributes = {}) {
  const node = document.createElementNS(svgNamespace, name);
  Object.entries(attributes).forEach(([key, value]) => node.setAttribute(key, value));
  return node;
}

export function initTrackingBode(reportData) {
  const lab = document.getElementById("trackingBodeLab");
  if (!lab || !reportData?.ncf_design?.bode) return;

  const design = reportData.ncf_design;
  const data = design.bode;
  const frequencies = data.frequency_hz;
  const visible = new Set(["pid", "lqr"]);
  const updateStep = createStepResponse("tracking", design.step, ["pid", "lqr"]);
  const box = { left: 66, right: 650, top: 26, bottom: 222 };
  const magnitudeDomain = { x: [0, frequencies[frequencies.length - 1]], y: [-35, 25] };
  const phaseDomain = { x: [0, frequencies[frequencies.length - 1]], y: [-450, 0] };
  const magnitudeGrid = document.getElementById("trackingBodeMagGrid");
  const phaseGrid = document.getElementById("trackingBodePhaseGrid");
  const magnitudePaths = [document.getElementById("trackingBodeMagPid"), document.getElementById("trackingBodeMagLqr")];
  const phasePaths = [document.getElementById("trackingBodePhasePid"), document.getElementById("trackingBodePhaseLqr")];

  function addLine(group, x1, y1, x2, y2, className = "damage-bode-gridline") {
    group.appendChild(svgNode("line", { x1, y1, x2, y2, class: className }));
  }

  function addText(group, x, y, value, anchor = "middle") {
    const label = svgNode("text", { x, y, "text-anchor": anchor });
    label.textContent = value;
    group.appendChild(label);
  }

  function drawGrid(group, domain, title, showFrequency) {
    group.replaceChildren();
    linearTicks(domain.x, 8).forEach(value => {
      const x = scaleLinear(value, domain.x, [box.left, box.right]);
      addLine(group, x, box.top, x, box.bottom);
      if (showFrequency) addText(group, x, box.bottom + 20, formatAxisTick(value, domain.x[1] - domain.x[0]));
    });
    linearTicks(domain.y, 5).forEach(value => {
      const y = scaleLinear(value, domain.y, [box.bottom, box.top]);
      addLine(group, box.left, y, box.right, y);
      addText(group, box.left - 10, y + 4, formatAxisTick(value, domain.y[1] - domain.y[0]), "end");
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
      return { re: start.re + condition * (end.re - start.re), im: start.im + condition * (end.im - start.im) };
    });
    return {
      magnitude: values.map(value => 20 * Math.log10(Math.max(Math.hypot(value.re, value.im), 1e-12))),
      phase: unwrapPhase(values)
    };
  }

  function pathFrom(values, domain) {
    return values.map((value, index) => {
      const x = scaleLinear(frequencies[index], domain.x, [box.left, box.right]);
      const y = scaleLinear(value, domain.y, [box.bottom, box.top]);
      return `${index ? "L" : "M"}${x.toFixed(1)},${y.toFixed(1)}`;
    }).join(" ");
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
    return values[lower] + (position - lower) * (values[upper] - values[lower]);
  }

  function setCurveVisibility(key) {
    const display = visible.has(key) ? "" : "none";
    document.getElementById(`trackingBodeMag${key === "pid" ? "Pid" : "Lqr"}`).style.display = display;
    document.getElementById(`trackingBodePhase${key === "pid" ? "Pid" : "Lqr"}`).style.display = display;
    document.getElementById(`trackingStep${key === "pid" ? "Pid" : "Lqr"}`).style.display = display;
  }

  function update() {
    const condition = Number(document.getElementById("trackingPlantSlider").value);
    ["pid", "lqr"].forEach(key => {
      const response = interpolateSeries(key, condition);
      const suffix = key === "pid" ? "Pid" : "Lqr";
      document.getElementById(`trackingBodeMag${suffix}`).setAttribute("d", pathFrom(response.magnitude, magnitudeDomain));
      document.getElementById(`trackingBodePhase${suffix}`).setAttribute("d", pathFrom(response.phase, phaseDomain));
      setCurveVisibility(key);
    });
    document.getElementById("trackingPlantOut").textContent = conditionLabel(condition);
    document.getElementById("trackingPidNcfOut").textContent = interpolateMargin("pid", condition).toFixed(2);
    document.getElementById("trackingLqrNcfOut").textContent = interpolateMargin("lqr", condition).toFixed(2);
    updateStep(condition);
  }

  drawGrid(magnitudeGrid, magnitudeDomain, "Magnitude (dB)", false);
  drawGrid(phaseGrid, phaseDomain, "Phase (deg)", true);
  attachAxisZoom({
    svg: magnitudeGrid.closest("svg"), box, xDomain: magnitudeDomain.x, yDomain: magnitudeDomain.y, clipElements: magnitudePaths,
    onChange: (x, y) => { magnitudeDomain.x = x; magnitudeDomain.y = y; drawGrid(magnitudeGrid, magnitudeDomain, "Magnitude (dB)", false); update(); }
  });
  attachAxisZoom({
    svg: phaseGrid.closest("svg"), box, xDomain: phaseDomain.x, yDomain: phaseDomain.y, clipElements: phasePaths,
    onChange: (x, y) => { phaseDomain.x = x; phaseDomain.y = y; drawGrid(phaseGrid, phaseDomain, "Phase (deg)", true); update(); }
  });
  document.getElementById("trackingLqrLegend").textContent = `LQR (Qy = ${Number(design.qy).toPrecision(8)}, R = ${design.ru})`;
  document.getElementById("trackingPlantSlider").addEventListener("input", update);
  document.querySelectorAll("[data-tracking-series]").forEach(button => {
    button.addEventListener("click", () => {
      const key = button.dataset.trackingSeries;
      if (visible.has(key)) visible.delete(key); else visible.add(key);
      button.classList.toggle("is-active", visible.has(key));
      button.setAttribute("aria-pressed", String(visible.has(key)));
      setCurveVisibility(key);
    });
  });
  update();
}
