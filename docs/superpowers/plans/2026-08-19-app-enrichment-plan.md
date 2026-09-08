# 麻神祈福 APP 功能丰富度增强 — 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将应用从"单次祈福工具"升级为"麻将人的随身祈福工具箱"，新增签到、日记、牌运记录、成就、黄历、排行榜、心愿墙 7 大功能。

**Architecture:** 线性流程重构为 4 Tab 底部导航（祈福广场/心愿墙/排行榜/我的），所有新增状态通过 `EnrichViewModel` 管理（本地 Preferences 持久化），排行榜和心愿墙通过 AGC Cloud DB + 云函数实现网络数据。

**Tech Stack:** HarmonyOS ArkTS, @kit.ArkData (preferences), @kit.ArkUI (router/Tabs), AGC Cloud DB, AGC Cloud Functions (Node.js 18)

---

## 实现顺序

```
Phase 1: 基础层（类型 + ViewModel + Tab 骨架）
Phase 2: Tab 4 "我的"（签到→日记→牌运→成就）
Phase 3: Tab 1 "祈福广场"（黄历 + HomePage 适配）
Phase 4: 云函数（Cloud DB schema + 3 个云函数）
Phase 5: Tab 3 "排行榜"（UI + CloudService 对接）
Phase 6: Tab 2 "心愿墙"（UI + CloudService 对接）
Phase 7: 集成收尾（入口切换 + 版本号 + 验证）
```

---

### Phase 1: 基础层

### Task 1.1: 新增类型定义

**Files:**
- Create: `entry/src/main/ets/model/EnrichTypes.ets`

- [ ] **Step 1: 创建 EnrichTypes.ets**

```typescript
// entry/src/main/ets/model/EnrichTypes.ets

/** 签到状态 */
export interface CheckinState {
  lastDate: string       // 上次签到日期 YYYY-MM-DD
  streak: number         // 连续签到天数 (1-7)
  totalIncense: number   // 累计香火值
}

/** 单场牌局结果 */
export interface GameResult {
  result: '+' | '·'      // + 赢 · 输/平
  magnitude: number      // 幅度 1-9
}

/** 某天的牌运记录 */
export interface GameRecord {
  date: string           // YYYY-MM-DD
  deityId: number        // 当天拜的财神
  kowtowCount: number    // 当天磕头次数
  games: GameResult[]    // 牌局结果
  note: string           // 备注
}

/** 成就徽章 */
export interface Achievement {
  badgeId: string        // 徽章 ID
  name: string           // 徽章名称
  icon: string           // 图标
  desc: string           // 条件描述
  unlocked: boolean      // 是否已解锁
  unlockDate: string     // 解锁日期
  progress: number       // 当前进度 0-1
}

/** 排行榜条目 */
export interface LeaderboardEntry {
  userId: string
  nickname: string
  count: number
  kowtow: number
  rank: number
}

/** 心愿 */
export interface Wish {
  id: string
  userId: string
  nickname: string
  content: string
  deityId: number
  fulfilled: boolean
  createdAt: string
  fulfilledAt: string
}

/** 排行榜类型 */
export enum LeaderboardType {
  DAILY = 'daily',
  WEEKLY = 'weekly',
  TOTAL = 'total'
}

/** 成就徽章定义 */
export const BADGE_DEFS: Omit<Achievement, 'unlocked' | 'unlockDate' | 'progress'>[] = [
  {
    badgeId: 'first_prayer',
    name: '初入牌局',
    icon: '🀄',
    desc: '完成首次祈福'
  },
  {
    badgeId: 'kowtow_100',
    name: '百拜成金',
    icon: '🏅',
    desc: '累计磕头 100 次'
  },
  {
    badgeId: 'streak_7',
    name: '虔诚信徒',
    icon: '🔥',
    desc: '连续签到 7 天'
  },
  {
    badgeId: 'all_deities',
    name: '五路通拜',
    icon: '🌟',
    desc: '拜过所有 5 位财神'
  },
  {
    badgeId: 'five_wins',
    name: '大杀四方',
    icon: '🀇',
    desc: '单日记录 5 场以上赢局'
  },
  {
    badgeId: 'win_rate_70',
    name: '常胜将军',
    icon: '👑',
    desc: '祈福胜率超 70%（≥10 场）'
  },
  {
    badgeId: 'wish_3',
    name: '心诚则灵',
    icon: '✨',
    desc: '发布并还愿 3 个心愿'
  },
  {
    badgeId: 'top_daily',
    name: '日榜第一',
    icon: '🏆',
    desc: '曾登上日祈福榜榜首'
  }
]

/** 黄历数据 */
export interface AlmanacData {
  direction: string       // 吉位
  luckySuit: string       // 幸运花色（条/筒/万）
  avoid: string           // 忌
  suitable: string        // 宜
  incenseCount: number    // 今日香火人数
}

/** 黄历 30 天轮换表 */
export const ALMANAC_TABLE: Omit<AlmanacData, 'incenseCount'>[] = [
  { direction: '坐东朝西', luckySuit: '🀇 条子', avoid: '心浮气躁', suitable: '稳扎稳打' },
  { direction: '坐南朝北', luckySuit: '🀈 筒子', avoid: '贪大胡', suitable: '见好就收' },
  { direction: '坐西朝东', luckySuit: '🀉 万子', avoid: '犹豫不决', suitable: '当机立断' },
  { direction: '坐北朝南', luckySuit: '🀇 条子', avoid: '急功近利', suitable: '耐心等待' },
  { direction: '坐东朝西', luckySuit: '🀈 筒子', avoid: '目中无人', suitable: '低调行事' },
  { direction: '坐南朝北', luckySuit: '🀉 万子', avoid: '贪心不足', suitable: '适可而止' },
  { direction: '坐西朝东', luckySuit: '🀇 条子', avoid: '心猿意马', suitable: '专注一局' },
  { direction: '坐北朝南', luckySuit: '🀈 筒子', avoid: '怨天尤人', suitable: '自省吾身' },
  { direction: '坐东朝西', luckySuit: '🀉 万子', avoid: '得意忘形', suitable: '戒骄戒躁' },
  { direction: '坐南朝北', luckySuit: '🀇 条子', avoid: '急于求成', suitable: '步步为营' },
  // 第 11-20 天
  { direction: '坐西朝东', luckySuit: '🀈 筒子', avoid: '刚愎自用', suitable: '广纳良言' },
  { direction: '坐北朝南', luckySuit: '🀉 万子', avoid: '患得患失', suitable: '放平心态' },
  { direction: '坐东朝西', luckySuit: '🀇 条子', avoid: '贪多嚼不烂', suitable: '集中精力' },
  { direction: '坐南朝北', luckySuit: '🀈 筒子', avoid: '贸然进攻', suitable: '以守为攻' },
  { direction: '坐西朝东', luckySuit: '🀉 万子', avoid: '轻敌冒进', suitable: '重视对手' },
  { direction: '坐北朝南', luckySuit: '🀇 条子', avoid: '情绪上头', suitable: '冷静克制' },
  { direction: '坐东朝西', luckySuit: '🀈 筒子', avoid: '瞻前顾后', suitable: '果断出击' },
  { direction: '坐南朝北', luckySuit: '🀉 万子', avoid: '好高骛远', suitable: '脚踏实地' },
  { direction: '坐西朝东', luckySuit: '🀇 条子', avoid: '自乱阵脚', suitable: '沉着冷静' },
  { direction: '坐北朝南', luckySuit: '🀈 筒子', avoid: '畏首畏尾', suitable: '大胆出手' },
  // 第 21-30 天
  { direction: '坐东朝西', luckySuit: '🀉 万子', avoid: '心浮气躁', suitable: '平心静气' },
  { direction: '坐南朝北', luckySuit: '🀇 条子', avoid: '贪大求全', suitable: '小胡即安' },
  { direction: '坐西朝东', luckySuit: '🀈 筒子', avoid: '急功近利', suitable: '厚积薄发' },
  { direction: '坐北朝南', luckySuit: '🀉 万子', avoid: '一意孤行', suitable: '听取建议' },
  { direction: '坐东朝西', luckySuit: '🀇 条子', avoid: '半途而废', suitable: '坚持到底' },
  { direction: '坐南朝北', luckySuit: '🀈 筒子', avoid: '患得患失', suitable: '笑对输赢' },
  { direction: '坐西朝东', luckySuit: '🀉 万子', avoid: '心不在焉', suitable: '全神贯注' },
  { direction: '坐北朝南', luckySuit: '🀇 条子', avoid: '怨天尤人', suitable: '顺其自然' },
  { direction: '坐东朝西', luckySuit: '🀈 筒子', avoid: '意气用事', suitable: '理智判断' },
  { direction: '坐南朝北', luckySuit: '🀉 万子', avoid: '骄傲自满', suitable: '虚心进取' }
]

/** 签到麻将牌序列 */
export const CHECKIN_TILES = ['🀇', '🀈', '🀉', '🀊', '🀋', '🀌', '🀍']
```

- [ ] **Step 2: 提交**

```bash
git add entry/src/main/ets/model/EnrichTypes.ets
git commit -m "feat: add EnrichTypes for checkin, game records, achievements, almanac, leaderboard, wish"
```

---

### Task 1.2: 创建 EnrichViewModel

**Files:**
- Create: `entry/src/main/ets/viewmodels/EnrichViewModel.ets`

- [ ] **Step 1: 创建 EnrichViewModel 核心框架**

