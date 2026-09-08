# 麻神祈福 APP 功能丰富度增强设计

> 状态：已确认 | 日期：2026-08-19 | 目标：通过华为应用市场审核（审核指南 3.5 项）

## 背景

当前应用仅有一条功能线：选神像→叩拜→祈福→得祝福语。用户 1-2 分钟体验完所有功能，缺乏持续使用价值。华为审核认为功能场景覆盖不足。

## 核心用户

麻将爱好者——打麻将前祈福求好运，主打"牌运"场景。

## 设计目标

将应用从"单次祈福工具"升级为"麻将人的随身祈福工具箱"，形成**祈福→打牌→记录→还愿→排行**的完整闭环。

---

## 架构变更

### 导航重构：线性流程 → 4 Tab 底部导航

```
首页（Tab 容器）
├── Tab 1: 祈福广场（原 HomePage 改造）
│   ├── 今日麻将黄历（新增）
│   ├── 五神弧形阵（保留）
│   └── 开始祈福 → 姓名 → 叩拜 → 祝福（保留原流程，Tab 内 pushUrl）
│
├── Tab 2: 心愿墙（新增）
│   ├── 全网心愿列表（AGC Cloud DB）
│   ├── 发布心愿
│   └── 还愿标记
│
├── Tab 3: 排行榜（新增）
│   ├── 祈福次数榜（日/周/总）
│   ├── 连续签到榜
│   └── 我的排名高亮
│
└── Tab 4: 我的（新增）
    ├── 顶部签到卡（含核心统计）
    ├── 祈福日记（合并原历史记录）
    ├── 牌运记录（+/· 表达）
    └── 成就徽章
```

原 4 个页面（HomePage/NameCard/PrayerCard/BlessingCard）保留，在 Tab 1 内通过 `router.pushUrl`/`replaceUrl` 完成，不干扰 Tab 切换。

---

## 新增功能详细设计

### 1. 今日麻将黄历

位置：祈福广场顶部，五神阵上方。

显示内容：
- 今日主神（由 DeityRotator 决定）
- 吉位（坐东朝西等，每日轮换）
- 幸运花色（条/筒/万，每日轮换）
- 忌：心浮气躁、贪大胡
- 宜：稳扎稳打、见好就收
- 今日香火：🔥🔥🔥🔥 (N 人已祈福)

数据来源：吉位和花色预定义 30 天轮换表，今日香火从 Cloud DB 查询。

---

### 2. 签到系统

融入麻将元素，7 天一个周期：

```
第 1 天：🀇 一条   第 2 天：🀈 二条   第 3 天：🀉 三条
第 4 天：🀊 四条   第 5 天：🀋 五条   第 6 天：🀌 六条
第 7 天：🀍 七条（大礼：香火值×2）
```

断签 → 从一条重新开始。连续签到累计香火值。

---

### 3. 祈福日记

合并原历史记录功能。每次祈福自动生成一条记录，包含：
- 日期、时间
- 拜的财神
- 磕头次数
- 祝福语正文
- 用户可补充备注（如"老王家"）

页面改造：原 HistoryPanel 组件迁移至 Tab 4 内，改为内嵌列表（非覆盖层），保留 LazyForEach 懒加载。

---

### 4. 牌运记录

用麻将语境隐晦表达输赢：

| 输入 | 含义 | 显示 |
|------|------|------|
| `+` 数字 | 赢了 | `+3` |
| `·` 数字 | 输了/平了 | `·2` |

数字 1-9 代表大致幅度，不涉及精确金额。

记录卡片样式：
```
📅 8月19日 周三
拜了 赵公明（中路财神）· 磕头 9 次

牌局：+ + · + · + +
      3 8 2 5 4 6 7

备注：老王家，手气不错
```

统计面板（在签到卡中展示）：
- 本周牌运符号串
- 祈福胜率（+ 场次 / 总场次）
- 最佳财神（拜后胜率最高的财神）

---

### 5. 成就徽章

| 徽章 | 条件 | 图标 |
|------|------|------|
| 初入牌局 | 完成首次祈福 | 🀄 |
| 百拜成金 | 累计磕头 100 次 | 🏅 |
| 虔诚信徒 | 连续签到 7 天 | 🔥 |
| 五路通拜 | 拜过所有 5 位财神 | 🌟 |
| 大杀四方 | 单日记录 5 场以上 `+` | 🀇 |
| 常胜将军 | 祈福胜率超 70%（≥10 场） | 👑 |
| 心诚则灵 | 发布并还愿 3 个心愿 | ✨ |
| 日榜第一 | 曾登上日祈福榜榜首 | 🏆 |

---

### 6. 祈福排行榜

**数据源：** AGC Cloud DB，祈福时云函数写入计数。

**榜单类型：**
- 日榜：今日祈福次数排名
- 周榜：本周祈福次数排名
- 总榜：累计祈福次数排名

**显示内容：**
- 前 50 名列表：排名、昵称（脱敏显示）、祈福次数、磕头总数
- 当前用户排名高亮（始终可见，如在榜外显示"第 N 名"）

