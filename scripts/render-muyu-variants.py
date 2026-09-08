"""把参考图轮廓程序化渲染成卡通木鱼（v2 为线上版）。

关键点：
- 参考剪影 430x323 全程保持原始宽高比（不做方形拉伸）
- 所有装饰（鳞弧/高光）只在身体掩膜内作画；透明区仅保留 ≤6px 描边带
  （杜绝装饰弧"波浪"外露到空白）
- 最后贴入 512x512 画布，四周留 ≥ 24px 透明边距

输入: scripts/屏幕截图 2026-09-02 231551.png (黑底白线条木鱼图)
输出: entry/src/main/resources/rawfile/props/muyu.png（线上）+ _candidates/trace_<key>.png

用法: python scripts/render-muyu-variants.py [v1 v2 v3]   (默认全部)
"""
import math
import sys
from pathlib import Path

from PIL import Image, ImageFilter, ImageDraw

SRC = Path(__file__).resolve().parent / "屏幕截图 2026-09-02 231551.png"
OUT = Path(__file__).resolve().parent.parent / "entry/src/main/resources/rawfile/props"
OUTLINE_BAND = 6  # 身体外允许保留的描边带宽度(px, 原尺寸)

# 变体: 颜色(高光/中调/暗调), 外描边, 金缘宽, 眼睛, 光斑, 鳞弧排数, 口缘加金
VARIANTS = {
    'v1': dict(label='童趣糖果', top=(243, 190, 120), mid=(216, 134, 76), low=(148, 80, 40),
               outline=(58, 28, 14), outline_w=5, gold=(236, 192, 104), gold_w=4,
               eye=True, gloss=1.0, scales=0, lip_gold=False),
    'v2': dict(label='寺庙描金', top=(196, 106, 58), mid=(158, 76, 40), low=(96, 42, 22),
               outline=(40, 18, 8), outline_w=4, gold=(226, 178, 92), gold_w=6,
               eye=False, gloss=0.5, scales=2, lip_gold=True),
    'v3': dict(label='琥珀轻木', top=(248, 204, 138), mid=(216, 156, 96), low=(170, 112, 64),
               outline=(110, 70, 36), outline_w=2, gold=(216, 176, 100), gold_w=3,
               eye=True, gloss=0.7, scales=0, lip_gold=False, soft_blur_gloss=True),
}


