"""
用 19 关键帧 (kowtow-frames-30/f01~f19) 生成透明度混合中间帧。
每对姿势变化的关键帧之间插 2 个混合帧，动作更丝滑。
混合效果类似动态模糊，快速播放时视觉上是平滑过渡。
"""
from PIL import Image
from pathlib import Path
import shutil

SRC = Path("scripts/kowtow-frames-30")
OUT = Path("scripts/kowtow-frames-smooth")
OUT.mkdir(parents=True, exist_ok=True)

# 清空输出目录旧文件
for f in OUT.glob("*.png"):
    f.unlink()

# 19 关键帧 + 度数（度数相同=停留段，不插帧）
KEYS = [
    (1, 0), (2, 5), (3, 12), (4, 20), (5, 30), (6, 40), (7, 50),
    (8, 60), (9, 70), (10, 80), (11, 90), (12, 110), (13, 130), (14, 150),
    (15, 150), (16, 150), (17, 150), (18, 150),  # 停留
    (19, -1),  # 起身
]

def load(n):
    return Image.open(SRC / f"f{n:02d}.png").convert("RGB")

out_idx = 0

def emit(img, label):
    global out_idx
    out_idx += 1
    img.save(OUT / f"f{out_idx:03d}.png")
    print(f"  f{out_idx:03d}.png = {label}")

print("生成混合中间帧...")

# 先输出第 1 帧
emit(load(1), f"f01 (key)")

for i in range(len(KEYS) - 1):
    n_a, deg_a = KEYS[i]
    n_b, deg_b = KEYS[i + 1]
    img_a = load(n_a)
    img_b = load(n_b)

    if deg_a != deg_b:
        # 姿势变化：插 2 个混合帧
        mid1 = Image.blend(img_a, img_b, 0.33)
        mid2 = Image.blend(img_a, img_b, 0.67)
        emit(mid1, f"f{n_a:02d}_f{n_b:02d} blend33%")
        emit(mid2, f"f{n_a:02d}_f{n_b:02d} blend67%")

    # 输出下一关键帧
    emit(img_b, f"f{n_b:02d} (key)")

print(f"\n完成! 共 {out_idx} 帧 -> scripts/kowtow-frames-smooth/")
print("下一步: python scripts/rembg-kowtow-smooth.py")
