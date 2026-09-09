// entry/src/main/ets/pages/GameRecordPage.ets
// 记录牌局：可配置底部 Tab 的完整内容页，也是「我的」页汇总卡「查看明细」的落点
// （Tab 模式由 MainTabs 渲染；独立模式 standalone=true，返回键并入大标题行）。
// 布局：顶部 = 汇总卡（周/月/年统计 + 记一笔），下方 = 按日分组的每笔明细。
// 数据与「我的」页固定汇总卡共用同一 enrichViewModel（AppStorage 全局单例），两边实时一致。
// 根布局为 Stack：原内容 Column + 长按菜单/编辑弹窗条件渲染（同一页内弹层）。
import { EnrichViewModel } from '../viewmodels/EnrichViewModel'
import { GameRecordCard } from '../components/GameRecordCard'
import { GameRecordDetailList } from '../components/GameRecordDetailList'
import { PageBack } from '../components/PageBack'
import { GameRecord, GameResult } from '../model/EnrichTypes'
import { promptAction } from '@kit.ArkUI'

@Component
export struct GameRecordPage {
  /** 独立模式（EntryShell 从「我的」进入）：返回键并入大标题行；Tab 模式不带 */
  @Prop standalone: boolean = false
  @StorageLink('enrichViewModel') enrichVM: EnrichViewModel = new EnrichViewModel()
  /** 最近一次成功云备份时间（ISO，空=从未备份）。由 EnrichViewModel 写入 AppStorage */
  @StorageLink('lastGameRecordBackupAt') lastBackupAt: string = ''
  /** 长按操作菜单状态：menuDate/menuIdx 定位被长按的单笔 */
  @State menuVisible: boolean = false
  @State menuDate: string = ''
  @State menuIdx: number = -1
  /** 编辑弹窗状态（预填被改单笔原值） */
  @State editVisible: boolean = false
  @State editResult: '+' | '-' | '·' = '+'
  @State editAmount: string = ''

  /** 把 ISO 时间转成本地「MM-DD HH:mm」展示 */
  private formatBackupTime(iso: string): string {
    if (!iso) return ''
    try {
      const d = new Date(iso)
      const pad = (n: number) => String(n).padStart(2, '0')
      return `${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`
    } catch {
      return ''
    }
  }

  // ── 长按菜单 / 编辑 / 删除 ──

  private openRowMenu(date: string, idx: number): void {
    const rec = this.enrichVM.gameRecords.find((r) => r.date === date)
    if (!rec || idx < 0 || idx >= rec.games.length) return
    this.menuDate = date
    this.menuIdx = idx
    this.menuVisible = true
  }

  private closeRowMenu(): void {
    this.menuVisible = false
  }

  /** 当前被长按的单笔（菜单/编辑共用） */
  private currentMenuGame(): GameResult | null {
    const rec = this.enrichVM.gameRecords.find((r) => r.date === this.menuDate)
    if (!rec || this.menuIdx < 0 || this.menuIdx >= rec.games.length) return null
    return rec.games[this.menuIdx]
  }

  /** 该笔描述文案：赢 +50 / 输 -50 / 平 */
  private gameDesc(game: GameResult | null): string {
    if (!game) return ''
    if (game.result === '·') return '平'
    const sign: string = game.result === '+' ? '+' : '-'
    return (game.result === '+' ? '赢' : '输') + ' ' + sign + this.formatMag(game.magnitude)
  }

  /** 长按单笔菜单 → 修改这笔 */
  private openEditDialog(): void {
    const game = this.currentMenuGame()
    if (!game) {
      this.closeRowMenu()
      return
    }
    this.editResult = game.result
    this.editAmount = game.result === '·' ? '' : this.formatMag(game.magnitude)
    this.menuVisible = false
    this.editVisible = true
  }

  /** 长按单笔菜单 → 删除这笔（确认后删；删到 0 笔自动整日删除） */
  private confirmDeleteRow(): void {
    const game = this.currentMenuGame()
    if (!game) {
      this.closeRowMenu()
      return
    }
    const desc: string = this.gameDesc(game)
    this.getUIContext().getPromptAction().showDialog({
      title: '删除这笔记录',
      message: `确定删除这笔「${desc}」吗？此操作不可恢复。`,
      buttons: [
        { text: '取消', color: '#fdf6e3' },
        { text: '删除', color: '#e74c3c' }
      ]
    }).then((result: promptAction.ShowDialogSuccessResponse) => {
      if (result.index === 1) {
        const date: string = this.menuDate
        const idx: number = this.menuIdx
        this.closeRowMenu()
        this.enrichVM.deleteGame(date, idx)
      }
    })
  }

