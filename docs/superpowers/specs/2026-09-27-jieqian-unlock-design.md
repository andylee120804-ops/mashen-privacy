# 供奉免费化 · 解签买断设计

> 日期：2026-09-27
> 状态：已确认
> 背景：App 因「供奉麻神」应用内付款被 AGC 审核判为封建迷信拒审。整改方向：供奉收款整体移除（保留为免费仪式），改为「解签」一次性买断解锁（IAP 非消耗型商品）。

## 1. 目标与范围

- **供奉免费化**：`TipModal` 从 5 档 IAP 打赏弹窗重做为免费供奉仪式，所有收款入口删除；云端 Donation/UserMerit 表与 `donation-record` 云函数停止调用（表留在 AGC 不动，不删）。
- **解签买断**：解签文 + 今日建议从免费改为付费解锁。IAP 非消耗型商品 `jieqian_unlock`（¥0.9，若 AGC 控制台无 0.9 档则用 ¥1，商品 id 不变），买断一次永久解锁全部解签。
- 免费边界：摇签、签号/吉凶/签名/签诗、签录回看全部免费；仅「解签文 interpretation + 今日建议 advice」两段文字锁定。

**不做**：按次付费/次数包；连签诗一起锁；功德榜；服务端票据校验（purchaseData 落库存证，接口留扩展位）。

## 2. 供奉免费仪式（TipModal 重做）

`TipModal`（`components/TipModal.ets`）重做为免费供奉台：

- **删除**：5 档金元宝金额卡、选中态、确认供奉按钮、我的累计功德显示区、IAP 支付流程（`IapPaymentService` 实例化）、`MeritInfo` 加载与缓存、成功态「功德 +N」滚动
- **保留**：红色装饰条、「✦ 供奉麻神 ✦」标题、「心诚则灵 · 福报自来」、烟花粒子氛围（免费仪式感）、关闭按钮
- **新增**：供奉完成瞬间的简易反馈（粒子 + 「心意已到 · 福报自来」文案），无任何支付元素
- 入口不动：`BlessingCard`「🧧 供奉麻神」金钮、`MyPage`「🧧 供奉打赏」菜单（菜单文案改为「诚心供奉」避免「打赏」关联收款语义）照常打开弹窗
- WCAG 检查清单照旧走一遍（弹窗底 #1a1a0a，米色 alpha≥0.5、金色 alpha≥0.6、钮上深字实色）

## 3. 支付服务改造（打赏 → 解签买断）

方案 A：改造现有 `IPaymentService`/`IapPaymentService`，不新建服务、不留打赏死代码。

### 3.1 IPaymentService.ets

删除打赏专属类型与常量：`TipProduct`、`TipPurchaseResult`、`TIP_PRODUCTS`、`ITipPaymentService`。改为：

```ts
/** 解签买断商品（AGC 控制台非消耗型商品 jieqian_unlock 唯一对应） */
export interface UnlockProduct {
  productId: string   // 'jieqian_unlock'
  amount: number      // 0.9（AGC 无 0.9 档则落 1，客户端标签同步改）
  label: string       // 永久解锁解签
}

export const UNLOCK_PRODUCT: UnlockProduct = { productId: 'jieqian_unlock', amount: 0.9, label: '永久解锁解签' }

export interface UnlockPurchaseResult {
  success: boolean
  canceled: boolean
  purchaseToken: string   // 幂等去重键（云端 record）
  orderId: string         // purchaseOrderId（SignUnlock 主键）
  purchaseData: string    // 华为签名原文（存证）
}

export interface IUnlockService {
  getProduct(): UnlockProduct
  purchase(): Promise<UnlockPurchaseResult>   // 拉起收银台买断
  isOwned(): Promise<boolean>                 // queryPurchases(NONCONSUMABLE, FINISHED) 恢复权益
}
```

`PaymentError`/`PaymentErrorKind` 保留（NEED_LOGIN/REGION/PRODUCT 三种；RETRY_AFTER_COMPLETE 删除——非消耗型无「未消耗订单」概念，无 1001860051 重试场景）。

### 3.2 IapPaymentService.ets

- `purchase()`：`createPurchase({ productId: UNLOCK_PRODUCT.productId, productType: NONCONSUMABLE, developerPayload: getDeviceUid() })`；取消 1001860000 静默返回 canceled；1001860007 商品未发布 → PRODUCT 错误；解析 purchaseData 逻辑（JWS 载荷）原样复用
- **删除**：`finishPurchase`、`completePendingOrders`、`amountOf`（白名单金额表）、CONSUMABLE 相关分支
- **新增** `isOwned()`：`queryPurchases({ productType: NONCONSUMABLE, queryType: CURRENT_ENTITLEMENT })` → purchaseDataList 非空即已购（华为帐号权益，换机/重装可恢复）。注：本机 SDK `PurchaseQueryType` 实测为 `ALL=0 / UNFINISHED=1 / CURRENT_ENTITLEMENT=2`，无 `FINISHED`；CURRENT_ENTITLEMENT（每商品最新已拥有订单）即权益恢复语义

## 4. 解签付费锁（QiuQian.ets）

### 4.1 锁定态 UI（SignDetailOverlay）

- 未解锁时：`解签：…` 与 `今日建议：…` 两段替换为锁占位卡片：
  - 文案「🔒 解签文已锁」+ 副文案「¥0.9 买断 · 一次解锁永久畅看」
  - 金钮「🔓 永久解锁」→ 拉起收银台
- 解锁后：显示完整 interpretation/advice（现有样式），此后永久免锁
- 复制签文按钮：锁定态 `.enabled(false)` + 文案「🔒 解锁后可复制」（按钮压暗态需检查 WCAG，禁用态用 enabled 而非压暗，参照 TipModal 旧实现注释）
- 去祈福按钮不受影响

