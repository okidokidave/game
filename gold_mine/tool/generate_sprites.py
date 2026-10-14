"""골드 광산 키우기의 도트(픽셀) 그림을 코드로 그려서 PNG로 저장한다.

실행: python3 tool/generate_sprites.py   (gold_mine 폴더에서)
결과: assets/sprites/*.png

나중에 디자이너가 그린 그림으로 바꾸려면 같은 이름, 같은 칸 크기로
PNG를 덮어쓰면 된다. 칸 크기는 lib/scene/sprites.dart 에 적혀 있다.
"""

import os
import random

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sprites')

# ── 색상표 ──────────────────────────────────────────────
OUTLINE = (43, 29, 20, 255)
SKIN = (242, 194, 155, 255)
SKIN_D = (205, 140, 100, 255)
HELMET = (247, 195, 49, 255)
HELMET_D = (201, 143, 28, 255)
LAMP = (255, 248, 190, 255)
SHIRT = (59, 110, 168, 255)
SHIRT_D = (40, 78, 122, 255)
PANTS = (94, 64, 45, 255)
PANTS_D = (64, 44, 31, 255)
BOOT = (42, 28, 20, 255)
WOOD = (150, 98, 54, 255)
WOOD_D = (107, 68, 35, 255)
WOOD_L = (186, 130, 76, 255)
METAL = (201, 209, 217, 255)
METAL_D = (125, 138, 150, 255)
GOLD = (255, 210, 63, 255)
GOLD_D = (217, 154, 30, 255)
GOLD_L = (255, 245, 170, 255)
SACK = (166, 124, 82, 255)
SACK_D = (122, 86, 56, 255)
EYE = (26, 26, 26, 255)
CLEAR = (0, 0, 0, 0)

# 층별 암석 색 (깊어질수록 바뀐다). (밝음, 보통, 어두움, 광석, 광석 그림자, 광석 하이라이트)
THEMES = [
    ((150, 108, 72), (122, 86, 56), (92, 64, 42), GOLD, GOLD_D, GOLD_L),  # 흙
    ((140, 140, 150), (112, 112, 124), (82, 82, 94), GOLD, GOLD_D, GOLD_L),  # 돌
    ((96, 92, 110), (72, 68, 86), (50, 47, 62), GOLD, GOLD_D, GOLD_L),  # 깊은 돌
    ((110, 86, 150), (84, 62, 120), (58, 42, 88),
     (120, 230, 255, 255), (60, 160, 210, 255), (220, 250, 255, 255)),  # 수정
    ((110, 60, 50), (84, 42, 36), (58, 28, 24),
     (255, 140, 40, 255), (210, 70, 20, 255), (255, 230, 120, 255)),  # 용암
]


def rgba(c):
    return c if len(c) == 4 else (*c, 255)


