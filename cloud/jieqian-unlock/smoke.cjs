// cloud/jieqian-unlock/smoke.cjs
// 冒烟测试：stub shared/response + shared/db，内存 store 验证 handler 逻辑。
// 运行：node cloud/jieqian-unlock/smoke.cjs（0 退出码 = 全过）
// 覆盖：record 记账 / purchaseToken 幂等不双记 / 跨用户 token 重放不加权益 /
//       query 解锁状态 / orderId 缺省兜底 / purchaseData 非字符串落 '' /
//       DB 抛错 500 信封 / 401 / 400。
const path = require('path');
const fsSync = require('fs');
const dir = __dirname;

// fresh clone 下 shared/ 尚未由 deploy.cjs 复制：启动时自动补
for (const f of ['response.js', 'db.js']) {
  const src = path.join(dir, '..', 'shared', f);
  const dst = path.join(dir, 'shared', f);
  if (!fsSync.existsSync(dst) && fsSync.existsSync(src)) {
    fsSync.mkdirSync(path.dirname(dst), { recursive: true });
    fsSync.copyFileSync(src, dst);
  }
}

// ---- 内存 fake Cloud DB（按 objectType 分 store，主键 upsert，可注入故障）----
const stores = { SignUnlock: [] };
const PRIMARY_KEY = { SignUnlock: 'id' };
let failNextUpsert = false;   // 故障注入：下一次 upsert 抛错

const fakeResponse = {
  CODE: { OK: 0, PARAM_ERROR: 400, UNAUTHORIZED: 401, FORBIDDEN: 403, NOT_FOUND: 404, SERVER_ERROR: 500 },
  success: (data, message) => ({ code: 0, message: message || 'success', data: data || null }),
  fail: (code, message) => ({ code: code, message: message || 'error', data: null }),
  wrapHttp: (handler) => async (event, context, callback, logger) => {
    const log = logger || console;
    callback(await handler((event && event.request) || {}, event, context, log));
  }
};

const fakeDb = {
  getDB: () => ({
    collection: (type) => ({
      query: () => ({
        // equalTo 按字段过滤（真机依赖 schema 索引：purchaseToken/uid）
        equalTo: (field, value) => ({
          get: async () => stores[type].filter((x) => x[field] === value).slice()
        })
      }),
      upsert: async (rows) => {
        if (failNextUpsert) {
          failNextUpsert = false;
          throw new Error('injected: upsert failed');
        }
        for (const r of (Array.isArray(rows) ? rows : [rows])) {
          const pk = PRIMARY_KEY[type];
          const idx = stores[type].findIndex((x) => x[pk] === r[pk]);
          if (idx >= 0) stores[type][idx] = r; else stores[type].push(r);
        }
      }
    })
  }),
  toGenericObjects: (t, records) => records,
  toPlainObject: (o) => o,
  withTimeout: (p) => p,
  DB_TIMEOUT_MS: 10000
};

require.cache[require.resolve(path.join(dir, 'shared', 'response.js'))] = { id: 'r', filename: 'r', loaded: true, exports: fakeResponse };
require.cache[require.resolve(path.join(dir, 'shared', 'db.js'))] = { id: 'd', filename: 'd', loaded: true, exports: fakeDb };

const { myHandler } = require(path.join(dir, 'handler.js'));

// ---- 断言工具 ----
const results = [];
function check(name, cond, detail) {
  results.push({ name: name, pass: !!cond, detail: detail || '' });
}
function show() {
  let failed = 0;
  for (const r of results) {
    console.log((r.pass ? '  ✓ ' : '  ✗ ') + r.name + (r.pass ? '' : '  [' + r.detail + ']'));
    if (!r.pass) failed++;
  }
  console.log(`\n${results.length - failed}/${results.length} 通过`);
  process.exit(failed ? 1 : 0);
}

/** 调 handler 并返回信封 */
async function call(data) {
  let out = null;
  await myHandler({ request: data }, {}, (r) => { out = r; });
  return out;
}

