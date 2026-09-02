// entry/src/main/ets/pages/MyPage.ets
// 我的：牌运汇总 + 今日运势速览 + 成就徽章 + 界面定制入口 + 功能入口。
// 功能入口只列出「未开启为底部 Tab」的项（开启后由底部 Tab 直达，此处不再重复展示）；
// 开关与排序统一收敛到界面定制子页（CustomizePage，长按拖拽）。
// 说明：UI v1 下 @StorageLink 不通知 @Observed 嵌套变更，页面把派生数据快照到
// @State，靠 VM bump 的 rev 信号（@Watch）+ onPageShow 重建。
import { PrayerViewModel } from '../viewmodels/PrayerViewModel'
import { EnrichViewModel } from '../viewmodels/EnrichViewModel'
import { EntryConfigVM, EntryItem } from '../viewmodels/EntryConfigVM'
import { FortuneViewModel } from '../viewmodels/FortuneViewModel'
import { GameRecordCard } from '../components/GameRecordCard'
import { AchievementGrid } from '../components/AchievementGrid'
import { Achievement } from '../model/EnrichTypes'
import { PAIYUN_LEVELS, formatDate, starText } from '../model/FortuneTypes'

@Component
export struct MyPage {
  @StorageLink('viewModel') viewModel: PrayerViewModel = new PrayerViewModel()
  @StorageLink('enrichViewModel') enrichVM: EnrichViewModel = new EnrichViewModel()
  @StorageLink('entryConfigVM') entryConfigVM: EntryConfigVM = new EntryConfigVM()
  @StorageLink('fortuneVM') fortuneVM: FortuneViewModel = new FortuneViewModel()
  @StorageLink('entryConfigRev') @Watch('onConfigRev') entryConfigRev: number = 0
  @StorageLink('fortuneRev') @Watch('onFortuneRev') fortuneRev: number = 0
  @State currentSection: string = 'home'
  // —— 派生数据快照 ——
  @State offRows: EntryItem[] = []     // 未开启为 Tab 的入口（按用户 order）
  @State tabCount: number = 0          // 已开启 Tab 数
  @State qcHas: boolean = false        // 已设置属相？
  @State qcStars: string = ''
  @State qcLevel: string = ''
  @State qcLevelColor: string = '#f9ca24'
  @State qcLevelText: string = ''
  @State qcNums: string = ''

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

  onFortuneRev(): void {
    this.syncFortune()
  }

  private syncAll(): void {
    this.syncConfig()
    this.syncFortune()
  }

  private syncConfig(): void {
    this.offRows = this.entryConfigVM.getSortedItems()
      .filter((it: EntryItem): boolean => !it.enabled)
    let n: number = 0
    for (const it of this.entryConfigVM.getSortedItems()) {
      if (it.enabled) {
        n++
      }
    }
    this.tabCount = n
  }

  private syncFortune(): void {
    const f = this.fortuneVM.getShengxiaoFortune(formatDate(new Date()))
    this.qcHas = f !== null
    if (f) {
      this.qcStars = starText(f.stars)
      this.qcLevel = PAIYUN_LEVELS[f.paiyun].level
      this.qcLevelColor = PAIYUN_LEVELS[f.paiyun].color
      this.qcLevelText = PAIYUN_LEVELS[f.paiyun].text
      this.qcNums = f.luckyNumbers.join(' · ')
    } else {
      this.qcStars = ''
      this.qcLevel = ''
      this.qcLevelText = ''
      this.qcNums = ''
    }
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
            // 牌运汇总卡片（置顶突出显示）
            GameRecordCard({ enrichVM: $enrichVM })
              .margin({ top: 8, bottom: 12 })

            // 今日运势速览卡
            this.FortuneQuickCard()

            // 成就入口
            this.MenuItem('🏅', '成就徽章', this.getUnlockedBadgeText(), (): void => { this.currentSection = 'achievement' })

            // 界面定制（子页：开关 + 长按拖拽排序）
            this.MenuItem('🏗', '界面定制', `Tab 已开 ${this.tabCount}/3`, (): void => {
              this.getUIContext().getRouter().pushUrl({ url: 'pages/CustomizePage' })
            })

            // 功能入口：只列未开启为底部 Tab 的功能（其余已由底部 Tab 直达）
            this.EntryListSection()
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
        }
        .layoutWeight(1)
        .edgeEffect(EdgeEffect.Spring)
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
          .edgeEffect(EdgeEffect.Spring)
          .scrollBar(BarState.Off)
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1a1a0a')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
  }

  // ── 今日运势速览卡（快照渲染，syncFortune 刷新）──
  @Builder
  FortuneQuickCard() {
    Column() {
      Row() {
        Text('✨ 今日运势')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#f9ca24')
        Blank()
        Text('查看详情 ›')
          .fontSize(11)
          .fontColor('rgba(249, 202, 36, 0.8)')
      }
      .width('100%')
      .margin({ bottom: 8 })

      if (this.qcHas) {
        Row() {
          Text(this.qcStars)
            .fontSize(14)
            .fontColor('#f9ca24')
          Column() {
            Text(`牌运 ${this.qcLevel}`)
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.qcLevelColor)
            Text(this.qcLevelText)
              .fontSize(9)
              .fontColor('rgba(253, 246, 227, 0.5)')
              .margin({ top: 1 })
          }
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 12 })
          Blank()
          Text(`幸运数字 ${this.qcNums}`)
            .fontSize(12)
            .fontColor('rgba(253, 246, 227, 0.7)')
        }
        .width('100%')
      } else {
        Text('设置属相后，解锁今日牌运与幸运数字')
          .fontSize(12)
          .fontColor('rgba(253, 246, 227, 0.6)')
      }
    }
    .width('90%')
    .padding(14)
    .backgroundColor('rgba(249, 202, 36, 0.05)')
    .border({ width: 1, color: 'rgba(249, 202, 36, 0.12)', radius: 10 })
    .margin({ bottom: 12 })
    .onClick(() => {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/EntryShell', params: { entryId: 'fortune' } })
    })
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
          .fontColor('rgba(253, 246, 227, 0.45)')
      }
      .width('90%')
      .margin({ bottom: 6 })

      ForEach(this.offRows, (item: EntryItem) => {
        this.MenuItem(this.entryConfigVM.getIcon(item.id), this.entryConfigVM.getTitle(item.id), '', (): void => {
          this.getUIContext().getRouter().pushUrl({ url: 'pages/EntryShell', params: { entryId: item.id } })
        })
      }, (item: EntryItem) => item.id)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  MenuItem(icon: string, label: string, value: string, onClick: () => void) {
    Row() {
      Text(icon)
        .fontSize(22)
        .fontColor('#f9ca24')
        .margin({ right: 10 })
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
