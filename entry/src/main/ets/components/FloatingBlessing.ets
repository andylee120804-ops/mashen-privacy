/**
 * 磕头时飘出的祝福语：从小人头顶向上飘升 + 淡出 + 放大 + 水平偏移。
 * 生命周期由 PrayerCard 管理（加入数组 -> 动画结束后移除），组件自身只负责动画。
 *
 * delayMs 参数控制飘字出现的延迟，实现多条飘字依次飘出的效果，
 * 替代原先 PrayerCard 中的逐条 setTimeout 加入逻辑。
 */
@Component
export struct FloatingBlessing {
  @Prop text: string
  @Prop offsetX: number = 0   // 水平偏移，多条飘字错开位置
  @Prop delayMs: number = 0   // 出现延迟（ms），多条飘字错开飘出
  @State offsetY: number = 0
  @State opacityVal: number = 0  // 初始不可见，延迟结束后才显现
  @State scaleVal: number = 0.6

  aboutToAppear(): void {
    // 阶段1：延迟结束后显现（opacity 0->1, scale 0.6->1.0）
    this.getUIContext().animateTo({
      duration: 150,
      curve: Curve.EaseIn,
      delay: this.delayMs
    }, () => {
      this.opacityVal = 1
      this.scaleVal = 1.0
    })
    // 阶段2：飘升 + 淡出 + 放大（延迟结束后开始）
    // 时长约束：点击完成时延标准 2400ms，最迟一条（delayMs=600）须在 ~2s 内结束
    this.getUIContext().animateTo({
      duration: 1200,
      curve: Curve.EaseOut,
      delay: this.delayMs + 150
    }, () => {
      this.offsetY = -220
      this.opacityVal = 0
      this.scaleVal = 1.3
    })
  }

  build() {
    Text(this.text)
      .fontSize(24)
      .fontWeight(FontWeight.Bold)
      .fontColor('#f9ca24')
      .textShadow({ radius: 10, color: 'rgba(249,202,36,0.7)', offsetX: 0, offsetY: 0 })
      .translate({ x: this.offsetX, y: this.offsetY })
      .opacity(this.opacityVal)
      .scale({ x: this.scaleVal, y: this.scaleVal })
  }
}
