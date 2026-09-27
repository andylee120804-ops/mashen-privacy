# 供奉免费化 + 解签买断 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 供奉麻神付款整体移除（改为免费仪式），解签文 + 今日建议改为 IAP 非消耗型商品 `jieqian_unlock`（¥0.9）一次性买断解锁，配 SignUnlock 云端记录。

**Architecture:** 客户端删除 5 档消耗型打赏（TipModal/IapPaymentService 重写），新增单商品非消耗型买断接口 + QiuQian 锁定态 UI + 本地解锁标志（主权益源，`mashen_user_prefs`）；云端新建 SignUnlock 表与 `jieqian-unlock` 云函数（record 幂等 / query 状态）；启动/打开详情时 `restoreOwned()` 恢复权益（华为帐号 queryPurchases FINISHED）。

**Tech Stack:** HarmonyOS ArkTS（@kit.IAPKit、@kit.ArkData preferences、@kit.CloudFoundationKit）、AGC Cloud Function（Node.js 18 + @hw-agconnect/cloud-server）、AGC Cloud DB。

**设计文档:** `docs/superpowers/specs/2026-09-27-jieqian-unlock-design.md`

**构建环境（本机已踩坑，勿重复）：**
- ArkTS 编译检查（快速，无需 Java）：
  ```bash
  export DEVECO_SDK_HOME="C:/Program Files/Huawei/DevEco/sdk"
  node hvigorw.js --mode module -p product=default -p buildMode=debug --no-daemon assembleHap
  # 期望: :entry:default@CompileArkTS... Finished → BUILD SUCCESSFUL（约 30s）
  ```
- 若报 `ReferenceError: require is not defined in ES module scope`：mashen-app 根目录需要 `package.json` 含 `{"type":"commonjs"}`（临时文件，缺失则创建）。
- 完整构建见 Task 12。

---

### Task 1: 云函数 jieqian-unlock（handler + smoke + package.json + schema json）

**Files:**
- Create: `cloud/jieqian-unlock/handler.js`
- Create: `cloud/jieqian-unlock/smoke.cjs`
- Create: `cloud/jieqian-unlock/package.json`
- Create: `cloud/agc-clouddb-object-types-jieqian-unlock.json`

- [ ] **Step 1: 创建 `cloud/jieqian-unlock/handler.js`**

```javascript
// cloud/jieqian-unlock/handler.js
// 解签买断解锁记录（IAP 非消耗型商品 jieqian_unlock）：
//   action=record —— 上报解锁购买，幂等（同 purchaseToken 只记一条）
//   action=query  —— 查该 uid 是否已解锁 { unlocked: bool }
// 客户端 data: { action, __uid, productId?, purchaseToken?, purchaseData?, orderId? }
// 非消耗型无「消耗」动作，时序简单：客户端支付成功 → 本地置位立即解锁 →
//   云端记录（失败不阻塞解锁，重装/换机后由客户端 isOwned() 恢复 + 幂等补记）。
const { wrapHttp, success, fail, CODE } = require('./shared/response');
const { getDB, toGenericObjects, toPlainObject, withTimeout, DB_TIMEOUT_MS } = require('./shared/db');

var UNLOCK_TYPE = 'SignUnlock';

// 商品白名单：唯一非消耗型商品。必须与 AGC 控制台「应用内购买服务」配置一致。
var ALLOWED_PRODUCT_ID = 'jieqian_unlock';

// 客户端可控字段长度上限（伪造面缓解：防大对象滥用存储/拖垮查询）
var MAX_TOKEN_LEN = 256;    // purchaseToken
// purchaseData 上限实测受控制台字段容量限制（真实 Cloud DB 二分验证：
//   200 字符 PASS、255 字符 3007007 out of range）。华为 JWS（含 x5c 证书链）
//   2500+ 字符，控制台字段装不下完整 JWS —— 这里只截断存证，真正的校验键是
//   purchaseToken（已单独存储，v2 action=verify 走 token 调华为订单服务）。
var MAX_DATA_LEN = 200;     // purchaseData（截断存证，勿再调大）
var MAX_ORDER_LEN = 128;    // purchaseOrderId

async function handler(body, event, context, log) {
  var action = body.action;
  var uid = body.__uid;

  if (!uid) {
    // 诊断模式（规则要求）：requestKeys 空数组 = 客户端 data 内容为空/未传
    var reqObj = event && event.request && typeof event.request === 'object' ? event.request : null;
    var diag = {
      requestKeys: reqObj ? Object.keys(reqObj) : [],
      bodyKeys: body ? Object.keys(body) : []
    };
    log.error('[jieqian-unlock] UID NOT FOUND, diag: ' + JSON.stringify(diag));
    return fail(CODE.UNAUTHORIZED, 'uid required: ' + JSON.stringify(diag));
  }

  var db = getDB();

  try {
    switch (action) {
      case 'record': {
        // ---- 参数校验（类型 + 长度，客户端可控字段一律不信任）----
        var productId = body.productId;
        var purchaseToken = body.purchaseToken;
        var orderId = typeof body.orderId === 'string' ? body.orderId.slice(0, MAX_ORDER_LEN) : '';
        var purchaseData = typeof body.purchaseData === 'string' ? body.purchaseData.slice(0, MAX_DATA_LEN) : '';
        if (productId !== ALLOWED_PRODUCT_ID) {
          return fail(CODE.PARAM_ERROR, 'invalid productId: ' + productId);
        }
        if (typeof purchaseToken !== 'string' || !purchaseToken || purchaseToken.length > MAX_TOKEN_LEN) {
          return fail(CODE.PARAM_ERROR, 'invalid purchaseToken');
        }

        // ---- 幂等检查：同 purchaseToken 只记一条（重复上报/补记不双记）----
        // 依赖 SignUnlock 表 purchaseToken 索引（控制台手动建，见 Task 13）。
        var existing = await withTimeout(
          db.collection(UNLOCK_TYPE).query().equalTo('purchaseToken', purchaseToken).get(),
          DB_TIMEOUT_MS,
          'jieqian-unlock:idem-query'
        );
        if (existing && existing.length > 0) {
          log.info('[jieqian-unlock] duplicate purchaseToken, skip uid=' + uid);
          return success({ unlocked: true }, 'duplicate ignored');
        }

        // ---- 落解锁记录 ----
        var unlock = {
          id: orderId || ('u_' + Date.now() + '_' + Math.random().toString(36).substring(2, 8)),
          uid: uid,
          productId: productId,
          purchaseToken: purchaseToken,
          purchaseData: purchaseData,
          createdAt: new Date().toISOString()
        };
        await withTimeout(
          db.collection(UNLOCK_TYPE).upsert(toGenericObjects(UNLOCK_TYPE, unlock)),
          DB_TIMEOUT_MS,
          'jieqian-unlock:unlock-upsert'
        );
        log.info('[jieqian-unlock] recorded id=' + unlock.id + ' productId=' + productId + ' uid=' + uid);
        return success({ unlocked: true });
      }

      case 'query': {
        // 依赖 SignUnlock 表 uid 索引（控制台手动建，见 Task 13）
        var rows = await withTimeout(
          db.collection(UNLOCK_TYPE).query().equalTo('uid', uid).get(),
          DB_TIMEOUT_MS,
          'jieqian-unlock:query'
        );
        return success({ unlocked: !!(rows && rows.length > 0) });
      }

      default:
        return fail(CODE.PARAM_ERROR, 'unknown action: ' + action);
    }
  } catch (err) {
    log.error('[jieqian-unlock] DB error: ' + (err && err.message));
    return fail(CODE.SERVER_ERROR, 'db error: ' + (err && err.message));
  }
}

module.exports.myHandler = wrapHttp(handler);
```

