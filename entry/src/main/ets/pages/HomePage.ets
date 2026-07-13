import { PrayerViewModel } from '../viewmodels/PrayerViewModel'
import { DeityView } from '../components/DeityView'
import { TipModal } from '../components/TipModal'
import { PrayerPhase } from '../model/PrayerTypes'
import { router } from '@kit.ArkUI'

@Entry
@Component
struct HomePage {
  @Provide viewModel: PrayerViewModel = new PrayerViewModel()
  @State showHistory: boolean = false
  private tipDialogController: CustomDialogController = new CustomDialogController({
    builder: TipModal({}),
    autoCancel: true,
    alignment: DialogAlignment.Center
  })

  aboutToAppear(): void {
    this.viewModel.initialize(getContext(this))
  }

  build() {
    Stack() {
      Column() {
        // 顶部装饰
        Text('✦ 麻神赐福 · 手气长虹 ✦')
          .fontSize(12)
          .fontColor('rgba(249, 202, 36, 0.6)')
          .margin({ top: 48 })

        // 财神展示区
        Column() {
          DeityView({
            deity: this.viewModel.todayDeity,
            scale: 1.0,
            opacity: 1.0
          })

          Text('「心诚则灵，牌来运转」')
            .fontSize(14)
            .fontColor('rgba(249, 202, 36, 0.5)')
            .fontStyle(FontStyle.Italic)
            .margin({ top: 12 })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)

        // 主按钮
        Button('🪷 开始祈福')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1a1a0a')
          .backgroundColor('#f9ca24')
          .borderRadius(25)
          .padding({ left: 40, right: 40, top: 14, bottom: 14 })
          .shadow({
            radius: 20,
            color: 'rgba(249, 202, 36, 0.4)',
            offsetY: 4
          })
          .onClick(() => {
            this.viewModel.startPrayer()
            router.pushUrl({ url: 'pages/NameCard' })
          })
          .margin({ bottom: 12 })

        Text('← 左滑查看祈福记录')
          .fontSize(11)
          .fontColor('rgba(249, 202, 36, 0.3)')
          .margin({ bottom: 32 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#1a1a0a')

      // 右下角打赏悬浮按钮
      Button('🧧')
        .fontSize(20)
        .width(44)
        .height(44)
        .borderRadius(22)
        .backgroundColor('#f9ca24')
        .shadow({
          radius: 12,
          color: 'rgba(249, 202, 36, 0.4)'
        })
        .position({ x: '85%', y: '82%' })
        .onClick(() => this.tipDialogController.open())
    }
    .width('100%')
    .height('100%')
    .gesture(
      PanGesture({ direction: PanDirection.Left })
        .onActionEnd(() => {
          this.showHistory = true
        })
    )
  }
}