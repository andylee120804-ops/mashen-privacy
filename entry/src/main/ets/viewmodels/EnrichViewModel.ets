// entry/src/main/ets/viewmodels/EnrichViewModel.ets
import {
  CheckinState, GameRecord, GameResult, Achievement, BadgeDef, BADGE_DEFS, AlmanacData, ALMANAC_TABLE, CHECKIN_TILES
} from '../model/EnrichTypes'
import { PrayerViewModel } from './PrayerViewModel'
import { CloudService } from '../service/CloudService'
import { preferences } from '@kit.ArkData'

/** 胜率统计 */
interface WinRate {
  wins: number
  total: number
  rate: number
}

/** 单个财神的胜负统计 */
interface DeityStats {
  wins: number
  total: number
}

const PREF_NAME = 'mashen_enrich_prefs'
const KEY_CHECKIN = 'checkin'
const KEY_GAME_RECORDS = 'gameRecords'
const KEY_ACHIEVEMENTS = 'achievements'
const KEY_DIARY_NOTES = 'diaryNotes'
const KEY_TOTAL_KOWTOW = 'totalKowtow'
const KEY_BOWED_DEITIES = 'bowedDeities'
const KEY_WAS_TOP_DAILY = 'wasTopDaily'
const KEY_WISH_FULFILLED_COUNT = 'wishFulfilledCount'
const KEY_LAST_BACKUP_AT = 'lastGameRecordBackupAt'
const KEY_DELETED_GAME_DATES = 'deletedGameDates'
/** 记一笔/改备注后等待多少毫秒再推送备份（防抖，避免连记多笔时频繁请求） */
const BACKUP_DEBOUNCE_MS = 2000

@Observed
export class EnrichViewModel {
  checkin: CheckinState = { lastDate: '', streak: 0, totalIncense: 0 }
  gameRecords: GameRecord[] = []
  /** 牌局记录变更代次：每次记一笔 +1。UI v1 下外层 ForEach 同 key 子节点不会刷新
   *  嵌套数据（当天连记多笔明细停在旧行数），明细页把本值混入 ForEach key 强制重建，
   *  与 EntryConfigVM rev / CustomizePage renderNonce 同思路。 */
  gameRecordsRev: number = 0
  achievements: Achievement[] = BADGE_DEFS.map((b: BadgeDef): Achievement => {
    return {
      badgeId: b.badgeId,
      name: b.name,
      icon: b.icon,
      desc: b.desc,
      unlocked: false,
      unlockDate: '',
      progress: 0
    }
  })
  diaryNotes: Record<string, string> = {}
  totalKowtow: number = 0
  bowedDeities: Set<number> = new Set()
  wasTopDaily: boolean = false
  wishFulfilledCount: number = 0
  /** 最近一次成功云备份的时间（ISO 字符串，空=从未备份）。UI 经 AppStorage 'lastGameRecordBackupAt' 读取 */
  lastBackupAt: string = ''
  /** 本地已删除的牌局日期墓碑（YYYY-MM-DD[]）：防云端 pull 把这些日期复活 */
  deletedGameDates: string[] = []
  /** 最近一次新解锁的徽章 ID（非空时 AchievementGrid 播放解锁动画后清空） */
  lastUnlockedBadgeId: string = ''
  private dataPrefs: preferences.Preferences | null = null
  private backupTimer: number = -1

