"""音效合成脚本 - 用 numpy/scipy 合成 + ffmpeg 编码 MP3。
免费、离线、无需 API key。生成祈福动画所需的 5 个音效。

用法：
    python scripts/gen-sound.py            # 生成全部 5 个
    python scripts/gen-sound.py appear     # 只生成 appear

规格（来自 sounds/README.md）：
    短音效：<=3s, <=100KB, MP3
    背景音乐：<=30s (循环), <=500KB, MP3

输出：entry/src/main/resources/rawfile/sounds/*.mp3
"""

import sys
import subprocess
import tempfile
import os
from pathlib import Path

import numpy as np
from scipy import signal

SR = 44100  # 采样率
OUT_DIR = Path(__file__).resolve().parent.parent / "entry/src/main/resources/rawfile/sounds"
FFMPEG = "ffmpeg"


# ---------- 基础工具 ----------

def adsr(n, attack=0.005, release=None):
    """简单 Attack-Release 包络。"""
    env = np.ones(n)
    a = int(SR * attack)
    if a > 0:
        env[:a] = np.linspace(0, 1, a)
    if release:
        r = int(SR * release)
        if r > 0 and r < n:
            env[-r:] = np.linspace(1, 0, r)
    return env


def bell(freq, dur, decay_rate=2.5):
    """加法合成钟声 - 非谐波分音赋予金属钟体音色。"""
    n = int(SR * dur)
    t = np.arange(n) / SR
    # (频率倍率, 振幅, 衰减倍率) - 钟体非谐波分音
    partials = [
        (1.0, 1.00, 1.0),
        (2.0, 0.50, 1.3),
        (2.4, 0.40, 1.5),
        (3.0, 0.30, 1.8),
        (4.0, 0.20, 2.2),
        (5.4, 0.15, 2.8),
    ]
    sig = np.zeros(n)
    for ratio, amp, d in partials:
        sig += amp * np.sin(2 * np.pi * freq * ratio * t) * np.exp(-t * decay_rate * d)
    return sig * adsr(n, attack=0.003)


def gong(dur=2.5, decay_rate=1.8):
    """锣声 - 丰富的高频非谐波分音 + 噪音起音。"""
    n = int(SR * dur)
    t = np.arange(n) / SR
    sig = np.zeros(n)
    # 多个非谐波分音
    for f, a in [(180, 0.4), (270, 0.3), (410, 0.25), (560, 0.2), (730, 0.15), (980, 0.1)]:
        sig += a * np.sin(2 * np.pi * f * t) * np.exp(-t * decay_rate)
    # 噪音起音（金属撞击感）
    noise = np.random.randn(n) * np.exp(-t * 25) * 0.3
    return (sig + noise) * adsr(n, attack=0.002)


def drum_hit(freq_start=130, freq_end=55, dur=0.5, decay_scale=1.0):
    """低沉鼓点 - 音高下滑的正弦 + 谐波 + 噪音起音。decay_scale<1 延长余韵。"""
    n = int(SR * dur)
    t = np.arange(n) / SR
    # 指数音高下滑
    freq = freq_start * (freq_end / freq_start) ** (t / dur)
    phase = 2 * np.pi * np.cumsum(freq) / SR
    sig = np.sin(phase) * np.exp(-t * 7 * decay_scale)
    sig += 0.35 * np.sin(2 * phase) * np.exp(-t * 11 * decay_scale)
    sig += 0.15 * np.sin(3 * phase) * np.exp(-t * 15 * decay_scale)
    # 低频体鸣（厚重感）
    sig += 0.3 * np.sin(2 * np.pi * freq_end * 0.5 * t) * np.exp(-t * 4 * decay_scale)
    # 噪音起音（鼓皮击打感）
    noise = np.random.randn(n) * np.exp(-t * 35) * 0.25
    return (sig + noise) * adsr(n, attack=0.002)


