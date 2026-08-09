"use strict";

const svgNamespace = "http://www.w3.org/2000/svg";
let zoomIndex = 0;

function svgNode(name, attributes = {}) {
  const node = document.createElementNS(svgNamespace, name);
  Object.entries(attributes).forEach(([key, value]) => node.setAttribute(key, value));
  return node;
}

export function scaleLinear(value, domain, range) {
  return range[0] + (value - domain[0]) / (domain[1] - domain[0]) * (range[1] - range[0]);
}

export function linearTicks(domain, divisions) {
  return Array.from({ length: divisions + 1 }, (_, index) => domain[0] + index * (domain[1] - domain[0]) / divisions);
}

export function formatAxisTick(value, span) {
  const magnitude = Math.max(Math.abs(value), Math.abs(span));
  if (magnitude >= 100 || span >= 20) return value.toFixed(0);
  if (span >= 2) return value.toFixed(1).replace(/\.0$/, "");
  return value.toFixed(2).replace(/0+$/, "").replace(/\.$/, "");
}

export function attachAxisZoom({ svg, box, xDomain, yDomain, clipElements = [], onChange }) {
  const initial = { x: [...xDomain], y: [...yDomain] };
  let current = { x: [...xDomain], y: [...yDomain] };
  let active = false;
  let start;

  const shell = document.createElement("div");
  shell.className = "axis-zoom-shell";
  svg.before(shell);
  shell.appendChild(svg);

  const toolbar = document.createElement("div");
  toolbar.className = "axis-zoom-toolbar";
  const zoomButton = document.createElement("button");
  zoomButton.type = "button";
  zoomButton.className = "axis-zoom-button";
  zoomButton.setAttribute("aria-label", "Zoom plot axes");
  zoomButton.setAttribute("aria-pressed", "false");
  zoomButton.title = "Zoom axes: drag a rectangle on the plot";
  zoomButton.innerHTML = '<svg viewBox="0 0 20 20" aria-hidden="true"><circle cx="8" cy="8" r="4.75"></circle><path d="m11.5 11.5 5 5"></path><path d="M8 5.5v5M5.5 8h5"></path></svg>';
  const resetButton = document.createElement("button");
  resetButton.type = "button";
  resetButton.className = "axis-zoom-reset";
  resetButton.textContent = "Reset";
  resetButton.hidden = true;
  toolbar.append(zoomButton, resetButton);
  shell.appendChild(toolbar);

  const definitions = svg.querySelector("defs") || svg.insertBefore(svgNode("defs"), svg.firstChild);
  const clipId = `axisZoomClip${zoomIndex += 1}`;
  const clip = svgNode("clipPath", { id: clipId });
  clip.appendChild(svgNode("rect", { x: box.left, y: box.top, width: box.right - box.left, height: box.bottom - box.top }));
  definitions.appendChild(clip);
  clipElements.forEach(element => element?.setAttribute("clip-path", `url(#${clipId})`));

  const selection = svgNode("rect", { class: "axis-zoom-selection", hidden: "" });
  const target = svgNode("rect", {
    x: box.left,
    y: box.top,
    width: box.right - box.left,
    height: box.bottom - box.top,
    class: "axis-zoom-target"
  });
  svg.append(selection, target);

  function plotPoint(event) {
    const point = svg.createSVGPoint();
    point.x = event.clientX;
    point.y = event.clientY;
    const transformed = point.matrixTransform(svg.getScreenCTM().inverse());
    return {
      x: Math.max(box.left, Math.min(box.right, transformed.x)),
      y: Math.max(box.top, Math.min(box.bottom, transformed.y))
    };
  }

  function setActive(value) {
    active = value;
    shell.classList.toggle("is-zooming", active);
    zoomButton.setAttribute("aria-pressed", String(active));
  }

  function redrawSelection(point) {
    const x = Math.min(start.x, point.x);
    const y = Math.min(start.y, point.y);
    selection.setAttribute("x", x);
    selection.setAttribute("y", y);
    selection.setAttribute("width", Math.abs(point.x - start.x));
    selection.setAttribute("height", Math.abs(point.y - start.y));
  }

  function finish(event) {
    if (!start) return;
    const end = plotPoint(event);
    selection.setAttribute("hidden", "");
    target.releasePointerCapture?.(event.pointerId);
    if (Math.abs(end.x - start.x) >= 8 && Math.abs(end.y - start.y) >= 8) {
      const xPixels = [Math.min(start.x, end.x), Math.max(start.x, end.x)];
      const yPixels = [Math.max(start.y, end.y), Math.min(start.y, end.y)];
      current = {
        x: xPixels.map(value => scaleLinear(value, [box.left, box.right], current.x)),
        y: yPixels.map(value => scaleLinear(value, [box.bottom, box.top], current.y))
      };
      resetButton.hidden = false;
      onChange([...current.x], [...current.y]);
    }
    start = undefined;
  }

  zoomButton.addEventListener("click", () => setActive(!active));
  resetButton.addEventListener("click", () => {
    current = { x: [...initial.x], y: [...initial.y] };
    resetButton.hidden = true;
    onChange([...current.x], [...current.y]);
  });
  target.addEventListener("pointerdown", event => {
    if (!active) return;
    start = plotPoint(event);
    selection.removeAttribute("hidden");
    redrawSelection(start);
    target.setPointerCapture?.(event.pointerId);
    event.preventDefault();
  });
  target.addEventListener("pointermove", event => {
    if (start) redrawSelection(plotPoint(event));
  });
  target.addEventListener("pointerup", finish);
  target.addEventListener("pointercancel", finish);
  shell.addEventListener("keydown", event => {
    if (event.key === "Escape") setActive(false);
  });
}
