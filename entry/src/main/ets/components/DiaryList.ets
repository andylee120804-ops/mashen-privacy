import { PrayerRecord } from '../model/PrayerTypes'
import { EnrichViewModel } from '../viewmodels/EnrichViewModel'

/**
 * 祈福日记懒加载数据源：配合 LazyForEach 只构建可视区行，
 * 沿用 HistoryPanel 的 IDataSource 模式。
 */
class DiaryDataSource implements IDataSource {
  private records: PrayerRecord[] = []
  private listeners: DataChangeListener[] = []

  totalCount(): number {
    return this.records.length
  }

  getData(index: number): PrayerRecord {
    return this.records[index]
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    const existing = this.listeners.indexOf(listener)
    if (existing < 0) {
      this.listeners.push(listener)
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const idx = this.listeners.indexOf(listener)
    if (idx >= 0) {
      this.listeners.splice(idx, 1)
    }
  }

  setRecords(records: PrayerRecord[]): void {
    this.records = records
    this.listeners.forEach((listener: DataChangeListener) => {
      listener.onDataReloaded()
    })
  }
}

/** 祝福语预览截断长度 */
const BLESSING_PREVIEW_LEN = 24

@Component
export struct DiaryList {
  @Prop @Watch('onRecordsUpdated') records: PrayerRecord[]
  @Link enrichVM: EnrichViewModel
  @State editingId: string = ''
  @State editingNote: string = ''
  private dataSource: DiaryDataSource = new DiaryDataSource()

  aboutToAppear(): void {
    this.dataSource.setRecords(this.records)
  }

  onRecordsUpdated(): void {
    this.dataSource.setRecords(this.records)
  }

  build() {
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
            this.DiaryItem(record)
          }
        }, (record: PrayerRecord) => record.id)
      }
      .cachedCount(5)
      .layoutWeight(1)
    }
  }

  @Builder
  DiaryItem(record: PrayerRecord) {
    Column() {
      Row() {
        Column() {
          Text(record.name)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#fdf6e3')
          Text(this.formatTime(record.timestamp))
            .fontSize(11)
            .fontColor('rgba(253, 246, 227, 0.4)')
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Text(this.blessingPreview(record.blessing))
          .fontSize(12)
          .fontColor('rgba(253, 246, 227, 0.6)')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('45%')
      }
      .width('100%')

      if (this.editingId === record.id) {
        Row() {
          TextInput({ text: this.editingNote, placeholder: '添加备注...' })
            .fontSize(12)
            .fontColor('#fdf6e3')
            .placeholderColor('rgba(253, 246, 227, 0.3)')
            .backgroundColor('rgba(249, 202, 36, 0.08)')
            .borderRadius(6)
            .height(32)
            .layoutWeight(1)
            .onChange((value: string) => {
              this.editingNote = value
            })
          Button('保存')
            .fontSize(11)
            .fontColor('#1a1a0a')
            .backgroundColor('#f9ca24')
            .borderRadius(4)
            .height(28)
            .padding({ left: 10, right: 10 })
            .margin({ left: 8 })
            .onClick(() => {
              this.enrichVM.setDiaryNote(record.id, this.editingNote)
              this.editingId = ''
            })
        }
        .width('100%')
        .margin({ top: 8 })
      } else {
        Row() {
          Text(this.noteText(record.id))
            .fontSize(11)
            .fontColor(this.hasNote(record.id) ? 'rgba(253, 246, 227, 0.5)' : 'rgba(253, 246, 227, 0.2)')
            .fontStyle(this.hasNote(record.id) ? FontStyle.Normal : FontStyle.Italic)
            .onClick(() => {
              this.editingId = record.id
              this.editingNote = this.enrichVM.getDiaryNote(record.id)
            })
        }
        .width('100%')
        .margin({ top: 8 })
      }
    }
    .width('100%')
    .padding(12)
    .border({ width: { bottom: 0.5 }, color: 'rgba(249, 202, 36, 0.1)' })
  }

  private hasNote(recordId: string): boolean {
    return this.enrichVM.getDiaryNote(recordId) !== ''
  }

  private noteText(recordId: string): string {
    const note = this.enrichVM.getDiaryNote(recordId)
    return note !== '' ? note : '点击添加备注'
  }

  private blessingPreview(blessing: string): string {
    if (blessing.length > BLESSING_PREVIEW_LEN) {
      return blessing.substring(0, BLESSING_PREVIEW_LEN) + '...'
    }
    return blessing
  }

  private formatTime(timestamp: number): string {
    const d = new Date(timestamp)
    const month: string = String(d.getMonth() + 1).padStart(2, '0')
    const day: string = String(d.getDate()).padStart(2, '0')
    const hours: string = String(d.getHours()).padStart(2, '0')
    const minutes: string = String(d.getMinutes()).padStart(2, '0')
    return `${d.getFullYear()}-${month}-${day} ${hours}:${minutes}`
  }
}
