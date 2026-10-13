(() => {
  const { storage, $, el, toast } = Site;
  const PUZZLES = window.CROSSWORDS || [];
  const SAVE_KEY = "crossword:progress";
  const DIR_LABEL = { across: "가로", down: "세로" };

  // progress: { [퍼즐 번호]: { fills: { "r,c": "글자" }, hints, done } }
  let progress = storage.get(SAVE_KEY, {});
  let index = 0;
  let puzzle, cells, current; // cells: Map "r,c" -> { answer, entries: { across, down }, number }
  let activeCell = null;

  const key = (r, c) => `${r},${c}`;
  const cellsOf = (e) =>
    [...e.answer].map((_, i) => key(e.row + (e.dir === "down" ? i : 0), e.col + (e.dir === "across" ? i : 0)));
  const state = () => (progress[index] ??= { fills: {}, hints: 0, done: false });
  const save = () => storage.set(SAVE_KEY, progress);
  const isSolved = (e) => cellsOf(e).every((k, i) => state().fills[k] === e.answer[i]);

  function load(i) {
    index = i;
    puzzle = PUZZLES[index];
    cells = new Map();
    puzzle.entries.forEach((e) => {
      cellsOf(e).forEach((k, j) => {
        const cell = cells.get(k) || { answer: e.answer[j], entries: {} };
        cell.entries[e.dir] = e;
        if (j === 0) cell.number = e.n;
        cells.set(k, cell);
      });
    });
    current = puzzle.entries.find((e) => !isSolved(e)) || puzzle.entries[0];
    activeCell = cellsOf(current)[0];
    renderPicker();
    render();
  }

  // ───── 선택 ─────
  function selectCell(k) {
    const cell = cells.get(k);
    if (!cell) return;
    if (activeCell === k && cell.entries.across && cell.entries.down) {
      current = current.dir === "across" ? cell.entries.down : cell.entries.across;
    } else if (!cell.entries[current.dir] || !cellsOf(current).includes(k)) {
      current = cell.entries[current.dir] || cell.entries.across || cell.entries.down;
    }
    activeCell = k;
    render();
    focusInput();
  }

  function selectEntry(e) {
    current = e;
    activeCell = cellsOf(e)[0];
    render();
    focusInput();
  }

  function focusInput() {
    const input = $("cw-input");
    input.value = "";
    input.placeholder = `${current.answer.length}글자로 입력`;
    input.maxLength = current.answer.length + 2;
    input.focus({ preventScroll: true });
  }

  // ───── 입력 ─────
  function submit() {
    if (state().done) return;
    const syllables = [...$("cw-input").value].filter((ch) => /[가-힣]/.test(ch));
    if (!syllables.length) return;
    cellsOf(current).forEach((k, i) => {
      if (syllables[i]) state().fills[k] = syllables[i];
    });
    $("cw-input").value = "";
    save();
    if (checkDone()) return;
    // 다음 안 푼 단어로
    const list = puzzle.entries;
    const start = list.indexOf(current);
    const next = [...list.slice(start + 1), ...list.slice(0, start)].find((e) => !cellsOf(e).every((k) => state().fills[k]));
    if (next) selectEntry(next);
    else render();
  }

  function eraseWord() {
    cellsOf(current).forEach((k) => {
      // 다른 방향 단어가 이미 맞게 채워진 칸은 남김
      const other = cells.get(k).entries[current.dir === "across" ? "down" : "across"];
      if (!other || !isSolved(other)) delete state().fills[k];
    });
    save();
    render();
  }

  function hint() {
    if (state().done) return;
    const k = cellsOf(current).find((c) => state().fills[c] !== cells.get(c).answer);
    if (!k) {
      toast("이 단어는 이미 맞혔어요");
      return;
    }
    state().fills[k] = cells.get(k).answer;
    state().hints += 1;
    save();
    if (!checkDone()) render();
  }

  function check() {
    const wrong = [...cells.keys()].filter((k) => state().fills[k] && state().fills[k] !== cells.get(k).answer);
    render(new Set(wrong));
    const empty = [...cells.keys()].filter((k) => !state().fills[k]).length;
    toast(wrong.length ? `틀린 칸이 ${wrong.length}개 있어요` : empty ? `지금까지 모두 맞아요! 빈칸 ${empty}개` : "모두 맞아요!");
  }

  function checkDone() {
    const all = [...cells.entries()].every(([k, c]) => state().fills[k] === c.answer);
    if (!all || state().done) return false;
    state().done = true;
    save();
    renderPicker();
    render();
    toast("🎉 완성했어요!");
    return true;
  }

  // ───── 화면 ─────
  function renderPicker() {
    $("cw-picker").replaceChildren(
      ...PUZZLES.map((_, i) => {
        const b = el("button", { type: "button", textContent: `${i + 1}${progress[i]?.done ? " ✓" : ""}` });
        b.classList.toggle("active", i === index);
        b.addEventListener("click", () => load(i));
        return b;
      })
    );
  }

  function render(wrong = new Set()) {
    const grid = $("cw-grid");
    grid.style.setProperty("--cols", puzzle.cols);
    const inWord = new Set(cellsOf(current));
    const nodes = [];
    for (let r = 0; r < puzzle.rows; r++) {
      for (let c = 0; c < puzzle.cols; c++) {
        const k = key(r, c);
        const cell = cells.get(k);
        if (!cell) {
          nodes.push(el("div", { className: "cw-cell block" }));
          continue;
        }
        const btn = el("button", { type: "button", className: "cw-cell" });
        btn.dataset.k = k;
        if (inWord.has(k)) btn.classList.add("in-word");
        if (k === activeCell) btn.classList.add("active");
        if (wrong.has(k)) btn.classList.add("wrong");
        if (cell.number) btn.append(el("span", { className: "cw-num", textContent: cell.number }));
        btn.append(el("span", { className: "cw-letter", textContent: state().fills[k] || "" }));
        nodes.push(btn);
      }
    }
    grid.replaceChildren(...nodes);

    $("cw-clue").replaceChildren(
      el("strong", { textContent: `${DIR_LABEL[current.dir]} ${current.n}` }),
      ` ${current.clue} `,
      el("small", { textContent: `(${current.answer.length}글자)` })
    );

    ["across", "down"].forEach((dir) => {
      $(`cw-list-${dir}`).replaceChildren(
        ...puzzle.entries
          .filter((e) => e.dir === dir)
          .map((e) => {
            const li = el("li", {}, [el("strong", { textContent: `${e.n}. ` }), e.clue]);
            if (e === current) li.classList.add("current");
            if (isSolved(e)) li.classList.add("solved");
            li.addEventListener("click", () => selectEntry(e));
            return li;
          })
      );
    });

    const solved = puzzle.entries.filter(isSolved).length;
    $("cw-status").textContent = `${index + 1}번 문제 · ${solved}/${puzzle.entries.length} 단어 · 힌트 ${state().hints}`;
    $("cw-done").hidden = !state().done;
    const doneCount = PUZZLES.filter((_, i) => progress[i]?.done).length;
    $("cw-records").textContent = `${doneCount} / ${PUZZLES.length} 문제 완성`;
  }

  function share() {
    const doneCount = PUZZLES.filter((_, i) => progress[i]?.done).length;
    const text = state().done
      ? `십자말풀이 ${index + 1}번 문제를 완성했어요! (${doneCount}/${PUZZLES.length}) 같이 풀어 봐요!`
      : "가볍게 푸는 무료 십자말풀이. 같이 풀어 봐요!";
    Share.open({ title: "십자말풀이", text });
  }

  // ───── 이벤트 ─────
  $("cw-grid").addEventListener("click", (e) => {
    const btn = e.target.closest(".cw-cell[data-k]");
    if (btn) selectCell(btn.dataset.k);
  });
  $("cw-form").addEventListener("submit", (e) => {
    e.preventDefault();
    submit();
  });
  $("cw-check").addEventListener("click", check);
  $("cw-hint").addEventListener("click", hint);
  $("cw-erase").addEventListener("click", eraseWord);
  $("cw-next").addEventListener("click", () => load((index + 1) % PUZZLES.length));
  $("cw-share-result").addEventListener("click", share);
  $("btn-share").addEventListener("click", share);
  $("cw-reset").addEventListener("click", () => {
    if (!confirm(`${index + 1}번 문제를 처음부터 다시 풀까요?`)) return;
    progress[index] = { fills: {}, hints: 0, done: false };
    save();
    load(index);
  });

  Site.init({ current: "puzzle:crossword" });
  const firstUnsolved = PUZZLES.findIndex((_, i) => !progress[i]?.done);
  load(firstUnsolved < 0 ? 0 : firstUnsolved);
})();
