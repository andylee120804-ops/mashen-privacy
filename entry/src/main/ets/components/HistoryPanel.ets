import { PrayerRecord } from '../model/PrayerTypes'

@Component
export struct HistoryPanel {
  @Prop records: PrayerRecord[]
  @BuilderParam onClose: () => void = () => {}

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('祈福记录')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#f9ca24')
        Blank()
        Text('关闭')
          .fontSize(14)
          .fontColor('#fdf6e3')
          .onClick(() => this.onClose())
      }
      .width('100%')
      .padding(16)

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
          ForEach(this.records, (record: PrayerRecord, index: number) => {
            ListItem() {
              this.RecordItem(record)
            }
          }, (record: PrayerRecord) => record.id)
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1a1a0a')
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
          .fontColor('rgba(253, 246, 227, 0.4)')
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
  }

  private formatTime(timestamp: number): string {
    const d = new Date(timestamp)
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')} ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`
  }
}