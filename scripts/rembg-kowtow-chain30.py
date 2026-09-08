"""rembg 30 frames kowtow chain"""
from rembg import remove
from pathlib import Path

SRC = Path("scripts/kowtow-frames-30")
OUT = Path("entry/src/main/resources/rawfile/animations")
OUT.mkdir(parents=True, exist_ok=True)

for i in range(1, 31):
    src_name = f"f{i:02d}.png"
    out_name = f"kowtow_{i:02d}.png"
    src_path = SRC / src_name
    if not src_path.exists():
        print(f"  MISS {src_name}")
        continue
    inp = src_path.read_bytes()
    out = remove(inp)
    (OUT / out_name).write_bytes(out)
    print(f"  OK {src_name} -> {out_name} ({len(out)//1024}KB)")

print("rembg done")
