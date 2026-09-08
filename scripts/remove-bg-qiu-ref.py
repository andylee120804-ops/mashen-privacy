"""抠图脚本 - 把用户提供的求签参考图(屏幕截图 2026-09-02 234642.png)主体抠成透明 PNG。

原理:背景 #f5f6f9 基本均匀 → 从四边洪水填充标背景 → 剩余为主体;
边缘用颜色距离做线性 alpha 过渡(去白边)。

用法:
    python scripts/remove-bg-qiu-ref.py

输入:scripts/屏幕截图 2026-09-02 234642.png
输出:scripts/qiu_ref_cutout.png(紧贴主体的透明图,原始分辨率)
"""

from pathlib import Path

from PIL import Image

BASE = Path(__file__).resolve().parent
SRC = BASE / "屏幕截图 2026-09-02 234642.png"
OUT = BASE / "qiu_ref_cutout.png"

BG = (245, 246, 249)   # #f5f6f9
FILL_TOL = 26          # 洪水填充判定背景的色差阈值(每通道最大差)
ALPHA_T0 = 18          # 边缘:色差 <= T0 视为背景(alpha 0)
ALPHA_T1 = 60          # 边缘:色差 >= T1 视为主体(alpha 255)


def main() -> None:
    im = Image.open(SRC).convert("RGBA")
    w, h = im.size
    px = im.load()
    print(f"source {SRC.name} {w}x{h}")

    # 1) 四边洪水填充标记背景(避免命中主体内部与背景同色的镂空)
    import collections
    bgmask = bytearray(w * h)

    def color_dist(p: tuple) -> int:
        return max(abs(p[0] - BG[0]), abs(p[1] - BG[1]), abs(p[2] - BG[2]))

    dq = collections.deque()
    for x in range(w):
        for y in (0, h - 1):
            dq.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            dq.append((x, y))
    while dq:
        x, y = dq.popleft()
        if not (0 <= x < w and 0 <= y < h):
            continue
        i = y * w + x
        if bgmask[i]:
            continue
        if color_dist(px[x, y]) > FILL_TOL:
            continue
        bgmask[i] = 1
        dq.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))

    # 2) 主体像素 + 边缘抗锯齿 alpha
    fg_count = 0
    xs, ys, xe, ye = w, h, 0, 0
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    opx = out.load()
    for y in range(h):
        for x in range(w):
            if bgmask[y * w + x]:
                continue
            r, g, b, a = px[x, y]
            d = color_dist(px[x, y])
            alpha = 255 if d >= ALPHA_T1 else max(0, int((d - ALPHA_T0) * 255 / (ALPHA_T1 - ALPHA_T0)))
            if alpha <= 0:
                continue
            fg_count += 1
            opx[x, y] = (r, g, b, min(a, alpha))
            xs, ys = min(xs, x), min(ys, y)
            xe, ye = max(xe, x), max(ye, y)

    out = out.crop((xs, ys, xe + 1, ye + 1))
    out.save(OUT, "PNG")
    ratio = fg_count / (w * h) * 100
    print(f"fg {fg_count}px ({ratio:.0f}%), bbox ({xs},{ys})-({xe},{ye}) -> {OUT} {out.size}, {OUT.stat().st_size / 1024:.0f} KB")


if __name__ == "__main__":
    main()
