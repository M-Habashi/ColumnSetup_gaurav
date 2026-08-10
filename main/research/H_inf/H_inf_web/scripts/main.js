"use strict";

import { initAppShell } from "./app-shell.js";

const componentPaths = [
  "components/article-evidence.html",
  "components/article-uncertainty.html",
  "components/article-novelty.html"
];

async function loadComponent(path) {
  const response = await fetch(path, { cache: "no-store" });
  if (!response.ok) throw new Error(`Could not load ${path}: ${response.status}`);
  return response.text();
}

async function start() {
  const mount = document.getElementById("articleMount");

  try {
    const components = await Promise.all(componentPaths.map(loadComponent));
    mount.innerHTML = components.join("\n");
    initAppShell();
  } catch (error) {
    mount.innerHTML = `<main class="load-error"><h1>Report unavailable</h1><p>${error.message}</p></main>`;
    console.error(error);
  }
}

start();

