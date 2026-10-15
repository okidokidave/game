"""앱 아이콘 만들기: 도트 캐릭터 + 하트 네온 + LIVE 표시.

python3 tool/generate_icon.py 를 실행하면 android/app/src/main/res/mipmap-*/ 의
ic_launcher.png (예전 폰용), ic_launcher_foreground.png (적응형 아이콘 앞면)와
스토어용 assets/icon/store_icon_512.png 가 다시 만들어진다.
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "android/app/src/main/res"

BG = (23, 26, 44, 255)  # 방 화면 바탕과 같은 남색

PAL = {
    "h": (42, 34, 48), "s": (243, 201, 165), "e": (42, 34, 48), "m": (163, 59, 59),
    "b": (241, 154, 154), "t": (232, 93, 93), "d": (174, 70, 70),
    "#": (255, 95, 168), "L": (255, 59, 59), "W": (255, 255, 255),
}

# 32×32 도안. 가운데 캐릭터, 뒤에 하트 네온, 오른쪽 위에 LIVE 빨간 불
ART = [
    "................................",
    "................................",
    "................................",
    "....##...##..............LL.....",
    "...####.####............LLLL....",
    "..###########...........LLLL....",
    "..###########............LL.....",
    "...#########....................",
    "....#######.....................",
    ".....#####......................",
    "......###.......................",
    ".......#.....hhhhhh.............",
    "............hhhhhhhh............",
    "...........hhhhhhhhhh...........",
    "...........hhhhhhhhhh...........",
    "...........hhsshhsssh...........",
    "...........hssssssssh...........",
    "...........hsessssesh...........",
    "...........hsessssesh...........",
    "...........hbssmmssbh...........",
    "............ssssssss............",
    ".............dttttd.............",
    "............tttttttt............",
    "...........stttttttts...........",
    "...........stttttttts...........",
    "............dddddddd............",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
]


def art(size: int, with_bg: bool, pad: float) -> Image.Image:
    """도안을 size 크기로. pad는 가장자리 여백 비율 (적응형 아이콘 안전 영역용)."""
    inner = int(round(size * (1 - 2 * pad)))
    cell = max(1, inner // 32)
    img = Image.new("RGBA", (size, size), BG if with_bg else (0, 0, 0, 0))
    ox = (size - cell * 32) // 2
    oy = (size - cell * 32) // 2
    for j, row in enumerate(ART):
        for i, ch in enumerate(row):
            c = PAL.get(ch)
            if c:
                for y in range(cell):
                    for x in range(cell):
                        img.putpixel((ox + i * cell + x, oy + j * cell + y), c + (255,))
    return img


def main() -> None:
    legacy = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for name, px in legacy.items():
        d = RES / f"mipmap-{name}"
        d.mkdir(parents=True, exist_ok=True)
        art(px, True, 0.06).save(d / "ic_launcher.png")
        # 적응형 아이콘 앞면은 108dp 중 가운데 66dp만 확실히 보인다
        art(px * 108 // 48, False, 0.2).save(d / "ic_launcher_foreground.png")
    (ROOT / "assets/icon").mkdir(parents=True, exist_ok=True)
    art(512, True, 0.06).save(ROOT / "assets/icon/store_icon_512.png")


if __name__ == "__main__":
    main()
