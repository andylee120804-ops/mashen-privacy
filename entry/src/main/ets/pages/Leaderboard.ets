// entry/src/main/ets/pages/Leaderboard.ets
import { LeaderboardEntry, LeaderboardType } from '../model/EnrichTypes'
import { CloudService } from '../service/CloudService'
import { LeaderboardItem } from '../components/LeaderboardItem'
import { PageBack } from '../components/PageBack'

@Component
export struct LeaderboardPage {
  /** 独立模式（EntryShell 从「我的」进入）：返回键并入大标题行；Tab 模式不带 */
  @Prop standalone: boolean = false
  @State entries: LeaderboardEntry[] = []
  @State currentType: LeaderboardType = LeaderboardType.TOTAL
  @State loading: boolean = false
  @StorageLink('deviceUserId') deviceUserId: string = ''
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
      // 标题（Tab 模式直接展示；独立模式返回键并入同行且标题居中）
      // 全 App Tab 页标题统一：20sp 金色粗体（Tab 左对齐，见黄历/木鱼/求签）
      Row() {
        if (this.standalone) {
          PageBack()
        }
        Text('🏆 祈福排行榜')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#f9ca24')
          .layoutWeight(1)
          .textAlign(this.standalone ? TextAlign.Center : TextAlign.Start)
        if (this.standalone) {
          Text(' ')
            .fontSize(14)
            .width(76)
        }
      }
      .width('100%')
      .padding({ left: this.standalone ? 6 : 20, top: 44, bottom: 8 })
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
        Scroll() {
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
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
        .layoutWeight(1)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .scrollBar(BarState.Off)
      } else if (this.entries.length === 0) {
        Scroll() {
          Column() {
            Text('🏆')
              .fontSize(40)
              .margin({ bottom: 8 })
            Text(this.getEmptyTitle())
              .fontSize(14)
              .fontColor('rgba(253, 246, 227, 0.5)')
            Text(this.getEmptySubtitle())
              .fontSize(14)
              .fontColor('rgba(253, 246, 227, 0.5)')
              .margin({ top: 4 })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
        .layoutWeight(1)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .scrollBar(BarState.Off)
      } else {
        Scroll() {
          Column() {
            ForEach(this.entries, (entry: LeaderboardEntry) => {
              LeaderboardItem({ entry: entry, isMe: entry.userId === this.deviceUserId })
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
                .fontColor('rgba(253, 246, 227, 0.5)')
                .width('90%')
                .margin({ bottom: 4 })

              LeaderboardItem({ entry: this.myEntry, isMe: true })
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
        }
        .layoutWeight(1)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .scrollBar(BarState.Off)
      }

      // 刷新按钮
      Button('↻ 刷新')
        .fontSize(12)
        .fontColor('rgba(249, 202, 36, 0.7)')
        .backgroundColor('transparent')
        .onClick(() => { this.loadData() })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1a1a0a')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
    // 沉浸式全屏下底部内容需避让系统导航条（≥28vp）：根容器下边距留足
    .padding({ bottom: 72 })
  }

  private getEmptyTitle(): string {
    if (this.currentType === LeaderboardType.DAILY) {
      return '今天还没人祈福'
    }
    if (this.currentType === LeaderboardType.WEEKLY) {
      return '本周还没人祈福'
    }
    return '暂无排行数据'
  }

  private getEmptySubtitle(): string {
    if (this.currentType === LeaderboardType.DAILY) {
      return '快去祈福，抢占今日榜首吧！'
    }
    if (this.currentType === LeaderboardType.WEEKLY) {
      return '快去祈福，抢占本周榜首吧！'
    }
    return '快去祈福上榜吧！'
  }

  @Builder
  TabButton(label: string, type: LeaderboardType) {
    Text(label)
      .fontSize(14)
      .fontWeight(this.currentType === type ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.currentType === type ? '#1a1a0a' : 'rgba(253, 246, 227, 0.55)')
      .backgroundColor(this.currentType === type ? '#f9ca24' : 'rgba(249, 202, 36, 0.1)')
      .borderRadius(16)
      .padding({ left: 16, right: 16, top: 6, bottom: 6 })
      .onClick(() => {
        this.currentType = type
        this.loadData()
      })
  }
}
