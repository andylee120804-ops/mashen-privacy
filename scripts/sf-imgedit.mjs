// 硅基流动 Qwen-Image-Edit 指令式图生图：以现有 worshipper_bow1.png 为底图，
// 用自然语言指令驱动人物磕头姿势（保人物一致性，改姿势）。
// 用法: node scripts/sf-imgedit.mjs "<编辑指令>" <输出文件名>
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const KEY = 'sk-izzswqdtlbmkkuxizbqrovkppxvbdomoujaezttrghipkpsx';
const SRC = resolve(__dirname, '../entry/src/main/resources/rawfile/props/worshipper_bow1.png');
const OUT_DIR = resolve(__dirname, 'kowtow-frames');

const instruction = process.argv[2] || 'bow deeply';
const outName = process.argv[3] || 'frame.png';

const b64 = 'data:image/png;base64,' + readFileSync(SRC).toString('base64');
console.log(`底图: ${SRC} (b64 ${b64.length})`);
console.log(`指令: ${instruction}`);

const body = {
  model: 'Qwen/Qwen-Image-Edit-2509',
  prompt: instruction,
  image: b64,
  image_size: '1024x1024',
};

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
const url = data.images[0].url;
const imgRes = await fetch(url);
const buf = Buffer.from(await imgRes.arrayBuffer());
mkdirSync(OUT_DIR, { recursive: true });
const outPath = resolve(OUT_DIR, outName);
writeFileSync(outPath, buf);
console.log(`✓ 已保存 ${outPath} (${(buf.length / 1024).toFixed(1)} KB)`);
