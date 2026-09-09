# 牌局记录长按修改/删除（含云端删除同步）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 牌局记录页支持长按修改/删除单笔与整日记录，且删除与云端 GameBackup 双向一致（墓碑防复活）。

**Architecture:** 三层改动——云函数 `game-record-backup` handler 加 `delete` action（按 date 索引查 → 过滤 uid → 完整对象删除）；客户端 EnrichViewModel 加墓碑（已删日期 prefs 持久化）+ 不可变 update/delete 方法 + `startCloudSync` 滤墓碑/补偿云删；GameRecordPage/GameRecordDetailList 加 LongPressGesture 菜单与预填编辑弹窗。单笔内容修改走既有全量 push upsert 覆盖，无需云删。

**Tech Stack:** AGC Cloud Function（Node 18 CommonJS）；HarmonyOS ArkTS（UI v1 @State/@Builder/LongPressGesture、preferences）；验证用 node stub 冒烟 + `build-debug.bat`（`node hvigorw.js --mode module -p product=default -p buildMode=debug --no-daemon assembleHap`）。

**Spec:** `docs/superpowers/specs/2026-09-09-game-record-manage-design.md`

---

### Task 1: 云函数 handler 加 `delete` action（TDD + 重新打包）

**Files:**
- Create: `cloud/game-record-backup/smoke-delete.cjs`
- Modify: `cloud/game-record-backup/handler.js`（switch 的 `case 'push':` 之后、`default:` 之前加 `case 'delete':`）
- 产物：`cloud/game-record-backup/game-record-backup.zip`

- [ ] **Step 1: 写失败测试（stub 冒烟脚本，断言 delete 行为）**

创建 `cloud/game-record-backup/smoke-delete.cjs`，内容：

```javascript
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
```

- [ ] **Step 2: 运行测试确认失败**

Run: `node cloud/game-record-backup/smoke-delete.cjs`
Expected: `delete 无 __uid → 401` PASS（现有校验），其余 delete 断言 FAIL（`unknown action` 返回 400）——`delete` 分支不存在。

- [ ] **Step 3: 实现 `delete` 分支**

修改 `cloud/game-record-backup/handler.js`：在 `case 'push'` 的 `}` 之后、`default:` 之前插入：

```javascript
      case 'delete': {
        var dates = body.dates;
        if (!Array.isArray(dates) || dates.length === 0) {
          return fail(CODE.PARAM_ERROR, 'dates required');
        }
        if (dates.length > 50) {
          return fail(CODE.PARAM_ERROR, 'too many dates, max 50');
        }
        // 去重 + 只留合法日期
        var targets = [];
        for (var di = 0; di < dates.length; di++) {
          var dd = String(dates[di] || '');
          if (DATE_RE.test(dd) && targets.indexOf(dd) < 0) targets.push(dd);
        }
        if (targets.length === 0) {
          return fail(CODE.PARAM_ERROR, 'dates require valid format (YYYY-MM-DD)');
        }
        var deleted = 0;
        var t2 = Date.now();
        for (var dj = 0; dj < targets.length; dj++) {
          var found = await withTimeout(
            db.collection(TYPE).query().equalTo('date', targets[dj]).limit(100).get(),
            DB_TIMEOUT_MS,
            'game-record-backup:delete-query'
          );
          // 只删本人行
          var mine = (found || []).filter(function (it) {
            return toPlainObject(it).userId === uid;
          });
          if (mine.length > 0) {
            // 用查询返回的完整对象删除（同 wish-wall 删除红线：仅含 id 的新对象无法定位记录）
            await withTimeout(db.collection(TYPE).delete(mine), DB_TIMEOUT_MS, 'game-record-backup:delete');
            deleted += mine.length;
          }
        }
        log.info('[game-record-backup] delete ok uid=' + uid + ' dates=' + targets.length + ' deleted=' + deleted + ' ' + (Date.now() - t2) + 'ms');
        return success({ deleted: deleted });
      }
```

（`DATE_RE` 常量已存在于文件顶部；`toPlainObject` 已 import。）

- [ ] **Step 4: 运行测试确认通过**

Run: `node cloud/game-record-backup/smoke-delete.cjs`
Expected: 8 项全 PASS，退出码 0。

