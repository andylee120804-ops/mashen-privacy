# 桌面服务卡片设计：每日求签 + 敲木鱼

> 日期：2026-10-02
> 状态：设计已确认，待实现计划
> 背景：用户希望把 App 功能以「服务卡片」形式放到桌面，实现快速抽签 / 敲木鱼，并引导解签付费。HarmonyOS 服务卡片 = FormExtensionAbility（数据源）+ ArkTS 卡片 UI + form_config.json 声明。

## 1. 目标与范围

新增**两张桌面卡片**（用户可在桌面长按 → 服务卡片里分别添加不同卡片）：

| 卡片 | 尺寸 | 核心交互 |
|---|---|---|
| 每日求签 | 2×2 + 2×4 两档 | 点「抽一签」本地真抽签；点「解签」跳 App 付费解签；点「签录」跳求签页 |
| 敲木鱼 | 2×2（仅此一档） | 点卡片敲一下 → 功德计数 +1（与 App 同一计数）；点「木鱼」跳木鱼页 |

**关键产品约束**：解签文（interpretation/advice）是付费内容，卡片**绝不展示**，只展示等级 + 签名 + 签诗（在 App 里签诗本免费）。

**不做**：卡片摇晃抽签（卡片无传感器权限，审核也禁后台占传感器）；按次付费；服务端票据校验。

## 2. 架构概览

```
桌面卡片（用户添加）                系统框架                     App（主进程）
┌───────────────┐   postCardAction    ┌─────────────────┐
│ SignCard2x2   │ ── message/router ─▶ │                 │
│ SignCard2x4   │                      │ FormExtension  │ ◀── 读写 preferences（与 App 共用）
│ MuyuCard2x2   │ ◀── updateForm ───── │ Ability         │
└───────────────┘                      │ (WidgetForm…  ) │
                                        └─────────────────┘
深链 router → App EntryAbility（onNewWant/onCreate）→ AppStorage flag → MainTabs 切 Tab
```

- **一个 FormExtensionAbility 服务三张卡片**：`onAddForm`/`onUpdateForm`/`onFormEvent` 里按 `formName`（`sign_2x2` / `sign_2x4` / `muyu_2x2`）分发。
- 卡片 UI 是**纯展示** ArkTS（只渲染 FormBindingData 注入的字段 + `postCardAction` 发交互），不放任何逻辑。
- 数据逻辑集中在扩展里，**复用 App 现有 VM 的持久化方法**，避免复制落盘代码。

## 3. 文件清单

### 新增

| 文件 | 作用 |
|---|---|
| `entry/src/main/ets/formability/WidgetFormAbility.ets` | 唯一数据源：抽签/敲木鱼、读写额度/功德、生成/刷新 FormBindingData |
| `entry/src/main/ets/widget/pages/SignCard2x2.ets` | 求签小卡 UI |
| `entry/src/main/ets/widget/pages/SignCard2x4.ets` | 求签中卡 UI |
| `entry/src/main/ets/widget/pages/MuyuCard2x2.ets` | 木鱼小卡 UI |
| `entry/src/main/ets/service/FormSyncService.ets` | App 侧：抽签/敲木鱼后 + 回前台，把最新状态推到所有卡片 |
| `entry/src/main/resources/base/profile/form_config.json` | 三张卡片的尺寸/名称/刷新策略声明 |

### 修改

| 文件 | 改动 |
|---|---|
| `entry/src/main/module.json5` | 新增 `extensionAbilities`（type=form）+ metadata 指向 form_config |
| `entry/src/main/ets/entryability/EntryAbility.ets` | `onCreate(want)` / 新增 `onNewWant(want)` 解析深链参数；`onForeground` 里 reload VM + 推卡片 |
| `entry/src/main/ets/pages/MainTabs.ets` | 读 AppStorage 深链 flag → 切 Tab → 通知目标页 |
| `entry/src/main/ets/viewmodels/QiuQianViewModel.ets` | 新增 `reload()`（重读额度/签录，供回前台同步）、`bestToday()`（今日最吉签） |
| `entry/src/main/ets/viewmodels/MuyuViewModel.ets` | 新增 `reload()`（重读今日/累计计数） |
| `entry/src/main/ets/pages/QiuQian.ets` | 深链到站后自动打开解签覆层；本地抽签成功后调 `FormSyncService` |
| `entry/src/main/ets/pages/MuyuPage.ets` | 敲击成功后调 `FormSyncService` |
| `entry/src/main/resources/base/element/string.json` | 卡片名/描述文案 |

