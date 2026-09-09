// entry/src/main/ets/components/GameRecordDetailList.ets
// 记录牌局·每笔明细：按日期分组，每笔以「结果标签 + 金额」独立成行，一眼可读。
// 供 GameRecordPage（记录牌局 Tab / 独立页）渲染；数据与「我的」页汇总卡
// 共用同一 enrichViewModel，记录后两边实时一致。
import { GameRecord, GameResult } from '../model/EnrichTypes'
import { EnrichViewModel } from '../viewmodels/EnrichViewModel'
import { FIVE_DEITIES, DeityInfo } from '../model/PrayerTypes'

const WEEK_CN: string[] = ['日', '一', '二', '三', '四', '五', '六']
/** 明细默认只渲染最近 N 天（按天=按张卡），更早记录由底部「展开」按钮再加载，避免天数多时一屏全渲染 */
const RECENT_DAYS = 30

@Component
export struct GameRecordDetailList {
  @Link enrichVM: EnrichViewModel
  @State expandedAll: boolean = false
  /** 长按单笔 → 宿主弹菜单（date=记录日期, idx=第几笔） */
  onRowLongPress: (date: string, idx: number) => void = () => {}
  /** 长按整日卡 → 宿主确认删除当天 */
  onDayCardLongPress: (record: GameRecord) => void = () => {}

