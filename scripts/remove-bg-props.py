"""抠图脚本 - 处理 props/ 目录道具素材，rembg 去背景输出透明 PNG。
绕开 rembg CLI（2.0.76 的 CLI 强依赖 gradio），与 remove-bg.py 同逻辑。

用法：
    python scripts/remove-bg-props.py                                   # 处理 props/ 所有 jpg
    python scripts/remove-bg-props.py worshipper incense_burner incense_stick

输入：entry/src/main/resources/rawfile/props/{name}.jpg
输出：entry/src/main/resources/rawfile/props/{name}.png（透明背景）
"""

import sys
from pathlib import Path

from PIL import Image
from rembg import remove

BASE = Path(__file__).resolve().parent.parent / "entry/src/main/resources/rawfile/props"


def process(name: str) -> None:
    src = BASE / f"{name}.jpg"
    dst = BASE / f"{name}.png"
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
    args = sys.argv[1:]
    if args:
        names = args
    else:
        names = [p.stem for p in sorted(BASE.glob("*.jpg"))] if BASE.exists() else []

    if not names:
        print(f"   [FAIL] no jpg found in {BASE}")
        return

    for name in names:
        try:
            process(name)
        except Exception as e:
            print(f"   [FAIL] {name}: {e}")


if __name__ == "__main__":
    main()