- [ ] **Step 2: 创建 `cloud/jieqian-unlock/smoke.cjs`**（先写测试，TDD）

```javascript
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
```

- [ ] **Step 3: 创建 `cloud/jieqian-unlock/package.json`**（参照 donation-record）

```json
{
  "name": "jieqian-unlock",
  "version": "1.0.0",
  "description": "解签买断解锁记录：record（幂等记账）/ query（解锁状态）",
  "main": "handler.js",
  "dependencies": {
    "@hw-agconnect/cloud-server": "^1.0.5"
  }
}
```

- [ ] **Step 4: 创建 `cloud/agc-clouddb-object-types-jieqian-unlock.json`**（SignUnlock 表 schema，控制台导入用；索引在控制台手动建，见 Task 13）

```json
{
  "schemaVersion": 1,
  "objectTypes": [
    {
      "objectTypeName": "SignUnlock",
      "fields": [
        {
          "fieldName": "id",
          "fieldType": "String",
          "belongPrimaryKey": true,
          "notNull": true,
          "isNeedEncrypt": false,
          "isSensitive": false
        },
        {
          "fieldName": "uid",
          "fieldType": "String",
          "belongPrimaryKey": false,
          "notNull": true,
          "isNeedEncrypt": false,
          "isSensitive": false,
          "defaultValue": ""
        },
        {
          "fieldName": "productId",
          "fieldType": "String",
          "belongPrimaryKey": false,
          "notNull": true,
          "isNeedEncrypt": false,
          "isSensitive": false,
          "defaultValue": ""
        },
        {
          "fieldName": "purchaseToken",
          "fieldType": "String",
          "belongPrimaryKey": false,
          "notNull": true,
          "isNeedEncrypt": false,
          "isSensitive": false,
          "defaultValue": ""
        },
        {
          "fieldName": "purchaseData",
          "fieldType": "String",
          "belongPrimaryKey": false,
          "notNull": true,
          "isNeedEncrypt": false,
          "isSensitive": false,
          "defaultValue": ""
        },
        {
          "fieldName": "createdAt",
          "fieldType": "String",
          "belongPrimaryKey": false,
          "notNull": true,
          "isNeedEncrypt": false,
          "isSensitive": false,
          "defaultValue": ""
        }
      ],
      "indexes": []
    }
  ],
  "permissions": [
    {
      "objectTypeName": "SignUnlock",
      "permissions": [
        { "role": "World", "rights": [] },
        { "role": "Authenticated", "rights": [] },
        { "role": "Creator", "rights": ["Read", "Upsert"] },
        { "role": "Administrator", "rights": ["Read", "Upsert", "Delete"] }
      ]
    }
  ]
}
```

- [ ] **Step 5: 跑冒烟测试（TDD：先验证测试，handler 已实现 → 直接全绿）**

Run:
```bash
node cloud/jieqian-unlock/smoke.cjs
```
Expected: 全部 ✓，`20/20 通过`，退出码 0。

- [ ] **Step 6: Commit**

```bash
git add cloud/jieqian-unlock/ cloud/agc-clouddb-object-types-jieqian-unlock.json
git commit -m "feat(cloud): 解签买断云函数 jieqian-unlock（record 幂等/query 状态）+ SignUnlock 表 schema"
```

---

### Task 2: deploy.cjs 注册新函数并打包验证

**Files:**
- Modify: `cloud/deploy.cjs:17`

- [ ] **Step 1: 把 `jieqian-unlock` 加入 FUNCTIONS 列表**

将：
```js
const FUNCTIONS = ['update-prayer-count', 'get-leaderboard', 'wish-wall', 'game-record-backup', 'donation-record'];
```
改为：
```js
const FUNCTIONS = ['update-prayer-count', 'get-leaderboard', 'wish-wall', 'game-record-backup', 'donation-record', 'jieqian-unlock'];
```

- [ ] **Step 2: 打包验证**

Run:
```bash
node cloud/deploy.cjs jieqian-unlock
```
Expected: `✓ 产出 cloud/jieqian-unlock/jieqian-unlock.zip（…条 hostOS→Unix）`，且 zip 含 `handler.js`、`shared/response.js`、`shared/db.js`、`node_modules/`、`agc-credential.json`。

- [ ] **Step 3: 再跑一次冒烟（打包复制 shared 后不得破坏逻辑）**

Run: `node cloud/jieqian-unlock/smoke.cjs` → Expected: `20/20 通过`

- [ ] **Step 4: Commit**

```bash
git add cloud/deploy.cjs
git commit -m "chore(cloud): deploy.cjs 注册 jieqian-unlock 云函数"
```

---

### Task 3: EnrichTypes.ets 类型替换（DonationParams/MeritInfo → SignUnlockParams）

**Files:**
- Modify: `entry/src/main/ets/model/EnrichTypes.ets:57-70`

- [ ] **Step 1: 删除打赏类型、新增解锁类型**

将：
```ts
/** 打赏上报参数（IAP 支付成功后传给 CloudService.recordDonation） */
export interface DonationParams {
  productId: string       // AGC 商品 ID（tip_06 等）
  amount: number           // 本地记录的金额（云端以商品白名单为准）
  purchaseToken: string   // 幂等去重键
  purchaseData: string     // 华为签名原文存证
  orderId: string          // purchaseOrderId，Donation 主键
}

/** 累计功德 */
export interface MeritInfo {
  totalAmount: number
  totalCount: number
}
```
改为：
```ts
/** 解签买断上报参数（IAP 支付成功后传给 CloudService.recordSignUnlock） */
export interface SignUnlockParams {
  productId: string       // AGC 商品 ID（jieqian_unlock，与服务端白名单一致）
  purchaseToken: string   // 幂等去重键
  purchaseData: string     // 华为签名原文存证
  orderId: string          // purchaseOrderId，SignUnlock 主键
}
```

- [ ] **Step 2: 编译检查**

Run:
```bash
export DEVECO_SDK_HOME="C:/Program Files/Huawei/DevEco/sdk"
node hvigorw.js --mode module -p product=default -p buildMode=debug --no-daemon assembleHap
```
Expected: `:entry:default@CompileArkTS... Finished` → BUILD SUCCESSFUL。
（若报 `require is not defined`：在 mashen-app 根目录创建临时 `package.json` 内容 `{"type":"commonjs"}` 后重跑。）

