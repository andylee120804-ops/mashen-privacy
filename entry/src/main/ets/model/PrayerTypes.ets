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
  APPEAR = 'appear',       // 0-1.6s 五神现身（自动）
  INCENSE = 'incense',     // 1.6-4s 进香（自动）
  KOWTOW = 'kowtow',       // 交互阶段：用户按按钮磕头，不自动推进
  BLESSING = 'blessing'    // 完成祈福后五神齐放金光（自动 1.5s）
}

/** 默认磕头次数（达成后解锁"完成祈福"） */
export const DEFAULT_KOWTOW_COUNT = 3

/** 磕头时飘出的祝福语池，围绕麻将胡牌赢钱，主打狠狠说喜话！循环取用 */
export const BLESSING_PHRASES: string[] = [
  // ── 胡牌类 ──
  '胡牌！',
  '自摸！',
  '杠上开花！',
  '海底捞月！',
  '妙手回春！',
  '绝处逢胡！',
  '天胡！',
  '地胡！',
  '人胡！',
  // ── 牌型类 ──
  '清一色！',
  '碰碰胡！',
  '七对子！',
  '龙七对！',
  '字一色！',
  '大四喜！',
  '小四喜！',
  '大三元！',
  '小三元！',
  '十三幺！',
  '九莲宝灯！',
  '一色双龙！',
  '三色双龙！',
  // ── 手气/财运类 ──
  '手气长红！',
  '财神附体！',
  '旺到飞起！',
  '赢钱！',
  '大杀四方！',
  '手风顺到爆！',
  '财源滚滚！',
  '金玉满堂！',
  '日进斗金！',
  '鸿运当头！',
  '招财进宝！',
  '一本万利！',
  '点石成金！',
  '八方来财！',
  '财星高照！',
  // ── 气势类 ──
  '谁也拦不住！',
  '挡我者输！',
  '所向披靡！',
  '旗开得胜！',
  '势如破竹！',
  '春风得意！',
  '独占鳌头！',
  '一骑绝尘！',
  // ── 麻将场景类 ──
  '想啥来啥！',
  '要啥有啥！',
  '缺啥来啥！',
  '张张是宝！',
  '手手是好牌！',
  '牌神眷顾！',
  '牌运亨通！',
  '见牌就胡！',
  '把把自摸！',
  '连庄不断！',
  '旺庄到底！',
]

/** 还愿模式（磕头还愿）飘出的答谢语池：感恩神明灵验、愿满酬神 */
export const FULFILL_PHRASES: string[] = [
  '谢神恩！',
  '如愿以偿！',
  '有求必应！',
  '心诚则灵！',
  '神恩浩荡！',
  '所愿皆成！',
  '愿望成真！',
  '善愿皆圆！',
  '福泽绵长！',
  '香火谢神！',
  '感恩庇佑！',
  '灵验如神！',
  '时来运转！',
  '财缘绵延！',
  '往后顺遂！',
  '一诺千金！',
  '香火续延！',
  '愿已酬神！',
]