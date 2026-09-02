// entry/src/main/ets/viewmodels/FortuneViewModel.ets
// 星座/属相偏好、神诞收藏（preferences 持久化）+ 运势查询入口。
import { preferences } from '@kit.ArkData'
import { ShengxiaoFortune, ZodiacFortune, generateShengxiaoFortune, generateZodiacFortune } from '../model/FortuneTypes'

const PREF_NAME = 'mashen_fortune_prefs'
const KEY_ZODIAC = 'zodiacIdx'
const KEY_SHENGXIAO = 'shengxiaoIdx'
const KEY_SHENDAN_FAVORITES = 'shendanFavorites'
/** AppStorage 版本信号：属相/星座/神诞收藏等偏好变更后 +1，
 *  消费页（运势页/我的页速览卡）以 @StorageLink('fortuneRev') + @Watch 重建派生 UI。
 *  UI v1 下 @StorageLink 不自动通知 @Observed 嵌套属性变更，必须显式发信号。 */
const KEY_FORTUNE_REV = 'fortuneRev'

@Observed
export class FortuneViewModel {
  zodiacIdx: number = -1      // 星座索引 0-11，-1 未设置
  shengxiaoIdx: number = -1    // 属相索引 0-11，-1 未设置
  shendanFavorites: string[] = []
  private dataPrefs: preferences.Preferences | null = null

  async initialize(context: Context): Promise<void> {
    this.dataPrefs = await preferences.getPreferences(context, PREF_NAME)
    try {
      this.zodiacIdx = await this.dataPrefs.get(KEY_ZODIAC, -1) as number
      this.shengxiaoIdx = await this.dataPrefs.get(KEY_SHENGXIAO, -1) as number
      const favStr = await this.dataPrefs.get(KEY_SHENDAN_FAVORITES, '[]') as string
      const favs: string[] = JSON.parse(favStr)
      this.shendanFavorites = Array.isArray(favs) ? favs : []
    } catch (err) {
      console.error('[FortuneViewModel] Failed to load prefs:', JSON.stringify(err))
    }
    this.notifyChanged()
  }

  /** 偏好变更信号：写 AppStorage rev，消费页 @Watch 后重建派生 UI（见 KEY_FORTUNE_REV 注释） */
  private notifyChanged(): void {
    try {
      const cur: number = AppStorage.get<number>(KEY_FORTUNE_REV) ?? 0
      AppStorage.setOrCreate(KEY_FORTUNE_REV, cur + 1)
    } catch (err) {
      console.error('[FortuneViewModel] notifyChanged failed:', JSON.stringify(err))
    }
  }

  hasShengxiao(): boolean {
    return this.shengxiaoIdx >= 0
  }

  setShengxiao(idx: number): void {
    this.shengxiaoIdx = idx
    this.persistProfile()
    this.notifyChanged()
  }

  setZodiac(idx: number): void {
    this.zodiacIdx = idx
    this.persistProfile()
    this.notifyChanged()
  }

  toggleShendanFavorite(id: string): void {
    if (this.shendanFavorites.includes(id)) {
      this.shendanFavorites = this.shendanFavorites.filter((f: string): boolean => f !== id)
    } else {
      this.shendanFavorites = [...this.shendanFavorites, id]
    }
    this.persistFavorites()
    this.notifyChanged()
  }

  getShengxiaoFortune(dateStr: string): ShengxiaoFortune | null {
    if (this.shengxiaoIdx < 0) {
      return null
    }
    return generateShengxiaoFortune(dateStr, this.shengxiaoIdx)
  }

  getZodiacFortune(dateStr: string): ZodiacFortune | null {
    if (this.zodiacIdx < 0) {
      return null
    }
    return generateZodiacFortune(dateStr, this.zodiacIdx)
  }

  private async persistProfile(): Promise<void> {
    if (!this.dataPrefs) {
      return
    }
    try {
      await this.dataPrefs.put(KEY_ZODIAC, this.zodiacIdx)
      await this.dataPrefs.put(KEY_SHENGXIAO, this.shengxiaoIdx)
      await this.dataPrefs.flush()
    } catch (err) {
      console.error('[FortuneViewModel] Failed to persist profile:', JSON.stringify(err))
    }
  }

  private async persistFavorites(): Promise<void> {
    if (!this.dataPrefs) {
      return
    }
    try {
      await this.dataPrefs.put(KEY_SHENDAN_FAVORITES, JSON.stringify(this.shendanFavorites))
      await this.dataPrefs.flush()
    } catch (err) {
      console.error('[FortuneViewModel] Failed to persist favorites:', JSON.stringify(err))
    }
  }
}
