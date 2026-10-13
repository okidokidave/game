/*
 * 모든 페이지가 함께 쓰는 기능: 저장소, 알림, 설정, 상단 메뉴, 삽화 그리기
 */
const Site = (() => {
  const SETTINGS_KEY = "gamebook:settings";

  // localStorage는 사생활 보호 모드 등에서 실패할 수 있으므로 감싸서 사용
  const storage = {
    get(key, fallback) {
      try {
        const raw = localStorage.getItem(key);
        return raw ? JSON.parse(raw) : fallback;
      } catch {
        return fallback;
      }
    },
    set(key, value) {
      try {
        localStorage.setItem(key, JSON.stringify(value));
      } catch {}
    },
    remove(key) {
      try {
        localStorage.removeItem(key);
      } catch {}
    },
  };

  const $ = (id) => document.getElementById(id);
  const el = (tag, props = {}, children = []) => {
    const node = Object.assign(document.createElement(tag), props);
    node.append(...children);
    return node;
  };

  function toast(message) {
    const t = $("toast");
    t.textContent = message;
    t.hidden = false;
    clearTimeout(toast.timer);
    toast.timer = setTimeout(() => (t.hidden = true), 2400);
  }

  let artId = 0;
  function renderArt(target, image) {
    target.replaceChildren();
    target.hidden = !image;
    if (!image) return;
    if (ILLUSTRATIONS[image]) {
      target.innerHTML = ILLUSTRATIONS[image].replaceAll("__ID__", `art${++artId}`);
      const svg = target.querySelector("svg");
      if (svg && matchMedia("(prefers-reduced-motion: reduce)").matches) svg.pauseAnimations();
    } else {
      target.append(el("img", { src: image, alt: "" }));
    }
  }

  // ───── 설정 (글자 크기, 테마) ─────
  function applySettings() {
    const settings = storage.get(SETTINGS_KEY, { font: "md", theme: "auto" });
    const root = document.documentElement;
    root.dataset.font = settings.font;
    if (settings.theme === "auto") delete root.dataset.theme;
    else root.dataset.theme = settings.theme;

    document.querySelectorAll(".segmented").forEach((group) => {
      group.querySelectorAll("button").forEach((b) => {
        b.classList.toggle("active", b.dataset.value === settings[group.dataset.setting]);
      });
    });
  }

  function bindSettings() {
    document.querySelectorAll(".segmented").forEach((group) => {
      group.addEventListener("click", (e) => {
        const value = e.target.dataset.value;
        if (!value) return;
        const settings = storage.get(SETTINGS_KEY, { font: "md", theme: "auto" });
        storage.set(SETTINGS_KEY, { ...settings, [group.dataset.setting]: value });
        applySettings();
      });
    });
    applySettings();
  }

  // ───── 상단 메뉴 / 다른 콘텐츠 목록 ─────
  function renderNav(current) {
    const nav = $("story-nav");
    if (!nav) return;
    nav.replaceChildren(
      ...SITE_CATALOG.map((c) => {
        const a = el("a", { href: c.href, className: "story-link" }, [
          el("span", { className: "nav-type", textContent: CATALOG_LABELS[c.type] }),
          c.title,
        ]);
        if (`${c.type}:${c.id}` === current) a.setAttribute("aria-current", "page");
        return a;
      })
    );
  }

  function renderMore(target, current) {
    if (!target) return;
    target.replaceChildren(
      ...SITE_CATALOG.filter((c) => `${c.type}:${c.id}` !== current).map((c) =>
        el("a", { href: c.href, className: "more-item" }, [
          el("span", { className: "nav-type", textContent: CATALOG_LABELS[c.type] }),
          el("strong", { textContent: c.title }),
          el("span", { className: "more-desc", textContent: c.desc }),
        ])
      )
    );
  }

  function init({ current }) {
    renderNav(current);
    renderMore($("more-list"), current);
    bindSettings();
    Share.init({ onNotify: toast });
  }

  return { storage, $, el, toast, renderArt, renderNav, renderMore, init };
})();