  /** 长按整日卡 → 确认删除当天全部 */
  private confirmDeleteDay(record: GameRecord): void {
    const monthDay: string = this.monthDayText(record.date)
    this.getUIContext().getPromptAction().showDialog({
      title: '删除当天记录',
      message: `确定删除 ${monthDay} 的全部记录（共 ${record.games.length} 笔）吗？将同步删除云端备份，不可恢复。`,
      buttons: [
        { text: '取消', color: '#fdf6e3' },
        { text: '删除', color: '#e74c3c' }
      ]
    }).then((result: promptAction.ShowDialogSuccessResponse) => {
      if (result.index === 1) {
        this.enrichVM.deleteDate(record.date)
      }
    })
  }

  /** 编辑弹窗确认：校验金额后更新（输赢金额必填 >0，平免金额） */
  private submitEdit(): void {
    let finalMag: number = 0
    if (this.editResult !== '·') {
      const mag: number = parseFloat(this.editAmount)
      if (isNaN(mag) || mag <= 0) {
        this.getUIContext().getPromptAction().showToast({ message: '输赢需先输入金额，平局则无需金额', duration: 2000 })
        return
      }
      finalMag = mag
    }
    const date: string = this.menuDate
    const idx: number = this.menuIdx
    const result: '+' | '-' | '·' = this.editResult
    this.editVisible = false
    this.menuDate = ''
    this.menuIdx = -1
    this.enrichVM.updateGame(date, idx, result, finalMag)
  }

  /** 'YYYY-MM-DD' → 'M月D日' */
  private monthDayText(date: string): string {
    const s: string[] = date.split('-')
    if (s.length !== 3) return date
    return `${Number(s[1])}月${Number(s[2])}日`
  }

  /** 格式化金额：整数不带小数，有小数则最多3位（与 GameRecordCard.formatMag 同规则） */
  private formatMag(mag: number): string {
    if (mag === Math.floor(mag)) {
      return `${mag}`
    }
    return mag.toFixed(3).replace(/0+$/, '').replace(/\.$/, '')
  }

