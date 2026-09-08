"""裁签脚本 - 从求签素材(qiu_art.png)中裁出一支"筒内同款"单签用作弹出签素材。

原理:参考图签束为密实一体(无透明缝),但按像素解剖可定位单签周期:
每支 ≈13px,红漆身 #ff0000 + 中部 3px 金色竖高光。取最接近正中的一列
(x60..73,金色高光居中)纵向裁 y34..133(可见签身段),顶部手动圆角化。

用法:
    python scripts/crop-qiu-stick.py

输入:entry/src/main/resources/rawfile/props/qiu_art.png
输出:entry/src/main/resources/rawfile/props/qiu_stick_pick.png
"""

from pathlib import Path

from PIL import Image, ImageDraw

BASE = Path(__file__).resolve().parent.parent / "entry/src/main/resources/rawfile/props"
SRC = BASE / "qiu_art.png"
OUT = BASE / "qiu_stick_pick.png"

BOX = (60, 34, 73, 134)   # 左,上,右,下(排他): x60..73, y34..133
TOP_ROUND = 8             # 顶部圆角半径(px,消除邻签残留的平切感)


def main() -> None:
    im = Image.open(SRC).convert("RGBA")
    stick = im.crop(BOX)
    w, h = stick.size
    print(f"crop {BOX} -> {w}x{h}")

    # 顶部圆角 alpha:椭圆遮罩只保留圆角内的像素
    mask = Image.new("L", (w, h), 255)
    d = ImageDraw.Draw(mask)
    for x in range(w):
        for y in range(TOP_ROUND):
            # 椭圆:中心(w/2, TOP_ROUND), 半轴 w/2 与 TOP_ROUND
            nx = (x - (w - 1) / 2) / (w / 2)
            ny = (y - TOP_ROUND) / TOP_ROUND
            if nx * nx + ny * ny > 1:
                d.point((x, y), fill=0)

    r, g, b, a = stick.split()
    a = Image.composite(a, Image.new("L", (w, h), 0), mask)
    stick = Image.merge("RGBA", (r, g, b, a))

    # 校验:中心竖线应金、两侧应红
    px = stick.load()
    mid = px[w // 2, h // 2]
    side = px[1, h // 2]
    print(f"mid rgb={mid[:3]} side rgb={side[:3]} (期望 金色 / 红)")

    stick.save(OUT, "PNG")
    print(f"saved {OUT} {stick.size}, {OUT.stat().st_size / 1024:.1f} KB")


if __name__ == "__main__":
    main()
