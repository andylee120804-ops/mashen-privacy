// 硅基流动 img2img：用文生图模型 + image 字段做图生图（保人物改姿势）。
// 用法: node scripts/sf-img2img.mjs <model> "<指令>" <输出文件名> [strength]
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const KEY = 'sk-izzswqdtlbmkkuxizbqrovkppxvbdomoujaezttrghipkpsx';
const SRC = resolve(__dirname, '../entry/src/main/resources/rawfile/props/worshipper_bow1.png');
const OUT_DIR = resolve(__dirname, 'kowtow-frames');

const model = process.argv[2];
const instruction = process.argv[3] || 'bow';
const outName = process.argv[4] || 'frame.png';
const strength = parseFloat(process.argv[5] || '0.6');

const b64 = readFileSync(SRC).toString('base64');
console.log(`model=${model} strength=${strength}\n指令: ${instruction.slice(0,80)}...`);

const body = {
  model,
  prompt: instruction,
  image: b64,
  image_size: '1024x1024',
};
if (model.startsWith('Kwai')) body.strength = strength;

const t0 = Date.now();
const res = await fetch('https://api.siliconflow.cn/v1/images/generations', {
  method: 'POST',
  headers: { 'Authorization': `Bearer ${KEY}`, 'Content-Type': 'application/json' },
  body: JSON.stringify(body),
});
const data = await res.json();
console.log(`HTTP ${res.status} (${Date.now() - t0}ms)`);
if (!data.images || !data.images[0]) {
  console.error(JSON.stringify(data).slice(0, 600));
  process.exit(1);
}
const buf = Buffer.from(await (await fetch(data.images[0].url)).arrayBuffer());
mkdirSync(OUT_DIR, { recursive: true });
const outPath = resolve(OUT_DIR, outName);
writeFileSync(outPath, buf);
console.log(`✓ ${outPath} (${(buf.length/1024).toFixed(1)} KB)`);
