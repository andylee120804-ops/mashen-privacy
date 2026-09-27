# 麻神祈福 - AGC 云函数

6 个云函数 + 共享库，为排行榜、心愿墙、牌局记录云备份与解签买断（IAP）提供后端。

## 目录结构

```
cloud/
├── shared/                  # 共享工具（随每个函数打包）
│   ├── response.js          # 统一响应信封 + wrapHttp + extractBody
│   └── db.js                # Cloud DB 封装（createInstance/getDB/toGenericObjects）
├── update-prayer-count/     # 上报祈福次数
│   ├── handler.js
│   └── package.json
├── get-leaderboard/         # 查询排行榜 / 今日香火人数
│   ├── handler.js
│   └── package.json
├── wish-wall/               # 心愿墙 list/create/fulfill
│   ├── handler.js
│   └── package.json
├── game-record-backup/      # 牌局记录云备份 pull/push（仅本人）
│   ├── handler.js
│   └── package.json
├── donation-record/         # 供奉打赏记录（已停止调用，客户端不再使用；保留不下架）
│   ├── handler.js
│   ├── package.json
│   └── smoke.cjs            # 冒烟测试：node cloud/donation-record/smoke.cjs
├── jieqian-unlock/          # 解签买断 record（幂等记账）/ query（解锁状态）
│   ├── handler.js
│   ├── package.json
│   └── smoke.cjs            # 冒烟测试：node cloud/jieqian-unlock/smoke.cjs
├── deploy.cjs               # 打包脚本
└── agc-credential.json      # ⬅ 部署时手动放置（API Client 凭证，见下）
```

## SDK API 要点（与官方文档示例的差异）

经核对 `@hw-agconnect/cloud-server@1.0.5` 类型定义，本仓库采用以下**正确**用法
（不少网络示例与官方文档示例写法有误，会导致运行时崩溃）：

| 用法 | ❌ 常见错误写法 | ✅ 本仓库写法 |
|------|----------------|---------------|
| 获取 DB | `cloud.database()` | `cloud.database({ zoneName })` （CloudDBZoneConfig 必填） |
| 对象类型 | `CloudDBZoneGenericObject.getObjectType('X')` | 直接传字符串：`collection('X')` （getObjectType 方法不存在） |
| 构造查询 | `CloudDBZoneQuery.where(type).equalTo(...)` | `db.collection('X').query().equalTo(...)` （query 由 collection 产生） |
| 执行查询 | `db.collection(t).query(query)` | `db.collection('X').query().equalTo(...).get()` （query() 无参，链式后 .get()） |
| upsert | 直接传普通对象 | 先 `toGenericObjects(typeName, records)` 转换（SDK convertTClass 不更新 fieldMap） |
| createInstance | `cloud.createInstance(path)` | `cloud.createInstance(path, '唯一name')` （默认 'default' 被环境变量抢占） |

## Cloud DB schema（部署前在 AGC 控制台创建）

存储区名称：`Mashen`（见 `shared/db.js` 的 `CLOUD_DB_ZONE`）。

### Leaderboard 对象类型

| 字段 | 类型 | 主键 | 说明 |
|------|------|------|------|
| userId | String | ✅ | 设备匿名 ID |
| nickname | String | | 脱敏昵称（首字+***） |
| todayCount | Integer | | 今日祈福次数 |
| weekCount | Integer | | 本周祈福次数 |
| totalCount | Integer | | 累计祈福次数 |
| totalKowtow | Integer | | 累计磕头数 |
| streak | Integer | | 连续签到天数 |
| updatedAt | String | | 最后更新时间（ISO） |
| weekStart | String | | 本周一日期（YYYY-MM-DD） |

### Wish 对象类型

| 字段 | 类型 | 主键 | 说明 |
|------|------|------|------|
| id | String | ✅ | 心愿 ID（w_时间戳_随机） |
| userId | String | | 发布者设备 ID |
| nickname | String | | 脱敏昵称 |
| content | String | | 心愿内容（≤30 字） |
| deityId | Integer | | 祈求的财神 ID |
| fulfilled | Boolean | | 是否已还愿 |
| createdAt | String | | 发布时间（ISO） |
| fulfilledAt | String | | 还愿时间（ISO） |

