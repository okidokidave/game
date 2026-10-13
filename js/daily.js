/*
 * 매일 바뀌는 콘텐츠: 오늘의 운세, 오늘의 맞춤법
 * 운세는 날짜와 기기마다 다르게 정해지고, 같은 날에는 다시 봐도 같은 결과가 나옵니다.
 * 운세 문구·색·물건을 늘리려면 아래 목록에 추가하면 됩니다.
 */
const Daily = (() => {
  const { storage, el } = Site;

  const FORTUNE = {
    messages: [
      "작은 친절이 큰 행운으로 돌아오는 날이에요.",
      "미뤄 둔 일을 시작하기 좋은 날. 첫걸음이 생각보다 가벼워요.",
      "뜻밖의 연락이 반가운 소식을 가져올 수 있어요.",
      "오늘은 서두르지 않는 것이 이기는 방법이에요.",
      "평소와 다른 길로 가 보세요. 작은 발견이 기다리고 있어요.",
      "웃을 일이 많은 하루. 그 웃음을 주변에도 나눠 주세요.",
      "계획대로 되지 않아도 괜찮아요. 오히려 더 나은 길이 열려요.",
      "집중력이 빛나는 날. 어려운 문제도 술술 풀려요.",
      "말 한마디가 분위기를 바꿔요. 칭찬을 아끼지 마세요.",
      "혼자만의 시간이 에너지를 채워 주는 날이에요.",
      "오래된 친구가 떠오르는 날. 먼저 안부를 물어보세요.",
      "잊고 있던 물건이나 생각을 다시 찾게 될 수 있어요.",
      "몸을 조금 더 움직이면 기분도 함께 가벼워져요.",
      "새로운 걸 배우기 딱 좋은 날이에요.",
      "고민하던 일의 답이 의외의 곳에서 나와요.",
      "작은 성공이 이어지는 날. 스스로를 칭찬해 주세요.",
      "마음이 넉넉해지는 하루. 양보가 행운을 불러와요.",
      "조금 느긋해도 괜찮아요. 쉬어 가는 것도 실력이에요.",
      "오늘 시작한 일은 끝까지 해낼 힘이 있어요.",
      "맛있는 음식 한 끼가 하루를 완성해 줄 거예요.",
      "주변을 정리하면 운이 트이는 날이에요.",
      "직감을 믿어 보세요. 오늘은 감이 좋아요.",
      "도움을 받고, 또 도움을 주게 되는 날이에요.",
      "평범한 하루 속에 소소한 행복이 숨어 있어요.",
      "도전하기 좋은 날! 망설이던 일을 한번 해 보세요.",
      "생각지 못한 칭찬을 듣게 될지도 몰라요.",
      "차분하게 하나씩 해 나가면 모든 게 제자리를 찾아요.",
      "기분 좋은 음악 한 곡이 오늘의 행운을 열어 줘요.",
      "오늘의 작은 실수는 내일의 즐거운 이야깃거리가 될 거예요.",
      "가벼운 산책이 좋은 생각을 데려와요.",
    ],
    colors: [
      ["하늘색", "#7cc4fa"], ["연두색", "#9be15d"], ["노란색", "#ffd43b"], ["보라색", "#9775fa"],
      ["주황색", "#ff922b"], ["분홍색", "#f783ac"], ["하얀색", "#f8f9fa"], ["남색", "#364fc7"],
      ["민트색", "#63e6be"], ["베이지색", "#e9d8b4"],
    ],
    items: ["텀블러", "손수건", "이어폰", "볼펜", "운동화", "우산", "책 한 권", "초콜릿", "열쇠고리", "머리끈", "수첩", "따뜻한 차"],
  };

  // 오늘 날짜(현지 시간 기준) 번호
  const today = () => Math.floor((Date.now() - new Date().getTimezoneOffset() * 60000) / 86400000);

  // 날짜 + 기기별 고유값으로 정해지는 난수
  function rng(seedText) {
    let h = 1779033703 ^ seedText.length;
    for (let i = 0; i < seedText.length; i++) {
      h = Math.imul(h ^ seedText.charCodeAt(i), 3432918353);
      h = (h << 13) | (h >>> 19);
    }
    return () => {
      h = Math.imul(h ^ (h >>> 16), 2246822507);
      h = Math.imul(h ^ (h >>> 13), 3266489909);
      return ((h ^= h >>> 16) >>> 0) / 4294967296;
    };
  }

  function fortuneFor(day) {
    let salt = storage.get("fortune:salt", null);
    if (!salt) {
      salt = Math.random().toString(36).slice(2);
      storage.set("fortune:salt", salt);
    }
    const r = rng(`${day}:${salt}`);
    const pick = (arr) => arr[Math.floor(r() * arr.length)];
    const stars = [3, 3, 4, 4, 4, 5, 5, 2][Math.floor(r() * 8)];
    const content = pick(SITE_CATALOG);
    const tips = {
      puzzle: `머리가 맑은 날, ${content.title} 한 판 어때요?`,
      quiz: `${content.title}로 실력을 확인해 보세요.`,
      story: `「${content.title}」에서 오늘의 운을 시험해 보세요.`,
      test: `${content.title}로 나를 알아보세요.`,
    };
    return {
      stars,
      message: pick(FORTUNE.messages),
      color: pick(FORTUNE.colors),
      number: 1 + Math.floor(r() * 45),
      item: pick(FORTUNE.items),
      content,
      tip: tips[content.type],
    };
  }

  function fortuneWidget({ compact = false } = {}) {
    const day = today();
    const wrap = el("div", { className: "fortune" });
    const draw = () => {
      const opened = storage.get("fortune:opened", null) === day;
      if (!opened) {
        const btn = el("button", { className: "btn primary fortune-open", type: "button", textContent: "🔮 오늘의 운세 보기" });
        btn.addEventListener("click", () => {
          storage.set("fortune:opened", day);
          draw();
          // 같은 페이지의 다른 운세 칸도 함께 갱신
          document.dispatchEvent(new CustomEvent("fortune:opened"));
        });
        wrap.replaceChildren(el("p", { className: "fortune-lead", textContent: "하루에 한 번, 오늘의 기운을 확인해 보세요." }), btn);
        return;
      }
      const f = fortuneFor(day);
      const swatch = el("span", { className: "swatch" });
      swatch.style.background = f.color[1];
      const parts = [
        el("p", { className: "fortune-stars", textContent: "★".repeat(f.stars) + "☆".repeat(5 - f.stars) }),
        el("p", { className: "fortune-msg", textContent: f.message }),
        el("dl", { className: "fortune-luck" }, [
          el("dt", { textContent: "행운의 색" }), el("dd", {}, [swatch, f.color[0]]),
          el("dt", { textContent: "행운의 숫자" }), el("dd", { textContent: f.number }),
          el("dt", { textContent: "행운의 물건" }), el("dd", { textContent: f.item }),
        ]),
        el("a", { className: "fortune-tip", href: f.content.href, textContent: `${f.content.icon || ""} ${f.tip} →` }),
      ];
      if (!compact) {
        const share = el("button", { className: "link fortune-share", type: "button", textContent: "📤 운세 공유하기" });
        share.addEventListener("click", () =>
          Share.open({ title: "오늘의 운세", text: `오늘 나의 운세 ${"★".repeat(f.stars)} "${f.message}" 행운의 색은 ${f.color[0]}! 당신의 운세는?` })
        );
        parts.push(share);
      }
      wrap.replaceChildren(...parts);
    };
    document.addEventListener("fortune:opened", draw);
    draw();
    return wrap;
  }

  function spellingWidget() {
    const quiz = (window.QUIZZES || [])[0];
    if (!quiz) return null;
    const day = today();
    const item = quiz.pool[day % quiz.pool.length];
    const stateKey = "daily:answer";
    // 날마다 보기 순서를 바꿔 정답 위치를 외우지 못하게
    const order = day % 2 ? [1, 0] : [0, 1];

    const wrap = el("div", { className: "daily" });
    const draw = () => {
      const saved = storage.get(stateKey, null);
      const picked = saved?.day === day ? saved.picked : null;
      const [before, after = ""] = item.q.split("___");
      const blank = el("span", { className: "blank", textContent: picked === null ? "　　" : item.options[item.answer] });
      const buttons = order.map((i) => {
        const b = el("button", { className: "daily-opt", type: "button", textContent: item.options[i] });
        if (picked !== null) {
          b.disabled = true;
          if (i === item.answer) b.classList.add("correct");
          else if (i === picked) b.classList.add("wrong");
        }
        b.addEventListener("click", () => {
          storage.set(stateKey, { day, picked: i });
          document.dispatchEvent(new CustomEvent("daily:answered"));
        });
        return b;
      });
      const parts = [el("p", { className: "daily-q" }, [before, blank, after]), el("div", { className: "daily-opts" }, buttons)];
      if (picked !== null) {
        parts.push(el("p", { className: "daily-explain", textContent: `${picked === item.answer ? "⭕ 정답!" : "❌ 아쉬워요."} ${item.explain}` }));
        parts.push(el("a", { className: "daily-more", href: `quiz.html#${quiz.id}`, textContent: `${quiz.count}문제 더 풀어 보기 →` }));
      }
      wrap.replaceChildren(...parts);
    };
    document.addEventListener("daily:answered", draw);
    draw();
    return wrap;
  }

  return { fortuneWidget, spellingWidget };
})();
