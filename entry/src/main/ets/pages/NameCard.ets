import { PrayerViewModel } from '../viewmodels/PrayerViewModel'
import { router } from '@kit.ArkUI'

@Entry
@Component
struct NameCard {
  @Consume viewModel: PrayerViewModel
  @State inputName: string = ''

  build() {
    Column() {
      // 祥云装饰
      Text('☁')
        .fontSize(40)
        .fontColor('rgba(249, 202, 36, 0.08)')
        .position({ x: 20, y: 40 })

      Column() {
        // 标题
        Text('🙏 祈福者')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#f9ca24')
          .margin({ bottom: 32 })

        // 输入框
        Stack() {
          TextInput({ placeholder: '输入你的名字或麻将ID', text: this.inputName })
            .fontSize(16)
            .fontColor('#fdf6e3')
            .placeholderColor('rgba(253, 246, 227, 0.3)')
            .backgroundColor('rgba(249, 202, 36, 0.06)')
            .border({ width: 2, color: 'rgba(249, 202, 36, 0.35)', radius: 8 })
            .padding(16)
            .width('75%')
            .onChange((value: string) => {
              this.inputName = value
            })
        }
        .width('100%')

        // 最近使用
        if (this.viewModel.recentNames.length > 0) {
          Column() {
            Text('最近使用')
              .fontSize(11)
              .fontColor('rgba(249, 202, 36, 0.3)')
              .margin({ top: 16, bottom: 8 })

            Row() {
              ForEach(this.viewModel.recentNames, (name: string) => {
                Text(`🀄 ${name}`)
                  .fontSize(12)
                  .fontColor('rgba(249, 202, 36, 0.7)')
                  .padding({ left: 12, right: 12, top: 4, bottom: 4 })
                  .backgroundColor('rgba(249, 202, 36, 0.1)')
                  .border({ width: 1, color: 'rgba(249, 202, 36, 0.2)', radius: 20 })
                  .margin({ right: 8 })
                  .onClick(() => {
                    this.inputName = name
                  })
              })
            }
            .flexWrap(FlexWrap.Wrap)
            .justifyContent(FlexAlign.Center)
          }
          .width('75%')
        }

        // 确认按钮
        Button('叩拜麻神 →')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1a1a0a')
          .backgroundColor('#f9ca24')
          .borderRadius(25)
          .padding({ left: 48, right: 48, top: 12, bottom: 12 })
          .shadow({
            radius: 15,
            color: 'rgba(249, 202, 36, 0.3)',
            offsetY: 4
          })
          .margin({ top: 40 })
          .enabled(this.inputName.trim().length > 0)
          .opacity(this.inputName.trim().length > 0 ? 1.0 : 0.5)
          .onClick(() => {
            this.viewModel.confirmName(this.inputName.trim())
            router.pushUrl({ url: 'pages/PrayerCard' })
          })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1a1a0a')
  }
}