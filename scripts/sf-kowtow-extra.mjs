// 生成 3 个补充中间帧，使 5 帧序列扩展为 8 帧（更丝滑）
// 用法: node scripts/sf-kowtow-extra.mjs
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

// 补充的中间帧（插入现有 5 帧之间）
const EXTRA = [
  { out: 'f1b_slightbow.png', pose: 'Slight bow: upper body tilting forward just a little, about 15-20 degrees from vertical, head barely lowered, hands still near chest. Very slight forward lean, still mostly upright.' },
  { out: 'f2b_midbow.png', pose: 'Medium-deep bow: upper body bent forward about 55-60 degrees, head lowered well below shoulders, arms extending forward. Between half-bow and deep-bow.' },
  { out: 'f4b_risehalf.png', pose: 'Rising from prostration: upper body lifted back up to about a 40 degree forward lean, head raised to mid-height, arms pulling back from the ground. Half-rise pose.' },
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
  console.error(`  ✗✗ ${f.out} 失败`);
}

for (const f of EXTRA) {
  await genOne(f);
}
console.log('补充帧完成');
