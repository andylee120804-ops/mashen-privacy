// entry/src/main/ets/model/LunarCalendar.ets
// 公历→农历转换（1900-2100）。经典 lunarInfo 位编码数据表 + 偏移天数算法，
// 已在 Node 侧用春节/端午/中秋/闰二月锚点验证（2023-03-22=闰二月初一等）。

/** 农历结果 */
export interface LunarDay {
  year: number
  month: number      // 1-12
  day: number        // 1-30
  isLeap: boolean    // 是否闰月
}

// 农历年数据（索引 = 年 - 1900，共 201 项）：
// 位 0-3 = 闰月位置（0=无闰月），位 4-15 = 12 个月大小（置位=30 天），位 16-19 = 闰月大小（置位=30 天）
const LUNAR_INFO: number[] = [
  0x04bd8, 0x04ae0, 0x0a570, 0x054d5, 0x0d260, 0x0d950, 0x16554, 0x056a0, 0x09ad0, 0x055d2,
  0x04ae0, 0x0a5b6, 0x0a4d0, 0x0d250, 0x1d255, 0x0b540, 0x0d6a0, 0x0ada2, 0x095b0, 0x14977,
  0x04970, 0x0a4b0, 0x0b4b5, 0x06a50, 0x06d40, 0x1ab54, 0x02b60, 0x09570, 0x052f2, 0x04970,
  0x06566, 0x0d4a0, 0x0ea50, 0x06e95, 0x05ad0, 0x02b60, 0x186e3, 0x092e0, 0x1c8d7, 0x0c950,
  0x0d4a0, 0x1d8a6, 0x0b550, 0x056a0, 0x1a5b4, 0x025d0, 0x092d0, 0x0d2b2, 0x0a950, 0x0b557,
  0x06ca0, 0x0b550, 0x15355, 0x04da0, 0x0a5b0, 0x14573, 0x052b0, 0x0a9a8, 0x0e950, 0x06aa0,
  0x0aea6, 0x0ab50, 0x04b60, 0x0aae4, 0x0a570, 0x05260, 0x0f263, 0x0d950, 0x05b57, 0x056a0,
  0x096d0, 0x04dd5, 0x04ad0, 0x0a4d0, 0x0d4d4, 0x0d250, 0x0d558, 0x0b540, 0x0b6a0, 0x195a6,
  0x095b0, 0x049b0, 0x0a974, 0x0a4b0, 0x0b27a, 0x06a50, 0x06d40, 0x0af46, 0x0ab60, 0x09570,
  0x04af5, 0x04970, 0x064b0, 0x074a3, 0x0ea50, 0x06b58, 0x055c0, 0x0ab60, 0x096d5, 0x092e0,
  0x0c960, 0x0d954, 0x0d4a0, 0x0da50, 0x07552, 0x056a0, 0x0abb7, 0x025d0, 0x092d0, 0x0cab5,
  0x0a950, 0x0b4a0, 0x0baa4, 0x0ad50, 0x055d9, 0x04ba0, 0x0a5b0, 0x15176, 0x052b0, 0x0a930,
  0x07954, 0x06aa0, 0x0ad50, 0x05b52, 0x04b60, 0x0a6e6, 0x0a4e0, 0x0d260, 0x0ea65, 0x0d530,
  0x05aa0, 0x076a3, 0x096d0, 0x04afb, 0x04ad0, 0x0a4d0, 0x1d0b6, 0x0d250, 0x0d520, 0x0dd45,
  0x0b5a0, 0x056d0, 0x055b2, 0x049b0, 0x0a577, 0x0a4b0, 0x0aa50, 0x1b255, 0x06d20, 0x0ada0,
  0x14b63, 0x09370, 0x049f8, 0x04970, 0x064b0, 0x168a6, 0x0ea50, 0x06b20, 0x1a6c4, 0x0aae0,
  0x0a2e0, 0x0d2e3, 0x0c960, 0x0d557, 0x0d4a0, 0x0da50, 0x05d55, 0x056a0, 0x0a6d0, 0x055d4,
  0x052d0, 0x0a9b8, 0x0a950, 0x0b4a0, 0x0b6a6, 0x0ad50, 0x055a0, 0x0aba4, 0x0a5b0, 0x052b0,
  0x0b273, 0x06930, 0x07337, 0x06aa0, 0x0ad50, 0x14b55, 0x04b60, 0x0a570, 0x054e4, 0x0d160,
  0x0e968, 0x0d520, 0x0daa0, 0x16aa6, 0x056d0, 0x04ae0, 0x0a9d4, 0x0a2d0, 0x0d150, 0x0f252,
  0x0d520
]

