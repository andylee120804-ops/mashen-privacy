// entry/src/main/ets/model/EnrichTypes.ets

/** 签到状态 */
export interface CheckinState {
  lastDate: string       // 上次签到日期 YYYY-MM-DD
  streak: number         // 连续签到天数 (1-7)
  totalIncense: number   // 累计香火值
}

/** 单场牌局结果 */
export interface GameResult {
  result: '+' | '·'      // + 赢 · 输/平
  magnitude: number      // 幅度 1-9
}

/** 某天的牌运记录 */
export interface GameRecord {
  date: string           // YYYY-MM-DD
  deityId: number        // 当天拜的财神
  kowtowCount: number    // 当天磕头次数
  games: GameResult[]    // 牌局结果
  note: string           // 备注
}

/** 成就徽章 */
export interface Achievement {
  badgeId: string        // 徽章 ID
  name: string           // 徽章名称
  icon: string           // 图标
  desc: string           // 条件描述
  unlocked: boolean      // 是否已解锁
  unlockDate: string     // 解锁日期
  progress: number       // 当前进度 0-1
}

/** 排行榜条目 */
export interface LeaderboardEntry {
  userId: string
  nickname: string
  count: number
  kowtow: number
  rank: number
}

/** 心愿 */
export interface Wish {
  id: string
  userId: string
  nickname: string
  content: string
  deityId: number
  fulfilled: boolean
  createdAt: string
  fulfilledAt: string
}

/** 排行榜类型 */
export enum LeaderboardType {
  DAILY = 'daily',
  WEEKLY = 'weekly',
  TOTAL = 'total'
}

/** 成就徽章定义 */
export const BADGE_DEFS: Omit<Achievement, 'unlocked' | 'unlockDate' | 'progress'>[] = [
  { badgeId: 'first_prayer', name: '初入牌局', icon: '🀄', desc: '完成首次祈福' },
  { badgeId: 'kowtow_100', name: '百拜成金', icon: '🏅', desc: '累计磕头 100 次' },
  { badgeId: 'streak_7', name: '虔诚信徒', icon: '🔥', desc: '连续签到 7 天' },
  { badgeId: 'all_deities', name: '五路通拜', icon: '🌟', desc: '拜过所有 5 位财神' },
  { badgeId: 'five_wins', name: '大杀四方', icon: '🀇', desc: '单日记录 5 场以上赢局' },
  { badgeId: 'win_rate_70', name: '常胜将军', icon: '👑', desc: '祈福胜率超 70%（≥10 场）' },
  { badgeId: 'wish_3', name: '心诚则灵', icon: '✨', desc: '发布并还愿 3 个心愿' },
  { badgeId: 'top_daily', name: '日榜第一', icon: '🏆', desc: '曾登上日祈福榜榜首' }
]

/** 黄历数据 */
export interface AlmanacData {
  direction: string       // 吉位
  luckySuit: string       // 幸运花色（条/筒/万）
  avoid: string           // 忌
  suitable: string        // 宜
  incenseCount: number    // 今日香火人数
}

/** 黄历 30 天轮换表 */
export const ALMANAC_TABLE: Omit<AlmanacData, 'incenseCount'>[] = [
  { direction: '坐东朝西', luckySuit: '🀇 条子', avoid: '心浮气躁', suitable: '稳扎稳打' },
  { direction: '坐南朝北', luckySuit: '🀈 筒子', avoid: '贪大胡', suitable: '见好就收' },
  { direction: '坐西朝东', luckySuit: '🀉 万子', avoid: '犹豫不决', suitable: '当机立断' },
  { direction: '坐北朝南', luckySuit: '🀇 条子', avoid: '急功近利', suitable: '耐心等待' },
  { direction: '坐东朝西', luckySuit: '🀈 筒子', avoid: '目中无人', suitable: '低调行事' },
  { direction: '坐南朝北', luckySuit: '🀉 万子', avoid: '贪心不足', suitable: '适可而止' },
  { direction: '坐西朝东', luckySuit: '🀇 条子', avoid: '心猿意马', suitable: '专注一局' },
  { direction: '坐北朝南', luckySuit: '🀈 筒子', avoid: '怨天尤人', suitable: '自省吾身' },
  { direction: '坐东朝西', luckySuit: '🀉 万子', avoid: '得意忘形', suitable: '戒骄戒躁' },
  { direction: '坐南朝北', luckySuit: '🀇 条子', avoid: '急于求成', suitable: '步步为营' },
  { direction: '坐西朝东', luckySuit: '🀈 筒子', avoid: '刚愎自用', suitable: '广纳良言' },
  { direction: '坐北朝南', luckySuit: '🀉 万子', avoid: '患得患失', suitable: '放平心态' },
  { direction: '坐东朝西', luckySuit: '🀇 条子', avoid: '贪多嚼不烂', suitable: '集中精力' },
  { direction: '坐南朝北', luckySuit: '🀈 筒子', avoid: '贸然进攻', suitable: '以守为攻' },
  { direction: '坐西朝东', luckySuit: '🀉 万子', avoid: '轻敌冒进', suitable: '重视对手' },
  { direction: '坐北朝南', luckySuit: '🀇 条子', avoid: '情绪上头', suitable: '冷静克制' },
  { direction: '坐东朝西', luckySuit: '🀈 筒子', avoid: '瞻前顾后', suitable: '果断出击' },
  { direction: '坐南朝北', luckySuit: '🀉 万子', avoid: '好高骛远', suitable: '脚踏实地' },
  { direction: '坐西朝东', luckySuit: '🀇 条子', avoid: '自乱阵脚', suitable: '沉着冷静' },
  { direction: '坐北朝南', luckySuit: '🀈 筒子', avoid: '畏首畏尾', suitable: '大胆出手' },
  { direction: '坐东朝西', luckySuit: '🀉 万子', avoid: '心浮气躁', suitable: '平心静气' },
  { direction: '坐南朝北', luckySuit: '🀇 条子', avoid: '贪大求全', suitable: '小胡即安' },
  { direction: '坐西朝东', luckySuit: '🀈 筒子', avoid: '急功近利', suitable: '厚积薄发' },
  { direction: '坐北朝南', luckySuit: '🀉 万子', avoid: '一意孤行', suitable: '听取建议' },
  { direction: '坐东朝西', luckySuit: '🀇 条子', avoid: '半途而废', suitable: '坚持到底' },
  { direction: '坐南朝北', luckySuit: '🀈 筒子', avoid: '患得患失', suitable: '笑对输赢' },
  { direction: '坐西朝东', luckySuit: '🀉 万子', avoid: '心不在焉', suitable: '全神贯注' },
  { direction: '坐北朝南', luckySuit: '🀇 条子', avoid: '怨天尤人', suitable: '顺其自然' },
  { direction: '坐东朝西', luckySuit: '🀈 筒子', avoid: '意气用事', suitable: '理智判断' },
  { direction: '坐南朝北', luckySuit: '🀉 万子', avoid: '骄傲自满', suitable: '虚心进取' }
]

/** 签到麻将牌序列 */
export const CHECKIN_TILES = ['🀇', '🀈', '🀉', '🀊', '🀋', '🀌', '🀍']