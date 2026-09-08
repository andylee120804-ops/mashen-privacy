/**
 * Wan2.2-T2V 生成磕头动画视频（纯文本，无输入图）
 * 后台轮询直到完成，下载视频
 */
import { writeFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const KEY = 'sk-izzswqdtlbmkkuxizbqrovkppxvbdomoujaezttrghipkpsx';
const OUT = resolve(__dirname, 'kowtow-video-v4.mp4');

const PROMPT = 'Q-version chibi cartoon Chinese style, digital painting, soft studio lighting, clean light cream background. Back view of a cute chibi Chinese worshipper devotee with simple black hair, big head small body, wearing traditional red Hanfu robe with gold trim, red and gold color scheme. Static camera, fixed shot from directly behind, back of the black head visible throughout, facing away toward the deities above. The character NEVER turns, NEVER rotates, NEVER shows face or side profile. Knees planted on the ground in a fixed spot. Only the upper body tilts forward and downward in a smooth slow kowtow until the forehead touches the ground, then holds the face-down prostration and stays down. The character does NOT rise back up, does NOT stand. No horizontal movement, no swaying, no side-to-side motion. Vibrant saturated colors, centered.';

async function submit() {
  const body = {
    model: 'Wan-AI/Wan2.2-T2V-A14B',
    prompt: PROMPT,
    duration: 5,
    resolution: '480p',
    seed: 200,
  };
  const r = await fetch('https://api.siliconflow.cn/v1/video/submit', {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const d = await r.json();
  console.log('Submit:', JSON.stringify(d), new Date().toISOString());
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
  console.log(`Task: ${rid}\nPolling (up to 10 min)...`);

  for (let i = 0; i < 60; i++) {
    await new Promise(r => setTimeout(r, 10000));
    const s = await status(rid);
    const ts = new Date().toISOString().slice(11, 19);
    console.log(`  [${ts}] ${i}: ${s.status} pos=${s.position} ${s.reason||''}`);
    if (s.status === 'Succeed') {
      const vids = s.results?.videos || [];
      if (vids.length > 0 && vids[0].url) {
        console.log('Video URL:', vids[0].url.slice(0, 100));
        const buf = Buffer.from(await (await fetch(vids[0].url)).arrayBuffer());
        writeFileSync(OUT, buf);
        console.log(`Downloaded: ${OUT} (${(buf.length/1024/1024).toFixed(1)}MB)`);
      }
      return;
    }
    if (s.status === 'Failed') {
      console.error('Failed:', JSON.stringify(s));
      return;
    }
  }
  console.log('Timeout (10 min)');
}

main();
