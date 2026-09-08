// cloud/cleanup-cloud-db.cjs
// 开发工具：清空 Cloud DB 中 Wish / Leaderboard / GameBackup 三个集合的全部记录。
// 用途：提审前删除开发/测试期间产生的云端测试数据（心愿、祈福记录、牌局备份）。
//      还愿 tab 与排行榜 tab 对所有人展示全量数据，测试数据会被审核员看到
//      （审核反馈「首次进入应用含默认数据」即由此而来）。
// 用法：
//   node cloud/cleanup-cloud-db.cjs           # 先只统计，不删除
//   node cloud/cleanup-cloud-db.cjs --yes     # 统计后删除（需二次回车确认）
//   node cloud/cleanup-cloud-db.cjs --yes --force  # 跳过交互确认（CI / 已人工确认场景）
//
// 前提：cloud/agc-credential.json 为有效 API Client 凭证（关联 Cloud DB），
//      且 Cloud DB 存储区 'Mashen' 已在 AGC 控制台创建。
// 安全：只删 Wish / Leaderboard / GameBackup 三个表，全量删除不可恢复，请谨慎执行。
const { getDB, toPlainObject, withTimeout, DB_TIMEOUT_MS } = require('./shared/db');
const readline = require('readline');

const TYPES = ['Wish', 'Leaderboard', 'GameBackup'];
const BATCH = 50;

function countAll(db, type) {
  return withTimeout(
    db.collection(type).query().limit(1000).get(),
    DB_TIMEOUT_MS,
    'cleanup:' + type + ':count'
  );
}

function deleteBatch(db, type, items) {
  // 用查询返回的完整 CloudDBZoneGenericObject 删除（同 wish-wall delete 红线：
  // 仅含 id 的新对象无法定位记录）
  return withTimeout(
    db.collection(type).delete(items),
    DB_TIMEOUT_MS,
    'cleanup:' + type + ':delete'
  );
}

function confirm(question) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return new Promise((resolve) => {
    rl.question(question + ' (y/N) ', (ans) => {
      rl.close();
      resolve(ans.trim().toLowerCase() === 'y');
    });
  });
}

async function main() {
  const doDelete = process.argv.includes('--yes');
  const db = getDB();

  // 阶段1：统计
  let total = 0;
  const counts = {};
  for (const type of TYPES) {
    const items = await countAll(db, type);
    counts[type] = items ? items.length : 0;
    total += counts[type];
    console.log(`[cleanup] ${type}: ${counts[type]} 条`);
  }
  console.log(`[cleanup] 合计 ${total} 条（Wish=心愿, Leaderboard=祈福排行榜记录, GameBackup=牌局记录备份）`);

  if (total === 0) {
    console.log('[cleanup] 云端无测试数据，无需清理 ✅');
    return;
  }
  if (!doDelete) {
    console.log('[cleanup] 仅统计模式：加 --yes 执行删除');
    return;
  }
  if (!process.argv.includes('--force') &&
      !(await confirm(`确认删除以上全部 ${total} 条记录？此操作不可恢复。`))) {
    console.log('[cleanup] 已取消');
    return;
  }

  // 阶段2：分批删除（query 一次最多返回 BATCH 条，循环直到删完）
  for (const type of TYPES) {
    let removed = 0;
    for (;;) {
      const items = await withTimeout(
        db.collection(type).query().limit(BATCH).get(),
        DB_TIMEOUT_MS,
        'cleanup:' + type + ':query'
      );
      if (!items || items.length === 0) break;
      await deleteBatch(db, type, items);
      removed += items.length;
      console.log(`[cleanup] ${type}: 已删除 ${removed} 条...`);
    }
    console.log(`[cleanup] ${type}: 共删除 ${removed} 条 ✅`);
  }
  console.log('[cleanup] 完成：请到 AGC 控制台 Cloud DB 复查两表已清空');
}

main().catch((err) => {
  console.error('[cleanup] 失败:', err && err.message);
  if (err && err.response && err.response.data) {
    console.error('[cleanup] 服务端响应:', JSON.stringify(err.response.data));
  }
  process.exit(1);
});
