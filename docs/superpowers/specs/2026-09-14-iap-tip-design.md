# 供奉麻神 · 应用内付款（IAP）打赏设计

> 日期：2026-09-14
> 状态：已确认（方案一：供奉弹窗直购）
> 目标：把「🧧 供奉麻神」从微信收款二维码改为华为 AGC 应用内付费，云端累计功德，未来解锁次数限制

## 1. 背景与目标

现状：`TipModal`（`entry/src/main/ets/components/TipModal.ets`）展示微信收款二维码，由祈福结算页 `BlessingCard` 的「🧧 供奉麻神」按钮触发。底层已有 `IPaymentService` 抽象（`service/IPaymentService.ets`），实现为 `QrCodePayment`。

动机：
- **审核合规**：AppGallery 明确要求虚拟商品/打赏必须走华为 IAP，禁止第三方收款二维码（本项目此前被 3.5 拒审，与此相关）
- **体验闭环**：扫码支付断裂感强，应用内直付 + 云端功德记录形成完整「供奉」仪式感
- **扩展性**：为未来「累计功德解锁限制」（如每日抽签 +1）打好数据地基

范围（v1）：5 档固定金额直购 + 云端「打赏流水 + 累计功德」+ 供奉弹窗 UI 重设计。
**不做**：功德榜、解锁判定、服务端票据校验（v1 仅存证，接口留扩展位）。

## 2. 关键 API 事实（基于本机 DevEco SDK `@hms.core.iap.d.ts`）

- 下单 API：`iap.createPurchase(context, PurchaseParameter): Promise<CreatePurchaseResult>`（**不是** `createOrderWithProductId`）。`PurchaseParameter`：`productId`、`productType`（CONSUMABLE=0 / NONCONSUMABLE=1 / SUBSCRIPTION=2）、可选 `developerPayload`、`reservedInfo`、`quantity`（API15+）。调用即拉起华为收银台，结果以 Promise 返回；用户取消抛 `BusinessError 1001860000`
- 定价：仅支持 AGC 控制台预配置固定价格，**无自定义金额入口** → 每档金额 = 一个 productId
- 发货：支付成功后必须 `iap.finishPurchase(context, { productType, purchaseToken, purchaseOrderId })` 确认消耗（旧 `consumePurchase` 已废弃）。`purchaseData` 为华为签名 JSON，`purchaseToken`/`purchaseOrderId` 从中解析
- 补单：启动时 `iap.queryPurchases({ productType })`（queryType 默认 UNFINISHED）返回未完成订单，防漏单
- 前置检查：`iap.queryEnvironmentStatus(context)` 校验华为帐号登录与地区支持；未登录抛 `1001860050`；地区不支持 `1001860054`；商品未发布 `1001860007`
- 沙箱：debug 签名 profile（1001860057）+ AGC 配置的沙箱测试华为 ID（1001860058），可调 `iap.isSandboxActivated(context)` 检测
- 华为帐号：IAP 依赖**设备系统级华为帐号**（与 AGC Auth 无关，App 无登录步骤不影响）。未登录时可用 **Account Kit（@kit.AccountKit）** `authentication.executeAuthorizationRequest(context, [{ action: AuthenticationAction.SIGN_IN }])` 引导登录（签名以 developer.huawei.com 文档为准）

## 3. AGC 控制台配置（一次性手动）

- 开通「应用内购买服务」
- 创建 5 个**消耗型商品**：

| productId | 价格 | 界面标签 |
|---|---|---|
| `tip_06` | ¥0.60 | 小小心意 |
| `tip_6` | ¥6.00 | 顺顺供奉 |
| `tip_18` | ¥18.00 | 财运供奉 |
| `tip_66` | ¥66.00 | 大吉供奉 |
| `tip_88` | ¥88.00 | 至尊供奉 |

- 配置沙箱测试帐号（华为 ID）+ 使用 debug 签名 profile 联调
- **正式支付需 App 上架、商品在对应地区发布后生效**（1001860007）

## 4. 客户端支付服务 `IapPaymentService`

替换 `QrCodePayment`，重写接口（`IPaymentService.ets`）：

```ts
interface TipProduct { productId: string; amount: number; label: string }
interface TipPurchaseResult {
  success: boolean; canceled: boolean; productId: string;
  amount: number; purchaseToken: string; orderId: string;
}
interface ITipPaymentService {
  getProducts(): TipProduct[]
  purchase(productId: string): Promise<TipPurchaseResult>
}
```

购买流程（`IapPaymentService` 内部）：

```
purchase(productId)
  ① queryEnvironmentStatus
     ├─ 1001860050 未登录 → 抛 NEED_LOGIN（由 UI 引导 Account Kit 登录后重试）
     └─ 通过 → ② queryProducts 拉真实价格
  ③ createPurchase({ productId, productType: CONSUMABLE, developerPayload: uid })
     ├─ 成功 → 解析 result.purchaseData → purchaseToken / purchaseOrderId / amount
     ├─ 1001860000 取消 → 返回 canceled
     └─ 其他错误 → 抛错由 UI toast
  ④ 返回结果（UI 层负责：先上报云端，成功后才 finishPurchase）
```

