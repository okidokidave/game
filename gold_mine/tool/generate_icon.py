"""앱 아이콘(도트 광부 + 곡괭이 + 금 더미)을 그려서 안드로이드 아이콘 파일로 저장한다.

실행: python3 tool/generate_icon.py   (gold_mine 폴더에서)
결과:
  android/app/src/main/res/mipmap-*/ic_launcher.png        (안드로이드 7 이하)
  android/app/src/main/res/mipmap-*/ic_launcher_foreground.png (8 이상, 적응형)
  android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml
  assets/icon/store_icon_512.png  (스토어 등록용 512x512)

그림은 24x24 도트로 그리고, 정수 배로만 키워서 픽셀이 뭉개지지 않게 한다.
"""

import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from generate_sprites import (  # noqa: E402
    BOOT, Canvas, CLEAR, EYE, GOLD, GOLD_D, GOLD_L, HELMET, HELMET_D, LAMP,
    METAL, METAL_D, OUTLINE, PANTS, PANTS_D, SHIRT, SHIRT_D, SKIN, SKIN_D,
    WOOD,
)

ROOT = os.path.join(os.path.dirname(__file__), '..')
RES = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')

ART = 24
BG = (62, 40, 22, 255)  # 진한 갱도 갈색
BG_GLOW = (138, 92, 40, 255)  # 가운데 금빛


def art():
    """24x24: 곡괭이를 치켜든 광부와 금 더미."""
    c = Canvas(ART, ART)

    # 곡괭이 (몸 뒤에 먼저): 자루와 휜 머리
    c.line(12, 10, 18, 3, WOOD)
    c.line(13, 10, 19, 3, WOOD)
    for x, y in ((14, 1), (15, 1), (16, 1), (17, 2), (18, 2), (19, 2),
                 (20, 3), (21, 4), (22, 5)):
        c.px(x, y, METAL)
    for x, y in ((13, 2), (14, 2), (20, 4), (21, 5), (22, 6)):
        c.px(x, y, METAL_D)

    # 다리와 장화
    c.rect(5, 17, 2, 4, PANTS_D)
    c.rect(8, 17, 2, 4, PANTS)
    c.rect(4, 21, 3, 2, BOOT)
    c.rect(8, 21, 3, 2, BOOT)

    # 몸통과 허리띠
    c.rect(4, 11, 7, 6, SHIRT)
    c.rect(4, 14, 7, 2, SHIRT_D)
    c.rect(4, 16, 7, 1, PANTS_D)
    c.px(7, 16, GOLD)  # 허리띠 버클

    # 곡괭이를 든 팔
    c.rect(9, 11, 2, 2, SHIRT_D)
    c.rect(11, 10, 2, 2, SHIRT_D)
    c.rect(12, 9, 2, 2, SKIN)

    # 얼굴
    c.rect(5, 6, 5, 5, SKIN)
    c.rect(5, 10, 5, 1, SKIN_D)
    c.px(8, 8, EYE)
    c.px(10, 8, SKIN)  # 코
    c.rect(6, 9, 2, 1, SKIN_D)  # 웃는 입

    # 안전모
    c.rect(5, 3, 5, 3, HELMET)
    c.rect(4, 4, 1, 2, HELMET)
    c.rect(4, 6, 8, 1, HELMET_D)
    c.rect(9, 4, 2, 1, LAMP)
    c.px(6, 3, (255, 236, 150, 255))  # 반짝

    # 금 더미 (오른쪽 아래)
    c.rect(13, 19, 10, 3, GOLD)
    c.rect(15, 17, 6, 2, GOLD)
    c.rect(17, 15, 3, 2, GOLD)
    c.rect(13, 21, 10, 1, GOLD_D)
    for x, y in ((16, 17), (18, 15), (14, 19), (20, 19), (19, 17)):
        c.px(x, y, GOLD_L)
    for x, y in ((17, 20), (21, 20), (15, 20), (19, 18)):
        c.px(x, y, GOLD_D)

    c.outline(OUTLINE)

    # 금빛 반짝임 (테두리 밖)
    for x, y in ((22, 13), (12, 15), (21, 9)):
        c.px(x, y, GOLD_L)
    c.px(22, 12, GOLD)
    c.px(22, 14, GOLD)
    c.px(21, 13, GOLD)
    c.px(23, 13, GOLD)
    return c.img


