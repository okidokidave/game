(() => {
  const TESTS = window.TESTS || [];
  const { storage, $, el, renderArt } = Site;

  let TEST, KEY;
  let answers = []; // 고른 보기 (질문 순서대로)

  function show(id) {
    ["intro-screen", "question-screen", "result-screen"].forEach((s) => ($(s).hidden = s !== id));
    window.scrollTo(0, 0);
  }

  function load() {
    const id = location.hash.slice(1);
    TEST = TESTS.find((t) => t.id === id) || TESTS[0];
    KEY = `test:${TEST.id}:last`;
    Site.renderNav(`test:${TEST.id}`);
    Site.renderMore($("more-list"), `test:${TEST.id}`);
    renderIntro();
  }

  function renderIntro() {
    document.title = `${TEST.title} - 심리테스트`;
    $("page-title").textContent = TEST.title;
    $("page-intro").textContent = TEST.intro;
    renderArt($("intro-art"), TEST.cover);

    const last = storage.get(KEY, null);
    const lastResult = last && TEST.results[last];
    $("last-result").hidden = !lastResult;
    if (lastResult) {
      $("last-result").replaceChildren("지난 결과: ", el("button", { className: "link", textContent: `${lastResult.name} →` }));
      $("last-result").querySelector("button").addEventListener("click", () => renderResult(last));
    }
    show("intro-screen");
  }

  function start() {
    answers = [];
    renderQuestion();
  }

  function renderQuestion() {
    const i = answers.length;
    const { q, options } = TEST.questions[i];
    $("q-bar").style.width = `${(i / TEST.questions.length) * 100}%`;
    $("q-count").textContent = `${i + 1} / ${TEST.questions.length}`;
    $("q-text").textContent = q;
    $("q-feedback").hidden = true;
    $("btn-next").hidden = true;

    const buttons = options.map((opt) => {
      const btn = el("button", { className: "choice" }, [el("span", { textContent: opt.label })]);
      btn.addEventListener("click", () => {
        answers.push(opt);
        if (answers.length < TEST.questions.length) renderQuestion();
        else finish();
      });
      return btn;
    });
    // 이전 질문으로
    if (i > 0) {
      const back = el("button", { className: "link q-back", textContent: "← 이전 질문" });
      back.addEventListener("click", () => {
        answers.pop();
        renderQuestion();
      });
      buttons.push(back);
    }
    $("q-options").replaceChildren(...buttons);
    show("question-screen");
  }

  function tally() {
    const scores = Object.fromEntries(Object.keys(TEST.results).map((k) => [k, 0]));
    answers.forEach((a) => Object.entries(a.score).forEach(([k, v]) => (scores[k] += v)));
    return scores;
  }

  function finish() {
    const scores = tally();
    const max = Math.max(...Object.values(scores));
    const tied = Object.keys(scores).filter((k) => scores[k] === max);
    // 동점이면 마지막으로 고른 답의 결과를 우선
    const lastPick = Object.keys(answers[answers.length - 1].score).find((k) => tied.includes(k));
    const key = lastPick || tied[0];
    storage.set(KEY, key);
    renderResult(key, scores);
  }

  function renderResult(key, scores) {
    const r = TEST.results[key];
    renderArt($("result-art"), r.image);

    const body = [
      el("p", { className: "eyebrow", textContent: "나와 닮은 인물은" }),
      el("h2", { className: "result-name", textContent: r.name }),
      el("p", { className: "result-title", textContent: `“${r.title}” · ${r.summary}` }),
      ...r.desc.map((d) => el("p", { textContent: d })),
      el("h3", { textContent: "이런 특징이 있어요" }),
      el("ul", { className: "traits" }, r.traits.map((t) => el("li", { textContent: t }))),
      el("p", { className: "match", textContent: `잘 맞는 인물: ${r.match}` }),
    ];

    // 성분 분석 막대 (방금 푼 경우에만)
    if (scores) {
      const total = Object.values(scores).reduce((a, b) => a + b, 0) || 1;
      body.push(el("h3", { textContent: "나의 성분" }));
      body.push(
        el(
          "div",
          { className: "breakdown" },
          Object.entries(scores)
            .sort((a, b) => b[1] - a[1])
            .map(([k, v]) => {
              const pct = Math.round((v / total) * 100);
              const bar = el("span", { className: "bar" });
              bar.style.width = `${pct}%`;
              return el("div", { className: "breakdown-row" }, [
                el("span", { className: "breakdown-name", textContent: TEST.results[k].name }),
                el("span", { className: "breakdown-track" }, [bar]),
                el("span", { className: "breakdown-pct", textContent: `${pct}%` }),
              ]);
            })
        )
      );
    }
    $("result-body").replaceChildren(...body);

    const actions = [
      { label: r.cta.label, href: r.cta.href, primary: true },
      { label: "결과 공유하기", action: () => share(r) },
      { label: "다시 하기", action: start },
    ];
    $("result-actions").replaceChildren(
      ...actions.map((a) => {
        const node = a.href
          ? el("a", { className: "choice primary-choice", href: a.href }, [el("span", { textContent: a.label })])
          : el("button", { className: "choice" }, [el("span", { textContent: a.label })]);
        if (a.action) node.addEventListener("click", a.action);
        return node;
      })
    );
    show("result-screen");
  }

  function share(result) {
    const text = result
      ? `「${TEST.title}」 결과, 나는 “${result.title}” ${result.name}! 당신은 누구와 닮았을까요?`
      : `「${TEST.title}」 8개의 질문으로 알아보는 나와 닮은 인물. 같이 해 봐요!`;
    Share.open({ title: TEST.title, text, path: `#${TEST.id}` });
  }

  $("btn-start").addEventListener("click", start);
  $("btn-share").addEventListener("click", () => {
    const last = storage.get(KEY, null);
    share(last && TEST.results[last]);
  });
  window.addEventListener("hashchange", load);

  Site.init({ current: "" });
  if (TESTS.length === 0) {
    $("page-title").textContent = "심리테스트 준비 중";
    $("page-intro").textContent = "곧 새로운 테스트로 찾아올게요.";
    $("btn-start").hidden = true;
    $("btn-share").hidden = true;
    Site.renderNav("");
    return;
  }
  load();
})();
