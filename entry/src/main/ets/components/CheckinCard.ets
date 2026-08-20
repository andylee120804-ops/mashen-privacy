import { EnrichViewModel } from '../viewmodels/EnrichViewModel'
import { PrayerViewModel } from '../viewmodels/PrayerViewModel'
import { CHECKIN_TILES } from '../model/EnrichTypes'

@Component
export struct CheckinCard {
  @Link enrichVM: EnrichViewModel
  @State showToast: boolean = false
  @State toastMsg: string = ''

  build() {
    Column() {
      // 签到麻将牌行
      Row() {
        ForEach(CHECKIN_TILES, (tile: string, index: number) => {
          Column() {
            Text(tile)
              .fontSize(24)
              .opacity(index < this.enrichVM.checkin.streak ? 1 : 0.2)
            Text(this.getDayLabel(index))
              .fontSize(9)
              .fontColor(index < this.enrichVM.checkin.streak ? '#f9ca24' : 'rgba(253, 246, 227, 0.2)')
              .margin({ top: 2 })
          }
          .width('13%')
          .alignItems(HorizontalAlign.Center)
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceEvenly)
      .margin({ bottom: 16 })

      // 签到按钮
      Button(this.enrichVM.canCheckin() ? '🔥 今日签到领香火' : '✅ 今日已签到')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.enrichVM.canCheckin() ? '#1a1a0a' : 'rgba(253, 246, 227, 0.4)')
        .backgroundColor(this.enrichVM.canCheckin() ? '#f9ca24' : 'rgba(249, 202, 36, 0.1)')
        .borderRadius(20)
        .padding({ left: 24, right: 24, top: 10, bottom: 10 })
        .enabled(this.enrichVM.canCheckin())
        .onClick(() => {
          const earned = this.enrichVM.doCheckin()
          const bonusMsg = this.enrichVM.checkin.streak === 7 ? '连续7天，香火值×2！' : ''
          this.toastMsg = earned > 0 ? `签到成功！${bonusMsg}获得 ${earned} 香火值` : '今日已签到'
          this.showToast = true
          setTimeout(() => { this.showToast = false }, 2000)
        })

      if (this.showToast) {
        Text(this.toastMsg)
          .fontSize(12)
          .fontColor('#f9ca24')
          .margin({ top: 8 })
          .transition(TransitionEffect.OPACITY.animation({ duration: 300 }))
      }

      // 统计数字
      Row() {
        this.StatItem('总祈福', `${this.getTotalPrayers()}`)
        this.StatItem('磕头', `${this.enrichVM.totalKowtow}`)
        this.StatItem('胜率', `${this.enrichVM.getWinRate().rate}%`)
        this.StatItem('香火值', `${this.enrichVM.checkin.totalIncense}`)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceEvenly)
      .margin({ top: 16 })
    }
    .width('90%')
    .padding(16)
    .backgroundColor('rgba(249, 202, 36, 0.05)')
    .border({ width: 1, color: 'rgba(249, 202, 36, 0.2)', radius: 12 })
  }

  @Builder
  StatItem(label: string, value: string) {
    Column() {
      Text(value)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#f9ca24')
      Text(label)
        .fontSize(10)
        .fontColor('rgba(253, 246, 227, 0.5)')
        .margin({ top: 2 })
    }
    .alignItems(HorizontalAlign.Center)
  }

  private getDayLabel(index: number): string {
    const labels: string[] = ['一', '二', '三', '四', '五', '六', '七']
    const label = labels[index]
    return label ? `第${label}天` : ''
  }

  private getTotalPrayers(): number {
    try {
      const vm: PrayerViewModel = AppStorage.get<PrayerViewModel>('viewModel') as PrayerViewModel
      return vm ? vm.totalPrayers : 0
    } catch {
      return 0
    }
  }
}