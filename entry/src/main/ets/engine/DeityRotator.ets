// entry/src/main/ets/engine/DeityRotator.ets
import { DeityInfo, FIVE_DEITIES } from '../model/PrayerTypes'

export class DeityRotator {
  /**
   * 获取当日值班财神
   * 算法: deityId = ((dayOfYear - 1) % 5) + 1
   */
  static getTodayDeity(): DeityInfo {
    const now = new Date()
    const startOfYear = new Date(now.getFullYear(), 0, 1)
    const dayOfYear = Math.floor(
      (now.getTime() - startOfYear.getTime()) / (1000 * 60 * 60 * 24)
    ) + 1
    const deityId = ((dayOfYear - 1) % 5) + 1
    return FIVE_DEITIES.find(d => d.id === deityId)!
  }

  /**
   * 根据日期获取指定日期的财神
   */
  static getDeityByDate(dateStr: string): DeityInfo {
    const d = new Date(dateStr)
    const startOfYear = new Date(d.getFullYear(), 0, 1)
    const dayOfYear = Math.floor(
      (d.getTime() - startOfYear.getTime()) / (1000 * 60 * 60 * 24)
    ) + 1
    const deityId = ((dayOfYear - 1) % 5) + 1
    return FIVE_DEITIES.find(deity => deity.id === deityId)!
  }

  /**
   * 获取所有财神列表
   */
  static getAllDeities(): DeityInfo[] {
    return FIVE_DEITIES
  }
}