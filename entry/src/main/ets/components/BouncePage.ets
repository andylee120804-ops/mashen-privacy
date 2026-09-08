// components/BouncePage.ets
// 全屏固定布局页（祈福/求签/木鱼等 100% 画布）的"可回弹"外壳。
// 背景：AGC「滑动到边界有反馈动效」真机检测要求页面上滑/下滑到边界有 Spring 回弹。
// 但画布页内容高度 == 视口时，Scroll 滚动区间为 0，edgeEffect 的 alwaysEnabled
// 只对"内容不足一屏"生效（见 Scroll.edgeEffect options 注释），恰好一屏=满屏=不生效，
// 表现为拖动无任何反馈。解法：用 onAreaChange 实测视口高度，把内容高度设成
// 视口 + SLACK，滚动区间恒 > 0（真实可滚 + 两端弹簧都生效），内部 % 布局只
// 相差几像素、不可察觉，且旋转/换设备自适应。
const SLACK: number = 8 // vp：超出视口的高度（滚动区间下限）

@Component
export struct BouncePage {
  /** 子页内容（画布布局原样传入） */
  @BuilderParam content: () => void
  @State canvasH: number = 0 // vp；0 = 首帧未测到，退化为 100%

  build() {
    Scroll() {
      Column() {
        this.content()
      }
      .width('100%')
      .height(this.canvasH > 0 ? this.canvasH + SLACK : '100%') // 数字单位 vp
    }
    .width('100%')
    .height('100%')
    .scrollable(ScrollDirection.Vertical)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .scrollBar(BarState.Off)
    .backgroundColor('#1a1a0a')
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      const h: number = Number(newArea.height) || 0
      if (h > 0 && Math.abs(h - this.canvasH) > 0.5) {
        this.canvasH = h
      }
    })
  }
}
