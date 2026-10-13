/*
 * 좀비 생존 게임 규칙 (화면과 분리되어 있어 시뮬레이션에도 씁니다)
 *
 * 하루 흐름: 아침 행동 → 오후 행동(doAction 두 번) → 밤 사건(drawEvent → choose) → 하루 마무리(식량·물 소비, 생존 확인)
 * 15일째 아침 행동을 마치면(정오) 한강에 있는지에 따라 엔딩이 정해집니다.
 */
const ZombieCore = (() => {
  const D = typeof ZOMBIE !== "undefined" ? ZOMBIE : require("./zombie-data.js");
  const RES = ["food", "water", "hp", "mind", "ammo", "med"];

  // ───── 난수 (상태에 저장되어 이어하기·오늘의 생존에서도 같은 흐름) ─────
  function rand(s) {
    s.seed = (s.seed + 0x6d2b79f5) | 0;
    let t = s.seed;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  }
  const randInt = (s, min, max) => min + Math.floor(rand(s) * (max - min + 1));
  const pick = (s, arr) => arr[Math.floor(rand(s) * arr.length)];
  function weighted(s, items, w) {
    const total = items.reduce((a, it) => a + w(it), 0);
    let r = rand(s) * total;
    for (const it of items) {
      r -= w(it);
      if (r < 0) return it;
    }
    return items[items.length - 1];
  }

  const has = (s, id) => s.comps.includes(id);
  const compName = (id) => D.companions[id]?.short || "";

  function newGame(job, seed, daily = false) {
    const st = { ...D.start, ...Object.fromEntries(Object.entries(D.jobs[job].start).map(([k, v]) => [k, (D.start[k] || 0) + v])) };
    return {
      job,
      daily,
      seed: seed | 0,
      day: 1,
      phase: "morning", // morning(행동) → night → morning … → end
      slot: 0, // 0: 아침, 1: 오후
      loc: st.loc,
      res: Object.fromEntries(RES.map((k) => [k, st[k] || 0])),
      comps: [],
      flags: [],
      trust: 0,
      fortified: false,
      seen: [],
      scheduled: [], // [{ day, event, target }]
      scavCount: {},
      pending: null, // { event, target }
      lastEvent: null,
      cause: null,
      log: [],
      ending: null,
    };
  }

  function clamp(s) {
    for (const k of RES) s.res[k] = Math.min(D.max[k], s.res[k]);
  }

  // ───── 효과 적용 ─────
  // 반환: 화면에 보여 줄 변화 목록 [{ key, delta }] 과 문구
  function applyFx(s, fx = {}, ctx = {}) {
    const changes = [];
    const notes = [];
    for (const k of RES) {
      if (!fx[k]) continue;
      let d = fx[k];
      if (k === "hp" && d < 0 && ctx.attack) {
        if (s.fortified) {
          d = Math.min(0, d + 1);
          s.fortified = false;
          notes.push("바리케이드가 피해를 막아 줬다.");
        }
        if (has(s, "park") && d < 0) {
          d = -Math.ceil(-d / 2);
          notes.push("박 상사가 앞장서 막아 줬다.");
        }
      }
      if (k === "med" && d > 0 && s.job === "doctor") d = d; // 의사는 구급약 효과가 큼 (useMed에서 처리)
      const before = s.res[k];
      s.res[k] = Math.max(0, s.res[k] + d);
      clamp(s);
      const real = s.res[k] - before;
      if (real) changes.push({ key: k, delta: real });
      if (k === "hp" && d < 0) s.cause = fx.cause || (ctx.attack ? "attack" : s.cause || "illness");
    }
    if (fx.trust) s.trust += fx.trust;
    if (fx.flag && !s.flags.includes(fx.flag)) s.flags.push(fx.flag);
    if (fx.unflag) s.flags = s.flags.filter((f) => f !== fx.unflag);
    if (fx.fortify) s.fortified = true;
    if (fx.add && !has(s, fx.add)) {
      s.comps.push(fx.add);
      notes.push(`🤝 동료 합류: ${D.companions[fx.add].name}`);
    }
    if (fx.remove) {
      const id = fx.remove === "target" ? ctx.target : fx.remove;
      if (id && has(s, id)) {
        s.comps = s.comps.filter((c) => c !== id);
        notes.push(`👋 동료 이탈: ${D.companions[id].name}`);
      }
    }
    if (fx.move) {
      const dest = pick(s, D.locations[s.loc].next);
      s.loc = dest;
      notes.push(`${D.locations[dest].name}(으)로 피했다.`);
    }
    if (fx.later) s.scheduled.push({ day: s.day + fx.later.days, event: fx.later.event, target: ctx.target });
    if (fx.end) s.ending = fx.end;
    return { changes, notes };
  }

  // ───── 아침 행동 ─────
  function actions(s) {
    const list = [
      { id: "scavenge", icon: "🔍", label: "주변을 탐색한다", desc: "물자를 찾지만 다칠 수 있어요" },
      { id: "rest", icon: "🛏️", label: "쉰다", desc: "체력 +1, 정신력 +1" },
      { id: "fortify", icon: "🪵", label: "바리케이드를 보강한다", desc: "다음 습격 피해 -1, 정신력 +1", disabled: s.fortified ? "이미 보강했어요" : null },
    ];
    const survivor = survivorHere(s);
    if (survivor) list.splice(1, 0, { id: "search", icon: "🧑‍🤝‍🧑", label: "생존자를 찾아본다", desc: "이곳 어딘가에 누군가 숨어 있을지도" });
    if (s.comps.length) list.push({ id: "talk", icon: "💬", label: "동료와 이야기한다", desc: "정신력 +2" });
    for (const dest of D.locations[s.loc].next) {
      const L = D.locations[dest];
      list.push({ id: `move:${dest}`, icon: L.icon, label: `${L.name}(으)로 이동한다`, desc: dest === "han" ? "구조 헬기가 오는 곳" : "새로운 장소의 물자와 사건" });
    }
    return list;
  }

  // 이 장소에서 아직 만나지 않은 동료 사건
  function survivorHere(s) {
    const evId = D.locations[s.loc].survivor;
    if (!evId || s.seen.includes(evId)) return null;
    const ev = D.events.find((e) => e.id === evId);
    return ev.when?.noComp && has(s, ev.when.noComp) ? null : evId;
  }

  function doAction(s, id) {
    if (s.phase !== "morning" || s.pending) return null;
    const L = D.locations[s.loc];
    let title = "";
    let text = "";
    let fx = {};
    let ctx = {};
    if (id === "scavenge") {
      const sc = L.scavenge;
      const used = s.scavCount[s.loc] || 0;
      s.scavCount[s.loc] = used + 1;
      fx = {};
      for (const [k, min, max] of sc.loot) {
        const n = Math.max(0, randInt(s, min, max) - Math.floor(used / 2));
        if (n) fx[k] = (fx[k] || 0) + n;
      }
      if (rand(s) < sc.med) fx.med = (fx.med || 0) + 1;
      if (sc.ammo && rand(s) < sc.ammo) fx.ammo = (fx.ammo || 0) + 1;
      if (has(s, "minjun")) {
        const k = pick(s, sc.loot)[0];
        fx[k] = (fx[k] || 0) + 1;
      }
      if (s.job === "cook" && sc.loot.some(([k]) => k === "food")) fx.food = (fx.food || 0) + 1;
      let hurt = false;
      if (rand(s) < sc.risk) {
        fx.hp = has(s, "park") ? -1 : -2;
        fx.cause = "attack";
        hurt = true;
      }
      title = "탐색";
      const found = Object.entries(fx)
        .filter(([k, v]) => LABELS[k] && v > 0)
        .map(([k, v]) => `${ICONS[k]} ${LABELS[k]} ${v}`);
      text = [
        pick(s, D.actionText.scavenge),
        found.length ? `${found.join(", ")}을(를) 찾았다!` : "아무것도 찾지 못했다.",
        used >= 3 ? "이곳은 이미 많이 뒤졌다. 다른 곳으로 가 보는 게 좋겠다." : "",
        hurt ? "그러다 좀비에게 습격당했다!" : "",
      ]
        .filter(Boolean)
        .join(" ");
    } else if (id === "search") {
      const evId = survivorHere(s);
      title = "생존자 찾기";
      if (evId && rand(s) < 0.75) {
        s.seen.push(evId);
        s.pending = { event: evId, target: null, day: true };
        s.log.push({ day: s.day, text: title });
        return { title, text: "어딘가에서 인기척이 느껴진다…", changes: [], notes: [], encounter: evId };
      }
      text = "구석구석 불러 봤지만 대답이 없었다. 다시 찾아보면 만날 수 있을지도.";
      if (rand(s) < 0.2) {
        fx = { hp: has(s, "park") ? -1 : -2, cause: "attack" };
        text += " 대신 소리를 듣고 좀비가 다가왔다!";
      }
    } else if (id === "rest") {
      fx = { hp: 1, mind: 1 };
      title = "휴식";
      text = pick(s, D.actionText.rest);
    } else if (id === "fortify") {
      fx = { fortify: true, mind: 1 };
      title = "바리케이드";
      text = pick(s, D.actionText.fortify);
    } else if (id === "talk") {
      fx = { mind: 2, trust: has(s, "kim") ? 1 : 0 };
      title = "대화";
      text = pick(s, D.actionText.talk);
    } else if (id.startsWith("move:")) {
      const dest = id.slice(5);
      const N = D.locations[dest];
      s.loc = dest;
      s.fortified = false;
      title = `${N.icon} ${N.name}`;
      text = N.desc;
      if (s.job !== "driver" && rand(s) < 0.3) {
        fx = { hp: has(s, "park") ? -1 : -2, cause: "attack" };
        text = "가는 길에 좀비를 만났다! " + text;
      }
    }
    const result = applyFx(s, fx, ctx);
    s.log.push({ day: s.day, text: `${title}` });

    return { title, text, ...result, ...advance(s) };
  }

  // 낮 행동 하나가 끝난 뒤: 사망·구조 확인, 오후 또는 밤으로
  function advance(s) {
    if (s.res.hp <= 0) return { ended: finish(s, deathEnding(s)) };
    if (s.day >= D.days) return { ended: finish(s, rescueEnding(s)) };
    if (!s.slot) {
      s.slot = 1;
      return { next: "afternoon" };
    }
    s.slot = 0;
    s.phase = "night";
    return { next: "night" };
  }

  // ───── 밤 사건 ─────
  function eligible(s, ev) {
    if (ev.forcedOnly) return false;
    if (ev.once && s.seen.includes(ev.id)) return false;
    const w = ev.when || {};
    if (w.loc && !w.loc.includes(s.loc)) return false;
    if (w.minDay && s.day < w.minDay) return false;
    if (w.maxDay && s.day > w.maxDay) return false;
    if (w.comp && !has(s, w.comp)) return false;
    if (w.noComp && has(s, w.noComp)) return false;
    if (w.anyComp && !s.comps.length) return false;
    if (w.minComps && s.comps.length < w.minComps) return false;
    if (w.flag && !s.flags.includes(w.flag)) return false;
    if (w.noFlag && s.flags.includes(w.noFlag)) return false;
    if (w.minTrust !== undefined && s.trust < w.minTrust) return false;
    if (w.maxTrust !== undefined && s.trust > w.maxTrust) return false;
    return true;
  }

  function drawEvent(s) {
    if (s.phase !== "night") return null;
    if (s.pending) return s.pending;
    const forced = s.scheduled.find((x) => x.day <= s.day && (!x.target || has(s, x.target)));
    s.scheduled = s.scheduled.filter((x) => x.day > s.day);
    let ev;
    let target = null;
    if (forced) {
      ev = D.events.find((e) => e.id === forced.event);
      target = forced.target;
    } else {
      const pool = D.events.filter((e) => eligible(s, e) && e.id !== s.lastEvent);
      // 장소 전용 사건은 더 자주 나오게
      ev = weighted(s, pool, (e) => (e.weight || 1) * (e.when?.loc ? 2 : 1));
      if (ev.text.includes("{name}")) target = pick(s, s.comps);
    }
    s.seen.push(ev.id);
    s.lastEvent = ev.id;
    s.pending = { event: ev.id, target };
    return s.pending;
  }

  const getEvent = (id) => D.events.find((e) => e.id === id);
  const fill = (text, target) => text.replaceAll("{name}", compName(target));

  function choiceState(s, choice) {
    const r = choice.req || {};
    for (const k of ["ammo", "med", "food", "water"]) {
      if (r[k] && s.res[k] < r[k]) return { ok: false, reason: `${LABELS[k]} ${r[k]}개 필요` };
    }
    if (r.comp && !has(s, r.comp)) return { ok: false, reason: `${compName(r.comp)} 필요` };
    if (r.anyComp && !s.comps.length) return { ok: false, reason: "동료 필요" };
    if (r.flag && !s.flags.includes(r.flag)) return { ok: false, reason: "조건 부족" };
    return { ok: true };
  }

  // 조건이 아예 안 맞는 동료 전용 선택지는 숨김 (예: 지은이 없으면 "지은에게 맡긴다")
  const visibleChoices = (s, ev) => ev.choices.filter((c) => !(c.req?.comp && !has(s, c.req.comp)));

  function choose(s, choiceIndex) {
    if (!s.pending) return null;
    if (s.phase !== "night" && !s.pending.day) return null;
    const ev = getEvent(s.pending.event);
    const target = s.pending.target;
    const choice = visibleChoices(s, ev)[choiceIndex];
    if (!choice || !choiceState(s, choice).ok) return null;
    const outcome = weighted(s, choice.outcomes, (o) => o.p || 1);
    const result = applyFx(s, outcome.fx, { attack: ev.attack, target });
    const dayEncounter = s.pending.day;
    s.pending = null;
    const text = fill(outcome.text, target);
    s.log.push({ day: s.day, text: `${ev.title}: ${choice.label}` });
    if (s.ending) return { text, ...result, ended: finish(s, s.ending) };
    if (dayEncounter) return { text, ...result, ...advance(s) };
    const night = endOfDay(s);
    return { text, ...result, night };
  }

  // ───── 하루 마무리 ─────
  function endOfDay(s) {
    const notes = [];
    const changes = [];
    const n = 1 + s.comps.length;
    const need = Math.ceil((n * 2) / 3); // 1명 1개, 2~3명 2개, 4명 3개, 5명 4개
    const before = { ...s.res };
    s.res.food -= need;
    s.res.water -= need;
    if (s.res.food < 0) {
      s.res.food = 0;
      s.res.hp -= 2;
      s.res.mind -= 1;
      s.cause = "starve";
      notes.push("먹을 것이 없어 굶주렸다.");
    }
    if (s.res.water < 0) {
      s.res.water = 0;
      s.res.hp -= 3;
      s.cause = "thirst";
      notes.push("마실 물이 없어 목이 타들어 간다.");
    }
    if (has(s, "jieun") && s.res.hp > 0 && s.res.hp < D.max.hp) {
      s.res.hp += 1;
      notes.push("지은이 상처를 돌봐 줬다.");
    }
    if (!s.comps.length && !s.flags.includes("dog")) {
      s.res.mind -= 1;
      notes.push("혼자 보내는 밤은 길다.");
    }
    s.res.hp = Math.max(0, s.res.hp);
    s.res.mind = Math.max(0, s.res.mind);
    clamp(s);
    for (const k of RES) if (s.res[k] !== before[k]) changes.push({ key: k, delta: s.res[k] - before[k] });

    if (s.res.hp <= 0) return { notes, changes, ended: finish(s, deathEnding(s)) };
    if (s.res.mind <= 0) return { notes, changes, ended: finish(s, "broken") };
    s.day += 1;
    s.phase = "morning";
    return { notes, changes };
  }

  function useMed(s) {
    if (s.ending || s.res.med < 1 || s.res.hp >= D.max.hp) return null;
    s.res.med -= 1;
    const heal = s.job === "doctor" ? 4 : 3;
    const before = s.res.hp;
    s.res.hp = Math.min(D.max.hp, s.res.hp + heal);
    return { changes: [{ key: "med", delta: -1 }, { key: "hp", delta: s.res.hp - before }] };
  }

  function deathEnding(s) {
    return { starve: "starved", thirst: "thirst" }[s.cause] || "killed";
  }

  function rescueEnding(s) {
    if (s.loc !== "han") return "missed";
    const c = s.comps.length;
    if (s.flags.includes("radio") && c >= 2) return "signal";
    if (c >= 3) return "everyone";
    if (c >= 1) return "together";
    if (s.flags.includes("dog")) return "dog";
    return "alone";
  }

  function finish(s, endingId) {
    s.ending = endingId;
    s.phase = "end";
    s.pending = null;
    return endingId;
  }

  const LABELS = { food: "식량", water: "물", hp: "체력", mind: "정신력", ammo: "탄약", med: "구급약" };
  const ICONS = { food: "🍙", water: "💧", hp: "❤️", mind: "🧠", ammo: "🔫", med: "🩹" };

  return { D, LABELS, ICONS, newGame, actions, doAction, drawEvent, getEvent, visibleChoices, choiceState, choose, useMed, fill };
})();

if (typeof module !== "undefined") module.exports = ZombieCore;
