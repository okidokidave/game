/*
 * 인플루언서 시뮬레이터 — 도트 방 그리기
 *
 * 싸이월드 미니룸처럼 벽 두 면과 바닥만 보이는 아이소메트릭 단면 방을 그립니다.
 * 216×186 해상도로 그린 뒤 CSS(image-rendering: pixelated)로 키워서 도트 느낌을 냅니다.
 *
 * 좌표: x는 오른쪽 아래, y는 왼쪽 아래, z는 위. 방 크기는 96×96, 벽 높이 72.
 * 화면 좌표 = (OX + x - y, OY + (x + y) / 2 - z)
 */
(() => {
  const W = 216;
  const H = 186;
  const OX = 108;
  const OY = 82;
  const RW = 96;
  const RH = 72;

  // ───── 색 ─────
  const cache = new Map();
  function rgba(hex) {
    let v = cache.get(hex);
    if (v === undefined) {
      const n = parseInt(hex.slice(1, 7), 16);
      const a = hex.length > 7 ? parseInt(hex.slice(7, 9), 16) : 255;
      v = ((a << 24) | ((n & 0xff) << 16) | (n & 0xff00) | (n >> 16)) >>> 0;
      cache.set(hex, v);
    }
    return v;
  }

  function shade(hex, amt) {
    const n = parseInt(hex.slice(1, 7), 16);
    const f = (c) => Math.max(0, Math.min(255, Math.round(amt > 0 ? c + (255 - c) * amt : c * (1 + amt))));
    const r = f(n >> 16);
    const g = f((n >> 8) & 0xff);
    const b = f(n & 0xff);
    return "#" + ((r << 16) | (g << 8) | b).toString(16).padStart(6, "0");
  }

  // ───── 래스터 (픽셀 버퍼) ─────
  class Raster {
    constructor() {
      this.img = new ImageData(W, H);
      this.buf = new Uint32Array(this.img.data.buffer);
    }
    set(x, y, hex) {
      x = Math.floor(x);
      y = Math.floor(y);
      if (x < 0 || y < 0 || x >= W || y >= H || !hex) return;
      this.buf[y * W + x] = rgba(hex);
    }
    toCanvas() {
      const c = document.createElement("canvas");
      c.width = W;
      c.height = H;
      c.getContext("2d").putImageData(this.img, 0, 0);
      return c;
    }
  }

  const sx = (x, y) => OX + x - y;
  const sy = (x, y, z) => OY + (x + y) / 2 - z;
  const pick = (col, a, b) => (typeof col === "function" ? col(a, b) : col);

  // 바닥과 평행한 면 (윗면)
  function top(r, x0, y0, x1, y1, z, col) {
    for (let x = x0; x < x1; x += 0.5)
      for (let y = y0; y < y1; y += 0.5) r.set(sx(x, y), sy(x, y, z), pick(col, x - x0, y - y0));
  }
  // x가 일정한 면 (왼쪽 벽과 평행, 화면에서 오른쪽 앞면)
  function sideX(r, x, y0, y1, z0, z1, col) {
    for (let y = y0; y < y1; y += 0.5)
      for (let z = z0; z < z1; z += 0.5) r.set(sx(x, y), sy(x, y, z), pick(col, y - y0, z - z0));
  }
  // y가 일정한 면 (오른쪽 벽과 평행, 화면에서 왼쪽 앞면)
  function sideY(r, y, x0, x1, z0, z1, col) {
    for (let x = x0; x < x1; x += 0.5)
      for (let z = z0; z < z1; z += 0.5) r.set(sx(x, y), sy(x, y, z), pick(col, x - x0, z - z0));
  }
  function box(r, x, y, z, w, d, h, hex, opt = {}) {
    sideY(r, y + d, x, x + w, z, z + h, opt.l || hex);
    sideX(r, x + w, y, y + d, z, z + h, opt.r || shade(hex, -0.22));
    top(r, x, y, x + w, y + d, z + h, opt.t || shade(hex, 0.14));
  }

  // 2D 스프라이트 (rows: 문자열 배열, pal: 문자 → 색). (px, py)는 아래쪽 가운데
  function sprite(r, px, py, rows, pal) {
    const w = rows[0].length;
    const ox = Math.round(px - w / 2);
    const oy = Math.round(py - rows.length);
    rows.forEach((row, j) => {
      for (let i = 0; i < row.length; i++) {
        const c = pal[row[i]];
        if (c) r.set(ox + i, oy + j, c);
      }
    });
  }
  const at = (x, y, z = 0) => [sx(x, y), sy(x, y, z)];

  // ───── 소품 스프라이트 ─────
  const SPR = {
    plant: [
      "...g.g.g...",
      "..gGg.gGg..",
      ".gGGgggGGg.",
      "gGg.gGg.gGg",
      ".g.gGGGg.g.",
      "...gGgGg...",
      "....ggg....",
      "....pPp....",
      "...pPPPp...",
      "...pPPPp...",
      "....ppp....",
    ],
    phone: ["kk", "kb", "kb", "kk", ".s", "ss"],
    webcam: ["kkkk", "kbbk", "kkkk", ".kk."],
    mirrorless: ["..kk..", "kkkkkk", "kkbbkk", "kbBbkk", "kkbbkk", "kkkkkk", "..k...", "..k...", "..k...", "..k...", ".k.k..", "k...k."],
    cinema: ["...kkkkk.", ".kkkkkkkk", "bkkkkkkkk", "Bbkkkrkkk", "bkkkkkkkk", ".kkkkkkkk", "....kk...", "....k....", "....k....", "....k....", "....k....", "...k.k...", "..k...k..", ".k.....k."],
    pinmic: ["k"],
    boom: ["....kkk", "...k...", "..k....", ".k.....", "kk.....", "kk.....", "kk.....", ".k....."],
    studio: [".sss.", "sSsSs", "sSsSs", "sSsSs", ".sss.", "..k..", "..k..", ".kkk."],
    lamp: ["wwww.", "wyyw.", "..k..", "..k..", ".k...", "kkk.."],
    ring: ["..wwww..", ".w....w.", "w......w", "w..kk..w", "w......w", ".w....w.", "..wwww..", "...kk...", "...k....", "...k....", "...k....", "...k....", "...k....", "...k....", "...k....", "..k.k...", ".k...k..", "k.....k."],
    softbox: ["kwwwwwk", "kwwwwwk", "kwwwwwk", "kwwwwwk", ".kkkkk.", "...k...", "...k...", "...k...", "...k...", "...k...", "...k...", "...k...", "...k...", "..k.k..", ".k...k.", "k.....k"],
    beanbag: ["....bbbb....", "..bbBBBBbb..", ".bBBBBBBBBb.", "bBBBBBBBBBBb", "bBBBbbbbBBBb", "bbBbbbbbbbBb", ".bbbbbbbbbb.", "..dddddddd.."],
    figure: ["r.", "rr", "kk"],
    figure2: [".y", "yy", "bb"],
    cushion: ["..pppppp..", ".pPPPPPPp.", "pPPPPPPPPp", ".pppppppp."],
  };

  // ───── 캐릭터 스프라이트 (12칸) ─────
  // h 머리, s 피부, e 눈, m 입, b 볼, t 옷, d 옷 그림자, p 바지, k 신발
  const HEAD = [
    "...hhhhhh...",
    "..hhhhhhhh..",
    ".hhhhhhhhhh.",
    ".hhhhhhhhhh.",
    ".hhsshhsssh.",
    ".hssssssssh.",
    ".hsessssesh.",
    ".hsessssesh.",
    ".hbssmmssbh.",
    "..ssssssss..",
  ];
  const BODY_SIT = [
    "...dttttd...",
    "..tttttttt..",
    ".stttttttts.",
    ".stttttttts.",
    "..dddddddd..",
    "..pppppppp..",
  ];
  const BODY_STAND = [
    "...dttttd...",
    "..tttttttt..",
    ".stttttttts.",
    ".stttttttts.",
    "..dddddddd..",
    "...pp..pp...",
    "...pp..pp...",
    "...kk..kk...",
  ];
  const ARMS_UP = [
    "s..dttttd..s",
    "st.tttttt.ts",
    "..tttttttt..",
    "..tttttttt..",
    "..dddddddd..",
    "..pppppppp..",
  ];

  function charPalette(look, f) {
    const hair = look.hair;
    return {
      h: hair,
      s: "#f3c9a5",
      e: f.blink ? "#e0a98a" : "#2a2230",
      m: f.talk ? "#a33b3b" : "#e0a98a",
      b: "#f19a9a",
      t: look.shirt,
      d: shade(look.shirt, -0.25),
      p: "#3b4a6b",
      k: "#2a2230",
    };
  }

  function headRows(look, closed) {
    let rows = HEAD.slice();
    if (look.long) {
      rows = rows.map((row, i) => (i >= 4 ? "h" + row.slice(1, 11) + "h" : row));
      rows.push("hh........hh", "h..........h");
    }
    if (closed) rows = rows.map((row) => row.replace(/e/g, "m"));
    return rows;
  }

  // ───── 방 구성 ─────
  // 캐릭터 위치(의자)와 침대 베개 위치
  const SEAT = { x: 30, y: 40 };
  const PILLOW = { x: 70, y: 13, z: 14 };

  function skyColors(slot) {
    return [
      { sky: "#9fd8f5", sky2: "#d5f0ff", sun: "#fff3b0" },
      { sky: "#f5b37a", sky2: "#ffd9a8", sun: "#ff8a5c" },
      { sky: "#1b2350", sky2: "#2d3a78", sun: "#f5f0c8" },
    ][Math.min(slot, 2)];
  }

  function drawBack(s) {
    const r = new Raster();
    const g = s.gear;
    const deco = new Set(s.deco);
    const wall = s.wallColor || "#e9dccb";
    const wallR = shade(wall, -0.08);
    const trim = "#b58a62";

    // 바닥 판
    box(r, 0, 0, -6, RW, RW, 6, "#8a6040");
    top(r, 0, 0, RW, RW, 0, (x, y) => {
      const row = Math.floor(y / 8);
      const seam = (x + row * 13) % 32 < 0.6 || y % 8 < 0.6;
      const tone = row % 2 ? "#c99a6b" : "#c49364";
      return seam ? "#a8784d" : tone;
    });

    // 벽 (두께 포함)
    box(r, -4, 0, -6, 4, RW, RH + 6, trim);
    box(r, -4, -4, -6, RW + 4, 4, RH + 6, trim);
    sideX(r, 0, 0, RW, 0, RH, (y, z) => {
      if (z < 2) return "#7a5a40";
      if (z < 16) return Math.floor(y / 4) % 2 ? "#cfae8a" : "#c6a47f";
      if (z < 17) return trim;
      return Math.floor(y / 6) % 2 ? wall : shade(wall, -0.04);
    });
    sideY(r, 0, 0, RW, 0, RH, (x, z) => {
      if (z < 2) return "#6c4f38";
      if (z < 16) return Math.floor(x / 4) % 2 ? "#c3a27f" : "#bb9a76";
      if (z < 17) return shade(trim, -0.1);
      return Math.floor(x / 6) % 2 ? wallR : shade(wallR, -0.04);
    });

    // 창문 (왼쪽 벽)
    const sky = skyColors(s.slot ?? 0);
    sideX(r, 0, 52, 84, 28, 58, (y, z) => {
      if (y < 2 || y >= 30 || z < 2 || z >= 28 || Math.abs(y - 16) < 1) return "#f4ede2";
      if (s.slot === 2 && (y * 7 + z * 13) % 37 < 0.6) return "#ffffff";
      if ((y - 22) ** 2 + (z - 21) ** 2 < 10) return sky.sun;
      return z > 14 ? sky.sky : sky.sky2;
    });
    sideX(r, 0.5, 49, 53, 24, 60, "#d97f8f");
    sideX(r, 0.5, 83, 87, 24, 60, "#d97f8f");

    // 네온사인 (왼쪽 벽, 캐릭터 뒤)
    if (deco.has("neon")) {
      const heart = ["..##...##..", ".####.####.", "###########", "###########", ".#########.", "..#######..", "...#####...", "....###....", ".....#....."];
      sideX(r, 0.5, 6, 28, 34, 52, (y, z) => {
        const row = heart[8 - Math.floor(z / 2)];
        const c = row && row[Math.floor(y / 2)];
        return c === "#" ? "#ff5fa8" : null;
      });
    }

    // 포스터 (오른쪽 벽)
    if (deco.has("poster")) {
      sideY(r, 0.5, 44, 58, 30, 52, (x, z) => {
        if (x < 1 || x >= 13 || z < 1 || z >= 21) return "#fafafa";
        if (z > 14) return "#2b3a67";
        if (z > 8) return (x - 7) ** 2 + (z - 11) ** 2 < 9 ? "#f2c14e" : "#2b3a67";
        return "#e85d5d";
      });
    }

    // 선반 + 트로피 (오른쪽 벽)
    const buttons = [];
    if (s.followers >= 10000) buttons.push("#d9dde3");
    if (s.followers >= 100000) buttons.push("#f2c14e");
    if (s.followers >= 1000000) buttons.push("#8fe3f5");
    if (buttons.length || deco.has("figure")) {
      box(r, 8, 0, 38, 30, 6, 2, "#8a6040");
      buttons.forEach((col, i) => {
        sideY(r, 3, 10 + i * 9, 17 + i * 9, 40, 48, (x, z) => {
          if (x < 1 || x >= 6 || z < 1 || z >= 7) return shade(col, -0.2);
          return x > 2 && x < 4.5 && z > 2.5 && z < 5.5 ? "#e8463c" : col;
        });
      });
      if (deco.has("figure")) {
        sprite(r, ...at(34, 3, 40), SPR.figure, { r: "#e8463c", k: "#333" });
        sprite(r, ...at(31, 3, 40), SPR.figure2, { y: "#f2c14e", b: "#3e7bd6" });
      }
    }

    // 러그
    if (deco.has("rug")) {
      top(r, 18, 46, 74, 90, 0.3, (x, y) => {
        if (x < 2 || y < 2 || x > 54 || y > 42) return "#e7a9b8";
        return (Math.floor(x / 6) + Math.floor(y / 6)) % 2 ? "#f5d6dd" : "#f0c4cf";
      });
    }

    // 침대 (오른쪽 벽)
    box(r, 62, 0, 0, 32, 28, 8, "#8a6040");
    box(r, 62, 0, 8, 32, 28, 4, "#f5f2ec");
    box(r, 64, 3, 12, 8, 20, 3, "#ffffff");
    box(r, 74, 1, 12, 20, 26, 2, s.blanket || "#7fb3d5");
    box(r, 60, 0, 0, 2, 28, 18, "#7a5236");

    // 소프트박스 (뒤쪽 하나)
    if (g.light >= 3) sprite(r, ...at(6, 30, 0), SPR.softbox, { k: "#333", w: "#fffbe8" });

    // 의자 / 방석
    if (g.pc === 0) {
      sprite(r, ...at(SEAT.x, SEAT.y, 0), SPR.cushion, { p: "#e07a7a", P: "#f09a9a" });
    } else if (g.pc === 1) {
      box(r, SEAT.x - 6, SEAT.y - 4, 0, 2, 8, 22, "#6b6b6b");
      box(r, SEAT.x - 4, SEAT.y - 4, 10, 8, 8, 2, "#7a7a7a");
    } else {
      box(r, SEAT.x - 7, SEAT.y - 5, 0, 3, 10, 30, "#222222", { t: "#e8463c" });
      box(r, SEAT.x - 4, SEAT.y - 5, 10, 9, 10, 3, "#2a2a2a");
    }

    return r.toCanvas();
  }

  // 카메라 스프라이트의 아래쪽 가운데 (화면 좌표)
  const DESK_X = 42;
  function camPos(g) {
    const dx = DESK_X;
    if (g.camera >= 2) return at(dx + 20, 44, 0);
    if (g.camera === 0) return at(dx + 3, 32, g.pc === 0 ? 10 : 22);
    if (g.pc >= 3) return at(dx + 5, 31, 37);
    if (g.pc === 2) return at(dx + 5, 29, 37);
    if (g.pc === 1) return at(dx + 3, 32, 31);
    return at(dx + 4, 32, 10);
  }
  const CAM_H = [6, 4, 12, 14];

  function drawFront(s) {
    const r = new Raster();
    const g = s.gear;
    const deco = new Set(s.deco);
    const dx = DESK_X;
    let deskTop;

    if (g.pc === 0) {
      // 좌식 밥상
      deskTop = 10;
      box(r, dx + 1, 31, 0, 2, 2, 8, "#8a6040");
      box(r, dx + 11, 31, 0, 2, 2, 8, "#8a6040");
      box(r, dx + 1, 51, 0, 2, 2, 8, "#8a6040");
      box(r, dx + 11, 51, 0, 2, 2, 8, "#8a6040");
      box(r, dx, 30, 8, 14, 24, 2, "#c89a64");
    } else {
      deskTop = 22;
      box(r, dx, 14, 0, 14, 36, 22, "#d7c2a3", { l: "#c4ad8c" });
      top(r, dx, 14, dx + 14, 50, 22, "#e8d6ba");
      if (g.pc >= 3) {
        sideY(r, 50, dx, dx + 14, 20, 21, (x) => ["#ff5fa8", "#5fd3ff", "#b48cff"][Math.floor(x / 3) % 3]);
        sideX(r, dx + 14, 14, 50, 20, 21, (y) => ["#ff5fa8", "#5fd3ff", "#b48cff"][Math.floor(y / 3) % 3]);
      }
    }

    // PC / 모니터 (화면은 캐릭터 쪽을 보고 있어 뒷면이 보임, 얼굴을 가리지 않게 안쪽에 둠)
    if (g.pc === 1) {
      box(r, dx + 3, 26, deskTop, 7, 12, 1, "#9aa0a8");
      box(r, dx + 2, 26, deskTop + 1, 1, 12, 8, "#b8bec6");
    } else if (g.pc >= 2) {
      const mons = g.pc >= 3 ? [15, 31] : [22];
      mons.forEach((my) => {
        box(r, dx + 5, my + 6, deskTop, 2, 3, 4, "#333");
        box(r, dx + 4, my, deskTop + 4, 3, 15, 11, "#2a2a2e");
      });
      box(r, dx + 2, 56, 0, 10, 6, 18, "#222226");
      sideY(r, 62, dx + 4, dx + 10, 4, 16, (x, z) => (Math.floor(z / 2) % 2 ? "#5fd3ff" : "#ff5fa8"));
    }

    // 카메라
    const cam = camPos(g);
    if (g.camera === 0) sprite(r, cam[0], cam[1], SPR.phone, { k: "#222", b: "#5c7cfa", s: "#888" });
    else if (g.camera === 1) sprite(r, cam[0], cam[1], SPR.webcam, { k: "#222", b: "#5c7cfa" });
    else if (g.camera === 2) sprite(r, cam[0], cam[1], SPR.mirrorless, { k: "#222", b: "#5c7cfa", B: "#9fb4ff" });
    else sprite(r, cam[0], cam[1], SPR.cinema, { k: "#1b1b1b", b: "#5c7cfa", B: "#9fb4ff", r: "#e8463c" });

    // 마이크
    if (g.mic === 2) sprite(r, ...at(dx + 1, 46, deskTop), SPR.boom, { k: "#222" });
    if (g.mic >= 3) {
      sprite(r, ...at(dx + 2, 45, deskTop), SPR.studio, { s: "#c0c4ca", S: "#8a8f96", k: "#333" });
      box(r, dx + 8, 40, deskTop, 5, 6, 3, "#c0392b");
    }

    // 조명
    if (g.light === 1) sprite(r, ...at(dx + 4, g.pc >= 1 ? 18 : 33, deskTop), SPR.lamp, { w: "#f4f4f4", y: "#fff3b0", k: "#555" });
    if (g.light === 2) sprite(r, ...at(dx + 16, 64, 0), SPR.ring, { w: "#fffbe8", k: "#444" });
    if (g.light >= 3) sprite(r, ...at(dx + 18, 70, 0), SPR.softbox, { k: "#333", w: "#fffbe8" });

    // 꾸미기 소품
    if (deco.has("plant")) sprite(r, ...at(6, 88, 0), SPR.plant, { g: "#3f8f4f", G: "#62b86e", p: "#b5653a", P: "#d07a4a" });
    if (deco.has("beanbag")) sprite(r, ...at(84, 64, 0), SPR.beanbag, { b: "#e0864f", B: "#f2a066", d: "#9c5a33" });

    return r.toCanvas();
  }

  // ───── 동적 레이어 (캐릭터, 효과) ─────
  function px(ctx, x, y, w, h, col) {
    ctx.fillStyle = col;
    ctx.fillRect(Math.round(x), Math.round(y), w, h);
  }

  function drawRows(ctx, rows, pal, x0, y0) {
    rows.forEach((row, j) => {
      for (let i = 0; i < row.length; i++) {
        const c = pal[row[i]];
        if (c) px(ctx, x0 + i, y0 + j, 1, 1, c);
      }
    });
  }

  const HEART = [".#.#.", "#####", "#####", ".###.", "..#.."];

  class Room {
    constructor(canvas) {
      this.canvas = canvas;
      canvas.width = W;
      canvas.height = H;
      this.ctx = canvas.getContext("2d");
      this.mode = "idle";
      this.particles = [];
      this.tick = 0;
      this.running = false;
    }

    // s: 게임 상태 (gear, deco, followers, slot, look)
    update(s, mode = this.mode) {
      this.s = s;
      this.mode = mode;
      this.back = drawBack(s);
      this.front = drawFront(s);
      if (!this.running) this.start();
      else this.draw();
    }

    setMode(mode) {
      this.mode = mode;
    }

    start() {
      this.running = true;
      let last = 0;
      const loop = (t) => {
        if (!this.canvas.isConnected) {
          this.running = false;
          return;
        }
        if (t - last > 90) {
          last = t;
          this.tick++;
          this.step();
          this.draw();
        }
        requestAnimationFrame(loop);
      };
      requestAnimationFrame(loop);
    }

    burst(kind, n = 6) {
      const [cx, cy] = at(SEAT.x, SEAT.y, 26);
      for (let i = 0; i < n; i++) {
        this.particles.push({
          kind,
          x: cx + (Math.random() * 24 - 12),
          y: cy + Math.random() * 6,
          vy: -(0.6 + Math.random() * 0.8),
          life: 22 + Math.random() * 14,
        });
      }
    }

    step() {
      if (this.mode === "live" && this.tick % 4 === 0) this.burst(Math.random() < 0.7 ? "heart" : "chat", 1);
      if (this.mode === "sleep" && this.tick % 10 === 0) {
        const [x, y] = at(PILLOW.x, PILLOW.y, PILLOW.z + 10);
        this.particles.push({ kind: "z", x: x + 2, y, vy: -0.4, life: 26 });
      }
      this.particles.forEach((p) => {
        p.y += p.vy;
        p.x += Math.sin((p.life + p.y) / 4) * 0.3;
        p.life--;
      });
      this.particles = this.particles.filter((p) => p.life > 0);
    }

    draw() {
      const { ctx, s } = this;
      if (!s) return;
      ctx.clearRect(0, 0, W, H);
      ctx.drawImage(this.back, 0, 0);

      const look = s.look;
      const live = this.mode === "live";
      const f = {
        blink: this.tick % 40 === 0 || this.tick % 40 === 1,
        talk: live && Math.floor(this.tick / 2) % 3 !== 0,
      };
      const pal = charPalette(look, f);

      if (this.mode === "sleep") {
        const [hx, hy] = at(PILLOW.x, PILLOW.y, PILLOW.z);
        const rows = headRows(look, true).slice(0, 10);
        drawRows(ctx, rows, pal, hx - 6, hy - 9);
      } else if (this.mode !== "away") {
        const seated = this.mode === "live" || this.mode === "idle";
        const [cx, cy] = seated ? at(SEAT.x, SEAT.y, s.gear.pc === 0 ? 0 : 12) : at(48, 74, 0);
        const bob = live ? (this.tick % 6 < 3 ? 0 : -1) : this.tick % 20 < 10 ? 0 : -1;
        const body = !seated ? BODY_STAND : live && this.tick % 14 < 4 ? ARMS_UP : BODY_SIT;
        const head = headRows(look, false);
        const rows = [...head.slice(0, 10), ...body];
        const x0 = cx - 6;
        const y0 = cy - rows.length + bob;
        drawRows(ctx, body, pal, x0, y0 + 10 - bob);
        drawRows(ctx, head, pal, x0, y0);
        if (s.gear.mic === 1) px(ctx, x0 + 4, y0 + 11 - bob, 1, 1, "#222");
        if (live && s.gear.light >= 2) {
          ctx.fillStyle = "rgba(255,250,220,0.18)";
          ctx.fillRect(x0 - 2, y0 - 2, 16, rows.length + 4);
        }
      }

      ctx.drawImage(this.front, 0, 0);

      // 시간대 조명
      const slot = s.slot ?? 0;
      if (slot === 2) {
        const dim = [0.42, 0.34, 0.24, 0.16][s.gear.light] ?? 0.3;
        ctx.fillStyle = `rgba(16,18,52,${dim})`;
        ctx.fillRect(0, 0, W, H);
      } else if (slot === 1) {
        ctx.fillStyle = "rgba(255,150,60,0.08)";
        ctx.fillRect(0, 0, W, H);
      }

      // 네온 빛 번짐
      if (s.deco.includes("neon")) {
        const [nx, ny] = at(0, 17, 44);
        const a = (slot === 2 ? 0.35 : 0.15) + (this.tick % 10 < 5 ? 0.05 : 0);
        const glow = ctx.createRadialGradient(nx, ny, 2, nx, ny, 26);
        glow.addColorStop(0, `rgba(255,95,168,${a})`);
        glow.addColorStop(1, "rgba(255,95,168,0)");
        ctx.fillStyle = glow;
        ctx.fillRect(nx - 26, ny - 26, 52, 52);
      }

      // 방송 중 빨간 불
      if (live && this.tick % 8 < 5) {
        const [cx, cy] = camPos(s.gear);
        px(ctx, cx + 1, cy - CAM_H[s.gear.camera] - 2, 2, 2, "#ff3b3b");
      }
      // 모니터 빛
      if (live && s.gear.pc >= 1) {
        const [cx, cy] = at(SEAT.x, SEAT.y, 30);
        ctx.fillStyle = "rgba(95,211,255,0.12)";
        ctx.fillRect(cx - 4, cy - 2, 12, 10);
      }

      this.particles.forEach((p) => {
        const alpha = Math.min(1, p.life / 10);
        ctx.globalAlpha = alpha;
        if (p.kind === "heart") drawRows(ctx, HEART, { "#": "#ff5f8f" }, p.x, p.y);
        else if (p.kind === "coin") {
          px(ctx, p.x, p.y, 4, 4, "#f2c14e");
          px(ctx, p.x + 1, p.y + 1, 2, 2, "#c99a2e");
        } else if (p.kind === "chat") {
          px(ctx, p.x, p.y, 7, 4, "#ffffff");
          px(ctx, p.x + 1, p.y + 4, 1, 1, "#ffffff");
          px(ctx, p.x + 1, p.y + 1, 5, 1, "#9aa0a8");
          px(ctx, p.x + 1, p.y + 2, 3, 1, "#9aa0a8");
        } else if (p.kind === "z") {
          ctx.fillStyle = "#ffffff";
          ctx.font = "8px monospace";
          ctx.fillText("z", p.x, p.y);
        } else if (p.kind === "bad") {
          px(ctx, p.x, p.y, 5, 5, "#555");
          px(ctx, p.x + 2, p.y + 1, 1, 2, "#fff");
          px(ctx, p.x + 2, p.y + 4, 1, 1, "#fff");
        }
      });
      ctx.globalAlpha = 1;
    }
  }

  IF.Room = Room;
})();
