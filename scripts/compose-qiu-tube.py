"""签筒合成脚本 - 把 qiu_sticks.png（签束）+ qiu_cup.png（红漆筒）叠放合成 qiu_tube.png。

原理：签束在后、筒身在前，筒盖住签束下半部 → 看起来像签插在筒里。
同时擦除签束图左侧的漂浮碎屑（生成图瑕疵）。

用法：
    python scripts/compose-qiu-tube.py

输入：entry/src/main/resources/rawfile/props/qiu_sticks.png, qiu_cup.png
输出：entry/src/main/resources/rawfile/props/qiu_tube.png
"""

from pathlib import Path

from PIL import Image

BASE = Path(__file__).resolve().parent.parent / "entry/src/main/resources/rawfile/props"

# 碎屑擦除区域（在 qiu_sticks.png 512×640 原图坐标系）：左侧漂浮小块
DEBRIS_BOX = (45, 175, 125, 255)

# 合成参数（内容裁剪后的坐标系）
CANVAS_W = 512
CUP_WIDTH = 320          # 筒身宽度（px）
STICKS_WIDTH = 400       # 签束宽度（px）
CUP_BOTTOM_MARGIN = 8    # 筒底距画布底
OVERLAP = 150            # 筒口盖住签束的深度（签束底部被遮多少）


def erase_debris(img: Image.Image) -> Image.Image:
    px = img.load()
    x0, y0, x1, y1 = DEBRIS_BOX
    for y in range(y0, min(y1, img.height)):
        for x in range(x0, min(x1, img.width)):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 0)
    return img


def main() -> None:
    sticks = Image.open(BASE / "qiu_sticks.png").convert("RGBA")
    cup = Image.open(BASE / "qiu_cup.png").convert("RGBA")
    print(f"sticks {sticks.size} bbox={sticks.getbbox()}")
    print(f"cup    {cup.size} bbox={cup.getbbox()}")

    sticks = erase_debris(sticks)

    # 裁到内容
    sticks = sticks.crop(sticks.getbbox())
    cup = cup.crop(cup.getbbox())

    # 缩放
    sw = STICKS_WIDTH
    sh = round(sticks.height * sw / sticks.width)
    sticks = sticks.resize((sw, sh), Image.LANCZOS)

    cw = CUP_WIDTH
    ch = round(cup.height * cw / cup.width)
    cup = cup.resize((cw, ch), Image.LANCZOS)

    # 画布高度 = 签束可见高度 + 筒高 - 重叠
    canvas_h = sh + ch - OVERLAP + CUP_BOTTOM_MARGIN
    canvas = Image.new("RGBA", (CANVAS_W, canvas_h), (0, 0, 0, 0))

    # 签束：贴顶居中（底部被筒盖住）
    canvas.paste(sticks, ((CANVAS_W - sw) // 2, 0), sticks)
    # 筒身：贴底居中（盖住签束底部）
    canvas.paste(cup, ((CANVAS_W - cw) // 2, canvas_h - ch - CUP_BOTTOM_MARGIN), cup)

    out = BASE / "qiu_tube.png"
    canvas.save(out, "PNG")
    kb = out.stat().st_size / 1024
    print(f"saved {out} ({canvas.size}, {kb:.1f} KB)")


if __name__ == "__main__":
    main()