  /** 深色底部操作菜单（单笔）：修改这笔 / 删除这笔 */
  @Builder
  RowActionSheet() {
    Column() {
      Column() {
        // 头部：日期 + 该笔描述
        Row() {
          Text(this.monthDayText(this.menuDate))
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#f9ca24')
          Text(this.gameDesc(this.currentMenuGame()))
            .fontSize(13)
            .fontColor('#fdf6e3')
            .margin({ left: 10 })
        }
        .width('100%')
        .margin({ bottom: 12 })

        // 修改这笔
        Row() {
          Text('✎ 修改这笔')
            .fontSize(15)
            .fontColor('#fdf6e3')
        }
        .width('100%')
        .height(48)
        .onClick(() => { this.openEditDialog() })

        // 删除这笔（红字实色 #e74c3c，对比度达标）
        Row() {
          Text('🗑 删除这笔')
            .fontSize(15)
            .fontColor('#e74c3c')
        }
        .width('100%')
        .height(48)
        .onClick(() => { this.confirmDeleteRow() })
      }
      .width('100%')
      .padding(20)
      .backgroundColor('#1a1a0a')
      .border({ width: { top: 1.5 }, color: 'rgba(249, 202, 36, 0.3)', radius: { topLeft: 16, topRight: 16 } })
      .onClick(() => {}) // 阻止穿透
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(0, 0, 0, 0.7)')
    .justifyContent(FlexAlign.End)
    .padding({ bottom: 20 })
    .onClick(() => { this.closeRowMenu() })
  }

  /** 编辑单笔弹窗（预填原输赢/金额，样式同 GameRecordCard.RecordDialog） */
  @Builder
  EditDialog() {
    Column() {
      Column() {
        Row() {
          Text('✎ 修改这笔')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#f9ca24')
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .margin({ bottom: 20 })

        // 输赢平切换
        Row() {
          Text('赢 +')
            .fontSize(16)
            .fontWeight(this.editResult === '+' ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.editResult === '+' ? '#1a1a0a' : 'rgba(253, 246, 227, 0.6)')
            .backgroundColor(this.editResult === '+' ? '#2ecc71' : 'rgba(46, 204, 113, 0.1)')
            .borderRadius(14)
            .padding({ left: 20, right: 20, top: 10, bottom: 10 })
            .onClick(() => { this.editResult = '+' })
          Text('输 -')
            .fontSize(16)
            .fontWeight(this.editResult === '-' ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.editResult === '-' ? '#1a1a0a' : 'rgba(253, 246, 227, 0.6)')
            .backgroundColor(this.editResult === '-' ? '#e74c3c' : 'rgba(231, 76, 60, 0.1)')
            .borderRadius(14)
            .padding({ left: 20, right: 20, top: 10, bottom: 10 })
            .margin({ left: 16 })
            .onClick(() => { this.editResult = '-' })
          Text('平 ·')
            .fontSize(16)
            .fontWeight(this.editResult === '·' ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.editResult === '·' ? '#1a1a0a' : 'rgba(253, 246, 227, 0.6)')
            .backgroundColor(this.editResult === '·' ? '#f9ca24' : 'rgba(249, 202, 36, 0.1)')
            .borderRadius(14)
            .padding({ left: 20, right: 20, top: 10, bottom: 10 })
            .margin({ left: 16 })
            .onClick(() => { this.editResult = '·' })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .margin({ bottom: 20 })

        // 金额输入：赢/输必填；平不显示
        if (this.editResult === '·') {
          Text('平局不计金额，同样记录一笔')
            .fontSize(12)
            .fontColor('rgba(253, 246, 227, 0.5)')
            .width('100%')
            .margin({ bottom: 20 })
        } else {
          Text('金额（必填）')
            .fontSize(12)
            .fontColor('rgba(253, 246, 227, 0.5)')
            .width('100%')
            .margin({ bottom: 8 })
          TextInput({ text: this.editAmount, placeholder: '输入金额，如 50、1.5、0.125' })
            .fontSize(18)
            .fontColor('#fdf6e3')
            .placeholderColor('rgba(253, 246, 227, 0.5)')
            .backgroundColor('rgba(249, 202, 36, 0.06)')
            .border({ width: 1, color: 'rgba(249, 202, 36, 0.25)', radius: 10 })
            .width('100%')
            .height(48)
            .type(InputType.NUMBER_DECIMAL)
            .onChange((value: string) => {
              this.editAmount = value
            })
            .margin({ bottom: 20 })
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
            .onClick(() => { this.editVisible = false })
          Button('✦ 保存')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1a1a0a')
            .backgroundColor('#f9ca24')
            .borderRadius(20)
            .height(40)
            .layoutWeight(1)
            .margin({ left: 12 })
            .onClick(() => { this.submitEdit() })
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
    .onClick(() => { this.editVisible = false })
  }

  build() {
    Stack() {
      Column() {
        // 标题（与其他 Tab 页统一：20sp 金色粗体 + 入口同款 emoji，见黄历/木鱼/求签；
        // 独立模式返回键并入同行且标题居中；Tab 模式不带返回，标题保持左对齐）
        Row() {
          if (this.standalone) {
            PageBack()
          }
          Text('🎲 记录牌局')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#f9ca24')
            .layoutWeight(1)
            .textAlign(this.standalone ? TextAlign.Center : TextAlign.Start)
          if (this.standalone) {
            Text(' ')
              .fontSize(14)
              .width(76)
          }
        }
        .width('100%')
        .padding({ left: this.standalone ? 6 : 20, top: 44, bottom: 6 })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

        // 云端备份状态行（P1 同设备云备份：防本地数据丢失）
        Row() {
          Text(this.lastBackupAt
            ? `☁ 已云备份 ${this.formatBackupTime(this.lastBackupAt)}`
            : '☁ 联网后自动备份牌局记录，防丢失')
            .fontSize(11)
            .fontColor('rgba(253, 246, 227, 0.5)')
        }
        .width('100%')
        .padding({ left: this.standalone ? 6 : 20, right: 20, bottom: 4 })

        Scroll() {
          Column() {
            // 顶部：汇总 + 记一笔（贴近标题，减少上方留白）
            GameRecordCard({ enrichVM: $enrichVM })
              .margin({ top: 2 })

            // 下方：每笔明细（标题与空态由 DetailList 自行管理）
            GameRecordDetailList({
              enrichVM: $enrichVM,
              onRowLongPress: (date: string, idx: number) => { this.openRowMenu(date, idx) },
              onDayCardLongPress: (record: GameRecord) => { this.confirmDeleteDay(record) }
            })

            Blank()
              .width(1)
              .height(20)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
        }
        .layoutWeight(1)
        // alwaysEnabled：无记录/内容不足一屏时拖拽也有回弹（AGC 滑动动效标准）
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#1a1a0a')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])

      // 长按单笔 → 深色底部操作菜单
      if (this.menuVisible) {
        this.RowActionSheet()
      }
      // 修改这笔 → 预填编辑弹窗
      if (this.editVisible) {
        this.EditDialog()
      }
    }
    .width('100%')
    .height('100%')
  }
}