class Canvas:
    def __init__(self, w, h):
        self.img = Image.new('RGBA', (w, h), CLEAR)
        self.w, self.h = w, h

    def px(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.img.putpixel((x, y), rgba(c))

    def rect(self, x, y, w, h, c):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.px(xx, yy, c)

    def line(self, x0, y0, x1, y1, c):
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        while True:
            self.px(x0, y0, c)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def outline(self, color=OUTLINE):
        """불투명한 픽셀 둘레에 1픽셀 테두리를 그린다."""
        src = self.img.copy()
        for y in range(self.h):
            for x in range(self.w):
                if src.getpixel((x, y))[3] != 0:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < self.w and 0 <= ny < self.h and src.getpixel((nx, ny))[3] != 0:
                        self.img.putpixel((x, y), color)
                        break


# ── 인부 ────────────────────────────────────────────────
MINER_W, MINER_H = 24, 22


def pickaxe(c, hx, hy, ex, ey, head_dir):
    """손(hx,hy)에서 끝(ex,ey)까지 자루, 끝에 곡괭이 머리."""
    c.line(hx, hy, ex, ey, WOOD)
    # 머리: 자루 끝에서 수직 방향으로 휜 금속
    if head_dir == 'up':  # 머리가 위쪽 (들어 올린 자세)
        c.rect(ex - 2, ey - 1, 5, 1, METAL)
        c.px(ex - 3, ey, METAL_D)
        c.px(ex + 3, ey, METAL_D)
    elif head_dir == 'down':  # 머리가 아래쪽 (내려찍은 자세)
        c.rect(ex - 1, ey - 2, 1, 5, METAL)
        c.px(ex, ey - 3, METAL_D)
        c.px(ex, ey + 3, METAL_D)
    else:  # 어깨에 멘 자세
        c.rect(ex - 1, ey - 1, 3, 1, METAL)
        c.px(ex - 2, ey, METAL_D)
        c.px(ex + 2, ey + 0, METAL_D)


def miner(legs=0, bob=0, pose='walk', carry=False):
    c = Canvas(MINER_W, MINER_H)
    ox, oy = 7, 2 + bob  # 몸 기준점

    # 등에 진 광석 자루 (몸 뒤에 먼저 그린다)
    if carry:
        c.rect(ox - 4, oy + 6, 5, 6, SACK)
        c.rect(ox - 4, oy + 10, 5, 2, SACK_D)
        c.rect(ox - 3, oy + 4, 3, 2, GOLD)
        c.px(ox - 2, oy + 4, GOLD_L)
        c.px(ox - 4, oy + 5, GOLD_D)

    # 걸을 때는 곡괭이를 등 뒤에 비스듬히 멘다 (몸 뒤에 먼저 그린다)
    if pose == 'walk' and not carry:
        pickaxe(c, ox + 3, oy + 12, ox - 1, oy + 5, 'up')

    # 다리 (legs: 0 서기, 1 앞다리 앞, 2 서기, 3 뒷다리 앞)
    stride = {0: 0, 1: 2, 2: 0, 3: -2}[legs]
    hip = oy + 13
    for dx, col in ((-stride, PANTS_D), (stride, PANTS)):
        lx = ox + 3 + dx
        # 허벅지는 엉덩이에서, 종아리는 발 위치로 비스듬히
        c.rect(ox + 3, hip, 3, 1, col)
        c.rect(lx, hip + 1, 2, 18 - hip - 1, col)
        c.rect(lx, 18, 3, 2, BOOT)

    # 몸통
    c.rect(ox + 1, oy + 8, 6, 5, SHIRT)
    c.rect(ox + 1, oy + 11, 6, 2, SHIRT_D)
    c.rect(ox + 1, oy + 12, 6, 1, PANTS_D)  # 허리띠

    # 머리
    c.rect(ox + 2, oy + 3, 5, 5, SKIN)
    c.rect(ox + 2, oy + 7, 5, 1, SKIN_D)
    c.px(ox + 5, oy + 5, EYE)
    c.px(ox + 7, oy + 5, SKIN)  # 코
    # 안전모
    c.rect(ox + 2, oy, 5, 3, HELMET)
    c.rect(ox + 1, oy + 1, 1, 2, HELMET)
    c.rect(ox + 1, oy + 3, 8, 1, HELMET_D)
    c.rect(ox + 6, oy + 1, 2, 1, LAMP)

    # 팔과 곡괭이 (앞쪽 팔)
    sx, sy = ox + 4, oy + 9  # 어깨
    if pose == 'walk':
        if carry:
            # 자루 끈을 잡은 팔
            c.rect(sx - 1, sy, 2, 3, SHIRT_D)
            c.px(sx - 1, sy + 3, SKIN)
        else:
            swing = {0: 0, 1: 1, 2: 0, 3: -1}[legs]
            c.rect(sx + swing, sy, 2, 3, SHIRT_D)
            c.px(sx + 1 + swing, sy + 3, SKIN)
    elif pose == 'windup':
        c.line(sx, sy, sx - 1, sy - 4, SHIRT_D)
        c.px(sx - 1, sy - 5, SKIN)
        pickaxe(c, sx - 1, sy - 5, sx - 5, sy - 8, 'up')
    elif pose == 'mid':
        c.line(sx, sy, sx + 3, sy - 3, SHIRT_D)
        c.px(sx + 4, sy - 4, SKIN)
        pickaxe(c, sx + 4, sy - 4, sx + 9, sy - 6, 'up')
    elif pose == 'hit':
        c.line(sx, sy, sx + 4, sy + 1, SHIRT_D)
        c.px(sx + 5, sy + 1, SKIN)
        pickaxe(c, sx + 5, sy + 1, sx + 11, sy + 2, 'down')

    c.outline()
    return c.img


def miner_sheet():
    frames = []
    for i in range(4):  # 0-3: 걷기
        frames.append(miner(legs=i, bob=1 if i % 2 else 0))
    for i in range(4):  # 4-7: 광석 지고 걷기
        frames.append(miner(legs=i, bob=1 if i % 2 else 0, carry=True))
    for pose in ('windup', 'mid', 'hit'):  # 8-10: 곡괭이질
        frames.append(miner(pose=pose))
    frames.append(miner())  # 11: 서 있기
    return strip(frames)


def strip(frames):
    w, h = frames[0].size
    sheet = Image.new('RGBA', (w * len(frames), h), CLEAR)
    for i, f in enumerate(frames):
        sheet.paste(f, (i * w, 0))
    return sheet


# ── 암벽 (광석이 박힌 벽) ───────────────────────────────
WALL_W, WALL_H = 20, 34


def wall(theme, seed):
    light, mid, dark, ore, ore_d, ore_l = theme
    rnd = random.Random(seed)
    c = Canvas(WALL_W, WALL_H)
    # 오른쪽 가장자리가 울퉁불퉁한 바위
    edge = []
    x = WALL_W - 4
    for y in range(WALL_H):
        x = max(WALL_W - 7, min(WALL_W - 1, x + rnd.choice((-1, 0, 0, 1))))
        edge.append(x)
    for y in range(WALL_H):
        for x in range(edge[y] + 1):
            r = rnd.random()
            col = mid if r < 0.6 else (dark if r < 0.85 else light)
            c.px(x, y, col)
        c.px(edge[y], y, dark)
    # 광석 덩어리
    for _ in range(5):
        cx, cy = rnd.randint(2, WALL_W - 9), rnd.randint(2, WALL_H - 5)
        c.rect(cx, cy, 3, 2, ore)
        c.px(cx + 1, cy + 2, ore_d)
        c.px(cx + 3, cy + 1, ore_d)
        c.px(cx, cy, ore_l)
    return c.img


def wall_sheet():
    return strip([wall(t, i * 7 + 3) for i, t in enumerate(THEMES)])


# ── 굴 안쪽 배경 (타일) ──────────────────────────────────
TILE = 16


def tile(theme, seed):
    light, mid, dark = theme[:3]
    rnd = random.Random(seed)
    c = Canvas(TILE, TILE)
    base = tuple(int(v * 0.55) for v in mid)
    for y in range(TILE):
        for x in range(TILE):
            r = rnd.random()
            col = base
            if r > 0.9:
                col = tuple(int(v * 0.45) for v in dark)
            elif r > 0.8:
                col = tuple(int(v * 0.65) for v in mid)
            c.px(x, y, col)
    return c.img


def tile_sheet():
    return strip([tile(t, i + 11) for i, t in enumerate(THEMES)])


# ── 땅속 흙 (층 사이 두꺼운 흙) ──────────────────────────
def dirt(theme, seed):
    light, mid, dark = theme[:3]
    rnd = random.Random(seed)
    c = Canvas(TILE, TILE)
    for y in range(TILE):
        for x in range(TILE):
            r = rnd.random()
            col = mid if r < 0.55 else (dark if r < 0.85 else light)
            c.px(x, y, col)
    for _ in range(2):
        sx, sy = rnd.randint(1, TILE - 3), rnd.randint(1, TILE - 3)
        c.rect(sx, sy, 2, 2, light)
        c.px(sx + 1, sy + 1, dark)
    return c.img


def dirt_sheet():
    return strip([dirt(t, i + 23) for i, t in enumerate(THEMES)])


# ── 광석 상자 ───────────────────────────────────────────
CRATE_W, CRATE_H = 14, 12


def crate(level):
    c = Canvas(CRATE_W, CRATE_H)
    c.rect(1, 4, 12, 8, WOOD)
    c.rect(1, 4, 12, 1, WOOD_L)
    c.rect(1, 8, 12, 1, WOOD_D)
    c.rect(1, 4, 1, 8, WOOD_D)
    c.rect(12, 4, 1, 8, WOOD_D)
    # 금 더미 (level 0: 비어 있음, 1: 조금, 2: 가득)
    if level >= 1:
        c.rect(3, 2, 8, 2, GOLD)
        c.px(5, 2, GOLD_L)
        c.px(9, 3, GOLD_D)
    if level >= 2:
        c.rect(4, 0, 6, 2, GOLD)
        c.px(6, 0, GOLD_L)
        c.px(8, 1, GOLD_D)
    c.outline()
    return c.img


def crate_sheet():
    return strip([crate(i) for i in range(3)])


# ── 엘리베이터 칸 ───────────────────────────────────────
CAGE_W, CAGE_H = 16, 18


def cage(loaded):
    c = Canvas(CAGE_W, CAGE_H)
    c.rect(1, 1, 14, 2, METAL_D)
    c.rect(1, 15, 14, 2, METAL_D)
    for x in (1, 5, 10, 14):
        c.rect(x, 3, 1, 12, METAL)
    c.rect(7, 0, 2, 1, METAL)
    if loaded:
        c.rect(3, 11, 10, 4, SACK)
        c.rect(4, 9, 8, 2, GOLD)
        c.px(6, 9, GOLD_L)
        c.px(10, 10, GOLD_D)
    c.outline()
    return c.img


def cage_sheet():
    return strip([cage(False), cage(True)])


# ── 광차 (수레) ─────────────────────────────────────────
CART_W, CART_H = 20, 13


def cart(loaded, wheel):
    c = Canvas(CART_W, CART_H)
    c.rect(2, 3, 16, 6, METAL_D)
    c.rect(2, 3, 16, 1, METAL)
    c.rect(1, 2, 18, 1, METAL)
    if loaded:
        c.rect(4, 0, 12, 3, GOLD)
        c.px(6, 0, GOLD_L)
        c.px(12, 1, GOLD_L)
        c.px(9, 2, GOLD_D)
    for wx in (4, 13):
        c.rect(wx, 9, 3, 3, (60, 60, 66, 255))
        if wheel:
            c.px(wx + 1, 10, METAL)
        else:
            c.px(wx, 9, METAL)
            c.px(wx + 2, 11, METAL)
    c.outline()
    return c.img


def cart_sheet():
    return strip([cart(l, w) for l in (False, True) for w in (0, 1)])


# ── 창고 ────────────────────────────────────────────────
HOUSE_W, HOUSE_H = 34, 28


def warehouse():
    c = Canvas(HOUSE_W, HOUSE_H)
    roof = (168, 64, 52, 255)
    roof_d = (124, 44, 38, 255)
    for i in range(9):
        c.rect(1 + i, 9 - i, HOUSE_W - 2 - 2 * i, 1, roof if i % 2 else roof_d)
    c.rect(3, 10, HOUSE_W - 6, 17, WOOD)
    for x in range(3, HOUSE_W - 3, 4):
        c.rect(x, 10, 1, 17, WOOD_D)
    c.rect(12, 16, 10, 11, WOOD_D)  # 문
    c.rect(16, 16, 1, 11, (70, 44, 24, 255))
    # 금화 간판
    c.rect(14, 5, 6, 5, GOLD)
    c.rect(16, 6, 2, 3, GOLD_D)
    c.px(15, 5, GOLD_L)
    c.outline()
    return c.img


# ── 도르래 바퀴 (엘리베이터 탑) ─────────────────────────
WHEEL = 10


def wheel(frame):
    c = Canvas(WHEEL, WHEEL)
    for y in range(WHEEL):
        for x in range(WHEEL):
            d = ((x - 4.5) ** 2 + (y - 4.5) ** 2) ** 0.5
            if 3.4 < d <= 4.6:
                c.px(x, y, METAL_D)
    if frame == 0:
        c.line(1, 4, 8, 5, METAL)
        c.line(4, 1, 5, 8, METAL)
    else:
        c.line(2, 2, 7, 7, METAL)
        c.line(7, 2, 2, 7, METAL)
    c.rect(4, 4, 2, 2, METAL)
    return c.img


def wheel_sheet():
    return strip([wheel(0), wheel(1)])


# ── 구름 ────────────────────────────────────────────────
def cloud():
    c = Canvas(22, 8)
    white = (245, 248, 255, 255)
    shade = (210, 222, 240, 255)
    c.rect(3, 3, 16, 4, white)
    c.rect(6, 1, 6, 3, white)
    c.rect(11, 0, 5, 3, white)
    c.rect(3, 6, 16, 1, shade)
    return c.img


def main():
    os.makedirs(OUT, exist_ok=True)
    sheets = {
        'miner.png': miner_sheet(),
        'wall.png': wall_sheet(),
        'tunnel.png': tile_sheet(),
        'dirt.png': dirt_sheet(),
        'crate.png': crate_sheet(),
        'cage.png': cage_sheet(),
        'cart.png': cart_sheet(),
        'warehouse.png': warehouse(),
        'wheel.png': wheel_sheet(),
        'cloud.png': cloud(),
    }
    for name, img in sheets.items():
        img.save(os.path.join(OUT, name))
        print(f'{name}: {img.size[0]}x{img.size[1]}')


if __name__ == '__main__':
    main()
