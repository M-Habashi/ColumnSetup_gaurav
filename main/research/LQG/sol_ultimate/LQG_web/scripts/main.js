"use strict";

import { initAppShell } from "./app-shell.js";
import { initDamageBodeExplorer } from "./damage-bode.js?v=20260806-10";
import { initReportCharts } from "./report-charts.js?v=20260806-6";
import { initTrackingBode } from "./tracking-bode.js?v=20260806-10";
import { initLqriBode } from "./lqri-bode.js?v=20260806-10";

const contentRevision = "20260806-11";

const componentPaths = [
  "components/article-pressure-lqgi.html",
  "components/article-damage-ensemble.html"
];

async function loadComponent(path) {
  const response = await fetch(`${path}?v=${contentRevision}`, { cache: "no-store" });
  if (!response.ok) throw new Error(`Could not load ${path}: ${response.status}`);
  return response.text();
}

async function start() {
  const mount = document.getElementById("articleMount");

  try {
    const components = await Promise.all(componentPaths.map(loadComponent));
    mount.innerHTML = components.join("\n");
    document.getElementById("lqrDesignMount").innerHTML = await loadComponent("components/lqr-design.html");
    document.getElementById("trackingBodeMount").innerHTML = await loadComponent("components/steady-state-tracking.html");
    document.getElementById("lqriDesignMount").innerHTML = await loadComponent("components/lqri-design.html");
    document.getElementById("lqriTrackingBodeMount").innerHTML = await loadComponent("components/lqri-tracking.html");
    initDamageBodeExplorer(window.SOL_OSI_BODE_DATA, window.SOL_ULTIMATE_PLOT_DATA);

    if (window.SOL_ULTIMATE_PLOT_DATA) {
      initReportCharts(window.SOL_ULTIMATE_PLOT_DATA);
      initTrackingBode(window.SOL_ULTIMATE_PLOT_DATA);
      initLqriBode(window.SOL_ULTIMATE_PLOT_DATA);
    } else {
      document.getElementById("responses").innerHTML = "<p>Plot data could not be loaded. Run generate_html_report_data.m.</p>";
    }

    initAppShell();
  } catch (error) {
    mount.innerHTML = `<main class="load-error"><h1>Report unavailable</h1><p>${error.message}</p></main>`;
    console.error(error);
  }
}

start();
