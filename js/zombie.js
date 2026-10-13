(() => {
  const { storage, $, el, toast } = Site;
  const C = ZombieCore;
  const D = C.D;
  const SAVE_KEY = "zombie:save";
  const ENDINGS_KEY = "zombie:endings";
  const RECORD_KEY = "zombie:records";
  const TYPE_LABELS = { true: "진 엔딩", good: "해피 엔딩", normal: "노멀 엔딩", bad: "배드 엔딩" };

  let s = null; // 게임 상태
  let job = "doctor";
  let newEnding = null;

  const today = () => Math.floor((Date.now() - new Date().getTimezoneOffset() * 60000) / 86400000);
  const save = () => (s && !s.ending ? storage.set(SAVE_KEY, s) : storage.remove(SAVE_KEY));

  function show(id) {
    ["zb-intro", "zb-game"].forEach((x) => ($(x).hidden = x !== id));
    window.scrollTo(0, 0);
  }

  // ───── 시작 화면 ─────
  function renderIntro() {
    s = null;
    const saved = storage.get(SAVE_KEY, null);
    $("zb-continue").hidden = !saved;
    if (saved) $("zb-continue").textContent = `이어하기 (${saved.day}일째 · ${D.locations[saved.loc].name})`;

    $("zb-jobs").replaceChildren(
      ...Object.entries(D.jobs).map(([id, j]) => {
        const b = el("button", { type: "button", className: "zb-job" }, [
          el("span", { className: "zb-job-icon", textContent: j.icon }),
          el("strong", { textContent: j.name }),
          el("small", { textContent: j.desc }),
        ]);
        b.classList.toggle("active", id === job);
        b.addEventListener("click", () => {
          job = id;
          renderIntro();
        });
        return b;
      })
    );

    const rec = storage.get(RECORD_KEY, {});
    const daily = rec.daily?.day === today() ? rec.daily : null;
    $("zb-daily-note").textContent = daily
      ? `오늘의 기록: ${daily.best}일 생존${daily.rescued ? " · 구조 성공 🚁" : ""}`
      : "모두에게 같은 사건이 같은 순서로 일어나요. 친구와 비교해 보세요!";
    renderSide();
    show("zb-intro");
  }

  function start(daily) {
    const seed = daily ? today() * 7919 + Object.keys(D.jobs).indexOf(job) : Math.floor(Math.random() * 2 ** 31);
    s = C.newGame(job, seed, daily);
    const rec = storage.get(RECORD_KEY, {});
    storage.set(RECORD_KEY, { ...rec, plays: (rec.plays || 0) + 1 });
    newEnding = null;
    save();
    renderMorning(`${D.jobs[job].icon} ${D.jobs[job].name}로 시작합니다. 라디오에서는 같은 말만 반복된다. “집 밖으로 나가지 마십시오.”`);
  }

  // ───── 상태 표시 ─────
  function renderStatus(changes = []) {
    const delta = Object.fromEntries(changes.map((c) => [c.key, c.delta]));
    $("zb-day").textContent = `${s.day}일째`;
    $("zb-days-left").textContent = s.day >= D.days ? "오늘 구조 헬기!" : `구조까지 ${D.days - s.day}일`;
    $("zb-day-bar").style.width = `${(s.day / D.days) * 100}%`;
    const L = D.locations[s.loc];
    $("zb-loc").textContent = `${L.icon} ${L.name}${s.fortified ? " · 🪵 보강됨" : ""}`;

    $("zb-res").replaceChildren(
      ...["hp", "mind", "food", "water", "ammo", "med"].map((k) => {
        const v = s.res[k];
        const low = (k === "hp" || k === "mind") ? v <= 3 : (k === "food" || k === "water") ? v <= 2 : false;
        const cell = el("div", { className: `zb-stat${low ? " low" : ""}` }, [
          el("span", { className: "zb-stat-label", textContent: `${C.ICONS[k]} ${C.LABELS[k]}` }),
          el("strong", { textContent: v }),
        ]);
        if (k === "hp" || k === "mind") {
          const bar = el("span", { className: "bar" });
          bar.style.width = `${v * 10}%`;
          cell.append(el("span", { className: "zb-meter" }, [bar]));
        }
        if (delta[k]) cell.append(el("em", { className: delta[k] > 0 ? "up" : "down", textContent: delta[k] > 0 ? `+${delta[k]}` : delta[k] }));
        return cell;
      })
    );

    $("zb-comps").replaceChildren(
      ...(s.comps.length
        ? s.comps.map((id) => el("span", { className: "zb-comp", title: D.companions[id].desc, textContent: `${D.companions[id].icon} ${D.companions[id].short}` }))
        : [el("span", { className: "empty", textContent: "동료 없음" })]),
      ...(s.flags.includes("dog") ? [el("span", { className: "zb-comp", textContent: "🐕 개" })] : []),
      ...(s.flags.includes("radio") ? [el("span", { className: "zb-comp", textContent: "📡 무전기" })] : [])
    );
    const med = $("zb-med");
    med.disabled = s.ending || s.res.med < 1 || s.res.hp >= D.max.hp;
    med.textContent = `🩹 구급약 쓰기 (${s.res.med})`;
  }

  function scene({ icon, kicker, title, text, changes = [], notes = [] }) {
    $("zb-icon").textContent = icon;
    $("zb-kicker").textContent = kicker;
    delete $("zb-kicker").dataset.type;
    $("zb-title").textContent = title;
    $("zb-text").replaceChildren(...[].concat(text).filter(Boolean).map((t) => el("p", { textContent: t })));
    $("zb-notes").replaceChildren(...notes.map((n) => el("li", { textContent: n })));
    $("zb-notes").hidden = !notes.length;
    renderStatus(changes);
    const card = $("zb-scene");
    card.classList.remove("enter");
    void card.offsetWidth;
    card.classList.add("enter");
    // 새 장면의 제목이 헤더 아래로 가려져 있으면 보이도록 스크롤
    if (card.getBoundingClientRect().top < 70) card.scrollIntoView({ block: "start", behavior: "smooth" });
  }

  function setChoices(list) {
    $("zb-choices").replaceChildren(
      ...list.map((c) => {
        const btn = el("button", { className: "choice", type: "button" }, [
          el("span", { textContent: `${c.icon ? c.icon + " " : ""}${c.label}` }),
        ]);
        if (c.desc || c.reason) btn.append(el("span", { className: "cost", textContent: c.reason || c.desc }));
        btn.disabled = !!c.reason;
        btn.addEventListener("click", c.action);
        return btn;
      })
    );
  }

  // ───── 아침 ─────
  function renderMorning(intro) {
    const L = D.locations[s.loc];
    scene({
      icon: L.icon,
      kicker: `${s.day}일째 아침 · ${L.name}`,
      title: s.day >= D.days ? "오늘 정오, 구조 헬기가 온다" : "오늘은 무엇을 할까?",
      text: [intro, s.day >= D.days && s.loc !== "han" ? "지금 한강에 있지 않다면, 이동해야 한다!" : L.desc],
    });
    setChoices(
      C.actions(s).map((a) => ({
        icon: a.icon,
        label: a.label,
        desc: a.desc,
        reason: a.disabled,
        action: () => act(a.id),
      }))
    );
    save();
  }

  function act(id) {
    const r = C.doAction(s, id);
    if (!r) return;
    if (r.ended) return renderEnding(r);
    scene({ icon: "☀️", kicker: `${s.day}일째 낮`, title: r.title, text: r.text, changes: r.changes, notes: r.notes });
    setChoices([{ icon: "🌙", label: "밤이 된다", action: renderNight }]);
    save();
  }

  // ───── 밤 ─────
  function renderNight() {
    const p = C.drawEvent(s);
    const ev = C.getEvent(p.event);
    scene({ icon: ev.icon, kicker: `${s.day}일째 밤`, title: ev.title, text: C.fill(ev.text, p.target) });
    setChoices(
      C.visibleChoices(s, ev).map((c, i) => {
        const st = C.choiceState(s, c);
        return { label: C.fill(c.label, p.target), reason: st.ok ? null : st.reason, action: () => decide(i) };
      })
    );
    save();
  }

  function decide(i) {
    const p = s.pending;
    const ev = C.getEvent(p.event);
    const r = C.choose(s, i);
    if (!r) return;
    if (r.ended || r.night?.ended) return renderEnding(r);
    const notes = [...r.notes, ...r.night.notes];
    const changes = mergeChanges(r.changes, r.night.changes);
    scene({ icon: ev.icon, kicker: `${s.day - 1}일째 밤`, title: ev.title, text: r.text, changes, notes });
    setChoices([{ icon: "🌅", label: `${s.day}일째 아침을 맞는다`, action: () => renderMorning() }]);
    save();
  }

  function mergeChanges(...lists) {
    const m = {};
    lists.flat().forEach((c) => (m[c.key] = (m[c.key] || 0) + c.delta));
    return Object.entries(m).filter(([, v]) => v).map(([key, delta]) => ({ key, delta }));
  }

  // ───── 엔딩 ─────
  function renderEnding(r) {
    const id = s.ending;
    const E = D.endings[id];
    const seen = storage.get(ENDINGS_KEY, []);
    newEnding = seen.includes(id) ? null : id;
    if (newEnding) storage.set(ENDINGS_KEY, [...seen, id]);

    const rescued = ["alone", "dog", "together", "everyone", "signal"].includes(id);
    const daysSurvived = rescued ? D.days : s.day;
    const rec = storage.get(RECORD_KEY, {});
    const next = {
      ...rec,
      best: Math.max(rec.best || 0, daysSurvived),
      rescues: (rec.rescues || 0) + (rescued ? 1 : 0),
    };
    if (s.daily) {
      const d = rec.daily?.day === today() ? rec.daily : { day: today(), best: 0, rescued: false };
      next.daily = { day: today(), best: Math.max(d.best, daysSurvived), rescued: d.rescued || rescued };
    }
    storage.set(RECORD_KEY, next);
    storage.remove(SAVE_KEY);

    const lead = r?.text ? [r.text] : [];
    scene({
      icon: rescued ? "🚁" : id === "missed" ? "🌇" : "💀",
      kicker: `${TYPE_LABELS[E.type]} · ${daysSurvived}일 생존`,
      title: E.title,
      text: [...lead, E.text, `동료: ${s.comps.length ? s.comps.map((c) => D.companions[c].short).join(", ") : "없음"} · 직업: ${D.jobs[s.job].name}`],
      changes: mergeChanges(r?.changes || [], r?.night?.changes || []),
    });
    $("zb-kicker").dataset.type = E.type;
    setChoices([
      { icon: "📤", label: "결과 공유하기", action: () => share(E, daysSurvived, rescued) },
      { icon: "🔁", label: "다시 도전하기", action: renderIntro },
    ]);
    if (newEnding) toast(`새 엔딩 발견! 「${E.title}」`);
    renderSide();
  }

  function share(E, days, rescued) {
    const text = E
      ? `🧟 서울, 구조까지 15일 — ${rescued ? "구조 성공! 🚁" : `${days}일째에 끝났다…`} 엔딩 「${E.title}」${s?.daily ? " (오늘의 생존)" : ""}. 당신은 며칠 버틸 수 있을까요?`
      : "🧟 좀비 사태 속 서울, 구조 헬기까지 15일. 당신은 살아남을 수 있을까요?";
    Share.open({ title: "서울, 구조까지 15일", text });
  }

  // ───── 사이드바 ─────
  function renderSide() {
    const seen = storage.get(ENDINGS_KEY, []);
    const all = Object.entries(D.endings);
    $("zb-ending-count").textContent = `${seen.length}/${all.length}`;
    $("zb-ending-bar").style.width = `${(seen.length / all.length) * 100}%`;
    $("zb-endings").replaceChildren(
      ...all.map(([id, E], i) => {
        const open = seen.includes(id);
        const li = el("li", { className: open ? "unlocked" : "locked" });
        li.dataset.type = E.type;
        if (id === newEnding) li.classList.add("new");
        const row = el("div", { className: "ending-row" }, [
          el("span", { className: "ending-name", textContent: `${i + 1}. ${open ? E.title : "???"}` }),
          el("span", { className: "ending-type", textContent: open ? TYPE_LABELS[E.type] : "" }),
        ]);
        li.append(row);
        if (!open) {
          const hint = el("p", { className: "hint", textContent: E.hint, hidden: true });
          const b = el("button", { className: "hint-btn", textContent: "힌트" });
          b.addEventListener("click", () => {
            hint.hidden = !hint.hidden;
            b.textContent = hint.hidden ? "힌트" : "닫기";
          });
          row.append(b);
          li.append(hint);
        }
        return li;
      })
    );
    const rec = storage.get(RECORD_KEY, {});
    $("zb-records").replaceChildren(
      ...[
        ["최장 생존", rec.best ? `${rec.best}일` : "-"],
        ["구조 성공", `${rec.rescues || 0}번`],
        ["플레이", `${rec.plays || 0}번`],
      ].flatMap(([k, v]) => [el("dt", { textContent: k }), el("dd", { textContent: v })])
    );
  }

  // ───── 이벤트 ─────
  $("zb-start").addEventListener("click", () => start(false));
  $("zb-daily").addEventListener("click", () => start(true));
  $("zb-continue").addEventListener("click", () => {
    s = storage.get(SAVE_KEY, null);
    if (!s) return renderIntro();
    show("zb-game");
    if (s.phase === "night") renderNight();
    else renderMorning("이어서 시작합니다.");
  });
  $("zb-home").addEventListener("click", renderIntro);
  $("zb-med").addEventListener("click", () => {
    const r = C.useMed(s);
    if (!r) return;
    renderStatus(r.changes);
    toast("구급약을 썼다.");
    save();
  });
  $("btn-share").addEventListener("click", () => share());

  // 시작 버튼을 누르면 게임 화면으로
  ["zb-start", "zb-daily"].forEach((id) => $(id).addEventListener("click", () => show("zb-game")));

  Site.init({ current: "game:zombie" });
  // 모바일에서는 긴 엔딩 도감을 접은 채로 시작
  if (matchMedia("(max-width: 860px)").matches) $("zb-endings").closest("details").open = false;
  renderIntro();
})();