def background(size_px, rounded):
    """진한 갈색 바탕 + 가운데 은은한 금빛. 도트처럼 계단식 원."""
    img = Image.new('RGBA', (size_px, size_px), CLEAR)
    cx = cy = (size_px - 1) / 2
    for y in range(size_px):
        for x in range(size_px):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5 / (size_px / 2)
            if rounded:
                # 모서리를 둥글게 (스토어·구형 아이콘용)
                r = size_px * 0.18
                dx = max(abs(x - cx) - (size_px / 2 - r), 0)
                dy = max(abs(y - cy) - (size_px / 2 - r), 0)
                if dx * dx + dy * dy > r * r:
                    continue
            step = min(3, int(d * 4))
            t = step / 3
            col = tuple(int(BG_GLOW[i] * (1 - t) + BG[i] * t) for i in range(3))
            img.putpixel((x, y), (*col, 255))
    return img


def scaled(img, k):
    return img.resize((img.width * k, img.height * k), Image.NEAREST)


def composite(canvas_cells, art_offset, k, rounded):
    """canvas_cells x canvas_cells 칸 바탕 위에 그림을 놓고 k배로 키운다."""
    bg = background(canvas_cells, rounded)
    bg.alpha_composite(art(), (art_offset, art_offset))
    return scaled(bg, k)


DENSITIES = {  # 이름: 배율 (mdpi = 1). 모든 크기가 2배 칸의 정수 배라 픽셀이 깨끗하다.
    'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4,
}


# 적응형 전경에서 그림 한 칸의 픽셀 수 (원형 마스크에서도 잘리지 않을 만큼).
FOREGROUND_CELL = {'mdpi': 2, 'hdpi': 4, 'xhdpi': 5, 'xxhdpi': 7, 'xxxhdpi': 10}


def main():
    # 구형 아이콘: 48dp 칸 전체를 24칸 그림으로 채운다 → 48dp = 24칸 × 2
    for name, d in DENSITIES.items():
        k = int(2 * d)
        icon = composite(ART, 0, k, rounded=True)
        path = os.path.join(RES, f'mipmap-{name}', 'ic_launcher.png')
        icon.save(path)

        # 적응형 전경: 108dp 캔버스의 안전 영역(가운데 66dp) 안에 그림을 크게.
        # 칸 하나를 정수 픽셀로 키워야 도트가 깨끗하다.
        size = int(108 * d)
        cell = FOREGROUND_CELL[name]
        fg = Image.new('RGBA', (size, size), CLEAR)
        big = scaled(art(), cell)
        offset = (size - big.width) // 2
        fg.alpha_composite(big, (offset, offset))
        fg.save(os.path.join(RES, f'mipmap-{name}', 'ic_launcher_foreground.png'))

    anydpi = os.path.join(RES, 'mipmap-anydpi-v26')
    os.makedirs(anydpi, exist_ok=True)
    with open(os.path.join(anydpi, 'ic_launcher.xml'), 'w') as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<adaptive-icon xmlns:android='
            '"http://schemas.android.com/apk/res/android">\n'
            '    <background android:drawable="@color/ic_launcher_background"/>\n'
            '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
            '</adaptive-icon>\n'
        )
    values = os.path.join(RES, 'values', 'ic_launcher_background.xml')
    with open(values, 'w') as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
            '    <color name="ic_launcher_background">#5C3A1C</color>\n'
            '</resources>\n'
        )

    store_dir = os.path.join(ROOT, 'assets', 'icon')
    os.makedirs(store_dir, exist_ok=True)
    # 스토어는 네모 그대로 올리고 모양은 스토어가 깎는다.
    composite(32, 4, 16, rounded=False).save(
        os.path.join(store_dir, 'store_icon_512.png'))
    print('아이콘 생성 완료')


if __name__ == '__main__':
    main()
