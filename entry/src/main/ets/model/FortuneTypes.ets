// entry/src/main/ets/model/FortuneTypes.ets
// v1.3.0 运势/黄历/场景/神诞 数据定义与确定性生成算法。
// 全部纯本地：文案池 + 确定性 PRNG（同一天同一属相/星座，结果恒定可复现）。
import { ALMANAC_TABLE, AlmanacEntry } from './EnrichTypes'

// ── 牌运五档（颜色需在 #1a1a0a 底上满足对比度：标题/徽章 ≥3:1，正文 ≥4.5:1）──
export interface PaiyunLevel {
  level: string
  text: string
  color: string
}

export const PAIYUN_LEVELS: PaiyunLevel[] = [
  { level: '旺', text: '宜打牌，牌运亨通', color: '#f9ca24' },
  { level: '吉', text: '可小试，见好就收', color: '#2ecc71' },
  { level: '平', text: '手气一般，宜观望', color: '#fdf6e3' },
  { level: '弱', text: '不宜下注，易破财', color: '#e67e22' },
  { level: '忌', text: '忌打牌，今日避赌', color: '#e74c3c' }
]

/** 牌运抽签权重：旺20% 吉25% 平25% 弱20% 忌10%，保证有好有坏有起伏 */
const PAIYUN_WEIGHTS: number[] = [20, 25, 25, 20, 10]

// ── 属相 / 星座 ──
export const SHENGXIAO: string[] = ['🐭鼠', '🐮牛', '🐯虎', '🐰兔', '🐲龙', '🐍蛇', '🐴马', '🐑羊', '🐵猴', '🐔鸡', '🐶狗', '🐷猪']
export const ZODIAC_SIGNS: string[] = ['♈白羊座', '♉金牛座', '♊双子座', '♋巨蟹座', '♌狮子座', '♍处女座', '♎天秤座', '♏天蝎座', '♐射手座', '♑摩羯座', '♒水瓶座', '♓双鱼座']

// ── 幸运色池 ──
export interface LuckyColor {
  name: string
  hex: string
}

export const LUCKY_COLORS: LuckyColor[] = [
  { name: '富贵金', hex: '#f9ca24' },
  { name: '朱砂红', hex: '#e74c3c' },
  { name: '翡翠绿', hex: '#2ecc71' },
  { name: '琥珀橙', hex: '#e67e22' },
  { name: '青金蓝', hex: '#3a8fd4' },
  { name: '象牙白', hex: '#fdf6e3' },
  { name: '紫气东来', hex: '#9b59b6' },
  { name: '黛青色', hex: '#1abc9c' }
]

// ── 文案池（含麻将祈福特色）──
const YI_POOL: string[] = [
  '宜打牌', '宜纳财', '宜签约', '宜会友', '宜表白', '宜出行',
  '宜投资', '宜考试', '宜搬家', '宜开业', '宜祈福', '宜还愿',
  '宜求签', '宜置衣', '宜动土', '宜扫舍', '宜栽种', '宜问名',
  '宜订盟', '宜祭祀', '宜求医', '宜入学', '宜乘船', '宜纳畜'
]

const JI_POOL: string[] = [
  '忌赌局', '忌借贷', '忌争执', '忌远行', '忌冲动消费', '忌熬夜',
  '忌贪大胡', '忌心浮气躁', '忌动怒', '忌签大单', '忌担保', '忌搬家',
  '忌破土', '忌掘井', '忌伐木', '忌乘船', '忌晒网', '忌理发',
  '忌针灸', '忌订盟', '忌求医', '忌开业', '忌分居', '忌安葬'
]

/** 属相总评池 */
const SUMMARY_POOL: string[] = [
  '今日气场稳中有升，稳扎稳打自有收获', '贵人运旺，牌桌上有高人指点',
  '宜静不宜动，守成即是赢', '鸿运当头，放手一搏正当时',
  '细水长流，小胜也是胜', '心平气和，好运自来',
  '锋芒内敛，后发制人', '运势平顺，以和为贵',
  '得道多助，求财易成', '稍有波折，缓一缓更稳',
  '藏巧于拙，闷声发财', '旺中带喜，好事将近'
]