**防漏单**：EntryAbility 启动时 `iap.queryPurchases({ productType: CONSUMABLE })`，对未完成订单补「finishPurchase + 上报云端」（幂等）。

## 5. 云端记录时序（自愈闭环，防丢单/防双记）

```
createPurchase 成功 → 解析 purchaseData
   → ① 先上报云端 donation-record（幂等：按 purchaseToken 去重）
        ├─ 成功 → ② 再调 finishPurchase 确认消耗
        └─ 失败 → 不调 finishPurchase，订单保持「未完成」，
                  purchaseData 缓存本地 Preferences 兜底
                     ↓
        下次启动 queryPurchases 发现未完成订单 → 补记账（幂等）→ finishPurchase
```

原则：**记账在消耗之前**——云端没记上绝不消耗，订单永远留得住；幂等保证补单/重试不双记。

## 6. TipModal 重设计（供奉台，深色金边）

- 顶部：红色装饰条 + 「✦ 供奉麻神 ✦」+「心诚则灵 · 福报自来」
- 5 张金元宝金额卡（金额金色大字 + 文化小标签 + 选中金边高亮）
- 「我的累计功德」显示区（云端 `action=query` 拉取，本地缓存兜底）
- 确认供奉按钮：金色实底 `#f9ca24` + 深字 `#1a1a0a`（遵循 WCAG 规则）
- 支付成功：弹窗内烟花粒子 + 「功德 +N」滚动动画 + 「功德已记入云簿」
- 移除：二维码 Image、SaveButton、扫码提示文案；保留关闭按钮
- 失败：toast 提示，弹窗不关可重试
- 未登录华为帐号：弹提示「供奉需登录华为帐号」→ Account Kit 引导登录 → 重试

## 7. 云端数据模型（Cloud DB + 云函数）

**Cloud DB 两张表**（遵循既有 schema 对齐规范：updatedAt 用 ISO 字符串、无多余字段）：

`Donation`（打赏流水）
| 字段 | 类型 | 说明 |
|---|---|---|
| id | String (PK) | 用 purchaseOrderId |
| uid | String | __uid |
| productId | String | tip_06 等 |
| amount | Double | 0.6/6/18/66/88 |
| purchaseToken | String | 幂等去重键 |
| purchaseData | String | 原文存证（未来校验/回滚） |
| status | String | 默认 'done'，未来可为 'verified'/'revoked' |
| createdAt | String (ISO) | |

`UserMerit`（累计功德）
| 字段 | 类型 | 说明 |
|---|---|---|
| uid | String (PK) | |
| totalAmount | Double | 累计金额 |
| totalCount | Integer | 供奉次数 |
| updatedAt | String (ISO) | |

**云函数 `donation-record`**（kebab-case，handler.js 导出 myHandler，复用 shared/response|auth|db 模板）：
- `action=record`：上报打赏 → 幂等（同 purchaseToken 只记一次）→ upsert 累计功德 → 返回 `{totalAmount, totalCount}`
- `action=query`：拉取我的累计功德 → 返回 `{totalAmount, totalCount}`
- **扩展位已留**：`purchaseData` 落库 + developerPayload 带 uid → 未来加 `action=verify`（服务端票据校验）、`action=entitle`（解锁判定），只增不改

**客户端 `CloudService` 新增**：`recordDonation(...)`、`getMyMerit()`。

## 8. 错误处理

| 场景 | 处理 |
|---|---|
| 用户取消（1001860000） | 静默返回 canceled，弹窗不关 |
| 未登录华为帐号（1001860050） | 弹提示 → Account Kit 引导登录 → 重试 |
| 地区不支持（1001860054） | toast「当前地区暂不支持」 |
| 商品未发布（1001860007） | toast「供奉服务准备中」 |
| 网络/其他错误 | toast「支付失败请重试」，弹窗不关 |
| 云端上报失败 | 不 finishPurchase，本地缓存待上报，启动补单重试 |
| 启动补单 | queryPurchases 未完成订单 → 补记账（幂等）→ finishPurchase |

## 9. 测试方案

- **沙箱**：AGC 配沙箱测试帐号 + debug 签名 → `isSandboxActivated` 确认
- **用例**：
  - 5 档正常购买 → 功德 +N → 云端 query 一致
  - 取消支付 → 无记录、功德不变
  - 断网：支付成功但上报失败 → 重启后补单到账（不丢不重）
  - 重复上报（同 purchaseToken）→ 幂等不双记
  - App 被杀后启动 → 未完成订单补发货
  - 未登录系统华为帐号 → 引导登录流程
  - 杀死进程后重进 → 功德/流水仍在（flush 落盘）
- **UI**：真机跑通后截图，按 WCAG 规则复查供奉弹窗新配色

## 10. 明确不做（YAGNI）

- 功德榜/金主榜（后续迭代）
- 解锁判定 `entitle`（接口留位，逻辑以后加）
- 服务端票据校验 `verify`（purchaseData 已存证，上线解锁前必须补）
- 自定义金额（IAP 无此能力，固定档位）
