import { EnrichViewModel } from '../viewmodels/EnrichViewModel'
import { PrayerViewModel } from '../viewmodels/PrayerViewModel'

@Component
export struct DailyAlmanac {
  @Link enrichVM: EnrichViewModel
  @StorageLink('viewModel') viewModel: PrayerViewModel = new PrayerViewModel()

  build() {
    Column() {
      // 日期行
      Text(`📅 ${this.getLunarDate()} · ${this.getWeekday()}`)
        .fontSize(12)
        .fontColor('rgba(249, 202, 36, 0.6)')
        .margin({ bottom: 8 })

      // 黄历主卡片
      Row() {
        // 宜
        Column() {
          Text('宜 ✅')
            .fontSize(10)
            .fontColor('rgba(46, 204, 113, 0.8)')
            .margin({ bottom: 2 })
          Text(this.enrichVM.getAlmanac().suitable)
            .fontSize(12)
            .fontColor('#fdf6e3')
        }
        .alignItems(HorizontalAlign.Center)
        .width('30%')

        // 中间
        Column() {
          Text(`主神：${this.viewModel.todayDeity.name}`)
            .fontSize(11)
            .fontColor('#f9ca24')
            .margin({ bottom: 4 })
          Text(`吉位：${this.enrichVM.getAlmanac().direction}`)
            .fontSize(10)
            .fontColor('rgba(253, 246, 227, 0.6)')
            .margin({ bottom: 2 })
          Text(`花色：${this.enrichVM.getAlmanac().luckySuit}`)
            .fontSize(10)
            .fontColor('rgba(253, 246, 227, 0.6)')
        }
        .alignItems(HorizontalAlign.Center)
        .width('40%')

        // 忌
        Column() {
          Text('忌 ❌')
            .fontSize(10)
            .fontColor('#f0533f')
            .margin({ bottom: 2 })
          Text(this.enrichVM.getAlmanac().avoid)
            .fontSize(12)
            .fontColor('rgba(253, 246, 227, 0.7)')
        }
        .alignItems(HorizontalAlign.Center)
        .width('30%')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      // 三列高度不同（中列3行、宜/忌列2行），顶部对齐保证"宜/主神/忌"标签在同一基线
      .alignItems(VerticalAlign.Top)

      // 香火指示
      Text(`今日香火：${this.getIncenseBar()}`)
        .fontSize(11)
        .fontColor('rgba(253, 246, 227, 0.5)')
        .margin({ top: 8 })
    }
    .width('90%')
    .padding(12)
    .backgroundColor('rgba(192, 57, 43, 0.08)')
    .border({ width: 1, color: 'rgba(249, 202, 36, 0.2)', radius: 10 })
    .position({ x: '50%', y: 48 }) // 避开沉浸式状态栏（时间/电量区域）
    .translate({ x: '-50%', y: '0' })
  }

  private getIncenseBar(): string {
    const count: number = this.enrichVM.getAlmanac().incenseCount || 0
    const flames: number = Math.min(Math.floor(count / 30) + 1, 5)
    let result: string = ''
    for (let i: number = 0; i < flames; i++) {
      result += '🔥'
    }
    return result
  }

  private getLunarDate(): string {
    const d: Date = new Date()
    const months: string[] = ['正月', '二月', '三月', '四月', '五月', '六月', '七月', '八月', '九月', '十月', '冬月', '腊月']
    const days: string[] = ['初一', '初二', '初三', '初四', '初五', '初六', '初七', '初八', '初九', '初十',
      '十一', '十二', '十三', '十四', '十五', '十六', '十七', '十八', '十九', '二十',
      '廿一', '廿二', '廿三', '廿四', '廿五', '廿六', '廿七', '廿八', '廿九', '三十']
    const m: number = ((d.getMonth() + 11) % 12)
    const day: number = ((d.getDate() + 30) % 30)
    return `${months[m]}${days[day]}`
  }

  private getWeekday(): string {
    const days: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六']
    return days[new Date().getDay()]
  }
}