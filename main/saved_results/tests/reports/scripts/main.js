"use strict";

import { initAppShell } from "./app-shell.js?v=20260828-1";
import { initHysteresisExplorer } from "./hysteresis-explorer.js?v=20260829-3";
import { initGuidedTour } from "./guided-tour.js?v=20260829-6";

async function fetchJson(path) {
  const response = await fetch(path, { cache: "no-store" });
  if (!response.ok) throw new Error(`Could not load ${path}: ${response.status}`);
  return response.json();
}

async function fetchText(path) {
  const response = await fetch(path, { cache: "no-store" });
  if (!response.ok) throw new Error(`Could not load ${path}: ${response.status}`);
  return response.text();
}

function buildArticleOptions(articles) {
  const list = document.getElementById("articleList");
  list.innerHTML = articles.map((article, index) => `
    <button class="article-option" type="button" data-article-target="${article.id}" aria-pressed="false">
      <span class="article-number">${String(index + 1).padStart(2, "0")}</span>
      <span><strong>${article.label}</strong><span class="article-summary">${article.summary}</span></span>
    </button>
  `).join("");
}

async function start() {
  const mount = document.getElementById("articleMount");

  try {
    const metadataApi = document.body.dataset.reportMetadataApi;
    const metadataPath = document.body.dataset.reportMetadata || "data/report-metadata.json";
    let metadata;
    try {
      metadata = await fetchJson(metadataApi);
    } catch {
      metadata = await fetchJson(metadataPath);
    }
    const config = metadata.report;
    const components = await Promise.all(config.articles.map(article => fetchText(article.component)));

    document.documentElement.style.setProperty("--accent", config.accent);
    document.getElementById("reportBrand").textContent = config.brand;
    document.getElementById("drawerTitle").textContent = config.title;
    buildArticleOptions(config.articles);
    mount.innerHTML = components.join("\n");

    initAppShell(config);
    const explorer = document.getElementById("hysteresisExplorer");
    if (explorer) {
      await initHysteresisExplorer(explorer, metadata);
      initGuidedTour(explorer);
    }
  } catch (error) {
    mount.innerHTML = `<main class="load-error"><h1>Report unavailable</h1><p>${error.message}</p></main>`;
    console.error(error);
  }
}

start();