- [ ] **Step 3: Commit**（先只提交本文件；此时 CloudService 仍引用旧类型会编译失败——若 Step 2 编译失败属预期，继续 Task 4-6 完成后统一编译）

```bash
git add entry/src/main/ets/model/EnrichTypes.ets
git commit -m "refactor(types): DonationParams/MeritInfo 替换为 SignUnlockParams（供奉打赏移除）"
```

---

### Task 4: IPaymentService.ets 重写为解锁接口

**Files:**
- Rewrite: `entry/src/main/ets/service/IPaymentService.ets`

- [ ] **Step 1: 整体重写文件**

```ts
// entry/src/main/ets/service/IPaymentService.ets
// 解签买断支付服务接口（华为 IAP 非消耗型商品）。
// 供奉打赏（5 档消耗型 tip_06~88）已随审核整改移除（2026-09-27 封建迷信拒审），
// 改为解签一次性买断：jieqian_unlock（¥0.9）非消耗型，买断一次永久解锁全部解签。
// 非消耗型无「消耗」动作：支付成功即拥有；权益靠本地标志（主）+ restoreOwned 恢复。

/** 解签买断商品（与 AGC 控制台非消耗型商品 jieqian_unlock 唯一对应） */
export interface UnlockProduct {
  productId: string      // AGC 商品 ID（jieqian_unlock，与服务端 jieqian-unlock 白名单一致）
  amount: number          // 本地展示金额（¥0.9；AGC 无 0.9 档则落 1，标签同步改）
  label: string           // 文化标签
}

/** 购买结果。success 时含云端记录所需全部字段 */
export interface UnlockPurchaseResult {
  success: boolean
  canceled: boolean       // 用户取消（1001860000），静默返回不弹错
  productId: string       // 白名单商品 ID（与云端 jieqian-unlock 白名单一致）
  purchaseToken: string   // 幂等去重键
  orderId: string          // purchaseOrderId，SignUnlock 主键
  purchaseData: string    // 华为签名原文（云端存证，未来 verify 用）
}

/** 支付前置错误（UI 按 kind 引导处理） */
export enum PaymentErrorKind {
  NEED_LOGIN = 'need_login',   // 1001860050 未登录华为帐号
  REGION = 'region',           // 1001860054 地区不支持
  PRODUCT = 'product',          // 1001860007 商品未发布
  ALREADY_OWNED = 'already_owned'  // 1001860051 已拥有（非消耗型重复购买被拒，应走恢复）
}

export class PaymentError extends Error {
  readonly kind: PaymentErrorKind
  readonly rawCode: number
  constructor(kind: PaymentErrorKind, message: string, rawCode: number) {
    super(message)
    this.kind = kind
    this.rawCode = rawCode
  }
}

/** 解签买断商品静态配置（三方一致：AGC 控制台 / 云函数 jieqian-unlock 白名单 / 本表） */
export const UNLOCK_PRODUCT: UnlockProduct = {
  productId: 'jieqian_unlock',
  amount: 0.9,
  label: '永久解锁解签'
}

export interface IUnlockService {
  /** 解签买断商品信息 */
  getProduct(): UnlockProduct

  /**
   * 发起买断（拉起华为收银台）。
   * 用户取消 → { success: false, canceled: true }；
   * 前置错误（未登录/地区/商品未发布/已拥有）→ 抛 PaymentError（UI 引导后处理）；
   * 其他错误 → 抛 Error（UI toast「购买失败请重试」）。
   */
  purchase(): Promise<UnlockPurchaseResult>

  /**
   * 权益恢复：queryPurchases(NONCONSUMABLE, CURRENT_ENTITLEMENT) 查已购订单。
   * 重装/换机/离线恢复走此路径（华为帐号权益）。返回已购订单
   * （含 purchaseToken 供云端幂等补记）；未购/查询失败返回 null。
   */
  restoreOwned(): Promise<UnlockPurchaseResult | null>

  /** 是否已购（restoreOwned 的布尔形态，UI 快速判断用） */
  isOwned(): Promise<boolean>
}
```

- [ ] **Step 2: 编译检查**（命令同 Task 3 Step 2；此时 IapPaymentService/EntryAbility 仍引用旧符号，编译失败属预期，Task 5-6 完成后统一验证）

Expected: 错误仅剩「IapPaymentService / EntryAbility / TipModal 引用旧接口」类编译错误（`TIP_PRODUCTS`、`ITipPaymentService`、`TipPurchaseResult` 不存在）。

- [ ] **Step 3: Commit**

```bash
git add entry/src/main/ets/service/IPaymentService.ets
git commit -m "refactor(iap): IPaymentService 从 5 档打赏改为解签买断接口（IUnlockService）"
```

---

### Task 5: IapPaymentService.ets 重写为非消耗型买断

**Files:**
- Rewrite: `entry/src/main/ets/service/IapPaymentService.ets`

- [ ] **Step 1: 整体重写文件**

