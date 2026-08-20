// entry/src/main/ets/pages/MainTabs.ets
import { PrayerViewModel } from '../viewmodels/PrayerViewModel'
import { EnrichViewModel } from '../viewmodels/EnrichViewModel'
import { DeityArrayView } from '../components/DeityArrayView'
import { DailyAlmanac } from '../components/DailyAlmanac'
import { PrivacyDialog } from '../components/PrivacyDialog'
import { FIVE_DEITIES } from '../model/PrayerTypes'
import { WishWallPage } from './WishWall'
import { LeaderboardPage } from './Leaderboard'
import { MyPage } from './MyPage'
import { router } from '@kit.ArkUI'

@Entry
@Component
struct MainTabs {
  @StorageLink('viewModel') viewModel: PrayerViewModel = new PrayerViewModel()
  @StorageLink('enrichViewModel') enrichVM: EnrichViewModel = new EnrichViewModel()
  @State currentTab: number = 0
  @State showPrivacyDialog: boolean = false
  private privacyDialogController: CustomDialogController | null = null
  private tabTitles: string[] = ['祈福广场', '心愿墙', '排行榜', '我的']

  aboutToAppear(): void {
    this.checkPrivacyAccepted()
  }

  private async checkPrivacyAccepted(): Promise<void> {
    try {
      const accepted = await this.viewModel.isPrivacyAccepted()
      if (!accepted) {
        this.showPrivacyDialog = true
        this.openPrivacyDialog()
      }
    } catch (err) {
      console.error('[MainTabs] Failed to check privacy:', JSON.stringify(err))
      this.showPrivacyDialog = true
      this.openPrivacyDialog()
    }
  }

  private openPrivacyDialog(): void {
    this.privacyDialogController = new CustomDialogController({
      builder: PrivacyDialog({
        onAgree: () => {
          this.showPrivacyDialog = false
          this.viewModel.acceptPrivacy()
        }
      }),
      autoCancel: false,
      alignment: DialogAlignment.Center,
      customStyle: true
    })
    this.privacyDialogController.open()
  }

  build() {
    Column() {
      Tabs({ index: this.currentTab }) {
        TabContent() {
          this.BlessingSquare()
        }
        .tabBar(this.TabBarBuilder(0, '🪷'))

        TabContent() {
          WishWallPage()
        }
        .tabBar(this.TabBarBuilder(1, '✨'))

        TabContent() {
          LeaderboardPage()
        }
        .tabBar(this.TabBarBuilder(2, '🏆'))

        TabContent() {
          MyPage()
        }
        .tabBar(this.TabBarBuilder(3, '👤'))
      }
      .barHeight(56)
      .barMode(BarMode.Fixed)
      .barBackgroundColor('#1a1a0a')
      .onChange((index: number) => {
        this.currentTab = index
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1a1a0a')
  }

  @Builder
  TabBarBuilder(index: number, icon: string) {
    Column() {
      Text(icon)
        .fontSize(20)
      Text(this.tabTitles[index])
        .fontSize(10)
        .fontColor(this.currentTab === index ? '#f9ca24' : 'rgba(253, 246, 227, 0.4)')
        .margin({ top: 2 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.currentTab === index ? 'rgba(249, 202, 36, 0.08)' : 'transparent')
  }

  @Builder
  BlessingSquare() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#1a1a0a')
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])

      // 黄历卡片
      DailyAlmanac({ enrichVM: $enrichVM })

      // 五神弧形阵
      Column() {
        DeityArrayView({
          deities: FIVE_DEITIES,
          highlightId: this.viewModel.todayDeity.id,
          appearProgress: 1,
          blessingProgress: 0
        })
      }
      .width('100%')
      .height('50%')
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Center)
      .margin({ top: 80 })

      // 副标题
      Text('「心诚则灵，牌来运转」')
        .fontSize(14)
        .fontColor('rgba(249, 202, 36, 0.5)')
        .fontStyle(FontStyle.Italic)
        .position({ x: '50%', y: '67%' })
        .translate({ x: '-50%', y: '-50%' })

      // 主按钮
      Button('🪷 开始祈福')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1a1a0a')
        .backgroundColor('#f9ca24')
        .borderRadius(25)
        .padding({ left: 40, right: 40, top: 14, bottom: 14 })
        .shadow({ radius: 20, color: 'rgba(249, 202, 36, 0.4)', offsetY: 4 })
        .onClick(() => {
          this.viewModel.startPrayer()
          setTimeout(() => {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/NameCard' }, router.RouterMode.Standard)
          }, 0)
        })
        .position({ x: '50%', y: '80%' })
        .translate({ x: '-50%', y: '-50%' })
    }
    .width('100%')
    .height('100%')
  }
}
