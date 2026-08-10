"use strict";

export function initAppShell() {
  const articlePanel = document.getElementById("articlePanel");
  const articlePanelToggle = document.getElementById("articlePanelToggle");
  const articlePanelClose = document.getElementById("articlePanelClose");
  const articlePanelBackdrop = document.getElementById("articlePanelBackdrop");
  const articleLabel = document.getElementById("articleLabel");
  const readingProgress = document.getElementById("readingProgress");
  const articleNames = {
    "article-1": "Evidence map",
    "article-2": "Uncertainty, honestly",
    "article-3": "One-term proposal"
  };

  function setArticlePanel(open) {
    articlePanel.classList.toggle("is-open", open);
    articlePanelBackdrop.classList.toggle("is-open", open);
    document.body.classList.toggle("has-open-panel", open);
    articlePanel.setAttribute("aria-hidden", String(!open));
    articlePanelToggle.setAttribute("aria-expanded", String(open));
    if (open) articlePanelClose.focus();
  }

  function updateReadingProgress() {
    const scrollable = document.documentElement.scrollHeight - window.innerHeight;
    const value = scrollable > 0 ? Math.min(100, Math.max(0, 100 * window.scrollY / scrollable)) : 100;
    readingProgress.style.width = `${value}%`;
    readingProgress.setAttribute("aria-valuenow", String(Math.round(value)));
  }

  function activateArticle(articleId, updateHistory = true) {
    document.querySelectorAll(".report-article").forEach(article => {
      const active = article.id === articleId;
      article.hidden = !active;
      article.classList.toggle("is-active", active);
    });
    document.querySelectorAll(".article-option").forEach(button => {
      const active = button.dataset.articleTarget === articleId;
      button.classList.toggle("is-active", active);
      button.setAttribute("aria-pressed", String(active));
    });
    articleLabel.textContent = articleNames[articleId];
    document.title = `${articleNames[articleId]} · H∞ / ColumnSetup`;
    setArticlePanel(false);
    if (updateHistory) history.replaceState(null, "", `#${articleId}`);
    window.scrollTo({ top: 0, behavior: "smooth" });
    updateReadingProgress();
  }

  articlePanelToggle.addEventListener("click", () => setArticlePanel(!articlePanel.classList.contains("is-open")));
  articlePanelClose.addEventListener("click", () => setArticlePanel(false));
  articlePanelBackdrop.addEventListener("click", () => setArticlePanel(false));
  document.querySelectorAll(".article-option").forEach(button => {
    button.addEventListener("click", () => activateArticle(button.dataset.articleTarget));
  });
  document.addEventListener("keydown", event => {
    if (event.key === "Escape" && articlePanel.classList.contains("is-open")) {
      setArticlePanel(false);
      articlePanelToggle.focus();
    }
  });

  window.addEventListener("scroll", updateReadingProgress, { passive: true });
  window.addEventListener("resize", updateReadingProgress);

  const sectionObserver = new IntersectionObserver(entries => {
    entries.forEach(entry => {
      if (!entry.isIntersecting) return;
      const article = entry.target.closest(".report-article");
      if (!article || !article.classList.contains("is-active")) return;
      article.querySelectorAll(".nav a").forEach(link => {
        link.classList.toggle("is-active", link.getAttribute("href") === `#${entry.target.id}`);
      });
    });
  }, { rootMargin: "-25% 0px -65%", threshold: 0 });
  document.querySelectorAll("main section[id]").forEach(section => sectionObserver.observe(section));

  document.getElementById("printReport").addEventListener("click", () => window.print());
  let initialArticle = "article-1";
  if (location.hash === "#article-2" || location.hash.startsWith("#unc-")) initialArticle = "article-2";
  if (location.hash === "#article-3" || location.hash.startsWith("#idea-")) initialArticle = "article-3";
  activateArticle(initialArticle, false);
  updateReadingProgress();
}

