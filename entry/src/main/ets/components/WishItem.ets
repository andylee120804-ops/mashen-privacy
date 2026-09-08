// entry/src/main/ets/components/WishItem.ets
import { Wish } from '../model/EnrichTypes'

/** 还愿确认弹窗：深色金边风格，与 TipModal/PrivacyDialog 一致 */
@CustomDialog
struct FulfillWishDialog {
  controller: CustomDialogController
  onConfirm: () => void = () => {}

  build() {
    Column() {
      // 顶部红色装饰条
      Row()
        .width('100%')
        .height(4)
        .backgroundColor('#c0392b')

      // 标题
      Text('✦  磕头还愿  ✦')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#f9ca24')
        .letterSpacing(2)
        .margin({ top: 22, bottom: 6 })

      Text('「诚心磕头，还愿谢神」')
        .fontSize(12)
        .fontColor('rgba(253, 246, 227, 0.5)')
        .fontStyle(FontStyle.Italic)
        .margin({ bottom: 18 })

      // 分隔线
      Row()
        .width('48%')
        .height(1)
        .backgroundColor('rgba(249, 202, 36, 0.25)')
        .margin({ bottom: 18 })

      // 操作按钮组
      Row() {
        Button('取消')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('rgba(253, 246, 227, 0.5)')
          .backgroundColor('rgba(255, 255, 255, 0.05)')
          .border({ width: 1, color: 'rgba(249, 202, 36, 0.35)', radius: 20 })
          .height(36)
          .padding({ left: 28, right: 28 })
          .onClick(() => this.controller.close())

        Button('磕头还愿')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1a1a0a')
          .backgroundColor('#f9ca24')
          .borderRadius(20)
          .height(36)
          .padding({ left: 28, right: 28 })
          .shadow({ radius: 10, color: 'rgba(249, 202, 36, 0.35)', offsetY: 2 })
          .onClick(() => {
            this.controller.close()
            this.onConfirm()
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceEvenly)
      .margin({ bottom: 8 })
    }
    .width('78%')
    .backgroundColor('#1a1a0a')
    .borderRadius(16)
    .border({ width: 1.5, color: 'rgba(249, 202, 36, 0.3)' })
    .shadow({ radius: 30, color: 'rgba(0, 0, 0, 0.6)', offsetY: 6 })
    .clip(true)
  }
}

@Component
export struct WishItem {
  @Prop wish: Wish
  @StorageLink('deviceUserId') deviceUserId: string = ''
  // 还愿回调由父页面持有（数据操作集中在页面层）
  onFulfill: (wishId: string) => void = (_wishId: string) => {}
  // 删除回调
  onDelete: (wishId: string) => void = (_wishId: string) => {}
  private fulfillDialogController: CustomDialogController | null = null

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
            .fontSize(11)
            .fontColor('rgba(253, 246, 227, 0.5)')
          Text(' · ')
            .fontSize(11)
            .fontColor('rgba(253, 246, 227, 0.5)')
          Text(this.formatTime(this.wish.createdAt))
            .fontSize(11)
            .fontColor('rgba(253, 246, 227, 0.5)')
        }
        .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.wish.fulfilled) {
        Text('✅ 已还愿')
          .fontSize(12)
          .fontColor('rgba(46, 204, 113, 0.8)')
          .backgroundColor('rgba(46, 204, 113, 0.1)')
          .borderRadius(10)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .alignSelf(ItemAlign.End)
      } else if (this.deviceUserId !== '' && this.deviceUserId === this.wish.userId) {
        Text('🙏 还愿')
          .fontSize(12)
          .fontColor('#f9ca24')
          .backgroundColor('rgba(249, 202, 36, 0.1)')
          .borderRadius(10)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .alignSelf(ItemAlign.End)
          .onClick(() => { this.confirmFulfill() })
      }
    }
    .width('100%')
    .padding(12)
    .border({ width: { bottom: 0.5 }, color: 'rgba(249, 202, 36, 0.08)' })
    .gesture(
      LongPressGesture({ repeat: false })
        .onAction(() => {
          if (this.deviceUserId !== '' && this.deviceUserId === this.wish.userId) {
            this.confirmDelete()
          }
        })
    )
  }

  private confirmFulfill(): void {
    // 惰性创建弹窗控制器，避免提前构建子树
    this.fulfillDialogController = new CustomDialogController({
      builder: FulfillWishDialog({
        onConfirm: () => { this.onFulfill(this.wish.id) }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      customStyle: true
    })
    this.fulfillDialogController.open()
  }

  private confirmDelete(): void {
    AlertDialog.show({
      title: '删除心愿',
      message: '确定要删除这条心愿吗？删除后不可恢复。',
      primaryButton: {
        value: '删除',
        action: () => { this.onDelete(this.wish.id) }
      },
      secondaryButton: {
        value: '取消',
        action: () => {}
      }
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
