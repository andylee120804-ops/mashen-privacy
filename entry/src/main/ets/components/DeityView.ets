import { DeityInfo } from '../model/PrayerTypes'

/**
 * 单个财神展示：金色光晕 + 形象 + 名号 + 方位。
 * 由 DeityArrayView 在五神阵中复用，也可单独使用（如 HomePage 主位）。
 *
 * - iconSize：形象尺寸（px），体现主次（避开基类 .size() 通用属性）
 * - isHighlight：主位高亮，光晕更强、名号更大
 * - blessingProgress：祝福阶段光晕脉动放大（0-1）
 */
@Component
export struct DeityView {
  @Prop deity: DeityInfo
  @Prop deityScale: number = 1.0
  @Prop deityOpacity: number = 1.0
  @Prop iconSize: number = 80
  @Prop isHighlight: boolean = false
  @Prop blessingProgress: number = 0

  private haloSize(): number {
    return this.iconSize * 1.5 * (1 + this.blessingProgress * 0.3)
  }

  private haloAlpha(): number {
    const base = this.isHighlight ? 0.28 : 0.10
    return Math.min(1, base * this.deityOpacity * (1 + this.blessingProgress * 0.7))
  }

  build() {
    Column() {
      // 金色光晕
      Circle({ width: this.haloSize(), height: this.haloSize() })
        .fill(`rgba(249, 202, 36, ${this.haloAlpha()})`)
        .position({ x: '50%', y: '50%' })
        .translate({ x: '-50%', y: '-50%' })

      // 财神形象
      Stack() {
        Image($rawfile(`deities/${this.deity.id}.png`))
          .width(this.iconSize)
          .height(this.iconSize)
          .objectFit(ImageFit.Contain)
      }
      .width(this.iconSize)
      .height(this.iconSize)
      .scale({ x: this.deityScale, y: this.deityScale })
      .opacity(this.deityOpacity)

      // 财神名号
      Text(this.deity.name)
        .fontSize(this.isHighlight ? 18 : 14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#f9ca24')
        .margin({ top: 8 })
        .opacity(this.deityOpacity)

      // 方位标签（装饰符包裹，与寓意分层避免长行随意断行）
      Text(`· ${this.deity.direction} ·`)
        .fontSize(10)
        .fontColor('rgba(249, 202, 36, 0.6)')
        .margin({ top: 4 })
        .opacity(this.deityOpacity)

      // 麻将寓意：四字逗号处换行，两行齐整排列
      Text(this.deity.mahjongMeaning.replace('，', '\n'))
        .fontSize(10)
        .fontColor('rgba(253, 246, 227, 0.5)')
        .textAlign(TextAlign.Center)
        .lineHeight(15)
        .margin({ top: 2 })
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .opacity(this.deityOpacity)
    }
    .width(this.iconSize * 1.6)
    .alignItems(HorizontalAlign.Center)
    .animation({
      duration: 200,
      curve: Curve.EaseOut
    })
  }
}