```typescript
// entry/src/main/ets/viewmodels/EnrichViewModel.ets
import {
  CheckinState, GameRecord, Achievement, BADGE_DEFS, AlmanacData, ALMANAC_TABLE, CHECKIN_TILES
} from '../model/EnrichTypes'
import { PrayerViewModel } from './PrayerViewModel'
import { preferences } from '@kit.ArkData'

const PREF_NAME = 'mashen_enrich_prefs'
const KEY_CHECKIN = 'checkin'
const KEY_GAME_RECORDS = 'gameRecords'
const KEY_ACHIEVEMENTS = 'achievements'
const KEY_DIARY_NOTES = 'diaryNotes'
const KEY_TOTAL_KOWTOW = 'totalKowtow'
const KEY_BOWED_DEITIES = 'bowedDeities'
const KEY_WAS_TOP_DAILY = 'wasTopDaily'
const KEY_WISH_FULFILLED_COUNT = 'wishFulfilledCount'

@Observed
export class EnrichViewModel {
  checkin: CheckinState = { lastDate: '', streak: 0, totalIncense: 0 }
  gameRecords: GameRecord[] = []
  achievements: Achievement[] = BADGE_DEFS.map(b => ({ ...b, unlocked: false, unlockDate: '', progress: 0 }))
  diaryNotes: Record<string, string> = {}  // recordId -> note
  totalKowtow: number = 0
  bowedDeities: Set<number> = new Set()    // 拜过的财神 ID 集合
  wasTopDaily: boolean = false
  wishFulfilledCount: number = 0
  private dataPrefs: preferences.Preferences | null = null

  async initialize(context: Context): Promise<void> {
    this.dataPrefs = await preferences.getPreferences(context, PREF_NAME)
    await this.loadPrefs()
    this.refreshAchievements()
  }

  // ── 签到 ──

  getTodayStr(): string {
    const d = new Date()
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
  }

  getYesterdayStr(): string {
    const d = new Date(Date.now() - 86400000)
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
  }

  canCheckin(): boolean {
    return this.checkin.lastDate !== this.getTodayStr()
  }

  doCheckin(): number {
    // 返回本次获得的香火值
    if (!this.canCheckin()) return 0
    const today = this.getTodayStr()
    if (this.checkin.lastDate === this.getYesterdayStr()) {
      this.checkin.streak = this.checkin.streak >= 7 ? 1 : this.checkin.streak + 1
    } else {
      this.checkin.streak = 1
    }
    this.checkin.lastDate = today
    const baseIncense = 10
    const bonus = this.checkin.streak === 7 ? baseIncense * 2 : 0
    const earned = baseIncense + bonus
    this.checkin.totalIncense += earned
    this.persistCheckin()
    this.refreshAchievements()
    return earned
  }

  getCheckinTiles(): string[] {
    // 返回已签到的麻将牌列表
    return CHECKIN_TILES.slice(0, this.checkin.streak)
  }

  // ── 牌运记录 ──

  getTodayGameRecord(): GameRecord | undefined {
    const today = this.getTodayStr()
    return this.gameRecords.find(r => r.date === today)
  }

  addGameResult(result: '+' | '·', magnitude: number, deityId: number, kowtowCount: number): void {
    const today = this.getTodayStr()
    let record = this.gameRecords.find(r => r.date === today)
    if (!record) {
      record = { date: today, deityId, kowtowCount, games: [], note: '' }
      this.gameRecords.unshift(record)
    }
    record.games.push({ result, magnitude })
    this.persistGameRecords()
    this.refreshAchievements()
  }

  updateGameNote(date: string, note: string): void {
    const record = this.gameRecords.find(r => r.date === date)
    if (record) {
      record.note = note
      this.persistGameRecords()
    }
  }

  getWinRate(): { wins: number, total: number, rate: number } {
    let wins = 0
    let total = 0
    for (const r of this.gameRecords) {
      for (const g of r.games) {
        total++
        if (g.result === '+') wins++
      }
    }
    return { wins, total, rate: total > 0 ? Math.round(wins / total * 100) : 0 }
  }

  getBestDeity(): string {
    // 统计拜后当天胜率最高的财神
    const stats: Record<number, { wins: number, total: number }> = {}
    for (const r of this.gameRecords) {
      if (!stats[r.deityId]) stats[r.deityId] = { wins: 0, total: 0 }
      for (const g of r.games) {
        stats[r.deityId].total++
        if (g.result === '+') stats[r.deityId].wins++
      }
    }
    let bestId = 0
    let bestRate = 0
    for (const id of Object.keys(stats)) {
      const s = stats[Number(id)]
      if (s.total >= 3) {
        const rate = s.wins / s.total
        if (rate > bestRate) { bestRate = rate; bestId = Number(id) }
      }
    }
    const names: Record<number, string> = { 1: '赵公明', 2: '萧升', 3: '曹宝', 4: '陈九公', 5: '姚少司' }
    return bestId > 0 ? names[bestId] || '' : '—'
  }

  // ── 祈福日记 ──

  getDiaryNote(recordId: string): string {
    return this.diaryNotes[recordId] || ''
  }

  setDiaryNote(recordId: string, note: string): void {
    this.diaryNotes[recordId] = note
    this.persistDiaryNotes()
  }

  // ── 成就 ──

  refreshAchievements(): void {
    const totalPrayers = this.getTotalPrayers()
    const winRate = this.getWinRate()
    const todayGames = this.getTodayGameRecord()?.games || []
    const todayWins = todayGames.filter(g => g.result === '+').length

    const checks: Record<string, boolean> = {
      'first_prayer': totalPrayers >= 1,
      'kowtow_100': this.totalKowtow >= 100,
      'streak_7': this.checkin.streak >= 7,
      'all_deities': this.bowedDeities.size >= 5,
      'five_wins': todayWins >= 5,
      'win_rate_70': winRate.total >= 10 && winRate.rate >= 70,
      'wish_3': this.wishFulfilledCount >= 3,
      'top_daily': this.wasTopDaily
    }

    const today = this.getTodayStr()
    for (let i = 0; i < this.achievements.length; i++) {
      const a = this.achievements[i]
      if (!a.unlocked && checks[a.badgeId]) {
        this.achievements[i] = { ...a, unlocked: true, unlockDate: today, progress: 1 }
      } else if (!a.unlocked) {
        // 更新进度
        let progress = 0
        switch (a.badgeId) {
          case 'first_prayer': progress = totalPrayers >= 1 ? 1 : 0; break
          case 'kowtow_100': progress = Math.min(this.totalKowtow / 100, 1); break
          case 'streak_7': progress = Math.min(this.checkin.streak / 7, 1); break
          case 'all_deities': progress = Math.min(this.bowedDeities.size / 5, 1); break
          case 'five_wins': progress = Math.min(todayWins / 5, 1); break
          case 'win_rate_70': progress = winRate.total >= 10 ? Math.min(winRate.rate / 70, 1) : Math.min(winRate.total / 10, 1); break
          case 'wish_3': progress = Math.min(this.wishFulfilledCount / 3, 1); break
          case 'top_daily': progress = this.wasTopDaily ? 1 : 0; break
        }
        this.achievements[i] = { ...a, progress }
      }
    }
    this.persistAchievements()
  }

  // ── 黄历 ──

  getAlmanac(): AlmanacData {
    const dayOfYear = this.getDayOfYear()
    const entry = ALMANAC_TABLE[dayOfYear % ALMANAC_TABLE.length]
    return { ...entry, incenseCount: 0 }  // incenseCount 由 CloudService 注入
  }

  // ── 磕头/财神追踪（由 PrayerViewModel 调用）─

  onKowtowDone(count: number, deityId: number): void {
    this.totalKowtow += count
    this.bowedDeities.add(deityId)
    this.persistKowtow()
    this.refreshAchievements()
  }

  setTopDaily(): void {
    if (!this.wasTopDaily) {
      this.wasTopDaily = true
      this.persistAchievements()
      this.refreshAchievements()
    }
  }

  incWishFulfilled(): void {
    this.wishFulfilledCount++
    this.persistWishCount()
    this.refreshAchievements()
  }

  // ── 持久化 ──

  private getTotalPrayers(): number {
    // 从 AppStorage 读取 PrayerViewModel，获取其 totalPrayers 属性
    try {
      const vm = AppStorage.get<PrayerViewModel>('viewModel')
      return vm ? vm.totalPrayers : 0
    } catch {
      return 0
    }
  }

  private getDayOfYear(): number {
    const now = new Date()
    const start = new Date(now.getFullYear(), 0, 0)
    const diff = now.getTime() - start.getTime()
    return Math.floor(diff / 86400000)
  }

  private async loadPrefs(): Promise<void> {
    if (!this.dataPrefs) return
    try {
      const checkinStr = await this.dataPrefs.get(KEY_CHECKIN, '{}') as string
      this.checkin = JSON.parse(checkinStr)
      if (!this.checkin.lastDate) this.checkin = { lastDate: '', streak: 0, totalIncense: 0 }

      const recordsStr = await this.dataPrefs.get(KEY_GAME_RECORDS, '[]') as string
      this.gameRecords = JSON.parse(recordsStr)

      const achievementsStr = await this.dataPrefs.get(KEY_ACHIEVEMENTS, '{}') as string
      const savedAchievements = JSON.parse(achievementsStr)
      this.achievements = BADGE_DEFS.map(b => ({
        ...b,
        unlocked: savedAchievements[b.badgeId] ? true : false,
        unlockDate: savedAchievements[b.badgeId] || '',
        progress: savedAchievements[b.badgeId] ? 1 : 0
      }))

      const notesStr = await this.dataPrefs.get(KEY_DIARY_NOTES, '{}') as string
      this.diaryNotes = JSON.parse(notesStr)

      this.totalKowtow = await this.dataPrefs.get(KEY_TOTAL_KOWTOW, 0) as number

      const deitiesArr = JSON.parse(await this.dataPrefs.get(KEY_BOWED_DEITIES, '[]') as string)
      this.bowedDeities = new Set(deitiesArr)

      this.wasTopDaily = await this.dataPrefs.get(KEY_WAS_TOP_DAILY, false) as boolean
      this.wishFulfilledCount = await this.dataPrefs.get(KEY_WISH_FULFILLED_COUNT, 0) as number
    } catch (err) {
      console.error('[EnrichViewModel] Failed to load prefs:', JSON.stringify(err))
    }
  }

  private async persistCheckin(): Promise<void> {
    if (!this.dataPrefs) return
    await this.dataPrefs.put(KEY_CHECKIN, JSON.stringify(this.checkin))
    await this.dataPrefs.flush()
  }

  private async persistGameRecords(): Promise<void> {
    if (!this.dataPrefs) return
    await this.dataPrefs.put(KEY_GAME_RECORDS, JSON.stringify(this.gameRecords))
    await this.dataPrefs.flush()
  }

  private async persistAchievements(): Promise<void> {
    if (!this.dataPrefs) return
    const obj: Record<string, string> = {}
    for (const a of this.achievements) {
      if (a.unlocked) obj[a.badgeId] = a.unlockDate
    }
    await this.dataPrefs.put(KEY_ACHIEVEMENTS, JSON.stringify(obj))
    await this.dataPrefs.put(KEY_WAS_TOP_DAILY, this.wasTopDaily)
    await this.dataPrefs.flush()
  }

  private async persistDiaryNotes(): Promise<void> {
    if (!this.dataPrefs) return
    await this.dataPrefs.put(KEY_DIARY_NOTES, JSON.stringify(this.diaryNotes))
    await this.dataPrefs.flush()
  }

  private async persistKowtow(): Promise<void> {
    if (!this.dataPrefs) return
    await this.dataPrefs.put(KEY_TOTAL_KOWTOW, this.totalKowtow)
    await this.dataPrefs.put(KEY_BOWED_DEITIES, JSON.stringify([...this.bowedDeities]))
    await this.dataPrefs.flush()
  }

  private async persistWishCount(): Promise<void> {
    if (!this.dataPrefs) return
    await this.dataPrefs.put(KEY_WISH_FULFILLED_COUNT, this.wishFulfilledCount)
    await this.dataPrefs.flush()
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add entry/src/main/ets/viewmodels/EnrichViewModel.ets
git commit -m "feat: add EnrichViewModel with checkin, game records, achievements, almanac"
```

---

### Task 1.3: 创建 MainTabs 骨架

**Files:**
- Create: `entry/src/main/ets/pages/MainTabs.ets`

- [ ] **Step 1: 创建 MainTabs 4 Tab 骨架**