- [ ] **Step 5: 语法检查 + 重新打包 + 验证 zip**

```bash
node --check cloud/game-record-backup/handler.js
node cloud/deploy.cjs game-record-backup
node -e "
const AdmZip=require('./cloud/node_modules/adm-zip');
const zip=new AdmZip('./cloud/game-record-backup/game-record-backup.zip');
const e=zip.getEntry('handler.js');
console.log('zip ok, handler.js', e?e.header.size+' bytes':'MISSING');
"
```

Expected: `syntax OK` 无输出即通过；deploy 打印 `完成 1/1`；zip 内 handler.js 非空。

- [ ] **Step 6: Commit**

```bash
git add cloud/game-record-backup/handler.js cloud/game-record-backup/smoke-delete.cjs
git commit -m "feat(cloud): game-record-backup 支持 delete action（按日期删本人行）
```

---

### Task 2: CloudService 客户端删除方法

**Files:**
- Modify: `entry/src/main/ets/service/CloudService.ets`（`pushGameRecordBackup` 方法结束后、类结束 `}` 前插入）

- [ ] **Step 1: 加方法**

```typescript
  /** 删除云端牌局记录（按日期，仅本人）。幂等：云端本无该日期也返回成功 */
  static async deleteGameRecordBackup(dates: string[]): Promise<boolean> {
    try {
      const result = await cloudFunction.call({
        name: 'game-record-backup',
        data: {
          action: 'delete',
          dates: dates,
          __uid: getUserId()
        }
      })
      const env: CloudEnvelope | null = parseEnvelope(result.result)
      return env !== null && env.code === 0
    } catch (err) {
      console.error('[CloudService] deleteGameRecordBackup failed:', JSON.stringify(err))
      return false
    }
  }
```

- [ ] **Step 2: Commit**

```bash
git add entry/src/main/ets/service/CloudService.ets
git commit -m "feat(cloud): CloudService 增加 deleteGameRecordBackup 客户端方法"
```

---

### Task 3: EnrichViewModel 墓碑 + 修改/删除方法

**Files:**
- Modify: `entry/src/main/ets/viewmodels/EnrichViewModel.ets`

- [ ] **Step 1: 加墓碑常量与字段**

在 `KEY_LAST_BACKUP_AT`（第 31 行）之后加：

```typescript
const KEY_DELETED_GAME_DATES = 'deletedGameDates'
```

在 `lastBackupAt: string = ''`（第 60 行）之后加：

```typescript
  /** 本地已删除的牌局日期墓碑（YYYY-MM-DD[]）：防云端 pull 把这些日期复活 */
  deletedGameDates: string[] = []
```

- [ ] **Step 2: loadPrefs 读取墓碑**

在 `loadPrefs()` 里 `this.lastBackupAt = ...`（第 442 行附近）之后加：

```typescript
      const deletedDatesStr = await this.dataPrefs.get(KEY_DELETED_GAME_DATES, '[]') as string
      this.deletedGameDates = JSON.parse(deletedDatesStr)
```

- [ ] **Step 3: 加 updateGame / deleteGame / deleteDate 与私有辅助**

在 `updateGameNote`（第 137-144 行）之后插入以下完整代码：

