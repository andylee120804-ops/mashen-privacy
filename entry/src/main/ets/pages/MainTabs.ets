// entry/src/main/ets/pages/MainTabs.ets
import { PrayerViewModel } from '../viewmodels/PrayerViewModel'
import { EnrichViewModel } from '../viewmodels/EnrichViewModel'
import { EntryConfigVM, EntryDef } from '../viewmodels/EntryConfigVM'
import { DeityArrayView } from '../components/DeityArrayView'
import { DailyAlmanac } from '../components/DailyAlmanac'
import { PrivacyDialog } from '../components/PrivacyDialog'
import { MahjongTile } from '../components/MahjongTile'
import { FIVE_DEITIES } from '../model/PrayerTypes'
import { BADGE_DEFS } from '../model/EnrichTypes'
import { WishWallPage } from './WishWall'
import { QiuQianPage } from './QiuQian'
import { MuyuPage } from './MuyuPage'
import { FortuneAlmanacPage } from './FortuneAlmanacPage'
import { ShenDanCalendarPage } from './ShenDanCalendar'
import { LeaderboardPage } from './Leaderboard'
import { EncyclopediaPage } from './EncyclopediaPage'
import { MyPage } from './MyPage'
import { router } from '@kit.ArkUI'

@Entry
@Component
struct MainTabs {
  @StorageLink('viewModel') viewModel: PrayerViewModel = new PrayerViewModel()
  @StorageLink('enrichViewModel') enrichVM: EnrichViewModel = new EnrichViewModel()
  @StorageLink('entryConfigVM') entryConfigVM: EntryConfigVM = new EntryConfigVM()
  @State currentTab: number = 0
  @State showPrivacyDialog: boolean = false
  // 监听成就解锁事件
  @Watch('onAchievementUnlocked') @StorageLink('newlyUnlockedBadgeId') newlyUnlockedBadgeId: string = ''
  private privacyDialogController: CustomDialogController | null = null

  aboutToAppear(): void {
    // 当前激活入口 id 写入 AppStorage，供求签页判断是否激活
    // （摇晃出签只在求签入口激活时响应；Tab 可配置后索引不再固定，必须用 id）
    AppStorage.setOrCreate('activeEntryId', 'blessing')
    this.checkPrivacyAccepted()
  }

  /** 从 EntryShell 返回时 Tab 未变、onChange 不触发，这里重新同步激活入口 id，
   *  避免 EntryShell 写入的 activeEntryId 残留导致摇晃门控误开 */
  onPageShow(): void {
    const tabs = this.getTabs()
    const activeId = this.currentTab >= 0 && this.currentTab < tabs.length ? tabs[this.currentTab].id : 'blessing'
    AppStorage.setOrCreate('activeEntryId', activeId)
  }

