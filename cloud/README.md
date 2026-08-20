# 麻神祈福 - AGC 云函数

3 个云函数 + 共享库，为排行榜与心愿墙提供后端。

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

存储区名称：`MashenZone`（见 `shared/db.js` 的 `CLOUD_DB_ZONE`）。

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
   node cloud/deploy.cjs          # 打包全部 3 个
   # 或：node cloud/deploy.cjs update-prayer-count
   ```
   `deploy.cjs` 用 adm-zip 打正斜杠路径，并在写完 zip 后用 `patchUnixHostOS()`
   把中央目录头的 `hostOS` 从 Windows(10) patch 成 Unix(3)——否则 AGC Linux 运行时
   会忽略条目的 Unix 权限位，`handler.js` 以无权限解压，报
   `180000 EACCES: permission denied, open '/dcache/layer/func/handler.js'`。
   这是 adm-zip 在 Windows 上打包的已知坑，patch 后文件以 0o644 可读权限解压。

4. **创建 Cloud DB**：AGC 控制台 → Cloud DB → 创建存储区 `MashenZone` →
   对象类型页「**导入对象类型**」，上传本仓库的 `cloud/agc-clouddb-object-types.json`
   （已按 AGC 真实导出格式编排：`schemaVersion` + `objectTypes` + `permissions` 三段，
   字段与各 handler upsert 逐一核对，权限块避免导入时报「权限为空」）。
   也可按上表手建，但务必保证字段名/类型与之一致，否则 upsert 静默失败。

   **导入报「权限为空」怎么办**：早期版本的 JSON 缺 `permissions` 块，AGC 控制台
   导入时会拦在「权限为空」。当前版本已补齐顶层 `permissions` 数组（每个对象类型 4 种
   role：World / Authenticated / Creator / Administrator，rights 为 Read / Upsert / Delete），
   直接导入即可，不再需要导入后手配权限。

   **权限设计**（已写入 JSON，导入即生效）：

   | 对象类型 | World（所有用户） | Authenticated（已认证） | Creator（创建者） | Administrator（管理员/云函数） |
   |----------|-------------------|------------------------|-------------------|-------------------------------|
   | Leaderboard | Read | Read | Read, Upsert | Read, Upsert, Delete |
   | Wish | Read | Read | Read, Upsert, Delete | Read, Upsert, Delete |

   - World/Authenticated 只读：排行榜、心愿墙是公开展示内容，读对所有人开放。
   - Creator 可改自己的记录（Wish 含 Delete，发布者可删自己心愿；还愿仅本人由云函数
     `wish.userId !== uid` → FORBIDDEN 兜底，不依赖 ACL）。
   - **Administrator 必须全权限**：云函数用服务端 SDK + API Client 凭证以应用管理员
     身份读写，不受 ACL 限制，但权限表要给它留 Read/Upsert/Delete 才规范。
   - 客户端不直连 Cloud DB（`CloudService.ets` 只用 `cloudFunction.call` 中转），
     故 World/Authenticated/Creator 实际不会被触发，设保守值即可，主要供审核看数据安全。

5. **部署云函数**：AGC 控制台 → 构建 → 云函数 → 创建函数，依次上传 3 个 zip。
   每个 zip 已含 `handler.js`（导出 `myHandler`）+ `shared/` + `node_modules/`
   （含 `@hw-agconnect/cloud-server`）+ `agc-credential.json`，正斜杠路径，可直接上传。

   **3 个函数的对应关系**（函数名必须与客户端 `cloudFunction.call({ name })` 逐字一致）：

   | 上传的 zip | 控制台函数名 | 客户端调用 | 作用 |
   |-----------|-------------|-----------|------|
   | `cloud/update-prayer-count/update-prayer-count.zip` | `update-prayer-count` | [CloudService.ets:57](../entry/src/main/ets/service/CloudService.ets#L57) | 祈福后上报次数 |
   | `cloud/get-leaderboard/get-leaderboard.zip` | `get-leaderboard` | [CloudService.ets:77](../entry/src/main/ets/service/CloudService.ets#L77) | 查日/周/总榜 + 今日香火人数 |
   | `cloud/wish-wall/wish-wall.zip` | `wish-wall` | [CloudService.ets:124](../entry/src/main/ets/service/CloudService.ets#L124) | 心愿墙列表/发布/还愿 |

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
   - 报 401 `client token auth failed` → 凭证问题（见下「凭证注意」）。
   - 报 `3037003 primary key missing` → 对象类型未导入或字段名不符。

6. **客户端权限**：已在 `module.json5` 声明 `ohos.permission.INTERNET`。

### 凭证说明（`products: []` 为空是正常的）

本地验证（第 2 步脚本）结果：`ret.code: 0` + `access_token 已获取` + `products: []`。
这是**正常的、凭证有效**的表现：

- `code: 0` + 拿到 access_token = 凭证是有效的 **API Client 凭证**（不是项目凭证——
  项目凭证会报 `203886599 the type of clientId not match`，这里没有，说明凭证类型对）。
- `products: []` 为空**不代表缺权限**：当前 AGC 控制台创建 API Client 时已没有「关联
  Cloud DB 产品」勾选项（旧版有，现版移除了）。Cloud DB 访问权是**项目级授予**的——
  项目里开通了 Cloud DB、建了 `MashenZone` 存储区，项目内的 API Client 即自动有访问权，
  `products` 只是 token 响应里不再回填的遗留字段。
- 所以**直接按上面步骤部署即可**，不用找产品勾选项。

**若云函数测试真报 401 `client token auth failed`**（实测拿到 token 一般不会）：
确认 `agc-credential.json` 已打进 zip（第 3 步打包后 `zip` 内应含该文件），且
`shared/db.js` 的 `createInstance(path, 'mashen-cloud-db')` 用了唯一实例名。仍 401 再
回用户中心重建 API Client 换新凭证，替换 `cloud/agc-credential.json` 后重新
`node cloud/deploy.cjs` 打包并重新上传 zip。`agc-credential.json` 已 gitignore，不会提交。

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