def temple_drum(freq=60, dur=1.6):
    """中国寺庙大鼓 - 鼓膜贝塞尔模态 + 木腔共鸣 + 鼓槌击打噪音。
    非谐波模态频率是真实鼓声区别于电子底鼓的核心。"""
    n = int(SR * dur)
    t = np.arange(n) / SR

    # 鼓膜模态（贝塞尔根比值，非谐波 1:2:3）- 低衰减率延长余韵
    modes = [
        (1.00, 1.00, 1.4),
        (1.34, 0.55, 1.8),
        (1.44, 0.40, 2.0),
        (1.66, 0.30, 2.5),
        (1.83, 0.22, 2.8),
        (1.95, 0.18, 3.2),
        (2.26, 0.12, 3.5),
    ]
    sig = np.zeros(n)
    for ratio, amp, decay in modes:
        f = freq * ratio
        sig += amp * np.sin(2 * np.pi * f * t) * np.exp(-t * decay)

    # 木腔体低频共鸣（鼓身木质共振）- 更低更长
    sig += 0.4 * np.sin(2 * np.pi * freq * 0.4 * t) * np.exp(-t * 1.0)

    # 鼓槌击打鼓皮 - 带通噪音，真实击打感
    attack = np.random.randn(n)
    sos = signal.butter(4, [80, 2500], btype="band", fs=SR, output="sos")
    attack = signal.sosfilt(sos, attack) * np.exp(-t * 28) * 0.5

    # 低频空气推动（鼓皮运动推动空气的"噗"声）- 更低
    thump = np.sin(2 * np.pi * 35 * t) * np.exp(-t * 14) * 0.4

    sig = sig + attack + thump
    return sig * adsr(n, attack=0.001)


def wooden_fish(dur=0.12):
    """木鱼声 - 短促的带通噪音 + 低频击打。"""
    n = int(SR * dur)
    t = np.arange(n) / SR
    noise = np.random.randn(n)
    # 带通滤波模拟木鱼共振
    sos = signal.butter(4, [250, 700], btype="band", fs=SR, output="sos")
    noise = signal.sosfilt(sos, noise)
    sig = noise * np.exp(-t * 45) * 0.7
    # 低频击打成分
    sig += 0.4 * np.sin(2 * np.pi * 320 * t) * np.exp(-t * 55)
    return sig * 0.7


def karplus_strong(freq, dur, decay=0.996):
    """Karplus-Strong 拨弦合成 - 模拟古筝/古琴音色。用 lfilter 向量化。"""
    L = max(2, int(SR / freq))
    n = int(SR * dur)
    # 传递函数: y[n] = x[n] + decay*0.5*(y[n-L] + y[n-L-1])
    a = np.zeros(L + 2)
    a[0] = 1.0
    a[L] = -decay * 0.5
    a[L + 1] = -decay * 0.5
    b = np.zeros(L + 2)
    b[0] = 1.0
    # 初始噪音激励
    x = np.zeros(n)
    x[:L] = np.random.uniform(-1, 1, L)
    out = signal.lfilter(b, a, x)
    return out * adsr(n, attack=0.001)


def reverb(sig, decay=2.5, length=1.2, wet=0.35):
    """卷积混响 - 衰减噪音脉冲响应，营造殿堂空间感。"""
    ir_len = int(SR * length)
    t = np.arange(ir_len) / SR
    ir = np.random.randn(ir_len) * np.exp(-t * decay)
    ir /= max(np.abs(ir).max(), 1e-9)
    wet_sig = signal.fftconvolve(sig, ir)[:len(sig)]
    wet_sig /= max(np.abs(wet_sig).max(), 1e-9)
    return sig * (1 - wet) + wet_sig * wet


def normalize(sig, peak=0.9):
    """归一化到指定峰值。"""
    m = np.abs(sig).max()
    return sig / m * peak if m > 0 else sig


def place(src, dst, offset_s):
    """将 src 叠加到 dst 的 offset_s 秒位置。"""
    start = int(SR * offset_s)
    end = start + len(src)
    if end > len(dst):
        dst = np.pad(dst, (0, end - len(dst)))
    dst[start:end] += src
    return dst


