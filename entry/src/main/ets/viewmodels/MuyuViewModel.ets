// entry/src/main/ets/viewmodels/MuyuViewModel.ets
// 电子木鱼计数：今日敲击数（跨日清零）+ 累计功德。
import { preferences } from '@kit.ArkData'
import { formatDate } from '../model/FortuneTypes'

const PREF_NAME = 'mashen_muyu_prefs'
const KEY_TODAY_DATE = 'todayDate'
const KEY_TODAY_COUNT = 'todayCount'
const KEY_TOTAL_COUNT = 'totalCount'

@Observed
export class MuyuViewModel {
  todayDate: string = ''
  todayCount: number = 0
  totalCount: number = 0
  private dataPrefs: preferences.Preferences | null = null

  async initialize(context: Context): Promise<void> {
    this.dataPrefs = await preferences.getPreferences(context, PREF_NAME)
    try {
      this.todayDate = await this.dataPrefs.get(KEY_TODAY_DATE, '') as string
      this.todayCount = await this.dataPrefs.get(KEY_TODAY_COUNT, 0) as number
      this.totalCount = await this.dataPrefs.get(KEY_TOTAL_COUNT, 0) as number
      this.rollDayIfNeeded()
    } catch (err) {
      console.error('[MuyuViewModel] Failed to load prefs:', JSON.stringify(err))
    }
  }

  knock(): void {
    this.rollDayIfNeeded()
    this.todayCount = this.todayCount + 1
    this.totalCount = this.totalCount + 1
    this.persist()
  }

  /** 跨日清零今日计数 */
  private rollDayIfNeeded(): void {
    const today = formatDate(new Date())
    if (this.todayDate !== today) {
      this.todayDate = today
      this.todayCount = 0
    }
  }

  private async persist(): Promise<void> {
    if (!this.dataPrefs) {
      return
    }
    try {
      await this.dataPrefs.put(KEY_TODAY_DATE, this.todayDate)
      await this.dataPrefs.put(KEY_TODAY_COUNT, this.todayCount)
      await this.dataPrefs.put(KEY_TOTAL_COUNT, this.totalCount)
      await this.dataPrefs.flush()
    } catch (err) {
      console.error('[MuyuViewModel] Failed to persist:', JSON.stringify(err))
    }
  }
}