## 4. 卡片 UI

沿用现有深底 `#1a1a0a` 与金/米色调。文字对比度遵守 WCAG 规则（正文米色 alpha≥0.5 / 金色≥0.6，等级徽章用 `LEVEL_COLOR` 实色）。

### 4.1 每日求签 2×2

```
┌───────────────────┐
│ 🎋 每日求签 · 第X签 │
│     上上签(金)      │
│     金榜题名        │
│  寒窗十载终不负，…  │
│  [ 抽一签 ] [ 解签 ] │
└───────────────────┘
```
- 「抽一签」→ `message {"action":"draw"}`（本地刷新，不出 App）
- 「解签」→ `router { route:'qiuqian', open:'unlock' }`

### 4.2 每日求签 2×4

```
┌─────────────────────────────────┐
│ 🎋 每日求签 · 第X签        [解签] │
│  上上签 · 金榜题名                │
│  寒窗十载终不负，金榜题名天下知    │
│  今日已抽 1/3                     │
│        [再抽一签]  [签录]         │
└─────────────────────────────────┘
```
- 信息更全：完整签诗 + 剩余额度提示 + 三个动作区（抽/解/录）。

### 4.3 敲木鱼 2×2

```
┌───────────────────┐
│   🪵  敲木鱼        │
│  今日功德  12       │
│  累计功德  3456     │
│  点我敲一下 · 咚     │
└───────────────────┘
```
- 整卡点击 → `message {"action":"knock"}` → 今日+1、累计+1（与 App 同一计数）
- 右上角小「木鱼」→ `router { route:'muyu' }`

## 5. 数据层与抽取/敲击规则

### 5.1 求签

- **默认展示（今日未抽）**：确定性每日签 `SIGN_TABLE[dayOfYear % 36]`（全用户同一天同签）。
- **抽过后**：展示今日已抽中最吉利签，等级序 `上上 > 上吉 > 中吉 > 中平 > 下`，同级取最新。
- **卡片抽签 = 真抽签**：`onFormEvent` 收到 draw → 复用 `QiuQianViewModel`（已存在的方法）：
  1. `canDraw()` 判断额度，满 3 则更新卡片为「已满 3 签」态
  2. `sign = SIGN_TABLE[floor(random*36)]`
  3. `consumeDraw()` 扣额度 + `addRecord(sign)` 写签录（同一份 `mashen_qiuqian_prefs`，键 `qiuDaily`/`qiuRecords`）
  4. `updateForm` 刷新卡片（新签 + 剩余额度）
- 等级→颜色复用 `LEVEL_COLOR`：上上 `#d4a017`、上吉 `#2ecc71`、中吉 `#3a8fd4`、中平 `#9a9a9a`、下 `#f0533f`。

### 5.2 敲木鱼

- 复用 `MuyuViewModel.knock()`（已存在）：跨日清零今日、今日+1、累计+1，写 `mashen_muyu_prefs`（键 `todayDate`/`todayCount`/`totalCount`）。
- 卡片与 App 共用同一计数，敲一下两处会话一致。

## 6. 交互路由

### 6.1 卡片内（message，不出 App）

- 求签：`postCardAction({ action:'message', params: JSON.stringify({action:'draw'}) })`
- 木鱼：`postCardAction({ action:'message', params: JSON.stringify({action:'knock'}) })`

### 6.2 跳 App（router + 深链）

