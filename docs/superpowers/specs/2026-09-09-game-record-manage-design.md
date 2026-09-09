# 牌局记录：长按修改/删除（含云端删除同步）设计

日期：2026-09-09
状态：已评审通过（2026-09-09）
关联：牌局记录云备份（P1）——[CloudService.ets](../../entry/src/main/ets/service/CloudService.ets) / [EnrichViewModel.ets](../../entry/src/main/ets/viewmodels/EnrichViewModel.ets) / `cloud/game-record-backup/handler.js`

## 背景与问题

1. 牌局记录目前只有"记录牌局"加一笔，**没有任何删除/修改入口**：记错输赢、金额、多记一笔都无法修正。
2. 现有云同步是"只增不删"：全量 push 幂等 upsert。若只删本地，云端残留旧行会在下次 `startCloudSync` 的 pull 合并时**复活**（pull 会把"云端有、本地缺"的日期补回本地）。因此删除必须同步到云端并防复活。
3. 列表结构：**按天分组的卡片（DayCard），卡内每行 = 一笔（GameResult）**；Cloud DB `GameBackup` 一行 = (userId, date)，`games` 字段为该日全部笔数的 JSON 数组。

## 交互设计（沿用 HistoryPanel 长按惯例）

| 位置 | 手势 | 行为 |
|---|---|---|
| 单笔行 | 长按 | 弹出深色底部菜单：`✎ 修改这笔` / `🗑 删除这笔` |
| 菜单→修改 | 点击 | 打开预填弹窗（同"记录牌局"弹窗样式：赢/输/平 + 金额），确认后本地更新 + 全量 push 覆盖云端 |
| 菜单→删除 | 点击 | `showDialog` 红字确认 → 删这一笔；若当天只剩这一笔 → 走整日删除语义 |
| 整日卡 | 长按 | `showDialog` 确认「删除当天全部 N 笔记录？」→ 整日删除 |
| 明细标题下 | — | 淡色提示一行：「长按单笔可修改/删除」 |

视觉：全部沿用现有深色底 #1a1a0a 弹层与金边风格；文字对比度按 wcag-contrast 规则（菜单/弹窗文字 ≥4.5:1，红字删除用实色 #e74c3c）。

## 数据模型

本地 `GameRecord`（每用户每天一条）不变。新增**墓碑**状态：

```
KEY_DELETED_GAME_DATES = 'deletedGameDates'   // string[]，格式 'YYYY-MM-DD'
```

- 整日删除 / 删到当天没笔 → 该日期进墓碑
- 编辑或删单笔（天仍存在）→ **不进墓碑**（行内容变化由全量 push upsert 覆盖）
- 墓碑持久化在既有 `mashen_enrich_prefs`（与 gameRecords 同 preferences 实例）

## 变更清单

### 1. EnrichViewModel（全部不可变更新，复用既有 pattern）

- `KEY_DELETED_GAME_DATES` 常量 + `deletedGameDates: string[]` 字段 + loadPrefs/persist 读写
- `updateGame(date, idx, result, magnitude)`：重建该日 games 数组 → persist → rev++ → refreshAchievements → queueBackup
- `deleteGame(date, idx)`：games 长度 1 → 走 `deleteDate`；否则重建去除该笔 → 同上副作用
- `deleteDate(date)`：从 gameRecords 移除 → 日期入墓碑（去重）→ persist → rev++ → refreshAchievements → **立即异步尝试云端 delete**（失败仅 log，靠启动同步补偿）
- `startCloudSync` 改造（防复活核心）：
  1. pull 云端记录
  2. 滤掉 `deletedGameDates` 里的日期 → 不参与合并回本地
  3. 云端仍残留墓碑日期 → 调云端 delete 补偿（失败保墓碑，下次再试）
  4. 云端已无该日期的墓碑 → 从墓碑清理（自愈不累积）
  5. 其余逻辑不变（missing 合并 + 全量 push）

### 2. CloudService

- `deleteGameRecordBackup(dates: string[]): Promise<boolean>`：`cloudFunction.call({ name: 'game-record-backup', data: { action: 'delete', dates, __uid } })`

### 3. 云函数 game-record-backup（handler.js 扩展，不动 schema）

- switch 加 `case 'delete'`：
  - 校验：dates 为数组、每项匹配 `^\d{4}-\d{2}-\d{2}$`、数量 ≤ 50；无 uid → 401
  - 逐日期：`withTimeout(query().equalTo('date', d).limit(100).get())`（走既有 date 索引）→ 过滤 `userId === uid` → 用**查询返回的完整对象** `delete(rows)`（沿用 wish-wall 删除红线：仅含 id 的新对象无法定位记录）
  - 返回 `{ deleted: n }`
- 全部走 wrapHttp / withTimeout / try-catch + log，与现有分支同风格

### 4. GameRecordDetailList（UI 改动集中处）

- 明细标题下加提示行
- DayCard：`.gesture(LongPressGesture)` → 删除当天确认 dialog
- GameRow：`.gesture(LongPressGesture)` → 深色底部菜单弹层（`修改这笔`/`删除这笔`）
  - 修改：预填编辑弹窗（输赢/平三段 + 金额输入，样式同 GameRecordCard.RecordDialog）→ `updateGame`
  - 删除：红字确认 dialog → `deleteGame`
- 新增局部 @State：被长按的 `{date, idx}`、菜单显隐、编辑弹窗显隐与预填值；`gameRecordsRev` 已混入 ForEach key，删除/修改后行自动重建
- 弹层/弹窗阻止穿透（onClick 空实现）与 RecordDialog 一致

## 不做的事（YAGNI）

- 备注（note）字段无 UI，不加编辑入口
- 不做撤销、滑动删除、整日记录的金额合并修改
- 不支持多设备同 uid 冲突消解（单机场景，墓碑按全局 uid 语义已够）

## 边界与错误处理

- **离线删除**：本地立即生效；云端 delete 失败仅 log → 下次冷启动 pull 发现墓碑日期仍残留云端时补偿删除（若失败保墓碑继续等下一次）
- **云端 delete 与 push 竞态**：push 只含现存日期，不含墓碑日期；墓碑日期永远不被推回 → 无复活窗口
- **墓碑自愈**：远端已无该日期（补偿已生效/从未存在）→ 清理墓碑，避免无限累积
- **同日重复长按**：菜单弹层互斥（一次只开一个），防穿透

## 验证

1. 云函数：stub 冒烟测试（delete 只删本人、无效日期 400、非本人行不动、完整对象删除路径、无 uid 401）→ `node cloud/deploy.cjs game-record-backup` 重打 zip，确认非空且含 handler.js
2. ArkTS 编译：hvigorw 构建通过
3. 真机手测清单：
   - 长按单笔 → 修改金额 → 汇总与明细刷新、云端行内容更新
   - 长按单笔 → 删除 → 行消失；删光当天 → 整卡消失
   - 长按整日卡 → 删除当天 → 云端行删除
   - **断网删除 → 联网重启 → 记录不复活**（墓碑补偿生效）
   - 对比度：菜单/弹窗文字不破 WCAG 阈值