/** 星座三行短评池 */
const LOVE_POOL: string[] = [
  '桃花朵朵开，单身宜表白', '有伴的感情升温，多陪伴', '感情平平，顺其自然',
  '旧缘未了，或有重逢', '不宜争执，多听少说', '姻缘天定，静待花开',
  '魅力提升，人缘大旺', '守心为上，勿招烂桃花'
]

const CAREER_POOL: string[] = [
  '事业顺遂，贵人提携', '宜签约谈事，一拍即合', '稳扎稳打，步步为营',
  '忌强出头，低调为妙', '考试运佳，下笔有神', '思路敏捷，难题可解',
  '合作共赢，忌单打独斗', '蓄力待发，明日更好'
]

const WEALTH_POOL: string[] = [
  '正财稳定，细水长流', '偏财运旺，小注怡情', '忌大额投资，守财为上',
  '有意外之喜，红包运佳', '宜收账不宜借出', '生意兴隆，财源广进',
  '忌担保借贷，防破财', '聚财有道，宜储蓄'
]

const NUM_POOL: number[] = [1, 2, 3, 4, 5, 6, 7, 8, 9]

// ── 结果类型 ──
export interface ShengxiaoFortune {
  stars: number            // 1-5 综合星级
  summary: string          // 一句总评
  paiyun: number           // 牌运档索引 0-4（对应 PAIYUN_LEVELS）
  yi: string[]             // 宜 3 条
  ji: string[]             // 忌 3 条
  luckyNumbers: number[]   // 幸运数字 2 个
  luckyColor: LuckyColor
}

export interface ZodiacFortune {
  stars: number
  love: string
  career: string
  wealth: string
  luckyNumbers: number[]
  luckyColor: LuckyColor
}

/** 未选择属相/星座时的空结果（页面守卫用，避免空指针） */
export const EMPTY_SHENGXIAO_FORTUNE: ShengxiaoFortune = {
  stars: 0, summary: '', paiyun: 2, yi: [], ji: [], luckyNumbers: [],
  luckyColor: { name: '', hex: '#f9ca24' }
}

export const EMPTY_ZODIAC_FORTUNE: ZodiacFortune = {
  stars: 0, love: '', career: '', wealth: '', luckyNumbers: [],
  luckyColor: { name: '', hex: '#f9ca24' }
}

// ── 场景矩阵（祈福场景选择）──
export interface SceneDef {
  id: string
  icon: string
  name: string
  guide: string
  blessings: string[]      // 场景专属祝福语池
}

export const SCENE_DEFS: SceneDef[] = [
  {
    id: 'wealth', icon: '💰', name: '求财', guide: '愿财源广进，牌运亨通',
    blessings: ['愿财源广进，牌运亨通', '愿点石成金，横财就手', '愿金玉满堂，日进斗金', '愿手气红火，把把自摸']
  },
  {
    id: 'career', icon: '💼', name: '事业', guide: '愿步步高升，贵人相助',
    blessings: ['愿步步高升，贵人在侧', '愿事业顺遂，大展宏图', '愿机遇不断，扶摇直上', '愿口碑载道，名利双收']
  },
  {
    id: 'exam', icon: '📖', name: '考试', guide: '愿金榜题名，逢考必过',
    blessings: ['愿金榜题名，逢考必过', '愿下笔有神，文思泉涌', '愿记忆超群，临场不慌', '愿才思敏捷，一举夺魁']
  },
  {
    id: 'love', icon: '❤️', name: '姻缘', guide: '愿良缘天成，两情相悦',
    blessings: ['愿良缘天成，两情相悦', '愿桃花朵开，姻缘早至', '愿有情人终成眷属', '愿心心相印，白首不离']
  },
  {
    id: 'health', icon: '🏥', name: '健康', guide: '愿身体康健，平安顺遂',
    blessings: ['愿身强体健，百病不侵', '愿神清气爽，精力充沛', '愿平安顺遂，无灾无难', '愿身心康泰，福寿绵长']
  },
  {
    id: 'travel', icon: '✈️', name: '出行', guide: '愿一路顺风，出入平安',
    blessings: ['愿一路顺风，出入平安', '愿旅途愉快，贵人相助', '愿行千里路，处处逢源', '愿高高兴兴出门，平平安安回家']
  },
  {
    id: 'home', icon: '🏠', name: '家宅', guide: '愿家宅安宁，和和美美',
    blessings: ['愿家宅安宁，和和美美', '愿阖家欢乐，福气盈门', '愿家运昌隆，人丁兴旺', '愿满堂金玉，四季平安']
  }
]

