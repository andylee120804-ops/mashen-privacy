import { DeityInfo, FIVE_DEITIES } from '../model/PrayerTypes'

export class DeityRotator {
  private static computeDeityId(date: Date): number {
    const startOfYear = new Date(date.getFullYear(), 0, 1)
    const dayOfYear = Math.floor(
      (date.getTime() - startOfYear.getTime()) / (1000 * 60 * 60 * 24)
    ) + 1
    return ((dayOfYear - 1) % 5) + 1
  }

  static getTodayDeity(): DeityInfo {
    const deityId = DeityRotator.computeDeityId(new Date())
    const deity = FIVE_DEITIES.find(d => d.id === deityId)
    if (!deity) {
      return FIVE_DEITIES[0] // fallback to first deity
    }
    return deity
  }

  static getDeityByDate(dateStr: string): DeityInfo {
    const d = new Date(dateStr)
    if (isNaN(d.getTime())) {
      return FIVE_DEITIES[0] // invalid date fallback
    }
    const deityId = DeityRotator.computeDeityId(d)
    const deity = FIVE_DEITIES.find(d => d.id === deityId)
    if (!deity) {
      return FIVE_DEITIES[0]
    }
    return deity
  }

  static getAllDeities(): DeityInfo[] {
    return FIVE_DEITIES
  }
}