### 4.2 解锁流程

```
点击解锁 → IapPaymentService.purchase()
   ├─ 成功 → 本地 Preferences 写 jieqianUnlocked=true（立即生效，UI 刷新）
   │        → CloudService.recordSignUnlock（异步，失败不阻塞解锁；
   │          重装/换机后由 isOwned() 兜底恢复 + 幂等补记）
   ├─ 取消   → 静默返回，锁占位不变
   └─ 错误   → 复用错误表（未登录 → 系统设置指引；地区/商品未发布 → toast）
```

### 4.3 权益状态

- 主权益源：本地 Preferences 标志 `jieqianUnlocked`，存 **`mashen_user_prefs`**（与 deviceUserId 同文件，EntryAbility 恢复逻辑复用同一 prefs 句柄）
- 恢复路径：
  1. QiuQian 页 `aboutToAppear`：读本地标志 → 已解锁直接显示
  2. 未解锁时页面打开详情/启动时调 `isOwned()` → 已购 → 置本地标志 + 云端幂等补记
- 新 VM：`QiuQianViewModel` 增加 `isUnlocked`/`setUnlocked`（preferences 持久化），页面经 `syncFromVM` 同步

## 5. 云端

### 5.1 Cloud DB 新表 `SignUnlock`（解锁流水，schema 对齐规范：ISO 字符串、无多余字段）

| 字段 | 类型 | 说明 |
|---|---|---|
| id | String (PK) | 用 purchaseOrderId |
| uid | String | __uid（设备匿名 ID） |
| productId | String | jieqian_unlock |
| purchaseToken | String | 幂等去重键 |
| purchaseData | String | 原文存证（未来 verify 用） |
| createdAt | String (ISO) | |

### 5.2 新云函数 `jieqian-unlock`

复用 `shared/response|auth|db` 模板（wrapHttp、extractBody、getUid、toGenericObjects、createInstance 唯一 name、handler.js 导出 myHandler、zip 含 node_modules）：

- `action=record`：按 purchaseToken 幂等（同 token 只记一条）→ upsert → 返回 `{ unlocked: true }`
- `action=query`：查该 uid 是否有记录 → 返回 `{ unlocked: bool }`
- 校验：`productId === 'jieqian_unlock'` 才记账（白名单外直接拒绝）

### 5.3 CloudService.ets

- **删除**：`recordDonation`、`getMyMerit`（及 `DonationParams`/`MeritInfo` 相关类型，`EnrichTypes.ets` 同步清理）
- **新增**：`recordSignUnlock(params)`（成功返回 bool）、`getSignUnlockStatus()`（返回 bool，失败返回 false）

### 5.4 AGC 控制台手动配置

- 新建非消耗型商品：productId `jieqian_unlock`、价格 ¥0.9（无 0.9 档则 ¥1）、地区发布
- Cloud DB 新建对象类型 `SignUnlock`（字段见 5.1）
- 部署云函数 `jieqian-unlock`（kebab-case，Node.js 18，HTTP 触发器）
- 旧商品 tip_06/6/18/66/88、旧表 Donation/UserMerit、旧函数 donation-record 不下架不删除（停止调用即可，避免误伤历史数据）

## 6. 时序与防漏单

非消耗型无「记账在消耗前」约束（无消耗动作），时序简化为：

```
支付成功 → 本地置位（立即生效，UI 即刻解锁）
        → 云端 record（幂等；失败仅记日志，权益不受影响）
启动/重装/换机 → isOwned() = queryPurchases(CURRENT_ENTITLEMENT) 非空
        → 置本地标志 + 云端幂等补记
```

EntryAbility 启动补单逻辑从「completePendingOrders（消耗型）」替换为「isOwned() 恢复非消耗型权益」。

## 7. 错误处理

| 场景 | 处理 |
|---|---|
| 用户取消（1001860000） | 静默返回 canceled，锁占位不变 |
| 未登录华为帐号（1001860050） | toast「解锁需登录华为帐号，请在系统设置中登录后重试」 |
| 地区不支持（1001860054） | toast「当前地区暂不支持」 |
| 商品未发布（1001860007） | toast「解锁服务准备中」 |
| 网络/其他错误 | toast「购买失败请重试」 |
| 云端 record 失败 | 不阻塞解锁；本地标志已生效，isOwned 兜底补记 |

## 8. 测试方案

- **沙箱**：AGC 配沙箱测试帐号 + debug 签名，`isSandboxActivated` 确认
- **用例**：
  - 买断成功 → 解签/建议立即显示，锁占位消失
  - 重启 App → 解锁保留（本地标志落盘）
  - 重装（同华为帐号）→ `isOwned()` 恢复解锁
  - 取消支付 → 保持锁定，无异常
  - 未登录华为帐号 → 引导提示，不崩
  - 云端 record 断网 → 本地仍解锁，网络恢复后 isOwned 补记
  - 重复 record（同 purchaseToken）→ 幂等不双记
  - 免费供奉：弹窗无任何金额/支付元素，关闭正常
  - 锁定态复制按钮禁用、去祈福不受影响
- **UI**：真机跑通后截图，按 WCAG 规则复查锁定态占位与禁用按钮配色

## 9. 明确不做（YAGNI）

- 按次付费/次数包（定价模型已定买断）
- 服务端票据校验 `verify`（purchaseData 已存证，上线后续补）
- 跨设备解锁迁移（uid 是设备匿名 ID，非账号体系；换机靠华为 IAP isOwned 恢复）
- 删除旧打赏云端资源（表/商品/函数保留，停止调用）
- 供奉台恢复任何收款入口
