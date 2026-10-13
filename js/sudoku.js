(() => {
  const { storage, $, el, toast } = Site;
  const SAVE_KEY = "sudoku:current";
  const BEST_KEY = "sudoku:best";
  const LEVELS = {
    easy: { label: "쉬움", givens: 40 },
    medium: { label: "보통", givens: 32 },
    hard: { label: "어려움", givens: 26 },
  };

  // ───── 퍼즐 생성 ─────
  const ROW = (i) => Math.floor(i / 9);
  const COL = (i) => i % 9;
  const BOX = (i) => Math.floor(ROW(i) / 3) * 3 + Math.floor(COL(i) / 3);
  const PEERS = Array.from({ length: 81 }, (_, i) => {
    const set = new Set();
    for (let j = 0; j < 81; j++) {
      if (j !== i && (ROW(j) === ROW(i) || COL(j) === COL(i) || BOX(j) === BOX(i))) set.add(j);
    }
    return [...set];
  });
  const shuffle = (arr) => {
    const a = [...arr];
    for (let i = a.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [a[i], a[j]] = [a[j], a[i]];
    }
    return a;
  };

  function candidates(grid, i) {
    let mask = 0x3fe; // 1~9
    for (const p of PEERS[i]) if (grid[p]) mask &= ~(1 << grid[p]);
    return mask;
  }

  // 해의 개수를 limit까지만 셈 (유일해 확인용)
  function countSolutions(grid, limit = 2) {
    let best = -1;
    let bestMask = 0;
    let bestCount = 10;
    for (let i = 0; i < 81; i++) {
      if (grid[i]) continue;
      const mask = candidates(grid, i);
      const count = popcount(mask);
      if (count === 0) return 0;
      if (count < bestCount) {
        best = i;
        bestMask = mask;
        bestCount = count;
        if (count === 1) break;
      }
    }
    if (best === -1) return 1;
    let total = 0;
    for (let d = 1; d <= 9; d++) {
      if (!(bestMask & (1 << d))) continue;
      grid[best] = d;
      total += countSolutions(grid, limit - total);
      grid[best] = 0;
      if (total >= limit) break;
    }
    return total;
  }

  function popcount(m) {
    let c = 0;
    while (m) {
      m &= m - 1;
      c++;
    }
    return c;
  }

  function fillGrid(grid, i = 0) {
    if (i === 81) return true;
    if (grid[i]) return fillGrid(grid, i + 1);
    const mask = candidates(grid, i);
    for (const d of shuffle([1, 2, 3, 4, 5, 6, 7, 8, 9])) {
      if (!(mask & (1 << d))) continue;
      grid[i] = d;
      if (fillGrid(grid, i + 1)) return true;
    }
    grid[i] = 0;
    return false;
  }

  function generate(level) {
    const solution = new Array(81).fill(0);
    fillGrid(solution);
    const puzzle = [...solution];
    let givens = 81;
    // 대칭으로 지워서 보기 좋은 모양을 만듦
    for (const i of shuffle([...Array(41).keys()])) {
      if (givens <= LEVELS[level].givens) break;
      const pair = [i, 80 - i];
      const saved = pair.map((p) => puzzle[p]);
      pair.forEach((p) => (puzzle[p] = 0));
      if (countSolutions([...puzzle]) !== 1) pair.forEach((p, k) => (puzzle[p] = saved[k]));
      else givens -= i === 40 ? 1 : 2;
    }
    return { puzzle, solution };
  }

  // ───── 상태 ─────
  // game: { level, puzzle, solution, values, notes, mistakes, hints, elapsed, history, done }
  let game = null;
  let selected = -1;
  let noteMode = false;
  let timer = null;

  const save = () => storage.set(SAVE_KEY, game);

  function newGame(level = game?.level || "easy") {
    const { puzzle, solution } = generate(level);
    game = {
      level,
      puzzle,
      solution,
      values: [...puzzle],
      notes: new Array(81).fill(0),
      mistakes: 0,
      hints: 0,
      elapsed: 0,
      history: [],
      done: false,
    };
    selected = puzzle.findIndex((v) => !v);
    save();
    render();
    startTimer();
  }

  function startTimer() {
    clearInterval(timer);
    timer = setInterval(() => {
      if (!game || game.done || document.hidden) return;
      game.elapsed += 1;
      $("sd-time").textContent = formatTime(game.elapsed);
      if (game.elapsed % 5 === 0) save();
    }, 1000);
  }

  const formatTime = (s) => `${String(Math.floor(s / 60)).padStart(2, "0")}:${String(s % 60).padStart(2, "0")}`;

  // ───── 입력 ─────
  function input(d) {
    if (!game || game.done || selected < 0 || game.puzzle[selected]) return;
    const i = selected;
    game.history.push({ i, value: game.values[i], notes: game.notes[i] });

    if (noteMode && d) {
      if (game.values[i]) return;
      game.notes[i] ^= 1 << d;
    } else {
      game.values[i] = game.values[i] === d ? 0 : d;
      game.notes[i] = 0;
      if (d && game.values[i] === d) {
        if (d !== game.solution[i]) {
          game.mistakes += 1;
        } else {
          // 같은 줄·칸·상자의 메모에서 이 숫자를 지움
          PEERS[i].forEach((p) => (game.notes[p] &= ~(1 << d)));
        }
      }
    }
    save();
    render();
    checkDone();
  }

  function erase() {
    if (!game || game.done || selected < 0 || game.puzzle[selected]) return;
    if (!game.values[selected] && !game.notes[selected]) return;
    game.history.push({ i: selected, value: game.values[selected], notes: game.notes[selected] });
    game.values[selected] = 0;
    game.notes[selected] = 0;
    save();
    render();
  }

  function undo() {
    if (!game || game.done) return;
    const h = game.history.pop();
    if (!h) return;
    game.values[h.i] = h.value;
    game.notes[h.i] = h.notes;
    selected = h.i;
    save();
    render();
  }

  function hint() {
    if (!game || game.done) return;
    let i = selected;
    if (i < 0 || game.puzzle[i] || game.values[i] === game.solution[i]) {
      i = game.values.findIndex((v, k) => v !== game.solution[k]);
    }
    if (i < 0) return;
    game.history.push({ i, value: game.values[i], notes: game.notes[i] });
    game.values[i] = game.solution[i];
    game.notes[i] = 0;
    game.hints += 1;
    selected = i;
    save();
    render();
    checkDone();
  }

  function checkDone() {
    if (game.values.some((v, i) => v !== game.solution[i])) return;
    game.done = true;
    const best = storage.get(BEST_KEY, {});
    const prev = best[game.level];
    const record = !prev || game.elapsed < prev.time;
    best[game.level] = {
      time: record ? game.elapsed : prev.time,
      count: (prev?.count || 0) + 1,
    };
    storage.set(BEST_KEY, best);
    save();
    render();
    toast(record ? "🎉 최고 기록이에요!" : "🎉 완성!");
  }

  // ───── 화면 ─────
  function render() {
    const sel = selected;
    const selValue = sel >= 0 ? game.values[sel] : 0;
    const counts = new Array(10).fill(0);
    game.values.forEach((v, i) => v && v === game.solution[i] && counts[v]++);

    $("sd-grid").replaceChildren(
      ...game.values.map((v, i) => {
        const cell = el("button", { className: "sd-cell", type: "button" });
        cell.dataset.i = i;
        if (game.puzzle[i]) cell.classList.add("given");
        if (sel >= 0 && i !== sel && (ROW(i) === ROW(sel) || COL(i) === COL(sel) || BOX(i) === BOX(sel))) cell.classList.add("peer");
        if (selValue && v === selValue) cell.classList.add("same");
        if (i === sel) cell.classList.add("selected");
        if (v && v !== game.solution[i]) cell.classList.add("wrong");
        if (COL(i) % 3 === 2 && COL(i) !== 8) cell.classList.add("br");
        if (ROW(i) % 3 === 2 && ROW(i) !== 8) cell.classList.add("bb");

        if (v) {
          cell.textContent = v;
        } else if (game.notes[i]) {
          const notes = el("span", { className: "sd-notes" });
          for (let d = 1; d <= 9; d++) notes.append(el("span", { textContent: game.notes[i] & (1 << d) ? d : "" }));
          cell.append(notes);
        }
        cell.setAttribute("aria-label", `${ROW(i) + 1}행 ${COL(i) + 1}열 ${v || "빈칸"}`);
        return cell;
      })
    );

    $("sd-pad").replaceChildren(
      ...[1, 2, 3, 4, 5, 6, 7, 8, 9].map((d) => {
        const b = el("button", { className: "sd-num", type: "button" }, [
          el("strong", { textContent: d }),
          el("small", { textContent: 9 - counts[d] || "" }),
        ]);
        b.disabled = counts[d] >= 9 || game.done;
        b.addEventListener("click", () => input(d));
        return b;
      })
    );

    $("sd-level").textContent = LEVELS[game.level].label;
    $("sd-mistakes").textContent = `실수 ${game.mistakes}`;
    $("sd-time").textContent = formatTime(game.elapsed);
    $("sd-note").classList.toggle("on", noteMode);
    $("sd-note").textContent = noteMode ? "✏️ 메모 켜짐" : "✏️ 메모";
    document.querySelectorAll("[data-level]").forEach((b) => b.classList.toggle("active", b.dataset.level === game.level));

    const donePanel = $("sd-done");
    donePanel.hidden = !game.done;
    if (game.done) {
      $("sd-done-text").textContent = `${LEVELS[game.level].label} · ${formatTime(game.elapsed)} · 실수 ${game.mistakes} · 힌트 ${game.hints}`;
    }
    renderRecords();
  }

  function renderRecords() {
    const best = storage.get(BEST_KEY, {});
    $("sd-records").replaceChildren(
      ...Object.entries(LEVELS).map(([k, l]) =>
        el("div", { className: "record-row" }, [
          el("span", { textContent: l.label }),
          el("strong", { textContent: best[k] ? formatTime(best[k].time) : "-" }),
          el("small", { textContent: best[k] ? `${best[k].count}번 완성` : "" }),
        ])
      )
    );
  }

  function share() {
    const text = game?.done
      ? `스도쿠 ${LEVELS[game.level].label} 난이도를 ${formatTime(game.elapsed)}만에 풀었어요! 당신은 몇 분?`
      : "매번 새로운 문제가 나오는 무료 스도쿠. 같이 풀어 봐요!";
    Share.open({ title: "스도쿠", text });
  }

  // ───── 이벤트 ─────
  $("sd-grid").addEventListener("click", (e) => {
    const cell = e.target.closest(".sd-cell");
    if (!cell) return;
    selected = Number(cell.dataset.i);
    render();
  });
  $("sd-erase").addEventListener("click", erase);
  $("sd-undo").addEventListener("click", undo);
  $("sd-hint").addEventListener("click", hint);
  $("sd-note").addEventListener("click", () => {
    noteMode = !noteMode;
    render();
  });
  $("sd-new").addEventListener("click", () => newGame());
  $("sd-again").addEventListener("click", () => newGame());
  $("sd-share-result").addEventListener("click", share);
  $("btn-share").addEventListener("click", share);
  document.querySelectorAll("[data-level]").forEach((b) =>
    b.addEventListener("click", () => {
      if (game && !game.done && game.history.length && !confirm("진행 중인 게임을 그만두고 새 게임을 시작할까요?")) return;
      newGame(b.dataset.level);
    })
  );

  document.addEventListener("keydown", (e) => {
    if (!game || e.target.closest("input, textarea, dialog")) return;
    if (/^[1-9]$/.test(e.key)) input(Number(e.key));
    else if (["Backspace", "Delete", "0"].includes(e.key)) erase();
    else if (e.key === "n" || e.key === "N") $("sd-note").click();
    else if (e.key.startsWith("Arrow")) {
      e.preventDefault();
      const i = selected < 0 ? 0 : selected;
      const r = ROW(i);
      const c = COL(i);
      const moves = { ArrowUp: [-1, 0], ArrowDown: [1, 0], ArrowLeft: [0, -1], ArrowRight: [0, 1] };
      const [dr, dc] = moves[e.key];
      selected = ((r + dr + 9) % 9) * 9 + ((c + dc + 9) % 9);
      render();
    } else return;
    e.preventDefault();
  });

  Site.init({ current: "puzzle:sudoku" });
  game = storage.get(SAVE_KEY, null);
  if (game && game.solution?.length === 81) {
    game.history = game.history || [];
    selected = game.values.findIndex((v) => !v);
    render();
    startTimer();
  } else {
    newGame("easy");
  }
})();