```typescript
// entry/src/main/ets/pages/MainTabs.ets
import { PrayerViewModel } from '../viewmodels/PrayerViewModel'
import { EnrichViewModel } from '../viewmodels/EnrichViewModel'
import { DailyAlmanac } from '../components/DailyAlmanac'
import { DeityArrayView } from '../components/DeityArrayView'
import { PrivacyDialog } from '../components/PrivacyDialog'
import { PrayerPhase, FIVE_DEITIES } from '../model/PrayerTypes'
import { LeaderboardType } from '../model/EnrichTypes'
import { WishWallPage } from './WishWall'
import { LeaderboardPage } from './Leaderboard'
import { MyPage } from './MyPage'
import { router } from '@kit.ArkUI'

@Entry
@Component
struct MainTabs {
  @StorageLink('viewModel') viewModel: PrayerViewModel = new PrayerViewModel()
  @StorageLink('enrichViewModel') enrichVM: EnrichViewModel = new EnrichViewModel()
  @State currentTab: number = 0
  @State showPrivacyDialog: boolean = false
  private privacyDialogController: CustomDialogController | null = null
  private tabTitles: string[] = ['祈福广场', '心愿墙', '排行榜', '我的']

  aboutToAppear(): void {
    this.checkPrivacyAccepted()
  }

  private async checkPrivacyAccepted(): Promise<void> {
    try {
      const accepted = await this.viewModel.isPrivacyAccepted()
      if (!accepted) {
        this.showPrivacyDialog = true
        this.openPrivacyDialog()
      }
    } catch (err) {
      console.error('[MainTabs] Failed to check privacy:', JSON.stringify(err))
      this.showPrivacyDialog = true
      this.openPrivacyDialog()
    }
  }

  private openPrivacyDialog(): void {
    this.privacyDialogController = new CustomDialogController({
      builder: PrivacyDialog({
        onAgree: () => {
          this.showPrivacyDialog = false
          this.viewModel.acceptPrivacy()
        }
      }),
      autoCancel: false,
      alignment: DialogAlignment.Center,
      customStyle: true
    })
    this.privacyDialogController.open()
  }

  // 导入 PrivacyDialog 需要显式引用
  // 实际上 PrivacyDialog 不在当前文件，需要在 build 中引入

  build() {
    Column() {
      Tabs({ index: this.currentTab }) {
        // Tab 1: 祈福广场
        TabContent() {
          this.BlessingSquare()
        }
        .tabBar(this.TabBarBuilder(0, '🪷'))

        // Tab 2: 心愿墙
        TabContent() {
          WishWallPage()
        }
        .tabBar(this.TabBarBuilder(1, '✨'))

        // Tab 3: 排行榜
        TabContent() {
          LeaderboardPage()
        }
        .tabBar(this.TabBarBuilder(2, '🏆'))

        // Tab 4: 我的
        TabContent() {
          MyPage()
        }
        .tabBar(this.TabBarBuilder(3, '👤'))
      }
      .barHeight(56)
      .barMode(BarMode.Fixed)
      .barBackgroundColor('#1a1a0a')
      .onChange((index: number) => {
        this.currentTab = index
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1a1a0a')
  }

  @Builder
  TabBarBuilder(index: number, icon: string) {
    Column() {
      Text(icon)
        .fontSize(20)
      Text(this.tabTitles[index])
        .fontSize(10)
        .fontColor(this.currentTab === index ? '#f9ca24' : 'rgba(253, 246, 227, 0.4)')
        .margin({ top: 2 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.currentTab === index ? 'rgba(249, 202, 36, 0.08)' : 'transparent')
  }

  @Builder
  BlessingSquare() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#1a1a0a')
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])

      // 黄历卡片
      DailyAlmanac({ enrichVM: this.enrichVM })

      // 五神弧形阵
      Column() {
        DeityArrayView({
          deities: FIVE_DEITIES,
          highlightId: this.viewModel.todayDeity.id,
          appearProgress: 1,
          blessingProgress: 0
        })
      }
      .width('100%')
      .height('50%')
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Center)
      .margin({ top: 120 })

      // 副标题
      Text('「心诚则灵，牌来运转」')
        .fontSize(14)
        .fontColor('rgba(249, 202, 36, 0.5)')
        .fontStyle(FontStyle.Italic)
        .position({ x: '50%', y: '67%' })
        .translate({ x: '-50%', y: '-50%' })

      // 主按钮
      Button('🪷 开始祈福')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1a1a0a')
        .backgroundColor('#f9ca24')
        .borderRadius(25)
        .padding({ left: 40, right: 40, top: 14, bottom: 14 })
        .shadow({ radius: 20, color: 'rgba(249, 202, 36, 0.4)', offsetY: 4 })
        .onClick(() => {
          this.viewModel.startPrayer()
          setTimeout(() => {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/NameCard' }, router.RouterMode.Standard)
          }, 0)
        })
        .position({ x: '50%', y: '80%' })
        .translate({ x: '-50%', y: '-50%' })
    }
    .width('100%')
    .height('100%')
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add entry/src/main/ets/pages/MainTabs.ets
git commit -m "feat: add MainTabs skeleton with 4-tab navigation"
```

---

### Phase 2: Tab 4 "我的"

### Task 2.1: 签到卡片组件

**Files:**
- Create: `entry/src/main/ets/components/CheckinCard.ets`

- [ ] **Step 1: 创建 CheckinCard 组件**

```typescript
// entry/src/main/ets/components/CheckinCard.ets
import { EnrichViewModel } from '../viewmodels/EnrichViewModel'
import { PrayerViewModel } from '../viewmodels/PrayerViewModel'
import { CHECKIN_TILES } from '../model/EnrichTypes'

@Component
export struct CheckinCard {
  @Link enrichVM: EnrichViewModel
  @State showToast: boolean = false
  @State toastMsg: string = ''

  build() {
    Column() {
      // 签到麻将牌行
      Row() {
        ForEach(CHECKIN_TILES, (tile: string, index: number) => {
          Column() {
            Text(tile)
              .fontSize(24)
              .opacity(index < this.enrichVM.checkin.streak ? 1 : 0.2)
            Text(this.getDayLabel(index))
              .fontSize(9)
              .fontColor(index < this.enrichVM.checkin.streak ? '#f9ca24' : 'rgba(253, 246, 227, 0.2)')
              .margin({ top: 2 })
          }
          .width('13%')
          .alignItems(HorizontalAlign.Center)
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceEvenly)
      .margin({ bottom: 16 })

      // 签到按钮
      Button(this.enrichVM.canCheckin() ? '🔥 今日签到领香火' : '✅ 今日已签到')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.enrichVM.canCheckin() ? '#1a1a0a' : 'rgba(253, 246, 227, 0.4)')
        .backgroundColor(this.enrichVM.canCheckin() ? '#f9ca24' : 'rgba(249, 202, 36, 0.1)')
        .borderRadius(20)
        .padding({ left: 24, right: 24, top: 10, bottom: 10 })
        .enabled(this.enrichVM.canCheckin())
        .onClick(() => {
          const earned = this.enrichVM.doCheckin()
          this.toastMsg = earned > 0
            ? `签到成功！${this.enrichVM.checkin.streak === 7 ? '连续7天，香火值×2！' : ''}获得 ${earned} 香火值`
            : '今日已签到'
          this.showToast = true
          setTimeout(() => { this.showToast = false }, 2000)
        })

      if (this.showToast) {
        Text(this.toastMsg)
          .fontSize(12)
          .fontColor('#f9ca24')
          .margin({ top: 8 })
          .transition(TransitionEffect.OPACITY.animation({ duration: 300 }))
      }

      // 统计数字
      Row() {
        this.StatItem('总祈福', `${this.getTotalPrayers()}`)
        this.StatItem('磕头', `${this.enrichVM.totalKowtow}`)
        this.StatItem('胜率', `${this.enrichVM.getWinRate().rate}%`)
        this.StatItem('香火值', `${this.enrichVM.checkin.totalIncense}`)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceEvenly)
      .margin({ top: 16 })
    }
    .width('90%')
    .padding(16)
    .backgroundColor('rgba(249, 202, 36, 0.05)')
    .border({ width: 1, color: 'rgba(249, 202, 36, 0.2)', radius: 12 })
  }

  @Builder
  StatItem(label: string, value: string) {
    Column() {
      Text(value)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#f9ca24')
      Text(label)
        .fontSize(10)
        .fontColor('rgba(253, 246, 227, 0.5)')
        .margin({ top: 2 })
    }
    .alignItems(HorizontalAlign.Center)
  }

  private getDayLabel(index: number): string {
    const labels = ['一', '二', '三', '四', '五', '六', '七']
    return `第${labels[index]}天`
  }

  private getTotalPrayers(): number {
    try {
      const vm = AppStorage.get<PrayerViewModel>('viewModel')
      return vm ? vm.totalPrayers : 0
    } catch {
      return 0
    }
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add entry/src/main/ets/components/CheckinCard.ets
git commit -m "feat: add CheckinCard component with mahjong tile checkin and stats"
```

---

### Task 2.2: 祈福日记页面（迁移历史记录）

**Files:**
- Create: `entry/src/main/ets/components/DiaryList.ets`

- [ ] **Step 1: 创建 DiaryList 组件**

```typescript
// entry/src/main/ets/components/DiaryList.ets
import { PrayerRecord } from '../model/PrayerTypes'
import { EnrichViewModel } from '../viewmodels/EnrichViewModel'
import { FIVE_DEITIES } from '../model/PrayerTypes'

class DiaryDataSource implements IDataSource {
  private records: PrayerRecord[] = []
  private listeners: DataChangeListener[] = []

  totalCount(): number { return this.records.length }
  getData(index: number): PrayerRecord { return this.records[index] }
  registerDataChangeListener(listener: DataChangeListener): void { this.listeners.push(listener) }
  unregisterDataChangeListener(listener: DataChangeListener): void {
    const idx = this.listeners.indexOf(listener)
    if (idx >= 0) this.listeners.splice(idx, 1)
  }
  setRecords(records: PrayerRecord[]): void {
    this.records = records
    this.listeners.forEach((listener) => listener.onDataReloaded())
  }
}

@Component
export struct DiaryList {
  @Prop @Watch('onRecordsUpdated') records: PrayerRecord[]
  @Link enrichVM: EnrichViewModel
  @State editingId: string = ''
  @State editingNote: string = ''
  private dataSource: DiaryDataSource = new DiaryDataSource()

  aboutToAppear(): void { this.dataSource.setRecords(this.records) }
  onRecordsUpdated(): void { this.dataSource.setRecords(this.records) }

  build() {
    if (this.records.length === 0) {
      Column() {
        Text('🎋')
          .fontSize(40)
          .margin({ bottom: 8 })
        Text('还没有祈福记录')
          .fontSize(14)
          .fontColor('rgba(253, 246, 227, 0.5)')
        Text('去拜拜麻神吧！')
          .fontSize(14)
          .fontColor('rgba(253, 246, 227, 0.5)')
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else {
      List() {
        LazyForEach(this.dataSource, (record: PrayerRecord) => {
          ListItem() {
            this.DiaryItem(record)
          }
        }, (record: PrayerRecord) => record.id)
      }
      .cachedCount(5)
      .layoutWeight(1)
    }
  }

  @Builder
  DiaryItem(record: PrayerRecord) {
    Column() {
      Row() {
        Column() {
          Text(record.name)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#fdf6e3')
          Text(this.formatTime(record.timestamp))
            .fontSize(11)
            .fontColor('rgba(253, 246, 227, 0.4)')
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Text(record.blessing.substring(0, 24) + '...')
          .fontSize(12)
          .fontColor('rgba(253, 246, 227, 0.6)')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('45%')
      }
      .width('100%')

      // 备注区域
      if (this.editingId === record.id) {
        Row() {
          TextInput({ text: this.editingNote, placeholder: '添加备注...' })
            .fontSize(12)
            .fontColor('#fdf6e3')
            .placeholderColor('rgba(253, 246, 227, 0.3)')
            .backgroundColor('rgba(249, 202, 36, 0.08)')
            .borderRadius(6)
            .height(32)
            .layoutWeight(1)
            .onChange((value: string) => { this.editingNote = value })
          Button('保存')
            .fontSize(11)
            .fontColor('#1a1a0a')
            .backgroundColor('#f9ca24')
            .borderRadius(4)
            .height(28)
            .padding({ left: 10, right: 10 })
            .margin({ left: 8 })
            .onClick(() => {
              this.enrichVM.setDiaryNote(record.id, this.editingNote)
              this.editingId = ''
            })
        }
        .width('100%')
        .margin({ top: 8 })
      } else {
        Row() {
          Text(this.enrichVM.getDiaryNote(record.id) || '点击添加备注')
            .fontSize(11)
            .fontColor(this.enrichVM.getDiaryNote(record.id) ? 'rgba(253, 246, 227, 0.5)' : 'rgba(253, 246, 227, 0.2)')
            .fontStyle(this.enrichVM.getDiaryNote(record.id) ? FontStyle.Normal : FontStyle.Italic)
            .onClick(() => {
              this.editingId = record.id
              this.editingNote = this.enrichVM.getDiaryNote(record.id)
            })
        }
        .width('100%')
        .margin({ top: 8 })
      }
    }
    .width('100%')
    .padding(12)
    .border({ width: { bottom: 0.5 }, color: 'rgba(249, 202, 36, 0.1)' })
  }

  private formatTime(timestamp: number): string {
    const d = new Date(timestamp)
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')} ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add entry/src/main/ets/components/DiaryList.ets
git commit -m "feat: add DiaryList component with editable notes"
```