```typescript
  /** 修改某天某笔的输赢/金额（不可变更新）。日期/下标越界静默忽略（UI 已二次确认） */
  updateGame(date: string, idx: number, result: '+' | '-' | '·', magnitude: number): void {
    const recIdx: number = this.gameRecords.findIndex(r => r.date === date)
    if (recIdx < 0) return
    const rec: GameRecord = this.gameRecords[recIdx]
    if (idx < 0 || idx >= rec.games.length) return
    const updatedGames: GameResult[] = rec.games.map((g: GameResult, i: number): GameResult => {
      return i === idx ? { result: result, magnitude: magnitude } : g
    })
    this.gameRecords = [
      ...this.gameRecords.slice(0, recIdx),
      { date: rec.date, deityId: rec.deityId, kowtowCount: rec.kowtowCount, games: updatedGames, note: rec.note },
      ...this.gameRecords.slice(recIdx + 1)
    ]
    this.persistGameRecords()
    this.gameRecordsRev++
    this.refreshAchievements()
    this.queueBackup()
  }

  /** 删除某天某笔；该天删到 0 笔时按整日删除处理（进墓碑 + 云删） */
  deleteGame(date: string, idx: number): void {
    const recIdx: number = this.gameRecords.findIndex(r => r.date === date)
    if (recIdx < 0) return
    const rec: GameRecord = this.gameRecords[recIdx]
    if (idx < 0 || idx >= rec.games.length) return
    if (rec.games.length === 1) {
      this.deleteDate(date)
      return
    }
    this.gameRecords = [
      ...this.gameRecords.slice(0, recIdx),
      {
        date: rec.date,
        deityId: rec.deityId,
        kowtowCount: rec.kowtowCount,
        games: rec.games.filter((g: GameResult, i: number): boolean => i !== idx),
        note: rec.note
      },
      ...this.gameRecords.slice(recIdx + 1)
    ]
    this.persistGameRecords()
    this.gameRecordsRev++
    this.refreshAchievements()
    this.queueBackup()
  }

  /** 整日删除：本地移除 + 日期进墓碑（防云端 pull 复活）+ 立即异步尝试云删（失败由下次同步补偿） */
  deleteDate(date: string): void {
    const recIdx: number = this.gameRecords.findIndex(r => r.date === date)
    if (recIdx < 0) return  // 已在删除态（防菜单双触发）
    this.gameRecords = [...this.gameRecords.slice(0, recIdx), ...this.gameRecords.slice(recIdx + 1)]
    this.addDeletedDate(date)
    this.persistGameRecords()
    this.gameRecordsRev++
    this.refreshAchievements()
    this.tryDeleteCloudDates([date])
  }

  private addDeletedDate(date: string): void {
    if (this.deletedGameDates.indexOf(date) >= 0) return
    this.deletedGameDates = [...this.deletedGameDates, date]
    this.persistDeletedDates()
  }

  /** 墓碑清理（云端已确认无该日期后调用，防无限累积） */
  private removeDeletedDates(dates: string[]): void {
    const next: string[] = this.deletedGameDates.filter((d: string): boolean => dates.indexOf(d) < 0)
    if (next.length !== this.deletedGameDates.length) {
      this.deletedGameDates = next
      this.persistDeletedDates()
    }
  }

  private isDeletedDate(date: string): boolean {
    return this.deletedGameDates.indexOf(date) >= 0
  }

  /** 立即尝试云端删除；失败仅 log，残留由 startCloudSync 补偿（不阻塞 UI） */
  private tryDeleteCloudDates(dates: string[]): void {
    CloudService.deleteGameRecordBackup(dates).then((ok: boolean) => {
      if (!ok) {
        console.warn('[EnrichViewModel] deleteGameRecordBackup failed, will retry on next sync: ' + dates.join(','))
      }
    }).catch((err: Object) => {
      console.error('[EnrichViewModel] deleteGameRecordBackup exception:', JSON.stringify(err))
    })
  }

  private async persistDeletedDates(): Promise<void> {
    if (!this.dataPrefs) return
    await this.dataPrefs.put(KEY_DELETED_GAME_DATES, JSON.stringify(this.deletedGameDates))
    await this.dataPrefs.flush()
  }
```

- [ ] **Step 4: Commit**

```bash
git add entry/src/main/ets/viewmodels/EnrichViewModel.ets
git commit -m "feat(record): 牌局记录支持修改单笔/删除单笔/删除整日，已删日期进墓碑防云端复活"
```

---

### Task 4: startCloudSync 墓碑过滤 + 补偿云删 + 墓碑自愈

**Files:**
- Modify: `entry/src/main/ets/viewmodels/EnrichViewModel.ets`（整段替换 `startCloudSync`，第 179-207 行）

- [ ] **Step 1: 替换 startCloudSync 整段实现**

