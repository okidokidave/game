// 갑질 사장 퇴치 대작전 - 매치3 퍼즐 RPG
(() => {
  'use strict';

  const COLS = 7;
  const ROWS = 7;
  const PAPER = 6;            // 사장이 던지는 서류더미 (맞출 수 없는 방해 블록)
  const MAX_MENTAL = 1000;
  const MAX_SHIELD = 300;
  const MAX_PAPERS = 10;
  const HEAL_PER_COFFEE = 15;
  const SHIELD_PER_PROOF = 12;
  const SAVE_KEY = 'office-puzzle-stage';

  const TILES = [
    { icon: '📈', color: '#e5534b', name: '영업' },
    { icon: '📋', color: '#4a8fe7', name: '기획' },
    { icon: '💻', color: '#3fb27f', name: '개발' },
    { icon: '🎨', color: '#e8b53a', name: '디자인' },
    { icon: '☕', color: '#b07a4f', name: '커피' },
    { icon: '📸', color: '#9b6ad6', name: '증거' },
  ];
  const PAPER_TILE = { icon: '📁', color: '#8b8f98', name: '서류더미' };

  const TEAM = [
    { name: '김대리', face: '😤', type: 0, atk: 22, need: 18, skill: '실적으로 증명', desc: '사장에게 큰 피해' },
    { name: '박과장', face: '🧐', type: 1, atk: 18, need: 15, skill: '결재 반려', desc: '사장 공격 2턴 지연' },
    { name: '이주임', face: '🤓', type: 2, atk: 20, need: 16, skill: '자동화 스크립트', desc: '가로줄 2개 제거' },
    { name: '최사원', face: '🙂', type: 3, atk: 16, need: 14, skill: '힐링 짤 공유', desc: '멘탈 35% 회복' },
  ];

  const BOSSES = [
    {
      name: '오 팀장', title: '꼰대', face: '😒', hp: 600, atk: 100, cd: 3, papers: 0,
      intro: '"나 때는 말이야~" 하루에도 열 번씩 듣는 그 말. 첫 상대는 꼰대 오 팀장이다.',
      lines: ['나 때는 말이야~', '이거 누가 이렇게 했어?', '회식은 필참이다!', '요즘 애들은 근성이 없어.'],
      defeat: '"요즘 애들은... 아, 아니야. 다들 수고했어."',
    },
    {
      name: '마 부장', title: '야근 강요', face: '😠', hp: 1000, atk: 130, cd: 3, papers: 2,
      intro: '퇴근 5분 전에 일을 던지는 마 부장. 공격할 때마다 서류더미를 던져 판을 막는다. 서류더미 옆에서 블록을 맞추면 치울 수 있다.',
      lines: ['오늘 다들 늦게까지 있지?', '퇴근? 일은 다 했고?', '주말에 잠깐만 나와.', '이것도 오늘까지야.'],
      defeat: '"오, 오늘은... 다들 일찍 들어가..."',
    },
    {
      name: '황 상무', title: '실적 압박', face: '😡', hp: 1500, atk: 100, cd: 2, papers: 2,
      intro: '말끝마다 숫자 타령인 황 상무. 공격 한 번은 약하지만 2턴마다 몰아붙인다. 증거를 모아 방어막을 쌓아두자.',
      lines: ['숫자로 말해!', '목표 200% 못 채우면 알지?', '이걸 보고서라고 썼어?', '경쟁사는 벌써 했다던데?'],
      defeat: '"숫자가... 숫자가 안 맞아..."',
    },
    {
      name: '갑 사장', title: '악질 갑질', face: '🤬', hp: 2200, atk: 170, cd: 3, papers: 4,
      intro: '모든 갑질의 원흉. 회사가 자기 것인 줄 아는 갑 사장과의 최후의 결전이다!',
      lines: ['내 회사니까 내 맘이야!', '월급 주는 게 어디야!', '너 내일부터 나오지 마!', '이게 다 너희를 위한 거야.', '연차? 그게 뭔데?'],
      defeat: '"이, 이럴 수가... 내 회사가..."',
    },
  ];

  const $ = (s) => document.querySelector(s);
  const app = $('#app');
  const canvas = $('#board');
  const ctx = canvas.getContext('2d');
  const overlay = $('#overlay');

  let grid = [];
  let dying = [];
  let flashes = [];
  let waiters = [];
  let stage = 0;
  let boss = null;
  let mental = MAX_MENTAL;
  let shield = 0;
  let gauges = [0, 0, 0, 0];
  let busy = true;
  let selected = null;
  let hint = null;
  let idle = 0;
  let nextId = 1;
  let cell = 48;
  let colors = {};
  let bubbleTimer = 0;

  /* ---------- 저장 ---------- */

  function loadStage() {
    try { return Math.min(BOSSES.length - 1, parseInt(localStorage.getItem(SAVE_KEY), 10) || 0); }
    catch (e) { return 0; }
  }

  function saveStage(n) {
    try { localStorage.setItem(SAVE_KEY, String(n)); } catch (e) { /* 저장 불가 환경 */ }
  }

  /* ---------- 유틸 ---------- */

  const rand = (n) => Math.floor(Math.random() * n);
  const pick = (arr) => arr[rand(arr.length)];
  const sleep = (ms) => new Promise((res) => setTimeout(res, ms));
  const key = (r, c) => r * COLS + c;
  const inBounds = (r, c) => r >= 0 && r < ROWS && c >= 0 && c < COLS;
  const tileAt = (k) => grid[Math.floor(k / COLS)][k % COLS];
  const matchable = (t) => t && t.type < PAPER;
  const swappable = (t) => t && t.type !== PAPER;

  function makeTile(type, r, c, y) {
    return { id: nextId++, type, special: null, r, c, x: c, y: y === undefined ? r : y, vy: 0 };
  }

  function settle() {
    return new Promise((res) => waiters.push(res));
  }

  function isSettled() {
    if (dying.length) return false;
    for (let r = 0; r < ROWS; r++) {
      for (let c = 0; c < COLS; c++) {
        const t = grid[r][c];
        if (t && (t.x !== t.c || t.y !== t.r)) return false;
      }
    }
    return true;
  }

  /* ---------- 판 생성 / 매치 판정 ---------- */

  function fillBoard() {
    do {
      grid = [];
      for (let r = 0; r < ROWS; r++) {
        const row = [];
        for (let c = 0; c < COLS; c++) {
          let t;
          do { t = rand(TILES.length); } while (
            (c >= 2 && row[c - 1].type === t && row[c - 2].type === t) ||
            (r >= 2 && grid[r - 1][c].type === t && grid[r - 2][c].type === t)
          );
          row.push(makeTile(t, r, c, r - ROWS - 1));
        }
        grid.push(row);
      }
    } while (!findMove());
  }

  function findRuns() {
    const runs = [];
    for (let r = 0; r < ROWS; r++) {
      let c = 0;
      while (c < COLS) {
        const t = grid[r][c];
        let e = c + 1;
        if (matchable(t)) {
          while (e < COLS && matchable(grid[r][e]) && grid[r][e].type === t.type) e++;
          if (e - c >= 3) {
            const cells = [];
            for (let i = c; i < e; i++) cells.push(key(r, i));
            runs.push({ dir: 'h', type: t.type, cells });
          }
        }
        c = e;
      }
    }
    for (let c = 0; c < COLS; c++) {
      let r = 0;
      while (r < ROWS) {
        const t = grid[r][c];
        let e = r + 1;
        if (matchable(t)) {
          while (e < ROWS && matchable(grid[e][c]) && grid[e][c].type === t.type) e++;
          if (e - r >= 3) {
            const cells = [];
            for (let i = r; i < e; i++) cells.push(key(i, c));
            runs.push({ dir: 'v', type: t.type, cells });
          }
        }
        r = e;
      }
    }
    return runs;
  }

  function swapRaw(r1, c1, r2, c2) {
    const t = grid[r1][c1];
    grid[r1][c1] = grid[r2][c2];
    grid[r2][c2] = t;
  }

  // 가능한 이동 하나를 찾는다 (힌트, 막힘 판정에 사용)
  function findMove() {
    for (let r = 0; r < ROWS; r++) {
      for (let c = 0; c < COLS; c++) {
        for (const [dr, dc] of [[0, 1], [1, 0]]) {
          const r2 = r + dr, c2 = c + dc;
          if (!inBounds(r2, c2) || !swappable(grid[r][c]) || !swappable(grid[r2][c2])) continue;
          swapRaw(r, c, r2, c2);
          const ok = findRuns().length > 0;
          swapRaw(r, c, r2, c2);
          if (ok) return [{ r, c }, { r: r2, c: c2 }];
        }
      }
    }
    return null;
  }

  // 매치 결과로 지울 칸과 새로 만들 특수 블록을 정한다
  function planRuns(runs, swapKeys) {
    const clear = new Set();
    const creates = [];
    const taken = new Set();
    const used = new Set();
    const free = (k) => !taken.has(k) && !tileAt(k).special;
    const choose = (ordered) => ordered.find((k) => swapKeys.includes(k) && free(k)) ?? ordered.find(free);
    const add = (k, special) => {
      if (k === undefined) return;
      taken.add(k);
      creates.push({ k, special, type: tileAt(k).type });
    };

    runs.forEach((run) => run.cells.forEach((k) => clear.add(k)));

    // ㄱ자, T자 모양은 폭탄
    runs.forEach((h, i) => {
      if (h.dir !== 'h') return;
      runs.forEach((v, j) => {
        if (v.dir !== 'v' || v.type !== h.type || used.has(i) || used.has(j)) return;
        const k = h.cells.find((x) => v.cells.includes(x));
        if (k === undefined) return;
        used.add(i);
        used.add(j);
        add(choose([k, ...h.cells, ...v.cells]), 'bomb');
      });
    });

    // 4개는 줄 폭탄, 5개 이상은 폭탄
    runs.forEach((run, i) => {
      if (used.has(i) || run.cells.length < 4) return;
      const mid = (run.cells.length - 1) / 2;
      const ordered = run.cells.slice().sort((a, b) => Math.abs(run.cells.indexOf(a) - mid) - Math.abs(run.cells.indexOf(b) - mid));
      const special = run.cells.length >= 5 ? 'bomb' : (run.dir === 'h' ? 'row' : 'col');
      add(choose(ordered), special);
    });

    creates.forEach((cr) => clear.delete(cr.k));
    return { clear, creates };
  }

  function specialArea(t, r, c) {
    const area = [];
    if (t.special === 'row') for (let i = 0; i < COLS; i++) area.push(key(r, i));
    if (t.special === 'col') for (let i = 0; i < ROWS; i++) area.push(key(i, c));
    if (t.special === 'bomb') {
      for (let dr = -1; dr <= 1; dr++) {
        for (let dc = -1; dc <= 1; dc++) if (inBounds(r + dr, c + dc)) area.push(key(r + dr, c + dc));
      }
    }
    return area;
  }

  function expandSpecials(clear) {
    const queue = [...clear];
    const done = new Set();
    while (queue.length) {
      const k = queue.pop();
      if (done.has(k)) continue;
      done.add(k);
      const r = Math.floor(k / COLS), c = k % COLS;
      const t = grid[r][c];
      if (!t || !t.special) continue;
      flashes.push({ special: t.special, r, c, life: 0.35 });
      for (const a of specialArea(t, r, c)) {
        if (!clear.has(a)) {
          clear.add(a);
          queue.push(a);
        }
      }
    }
  }

  function addAdjacentPapers(clear) {
    for (const k of [...clear]) {
      const r = Math.floor(k / COLS), c = k % COLS;
      for (const [dr, dc] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
        const r2 = r + dr, c2 = c + dc;
        if (inBounds(r2, c2) && grid[r2][c2] && grid[r2][c2].type === PAPER) clear.add(key(r2, c2));
      }
    }
  }

  function gravity() {
    for (let c = 0; c < COLS; c++) {
      let write = ROWS - 1;
      for (let r = ROWS - 1; r >= 0; r--) {
        const t = grid[r][c];
        if (!t) continue;
        if (r !== write) {
          grid[write][c] = t;
          grid[r][c] = null;
          t.r = write;
        }
        write--;
      }
      const missing = write + 1;
      for (let r = write; r >= 0; r--) {
        grid[r][c] = makeTile(rand(TILES.length), r, c, r - missing - 0.3);
      }
    }
  }

  /* ---------- 턴 진행 ---------- */

  // 블록을 지우고 연쇄가 끝날 때까지 반복한다
  async function runClears(forced, swapKeys) {
    let cascade = 0;
    while (true) {
      let clear;
      let creates = [];
      if (forced) {
        clear = new Set(forced);
        forced = null;
      } else {
        const runs = findRuns();
        if (!runs.length) break;
        ({ clear, creates } = planRuns(runs, swapKeys));
      }
      swapKeys = [];
      cascade++;

      expandSpecials(clear);
      addAdjacentPapers(clear);
      applyEffects(clear, cascade);

      for (const k of clear) {
        const r = Math.floor(k / COLS), c = k % COLS;
        const t = grid[r][c];
        if (!t) continue;
        dying.push({ tile: t, life: 0.22, max: 0.22 });
        grid[r][c] = null;
      }
      for (const cr of creates) {
        const t = tileAt(cr.k);
        if (t) {
          t.special = cr.special;
          t.type = cr.type;
        }
      }
      await sleep(220);
      gravity();
      await settle();
    }
    return cascade;
  }

  function applyEffects(clear, cascade) {
    const counts = [0, 0, 0, 0, 0, 0];
    for (const k of clear) {
      const t = tileAt(k);
      if (matchable(t)) counts[t.type]++;
    }
    const mult = 1 + 0.25 * (cascade - 1);

    let dmg = 0;
    TEAM.forEach((m, i) => {
      const n = counts[m.type];
      dmg += n * m.atk;
      gauges[i] = Math.min(m.need, gauges[i] + n);
    });
    dmg = Math.round(dmg * mult);
    if (dmg > 0) hitBoss(dmg);

    const heal = Math.round(counts[4] * HEAL_PER_COFFEE * mult);
    if (heal > 0) {
      mental = Math.min(MAX_MENTAL, mental + heal);
      floatText('+' + heal, $('.mental-row .bar'), 'heal');
    }
    if (counts[5] > 0) {
      const add = counts[5] * SHIELD_PER_PROOF;
      shield = Math.min(MAX_SHIELD, shield + add);
      floatText('🛡️+' + add, $('#shield'), 'shield');
    }
    if (cascade >= 2) floatText(cascade + ' 콤보!', canvas, 'combo');
    updateHud();
  }

  function hitBoss(dmg) {
    boss.hp = Math.max(0, boss.hp - dmg);
    floatText('-' + dmg, $('#boss-face'), 'dmg');
    const face = $('#boss-face');
    face.classList.remove('hurt');
    void face.offsetWidth;
    face.classList.add('hurt');
  }

  async function trySwap(a, b) {
    busy = true;
    hint = null;
    idle = 0;
    swapTiles(a, b);
    await settle();
    if (!findRuns().length) {
      swapTiles(a, b);
      await settle();
      busy = false;
      return;
    }
    await runClears(null, [key(a.r, a.c), key(b.r, b.c)]);
    await endTurn();
  }

  function swapTiles(a, b) {
    grid[a.r][a.c] = b;
    grid[b.r][b.c] = a;
    [a.r, b.r] = [b.r, a.r];
    [a.c, b.c] = [b.c, a.c];
  }

  async function endTurn() {
    if (boss.hp <= 0) return stageClear();
    boss.cd--;
    updateHud();
    if (boss.cd <= 0) await bossAttack();
    updateHud();
    if (mental <= 0) return gameOver();
    if (!findMove()) await shuffleBoard();
    busy = false;
  }

  async function bossAttack() {
    const b = BOSSES[stage];
    say(pick(b.lines));
    const bossEl = $('#boss');
    bossEl.classList.remove('attack');
    void bossEl.offsetWidth;
    bossEl.classList.add('attack');
    await sleep(350);

    const absorbed = Math.min(shield, b.atk);
    shield -= absorbed;
    const dmg = b.atk - absorbed;
    mental = Math.max(0, mental - dmg);
    const wrap = $('#board-wrap');
    wrap.classList.remove('hit');
    void wrap.offsetWidth;
    wrap.classList.add('hit');
    floatText(dmg > 0 ? '멘탈 -' + dmg : '방어!', $('.mental-row .bar'), dmg > 0 ? 'dmg' : 'shield');

    if (b.papers) dropPapers(b.papers);
    boss.cd = b.cd;
    await sleep(450);
  }

  function dropPapers(n) {
    const all = grid.flat();
    const room = MAX_PAPERS - all.filter((t) => t.type === PAPER).length;
    const candidates = all.filter((t) => matchable(t) && !t.special);
    for (let i = 0; i < Math.min(n, room) && candidates.length; i++) {
      const t = candidates.splice(rand(candidates.length), 1)[0];
      t.type = PAPER;
      flashes.push({ special: 'paper', r: t.r, c: t.c, life: 0.4 });
    }
  }

  async function shuffleBoard() {
    floatText('판을 섞는 중...', canvas, 'info');
    const normals = grid.flat().filter((t) => matchable(t) && !t.special);
    let tries = 0;
    do {
      normals.forEach((t) => { t.type = rand(TILES.length); });
      tries++;
    } while ((findRuns().length || !findMove()) && tries < 300);
    if (!findMove()) {
      // 서류더미가 너무 많아 막혔다면 치워준다
      grid.flat().forEach((t) => { if (t.type === PAPER) t.type = rand(TILES.length); });
      if (findRuns().length) await runClears(null, []);
    }
    await sleep(400);
  }

  /* ---------- 스킬 ---------- */

  async function useSkill(i) {
    const m = TEAM[i];
    if (busy || gauges[i] < m.need) return;
    busy = true;
    hint = null;
    gauges[i] = 0;
    floatText(m.skill + '!', canvas, 'combo');
    updateHud();
    await sleep(300);

    if (i === 0) {
      hitBoss(m.atk * 15);
    } else if (i === 1) {
      boss.cd += 2;
      say('어? 결재가... 반려됐다고?');
    } else if (i === 2) {
      const rows = [];
      while (rows.length < 2) {
        const r = rand(ROWS);
        if (!rows.includes(r)) rows.push(r);
      }
      const forced = [];
      rows.forEach((r) => { for (let c = 0; c < COLS; c++) forced.push(key(r, c)); });
      await runClears(forced, []);
    } else if (i === 3) {
      const heal = Math.round(MAX_MENTAL * 0.35);
      mental = Math.min(MAX_MENTAL, mental + heal);
      floatText('+' + heal, $('.mental-row .bar'), 'heal');
    }
    updateHud();
    await sleep(300);

    if (boss.hp <= 0) return stageClear();
    if (!findMove()) await shuffleBoard();
    busy = false;
  }

  /* ---------- 화면 ---------- */

  function buildTeam() {
    const box = $('#members');
    box.innerHTML = '';
    TEAM.forEach((m, i) => {
      const btn = document.createElement('button');
      btn.className = 'member';
      btn.title = m.skill + ': ' + m.desc;
      btn.innerHTML =
        '<div class="face">' + m.face + '</div>' +
        '<div class="name">' + m.name + '</div>' +
        '<span class="tag" style="background:' + TILES[m.type].color + '"></span>' +
        '<div class="gauge"><i></i></div>';
      btn.addEventListener('click', () => useSkill(i));
      box.appendChild(btn);
    });
  }

  function updateHud() {
    const b = BOSSES[stage];
    $('#boss-face').textContent = b.face;
    $('#boss-title').textContent = b.title;
    $('#boss-name').textContent = b.name;
    $('#boss-hp-fill').style.width = (boss.hp / boss.max) * 100 + '%';
    $('#boss-hp-text').textContent = boss.hp + ' / ' + boss.max;
    $('#boss-cd').textContent = Math.max(0, boss.cd);
    $('.boss-cd').classList.toggle('danger', boss.cd <= 1);
    $('#mental-fill').style.width = (mental / MAX_MENTAL) * 100 + '%';
    $('#mental-text').textContent = mental + ' / ' + MAX_MENTAL;
    $('#shield').textContent = '🛡️ ' + shield;
    document.querySelectorAll('.member').forEach((el, i) => {
      el.querySelector('.gauge i').style.width = (gauges[i] / TEAM[i].need) * 100 + '%';
      el.classList.toggle('ready', gauges[i] >= TEAM[i].need);
    });
  }

  function say(text) {
    const el = $('#bubble');
    el.textContent = text;
    el.classList.add('show');
    clearTimeout(bubbleTimer);
    bubbleTimer = setTimeout(() => el.classList.remove('show'), 2200);
  }

  function floatText(text, target, cls) {
    const a = app.getBoundingClientRect();
    const t = target.getBoundingClientRect();
    const el = document.createElement('div');
    el.className = 'float ' + cls;
    el.textContent = text;
    el.style.left = t.left - a.left + t.width / 2 + (Math.random() * 20 - 10) + 'px';
    el.style.top = t.top - a.top + t.height / 2 + 'px';
    app.appendChild(el);
    el.addEventListener('animationend', () => el.remove());
  }

  function showCard(html, handlers) {
    overlay.innerHTML = '<div class="card">' + html + '</div>';
    overlay.classList.add('show');
    Object.entries(handlers).forEach(([id, fn]) => {
      const el = overlay.querySelector('#' + id);
      if (el) el.addEventListener('click', fn);
    });
  }

  function hideCard() {
    overlay.classList.remove('show');
    overlay.innerHTML = '';
  }

  function showTitle() {
    busy = true;
    const saved = loadStage();
    showCard(
      '<div class="big">🏢</div>' +
      '<h1>갑질 사장 퇴치 대작전</h1>' +
      '<p class="sub">블록을 맞춰 갑질 상사들을 혼내주자!</p>' +
      '<p>주 6일 야근, 주말 단톡방 호출, 회식 필참... 참다못한 직원 넷이 뭉쳤다. 팀장부터 사장까지 한 명씩 혼쭐을 내주자!</p>' +
      '<ul class="howto">' +
      '<li>같은 블록 <b>3개 이상</b>을 맞추면 그 색깔 직원이 공격</li>' +
      '<li>☕ <b>커피</b>는 멘탈 회복, 📸 <b>증거</b>는 방어막</li>' +
      '<li><b>4개</b>를 맞추면 줄 폭탄, <b>5개</b>나 ㄱ·T자는 큰 폭탄</li>' +
      '<li>게이지가 차면 <b>직원 얼굴</b>을 눌러 스킬 사용</li>' +
      '<li>멘탈이 0이 되면 패배!</li>' +
      '</ul>' +
      '<div class="btns">' +
      (saved > 0 ? '<button id="go-continue" class="btn primary">이어하기 (' + BOSSES[saved].name + ')</button>' : '') +
      '<button id="go-new" class="btn' + (saved > 0 ? '' : ' primary') + '">처음부터 출근하기</button>' +
      '</div>',
      {
        'go-continue': () => showIntro(saved),
        'go-new': () => { saveStage(0); showIntro(0); },
      }
    );
  }

  function showIntro(i) {
    const b = BOSSES[i];
    showCard(
      '<p class="sub">' + (i + 1) + ' / ' + BOSSES.length + ' 번째 상대</p>' +
      '<div class="big">' + b.face + '</div>' +
      '<h2>' + b.title + ' ' + b.name + '</h2>' +
      '<p>' + b.intro + '</p>' +
      '<div class="btns"><button id="go-fight" class="btn primary">맞서기</button></div>',
      { 'go-fight': () => startStage(i) }
    );
  }

  async function startStage(i) {
    hideCard();
    stage = i;
    const b = BOSSES[i];
    boss = { hp: b.hp, max: b.hp, cd: b.cd };
    mental = MAX_MENTAL;
    shield = 0;
    gauges = [0, 0, 0, 0];
    selected = null;
    hint = null;
    idle = 0;
    dying = [];
    flashes = [];
    busy = true;
    fillBoard();
    updateHud();
    say(b.lines[0]);
    await settle();
    busy = false;
  }

  async function stageClear() {
    busy = true;
    const b = BOSSES[stage];
    say(b.defeat);
    await sleep(900);
    const last = stage === BOSSES.length - 1;
    saveStage(last ? 0 : stage + 1);
    if (last) return showEnding();
    showCard(
      '<div class="big">🎉</div>' +
      '<h2>' + b.name + ' 퇴치!</h2>' +
      '<p class="quote">' + b.defeat + '</p>' +
      '<div class="btns"><button id="go-next" class="btn primary">다음 상대로</button>' +
      '<button id="go-title" class="btn">타이틀로</button></div>',
      { 'go-next': () => showIntro(stage + 1), 'go-title': showTitle }
    );
  }

  function gameOver() {
    busy = true;
    const b = BOSSES[stage];
    showCard(
      '<div class="big">😵</div>' +
      '<h2>멘탈이 바닥났다...</h2>' +
      '<p>' + b.name + '의 갑질에 모두 책상에 엎드리고 말았다. 커피 한 잔 마시고 다시 도전하자.</p>' +
      '<div class="btns"><button id="go-retry" class="btn primary">다시 도전</button>' +
      '<button id="go-title" class="btn">타이틀로</button></div>',
      { 'go-retry': () => startStage(stage), 'go-title': showTitle }
    );
  }

  function showEnding() {
    showCard(
      '<div class="big">🌇</div>' +
      '<h2>칼퇴의 날</h2>' +
      '<p>모아둔 녹취록과 증거 사진이 세상에 공개되었다. 갑 사장은 결국 대표 자리에서 물러났고, 새로 온 대표의 첫 지시는 "정시 퇴근"이었다.</p>' +
      '<p>오늘 저녁 6시, 네 사람은 처음으로 해가 지기 전에 회사를 나섰다.</p>' +
      '<div class="btns"><button id="go-title" class="btn primary">처음으로</button></div>',
      { 'go-title': showTitle }
    );
  }

  /* ---------- 입력 ---------- */

  let drag = null;

  function cellAt(e) {
    const rect = canvas.getBoundingClientRect();
    const c = Math.floor((e.clientX - rect.left) / cell);
    const r = Math.floor((e.clientY - rect.top) / cell);
    return inBounds(r, c) ? { r, c } : null;
  }

  function attemptSwap(r1, c1, r2, c2) {
    if (busy || !inBounds(r2, c2)) return;
    const a = grid[r1][c1], b = grid[r2][c2];
    if (!swappable(a) || !swappable(b)) return;
    selected = null;
    trySwap(a, b);
  }

  canvas.addEventListener('pointerdown', (e) => {
    if (busy) return;
    const p = cellAt(e);
    if (!p) return;
    drag = { r: p.r, c: p.c, x: e.clientX, y: e.clientY, moved: false };
    canvas.setPointerCapture(e.pointerId);
  });

  canvas.addEventListener('pointermove', (e) => {
    if (!drag || drag.moved) return;
    const dx = e.clientX - drag.x, dy = e.clientY - drag.y;
    if (Math.max(Math.abs(dx), Math.abs(dy)) < cell * 0.35) return;
    drag.moved = true;
    const [dr, dc] = Math.abs(dx) > Math.abs(dy) ? [0, Math.sign(dx)] : [Math.sign(dy), 0];
    attemptSwap(drag.r, drag.c, drag.r + dr, drag.c + dc);
  });

  canvas.addEventListener('pointerup', () => {
    if (drag && !drag.moved && !busy) {
      const { r, c } = drag;
      if (selected && Math.abs(selected.r - r) + Math.abs(selected.c - c) === 1) {
        attemptSwap(selected.r, selected.c, r, c);
      } else if (selected && selected.r === r && selected.c === c) {
        selected = null;
      } else if (swappable(grid[r][c])) {
        selected = { r, c };
      }
    }
    drag = null;
  });

  canvas.addEventListener('pointercancel', () => { drag = null; });

  /* ---------- 그리기 ---------- */

  function readColors() {
    const s = getComputedStyle(document.documentElement);
    colors.a = s.getPropertyValue('--board-a').trim();
    colors.b = s.getPropertyValue('--board-b').trim();
  }

  function resize() {
    const wrapW = $('#board-wrap').clientWidth;
    const used = $('#boss').offsetHeight + $('#team').offsetHeight + 56;
    const hAvail = window.innerHeight - used;
    cell = Math.floor(Math.max(38, Math.min(wrapW / COLS, hAvail / ROWS, 64)));
    const dpr = window.devicePixelRatio || 1;
    canvas.style.width = cell * COLS + 'px';
    canvas.style.height = cell * ROWS + 'px';
    canvas.width = Math.round(cell * COLS * dpr);
    canvas.height = Math.round(cell * ROWS * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    readColors();
  }

  function roundRect(x, y, w, h, rad) {
    ctx.beginPath();
    ctx.moveTo(x + rad, y);
    ctx.arcTo(x + w, y, x + w, y + h, rad);
    ctx.arcTo(x + w, y + h, x, y + h, rad);
    ctx.arcTo(x, y + h, x, y, rad);
    ctx.arcTo(x, y, x + w, y, rad);
    ctx.closePath();
  }

  function drawTile(t, scale, time) {
    const info = t.type === PAPER ? PAPER_TILE : TILES[t.type];
    const size = cell * 0.88 * scale;
    ctx.save();
    ctx.translate(t.x * cell + cell / 2, t.y * cell + cell / 2);
    ctx.globalAlpha = Math.min(1, scale * 1.3);

    roundRect(-size / 2, -size / 2, size, size, size * 0.24);
    ctx.fillStyle = info.color;
    ctx.fill();
    ctx.fillStyle = 'rgba(255,255,255,0.18)';
    roundRect(-size / 2 + 3, -size / 2 + 3, size - 6, size * 0.42, size * 0.18);
    ctx.fill();

    if (t.special === 'row' || t.special === 'col') {
      ctx.fillStyle = 'rgba(255,255,255,0.75)';
      const w = size * 0.1;
      for (const off of [-size * 0.2, size * 0.2]) {
        if (t.special === 'row') ctx.fillRect(-size / 2 + 2, off - w / 2, size - 4, w);
        else ctx.fillRect(off - w / 2, -size / 2 + 2, w, size - 4);
      }
    } else if (t.special === 'bomb') {
      ctx.strokeStyle = 'rgba(255,255,255,' + (0.6 + 0.4 * Math.sin(time * 6)) + ')';
      ctx.lineWidth = 3;
      roundRect(-size / 2 + 2, -size / 2 + 2, size - 4, size - 4, size * 0.22);
      ctx.stroke();
    }

    ctx.font = Math.floor(size * 0.56) + 'px "Apple Color Emoji","Segoe UI Emoji","Noto Color Emoji",sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillStyle = '#000';     // 컬러 이모지도 fillStyle의 투명도를 따라가므로 불투명하게
    ctx.fillText(info.icon, 0, size * 0.04);
    if (t.special === 'bomb') {
      ctx.font = Math.floor(size * 0.3) + 'px sans-serif';
      ctx.fillText('💥', size * 0.28, -size * 0.28);
    }
    ctx.restore();
  }

  function outline(r, c, color, width) {
    ctx.strokeStyle = color;
    ctx.lineWidth = width;
    roundRect(c * cell + 2, r * cell + 2, cell - 4, cell - 4, cell * 0.24);
    ctx.stroke();
  }

  function draw(time) {
    const w = cell * COLS, h = cell * ROWS;
    ctx.clearRect(0, 0, w, h);
    for (let r = 0; r < ROWS; r++) {
      for (let c = 0; c < COLS; c++) {
        ctx.fillStyle = (r + c) % 2 ? colors.a : colors.b;
        ctx.fillRect(c * cell, r * cell, cell, cell);
      }
    }

    for (const f of flashes) {
      ctx.fillStyle = 'rgba(255,255,255,' + Math.min(0.7, f.life * 2) + ')';
      if (f.special === 'row') ctx.fillRect(0, f.r * cell, w, cell);
      else if (f.special === 'col') ctx.fillRect(f.c * cell, 0, cell, h);
      else if (f.special === 'bomb') ctx.fillRect((f.c - 1) * cell, (f.r - 1) * cell, cell * 3, cell * 3);
      else if (f.special === 'paper') ctx.fillRect(f.c * cell, f.r * cell, cell, cell);
    }

    for (let r = 0; r < ROWS; r++) {
      for (let c = 0; c < COLS; c++) if (grid[r] && grid[r][c]) drawTile(grid[r][c], 1, time);
    }
    for (const d of dying) drawTile(d.tile, d.life / d.max, time);

    if (selected) outline(selected.r, selected.c, '#ffffff', 3);
    if (hint) {
      const a = 0.4 + 0.4 * Math.sin(time * 5);
      hint.forEach((p) => outline(p.r, p.c, 'rgba(255,255,255,' + a + ')', 3));
    }
  }

  function step(dt) {
    for (let r = 0; r < ROWS; r++) {
      for (let c = 0; c < COLS; c++) {
        const t = grid[r] && grid[r][c];
        if (!t) continue;
        if (t.x !== t.c) {
          const d = t.c - t.x, m = 9 * dt;
          t.x = Math.abs(d) <= m ? t.c : t.x + Math.sign(d) * m;
        }
        if (t.y < t.r) {
          t.vy = Math.min(t.vy + 70 * dt, 22);
          t.y = Math.min(t.r, t.y + t.vy * dt);
          if (t.y === t.r) t.vy = 0;
        } else if (t.y > t.r) {
          t.y = Math.max(t.r, t.y - 9 * dt);
        }
      }
    }
    dying = dying.filter((d) => (d.life -= dt) > 0);
    flashes = flashes.filter((f) => (f.life -= dt) > 0);

    if (waiters.length && isSettled()) {
      const list = waiters;
      waiters = [];
      list.forEach((res) => res());
    }

    if (!busy && !hint && !overlay.classList.contains('show')) {
      idle += dt;
      if (idle > 6) hint = findMove();
    }
  }

  let last = performance.now();
  function loop(now) {
    const dt = Math.min(0.05, (now - last) / 1000);
    last = now;
    if (grid.length) {
      step(dt);
      draw(now / 1000);
    }
    requestAnimationFrame(loop);
  }

  /* ---------- 시작 ---------- */

  buildTeam();
  boss = { hp: BOSSES[0].hp, max: BOSSES[0].hp, cd: BOSSES[0].cd };
  fillBoard();
  updateHud();
  resize();
  window.addEventListener('resize', resize);
  window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', readColors);
  requestAnimationFrame(loop);
  showTitle();
})();
