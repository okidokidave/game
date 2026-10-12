(() => {
  const STORIES = window.STORIES || [];
  const SETTINGS_KEY = "gamebook:settings";
  const ENDING_LABELS = { true: "진 엔딩", good: "해피 엔딩", normal: "노멀 엔딩", bad: "배드 엔딩" };

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

  // 현재 이야기 — 주소의 #아이디로 고름 (예: index.html#mansion)
  let STORY, KEYS, allEndings, sceneCount;

  // state: { scene, items, history: [{ scene, items, label }] }
  let state = null;
  let newEnding = null;
  let artId = 0;

  function loadStory() {
    const id = location.hash.slice(1);
    STORY = STORIES.find((s) => s.id === id) || STORIES[0];
    KEYS = {
      save: `gamebook:${STORY.id}:save`,
      endings: `gamebook:${STORY.id}:endings`,
      stats: `gamebook:${STORY.id}:stats`,
    };
    allEndings = Object.entries(STORY.scenes).filter(([, s]) => s.ending);
    sceneCount = Object.keys(STORY.scenes).length;
    renderNav();
    renderTitle();
  }

  function renderNav() {
    const links = STORIES.map((s) => {
      const a = el("a", { href: `#${s.id}`, className: "story-link", textContent: s.title });
      if (s === STORY) a.setAttribute("aria-current", "page");
      return a;
    });
    links.push(el("span", { className: "story-link soon", textContent: "새 이야기 준비 중" }));
    $("story-nav").replaceChildren(...links);
  }

  const getStats = () => storage.get(KEYS.stats, { plays: 0, visited: [] });

  function show(screenId) {
    ["title-screen", "game-screen"].forEach((id) => ($(id).hidden = id !== screenId));
    window.scrollTo(0, 0);
  }

  function toast(message) {
    const t = $("toast");
    t.textContent = message;
    t.hidden = false;
    clearTimeout(toast.timer);
    toast.timer = setTimeout(() => (t.hidden = true), 2000);
  }

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

  // ───── 타이틀 ─────
  function renderTitle() {
    state = null;
    document.title = STORY.title;
    $("story-title").textContent = STORY.title;
    $("story-intro").textContent = STORY.intro;
    renderArt($("title-art"), STORY.cover);

    const save = storage.get(KEYS.save, null);
    $("btn-continue").hidden = !(save && STORY.scenes[save.scene]);
    renderSidebar();
    show("title-screen");
  }

  // ───── 게임 ─────
  function startNew() {
    const stats = getStats();
    storage.set(KEYS.stats, { ...stats, plays: stats.plays + 1 });
    state = { scene: STORY.start, items: [], history: [] };
    goTo(STORY.start);
  }

  function continueGame() {
    state = storage.get(KEYS.save, null);
    state.history = state.history || [];
    renderScene();
  }

  function choose(choice) {
    state.history.push({ scene: state.scene, items: [...state.items], label: choice.label });
    goTo(choice.next);
  }

  function undo() {
    if (!state || state.history.length === 0) return;
    const prev = state.history.pop();
    state.scene = prev.scene;
    state.items = prev.items;
    storage.set(KEYS.save, state);
    renderScene();
  }

  function goTo(sceneId) {
    const scene = STORY.scenes[sceneId];
    if (!scene) {
      console.error(`존재하지 않는 장면: ${sceneId}`);
      return;
    }
    state.scene = sceneId;

    const gained = (scene.gives || []).filter((i) => !state.items.includes(i));
    state.items.push(...gained);

    const stats = getStats();
    if (!stats.visited.includes(sceneId)) {
      storage.set(KEYS.stats, { ...stats, visited: [...stats.visited, sceneId] });
    }

    newEnding = null;
    if (scene.ending) {
      const seen = storage.get(KEYS.endings, []);
      if (!seen.includes(sceneId)) {
        storage.set(KEYS.endings, [...seen, sceneId]);
        newEnding = sceneId;
      }
      storage.remove(KEYS.save);
    } else {
      storage.set(KEYS.save, state);
    }

    renderScene(gained);
    if (newEnding) toast(`새 엔딩 발견! 「${scene.ending.title}」`);
  }

  function isVisible(choice) {
    const has = (i) => state.items.includes(i);
    return (choice.requires || []).every(has) && !(choice.excludes || []).some(has);
  }

  function renderScene(gained = []) {
    const scene = STORY.scenes[state.scene];

    renderArt($("scene-art"), scene.image);

    const badge = $("ending-badge");
    badge.hidden = !scene.ending;
    if (scene.ending) {
      badge.textContent = `${ENDING_LABELS[scene.ending.type] || "엔딩"} · ${scene.ending.title}`;
      badge.dataset.type = scene.ending.type;
    }

    $("scene-text").replaceChildren(...scene.text.map((para) => el("p", { textContent: para })));

    const gain = $("scene-gain");
    gain.hidden = gained.length === 0;
    gain.textContent = `획득: ${gained.join(", ")}`;

    const choices = scene.ending
      ? [
          { label: "처음부터 다시", action: startNew },
          { label: "타이틀로", action: renderTitle },
        ]
      : scene.choices.filter(isVisible).map((c) => ({ label: c.label, action: () => choose(c) }));

    $("choices").replaceChildren(
      ...choices.map((c) => {
        const btn = el("button", { className: "choice", textContent: c.label });
        btn.addEventListener("click", c.action);
        return btn;
      })
    );

    $("btn-undo-top").hidden = state.history.length === 0;

    const article = $("scene");
    article.classList.remove("enter");
    void article.offsetWidth;
    article.classList.add("enter");

    renderSidebar();
    show("game-screen");
  }

  // ───── 사이드바 ─────
  function renderSidebar() {
    // 소지품
    const items = state ? state.items : [];
    $("side-inventory").replaceChildren(
      ...(items.length
        ? items.map((i) => el("span", { className: "item", textContent: i }))
        : [el("p", { className: "empty", textContent: "아직 아무것도 없다." })])
    );

    // 엔딩 도감
    const seen = storage.get(KEYS.endings, []);
    $("ending-count").textContent = `${seen.length}/${allEndings.length}`;
    $("ending-bar").style.width = `${(seen.length / allEndings.length) * 100}%`;
    $("endings-list").replaceChildren(
      ...allEndings.map(([id, scene], idx) => {
        const { title, type, hint } = scene.ending;
        const unlocked = seen.includes(id);
        const li = el("li", { className: unlocked ? "unlocked" : "locked" });
        li.dataset.type = type;
        if (id === newEnding) li.classList.add("new");

        const name = el("span", {
          className: "ending-name",
          textContent: `${idx + 1}. ${unlocked ? title : "???"}`,
        });
        const tag = el("span", { className: "ending-type", textContent: unlocked ? ENDING_LABELS[type] : "" });
        li.append(el("div", { className: "ending-row" }, [name, tag]));

        if (!unlocked && hint) {
          const hintText = el("p", { className: "hint", textContent: hint, hidden: true });
          const btn = el("button", { className: "hint-btn", textContent: "힌트" });
          btn.addEventListener("click", () => {
            hintText.hidden = !hintText.hidden;
            btn.textContent = hintText.hidden ? "힌트" : "닫기";
          });
          li.querySelector(".ending-row").append(btn);
          li.append(hintText);
        }
        return li;
      })
    );

    // 진행 현황
    const stats = getStats();
    $("stat-explore").textContent = `${Math.round((stats.visited.length / sceneCount) * 100)}% (${stats.visited.length}/${sceneCount})`;
    $("stat-plays").textContent = `${stats.plays}회`;
    $("stat-steps").textContent = state ? `${state.history.length}번` : "-";

    // 지나온 길
    const history = state ? state.history : [];
    $("history-list").replaceChildren(
      ...(history.length
        ? history.map((h) => el("li", { textContent: h.label }))
        : [el("li", { className: "empty", textContent: "아직 선택한 길이 없다." })])
    );
    $("btn-undo").disabled = history.length === 0;
  }

  // ───── 설정 ─────
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

  document.querySelectorAll(".segmented").forEach((group) => {
    group.addEventListener("click", (e) => {
      const value = e.target.dataset.value;
      if (!value) return;
      const settings = storage.get(SETTINGS_KEY, { font: "md", theme: "auto" });
      storage.set(SETTINGS_KEY, { ...settings, [group.dataset.setting]: value });
      applySettings();
    });
  });

  async function share() {
    const seen = storage.get(KEYS.endings, []).length;
    const text = `「${STORY.title}」에서 엔딩 ${seen}/${allEndings.length}개를 찾았어요! 당신은 몇 개나 찾을 수 있을까요?`;
    const url = `${location.href.split("#")[0]}#${STORY.id}`;
    try {
      if (navigator.share) {
        await navigator.share({ title: STORY.title, text, url });
        return;
      }
      await navigator.clipboard.writeText(`${text}\n${url}`);
      toast("링크를 복사했어요");
    } catch (e) {
      if (e.name !== "AbortError") toast("공유하지 못했어요");
    }
  }

  function resetAll() {
    if (!confirm(`「${STORY.title}」의 엔딩 도감, 진행 현황, 저장된 게임을 모두 지울까요?`)) return;
    [KEYS.save, KEYS.endings, KEYS.stats].forEach(storage.remove);
    renderTitle();
    toast("기록을 초기화했어요");
  }

  // ───── 이벤트 ─────
  $("btn-new").addEventListener("click", startNew);
  $("btn-continue").addEventListener("click", continueGame);
  $("btn-home").addEventListener("click", renderTitle);
  $("btn-undo").addEventListener("click", undo);
  $("btn-undo-top").addEventListener("click", undo);
  $("btn-share").addEventListener("click", share);
  $("btn-reset").addEventListener("click", resetAll);

  window.addEventListener("hashchange", loadStory);

  applySettings();
  loadStory();
})();