### GameBackup 对象类型（牌局记录云备份，仅本人可见）

| 字段 | 类型 | 主键 | 说明 |
|------|------|------|------|
| userId | String | ✅ | 设备匿名 ID（复合主键之一） |
| date | String | ✅ | 记录日期 YYYY-MM-DD（复合主键之一） |
| deityId | Integer | | 当天拜的财神 ID |
| kowtowCount | Integer | | 当天磕头次数 |
| games | String | | 每局结果数组的 JSON 字符串（Cloud DB 无数组类型） |
| note | String | | 备注（≤200 字） |
| updatedAt | String | | 最后同步时间（ISO） |

> 每天一行、复合主键 `(userId, date)`，upsert 幂等可重复推送；
> games 用 JSON 字符串承载（如 `[{"result":"+","magnitude":5}]`），
> 避免依赖 Cloud DB 大 String 字段上限而把整份快照塞进单行。

### Donation 对象类型（供奉打赏流水，IAP）

| 字段 | 类型 | 主键 | 说明 |
|------|------|------|------|
| id | String | ✅ | purchaseOrderId（orderId 缺省时 d_时间戳_随机） |
| uid | String | | 打赏者设备匿名 ID |
| productId | String | | AGC 商品 ID（tip_06 / tip_6 / tip_18 / tip_66 / tip_88） |
| amount | Double | | 金额（服务端商品白名单定价，不信任客户端传值） |
| purchaseToken | String | | **幂等去重键**（补单/重试不双记） |
| purchaseData | String | | 华为签名 purchaseData 存证。⚠️ 控制台字段容量实测 ~200~255 字符（255 报 3007007），完整 JWS（2500+）装不下，handler 截断到 200 字符存证；真正的校验键是 purchaseToken（未来 verify 走 token 调华为订单服务） |
| status | String | | 默认 'done'，未来可为 'verified'/'revoked' |
| createdAt | String | | 记账时间（ISO） |

**索引（必须在控制台建，否则 record 幂等查询报错）**：
`uid ASC`、`purchaseToken ASC`、`createdAt DESC`。

### UserMerit 对象类型（累计功德）

| 字段 | 类型 | 主键 | 说明 |
|------|------|------|------|
| uid | String | ✅ | 设备匿名 ID |
| totalAmount | Double | | 累计打赏金额 |
| totalCount | Integer | | 累计供奉次数 |
| updatedAt | String | | 最后更新（ISO） |

> 两表均为**私有数据**：权限同 GameBackup（World/Authenticated 无权限，
> Creator Read+Upsert，Administrator 全权限），客户端只经 `donation-record`
> 云函数中转读写，不直连 Cloud DB。`cleanup-cloud-db.cjs` **不清这两张表**
> ——Donation 是真实交易流水，删除不可恢复；测试期 `__uid: "test123"` 产生
> 的测试数据需在 Cloud DB 控制台按 uid 定点删。
> ⚠️ **打赏已随审核整改移除（2026-09-27）**：客户端不再调用 `donation-record`，
> 两表与函数保留不下架（避免误伤历史数据），仅停止调用。

### SignUnlock 对象类型（解签买断流水，IAP 非消耗型）

| 字段 | 类型 | 主键 | 说明 |
|------|------|------|------|
| id | String | ✅ | purchaseOrderId |
| uid | String | | 设备匿名 ID（__uid） |
| productId | String | | jieqian_unlock（服务端白名单校验，仅此值可记账） |
| purchaseToken | String | | **幂等去重键**（重复 record 不双记） |
| purchaseData | String | | 华为签名原文存证（未来 verify 用） |
| createdAt | String | | 记账时间（ISO） |

**索引（必须在控制台建，否则 record 幂等/query 查询报错）**：
`purchaseToken ASC`、`uid ASC`。