```ts
// entry/src/main/ets/service/IapPaymentService.ets
// 解签买断支付实现（华为 IAP Kit，@kit.IAPKit，非消耗型商品 jieqian_unlock）。
// API 事实（本机 SDK @hms.core.iap.d.ts 实测核对）：
//  - createPurchase(context, { productId, productType: NONCONSUMABLE, developerPayload })
//    → CreatePurchaseResult.purchaseData（JWS，payload 才含 productId/purchaseToken/purchaseOrderId）
//  - queryPurchases(context, { productType: NONCONSUMABLE, queryType: CURRENT_ENTITLEMENT })
//    → 已购商品列表（权益恢复；非消耗型无需 finishPurchase）
//  - queryEnvironmentStatus(context)：未登录抛 1001860050，地区不支持 1001860054
// 时序：支付成功 → 本地置解锁标志（立即生效）→ 云端 record（异步幂等）；
//  重装/换机 → restoreOwned() 恢复本地标志 + 云端幂等补记。
import { iap } from '@kit.IAPKit'
import { common } from '@kit.AbilityKit'
import { util } from '@kit.ArkTS'
import { BusinessError } from '@kit.BasicServicesKit'
import { IUnlockService, UnlockProduct, UnlockPurchaseResult, UNLOCK_PRODUCT, PaymentError, PaymentErrorKind } from './IPaymentService'

// IAP 错误码（@hms.core.iap）
const ERR_USER_CANCEL = 1001860000
const ERR_ALREADY_OWNED = 1001860051  // 非消耗型重复购买（已拥有）被拒
const ERR_NOT_LOGIN = 1001860050
const ERR_REGION_UNSUPPORTED = 1001860054
const ERR_PRODUCT_UNAVAILABLE = 1001860007

/** 华为签名 purchaseData 解析后需要的关键字段 */
interface HuaweiPurchaseData {
  productId: string
  purchaseToken: string
  purchaseOrderId: string
}

/** JWS 载荷（PurchaseOrderPayload，华为 IAP 文档）字段 */
interface PurchaseOrderPayload {
  productId: string
  purchaseToken: string
  purchaseOrderId: string
  productType: number
}

/** JWS 三段紧凑格式（header.payload.signature）：base64url 解码 payload 段，返回 JSON 字符串 */
function decodeJwsPayload(jws: string): string {
  const parts: string[] = jws.split('.')
  if (parts.length < 2) {
    throw new Error('jws format error: parts=' + parts.length)
  }
  const base64 = new util.Base64Helper()
  const payloadBytes: Uint8Array = base64.decodeSync(parts[1], util.Type.BASIC_URL_SAFE)
  return util.TextDecoder.create('utf-8').decodeToString(payloadBytes)
}

/**
 * 解析华为 purchaseData。官方结构（华为 IAP 文档/codelab 实测）：
 *   purchaseData = { "jwsPurchaseOrder": "<header.payload.signature>" }
 * 链路：JSON.parse → 取 jwsPurchaseOrder → base64url 解码 JWS payload → JSON.parse 得
 * PurchaseOrderPayload（含 productId / purchaseToken / purchaseOrderId）。
 * ⚠️ productId 在 JWS 载荷里不在顶层；解析失败返回 null——调用方不得对空 token 记账。
 */
function parsePurchaseData(raw: string): HuaweiPurchaseData | null {
  try {
    const wrapper: Object = JSON.parse(raw) as Object
    const w = wrapper as Record<string, Object>
    let jws: Object = w['jwsPurchaseOrder']
    // 兜底：个别版本可能把 JWS 再包一层字符串，救一层
    if (typeof jws !== 'string' && typeof wrapper === 'string') {
      const inner: Object = JSON.parse(wrapper as string) as Object
      jws = (inner as Record<string, Object>)['jwsPurchaseOrder']
    }
    if (typeof jws !== 'string' || (jws as string) === '') {
      console.error('[IapUnlock] purchaseData 无 jwsPurchaseOrder 字段 | keys='
        + Object.keys(wrapper).join(',') + ' | raw(0-300)=' + raw.substring(0, 300))
      return null
    }
    const payloadStr: string = decodeJwsPayload(jws as string)
    const payload: PurchaseOrderPayload = JSON.parse(payloadStr) as PurchaseOrderPayload
    if (!payload.productId || !payload.purchaseToken || !payload.purchaseOrderId) {
      console.error('[IapUnlock] PurchaseOrderPayload 字段缺失 productId=' + (payload.productId || '')
        + ' token=' + (payload.purchaseToken ? 'set' : 'empty')
        + ' order=' + (payload.purchaseOrderId || '')
        + ' | payload(0-300)=' + payloadStr.substring(0, 300))
      return null
    }
    return {
      productId: payload.productId,
      purchaseToken: payload.purchaseToken,
      purchaseOrderId: payload.purchaseOrderId
    }
  } catch (err) {
    console.error('[IapUnlock] purchaseData 解析失败: ' + JSON.stringify(err)
      + ' | raw(0-300)=' + raw.substring(0, 300))
    return null
  }
}

/** 设备匿名 ID（EntryAbility 启动时写入 AppStorage），随订单进 developerPayload——
 *  华为会将其签名进 purchaseData，是未来 action=verify 服务端校验的 uid 锚点 */
function getDeviceUid(): string {
  try {
    const uid: string | undefined = AppStorage.get<string>('deviceUserId')
    return uid || ''
  } catch {
    return ''
  }
}

export class IapPaymentService implements IUnlockService {
  private readonly context: common.UIAbilityContext

  constructor(context: common.UIAbilityContext) {
    this.context = context
  }

  getProduct(): UnlockProduct {
    return UNLOCK_PRODUCT
  }

  async purchase(): Promise<UnlockPurchaseResult> {
    // ① 环境检查：华为帐号登录 / 地区支持（不依赖 AGC Auth，系统级帐号）
    try {
      await iap.queryEnvironmentStatus(this.context)
    } catch (err) {
      const e = err as BusinessError
      if (e.code === ERR_NOT_LOGIN) {
        throw new PaymentError(PaymentErrorKind.NEED_LOGIN, '解锁需登录华为帐号', e.code)
      }
      if (e.code === ERR_REGION_UNSUPPORTED) {
        throw new PaymentError(PaymentErrorKind.REGION, '当前地区暂不支持', e.code)
      }
      throw new Error('支付环境检查失败：' + e.message)
    }

    // ② 拉起收银台（非消耗型：买断即永久拥有，无消耗动作）
    let raw: string
    let data: HuaweiPurchaseData | null
    try {
      const result = await iap.createPurchase(this.context, {
        productId: UNLOCK_PRODUCT.productId,
        productType: iap.ProductType.NONCONSUMABLE,
        developerPayload: getDeviceUid()
      })
      raw = result.purchaseData
      data = parsePurchaseData(raw)
      if (data === null) {
        // 解析不出关键字段：无法云端记账。本地解锁不受影响（isOwned 兜底恢复）
        console.error('[IapUnlock] 购买成功但 purchaseData 解析失败，走 restoreOwned 兜底')
      }
    } catch (err) {
      const e = err as BusinessError
      if (e.code === ERR_USER_CANCEL) {
        return { success: false, canceled: true, productId: UNLOCK_PRODUCT.productId, purchaseToken: '', orderId: '', purchaseData: '' }
      }
      if (e.code === ERR_PRODUCT_UNAVAILABLE) {
        throw new PaymentError(PaymentErrorKind.PRODUCT, '解锁服务准备中', e.code)
      }
      if (e.code === ERR_ALREADY_OWNED) {
        // 非消耗型重复购买：已拥有，UI 引导走 restoreOwned 恢复
        throw new PaymentError(PaymentErrorKind.ALREADY_OWNED, '已拥有解签权益', e.code)
      }
      throw new Error('购买失败：' + e.message)
    }

    // productId 兜底用配置值：JWS 载荷解析不出（异常版本）时，配置常量即权威值
    const resolvedProductId: string = (data !== null && data.productId !== '') ? data.productId : UNLOCK_PRODUCT.productId
    return {
      success: true,
      canceled: false,
      productId: resolvedProductId,
      purchaseToken: (data !== null) ? data.purchaseToken : '',
      orderId: (data !== null) ? data.purchaseOrderId : '',
      purchaseData: raw
    }
  }

  async restoreOwned(): Promise<UnlockPurchaseResult | null> {
    // 权益恢复：queryPurchases CURRENT_ENTITLEMENT 拉已购非消耗型商品（华为帐号权益，
    // 重装/换机可恢复）。未登录华为帐号会抛错——记日志返回 null（下次再试）。
    let list: string[]
    try {
      const result = await iap.queryPurchases(this.context, {
        productType: iap.ProductType.NONCONSUMABLE,
        queryType: iap.PurchaseQueryType.CURRENT_ENTITLEMENT  // 每商品最新已拥有订单（SDK 实测无 FINISHED，语义即权益恢复）
      })
      list = result.purchaseDataList || []
    } catch (err) {
      console.warn('[IapUnlock] queryPurchases 跳过（未登录/网络）:', JSON.stringify(err))
      return null
    }
    for (const raw of list) {
      const data = parsePurchaseData(raw)
      if (data === null) {
        // 不可解析：跳过该条，继续看下一条（不因单条异常放弃整个恢复）
        console.error('[IapUnlock] 恢复遇不可解析订单，跳过: raw(0-300)=' + raw.substring(0, 300))
        continue
      }
      return {
        success: true,
        canceled: false,
        productId: data.productId,
        purchaseToken: data.purchaseToken,
        orderId: data.purchaseOrderId,
        purchaseData: raw
      }
    }
    return null
  }

  async isOwned(): Promise<boolean> {
    const owned: UnlockPurchaseResult | null = await this.restoreOwned()
    return owned !== null
  }
}
```

