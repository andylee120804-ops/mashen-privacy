"""抠图脚本 - 用 rembg 核心 API 去背景，输出透明 PNG。
绕开 rembg CLI（2.0.76 的 CLI 强依赖 gradio）。

用法：
    python scripts/remove-bg.py 1          # 处理第 1 张
    python scripts/remove-bg.py 1 2 3 4 5   # 处理全部

输入：entry/src/main/resources/rawfile/deities/{n}.jpg
输出：entry/src/main/resources/rawfile/deities/{n}.png（透明背景）
"""

import sys
from pathlib import Path

from PIL import Image
from rembg import remove

BASE = Path(__file__).resolve().parent.parent / "entry/src/main/resources/rawfile/deities"


def process(idx: str) -> None:
    src = BASE / f"{idx}.jpg"
    dst = BASE / f"{idx}.png"
    if not src.exists():
        print(f"   [FAIL] source not found: {src}")
        return

    print(f">> rembg {src.name} -> {dst.name}")
    img = Image.open(src)
    out = remove(img)  # default u2net model, ~176MB download on first run
    out.save(dst, "PNG")
    kb = dst.stat().st_size / 1024
    print(f"   [OK] saved {dst} ({kb:.1f} KB)")


def main() -> None:
    idxs = sys.argv[1:] or ["1", "2", "3", "4", "5"]
    for idx in idxs:
        try:
            process(idx)
        except Exception as e:
            print(f"   [FAIL] {idx}: {e}")


if __name__ == "__main__":
    main()