  build() {
    Column() {
      // 无记录时整块省略（汇总卡已有空态提示）。
      // 标题放本组件内：@Link 能观察 gameRecords 变更，首次记录后自动出现；
      // 宿主 @StorageLink 观察不到嵌套变更，不能放外面判断。
      if (this.enrichVM.gameRecords.length > 0) {
        Row() {
          Text('📋 每笔明细')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor('#f9ca24')
          Blank()
          Text(`共 ${this.enrichVM.gameRecords.length} 天有记录`)
            .fontSize(10)
            .fontColor('rgba(253, 246, 227, 0.5)')
        }
        .width('90%')
        .margin({ top: 12, bottom: 8 })

        // 长按提示：单笔=修改/删除菜单，日期卡=删除当天
        Text('长按单笔可修改/删除 · 长按日期卡可删除当天')
          .fontSize(10)
          .fontColor('rgba(253, 246, 227, 0.5)')
          .width('90%')
          .margin({ bottom: 8 })

        // 展开全部时渲染全量；默认截取最近 RECENT_DAYS 天。
        // key 混入 gameRecordsRev：当天连记多笔时旧 key 不变、子节点不刷新嵌套行
        // （UI v1 局限），rev 变更使整卡重建，行数与内容即时跟上。
        if (this.expandedAll) {
          ForEach(this.enrichVM.gameRecords, (record: GameRecord) => {
            this.DayCard(record)
          }, (record: GameRecord) => `${record.date}-v${this.enrichVM.gameRecordsRev}`)
        } else {
          ForEach(this.recentRecords(), (record: GameRecord) => {
            this.DayCard(record)
          }, (record: GameRecord) => `${record.date}-v${this.enrichVM.gameRecordsRev}`)
        }

        // 超过 30 天时提供展开/收起（展开状态保留，切 Tab 回来仍是展开的）
        if (this.enrichVM.gameRecords.length > RECENT_DAYS) {
          this.ExpandToggle()
        }
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  private recentRecords(): GameRecord[] {
    const all: GameRecord[] = this.enrichVM.gameRecords
    if (all.length > RECENT_DAYS) {
      return all.slice(0, RECENT_DAYS)
    }
    return all
  }

  @Builder
  ExpandToggle() {
    Row() {
      if (this.expandedAll) {
        Text('▲ 收起至最近 30 天')
          .fontSize(13)
          .fontColor('#f9ca24')
      } else {
        Text(`▼ 展开更早记录（还有 ${this.enrichVM.gameRecords.length - RECENT_DAYS} 天）`)
          .fontSize(13)
          .fontColor('#f9ca24')
      }
    }
    .justifyContent(FlexAlign.Center)
    .width('90%')
    .height(40)
    .backgroundColor('rgba(249, 202, 36, 0.05)')
    .border({ width: 1, color: 'rgba(249, 202, 36, 0.2)', radius: 10 })
    .margin({ bottom: 10 })
    .onClick(() => { this.expandedAll = !this.expandedAll })
  }

  // ── 单日战绩卡 ──
  @Builder
  DayCard(record: GameRecord) {
    Column() {
      // 日期 + 护法 + 当日净盈亏（标注说明，避免裸数字）
      Row() {
        Column() {
          Text(this.dayTitle(record.date))
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#fdf6e3')
          Text(this.deityText(record.deityId))
            .fontSize(11)
            .fontColor('rgba(253, 246, 227, 0.5)')
            .margin({ top: 3 })
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Column() {
          Text('当日净盈亏')
            .fontSize(9)
            .fontColor('rgba(253, 246, 227, 0.6)')
          Text(this.dayNetText(record))
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.dayNetColor(record))
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')

      // 分隔线
      Row()
        .width('100%')
        .height(1)
        .backgroundColor('rgba(249, 202, 36, 0.1)')
        .margin({ top: 10, bottom: 4 })

      // 每笔：结果标签 + 金额独立成行
      ForEach(record.games, (game: GameResult, idx: number) => {
        this.GameRow(game, idx, record.date)
      }, (game: GameResult, idx: number) => `${record.date}-${idx}`)

      // 当日赢输平计数
      Row() {
        Text(`赢 ${this.countOf(record.games, '+')}`)
          .fontSize(10)
          .fontColor('#2ecc71')
        Text(`输 ${this.countOf(record.games, '-')}`)
          .fontSize(10)
          .fontColor('#ff6b5e')
          .margin({ left: 12 })
        Text(`平 ${this.countOf(record.games, '·')}`)
          .fontSize(10)
          .fontColor('rgba(253, 246, 227, 0.6)')
          .margin({ left: 12 })
        Blank()
        Text(`共 ${record.games.length} 笔`)
          .fontSize(10)
          .fontColor('rgba(253, 246, 227, 0.6)')
      }
      .width('100%')
      .margin({ top: 6 })
    }
    .width('90%')
    .padding(14)
    .backgroundColor('rgba(249, 202, 36, 0.05)')
    .border({ width: 1, color: 'rgba(249, 202, 36, 0.14)', radius: 12 })
    .margin({ bottom: 10 })
    .gesture(
      LongPressGesture({ repeat: false })
        .onAction(() => {
          this.onDayCardLongPress(record)
        })
    )
  }

  /** 单笔：左结果标签（赢=绿底深字/输=红底/平=浅灰底）+ 右金额大字；长按回调宿主 */
  @Builder
  GameRow(game: GameResult, idx: number, date: string) {
    Row() {
      Text(this.tagText(game.result))
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.tagTextColor(game.result))
        .backgroundColor(this.tagBgColor(game.result))
        .width(46)
        .height(26)
        .textAlign(TextAlign.Center)
        .borderRadius(13)

      Text(this.amountText(game))
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.amountColor(game.result))
        .margin({ left: 14 })
    }
    .width('100%')
    .padding({ top: 7, bottom: 7 })
    .gesture(
      LongPressGesture({ repeat: false })
        .onAction(() => {
          this.onRowLongPress(date, idx)
        })
    )
  }

  // ── 展示辅助 ──

  private dayTitle(date: string): string {
    const p: number[] = this.partsOf(date)
    const d: Date = new Date(p[0], p[1] - 1, p[2])
    if (date === this.dateStr(new Date())) {
      return `今天 · ${p[1]}月${p[2]}日 · 周${WEEK_CN[d.getDay()]}`
    }
    if (date === this.dateStr(new Date(Date.now() - 86400000))) {
      return `昨天 · ${p[1]}月${p[2]}日 · 周${WEEK_CN[d.getDay()]}`
    }
    return `${p[1]}月${p[2]}日 · 周${WEEK_CN[d.getDay()]}`
  }

  private deityText(deityId: number): string {
    if (!deityId) {
      return ''
    }
    const d: DeityInfo | undefined = FIVE_DEITIES.find((it: DeityInfo): boolean => it.id === deityId)
    if (!d) {
      return ''
    }
    return `${d.name} · ${d.direction}`
  }

  /** 当日净盈亏（赢+幅度 - 输幅度，平不计） */
  private dayNet(record: GameRecord): number {
    let net: number = 0
    for (const g of record.games) {
      if (g.result === '+') {
        net += g.magnitude
      } else if (g.result === '-') {
        net -= g.magnitude
      }
    }
    return net
  }

  private dayNetText(record: GameRecord): string {
    const net: number = this.dayNet(record)
    return (net > 0 ? '+' : '') + this.formatMag(net)
  }

  private dayNetColor(record: GameRecord): string {
    const net: number = this.dayNet(record)
    if (net > 0) return '#2ecc71'
    if (net < 0) return '#e74c3c'
    return 'rgba(253, 246, 227, 0.6)'
  }

  private tagText(result: string): string {
    if (result === '+') return '赢'
    if (result === '-') return '输'
    return '平'
  }

  private tagTextColor(result: string): string {
    // 深字压红/绿底：#fdf6e3 在 #e74c3c 上仅 3.54，需与「赢」标签对称用深字（4.60）
    if (result === '+') return '#1a1a0a'
    if (result === '-') return '#1a1a0a'
    return '#fdf6e3'
  }

  private tagBgColor(result: string): string {
    if (result === '+') return '#2ecc71'
    if (result === '-') return '#e74c3c'
    return 'rgba(253, 246, 227, 0.16)'
  }

  private amountText(game: GameResult): string {
    if (game.result === '+') {
      return `+${this.formatMag(game.magnitude)}`
    }
    if (game.result === '-') {
      return `-${this.formatMag(game.magnitude)}`
    }
    return '— 不计金额'
  }

  private amountColor(result: string): string {
    if (result === '+') return '#2ecc71'
    if (result === '-') return '#e74c3c'
    return 'rgba(253, 246, 227, 0.55)'
  }

  private countOf(games: GameResult[], result: string): number {
    let n: number = 0
    for (const g of games) {
      if (g.result === result) {
        n++
      }
    }
    return n
  }

  /** 格式化金额：整数不带小数，有小数则最多3位 */
  private formatMag(mag: number): string {
    if (mag === Math.floor(mag)) {
      return `${mag}`
    }
    return mag.toFixed(3).replace(/0+$/, '').replace(/\.$/, '')
  }

  /** 'YYYY-MM-DD' → [年, 月, 日]（月日 1-based） */
  private partsOf(date: string): number[] {
    const s: string[] = date.split('-')
    if (s.length !== 3) {
      return [0, 0, 0]
    }
    return [Number(s[0]), Number(s[1]), Number(s[2])]
  }

  private dateStr(d: Date): string {
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
  }
}
