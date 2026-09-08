/**
 * 用 Wan2.2-I2V 生成磕头动画视频
 * 输入：站立祈福者图片
 * 输出：磕头动作视频 -> scripts/kowtow-video.mp4
 */
import { readFileSync, writeFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const KEY = 'sk-izzswqdtlbmkkuxizbqrovkppxvbdomoujaezttrghipkpsx';
const IMG = resolve(__dirname, 'kowtow-frames-30/f01.png');
const OUT = resolve(__dirname, 'kowtow-video.mp4');

const PROMPT = 'A chibi character in red Hanfu robe with gold trim, big head small body, kneeling on the ground and performing a kowtow: slowly bowing forward from kneeling position until forehead touches the ground, then holding prostration. Viewed from behind (back view), the character faces away from the camera the entire time. Smooth continuous downward bowing motion. Digital painting style, cream background.';

async function submit() {
  const b64 = 'data:image/png;base64,' + readFileSync(IMG).toString('base64');
  const body = {
    model: 'Wan-AI/Wan2.2-I2V-A14B',
    prompt: PROMPT,
    image: b64,
    duration: 5,
    resolution: '720p',
    seed: 42,
  };
  const r = await fetch('https://api.siliconflow.cn/v1/video/submit', {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const d = await r.json();
  console.log('Submit:', JSON.stringify(d));
  return d.requestId;
}

async function status(rid) {
  const r = await fetch('https://api.siliconflow.cn/v1/video/status', {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ requestId: rid }),
  });
  return r.json();
}

async function main() {
  const rid = await submit();
  if (!rid) { console.error('No requestId'); return; }
  console.log(`Task ID: ${rid}\nPolling...`);

  for (let i = 0; i < 120; i++) {
    await new Promise(r => setTimeout(r, 5000));
    const s = await status(rid);
    console.log(`  [${i}] status=${s.status} pos=${s.position} reason=${s.reason||''}`);
    if (s.status === 'Succeed') {
      const vids = s.results?.videos || [];
      if (vids.length > 0 && vids[0].url) {
        console.log('Video URL:', vids[0].url);
        const buf = Buffer.from(await (await fetch(vids[0].url)).arrayBuffer());
        writeFileSync(OUT, buf);
        console.log(`Downloaded: ${OUT} (${(buf.length/1024/1024).toFixed(1)}MB)`);
      }
      return;
    }
    if (s.status === 'Failed') {
      console.error('Task failed:', JSON.stringify(s));
      return;
    }
  }
  console.log('Timeout');
}

main();
