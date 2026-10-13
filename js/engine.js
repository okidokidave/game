(() => {
  const STORIES = window.STORIES || [];
  const ENDING_LABELS = { true: "진 엔딩", good: "해피 엔딩", normal: "노멀 엔딩", bad: "배드 엔딩" };
  const { storage, $, el, toast, renderArt } = Site;

  // 현재 이야기 — 주소의 #아이디로 고름 (예: index.html#mansion)
  let STORY, KEYS, allEndings, sceneCount;

  // state: { scene, items, time, history: [{ scene, items, time, label }] }
  // time: 이야기 시작 후 흐른 시간(분). 이야기에 clock이 있을 때만 사용
  let state = null;
  let newEnding = null;

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
    Site.renderNav(`story:${STORY.id}`);
    Site.renderMore($("more-list"), `story:${STORY.id}`);
    renderTitle();
  }

  // ───── 시계 (시간 압박) ─────
  // STORY.clock = { start: 시작 시각(분), limit: 제한 시간(분), cost: 선택지 기본 소요 시간, timeout: 시간 초과 시 장면 }
  // 선택지에 time: n 을 적으면 그 선택지는 n분이 걸립니다.
  const formatTime = (elapsed) => {
    const t = (STORY.clock.start + elapsed) % (24 * 60);
    return `${String(Math.floor(t / 60)).padStart(2, "0")}:${String(t % 60).padStart(2, "0")}`;
  };
  const costOf = (choice) => choice.time ?? STORY.clock.cost;

  function renderClock(scene) {
    const clock = $("clock");
    clock.hidden = !STORY.clock || !!scene.ending;
    if (clock.hidden) return;
    const left = Math.max(0, STORY.clock.limit - state.time);
    clock.textContent = `🕰 ${formatTime(state.time)} · 자정까지 ${left}분`;
    clock.classList.toggle("warn", left <= 10);
  }

  const getStats = () => storage.get(KEYS.stats, { plays: 0, visited: [] });

  function show(screenId) {
    ["title-screen", "game-screen"].forEach((id) => ($(id).hidden = id !== screenId));
    window.scrollTo(0, 0);
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
    state = { scene: STORY.start, items: [], time: 0, history: [] };
    goTo(STORY.start);
  }

  function continueGame() {
    state = storage.get(KEYS.save, null);
    state.history = state.history || [];
    state.time = state.time || 0;
    renderScene();
  }

  function choose(choice) {
    state.history.push({ scene: state.scene, items: [...state.items], time: state.time, label: choice.label });
    if (STORY.clock) {
      state.time += costOf(choice);
      // 자정이 지나면 엔딩으로 가는 선택이 아닌 한 시간 초과 장면으로
      if (state.time >= STORY.clock.limit && !STORY.scenes[choice.next].ending) {
        goTo(STORY.clock.timeout);
        return;
      }
    }
    goTo(choice.next);
  }

  function undo() {
    if (!state || state.history.length === 0) return;
    const prev = state.history.pop();
    state.scene = prev.scene;
    state.items = prev.items;
    state.time = prev.time || 0;
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

    // "> "로 시작하는 문단은 메시지·쪽지처럼 표시
    $("scene-text").replaceChildren(
      ...scene.text.map((para) =>
        para.startsWith("> ")
          ? el("p", { className: "note", textContent: para.slice(2) })
          : el("p", { textContent: para })
      )
    );

    const gain = $("scene-gain");
    gain.hidden = gained.length === 0;
    gain.textContent = `획득: ${gained.join(", ")}`;

    const choices = scene.ending
      ? [
          { label: "이 엔딩 공유하기", action: () => share(scene.ending) },
          { label: "처음부터 다시", action: startNew },
          { label: "타이틀로", action: renderTitle },
        ]
      : scene.choices.filter(isVisible).map((c) => ({
          label: c.label,
          cost: STORY.clock ? costOf(c) : null,
          action: () => choose(c),
        }));

    $("choices").replaceChildren(
      ...choices.map((c) => {
        const btn = el("button", { className: "choice" }, [el("span", { textContent: c.label })]);
        if (c.cost) btn.append(el("span", { className: "cost", textContent: `${c.cost}분` }));
        btn.addEventListener("click", c.action);
        return btn;
      })
    );

    renderClock(scene);

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

  function share(ending) {
    const seen = storage.get(KEYS.endings, []).length;
    const text = ending
      ? `「${STORY.title}」에서 「${ending.title}」 엔딩을 봤어요! (${seen}/${allEndings.length}) 당신은 어떤 결말을 맞이할까요?`
      : `「${STORY.title}」에서 엔딩 ${seen}/${allEndings.length}개를 찾았어요! 당신은 몇 개나 찾을 수 있을까요?`;
    Share.open({ title: STORY.title, text, path: `#${STORY.id}` });
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
  $("btn-share").addEventListener("click", () => share());
  $("btn-reset").addEventListener("click", resetAll);

  window.addEventListener("hashchange", loadStory);

  // 모바일에서는 긴 엔딩 도감을 접은 채로 시작
  if (matchMedia("(max-width: 860px)").matches) $("endings-card").open = false;

  Site.init({ current: "" });
  loadStory();
})();
