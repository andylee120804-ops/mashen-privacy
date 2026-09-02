// entry/src/main/ets/pages/EntryShell.ets
// 统一 @Entry 外壳：从「我的」页进入各可配置入口时提供返回头。
// 各入口页本身为 @Component 内容组件（无返回头）；Tab 模式由 MainTabs 直接渲染。
import { QiuQianPage } from './QiuQian'
import { MuyuPage } from './MuyuPage'
import { FortuneAlmanacPage } from './FortuneAlmanacPage'
import { WishWallPage } from './WishWall'
import { LeaderboardPage } from './Leaderboard'
import { EncyclopediaPage } from './EncyclopediaPage'

@Entry
@Component
struct EntryShell {
  @State entryId: string = ''

  aboutToAppear(): void {
    const params = this.getUIContext().getRouter().getParams() as Record<string, Object>
    if (params && params['entryId']) {
      this.entryId = params['entryId'] as string
    }
    // 同步激活入口 id：求签页摇晃门控读 activeEntryId，EntryShell 独立进入求签时也要能摇出签
    AppStorage.setOrCreate('activeEntryId', this.entryId)
  }

  build() {
    Column() {
      // 返回头（各入口页自带标题行，此处只提供返回）
      Row() {
        Text('← 返回')
          .fontSize(14)
          .fontColor('#f9ca24')
          .onClick((): void => {
            this.getUIContext().getRouter().back()
          })
        Blank()
        Text(' ')
          .fontSize(14)
          .width(60)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 44, bottom: 6 })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

      if (this.entryId === 'qiuqian') {
        QiuQianPage()
      } else if (this.entryId === 'muyu') {
        MuyuPage()
      } else if (this.entryId === 'fortune') {
        FortuneAlmanacPage()
      } else if (this.entryId === 'wishwall') {
        WishWallPage()
      } else if (this.entryId === 'leaderboard') {
        LeaderboardPage()
      } else if (this.entryId === 'encyclopedia') {
        EncyclopediaPage()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1a1a0a')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
  }
}
