// entry/src/main/ets/pages/MyPage.ets
import { PrayerViewModel } from '../viewmodels/PrayerViewModel'
import { EnrichViewModel } from '../viewmodels/EnrichViewModel'
import { EntryConfigVM, EntryItem } from '../viewmodels/EntryConfigVM'
import { FortuneViewModel } from '../viewmodels/FortuneViewModel'
import { GameRecordCard } from '../components/GameRecordCard'
import { AchievementGrid } from '../components/AchievementGrid'
import { Achievement } from '../model/EnrichTypes'
import {
  ShengxiaoFortune, PAIYUN_LEVELS, EMPTY_SHENGXIAO_FORTUNE,
  formatDate, starText
} from '../model/FortuneTypes'
import { router } from '@kit.ArkUI'

@Component
export struct MyPage {
  @StorageLink('viewModel') viewModel: PrayerViewModel = new PrayerViewModel()
  @StorageLink('enrichViewModel') enrichVM: EnrichViewModel = new EnrichViewModel()
  @StorageLink('entryConfigVM') entryConfigVM: EntryConfigVM = new EntryConfigVM()
  @StorageLink('fortuneVM') fortuneVM: FortuneViewModel = new FortuneViewModel()
  @State currentSection: string = 'home'

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

            // 界面定制（Tab 开关 + 排序）
            this.CustomizeSection()

            // 我的入口（按用户排序展示全部可配置入口）
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

  // ── 今日运势速览卡 ──
  private todayFortune(): ShengxiaoFortune {
    const f = this.fortuneVM.getShengxiaoFortune(formatDate(new Date()))
    if (f !== null) {
      return f
    }
    return EMPTY_SHENGXIAO_FORTUNE
  }

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

      if (this.fortuneVM.hasShengxiao()) {
        Row() {
          Text(starText(this.todayFortune().stars))
            .fontSize(14)
            .fontColor('#f9ca24')
          Text(`牌运 ${PAIYUN_LEVELS[this.todayFortune().paiyun].level}`)
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(PAIYUN_LEVELS[this.todayFortune().paiyun].color)
            .margin({ left: 12 })
          Blank()
          Text(`幸运数字 ${this.todayFortune().luckyNumbers.join(' · ')}`)
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
      this.getUIContext().getRouter().pushUrl({ url: 'pages/EntryShell', params: { entryId: 'fortune' } }, router.RouterMode.Standard)
    })
  }

  // ── 界面定制 ──
  @Builder
  CustomizeSection() {
    Column() {
      Row() {
        Text('🏗 界面定制')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#f9ca24')
        Blank()
        Text(`已开 ${this.entryConfigVM.tabEnabledCount()}/3 个 Tab`)
          .fontSize(10)
          .fontColor('rgba(253, 246, 227, 0.6)')
      }
      .width('90%')
      .margin({ bottom: 6 })

      ForEach(this.entryConfigVM.getSortedItems(), (item: EntryItem) => {
        this.CustomizeRow(item)
      }, (item: EntryItem) => item.id)

      Text('↑↓ 调整顺序 · 开关控制是否显示为底部 Tab（关闭后仍可从「我的入口」进入）')
        .fontSize(10)
        .fontColor('rgba(253, 246, 227, 0.5)')
        .width('90%')
        .margin({ top: 2, bottom: 12 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  CustomizeRow(item: EntryItem) {
    Row() {
      Text(this.entryConfigVM.getIcon(item.id))
        .fontSize(20)
        .fontColor('#f9ca24')
      Text(this.entryConfigVM.getTitle(item.id))
        .fontSize(14)
        .fontColor('#fdf6e3')
        .margin({ left: 10 })
      Blank()
      Text('↑')
        .fontSize(15)
        .fontColor(this.entryConfigVM.isFirst(item.id) ? 'rgba(253, 246, 227, 0.4)' : '#f9ca24')
        .padding(6)
        .onClick(() => {
          this.entryConfigVM.swap(item.id, -1)
        })
      Text('↓')
        .fontSize(15)
        .fontColor(this.entryConfigVM.isLast(item.id) ? 'rgba(253, 246, 227, 0.4)' : '#f9ca24')
        .padding(6)
        .margin({ left: 4 })
        .onClick(() => {
          this.entryConfigVM.swap(item.id, 1)
        })
      Toggle({ type: ToggleType.Switch, isOn: item.enabled })
        // 已满 3 个 Tab 时禁用未开启行的开关（防第 4 个），已开启行仍可关闭
        .enabled(item.enabled || this.entryConfigVM.tabEnabledCount() < 3)
        .onChange((isOn: boolean) => {
          this.entryConfigVM.setEnabled(item.id, isOn)
        })
        .margin({ left: 8 })
    }
    .width('90%')
    .padding(14)
    .backgroundColor('rgba(249, 202, 36, 0.05)')
    .border({ width: 1, color: 'rgba(249, 202, 36, 0.1)', radius: 8 })
    .margin({ bottom: 8 })
  }

  // ── 我的入口 ──
  @Builder
  EntryListSection() {
    Column() {
      Text('🧭 我的入口')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#f9ca24')
        .width('90%')
        .margin({ bottom: 6 })

      ForEach(this.entryConfigVM.getSortedItems(), (item: EntryItem) => {
        this.MenuItem(this.entryConfigVM.getIcon(item.id), this.entryConfigVM.getTitle(item.id), this.entryConfigVM.isTabOn(item.id) ? 'Tab' : '', (): void => {
          this.getUIContext().getRouter().pushUrl({ url: 'pages/EntryShell', params: { entryId: item.id } }, router.RouterMode.Standard)
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
          .fontColor('rgba(249, 202, 36, 0.6)')
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
