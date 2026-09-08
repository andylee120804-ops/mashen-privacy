// components/PageBack.ets
// 子页返回键：供 EntryShell 独立模式（standalone）下各功能页复用。
// 与页面 20sp 大标题同一行（方案：返回并入大标题行，不再单独占一行）。
// 样式与其他子页返回入口一致：14sp 金色「← 返回」（≥3:1 对比度，随行高自带可点区域）。
@Component
export struct PageBack {
  onBack?: () => void

  build() {
    Text('← 返回')
      .fontSize(14)
      .fontColor('#f9ca24')
      .padding({ left: 6, right: 12 })
      .onClick((): void => {
        if (this.onBack) {
          this.onBack()
        } else {
          this.getUIContext().getRouter().back()
        }
      })
  }
}
