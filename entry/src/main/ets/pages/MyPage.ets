// entry/src/main/ets/pages/MyPage.ets
import { PrayerViewModel } from '../viewmodels/PrayerViewModel'
import { EnrichViewModel } from '../viewmodels/EnrichViewModel'
import { CheckinCard } from '../components/CheckinCard'
import { DiaryList } from '../components/DiaryList'
import { GameRecordCard } from '../components/GameRecordCard'
import { AchievementGrid } from '../components/AchievementGrid'
import { Achievement } from '../model/EnrichTypes'

@Component
export struct MyPage {
  @StorageLink('viewModel') viewModel: PrayerViewModel = new PrayerViewModel()
  @StorageLink('enrichViewModel') enrichVM: EnrichViewModel = new EnrichViewModel()
  @State currentSection: string = 'home'

  build() {
    Column() {
      // 顶部标题
      Text('我的')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#f9ca24')
        .width('100%')
        .padding({ left: 20, top: 12, bottom: 8 })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

      if (this.currentSection === 'home') {
        Scroll() {
          Column() {
            // 签到卡片
            CheckinCard({ enrichVM: $enrichVM })
              .margin({ top: 12, bottom: 12 })

            // 入口列表
            this.MenuItem('📝 祈福日记', '', (): void => { this.currentSection = 'diary' })
            this.MenuItem('🀇 牌运记录', '', (): void => { this.currentSection = 'game' })
            this.MenuItem('🏅 成就徽章', this.getUnlockedBadgeText(), (): void => { this.currentSection = 'achievement' })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
        }
        .layoutWeight(1)
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

        if (this.currentSection === 'diary') {
          DiaryList({ records: this.viewModel.history, enrichVM: $enrichVM })
        } else if (this.currentSection === 'game') {
          Scroll() {
            GameRecordCard({ enrichVM: $enrichVM })
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        } else if (this.currentSection === 'achievement') {
          Scroll() {
            AchievementGrid({ enrichVM: $enrichVM })
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1a1a0a')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
  }

  @Builder
  MenuItem(label: string, value: string, onClick: () => void) {
    Row() {
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
        .fontColor('rgba(253, 246, 227, 0.3)')
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
    if (this.currentSection === 'diary') {
      return '祈福日记'
    }
    if (this.currentSection === 'game') {
      return '牌运记录'
    }
    if (this.currentSection === 'achievement') {
      return '成就徽章'
    }
    return ''
  }
}
