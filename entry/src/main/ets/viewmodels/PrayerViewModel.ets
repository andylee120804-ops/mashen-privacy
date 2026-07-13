// entry/src/main/ets/viewmodels/PrayerViewModel.ets
import { PrayerRecord, PrayerPhase, UserPrefs, DeityInfo } from '../model/PrayerTypes'
import { DeityRotator } from '../engine/DeityRotator'
import { BlessingEngine } from '../engine/BlessingEngine'
import { preferences } from '@kit.ArkData'
import { util } from '@kit.ArkTS'

const PREF_NAME = 'mashen_user_prefs'
const HISTORY_KEY = 'prayer_history'
const RECENT_NAMES_KEY = 'recentNames'
const TOTAL_PRAYERS_KEY = 'totalPrayers'
const MAX_HISTORY = 100
const MAX_RECENT_NAMES = 5

@Observed
export class PrayerViewModel {
  currentPhase: PrayerPhase = PrayerPhase.IDLE
  userName: string = ''
  todayDeity: DeityInfo
  blessing: string = ''
  kowtowCount: number = 0
  recentNames: string[] = []
  totalPrayers: number = 0
  history: PrayerRecord[] = []
  private blessingEngine: BlessingEngine | null = null
  private dataPrefs: preferences.Preferences | null = null

  constructor() {
    this.todayDeity = DeityRotator.getTodayDeity()
  }

  async initialize(context: Context): Promise<void> {
    this.blessingEngine = new BlessingEngine()
    await this.blessingEngine.loadBlessings(context)
    this.dataPrefs = await preferences.getPreferences(context, PREF_NAME)
    await this.loadPrefs()
  }

  startPrayer(): void {
    this.currentPhase = PrayerPhase.INPUT_NAME
    this.todayDeity = DeityRotator.getTodayDeity()
  }

  confirmName(name: string): void {
    this.userName = name
    this.saveRecentName(name)
    this.currentPhase = PrayerPhase.ANIMATING
  }

  onAnimationComplete(): void {
    if (!this.blessingEngine) return
    this.blessing = this.blessingEngine.getBlessing(this.todayDeity.id, this.userName)
    this.kowtowCount = 3
    this.currentPhase = PrayerPhase.BLESSING
    this.saveRecord()
  }

  resetPrayer(): void {
    this.currentPhase = PrayerPhase.IDLE
    this.userName = ''
    this.blessing = ''
    this.kowtowCount = 0
  }

  private async saveRecord(): Promise<void> {
    const record: PrayerRecord = {
      id: util.generateRandomUUID(true),
      name: this.userName,
      deityId: this.todayDeity.id,
      blessing: this.blessing,
      kowtowCount: this.kowtowCount,
      timestamp: Date.now()
    }
    this.history.unshift(record)
    if (this.history.length > MAX_HISTORY) {
      this.history = this.history.slice(0, MAX_HISTORY)
    }
    this.totalPrayers++
    await this.persistData()
  }

  private saveRecentName(name: string): void {
    this.recentNames = this.recentNames.filter(n => n !== name)
    this.recentNames.unshift(name)
    if (this.recentNames.length > MAX_RECENT_NAMES) {
      this.recentNames = this.recentNames.slice(0, MAX_RECENT_NAMES)
    }
  }

  private async loadPrefs(): Promise<void> {
    if (!this.dataPrefs) return
    try {
      this.recentNames = this.parseJsonArray<string>(
        await this.dataPrefs.get(RECENT_NAMES_KEY, '[]') as string
      )
      this.totalPrayers = await this.dataPrefs.get(TOTAL_PRAYERS_KEY, 0) as number
      this.history = this.parseJsonArray<PrayerRecord>(
        await this.dataPrefs.get(HISTORY_KEY, '[]') as string
      )
    } catch (err) {
      console.error('Failed to load preferences:', JSON.stringify(err))
    }
  }

  private async persistData(): Promise<void> {
    if (!this.dataPrefs) return
    try {
      await this.dataPrefs.put(RECENT_NAMES_KEY, JSON.stringify(this.recentNames))
      await this.dataPrefs.put(TOTAL_PRAYERS_KEY, this.totalPrayers)
      await this.dataPrefs.put(HISTORY_KEY, JSON.stringify(this.history))
      await this.dataPrefs.flush()
    } catch (err) {
      console.error('Failed to persist data:', JSON.stringify(err))
    }
  }

  private parseJsonArray<T>(json: string): T[] {
    try {
      const parsed = JSON.parse(json)
      return Array.isArray(parsed) ? (parsed as T[]) : []
    } catch {
      return []
    }
  }
}