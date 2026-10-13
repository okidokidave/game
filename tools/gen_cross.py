# 사용법: python3 tools/gen_cross.py tools 결과.json  (words.py가 있는 폴더, 출력 파일)
import random, json, sys
sys.path.insert(0, sys.argv[1])
from words import WORDS

MAX = 7  # 판 크기 한도 (모바일에서 7칸)

def try_build(words, rng, target):
    grid = {}  # (r,c) -> ch
    placed = []  # (word, r, c, dir)
    owner = {}  # (r,c) -> set(dirs)
    def bbox(extra=()):
        cells = list(grid.keys()) + list(extra)
        rs = [p[0] for p in cells]; cs = [p[1] for p in cells]
        return min(rs), max(rs), min(cs), max(cs)
    def can_place(w, r, c, d):
        dr, dc = (0, 1) if d == 'A' else (1, 0)
        cells = [(r + dr * i, c + dc * i) for i in range(len(w))]
        # 앞뒤 칸 비어 있어야
        before = (r - dr, c - dc); after = (r + dr * len(w), c + dc * len(w))
        if before in grid or after in grid: return False
        crosses = 0
        for (cr, cc), ch in zip(cells, w):
            if (cr, cc) in grid:
                if grid[(cr, cc)] != ch or d in owner[(cr, cc)]: return False
                crosses += 1
            else:
                # 옆 칸(수직 방향)이 비어 있어야 의도치 않은 단어가 안 생김
                for nb in [(cr + dc, cc + dr), (cr - dc, cc - dr)]:
                    if nb in grid: return False
        if placed and crosses == 0: return False
        r0, r1, c0, c1 = bbox(cells) if grid else (min(p[0] for p in cells), max(p[0] for p in cells), min(p[1] for p in cells), max(p[1] for p in cells))
        if r1 - r0 + 1 > MAX or c1 - c0 + 1 > MAX: return False
        return cells
    def place(w, cells, d):
        for p, ch in zip(cells, w):
            grid[p] = ch; owner.setdefault(p, set()).add(d)
        placed.append((w, cells[0][0], cells[0][1], d))
    first = rng.choice([w for w in words if len(w) >= 3])
    place(first, can_place(first, 0, 0, 'A'), 'A')
    pool = [w for w in words if w != first]
    order = pool[:]; rng.shuffle(order)
    for w in order:
        if len(placed) >= target: break
        if not any(ch in grid.values() for ch in w): continue
        opts = []
        for i, ch in enumerate(w):
            for (gr, gc), gch in list(grid.items()):
                if gch != ch: continue
                for d in 'AD':
                    dr, dc = (0, 1) if d == 'A' else (1, 0)
                    r, c = gr - dr * i, gc - dc * i
                    cells = can_place(w, r, c, d)
                    if cells: opts.append((cells, d))
        if opts:
            cells, d = rng.choice(opts)
            place(w, cells, d)
    return grid, placed

def runs(grid):
    out = set()
    for d in 'AD':
        dr, dc = (0, 1) if d == 'A' else (1, 0)
        for (r, c) in grid:
            if (r - dr, c - dc) in grid: continue
            w = ''; rr, cc = r, c
            while (rr, cc) in grid:
                w += grid[(rr, cc)]; rr += dr; cc += dc
            if len(w) >= 2: out.add((w, r, c, d))
    return out

def build_puzzle(words, seed, target=10, tries=200):
    rng = random.Random(seed)
    best = None
    for _ in range(tries):
        grid, placed = try_build(words, rng, target)
        if best is None or len(placed) > len(best[1]):
            best = (grid, placed)
        if len(placed) >= target: break
    grid, placed = best
    assert runs(grid) == set(placed), "의도치 않은 단어가 생김"
    r0 = min(p[0] for p in grid); c0 = min(p[1] for p in grid)
    rows = max(p[0] for p in grid) - r0 + 1; cols = max(p[1] for p in grid) - c0 + 1
    entries = sorted([(r - r0, c - c0, d, w) for (w, r, c, d) in placed])
    # 번호 매기기 (위→아래, 왼→오)
    starts = sorted({(r, c) for r, c, d, w in entries})
    num = {p: i + 1 for i, p in enumerate(starts)}
    out = [{"n": num[(r, c)], "dir": "across" if d == 'A' else "down", "row": r, "col": c, "answer": w, "clue": WORDS[w]}
           for r, c, d, w in entries]
    out.sort(key=lambda e: (e["dir"], e["n"]))
    return {"rows": rows, "cols": cols, "entries": out}

if __name__ == '__main__':
    words = list(WORDS)
    puzzles = []
    used = set()
    seed = 1
    while len(puzzles) < 8 and seed < 500:
        avail = [w for w in words if w not in used]
        p = build_puzzle(avail, seed)
        seed += 1
        if len(p["entries"]) < 10: continue
        puzzles.append(p)
        used |= {e["answer"] for e in p["entries"]}
    for i, p in enumerate(puzzles):
        print(f"#{i+1} {p['rows']}x{p['cols']} words={len(p['entries'])}", file=sys.stderr)
    json.dump(puzzles, open(sys.argv[2], 'w'), ensure_ascii=False)
