// cloud/donation-record/smoke.cjs
// 冒烟测试：stub shared/response + shared/db，内存 store 验证 handler 逻辑。
// 运行：node cloud/donation-record/smoke.cjs（0 退出码 = 全过）
// 覆盖：record 记账+白名单金额 / purchaseToken 幂等不双记 / 多档累计 /
//       从流水重算 merit（自愈：merit 写失败后重试补上）/ 浮点归一 /
//       跨用户 token 重放不增益 / query / 新用户空功德 / orderId 缺省兜底 /
//       purchaseData 非字符串落 '' / DB 抛错 500 信封 / 401 / 400。
const path = require('path');
const fsSync = require('fs');
const dir = __dirname;

// fresh clone 下 shared/ 尚未由 deploy.cjs 复制（gitignore 不追踪）：启动时自动补
for (const f of ['response.js', 'db.js']) {
  const src = path.join(dir, '..', 'shared', f);
  const dst = path.join(dir, 'shared', f);
  if (!fsSync.existsSync(dst) && fsSync.existsSync(src)) {
    fsSync.mkdirSync(path.dirname(dst), { recursive: true });
    fsSync.copyFileSync(src, dst);
  }
}

// ---- 内存 fake Cloud DB（按 objectType 分 store，主键 upsert，可注入故障）----
const stores = { Donation: [], UserMerit: [] };
const PRIMARY_KEY = { Donation: 'id', UserMerit: 'uid' };
// 故障注入：下一次 UserMerit upsert 抛错（测 merit 写失败后的自愈路径）
let failNextMeritUpsert = false;

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
        if (type === 'UserMerit' && failNextMeritUpsert) {
          failNextMeritUpsert = false;
          throw new Error('injected: merit upsert failed');
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
  // 1. record 记账：amount 传 999 应被白名单覆盖为 6
  let r = await call({ action: 'record', __uid: 'u1', productId: 'tip_6', purchaseToken: 'tok_1', purchaseData: '{"sig":1}', orderId: 'order_1', amount: 999 });
  check('record 首次记账 code=0', r.code === 0, JSON.stringify(r));
  check('record 金额以白名单为准（999 -> 6）', r.data && r.data.totalAmount === 6, JSON.stringify(r.data));
  check('record 计数 +1', r.data && r.data.totalCount === 1, JSON.stringify(r.data));
  check('Donation 落 1 条流水 amount=6', stores.Donation.length === 1 && stores.Donation[0].amount === 6, JSON.stringify(stores.Donation));
  check('UserMerit uid 为本人', stores.UserMerit.length === 1 && stores.UserMerit[0].uid === 'u1', JSON.stringify(stores.UserMerit));
  check('流水 id 用 purchaseOrderId', stores.Donation[0].id === 'order_1', stores.Donation[0].id);
  check('流水 status=done 且存证保留', stores.Donation[0].status === 'done' && stores.Donation[0].purchaseData === '{"sig":1}', JSON.stringify(stores.Donation[0]));

  // 2. 幂等：同 purchaseToken 重复上报不双记
  r = await call({ action: 'record', __uid: 'u1', productId: 'tip_6', purchaseToken: 'tok_1', purchaseData: '{"sig":1}', orderId: 'order_1', amount: 999 });
  check('幂等重复上报 code=0（静默成功）', r.code === 0, JSON.stringify(r));
  check('幂等不双记 totalAmount 仍 6', r.data && r.data.totalAmount === 6, JSON.stringify(r.data));
  check('幂等不双记 totalCount 仍 1', r.data && r.data.totalCount === 1, JSON.stringify(r.data));
  check('Donation 仍 1 条', stores.Donation.length === 1, 'len=' + stores.Donation.length);

  // 3. 跨用户 token 重放：u2 拿 u1 的 tok_1 重放，不给 u2 记功德
  r = await call({ action: 'record', __uid: 'u2', productId: 'tip_6', purchaseToken: 'tok_1' });
  check('跨用户重放 code=0（幂等命中）', r.code === 0, JSON.stringify(r));
  check('跨用户重放不记功德（u2 仍 0）', r.data && r.data.totalAmount === 0 && r.data.totalCount === 0, JSON.stringify(r.data));
  check('跨用户重放不落流水', stores.Donation.length === 1, 'len=' + stores.Donation.length);

  // 4. 第二笔不同档位（tip_88）累计
  r = await call({ action: 'record', __uid: 'u1', productId: 'tip_88', purchaseToken: 'tok_2', purchaseData: '{}', orderId: 'order_2' });
  check('第二笔累计 6+88=94', r.data && r.data.totalAmount === 94, JSON.stringify(r.data));
  check('第二笔计数 =2', r.data && r.data.totalCount === 2, JSON.stringify(r.data));

  // 5. orderId 缺省 + purchaseData 非字符串
  r = await call({ action: 'record', __uid: 'u1', productId: 'tip_06', purchaseToken: 'tok_3', purchaseData: 12345 });
  const d3 = stores.Donation.find((x) => x.purchaseToken === 'tok_3');
  check('orderId 缺省生成 d_ 前缀 id', d3 && /^d_/.test(d3.id), d3 && d3.id);
  check('purchaseData 非字符串落空串', d3 && d3.purchaseData === '', d3 && String(d3.purchaseData));

  // 6. 浮点归一：u3 三次 tip_06（0.6*3），不得出现 1.7999...
  await call({ action: 'record', __uid: 'u3', productId: 'tip_06', purchaseToken: 't3a', orderId: 'o3a' });
  await call({ action: 'record', __uid: 'u3', productId: 'tip_06', purchaseToken: 't3b', orderId: 'o3b' });
  r = await call({ action: 'record', __uid: 'u3', productId: 'tip_06', purchaseToken: 't3c', orderId: 'o3c' });
  check('浮点归一 0.6*3 = 1.8', r.data && r.data.totalAmount === 1.8, JSON.stringify(r.data));

  // 7. 自愈：merit 写失败 -> 500 -> 重试同 token 幂等命中 -> merit 补上
  failNextMeritUpsert = true;
  r = await call({ action: 'record', __uid: 'u4', productId: 'tip_6', purchaseToken: 'tok_heal', orderId: 'order_heal' });
  check('merit 写失败返回 500 信封（不崩）', r.code === 500, JSON.stringify(r));
  check('自愈场景：donation 已落库', stores.Donation.some((x) => x.id === 'order_heal'), 'missing');
  r = await call({ action: 'record', __uid: 'u4', productId: 'tip_6', purchaseToken: 'tok_heal', orderId: 'order_heal' });
  check('重试同 token 自愈 code=0', r.code === 0, JSON.stringify(r));
  check('自愈后 merit 从流水补上（6/1）', r.data && r.data.totalAmount === 6 && r.data.totalCount === 1, JSON.stringify(r.data));

  // 8. query 拉累计：u1 = 6+88+0.6 = 94.6，共 3 次
  r = await call({ action: 'query', __uid: 'u1' });
  check('query 返回累计 94.6', r.code === 0 && r.data && r.data.totalAmount === 94.6, JSON.stringify(r.data));
  check('query 返回计数 3', r.data && r.data.totalCount === 3, JSON.stringify(r.data));

  // 9. 新用户 query 返回 0/0 而非报错
  r = await call({ action: 'query', __uid: 'u_nobody' });
  check('新用户 query 空功德', r.code === 0 && r.data && r.data.totalAmount === 0 && r.data.totalCount === 0, JSON.stringify(r.data));

  // 10. 鉴权与参数校验
  r = await call({ action: 'query' });
  check('无 uid -> 401（带诊断）', r.code === 401, JSON.stringify(r));
  r = await call({ action: 'record', __uid: 'u1', productId: 'tip_free', purchaseToken: 'tok_x' });
  check('非法 productId -> 400', r.code === 400, JSON.stringify(r));
  r = await call({ action: 'record', __uid: 'u1', productId: 'tip_6', purchaseToken: 'x'.repeat(257) });
  check('purchaseToken 超长 -> 400', r.code === 400, JSON.stringify(r));
  r = await call({ action: 'record', __uid: 'u1', productId: 'tip_6' });
  check('缺 purchaseToken -> 400', r.code === 400, JSON.stringify(r));
  r = await call({ action: 'refund', __uid: 'u1' });
  check('未知 action -> 400', r.code === 400, JSON.stringify(r));

  show();
})().catch((e) => {
  console.error('smoke 崩溃:', e);
  process.exit(1);
});
