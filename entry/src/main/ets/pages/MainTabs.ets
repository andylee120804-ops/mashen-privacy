// entry/src/main/ets/pages/MainTabs.ets
import { PrayerViewModel } from '../viewmodels/PrayerViewModel'
import { EnrichViewModel } from '../viewmodels/EnrichViewModel'
import { EntryConfigVM, EntryDef } from '../viewmodels/EntryConfigVM'
import { DeityArrayView } from '../components/DeityArrayView'
import { DailyAlmanac } from '../components/DailyAlmanac'
import { PrivacyDialog } from '../components/PrivacyDialog'
import { MahjongTile } from '../components/MahjongTile'
import { BouncePage } from '../components/BouncePage'
import { FIVE_DEITIES } from '../model/PrayerTypes'
import { BADGE_DEFS } from '../model/EnrichTypes'
import { WishWallPage } from './WishWall'
import { QiuQianPage } from './QiuQian'
import { MuyuPage } from './MuyuPage'
import { FortuneAlmanacPage } from './FortuneAlmanacPage'
import { LeaderboardPage } from './Leaderboard'
import { EncyclopediaPage } from './EncyclopediaPage'
import { GameRecordPage } from './GameRecordPage'
import { MahjongTipsPage } from './MahjongTipsPage'
import { MyPage } from './MyPage'
import { router } from '@kit.ArkUI'

@Entry
@Component
struct MainTabs {
  @StorageLink('viewModel') viewModel: PrayerViewModel = new PrayerViewModel()
  @StorageLink('enrichViewModel') enrichVM: EnrichViewModel = new EnrichViewModel()
  @StorageLink('entryConfigVM') entryConfigVM: EntryConfigVM = new EntryConfigVM()
  // UI v1：@StorageLink 只观察顶层键，@Observed VM 嵌套变更不通知 UI。
  // VM 每次变更 bump entryConfigRev，这里 @Watch 后重建 tabDefs（@State）驱动刷新。
  @StorageLink('entryConfigRev') @Watch('onEntryConfigRev') entryConfigRev: number = 0
  @State tabDefs: EntryDef[] = []
  @State currentTab: number = 0
  @State showPrivacyDialog: boolean = false
  // 监听成就解锁事件
  @Watch('onAchievementUnlocked') @StorageLink('newlyUnlockedBadgeId') newlyUnlockedBadgeId: string = ''
  private privacyDialogController: CustomDialogController | null = null

  aboutToAppear(): void {
    this.syncTabs()
    // 当前激活入口 id 写入 AppStorage，供求签页判断是否激活
    // （摇晃出签只在求签入口激活时响应；Tab 可配置后索引不再固定，必须用 id）
    AppStorage.setOrCreate('activeEntryId', 'blessing')
    this.checkPrivacyAccepted()
  }

  /** VM 变更通知（AppStorage rev 信号）：重建 Tab 列表并校正当前索引 */
  onEntryConfigRev(): void {
    this.syncTabs()
  }

  /** 完整 Tab 列表：祈福（固定头）+ 已启用入口（按用户 order）+ 我的（固定尾） */
  private buildTabs(): EntryDef[] {
    const tabs: EntryDef[] = [{ id: 'blessing', icon: '🀄', title: '祈福' }]
    const enabled = this.entryConfigVM.getTabEntries()
    for (const e of enabled) {
      tabs.push(e)
    }
    tabs.push({ id: 'mine', icon: '🧧', title: '我的' })
    return tabs
  }

  /** 重建 tabDefs（@State 快照，UI 可靠刷新）并把 currentTab 收敛到有效范围 */
  private syncTabs(): void {
    const tabs = this.buildTabs()
    this.tabDefs = tabs
    if (this.currentTab >= tabs.length) {
      // 开启项被关闭导致尾部索引失效时收敛（「我的」固定在最后，正常总会落到它）
      this.currentTab = Math.max(0, tabs.length - 1)
    }
  }