```typescript
  /**
   * 启动云端同步（EntryAbility 在 deviceUserId 解析后调用）：
   * 1) 拉取云端记录；2) 墓碑日期（本地已删）不回灌本地——云端仍残留则补发云删，
   *    云端已无该日期则清理墓碑（自愈，防无限累积）；3) 其余日期合并（云端有本地缺才补）；
   * 4) 本地有记录则全量推回。幂等，无记录/离线时安全跳过。
   */
  async startCloudSync(): Promise<void> {
    const uid: string = AppStorage.get<string>('deviceUserId') || ''
    if (!uid) {
      return
    }
    try {
      const remote: GameRecord[] | null = await CloudService.fetchGameRecordBackup()
      if (remote === null) {
        console.warn('[EnrichViewModel] startCloudSync: 云端拉取失败，跳过合并（保留本地）')
        return
      }
      // 墓碑日期不回灌：本地删了，云端即使残留也要保持两端删除态
      const toDeleteCloud: string[] = []
      const keep: GameRecord[] = []
      for (const r of remote) {
        if (this.isDeletedDate(r.date)) {
          toDeleteCloud.push(r.date)
        } else {
          keep.push(r)
        }
      }
      if (toDeleteCloud.length > 0) {
        const ok: boolean = await CloudService.deleteGameRecordBackup(toDeleteCloud)
        // 成功 = 云端行已删，墓碑使命完成；失败 = 保墓碑，下次同步再补偿
        if (ok) {
          this.removeDeletedDates(toDeleteCloud)
        } else {
          console.warn('[EnrichViewModel] startCloudSync: 云端墓碑残留删除失败，下次再试: ' + toDeleteCloud.join(','))
        }
      }
      // 合并云端有、本地缺的日期（墓碑日期已排除，不会复活）
      const localDates: string[] = this.gameRecords.map((r: GameRecord) => r.date)
      const missing: GameRecord[] = keep.filter((r: GameRecord) => localDates.indexOf(r.date) === -1)
      if (missing.length > 0) {
        this.gameRecords = [...missing, ...this.gameRecords].sort((a: GameRecord, b: GameRecord) => {
          return a.date < b.date ? 1 : -1
        })
        await this.persistGameRecords()
        this.gameRecordsRev++
      }
      // 本地有记录则全量推回（幂等 upsert），保证云端与本地一致
      if (this.gameRecords.length > 0) {
        await this.flushBackup()
      }
    } catch (err) {
      console.error('[EnrichViewModel] startCloudSync failed:', JSON.stringify(err))
    }
  }
```

- [ ] **Step 2: Commit**

```bash
git add entry/src/main/ets/viewmodels/EnrichViewModel.ets
git commit -m "feat(record): startCloudSync 滤墓碑防复活 + 云端残留补偿删除 + 墓碑自愈清理"
```

---

### Task 5: UI——长按菜单/编辑弹窗/确认删除

**Files:**
- Modify: `entry/src/main/ets/pages/GameRecordPage.ets`
- Modify: `entry/src/main/ets/components/GameRecordDetailList.ets`

- [ ] **Step 1: GameRecordDetailList——加回调 props + 提示行 + 手势**

改动点（`entry/src/main/ets/components/GameRecordDetailList.ets`）：

a) 文件头部 import 区已有 `GameRecord, GameResult`。在组件属性区（`@State expandedAll` 之后）加：

```typescript
  /** 长按单笔 → 宿主弹菜单（date=记录日期, idx=第几笔） */
  onRowLongPress: (date: string, idx: number) => void = () => {}
  /** 长按整日卡 → 宿主确认删除当天 */
  onDayCardLongPress: (record: GameRecord) => void = () => {}
```

b) 「每笔明细」标题 Row（第 24-35 行）之后加提示行：

```typescript
        Text('长按单笔可修改/删除 · 长按日期卡可删除当天')
          .fontSize(10)
          .fontColor('rgba(253, 246, 227, 0.5)')
          .width('90%')
          .margin({ bottom: 8 })
```

c) DayCard 最外层 Column（`.width('90%')...margin({ bottom: 10 })` 链之后）加手势：

```typescript
        .gesture(
          LongPressGesture({ repeat: false })
            .onAction(() => {
              this.onDayCardLongPress(record)
            })
        )
```

d) GameRow 调用处（`this.GameRow(game)`）改为：

```typescript
        this.GameRow(game, idx, record.date)
```

GameRow 签名与 body 改为（原 Row 内容不变，仅签名与手势）：

