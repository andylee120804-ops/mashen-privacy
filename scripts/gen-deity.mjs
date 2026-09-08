// 免费图像生成脚本 - 通过 Pollinations.ai (FLUX 模型) 生成五路财神神像
// 无需 API key，无需 GPU，直接 HTTP 调用。
//
// 用法：
//   node scripts/gen-deity.mjs          # 生成全部 5 张
//   node scripts/gen-deity.mjs 1        # 只生成第 1 张（赵公明）
//   node scripts/gen-deity.mjs 1 4      # 生成第 1 和第 4 张
//
// 输出：entry/src/main/resources/rawfile/deities/{n}.png
// 注意：Pollinations 出的是带背景图，透明背景需另用 rembg 抠图。

import { writeFile, mkdir } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const OUT_DIR = resolve(__dirname, '../entry/src/main/resources/rawfile/deities');

// Pollinations 接口：返回二进制图片，免 key
const POLLINATIONS_URL = 'https://image.pollinations.ai/prompt/';
const MODEL = 'flux'; // flux | turbo
const WIDTH = 512;
const HEIGHT = 512;

// 公共画风前缀 - 与 README 规格对齐：Q版卡通中国风，512×512
const STYLE_PREFIX =
  'Q-version chibi cartoon Chinese God of Wealth (Caishen), ' +
  'cute chibi style, big head small body, traditional Chinese folk deity, ' +
  'centered full body, symmetrical, vibrant saturated colors, ' +
  'clean solid light cream background, high detail, digital painting, ' +
  'soft studio lighting, 512x512';

// 五路财神配置 - 来自 deities/README.md
const DEITIES = [
  {
    file: '1.png',
    name: '赵公明',
    role: '中路',
    desc: '黑面·铁鞭·黑虎，黑金配色',
    prompt:
      'Zhao Gongming the Black-faced Marshal, dark black skin, fierce but cute expression, ' +
      'wearing black and gold ornate armor robe, holding an iron whip, ' +
      'riding a cute black tiger, black and gold color scheme',
    seed: 101,
  },
  {
    file: '2.png',
    name: '萧升',
    role: '东路',
    desc: '绿袍·宝珠，翠绿配色',
    prompt:
      'Xiao Sheng, friendly smiling chibi god, wearing emerald green robe with gold trim, ' +
      'holding a glowing treasure pearl, jade green and gold color scheme',
    seed: 102,
  },
  {
    file: '3.png',
    name: '曹宝',
    role: '西路',
    desc: '棕袍·珍宝，金棕配色',
    prompt:
      'Cao Bao, jolly chibi god, wearing golden brown robe, holding a pile of treasures and gold ingots, ' +
      'golden brown and amber color scheme',
    seed: 103,
  },
  {
    file: '4.png',
    name: '陈九公',
    role: '南路',
    desc: '红袍·金元宝，朱红配色',
    prompt:
      'Chen Jiugong, cheerful chibi god, wearing vermilion red robe with gold patterns, ' +
      'holding a large gold yuanbao ingot, vermilion red and gold color scheme',
    seed: 104,
  },
  {
    file: '5.png',
    name: '姚少司',
    role: '北路',
    desc: '紫袍·如意，紫金配色',
    prompt:
      'Yao Shaosi, serene elegant chibi god, wearing purple robe with gold trim, ' +
      'holding a golden ruyi scepter, purple and gold color scheme',
    seed: 105,
  },
];

async function generateOne(deity) {
  const fullPrompt = `${STYLE_PREFIX}. ${deity.prompt}.`;
  const params = new URLSearchParams({
    width: String(WIDTH),
    height: String(HEIGHT),
    model: MODEL,
    seed: String(deity.seed),
    nologo: 'true',
  });
  const url = `${POLLINATIONS_URL}${encodeURIComponent(fullPrompt)}?${params}`;

  const outPath = resolve(OUT_DIR, deity.file);
  console.log(`▶ 生成 ${deity.file} - ${deity.name}（${deity.role}，${deity.desc}）`);
  console.log(`  模型=${MODEL} 种子=${deity.seed}`);

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
  const indices = args.length
    ? args.map((n) => Number(n) - 1).filter((i) => i >= 0 && i < DEITIES.length)
    : DEITIES.map((_, i) => i);

  if (!indices.length) {
    console.error('没有匹配的神像序号');
    process.exit(1);
  }

  console.log(`将生成 ${indices.length} 张神像\n`);
  for (const i of indices) {
    try {
      await generateOne(DEITIES[i]);
    } catch (err) {
      console.error(`  ✗ 失败 ${DEITIES[i].file}: ${err.message}\n`);
    }
  }
  console.log('完成。');
}

main();
