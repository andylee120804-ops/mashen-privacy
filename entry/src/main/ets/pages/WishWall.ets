// entry/src/main/ets/pages/WishWall.ets
import { Wish } from '../model/EnrichTypes'
import { CloudService } from '../service/CloudService'
import { EnrichViewModel } from '../viewmodels/EnrichViewModel'
import { FIVE_DEITIES, DeityInfo } from '../model/PrayerTypes'
import { WishItem } from '../components/WishItem'

@Component
export struct WishWallPage {
  @State wishes: Wish[] = []
  @State loading: boolean = false
  @State showCreateDialog: boolean = false
  @State newWishContent: string = ''
  @State selectedDeity: number = 0

  aboutToAppear(): void {
    this.loadData()
  }

  async loadData(): Promise<void> {
    this.loading = true
    try {
      this.wishes = await CloudService.getWishes()
    } catch (err) {
      console.error('[WishWall] load failed:', JSON.stringify(err))
    } finally {
      this.loading = false
    }
  }

  async fulfillWish(wishId: string): Promise<void> {
    const ok: boolean = await CloudService.fulfillWish(wishId)
    if (ok) {
      const vm: EnrichViewModel = AppStorage.get<EnrichViewModel>('enrichViewModel') as EnrichViewModel
      if (vm) { vm.incWishFulfilled() }
      this.getUIContext().getPromptAction().showToast({ message: '还愿成功！' })
      this.loadData()
    } else {
      this.getUIContext().getPromptAction().showToast({ message: '还愿失败，请重试' })
    }
  }

  private closeCreateDialog(): void {
    this.showCreateDialog = false
    this.newWishContent = ''
    this.selectedDeity = 0
  }

  private async submitWish(): Promise<void> {
    const content: string = this.newWishContent.trim()
    if (content.length === 0) return
    const ok: boolean = await CloudService.createWish(content, this.selectedDeity)
    if (ok) {
      this.getUIContext().getPromptAction().showToast({ message: '许愿成功！' })
      this.closeCreateDialog()
      this.loadData()
    } else {
      this.getUIContext().getPromptAction().showToast({ message: '许愿失败，请重试' })
    }
  }

  build() {
    Stack() {
      Column() {
        // 标题
        Row() {
          Text('✨ 心愿墙')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#f9ca24')
          Blank()
          Text('+ 许愿')
            .fontSize(13)
            .fontColor('#f9ca24')
            .backgroundColor('rgba(249, 202, 36, 0.1)')
            .borderRadius(14)
            .padding({ left: 14, right: 14, top: 6, bottom: 6 })
            .onClick(() => { this.showCreateDialog = true })
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 12, bottom: 8 })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

        if (this.loading) {
          Column() {
            LoadingProgress().width(40).height(40).color('#f9ca24')
            Text('加载中...').fontSize(12).fontColor('rgba(253, 246, 227, 0.5)').margin({ top: 8 })
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.wishes.length === 0) {
          Column() {
            Text('✨').fontSize(40).margin({ bottom: 8 })
            Text('心愿墙空空如也').fontSize(14).fontColor('rgba(253, 246, 227, 0.5)')
            Text('成为第一个许愿的人吧！').fontSize(14).fontColor('rgba(253, 246, 227, 0.5)').margin({ top: 4 })
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          Scroll() {
            Column() {
              ForEach(this.wishes, (wish: Wish) => {
                WishItem({ wish: wish, onFulfill: (id: string) => { this.fulfillWish(id) } })
              })
            }
            .width('100%')
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        }
      }
      .width('100%')
      .height('100%')

      // 许愿弹窗
      if (this.showCreateDialog) {
        Column() {
          Column() {
            Text('🙏 许下心愿')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#f9ca24')
              .margin({ bottom: 16 })

            TextInput({ text: this.newWishContent, placeholder: '写下你的心愿（最多30字）' })
              .fontSize(14)
              .fontColor('#fdf6e3')
              .placeholderColor('rgba(253, 246, 227, 0.3)')
              .backgroundColor('rgba(249, 202, 36, 0.08)')
              .borderRadius(8)
              .height(44)
              .padding({ left: 12, right: 12 })
              .maxLength(30)
              .onChange((value: string) => { this.newWishContent = value })
              .margin({ bottom: 12 })

            Text('关联财神（可选）')
              .fontSize(12)
              .fontColor('rgba(253, 246, 227, 0.5)')
              .margin({ bottom: 8 })

            Row() {
              ForEach(FIVE_DEITIES, (deity: DeityInfo) => {
                Text(deity.name)
                  .fontSize(11)
                  .fontColor(this.selectedDeity === deity.id ? '#1a1a0a' : 'rgba(253, 246, 227, 0.5)')
                  .backgroundColor(this.selectedDeity === deity.id ? '#f9ca24' : 'rgba(249, 202, 36, 0.1)')
                  .borderRadius(12)
                  .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                  .margin({ right: 4 })
                  .onClick(() => { this.selectedDeity = deity.id })
              })
            }
            .width('100%')
            .margin({ bottom: 16 })

            Row() {
              Button('取消')
                .fontSize(13)
                .fontColor('rgba(253, 246, 227, 0.5)')
                .backgroundColor('rgba(253, 246, 227, 0.1)')
                .borderRadius(20)
                .padding({ left: 24, right: 24, top: 8, bottom: 8 })
                .onClick(() => { this.closeCreateDialog() })

              Button('许愿')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor('#1a1a0a')
                .backgroundColor('#f9ca24')
                .borderRadius(20)
                .padding({ left: 24, right: 24, top: 8, bottom: 8 })
                .margin({ left: 16 })
                .enabled(this.newWishContent.trim().length > 0)
                .onClick(() => { this.submitWish() })
            }
          }
          .width('78%')
          .padding(20)
          .backgroundColor('#1a1a0a')
          .borderRadius(16)
          .border({ width: 1.5, color: 'rgba(249, 202, 36, 0.3)' })
          .onClick(() => {}) // 拦截点击，避免穿透到背景层关闭弹窗
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.7)')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .onClick(() => { this.closeCreateDialog() })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1a1a0a')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
  }
}