  onAchievementUnlocked(): void {
    if (this.newlyUnlockedBadgeId !== '') {
      const badgeId: string = this.newlyUnlockedBadgeId
      this.newlyUnlockedBadgeId = ''
      // 查找徽章信息
      const badge = BADGE_DEFS.find(b => b.badgeId === badgeId)
      if (badge) {
        this.getUIContext().getPromptAction().showToast({
          message: `🏅 成就解锁：${badge.icon} ${badge.name}`,
          duration: 3000
        })
      }
    }
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

  /** 完整 Tab 列表：祈福（固定头）+ 已启用入口（按用户 order）+ 我的（固定尾） */
  private getTabs(): EntryDef[] {
    const tabs: EntryDef[] = [{ id: 'blessing', icon: '🀄', title: '祈福' }]
    const enabled = this.entryConfigVM.getTabEntries()
    for (const e of enabled) {
      tabs.push(e)
    }
    tabs.push({ id: 'mine', icon: '🧧', title: '我的' })
    return tabs
  }

  private tabIndexOf(id: string): number {
    const tabs = this.getTabs()
    for (let i = 0; i < tabs.length; i++) {
      if (tabs[i].id === id) {
        return i
      }
    }
    return 0
  }

  build() {
    Column() {
      Tabs({ index: this.currentTab }) {
        TabContent() {
          // 祈福页为固定全屏布局：包一层垂直 Scroll，让上下滑动到边界有
          // Spring 回弹反馈（AGC「滑动动效」标准：滑动到边界必须有反馈动效）
          Scroll() {
            this.BlessingSquare()
          }
          .width('100%')
          .height('100%')
          .scrollable(ScrollDirection.Vertical)
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
          .scrollBar(BarState.Off)
        }
        .tabBar(this.TabBarBuilder(0, '🀄', '祈福'))

        // 中间可配置 Tab（由「我的」页界面定制控制开关与排序）
        ForEach(this.entryConfigVM.getTabEntries(), (entry: EntryDef) => {
          TabContent() {
            this.EntryContent(entry.id)
          }
          .tabBar(this.TabBarBuilder(this.tabIndexOf(entry.id), entry.icon, entry.title))
        }, (entry: EntryDef) => entry.id)

        TabContent() {
          MyPage()
        }
        .tabBar(this.TabBarBuilder(this.tabIndexOf('mine'), '🧧', '我的'))
      }
      // 底部导航栏：Tabs 默认 BarPosition.Start 渲染在顶部，沉浸式下易与状态栏重叠
      // 导致点击不响应；显式指定 End 让 Tab 栏落在底部可点击安全区。
      .barPosition(BarPosition.End)
      // barHeight 含底部手势导航条高度，配合 TabBarBuilder 内 padding({bottom}) 把
      // 图标/文字顶到安全区上方，避免与手势条重叠、显得"太贴底"。
      .barHeight(72)
      .barMode(BarMode.Fixed)
      .barBackgroundColor('#1a1a0a')
      // 滑到首尾 Tab 边界时回弹，满足 AGC「滑动到边界有反馈动效」质量标准
      .edgeEffect(EdgeEffect.Spring)
      .onChange((index: number) => {
        this.currentTab = index
        const tabs = this.getTabs()
        const activeId = index >= 0 && index < tabs.length ? tabs[index].id : 'blessing'
        AppStorage.setOrCreate('activeEntryId', activeId)
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1a1a0a')
  }

  /** 可配置入口的 Tab 内容（按入口 id 分发） */
  @Builder
  EntryContent(id: string) {
    if (id === 'qiuqian') {
      // 求签页同为固定全屏布局：包一层垂直 Scroll，保证上下边界有回弹反馈
      Scroll() {
        QiuQianPage()
      }
      .width('100%')
      .height('100%')
      .scrollable(ScrollDirection.Vertical)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .scrollBar(BarState.Off)
    } else if (id === 'muyu') {
      MuyuPage()
    } else if (id === 'fortune') {
      FortuneAlmanacPage()
    } else if (id === 'wishwall') {
      WishWallPage()
    } else if (id === 'calendar') {
      ShenDanCalendarPage()
    } else if (id === 'leaderboard') {
      LeaderboardPage()
    } else if (id === 'encyclopedia') {
      EncyclopediaPage()
    }
  }

  @Builder
  TabBarBuilder(index: number, icon: string, title: string) {
    Column() {
      Text(icon)
        .fontSize(22)
        .fontColor('#f9ca24')
      Text(title)
        .fontSize(10)
        .fontColor(this.currentTab === index ? '#f9ca24' : 'rgba(253, 246, 227, 0.5)')
        .margin({ top: 3 })
    }
    .width('100%')
    .height('100%')
    .padding({ top: 6, bottom: 18 }) // bottom 留出手势导航条空间，图标上移到可点击安全区
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
        .fontColor('rgba(249, 202, 36, 0.6)')
        .fontStyle(FontStyle.Italic)
        .position({ x: '50%', y: '73%' })
        .translate({ x: '-50%', y: '-50%' })

      // 主按钮
      Row() {
        MahjongTile({ icon: '🀅', tileSize: 28 })
        Text('开始祈福')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1a1a0a')
          .margin({ left: 10 })
      }
      .justifyContent(FlexAlign.Center)
      .padding({ left: 20, right: 36, top: 10, bottom: 10 })
      .backgroundColor('#f9ca24')
      .borderRadius(25)
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