// ── 财神历·神诞（民俗常见农历日期；仅静态展示 + 收藏，不做倒计时/提醒）──
export interface ShendanEntry {
  id: string
  icon: string
  name: string
  lunarDate: string
  desc: string
}

export const SHENDAN_LIST: ShendanEntry[] = [
  { id: 'yingcaishen', icon: '🧧', name: '迎财神', lunarDate: '正月初五', desc: '民间迎财神日，接福纳财正当时' },
  { id: 'tudi', icon: '⛰️', name: '土地公诞辰', lunarDate: '农历二月初二', desc: '福德正神圣诞，家宅安宁地基稳' },
  { id: 'zhaogongming', icon: '🐯', name: '赵公明诞辰', lunarDate: '农历三月十五', desc: '正财神赵公元帅圣诞，掌天下财源' },
  { id: 'biguan', icon: '📜', name: '比干诞辰', lunarDate: '农历四月初四', desc: '文财神比干圣诞，公正无私守财帛' },
  { id: 'guandi', icon: '⚔️', name: '关帝诞辰', lunarDate: '农历六月廿四', desc: '武财神关公圣诞，义气千秋守正财' },
  { id: 'liguizu', icon: '💰', name: '财帛星君诞辰', lunarDate: '农历九月十七', desc: '财帛星君李诡祖圣诞，增福纳祥' }
]

// ── 确定性 PRNG（Park-Miller minimal standard，double 精度内精确无溢出）──

/** 31 位滚动哈希：h*31+c，h < 2^31，h*31 < 2^53，double 运算精确 */
function hashStr(s: string): number {
  let h: number = 0
  for (let i = 0; i < s.length; i++) {
    h = (h * 31 + s.charCodeAt(i)) % 2147483647
  }
  return h
}

/** Park-Miller PRNG：同 seed 序列恒定 */
class Rng {
  private s: number

  constructor(seed: number) {
    this.s = (seed % 2147483646) + 1
  }

  next(): number {
    this.s = (this.s * 16807) % 2147483647
    return this.s / 2147483647
  }
}

/** 从池中无放回抽 n 条 */
function pickN(pool: string[], n: number, rng: Rng): string[] {
  const arr: string[] = [...pool]
  const out: string[] = []
  const count = Math.min(n, arr.length)
  for (let i = 0; i < count; i++) {
    const j = i + Math.floor(rng.next() * (arr.length - i))
    const tmp = arr[i]
    arr[i] = arr[j]
    arr[j] = tmp
    out.push(arr[i])
  }
  return out
}

function pickNNum(pool: number[], n: number, rng: Rng): number[] {
  const arr: number[] = [...pool]
  const out: number[] = []
  const count = Math.min(n, arr.length)
  for (let i = 0; i < count; i++) {
    const j = i + Math.floor(rng.next() * (arr.length - i))
    const tmp = arr[i]
    arr[i] = arr[j]
    arr[j] = tmp
    out.push(arr[i])
  }
  return out
}

