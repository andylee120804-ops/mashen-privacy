// 一次性实验：为签筒/签素材试多组 prompt + seed，挑最好的再固化进 gen-props.mjs
// 输出到 props/_candidates/（挑完即删）
import { writeFile, mkdir } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const OUT_DIR = resolve(__dirname, '../entry/src/main/resources/rawfile/props/_candidates');
const POLLINATIONS_URL = 'https://image.pollinations.ai/prompt/';

// 不用 chibi（太诱导画角色），改游戏道具图标/静物渲染语言
const STYLE =
  'casual mobile game item icon style, Chinese temple aesthetic, warm saturated colors, ' +
  'clean solid light cream background, high detail digital painting, soft studio lighting, ' +
  'inanimate object only, no people, no person, no character, no face, no mascot';

// 策略A：写实摄影风（签筒是真实物件，模型有实物照片先验）
// 策略B：拆分生成——签束/红筒各自单独画，App 内叠放合成
const PHOTO_STYLE =
  'professional product photography, studio lighting, sharp focus, ' +
  'clean solid light cream background, high detail';
const CANDIDATES = [
  {
    name: 'stickJ', width: 640, height: 256, seed: 361,
    prompt:
      'a single long bamboo incense stick lying diagonally across the frame, ' +
      'red coated tip on one end, natural pale bamboo body, one lone stick only, ' +
      'no holder, no container, nothing else',
  },
  {
    name: 'stickK', width: 640, height: 256, seed: 362,
    prompt:
      'a single wooden chopstick-like bamboo stick with red painted end, ' +
      'lying flat diagonally, lone single object, plain background, nothing else',
  },
  {
    name: 'stickL', width: 256, height: 640, seed: 363,
    usePhotoStyle: true,
    prompt:
      'extreme close-up of one thin bamboo stick with red dyed tip, ' +
      'single lone stick, vertical, plain background',
  },
];

async function gen(c) {
  const style = c.usePhotoStyle ? PHOTO_STYLE : STYLE;
  const params = new URLSearchParams({
    width: String(c.width), height: String(c.height),
    model: 'flux', seed: String(c.seed), nologo: 'true',
  });
  const url = `${POLLINATIONS_URL}${encodeURIComponent(`${style}. ${c.prompt}.`)}?${params}`;
  const out = resolve(OUT_DIR, `${c.name}.jpg`);
  console.log(`▶ ${c.name} (seed=${c.seed})`);
  const res = await fetch(url);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const buf = Buffer.from(await res.arrayBuffer());
  await mkdir(OUT_DIR, { recursive: true });
  await writeFile(out, buf);
  console.log(`  ✓ ${(buf.length / 1024).toFixed(1)} KB`);
}

for (const c of CANDIDATES) {
  try { await gen(c); } catch (e) { console.error(`  ✗ ${c.name}: ${e.message}`); }
}
console.log('done');
