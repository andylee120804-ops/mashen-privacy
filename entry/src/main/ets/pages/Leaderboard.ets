// entry/src/main/ets/pages/Leaderboard.ets
import { LeaderboardEntry, LeaderboardType } from '../model/EnrichTypes'
import { CloudService } from '../service/CloudService'
import { LeaderboardItem } from '../components/LeaderboardItem'

@Component
export struct LeaderboardPage {
  @State entries: LeaderboardEntry[] = []
  @State currentType: LeaderboardType = LeaderboardType.DAILY
  @State loading: boolean = false
  @State myEntry: LeaderboardEntry = { userId: '', nickname: '', count: 0, kowtow: 0, rank: 0 }
  @State hasMyEntry: boolean = false

  aboutToAppear(): void {
    this.loadData()
  }

  async loadData(): Promise<void> {
    this.loading = true
    try {
      const data: LeaderboardEntry[] = await CloudService.getLeaderboard(this.currentType)
      this.entries = data.filter((e: LeaderboardEntry): boolean => e.rank > 0)
      const me: LeaderboardEntry | undefined = data.find((e: LeaderboardEntry): boolean => e.rank === 0)
      if (me) {
        this.myEntry = me
        this.hasMyEntry = true
      } else {
        this.hasMyEntry = false
      }
    } catch (err) {
      console.error('[Leaderboard] load failed:', JSON.stringify(err))
    } finally {
      this.loading = false
    }
  }

  build() {
    Column() {
      // 标题
      Text('🏆 祈福排行榜')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#f9ca24')
        .width('100%')
        .padding({ left: 20, top: 12, bottom: 8 })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

      // 榜单切换
      Row() {
        this.TabButton('日榜', LeaderboardType.DAILY)
        this.TabButton('周榜', LeaderboardType.WEEKLY)
        this.TabButton('总榜', LeaderboardType.TOTAL)
      }
      .width('90%')
      .justifyContent(FlexAlign.SpaceEvenly)
      .margin({ bottom: 12 })

      if (this.loading) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
            .color('#f9ca24')
          Text('加载中...')
            .fontSize(12)
            .fontColor('rgba(253, 246, 227, 0.5)')
            .margin({ top: 8 })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.entries.length === 0) {
        Column() {
          Text('🏆')
            .fontSize(40)
            .margin({ bottom: 8 })
          Text('暂无排行数据')
            .fontSize(14)
            .fontColor('rgba(253, 246, 227, 0.5)')
          Text('快去祈福上榜吧！')
            .fontSize(14)
            .fontColor('rgba(253, 246, 227, 0.5)')
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            ForEach(this.entries, (entry: LeaderboardEntry) => {
              LeaderboardItem({ entry: entry, isMe: false })
            })

            // 我的排名（不在前 50 时单独展示）
            if (this.hasMyEntry) {
              Row()
                .width('100%')
                .height(1)
                .backgroundColor('rgba(249, 202, 36, 0.2)')
                .margin({ top: 8, bottom: 8 })

              Text('我的排名')
                .fontSize(11)
                .fontColor('rgba(253, 246, 227, 0.4)')
                .width('90%')
                .margin({ bottom: 4 })

              LeaderboardItem({ entry: this.myEntry, isMe: true })
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }

      // 刷新按钮
      Button('🔄 刷新')
        .fontSize(12)
        .fontColor('rgba(249, 202, 36, 0.6)')
        .backgroundColor('transparent')
        .margin({ bottom: 12 })
        .onClick(() => { this.loadData() })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1a1a0a')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
  }

  @Builder
  TabButton(label: string, type: LeaderboardType) {
    Text(label)
      .fontSize(14)
      .fontWeight(this.currentType === type ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.currentType === type ? '#1a1a0a' : 'rgba(253, 246, 227, 0.5)')
      .backgroundColor(this.currentType === type ? '#f9ca24' : 'rgba(249, 202, 36, 0.1)')
      .borderRadius(16)
      .padding({ left: 16, right: 16, top: 6, bottom: 6 })
      .onClick(() => {
        this.currentType = type
        this.loadData()
      })
  }
}
