"use strict";

const chartNamespace = "http://www.w3.org/2000/svg";

function svgNode(name, attributes = {}) {
  const node = document.createElementNS(chartNamespace, name);
  Object.entries(attributes).forEach(([key, value]) => node.setAttribute(key, value));
  return node;
}

export function initDamageBodeExplorer(osiBodeData) {
        if (!osiBodeData || !document.getElementById("damageBodeLab")) return;

        const box = { left: 66, right: 650, top: 26, bottom: 222 };
        const xScale = frequency => box.left + Math.log10(frequency / 0.2) / Math.log10(500) * (box.right - box.left);
        const magnitudeScale = db => box.bottom - (db + 30) / 70 * (box.bottom - box.top);
        const phaseScale = degrees => box.bottom - (degrees + 450) / 450 * (box.bottom - box.top);
        const complex = (re, im) => ({ re, im });
        const magnitudeDb = value => 20 * Math.log10(Math.max(Math.hypot(value.re, value.im), 1e-12));
        const pathFrom = points => points.map((point, index) => `${index ? "L" : "M"}${point[0].toFixed(1)},${point[1].toFixed(1)}`).join(" ");
        const closedLoop = value => {
          const denominator = (1 + value.re) ** 2 + value.im ** 2;
          return {
            re: (value.re * (1 + value.re) + value.im ** 2) / denominator,
            im: value.im / denominator
          };
        };

        function addLine(group, x1, y1, x2, y2, className = "damage-bode-gridline") {
          group.appendChild(svgNode("line", { x1, y1, x2, y2, class: className }));
        }

        function addText(group, x, y, value, anchor = "middle", className) {
          const attributes = { x, y, "text-anchor": anchor };
          if (className) attributes.class = className;
          const text = svgNode("text", attributes);
          text.textContent = value;
          group.appendChild(text);
        }

        function drawGrid(group, yTicks, yMap, title, showFrequency) {
          [0.2, 0.5, 1, 2, 5, 10, 20, 50, 100].forEach(frequency => {
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

        function unwrapPhase(values) {
          const unwrapped = [];
          let offset = 0;
          let previous;
          values.forEach(value => {
            let degrees = Math.atan2(value.im, value.re) * 180 / Math.PI;
            if (previous !== undefined) {
              const jump = degrees + offset - previous;
              if (jump > 180) offset -= 360;
              if (jump < -180) offset += 360;
            }
            degrees += offset;
            unwrapped.push(degrees);
            previous = degrees;
          });
          return unwrapped;
        }

        function interpolateCross(frequencies, values, target) {
          for (let index = 0; index < values.length - 1; index += 1) {
            const start = values[index] - target;
            const end = values[index + 1] - target;
            if (start === 0 || start * end < 0) {
              const ratio = start === 0 ? 0 : start / (start - end);
              const logFrequency = Math.log(frequencies[index]) + ratio * (Math.log(frequencies[index + 1]) - Math.log(frequencies[index]));
              return { frequency: Math.exp(logFrequency), index, ratio };
            }
          }
          return null;
        }

        const interpolateAt = (values, crossing) => values[crossing.index] + crossing.ratio * (values[crossing.index + 1] - values[crossing.index]);
        const clearGroup = group => group.replaceChildren();

        function addMarker(group, x, y) {
          group.appendChild(svgNode("circle", { cx: x, cy: y, r: 4, class: "damage-bode-margin-marker" }));
        }

        function addMarginLabel(group, x, y, value, anchor = "start") {
          addText(group, x, y, value, anchor, "damage-bode-margin-label");
        }

        function liveColor(condition) {
          const blend = Math.min(condition, 1);
          const start = [216, 178, 76];
          const end = [216, 178, 76];
          return `rgb(${start.map((value, index) => Math.round(value + (end[index] - value) * blend)).join(",")})`;
        }

        function conditionLabel(condition) {
          const stiffness = 7 - 2 * condition;
          const damage = Math.round(100 * (7 - stiffness) / 7);
          const note = condition > 1 ? " · extrap." : "";
          return `${stiffness.toFixed(1)}k (${damage}%)${note}`;
        }

        drawGrid(document.getElementById("damageBodeMagGrid"), [-30, -20, -10, 0, 10, 20, 30, 40], magnitudeScale, "Magnitude (dB)", false);
        drawGrid(document.getElementById("damageBodePhaseGrid"), [-450, -360, -270, -180, -90, 0], phaseScale, "Phase (deg)", true);
        const criticalY = phaseScale(-180);
        const criticalLine = document.getElementById("damagePhaseCritical");
        Object.entries({ x1: box.left, x2: box.right, y1: criticalY, y2: criticalY }).forEach(([key, value]) => criticalLine.setAttribute(key, value));
        const criticalLabel = document.getElementById("damagePhaseCriticalLabel");
        criticalLabel.setAttribute("x", box.right - 5);
        criticalLabel.setAttribute("y", criticalY - 6);
        criticalLabel.setAttribute("text-anchor", "end");

        function update() {
          const condition = Number(document.getElementById("damagePlantSlider").value);
          const alpha = Number(document.getElementById("damageAlphaSlider").value);
          const closed = document.getElementById("damageLoopModeSwitch").checked;
          const frequencies = osiBodeData.map(row => row[0]);
          const openLive = osiBodeData.map(row => complex(
            alpha * (row[1] + (row[3] - row[1]) * condition),
            alpha * (row[2] + (row[4] - row[2]) * condition)
          ));
          const openReference = osiBodeData.map(row => complex(row[1], row[2]));
          const shownLive = closed ? openLive.map(closedLoop) : openLive;
          const shownReference = closed ? openReference.map(closedLoop) : openReference;
          const liveMagnitude = shownLive.map(magnitudeDb);
          const referenceMagnitude = shownReference.map(magnitudeDb);
          const livePhase = unwrapPhase(shownLive);
          const referencePhase = unwrapPhase(shownReference);
          document.getElementById("damageBodeMagLive").setAttribute("d", pathFrom(frequencies.map((frequency, index) => [xScale(frequency), magnitudeScale(liveMagnitude[index])])));
          document.getElementById("damageBodeMagReference").setAttribute("d", pathFrom(frequencies.map((frequency, index) => [xScale(frequency), magnitudeScale(referenceMagnitude[index])])));
          document.getElementById("damageBodePhaseLive").setAttribute("d", pathFrom(frequencies.map((frequency, index) => [xScale(frequency), phaseScale(livePhase[index])])));
          document.getElementById("damageBodePhaseReference").setAttribute("d", pathFrom(frequencies.map((frequency, index) => [xScale(frequency), phaseScale(referencePhase[index])])));
          const color = liveColor(condition);
          document.getElementById("damageBodeMagLive").style.stroke = color;
          document.getElementById("damageBodePhaseLive").style.stroke = color;
          document.getElementById("damageLiveSwatch").style.background = color;

          const openMagnitude = openLive.map(magnitudeDb);
          const openPhase = unwrapPhase(openLive);
          const gainCross = interpolateCross(frequencies, openMagnitude, 0);
          const phaseCross = interpolateCross(frequencies, openPhase, -180);
          const gainMargin = phaseCross ? -interpolateAt(openMagnitude, phaseCross) : null;
          const phaseMargin = gainCross ? 180 + interpolateAt(openPhase, gainCross) : null;
          document.getElementById("damageGmOut").textContent = gainMargin === null ? "not crossed" : `${gainMargin.toFixed(1)} dB`;
          document.getElementById("damagePmOut").textContent = phaseMargin === null ? "not crossed" : `${phaseMargin.toFixed(1)}°`;

          const gainGroup = document.getElementById("damageGainMarginMark");
          const phaseGroup = document.getElementById("damagePhaseMarginMark");
          clearGroup(gainGroup);
          clearGroup(phaseGroup);
          if (phaseCross) {
            const x = xScale(phaseCross.frequency);
            const curveY = magnitudeScale(interpolateAt(openMagnitude, phaseCross));
            addLine(gainGroup, x, closed ? box.top : curveY, x, closed ? box.bottom : magnitudeScale(0), "damage-bode-margin-guide");
            if (!closed) {
              addMarker(gainGroup, x, curveY);
              addMarker(gainGroup, x, magnitudeScale(0));
            }
            addMarginLabel(gainGroup, x - 7, box.top + 13, `GM ${gainMargin.toFixed(1)} dB`, "end");
          }
          if (gainCross) {
            const x = xScale(gainCross.frequency);
            const curveY = phaseScale(interpolateAt(openPhase, gainCross));
            addLine(phaseGroup, x, closed ? box.top : curveY, x, closed ? box.bottom : criticalY, "damage-bode-margin-guide");
            if (!closed) {
              addMarker(phaseGroup, x, curveY);
              addMarker(phaseGroup, x, criticalY);
            }
            addMarginLabel(phaseGroup, x + 7, box.top + 13, `PM ${phaseMargin.toFixed(1)}°`);
          }

          document.getElementById("damagePlantOut").textContent = conditionLabel(condition);
          document.getElementById("damageAlphaOut").textContent = alpha.toFixed(2);
          document.getElementById("damageLiveLegend").textContent = `live ${conditionLabel(condition)}, α = ${alpha.toFixed(2)}`;
        }

        ["damagePlantSlider", "damageAlphaSlider", "damageLoopModeSwitch"].forEach(id => document.getElementById(id).addEventListener("input", update));
        update();
      }
