// test-fortune-rng.cjs
// 与 entry/src/main/ets/model/FortuneTypes.ets 的 PRNG/生成器保持同步的确定性验证。
// 运行：node test-fortune-rng.cjs
// 覆盖：同输入结果恒定、结果形状合法（星级/牌运/宜忌唯一/幸运数字）、牌运-宜忌呼应、牌运档分布。
'use strict'

const PAIYUN_WEIGHTS = [20, 25, 25, 20, 10]
const NUM_POOL = [1, 2, 3, 4, 5, 6, 7, 8, 9]
const YI_SIZE = 24
const JI_SIZE = 24

function hashStr(s) {
  let h = 0
  for (let i = 0; i < s.length; i++) {
    h = (h * 31 + s.charCodeAt(i)) % 2147483647
  }
  return h
}

class Rng {
  constructor(seed) {
    this.s = (seed % 2147483646) + 1
  }
  next() {
    this.s = (this.s * 16807) % 2147483647
    return this.s / 2147483647
  }
}

function pickWeighted(weights, rng) {
  let total = 0
  for (const w of weights) total += w
  let r = rng.next() * total
  for (let i = 0; i < weights.length; i++) {
    r -= weights[i]
    if (r < 0) return i
  }
  return weights.length - 1
}

function pickN(pool, n, rng) {
  const arr = [...pool]
  const out = []
  const count = Math.min(n, arr.length)
  for (let i = 0; i < count; i++) {
    const j = i + Math.floor(rng.next() * (arr.length - i))
    const tmp = arr[i]; arr[i] = arr[j]; arr[j] = tmp
    out.push(arr[i])
  }
  return out
}

// 与 FortuneTypes.generateShengxiaoFortune 同构（含宜忌呼应逻辑）
function generateShengxiaoFortune(dateStr, shengxiaoIdx) {
  const rng = new Rng(hashStr(dateStr + '|shengxiao|' + shengxiaoIdx))
  const stars = 1 + Math.floor(rng.next() * 5)
  rng.next() // summary（池大小不同不影响后续序列一致性断言，仅跳过一次抽样）
  const paiyun = pickWeighted(PAIYUN_WEIGHTS, rng)
  const yi = pickN([...Array(YI_SIZE).keys()].map(String), 3, rng)
  const ji = pickN([...Array(JI_SIZE).keys()].map(String), 3, rng)
  if (paiyun <= 1 && !yi.includes('0')) yi[0] = '0' // 池[0] 即「宜打牌」
  if (paiyun >= 3 && !ji.includes('0')) ji[0] = '0' // 池[0] 即「忌赌局」
  const luckyNumbers = pickN(NUM_POOL, 2, rng)
  return { stars, paiyun, yi, ji, luckyNumbers }
}

let failed = 0
function assert(cond, msg) {
  if (!cond) {
    console.error('FAIL:', msg)
    failed++
  }
}

// 1. 确定性：同输入两次生成 deep-equal
for (let idx = 0; idx < 12; idx++) {
  const a = JSON.stringify(generateShengxiaoFortune('2026-09-02', idx))
  const b = JSON.stringify(generateShengxiaoFortune('2026-09-02', idx))
  assert(a === b, `determinism failed for idx=${idx}`)
}

// 2. 形状合法 + 牌运-宜忌呼应
for (let idx = 0; idx < 12; idx++) {
  const f = generateShengxiaoFortune('2026-10-15', idx)
  assert(f.stars >= 1 && f.stars <= 5, 'stars out of range')
  assert(f.paiyun >= 0 && f.paiyun <= 4, 'paiyun out of range')
  assert(f.yi.length === 3 && new Set(f.yi).size === 3, 'yi must be 3 unique')
  assert(f.ji.length === 3 && new Set(f.ji).size === 3, 'ji must be 3 unique')
  assert(f.luckyNumbers.length === 2 && new Set(f.luckyNumbers).size === 2, 'luckyNumbers must be 2 unique')
  assert(f.luckyNumbers.every((n) => n >= 1 && n <= 9), 'luckyNumbers out of 1-9')
  if (f.paiyun <= 1) assert(f.yi.includes('0'), '旺/吉必有宜打牌')
  if (f.paiyun >= 3) assert(f.ji.includes('0'), '弱/忌必有忌赌局')
}

// 3. 牌运档分布（366 天 × 12 属相 = 4392 样本，误差 ±5 个百分点）
const counts = [0, 0, 0, 0, 0]
const total = 366 * 12
for (let day = 0; day < 366; day++) {
  const d = new Date(2026, 0, 1 + day)
  const dateStr = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
  for (let idx = 0; idx < 12; idx++) {
    counts[generateShengxiaoFortune(dateStr, idx).paiyun]++
  }
}
const expect = PAIYUN_WEIGHTS.map((w) => (w / 100) * total)
for (let i = 0; i < 5; i++) {
  assert(Math.abs(counts[i] - expect[i]) / total < 0.05, `paiyun[${i}] distribution off: ${counts[i]} vs ${expect[i].toFixed(0)}`)
}

// 4. 换日期结果变化（避免全同）
const f1 = generateShengxiaoFortune('2026-09-02', 3)
const f2 = generateShengxiaoFortune('2026-09-03', 3)
assert(JSON.stringify(f1) !== JSON.stringify(f2), 'different dates should differ')

if (failed > 0) {
  console.error(`\n${failed} assertion(s) FAILED`)
  process.exit(1)
}
console.log('PASS: fortune RNG determinism + distribution (' + total + ' samples)')
