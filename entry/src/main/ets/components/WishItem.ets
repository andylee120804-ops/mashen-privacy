// entry/src/main/ets/components/WishItem.ets
import { Wish } from '../model/EnrichTypes'

@Component
export struct WishItem {
  @Prop wish: Wish
  @State isOwn: boolean = false
  // 还愿回调由父页面持有（数据操作集中在页面层）
  onFulfill: (wishId: string) => void = (_wishId: string) => {}

  aboutToAppear(): void {
    try {
      const uid: string | undefined = AppStorage.get<string>('deviceUserId')
      this.isOwn = (uid || '') === this.wish.userId
    } catch {
      this.isOwn = false
    }
  }

  build() {
    Row() {
      Column() {
        Text(this.wish.content)
          .fontSize(14)
          .fontColor('#fdf6e3')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Row() {
          Text(this.wish.nickname)
            .fontSize(10)
            .fontColor('rgba(253, 246, 227, 0.3)')
          Text(' · ')
            .fontSize(10)
            .fontColor('rgba(253, 246, 227, 0.2)')
          Text(this.formatTime(this.wish.createdAt))
            .fontSize(10)
            .fontColor('rgba(253, 246, 227, 0.3)')
        }
        .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.wish.fulfilled) {
        Text('✅ 已还愿')
          .fontSize(11)
          .fontColor('rgba(46, 204, 113, 0.8)')
          .backgroundColor('rgba(46, 204, 113, 0.1)')
          .borderRadius(10)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      } else if (this.isOwn) {
        Text('🙏 还愿')
          .fontSize(11)
          .fontColor('#f9ca24')
          .backgroundColor('rgba(249, 202, 36, 0.1)')
          .borderRadius(10)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .onClick(() => { this.confirmFulfill() })
      }
    }
    .width('100%')
    .padding(12)
    .border({ width: { bottom: 0.5 }, color: 'rgba(249, 202, 36, 0.08)' })
  }

  private confirmFulfill(): void {
    AlertDialog.show({
      title: '确认还愿',
      message: '确定要标记此心愿为已达成吗？',
      confirm: {
        value: '还愿',
        fontColor: '#f9ca24',
        action: () => { this.onFulfill(this.wish.id) }
      },
      cancel: () => {}
    })
  }

  private formatTime(isoStr: string): string {
    if (!isoStr) return ''
    try {
      const d: Date = new Date(isoStr)
      return `${d.getMonth() + 1}/${d.getDate()}`
    } catch {
      return ''
    }
  }
}
