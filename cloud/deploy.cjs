// cloud/deploy.cjs
// 打包 AGC 云函数 ZIP（每个函数：复制 shared/ + 安装依赖 + 打 zip）。
// 用法：node cloud/deploy.cjs [func-name...]
//   node cloud/deploy.cjs                      # 打包全部 3 个函数
//   node cloud/deploy.cjs update-prayer-count  # 只打包指定函数
// 产物：cloud/<func>/<func>.zip，上传到 AGC 控制台云函数。
// 注意：agc-credential.json 需手动放置到 cloud/ 根目录（API Client 凭证，见 README）。
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const CLOUD_DIR = __dirname;
const SHARED_DIR = path.join(CLOUD_DIR, 'shared');
const FUNCTIONS = ['update-prayer-count', 'get-leaderboard', 'wish-wall'];

// 优先用项目 node 的 zip 命令；Windows 无 zip 时回退到 PowerShell Compress-Archive（注意路径用正斜杠）
function makeZip(srcDir, zipPath) {
  // 临时方案：用 Node 内置无原生 zip，依赖系统 zip 或 PowerShell
  try {
    execSync(`zip -rj "${zipPath}" .`, { cwd: srcDir, stdio: 'ignore' });
    return true;
  } catch (e) {
    // 回退 PowerShell（需保持目录结构，不能用 -j）
    const psSrc = srcDir.replace(/\\/g, '/');
    const psZip = zipPath.replace(/\\/g, '/');
    try {
      execSync(`powershell -NoProfile -Command "Compress-Archive -Path '${psSrc}/*' -DestinationPath '${psZip}' -Force"`, { stdio: 'ignore' });
      return true;
    } catch (e2) {
      console.error(`  [zip] failed for ${srcDir}: ${e2.message}`);
      return false;
    }
  }
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

  // 4. 打 zip
  const zipPath = path.join(funcDir, `${name}.zip`);
  if (fs.existsSync(zipPath)) fs.unlinkSync(zipPath);
  if (makeZip(funcDir, zipPath)) {
    console.log(`  ✓ 产出 ${path.relative(CLOUD_DIR, zipPath)}`);
    return true;
  }
  return false;
}

const targets = process.argv.slice(2).length ? process.argv.slice(2) : FUNCTIONS;
let ok = 0;
for (const name of targets) {
  if (packageFunction(name)) ok++;
}
console.log(`\n完成 ${ok}/${targets.length}。将 cloud/<func>/<func>.zip 上传到 AGC 控制台。`);