---

### Task 2.3: 牌运记录组件

**Files:**
- Create: `entry/src/main/ets/components/GameRecordCard.ets`

- [ ] **Step 1: 创建 GameRecordCard 组件**

```typescript
// entry/src/main/ets/components/GameRecordCard.ets
import { GameRecord, GameResult } from '../model/EnrichTypes'
import { EnrichViewModel } from '../viewmodels/EnrichViewModel'
import { FIVE_DEITIES } from '../model/PrayerTypes'

@Component
export struct GameRecordCard {
  @Link enrichVM: EnrichViewModel
  @State showAddDialog: boolean = false
  @State addResult: '+' | '·' = '+'
  @State addMagnitude: number = 5
  @State addNote: string = ''

  build() {
    Column() {
      // 今日牌运标题
      Row() {
        Text('🀇 今日牌运')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#f9ca24')
        Blank()
        Text('+ 记录牌局')
          .fontSize(12)
          .fontColor('rgba(249, 202, 36, 0.6)')
          .onClick(() => { this.showAddDialog = true })
      }
      .width('100%')
      .margin({ bottom: 12 })

      // 牌局列表
      if (this.enrichVM.gameRecords.length === 0) {
        Text('暂无牌运记录，打牌后来记录吧')
          .fontSize(12)
          .fontColor('rgba(253, 246, 227, 0.3)')
          .fontStyle(FontStyle.Italic)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 20, bottom: 20 })
      } else {
        ForEach(this.enrichVM.gameRecords, (record: GameRecord) => {
          this.RecordItem(record)
        })
      }

      // 本周牌运统计
      if (this.enrichVM.gameRecords.length > 0) {
        Row()
          .width('100%')
          .height(1)
          .backgroundColor('rgba(249, 202, 36, 0.15)')
          .margin({ top: 12, bottom: 12 })

        this.WeekSummary()
      }
    }
    .width('90%')
    .padding(16)
    .backgroundColor('rgba(249, 202, 36, 0.05)')
    .border({ width: 1, color: 'rgba(249, 202, 36, 0.2)', radius: 12 })
  }

  @Builder
  RecordItem(record: GameRecord) {
    Column() {
      Row() {
        Text(`📅 ${record.date}`)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#fdf6e3')
        Blank()
        Text(this.getDeityName(record.deityId))
          .fontSize(11)
          .fontColor('rgba(253, 246, 227, 0.4)')
      }
      .width('100%')

      if (record.games.length > 0) {
        // 符号行
        Row() {
          ForEach(record.games, (game: GameResult) => {
            Text(game.result)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(game.result === '+' ? '#2ecc71' : 'rgba(253, 246, 227, 0.4)')
              .margin({ right: 4 })
          })
        }
        .width('100%')
        .margin({ top: 6 })

        // 数字行
        Row() {
          ForEach(record.games, (game: GameResult) => {
            Text(`${game.magnitude}`)
              .fontSize(12)
              .fontColor(game.result === '+' ? 'rgba(46, 204, 113, 0.7)' : 'rgba(253, 246, 227, 0.3)')
              .margin({ right: 4 })
              .width(20)
              .textAlign(TextAlign.Center)
          })
        }
        .width('100%')
      }

      // 备注
      if (record.note) {
        Text(record.note)
          .fontSize(11)
          .fontColor('rgba(253, 246, 227, 0.4)')
          .fontStyle(FontStyle.Italic)
          .margin({ top: 6 })
      }
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .border({ width: { bottom: 0.5 }, color: 'rgba(249, 202, 36, 0.08)' })
  }

  @Builder
  WeekSummary() {
    Column() {
      Text('📊 本周牌运')
        .fontSize(12)
        .fontColor('rgba(249, 202, 36, 0.7)')
        .margin({ bottom: 6 })

      // 本周符号串
      Row() {
        ForEach(this.getWeekGames(), (game: GameResult) => {
          Text(game.result)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(game.result === '+' ? '#2ecc71' : 'rgba(253, 246, 227, 0.4)')
            .margin({ right: 2 })
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)

      Row() {
        Text(`祈福胜率：${this.enrichVM.getWinRate().rate}%`)
          .fontSize(11)
          .fontColor('rgba(253, 246, 227, 0.5)')
        Text(` | `)
          .fontSize(11)
          .fontColor('rgba(253, 246, 227, 0.2)')
        Text(`最佳财神：${this.enrichVM.getBestDeity()}`)
          .fontSize(11)
          .fontColor('rgba(253, 246, 227, 0.5)')
      }
      .margin({ top: 4 })
    }
  }

  private getWeekGames(): GameResult[] {
    const now = new Date()
    const weekAgo = new Date(now.getTime() - 7 * 86400000)
    const weekStr = `${weekAgo.getFullYear()}-${String(weekAgo.getMonth() + 1).padStart(2, '0')}-${String(weekAgo.getDate()).padStart(2, '0')}`
    const results: GameResult[] = []
    for (const r of this.enrichVM.gameRecords) {
      if (r.date >= weekStr) {
        results.push(...r.games)
      }
    }
    return results
  }

  private getDeityName(deityId: number): string {
    const deity = FIVE_DEITIES.find(d => d.id === deityId)
    return deity ? `${deity.name}（${deity.direction}）` : ''
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add entry/src/main/ets/components/GameRecordCard.ets
git commit -m "feat: add GameRecordCard component with +/- notation and weekly summary"
```

---

### Task 2.4: 成就徽章组件

**Files:**
- Create: `entry/src/main/ets/components/AchievementGrid.ets`

- [ ] **Step 1: 创建 AchievementGrid 组件**

```typescript
// entry/src/main/ets/components/AchievementGrid.ets
import { Achievement } from '../model/EnrichTypes'
import { EnrichViewModel } from '../viewmodels/EnrichViewModel'

@Component
export struct AchievementGrid {
  @Link enrichVM: EnrichViewModel

  build() {
    Column() {
      Text('🏅 成就徽章')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#f9ca24')
        .width('90%')
        .margin({ bottom: 12 })

      Grid() {
        ForEach(this.enrichVM.achievements, (badge: Achievement) => {
          GridItem() {
            this.BadgeItem(badge)
          }
        })
      }
      .columnsTemplate('1fr 1fr 1fr 1fr')
      .rowsGap(12)
      .columnsGap(8)
      .width('90%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  BadgeItem(badge: Achievement) {
    Column() {
      Text(badge.icon)
        .fontSize(28)
        .opacity(badge.unlocked ? 1 : 0.25)
        .grayscale(badge.unlocked ? 0 : 1)

      Text(badge.name)
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor(badge.unlocked ? '#f9ca24' : 'rgba(253, 246, 227, 0.3)')
        .margin({ top: 4 })
        .textAlign(TextAlign.Center)

      // 进度条（未解锁时显示）
      if (!badge.unlocked && badge.progress > 0) {
        Row()
          .width('80%')
          .height(3)
          .backgroundColor('rgba(253, 246, 227, 0.1)')
          .borderRadius(2)
          .margin({ top: 4 })

        Row()
          .width(`${badge.progress * 80}%`)
          .height(3)
          .backgroundColor('#f9ca24')
          .borderRadius(2)
          .position({ x: '10%', y: 0 })
      }
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .alignItems(HorizontalAlign.Center)
    .borderRadius(8)
    .backgroundColor(badge.unlocked ? 'rgba(249, 202, 36, 0.08)' : 'rgba(253, 246, 227, 0.03)')
    .border({ width: badge.unlocked ? 1 : 0, color: 'rgba(249, 202, 36, 0.2)', radius: 8 })
    .onClick(() => {
      if (badge.unlocked) {
        this.getUIContext().getPromptAction().showToast({
          message: `${badge.name}：${badge.desc}（${badge.unlockDate} 解锁）`
        })
      } else {
        this.getUIContext().getPromptAction().showToast({
          message: `${badge.name}：${badge.desc}（进度 ${Math.round(badge.progress * 100)}%）`
        })
      }
    })
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add entry/src/main/ets/components/AchievementGrid.ets
git commit -m "feat: add AchievementGrid component with 8 mahjong-themed badges"
```

---

### Task 2.5: 创建 MyPage 页面

**Files:**
- Create: `entry/src/main/ets/pages/MyPage.ets`

- [ ] **Step 1: 创建 MyPage 页面**

```typescript
// entry/src/main/ets/pages/MyPage.ets
import { PrayerViewModel } from '../viewmodels/PrayerViewModel'
import { EnrichViewModel } from '../viewmodels/EnrichViewModel'
import { CheckinCard } from '../components/CheckinCard'
import { DiaryList } from '../components/DiaryList'
import { GameRecordCard } from '../components/GameRecordCard'
import { AchievementGrid } from '../components/AchievementGrid'

@Component
export struct MyPage {
  @StorageLink('viewModel') viewModel: PrayerViewModel = new PrayerViewModel()
  @StorageLink('enrichViewModel') enrichVM: EnrichViewModel = new EnrichViewModel()
  @State currentSection: string = 'home'

  build() {
    Column() {
      // 顶部标题
      Text('我的')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#f9ca24')
        .width('100%')
        .padding({ left: 20, top: 12, bottom: 8 })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

      if (this.currentSection === 'home') {
        Scroll() {
          Column() {
            // 签到卡片
            CheckinCard({ enrichVM: this.enrichVM })
              .margin({ top: 12, bottom: 12 })

            // 入口列表
            this.MenuItem('📝 祈福日记', '', () => { this.currentSection = 'diary' })
            this.MenuItem('🀇 牌运记录', '', () => { this.currentSection = 'game' })
            this.MenuItem('🏅 成就徽章', `${this.enrichVM.achievements.filter(a => a.unlocked).length}/8`, () => { this.currentSection = 'achievement' })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      } else {
        // 子页面头部
        Row() {
          Text('← 返回')
            .fontSize(14)
            .fontColor('#f9ca24')
            .onClick(() => { this.currentSection = 'home' })
          Blank()
          Text(this.getSectionTitle())
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#f9ca24')
          Blank()
          Text('')
            .width(60)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })

        if (this.currentSection === 'diary') {
          DiaryList({ records: this.viewModel.history, enrichVM: this.enrichVM })
        } else if (this.currentSection === 'game') {
          Scroll() {
            GameRecordCard({ enrichVM: this.enrichVM })
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        } else if (this.currentSection === 'achievement') {
          Scroll() {
            AchievementGrid({ enrichVM: this.enrichVM })
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1a1a0a')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
  }

  @Builder
  MenuItem(label: string, value: string, onClick: () => void) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor('#fdf6e3')
      Blank()
      if (value) {
        Text(value)
          .fontSize(12)
          .fontColor('rgba(249, 202, 36, 0.6)')
          .margin({ right: 8 })
      }
      Text('→')
        .fontSize(14)
        .fontColor('rgba(253, 246, 227, 0.3)')
    }
    .width('90%')
    .padding(16)
    .backgroundColor('rgba(249, 202, 36, 0.05)')
    .border({ width: 1, color: 'rgba(249, 202, 36, 0.1)', radius: 8 })
    .margin({ bottom: 8 })
    .onClick(onClick)
  }

  private getSectionTitle(): string {
    switch (this.currentSection) {
      case 'diary': return '祈福日记'
      case 'game': return '牌运记录'
      case 'achievement': return '成就徽章'
      default: return ''
    }
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add entry/src/main/ets/pages/MyPage.ets
git commit -m "feat: add MyPage with checkin, diary, game records, achievements"
```

