// entry/src/main/ets/service/CloudService.ets
// 云函数调用封装：排行榜 / 心愿墙 / 香火人数。
// 依据 @kit.CloudFoundationKit 的 cloudFunction.call —— FunctionParams.data 为请求体，
// 服务端从 event.request 读取；FunctionResult.result 类型为 string | Object，
// 需显式转换为 CloudEnvelope 后读取 code/data（ArkTS 严格模式不允许直接访问联合类型字段）。
// 注意：ArkTS 不允许在 static 方法中使用 this（arkts-no-standalone-this），
// 故 getUserId/getNickname/parseEnvelope 为模块级函数，static 方法直接调用。
import { cloudFunction } from '@kit.CloudFoundationKit'
import { LeaderboardEntry, LeaderboardType, Wish, GameRecord } from '../model/EnrichTypes'

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

/** 设备匿名 ID（EntryAbility 启动时生成并写入 AppStorage） */
function getUserId(): string {
  try {
    const uid: string | undefined = AppStorage.get<string>('deviceUserId')
    return uid || 'unknown'
  } catch {
    return 'unknown'
  }
}

/** 脱敏昵称：首字 + *** */
function getNickname(): string {
  try {
    const name: string | undefined = AppStorage.get<string>('lastPrayerName')
    const n: string = name || '麻友'
    return n.substring(0, 1) + '***'
  } catch {
    return '麻***'
  }
}

/** 把 FunctionResult.result(string | Object) 安全转为 CloudEnvelope */
function parseEnvelope(raw: string | Object): CloudEnvelope | null {
  if (typeof raw !== 'object' || raw === null) {
    return null
  }
  return raw as CloudEnvelope
}

export class CloudService {
  /** 祈福完成后上报次数与磕头数 */
  static async updatePrayerCount(kowtowCount: number, streak: number): Promise<boolean> {
    try {
      const result = await cloudFunction.call({
        name: 'update-prayer-count',
        data: {
          __uid: getUserId(),
          nickname: getNickname(),
          kowtowCount: kowtowCount,
          streak: streak
        }
      })
      const env: CloudEnvelope | null = parseEnvelope(result.result)
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
          __uid: getUserId()
        }
      })
      const env: CloudEnvelope | null = parseEnvelope(result.result)
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
          __uid: getUserId()
        }
      })
      const env: CloudEnvelope | null = parseEnvelope(result.result)
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
    const result = await cloudFunction.call({
      name: 'wish-wall',
      data: {
        action: 'list',
        __uid: getUserId()
      }
    })
    const env: CloudEnvelope | null = parseEnvelope(result.result)
    if (env === null) {
      throw new Error('wish-wall response format error')
    }
    if (env.code !== 0) {
      throw new Error('wish-wall failed: ' + env.message)
    }
    if (env.data !== null && Array.isArray(env.data)) {
      return env.data as Wish[]
    }
    return []
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
          nickname: getNickname(),
          __uid: getUserId()
        }
      })
      const env: CloudEnvelope | null = parseEnvelope(result.result)
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
          __uid: getUserId()
        }
      })
      const env: CloudEnvelope | null = parseEnvelope(result.result)
      return env !== null && env.code === 0
    } catch (err) {
      console.error('[CloudService] fulfillWish failed:', JSON.stringify(err))
      return false
    }
  }

  /** 删除心愿（仅发布者可删）。返回空字符串=成功，否则返回给用户看的错误信息 */
  static async deleteWish(wishId: string): Promise<string> {
    try {
      const result = await cloudFunction.call({
        name: 'wish-wall',
        data: {
          action: 'delete',
          wishId: wishId,
          __uid: getUserId()
        }
      })
      const env: CloudEnvelope | null = parseEnvelope(result.result)
      if (env === null) {
        return '删除失败：服务响应格式异常'
      }
      if (env.code !== 0) {
        console.error('[CloudService] deleteWish cloud error: code=' + env.code + ' msg=' + env.message)
        // 透出服务端真实原因（403 非本人 / 404 不存在 / 500 云端错误等），而非笼统提示网络
        return '删除失败：' + (env.message || ('云端错误 code ' + env.code))
      }
      return ''
    } catch (err) {
      console.error('[CloudService] deleteWish failed:', JSON.stringify(err))
      return '删除失败，请检查网络后重试'
    }
  }

  /** 拉取本人云端牌局记录备份。成功返回记录数组（可为空），失败返回 null（便于区分空数据与错误） */
  static async fetchGameRecordBackup(): Promise<GameRecord[] | null> {
    try {
      const result = await cloudFunction.call({
        name: 'game-record-backup',
        data: {
          action: 'pull',
          __uid: getUserId()
        }
      })
      const env: CloudEnvelope | null = parseEnvelope(result.result)
      if (env === null || env.code !== 0 || env.data === null) {
        console.error('[CloudService] fetchGameRecordBackup failed: ' + (env ? env.message : 'bad format'))
        return null
      }
      if (!Array.isArray(env.data)) {
        return null
      }
      return env.data as GameRecord[]
    } catch (err) {
      console.error('[CloudService] fetchGameRecordBackup failed:', JSON.stringify(err))
      return null
    }
  }

  /** 全量推送牌局记录到云端备份（幂等 upsert，重复推送无害）。成功返回 true */
  static async pushGameRecordBackup(records: GameRecord[]): Promise<boolean> {
    try {
      const result = await cloudFunction.call({
        name: 'game-record-backup',
        data: {
          action: 'push',
          records: records,
          __uid: getUserId()
        }
      })
      const env: CloudEnvelope | null = parseEnvelope(result.result)
      return env !== null && env.code === 0
    } catch (err) {
      console.error('[CloudService] pushGameRecordBackup failed:', JSON.stringify(err))
      return false
    }
  }

  /** 删除云端牌局记录（按日期，仅本人）。幂等：云端本无该日期也返回成功 */
  static async deleteGameRecordBackup(dates: string[]): Promise<boolean> {
    try {
      const result = await cloudFunction.call({
        name: 'game-record-backup',
        data: {
          action: 'delete',
          dates: dates,
          __uid: getUserId()
        }
      })
      const env: CloudEnvelope | null = parseEnvelope(result.result)
      return env !== null && env.code === 0
    } catch (err) {
      console.error('[CloudService] deleteGameRecordBackup failed:', JSON.stringify(err))
      return false
    }
  }
}