- [ ] **Step 2: 编译检查**（命令同 Task 3 Step 2；此时 EntryAbility/TipModal 仍引用旧 API，剩余错误应只在它们处）

- [ ] **Step 3: Commit**

```bash
git add entry/src/main/ets/service/IapPaymentService.ets
git commit -m "refactor(iap): IapPaymentService 改非消耗型买断（purchase/restoreOwned/isOwned），删打赏与补单"
```

---

### Task 6: CloudService.ets 删打赏、加解锁

**Files:**
- Modify: `entry/src/main/ets/service/CloudService.ets:9,284-342`

- [ ] **Step 1: 更新 import**

将：
```ts
import { LeaderboardEntry, LeaderboardType, Wish, GameRecord, DonationParams, MeritInfo } from '../model/EnrichTypes'
```
改为：
```ts
import { LeaderboardEntry, LeaderboardType, Wish, GameRecord, SignUnlockParams } from '../model/EnrichTypes'
```

- [ ] **Step 2: 删除 recordDonation + getMyMerit 两个方法**（约第 284-342 行，含文件头部注释中的打赏相关说明可一并删除；从 `/**\n   * 上报打赏流水…` 起至 `getMyMerit` 方法结束的整块删除）

- [ ] **Step 3: 新增解锁上报/查询两个方法**（加在文件末尾 `}` 之前）

```ts
  /** 上报解签买断（IAP 支付成功后调用）。云端按 purchaseToken 幂等去重。
   *  成功返回 true；失败返回 false——不阻塞解锁（本地标志已生效），
   *  重装/换机后由 restoreOwned 恢复 + 幂等补记。 */
  static async recordSignUnlock(params: SignUnlockParams): Promise<boolean> {
    try {
      const result = await cloudFunction.call({
        name: 'jieqian-unlock',
        data: {
          action: 'record',
          productId: params.productId,
          purchaseToken: params.purchaseToken,
          purchaseData: params.purchaseData,
          orderId: params.orderId,
          __uid: getUserId()
        }
      })
      const env: CloudEnvelope | null = parseEnvelope(result.result)
      return env !== null && env.code === 0
    } catch (err) {
      console.error('[CloudService] recordSignUnlock failed:', JSON.stringify(err))
      return false
    }
  }

  /** 查询该设备是否已解锁解签（云端兜底，与 restoreOwned 双保险）。失败返回 false */
  static async getSignUnlockStatus(): Promise<boolean> {
    try {
      const result = await cloudFunction.call({
        name: 'jieqian-unlock',
        data: {
          action: 'query',
          __uid: getUserId()
        }
      })
      const env: CloudEnvelope | null = parseEnvelope(result.result)
      if (env !== null && env.code === 0 && env.data !== null) {
        const d: UnlockStatusData = env.data as UnlockStatusData
        return d.unlocked === true
      }
      return false
    } catch (err) {
      console.error('[CloudService] getSignUnlockStatus failed:', JSON.stringify(err))
      return false
    }
  }
```

并在文件头部 `interface IncenseCountData` 附近新增：
```ts
/** 解签解锁状态返回体 */
interface UnlockStatusData {
  unlocked: boolean
}
```

- [ ] **Step 4: 编译检查**（命令同 Task 3 Step 2；剩余错误应只在 EntryAbility/TipModal/QiuQian 引用旧接口处——EntryAbility 的 completePendingOrders 在 Task 10 改，TipModal 在 Task 8 重写）

- [ ] **Step 5: Commit**

```bash
git add entry/src/main/ets/service/CloudService.ets
git commit -m "feat(cloud): CloudService 删 recordDonation/getMyMerit，加 recordSignUnlock/getSignUnlockStatus"
```

---

### Task 7: QiuQianViewModel.ets 加解锁状态

**Files:**
- Modify: `entry/src/main/ets/viewmodels/QiuQianViewModel.ets:4,27-46`

- [ ] **Step 1: 加解锁标志常量与字段**

在 `export const MAX_DAILY_QIU = 3` 附近新增：
```ts
export const KEY_UNLOCKED = 'jieqianUnlocked'   // 解签买断解锁标志（存 mashen_user_prefs，与 deviceUserId 同文件；EntryAbility 恢复路径复用）
```

类字段新增（在 `private dataPrefs: preferences.Preferences | null = null` 之后）：
```ts
  private unlockPrefs: preferences.Preferences | null = null
  unlocked: boolean = false   // 解签买断解锁状态（内存主权益源）
```

- [ ] **Step 2: initialize 加载解锁标志**

在 `initialize` 方法末尾（`this.daily = { date: '', count: 0 }` 的 catch 块之后）追加：
```ts
    try {
      this.unlockPrefs = await preferences.getPreferences(context, 'mashen_user_prefs')
      const raw = await this.unlockPrefs.get(KEY_UNLOCKED, false)
      // 启动恢复（EntryAbility setUnlocked）可能先于本初始化置位内存值：
      // 已置位则不覆盖（避免读旧快照把解锁回退）
      if (!this.unlocked) {
        this.unlocked = raw === true
      }
    } catch (err) {
      console.error('[QiuQianVM] load unlocked failed:', JSON.stringify(err))
    }
```

- [ ] **Step 3: 新增 isUnlocked / setUnlocked 方法**（加在 `clearRecords` 之后）

```ts
  isUnlocked(): boolean {
    return this.unlocked
  }

  /** 置解锁状态并落盘（支付成功 / restoreOwned 恢复时调用）。
   *  内存值立即生效；持久化失败仅记日志（重装后由 EntryAbility 恢复路径重写）。 */
  async setUnlocked(v: boolean): Promise<void> {
    this.unlocked = v
    if (this.unlockPrefs === null) {
      return
    }
    try {
      await this.unlockPrefs.put(KEY_UNLOCKED, v)
      await this.unlockPrefs.flush()
    } catch (err) {
      console.error('[QiuQianVM] save unlocked failed:', JSON.stringify(err))
    }
  }
```

- [ ] **Step 4: 编译检查**（命令同 Task 3 Step 2）

- [ ] **Step 5: Commit**

```bash
git add entry/src/main/ets/viewmodels/QiuQianViewModel.ets
git commit -m "feat(qiuqian): VM 加解签买断解锁状态（本地主权益源，mashen_user_prefs 持久化）"
```

---

### Task 8: TipModal.ets 重做为免费供奉仪式

**Files:**
- Rewrite: `entry/src/main/ets/components/TipModal.ets`

