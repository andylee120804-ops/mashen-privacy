// entry/src/main/ets/model/PrayerTypes.ets

/** 祈福记录 */
export interface PrayerRecord {
  id: string          // UUID，由 @ohos.util.generateRandomUUID(true) 生成
  name: string        // 祈福者名字
  deityId: number     // 当日财神ID (1-5)
  blessing: string    // 祝福语
  kowtowCount: number // 磕头次数
  timestamp: number   // 祈福时间戳
}

/** 用户偏好 */
export interface UserPrefs {
  recentNames: string[]   // 最近5个名字
  totalPrayers: number    // 累计祈福次数
  lastPrayerDate: string  // 上次祈福日期 YYYY-MM-DD
  favoriteDeity: number   // 最常拜的财神ID
}

/** 财神信息 */
export interface DeityInfo {
  id: number
  name: string
  direction: string      // 方位
  features: string       // 特征描述
  color: string          // 代表色
  mahjongMeaning: string // 麻将寓意
  lottieFile: string     // Lottie 动画文件名
  soundFile: string      // 专属音效
}

/** 五路财神数据 */
export const FIVE_DEITIES: DeityInfo[] = [
  {
    id: 1, name: '赵公明', direction: '中路',
    features: '黑面·铁鞭·黑虎', color: '#1a1a0a',
    mahjongMeaning: '坐镇牌局，保护手气',
    lottieFile: 'deities/zhaogongming.json',
    soundFile: 'deity_zhonglu.mp3'
  },
  {
    id: 2, name: '萧升', direction: '东路',
    features: '绿袍·宝珠', color: '#2ecc71',
    mahjongMeaning: '招宝入局，好牌连连',
    lottieFile: 'deities/xiaosheng.json',
    soundFile: 'deity_donglu.mp3'
  },
  {
    id: 3, name: '曹宝', direction: '西路',
    features: '棕袍·珍宝', color: '#8B4513',
    mahjongMeaning: '纳珍入库，攒好牌型',
    lottieFile: 'deities/caobao.json',
    soundFile: 'deity_xilu.mp3'
  },
  {
    id: 4, name: '陈九公', direction: '南路',
    features: '红袍·金元宝', color: '#c0392b',
    mahjongMeaning: '招财进宝，胡牌赢钱',
    lottieFile: 'deities/chenjiugong.json',
    soundFile: 'deity_nanlu.mp3'
  },
  {
    id: 5, name: '姚少司', direction: '北路',
    features: '紫袍·如意', color: '#9b59b6',
    mahjongMeaning: '利市亨通，顺风顺水',
    lottieFile: 'deities/yaoshaosi.json',
    soundFile: 'deity_beilu.mp3'
  }
]

/** 祈福流程阶段 */
export enum PrayerPhase {
  IDLE = 'idle',
  INPUT_NAME = 'inputName',
  ANIMATING = 'animating',
  BLESSING = 'blessing'
}

/** 动画阶段 */
export enum AnimStage {
  APPEAR = 'appear',       // 0-1.5s 财神现身
  INCENSE = 'incense',     // 1.5-4s 进香
  KOWTOW = 'kowtow',       // 4-6.5s 磕头
  BLESSING = 'blessing'    // 6.5-8s 祝福降临
}