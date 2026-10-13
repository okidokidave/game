(() => {
  const QUIZZES = window.QUIZZES || [];
  const { storage, $, el, renderArt } = Site;

  let QUIZ, KEY;
  let round = []; // [{ q, options(섞인 순서), answer(섞인 뒤 정답 위치), explain, picked }]
  let index = 0;

  const shuffle = (arr) => {
    const a = [...arr];
    for (let i = a.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [a[i], a[j]] = [a[j], a[i]];
    }
    return a;
  };

  function show(id) {
    ["intro-screen", "question-screen", "result-screen"].forEach((s) => ($(s).hidden = s !== id));
    window.scrollTo(0, 0);
  }

  function load() {
    const id = location.hash.slice(1);
    QUIZ = QUIZZES.find((q) => q.id === id) || QUIZZES[0];
    KEY = `quiz:${QUIZ.id}:best`;
    Site.renderNav(`quiz:${QUIZ.id}`);
    Site.renderMore($("more-list"), `quiz:${QUIZ.id}`);
    renderIntro();
  }

  function renderIntro() {
    document.title = `${QUIZ.title} | 틈놀`;
    $("page-title").textContent = QUIZ.title;
    $("page-intro").textContent = QUIZ.intro;
    renderArt($("intro-art"), QUIZ.cover);
    const best = storage.get(KEY, null);
    $("last-result").hidden = best === null;
    $("last-result").textContent = best === null ? "" : `내 최고 점수: ${best} / ${QUIZ.count}`;
    show("intro-screen");
  }

  function start() {
    round = shuffle(QUIZ.pool)
      .slice(0, QUIZ.count)
      .map((item) => {
        const order = shuffle(item.options.map((_, i) => i));
        return {
          ...item,
          options: order.map((i) => item.options[i]),
          answer: order.indexOf(item.answer),
          picked: null,
        };
      });
    index = 0;
    renderQuestion();
  }

  // 문제 속 ___ 자리를 강조해서 보여 줌
  function questionNode(item, fill) {
    const [before, after = ""] = item.q.split("___");
    const blank = el("span", { className: "blank", textContent: fill ?? "　　" });
    return [before, blank, after];
  }

  function renderQuestion() {
    const item = round[index];
    $("q-bar").style.width = `${(index / round.length) * 100}%`;
    $("q-count").textContent = `${index + 1} / ${round.length}`;
    $("q-text").replaceChildren(...questionNode(item));
    $("q-feedback").hidden = true;
    $("btn-next").hidden = true;

    $("q-options").replaceChildren(
      ...item.options.map((label, i) => {
        const btn = el("button", { className: "choice quiz-option" }, [el("span", { textContent: label })]);
        btn.addEventListener("click", () => answer(i));
        return btn;
      })
    );
    show("question-screen");
  }

  function answer(i) {
    const item = round[index];
    if (item.picked !== null) return;
    item.picked = i;
    const correct = i === item.answer;

    $("q-text").replaceChildren(...questionNode(item, item.options[item.answer]));
    [...$("q-options").children].forEach((btn, j) => {
      btn.disabled = true;
      if (j === item.answer) btn.classList.add("correct");
      else if (j === i) btn.classList.add("wrong");
    });

    const fb = $("q-feedback");
    fb.className = `q-feedback ${correct ? "ok" : "no"}`;
    fb.replaceChildren(el("strong", { textContent: correct ? "⭕ 정답!" : "❌ 아쉬워요" }), el("p", { textContent: item.explain }));
    fb.hidden = false;

    const next = $("btn-next");
    next.textContent = index + 1 < round.length ? "다음 문제" : "결과 보기";
    next.hidden = false;
    next.focus({ preventScroll: true });
  }

  function nextQuestion() {
    index += 1;
    if (index < round.length) renderQuestion();
    else finish();
  }

  function finish() {
    const score = round.filter((r) => r.picked === r.answer).length;
    const best = storage.get(KEY, null);
    const isBest = best === null || score > best;
    if (isBest) storage.set(KEY, score);
    renderResult(score, isBest && best !== null);
  }

  function renderResult(score, newBest) {
    const grade = QUIZ.grades.find((g) => score >= g.min);
    renderArt($("result-art"), QUIZ.cover);

    const wrong = round.filter((r) => r.picked !== r.answer);
    const body = [
      el("p", { className: "eyebrow", textContent: QUIZ.title }),
      el("h2", { className: "result-name", textContent: `${score} / ${round.length}점` }),
      el("p", { className: "result-title", textContent: grade.title }),
      el("p", { textContent: grade.desc }),
    ];
    if (newBest) body.push(el("p", { className: "gain", textContent: "🎉 최고 점수 갱신!" }));
    if (wrong.length) {
      body.push(el("h3", { textContent: "틀린 문제 다시 보기" }));
      body.push(
        el(
          "ul",
          { className: "review" },
          wrong.map((r) =>
            el("li", {}, [
              el("p", { className: "review-q" }, questionNode(r, r.options[r.answer])),
              el("p", { className: "review-a", textContent: `정답: ${r.options[r.answer]} · 내 답: ${r.options[r.picked]}` }),
              el("p", { className: "review-e", textContent: r.explain }),
            ])
          )
        )
      );
    }
    $("result-body").replaceChildren(...body);

    const actions = [
      { label: "결과 공유하기", action: () => share(score, grade) },
      { label: "새 문제로 다시 풀기", action: start },
      ...SITE_CATALOG.filter((c) => c.type !== "quiz")
        .slice(0, 1)
        .map((c) => ({ label: `${CATALOG_LABELS[c.type]} 「${c.title}」 하러 가기`, href: c.href })),
    ];
    $("result-actions").replaceChildren(
      ...actions.map((a) => {
        const node = a.href
          ? el("a", { className: "choice", href: a.href }, [el("span", { textContent: a.label })])
          : el("button", { className: "choice" }, [el("span", { textContent: a.label })]);
        if (a.action) node.addEventListener("click", a.action);
        return node;
      })
    );
    show("result-screen");
  }

  function share(score, grade) {
    const text =
      score === undefined
        ? `「${QUIZ.title}」 ${QUIZ.count}문제, 몇 개나 맞힐 수 있을까요?`
        : `「${QUIZ.title}」 ${score}/${QUIZ.count}점! 나는 ${grade.title} 당신은 몇 점?`;
    Share.open({ title: QUIZ.title, text, path: `#${QUIZ.id}` });
  }

  $("btn-start").addEventListener("click", start);
  $("btn-next").addEventListener("click", nextQuestion);
  $("btn-share").addEventListener("click", () => share());
  window.addEventListener("hashchange", load);

  Site.init({ current: "" });
  load();
})();