```typescript
  /** 单笔：左结果标签（赢=绿底深字/输=红底/平=浅灰底）+ 右金额大字；长按回调宿主 */
  @Builder
  GameRow(game: GameResult, idx: number, date: string) {
    Row() {
      Text(this.tagText(game.result))
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.tagTextColor(game.result))
        .backgroundColor(this.tagBgColor(game.result))
        .width(46)
        .height(26)
        .textAlign(TextAlign.Center)
        .borderRadius(13)

      Text(this.amountText(game))
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.amountColor(game.result))
        .margin({ left: 14 })
    }
    .width('100%')
    .padding({ top: 7, bottom: 7 })
    .gesture(
      LongPressGesture({ repeat: false })
        .onAction(() => {
          this.onRowLongPress(date, idx)
        })
    )
  }
```

（`tagText/tagTextColor/tagBgColor/amountText/amountColor` 等辅助方法全部保留不动。）

- [ ] **Step 2: GameRecordPage——Stack 根 + 菜单/编辑弹窗状态与回调**

`entry/src/main/ets/pages/GameRecordPage.ets`：

a) 组件属性区（`lastBackupAt` 之后）加状态：

```typescript
  /** 长按操作菜单状态：menuDate/menuIdx 定位被长按的单笔 */
  @State menuVisible: boolean = false
  @State menuDate: string = ''
  @State menuIdx: number = -1
  /** 编辑弹窗状态（预填被改单笔原值） */
  @State editVisible: boolean = false
  @State editResult: '+' | '-' | '·' = '+'
  @State editAmount: string = ''
```

b) `build()` 根 Column 改为 Stack（原内容整体作 Stack 第一个子元素）：

```typescript
  build() {
    Stack() {
      Column() {
        // ……原有 build 内容全部不变……
      }
      .width('100%')
      .height('100%')

      // 长按单笔 → 深色底部操作菜单
      if (this.menuVisible) {
        this.RowActionSheet()
      }
      // 修改这笔 → 预填编辑弹窗
      if (this.editVisible) {
        this.EditDialog()
      }
    }
    .width('100%')
    .height('100%')
  }
```

c) 加打开菜单/关闭辅助与回调绑定。DetailList 调用处（`GameRecordDetailList({ enrichVM: $enrichVM })`）改为：

```typescript
          GameRecordDetailList({
            enrichVM: $enrichVM,
            onRowLongPress: (date: string, idx: number) => { this.openRowMenu(date, idx) },
            onDayCardLongPress: (record: GameRecord) => { this.confirmDeleteDay(record) }
          })
```

d) 在 `formatBackupTime` 之后加辅助与全部新 @Builder（完整代码）：

