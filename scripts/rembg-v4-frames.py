"""rembg v4 video frames -> transparent PNGs for WorshipperView"""
from rembg import remove, new_session
from pathlib import Path

SRC = Path("scripts/v4-frames")
OUT = Path("entry/src/main/resources/rawfile/animations")
OUT.mkdir(parents=True, exist_ok=True)

# 清空旧帧
for f in OUT.glob("kowtow_*.png"):
    f.unlink()

print("Loading rembg session (u2net)...", flush=True)
session = new_session("u2net")
print("Session ready.", flush=True)

frames = sorted(SRC.glob("f*.png"))
done = 0
for i, src_path in enumerate(frames, 1):
    out_name = f"kowtow_{i:02d}.png"
    out_path = OUT / out_name
    inp = src_path.read_bytes()
    out = remove(inp, session=session)
    out_path.write_bytes(out)
    done += 1
    print(f"  OK {src_path.name} -> {out_name} ({len(out)//1024}KB)", flush=True)

print(f"rembg done: {done} processed", flush=True)