(async () => {
  // 1. record 首次记账
  let r = await call({ action: 'record', __uid: 'u1', productId: 'jieqian_unlock', purchaseToken: 'tok_1', purchaseData: '{"sig":1}', orderId: 'order_1' });
  check('record 首次 code=0', r.code === 0, JSON.stringify(r));
  check('record 返回 unlocked=true', r.data && r.data.unlocked === true, JSON.stringify(r.data));
  check('SignUnlock 落 1 条', stores.SignUnlock.length === 1, JSON.stringify(stores.SignUnlock));
  check('id 用 purchaseOrderId', stores.SignUnlock[0].id === 'order_1', stores.SignUnlock[0].id);
  check('uid/productId/purchaseToken 落库', stores.SignUnlock[0].uid === 'u1'
    && stores.SignUnlock[0].productId === 'jieqian_unlock'
    && stores.SignUnlock[0].purchaseToken === 'tok_1', JSON.stringify(stores.SignUnlock[0]));
  check('purchaseData 存证保留', stores.SignUnlock[0].purchaseData === '{"sig":1}', String(stores.SignUnlock[0].purchaseData));

  // 2. 幂等：同 purchaseToken 重复上报不双记
  r = await call({ action: 'record', __uid: 'u1', productId: 'jieqian_unlock', purchaseToken: 'tok_1', purchaseData: '{"sig":1}', orderId: 'order_1' });
  check('幂等重复 code=0（静默成功）', r.code === 0, JSON.stringify(r));
  check('幂等不双记仍 1 条', stores.SignUnlock.length === 1, 'len=' + stores.SignUnlock.length);

  // 3. 跨用户 token 重放：u2 拿 u1 的 tok_1 重放，不加新记录
  r = await call({ action: 'record', __uid: 'u2', productId: 'jieqian_unlock', purchaseToken: 'tok_1' });
  check('跨用户重放 code=0（幂等命中）', r.code === 0, JSON.stringify(r));
  check('跨用户重放不落流水', stores.SignUnlock.length === 1, 'len=' + stores.SignUnlock.length);

  // 4. orderId 缺省 + purchaseData 非字符串
  r = await call({ action: 'record', __uid: 'u3', productId: 'jieqian_unlock', purchaseToken: 'tok_3', purchaseData: 12345 });
  const d3 = stores.SignUnlock.find((x) => x.purchaseToken === 'tok_3');
  check('orderId 缺省生成 u_ 前缀 id', d3 && /^u_/.test(d3.id), d3 && d3.id);
  check('purchaseData 非字符串落空串', d3 && d3.purchaseData === '', d3 && String(d3.purchaseData));

  // 5. query 解锁状态
  r = await call({ action: 'query', __uid: 'u1' });
  check('query u1 已解锁', r.code === 0 && r.data && r.data.unlocked === true, JSON.stringify(r.data));
  r = await call({ action: 'query', __uid: 'u_nobody' });
  check('query 新用户未解锁', r.code === 0 && r.data && r.data.unlocked === false, JSON.stringify(r.data));

  // 6. 故障注入：upsert 抛错 → 500 信封不崩
  failNextUpsert = true;
  r = await call({ action: 'record', __uid: 'u5', productId: 'jieqian_unlock', purchaseToken: 'tok_5', orderId: 'order_5' });
  check('DB 抛错返回 500 信封（不崩）', r.code === 500, JSON.stringify(r));

  // 7. 鉴权与参数校验
  r = await call({ action: 'query' });
  check('无 uid -> 401（带诊断）', r.code === 401, JSON.stringify(r));
  r = await call({ action: 'record', __uid: 'u1', productId: 'tip_6', purchaseToken: 'tok_x' });
  check('非法 productId -> 400', r.code === 400, JSON.stringify(r));
  r = await call({ action: 'record', __uid: 'u1', productId: 'jieqian_unlock', purchaseToken: 'x'.repeat(257) });
  check('purchaseToken 超长 -> 400', r.code === 400, JSON.stringify(r));
  r = await call({ action: 'record', __uid: 'u1', productId: 'jieqian_unlock' });
  check('缺 purchaseToken -> 400', r.code === 400, JSON.stringify(r));
  r = await call({ action: 'refund', __uid: 'u1' });
  check('未知 action -> 400', r.code === 400, JSON.stringify(r));

  show();
})().catch((e) => {
  console.error('smoke 崩溃:', e);
  process.exit(1);
});
