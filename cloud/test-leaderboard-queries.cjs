// 临时测试：验证排行榜三种查询在真实 Cloud DB 上是否可用
process.chdir(__dirname);
const { getDB, toPlainObject, withTimeout, getWeekStart, DB_TIMEOUT_MS } = require('./get-leaderboard/shared/db');

const TYPE = 'Leaderboard';

async function run(label, buildQuery) {
  try {
    const q = buildQuery();
    const r = await withTimeout(q.get(), DB_TIMEOUT_MS, label);
    console.log(`[OK] ${label}: ${r ? r.length : 0} rows`);
    if (r && r.length) {
      const first = toPlainObject(r[0]);
      console.log('     first:', JSON.stringify({
        userId: first.userId, todayCount: first.todayCount,
        weekCount: first.weekCount, totalCount: first.totalCount,
        updatedAt: first.updatedAt, weekStart: first.weekStart
      }));
    }
  } catch (e) {
    console.log(`[ERR] ${label}: ${e && e.message}`);
  }
}

(async () => {
  const db = getDB();
  const now = new Date().toISOString();
  const today = now.split('T')[0];
  const weekStart = getWeekStart(now);
  console.log('today=', today, 'weekStart=', weekStart);

  await run('total(仅 totalCount>0)', () =>
    db.collection(TYPE).query().greaterThan('totalCount', 0).orderByDesc('totalCount').limit(50));

  await run('daily(todayCount>0 + updatedAt>=today)', () =>
    db.collection(TYPE).query().greaterThan('todayCount', 0)
      .greaterThanOrEqualTo('updatedAt', today).orderByDesc('todayCount').limit(50));

  await run('weekly(weekCount>0 + updatedAt>=weekStart)', () =>
    db.collection(TYPE).query().greaterThan('weekCount', 0)
      .greaterThanOrEqualTo('updatedAt', weekStart).orderByDesc('weekCount').limit(50));

  await run('plain-daily(仅 todayCount>0)', () =>
    db.collection(TYPE).query().greaterThan('todayCount', 0).orderByDesc('todayCount').limit(50));

  process.exit(0);
})().catch(e => { console.error('fatal:', e && e.message); process.exit(1); });
