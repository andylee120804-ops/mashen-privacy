// entry/src/main/ets/viewmodels/QiuQianViewModel.ets
// 求签记录 + 每日求签额度（最多 3 次/天，跨天自动重置），preferences 本地持久化。
// 记录在「揭晓」时自动写入（保留最近 MAX_QIU_RECORDS 条），额度在「出签」时消费。
import { preferences } from '@kit.ArkData'
import { SignEntry, QiuRecord } from '../model/CultureContent'

const PREF_NAME = 'mashen_qiuqian_prefs'
const KEY_RECORDS = 'qiuRecords'
const KEY_DAILY = 'qiuDaily'
export const MAX_DAILY_QIU = 3      // 每日最多求签次数
// 解签每日解锁日期（YYYY-MM-DD，存 mashen_user_prefs，与 deviceUserId 同文件；
// EntryAbility 恢复路径复用）。值为「最近一次解锁日期」，isUnlocked() 按本地今天比较——
// 跨天自动失效（每日解锁：一次付款只解锁当天最多 3 个签的解签，次日重新付费）。
export const KEY_UNLOCKED = 'jieqianUnlocked'
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
  unlockDate: string = ''   // 最近一次解签解锁日期（YYYY-MM-DD；isUnlocked 按本地今天比较）

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
      const raw = await this.unlockPrefs.get(KEY_UNLOCKED, '')
      // 旧版永久买断标志迁移（布尔 true）：一次性转为「今日已解锁」（预发布无真实购买，
      // 给早期测试者当天权益；次日按每日解锁模型重新付费）。false/空串 → 未解锁。
      let storedDate: string = ''
      if (typeof raw === 'string') {
        storedDate = raw as string
      } else if (raw === true) {
        storedDate = todayStr()
        await this.unlockPrefs.put(KEY_UNLOCKED, storedDate)
        await this.unlockPrefs.flush()
      }
      // 启动恢复（EntryAbility setUnlockedForToday）可能先于本初始化置位内存值：
      // 已置位则不覆盖（避免读旧快照把解锁回退）
      if (this.unlockDate === '') {
        this.unlockDate = storedDate
      } else {
        // 内存已置位（EntryAbility 恢复先行）：回写磁盘，避免内存有值 / 磁盘旧值不一致
        await this.unlockPrefs.put(KEY_UNLOCKED, this.unlockDate)
        await this.unlockPrefs.flush()
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

  /** 今日是否已解锁解签：最近解锁日期 === 本地今天（跨天自动失效，无需额外清理） */
  isUnlocked(): boolean {
    return this.unlockDate === todayStr()
  }

  /** 置「今日已解锁」并落盘（支付成功 / recoverPending 补单恢复时调用）。
   *  内存值立即生效；持久化失败仅记日志（重装后由 EntryAbility 恢复路径重写）。 */
  async setUnlockedForToday(): Promise<void> {
    this.unlockDate = todayStr()
    if (this.unlockPrefs === null) {
      return
    }
    try {
      await this.unlockPrefs.put(KEY_UNLOCKED, this.unlockDate)
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