/** 加权抽签，返回命中下标 */
function pickWeighted(weights: number[], rng: Rng): number {
  let total = 0
  for (const w of weights) {
    total += w
  }
  let r = rng.next() * total
  for (let i = 0; i < weights.length; i++) {
    r -= weights[i]
    if (r < 0) {
      return i
    }
  }
  return weights.length - 1
}

// ── 生成器（同日期同索引结果恒定）──

export function generateShengxiaoFortune(dateStr: string, shengxiaoIdx: number): ShengxiaoFortune {
  const rng = new Rng(hashStr(dateStr + '|shengxiao|' + shengxiaoIdx))
  const stars = 1 + Math.floor(rng.next() * 5)
  const summary = SUMMARY_POOL[Math.floor(rng.next() * SUMMARY_POOL.length)]
  const paiyun = pickWeighted(PAIYUN_WEIGHTS, rng)
  const yi = pickN(YI_POOL, 3, rng)
  const ji = pickN(JI_POOL, 3, rng)
  // 牌运与宜忌呼应：旺/吉必有「宜打牌」，弱/忌必有「忌赌局」（用户核心诉求：明显标注适不适合打牌）
  if (paiyun <= 1 && !yi.includes('宜打牌')) {
    yi[0] = '宜打牌'
  }
  if (paiyun >= 3 && !ji.includes('忌赌局')) {
    ji[0] = '忌赌局'
  }
  const luckyNumbers = pickNNum(NUM_POOL, 2, rng)
  const luckyColor = LUCKY_COLORS[Math.floor(rng.next() * LUCKY_COLORS.length)]
  const result: ShengxiaoFortune = {
    stars: stars,
    summary: summary,
    paiyun: paiyun,
    yi: yi,
    ji: ji,
    luckyNumbers: luckyNumbers,
    luckyColor: luckyColor
  }
  return result
}

export function generateZodiacFortune(dateStr: string, zodiacIdx: number): ZodiacFortune {
  const rng = new Rng(hashStr(dateStr + '|zodiac|' + zodiacIdx))
  const stars = 1 + Math.floor(rng.next() * 5)
  const love = LOVE_POOL[Math.floor(rng.next() * LOVE_POOL.length)]
  const career = CAREER_POOL[Math.floor(rng.next() * CAREER_POOL.length)]
  const wealth = WEALTH_POOL[Math.floor(rng.next() * WEALTH_POOL.length)]
  const luckyNumbers = pickNNum(NUM_POOL, 2, rng)
  const luckyColor = LUCKY_COLORS[Math.floor(rng.next() * LUCKY_COLORS.length)]
  const result: ZodiacFortune = {
    stars: stars,
    love: love,
    career: career,
    wealth: wealth,
    luckyNumbers: luckyNumbers,
    luckyColor: luckyColor
  }
  return result
}

// ── 黄历（任意日期查询；与祈福页黄历卡同源同公式，同日结果一致）──

export function getAlmanacForDate(dateStr: string): AlmanacEntry {
  const d = new Date(dateStr + 'T00:00:00')
  const start = new Date(d.getFullYear(), 0, 0)
  const dayOfYear = Math.floor((d.getTime() - start.getTime()) / 86400000)
  return ALMANAC_TABLE[dayOfYear % ALMANAC_TABLE.length]
}

// ── 日期工具 ──

export function formatDate(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

export function dateOffsetStr(dateStr: string, days: number): string {
  const d = new Date(dateStr + 'T00:00:00')
  d.setDate(d.getDate() + days)
  return formatDate(d)
}

/** 返回 '日' '一' '二' ... '六' */
export function weekdayOf(dateStr: string): string {
  const d = new Date(dateStr + 'T00:00:00')
  const names: string[] = ['日', '一', '二', '三', '四', '五', '六']
  return names[d.getDay()]
}

/** 星级文本：stars=3 → '★★★☆☆' */
export function starText(stars: number): string {
  let s = ''
  for (let i = 0; i < stars; i++) {
    s += '★'
  }
  for (let i = stars; i < 5; i++) {
    s += '☆'
  }
  return s
}