**权限**：私有数据，同 Donation（World/Authenticated 无权限，
Creator Read+Upsert，Administrator 全权限），客户端只经 `jieqian-unlock`
云函数中转，不直连 Cloud DB。

## 部署步骤

1. **准备凭证**：AGC 控制台 → 用户中心 → 凭证管理 → 创建 **API Client**，
   下载 `api-client-project.json`，重命名为 `agc-credential.json` 放到 `cloud/` 根目录。
   - 当前控制台创建 API Client 时**已无「关联 Cloud DB 产品」勾选项**（旧版有，现版移除），
     Cloud DB 访问权随项目开通 Cloud DB 自动授予，无需手动勾选。
   - ⚠️ 不能用「项目设置 > 常规 > 项目凭证」：那是项目凭证，类型不对，调用会报
     `203886599 the type of clientId not match`。必须用用户中心创建的 API Client。

2. **本地验证凭证**（不用部署即可测）：
   ```bash
   cd cloud && node -e "
   const https=require('https'),c=require('./agc-credential.json');
   const b=JSON.stringify({grant_type:'client_credentials',client_id:c.client_id,client_secret:c.client_secret});
   const r=https.request({hostname:'connect-api.cloud.huawei.com',path:'/api/oauth2/v1/token',method:'POST',headers:{'Content-Type':'application/json','Content-Length':Buffer.byteLength(b),'algorithm_type':'1','User-Agent':'AGCServerSDK/1.0.0','serverSdkName':'node/cloud-server/common-server','serverSdkVersion':'1.0.0'}},res=>{let d='';res.on('data',x=>d+=x);res.on('end',()=>{const j=JSON.parse(d);console.log('code:',j.ret?.code??'ok','products:',JSON.stringify(j.products||[]));});});r.write(b);r.end();
   "
   # code: 0 + products 非空 = 有效
   ```

3. **打包**：
   ```bash
   node cloud/deploy.cjs          # 打包全部 6 个
   # 或：node cloud/deploy.cjs update-prayer-count
   ```
   （`smoke*.cjs` 冒烟测试脚本会自动排除，不进部署包。）
   `deploy.cjs` 用 adm-zip 打正斜杠路径，并在写完 zip 后用 `patchUnixHostOS()`
   把中央目录头的 `hostOS` 从 Windows(10) patch 成 Unix(3)——否则 AGC Linux 运行时
   会忽略条目的 Unix 权限位，`handler.js` 以无权限解压，报
   `180000 EACCES: permission denied, open '/dcache/layer/func/handler.js'`。
   这是 adm-zip 在 Windows 上打包的已知坑，patch 后文件以 0o644 可读权限解压。

4. **创建 Cloud DB 存储区**（必须在导入对象类型之前，云函数访问依赖此区）：
   AGC 控制台 → 构建 → Cloud DB → 存储区管理 → **新增存储区**
   - 存储区名称：`Mashen`（与 `shared/db.js` 的 `CLOUD_DB_ZONE` **逐字一致**）
   - 命名规则：字母开头，仅含字母数字（**不能下划线/中划线**），`Mashen` 合规
   - ⚠️ **存储区必须手动创建**：`database({ zoneName })` 不会自动建，不提前建好
     云函数查询会报 `2002037: CloudDBZone does not exist`。
   - 没建存储区只导入对象类型 = 对象类型存在但无处读写，仍报 2002037。