- [ ] **Step 1: 整体重写文件**（移除全部收款元素：金额卡/确认供奉/功德显示/支付服务/成功滚动；保留仪式粒子）

```ts
// entry/src/main/ets/components/TipModal.ets
// 供奉台（免费仪式弹窗）。
// 审核整改（2026-09-27）：供奉麻神应用内付款被判封建迷信拒审，移除全部收款元素
// （金额卡/支付/云端功德），保留仪式感：香火粒子 + 祝福语，纯免费。
// 入口不变：祈福结算页「🧧 供奉麻神」、我的页「🧧 诚心供奉」。
// WCAG（规则 common/wcag-contrast.md，弹窗底 #1a1a0a）：金实色 #f9ca24 仅用于
// 大字/实底钮（≥3:1 或钮上深字），正文米色 alpha≥0.5、金色 alpha≥0.6，深字实色 #1a1a0a。

/** 香火粒子静态参数（构造时随机生成，避免动画期间重算） */
interface FireParticle {
  id: number
  angle: number      // 发射角度（度）
  dist: number       // 飞行距离（vp）
  delay: number      // 起飞延迟（ms）
  size: number       // 字号
}

@CustomDialog
export struct TipModal {
  controller: CustomDialogController
  @State incenseAnim: boolean = false   // 点香粒子触发
  private particles: FireParticle[] = []

  aboutToAppear(): void {
    // 香火粒子：10 颗随机角度/距离
    for (let i = 0; i < 10; i++) {
      this.particles.push({
        id: i,
        angle: Math.random() * 360,
        dist: 60 + Math.random() * 90,
        delay: i * 45,
        size: 12 + Math.random() * 10
      })
    }
  }

  /** 点香供奉：一次粒子 + 祝福语，无任何支付 */
  private offerIncense(): void {
    this.incenseAnim = false
    setTimeout(() => {
      this.incenseAnim = true
    }, 50)
    this.getUIContext().getPromptAction().showToast({ message: '心意已到 · 福报自来 🙏' })
  }

  build() {
    Column() {
      // 顶部红色装饰条
      Row()
        .width('100%')
        .height(4)
        .backgroundColor('#c0392b')

      Text('✦  供奉麻神  ✦')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#f9ca24')
        .letterSpacing(2)
        .margin({ top: 20, bottom: 6 })

      Text('「心诚则灵 · 福报自来」')
        .fontSize(12)
        .fontColor('rgba(253, 246, 227, 0.5)')
        .fontStyle(FontStyle.Italic)
        .margin({ bottom: 14 })

      // 香火粒子层（点香触发，纯仪式）
      Stack() {
        ForEach(this.particles, (p: FireParticle) => {
          Text('✦')
            .fontSize(p.size)
            .fontColor('#f9ca24')
            .opacity(this.incenseAnim ? 0 : 0.9)
            .translate({
              x: this.incenseAnim ? Math.cos(p.angle * Math.PI / 180) * p.dist : 0,
              y: this.incenseAnim ? Math.sin(p.angle * Math.PI / 180) * p.dist - 20 : 0
            })
            .animation({
              duration: 1100,
              delay: p.delay,
              curve: Curve.EaseOut
            })
        }, (p: FireParticle) => 'p' + p.id)
      }
      .width('100%')
      .height(80)
      .margin({ top: 8 })

      Text('诚心供奉 · 无求自得')
        .fontSize(13)
        .fontColor('rgba(253, 246, 227, 0.75)')
        .margin({ bottom: 14 })

      Button('🪷 点香供奉')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1a1a0a')
        .backgroundColor('#f9ca24')
        .borderRadius(20)
        .height(40)
        .width('60%')
        .margin({ bottom: 10 })
        .onClick(() => {
          this.offerIncense()
        })

      Text('供奉即心意 · 心诚比金贵')
        .fontSize(9)
        .fontColor('rgba(253, 246, 227, 0.5)')
        .margin({ bottom: 8 })

      Button('关闭')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#f9ca24')
        .backgroundColor(Color.Transparent)
        .border({ width: 1, color: 'rgba(249, 202, 36, 0.4)' })
        .borderRadius(20)
        .height(34)
        .padding({ left: 28, right: 28 })
        .margin({ bottom: 12 })
        .onClick(() => {
          this.controller.close()
        })
    }
    .width('78%')
    .backgroundColor('#1a1a0a')
    .borderRadius(16)
    .border({ width: 1.5, color: 'rgba(249, 202, 36, 0.3)' })
    .shadow({ radius: 30, color: 'rgba(0, 0, 0, 0.6)', offsetY: 6 })
    .clip(true)
  }
}
```

- [ ] **Step 2: 编译检查**（命令同 Task 3 Step 2；剩余错误应只在 EntryAbility 的 completePendingOrders 处——Task 10 处理）

- [ ] **Step 3: Commit**

```bash
git add entry/src/main/ets/components/TipModal.ets
git commit -m "refactor(ui): TipModal 重做为免费供奉仪式（移除全部收款元素，审核整改）"
```

---

### Task 9: QiuQian.ets 锁定态 + 解锁流程

**Files:**
- Modify: `entry/src/main/ets/pages/QiuQian.ets`

- [ ] **Step 1: 更新 import**（第 6-13 行区域）

新增：
```ts
import { BusinessError } from '@kit.BasicServicesKit'
import { common } from '@kit.AbilityKit'
import { IapPaymentService } from '../service/IapPaymentService'
import { PaymentError, PaymentErrorKind, UnlockPurchaseResult } from '../service/IPaymentService'
import { CloudService } from '../service/CloudService'
```
（`pasteboard` 已从 `@kit.BasicServicesKit` 导入，把 BusinessError 并入同一行即可：`import { pasteboard, BusinessError } from '@kit.BasicServicesKit'`）

- [ ] **Step 2: 新增状态字段**（在 `@State clearArmed: boolean = false` 之后）

```ts
  @State unlocked: boolean = false       // 解签买断解锁状态（快照自 qiuVM）
  private unlocking: boolean = false     // 解锁进行中（防重入）
  private restoreCheckDone: boolean = false  // 本页会话内只做一次权益恢复检查
```

- [ ] **Step 3: syncFromVM 同步解锁状态**

在 `syncFromVM()` 中追加一行：
```ts
    this.unlocked = this.qiuVM.isUnlocked()
```

- [ ] **Step 4: SignDetailOverlay 解签/建议区改条件渲染**

