// entry/src/main/ets/pages/EntryShell.ets
// 统一 @Entry 外壳：从「我的」页进入各可配置入口（未开 Tab 功能）。
// 头部布局由各入口页自行负责（standalone=true 时返回键并入页面 20sp 大标题行，
// 见 FortuneAlmanacPage / QiuQian 等）；本壳只做按 entryId 分发 + 激活入口 id 同步。
// Tab 模式由 MainTabs 直接渲染（standalone=false，不带返回键）。
import { QiuQianPage } from './QiuQian'
import { MuyuPage } from './MuyuPage'
import { FortuneAlmanacPage } from './FortuneAlmanacPage'
import { WishWallPage } from './WishWall'
import { LeaderboardPage } from './Leaderboard'
import { EncyclopediaPage } from './EncyclopediaPage'
import { GameRecordPage } from './GameRecordPage'
import { MahjongTipsPage } from './MahjongTipsPage'
import { BouncePage } from '../components/BouncePage'

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
      if (this.entryId === 'qiuqian') {
        // 固定全屏画布：BouncePage 内容恒超视口 8vp，滑动到边界必有回弹
        BouncePage() {
          QiuQianPage({ standalone: true })
        }
      } else if (this.entryId === 'muyu') {
        BouncePage() {
          MuyuPage({ standalone: true })
        }
      } else if (this.entryId === 'fortune') {
        FortuneAlmanacPage({ standalone: true })
      } else if (this.entryId === 'wishwall') {
        WishWallPage({ standalone: true })
      } else if (this.entryId === 'leaderboard') {
        LeaderboardPage({ standalone: true })
      } else if (this.entryId === 'encyclopedia') {
        EncyclopediaPage({ standalone: true })
      } else if (this.entryId === 'gamerecord') {
        // 记录牌局：汇总 + 每笔明细（数据与「我的」页汇总卡同一份）
        GameRecordPage({ standalone: true })
      } else if (this.entryId === 'tips') {
        MahjongTipsPage({ standalone: true })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1a1a0a')
  }
}