5. **导入对象类型**：Cloud DB → 对象类型 → 「**导入对象类型**」。
   - **已上线 3 张表**（Leaderboard / Wish / GameBackup）：结构以
     `cloud/agc-clouddb-object-types.json` 为准——该文件是线上结构的**零改动快照**，
     已导入过就**不再重新导入、不做任何修改**。
   - **新增 Donation / UserMerit 两表（IAP）**：用独立文件
     `cloud/agc-clouddb-object-types-donation.json` 导入——只含这两张新表，
     **已有表零接触**；若控制台不支持导入，按上表手动建（字段名/类型务必一致，
     否则 upsert 静默失败）。
   - **新增 SignUnlock 表（解签买断，2026-09-27）**：用独立文件
     `cloud/agc-clouddb-object-types-jieqian-unlock.json` 导入——只含这一张新表，
     已有表零接触。

   ⚠️ 手建 Donation 时**必须一并建索引**
   `uid ASC` / `purchaseToken ASC` / `createdAt DESC`——`donation-record` 的幂等
   查询按 purchaseToken 走索引，无索引查询直接报错。

   **导入报「权限为空」怎么办**：早期版本的 JSON 缺 `permissions` 块，AGC 控制台
   导入时会拦在「权限为空」。当前版本已补齐顶层 `permissions` 数组（每个对象类型 4 种
   role：World / Authenticated / Creator / Administrator，rights 为 Read / Upsert / Delete），
   直接导入即可，不再需要导入后手配权限。

   **权限设计**（已写入对应 JSON，导入即生效：前 3 张在主文件，Donation/UserMerit
   在 `agc-clouddb-object-types-donation.json`）：

   | 对象类型 | World（所有用户） | Authenticated（已认证） | Creator（创建者） | Administrator（管理员/云函数） |
   |----------|-------------------|------------------------|-------------------|-------------------------------|
   | Leaderboard | Read | Read | Read, Upsert | Read, Upsert, Delete |
   | Wish | Read | Read | Read, Upsert, Delete | Read, Upsert, Delete |
   | GameBackup | —（无权限） | —（无权限） | Read, Upsert | Read, Upsert, Delete |
   | Donation | —（无权限） | —（无权限） | Read, Upsert | Read, Upsert, Delete |
   | UserMerit | —（无权限） | —（无权限） | Read, Upsert | Read, Upsert, Delete |
   | SignUnlock | —（无权限） | —（无权限） | Read, Upsert | Read, Upsert, Delete |

   - World/Authenticated 只读：排行榜、心愿墙是公开展示内容，读对所有人开放。
   - GameBackup 是**私有数据**（仅本人可见），World/Authenticated 权限为空、
     无 Read 权，Creator 仅 Read/Upsert 自己的行——牌局记录不向任何其他用户公开。
   - Creator 可改自己的记录（Wish 含 Delete，发布者可删自己心愿；还愿仅本人由云函数
     `wish.userId !== uid` → FORBIDDEN 兜底，不依赖 ACL）。
   - **Administrator 必须全权限**：云函数用服务端 SDK + API Client 凭证以应用管理员
     身份读写，不受 ACL 限制，但权限表要给它留 Read/Upsert/Delete 才规范。
   - 客户端不直连 Cloud DB（`CloudService.ets` 只用 `cloudFunction.call` 中转），
     故 World/Authenticated/Creator 实际不会被触发，设保守值即可，主要供审核看数据安全。

