/**
 * 细化磕头动画：以 30帧版的 f01-f19 为关键帧锚点，
 * 在每对关键帧之间生成中间帧（下拜段2帧/段，起身段1帧），
 * 短链不跑偏，动作更丝滑。
 *
 * 关键帧来源：scripts/kowtow-frames-30/f01.png ~ f19.png
 * 输出：scripts/kowtow-frames-smooth/f001.png ~ fNNN.png
 */
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const KEY = 'sk-izzswqdtlbmkkuxizbqrovkppxvbdomoujaezttrghipkpsx';
const KEY_DIR = resolve(__dirname, 'kowtow-frames-30');
const OUT_DIR = resolve(__dirname, 'kowtow-frames-smooth');
mkdirSync(OUT_DIR, { recursive: true });

const KEEP = 'CRITICAL RULE: The figure must ALWAYS face AWAY from the viewer/camera. Back of head ALWAYS visible. Back view ONLY. Never turn sideways or face the camera. Keep the exact same red Hanfu robe with gold trim, same big-head-small-body chibi proportions, same cream background, same digital painting style, same character.';

// 19 关键帧：度数 + 姿势描述（度数 -1 = 起身段，不用度数）
const KEY_FRAMES = [
  { name: 'f01', deg: 0,   desc: 'Kneeling upright, back completely vertical and straight' },
  { name: 'f02', deg: 5,   desc: 'Very slight forward lean, about 5 degrees' },
  { name: 'f03', deg: 12,  desc: 'Lean forward about 12 degrees, head tilts forward slightly' },
  { name: 'f04', deg: 20,  desc: 'Bow forward about 20 degrees, upper body tilting a little' },
  { name: 'f05', deg: 30,  desc: 'Bow forward about 30 degrees, hands starting to move forward' },
  { name: 'f06', deg: 40,  desc: 'Bow forward about 40 degrees, upper body at diagonal' },
  { name: 'f07', deg: 50,  desc: 'Bow forward about 50 degrees, head lowered to about chest height' },
  { name: 'f08', deg: 60,  desc: 'Bow forward about 60 degrees, arms extending forward' },
  { name: 'f09', deg: 70,  desc: 'Bow forward about 70 degrees, upper body steep angle' },
  { name: 'f10', deg: 80,  desc: 'Bow forward about 80 degrees, head near ground level' },
  { name: 'f11', deg: 90,  desc: 'Bow forward about 90 degrees, upper body horizontal, arms reaching ground' },
  { name: 'f12', deg: 110, desc: 'Upper body below horizontal about 110 degrees, hands touching ground, head very close to ground' },
  { name: 'f13', deg: 130, desc: 'Almost flat about 130 degrees, forehead nearly touching ground, arms flat on ground' },
  { name: 'f14', deg: 150, desc: 'Full flat prostration about 150 degrees, forehead firmly on ground, arms stretched forward on ground, body flat' },
  { name: 'f15', deg: 150, desc: 'Full prostration, forehead on ground, holding' },
  { name: 'f16', deg: 150, desc: 'Full prostration, forehead on ground, holding' },
  { name: 'f17', deg: 150, desc: 'Full prostration, forehead on ground, holding' },
  { name: 'f18', deg: 150, desc: 'Full prostration, forehead on ground, holding' },
  { name: 'f19', deg: -1,  desc: 'Starting to rise, head lifts off ground about 5cm, arms still on ground' },
];

// 判断两帧之间是否需要生成中间帧（度数相同=停留段，跳过）
function needsIntermediates(a, b) {
  return a.deg !== b.deg;
}

// 为中间帧生成姿势描述（基于度数插值）
function midPose(degA, degB, t) {
  const mid = degA + (degB - degA) * t;
  if (mid < 10) return `Very slight forward lean, about ${mid.toFixed(0)} degrees`;
  if (mid < 25) return `Lean forward about ${mid.toFixed(0)} degrees, head tilts forward`;
  if (mid < 45) return `Bow forward about ${mid.toFixed(0)} degrees, upper body tilting, hands moving forward`;
  if (mid < 65) return `Bow forward about ${mid.toFixed(0)} degrees, arms extending forward, head lowered`;
  if (mid < 85) return `Bow forward about ${mid.toFixed(0)} degrees, upper body at steep angle, head near ground`;
  if (mid < 100) return `Bow forward about ${mid.toFixed(0)} degrees, upper body horizontal, arms reaching ground`;
  if (mid < 120) return `Upper body below horizontal about ${mid.toFixed(0)} degrees, hands touching ground, head very close to ground`;
  if (mid < 140) return `Almost flat about ${mid.toFixed(0)} degrees, forehead nearly touching ground, arms flat on ground`;
  return `Full flat prostration about ${mid.toFixed(0)} degrees, forehead firmly on ground, arms stretched forward, body flat`;
}

