"use strict";

export function initAppShell(config) {
  const panel = document.getElementById("articlePanel");
  const toggle = document.getElementById("articlePanelToggle");
  const close = document.getElementById("articlePanelClose");
  const backdrop = document.getElementById("articlePanelBackdrop");
  const articleLabel = document.getElementById("articleLabel");
  const progress = document.getElementById("readingProgress");
  const articleNames = new Map(config.articles.map(article => [article.id, article.label]));

  function setPanel(open) {
    panel.classList.toggle("is-open", open);
    backdrop.classList.toggle("is-open", open);
    document.body.classList.toggle("has-open-panel", open);
    panel.setAttribute("aria-hidden", String(!open));
    toggle.setAttribute("aria-expanded", String(open));
    if (open) close.focus();
  }

  function updateProgress() {
    const scrollable = document.documentElement.scrollHeight - window.innerHeight;
    const value = scrollable > 0 ? Math.min(100, Math.max(0, 100 * window.scrollY / scrollable)) : 100;
    progress.style.width = `${value}%`;
    progress.setAttribute("aria-valuenow", String(Math.round(value)));
  }

  function articleForHash(hash) {
    const direct = articleNames.has(hash.slice(1)) ? hash.slice(1) : null;
    if (direct) return direct;
    const section = hash.length > 1 ? document.getElementById(hash.slice(1)) : null;
    return section?.closest(".report-article")?.id || config.articles[0].id;
  }

  function activateArticle(articleId, nextHash = null) {
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
    articleLabel.textContent = articleNames.get(articleId);
    document.title = `${articleNames.get(articleId)} · ${config.title}`;
    setPanel(false);
    history.replaceState(null, "", nextHash || `#${articleId}`);
    const target = nextHash && nextHash !== `#${articleId}` ? document.querySelector(nextHash) : null;
    if (target) target.scrollIntoView({ behavior: "smooth", block: "start" });
    else window.scrollTo({ top: 0, behavior: "smooth" });
    updateProgress();
  }

  toggle.addEventListener("click", () => setPanel(!panel.classList.contains("is-open")));
  close.addEventListener("click", () => setPanel(false));
  backdrop.addEventListener("click", () => setPanel(false));
  document.querySelectorAll(".article-option").forEach(button => {
    button.addEventListener("click", () => activateArticle(button.dataset.articleTarget));
  });
  document.addEventListener("keydown", event => {
    if (event.key === "Escape" && panel.classList.contains("is-open")) {
      setPanel(false);
      toggle.focus();
    }
  });

  window.addEventListener("scroll", updateProgress, { passive: true });
  window.addEventListener("resize", updateProgress);

  const revealObserver = new IntersectionObserver(entries => {
    entries.forEach(entry => {
      if (entry.isIntersecting) entry.target.classList.add("is-visible");
    });
  }, { threshold: 0.08 });
  document.querySelectorAll(".reveal").forEach(element => revealObserver.observe(element));

  const sectionObserver = new IntersectionObserver(entries => {
    entries.forEach(entry => {
      if (!entry.isIntersecting) return;
      const article = entry.target.closest(".report-article");
      if (!article?.classList.contains("is-active")) return;
      article.querySelectorAll(".nav a").forEach(link => {
        link.classList.toggle("is-active", link.getAttribute("href") === `#${entry.target.id}`);
      });
    });
  }, { rootMargin: "-25% 0px -65%", threshold: 0 });
  document.querySelectorAll("main section[id]").forEach(section => sectionObserver.observe(section));

  document.querySelectorAll(".nav a").forEach(link => {
    link.addEventListener("click", event => {
      const hash = link.getAttribute("href");
      const articleId = link.closest(".report-article").id;
      if (!link.closest(".report-article").classList.contains("is-active")) {
        event.preventDefault();
        activateArticle(articleId, hash);
      }
    });
  });

  document.getElementById("printReport").addEventListener("click", () => window.print());
  const initialHash = location.hash || `#${config.articles[0].id}`;
  activateArticle(articleForHash(initialHash), initialHash);
  updateProgress();
}