6. **部署云函数**：AGC 控制台 → 构建 → 云函数 → 创建函数，依次上传 6 个 zip。
   每个 zip 已含 `handler.js`（导出 `myHandler`）+ `shared/` + `node_modules/`
   （含 `@hw-agconnect/cloud-server`）+ `agc-credential.json`，正斜杠路径，可直接上传。

   **6 个函数的对应关系**（函数名必须与客户端 `cloudFunction.call({ name })` 逐字一致）：

   | 上传的 zip | 控制台函数名 | 客户端调用 | 作用 |
   |-----------|-------------|-----------|------|
   | `cloud/update-prayer-count/update-prayer-count.zip` | `update-prayer-count` | [CloudService.ets:74](../entry/src/main/ets/service/CloudService.ets#L74) | 祈福后上报次数 |
   | `cloud/get-leaderboard/get-leaderboard.zip` | `get-leaderboard` | [CloudService.ets:94](../entry/src/main/ets/service/CloudService.ets#L94) | 查日/周/总榜 + 今日香火人数 |
   | `cloud/wish-wall/wish-wall.zip` | `wish-wall` | [CloudService.ets:140](../entry/src/main/ets/service/CloudService.ets#L140) | 心愿墙列表/发布/还愿 |
   | `cloud/game-record-backup/game-record-backup.zip` | `game-record-backup` | [CloudService.ets:230](../entry/src/main/ets/service/CloudService.ets#L230) | 牌局记录拉取/推送备份 |
   | `cloud/jieqian-unlock/jieqian-unlock.zip` | `jieqian-unlock` | [CloudService.ets:295](../entry/src/main/ets/service/CloudService.ets#L295)（record）/ [317](../entry/src/main/ets/service/CloudService.ets#L317)（query） | 解签买断记账（purchaseToken 幂等）/ 查解锁状态 |
   | `cloud/donation-record/donation-record.zip` | `donation-record` | —（已停止调用，保留不下架） | 打赏记账（purchaseToken 幂等）/ 查累计功德 |

   **每个函数的创建参数**：
   - 函数名：照上表填（kebab-case，小写连字符）
   - 描述：随意
   - 代码上传方式：上传 .zip 包 → 选对应 zip
   - 运行时：**Node.js 18**
   - 内存：256 MB
   - 超时：30 秒
   - 实例数：单实例（默认 1）
   - 执行超时同上 30s

   **触发器配置**（创建函数后进入该函数 → 触发器 → 新建）：
   - 触发器类型：**HTTP 触发器**
   - 标识符：随意（如函数名）
   - 方法：**POST**
   - 鉴权：**开启 AGC Auth**（客户端用 cloudFunction.call 自动带鉴权）
   - 创建后复制得到的 HTTP URL 备用（客户端 SDK 调用走 name，一般不用手填 URL）

   **验证函数可用**（控制台「云函数 → 对应函数 → 测试」）：
   - `get-leaderboard` 测试入参：`{ "type": "total", "__uid": "test123" }`
     期望返回：`{ "code": 0, "message": "success", "data": [] }`（空榜正常）
   - `update-prayer-count` 测试入参：
     `{ "nickname": "测***", "kowtowCount": 3, "streak": 1, "__uid": "test123" }`
     期望返回：`{ "code": 0, ... "data": { "updated": true } }`，且 Cloud DB
     `Leaderboard` 表多一条 `userId=test123` 记录。
   - `game-record-backup` 测试入参（push）：
     `{ "action": "push", "__uid": "test123", "records": [{ "date": "2026-09-08", "deityId": 1, "kowtowCount": 3, "games": [{ "result": "+", "magnitude": 5 }], "note": "测试" }] }`
     期望返回：`{ "code": 0, "data": { "pushed": 1 } }`；再测 pull：
     `{ "action": "pull", "__uid": "test123" }` 应返回该条记录。测完记得清库。
   - `donation-record` 测试入参（record）：
     `{ "action": "record", "__uid": "test123", "productId": "tip_6", "purchaseToken": "test_tok_1", "purchaseData": "{}", "orderId": "test_order_1" }`
     期望返回：`{ "code": 0, "data": { "totalAmount": 6, "totalCount": 1 } }`，且 Cloud DB
     `Donation` 表多一条 `id=test_order_1`、`UserMerit` 表多一条 `uid=test123`。
     **再传一遍完全相同的入参**（幂等验证）：返回的 `totalAmount` 仍是 6、`totalCount` 仍是 1，
     `Donation` 表仍只有一条——不双记。再测 query：
     `{ "action": "query", "__uid": "test123" }` 应返回 `{ "totalAmount": 6, "totalCount": 1 }`。
     ⚠️ 测完在 Cloud DB 控制台定点删 `uid=test123` 的 Donation/UserMerit 记录
     （cleanup 脚本不清这两张表，防误删真实打赏）。
   - `jieqian-unlock` 测试入参（record）：
     `{ "action": "record", "__uid": "test123", "productId": "jieqian_unlock", "purchaseToken": "test_unlock_tok_1", "purchaseData": "{}", "orderId": "test_unlock_1" }`
     期望返回：`{ "code": 0, "data": { "unlocked": true } }`，且 Cloud DB
     `SignUnlock` 表多一条 `id=test_unlock_1`。
     **再传一遍完全相同的入参**（幂等验证）：仍返回 `{ "unlocked": true }`，
     `SignUnlock` 表仍只有一条——不双记。再测 query：
     `{ "action": "query", "__uid": "test123" }` 应返回 `{ "unlocked": true }`。
     ⚠️ 测完在 Cloud DB 控制台定点删 `uid=test123` 的 SignUnlock 记录。
   - 报 401 `client token auth failed` → 凭证问题（见下「凭证说明」）。
   - 报 `3037003 primary key missing` → 对象类型未导入或字段名不符。
   - 报 `2002037 CloudDBZone does not exist` → 存储区 `Mashen` 没建（见步骤 4）。

7. **客户端权限**：已在 `module.json5` 声明 `ohos.permission.INTERNET`。

### 凭证说明（`products: []` 为空是正常的）

本地验证（第 2 步脚本）结果：`ret.code: 0` + `access_token 已获取` + `products: []`。
这是**正常的、凭证有效**的表现：

- `code: 0` + 拿到 access_token = 凭证是有效的 **API Client 凭证**（不是项目凭证——
  项目凭证会报 `203886599 the type of clientId not match`，这里没有，说明凭证类型对）。
- `products: []` 为空**不代表缺权限**：当前 AGC 控制台创建 API Client 时已没有「关联
  Cloud DB 产品」勾选项（旧版有，现版移除了）。Cloud DB 访问权是**项目级授予**的——
  项目里开通了 Cloud DB、建了 `Mashen` 存储区，项目内的 API Client 即自动有访问权，
  `products` 只是 token 响应里不再回填的遗留字段。
- 所以**直接按上面步骤部署即可**，不用找产品勾选项。

**若云函数测试真报 401 `client token auth failed`**（实测拿到 token 一般不会）：
确认 `agc-credential.json` 已打进 zip（第 3 步打包后 `zip` 内应含该文件），且
`shared/db.js` 的 `createInstance(path, 'mashen-cloud-db')` 用了唯一实例名。仍 401 再
回用户中心重建 API Client 换新凭证，替换 `cloud/agc-credential.json` 后重新
`node cloud/deploy.cjs` 打包并重新上传 zip。`agc-credential.json` 已 gitignore，不会提交。

## ⚠️ 提审前必做：清空云端测试数据

还愿 tab（wish-wall list）与排行榜 tab（get-leaderboard）对**所有用户**展示全量数据，
没有用户过滤。开发/测试期间产生的心愿、祈福记录会出现在任何新用户的首次进入画面，
华为审核实测会判「应用内含有测试数据」（审核指南 3.4 项），务必在**每次提审前**执行：

```bash
cd cloud
# NODE_PATH 指向函数目录的依赖（SDK 只在各函数 node_modules 里）
export NODE_PATH="$(pwd)/wish-wall/node_modules"
node cleanup-cloud-db.cjs            # 先统计（只读）
node cleanup-cloud-db.cjs --yes      # 确认后删除 Wish / Leaderboard / GameBackup 全部记录
```

- 脚本用 `agc-credential.json` 直连 Cloud DB，删除 `Wish` / `Leaderboard` / `GameBackup`
  三个集合的全部记录（分批查询+删除，幂等可重复执行）。
- 运行前提：凭证有效 + 存储区 `Mashen` 已创建（未部署云端时运行会报
  `2002037 CloudDBZone does not exist`，属正常提示）。
- 删除不可恢复。建议提审流程：**清库 → 构建 release 包 → 提审**，提审后不要再做
  真机祈福/心愿测试（会重新产生测试数据）。
- 如需本地开发联调，用完即清；云函数「测试」页的 `__uid: "test123"` 也会写库，
  测完顺手清掉。

## 客户端调用约定

```typescript
// 客户端 cloudFunction.call 用 data 字段（FunctionParams.data），不是 params
const result = await cloudFunction.call({
  name: 'update-prayer-count',   // kebab-case
  data: { __uid, nickname, kowtowCount, streak }  // ← data，含 __uid 兜底
});
// result.result 是 { code, message, data } 信封（string | Object，需显式转型）
```

服务端从 `event.request` 读取 `data` 内容（`extractBody` 处理）。
