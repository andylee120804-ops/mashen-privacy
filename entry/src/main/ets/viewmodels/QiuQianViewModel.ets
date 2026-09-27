// entry/src/main/ets/viewmodels/QiuQianViewModel.ets
// 求签记录 + 每日求签额度（最多 3 次/天，跨天自动重置），preferences 本地持久化。
// 记录在「揭晓」时自动写入（保留最近 MAX_QIU_RECORDS 条），额度在「出签」时消费。
import { preferences } from '@kit.ArkData'
import { SignEntry, QiuRecord } from '../model/CultureContent'

const PREF_NAME = 'mashen_qiuqian_prefs'
const KEY_RECORDS = 'qiuRecords'
const KEY_DAILY = 'qiuDaily'
export const MAX_DAILY_QIU = 3      // 每日最多求签次数
export const KEY_UNLOCKED = 'jieqianUnlocked'   // 解签买断解锁标志（存 mashen_user_prefs，与 deviceUserId 同文件；EntryAbility 恢复路径复用）
const MAX_QIU_RECORDS = 100         // 本机保留记录上限

/** 每日额度（按本地日期滚动） */
interface QiuDaily {
  date: string
  count: number
}

function todayStr(): string {
  const d = new Date()
  const mm = `${d.getMonth() + 1}`.padStart(2, '0')
  const dd = `${d.getDate()}`.padStart(2, '0')
  return `${d.getFullYear()}-${mm}-${dd}`
}

@Observed
export class QiuQianViewModel {
  records: QiuRecord[] = []
  daily: QiuDaily = { date: '', count: 0 }
  private dataPrefs: preferences.Preferences | null = null
  private unlockPrefs: preferences.Preferences | null = null
  unlocked: boolean = false   // 解签买断解锁状态（内存主权益源）

  async initialize(context: Context): Promise<void> {
    this.dataPrefs = await preferences.getPreferences(context, PREF_NAME)
    try {
      const rawRec = await this.dataPrefs.get(KEY_RECORDS, '[]')
      this.records = JSON.parse(rawRec as string) as QiuRecord[]
      const rawDaily = await this.dataPrefs.get(KEY_DAILY, '')
      if (rawDaily !== '') {
        this.daily = JSON.parse(rawDaily as string) as QiuDaily
      }
    } catch (err) {
      console.error('[QiuQianVM] load failed:', JSON.stringify(err))
      this.records = []
      this.daily = { date: '', count: 0 }
    }
    try {
      this.unlockPrefs = await preferences.getPreferences(context, 'mashen_user_prefs')
      const raw = await this.unlockPrefs.get(KEY_UNLOCKED, false)
      // 启动恢复（EntryAbility setUnlocked）可能先于本初始化置位内存值：
      // 已置位则不覆盖（避免读旧快照把解锁回退）
      if (!this.unlocked) {
        this.unlocked = raw === true
      }
    } catch (err) {
      console.error('[QiuQianVM] load unlocked failed:', JSON.stringify(err))
    }
  }

  /** 今日已用次数（跨天自动归零并落盘） */
  usedToday(): number {
    const t = todayStr()
    if (this.daily.date !== t) {
      this.daily = { date: t, count: 0 }
      this.persistDaily()
    }
    return this.daily.count
  }

  /** 今日还可求几次 */
  remainingToday(): number {
    return Math.max(0, MAX_DAILY_QIU - this.usedToday())
  }

  canDraw(): boolean {
    return this.usedToday() < MAX_DAILY_QIU
  }

  /** 出签时消费一次今日额度（内存先行，落盘异步） */
  async consumeDraw(): Promise<void> {
    if (!this.canDraw()) {
      return
    }
    const t = todayStr()
    if (this.daily.date !== t) {
      this.daily = { date: t, count: 0 }
    }
    this.daily.count += 1
    await this.persistDaily()
  }

  /** 揭晓时自动记一条（最新在前，超上限截断） */
  async addRecord(sign: SignEntry): Promise<void> {
    const rec: QiuRecord = {
      recId: `${Date.now()}_${Math.floor(Math.random() * 100000)}`,
      ts: Date.now(),
      sign: sign
    }
    this.records.unshift(rec)
    if (this.records.length > MAX_QIU_RECORDS) {
      this.records = this.records.slice(0, MAX_QIU_RECORDS)
    }
    await this.persistRecords()
  }

  async deleteRecord(recId: string): Promise<void> {
    this.records = this.records.filter((r: QiuRecord): boolean => r.recId !== recId)
    await this.persistRecords()
  }

  async clearRecords(): Promise<void> {
    this.records = []
    await this.persistRecords()
  }

  isUnlocked(): boolean {
    return this.unlocked
  }

  /** 置解锁状态并落盘（支付成功 / restoreOwned 恢复时调用）。
   *  内存值立即生效；持久化失败仅记日志（重装后由 EntryAbility 恢复路径重写）。 */
  async setUnlocked(v: boolean): Promise<void> {
    this.unlocked = v
    if (this.unlockPrefs === null) {
      return
    }
    try {
      await this.unlockPrefs.put(KEY_UNLOCKED, v)
      await this.unlockPrefs.flush()
    } catch (err) {
      console.error('[QiuQianVM] save unlocked failed:', JSON.stringify(err))
    }
  }

  private async persistRecords(): Promise<void> {
    if (!this.dataPrefs) {
      return
    }
    try {
      await this.dataPrefs.put(KEY_RECORDS, JSON.stringify(this.records))
      // 必须 flush 才落盘：进程被杀死时未 flush 的内存数据会丢失（历史记录消失）
      await this.dataPrefs.flush()
    } catch (err) {
      console.error('[QiuQianVM] save records failed:', JSON.stringify(err))
    }
  }

  private async persistDaily(): Promise<void> {
    if (!this.dataPrefs) {
      return
    }
    try {
      await this.dataPrefs.put(KEY_DAILY, JSON.stringify(this.daily))
      await this.dataPrefs.flush()
    } catch (err) {
      console.error('[QiuQianVM] save daily failed:', JSON.stringify(err))
    }
  }
}
