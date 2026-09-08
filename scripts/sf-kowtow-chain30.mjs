/**
 * 链式生成 30 帧磕头动画：每帧输出作为下一帧输入。
 * 小步递进 → 方向锁定、人物一致、动作丝滑。
 * 下拜14帧 → 触地停留4帧 → 起身12帧 = 30帧
 */
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const KEY = 'sk-izzswqdtlbmkkuxizbqrovkppxvbdomoujaezttrghipkpsx';
const SRC = resolve(__dirname, '../entry/src/main/resources/rawfile/props/worshipper_bow1.png');
const OUT_DIR = resolve(__dirname, 'kowtow-frames-30');
mkdirSync(OUT_DIR, { recursive: true });

const KEEP = 'CRITICAL RULE: The figure must ALWAYS face AWAY from the viewer/camera. Back of head ALWAYS visible. Back view ONLY. Never turn sideways or face the camera. Keep the exact same red Hanfu robe with gold trim, same big-head-small-body chibi proportions, same cream background, same digital painting style, same character.';

// 30帧：每帧只做小幅递进，AI 不会跑偏
const STEPS = [
  // === 下拜 0°→180° (14帧, 每帧约13°) ===
  { out: 'f01.png',  pose: 'Kneeling upright, back completely vertical and straight. No change from original. Back view, facing away.' },
  { out: 'f02.png',  pose: 'Very slight forward lean, about 5 degrees. Barely noticeable. Back view, facing away.' },
  { out: 'f03.png',  pose: 'Lean forward about 12 degrees. Head tilts forward slightly. Back view, facing away.' },
  { out: 'f04.png',  pose: 'Bow forward about 20 degrees. Upper body tilting a little. Back view, facing away.' },
  { out: 'f05.png',  pose: 'Bow forward about 30 degrees. Hands starting to move forward. Back view, facing away.' },
  { out: 'f06.png',  pose: 'Bow forward about 40 degrees. Upper body at diagonal. Back view, facing away.' },
  { out: 'f07.png',  pose: 'Bow forward about 50 degrees. Head lowered to about chest height. Back view, facing away.' },
  { out: 'f08.png',  pose: 'Bow forward about 60 degrees. Arms extending forward. Back view, facing away.' },
  { out: 'f09.png',  pose: 'Bow forward about 70 degrees. Upper body steep angle. Back view, facing away.' },
  { out: 'f10.png',  pose: 'Bow forward about 80 degrees. Head near ground level. Back view, facing away.' },
  { out: 'f11.png',  pose: 'Bow forward about 90 degrees. Upper body horizontal, arms reaching ground. Back view, facing away.' },
  { out: 'f12.png',  pose: 'Upper body below horizontal, about 110 degrees. Hands touching ground, head very close to ground. Back view, facing away.' },
  { out: 'f13.png',  pose: 'Almost flat, about 130 degrees. Forehead nearly touching ground, arms flat on ground. Back view, facing away.' },
  { out: 'f14.png',  pose: 'Full flat prostration, about 150 degrees. Forehead firmly on ground, arms stretched forward on ground, body flat. Back view, facing away.' },
  // === 触地停留 (4帧, 同姿势) ===
  { out: 'f15.png',  pose: 'Full prostration, forehead on ground, holding. Same pose as before. Back view, facing away.' },
  { out: 'f16.png',  pose: 'Full prostration, forehead on ground, holding. Same pose. Back view, facing away.' },
  { out: 'f17.png',  pose: 'Full prostration, forehead on ground, holding. Same pose. Back view, facing away.' },
  { out: 'f18.png',  pose: 'Full prostration, forehead on ground, holding. Same pose. Back view, facing away.' },
  // === 起身 (12帧) ===
  { out: 'f19.png',  pose: 'Starting to rise, head lifts off ground about 5cm. Arms still on ground. Back view, facing away.' },
  { out: 'f20.png',  pose: 'Rising, head lifted about 15 degrees off ground. Arms still extended. Back view, facing away.' },
  { out: 'f21.png',  pose: 'Rising, upper body at about 30 degrees from ground. Head at knee height. Back view, facing away.' },
  { out: 'f22.png',  pose: 'Rising, upper body at about 45 degrees. Arms pulling back. Back view, facing away.' },
  { out: 'f23.png',  pose: 'Rising, upper body at about 55 degrees. Hands coming back toward body. Back view, facing away.' },
  { out: 'f24.png',  pose: 'Rising, upper body at about 65 degrees. Head rising. Back view, facing away.' },
  { out: 'f25.png',  pose: 'Rising, upper body at about 75 degrees. Almost upright. Back view, facing away.' },
  { out: 'f26.png',  pose: 'Rising, upper body at about 80 degrees. Very slight forward lean. Back view, facing away.' },
  { out: 'f27.png',  pose: 'Rising, upper body at about 85 degrees. Almost straight. Back view, facing away.' },
  { out: 'f28.png',  pose: 'Nearly upright, about 88 degrees. Just barely leaning forward. Back view, facing away.' },
  { out: 'f29.png',  pose: 'Almost completely upright, about 90 degrees. Hands at chest. Back view, facing away.' },
  { out: 'f30.png',  pose: 'Fully upright kneeling, back completely vertical and straight, hands pressed together at chest. Same as starting pose. Back view, facing away.' },
];

async function editOne(inputPath, step, idx) {
  const b64 = 'data:image/png;base64,' + readFileSync(inputPath).toString('base64');
  const body = {
    model: 'Qwen/Qwen-Image-Edit-2509',
    prompt: `${step.pose}. ${KEEP}`,
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
        const outPath = resolve(OUT_DIR, step.out);
        writeFileSync(outPath, buf);
        console.log(`  [${idx}/30] ${step.out} (${(buf.length/1024).toFixed(0)}KB, ${Date.now()-t0}ms)`);
        return outPath;
      }
      console.warn(`  retry ${step.out} attempt${attempt}: ${JSON.stringify(data).slice(0,150)}`);
    } catch (e) {
      console.warn(`  retry ${step.out} attempt${attempt}: ${e.message}`);
    }
    await new Promise(r => setTimeout(r, 3000));
  }
  console.error(`  FAIL ${step.out}, using prev as fallback`);
  return inputPath;
}

async function main() {
  let currentInput = SRC;
  console.log('链式生成 30 帧磕头序列 (预计 ~12 分钟)...\n');
  for (let i = 0; i < STEPS.length; i++) {
    const step = STEPS[i];
    console.log(`-> ${step.out}  (${step.pose.slice(0, 50)}...)`);
    currentInput = await editOne(currentInput, step, i + 1);
  }
  console.log('\n30 帧全部完成! 接下来: python scripts/rembg-kowtow-chain30.py');
}

main();
