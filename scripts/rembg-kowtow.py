"""rembg 抠透明背景 - 磕头序列 8 帧"""
from rembg import remove
from pathlib import Path

SRC = Path("scripts/kowtow-frames")
OUT = Path("entry/src/main/resources/rawfile/animations")
OUT.mkdir(parents=True, exist_ok=True)

# 8 帧播放顺序
FRAMES = [
    ("f1_stand.png",       "kowtow_1.png"),   # 站立
    ("f1b_slightbow.png",  "kowtow_2.png"),   # 微弯
    ("f2_halfbow.png",     "kowtow_3.png"),   # 半弯
    ("f2b_midbow.png",     "kowtow_4.png"),   # 中弯
    ("f3_deepbow.png",     "kowtow_5.png"),   # 深弯
    ("f4_prostration.png", "kowtow_6.png"),   # 触地
    ("f4b_risehalf.png",   "kowtow_7.png"),   # 起身半
    ("f5_rise.png",        "kowtow_8.png"),   # 起身
]

for src_name, out_name in FRAMES:
    src_path = SRC / src_name
    out_path = OUT / out_name
    if not src_path.exists():
        print(f"  MISS {src_name}")
        continue
    inp = src_path.read_bytes()
    out = remove(inp)
    out_path.write_bytes(out)
    print(f"  OK {src_name} -> {out_name} ({len(out)//1024}KB)")

print("rembg done")