  async initialize(context: Context): Promise<void> {
    this.dataPrefs = await preferences.getPreferences(context, PREF_NAME)
    await this.loadPrefs()
    this.refreshAchievements()
  }

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
    return CHECKIN_TILES.slice(0, this.checkin.streak)
  }

  getTodayGameRecord(): GameRecord | undefined {
    const today = this.getTodayStr()
    return this.gameRecords.find(r => r.date === today)
  }

  addGameResult(result: '+' | '-' | '·', magnitude: number, deityId: number, kowtowCount: number): void {
    const today = this.getTodayStr()
    const newGame: GameResult = { result: result, magnitude: magnitude }
    const existingIdx: number = this.gameRecords.findIndex(r => r.date === today)
    if (existingIdx >= 0) {
      const existing: GameRecord = this.gameRecords[existingIdx]
      const updatedGames: GameResult[] = [...existing.games, newGame]
      this.gameRecords = [
        ...this.gameRecords.slice(0, existingIdx),
        { date: today, deityId: existing.deityId, kowtowCount: existing.kowtowCount, games: updatedGames, note: existing.note },
        ...this.gameRecords.slice(existingIdx + 1)
      ]
    } else {
      this.gameRecords = [
        { date: today, deityId: deityId, kowtowCount: kowtowCount, games: [newGame], note: '' },
        ...this.gameRecords
      ]
    }
    this.persistGameRecords()
    this.gameRecordsRev++
    this.refreshAchievements()
    this.queueBackup()
  }

  updateGameNote(date: string, note: string): void {
    const record = this.gameRecords.find(r => r.date === date)
    if (record) {
      record.note = note
      this.persistGameRecords()
      this.queueBackup()
    }
  }

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

  /** 记一笔/改备注后触发云备份：防抖 2s 合并多次写入为一次全量推送（幂等 upsert，重复推送无害） */
  queueBackup(): void {
    if (this.backupTimer !== -1) {
      clearTimeout(this.backupTimer)
    }
    this.backupTimer = setTimeout(() => {
      this.backupTimer = -1
      this.flushBackup()
    }, BACKUP_DEBOUNCE_MS)
  }

  /** 全量推送本地牌局记录到云端；成功后记录最近备份时间（写入 AppStorage 供 UI 刷新） */
  async flushBackup(): Promise<void> {
    const uid: string = AppStorage.get<string>('deviceUserId') || ''
    if (!uid || this.gameRecords.length === 0) {
      return
    }
    try {
      const ok: boolean = await CloudService.pushGameRecordBackup(this.gameRecords)
      if (ok) {
        this.lastBackupAt = new Date().toISOString()
        await this.persistBackupTime()
      }
    } catch (err) {
      console.error('[EnrichViewModel] flushBackup failed:', JSON.stringify(err))
    }
  }

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

  /** 把最近备份时间写入偏好并同步到 AppStorage（@StorageLink 据此刷新状态行） */
  private async persistBackupTime(): Promise<void> {
    if (!this.dataPrefs) return
    await this.dataPrefs.put(KEY_LAST_BACKUP_AT, this.lastBackupAt)
    await this.dataPrefs.flush()
    AppStorage.setOrCreate<string>('lastGameRecordBackupAt', this.lastBackupAt)
  }

  getWinRate(): WinRate {
    return this.getWinRateInRange('')
  }

  getWinRateInRange(sinceDate: string): WinRate {
    let wins = 0
    let total = 0
    for (const r of this.gameRecords) {
      if (sinceDate && r.date < sinceDate) continue
      for (const g of r.games) {
        total++
        if (g.result === '+') wins++
      }
    }
    const stats: WinRate = {
      wins: wins,
      total: total,
      rate: total > 0 ? Math.round(wins / total * 100) : 0
    }
    return stats
  }

  /** 计算指定范围内的净盈亏（赢+幅度 - 输幅度） */
  getNetResultInRange(sinceDate: string): number {
    let net = 0
    for (const r of this.gameRecords) {
      if (sinceDate && r.date < sinceDate) continue
      for (const g of r.games) {
        if (g.result === '+') {
          net += g.magnitude
        } else if (g.result === '-') {
          net -= g.magnitude
        }
        // '·' 平不计入
      }
    }
    return net
  }

  /** 获取指定范围内的所有 GameResult */
  getGamesInRange(sinceDate: string): GameResult[] {
    const results: GameResult[] = []
    for (const r of this.gameRecords) {
      if (sinceDate && r.date < sinceDate) continue
      for (const g of r.games) {
        results.push(g)
      }
    }
    return results
  }

  getBestDeity(): string {
    const stats: Record<number, DeityStats> = {}
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
    return bestId > 0 ? names[bestId] || '' : '-'
  }

  getDiaryNote(recordId: string): string {
    return this.diaryNotes[recordId] || ''
  }

  setDiaryNote(recordId: string, note: string): void {
    this.diaryNotes[recordId] = note
    this.persistDiaryNotes()
  }

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
        this.lastUnlockedBadgeId = a.badgeId
        // 写入 AppStorage 供全局监听（如 MainTabs 显示 Toast）
        AppStorage.setOrCreate<string>('newlyUnlockedBadgeId', a.badgeId)
        this.achievements[i] = {
          badgeId: a.badgeId,
          name: a.name,
          icon: a.icon,
          desc: a.desc,
          unlocked: true,
          unlockDate: today,
          progress: 1
        }
      } else if (!a.unlocked) {
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
        this.achievements[i] = {
          badgeId: a.badgeId,
          name: a.name,
          icon: a.icon,
          desc: a.desc,
          unlocked: a.unlocked,
          unlockDate: a.unlockDate,
          progress: progress
        }
      }
    }
    this.persistAchievements()
  }

  getAlmanac(): AlmanacData {
    const dayOfYear = this.getDayOfYear()
    const entry = ALMANAC_TABLE[dayOfYear % ALMANAC_TABLE.length]
    const almanac: AlmanacData = {
      direction: entry.direction,
      luckySuit: entry.luckySuit,
      avoid: entry.avoid,
      suitable: entry.suitable,
      incenseCount: 0
    }
    return almanac
  }

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

  private getTotalPrayers(): number {
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
      const savedAchievements: Record<string, string> = JSON.parse(achievementsStr)
      this.achievements = BADGE_DEFS.map((b: BadgeDef): Achievement => {
        return {
          badgeId: b.badgeId,
          name: b.name,
          icon: b.icon,
          desc: b.desc,
          unlocked: savedAchievements[b.badgeId] ? true : false,
          unlockDate: savedAchievements[b.badgeId] || '',
          progress: savedAchievements[b.badgeId] ? 1 : 0
        }
      })

      const notesStr = await this.dataPrefs.get(KEY_DIARY_NOTES, '{}') as string
      this.diaryNotes = JSON.parse(notesStr)

      this.totalKowtow = await this.dataPrefs.get(KEY_TOTAL_KOWTOW, 0) as number

      const deitiesArr: number[] = JSON.parse(await this.dataPrefs.get(KEY_BOWED_DEITIES, '[]') as string)
      this.bowedDeities = new Set(deitiesArr)

      this.wasTopDaily = await this.dataPrefs.get(KEY_WAS_TOP_DAILY, false) as boolean
      this.wishFulfilledCount = await this.dataPrefs.get(KEY_WISH_FULFILLED_COUNT, 0) as number
      this.lastBackupAt = await this.dataPrefs.get(KEY_LAST_BACKUP_AT, '') as string
      const deletedDatesStr = await this.dataPrefs.get(KEY_DELETED_GAME_DATES, '[]') as string
      this.deletedGameDates = JSON.parse(deletedDatesStr)
      // 把最近备份时间同步到 AppStorage，供 GameRecordPage 状态行经 @StorageLink 读取
      AppStorage.setOrCreate<string>('lastGameRecordBackupAt', this.lastBackupAt)
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
    const bowedList: number[] = []
    this.bowedDeities.forEach((id: number) => {
      bowedList.push(id)
    })
    await this.dataPrefs.put(KEY_BOWED_DEITIES, JSON.stringify(bowedList))
    await this.dataPrefs.flush()
  }

  private async persistWishCount(): Promise<void> {
    if (!this.dataPrefs) return
    await this.dataPrefs.put(KEY_WISH_FULFILLED_COUNT, this.wishFulfilledCount)
    await this.dataPrefs.flush()
  }
}
