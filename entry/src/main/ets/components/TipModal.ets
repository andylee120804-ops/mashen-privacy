// entry/src/main/ets/components/TipModal.ets
// 供奉台（免费仪式弹窗）。
// 审核整改（2026-09-27）：供奉麻神应用内付款被判封建迷信拒审，移除全部收款元素
// （金额卡/支付/云端功德），保留仪式感：香火粒子 + 祝福语，纯免费。
// 入口不变：祈福结算页「🧧 供奉麻神」、我的页「🧧 诚心供奉」。
// WCAG（规则 common/wcag-contrast.md，弹窗底 #1a1a0a）：金实色 #f9ca24 仅用于
// 大字/实底钮（≥3:1 或钮上深字），正文米色 alpha≥0.5、金色 alpha≥0.6，深字实色 #1a1a0a。

/** 香火粒子静态参数（构造时随机生成，避免动画期间重算） */
interface FireParticle {
  id: number
  angle: number      // 发射角度（度）
  dist: number       // 飞行距离（vp）
  delay: number      // 起飞延迟（ms）
  size: number       // 字号
}

@CustomDialog
export struct TipModal {
  controller: CustomDialogController
  @State incenseAnim: boolean = false   // 点香粒子触发
  private particles: FireParticle[] = []

  aboutToAppear(): void {
    // 香火粒子：10 颗随机角度/距离
    for (let i = 0; i < 10; i++) {
      this.particles.push({
        id: i,
        angle: Math.random() * 360,
        dist: 60 + Math.random() * 90,
        delay: i * 45,
        size: 12 + Math.random() * 10
      })
    }
  }

  /** 点香供奉：一次粒子 + 祝福语，无任何支付 */
  private offerIncense(): void {
    this.incenseAnim = false
    setTimeout(() => {
      this.incenseAnim = true
    }, 50)
    this.getUIContext().getPromptAction().showToast({ message: '心意已到 · 福报自来 🙏' })
  }

  build() {
    Column() {
      // 顶部红色装饰条
      Row()
        .width('100%')
        .height(4)
        .backgroundColor('#c0392b')

      Text('✦  供奉麻神  ✦')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#f9ca24')
        .letterSpacing(2)
        .margin({ top: 20, bottom: 6 })

      Text('「心诚则灵 · 福报自来」')
        .fontSize(12)
        .fontColor('rgba(253, 246, 227, 0.5)')
        .fontStyle(FontStyle.Italic)
        .margin({ bottom: 14 })

      // 香火粒子层（点香触发，纯仪式）
      Stack() {
        ForEach(this.particles, (p: FireParticle) => {
          Text('✦')
            .fontSize(p.size)
            .fontColor('#f9ca24')
            .opacity(this.incenseAnim ? 0 : 0.9)
            .translate({
              x: this.incenseAnim ? Math.cos(p.angle * Math.PI / 180) * p.dist : 0,
              y: this.incenseAnim ? Math.sin(p.angle * Math.PI / 180) * p.dist - 20 : 0
            })
            .animation({
              duration: 1100,
              delay: p.delay,
              curve: Curve.EaseOut
            })
        }, (p: FireParticle) => 'p' + p.id)
      }
      .width('100%')
      .height(80)
      .margin({ top: 8 })

      Text('诚心供奉 · 无求自得')
        .fontSize(13)
        .fontColor('rgba(253, 246, 227, 0.75)')
        .margin({ bottom: 14 })

      Button('🪷 点香供奉')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1a1a0a')
        .backgroundColor('#f9ca24')
        .borderRadius(20)
        .height(40)
        .width('60%')
        .margin({ bottom: 10 })
        .onClick(() => {
          this.offerIncense()
        })

      Text('供奉即心意 · 心诚比金贵')
        .fontSize(9)
        .fontColor('rgba(253, 246, 227, 0.5)')
        .margin({ bottom: 8 })

      Button('关闭')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#f9ca24')
        .backgroundColor(Color.Transparent)
        .border({ width: 1, color: 'rgba(249, 202, 36, 0.4)' })
        .borderRadius(20)
        .height(34)
        .padding({ left: 28, right: 28 })
        .margin({ bottom: 12 })
        .onClick(() => {
          this.controller.close()
        })
    }
    .width('78%')
    .backgroundColor('#1a1a0a')
    .borderRadius(16)
    .border({ width: 1.5, color: 'rgba(249, 202, 36, 0.3)' })
    .shadow({ radius: 30, color: 'rgba(0, 0, 0, 0.6)', offsetY: 6 })
    .clip(true)
  }
}
