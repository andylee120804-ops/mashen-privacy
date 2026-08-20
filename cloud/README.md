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

1. **准备凭证**：AGC 控制台 → 用户中心 → 凭证管理 → 创建 **API Client**
   （务必勾选关联 Cloud DB 产品），下载 `api-client-project.json`，重命名为
   `agc-credential.json` 放到 `cloud/` 根目录。
   - ⚠️ 不能用「项目设置 > 常规 > 项目凭证」，其 `products:[]` 无 Cloud DB 权限。

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

4. **创建 Cloud DB**：AGC 控制台 → Cloud DB → 创建存储区 `MashenZone` →
   对象类型页「**导入对象类型**」，上传本仓库的 `cloud/agc-clouddb-object-types.json`
   （已按 AGC 真实导出格式编排，与各 handler upsert 字段逐一核对一致）。
   也可按上表手建，但务必保证字段名/类型与之一致，否则 upsert 静默失败。

5. **部署云函数**：AGC 控制台 → 云函数 → 依次上传 3 个 zip：
   - 运行时 Node.js 18，内存 256MB，超时 30s
   - 触发器：HTTP POST（开启 AGC Auth）
   - 函数名必须 kebab-case，与客户端 `cloudFunction.call({ name })` 一致

6. **客户端权限**：已在 `module.json5` 声明 `ohos.permission.INTERNET`。

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