---

### Phase 3: Tab 1 "祈福广场"

### Task 3.1: 今日黄历组件

**Files:**
- Create: `entry/src/main/ets/components/DailyAlmanac.ets`

- [ ] **Step 1: 创建 DailyAlmanac 组件**

```typescript
// entry/src/main/ets/components/DailyAlmanac.ets
import { EnrichViewModel } from '../viewmodels/EnrichViewModel'
import { PrayerViewModel } from '../viewmodels/PrayerViewModel'

@Component
export struct DailyAlmanac {
  @Link enrichVM: EnrichViewModel
  @StorageLink('viewModel') viewModel: PrayerViewModel = new PrayerViewModel()

  build() {
    Column() {
      // 日期行
      Text(`📅 ${this.getLunarDate()} · ${this.getWeekday()}`)
        .fontSize(12)
        .fontColor('rgba(249, 202, 36, 0.6)')
        .margin({ bottom: 8 })

      // 黄历主卡片
      Row() {
        // 宜忌
        Column() {
          Text('宜 ✅')
            .fontSize(10)
            .fontColor('rgba(46, 204, 113, 0.8)')
            .margin({ bottom: 2 })
          Text(this.enrichVM.getAlmanac().suitable)
            .fontSize(12)
            .fontColor('#fdf6e3')
        }
        .alignItems(HorizontalAlign.Center)
        .width('30%')

        // 中间信息
        Column() {
          Text(`主神：${this.viewModel.todayDeity.name}`)
            .fontSize(11)
            .fontColor('#f9ca24')
            .margin({ bottom: 4 })
          Text(`吉位：${this.enrichVM.getAlmanac().direction}`)
            .fontSize(10)
            .fontColor('rgba(253, 246, 227, 0.6)')
            .margin({ bottom: 2 })
          Text(`花色：${this.enrichVM.getAlmanac().luckySuit}`)
            .fontSize(10)
            .fontColor('rgba(253, 246, 227, 0.6)')
        }
        .alignItems(HorizontalAlign.Center)
        .width('40%')

        // 忌
        Column() {
          Text('忌 ❌')
            .fontSize(10)
            .fontColor('rgba(231, 76, 60, 0.8)')
            .margin({ bottom: 2 })
          Text(this.enrichVM.getAlmanac().avoid)
            .fontSize(12)
            .fontColor('rgba(253, 246, 227, 0.7)')
        }
        .alignItems(HorizontalAlign.Center)
        .width('30%')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      // 香火指示
      Text(`今日香火：${this.getIncenseBar()}`)
        .fontSize(11)
        .fontColor('rgba(253, 246, 227, 0.4)')
        .margin({ top: 8 })
    }
    .width('90%')
    .padding(12)
    .backgroundColor('rgba(192, 57, 43, 0.08)')
    .border({ width: 1, color: 'rgba(249, 202, 36, 0.2)', radius: 10 })
    .position({ x: '50%', y: 12 })
    .translate({ x: '-50%', y: '0' })
  }

  private getIncenseBar(): string {
    const count = this.enrichVM.getAlmanac().incenseCount || 0
    const flames = Math.min(Math.floor(count / 30) + 1, 5)
    return '🔥'.repeat(flames)
  }

  private getLunarDate(): string {
    const d = new Date()
    const months = ['正月', '二月', '三月', '四月', '五月', '六月', '七月', '八月', '九月', '十月', '冬月', '腊月']
    const days = ['初一', '初二', '初三', '初四', '初五', '初六', '初七', '初八', '初九', '初十',
      '十一', '十二', '十三', '十四', '十五', '十六', '十七', '十八', '十九', '二十',
      '廿一', '廿二', '廿三', '廿四', '廿五', '廿六', '廿七', '廿八', '廿九', '三十']
    // 简单估算：农历月≈公历月-1（不做精确转换，视觉装饰用）
    const m = ((d.getMonth() + 11) % 12)
    const day = ((d.getDate() + 30) % 30)
    return `${months[m]}${days[day]}`
  }

  private getWeekday(): string {
    const days = ['周日', '周一', '周二', '周三', '周四', '周五', '周六']
    return days[new Date().getDay()]
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add entry/src/main/ets/components/DailyAlmanac.ets
git commit -m "feat: add DailyAlmanac component with auspicious direction and lucky suit"
```

---

### Task 3.2: 更新 EntryAbility 和主入口

**Files:**
- Modify: `entry/src/main/ets/entryability/EntryAbility.ets`
- Modify: `entry/src/main/ets/viewmodels/PrayerViewModel.ets`

- [ ] **Step 1: 更新 EntryAbility 初始化 EnrichViewModel**

修改 `entry/src/main/ets/entryability/EntryAbility.ets`，在 `onCreate` 中新增 EnrichViewModel 初始化，将入口改为 MainTabs：

```typescript
import { UIAbility, Want, AbilityConstant } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { AudioManager } from '../service/AudioManager'
import { PrayerViewModel } from '../viewmodels/PrayerViewModel'
import { EnrichViewModel } from '../viewmodels/EnrichViewModel'

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    AudioManager.getInstance().init(this.context).catch((err: Object) => {
      console.error('AudioManager init failed:', JSON.stringify(err))
    })

    const viewModel = new PrayerViewModel()
    AppStorage.setOrCreate('viewModel', viewModel)
    viewModel.initialize(this.context).catch((err: Object) => {
      console.error('PrayerViewModel init failed:', JSON.stringify(err))
    })

    // 新增：初始化 EnrichViewModel
    const enrichVM = new EnrichViewModel()
    AppStorage.setOrCreate('enrichViewModel', enrichVM)
    enrichVM.initialize(this.context).catch((err: Object) => {
      console.error('EnrichViewModel init failed:', JSON.stringify(err))
    })
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    const mainWindow = windowStage.getMainWindowSync()
    mainWindow.setWindowLayoutFullScreen(true).then(() => {
      return mainWindow.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        statusBarContentColor: '#f9ca24',
        navigationBarColor: '#00000000',
        navigationBarContentColor: '#f9ca24'
      })
    }).catch((err: Object) => {
      console.error('Immersive window setup failed:', JSON.stringify(err))
    })

    // 改为加载 MainTabs
    windowStage.loadContent('pages/MainTabs', (err) => {
      if (err.code) {
        console.error('Failed to load content:', JSON.stringify(err))
      }
    })
  }

  onBackground(): void {
    AudioManager.getInstance().stopBgm()
  }

  onDestroy(): void {
    AudioManager.getInstance().release()
  }
}
```

- [ ] **Step 2: 更新 PrayerViewModel 触发成就追踪**

在 `PrayerViewModel` 的 `saveRecord` 方法末尾，添加磕头/财神追踪：

修改 `entry/src/main/ets/viewmodels/PrayerViewModel.ets`，在 `saveRecord` 的最后（`await this.persistData()` 之前）添加：

```typescript
// 在 saveRecord() 方法中，this.history 处理之后，persistData 之前添加：
// 通知 EnrichViewModel 更新磕头/财神追踪
try {
  const enrichVM = AppStorage.get<EnrichViewModel>('enrichViewModel')
  if (enrichVM) {
    enrichVM.onKowtowDone(this.kowtowCount, this.todayDeity.id)
  }
} catch (err) {
  console.error('[PrayerViewModel] Failed to update enrichVM:', JSON.stringify(err))
}
```

同时需要导入 EnrichViewModel：
```typescript
import { EnrichViewModel } from '../viewmodels/EnrichViewModel'
```

- [ ] **Step 3: 更新 main_pages.json**

```json
{
  "src": [
    "pages/MainTabs",
    "pages/HomePage",
    "pages/NameCard",
    "pages/PrayerCard",
    "pages/BlessingCard"
  ]
}
```

- [ ] **Step 4: 提交**

```bash
git add entry/src/main/ets/entryability/EntryAbility.ets entry/src/main/ets/viewmodels/PrayerViewModel.ets entry/src/main/resources/base/profile/main_pages.json
git commit -m "feat: switch entry to MainTabs, init EnrichViewModel, wire kowtow tracking"
```

---

### Phase 4: 云函数

### Task 4.1: 创建 CloudService 封装

**Files:**
- Create: `entry/src/main/ets/service/CloudService.ets`

- [ ] **Step 1: 创建 CloudService**

```typescript
// entry/src/main/ets/service/CloudService.ets
import { cloudFunction } from '@kit.CloudFoundationKit'
import { LeaderboardEntry, LeaderboardType, Wish } from '../model/EnrichTypes'

export class CloudService {
  private static getUserId(): string {
    try {
      // 使用设备随机 ID 作为用户标识
      return AppStorage.get<string>('deviceUserId') || 'unknown'
    } catch {
      return 'unknown'
    }
  }

  private static getNickname(): string {
    try {
      const name = AppStorage.get<string>('lastPrayerName') || '麻友'
      // 脱敏：首字 + ***
      return name.substring(0, 1) + '***'
    } catch {
      return '麻***'
    }
  }

  static async updatePrayerCount(kowtowCount: number, streak: number): Promise<boolean> {
    try {
      const result = await cloudFunction.call({
        name: 'update-prayer-count',
        data: {
          __uid: this.getUserId(),
          nickname: this.getNickname(),
          kowtowCount,
          streak
        }
      })
      return result.result?.code === 0
    } catch (err) {
      console.error('[CloudService] updatePrayerCount failed:', JSON.stringify(err))
      return false
    }
  }

  static async getLeaderboard(type: LeaderboardType): Promise<LeaderboardEntry[]> {
    try {
      const result = await cloudFunction.call({
        name: 'get-leaderboard',
        data: {
          type,
          __uid: this.getUserId()
        }
      })
      if (result.result?.code === 0 && result.result?.data) {
        return result.result.data as LeaderboardEntry[]
      }
      return []
    } catch (err) {
      console.error('[CloudService] getLeaderboard failed:', JSON.stringify(err))
      return []
    }
  }

  static async getTodayIncenseCount(): Promise<number> {
    try {
      const result = await cloudFunction.call({
        name: 'get-leaderboard',
        data: {
          type: 'daily-count',
          __uid: this.getUserId()
        }
      })
      return result.result?.data?.count || 0
    } catch (err) {
      return 0
    }
  }

  static async getWishes(): Promise<Wish[]> {
    try {
      const result = await cloudFunction.call({
        name: 'wish-wall',
        data: {
          action: 'list',
          __uid: this.getUserId()
        }
      })
      if (result.result?.code === 0 && result.result?.data) {
        return result.result.data as Wish[]
      }
      return []
    } catch (err) {
      console.error('[CloudService] getWishes failed:', JSON.stringify(err))
      return []
    }
  }

  static async createWish(content: string, deityId: number): Promise<boolean> {
    try {
      const result = await cloudFunction.call({
        name: 'wish-wall',
        data: {
          action: 'create',
          content,
          deityId,
          nickname: this.getNickname(),
          __uid: this.getUserId()
        }
      })
      return result.result?.code === 0
    } catch (err) {
      console.error('[CloudService] createWish failed:', JSON.stringify(err))
      return false
    }
  }

  static async fulfillWish(wishId: string): Promise<boolean> {
    try {
      const result = await cloudFunction.call({
        name: 'wish-wall',
        data: {
          action: 'fulfill',
          wishId,
          __uid: this.getUserId()
        }
      })
      return result.result?.code === 0
    } catch (err) {
      console.error('[CloudService] fulfillWish failed:', JSON.stringify(err))
      return false
    }
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add entry/src/main/ets/service/CloudService.ets
git commit -m "feat: add CloudService for leaderboard and wish wall cloud functions"
```

---

### Task 4.2: 创建云函数（update-prayer-count）