```typescript
  // ── 长按菜单 / 编辑 / 删除 ──

  private openRowMenu(date: string, idx: number): void {
    const rec = this.enrichVM.gameRecords.find((r) => r.date === date)
    if (!rec || idx < 0 || idx >= rec.games.length) return
    this.menuDate = date
    this.menuIdx = idx
    this.menuVisible = true
  }

  private closeRowMenu(): void {
    this.menuVisible = false
  }

  /** 当前被长按的单笔（菜单/编辑共用） */
  private currentMenuGame(): GameResult | null {
    const rec = this.enrichVM.gameRecords.find((r) => r.date === this.menuDate)
    if (!rec || this.menuIdx < 0 || this.menuIdx >= rec.games.length) return null
    return rec.games[this.menuIdx]
  }

  /** 该笔描述文案：赢 +50 / 输 -50 / 平 */
  private gameDesc(game: GameResult | null): string {
    if (!game) return ''
    if (game.result === '·') return '平'
    const sign: string = game.result === '+' ? '+' : '-'
    return (game.result === '+' ? '赢' : '输') + ' ' + sign + this.formatMag(game.magnitude)
  }

  /** 长按单笔菜单 → 修改这笔 */
  private openEditDialog(): void {
    const game = this.currentMenuGame()
    if (!game) {
      this.closeRowMenu()
      return
    }
    this.editResult = game.result
    this.editAmount = game.result === '·' ? '' : this.formatMag(game.magnitude)
    this.menuVisible = false
    this.editVisible = true
  }

  /** 长按单笔菜单 → 删除这笔（确认后删；删到 0 笔自动整日删除） */
  private confirmDeleteRow(): void {
    const game = this.currentMenuGame()
    if (!game) {
      this.closeRowMenu()
      return
    }
    const desc: string = this.gameDesc(game)
    this.getUIContext().getPromptAction().showDialog({
      title: '删除这笔记录',
      message: `确定删除这笔「${desc}」吗？此操作不可恢复。`,
      buttons: [
        { text: '取消', color: '#fdf6e3' },
        { text: '删除', color: '#e74c3c' }
      ]
    }).then((result: promptAction.ShowDialogSuccessResponse) => {
      if (result.index === 1) {
        const date: string = this.menuDate
        const idx: number = this.menuIdx
        this.closeRowMenu()
        this.enrichVM.deleteGame(date, idx)
      }
    })
  }

  /** 长按整日卡 → 确认删除当天全部 */
  private confirmDeleteDay(record: GameRecord): void {
    const monthDay: string = this.monthDayText(record.date)
    this.getUIContext().getPromptAction().showDialog({
      title: '删除当天记录',
      message: `确定删除 ${monthDay} 的全部记录（共 ${record.games.length} 笔）吗？将同步删除云端备份，不可恢复。`,
      buttons: [
        { text: '取消', color: '#fdf6e3' },
        { text: '删除', color: '#e74c3c' }
      ]
    }).then((result: promptAction.ShowDialogSuccessResponse) => {
      if (result.index === 1) {
        this.enrichVM.deleteDate(record.date)
      }
    })
  }

  /** 编辑弹窗确认：校验金额后更新（输赢金额必填 >0，平免金额） */
  private submitEdit(): void {
    let finalMag: number = 0
    if (this.editResult !== '·') {
      const mag: number = parseFloat(this.editAmount)
      if (isNaN(mag) || mag <= 0) {
        this.getUIContext().getPromptAction().showToast({ message: '输赢需先输入金额，平局则无需金额', duration: 2000 })
        return
      }
      finalMag = mag
    }
    const date: string = this.menuDate
    const idx: number = this.menuIdx
    const result: '+' | '-' | '·' = this.editResult
    this.editVisible = false
    this.menuDate = ''
    this.menuIdx = -1
    this.enrichVM.updateGame(date, idx, result, finalMag)
  }

  /** 'YYYY-MM-DD' → 'M月D日' */
  private monthDayText(date: string): string {
    const s: string[] = date.split('-')
    if (s.length !== 3) return date
    return `${Number(s[1])}月${Number(s[2])}日`
  }

  /** 格式化金额：整数不带小数，有小数则最多3位（与 GameRecordCard.formatMag 同规则） */
  private formatMag(mag: number): string {
    if (mag === Math.floor(mag)) {
      return `${mag}`
    }
    return mag.toFixed(3).replace(/0+$/, '').replace(/\.$/, '')
  }

  /** 深色底部操作菜单（单笔）：修改这笔 / 删除这笔 */
  @Builder
  RowActionSheet() {
    Column() {
      Column() {
        // 头部：日期 + 该笔描述
        Row() {
          Text(this.monthDayText(this.menuDate))
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#f9ca24')
          Text(this.gameDesc(this.currentMenuGame()))
            .fontSize(13)
            .fontColor('#fdf6e3')
            .margin({ left: 10 })
        }
        .width('100%')
        .margin({ bottom: 12 })

        // 修改这笔
        Row() {
          Text('✎ 修改这笔')
            .fontSize(15)
            .fontColor('#fdf6e3')
        }
        .width('100%')
        .height(48)
        .onClick(() => { this.openEditDialog() })

        // 删除这笔（红字实色 #e74c3c，对比度达标）
        Row() {
          Text('🗑 删除这笔')
            .fontSize(15)
            .fontColor('#e74c3c')
        }
        .width('100%')
        .height(48)
        .onClick(() => { this.confirmDeleteRow() })
      }
      .width('100%')
      .padding(20)
      .backgroundColor('#1a1a0a')
      .border({ width: { top: 1.5 }, color: 'rgba(249, 202, 36, 0.3)', radius: { topLeft: 16, topRight: 16 } })
      .onClick(() => {}) // 阻止穿透
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(0, 0, 0, 0.7)')
    .justifyContent(FlexAlign.End)
    .padding({ bottom: 20 })
    .onClick(() => { this.closeRowMenu() })
  }

  /** 编辑单笔弹窗（预填原输赢/金额，样式同 GameRecordCard.RecordDialog） */
  @Builder
  EditDialog() {
    Column() {
      Column() {
        Row() {
          Text('✎ 修改这笔')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#f9ca24')
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .margin({ bottom: 20 })

        // 输赢平切换
        Row() {
          Text('赢 +')
            .fontSize(16)
            .fontWeight(this.editResult === '+' ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.editResult === '+' ? '#1a1a0a' : 'rgba(253, 246, 227, 0.6)')
            .backgroundColor(this.editResult === '+' ? '#2ecc71' : 'rgba(46, 204, 113, 0.1)')
            .borderRadius(14)
            .padding({ left: 20, right: 20, top: 10, bottom: 10 })
            .onClick(() => { this.editResult = '+' })
          Text('输 -')
            .fontSize(16)
            .fontWeight(this.editResult === '-' ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.editResult === '-' ? '#1a1a0a' : 'rgba(253, 246, 227, 0.6)')
            .backgroundColor(this.editResult === '-' ? '#e74c3c' : 'rgba(231, 76, 60, 0.1)')
            .borderRadius(14)
            .padding({ left: 20, right: 20, top: 10, bottom: 10 })
            .margin({ left: 16 })
            .onClick(() => { this.editResult = '-' })
          Text('平 ·')
            .fontSize(16)
            .fontWeight(this.editResult === '·' ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.editResult === '·' ? '#1a1a0a' : 'rgba(253, 246, 227, 0.6)')
            .backgroundColor(this.editResult === '·' ? '#f9ca24' : 'rgba(249, 202, 36, 0.1)')
            .borderRadius(14)
            .padding({ left: 20, right: 20, top: 10, bottom: 10 })
            .margin({ left: 16 })
            .onClick(() => { this.editResult = '·' })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .margin({ bottom: 20 })

        // 金额输入：赢/输必填；平不显示
        if (this.editResult === '·') {
          Text('平局不计金额，同样记录一笔')
            .fontSize(12)
            .fontColor('rgba(253, 246, 227, 0.5)')
            .width('100%')
            .margin({ bottom: 20 })
        } else {
          Text('金额（必填）')
            .fontSize(12)
            .fontColor('rgba(253, 246, 227, 0.5)')
            .width('100%')
            .margin({ bottom: 8 })
          TextInput({ text: this.editAmount, placeholder: '输入金额，如 50、1.5、0.125' })
            .fontSize(18)
            .fontColor('#fdf6e3')
            .placeholderColor('rgba(253, 246, 227, 0.5)')
            .backgroundColor('rgba(249, 202, 36, 0.06)')
            .border({ width: 1, color: 'rgba(249, 202, 36, 0.25)', radius: 10 })
            .width('100%')
            .height(48)
            .type(InputType.NUMBER_DECIMAL)
            .onChange((value: string) => {
              this.editAmount = value
            })
            .margin({ bottom: 20 })
        }

        // 操作按钮
        Row() {
          Button('取消')
            .fontSize(15)
            .fontColor('rgba(253, 246, 227, 0.6)')
            .backgroundColor('rgba(253, 246, 227, 0.1)')
            .borderRadius(20)
            .height(40)
            .layoutWeight(1)
            .onClick(() => { this.editVisible = false })
          Button('✦ 保存')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1a1a0a')
            .backgroundColor('#f9ca24')
            .borderRadius(20)
            .height(40)
            .layoutWeight(1)
            .margin({ left: 12 })
            .onClick(() => { this.submitEdit() })
        }
        .width('100%')
      }
      .width('80%')
      .padding(24)
      .backgroundColor('#1a1a0a')
      .borderRadius(16)
      .border({ width: 1.5, color: 'rgba(249, 202, 36, 0.3)' })
      .onClick(() => {}) // 阻止穿透
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(0, 0, 0, 0.7)')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => { this.editVisible = false })
  }
```

