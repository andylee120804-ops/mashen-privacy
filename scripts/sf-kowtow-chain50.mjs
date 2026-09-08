/**
 * 链式生成 50 帧细化下拜序列（0°→150°）+ 4 帧触地停留 = 54 帧。
 * 每帧 ~3° 增量，动作极致丝滑。
 * 从 kowtow_01.png（站立）开始链式生成。
 */
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const KEY = 'sk-izzswqdtlbmkkuxizbqrovkppxvbdomoujaezttrghipkpsx';
const SRC = resolve(__dirname, '../entry/src/main/resources/rawfile/animations/kowtow_01.png');
const OUT_DIR = resolve(__dirname, 'kowtow-frames-50');
mkdirSync(OUT_DIR, { recursive: true });

const KEEP = 'CRITICAL: The figure MUST ALWAYS face AWAY from viewer/camera. Back of head ALWAYS visible. Back view ONLY. Keep exact red Hanfu robe with gold trim, same big-head-small-body chibi proportions, same cream background, same digital painting style, same character.';

// 50帧下拜：0°→150°，每帧~3°
const DESCENT = [
  { deg: 0,   pose: 'Kneeling upright, back completely vertical and straight. Facing away.' },
  { deg: 5,   pose: 'Lean forward about 5 degrees. Very slight lean. Facing away.' },
  { deg: 10,  pose: 'Lean forward about 10 degrees. Head tilts forward a tiny bit. Facing away.' },
  { deg: 13,  pose: 'Lean forward about 13 degrees. Slight bow. Facing away.' },
  { deg: 16,  pose: 'Lean forward about 16 degrees. Facing away.' },
  { deg: 19,  pose: 'Lean forward about 19 degrees. Facing away.' },
  { deg: 22,  pose: 'Lean forward about 22 degrees. Facing away.' },
  { deg: 25,  pose: 'Bow forward about 25 degrees. Facing away.' },
  { deg: 28,  pose: 'Bow forward about 28 degrees. Facing away.' },
  { deg: 31,  pose: 'Bow forward about 31 degrees. Facing away.' },
  { deg: 34,  pose: 'Bow forward about 34 degrees. Facing away.' },
  { deg: 37,  pose: 'Bow forward about 37 degrees. Facing away.' },
  { deg: 40,  pose: 'Bow forward about 40 degrees. Upper body at diagonal. Facing away.' },
  { deg: 43,  pose: 'Bow forward about 43 degrees. Facing away.' },
  { deg: 46,  pose: 'Bow forward about 46 degrees. Facing away.' },
  { deg: 49,  pose: 'Bow forward about 49 degrees. Facing away.' },
  { deg: 52,  pose: 'Bow forward about 52 degrees. Facing away.' },
  { deg: 55,  pose: 'Bow forward about 55 degrees. Head lowered to waist height. Facing away.' },
  { deg: 58,  pose: 'Bow forward about 58 degrees. Facing away.' },
  { deg: 61,  pose: 'Bow forward about 61 degrees. Facing away.' },
  { deg: 64,  pose: 'Bow forward about 64 degrees. Facing away.' },
  { deg: 67,  pose: 'Bow forward about 67 degrees. Facing away.' },
  { deg: 70,  pose: 'Bow forward about 70 degrees. Upper body at steep angle. Facing away.' },
  { deg: 73,  pose: 'Bow forward about 73 degrees. Facing away.' },
  { deg: 76,  pose: 'Bow forward about 76 degrees. Facing away.' },
  { deg: 79,  pose: 'Bow forward about 79 degrees. Head near ground. Facing away.' },
  { deg: 82,  pose: 'Bow forward about 82 degrees. Facing away.' },
  { deg: 85,  pose: 'Bow forward about 85 degrees. Upper body horizontal. Facing away.' },
  { deg: 88,  pose: 'Bow forward about 88 degrees. Facing away.' },
  { deg: 91,  pose: 'Bow forward about 91 degrees. Head touching ground. Facing away.' },
  { deg: 94,  pose: 'Bow forward about 94 degrees. Upper body below horizontal. Facing away.' },
  { deg: 97,  pose: 'Bow forward about 97 degrees. Facing away.' },
  { deg: 100, pose: 'Bow forward about 100 degrees. Facing away.' },
  { deg: 103, pose: 'Bow forward about 103 degrees. Facing away.' },
  { deg: 106, pose: 'Bow forward about 106 degrees. Facing away.' },
  { deg: 109, pose: 'Bow forward about 109 degrees. Facing away.' },
  { deg: 112, pose: 'Bow forward about 112 degrees. Facing away.' },
  { deg: 115, pose: 'Bow forward about 115 degrees. Facing away.' },
  { deg: 118, pose: 'Bow forward about 118 degrees. Facing away.' },
  { deg: 121, pose: 'Bow forward about 121 degrees. Facing away.' },
  { deg: 124, pose: 'Bow forward about 124 degrees. Facing away.' },
  { deg: 127, pose: 'Bow forward about 127 degrees. Almost flat. Facing away.' },
  { deg: 130, pose: 'Bow forward about 130 degrees. Almost flat. Facing away.' },
  { deg: 133, pose: 'Bow forward about 133 degrees. Almost flat. Facing away.' },
  { deg: 136, pose: 'Bow forward about 136 degrees. Nearly flat. Facing away.' },
  { deg: 139, pose: 'Bow forward about 139 degrees. Nearly flat. Facing away.' },
  { deg: 142, pose: 'Bow forward about 142 degrees. Nearly flat. Facing away.' },
  { deg: 145, pose: 'Bow forward about 145 degrees. Almost fully prostrate. Facing away.' },
  { deg: 148, pose: 'Bow forward about 148 degrees. Almost fully prostrate. Facing away.' },
  { deg: 150, pose: 'Full prostration, forehead on ground, arms stretched forward. Fully flat. Facing away.' },
  // 触地停留 4 帧
  { deg: 150, pose: 'Full prostration, forehead on ground, holding still. Same pose. Facing away.' },
  { deg: 150, pose: 'Full prostration, forehead on ground, holding still. Same pose. Facing away.' },
  { deg: 150, pose: 'Full prostration, forehead on ground, holding still. Same pose. Facing away.' },
  { deg: 150, pose: 'Full prostration, forehead on ground, holding still. Same pose. Facing away.' },
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
        const outPath = resolve(OUT_DIR, `f${String(idx+1).padStart(3,'0')}.png`);
        writeFileSync(outPath, buf);
        console.log(`  [${idx+1}/54] f${String(idx+1).padStart(3,'0')} (${(buf.length/1024).toFixed(0)}KB, ${Date.now()-t0}ms)`);
        return outPath;
      }
      console.warn(`  retry ${idx+1} attempt${attempt}: ${JSON.stringify(data).slice(0,150)}`);
    } catch (e) {
      console.warn(`  retry ${idx+1} attempt${attempt}: ${e.message}`);
    }
    await new Promise(r => setTimeout(r, 3000));
  }
  console.error(`  FAIL f${idx+1}, fallback to prev`);
  return inputPath;
}

async function main() {
  let currentInput = SRC;
  console.log('Generating 54 smooth descent frames (50+4 hold)...\n');
  for (let i = 0; i < DESCENT.length; i++) {
    currentInput = await editOne(currentInput, DESCENT[i], i);
  }
  console.log('\nDone! Next: python scripts/rembg-kowtow-chain50.py');
}

main();