  /** 从 EntryShell 返回时 Tab 未变、onChange 不触发，这里重新同步激活入口 id，
   *  避免 EntryShell 写入的 activeEntryId 残留导致摇晃门控误开 */
  onPageShow(): void {
    const activeId = this.activeIdOf(this.currentTab)
    AppStorage.setOrCreate('activeEntryId', activeId)
  }

  private activeIdOf(tabIndex: number): string {
    if (tabIndex >= 0 && tabIndex < this.tabDefs.length) {
      return this.tabDefs[tabIndex].id
    }
    return 'blessing'
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

  build() {
    Column() {
      Tabs({ index: this.currentTab }) {
        // 全部 Tab 由 tabDefs 统一驱动（祈福/我的固定项也在列表内，按 id 分支内容）
        ForEach(this.tabDefs, (def: EntryDef, idx: number) => {
          TabContent() {
            if (def.id === 'blessing') {
              // 祈福页为固定全屏布局：BouncePage 内容恒比视口高 8vp（实测视口+8），
              // 滚动区间 >0，上下滑动到边界必有 Spring 回弹（AGC「滑动动效」标准）
              BouncePage() {
                this.BlessingSquare()
              }
            } else if (def.id === 'mine') {
              MyPage()
            } else {
              // 中间可配置 Tab（由「界面定制」子页控制开关与排序）
              this.EntryContent(def.id)
            }
          }
          .tabBar(this.TabBarBuilder(idx, def))
        }, (def: EntryDef) => def.id)
      }
      // 底部导航栏：Tabs 默认 BarPosition.Start 渲染在顶部，沉浸式下易与状态栏重叠
      // 导致点击不响应；显式指定 End 让 Tab 栏落在底部可点击安全区。
      .barPosition(BarPosition.End)
      // barHeight 含底部手势导航条高度，配合 TabBarBuilder 内 padding({bottom}) 把
      // 图标/文字顶到安全区上方（下缘距屏底 ≥28vp），避免与手势条/三键导航重叠。
      .barHeight(84)
      .barMode(BarMode.Fixed)
      .barBackgroundColor('#1a1a0a')
      // 滑到首尾 Tab 边界时回弹，满足 AGC「滑动到边界有反馈动效」质量标准
      .edgeEffect(EdgeEffect.Spring)
      .onChange((index: number) => {
        this.currentTab = index
        const activeId = this.activeIdOf(index)
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
      // 求签页同为固定全屏布局：BouncePage 内容恒超视口 8vp，上下边界有回弹
      BouncePage() {
        QiuQianPage()
      }
    } else if (id === 'muyu') {
      // 木鱼页固定全屏：同上，BouncePage 保证滑动到边界有回弹反馈
      BouncePage() {
        MuyuPage()
      }
    } else if (id === 'fortune') {
      FortuneAlmanacPage()
    } else if (id === 'wishwall') {
      WishWallPage()
    } else if (id === 'leaderboard') {
      LeaderboardPage()
    } else if (id === 'encyclopedia') {
      EncyclopediaPage()
    } else if (id === 'gamerecord') {
      // 记录牌局：与「我的」页置顶卡片共用同一份数据（同 enrichViewModel）
      GameRecordPage()
    } else if (id === 'tips') {
      MahjongTipsPage()
    }
  }

  @Builder
  TabBarBuilder(index: number, def: EntryDef) {
    Column() {
      if (def.id === 'muyu') {
        // 木鱼入口：真实木鱼图（emoji 无木鱼字形，🪵 会看成木头）
        Image($rawfile('props/muyu.png'))
          .width(24)
          .height(24)
          .objectFit(ImageFit.Contain)
      } else {
        Text(def.icon)
          .fontSize(22)
          .fontColor('#f9ca24')
      }
      Text(def.title)
        .fontSize(10)
        .fontColor(this.currentTab === index ? '#f9ca24' : 'rgba(253, 246, 227, 0.5)')
        .margin({ top: 3 })
    }
    .width('100%')
    .height('100%')
    .padding({ top: 8, bottom: 32 }) // bottom 留出手势导航条空间，图标/文字下缘距屏底 ≥28vp
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