e) 头部 import 加类型：`GameResult` 已从 DetailList 用，但 **GameRecordPage 需要**——补 import：

```typescript
import { GameRecord, GameResult } from '../model/EnrichTypes'
```

（替换现有 `import { EnrichViewModel }...` 之上的结构；GameRecordPage 当前无 model import，新增一行。）

- [ ] **Step 3: 类型/编译检查（快速自查）**

`promptAction.ShowDialogSuccessResponse` 类型需要 `import { promptAction } from '@kit.ArkUI'`？——项目内 HistoryPanel 直接用 `promptAction.ShowDialogSuccessResponse` 而无显式 import（kit 全局可见），照 HistoryPanel 先例即可；若编译报未定义再加 import。placeholder 由构建任务裁决。

- [ ] **Step 4: Commit**

```bash
git add entry/src/main/ets/pages/GameRecordPage.ets entry/src/main/ets/components/GameRecordDetailList.ets
git commit -m "feat(ui): 牌局记录长按单笔修改/删除、长按整日卡删除当天"
```

---

### Task 6: 构建验证 + 真机手测清单

**Files:** 无（验证任务）

- [ ] **Step 1: 编译验证**

Run: `cmd //c build-debug.bat`
Expected: `BUILD SUCCESSFUL`（assembleHap）。若 ArkTS 报错（如 promptAction 类型、builder 签名），按报错在 Task 5 的文件内最小修正后重跑，直到绿。

