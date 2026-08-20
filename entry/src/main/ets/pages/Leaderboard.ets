// entry/src/main/ets/pages/Leaderboard.ets
// Placeholder - will be replaced in Task 5.1

@Component
export struct LeaderboardPage {
  build() {
    Column() {
      Text('🏆 排行榜')
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
