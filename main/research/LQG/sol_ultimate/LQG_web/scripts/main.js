"use strict";

import { initAppShell } from "./app-shell.js";
import { initDamageBodeExplorer } from "./damage-bode.js";
import { initReportCharts } from "./report-charts.js";

const componentPaths = [
  "components/article-pressure-lqgi.html",
  "components/article-damage-ensemble.html"
];

async function loadComponent(path) {
  const response = await fetch(path);
  if (!response.ok) throw new Error(`Could not load ${path}: ${response.status}`);
  return response.text();
}

async function start() {
  const mount = document.getElementById("articleMount");

  try {
    const components = await Promise.all(componentPaths.map(loadComponent));
    mount.innerHTML = components.join("\n");
    initDamageBodeExplorer(window.SOL_OSI_BODE_DATA);

    if (window.SOL_ULTIMATE_PLOT_DATA) {
      initReportCharts(window.SOL_ULTIMATE_PLOT_DATA);
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
