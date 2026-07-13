import { PrayerViewModel } from '../viewmodels/PrayerViewModel'
import { ParticleCanvas, ParticleType } from '../components/ParticleCanvas'
import { TipModal } from '../components/TipModal'
import { router } from '@kit.ArkUI'

@Entry
@Component
struct BlessingCard {
  @Consume viewModel: PrayerViewModel
  @State showFirework: boolean = false
  private tipDialogController: CustomDialogController = new CustomDialogController({
    builder: TipModal({}),
    autoCancel: true,
    alignment: DialogAlignment.Center
  })

  aboutToAppear(): void {
    setTimeout(() => {
      this.showFirework = true
    }, 300)
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#1a1a0a')

      ParticleCanvas({
        particleType: ParticleType.FIREWORK,
        isActive: this.showFirework
      })

      ParticleCanvas({
        particleType: ParticleType.GOLD,
        isActive: true
      })

      Column() {
        Text(`${this.viewModel.todayDeity.name} · ${this.viewModel.todayDeity.direction}`)
          .fontSize(14)
          .fontColor('rgba(253, 246, 227, 0.5)')
          .margin({ bottom: 20 })

        Text(this.viewModel.blessing)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#f9ca24')
          .textAlign(TextAlign.Center)
          .width('80%')
          .lineHeight(36)
          .margin({ bottom: 8 })

        Text('🀄 🀅 🀇 🀄 🀅')
          .fontSize(20)
          .margin({ bottom: 32 })

        Row() {
          Button('再拜一次')
            .fontSize(15)
            .fontColor('#f9ca24')
            .backgroundColor('rgba(249, 202, 36, 0.1)')
            .border({ width: 1, color: 'rgba(249, 202, 36, 0.3)', radius: 25 })
            .padding({ left: 28, right: 28, top: 10, bottom: 10 })
            .onClick(() => {
              this.viewModel.resetPrayer()
              router.replaceUrl({
                url: 'pages/PrayerCard',
                params: { repeat: true }
              })
            })

          Button('打赏麻神')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1a1a0a')
            .backgroundColor('#f9ca24')
            .borderRadius(25)
            .padding({ left: 28, right: 28, top: 10, bottom: 10 })
            .margin({ left: 16 })
            .onClick(() => this.tipDialogController.open())
        }
        .margin({ bottom: 24 })

        Button('返回首页')
          .fontSize(13)
          .fontColor('rgba(253, 246, 227, 0.4)')
          .backgroundColor('transparent')
          .onClick(() => {
            this.viewModel.resetPrayer()
            router.clear()
            router.pushUrl({ url: 'pages/HomePage' })
          })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
  }
}