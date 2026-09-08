// entry/src/main/ets/components/GameRecordCard.ets
// 牌运汇总卡：只展示汇总（周/月/年切换 + 赢输平 + 净盈亏 + 胜率）+「记录牌局」记一笔。
// 每笔明细不在本卡内展示（见 GameRecordDetailList / GameRecordPage）；
// 宿主可在「我的」页传入 showDetailEntry + onOpenDetail 提供「查看每笔明细」入口。
import { EnrichViewModel } from '../viewmodels/EnrichViewModel'
import { DeityRotator } from '../engine/DeityRotator'
import { MahjongTile } from './MahjongTile'

@Component
export struct GameRecordCard {
  @Link enrichVM: EnrichViewModel
  /** 是否显示「查看每笔明细」入口（仅「我的」页汇总卡需要；记录牌局页明细就在下方） */
  showDetailEntry: boolean = false
  onOpenDetail: () => void = () => {}
  @State showRecordDialog: boolean = false
  @State newGameResult: '+' | '-' | '·' = '+'
  @State amountInput: string = ''
  @State summaryRange: string = 'week'

  build() {
    Stack() {
      Column() {
        // 汇总展示（置顶，用户一眼看到整体牌运）
        if (this.enrichVM.gameRecords.length > 0) {
          this.SummarySection()
        } else {
          Row() {
            MahjongTile({ icon: '🀇', tileSize: 24 })
            Text('暂无牌运记录')
              .fontSize(14)
              .fontColor('rgba(253, 246, 227, 0.5)')
              .fontStyle(FontStyle.Italic)
              .margin({ left: 8 })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding({ top: 16, bottom: 8 })
        }

        // 记录牌局按钮（赢/输必填金额，平免金额也记一笔）
        Row() {
          MahjongTile({ icon: '🀇', tileSize: 26 })
          Text('记录牌局')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1a1a0a')
            .margin({ left: 10 })
        }
        .justifyContent(FlexAlign.Center)
        .width('80%')
        .height(44)
        .backgroundColor('#f9ca24')
        .borderRadius(24)
        .shadow({ radius: 8, color: 'rgba(249, 202, 36, 0.3)', offsetY: 2 })
        .margin({ top: 12, bottom: 4 })
        .onClick(() => { this.showRecordDialog = true })

        // 明细入口（有记录时才展示，避免空页）
        if (this.showDetailEntry && this.enrichVM.gameRecords.length > 0) {
          this.DetailEntry()
        }
      }
      .width('90%')
      .padding(16)
      .backgroundColor('rgba(249, 202, 36, 0.05)')
      .border({ width: 1, color: 'rgba(249, 202, 36, 0.2)', radius: 12 })

      // 记录牌局弹窗
      if (this.showRecordDialog) {
        this.RecordDialog()
      }
    }
    .width('100%')
  }

  /** 查看每笔明细 → 记录牌局完整页 */
  @Builder
  DetailEntry() {
    Row() {
      Text('📋 查看每笔明细')
        .fontSize(13)
        .fontColor('rgba(253, 246, 227, 0.8)')
      Blank()
      Text('›')
        .fontSize(16)
        .fontColor('#f9ca24')
    }
    .width('100%')
    .padding({ top: 12 })
    .margin({ top: 6 })
    .border({ width: { top: 0.5 }, color: 'rgba(249, 202, 36, 0.15)' })
    .onClick(() => { this.onOpenDetail() })
  }

  /** 汇总展示 */
  @Builder
  SummarySection() {
    Column() {
      // 范围切换
      Row() {
        Text('周')
          .fontSize(12)
          .fontWeight(this.summaryRange === 'week' ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.summaryRange === 'week' ? '#1a1a0a' : 'rgba(253, 246, 227, 0.65)')
          .backgroundColor(this.summaryRange === 'week' ? '#f9ca24' : 'rgba(249, 202, 36, 0.1)')
          .borderRadius(10)
          .padding({ left: 14, right: 14, top: 4, bottom: 4 })
          .margin({ right: 8 })
          .onClick(() => { this.summaryRange = 'week' })
        Text('月')
          .fontSize(12)
          .fontWeight(this.summaryRange === 'month' ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.summaryRange === 'month' ? '#1a1a0a' : 'rgba(253, 246, 227, 0.65)')
          .backgroundColor(this.summaryRange === 'month' ? '#f9ca24' : 'rgba(249, 202, 36, 0.1)')
          .borderRadius(10)
          .padding({ left: 14, right: 14, top: 4, bottom: 4 })
          .margin({ right: 8 })
          .onClick(() => { this.summaryRange = 'month' })
        Text('年')
          .fontSize(12)
          .fontWeight(this.summaryRange === 'year' ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.summaryRange === 'year' ? '#1a1a0a' : 'rgba(253, 246, 227, 0.65)')
          .backgroundColor(this.summaryRange === 'year' ? '#f9ca24' : 'rgba(249, 202, 36, 0.1)')
          .borderRadius(10)
          .padding({ left: 14, right: 14, top: 4, bottom: 4 })
          .onClick(() => { this.summaryRange = 'year' })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .margin({ bottom: 10 })

      // 核心数据
      Row() {
        // 左：赢/输/平计数（每行小标签与数字底对齐，基线一致）
        Column() {
          Row() {
            Text('赢').fontSize(10).fontColor('#2ecc71')
            Text(`${this.getWinCount()}`).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#2ecc71').margin({ left: 4 })
          }.alignItems(VerticalAlign.Bottom)
          Row() {
            Text('输').fontSize(10).fontColor('#ff6b5e')
            Text(`${this.getLoseCount()}`).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#e74c3c').margin({ left: 4 })
          }.alignItems(VerticalAlign.Bottom).margin({ top: 4 })
          Row() {
            Text('平').fontSize(10).fontColor('rgba(253, 246, 227, 0.6)')
            Text(`${this.getDrawCount()}`).fontSize(14).fontColor('rgba(253, 246, 227, 0.6)').margin({ left: 4 })
          }.alignItems(VerticalAlign.Bottom).margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)

        // 中：净盈亏
        Column() {
          Text('净盈亏')
            .fontSize(9)
            .fontColor('rgba(253, 246, 227, 0.6)')
          Text(`${this.getNetSign()}${this.formatMag(this.getNetResult())}`)
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getNetColor())
            .margin({ top: 2 })
          Text(this.getLuckLabel(this.getNetResult(), this.getWinRate()))
            .fontSize(10)
            .fontColor(this.getLuckColor())
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Center)
        .layoutWeight(1)

        // 右：胜率
        Column() {
          Text(`${this.getWinRate()}%`)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#f9ca24')

          Stack() {
            Row()
              .width('100%')
              .height(4)
              .backgroundColor('rgba(253, 246, 227, 0.1)')
              .borderRadius(2)
            Row()
              .width(`${this.getWinRate()}%`)
              .height(4)
              .backgroundColor('#f9ca24')
              .borderRadius(2)
          }
          .width(60)
          .margin({ top: 4 })

          Text(`${this.getTotalGames()} 局`)
            .fontSize(10)
            .fontColor('rgba(253, 246, 227, 0.6)')
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      // 左/中/右三列高度不同，顶部对齐避免居中错位
      .alignItems(VerticalAlign.Top)
    }
    .padding(12)
    .backgroundColor('rgba(249, 202, 36, 0.08)')
    .borderRadius(8)
  }

  // ── 统计辅助 ──

  private getWinCount(): number {
    return this.enrichVM.getGamesInRange(this.getRangeSinceDate()).filter((g) => g.result === '+').length
  }

  private getLoseCount(): number {
    return this.enrichVM.getGamesInRange(this.getRangeSinceDate()).filter((g) => g.result === '-').length
  }

  private getDrawCount(): number {
    return this.enrichVM.getGamesInRange(this.getRangeSinceDate()).filter((g) => g.result === '·').length
  }

  private getNetResult(): number {
    return this.enrichVM.getNetResultInRange(this.getRangeSinceDate())
  }

  private getNetSign(): string {
    return this.getNetResult() > 0 ? '+' : ''
  }

  private getNetColor(): string {
    const net: number = this.getNetResult()
    if (net > 0) return '#2ecc71'
    if (net < 0) return '#e74c3c'
    return 'rgba(253, 246, 227, 0.5)'
  }

  /** 10sp 小字版状态色：tint 底上 #e74c3c 仅 3.46、cream0.5 仅 4.30，需加亮/加 alpha */
  private getLuckColor(): string {
    const net: number = this.getNetResult()
    if (net > 0) return '#2ecc71'
    if (net < 0) return '#ff6b5e'
    return 'rgba(253, 246, 227, 0.6)'
  }

  private getWinRate(): number {
    return this.enrichVM.getWinRateInRange(this.getRangeSinceDate()).rate
  }

  private getTotalGames(): number {
    return this.enrichVM.getWinRateInRange(this.getRangeSinceDate()).total
  }

  private getLuckLabel(netResult: number, winRate: number): string {
    if (winRate === 0 && netResult === 0) return '—'
    if (netResult > 20) return '🔥 大旺'
    if (netResult > 5) return '✨ 小旺'
    if (netResult > 0) return '📈 微赢'
    if (netResult === 0) return '⚖️ 持平'
    if (netResult > -5) return '📉 微输'
    if (netResult > -20) return '💨 小损'
    return '🌊 大损'
  }

  /** 格式化金额：整数不带小数，有小数则最多3位 */
  private formatMag(mag: number): string {
    if (mag === Math.floor(mag)) {
      return `${mag}`
    }
    return mag.toFixed(3).replace(/0+$/, '').replace(/\.$/, '')
  }

  private getRangeSinceDate(): string {
    const now = new Date()
    let since: Date
    if (this.summaryRange === 'week') {
      since = new Date(now.getTime() - 7 * 86400000)
    } else if (this.summaryRange === 'month') {
      since = new Date(now.getTime() - 30 * 86400000)
    } else {
      since = new Date(now.getTime() - 365 * 86400000)
    }
    return `${since.getFullYear()}-${String(since.getMonth() + 1).padStart(2, '0')}-${String(since.getDate()).padStart(2, '0')}`
  }

  private submitGameRecord(): void {
    // 赢/输：金额必填（需 >0）；平：无需金额，也记一笔（magnitude 0，不计净盈亏）
    let finalMag: number = 0
    if (this.newGameResult !== '·') {
      const mag: number = parseFloat(this.amountInput)
      if (isNaN(mag) || mag <= 0) {
        this.toast('输赢需先输入金额，平局则无需金额')
        return
      }
      finalMag = mag
    }
    const todayDeity: number = DeityRotator.getTodayDeity().id
    this.enrichVM.addGameResult(this.newGameResult, finalMag, todayDeity, 0)
    this.showRecordDialog = false
    this.newGameResult = '+'
    this.amountInput = ''
  }

  private toast(msg: string): void {
    this.getUIContext().getPromptAction().showToast({ message: msg, duration: 2000 })
  }

  @Builder
  RecordDialog() {
    Column() {
      Column() {
        Row() {
          MahjongTile({ icon: '🀇', tileSize: 30 })
          Text('记录牌局')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#f9ca24')
            .margin({ left: 10 })
        }
        .margin({ bottom: 24 })

        // 输赢平切换
        Row() {
          Text('赢 +')
            .fontSize(16)
            .fontWeight(this.newGameResult === '+' ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.newGameResult === '+' ? '#1a1a0a' : 'rgba(253, 246, 227, 0.6)')
            .backgroundColor(this.newGameResult === '+' ? '#2ecc71' : 'rgba(46, 204, 113, 0.1)')
            .borderRadius(14)
            .padding({ left: 20, right: 20, top: 10, bottom: 10 })
            .onClick(() => { this.newGameResult = '+' })
          Text('输 -')
            .fontSize(16)
            .fontWeight(this.newGameResult === '-' ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.newGameResult === '-' ? '#1a1a0a' : 'rgba(253, 246, 227, 0.6)')
            .backgroundColor(this.newGameResult === '-' ? '#e74c3c' : 'rgba(231, 76, 60, 0.1)')
            .borderRadius(14)
            .padding({ left: 20, right: 20, top: 10, bottom: 10 })
            .margin({ left: 16 })
            .onClick(() => { this.newGameResult = '-' })
          Text('平 ·')
            .fontSize(16)
            .fontWeight(this.newGameResult === '·' ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.newGameResult === '·' ? '#1a1a0a' : 'rgba(253, 246, 227, 0.6)')
            .backgroundColor(this.newGameResult === '·' ? '#f9ca24' : 'rgba(249, 202, 36, 0.1)')
            .borderRadius(14)
            .padding({ left: 20, right: 20, top: 10, bottom: 10 })
            .margin({ left: 16 })
            .onClick(() => { this.newGameResult = '·' })
        }
        .margin({ bottom: 24 })

        // 金额输入：赢/输必填；选「平」时不显示金额输入（平局不计金额，但同样记一笔）
        if (this.newGameResult === '·') {
          Text('平局不计金额，同样记录一笔')
            .fontSize(12)
            .fontColor('rgba(253, 246, 227, 0.5)')
            .width('100%')
            .margin({ bottom: 24 })
        } else {
          Text('金额（必填）')
            .fontSize(12)
            .fontColor('rgba(253, 246, 227, 0.5)')
            .width('100%')
            .margin({ bottom: 8 })
          TextInput({ text: this.amountInput, placeholder: '输入金额，如 50、1.5、0.125' })
            .fontSize(18)
            .fontColor('#fdf6e3')
            .placeholderColor('rgba(253, 246, 227, 0.5)')
            .backgroundColor('rgba(249, 202, 36, 0.06)')
            .border({ width: 1, color: 'rgba(249, 202, 36, 0.25)', radius: 10 })
            .width('100%')
            .height(48)
            .type(InputType.NUMBER_DECIMAL)
            .onChange((value: string) => {
              this.amountInput = value
            })
            .margin({ bottom: 24 })
        }

        // 操作按钮
        Row() {
          Button('取消')
            .fontSize(15)
            .fontColor('rgba(253, 246, 227, 0.6)')
            .backgroundColor('rgba(253, 246, 227, 0.1)')
            .borderRadius(20)
            .height(40)
            .layoutWeight(1)
            .onClick(() => { this.showRecordDialog = false })
          Button('✦ 记录')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1a1a0a')
            .backgroundColor('#f9ca24')
            .borderRadius(20)
            .height(40)
            .layoutWeight(1)
            .margin({ left: 12 })
            .onClick(() => { this.submitGameRecord() })
        }
        .width('100%')
      }
      .width('80%')
      .padding(24)
      .backgroundColor('#1a1a0a')
      .borderRadius(16)
      .border({ width: 1.5, color: 'rgba(249, 202, 36, 0.3)' })
      .onClick(() => {}) // 阻止穿透
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(0, 0, 0, 0.7)')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => { this.showRecordDialog = false })
  }
}
