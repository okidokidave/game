(() => {
  const SAVE_KEY = "gamebook:save";
  const ENDINGS_KEY = "gamebook:endings";

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
  const screens = ["title-screen", "game-screen", "endings-screen"];

  let state = null; // { scene, items }

  function show(screenId) {
    screens.forEach((id) => ($(id).hidden = id !== screenId));
    window.scrollTo(0, 0);
  }

  const allEndings = () =>
    Object.entries(STORY.scenes).filter(([, s]) => s.ending);

  // ───── 타이틀 ─────
  function renderTitle() {
    document.title = STORY.title;
    $("story-title").textContent = STORY.title;
    $("story-intro").textContent = STORY.intro;

    const save = storage.get(SAVE_KEY, null);
    $("btn-continue").hidden = !(save && STORY.scenes[save.scene]);

    const seen = storage.get(ENDINGS_KEY, []);
    $("ending-count").textContent = `${seen.length}/${allEndings().length}`;
    show("title-screen");
  }

  // ───── 게임 ─────
  function startNew() {
    state = { scene: STORY.start, items: [] };
    goTo(STORY.start);
  }

  function continueGame() {
    state = storage.get(SAVE_KEY, null);
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

    if (scene.ending) {
      const seen = storage.get(ENDINGS_KEY, []);
      if (!seen.includes(sceneId)) storage.set(ENDINGS_KEY, [...seen, sceneId]);
      storage.remove(SAVE_KEY);
    } else {
      storage.set(SAVE_KEY, state);
    }

    renderScene(gained);
  }

  function isVisible(choice) {
    const has = (i) => state.items.includes(i);
    return (choice.requires || []).every(has) && !(choice.excludes || []).some(has);
  }

  function renderScene(gained = []) {
    const scene = STORY.scenes[state.scene];

    // 인벤토리
    const inv = $("inventory");
    inv.replaceChildren(
      ...state.items.map((item) => {
        const el = document.createElement("span");
        el.className = "item";
        el.textContent = item;
        return el;
      })
    );

    // 엔딩 배지
    const badge = $("ending-badge");
    if (scene.ending) {
      const labels = { good: "진 엔딩", normal: "노멀 엔딩", bad: "배드 엔딩" };
      badge.textContent = `${labels[scene.ending.type] || "엔딩"} · ${scene.ending.title}`;
      badge.dataset.type = scene.ending.type;
      badge.hidden = false;
    } else {
      badge.hidden = true;
    }

    // 본문
    $("scene-text").replaceChildren(
      ...scene.text.map((para) => {
        const p = document.createElement("p");
        p.textContent = para;
        return p;
      })
    );

    const gain = $("scene-gain");
    gain.hidden = gained.length === 0;
    gain.textContent = `획득: ${gained.join(", ")}`;

    // 선택지
    const choices = scene.ending
      ? [
          { label: "처음부터 다시", action: startNew },
          { label: "엔딩 도감 보기", action: renderEndings },
        ]
      : scene.choices.filter(isVisible).map((c) => ({ label: c.label, action: () => goTo(c.next) }));

    $("choices").replaceChildren(
      ...choices.map((c) => {
        const btn = document.createElement("button");
        btn.className = "choice";
        btn.textContent = c.label;
        btn.addEventListener("click", c.action);
        return btn;
      })
    );

    // 장면 전환 애니메이션
    const article = $("scene");
    article.classList.remove("enter");
    void article.offsetWidth;
    article.classList.add("enter");

    show("game-screen");
  }

  // ───── 엔딩 도감 ─────
  function renderEndings() {
    const seen = storage.get(ENDINGS_KEY, []);
    $("endings-list").replaceChildren(
      ...allEndings().map(([id, scene], idx) => {
        const li = document.createElement("li");
        const unlocked = seen.includes(id);
        li.className = unlocked ? "unlocked" : "locked";
        li.dataset.type = scene.ending.type;
        li.textContent = `${idx + 1}. ${unlocked ? scene.ending.title : "???"}`;
        return li;
      })
    );
    show("endings-screen");
  }

  // ───── 이벤트 ─────
  $("btn-new").addEventListener("click", startNew);
  $("btn-continue").addEventListener("click", continueGame);
  $("btn-endings").addEventListener("click", renderEndings);
  $("btn-home").addEventListener("click", renderTitle);
  $("btn-endings-back").addEventListener("click", renderTitle);

  renderTitle();
})();
