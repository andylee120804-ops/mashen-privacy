// entry/src/main/ets/pages/ShenDanCalendar.ets
// 财神历·神诞：静态神诞日历浏览 + 收藏（收藏项排前，本地持久化）。
// 不做系统提醒与倒计时（见设计文档「非目标」）。
import { FortuneViewModel } from '../viewmodels/FortuneViewModel'
import { ShendanEntry, SHENDAN_LIST } from '../model/FortuneTypes'

@Component
export struct ShenDanCalendarPage {
  @StorageLink('fortuneVM') fortuneVM: FortuneViewModel = new FortuneViewModel()

  build() {
    Column() {
      // 标题
      Text('📅 财神历 · 神诞')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#f9ca24')
        .width('100%')
        .padding({ left: 20, top: 44, bottom: 8 })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

      Scroll() {
        Column() {
          Text('记住财神圣诞，逢诞祈福更灵验')
            .fontSize(11)
            .fontColor('rgba(253, 246, 227, 0.5)')
            .margin({ bottom: 10 })

          ForEach(this.getSortedShendan(), (s: ShendanEntry) => {
            this.ShendanCard(s)
          }, (s: ShendanEntry) => s.id)
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 16 })
      }
      .layoutWeight(1)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1a1a0a')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
  }

  /** 收藏项排前，其余按定义顺序 */
  private getSortedShendan(): ShendanEntry[] {
    const favs = this.fortuneVM.shendanFavorites
    const fav = SHENDAN_LIST.filter((s: ShendanEntry): boolean => favs.includes(s.id))
    const rest = SHENDAN_LIST.filter((s: ShendanEntry): boolean => !favs.includes(s.id))
    return [...fav, ...rest]
  }

  private isFav(id: string): boolean {
    return this.fortuneVM.shendanFavorites.includes(id)
  }

  @Builder
  ShendanCard(s: ShendanEntry) {
    Row() {
      Text(s.icon)
        .fontSize(28)
        .width(44)
        .textAlign(TextAlign.Center)

      Column() {
        Row() {
          Text(s.name)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#fdf6e3')
          Text(s.lunarDate)
            .fontSize(10)
            .fontColor('rgba(249, 202, 36, 0.8)')
            .margin({ left: 8 })
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .border({ width: 1, color: 'rgba(249, 202, 36, 0.3)', radius: 8 })
        }

        Text(s.desc)
          .fontSize(12)
          .fontColor('rgba(253, 246, 227, 0.6)')
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 10 })

      Text(this.isFav(s.id) ? '★ 已收藏' : '☆ 收藏')
        .fontSize(12)
        .fontColor('#f9ca24')
        .onClick(() => {
          this.fortuneVM.toggleShendanFavorite(s.id)
        })
    }
    .width('100%')
    .padding(14)
    .backgroundColor('rgba(249, 202, 36, 0.05)')
    .border({ width: 1, color: 'rgba(249, 202, 36, 0.12)', radius: 10 })
    .margin({ bottom: 10 })
  }
}
