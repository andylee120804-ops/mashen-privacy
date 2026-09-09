// cloud/game-record-backup/smoke-delete.cjs
// delete action 冒烟测试：stub shared/response + shared/db，隔离测试 handler 的 delete 分支。
// 运行：node cloud/game-record-backup/smoke-delete.cjs（0 退出码 = 全过）
const path = require('path');
const dir = __dirname;

const store = [];
const results = [];

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
    collection: () => ({
      query: () => ({
        // equalTo 用 date 索引（schema 已有 date DESC）
        equalTo: (field, value) => ({
          limit: () => ({
            get: async () => store.filter((x) => x[field] === value).slice()
          })
        }),
        orderByDesc: () => ({
          limit: () => ({
            get: async () => store.slice()
          })
        })
      }),
      upsert: async (rows) => {
        for (const r of rows) {
          const idx = store.findIndex((x) => x.userId === r.userId && x.date === r.date);
          if (idx >= 0) store[idx] = r; else store.push(r);
        }
      },
      // 完整对象按引用删除（wish-wall 删除红线路径：查询返回的对象直接 delete）
      delete: async (rows) => {
        for (const r of rows) {
          const idx = store.indexOf(r);
          if (idx >= 0) store.splice(idx, 1);
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
const call = (body) => new Promise((res) => myHandler({ request: body }, { logger: console }, res));
const check = (name, cond, detail) => { results.push([cond ? 'PASS' : 'FAIL', name, detail || '']); if (!cond) process.exitCode = 1; };

(async () => {
  // 造数据：u1 两行、u2 同行（验证只删本人）
  store.push({ userId: 'u1', date: '2026-09-07', deityId: 1, kowtowCount: 3, games: '[]', note: '', updatedAt: 'x' });
  store.push({ userId: 'u1', date: '2026-09-08', deityId: 2, kowtowCount: 5, games: '[]', note: '', updatedAt: 'x' });
  store.push({ userId: 'u2', date: '2026-09-08', deityId: 2, kowtowCount: 5, games: '[]', note: '别人', updatedAt: 'x' });

  let r = await call({ action: 'delete', dates: ['2026-09-08'] });
  check('delete 无 __uid → 401', r.code === 401, JSON.stringify(r));

  r = await call({ action: 'delete', __uid: 'u1', dates: ['2026-09-08', '2026-09-08'] });
  check('delete 本人行成功 → deleted=1（同日去重）', r.code === 0 && r.data.deleted === 1, JSON.stringify(r));
  check('u2 同日行保留', store.some((x) => x.userId === 'u2' && x.date === '2026-09-08'), JSON.stringify(store));

  r = await call({ action: 'delete', __uid: 'u1', dates: [] });
  check('空 dates → 400', r.code === 400, JSON.stringify(r));

  r = await call({ action: 'delete', __uid: 'u1', dates: ['not-a-date'] });
  check('非法日期 → 400', r.code === 400, JSON.stringify(r));

  r = await call({ action: 'delete', __uid: 'u1', dates: ['2026-09-01'] });
  check('云端无该日期 → deleted=0（幂等成功）', r.code === 0 && r.data.deleted === 0, JSON.stringify(r));
  check('u1 其余行（09-07）保留', store.some((x) => x.userId === 'u1' && x.date === '2026-09-07'), JSON.stringify(store));

  const many = [];
  for (let i = 0; i < 51; i++) many.push('2026-09-01');
  r = await call({ action: 'delete', __uid: 'u1', dates: many });
  check('>50 日期 → 400', r.code === 400, JSON.stringify(r));

  r = await call({ action: 'unknown', __uid: 'u1' });
  check('未知 action 仍 → 400（原行为不破坏）', r.code === 400, JSON.stringify(r));

  console.log(results.map((x) => x.join(' | ')).join('\n'));
  console.log(results.every((x) => x[0] === 'PASS') ? '\nALL PASS ✅' : '\nSOME FAILED ❌');
})();