- `postCardAction({ action:'router', abilityName:'EntryAbility', params: { route:'qiuqian', open:'unlock' } })`（解签）
- `params: { route:'qiuqian' }`（签录/再抽）
- `params: { route:'muyu' }`（木鱼页）
- App 侧：`EntryAbility.onCreate(want)` / `onNewWant(want)` → 读 `want.parameters.route/open` → 写 AppStorage `pendingRoute` / `pendingOpenUnlock` → `MainTabs` 起来后切到对应 Tab（`qiuqian` / `muyu`），`open:'unlock'` 时通知 QiuQian 页自动打开解签覆层（已解锁看详解、未解锁弹付费按钮）。

## 7. 刷新策略

- form_config：`updateEnabled:true`、`updateDuration:1`（30 分钟兜底）、`scheduledUpdateTime:"00:05"`（跨天轮换）。
- 卡片交互（draw/knock）→ `message` → 即时 `updateForm`。
- App 侧抽签/敲木鱼成功 + 回前台 → `FormSyncService` 调 `formProvider.updateForms` 把最新状态推给所有卡片。

## 8. 同步一致性（方案 A 的坑及对策）

- 扩展与 App **同进程**，读同一份 preferences，天然一致。
- 卡片抽签/敲击发生在 App 后台时 → App 回前台必须 `reload()` 重读额度/功德（列在修改项），否则显示旧值。
- App 侧变动后主动推卡片，保证卡片「最吉签 / 功德数」实时。
- 已知轻微边界：App 前台敲木鱼与卡片敲击理论上的并发写（preferences 自身有锁，丢一次计数概率极低，v1 接受）。

## 9. 付费与合规 / WCAG

- 卡片只放免费内容（等级/签名/签诗/功德数），interpretation/advice 绝不进卡片。
- 解签必须进 App 走消耗型 IAP（`jieqian_unlock`，现有的 `unlockJieqian()` 流程）。
- 深底卡片文字对比度按 `common/wcag-contrast.md` 阈值，等级徽章用 `LEVEL_COLOR` 实色，正文米色 alpha≥0.5。

## 10. 注册细节（待 build 对照已装 SDK 校准）

- `module.json5` 新增 `extensionAbilities`，项含 `type:"form"`、`srcEntry:"./ets/formability/WidgetFormAbility.ets"`、`metadata:[{ name:"ohos.extensions.form", resource:"$profile:form_config" }]`（metadata 名与字段名以 target 6.1.0(23) 实际 SDK 为准，build 阶段核对）。
- `form_config.json` 的 `forms` 数组三项：`sign_2x2`（supportDimensions `["2*2"]`，`isDefault:true`）、`sign_2x4`（`["2*4"]`）、`muyu_2x2`（`["2*2"]`），统一 `uiSyntax:"arkts"`、`formConfigAbility:"ability://WidgetFormAbility"`。
- ArkTS 卡片 UI 只用基础组件（Text/Row/Column/Stack/Button），不引动画/传感器/非白名单 API。

## 11. 明确不做（YAGNI）

- 卡片摇晃抽签
- 卡片直接展示解签付费内容 / 卡片内完成付费
- 微卡 1×2、大卡 4×4
- 服务端票据校验、跨设备同步
- 卡片定时频繁刷新（沿用 30 分钟兜底 + 事件驱动）

## 12. 测试方案

1. 构建：`hvigorw assembleApp`（--mode project，参照 build 环境 memory）。
2. 真机 USB 验证（本机模拟器起不来）：
   - 桌面长按 → 服务卡片列表出现「每日求签」「敲木鱼」两张，可分别添加
   - 求签卡：点抽一签 → 卡片出签 + 额度-1 → 满 3 后变「已满」→ 解签跳 App 付费 → 签录跳求签页
   - 求签卡跨天：默认签轮换
   - 木鱼卡：点一下 +1 → 打开 App 木鱼页计数一致 → App 敲后回桌面卡片同步
   - App 后台时卡片抽签/敲击 → App 回前台额度/功德已刷新
   - 深链冷启/热启两条路径（onCreate / onNewWant）都切对 Tab、解签自动弹付费
   - WCAG：复用既有的真机截图 + 对比度复查