将：
```ts
        Text(`解签：${sign.interpretation}`)
          .fontSize(13)
          .fontColor('rgba(253, 246, 227, 0.85)')
          .lineHeight(20)
          .margin({ top: 16 })

        Text(`今日建议：${sign.advice}`)
          .fontSize(12)
          .fontColor('rgba(249, 202, 36, 0.8)')
          .lineHeight(19)
          .margin({ top: 10 })
```
改为：
```ts
        if (this.unlocked) {
          Text(`解签：${sign.interpretation}`)
            .fontSize(13)
            .fontColor('rgba(253, 246, 227, 0.85)')
            .lineHeight(20)
            .margin({ top: 16 })

          Text(`今日建议：${sign.advice}`)
            .fontSize(12)
            .fontColor('rgba(249, 202, 36, 0.8)')
            .lineHeight(19)
            .margin({ top: 10 })
        } else {
          // 锁占位：解签文 + 买断入口（WCAG：金底深字 #1a1a0a 实色，禁用仅用 enabled 不压暗）
          Column() {
            Text('🔒 解签文已锁')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('rgba(253, 246, 227, 0.85)')
            Text('¥0.9 买断 · 一次解锁永久畅看')
              .fontSize(11)
              .fontColor('rgba(253, 246, 227, 0.5)')
              .margin({ top: 4 })
            Button(this.unlocking ? '解锁中…' : '🔓 永久解锁')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1a1a0a')
              .backgroundColor('#f9ca24')
              .borderRadius(20)
              .padding({ left: 26, right: 26, top: 9, bottom: 9 })
              .margin({ top: 12 })
              .enabled(!this.unlocking)
              .onClick((): void => { this.unlockJieqian() })
          }
          .width('100%')
          .padding({ top: 14, bottom: 14 })
          .border({ width: 1, color: 'rgba(249, 202, 36, 0.35)', radius: 12 })
          .backgroundColor('rgba(249, 202, 36, 0.06)')
          .margin({ top: 14 })
        }
```

- [ ] **Step 5: 复制按钮锁定态禁用**

将：
```ts
          Button('📋 复制签文')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor('#f9ca24')
            .backgroundColor('rgba(249, 202, 36, 0.12)')
            .border({ width: 1, color: '#f9ca24' })
            .borderRadius(20)
            .layoutWeight(1)
            .padding({ top: 11, bottom: 11 })
            .onClick((): void => { this.copySignText(sign) })
```
改为：
```ts
          Button(this.unlocked ? '📋 复制签文' : '🔒 解锁后可复制')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor('#f9ca24')
            .backgroundColor('rgba(249, 202, 36, 0.12)')
            .border({ width: 1, color: '#f9ca24' })
            .borderRadius(20)
            .layoutWeight(1)
            .padding({ top: 11, bottom: 11 })
            .enabled(this.unlocked)
            .onClick((): void => { this.copySignText(sign) })
```

- [ ] **Step 6: openDetail 追加静默恢复 + 新增解锁方法**（改 openDetail，并在其下方加 4 个方法）

将：
```ts
  /** 打开解签详情（当前签揭晓 / 签录记录行共用入口） */
  private openDetail(sign: SignEntry): void {
    this.detail = sign
    this.detailOpenedAt = Date.now()
    this.showDetail = true
  }
```
改为：
```ts
  /** 打开解签详情（当前签揭晓 / 签录记录行共用入口） */
  private openDetail(sign: SignEntry): void {
    this.detail = sign
    this.detailOpenedAt = Date.now()
    this.showDetail = true
    this.tryRestoreUnlock()
  }

  /** 未解锁时静默恢复权益（重装/换机/上次云端未记）：打开详情即自动解锁 */
  private tryRestoreUnlock(): void {
    if (this.qiuVM.isUnlocked() || this.restoreCheckDone) {
      return
    }
    this.restoreCheckDone = true
    const iap = new IapPaymentService(this.getUIContext().getHostContext() as common.UIAbilityContext)
    iap.restoreOwned().then((owned: UnlockPurchaseResult | null) => {
      if (owned !== null) {
        this.applyUnlock(owned)
      }
    }).catch((err: Object) => {
      console.error('[QiuQian] restoreUnlock failed:', JSON.stringify(err))
    })
  }

  /** 解锁流程：已购恢复 → 买断 → 本地置位 + 云端幂等补记 */
  private async unlockJieqian(): Promise<void> {
    if (this.unlocking) {
      return
    }
    this.unlocking = true
    try {
      const iap = new IapPaymentService(this.getUIContext().getHostContext() as common.UIAbilityContext)
      // ① 已购恢复（重装/换机/上次云端未记）
      const owned: UnlockPurchaseResult | null = await iap.restoreOwned()
      if (owned !== null) {
        await this.applyUnlock(owned)
        return
      }
      // ② 买断
      const result: UnlockPurchaseResult = await iap.purchase()
      if (!result.success) {
        return  // 用户取消：静默
      }
      await this.applyUnlock(result)
    } catch (err) {
      this.handleUnlockError(err)
    } finally {
      this.unlocking = false
    }
  }

  /** 解锁落账：本地置位（主权益源，立即生效）+ 云端幂等补记（失败不阻塞解锁） */
  private async applyUnlock(result: UnlockPurchaseResult): Promise<void> {
    await this.qiuVM.setUnlocked(true)
    this.unlocked = true
    this.toast('解签已解锁 · 功德圆满 🙏')
    CloudService.recordSignUnlock({
      productId: result.productId,
      purchaseToken: result.purchaseToken,
      purchaseData: result.purchaseData,
      orderId: result.orderId
    })
  }

  private handleUnlockError(err: Object): void {
    if (err instanceof PaymentError) {
      const pe = err as PaymentError
      if (pe.kind === PaymentErrorKind.NEED_LOGIN) {
        // 与供奉弹窗同款 v1 指引：系统设置登录（LoginWithHuaweiID 引导留 v2）
        this.toast('解锁需登录华为帐号，请在系统设置中登录后重试')
      } else if (pe.kind === PaymentErrorKind.ALREADY_OWNED) {
        // 已拥有但 restoreOwned 未生效（queryPurchases 瞬断）：重置恢复标记直接再恢复，
        // 成功路径走 applyUnlock 的「解签已解锁」toast
        this.restoreCheckDone = false
        this.tryRestoreUnlock()
      } else {
        this.toast(pe.message)
      }
      console.error('[QiuQian] unlock error: kind=' + pe.kind + ' code=' + pe.rawCode)
      return
    }
    const e = err as BusinessError
    console.error('[QiuQian] unlock error: code=' + e.code + ' msg=' + e.message)
    this.toast('购买失败请重试')
  }
```

- [ ] **Step 7: 编译检查**（命令同 Task 3 Step 2；剩余错误应只在 EntryAbility 的 completePendingOrders 处——Task 10 处理）

- [ ] **Step 8: Commit**

```bash
git add entry/src/main/ets/pages/QiuQian.ets
git commit -m "feat(qiuqian): 解签买断锁定态 UI + 解锁流程（restoreOwned 恢复 → purchase → 本地置位 + 云端幂等补记）"
```

---

### Task 10: EntryAbility.ets 启动权益恢复

**Files:**
- Modify: `entry/src/main/ets/entryability/EntryAbility.ets:12,80-86`

- [ ] **Step 1: 更新 import**

将：
```ts
import { QiuQianViewModel } from '../viewmodels/QiuQianViewModel'
import { IapPaymentService } from '../service/IapPaymentService'
```
改为：
```ts
import { QiuQianViewModel, KEY_UNLOCKED } from '../viewmodels/QiuQianViewModel'
import { IapPaymentService } from '../service/IapPaymentService'
import { UnlockPurchaseResult } from '../service/IPaymentService'
import { CloudService } from '../service/CloudService'
```