const MIN_YEAR = 1900
const MAX_YEAR = 2100

/** 农历年是否闰年（有闰月） */
function leapMonthOf(year: number): number {
  return LUNAR_INFO[year - MIN_YEAR] & 0xf
}

/** 闰月天数（0=该年无闰月） */
function leapDaysOf(year: number): number {
  if (leapMonthOf(year) === 0) {
    return 0
  }
  return (LUNAR_INFO[year - MIN_YEAR] & 0x10000) !== 0 ? 30 : 29
}

/** 某年农历天数（12 个月 + 闰月） */
function yearDaysOf(year: number): number {
  let sum = 348
  for (let i = 0x8000; i > 0x8; i = i >> 1) {
    if ((LUNAR_INFO[year - MIN_YEAR] & i) !== 0) {
      sum += 1
    }
  }
  return sum + leapDaysOf(year)
}

/** 农历第 m 月天数（m 不含闰月） */
function monthDaysOf(year: number, month: number): number {
  return (LUNAR_INFO[year - MIN_YEAR] & (0x10000 >> month)) !== 0 ? 30 : 29
}

/** 公历 → 农历（1900-01-31 起，超出范围返回 null） */
export function solarToLunar(y: number, m: number, d: number): LunarDay | null {
  if (y < MIN_YEAR || y > MAX_YEAR) {
    return null
  }
  // 以 1900-01-31（农历 1900 正月初一）为基准的偏移天数
  let offset = Math.floor((Date.UTC(y, m - 1, d) - Date.UTC(MIN_YEAR, 0, 31)) / 86400000)
  if (offset < 0) {
    return null
  }
  let temp = 0
  let year = MIN_YEAR
  for (; year <= MAX_YEAR && offset > 0; year++) {
    temp = yearDaysOf(year)
    offset -= temp
  }
  if (offset < 0) {
    offset += temp
    year--
  }
  const leap = leapMonthOf(year)
  let isLeap = false
  let month = 1
  for (; month < 13 && offset > 0; month++) {
    if (leap > 0 && month === leap + 1 && !isLeap) {
      month--
      isLeap = true
      temp = leapDaysOf(year)
    } else {
      temp = monthDaysOf(year, month)
    }
    if (isLeap && month === leap + 1) {
      isLeap = false
    }
    offset -= temp
  }
  // 正好落在闰月口
  if (offset === 0 && leap > 0 && month === leap + 1) {
    if (isLeap) {
      isLeap = false
    } else {
      isLeap = true
      month--
    }
  }
  if (offset < 0) {
    offset += temp
    month--
  }
  const ld: LunarDay = { year: year, month: month, day: offset + 1, isLeap: isLeap }
  return ld
}

const MONTH_CN: string[] = ['正', '二', '三', '四', '五', '六', '七', '八', '九', '十', '冬', '腊']
const DAY_UNITS: string[] = ['一', '二', '三', '四', '五', '六', '七', '八', '九']

/** 农历日汉字：初X / 十X / 廿X / 三十 */
function dayCn(day: number): string {
  if (day === 10) {
    return '初十'
  }
  if (day === 20) {
    return '二十'
  }
  if (day === 30) {
    return '三十'
  }
  const tens = Math.floor(day / 10)
  const unit = DAY_UNITS[day % 10 - 1]
  if (tens === 0) {
    return '初' + unit
  }
  if (tens === 1) {
    return '十' + unit
  }
  return '廿' + unit
}

/** '2026-09-02' → '农历七月廿一'；范围外/非法返回 ''（调用方隐藏该段） */
export function lunarTextOf(dateStr: string): string {
  const d = new Date(dateStr + 'T00:00:00')
  if (isNaN(d.getTime())) {
    return ''
  }
  const ld = solarToLunar(d.getFullYear(), d.getMonth() + 1, d.getDate())
  if (ld === null) {
    return ''
  }
  return '农历' + (ld.isLeap ? '闰' : '') + MONTH_CN[ld.month - 1] + '月' + dayCn(ld.day)
}