async function editOne(inputPath, prompt, label, idx, total) {
  const b64 = 'data:image/png;base64,' + readFileSync(inputPath).toString('base64');
  const body = {
    model: 'Qwen/Qwen-Image-Edit-2509',
    prompt: `${prompt}. ${KEEP}`,
    image: b64,
    image_size: '1024x1024',
  };
  const t0 = Date.now();
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      const res = await fetch('https://api.siliconflow.cn/v1/images/generations', {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${KEY}`, 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });
      const data = await res.json();
      if (data.images && data.images[0]) {
        const buf = Buffer.from(await (await fetch(data.images[0].url)).arrayBuffer());
        console.log(`  [${idx}/${total}] ${label} (${(buf.length/1024).toFixed(0)}KB, ${Date.now()-t0}ms)`);
        return buf;
      }
      console.warn(`  retry ${label} attempt${attempt}: ${JSON.stringify(data).slice(0,150)}`);
    } catch (e) {
      console.warn(`  retry ${label} attempt${attempt}: ${e.message}`);
    }
    await new Promise(r => setTimeout(r, 3000));
  }
  console.error(`  FAIL ${label}, using input as fallback`);
  return readFileSync(inputPath);
}

async function main() {
  // 先构建完整帧序列计划
  const plan = []; // {type:'key'|'mid', name, srcKey, degA, degB, t}
  for (let i = 0; i < KEY_FRAMES.length; i++) {
    const kf = KEY_FRAMES[i];
    plan.push({ type: 'key', name: kf.name, kf });
    if (i < KEY_FRAMES.length - 1) {
      const next = KEY_FRAMES[i + 1];
      if (needsIntermediates(kf, next)) {
        if (next.deg === -1) {
          // 起身段：1 个中间帧
          plan.push({ type: 'mid', name: `${kf.name}_${next.name}`, fromKey: kf.name, degA: kf.deg, degB: kf.deg, t: 0, isRise: true });
        } else {
          // 下拜段：2 个中间帧
          plan.push({ type: 'mid', name: `${kf.name}_${next.name}_a`, fromKey: kf.name, degA: kf.deg, degB: next.deg, t: 0.33 });
          plan.push({ type: 'mid', name: `${kf.name}_${next.name}_b`, fromKey: null, degA: kf.deg, degB: next.deg, t: 0.67 });
        }
      }
    }
  }

  const total = plan.filter(p => p.type === 'mid').length;
  console.log(`计划：${KEY_FRAMES.length} 关键帧 + ${total} 中间帧 = ${plan.length} 总帧\n`);

  let outIdx = 0;
  let midIdx = 0;
  let lastMidBuf = null; // 上一中间帧的 buffer（用于 b 帧的链式输入）

  for (const item of plan) {
    outIdx++;
    const outName = `f${String(outIdx).padStart(3, '0')}.png`;
    const outPath = resolve(OUT_DIR, outName);

    if (item.type === 'key') {
      // 关键帧：直接复制
      const srcPath = resolve(KEY_DIR, `${item.kf.name}.png`);
      const buf = readFileSync(srcPath);
      writeFileSync(outPath, buf);
      console.log(`  [${outIdx}/${plan.length}] ${outName} = ${item.kf.name} (key, ${(buf.length/1024).toFixed(0)}KB)`);
      lastMidBuf = null;
    } else {
      // 中间帧：img2img 生成
      midIdx++;
      let inputPath;
      let prompt;
      if (item.fromKey) {
        // a 帧 或 起身帧：从关键帧开始
        inputPath = resolve(KEY_DIR, `${item.fromKey}.png`);
        if (item.isRise) {
          prompt = 'Forehead still touching ground but very slightly beginning to lift, about 2cm rise, arms still on ground';
        } else {
          prompt = midPose(item.degA, item.degB, item.t);
        }
      } else {
        // b 帧：从 a 帧的 buffer 继续
        const tmpPath = resolve(OUT_DIR, `_tmp_last.png`);
        writeFileSync(tmpPath, lastMidBuf);
        inputPath = tmpPath;
        prompt = midPose(item.degA, item.degB, item.t);
      }
      const buf = await editOne(inputPath, prompt, `${outName} (${item.name})`, midIdx, total);
      writeFileSync(outPath, buf);
      lastMidBuf = buf;
    }
  }

  // 清理临时文件
  try { const tmp = resolve(OUT_DIR, '_tmp_last.png'); if (existsSync(tmp)) writeFileSync(tmp, ''); } catch (e) {}

  console.log(`\n完成! 共 ${outIdx} 帧 -> scripts/kowtow-frames-smooth/`);
  console.log('下一步: python scripts/rembg-kowtow-smooth.py');
}

main();
