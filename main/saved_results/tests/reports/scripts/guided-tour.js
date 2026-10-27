"use strict";

import { driver } from "./vendor/driver.js.mjs";

const TOUR_SEEN_KEY = "rths-hysteresis-tour-seen";

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, character => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#039;"
  })[character]);
}

function rowForPath(container, path) {
  return container.querySelector(rowSelector(path));
}

function rowSelector(path) {
  return `.tree-file[data-path="${CSS.escape(path)}"]`;
}

function colorSelector(path) {
  return `#selectedDetails .series-color-picker[data-path="${CSS.escape(path)}"]`;
}

function waitForColorPicker(container, path) {
  const selector = colorSelector(path);
  if (container.querySelector(selector)) return Promise.resolve(true);

  return new Promise(resolve => {
    const observer = new MutationObserver(() => {
      if (!container.querySelector(selector)) return;
      observer.disconnect();
      resolve(true);
    });
    observer.observe(container.querySelector("#selectedDetails"), { childList: true });
    setTimeout(() => {
      observer.disconnect();
      resolve(false);
    }, 15000);
  });
}

function tourFile(folder) {
  const rows = [...folder.querySelectorAll(".tree-file")]
    .filter(row => !row.querySelector('input[type="checkbox"]').disabled);
  return rows[0];
}

function fileStep(container, path, folderName) {
  const checkbox = () => rowForPath(container, path).querySelector('input[type="checkbox"]');
  const selected = checkbox().checked;
  let listener = null;
  let advancing = false;
  const advance = async activeTour => {
    if (advancing) return;
    advancing = true;
    if (!checkbox().checked) checkbox().click();
    if (await waitForColorPicker(container, path)) {
      requestAnimationFrame(() => requestAnimationFrame(() => activeTour.moveNext()));
    }
    advancing = false;
  };
  return {
    element: `${rowSelector(path)} .tree-file-select`,
    advanceOnClick: false,
    onHighlighted: (_element, _step, { driver: activeTour }) => {
      listener = new AbortController();
      checkbox().addEventListener("change", event => {
        if (event.target.checked) advance(activeTour);
      }, { signal: listener.signal });
    },
    onDeselected: () => listener?.abort(),
    popover: {
      onNextClick: (_element, _step, { driver: activeTour }) => advance(activeTour),
      title: `Select a file from ${escapeHtml(folderName)}`,
      description: selected
        ? "This test is already selected."
        : "Tap this file to add it to the comparison, or press Next to add it for you.",
      side: "right",
      align: "start",
      showButtons: ["next", "close"]
    }
  };
}

export function initGuidedTour(container) {
  const launcher = document.getElementById("tourLauncher");

  const startTour = () => {
    localStorage.setItem(TOUR_SEEN_KEY, "true");
    document.querySelector(`.article-option[data-article-target="${container.closest(".report-article").id}"]`)?.click();
    const search = container.querySelector("#fileSearch");
    search.value = "";
    search.dispatchEvent(new Event("input", { bubbles: true }));

    const folders = [...container.querySelectorAll("#fileTree > .tree-folder")].slice(0, 2);
    folders.forEach(folder => { folder.open = true; });
    const rows = folders.map(tourFile);
    const paths = rows.map(row => row.dataset.path);
    const names = folders.map(folder => folder.querySelector(":scope > summary span:nth-child(2)").textContent.trim());
    const forceAxis = container.querySelector("#hysteresisPlot .ytitle");
    if (forceAxis?.textContent.includes("(kip)")) {
      forceAxis.dispatchEvent(new MouseEvent("click", { bubbles: true }));
    }

    const tour = driver({
      animate: true,
      duration: 180,
      smoothScroll: true,
      allowClose: true,
      allowScroll: true,
      overlayClickBehavior: () => {},
      overlayColor: "#000000",
      overlayOpacity: 0.72,
      stagePadding: 6,
      stageRadius: 8,
      popoverClass: "rths-tour",
      showProgress: true,
      progressText: "{{current}} / {{total}}",
      nextBtnText: "Next",
      doneBtnText: "Done",
      steps: [
        {
          element: launcher,
          popover: {
            title: "Hysteresis explorer tour",
            description: "Follow the highlighted controls to compare two tests, change presentation settings, adjust the time window, and export a file.",
            side: "bottom",
            align: "end",
            showButtons: ["next", "close"]
          }
        },
        fileStep(container, paths[1], names[1]),
        {
          element: colorSelector(paths[0]),
          waitForElement: 8000,
          popover: {
            title: "Change a trace color",
            description: "Click the colored strip on the left edge of this test and choose a new trace color.",
            side: "left",
            align: "start",
            showButtons: ["next", "close"]
          }
        },
        {
          element: "#hysteresisPlot .ytitle",
          waitForElement: 8000,
          advanceOnClick: true,
          popover: {
            popoverClass: "rths-tour force-unit-tour",
            title: "Convert force to kips",
            description: "Click the force-axis title to switch the plotted force from kN to kip.",
            side: "right",
            align: "center",
            showButtons: ["close"]
          }
        },
        {
          element: ".time-control",
          popover: {
            title: "Adjust earthquake time",
            description: "Drag either time handle to focus the plot on a smaller earthquake-time window.",
            side: "top",
            align: "center",
            showButtons: ["next", "close"]
          }
        },
        {
          element: `${rowSelector(paths[1])} .file-download`,
          advanceOnClick: true,
          onHighlighted: (element, _step, { driver: activeTour }) => {
            element.addEventListener("click", () => activeTour.destroy(), { once: true });
          },
          popover: {
            title: "Download the test",
            description: "Click XLSX beside the file to download it and finish the tour.",
            side: "right",
            align: "center",
            showButtons: ["close"]
          }
        }
      ]
    });

    tour.drive();
  };

  launcher.addEventListener("click", startTour);
  if (!localStorage.getItem(TOUR_SEEN_KEY)) requestAnimationFrame(startTour);
}
