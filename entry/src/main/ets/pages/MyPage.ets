// entry/src/main/ets/pages/MyPage.ets
// Placeholder - will be replaced in Task 2.5

@Component
export struct MyPage {
  build() {
    Column() {
      Text('👤 我的')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#f9ca24')
      Text('即将上线...')
        .fontSize(14)
        .fontColor('rgba(253, 246, 227, 0.5)')
        .margin({ top: 8 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1a1a0a')
    .justifyContent(FlexAlign.Center)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
  }
}
