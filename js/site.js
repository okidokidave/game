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

    document.querySelectorAll(".segmented[data-setting]").forEach((group) => {
      group.querySelectorAll("button").forEach((b) => {
        b.classList.toggle("active", b.dataset.value === settings[group.dataset.setting]);
      });
    });
  }

  function bindSettings() {
    document.querySelectorAll(".segmented[data-setting]").forEach((group) => {
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
    renderLeft(current);
  }

  // ───── 왼쪽 칸: 이어하기 · 오늘의 맞춤법 · 카테고리 ─────
  function continueItems() {
    const items = [];
    const sd = storage.get("sudoku:current", null);
    if (sd && !sd.done && sd.history?.length) {
      const level = { easy: "쉬움", medium: "보통", hard: "어려움" }[sd.level];
      const t = `${String(Math.floor(sd.elapsed / 60)).padStart(2, "0")}:${String(sd.elapsed % 60).padStart(2, "0")}`;
      items.push({ title: "스도쿠", detail: `${level} · ${t}`, href: "sudoku.html" });
    }
    const cw = storage.get("crossword:progress", {});
    const cwIndex = Object.keys(cw).find((i) => !cw[i].done && Object.keys(cw[i].fills || {}).length);
    if (cwIndex !== undefined) {
      items.push({ title: "십자말풀이", detail: `${Number(cwIndex) + 1}번 문제 풀던 중`, href: "crossword.html" });
    }
    SITE_CATALOG.filter((c) => c.type === "story").forEach((c) => {
      const save = storage.get(`gamebook:${c.id}:save`, null);
      if (save?.history?.length) items.push({ title: c.title, detail: `선택 ${save.history.length}번째`, href: c.href });
    });
    return items;
  }

  function renderLeft(current) {
    const target = $("left-content");
    if (!target) return;
    const sections = [];

    const items = continueItems();
    sections.push(
      el("section", { className: "card rail-card" }, [
        el("h2", { textContent: "이어하기" }),
        ...(items.length
          ? items.map((it) =>
              el("a", { className: "rail-link", href: it.href }, [el("strong", { textContent: it.title }), el("span", { textContent: it.detail })])
            )
          : [el("p", { className: "empty", textContent: "하던 게임이 여기에 나타나요." })]),
      ])
    );

    // 홈 화면은 본문에 오늘의 콘텐츠가 있으므로 왼쪽 칸에서는 생략
    if (typeof Daily !== "undefined" && !$("home")) {
      sections.push(el("section", { className: "card rail-card" }, [el("h2", { textContent: "오늘의 운세" }), Daily.fortuneWidget({ compact: true })]));
      const spelling = Daily.spellingWidget();
      if (spelling) sections.push(el("section", { className: "card rail-card" }, [el("h2", { textContent: "오늘의 맞춤법" }), spelling]));
    }

    const groups = Object.keys(CATALOG_LABELS).filter((t) => SITE_CATALOG.some((c) => c.type === t));
    sections.push(
      el("nav", { className: "card rail-card", ariaLabel: "카테고리" }, [
        el("h2", { textContent: "카테고리" }),
        ...groups.map((t) =>
          el("div", { className: "rail-group" }, [
            el("span", { className: "nav-type", textContent: CATALOG_LABELS[t] }),
            ...SITE_CATALOG.filter((c) => c.type === t).map((c) => {
              const a = el("a", { className: "rail-item", href: c.href, textContent: c.title });
              if (`${c.type}:${c.id}` === current) a.setAttribute("aria-current", "page");
              return a;
            }),
          ])
        ),
      ])
    );
    target.replaceChildren(...sections);
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

  return { storage, $, el, toast, renderArt, renderNav, renderMore, continueItems, init };
})();
