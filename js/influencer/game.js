/*
 * 인플루언서 시뮬레이터 — 게임 진행과 화면
 */
(() => {
  const SAVE_KEY = "influencer:save";
  const BEST_KEY = "influencer:endings";

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
  const h = (tag, props = {}, ...children) => {
    const node = Object.assign(document.createElement(tag), props);
    node.append(...children.flat().filter((c) => c !== null && c !== undefined && c !== false));
    return node;
  };
  const rand = (a, b) => a + Math.random() * (b - a);
  const pick = (arr) => arr[Math.floor(Math.random() * arr.length)];
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  const fill = (text) => text.replace(/\{name\}/g, S.name);
  const won = IF.won;

  // 1.2만, 34.5만 같은 짧은 표기
  function short(n) {
    const a = Math.abs(n);
    const sign = n < 0 ? "-" : "";
    if (a >= 1e8) return sign + (a / 1e8).toFixed(a >= 1e9 ? 0 : 1).replace(/\.0$/, "") + "억";
    if (a >= 1e4) return sign + (a / 1e4).toFixed(a >= 1e5 ? 0 : 1).replace(/\.0$/, "") + "만";
    return sign + a.toLocaleString("ko-KR");
  }
  const shortWon = (n) => `${short(n)}원`;

  const HAIR = ["#2a2230", "#6b4226", "#c98a3c", "#e8c66a", "#d9577a", "#5b7bd6", "#8fd0c8", "#e8e8ee"];
  const SHIRT = ["#f4f4f4", "#e85d5d", "#f2a13a", "#5fbf72", "#4f8fe0", "#9b6fe0", "#2a2a2e", "#f59bb8"];
  const WALLS = ["#e9dccb", "#dfe8f0", "#f3dde2", "#e2efdc", "#ece4f5"];

  let S = null; // 게임 상태
  let room = null;
  let preview = null;
  let busy = false;

  function newState(name, look) {
    return {
      v: 1,
      name,
      look,
      wallColor: look.wall,
      day: 1,
      slot: 0,
      money: 30000,
      followers: 0,
      energy: 100,
      mental: 80,
      image: 0,
      heat: 0,
      gear: { camera: 0, mic: 0, light: 0, pc: 0 },
      deco: [],
      skills: {},
      flags: {},
      seen: [],
      trend: pick(["talk", "mukbang", "sing"]),
      lastContent: null,
      lastViewers: 0,
      milestones: [],
      feed: [],
      trends: [],
      unread: 0,
      log: [],
      mode: "idle",
      stats: { streams: 0, peak: 0, earned: 0, uploads: 0 },
    };
  }

  const save = () => S && storage.set(SAVE_KEY, S);

  // ───── 로그 / 토스트 ─────
  function log(text, kind = "") {
    S.log.unshift({ text, kind, day: S.day, slot: S.slot });
    S.log = S.log.slice(0, 30);
  }

  function toast(message) {
    const t = $("toast");
    t.textContent = message;
    t.hidden = false;
    clearTimeout(toast.timer);
    toast.timer = setTimeout(() => (t.hidden = true), 2200);
  }

  // ───── HUD ─────
  function bar(label, value, max, cls, text) {
    const pct = clamp((value / max) * 100, 0, 100);
    return h(
      "div",
      { className: `meter ${cls}` },
      h("span", { className: "meter-label", textContent: label }),
      h("span", { className: "meter-track" }, h("span", { className: "meter-fill", style: `width:${pct}%` })),
      h("span", { className: "meter-value", textContent: text ?? Math.round(value) })
    );
  }

  function imageText(v) {
    if (v >= 40) return "호감";
    if (v >= 10) return "좋음";
    if (v > -10) return "보통";
    if (v > -40) return "나쁨";
    return "비호감";
  }

  function renderHud() {
    const rank = IF.rankOf(S.followers);
    $("hud").replaceChildren(
      h(
        "div",
        { className: "hud-top" },
        h("div", { className: "hud-day" }, h("b", { textContent: `D+${S.day}` }), h("span", { textContent: ` / ${IF.SEASON_DAYS}일 · ${IF.SLOTS[S.slot]}` })),
        h("div", { className: "hud-name" }, h("b", { textContent: S.name }), h("span", { className: "rank", textContent: rank.name }))
      ),
      h(
        "div",
        { className: "hud-nums" },
        h("div", { className: "num" }, h("span", { textContent: "구독자" }), h("b", { textContent: short(S.followers) })),
        h("div", { className: "num" }, h("span", { textContent: "통장" }), h("b", { textContent: shortWon(S.money) }))
      ),
      h(
        "div",
        { className: "hud-meters" },
        bar("체력", S.energy, 100, "m-energy"),
        bar("멘탈", S.mental, 100, "m-mental"),
        bar("이미지", S.image + 100, 200, "m-image", imageText(S.image)),
        bar("논란", S.heat, 100, "m-heat")
      )
    );
  }

  const ACTIONS = [
    { id: "stream", icon: "📡", label: "방송하기", sub: "콘텐츠 선택" },
    { id: "upload", icon: "✂️", label: "편집·업로드", sub: "체력 15" },
    { id: "work", icon: "🏪", label: "편의점 알바", sub: "+6만 원 · 체력 22" },
    { id: "rest", icon: "🛋️", label: "휴식", sub: "체력·멘탈 회복" },
    { id: "sleep", icon: "😴", label: "잠자기", sub: "하루 마치기" },
    { id: "shop", icon: "🛒", label: "장비 쇼핑", sub: "시간 안 듦" },
  ];

  function actionState(id) {
    if (busy) return "잠시만요";
    if (id === "stream") {
      const min = Math.min(...IF.CONTENTS.filter((c) => IF.canStream(S, c)).map((c) => c.energy));
      if (S.energy < min) return "체력 부족";
    }
    if (id === "upload") {
      if (S.gear.pc < 1) return "PC 필요";
      if (!S.lastViewers) return "방송 기록 없음";
      if (S.energy < 15) return "체력 부족";
    }
    if (id === "work" && S.energy < 22) return "체력 부족";
    return null;
  }

  function renderActions() {
    $("actions").replaceChildren(
      ...ACTIONS.map((a) => {
        const why = actionState(a.id);
        return h(
          "button",
          { className: `act act-${a.id}`, disabled: !!why, onclick: () => doAction(a.id) },
          h("span", { className: "act-icon", textContent: a.icon }),
          h("span", { className: "act-label", textContent: a.label }),
          h("span", { className: "act-sub", textContent: why || a.sub })
        );
      })
    );
  }

  function renderLog() {
    $("log").replaceChildren(
      ...S.log.slice(0, 8).map((l) => h("li", { className: l.kind }, h("span", { className: "log-time", textContent: `D${l.day} ${IF.SLOTS[l.slot]}` }), l.text))
    );
  }

  function renderStage() {
    const c = IF.CONTENTS.find((x) => x.id === S.trend);
    $("trend-chip").textContent = `🔥 이번 주 대세: ${c.icon} ${c.name}`;
    const badge = $("phone-badge");
    badge.hidden = !S.unread;
    badge.textContent = S.unread > 99 ? "99+" : S.unread;
    room.update(S, S.mode);
  }

  function render() {
    renderHud();
    renderActions();
    renderLog();
    renderStage();
  }

  // ───── 모달 ─────
  function modal(...children) {
    $("modal-body").replaceChildren(...children.flat().filter((c) => c !== null && c !== undefined && c !== false));
    $("modal").hidden = false;
    $("modal-body").scrollTop = 0;
  }
  function closeModal() {
    $("modal").hidden = true;
  }
  // 버튼 하나를 누를 때까지 기다리는 모달
  function ask(title, body, buttons) {
    return new Promise((resolve) => {
      modal(
        h("h2", { textContent: title }),
        ...(Array.isArray(body) ? body : [body]),
        h(
          "div",
          { className: "modal-actions" },
          buttons.map((b, i) =>
            h("button", {
              className: `btn ${b.primary ? "primary" : ""} ${b.className || ""}`,
              textContent: b.label,
              disabled: !!b.disabled,
              onclick: () => {
                closeModal();
                resolve(b.value ?? i);
              },
            })
          )
        )
      );
    });
  }

  // ───── 수치 적용 ─────
  function applyFx(fx) {
    const changes = [];
    if (fx.followers) {
      let d = Math.round(S.followers * fx.followers);
      if (fx.followers > 0) d = Math.max(d, Math.round(rand(3, 12)));
      S.followers = Math.max(0, S.followers + d);
      changes.push(delta("구독자", d, short));
    }
    if (fx.money) {
      S.money += fx.money;
      if (fx.money > 0) S.stats.earned += fx.money;
      changes.push(delta("돈", fx.money, shortWon));
    }
    if (fx.image) {
      S.image = clamp(S.image + fx.image, -100, 100);
      changes.push(delta("이미지", fx.image));
    }
    if (fx.heat) {
      S.heat = clamp(S.heat + fx.heat, 0, 100);
      changes.push(delta("논란", fx.heat, undefined, true));
    }
    if (fx.mental) {
      S.mental = clamp(S.mental + fx.mental, 0, 100);
      changes.push(delta("멘탈", fx.mental));
    }
    if (fx.energy) {
      S.energy = clamp(S.energy + fx.energy, 0, 100);
      changes.push(delta("체력", fx.energy));
    }
    if (fx.flag) S.flags[fx.flag] = true;
    if (fx.unflag) delete S.flags[fx.unflag];
    return changes;
  }

  function delta(label, d, fmt = (n) => n, invert = false) {
    const good = invert ? d < 0 : d > 0;
    return { label, text: `${d > 0 ? "+" : ""}${fmt(d)}`, cls: d === 0 ? "" : good ? "up" : "down" };
  }

  function changeList(changes) {
    if (!changes.length) return null;
    return h(
      "ul",
      { className: "changes" },
      changes.map((c) => h("li", { className: c.cls }, h("span", { textContent: c.label }), h("b", { textContent: c.text })))
    );
  }

  // ───── SNS ─────
  function pushFeed(posts) {
    S.feed = [...posts, ...S.feed].slice(0, 80);
    S.unread += posts.length;
  }

  function pushTopic(topicResult) {
    S.trends.push({ tag: topicResult.tag, headline: topicResult.headline, shield: topicResult.shield, hate: topicResult.hate, day: S.day, posts: topicResult.posts });
    S.trends = S.trends.slice(-12);
    pushFeed(topicResult.posts);
  }

  function renderPost(p, isReply = false) {
    return h(
      "article",
      { className: `post ${isReply ? "reply" : ""} ${p.news ? "news" : ""}` },
      h("div", { className: "avatar", style: `background:${p.color}`, textContent: p.nick[0] }),
      h(
        "div",
        { className: "post-main" },
        h(
          "div",
          { className: "post-head" },
          h("b", { textContent: p.nick }),
          h("span", { textContent: ` @${p.handle} · D${p.day} ${IF.SLOTS[p.slot] || ""}` })
        ),
        p.replyTo ? h("div", { className: "reply-to", textContent: `↳ ${p.replyTo}님에게 답글` }) : null,
        h("p", { className: "post-text" }, ...linkTags(p.text)),
        h(
          "div",
          { className: "post-foot" },
          h("span", { textContent: `💬 ${p.replies.length}` }),
          h("span", { textContent: `🔁 ${short(p.reposts)}` }),
          h("span", { textContent: `♥ ${short(p.likes)}` })
        ),
        p.replies.length ? h("div", { className: "replies" }, p.replies.map((r) => renderPost(r, true))) : null
      )
    );
  }

  function linkTags(text) {
    return text.split(/(#[^\s#]+)/g).map((part) => (part.startsWith("#") ? h("span", { className: "tag", textContent: part }) : part));
  }

  function opinion(t) {
    const total = t.shield + t.hate || 1;
    const sp = Math.round((t.shield / total) * 100);
    return h(
      "div",
      { className: "opinion" },
      h("div", { className: "op-bar" }, h("span", { className: "op-shield", style: `width:${sp}%` }), h("span", { className: "op-hate", style: `width:${100 - sp}%` })),
      h("div", { className: "op-legend" }, h("span", { className: "s", textContent: `🛡️ 쉴드 ${sp}%` }), h("span", { className: "h", textContent: `💢 비난 ${100 - sp}%` }))
    );
  }

  let phoneTab = "feed";
  let phoneTopic = null;

  function openPhone(tab = "feed", topic = null) {
    phoneTab = tab;
    phoneTopic = topic;
    S.unread = 0;
    $("phone").hidden = false;
    $("phone").classList.remove("pop");
    void $("phone").offsetWidth;
    $("phone").classList.add("pop");
    renderPhone();
    renderStage();
    save();
  }

  function closePhone() {
    $("phone").hidden = true;
    if (closePhone.resolve) {
      const r = closePhone.resolve;
      closePhone.resolve = null;
      r();
    }
  }

  // 휴대폰을 띄우고 닫을 때까지 기다림
  function showPhone(tab, topic) {
    return new Promise((resolve) => {
      closePhone.resolve = resolve;
      openPhone(tab, topic);
    });
  }

  function renderPhone() {
    document.querySelectorAll(".phone-tabs button").forEach((b) => b.classList.toggle("active", b.dataset.tab === phoneTab));
    const body = $("phone-body");
    body.scrollTop = 0;

    if (phoneTab === "trend") {
      const list = [...S.trends].reverse();
      const t = phoneTopic || list[0];
      if (!t) {
        body.replaceChildren(h("p", { className: "empty", textContent: "아직 트렌드에 오른 적이 없어요. 방송을 하다 보면 사람들이 당신 이야기를 시작할 거예요." }));
        return;
      }
      body.replaceChildren(
        h(
          "div",
          { className: "trend-hero" },
          h("span", { className: "trend-rank", textContent: "실시간 트렌드 1위" }),
          h("b", { textContent: `#${t.tag}` }),
          h("span", { className: "trend-count", textContent: `${short(Math.round((t.shield + t.hate + 3) * (10 + S.followers * 0.02)))}개의 게시물` }),
          opinion(t)
        ),
        ...t.posts.map((p) => renderPost(p)),
        list.length > 1
          ? h(
              "div",
              { className: "trend-history" },
              h("h4", { textContent: "지난 트렌드" }),
              list
                .filter((x) => x !== t)
                .map((x) =>
                  h(
                    "button",
                    { className: "trend-item", onclick: () => ((phoneTopic = x), renderPhone()) },
                    h("b", { textContent: `#${x.tag}` }),
                    h("span", { textContent: `D${x.day} · ${x.headline}` })
                  )
                )
            )
          : null
      );
      return;
    }

    if (!S.feed.length) {
      body.replaceChildren(h("p", { className: "empty", textContent: "타임라인이 조용하네요. 첫 방송을 켜 보세요!" }));
      return;
    }
    body.replaceChildren(...S.feed.slice(0, 40).map((p) => renderPost(p)));
  }

  // ───── 행동 ─────
  async function doAction(id) {
    if (busy || actionState(id)) return;
    if (id === "shop") return openShop();
    busy = true;
    try {
      if (id === "stream") await stream();
      else if (id === "upload") await upload();
      else if (id === "work") await work();
      else if (id === "rest") await rest();
      else if (id === "sleep") await goSleep();
    } finally {
      busy = false;
      if (S && !S.ended) {
        render();
        save();
      }
    }
  }

  // 시간 흐름
  async function advance() {
    S.slot++;
    if (S.slot > 2) await endDay(0);
  }

  async function endDay(remaining) {
    S.slot = 2;
    S.mode = "sleep";
    render();
    await sleep(700);
    const restore = 45 + remaining * 15;
    S.energy = clamp(S.energy + restore, 0, 100);
    S.mental = clamp(S.mental + 5, 0, 100);
    S.heat = clamp(S.heat - 7, 0, 100);
    S.day++;
    S.slot = 0;
    S.mode = "idle";

    if (S.day > IF.SEASON_DAYS) return finish();

    const notes = [];
    if (S.heat >= 60) {
      S.mental = clamp(S.mental - 8, 0, 100);
      notes.push("밤새 악플 알림이 울렸다. 멘탈 -8");
    }
    if (S.day % 7 === 1) {
      const options = IF.CONTENTS.filter((c) => c.id !== S.trend);
      S.trend = pick(options).id;
      const c = IF.CONTENTS.find((x) => x.id === S.trend);
      notes.push(`이번 주 대세 콘텐츠는 ${c.icon} ${c.name}! 시청자 1.5배`);
    }
    log(`D+${S.day} 아침이 밝았다.`, "day");
    notes.forEach((n) => log(n, "note"));
    if (checkOver()) return;
    render();
    save();

    // 아침 뉴스 이벤트
    const news = pickEvent("news", S.flags.hiddenAd || S.flags.lieDating ? 0.2 : 0.06);
    if (news) await runEvent(news, true);
    checkOver();
  }

  function pickEvent(where, chance) {
    if (Math.random() > chance) return null;
    const pool = IF.EVENTS.filter((e) => e.where === where && e.when(S) && !S.seen.slice(-5).includes(e.id));
    if (!pool.length) return null;
    let r = Math.random() * pool.reduce((a, e) => a + e.weight, 0);
    for (const e of pool) {
      r -= e.weight;
      if (r <= 0) return e;
    }
    return pool[pool.length - 1];
  }

  // 이벤트 진행 → 결과 → SNS 반응
  async function runEvent(ev, isNews) {
    S.seen.push(ev.id);
    S.seen = S.seen.slice(-10);
    const text = typeof ev.text === "function" ? ev.text(S) : ev.text;
    const idx = await ask(
      `${isNews ? "📰" : "⚡"} ${ev.title}`,
      h("p", { className: "event-text", textContent: fill(text) }),
      ev.choices.map((c, i) => ({ label: c.label, value: i, className: "choice-btn" }))
    );
    const choice = ev.choices[idx];
    const changes = applyFx(choice.fx(S));
    log(`${ev.title}: ${choice.label}`, "event");
    let topic = null;
    if (choice.sns) {
      topic = IF.SNS.topicFeed(S, choice.sns);
      pushTopic(topic);
    }
    checkMilestones();
    render();
    save();
    await ask(ev.title, [h("p", { className: "event-text", textContent: fill(choice.result) }), changeList(changes)], [
      topic ? { label: "📱 SNS 반응 보러 가기", primary: true } : { label: "확인", primary: true },
    ]);
    if (topic) await showPhone("trend", S.trends[S.trends.length - 1]);
    return { changes, topic };
  }

  function checkMilestones() {
    for (const m of IF.MILESTONES) {
      if (S.followers >= m.at && !S.milestones.includes(m.at)) {
        S.milestones.push(m.at);
        pushFeed(IF.SNS.milestonePosts(S, m.at));
        log(`🏆 ${m.title}`, "milestone");
        queueMicrotask(() => toast(`🏆 ${m.title}`));
        room && room.burst("heart", 14);
      }
    }
  }

  // 방송
  function chooseContent() {
    return new Promise((resolve) => {
      const cards = IF.CONTENTS.map((c) => {
        const ok = IF.canStream(S, c);
        const lack = !ok
          ? Object.entries(c.need)
              .filter(([k, v]) => S.gear[k] < v)
              .map(([k, v]) => `${IF.GEAR[k].label}: ${IF.GEAR[k].tiers[v].name} 필요`)
              .join(", ")
          : S.energy < c.energy
          ? `체력 ${c.energy} 필요`
          : c.cost && S.money < c.cost
          ? "돈 부족"
          : "";
        const lv = S.skills[c.id] || 0;
        return h(
          "button",
          {
            className: `content-card ${S.trend === c.id ? "hot" : ""}`,
            disabled: !!lack,
            onclick: () => {
              closeModal();
              resolve(c);
            },
          },
          h("span", { className: "cc-icon", textContent: c.icon }),
          h(
            "span",
            { className: "cc-body" },
            h("b", { textContent: c.name + (S.trend === c.id ? " 🔥" : "") + (S.lastContent === c.id ? " · 연속" : "") }),
            h("small", { textContent: lack || c.desc }),
            h("small", { className: "cc-meta", textContent: `체력 ${c.energy}${c.cost ? ` · 비용 ${shortWon(c.cost)}` : ""} · 숙련 Lv.${lv}` })
          )
        );
      });
      modal(
        h("h2", { textContent: `📡 ${IF.SLOTS[S.slot]} 방송` }),
        h("p", { className: "muted", textContent: S.slot === 2 ? "밤 방송은 시청자가 가장 많아요." : S.slot === 0 ? "오전 방송은 시청자가 적어요." : "오후 방송은 무난해요." }),
        h("div", { className: "content-grid" }, cards),
        h("div", { className: "modal-actions" }, h("button", { className: "btn", textContent: "취소", onclick: () => (closeModal(), resolve(null)) }))
      );
    });
  }

  async function stream() {
    const c = await chooseContent();
    if (!c) return;

    S.energy -= c.energy;
    if (c.cost) S.money -= c.cost;
    const r = IF.calcStream(S, c);

    // 방송 연출
    S.mode = "live";
    render();
    await liveShow(c, r.viewers);

    // 방송 중 이벤트
    const chance = 0.38 + (c.risky ? 0.15 : 0) - (c.calm ? 0.15 : 0);
    const ev = pickEvent("live", chance);
    if (ev) {
      stopChat();
      await runEvent(ev, false);
      if (checkOver()) return;
    }
    stopLive();

    // 결과 반영
    S.followers += r.gain;
    const income = r.donation + r.ads;
    S.money += income;
    S.stats.earned += income;
    S.stats.streams++;
    S.stats.peak = Math.max(S.stats.peak, r.viewers);
    S.skills[c.id] = (S.skills[c.id] || 0) + 1;
    S.lastContent = c.id;
    S.lastViewers = r.viewers;
    S.mental = clamp(S.mental - 2, 0, 100);
    if (c.id === "study") S.image = clamp(S.image + 1, -100, 100);
    S.mode = "idle";

    const posts = IF.SNS.streamPosts(S, c, r);
    pushFeed(posts);
    log(`${c.icon} ${c.name} · 시청자 ${short(r.viewers)}명 · 구독자 +${short(r.gain)}`, r.viral ? "viral" : r.flop ? "flop" : "");
    checkMilestones();
    if (r.viral) room.burst("heart", 20);
    if (income > 0) room.burst("coin", 6);
    render();

    let topic = null;
    if (r.viral) {
      topic = IF.SNS.topicFeed(S, {
        tag: "{name}_떡상",
        headline: `{name}의 ${c.name} 클립이 알고리즘을 탔다`,
        tone: 0.6,
        hate: ["이게 왜 뜨는지 모르겠음", "알고리즘 고장났나", "곧 거품 빠질 듯"],
        shield: ["드디어 {name}이 빛을 보네", "원래 재밌었음 이제 알았냐", "클립 10번 돌려봄 ㅋㅋㅋ"],
        neutral: ["추천 탭에 계속 뜸", "누군데 다들 얘기함?"],
      });
      pushTopic(topic);
    }

    const head = r.viral ? "🚀 떡상!" : r.flop ? "😓 오늘은 좀 별로…" : "방송 종료";
    await ask(head, [
      h(
        "div",
        { className: "result-grid" },
        resultCell("최고 시청자", `${short(r.viewers)}명`),
        resultCell("새 구독자", `+${short(r.gain)}`),
        resultCell("후원", shortWon(r.donation)),
        resultCell("광고 수익", r.ads ? shortWon(r.ads) : S.followers >= 1000 ? "0원" : "구독자 1천 명부터")
      ),
      h("p", { className: "muted small", textContent: hintFor(c) }),
    ], [topic ? { label: "📱 반응 보러 가기", primary: true } : { label: "확인", primary: true }]);
    if (topic) await showPhone("trend", S.trends[S.trends.length - 1]);

    if (checkOver()) return;
    await advance();
  }

  function resultCell(label, value) {
    return h("div", { className: "result-cell" }, h("span", { textContent: label }), h("b", { textContent: value }));
  }

  function hintFor(c) {
    const g = S.gear;
    if (g.camera === 0) return "💡 시청자들이 화질을 아쉬워해요. 장비 쇼핑에서 웹캠을 살펴보세요.";
    if (g.mic === 0) return "💡 소리가 지직거린다는 반응이 있어요. 핀 마이크라도 장만해 보세요.";
    if (g.light === 0) return "💡 얼굴이 어둡게 나와요. 조명을 사면 화면이 확 살아나요.";
    if (g.pc === 0 && S.money > 300000) return "💡 노트북이 있으면 게임·리액션 방송과 영상 업로드를 할 수 있어요.";
    if (c.id !== S.trend) return "💡 이번 주 대세 콘텐츠로 방송하면 시청자가 1.5배예요.";
    if (S.slot !== 2) return "💡 밤 방송이 시청자가 가장 많아요.";
    return "💡 같은 콘텐츠를 연속으로 하면 시청자가 조금 줄어들어요.";
  }

  // 방송 중 채팅 연출
  let chatTimer = null;
  let viewerTimer = null;

  function chatLine() {
    const g = S.gear;
    const pools = [IF.CHAT.any, IF.CHAT.any, IF.CHAT[liveShow.content.id]];
    if (g.camera === 0) pools.push(IF.CHAT.lowcam);
    if (g.mic === 0) pools.push(IF.CHAT.lowmic);
    if (g.light === 0 && S.slot === 2) pools.push(IF.CHAT.dark);
    const u = IF.SNS.user();
    const li = h("li", {}, h("b", { style: `color:${u.color}`, textContent: u.nick }), " ", fill(pick(pick(pools))));
    const list = $("chat");
    list.append(li);
    while (list.children.length > 6) list.firstChild.remove();
  }

  function liveShow(c, viewers) {
    liveShow.content = c;
    $("live-badge").hidden = false;
    $("chat").hidden = false;
    $("chat").replaceChildren();
    let shown = 0;
    const steps = 22;
    let i = 0;
    viewerTimer = setInterval(() => {
      i++;
      shown = Math.round(viewers * Math.min(1, (i / steps) * rand(0.9, 1.1)));
      $("live-viewers").textContent = `👁 ${short(Math.max(1, shown))}`;
      if (i >= steps) clearInterval(viewerTimer);
    }, 110);
    chatTimer = setInterval(chatLine, 320);
    return sleep(2600);
  }

  function stopChat() {
    clearInterval(chatTimer);
    clearInterval(viewerTimer);
  }

  function stopLive() {
    stopChat();
    $("live-badge").hidden = true;
    $("chat").hidden = true;
  }

  // 편집 영상 업로드
  async function upload() {
    S.energy -= 15;
    S.mode = "idle";
    const r = IF.calcUpload(S);
    S.followers += r.gain;
    S.money += r.ads;
    S.stats.earned += r.ads;
    S.stats.uploads++;
    S.mental = clamp(S.mental - 1, 0, 100);
    const c = IF.CONTENTS.find((x) => x.id === S.lastContent) || IF.CONTENTS[0];
    pushFeed(IF.SNS.streamPosts(S, c, { viral: r.viral }));
    log(`✂️ 하이라이트 영상 업로드 · 조회수 ${short(r.views)} · 구독자 +${short(r.gain)}`, r.viral ? "viral" : "");
    checkMilestones();
    let topic = null;
    if (r.viral) {
      topic = IF.SNS.topicFeed(S, {
        tag: "{name}_쇼츠",
        headline: "{name} 쇼츠 영상, 하루 만에 조회수 폭발",
        tone: 0.5,
        hate: ["쇼츠로 뜬 사람은 금방 짐", "편집빨이네"],
        shield: ["쇼츠 보고 본방까지 정주행함", "{name} 편집 센스 미쳤다", "이 영상 중독성 있음 ㅋㅋ"],
        neutral: ["이 밈 어디서 시작된 거임?"],
      });
      pushTopic(topic);
    }
    render();
    await ask(r.viral ? "🚀 쇼츠 대박!" : "업로드 완료", [
      h("div", { className: "result-grid" }, resultCell("조회수", short(r.views)), resultCell("새 구독자", `+${short(r.gain)}`), resultCell("광고 수익", r.ads ? shortWon(r.ads) : "-")),
    ], [topic ? { label: "📱 반응 보러 가기", primary: true } : { label: "확인", primary: true }]);
    if (topic) await showPhone("trend", S.trends[S.trends.length - 1]);
    await advance();
  }

  const WORK_TEXT = [
    "편의점 야간 알바를 했다. 폐기 삼각김밥이 오늘의 저녁.",
    "편의점 알바를 했다. 진상 손님에게 시달렸다.",
    "편의점 알바를 했다. 손님이 \"혹시 방송하시는 분?\"이라고 물었다… 착각이었다.",
    "편의점 알바를 했다. 물건 정리하며 다음 방송 아이디어를 떠올렸다.",
  ];

  async function work() {
    S.mode = "away";
    render();
    await sleep(600);
    S.energy -= 22;
    S.mental = clamp(S.mental - 3, 0, 100);
    const pay = S.slot === 2 ? 72000 : 60000;
    S.money += pay;
    log(`🏪 ${pick(WORK_TEXT)} +${shortWon(pay)}`);
    await advance();
    S.mode = S.slot === 0 && S.day > 1 ? "idle" : "away";
  }

  async function rest() {
    S.mode = "stand";
    S.energy = clamp(S.energy + 25, 0, 100);
    S.mental = clamp(S.mental + 8, 0, 100);
    log(pick(["🛋️ 뒹굴거리며 쉬었다.", "🛋️ 좋아하는 방송을 보며 쉬었다.", "🛋️ 산책을 다녀왔다. 머리가 맑아졌다.", "🛋️ 낮잠을 잤다."]) + " 체력 +25, 멘탈 +8");
    render();
    await sleep(400);
    await advance();
  }

  async function goSleep() {
    const remaining = 2 - S.slot;
    log(`😴 일찍 잠자리에 들었다.${remaining ? ` 체력 추가 회복 +${remaining * 15}` : ""}`);
    await endDay(remaining);
  }

  // ───── 상점 ─────
  function openShop(tab = "gear") {
    const tabs = h(
      "div",
      { className: "shop-tabs" },
      h("button", { className: tab === "gear" ? "active" : "", textContent: "장비", onclick: () => openShop("gear") }),
      h("button", { className: tab === "deco" ? "active" : "", textContent: "방 꾸미기", onclick: () => openShop("deco") })
    );
    let rows;
    if (tab === "gear") {
      rows = Object.entries(IF.GEAR).map(([k, g]) => {
        const cur = g.tiers[S.gear[k]];
        const next = g.tiers[S.gear[k] + 1];
        return h(
          "div",
          { className: "shop-row" },
          h("span", { className: "shop-icon", textContent: g.icon }),
          h(
            "span",
            { className: "shop-body" },
            h("b", { textContent: `${g.label} · Lv.${S.gear[k]}` }),
            h("small", { textContent: next ? `${cur.name} → ${next.name}` : `${cur.name} (최고 단계)` })
          ),
          next
            ? h("button", { className: "btn small-btn primary", disabled: S.money < next.price, textContent: shortWon(next.price), onclick: () => buyGear(k) })
            : h("span", { className: "owned", textContent: "MAX" })
        );
      });
    } else {
      rows = IF.DECO.map((d) => {
        const owned = S.deco.includes(d.id);
        return h(
          "div",
          { className: "shop-row" },
          h("span", { className: "shop-icon", textContent: "🪴" }),
          h("span", { className: "shop-body" }, h("b", { textContent: d.name }), h("small", { textContent: "방 매력도 +1 (시청자 +3%)" })),
          owned
            ? h("span", { className: "owned", textContent: "보유" })
            : h("button", { className: "btn small-btn primary", disabled: S.money < d.price, textContent: shortWon(d.price), onclick: () => buyDeco(d) })
        );
      });
      rows.push(
        h(
          "div",
          { className: "shop-row" },
          h("span", { className: "shop-icon", textContent: "🎨" }),
          h("span", { className: "shop-body" }, h("b", { textContent: "벽지 색 바꾸기" }), h("small", { textContent: "무료" })),
          h(
            "div",
            { className: "swatches" },
            WALLS.map((w) =>
              h("button", {
                className: `swatch ${S.wallColor === w ? "active" : ""}`,
                style: `background:${w}`,
                ariaLabel: "벽지 색",
                onclick: () => {
                  S.wallColor = w;
                  render();
                  save();
                  openShop("deco");
                },
              })
            )
          )
        )
      );
    }
    modal(
      h("h2", { textContent: "🛒 장비 쇼핑" }),
      h("p", { className: "muted", textContent: `통장 잔고 ${won(S.money)}` }),
      tabs,
      h("div", { className: "shop-list" }, rows),
      h("div", { className: "modal-actions" }, h("button", { className: "btn", textContent: "닫기", onclick: closeModal }))
    );
  }

  function buyGear(k) {
    const g = IF.GEAR[k];
    const next = g.tiers[S.gear[k] + 1];
    if (!next || S.money < next.price) return;
    S.money -= next.price;
    S.gear[k]++;
    log(`🛒 ${next.name} 구입! (-${shortWon(next.price)})`, "buy");
    pushFeed([IF.SNS.post(S, pick([`{name} 장비 바꿨나? ${g.label} 확 좋아짐`, `{name} 새 ${g.label} 플렉스 ㅋㅋ`, `{name} 방송 퀄 점점 올라가네`]), "fan")]);
    toast(`${next.name} 설치 완료!`);
    room.burst("coin", 8);
    render();
    save();
    openShop("gear");
  }

  function buyDeco(d) {
    if (S.deco.includes(d.id) || S.money < d.price) return;
    S.money -= d.price;
    S.deco.push(d.id);
    log(`🛒 ${d.name} 구입! (-${shortWon(d.price)})`, "buy");
    toast(`${d.name}을(를) 방에 놓았어요`);
    render();
    save();
    openShop("deco");
  }

  // ───── 종료 ─────
  function checkOver() {
    if (S.ended) return true;
    if (S.heat >= 100) {
      finish("scandal");
      return true;
    }
    if (S.mental <= 0) {
      finish("burnout");
      return true;
    }
    return false;
  }

  function endingKey() {
    const f = S.followers;
    if (f >= 1000000) return S.image >= 0 ? "celeb_good" : "celeb_bad";
    if (f >= 100000) return "big";
    if (f >= 10000) return "mid";
    if (f >= 1000) return "small";
    return "zero";
  }

  async function finish(key = endingKey()) {
    S.ended = key;
    stopLive();
    closePhone();
    const e = IF.ENDINGS[key];
    const seen = storage.get(BEST_KEY, []);
    if (!seen.includes(key)) storage.set(BEST_KEY, [...seen, key]);
    storage.remove(SAVE_KEY);

    // 마지막 SNS 반응
    const topic = IF.SNS.topicFeed(S, {
      tag: key === "scandal" ? "{name}_자숙" : key === "burnout" ? "{name}_휴방" : "{name}_60일",
      headline: key === "scandal" ? "{name}, 잇단 논란에 결국 자숙 선언" : key === "burnout" ? "{name}, 건강 문제로 무기한 휴방" : `{name}, 방송 60일 만에 구독자 ${short(S.followers)}`,
      tone: key === "scandal" ? -0.5 : 0.5,
      hate: key === "scandal" ? ["자숙이 아니라 은퇴해라", "결국 이렇게 될 줄 알았다"] : ["별로 대단한 것도 아닌데"],
      shield: ["그동안 고생 많았어요", "{name} 꼭 다시 돌아와요", "덕분에 즐거웠다 진짜"],
      neutral: ["한 시대가 끝났다", "다음 행보가 궁금하다"],
    });
    pushTopic(topic);

    S.mode = key === "scandal" || key === "burnout" ? "away" : "live";
    renderHud();
    renderStage();
    $("actions").replaceChildren(
      h("button", { className: "act", onclick: () => openPhone("trend") }, h("span", { className: "act-icon", textContent: "📱" }), h("span", { className: "act-label", textContent: "마지막 반응 보기" })),
      h("button", { className: "act", onclick: () => location.reload() }, h("span", { className: "act-icon", textContent: "🔄" }), h("span", { className: "act-label", textContent: "새 게임" }))
    );

    const all = Object.keys(IF.ENDINGS);
    const got = storage.get(BEST_KEY, []);
    modal(
      h("p", { className: `ending-badge type-${e.type}`, textContent: "ENDING" }),
      h("h2", { textContent: e.title }),
      h("p", { className: "event-text", textContent: e.text }),
      h(
        "div",
        { className: "result-grid" },
        resultCell("구독자", short(S.followers)),
        resultCell("최고 시청자", `${short(S.stats.peak)}명`),
        resultCell("총 수입", shortWon(S.stats.earned)),
        resultCell("방송 횟수", `${S.stats.streams}회`),
        resultCell("이미지", imageText(S.image)),
        resultCell("진행 일수", `${Math.min(S.day, IF.SEASON_DAYS)}일`)
      ),
      h("p", { className: "muted small", textContent: `엔딩 도감 ${got.length} / ${all.length}` }),
      h(
        "div",
        { className: "modal-actions" },
        h("button", { className: "btn", textContent: "📱 마지막 반응 보기", onclick: () => (closeModal(), openPhone("trend")) }),
        h("button", { className: "btn", textContent: "🔗 공유하기", onclick: () => share(e) }),
        h("button", { className: "btn primary", textContent: "새 게임", onclick: () => location.reload() })
      )
    );
  }

  async function share(e) {
    const text = `[인플루언서 시뮬레이터] ${S.name}의 결말: ${e.title} — 구독자 ${short(S.followers)}명`;
    const url = location.href.split("#")[0];
    try {
      if (navigator.share) return await navigator.share({ title: "인플루언서 시뮬레이터", text, url });
      await navigator.clipboard.writeText(`${text}\n${url}`);
      toast("링크를 복사했어요");
    } catch (err) {
      if (err.name !== "AbortError") toast("공유하지 못했어요");
    }
  }

  // ───── 시작 화면 ─────
  const setup = { hair: HAIR[0], shirt: SHIRT[1], long: false, wall: WALLS[0] };

  function previewState() {
    return {
      ...newState("", setup),
      followers: 0,
      slot: 2,
      deco: ["neon", "plant", "rug"],
      gear: { camera: 0, mic: 0, light: 1, pc: 0 },
    };
  }

  function renderSwatches(id, colors, key) {
    $(id).replaceChildren(
      ...colors.map((c) =>
        h("button", {
          type: "button",
          className: `swatch ${setup[key] === c ? "active" : ""}`,
          style: `background:${c}`,
          ariaLabel: c,
          onclick: () => {
            setup[key] = c;
            renderSetup();
          },
        })
      )
    );
  }

  function renderSetup() {
    renderSwatches("sw-hair", HAIR, "hair");
    renderSwatches("sw-shirt", SHIRT, "shirt");
    document.querySelectorAll("#sw-style button").forEach((b) => b.classList.toggle("active", (b.dataset.long === "1") === setup.long));
    preview.update(previewState(), "live");
  }

  function showStart() {
    $("if-start").hidden = false;
    $("if-game").hidden = true;
    const saved = storage.get(SAVE_KEY, null);
    $("btn-continue").hidden = !saved;
    if (saved) $("btn-continue").textContent = `이어하기 · ${saved.name} D+${saved.day}`;
    const got = storage.get(BEST_KEY, []);
    $("ending-progress").textContent = got.length ? `엔딩 도감 ${got.length} / ${Object.keys(IF.ENDINGS).length} · ${got.map((k) => IF.ENDINGS[k].title).join(", ")}` : "";
    preview = new IF.Room($("preview"));
    renderSetup();
  }

  function startGame(state) {
    S = state;
    $("if-start").hidden = true;
    $("if-game").hidden = false;
    room = new IF.Room($("room"));
    render();
    save();
    window.scrollTo(0, 0);
  }

  $("sw-style").addEventListener("click", (e) => {
    const b = e.target.closest("button");
    if (!b) return;
    setup.long = b.dataset.long === "1";
    renderSetup();
  });

  $("if-setup").addEventListener("submit", async (e) => {
    e.preventDefault();
    const name = $("in-name").value.trim().slice(0, 10) || "방구석스타";
    if (storage.get(SAVE_KEY, null) && !confirm("저장된 게임이 사라져요. 새로 시작할까요?")) return;
    startGame(newState(name, { ...setup }));
    log("📱 스마트폰 하나로 방송을 시작했다. 목표: 60일 안에 셀럽 되기!", "day");
    render();
    await ask(
      `${name}의 방송 데뷔`,
      [
        h("p", { className: "event-text", textContent: "가진 건 스마트폰 한 대와 작은 원룸뿐. 방송으로 돈을 벌어 장비를 하나씩 맞춰 가세요." }),
        h(
          "ul",
          { className: "tips" },
          h("li", { textContent: "하루는 오전·오후·밤 세 번 행동할 수 있어요. 밤 방송이 시청자가 가장 많아요." }),
          h("li", { textContent: "돈이 없으면 편의점 알바! 장비를 사면 화질과 음질이 좋아져요." }),
          h("li", { textContent: "당신의 모든 행동은 SNS '버즈'에서 토론거리가 돼요. 📱를 눌러 반응을 확인하세요." }),
          h("li", { textContent: "논란이 100이 되거나 멘탈이 0이 되면 게임 오버예요." })
        ),
      ],
      [{ label: "방송 시작!", primary: true }]
    );
  });

  $("btn-continue").addEventListener("click", () => {
    const saved = storage.get(SAVE_KEY, null);
    if (!saved) return;
    saved.mode = "idle";
    startGame(saved);
  });

  $("btn-phone").addEventListener("click", () => openPhone("feed"));
  $("phone-close").addEventListener("click", closePhone);
  $("phone").addEventListener("click", (e) => {
    if (e.target === $("phone")) closePhone();
  });
  document.querySelectorAll(".phone-tabs button").forEach((b) =>
    b.addEventListener("click", () => {
      phoneTab = b.dataset.tab;
      phoneTopic = null;
      renderPhone();
    })
  );
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && !$("phone").hidden) closePhone();
  });

  showStart();
})();