- [ ] **Step 2: 替换补单为权益恢复**

将：
```ts
        // IAP 防漏单补单：上次供奉若「已支付未消耗」（上报云端失败/进程被杀），
        // 这里补「云端幂等记账 + finishPurchase」。deviceUserId 就绪后才有 __uid 可记账；
        // 未登录华为帐号时 queryPurchases 会安全跳过，下次启动再补。
        const iapService = new IapPaymentService(this.context)
        iapService.completePendingOrders().catch((err: Object) => {
          console.error('IapPaymentService completePendingOrders failed:', JSON.stringify(err))
        })
```
改为：
```ts
        // 解签买断权益恢复：非消耗型商品已购（重装/换机/上次云端未记）→
        // 置本地解锁标志 + 云端幂等补记。deviceUserId 就绪后才有 __uid 可记账；
        // 未登录华为帐号时 queryPurchases 会安全跳过，下次启动再补。
        const iapService = new IapPaymentService(this.context)
        iapService.restoreOwned().then((owned: UnlockPurchaseResult | null) => {
          if (owned === null) {
            return
          }
          qiuVM.setUnlocked(true).catch((err: Object) => {
            console.error('QiuQianViewModel setUnlocked failed:', JSON.stringify(err))
          })
          prefs.put(KEY_UNLOCKED, true).then(() => {
            return prefs.flush()
          }).catch((err: Object) => {
            console.error('EntryAbility save jieqianUnlocked failed:', JSON.stringify(err))
          })
          CloudService.recordSignUnlock({
            productId: owned.productId,
            purchaseToken: owned.purchaseToken,
            purchaseData: owned.purchaseData,
            orderId: owned.orderId
          })
        }).catch((err: Object) => {
          console.error('IapPaymentService restoreOwned failed:', JSON.stringify(err))
        })
```

- [ ] **Step 3: 编译检查**（命令同 Task 3 Step 2）→ Expected: BUILD SUCCESSFUL（至此全部引用链改完）

- [ ] **Step 4: Commit**

```bash
git add entry/src/main/ets/entryability/EntryAbility.ets
git commit -m "feat(entry): 启动恢复解签买断权益（restoreOwned → 本地置位 + 云端幂等补记）"
```

---

### Task 11: MyPage.ets 菜单文案调整

**Files:**
- Modify: `entry/src/main/ets/pages/MyPage.ets:117-118`

- [ ] **Step 1: 改菜单文案与注释**

将：
```ts
            // 供奉打赏（IAP 供奉台，与祈福结算页同款弹窗）
            this.MenuItem('🧧', '供奉打赏', '', false, (): void => { this.openTipDialog() })
```
改为：
```ts
            // 供奉（免费仪式弹窗，与祈福结算页同款；供奉打赏已随审核整改移除）
            this.MenuItem('🧧', '诚心供奉', '', false, (): void => { this.openTipDialog() })
```

- [ ] **Step 2: 编译检查**（命令同 Task 3 Step 2）→ Expected: BUILD SUCCESSFUL

- [ ] **Step 3: Commit**

```bash
git add entry/src/main/ets/pages/MyPage.ets
git commit -m "refactor(ui): 我的页供奉菜单改「诚心供奉」（免费仪式，移除打赏语义）"
```

---

### Task 12: 全量构建验证 + 检查清单

**Files:** 无（验证）

- [ ] **Step 1: 冒烟测试回归**（云函数逻辑不受客户端改动影响，仍应全绿）

Run: `node cloud/jieqian-unlock/smoke.cjs` → Expected: `20/20 通过`

- [ ] **Step 2: 打包验证**

Run: `node cloud/deploy.cjs jieqian-unlock` → Expected: zip 正常产出

- [ ] **Step 3: 完整构建**（含 Java 阶段与签名）

```bash
export DEVECO_SDK_HOME="C:/Program Files/Huawei/DevEco/sdk"
export JAVA_HOME="C:/Program Files/Huawei/DevEco/jbr"
export PATH="/c/Program Files/Huawei/DevEco/jbr/bin:$PATH"
node hvigorw.js --mode module -p product=default -p buildMode=debug --no-daemon assembleHap
```
Expected: `BUILD SUCCESSFUL`，产物 `entry/build/default/outputs/default/entry-default-signed.hap`

- [ ] **Step 4: 更新 cloud/README.md 部署 runbook**（Task 2 质量评审发现：README 仍写「5 个云函数」，权威函数对照表缺 jieqian-unlock；任务 3-11 已改完，本次一并刷新）

- 函数计数：README 中所有「5 个云函数 / 打包全部 5 个 / 依次上传 5 个 zip / 5 个函数的对应关系」表述改为 6（约第 3、145、202、206 行）
- 对应关系表补 `jieqian-unlock` 行：函数名 `jieqian-unlock`、动作 `record（幂等记账）/ query（解锁状态）`、客户端调用方 `CloudService.ets: recordSignUnlock / getSignUnlockStatus`
- 表中 CloudService.ets 旧行号已漂移，按 Task 12 后实际状态刷新（grep `recordSignUnlock` 定位新行号）

- [ ] **Step 5: 全仓残留检查**（不得有打赏/功德/供奉付款残留）

Run:
```bash
grep -rn "recordDonation\|getMyMerit\|TIP_PRODUCTS\|TipPurchaseResult\|completePendingOrders\|tip_06\|donation-record\|供奉打赏\|功德" entry/src/main/ets --include="*.ets" | grep -v "// " || echo "CLEAN"
```
Expected: 无输出（或仅注释行）→ 输出 `CLEAN`

- [ ] **Step 5: 提交残留清理**

```bash
git status
git add -u
git commit -m "chore: 打赏残留清理确认"
```

---

### Task 13: AGC 控制台手动配置（无法自动化，交付时逐项核对）

**Files:** 无（AGC 控制台操作）

- [ ] **Step 1: 应用内购买服务**：开通/确认 IAP 服务；新建**非消耗型**商品 `jieqian_unlock`，价格 ¥0.9（控制台无 0.9 档则用 ¥1，并同步改 `IPaymentService.ets` 的 `UNLOCK_PRODUCT.amount` 与 QiuQian 锁占位文案「¥0.9」），地区发布
- [ ] **Step 2: Cloud DB**：导入 `cloud/agc-clouddb-object-types-jieqian-unlock.json` 创建 `SignUnlock` 对象类型；**手动建索引** `purchaseToken`、`uid`（幂等查询与 query 依赖，未建会报错）
- [ ] **Step 3: 云函数**：上传 `cloud/jieqian-unlock/jieqian-unlock.zip`，函数名 `jieqian-unlock`（kebab-case），Node.js 18，HTTP 触发器
- [ ] **Step 4: 沙箱联调**：配置沙箱测试华为 ID + debug 签名 profile；真机验证买断全流程（见设计文档第 8 节测试用例）
- [ ] **Step 5: 旧资源保留**：tip_06~88 商品、Donation/UserMerit 表、donation-record 函数**不删除**（停止调用即可）
