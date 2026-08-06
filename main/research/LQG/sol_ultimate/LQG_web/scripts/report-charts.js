"use strict";

let data;

const chartNamespace = "http://www.w3.org/2000/svg";
      const methodStyles = {
        desired: { label: "Desired", color: "#0b0b0a", width: 3, dash: "10 7" },
        pid: { label: "Saved PID", color: "#39bf5e", width: 2.4 },
        lqr: { label: "Full-state LQR", color: "#901500", width: 2.5 },
        ordinary_lqg: { label: "Ordinary LQG", color: "#ac6420", width: 2.3, dash: "7 5" },
        lqgi: { label: "Classical LQGI", color: "#007ca8", width: 2.7 }
      };

      const state = {
        condition: "condition7k",
        stepFocus: false,
        stepVisible: new Set(["desired", "pid", "lqr", "lqgi"]),
        bodeVisible: new Set(["pid", "lqr", "lqgi"])
      };

      function svgNode(name, attributes = {}) {
        const node = document.createElementNS(chartNamespace, name);
        Object.entries(attributes).forEach(([key, value]) => node.setAttribute(key, value));
        return node;
      }

      function formatTick(value, span) {
        if (Math.abs(value) >= 100) return value.toFixed(0);
        if (span < 2) return value.toFixed(2).replace(/0+$/, "").replace(/\.$/, "");
        if (Math.abs(value) < 10) return value.toFixed(1).replace(/\.0$/, "");
        return value.toFixed(0);
      }

      function extent(series, visibleKeys, fallback) {
        const values = [];
        series.forEach(item => {
          if (!visibleKeys.has(item.key)) return;
          item.values.forEach(value => { if (Number.isFinite(value)) values.push(value); });
        });
        if (!values.length) return fallback;
        let min = Math.min(...values);
        let max = Math.max(...values);
        if (min === max) { min -= 1; max += 1; }
        const pad = (max - min) * 0.09;
        return [min - pad, max + pad];
      }

      function renderChart(targetId, xValues, series, options) {
        const host = document.getElementById(targetId);
        host.replaceChildren();
        const width = 820;
        const height = options.height || 330;
        const margin = { top: 24, right: 24, bottom: 52, left: 66 };
        const innerWidth = width - margin.left - margin.right;
        const innerHeight = height - margin.top - margin.bottom;
        const svg = svgNode("svg", { viewBox: `0 0 ${width} ${height}`, role: "img" });
        const title = svgNode("title");
        title.textContent = options.ariaTitle;
        svg.appendChild(title);

        const xMin = options.xDomain ? options.xDomain[0] : Math.min(...xValues);
        const xMax = options.xDomain ? options.xDomain[1] : Math.max(...xValues);
        const yDomain = options.yDomain || extent(series, options.visible, [0, 1]);
        const yMin = yDomain[0];
        const yMax = yDomain[1];
        const xScale = value => {
          const normalized = options.logX
            ? (Math.log(value) - Math.log(xMin)) / (Math.log(xMax) - Math.log(xMin))
            : (value - xMin) / (xMax - xMin);
          return margin.left + normalized * innerWidth;
        };
        const yScale = value => margin.top + (1 - (value - yMin) / (yMax - yMin)) * innerHeight;

        const background = svgNode("rect", { x: margin.left, y: margin.top, width: innerWidth, height: innerHeight, fill: "#f4f1e9" });
        svg.appendChild(background);

        const yTickCount = 5;
        for (let i = 0; i <= yTickCount; i += 1) {
          const value = yMin + (yMax - yMin) * i / yTickCount;
          const y = yScale(value);
          svg.appendChild(svgNode("line", { x1: margin.left, x2: width - margin.right, y1: y, y2: y, stroke: "#d7d2c8", "stroke-width": 1 }));
          const label = svgNode("text", { x: margin.left - 10, y: y + 4, fill: "#4d4a44", "font-size": 12, "text-anchor": "end", "font-family": "IBM Plex Mono" });
          label.textContent = formatTick(value, yMax - yMin);
          svg.appendChild(label);
        }

        const xTicks = options.xTicks || Array.from({ length: 7 }, (_, i) => xMin + (xMax - xMin) * i / 6);
        xTicks.forEach(value => {
          const x = xScale(value);
          svg.appendChild(svgNode("line", { x1: x, x2: x, y1: margin.top, y2: height - margin.bottom, stroke: "#d7d2c8", "stroke-width": 1 }));
          const label = svgNode("text", { x, y: height - margin.bottom + 22, fill: "#4d4a44", "font-size": 12, "text-anchor": "middle", "font-family": "IBM Plex Mono" });
          label.textContent = options.logX ? String(value) : formatTick(value, xMax - xMin);
          svg.appendChild(label);
        });

        const clipId = `${targetId}-clip`;
        const defs = svgNode("defs");
        const clip = svgNode("clipPath", { id: clipId });
        clip.appendChild(svgNode("rect", { x: margin.left, y: margin.top, width: innerWidth, height: innerHeight }));
        defs.appendChild(clip);
        svg.appendChild(defs);

        const paths = svgNode("g", { "clip-path": `url(#${clipId})` });
        series.forEach(item => {
          if (!options.visible.has(item.key)) return;
          let pathData = "";
          item.values.forEach((value, index) => {
            if (!Number.isFinite(value)) return;
            const command = pathData ? "L" : "M";
            pathData += `${command}${xScale(xValues[index]).toFixed(2)},${yScale(value).toFixed(2)}`;
          });
          const style = methodStyles[item.key];
          const path = svgNode("path", {
            d: pathData,
            fill: "none",
            stroke: style.color,
            "stroke-width": style.width,
            "stroke-linecap": "round",
            "stroke-linejoin": "round",
            "vector-effect": "non-scaling-stroke",
            class: "series-path"
          });
          if (style.dash) path.setAttribute("stroke-dasharray", style.dash);
          paths.appendChild(path);
        });
        svg.appendChild(paths);

        const xLabel = svgNode("text", { x: margin.left + innerWidth / 2, y: height - 11, fill: "#302f2b", "font-size": 13, "text-anchor": "middle", "font-family": "IBM Plex Sans" });
        xLabel.textContent = options.xLabel;
        svg.appendChild(xLabel);
        const yLabel = svgNode("text", { x: 17, y: margin.top + innerHeight / 2, fill: "#302f2b", "font-size": 13, "text-anchor": "middle", "font-family": "IBM Plex Sans", transform: `rotate(-90 17 ${margin.top + innerHeight / 2})` });
        yLabel.textContent = options.yLabel;
        svg.appendChild(yLabel);

        host.appendChild(svg);
      }

      function buildLegend(targetId, keys, visible, onToggle) {
        const legend = document.getElementById(targetId);
        legend.replaceChildren();
        keys.forEach(key => {
          const style = methodStyles[key];
          const button = document.createElement("button");
          button.type = "button";
          button.className = "legend-item";
          button.setAttribute("aria-pressed", String(visible.has(key)));
          button.style.color = style.color;
          const line = document.createElement("span");
          line.className = `legend-line${style.dash ? " is-dashed" : ""}`;
          const label = document.createElement("span");
          label.textContent = style.label;
          label.style.color = "#3c3a35";
          button.append(line, label);
          button.addEventListener("click", () => onToggle(key));
          legend.appendChild(button);
        });
      }

      function renderStep() {
        const condition = data.step[state.condition];
        const keys = ["desired", "pid", "lqr", "ordinary_lqg", "lqgi"];
        const series = keys.map(key => ({
          key,
          values: key === "desired" ? data.step.time_s.map(() => 1) : condition[key]
        }));
        let yDomain;
        if (state.condition === "condition7k") yDomain = [-0.08, 1.2];
        else if (state.stepFocus) yDomain = [-0.08, 1.25];
        else yDomain = [-0.25, 8.85];
        renderChart("stepChart", data.step.time_s, series, {
          visible: state.stepVisible,
          yDomain,
          xDomain: [0, 0.6],
          xLabel: "Time (s)",
          yLabel: "Measured response / reference",
          ariaTitle: `${state.condition === "condition7k" ? "7k" : "5k"} unit-step response`,
          height: 350
        });
        buildLegend("stepLegend", keys, state.stepVisible, key => {
          if (state.stepVisible.has(key)) state.stepVisible.delete(key); else state.stepVisible.add(key);
          renderStep();
        });
        const button = document.getElementById("stepScaleButton");
        button.hidden = state.condition === "condition7k";
        button.textContent = state.stepFocus ? "Show full 5k failure" : "Focus on unit target";
      }

      function renderBode() {
        const condition = data.bode[state.condition];
        const keys = ["pid", "lqr", "lqgi"];
        const magnitudeSeries = keys.map(key => ({ key, values: condition[key].magnitude_db }));
        const phaseSeries = keys.map(key => ({ key, values: condition[key].phase_deg }));
        const xTicks = [2, 5, 10, 20, 40, 80];
        renderChart("bodeMagnitude", data.bode.frequency_hz, magnitudeSeries, {
          visible: state.bodeVisible,
          logX: true,
          xDomain: [2, 80],
          xTicks,
          xLabel: "Frequency (Hz)",
          yLabel: "Magnitude (dB)",
          ariaTitle: `${state.condition === "condition7k" ? "7k" : "5k"} Bode magnitude`,
          height: 310
        });
        renderChart("bodePhase", data.bode.frequency_hz, phaseSeries, {
          visible: state.bodeVisible,
          logX: true,
          xDomain: [2, 80],
          xTicks,
          xLabel: "Frequency (Hz)",
          yLabel: "Phase (degrees)",
          ariaTitle: `${state.condition === "condition7k" ? "7k" : "5k"} Bode phase`,
          height: 310
        });
        const toggle = key => {
          if (state.bodeVisible.has(key)) state.bodeVisible.delete(key); else state.bodeVisible.add(key);
          renderBode();
        };
        buildLegend("bodeMagnitudeLegend", keys, state.bodeVisible, toggle);
        buildLegend("bodePhaseLegend", keys, state.bodeVisible, toggle);
      }

      function setCondition(condition) {
        state.condition = condition;
        state.stepFocus = false;
        state.stepVisible = condition === "condition7k"
          ? new Set(["desired", "pid", "lqr", "lqgi"])
          : new Set(["desired", "pid", "lqr", "ordinary_lqg", "lqgi"]);
        document.querySelectorAll(".condition-tab").forEach(button => {
          button.setAttribute("aria-selected", String(button.dataset.condition === condition));
        });
        document.getElementById("stepDescription").textContent = condition === "condition7k"
          ? "At 7k, LQR is fast but aggressive; LQGI trades some settling speed for implementable output regulation and lower command effort."
          : "At 5k, the reused precompensator drives the full-state LQR to 6.7666. Ordinary LQG reduces the error but cannot restore unit regulation; LQGI does."
        document.getElementById("stepNote").textContent = condition === "condition7k"
          ? "The ordinary nominal-observer LQG overlaps the nominal full-state LQR at 7k and is hidden initially."
          : "Use the focus control to inspect PID and LQGI near the target; the large LQR response will be clipped in that view."
        renderStep();
        renderBode();
      }

export function initReportCharts(plotData) {
  data = plotData;
  document.querySelectorAll(".condition-tab").forEach(button => {
    button.addEventListener("click", () => setCondition(button.dataset.condition));
  });
  document.getElementById("stepScaleButton").addEventListener("click", () => {
    state.stepFocus = !state.stepFocus;
    renderStep();
  });
  setCondition("condition7k");
}
