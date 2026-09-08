// 生成完整磕头序列：站立→半弯→深弯→触地→起身（5帧）
// 每帧都以 worshipper_bow1.png 为底图做 img2img，保证人物一致。
// 用法: node scripts/sf-kowtow-seq.mjs
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const KEY = 'sk-izzswqdtlbmkkuxizbqrovkppxvbdomoujaezttrghipkpsx';
const SRC = resolve(__dirname, '../entry/src/main/resources/rawfile/props/worshipper_bow1.png');
const OUT_DIR = resolve(__dirname, 'kowtow-frames');
mkdirSync(OUT_DIR, { recursive: true });

const b64 = 'data:image/png;base64,' + readFileSync(SRC).toString('base64');

const KEEP = 'Keep the EXACT same character, same red Hanfu robe with gold trim, same back view facing away from camera, same big-head-small-body chibi proportions, same clean cream background, same digital painting style.';

const FRAMES = [
  { out: 'f1_stand.png', pose: 'Kneeling upright, back completely straight and vertical, hands pressed together in prayer at chest level. Standing-kneeling pose, no bow.' },
  { out: 'f2_halfbow.png', pose: 'Bowing halfway forward, upper body leaning forward about 45 degrees, head lowered partway, hands pressed together extended forward. Half bow.' },
  { out: 'f3_deepbow.png', pose: 'Bowing deeply, upper body bent far forward nearly horizontal, head lowered close to ground, arms extended forward. Deep bow.' },
  { out: 'f4_prostration.png', pose: 'Full prostration: torso and head lying completely flat on the ground, forehead touching the floor, both arms stretched forward along the ground, only lower legs remain kneeling. Back horizontal. Kowtow, head on ground.' },
  { out: 'f5_rise.png', pose: 'Rising back up, upper body returning to about 45 degrees, head lifting partway, arms coming back. Mid-rise pose.' },
];

async function genOne(f) {
  const body = {
    model: 'Qwen/Qwen-Image-Edit-2509',
    prompt: `${f.pose}. ${KEEP}`,
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
        writeFileSync(resolve(OUT_DIR, f.out), buf);
        console.log(`✓ ${f.out} (${(buf.length/1024).toFixed(0)}KB, ${Date.now()-t0}ms)`);
        return;
      }
      console.warn(`  ✗ ${f.out} attempt${attempt}: ${JSON.stringify(data).slice(0,200)}`);
    } catch (e) {
      console.warn(`  ✗ ${f.out} attempt${attempt}: ${e.message}`);
    }
    await new Promise(r => setTimeout(r, 2000));
  }
  console.error(`  ✗✗ ${f.out} 全部失败`);
}

for (const f of FRAMES) {
  await genOne(f);
}
console.log('序列完成');