- [ ] **Step 2: 云函数 zip 已含 delete（Task 1 已打）**

Run: `node cloud/game-record-backup/smoke-delete.cjs`
Expected: 8 项全 PASS。

- [ ] **Step 3: 真机手测清单（记录到最终交付说明，标注 PASS/FAIL）**

1. 长按单笔 → 底部菜单出现（修改这笔/删除这笔）
2. 修改：改输赢（赢→输）与金额 → 明细行/汇总/胜率即时更新
3. 修改平局笔不显示金额输入
4. 删除单笔（当天还有笔）→ 该行消失，天数卡保留，笔数-1
5. 删除当天最后一笔 → 整卡消失
6. 长按整日卡 → 确认弹窗含天数与笔数 → 删除 → 卡消失
7. AGC 控制台 Cloud DB：删除的日期行消失（联网场景）
8. **断网**删除某天 → 联网后**冷启动** App → 该天不复活（墓碑补偿），且 AGC 控制台该行最终被删
9. 再次冷启动后墓碑不无限累积（重删成功即清理）
10. 旧记录/编辑后的推送仍正常（记一笔后云端行更新）

- [ ] **Step 4: 收尾（如用户要求提交）**

```bash
git add docs/superpowers/specs/2026-09-09-game-record-manage-design.md docs/superpowers/plans/2026-09-09-game-record-manage.md .gitignore cloud/game-record-backup/handler.js cloud/game-record-backup/package.json cloud/game-record-backup/smoke-delete.cjs
git commit -m "feat(record): 牌局记录长按修改/删除（含云端删除同步）——spec/计划/云函数补全与部署包
```

---

## 自检记录

- **Spec 覆盖**：交互四行 → Task 5；VM 三方法+墓碑 → Task 3；startCloudSync 改造 → Task 4；云函数 delete → Task 1；CloudService → Task 2；验证 → Task 6。全对齐。
- **类型一致性**：`updateGame(date, idx, result, magnitude)` / `deleteGame(date, idx)` / `deleteDate(date)` 在 Task 3 定义、Task 5 UI 调用处签名一致；`enrichVM.deleteGame(date, idx)` 传参顺序一致；回调 props `onRowLongPress(date, idx)` / `onDayCardLongPress(record)` 在 Task 5 Step 1 定义、Step 2c 绑定一致；`tryDeleteCloudDates`/`removeDeletedDates`/`isDeletedDate` 在 Task 3 定义、Task 4 调用一致。
- **风险注记**：UI 弹窗/菜单布局细节（如底部安全区 padding）如真机观感不佳可在 Task 6 Step 3 手测时微调，不动结构与颜色常量。
