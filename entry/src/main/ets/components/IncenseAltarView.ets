/**
 * 香炉（带三炷香）：用与财神同款 FLUX 生成的 Q版国风 PNG（props/incense_burner.png）。
 * 香炉内已含三炷点燃的香，lightProgress 0->1 驱动淡入 + 轻微放大表现敬香显现，
 * 烟雾由 PrayerCard 的 SMOKE 粒子叠加。
 */
@Component
export struct IncenseAltarView {
  @Prop lightProgress: number = 0

  build() {
    Image($rawfile('props/incense_burner.png'))
      .width(120)
      .height(108)
      .objectFit(ImageFit.Contain)
      .opacity(this.lightProgress)
      .scale({
        x: 0.92 + 0.08 * this.lightProgress,
        y: 0.92 + 0.08 * this.lightProgress
      })
  }
}