**Files:**
- Create: `cloud/update-prayer-count/handler.js`
- Create: `cloud/update-prayer-count/package.json`
- Create: `cloud/shared/response.js`（如不存在）
- Create: `cloud/shared/db.js`（如不存在）

- [ ] **Step 1: 创建 shared/response.js**

```javascript
// cloud/shared/response.js
const CODE = {
  OK: 0, PARAM_ERROR: 400, UNAUTHORIZED: 401,
  FORBIDDEN: 403, NOT_FOUND: 404, SERVER_ERROR: 500
};

function success(data, message) {
  return { code: CODE.OK, message: message || 'success', data: data || null };
}

function fail(code, message, data) {
  return { code: code, message: message || 'error', data: data || null };
}

function extractBody(event) {
  if (event && event.request !== undefined && event.request !== null) {
    if (typeof event.request === 'string') {
      try { return JSON.parse(event.request); } catch (e) { return {}; }
    }
    if (typeof event.request === 'object') {
      if (event.request.body !== undefined && event.request.body !== null) {
        if (typeof event.request.body === 'string') {
          try { return JSON.parse(event.request.body); } catch (e) { return {}; }
        }
        return event.request.body;
      }
      return event.request;
    }
  }
  return {};
}

function wrapHttp(handler) {
  return async function (event, context, callback, logger) {
    const cb = callback || (context && context.callback) || function () {};
    const log = logger || (context && context.logger) || console;
    try {
      const body = extractBody(event);
      const result = await handler(body, event, context, log);
      cb(result);
    } catch (err) {
      const msg = (err && err.message) || 'Internal error';
      log.error('[wrapHttp] error: ' + (err && err.stack || msg));
      cb(fail(CODE.SERVER_ERROR, msg));
    }
  };
}

module.exports = { CODE, success, fail, wrapHttp, extractBody };
```

- [ ] **Step 2: 创建 shared/db.js**

```javascript
// cloud/shared/db.js
const { cloud, CloudDBZoneGenericObject } = require('@hw-agconnect/cloud-server');
const fs = require('fs'), path = require('path');
const CRED_FILE = path.join(__dirname, '..', 'agc-credential.json');

let cloudInstance = null;

function getCloud() {
  if (cloudInstance) return cloudInstance;
  if (fs.existsSync(CRED_FILE)) {
    try {
      cloudInstance = cloud.createInstance(CRED_FILE, 'mashen-cloud-db');
      return cloudInstance;
    } catch (e) { console.warn('[db] createInstance failed:', e.message); }
  }
  cloudInstance = cloud;
  return cloudInstance;
}

function toGenericObjects(objectType, records) {
  if (!Array.isArray(records)) records = [records];
  return records.map(function (r) {
    if (r instanceof CloudDBZoneGenericObject) return r;
    var obj = CloudDBZoneGenericObject.build(objectType);
    for (var key of Object.keys(r)) {
      if (typeof r[key] !== 'function' && r[key] !== undefined) {
        obj.addFieldValue(key, r[key], false);
      }
    }
    return obj;
  });
}

module.exports = { getCloud, toGenericObjects };
```

- [ ] **Step 3: 创建 update-prayer-count/handler.js**

```javascript
// cloud/update-prayer-count/handler.js
const { wrapHttp, success, fail, CODE } = require('../shared/response');
const { getCloud, toGenericObjects } = require('../shared/db');

async function handler(body, event, context, log) {
  const uid = body.__uid;
  const nickname = body.nickname || '麻***';
  const kowtowCount = body.kowtowCount || 0;
  const streak = body.streak || 0;

  if (!uid) return fail(CODE.UNAUTHORIZED, 'uid required');

  const cloudInstance = getCloud();
  const db = cloudInstance.database();
  const LeaderboardType = cloudInstance.CloudDBZoneGenericObject.getObjectType('Leaderboard');

  try {
    // 查询现有记录
    const query = cloudInstance.CloudDBZoneQuery.where(LeaderboardType).equalTo('userId', uid);
    const existing = await db.collection(LeaderboardType).query(query);

    const now = new Date().toISOString();
    const today = new Date().toISOString().split('T')[0];

    if (existing && existing.length > 0) {
      const record = existing[0];
      const updatedAt = record.updatedAt || '';
      const isNewDay = !updatedAt.startsWith(today);

      const data = {
        userId: uid,
        nickname: nickname,
        todayCount: isNewDay ? 1 : (record.todayCount || 0) + 1,
        weekCount: (record.weekCount || 0) + 1,
        totalCount: (record.totalCount || 0) + 1,
        totalKowtow: (record.totalKowtow || 0) + kowtowCount,
        streak: streak,
        updatedAt: now
      };
      const genericObjects = toGenericObjects(LeaderboardType, data);
      await db.collection(LeaderboardType).upsert(genericObjects);
    } else {
      const data = {
        userId: uid,
        nickname: nickname,
        todayCount: 1,
        weekCount: 1,
        totalCount: 1,
        totalKowtow: kowtowCount,
        streak: streak,
        updatedAt: now
      };
      const genericObjects = toGenericObjects(LeaderboardType, data);
      await db.collection(LeaderboardType).upsert(genericObjects);
    }

    return success({ updated: true });
  } catch (err) {
    log.error('[update-prayer-count] DB error:', err.message);
    return fail(CODE.SERVER_ERROR, 'db error: ' + err.message);
  }
}

module.exports.myHandler = wrapHttp(handler);
```

- [ ] **Step 4: 创建 update-prayer-count/package.json**

```json
{
  "name": "update-prayer-count",
  "version": "1.0.0",
  "main": "handler.js",
  "dependencies": {
    "@hw-agconnect/cloud-server": "^1.0.5"
  }
}
```

- [ ] **Step 5: 提交**

```bash
git add cloud/
git commit -m "feat: add update-prayer-count cloud function"
```

---

### Task 4.3: 创建云函数（get-leaderboard + wish-wall）

- [ ] **Step 1: 创建 get-leaderboard/handler.js**

```javascript
// cloud/get-leaderboard/handler.js
const { wrapHttp, success, fail, CODE } = require('../shared/response');
const { getCloud } = require('../shared/db');

async function handler(body, event, context, log) {
  const type = body.type || 'daily';
  const uid = body.__uid || '';

  // 今日香火人数统计
  if (type === 'daily-count') {
    const cloudInstance = getCloud();
    const Leaderboard = cloudInstance.CloudDBZoneGenericObject.getObjectType('Leaderboard');
    const query = cloudInstance.CloudDBZoneQuery.where(Leaderboard).greaterThan('todayCount', 0);
    try {
      const result = await cloudInstance.database().collection(Leaderboard).query(query);
      return success({ count: result ? result.length : 0 });
    } catch (err) {
      return success({ count: 0 });
    }
  }

  const cloudInstance = getCloud();
  const Leaderboard = cloudInstance.CloudDBZoneGenericObject.getObjectType('Leaderboard');

  let query;
  try {
    switch (type) {
      case 'daily':
        query = cloudInstance.CloudDBZoneQuery.where(Leaderboard).greaterThan('todayCount', 0)
          .orderByDesc('todayCount').limit(50);
        break;
      case 'weekly':
        query = cloudInstance.CloudDBZoneQuery.where(Leaderboard).greaterThan('weekCount', 0)
          .orderByDesc('weekCount').limit(50);
        break;
      case 'total':
      default:
        query = cloudInstance.CloudDBZoneQuery.where(Leaderboard).greaterThan('totalCount', 0)
          .orderByDesc('totalCount').limit(50);
        break;
    }

    const result = await cloudInstance.database().collection(Leaderboard).query(query);

    const entries = (result || []).map((item, index) => ({
      userId: item.userId || '',
      nickname: item.nickname || '麻***',
      count: type === 'daily' ? (item.todayCount || 0) : (type === 'weekly' ? (item.weekCount || 0) : (item.totalCount || 0)),
      kowtow: item.totalKowtow || 0,
      rank: index + 1
    }));

    // 如果当前用户不在榜单中，追加用户自己的排名
    if (uid) {
      const userEntry = entries.find(e => e.userId === uid);
      if (!userEntry) {
        const userQuery = cloudInstance.CloudDBZoneQuery.where(Leaderboard).equalTo('userId', uid);
        const userResult = await cloudInstance.database().collection(Leaderboard).query(userQuery);
        if (userResult && userResult.length > 0) {
          const u = userResult[0];
          entries.push({
            userId: u.userId,
            nickname: u.nickname || '麻***',
            count: type === 'daily' ? (u.todayCount || 0) : (type === 'weekly' ? (u.weekCount || 0) : (u.totalCount || 0)),
            kowtow: u.totalKowtow || 0,
            rank: 0  // 不在前 50
          });
        }
      }
    }

    return success(entries);
  } catch (err) {
    log.error('[get-leaderboard] DB error:', err.message);
    return fail(CODE.SERVER_ERROR, 'query error: ' + err.message);
  }
}

module.exports.myHandler = wrapHttp(handler);
```

- [ ] **Step 2: 创建 get-leaderboard/package.json**

```json
{
  "name": "get-leaderboard",
  "version": "1.0.0",
  "main": "handler.js",
  "dependencies": {
    "@hw-agconnect/cloud-server": "^1.0.5"
  }
}
```

- [ ] **Step 3: 创建 wish-wall/handler.js**

```javascript
// cloud/wish-wall/handler.js
const { wrapHttp, success, fail, CODE } = require('../shared/response');
const { getCloud, toGenericObjects } = require('../shared/db');

async function handler(body, event, context, log) {
  const action = body.action;
  const uid = body.__uid;

  if (!uid) return fail(CODE.UNAUTHORIZED, 'uid required');

  const cloudInstance = getCloud();
  const WishType = cloudInstance.CloudDBZoneGenericObject.getObjectType('Wish');
  const db = cloudInstance.database();

  try {
    switch (action) {
      case 'list': {
        const query = cloudInstance.CloudDBZoneQuery.where(WishType)
          .orderByDesc('createdAt').limit(50);
        const result = await db.collection(WishType).query(query);
        const wishes = (result || []).map(item => ({
          id: item.id || '',
          userId: item.userId || '',
          nickname: item.nickname || '麻***',
          content: item.content || '',
          deityId: item.deityId || 0,
          fulfilled: item.fulfilled || false,
          createdAt: item.createdAt || '',
          fulfilledAt: item.fulfilledAt || ''
        }));
        return success(wishes);
      }

      case 'create': {
        const content = body.content;
        const deityId = body.deityId || 0;
        const nickname = body.nickname || '麻***';

        if (!content || content.length > 30) {
          return fail(CODE.PARAM_ERROR, 'content required, max 30 chars');
        }

        const id = 'w_' + Date.now() + '_' + Math.random().toString(36).substring(2, 8);
        const now = new Date().toISOString();

        const data = {
          id: id,
          userId: uid,
          nickname: nickname,
          content: content,
          deityId: deityId,
          fulfilled: false,
          createdAt: now,
          fulfilledAt: ''
        };
        const genericObjects = toGenericObjects(WishType, data);
        await db.collection(WishType).upsert(genericObjects);
        return success({ id, createdAt: now });
      }

      case 'fulfill': {
        const wishId = body.wishId;
        if (!wishId) return fail(CODE.PARAM_ERROR, 'wishId required');

        const query = cloudInstance.CloudDBZoneQuery.where(WishType).equalTo('id', wishId);
        const result = await db.collection(WishType).query(query);
        if (!result || result.length === 0) return fail(CODE.NOT_FOUND, 'wish not found');

        const wish = result[0];
        if (wish.userId !== uid) return fail(CODE.FORBIDDEN, 'not your wish');

        const now = new Date().toISOString();
        const data = {
          id: wishId,
          userId: uid,
          nickname: wish.nickname,
          content: wish.content,
          deityId: wish.deityId,
          fulfilled: true,
          createdAt: wish.createdAt,
          fulfilledAt: now
        };
        const genericObjects = toGenericObjects(WishType, data);
        await db.collection(WishType).upsert(genericObjects);
        return success({ fulfilled: true, fulfilledAt: now });
      }

      default:
        return fail(CODE.PARAM_ERROR, 'unknown action: ' + action);
    }
  } catch (err) {
    log.error('[wish-wall] DB error:', err.message);
    return fail(CODE.SERVER_ERROR, 'db error: ' + err.message);
  }
}

module.exports.myHandler = wrapHttp(handler);
```

