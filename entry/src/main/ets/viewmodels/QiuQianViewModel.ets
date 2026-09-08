// entry/src/main/ets/viewmodels/QiuQianViewModel.ets
// 求签记录 + 每日求签额度（最多 3 次/天，跨天自动重置），preferences 本地持久化。
// 记录在「揭晓」时自动写入（保留最近 MAX_QIU_RECORDS 条），额度在「出签」时消费。
import { preferences } from '@kit.ArkData'
import { SignEntry, QiuRecord } from '../model/CultureContent'

const PREF_NAME = 'mashen_qiuqian_prefs'
const KEY_RECORDS = 'qiuRecords'
const KEY_DAILY = 'qiuDaily'
export const MAX_DAILY_QIU = 3      // 每日最多求签次数
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

  private async persistRecords(): Promise<void> {
    if (!this.dataPrefs) {
      return
    }
    try {
      await this.dataPrefs.put(KEY_RECORDS, JSON.stringify(this.records))
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
    } catch (err) {
      console.error('[QiuQianVM] save daily failed:', JSON.stringify(err))
    }
  }
}
