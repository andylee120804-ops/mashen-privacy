// entry/src/main/ets/service/CloudService.ets
// 云函数调用封装：排行榜 / 心愿墙 / 香火人数。
// 依据 @kit.CloudFoundationKit 的 cloudFunction.call —— FunctionParams.data 为请求体，
// 服务端从 event.request 读取；FunctionResult.result 类型为 string | Object，
// 需显式转换为 CloudEnvelope 后读取 code/data（ArkTS 严格模式不允许直接访问联合类型字段）。
import { cloudFunction } from '@kit.CloudFoundationKit'
import { LeaderboardEntry, LeaderboardType, Wish } from '../model/EnrichTypes'

/** 云函数统一返回信封 */
interface CloudEnvelope {
  code: number
  message: string
  data: Object | null
}

/** 今日香火人数统计返回体 */
interface IncenseCountData {
  count: number
}

export class CloudService {
  /** 设备匿名 ID（EntryAbility 启动时生成并写入 AppStorage） */
  private static getUserId(): string {
    try {
      const uid: string | undefined = AppStorage.get<string>('deviceUserId')
      return uid || 'unknown'
    } catch {
      return 'unknown'
    }
  }

  /** 脱敏昵称：首字 + *** */
  private static getNickname(): string {
    try {
      const name: string | undefined = AppStorage.get<string>('lastPrayerName')
      const n: string = name || '麻友'
      return n.substring(0, 1) + '***'
    } catch {
      return '麻***'
    }
  }

  /** 把 FunctionResult.result(string | Object) 安全转为 CloudEnvelope */
  private static parseEnvelope(raw: string | Object): CloudEnvelope | null {
    if (typeof raw !== 'object' || raw === null) {
      return null
    }
    return raw as CloudEnvelope
  }

  /** 祈福完成后上报次数与磕头数 */
  static async updatePrayerCount(kowtowCount: number, streak: number): Promise<boolean> {
    try {
      const result = await cloudFunction.call({
        name: 'update-prayer-count',
        data: {
          __uid: this.getUserId(),
          nickname: this.getNickname(),
          kowtowCount: kowtowCount,
          streak: streak
        }
      })
      const env: CloudEnvelope | null = this.parseEnvelope(result.result)
      return env !== null && env.code === 0
    } catch (err) {
      console.error('[CloudService] updatePrayerCount failed:', JSON.stringify(err))
      return false
    }
  }

  /** 获取排行榜（日榜 / 周榜 / 总榜） */
  static async getLeaderboard(type: LeaderboardType): Promise<LeaderboardEntry[]> {
    try {
      const result = await cloudFunction.call({
        name: 'get-leaderboard',
        data: {
          type: type,
          __uid: this.getUserId()
        }
      })
      const env: CloudEnvelope | null = this.parseEnvelope(result.result)
      if (env !== null && env.code === 0 && env.data !== null) {
        const arr: Object = env.data
        if (Array.isArray(arr)) {
          return arr as LeaderboardEntry[]
        }
      }
      return []
    } catch (err) {
      console.error('[CloudService] getLeaderboard failed:', JSON.stringify(err))
      return []
    }
  }

  /** 今日香火人数（黄历卡片用） */
  static async getTodayIncenseCount(): Promise<number> {
    try {
      const result = await cloudFunction.call({
        name: 'get-leaderboard',
        data: {
          type: 'daily-count',
          __uid: this.getUserId()
        }
      })
      const env: CloudEnvelope | null = this.parseEnvelope(result.result)
      if (env !== null && env.code === 0 && env.data !== null) {
        const d: Object = env.data
        const cnt: IncenseCountData = d as IncenseCountData
        return cnt.count || 0
      }
      return 0
    } catch (err) {
      console.error('[CloudService] getTodayIncenseCount failed:', JSON.stringify(err))
      return 0
    }
  }

  /** 拉取心愿墙列表 */
  static async getWishes(): Promise<Wish[]> {
    try {
      const result = await cloudFunction.call({
        name: 'wish-wall',
        data: {
          action: 'list',
          __uid: this.getUserId()
        }
      })
      const env: CloudEnvelope | null = this.parseEnvelope(result.result)
      if (env !== null && env.code === 0 && env.data !== null) {
        const arr: Object = env.data
        if (Array.isArray(arr)) {
          return arr as Wish[]
        }
      }
      return []
    } catch (err) {
      console.error('[CloudService] getWishes failed:', JSON.stringify(err))
      return []
    }
  }

  /** 发布心愿 */
  static async createWish(content: string, deityId: number): Promise<boolean> {
    try {
      const result = await cloudFunction.call({
        name: 'wish-wall',
        data: {
          action: 'create',
          content: content,
          deityId: deityId,
          nickname: this.getNickname(),
          __uid: this.getUserId()
        }
      })
      const env: CloudEnvelope | null = this.parseEnvelope(result.result)
      return env !== null && env.code === 0
    } catch (err) {
      console.error('[CloudService] createWish failed:', JSON.stringify(err))
      return false
    }
  }

  /** 还愿（标记心愿已灵验） */
  static async fulfillWish(wishId: string): Promise<boolean> {
    try {
      const result = await cloudFunction.call({
        name: 'wish-wall',
        data: {
          action: 'fulfill',
          wishId: wishId,
          __uid: this.getUserId()
        }
      })
      const env: CloudEnvelope | null = this.parseEnvelope(result.result)
      return env !== null && env.code === 0
    } catch (err) {
      console.error('[CloudService] fulfillWish failed:', JSON.stringify(err))
      return false
    }
  }
}
