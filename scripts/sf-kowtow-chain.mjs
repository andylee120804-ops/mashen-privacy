/**
 * 链式生成 16 帧磕头动画：每帧的输出作为下一帧的输入。
 * 小步递进 → 方向不漂移、人物一致、动作细化。
 *
 * 用法: node scripts/sf-kowtow-chain.mjs
 */
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const KEY = 'sk-izzswqdtlbmkkuxizbqrovkppxvbdomoujaezttrghipkpsx';
const SRC = resolve(__dirname, '../entry/src/main/resources/rawfile/props/worshipper_bow1.png');
const OUT_DIR = resolve(__dirname, 'kowtow-frames');
mkdirSync(OUT_DIR, { recursive: true });

// 16 帧磕头序列：下拜(0-8) + 触地停留(8-9) + 起身(9-15)
// 每帧只做小幅姿势递进，锁死"背对屏幕朝麻神"方向
const STEPS = [
  { out: 'c01_stand.png',       pose: 'The figure is kneeling upright, back completely vertical and straight, facing away from the viewer. No change from the original pose. Same back view.' },
  { out: 'c02_lean.png',        pose: 'The figure leans forward just slightly, about 10 degrees from vertical. Back still mostly upright, head tilts forward a tiny bit. Facing away from viewer.' },
  { out: 'c03_slightbow.png',   pose: 'The figure bows forward about 20 degrees. Upper body tilting slightly forward, head lowered a little. Facing away from viewer, back of head visible.' },
  { out: 'c04_quarterbow.png',  pose: 'The figure bows forward about 30 degrees. Upper body tilting more, hands starting to move forward. Facing away from viewer.' },
  { out: 'c05_halfbow.png',     pose: 'The figure bows forward about 45 degrees. Upper body at a diagonal, head lowered to about waist height. Hands pressed together extending forward. Facing away.' },
  { out: 'c06_bow60.png',       pose: 'The figure bows forward about 60 degrees. Upper body leaning well forward, back at a steep angle. Facing away from viewer, back of head still visible.' },
  { out: 'c07_deepbow.png',     pose: 'The figure bows forward about 70 degrees. Upper body nearly horizontal, head close to ground level. Arms extending forward toward the ground. Facing away.' },
  { out: 'c08_nearfloor.png',   pose: 'The figure bows forward about 80 degrees, head almost touching the ground. Upper body almost flat, arms stretched forward on the ground. Facing away from viewer.' },
  { out: 'c09_prostration.png', pose: 'Full prostration: forehead and hands flat on the ground, upper body completely horizontal and flat on the ground, only lower legs kneeling. Facing away from viewer, back of head visible on ground.' },
  // 触地停留一帧（同姿势）
  { out: 'c10_hold.png',        pose: 'Same full prostration pose, forehead on ground, arms forward, body flat. No change. Holding the prostration. Facing away from viewer.' },
  // 起身
  { out: 'c11_rise1.png',       pose: 'Starting to rise from prostration. Head lifts off the ground about 15 degrees, arms still extended forward. Upper body begins to lift slightly. Facing away.' },
  { out: 'c12_rise2.png',       pose: 'Rising more, upper body at about 45 degrees from ground. Head lifted to mid-height, arms pulling back. Facing away from viewer.' },
  { out: 'c13_rise3.png',       pose: 'Rising more, upper body at about 60 degrees from ground (30 degrees from vertical). Head raised, arms coming back to sides. Facing away.' },
  { out: 'c14_rise4.png',       pose: 'Almost standing upright, upper body at about 75 degrees (15 degrees forward lean). Head nearly level, hands at chest. Facing away from viewer.' },
  { out: 'c15_rise5.png',       pose: 'Nearly upright, just a very slight forward lean of about 5 degrees. Almost back to the starting kneeling position. Facing away from viewer.' },
  { out: 'c16_stand.png',       pose: 'Back to kneeling upright, back completely vertical and straight, hands pressed together at chest. Same as starting pose. Facing away from viewer.' },
];

const KEEP = 'CRITICAL: The figure must ALWAYS face AWAY from the viewer/camera, back of head always visible, back view. Never turn to face the camera. Keep the exact same red Hanfu robe with gold trim, same big-head-small-body chibi proportions, same cream background, same digital painting style, same character design.';

async function editOne(inputPath, step) {
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
        console.log(`  OK ${step.out} (${(buf.length/1024).toFixed(0)}KB, ${Date.now()-t0}ms)`);
        return outPath;
      }
      console.warn(`  retry ${step.out} attempt${attempt}: ${JSON.stringify(data).slice(0,150)}`);
    } catch (e) {
      console.warn(`  retry ${step.out} attempt${attempt}: ${e.message}`);
    }
    await new Promise(r => setTimeout(r, 3000));
  }
  // 链式：如果某帧失败，用上一帧作为下一帧的输入（降级但不中断链）
  console.error(`  FAIL ${step.out}, using prev frame as fallback`);
  return inputPath;
}

async function main() {
  let currentInput = SRC;
  console.log('链式生成 16 帧磕头序列...\n');
  for (const step of STEPS) {
    console.log(`-> ${step.out}`);
    currentInput = await editOne(currentInput, step);
  }
  console.log('\n全部完成! 接下来: python scripts/rembg-kowtow-chain.py');
}

main();
