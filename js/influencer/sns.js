/*
 * 인플루언서 시뮬레이터 — 가상 SNS "버즈"
 *
 * 플레이어의 행동마다 글과 댓글 토론을 만들어 냅니다.
 * tone(-1 ~ 1)과 플레이어의 이미지에 따라 악플과 쉴드의 비율이 달라집니다.
 */
(() => {
  const rand = (a, b) => a + Math.random() * (b - a);
  const pick = (arr) => arr[Math.floor(Math.random() * arr.length)];
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

  const NICK_A = ["새벽", "치킨", "감자", "고양이", "월요일", "퇴근", "라면", "방구석", "분노의", "행복한", "졸린", "배고픈", "익명의", "눈팅", "프로", "야식", "민초", "출근", "주말", "솔직한", "지나가던", "댓글", "팝콘", "현실"];
  const NICK_B = ["러버", "요정", "장인", "집사", "중독자", "전문가", "1호팬", "고인물", "뉴비", "학생", "직장인", "탐정", "수집가", "관찰자", "백수", "토끼", "곰", "판사", "평론가", "참견러"];
  const HANDLE = ["daily", "real", "just", "im", "the", "mr", "ms", "lazy", "night", "pop", "hot", "cool", "zz", "yolo", "nope", "kkk"];
  const ROMAN = ["potato", "cat", "ramen", "chicken", "bear", "toki", "mango", "kimchi", "sky", "moon", "pudding", "mint", "duck", "star"];
  const COLORS = ["#ff8a65", "#ffb74d", "#81c784", "#4fc3f7", "#9575cd", "#f06292", "#a1887f", "#4db6ac", "#e57373", "#7986cb"];

  const SIDE_TAG = { hate: "까", shield: "쉴드", neutral: "", fan: "팬" };

  function user() {
    const nick = pick(NICK_A) + pick(NICK_B) + (Math.random() < 0.3 ? Math.floor(rand(1, 99)) : "");
    const handle = `${pick(HANDLE)}_${pick(ROMAN)}${Math.random() < 0.6 ? Math.floor(rand(1, 999)) : ""}`;
    return { nick, handle, color: pick(COLORS) };
  }

  const fill = (text, s) => text.replace(/\{name\}/g, s.name);

  // 구독자에 비례한 반응 수
  function reach(s, mult = 1) {
    return Math.max(0, Math.round((2 + Math.pow(s.followers, 0.82) * 0.06) * mult * rand(0.4, 1.6)));
  }

  function post(s, text, side, opts = {}) {
    const u = opts.user || user();
    const likes = reach(s, opts.boost || 1);
    return {
      id: Math.random().toString(36).slice(2, 9),
      ...u,
      text: fill(text, s),
      side,
      likes,
      reposts: Math.round(likes * rand(0.05, 0.4)),
      day: s.day,
      slot: s.slot,
      replies: [],
      news: !!opts.news,
    };
  }

  // tone과 이미지로 악플/쉴드 비율 결정
  function sideFor(tone, s) {
    const t = clamp(tone + s.image / 160, -1, 1);
    if (Math.random() < 0.18) return "neutral";
    return Math.random() < (t + 1) / 2 ? "shield" : "hate";
  }

  // 같은 토론 안에서 같은 문구가 반복되지 않게 used에 기록
  function lineFor(side, topic, used) {
    const own = (topic && topic[side]) || [];
    const pools = [own.filter((l) => !used.has(l)), IF.SNS_POOL[side].filter((l) => !used.has(l))];
    let pool = pools[0].length && (Math.random() < 0.7 || !pools[1].length) ? pools[0] : pools[1];
    if (!pool.length) pool = own.length ? own : IF.SNS_POOL[side];
    const line = pick(pool);
    used.add(line);
    return line;
  }

  // 주제(이벤트 선택)에 대한 토론 피드
  function topicFeed(s, topic) {
    const tag = fill(topic.tag, s);
    const posts = [];
    const used = new Set();

    // 이슈 정리 글 + 댓글 토론
    const main = post(s, topic.headline, "neutral", {
      news: true,
      boost: 3,
      user: { nick: pick(["이슈정리봇", "실시간 이슈", "방송계 소식통", "커뮤 요약러"]), handle: pick(["issue_bot", "live_issue", "stream_news", "comm_digest"]), color: "#546e7a" },
    });
    main.text = `[이슈] ${main.text} #${tag}`;
    const nReplies = 4 + Math.floor(Math.random() * 3);
    let prev = null;
    for (let i = 0; i < nReplies; i++) {
      // 앞 댓글과 반대 진영이 답하는 경우가 많게 → 토론처럼 보이게
      let side = sideFor(topic.tone, s);
      if (prev && prev !== "neutral" && Math.random() < 0.55) side = prev === "hate" ? "shield" : "hate";
      const reply = post(s, lineFor(side, topic, used), side, { boost: 0.4 });
      if (prev && side !== "neutral" && prev !== side && prev !== "neutral" && Math.random() < 0.6) reply.replyTo = main.replies[main.replies.length - 1].nick;
      main.replies.push(reply);
      prev = side;
    }
    posts.push(main);

    const n = 4 + Math.floor(Math.random() * 3);
    for (let i = 0; i < n; i++) {
      const side = sideFor(topic.tone, s);
      const p = post(s, lineFor(side, topic, used), side);
      if (Math.random() < 0.6) p.text += ` #${tag}`;
      if (Math.random() < 0.35) {
        const opp = side === "hate" ? "shield" : side === "shield" ? "hate" : sideFor(topic.tone, s);
        p.replies.push(post(s, lineFor(opp, topic, used), opp, { boost: 0.3 }));
      }
      posts.push(p);
    }

    const shield = posts.concat(posts.flatMap((p) => p.replies)).filter((p) => p.side === "shield").length;
    const hate = posts.concat(posts.flatMap((p) => p.replies)).filter((p) => p.side === "hate").length;
    return { tag, posts, shield, hate, headline: fill(topic.headline, s) };
  }

  // 평범한 방송 후 올라오는 글 몇 개
  function streamPosts(s, content, flags) {
    const S = IF.SNS_STREAM;
    const out = [];
    const n = flags.viral ? 4 : 1 + Math.floor(Math.random() * 2);
    for (let i = 0; i < n; i++) {
      const pool = flags.viral && i < 2 ? S.viral : flags.flop && i === 0 ? S.flop : S[content.id];
      out.push(post(s, pick(pool), flags.flop && i === 0 ? "hate" : "fan", { boost: flags.viral ? 4 : 1 }));
    }
    // 장비가 부족하면 지적하는 글
    if (s.gear.camera === 0 && Math.random() < 0.45) out.push(post(s, pick(S.lowcam), "neutral"));
    else if (s.gear.mic === 0 && Math.random() < 0.45) out.push(post(s, pick(S.lowmic), "neutral"));
    else if (s.gear.light === 0 && Math.random() < 0.35) out.push(post(s, pick(S.dark), "neutral"));
    return out;
  }

  function milestonePosts(s, at) {
    return (IF.SNS_MILESTONE[at] || []).map((t) => post(s, t, "fan", { boost: 2 }));
  }

  function trendingFor(s) {
    const tags = [];
    (s.trends || []).slice(-4).reverse().forEach((t) => tags.push(t));
    return tags;
  }

  IF.SNS = { topicFeed, streamPosts, milestonePosts, trendingFor, post, user, SIDE_TAG };
})();
