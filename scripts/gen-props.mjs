// 道具素材生成脚本 - 通过 Pollinations.ai (FLUX) 生成祈福小人、香炉、单根香
// 与 gen-deity.mjs 同画风（Q版 chibi 国风），生成后需用 remove-bg-props.py 抠透明背景。
//
// 用法：
//   node scripts/gen-props.mjs                 # 生成全部 3 张
//   node scripts/gen-props.mjs worshipper      # 只生成 worshipper
//   node scripts/gen-props.mjs worshipper incense_stick
//
// 输出：entry/src/main/resources/rawfile/props/{name}.jpg
// 抠图：python scripts/remove-bg-props.py

import { writeFile, mkdir } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const OUT_DIR = resolve(__dirname, '../entry/src/main/resources/rawfile/props');

const POLLINATIONS_URL = 'https://image.pollinations.ai/prompt/';
const MODEL = 'flux';

// 与财神一致的画风前缀（Q版 chibi 国风、米色背景便于 rembg 抠图）
const STYLE_PREFIX =
  'Q-version chibi cartoon Chinese style, cute chibi style, big head small body, ' +
  'vibrant saturated colors, clean solid light cream background, high detail, ' +
  'digital painting, soft studio lighting';

// 静物道具专用前缀：去掉"big head small body"（否则模型会把静物画成小人），明确 no people
const OBJECT_STYLE_PREFIX =
  'Q-version chibi cartoon Chinese style, vibrant saturated colors, ' +
  'clean solid light cream background, high detail, digital painting, soft studio lighting, ' +
  'still life object, no people, no person, no character, no face';

const PROPS = [
  {
    name: 'worshipper_bow1',
    file: 'worshipper_bow1.jpg',
    width: 512, height: 512, seed: 211,
    prompt:
      'Back view of a cute chibi Chinese worshipper devotee, big head small body, ' +
      'kneeling upright, back of head visible, facing away toward the deities above, ' +
      'wearing traditional red Hanfu robe with gold trim, hands pressed forward in prayer, ' +
      'upright kneeling pose, red and gold color scheme, centered full body',
  },
  {
    name: 'worshipper_bow2',
    file: 'worshipper_bow2.jpg',
    width: 512, height: 512, seed: 212,
    prompt:
      'Back view of a cute chibi Chinese worshipper devotee, big head small body, ' +
      'kneeling and bowing halfway, upper body leaning forward about 45 degrees, back of head visible, ' +
      'facing away toward the deities above, wearing traditional red Hanfu robe with gold trim, ' +
      'half bowing pose, red and gold color scheme, centered full body',
  },
  {
    name: 'worshipper_bow3',
    file: 'worshipper_bow3.jpg',
    width: 512, height: 512, seed: 213,
    prompt:
      'Back view of a cute chibi Chinese worshipper devotee, big head small body, ' +
      'bowing deeply in full prostration, upper body flat on ground, head touching ground, back of head visible, ' +
      'facing away toward the deities above, wearing traditional red Hanfu robe with gold trim, ' +
      'full prostration pose, red and gold color scheme, centered full body',
  },
  {
    name: 'incense_burner',
    file: 'incense_burner.jpg',
    width: 512, height: 448, seed: 202,
    prompt:
      'A cute ornate Chinese bronze incense burner censer, traditional temple censer, ' +
      'golden bronze with red and gold patterns, three burning incense sticks inserted upright in the burner, ' +
      'glowing red embers on stick tips, thin smoke rising, centered, symmetrical, vibrant saturated colors, chibi style',
  },
  {
    name: 'qiu_tube',
    file: 'qiu_tube.jpg',
    width: 512, height: 640, seed: 301,
    useObjectStyle: true,
    prompt:
      'a traditional Chinese fortune telling stick tube (qiuqian bamboo lottery tube), ' +
      'ornate cylindrical red lacquer tube with golden rim and golden decorative cloud patterns, ' +
      'a fan of many thin bamboo fortune sticks with red painted tips protruding from the tube opening at top, ' +
      'bamboo sticks spreading outward like a folding fan, natural bamboo yellow sticks, ' +
      'centered, symmetrical composition, no text, no letters',
  },
  {
    name: 'qiu_stick',
    file: 'qiu_stick.jpg',
    width: 256, height: 640, seed: 302,
    useObjectStyle: true,
    prompt:
      'a single traditional Chinese bamboo fortune telling stick (qian stick), ' +
      'one long slender cylindrical bamboo stick standing perfectly upright and centered, ' +
      'bright red painted rounded tip on the top end, natural light yellow bamboo body with subtle wood grain, ' +
      'the whole stick fully visible from red tip to rounded bottom, ' +
      'vertical composition, no text, no letters',
  },
];

async function generateOne(prop) {
  const stylePrefix = prop.useObjectStyle ? OBJECT_STYLE_PREFIX : STYLE_PREFIX;
  const fullPrompt = `${stylePrefix}. ${prop.prompt}.`;
  const params = new URLSearchParams({
    width: String(prop.width),
    height: String(prop.height),
    model: MODEL,
    seed: String(prop.seed),
    nologo: 'true',
  });
  const url = `${POLLINATIONS_URL}${encodeURIComponent(fullPrompt)}?${params}`;
  const outPath = resolve(OUT_DIR, prop.file);
  console.log(`▶ 生成 ${prop.file}（seed=${prop.seed}, ${prop.width}x${prop.height}）`);

  const start = Date.now();
  const res = await fetch(url, { method: 'GET' });
  if (!res.ok) {
    throw new Error(`HTTP ${res.status} ${res.statusText}`);
  }
  const buf = Buffer.from(await res.arrayBuffer());
  await mkdir(OUT_DIR, { recursive: true });
  await writeFile(outPath, buf);
  const kb = (buf.length / 1024).toFixed(1);
  console.log(`  ✓ 已保存 ${outPath} (${kb} KB, ${Date.now() - start}ms)\n`);
  return outPath;
}

async function main() {
  const args = process.argv.slice(2);
  const targets = args.length
    ? PROPS.filter((p) => args.includes(p.name))
    : PROPS;

  if (!targets.length) {
    console.error('没有匹配的道具素材。可用: ' + PROPS.map((p) => p.name).join(', '));
    process.exit(1);
  }

  console.log(`将生成 ${targets.length} 张道具素材\n`);
  for (const prop of targets) {
    try {
      await generateOne(prop);
    } catch (err) {
      console.error(`  ✗ 失败 ${prop.file}: ${err.message}\n`);
    }
  }
  console.log('完成。接下来运行: python scripts/remove-bg-props.py');
}

main();