**云函数：**
- `update-prayer-count`：祈福完成后调用，写入 Cloud DB
- `get-leaderboard`：查询排行榜，支持日/周/总 + 分页

**隐私：** 昵称取用户姓名首字 + `***`（如"张***"），不暴露完整姓名。

---

### 7. 心愿墙

**数据源：** AGC Cloud DB

**功能：**
- 发布心愿：输入心愿文字（限 30 字），可关联特定财神
- 心愿列表：按时间倒序，显示心愿内容、发布者（脱敏）、时间、还愿状态
- 还愿：用户可标记自己的心愿为"已达成"，显示还愿标记

**云函数：**
- `wish-wall`：处理心愿 CRUD（list/create/fulfill）

---

## 数据架构

### 本地存储（Preferences）

| Key | 内容 | 类型 |
|-----|------|------|
| `checkin` | `{ lastDate, streak, totalValue }` | JSON |
| `gameRecords` | `[{ date, deityId, games: [{result, magnitude}], note }]` | JSON |
| `achievements` | `{ badgeId: unlockDate }` | JSON |
| `diaryNotes` | `{ recordId: note }` | JSON |
| 原 `recentNames` | 保留 | — |
| 原 `prayerHistory` | 保留（祈福日记数据源） | — |
| 原 `totalPrayers` | 保留 | — |

### AGC Cloud DB（新增对象类型）

**Leaderboard 表：**
| 字段 | 类型 | 说明 |
|------|------|------|
| `userId` | String (PK) | 用户标识 |
| `nickname` | String | 脱敏昵称 |
| `todayCount` | Integer | 今日祈福次数 |
| `weekCount` | Integer | 本周祈福次数 |
| `totalCount` | Integer | 总祈福次数 |
| `totalKowtow` | Integer | 总磕头次数 |
| `streak` | Integer | 连续签到天数 |
| `updatedAt` | String | 更新时间 |

**Wish 表：**
| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | String (PK) | 心愿 ID |
| `userId` | String | 发布者 |
| `nickname` | String | 脱敏昵称 |
| `content` | String | 心愿内容 |
| `deityId` | Integer | 关联财神 |
| `fulfilled` | Bool | 是否还愿 |
| `createdAt` | String | 创建时间 |
| `fulfilledAt` | String | 还愿时间 |

### 云函数

| 函数名 | 用途 | 触发器 |
|--------|------|--------|
| `update-prayer-count` | 祈福后更新排行榜计数 | HTTP |
| `get-leaderboard` | 查询排行榜 | HTTP |
| `wish-wall` | 心愿 CRUD | HTTP |

---

## 页面改造清单

### 新增文件

| 文件 | 说明 |
|------|------|
| `pages/MainTabs.ets` | 新 Tab 容器页，替代 HomePage 为入口 |
| `pages/WishWall.ets` | 心愿墙页面 |
| `pages/Leaderboard.ets` | 排行榜页面 |
| `pages/MyPage.ets` | 我的页面 |
| `components/DailyAlmanac.ets` | 今日麻将黄历卡片 |
| `components/CheckinCard.ets` | 签到卡片（含统计数字） |
| `components/GameRecordCard.ets` | 牌运记录卡片 |
| `components/AchievementGrid.ets` | 成就徽章网格 |
| `components/WishItem.ets` | 心愿列表项 |
| `components/LeaderboardItem.ets` | 排行榜列表项 |
| `model/EnrichTypes.ets` | 新功能的类型定义 |
| `viewmodels/EnrichViewModel.ets` | 新功能的状态管理 |
| `service/CloudService.ets` | 云函数调用封装 |

### 修改文件

| 文件 | 改动 |
|------|------|
| `pages/HomePage.ets` | 改为 Tab 1 内容，顶部加黄历，保留五神阵和开始祈福按钮 |
| `components/HistoryPanel.ets` | 迁移逻辑到祈福日记，原组件可删除或重构 |
| `viewmodels/PrayerViewModel.ets` | 祈福完成后触发排行榜更新 |
| `entryability/EntryAbility.ets` | 初始化 EnrichViewModel |
| `model/PrayerTypes.ets` | 新增类型定义 |
| `AppScope/app.json5` | 可能需更新版本号 |

---

## 实现顺序

1. **主框架**：Tab 容器 + 4 个 Tab 页面骨架
2. **签到 + 统计**：纯本地，无依赖
3. **祈福日记**：迁移历史记录 + 加备注
4. **牌运记录**：本地存储 + UI
5. **成就徽章**：本地判断逻辑
6. **今日黄历**：本地数据 + 简单 UI
7. **排行榜**：Cloud DB + 云函数
8. **心愿墙**：Cloud DB + 云函数

---

## 风险与约束

- Cloud DB 新增对象类型需在 AGC 控制台手动创建 schema
- 云函数需遵循 `agc-cloud-function.md` 规范（handler.js、shared/、node_modules 打包）
- 排行榜写入需在祈福完成回调中异步触发，不阻塞 UI
- 首次使用无网络时排行榜和心愿墙显示空状态，不影响核心祈福流程