- [ ] **Step 4: 创建 wish-wall/package.json**

```json
{
  "name": "wish-wall",
  "version": "1.0.0",
  "main": "handler.js",
  "dependencies": {
    "@hw-agconnect/cloud-server": "^1.0.5"
  }
}
```

- [ ] **Step 5: 提交**

```bash
git add cloud/get-leaderboard/ cloud/wish-wall/
git commit -m "feat: add get-leaderboard and wish-wall cloud functions"
```

---

### Phase 5: Tab 3 "排行榜"

### Task 5.1: 排行榜页面

**Files:**
- Create: `entry/src/main/ets/pages/Leaderboard.ets`
- Create: `entry/src/main/ets/components/LeaderboardItem.ets`

- [ ] **Step 1: 创建 LeaderboardItem 组件**

```typescript
// entry/src/main/ets/components/LeaderboardItem.ets
import { LeaderboardEntry } from '../model/EnrichTypes'

@Component
export struct LeaderboardItem {
  @Prop entry: LeaderboardEntry
  @Prop isMe: boolean = false

  build() {
    Row() {
      // 排名
      Text(this.getRankText())
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.getRankColor())
        .width(40)
        .textAlign(TextAlign.Center)

      // 昵称
      Text(this.entry.nickname)
        .fontSize(14)
        .fontColor('#fdf6e3')
        .layoutWeight(1)

      // 祈福次数
      Text(`${this.entry.count}次`)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#f9ca24')
        .margin({ right: 12 })

      // 磕头
      Text(`🙏${this.entry.kowtow}`)
        .fontSize(12)
        .fontColor('rgba(253, 246, 227, 0.5)')
    }
    .width('100%')
    .padding(12)
    .backgroundColor(this.isMe ? 'rgba(249, 202, 36, 0.12)' : 'transparent')
    .border({
      width: { bottom: 0.5 },
      color: 'rgba(249, 202, 36, 0.08)'
    })
    .borderRadius(this.isMe ? 8 : 0)
  }

  private getRankText(): string {
    if (this.entry.rank <= 0) return '···'
    if (this.entry.rank <= 3) return ['🥇', '🥈', '🥉'][this.entry.rank - 1]
    return `${this.entry.rank}`
  }

  private getRankColor(): string {
    if (this.entry.rank === 1) return '#f9ca24'
    if (this.entry.rank === 2) return '#c0c0c0'
    if (this.entry.rank === 3) return '#cd7f32'
    return 'rgba(253, 246, 227, 0.5)'
  }
}
```

- [ ] **Step 2: 创建 Leaderboard 页面**

```typescript
// entry/src/main/ets/pages/Leaderboard.ets
import { LeaderboardEntry, LeaderboardType } from '../model/EnrichTypes'
import { CloudService } from '../service/CloudService'
import { LeaderboardItem } from '../components/LeaderboardItem'

@Component
export struct LeaderboardPage {
  @State entries: LeaderboardEntry[] = []
  @State currentType: LeaderboardType = LeaderboardType.DAILY
  @State loading: boolean = false
  @State myEntry: LeaderboardEntry | null = null

  aboutToAppear(): void {
    this.loadData()
  }

  async loadData(): Promise<void> {
    this.loading = true
    try {
      const data = await CloudService.getLeaderboard(this.currentType)
      this.entries = data.filter(e => e.rank > 0)
      const me = data.find(e => e.rank === 0)
      this.myEntry = me || null
    } catch (err) {
      console.error('[Leaderboard] load failed:', JSON.stringify(err))
    } finally {
      this.loading = false
    }
  }

  build() {
    Column() {
      // 标题
      Text('🏆 祈福排行榜')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#f9ca24')
        .width('100%')
        .padding({ left: 20, top: 12, bottom: 8 })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

      // 榜单切换
      Row() {
        this.TabButton('日榜', LeaderboardType.DAILY)
        this.TabButton('周榜', LeaderboardType.WEEKLY)
        this.TabButton('总榜', LeaderboardType.TOTAL)
      }
      .width('90%')
      .justifyContent(FlexAlign.SpaceEvenly)
      .margin({ bottom: 12 })

      if (this.loading) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
            .color('#f9ca24')
          Text('加载中...')
            .fontSize(12)
            .fontColor('rgba(253, 246, 227, 0.5)')
            .margin({ top: 8 })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.entries.length === 0) {
        Column() {
          Text('🏆')
            .fontSize(40)
            .margin({ bottom: 8 })
          Text('暂无排行数据')
            .fontSize(14)
            .fontColor('rgba(253, 246, 227, 0.5)')
          Text('快去祈福上榜吧！')
            .fontSize(14)
            .fontColor('rgba(253, 246, 227, 0.5)')
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            ForEach(this.entries, (entry: LeaderboardEntry) => {
              LeaderboardItem({ entry: entry, isMe: false })
            })

            // 我的排名
            if (this.myEntry) {
              Row()
                .width('100%')
                .height(1)
                .backgroundColor('rgba(249, 202, 36, 0.2)')
                .margin({ top: 8, bottom: 8 })

              Text('我的排名')
                .fontSize(11)
                .fontColor('rgba(253, 246, 227, 0.4)')
                .width('90%')
                .margin({ bottom: 4 })

              LeaderboardItem({ entry: this.myEntry, isMe: true })
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }

      // 刷新按钮
      Button('🔄 刷新')
        .fontSize(12)
        .fontColor('rgba(249, 202, 36, 0.6)')
        .backgroundColor('transparent')
        .margin({ bottom: 12 })
        .onClick(() => { this.loadData() })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1a1a0a')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
  }

  @Builder
  TabButton(label: string, type: LeaderboardType) {
    Text(label)
      .fontSize(14)
      .fontWeight(this.currentType === type ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.currentType === type ? '#1a1a0a' : 'rgba(253, 246, 227, 0.5)')
      .backgroundColor(this.currentType === type ? '#f9ca24' : 'rgba(249, 202, 36, 0.1)')
      .borderRadius(16)
      .padding({ left: 16, right: 16, top: 6, bottom: 6 })
      .onClick(() => {
        this.currentType = type
        this.loadData()
      })
  }
}
```

- [ ] **Step 3: 提交**

```bash
git add entry/src/main/ets/components/LeaderboardItem.ets entry/src/main/ets/pages/Leaderboard.ets
git commit -m "feat: add Leaderboard page with daily/weekly/total tabs"
```

---

### Phase 6: Tab 2 "心愿墙"

### Task 6.1: 心愿墙页面

**Files:**
- Create: `entry/src/main/ets/pages/WishWall.ets`
- Create: `entry/src/main/ets/components/WishItem.ets`

- [ ] **Step 1: 创建 WishItem 组件**

```typescript
// entry/src/main/ets/components/WishItem.ets
import { Wish } from '../model/EnrichTypes'
import { CloudService } from '../service/CloudService'
import { EnrichViewModel } from '../viewmodels/EnrichViewModel'

@Component
export struct WishItem {
  @Prop wish: Wish
  @Link enrichVM: EnrichViewModel
  @State isOwn: boolean = false
  @State showFulfillConfirm: boolean = false

  aboutToAppear(): void {
    try {
      const uid = AppStorage.get<string>('deviceUserId') || ''
      this.isOwn = uid === this.wish.userId
    } catch {
      this.isOwn = false
    }
  }

  build() {
    Row() {
      Column() {
        Text(this.wish.content)
          .fontSize(14)
          .fontColor('#fdf6e3')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Row() {
          Text(this.wish.nickname)
            .fontSize(10)
            .fontColor('rgba(253, 246, 227, 0.3)')
          Text(' · ')
            .fontSize(10)
            .fontColor('rgba(253, 246, 227, 0.2)')
          Text(this.formatTime(this.wish.createdAt))
            .fontSize(10)
            .fontColor('rgba(253, 246, 227, 0.3)')
        }
        .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.wish.fulfilled) {
        Text('✅ 已还愿')
          .fontSize(11)
          .fontColor('rgba(46, 204, 113, 0.8)')
          .backgroundColor('rgba(46, 204, 113, 0.1)')
          .borderRadius(10)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      } else if (this.isOwn) {
        Text('🙏 还愿')
          .fontSize(11)
          .fontColor('#f9ca24')
          .backgroundColor('rgba(249, 202, 36, 0.1)')
          .borderRadius(10)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .onClick(() => {
            this.showFulfillConfirm = true
          })
      }
    }
    .width('100%')
    .padding(12)
    .border({
      width: { bottom: 0.5 },
      color: 'rgba(249, 202, 36, 0.08)'
    })
    .onClick(() => {
      if (this.showFulfillConfirm) {
        // 使用自定义确认
        this.getUIContext().getPromptAction().showDialog({
          title: '确认还愿',
          message: '确定要标记此心愿为已达成吗？',
          buttons: [
            { text: '取消', color: '#fdf6e3' },
            { text: '还愿', color: '#f9ca24' }
          ]
        }).then((result: { index: number }) => {
          if (result.index === 1) {
            CloudService.fulfillWish(this.wish.id).then((ok) => {
              if (ok) {
                this.enrichVM.incWishFulfilled()
                this.getUIContext().getPromptAction().showToast({ message: '还愿成功！' })
              }
            })
          }
        })
      }
    })
  }

  private formatTime(isoStr: string): string {
    if (!isoStr) return ''
    try {
      const d = new Date(isoStr)
      return `${d.getMonth() + 1}/${d.getDate()}`
    } catch {
      return ''
    }
  }
}
```

- [ ] **Step 2: 创建 WishWall 页面**

