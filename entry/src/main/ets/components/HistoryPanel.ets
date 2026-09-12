import { PrayerRecord } from '../model/PrayerTypes'
import { ConfirmDialog } from './ConfirmDialog'

/**
 * 祈福记录懒加载数据源：配合 LazyForEach 只构建可视区行，
 * 避免打开面板时一次性渲染全部记录（最多 100 条 × ~5 节点）。
 */
class HistoryDataSource implements IDataSource {
  private records: PrayerRecord[] = []
  private listeners: DataChangeListener[] = []

  totalCount(): number {
    return this.records.length
  }

  getData(index: number): PrayerRecord {
    return this.records[index]
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    this.listeners.push(listener)
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const idx = this.listeners.indexOf(listener)
    if (idx >= 0) {
      this.listeners.splice(idx, 1)
    }
  }

  setRecords(records: PrayerRecord[]): void {
    this.records = records
    this.listeners.forEach((listener) => listener.onDataReloaded())
  }
}

@Component
export struct HistoryPanel {
  @Prop @Watch('onRecordsUpdated') records: PrayerRecord[]
  onClose: () => void = () => {}
  onClear: () => void = () => {}
  onDelete: (id: string) => void = (_id: string) => {}
  /** 删除/清空确认弹窗状态 */
  @State confirmVisible: boolean = false
  @State confirmTitle: string = ''
  @State confirmMsg: string = ''
  /** 'del' = 删除单条；'clear' = 清空全部 */
  @State confirmKind: string = 'del'
  @State confirmRecordId: string = ''
  private dataSource: HistoryDataSource = new HistoryDataSource()

  aboutToAppear(): void {
    this.dataSource.setRecords(this.records)
  }

  onRecordsUpdated(): void {
    this.dataSource.setRecords(this.records)
  }

  build() {
    Stack() {
      Column() {
      // 顶部标题栏：避开状态栏，左侧返回按钮 + 居中标题 + 右侧清空按钮
      Row() {
        Text('← 返回')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#f9ca24')
          .width(72)
          .textAlign(TextAlign.Start)
          .onClick(() => this.onClose())
        Blank()
        Text('祈福记录')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#f9ca24')
        Blank()
        if (this.records.length > 0) {
          Text('清空')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor('#f9ca24')
            .width(72)
            .textAlign(TextAlign.End)
            .onClick(() => this.showClearConfirm())
        } else {
          Text('')
            .width(72)
        }
      }
      .width('100%')
      .padding({ top: 48, left: 16, right: 16, bottom: 12 })

      // 记录列表
      if (this.records.length === 0) {
        Column() {
          Text('🎋')
            .fontSize(40)
            .margin({ bottom: 8 })
          Text('还没有祈福记录')
            .fontSize(14)
            .fontColor('rgba(253, 246, 227, 0.5)')
          Text('去拜拜麻神吧！')
            .fontSize(14)
            .fontColor('rgba(253, 246, 227, 0.5)')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          LazyForEach(this.dataSource, (record: PrayerRecord) => {
            ListItem() {
              this.RecordItem(record)
            }
          }, (record: PrayerRecord) => record.id)
        }
        .cachedCount(5)
        // alwaysEnabled：记录少于一屏时也回弹，满足 AGC「滑动到边界有反馈动效」
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .layoutWeight(1)
      }

      // 底部右滑返回提示
      Text('长按记录可删除 · 右滑返回主页')
        .fontSize(11)
        .fontColor('rgba(249, 202, 36, 0.6)')
        .margin({ bottom: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1a1a0a')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    // priorityGesture + Normal：右滑优先于 List 滚动与父级左滑，但不阻断 List 垂直滚动
    .priorityGesture(
      PanGesture({ direction: PanDirection.Right })
        .onActionEnd(() => this.onClose()),
      GestureMask.Normal
    )

    // 删除/清空确认（项目风格弹窗）
    if (this.confirmVisible) {
      ConfirmDialog({
        title: this.confirmTitle,
        message: this.confirmMsg,
        confirmText: this.confirmKind === 'clear' ? '清空' : '删除',
        danger: true,
        onCancel: () => { this.confirmVisible = false },
        onConfirm: () => { this.confirmExecute() }
      })
    }
    }
  }

  @Builder
  RecordItem(record: PrayerRecord) {
    Row() {
      Column() {
        Text(record.name)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#fdf6e3')
        Text(this.formatTime(record.timestamp))
          .fontSize(11)
          .fontColor('rgba(253, 246, 227, 0.5)')
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)

      Blank()

      Text(record.blessing.substring(0, 20) + '...')
        .fontSize(12)
        .fontColor('rgba(253, 246, 227, 0.6)')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('50%')
    }
    .width('100%')
    .padding(12)
    .border({
      width: { bottom: 0.5 },
      color: 'rgba(249, 202, 36, 0.1)'
    })
    .gesture(
      LongPressGesture({ repeat: false })
        .onAction(() => {
          this.showDeleteConfirm(record)
        })
    )
  }

  /** 删除单条祈福记录 → 项目风格确认弹窗 */
  private showDeleteConfirm(record: PrayerRecord): void {
    this.confirmKind = 'del'
    this.confirmRecordId = record.id
    this.confirmTitle = '删除祈福记录'
    this.confirmMsg = `确定删除「${record.name}」的祈福记录吗？此操作不可恢复。`
    this.confirmVisible = true
  }

  /** 清空全部祈福记录 → 项目风格确认弹窗 */
  private showClearConfirm(): void {
    this.confirmKind = 'clear'
    this.confirmTitle = '清空祈福记录'
    this.confirmMsg = '确定要清空所有祈福记录吗？此操作不可恢复。'
    this.confirmVisible = true
  }

  /** 确认弹窗 → 执行删除/清空 */
  private confirmExecute(): void {
    const kind: string = this.confirmKind
    const id: string = this.confirmRecordId
    this.confirmVisible = false
    this.confirmRecordId = ''
    if (kind === 'clear') {
      this.onClear()
    } else {
      this.onDelete(id)
    }
  }

  private formatTime(timestamp: number): string {
    const d = new Date(timestamp)
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')} ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`
  }
}
