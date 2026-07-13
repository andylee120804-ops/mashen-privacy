import { DeityInfo } from '../model/PrayerTypes'

@Component
export struct DeityView {
  @Prop deity: DeityInfo
  @Prop scale: number = 1.0
  @Prop opacity: number = 1.0

  build() {
    Column() {
      // 金色光晕
      Circle({ width: 120, height: 120 })
        .fill(`rgba(249, 202, 36, ${0.1 * this.opacity})`)
        .position({ x: '50%', y: '50%' })
        .translate({ x: '-50%', y: '-50%' })

      // 财神形象
      Stack() {
        Image($rawfile(`deities/${this.deity.id}.png`))
          .width(80)
          .height(80)
          .objectFit(ImageFit.Contain)
      }
      .width(80)
      .height(80)
      .scale({ x: this.scale, y: this.scale })
      .opacity(this.opacity)

      // 财神名称
      Text(this.deity.name)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#f9ca24')
        .margin({ top: 8 })

      // 方位标签
      Text(`${this.deity.direction} · ${this.deity.mahjongMeaning}`)
        .fontSize(11)
        .fontColor('rgba(253, 246, 227, 0.5)')
        .margin({ top: 4 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .animation({
      duration: 300,
      curve: Curve.EaseInOut
    })
  }
}