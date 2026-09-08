"""
Synthesize a traditional Chinese temple drum (堂鼓/大鼓) hit.
Acoustic characteristics:
  - Sharp beater attack: short filtered-noise burst (the "thock" of wood on skin)
  - Membrane resonance: pitched tone ~120Hz with inharmonic partials, exponential decay
  - Slight downward pitch chirp on attack (membrane tension settling)
  - Subtle room reverb tail
NO sustained electronic drone - natural percussive decay.
Output: mono 44100Hz, ~1.2s total, encoded to MP3.
"""
import numpy as np
from scipy.io import wavfile
import subprocess, os, sys

sr = 44100
dur = 1.2  # seconds total (decays to silence well before end)
n = int(sr * dur)
t = np.arange(n) / sr
rng = np.random.default_rng(7)

# === 1. Membrane body: two slightly inharmonic sinusoidal partials w/ exp decay ===
fund = 118.0  # Hz - 堂鼓-like pitch
# inharmonic partials (real drum membranes are Bessel-mode, not harmonic)
partials = [(1.00, 1.00, 118.0),
            (1.56, 0.45, 184.0),
            (2.10, 0.22, 248.0),
            (2.78, 0.12, 328.0)]
body = np.zeros(n)
decay = 0.28  # seconds - main body decay time
for ratio, amp, freq in partials:
    # each partial has its own (faster) decay
    d = decay / (0.6 + 0.4*ratio)
    env = np.exp(-t / d)
    # slight initial pitch drop (chirp) on the fundamental only
    if ratio == 1.0:
        # pitch slides from +12% down to nominal over 40ms
        slide_len = int(0.04 * sr)
        inst_f = np.full(n, freq)
        inst_f[:slide_len] = freq * (1.12 - 0.12 * np.linspace(0, 1, slide_len))
        phase = np.cumsum(2*np.pi*inst_f/sr)
        body += amp * np.sin(phase) * env
    else:
        body += amp * np.sin(2*np.pi*freq*t) * env

# === 2. Beater attack: short filtered noise burst ===
atk_len = int(0.012 * sr)  # 12ms attack
noise = rng.standard_normal(atk_len)
# bandpass-ish: emphasize 400-2500 Hz (the "smack")
from scipy.signal import butter, sosfilt
sos = butter(4, [400/(sr/2), 2500/(sr/2)], btype="band", output="sos")
atk = sosfilt(sos, noise)
# sharp attack envelope
atk_env = np.exp(-np.arange(atk_len) / (0.004*sr))  # 4ms decay
atk = atk * atk_env * 0.55
# add a tiny low-frequency "thump" click for weight
click = np.exp(-np.arange(atk_len)/(0.003*sr)) * np.sin(2*np.pi*70*np.arange(atk_len)/sr)
atk += click * 0.35

# === 3. Combine ===
sig = body.copy()
sig[:atk_len] += atk

# === 4. Natural amplitude shape: overall fast decay, but let reverb tail breathe ===
overall = np.exp(-t / 0.45)  # ~450ms overall e-fold
sig *= overall

# === 5. Tiny reverb tail (early reflections) - convolve with sparse impulse ===
ir_len = int(0.35*sr)
ir = np.zeros(ir_len)
# a few decaying reflections
for delay_ms, amp in [(18, 0.30), (37, 0.22), (61, 0.15), (95, 0.10), (140, 0.06)]:
    idx = int(delay_ms/1000*sr)
    if idx < ir_len:
        ir[idx] = amp * np.exp(-delay_ms/200)
ir *= rng.standard_normal(ir_len)*0 + 1  # keep deterministic signs
# normalize ir
ir /= max(np.abs(ir).max(), 1e-9)
# apply light reverb (parallel mix, ~25% wet)
from scipy.signal import fftconvolve
wet = fftconvolve(sig, ir)[:n] * 0.25
sig = sig*0.85 + wet

# === 6. Normalize & soft clip ===
sig = sig / max(np.abs(sig).max(), 1e-9) * 0.82
# soft clip to tame attack transient
sig = np.tanh(sig*1.1)*0.9

# fade out last 80ms to avoid click
fade = int(0.08*sr)
sig[-fade:] *= np.linspace(1, 0, fade)

# 16-bit PCM
pcm = (sig*32767).astype(np.int16)
wav_path = 'scripts/_kowtow_tmp.wav'
wavfile.write(wav_path, sr, pcm)

# === 7. Encode MP3 (mono, 64kbps to match existing ~65kbps) ===
out_mp3 = 'entry/src/main/resources/rawfile/sounds/kowtow.mp3'
# back up original
import shutil
if os.path.exists(out_mp3) and not os.path.exists(out_mp3+'.bak'):
    shutil.copy(out_mp3, out_mp3+'.bak')
r = subprocess.run(['ffmpeg','-y','-i',wav_path,'-codec:a','libmp3lame','-b:a','64k',
                    '-ar','44100','-ac','1',out_mp3],
                   capture_output=True, text=True)
if r.returncode != 0:
    print('FFMPEG ERR:', r.stderr[-1500:]); sys.exit(1)
os.remove(wav_path)
sz = os.path.getsize(out_mp3)
print(f'OK wrote {out_mp3} ({sz} bytes)')
print(f'duration={dur}s peak={np.abs(sig).max():.3f} rms={np.sqrt((sig**2).mean()):.3f}')