```typescript
// entry/src/main/ets/pages/WishWall.ets
import { Wish } from '../model/EnrichTypes'
import { CloudService } from '../service/CloudService'
import { EnrichViewModel } from '../viewmodels/EnrichViewModel'
import { FIVE_DEITIES } from '../model/PrayerTypes'
import { WishItem } from '../components/WishItem'

@Component
export struct WishWallPage {
  @StorageLink('enrichViewModel') enrichVM: EnrichViewModel = new EnrichViewModel()
  @State wishes: Wish[] = []
  @State loading: boolean = false
  @State showCreateDialog: boolean = false
  @State newWishContent: string = ''
  @State selectedDeity: number = 0

  aboutToAppear(): void {
    this.loadData()
  }

  async loadData(): Promise<void> {
    this.loading = true
    try {
      this.wishes = await CloudService.getWishes()
    } catch (err) {
      console.error('[WishWall] load failed:', JSON.stringify(err))
    } finally {
      this.loading = false
    }
  }

  build() {
    Stack() {
      Column() {
        // 标题
        Row() {
          Text('✨ 心愿墙')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#f9ca24')
          Blank()
          Text('+ 许愿')
            .fontSize(13)
            .fontColor('#f9ca24')
            .backgroundColor('rgba(249, 202, 36, 0.1)')
            .borderRadius(14)
            .padding({ left: 14, right: 14, top: 6, bottom: 6 })
            .onClick(() => { this.showCreateDialog = true })
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 12, bottom: 8 })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

        if (this.loading) {
          Column() {
            LoadingProgress().width(40).height(40).color('#f9ca24')
            Text('加载中...').fontSize(12).fontColor('rgba(253, 246, 227, 0.5)').margin({ top: 8 })
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.wishes.length === 0) {
          Column() {
            Text('✨').fontSize(40).margin({ bottom: 8 })
            Text('心愿墙空空如也').fontSize(14).fontColor('rgba(253, 246, 227, 0.5)')
            Text('成为第一个许愿的人吧！').fontSize(14).fontColor('rgba(253, 246, 227, 0.5)')
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          Scroll() {
            Column() {
              ForEach(this.wishes, (wish: Wish) => {
                WishItem({ wish: wish, enrichVM: this.enrichVM })
              })
            }
            .width('100%')
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        }
      }
      .width('100%')
      .height('100%')

      // 许愿弹窗
      if (this.showCreateDialog) {
        Column() {
          Column() {
            Text('🙏 许下心愿')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#f9ca24')
              .margin({ bottom: 16 })

            TextInput({ text: this.newWishContent, placeholder: '写下你的心愿（最多30字）' })
              .fontSize(14)
              .fontColor('#fdf6e3')
              .placeholderColor('rgba(253, 246, 227, 0.3)')
              .backgroundColor('rgba(249, 202, 36, 0.08)')
              .borderRadius(8)
              .height(44)
              .padding({ left: 12, right: 12 })
              .maxLength(30)
              .onChange((value: string) => { this.newWishContent = value })
              .margin({ bottom: 12 })

            // 财神选择
            Text('关联财神（可选）')
              .fontSize(12)
              .fontColor('rgba(253, 246, 227, 0.5)')
              .margin({ bottom: 8 })

            Row() {
              ForEach(FIVE_DEITIES, (deity) => {
                Text(deity.name)
                  .fontSize(11)
                  .fontColor(this.selectedDeity === deity.id ? '#1a1a0a' : 'rgba(253, 246, 227, 0.5)')
                  .backgroundColor(this.selectedDeity === deity.id ? '#f9ca24' : 'rgba(249, 202, 36, 0.1)')
                  .borderRadius(12)
                  .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                  .margin({ right: 4 })
                  .onClick(() => { this.selectedDeity = deity.id })
              })
            }
            .width('100%')
            .margin({ bottom: 16 })

            Row() {
              Button('取消')
                .fontSize(13)
                .fontColor('rgba(253, 246, 227, 0.5)')
                .backgroundColor('rgba(253, 246, 227, 0.1)')
                .borderRadius(20)
                .padding({ left: 24, right: 24, top: 8, bottom: 8 })
                .onClick(() => {
                  this.showCreateDialog = false
                  this.newWishContent = ''
                  this.selectedDeity = 0
                })

              Button('许愿')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor('#1a1a0a')
                .backgroundColor('#f9ca24')
                .borderRadius(20)
                .padding({ left: 24, right: 24, top: 8, bottom: 8 })
                .margin({ left: 16 })
                .enabled(this.newWishContent.trim().length > 0)
                .onClick(async () => {
                  if (this.newWishContent.trim().length === 0) return
                  const ok = await CloudService.createWish(this.newWishContent.trim(), this.selectedDeity)
                  if (ok) {
                    this.getUIContext().getPromptAction().showToast({ message: '许愿成功！' })
                    this.showCreateDialog = false
                    this.newWishContent = ''
                    this.selectedDeity = 0
                    this.loadData()
                  } else {
                    this.getUIContext().getPromptAction().showToast({ message: '许愿失败，请重试' })
                  }
                })
            }
          }
          .width('78%')
          .padding(20)
          .backgroundColor('#1a1a0a')
          .borderRadius(16)
          .border({ width: 1.5, color: 'rgba(249, 202, 36, 0.3)' })
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.7)')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .onClick(() => {
          // 点击背景关闭
          this.showCreateDialog = false
          this.newWishContent = ''
          this.selectedDeity = 0
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1a1a0a')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
  }
}
```

- [ ] **Step 3: 提交**

```bash
git add entry/src/main/ets/components/WishItem.ets entry/src/main/ets/pages/WishWall.ets
git commit -m "feat: add WishWall page with create and fulfill wish functionality"
```

---

### Phase 7: 集成收尾

### Task 7.1: 更新 main_pages.json 和版本号

- [ ] **Step 1: 更新 main_pages.json**

所有页面必须在 main_pages.json 中声明，否则 router.pushUrl 会报错：

```json
{
  "src": [
    "pages/MainTabs",
    "pages/HomePage",
    "pages/NameCard",
    "pages/PrayerCard",
    "pages/BlessingCard",
    "pages/WishWall",
    "pages/Leaderboard",
    "pages/MyPage"
  ]
}
```

- [ ] **Step 2: 更新 AppScope/app.json5**

```json5
{
  "app": {
    "bundleName": "luck.happy.huawei",
    "vendor": "mashen",
    "versionCode": 1000001,
    "versionName": "1.1.0",
    "icon": "$media:app_icon",
    "label": "$string:app_name"
  }
}
```

- [ ] **Step 3: 更新 BlessingCard 返回路径**

修改 `entry/src/main/ets/pages/BlessingCard.ets`，将"返回首页"的路由目标从 `pages/HomePage` 改为 `pages/MainTabs`：

找到 `pages/HomePage` 替换为 `pages/MainTabs`。

- [ ] **Step 4: 在 PrayerCard 完成后触发 CloudService**

修改 `entry/src/main/ets/pages/PrayerCard.ets` 或 `viewmodels/PrayerViewModel.ets`，在 `onAnimationComplete` 中异步调用 CloudService：

在 `PrayerViewModel.onAnimationComplete` 的 `saveRecord()` 之后添加：

```typescript
// 异步更新排行榜，不阻塞 UI
import { CloudService } from '../service/CloudService'
// ... 在 saveRecord() 之后
CloudService.updatePrayerCount(this.kowtowCount, 0).catch(() => {})
```

- [ ] **Step 5: 设置 deviceUserId**

在 `EntryAbility.onCreate` 中，使用 preferences 生成或读取设备唯一 ID：

```typescript
// 在 EntryAbility.onCreate 中，EnrichViewModel 初始化之前添加
import { preferences } from '@kit.ArkData'
import { util } from '@kit.ArkTS'

// 生成或读取设备用户 ID
preferences.getPreferences(this.context, 'mashen_user_prefs').then((prefs) => {
  prefs.get('deviceUserId', '').then((val: string | preferences.ValueType) => {
    let uid = val as string
    if (!uid) {
      uid = 'u_' + util.generateRandomUUID(true)
      prefs.put('deviceUserId', uid)
      prefs.flush()
    }
    AppStorage.setOrCreate('deviceUserId', uid)
  })
})
```

- [ ] **Step 6: 提交**

```bash
git add entry/src/main/resources/base/profile/main_pages.json AppScope/app.json5 entry/src/main/ets/pages/BlessingCard.ets entry/src/main/ets/viewmodels/PrayerViewModel.ets entry/src/main/ets/entryability/EntryAbility.ets
git commit -m "feat: wire up integration - version bump, return path, leaderboard trigger, device ID"
```

---

### Task 7.2: 构建验证

- [ ] **Step 1: 运行 hvigorw 构建**

```bash
cd c:/Users/Andy/mashen-app && cmd.exe /c "build-debug.bat"
```

Expected: BUILD SUCCESSFUL

- [ ] **Step 2: 检查构建产物**

```bash
ls -la entry/build/default/outputs/default/
```

Expected: 有 `.hap` 或 `.app` 文件

- [ ] **Step 3: 手动验证清单**

- [ ] MainTabs 作为入口页正常加载
- [ ] 4 个 Tab 可切换
- [ ] Tab 1 显示黄历 + 五神阵 + 开始祈福
- [ ] 祈福流程（姓名→叩拜→祝福）正常
- [ ] Tab 2 心愿墙显示（含空状态）
- [ ] Tab 3 排行榜显示（含空状态）
- [ ] Tab 4 签到卡片可签到
- [ ] Tab 4 祈福日记显示历史记录
- [ ] Tab 4 牌运记录可查看
- [ ] Tab 4 成就徽章显示进度
- [ ] 返回首页按钮回到 MainTabs

---

### Task 7.3: 云函数部署

- [ ] **Step 1: 打包 update-prayer-count**

```bash
cd cloud/update-prayer-count && cp -r ../shared ./shared && npm install --production && zip -r update-prayer-count.zip handler.js package.json shared/ node_modules/
```

- [ ] **Step 2: 打包 get-leaderboard**

```bash
cd cloud/get-leaderboard && cp -r ../shared ./shared && npm install --production && zip -r get-leaderboard.zip handler.js package.json shared/ node_modules/
```

- [ ] **Step 3: 打包 wish-wall**

```bash
cd cloud/wish-wall && cp -r ../shared ./shared && npm install --production && zip -r wish-wall.zip handler.js package.json shared/ node_modules/
```

- [ ] **Step 4: 在 AGC 控制台创建 Cloud DB 对象类型**

1. 进入 AGC 控制台 > Cloud DB
2. 创建对象类型 `Leaderboard`（字段：userId String PK, nickname String, todayCount Integer, weekCount Integer, totalCount Integer, totalKowtow Integer, streak Integer, updatedAt String）
3. 创建对象类型 `Wish`（字段：id String PK, userId String, nickname String, content String, deityId Integer, fulfilled Bool, createdAt String, fulfilledAt String）
4. 发布 schema

- [ ] **Step 5: 在 AGC 控制台部署云函数**

1. 上传 `update-prayer-count.zip`
2. 上传 `get-leaderboard.zip`
3. 上传 `wish-wall.zip`
4. 配置触发器：HTTP (POST)
5. 配置凭证：上传 `agc-credential.json`（API Client 凭证）

---

## 文件清单汇总

### 新增文件（17 个）

| 文件 | 说明 |
|------|------|
| `model/EnrichTypes.ets` | 新功能类型定义 |
| `viewmodels/EnrichViewModel.ets` | 签到/牌运/成就/黄历状态管理 |
| `pages/MainTabs.ets` | 4 Tab 容器入口 |
| `pages/MyPage.ets` | 我的页面 |
| `pages/Leaderboard.ets` | 排行榜页面 |
| `pages/WishWall.ets` | 心愿墙页面 |
| `components/CheckinCard.ets` | 签到卡片 |
| `components/DailyAlmanac.ets` | 今日黄历 |
| `components/DiaryList.ets` | 祈福日记列表 |
| `components/GameRecordCard.ets` | 牌运记录卡片 |
| `components/AchievementGrid.ets` | 成就徽章网格 |
| `components/LeaderboardItem.ets` | 排行榜列表项 |
| `components/WishItem.ets` | 心愿列表项 |
| `service/CloudService.ets` | 云函数调用封装 |
| `cloud/update-prayer-count/handler.js` | 排行榜更新云函数 |
| `cloud/get-leaderboard/handler.js` | 排行榜查询云函数 |
| `cloud/wish-wall/handler.js` | 心愿墙云函数 |

### 修改文件（5 个）

| 文件 | 改动 |
|------|------|
| `entryability/EntryAbility.ets` | 初始化 EnrichViewModel + deviceUserId + 入口改为 MainTabs |
| `viewmodels/PrayerViewModel.ets` | 触发磕头追踪 + 排行榜更新 |
| `pages/BlessingCard.ets` | 返回主页路径改为 MainTabs |
| `AppScope/app.json5` | 版本号 1.0.0 → 1.1.0 |
| `resources/base/profile/main_pages.json` | 添加 MainTabs 为首页 |

### 可删除文件（1 个）

| 文件 | 原因 |
|------|------|
| `pages/HomePage.ets` | 已合并到 MainTabs 的 Tab 1（保留文件但不再作为入口） |