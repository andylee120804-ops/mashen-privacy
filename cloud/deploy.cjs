// cloud/deploy.cjs
// 打包 AGC 云函数 ZIP（每个函数：复制 shared/ + 安装依赖 + 打 zip）。
// 用法：node cloud/deploy.cjs [func-name...]
//   node cloud/deploy.cjs                      # 打包全部 3 个函数
//   node cloud/deploy.cjs update-prayer-count  # 只打包指定函数
// 产物：cloud/<func>/<func>.zip，上传到 AGC 控制台云函数。
// 注意：agc-credential.json 需手动放置到 cloud/ 根目录（API Client 凭证，见 README）。
// ⚠️ 必须用正斜杠路径打包（adm-zip），AGC 运行时是 Linux，
//    PowerShell Compress-Archive 产生的反斜杠路径会导致 Cannot find module handler.js。
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const AdmZip = require('adm-zip');

const CLOUD_DIR = __dirname;
const SHARED_DIR = path.join(CLOUD_DIR, 'shared');
const FUNCTIONS = ['update-prayer-count', 'get-leaderboard', 'wish-wall'];

/** 递归收集目录下所有文件，返回正斜杠相对路径 */
function collectFiles(rootDir) {
  const results = [];
  function walk(dir, relPrefix) {
    const entries = fs.readdirSync(dir, { withFileTypes: true });
    for (const entry of entries) {
      const absPath = path.join(dir, entry.name);
      const relPath = relPrefix ? relPrefix + '/' + entry.name : entry.name;
      if (entry.isDirectory()) {
        // 跳过 .bin 之外的隐藏目录无碍；node_modules 全部打包
        walk(absPath, relPath);
      } else {
        results.push({ absPath: absPath, relPath: relPath });
      }
    }
  }
  walk(rootDir, '');
  return results;
}

function packageFunction(name) {
  const funcDir = path.join(CLOUD_DIR, name);
  if (!fs.existsSync(funcDir)) {
    console.error(`[skip] ${name}: 目录不存在`);
    return false;
  }

  console.log(`\n=== 打包 ${name} ===`);

  // 1. 复制 shared/
  const destShared = path.join(funcDir, 'shared');
  if (fs.existsSync(destShared)) {
    fs.rmSync(destShared, { recursive: true, force: true });
  }
  fs.mkdirSync(destShared, { recursive: true });
  fs.copyFileSync(path.join(SHARED_DIR, 'response.js'), path.join(destShared, 'response.js'));
  fs.copyFileSync(path.join(SHARED_DIR, 'db.js'), path.join(destShared, 'db.js'));
  console.log('  ✓ 复制 shared/');

  // 2. 复制 agc-credential.json（如存在）
  const credSrc = path.join(CLOUD_DIR, 'agc-credential.json');
  if (fs.existsSync(credSrc)) {
    fs.copyFileSync(credSrc, path.join(funcDir, 'agc-credential.json'));
    console.log('  ✓ 复制 agc-credential.json');
  } else {
    console.warn('  ! 未找到 agc-credential.json（运行时将回退到环境变量凭证）');
  }

  // 3. 安装依赖
  try {
    execSync('npm install --production', { cwd: funcDir, stdio: 'inherit' });
    console.log('  ✓ npm install');
  } catch (e) {
    console.error(`  [fail] npm install 失败: ${e.message}`);
    return false;
  }

  // 4. 用 adm-zip 打包（正斜杠路径）
  const zipPath = path.join(funcDir, `${name}.zip`);
  if (fs.existsSync(zipPath)) fs.unlinkSync(zipPath);

  const zip = new AdmZip();
  const files = collectFiles(funcDir);
  let added = 0;
  for (const f of files) {
    // 排除产物 zip 自身
    if (f.relPath === `${name}.zip`) continue;
    // adm-zip addLocalFile 用系统路径，但 entry 名会带反斜杠，故用 addFile 显式指定正斜杠名
    const data = fs.readFileSync(f.absPath);
    zip.addFile(f.relPath, data);
    added++;
  }
  zip.writeZip(zipPath);
  console.log(`  ✓ 产出 ${path.relative(CLOUD_DIR, zipPath)}（${added} 个文件，正斜杠路径）`);
  return true;
}

const targets = process.argv.slice(2).length ? process.argv.slice(2) : FUNCTIONS;
let ok = 0;
for (const name of targets) {
  if (packageFunction(name)) ok++;
}
console.log(`\n完成 ${ok}/${targets.length}。将 cloud/<func>/<func>.zip 上传到 AGC 控制台。`);
