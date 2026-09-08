"""rembg 46 frames smooth kowtow - persistent session + resume"""
from rembg import remove, new_session
from pathlib import Path

SRC = Path("scripts/kowtow-frames-smooth")
OUT = Path("entry/src/main/resources/rawfile/animations")
OUT.mkdir(parents=True, exist_ok=True)

# 清空旧的 kowtow 动画帧
for f in OUT.glob("kowtow_*.png"):
    f.unlink()

print("Loading rembg session (u2net)...", flush=True)
session = new_session("u2net")
print("Session ready.", flush=True)

done = 0
for i in range(1, 47):
    src_name = f"f{i:03d}.png"
    out_name = f"kowtow_{i:02d}.png"
    src_path = SRC / src_name
    out_path = OUT / out_name
    if not src_path.exists():
        print(f"  MISS {src_name}", flush=True)
        continue
    if out_path.exists() and out_path.stat().st_size > 1000:
        print(f"  SKIP {out_name}", flush=True)
        continue
    inp = src_path.read_bytes()
    out = remove(inp, session=session)
    out_path.write_bytes(out)
    done += 1
    print(f"  OK {src_name} -> {out_name} ({len(out)//1024}KB)", flush=True)

print(f"rembg done: {done} processed", flush=True)
