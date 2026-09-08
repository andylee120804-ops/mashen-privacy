// 硅基流动文生图（同 seed 锁风格/构图，只改姿势词）——免费余额可用。
// 测试能否靠 seed 锁住人物一致性、只换磕头姿势。
// 用法: node scripts/sf-txt2img-seed.mjs "<姿势prompt>" <out> <seed>
import { writeFileSync, mkdirSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const KEY = 'sk-izzswqdtlbmkkuxizbqrovkppxvbdomoujaezttrghipkpsx';
const OUT_DIR = resolve(__dirname, 'kowtow-frames');

const STYLE = 'Q-version chibi cartoon Chinese style, back view of a cute chibi worshipper devotee, big head small body, wearing traditional red Hanfu robe with gold trim, facing away toward deities, vibrant saturated colors, clean solid light cream background, high detail, digital painting, soft studio lighting, centered full body';
const posePrompt = process.argv[2];
const outName = process.argv[3] || 'f.png';
const seed = parseInt(process.argv[4] || '211');

const body = {
  model: 'Qwen/Qwen-Image',
  prompt: `${STYLE}. ${posePrompt}.`,
  image_size: '1024x1024',
  seed,
};
console.log(`seed=${seed} out=${outName}\npose: ${posePrompt.slice(0,80)}`);

const t0 = Date.now();
const res = await fetch('https://api.siliconflow.cn/v1/images/generations', {
  method: 'POST',
  headers: { 'Authorization': `Bearer ${KEY}`, 'Content-Type': 'application/json' },
  body: JSON.stringify(body),
});
const data = await res.json();
console.log(`HTTP ${res.status} (${Date.now()-t0}ms)`);
if (!data.images || !data.images[0]) { console.error(JSON.stringify(data).slice(0,500)); process.exit(1); }
const buf = Buffer.from(await (await fetch(data.images[0].url)).arrayBuffer());
mkdirSync(OUT_DIR, { recursive: true });
const p = resolve(OUT_DIR, outName);
writeFileSync(p, buf);
console.log(`✓ ${p} (${(buf.length/1024).toFixed(1)} KB)`);
