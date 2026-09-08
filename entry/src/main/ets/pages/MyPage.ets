// entry/src/main/ets/pages/MyPage.ets
// 我的：牌运汇总 + 成就徽章 + 界面定制入口 + 功能入口。
// 牌运汇总（GameRecordCard）置顶固定展示，即使「记录牌局」被设为底部 Tab 也不隐藏，
// 两处共用同一 enrichViewModel 数据一致；其开关在界面定制，不入「功能入口」行。
// 功能入口只列出「未开启为底部 Tab」的项（开启后由底部 Tab 直达，此处不再重复展示）；
// 开关与排序统一收敛到界面定制子页（CustomizePage，长按拖拽）。
// 说明：UI v1 下 @StorageLink 不通知 @Observed 嵌套变更，页面把派生数据快照到
// @State，靠 VM bump 的 rev 信号（@Watch）+ onPageShow 重建。
import { PrayerViewModel } from '../viewmodels/PrayerViewModel'
import { EnrichViewModel } from '../viewmodels/EnrichViewModel'
import { EntryConfigVM, EntryItem } from '../viewmodels/EntryConfigVM'
import { GameRecordCard } from '../components/GameRecordCard'
import { AchievementGrid } from '../components/AchievementGrid'
import { PrivacyDialog } from '../components/PrivacyDialog'
import { Achievement } from '../model/EnrichTypes'

@Component
export struct MyPage {
  @StorageLink('viewModel') viewModel: PrayerViewModel = new PrayerViewModel()
  @StorageLink('enrichViewModel') enrichVM: EnrichViewModel = new EnrichViewModel()
  @StorageLink('entryConfigVM') entryConfigVM: EntryConfigVM = new EntryConfigVM()
  @StorageLink('entryConfigRev') @Watch('onConfigRev') entryConfigRev: number = 0
  @State currentSection: string = 'home'
  // —— 派生数据快照 ——
  @State offRows: EntryItem[] = []     // 未开启为 Tab 的入口（按用户 order）
  @State tabCount: number = 0          // 已开启 Tab 数
  private privacyDialogController: CustomDialogController | null = null

  aboutToAppear(): void {
    this.syncAll()
  }

  /** 从 EntryShell/界面定制返回后重新同步（Tab 内容可能被另一页改过） */
  onPageShow(): void {
    this.syncAll()
  }

  onConfigRev(): void {
    this.syncConfig()
  }

  private syncAll(): void {
    this.syncConfig()
  }

  private syncConfig(): void {
    // gamerecord 除外：其入口是置顶固定的 GameRecordCard（开关在界面定制，
    // 开启后由底部 Tab 直达），不重复出现在「功能入口」行
    this.offRows = this.entryConfigVM.getSortedItems()
      .filter((it: EntryItem): boolean => !it.enabled && it.id !== 'gamerecord')
    let n: number = 0
    for (const it of this.entryConfigVM.getSortedItems()) {
      if (it.enabled) {
        n++
      }
    }
    this.tabCount = n
  }

  /** 复阅隐私政策（首次同意后仍可随时查看；只读模式，不提供退出应用） */
  private openPrivacyDialog(): void {
    this.privacyDialogController = new CustomDialogController({
      builder: PrivacyDialog({
        reviewOnly: true
      }),
      autoCancel: false,
      alignment: DialogAlignment.Center,
      customStyle: true
    })
    this.privacyDialogController.open()
  }