def write_mp3(sig, path, bitrate=64):
    """numpy 数组 -> WAV(临时) -> ffmpeg -> MP3。"""
    sig = normalize(sig)
    audio_int = (sig * 32767).astype(np.int16)
    wav_path = tempfile.mktemp(suffix=".wav")
    import wave
    with wave.open(wav_path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(audio_int.tobytes())
    os.makedirs(os.path.dirname(path), exist_ok=True)
    subprocess.run(
        [FFMPEG, "-y", "-i", wav_path, "-codec:a", "libmp3lame",
         "-b:a", f"{bitrate}k", "-ac", "1", path],
        check=True, capture_output=True,
    )
    os.unlink(wav_path)
    kb = os.path.getsize(path) / 1024
    print(f"   [OK] {os.path.basename(path)} ({kb:.1f} KB)")
    return path


# ---------- 五个音效 ----------

def gen_appear():
    """财神现身 - 编钟琶音（五声音阶自下而上）。"""
    dur = 3.0
    out = np.zeros(int(SR * dur))
    # 五声音阶 C5 D5 E5 G5 A5
    notes = [523, 587, 659, 784, 880]
    for i, f in enumerate(notes):
        out = place(bell(f, 2.0, decay_rate=2.2), out, 0.15 * i)
    out = reverb(out, wet=0.3)
    write_mp3(out, str(OUT_DIR / "appear.mp3"), bitrate=64)


def gen_incense():
    """进香 - 三下木鱼声。"""
    dur = 2.2
    out = np.zeros(int(SR * dur))
    for i, t in enumerate([0.0, 0.5, 1.4]):
        hit = wooden_fish(0.15)
        out = place(hit, out, t)
    out = reverb(out, decay=4.0, length=0.6, wet=0.2)
    write_mp3(out, str(OUT_DIR / "incense.mp3"), bitrate=64)


def gen_kowtow():
    """磕头 - 三叩首寺庙大鼓，深沉庄重，殿堂共鸣。"""
    dur = 3.0
    out = np.zeros(int(SR * dur))
    # 三下大鼓，逐下更深沉
    out = place(temple_drum(62, 1.6), out, 0.0)
    out = place(temple_drum(55, 1.7), out, 1.0)
    out = place(temple_drum(48, 1.9), out, 2.0)
    # 深层殿堂共鸣（更长混响尾）
    out = reverb(out, decay=0.9, length=2.2, wet=0.45)
    out = out[:int(SR * dur)]  # 裁到 3 秒
    write_mp3(out, str(OUT_DIR / "kowtow.mp3"), bitrate=64)


def majestic_bell(freq, dur, decay_rate=1.4):
    """大气明亮钟声 - 谐和泛音列（整数倍），神圣祝福感，避免非谐波分音的诡异金属感。"""
    n = int(SR * dur)
    t = np.arange(n) / SR
    # 谐和泛音（接近自然谐波列 1:2:3:4:5:6），明亮纯净如教堂钟/编钟
    partials = [
        (1.0, 1.00, 1.0),
        (2.0, 0.55, 1.2),
        (3.0, 0.35, 1.5),
        (4.0, 0.22, 1.8),
        (5.0, 0.14, 2.2),
        (6.0, 0.08, 2.6),
    ]
    sig = np.zeros(n)
    for ratio, amp, d in partials:
        sig += amp * np.sin(2 * np.pi * freq * ratio * t) * np.exp(-t * decay_rate * d)
    return sig * adsr(n, attack=0.004)


def coin_hit(dur=0.12, pitch=3000, amp=1.0):
    """单个硬币清脆金属撞击声 - 真实硬币非谐波模态 + 叮当双音 + 高频金属体噪音。
    模态频率比 1:2.76:5.40（实测硬币振动模式，非谐波赋予金属辨识度），
    高衰减率（70-110）保证短促清脆，高频带通噪音模拟金属体瞬间振动。"""
    n = int(SR * dur)
    t = np.arange(n) / SR
    sig = np.zeros(n)
    # 硬币金属体非谐波模态（真实振动模式频率比，非整数倍）
    partials = [
        (1.00, 1.00, 75),
        (2.76, 0.55, 90),
        (5.40, 0.28, 105),
    ]
    for ratio, p_amp, decay in partials:
        f = pitch * ratio
        if f < SR * 0.45:  # 防混叠
            sig += p_amp * np.sin(2 * np.pi * f * t) * np.exp(-t * decay)
    # 高频金属体噪音 - 更亮频段，模拟硬币表面瞬间振动
    noise = np.random.randn(n)
    high_cut = min(pitch * 6.0, SR * 0.45)
    sos = signal.butter(4, [pitch * 1.2, high_cut], btype="band", fs=SR, output="sos")
    noise = signal.sosfilt(sos, noise) * np.exp(-t * 130) * 0.14
    # "叮-当"双音 - 25ms 后稍低余音，两枚硬币碰撞的翻滚感
    n2_start = int(SR * 0.025)
    if n2_start < n:
        n2 = n - n2_start
        t2 = np.arange(n2) / SR
        f2 = pitch * 0.80
        sig2 = 0.40 * np.sin(2 * np.pi * f2 * t2) * np.exp(-t2 * 72)
        if f2 * 2.76 < SR * 0.45:
            sig2 += 0.18 * np.sin(2 * np.pi * f2 * 2.76 * t2) * np.exp(-t2 * 95)
        sig[n2_start:] += sig2
    return (sig + noise) * adsr(n, attack=0.0003) * amp


def coin_shower(dur=3.0, density_per_sec=20):
    """钱币哗啦啦 - 高密度金属硬币倾泻碰撞，前疏后密翻滚感。
    密度 20/s 接近真实多枚硬币倒入容器的密集碰撞，音高 2200-5000Hz 清脆金属音域。"""
    n = int(SR * dur)
    out = np.zeros(n)
    n_coins = int(density_per_sec * dur)
    for _ in range(n_coins):
        u = np.random.random()
        # 前疏后密：u^0.6 使后半段碰撞更密集（钱雨倾泻高潮在后）
        t_offset = (u ** 0.6) * (dur - 0.12)
        # 音高 2200-5000 Hz（清脆金属音域，真实硬币共振范围）
        pitch = 2200 + np.random.random() * 2800
        # 力度动态范围
        amp = 0.12 + np.random.random() * 0.48
        coin = coin_hit(dur=0.11, pitch=pitch, amp=amp)
        out = place(coin, out, t_offset)
    return out


def gen_blessing():
    """祝福礼成 - 与磕头同源寺庙大鼓风格 + 真实 CC0 钱币录音，体现「祈福完成 · 福到 · 钱到」。
    寺庙大鼓末槌收束（承接三叩首，礼成）-> 庄严礼成大钟（福到）-> 真实钱币哗啦（钱到）。
    钱币声来自 Freesound CC0 公共领域录音「Doudar41 light coin shower」(sound 728430)，
    经 highpass+treble+dynaudnorm 归一化后用 ffmpeg 与合成大鼓/钟混合。
    殿堂混响参数与 gen_kowtow 一致，保证磕头->礼成同一空间听感。"""
    dur = 5.0
    out = np.zeros(int(SR * dur))

    # 层1：寺庙大鼓双击收束 - 承接磕头三叩首（kowtow: 62/55/48Hz 三下），
    #   末槌更深沉（50->42Hz），长余韵象征叩拜圆满。与磕头同 temple_drum 音色。
    out = place(temple_drum(50, 2.0) * 0.72, out, 0.0)
    out = place(temple_drum(42, 2.8) * 0.85, out, 0.55)

    # 层2：庄严礼成大钟 - 在第二击鼓声余韵中响起，福到神圣。
    #   G2 (98Hz) + G3 (196Hz) 双钟，谐和泛音列，与 BGM 同 G 大调。
    out = place(majestic_bell(98, 4.0, decay_rate=0.7) * 0.38, out, 0.7)
    out = place(majestic_bell(196, 3.2, decay_rate=0.9) * 0.24, out, 0.85)

    # 殿堂混响 - 与 gen_kowtow 完全一致（decay=0.9, length=2.2, wet=0.45），同空间听感
    out = reverb(out, decay=0.9, length=2.2, wet=0.45)
    out = out[:int(SR * dur)]

    out_path = str(OUT_DIR / "blessing.mp3")
    coin_path = str(Path(__file__).resolve().parent / "coin-shower-cc0.mp3")

    if os.path.exists(coin_path):
        # 真实 CC0 钱币录音：合成 base 写临时 WAV，用 ffmpeg 混合
        base_wav = tempfile.mktemp(suffix=".wav")
        sig = normalize(out)
        audio_int = (sig * 32767).astype(np.int16)
        import wave
        with wave.open(base_wav, "w") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(audio_int.tobytes())
        try:
            subprocess.run([
                FFMPEG, "-y",
                "-i", base_wav,
                "-i", coin_path,
                "-filter_complex",
                # 钱币声处理：highpass 去低频干扰 + treble 增强金属高频 +
                # dynaudnorm 自适应归一化（mean -38dB -> 可听水平）+
                # volume 2x 提升 + adelay 延迟到 1.4s（大鼓/钟之后）
                "[1:a]highpass=f=1500,treble=g=12:f=2500,dynaudnorm=p=0.95:g=101,"
                "volume=2.0,adelay=1400|1400[coin];"
                "[0:a][coin]amix=inputs=2:duration=first:dropout_transition=0:normalize=0,"
                "alimiter=limit=0.9[a]",
                "-map", "[a]",
                "-codec:a", "libmp3lame", "-b:a", "96k", "-ac", "1",
                out_path
            ], check=True, capture_output=True)
            kb = os.path.getsize(out_path) / 1024
            print(f"   [OK] blessing.mp3 ({kb:.1f} KB) [真实CC0钱币录音 + 合成大鼓/钟]")
        except subprocess.CalledProcessError:
            # ffmpeg 失败兜底用合成钱币
            out_final = place(coin_shower(dur=3.4, density_per_sec=20) * 0.52, out, 1.4)
            write_mp3(out_final, out_path, bitrate=96)
        finally:
            if os.path.exists(base_wav):
                os.unlink(base_wav)
    else:
        # 无 CC0 素材时用合成钱币兜底
        out_final = place(coin_shower(dur=3.4, density_per_sec=20) * 0.52, out, 1.4)
        write_mp3(out_final, out_path, bitrate=96)


def gen_bgm():
    """背景氛围 - 古筝五声音阶慢旋律，30 秒可循环。"""
    dur = 30.0
    total = int(SR * dur)
    out = np.zeros(total)
    # 五声音阶（G 调）：G4 A4 B4 D5 E5
    scale = [392, 440, 494, 587, 659]
    # 慢旋律（音高索引序列），14 个音，每音 2 秒
    melody = [4, 3, 2, 1, 0, 1, 2, 3, 4, 3, 2, 1, 0, 2]
    for i, idx in enumerate(melody):
        f = scale[idx]
        note = karplus_strong(f, 2.6, decay=0.994)
        out = place(note, out, i * 2.0)
    # 低音点缀
    for i in range(0, 14, 4):
        bass = karplus_strong(scale[0] / 2, 3.0, decay=0.992) * 0.4
        out = place(bass, out, i * 2.0)
    out = reverb(out, decay=1.8, length=1.5, wet=0.3)
    out = out[:total]  # 裁到正好 30 秒
    # 淡入淡出，保证循环接缝平滑
    fade = int(SR * 0.5)
    out[:fade] *= np.linspace(0, 1, fade)
    out[-fade:] *= np.linspace(1, 0, fade)
    write_mp3(out, str(OUT_DIR / "bgm.mp3"), bitrate=96)


GENS = {
    "appear": gen_appear,
    "incense": gen_incense,
    "kowtow": gen_kowtow,
    "blessing": gen_blessing,
    "bgm": gen_bgm,
}


def main():
    keys = sys.argv[1:] if len(sys.argv) > 1 else list(GENS.keys())
    for k in keys:
        if k not in GENS:
            print(f"   [SKIP] unknown: {k}")
            continue
        print(f">> gen {k}")
        try:
            GENS[k]()
        except Exception as e:
            print(f"   [FAIL] {k}: {e}")
    print("done.")


if __name__ == "__main__":
    main()
