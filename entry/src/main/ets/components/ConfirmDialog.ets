// entry/src/main/ets/components/ConfirmDialog.ets
// 项目风格确认弹窗（替代系统 promptAction.showDialog）：
// 深色底 #1a1a0a + 金色描边 + 金色标题 + 米色正文 + 取消/确认双按钮。
// 与 GameRecordCard.RecordDialog、GameRecordPage.EditDialog 同风格，
// 供牌局记录删除、祈福记录删除/清空等确认场景复用。visible 由宿主用 if 控制。
@Component
export struct ConfirmDialog {
  /** 弹窗标题（金色粗体） */
  title: string = ''
  /** 正文（米色，自动居中换行） */
  message: string = ''
  /** 确认按钮文案（默认「确定」） */
  confirmText: string = '确定'
  /** 危险操作：确认按钮红底深字（#e74c3c/#1a1a0a，对比 4.60）；否则金底深字 */
  danger: boolean = false
  /** 点遮罩/取消 */
  onCancel: () => void = () => {}
  /** 点确认 */
  onConfirm: () => void = () => {}

  build() {
    Column() {
      Column() {
        Text(this.title)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#f9ca24')
          .textAlign(TextAlign.Center)
          .width('100%')

        Text(this.message)
          .fontSize(13)
          .fontColor('#fdf6e3')
          .textAlign(TextAlign.Center)
          .width('100%')
          .margin({ top: 14 })

        Row() {
          Button('取消')
            .fontSize(15)
            .fontColor('rgba(253, 246, 227, 0.6)')
            .backgroundColor('rgba(253, 246, 227, 0.1)')
            .borderRadius(20)
            .height(40)
            .layoutWeight(1)
            .onClick(() => { this.onCancel() })
          Button(this.confirmText)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.danger ? '#1a1a0a' : '#1a1a0a')
            .backgroundColor(this.danger ? '#e74c3c' : '#f9ca24')
            .borderRadius(20)
            .height(40)
            .layoutWeight(1)
            .margin({ left: 12 })
            .onClick(() => { this.onConfirm() })
        }
        .width('100%')
        .margin({ top: 24 })
      }
      .width('80%')
      .padding(24)
      .backgroundColor('#1a1a0a')
      .borderRadius(16)
      .border({ width: 1.5, color: 'rgba(249, 202, 36, 0.3)' })
      .onClick(() => {}) // 阻止穿透
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(0, 0, 0, 0.7)')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => { this.onCancel() })
  }
}