  build() {
    Column() {
      // 顶部标题
      Text('我的')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#f9ca24')
        .width('100%')
        .padding({ left: 20, top: 44, bottom: 8 })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

      if (this.currentSection === 'home') {
        Scroll() {
          Column() {
            // 牌运汇总卡片（置顶突出显示，固定不随 Tab 开关消失）。
            // 只显示汇总 + 记一笔；每笔明细在记录牌局页（下方入口跳转，数据同一份）
            GameRecordCard({
              enrichVM: $enrichVM,
              showDetailEntry: true,
              onOpenDetail: (): void => {
                this.getUIContext().getRouter().pushUrl({
                  url: 'pages/EntryShell',
                  params: { entryId: 'gamerecord' }
                })
              }
            })
              .margin({ top: 4, bottom: 12 })

            // 成就入口
            this.MenuItem('🏅', '成就徽章', this.getUnlockedBadgeText(), false, (): void => { this.currentSection = 'achievement' })

            // 界面定制（子页：开关 + 长按拖拽排序）
            this.MenuItem('🏗', '界面定制', `Tab 已开 ${this.tabCount}/3`, false, (): void => {
              this.getUIContext().getRouter().pushUrl({ url: 'pages/CustomizePage' })
            })

            // 功能入口：只列未开启为底部 Tab 的功能（其余已由底部 Tab 直达）
            this.EntryListSection()

            // 隐私政策（最底部小字入口，可随时查看；首次启动时已弹窗同意）
            Text('隐私政策')
              .fontSize(11)
              .fontColor('rgba(249, 202, 36, 0.6)')
              .textAlign(TextAlign.Center)
              .margin({ top: 14, bottom: 8 })
              .onClick((): void => {
                this.openPrivacyDialog()
              })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          // 沉浸式全屏：内容滚到底需避让系统导航条/手势条（≥28vp）
          .padding({ bottom: 28 })
        }
        .layoutWeight(1)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .scrollBar(BarState.Off)
      } else {
        // 子页面头部
        Row() {
          Text('← 返回')
            .fontSize(14)
            .fontColor('#f9ca24')
            .onClick((): void => { this.currentSection = 'home' })
          Blank()
          Text(this.getSectionTitle())
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#f9ca24')
          Blank()
          Text(' ')
            .fontSize(14)
            .width(60)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })

        if (this.currentSection === 'achievement') {
          Scroll() {
            AchievementGrid({ enrichVM: $enrichVM })
          }
          .layoutWeight(1)
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
          .scrollBar(BarState.Off)
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1a1a0a')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
  }

  // ── 功能入口（未开 Tab 项）──
  @Builder
  EntryListSection() {
    Column() {
      Row() {
        Text('🧭 功能入口')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#f9ca24')
        Blank()
        Text('开启为 Tab 的功能不在此重复显示')
          .fontSize(10)
          .fontColor('rgba(253, 246, 227, 0.5)')
      }
      // 15/10sp 混排标题行：底对齐避免基准线错位
      .alignItems(VerticalAlign.Bottom)
      .width('90%')
      .margin({ bottom: 6 })

      ForEach(this.offRows, (item: EntryItem) => {
        this.MenuItem(this.entryConfigVM.getIcon(item.id), this.entryConfigVM.getTitle(item.id), '', item.id === 'muyu', (): void => {
          this.getUIContext().getRouter().pushUrl({ url: 'pages/EntryShell', params: { entryId: item.id } })
        })
      }, (item: EntryItem) => item.id)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  MenuItem(icon: string, label: string, value: string, isMuyu: boolean, onClick: () => void) {
    Row() {
      if (isMuyu) {
        // 木鱼入口：真实木鱼图（emoji 无木鱼字形，🪵 会看成木头）
        Image($rawfile('props/muyu.png'))
          .width(26)
          .height(26)
          .objectFit(ImageFit.Contain)
          .margin({ right: 10 })
      } else {
        Text(icon)
          .fontSize(22)
          .fontColor('#f9ca24')
          .margin({ right: 10 })
      }
      Text(label)
        .fontSize(14)
        .fontColor('#fdf6e3')
      Blank()
      if (value !== '') {
        Text(value)
          .fontSize(12)
          .fontColor('rgba(249, 202, 36, 0.7)')
          .margin({ right: 8 })
      }
      Text('→')
        .fontSize(14)
        .fontColor('rgba(253, 246, 227, 0.5)')
    }
    // 行内图标/图片/文本（22/26/14/12sp 混排）统一底对齐：不同字号底线齐平，
    // 避免 AGC「控件基准线不对齐」（默认 Center 对齐时不同行高底边错开）
    .alignItems(VerticalAlign.Bottom)
    .width('90%')
    .padding(16)
    .backgroundColor('rgba(249, 202, 36, 0.05)')
    .border({ width: 1, color: 'rgba(249, 202, 36, 0.1)', radius: 8 })
    .margin({ bottom: 8 })
    .onClick(onClick)
  }

  private getUnlockedBadgeText(): string {
    const unlockedCount: number = this.enrichVM.achievements.filter((a: Achievement): boolean => a.unlocked).length
    return `${unlockedCount}/8`
  }

  private getSectionTitle(): string {
    if (this.currentSection === 'achievement') {
      return '成就徽章'
    }
    return ''
  }
}