def render(key):
    v = VARIANTS[key]
    mask = Image.open(SRC).convert('L').crop((61, 26, 491, 349))
    mask = mask.point(lambda t: 255 if t > 90 else 0, 'L')
    mask = mask.filter(ImageFilter.MedianFilter(3)).filter(ImageFilter.MedianFilter(3))
    mp = mask.load()
    w, h = mask.size
    rgba = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    px = rgba.load()

    # 基色渐变（左上光源）
    cx_, cy_ = 0.13 * w, 0.10 * h
    for y in range(h):
        for x in range(w):
            if mp[x, y] < 200:
                continue
            d = math.sqrt(((x - cx_) / w) ** 2 + ((y - cy_) / h) ** 2)
            t = min(d / 0.9, 1.0) ** 2
            if t < 0.1:
                r, g, b = v['top']
            elif t < 0.55:
                tt = (t - 0.1) / 0.45
                r = int(v['top'][0] + (v['mid'][0] - v['top'][0]) * tt)
                g = int(v['top'][1] + (v['mid'][1] - v['top'][1]) * tt)
                b = int(v['top'][2] + (v['mid'][2] - v['top'][2]) * tt)
            else:
                tt = (t - 0.55) / 0.45
                r = int(v['mid'][0] + (v['low'][0] - v['mid'][0]) * tt)
                g = int(v['mid'][1] + (v['low'][1] - v['mid'][1]) * tt)
                b = int(v['mid'][2] + (v['low'][2] - v['mid'][2]) * tt)
            px[x, y] = (max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b)), 255)

    # 口/缝内侧体积暗部（体内贴边一圈压暗）
    deep = mask.filter(ImageFilter.MaxFilter(13))
    dp = deep.load()
    for y in range(h):
        for x in range(w):
            if dp[x, y] < 200 or mp[x, y] > 200:
                continue
            r, g, b, _ = rgba.getpixel((x, y))
            if r > 12:
                rgba.putpixel((x, y), (max(0, r - 50), max(0, g - 40), max(0, b - 26), 255))

    # 外描边
    od = mask.filter(ImageFilter.MaxFilter(2 * v['outline_w'] + 1))
    odp = od.load()
    for y in range(h):
        for x in range(w):
            if odp[x, y] > 200 and mp[x, y] < 200:
                rgba.putpixel((x, y), v['outline'] + (255,))

    # 金缘（体内侧带）
    er = mask.filter(ImageFilter.MinFilter(2 * v['gold_w'] + 3))
    erp = er.load()
    for y in range(h):
        for x in range(w):
            if erp[x, y] > 200:
                continue
            hit = any((x + dd < w and erp[x + dd, y] > 200) or (x - dd >= 0 and erp[x - dd, y] > 200)
                      for dd in range(1, v['gold_w'] + 1))
            if not hit:
                continue
            r, g, b, _ = rgba.getpixel((x, y))
            rgba.putpixel((x, y), (int(r * 0.4 + v['gold'][0] * 0.6),
                                   int(g * 0.4 + v['gold'][1] * 0.6),
                                   int(b * 0.4 + v['gold'][2] * 0.6), 255))

    # 口缘加金
    if v['lip_gold']:
        er2 = mask.filter(ImageFilter.MinFilter(19))
        er2p = er2.load()
        for y in range(int(0.02 * h), int(0.62 * h)):
            for x in range(int(0.02 * w), int(0.62 * w)):
                if er2p[x, y] < 200 and mp[x, y] > 200:
                    rgba.putpixel((x, y), v['gold'] + (255,))

    # 柔和高光（体内）
    if v['gloss'] > 0:
        hl = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        dhl = ImageDraw.Draw(hl)
        dhl.ellipse([0.17 * w, 0.12 * h, 0.38 * w, 0.23 * h], fill=(255, 255, 255, int(100 * v['gloss'])))
        hl = hl.filter(ImageFilter.GaussianBlur(max(3, int(w * 0.045))))
        hlp = hl.load()
        for y in range(h):
            for x in range(w):
                if mp[x, y] < 200:
                    continue
                ha = hlp[x, y][3]
                if ha > 0:
                    k = ha / 255.0 * 0.5
                    r, g, b, _ = rgba.getpixel((x, y))
                    rgba.putpixel((x, y), (int(r + (255 - r) * k), int(g + (255 - g) * k), int(b + (255 - b) * k), 255))

    # 金鳞弧（小半径、锚点取体内深处，避免越界）
    if v['scales'] > 0:
        dr = ImageDraw.Draw(rgba)
        for row_i in range(v['scales']):
            yf = 0.5 + 0.30 * row_i / max(v['scales'] - 1, 1)
            x = 0.40 * w
            while x < 0.92 * w:
                xx, yy = int(x), int(yf * h)
                for dy in range(int(0.03 * h), int(0.13 * h), 3):
                    if yy + dy < h and mp[xx, yy + dy] > 200:
                        yy += dy
                        break
                if mp[xx, yy] > 200:
                    rr = int(0.038 * w)
                    dr.arc([xx - rr, yy - rr, xx + rr, yy + rr], 5, 172,
                           fill=(228, 178, 84, 255), width=max(2, w // 90))
                x += 0.1 * w

    # 眼睛
    if v['eye']:
        r = int(w * 0.05)
        ex, ey = int(w * 0.2), int(h * 0.22)
        for yy in range(int(0.1 * h), int(0.5 * h), 3):
            if mp[int(0.2 * w), yy] > 200:
                ey = yy
                break
        dr = ImageDraw.Draw(rgba)
        dr.ellipse([ex - r, ey - r, ex + r, ey + r], fill=(44, 22, 10, 255))
        dr.ellipse([ex - r // 2, ey - r // 2, ex + r // 2, ey + r // 2], fill=(255, 255, 255, 230))

    # 最终裁剪：透明区只保留描边带，杜绝装饰外露
    band = mask.filter(ImageFilter.MaxFilter(2 * OUTLINE_BAND + 1))
    bp = band.load()
    for y in range(h):
        for x in range(w):
            if mp[x, y] > 200 or bp[x, y] < 200:
                continue
            rgba.putpixel((x, y), (0, 0, 0, 0))

    # 入 512 画布（内容 88% 宽、居中，四周透明留白）
    final = Image.new('RGBA', (512, 512), (0, 0, 0, 0))
    cw = int(512 * 0.88)
    ch = int(cw * h / w)
    art = rgba.resize((cw, ch), Image.LANCZOS)
    final.paste(art, ((512 - cw) // 2, (512 - ch) // 2), art)
    outdir = OUT / '_candidates'
    outdir.mkdir(parents=True, exist_ok=True)
    final.save(outdir / f'trace_{key}.png')
    print('OK', key, v['label'])
    if key == 'v2':
        final.save(OUT / 'muyu.png')
        print('   -> 已同步 muyu.png')


if __name__ == '__main__':
    keys = sys.argv[1:] or list(VARIANTS)
    for k in keys:
        render(k)
