// entry/src/main/ets/pages/EncyclopediaPage.ets
// 财神百科：五路财神详档 + 祈福文化栏目。从「我的」页导航进入。
// 详情用页面内覆层实现（点遮罩或「收下」确定性关闭），避免 CustomDialog 控制器绑定问题。
import { DeityEntry, CultureArticle, DEITY_ENCYCLOPEDIA, CULTURE_ARTICLES } from '../model/CultureContent'
import { MahjongTile } from '../components/MahjongTile'
import { PageBack } from '../components/PageBack'

@Component
export struct EncyclopediaPage {
  /** 独立模式（EntryShell 从「我的」进入）：返回键并入大标题行；Tab 模式不带 */
  @Prop standalone: boolean = false
  @State currentSection: string = 'deities'
  @State showDeityDetail: boolean = false
  @State selectedDeity: DeityEntry = DEITY_ENCYCLOPEDIA[0]
  @State showArticleDetail: boolean = false
  @State selectedArticle: CultureArticle = CULTURE_ARTICLES[0]

  build() {
    Stack() {
      Column() {
        // 标题（Tab 模式直接展示；独立模式返回键并入同行且标题居中）
        // 全 App Tab 页标题统一：20sp 金色粗体（Tab 左对齐，见黄历/木鱼/求签）
        Row() {
          if (this.standalone) {
            PageBack()
          }
          Text('📜 财神百科')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#f9ca24')
            .layoutWeight(1)
            .textAlign(this.standalone ? TextAlign.Center : TextAlign.Start)
          if (this.standalone) {
            Text(' ')
              .fontSize(14)
              .width(76)
          }
        }
        .width('100%')
        .padding({ left: this.standalone ? 6 : 20, top: 44, bottom: 8 })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

        // 分区切换
        Row() {
          this.SectionTab('deities', '五路财神')
          this.SectionTab('culture', '祈福文化')
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 8 })

        if (this.currentSection === 'deities') {
          Scroll() {
            Column() {
              Text('拜对财神，财运亨通——认识五路财神的来历与讲究')
                .fontSize(11)
                .fontColor('rgba(253, 246, 227, 0.5)')
                .margin({ bottom: 10 })
              ForEach(DEITY_ENCYCLOPEDIA, (deity: DeityEntry) => {
                this.DeityCard(deity)
              }, (deity: DeityEntry) => deity.id.toString())
            }
            .width('100%')
            .padding({ left: 16, right: 16, bottom: 28 })
          }
          .layoutWeight(1)
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
          .scrollBar(BarState.Off)
        } else {
          Scroll() {
            Column() {
              Text('祈福有讲究，心诚则灵——传统习俗与礼仪')
                .fontSize(11)
                .fontColor('rgba(253, 246, 227, 0.5)')
                .margin({ bottom: 10 })
              ForEach(CULTURE_ARTICLES, (article: CultureArticle) => {
                this.ArticleCard(article)
              }, (article: CultureArticle) => article.id)
            }
            .width('100%')
            .padding({ left: 16, right: 16, bottom: 28 })
          }
          .layoutWeight(1)
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
          .scrollBar(BarState.Off)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#1a1a0a')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])

      // 详情覆层
      if (this.showDeityDetail) {
        this.DeityDetailOverlay()
      }
      if (this.showArticleDetail) {
        this.ArticleDetailOverlay()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  SectionTab(key: string, label: string) {
    Text(label)
      .fontSize(14)
      .fontWeight(this.currentSection === key ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.currentSection === key ? '#f9ca24' : 'rgba(253, 246, 227, 0.5)')
      .padding({ left: 16, right: 16, top: 6, bottom: 6 })
      .backgroundColor(this.currentSection === key ? 'rgba(249, 202, 36, 0.12)' : 'transparent')
      .borderRadius(16)
      .onClick((): void => { this.currentSection = key })
  }

  @Builder
  DeityCard(deity: DeityEntry) {
    Row() {
      MahjongTile({ icon: deity.icon, tileSize: 44 })
      Column() {
        Row() {
          Text(deity.name)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#fdf6e3')
          Text(deity.direction)
            .fontSize(10)
            .fontColor('rgba(249, 202, 36, 0.7)')
            .margin({ left: 8 })
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .border({ width: 1, color: 'rgba(249, 202, 36, 0.3)', radius: 8 })
        }
        Text(deity.title)
          .fontSize(12)
          .fontColor('rgba(249, 202, 36, 0.8)')
          .margin({ top: 3 })
        Text(deity.domain)
          .fontSize(11)
          .fontColor('rgba(253, 246, 227, 0.6)')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 10 })

      Text('详情 ›')
        .fontSize(12)
        .fontColor('#f9ca24')
    }
    .width('100%')
    .padding(14)
    .backgroundColor('rgba(249, 202, 36, 0.05)')
    .border({ width: 1, color: 'rgba(249, 202, 36, 0.12)', radius: 10 })
    .margin({ bottom: 10 })
    .onClick((): void => {
      this.selectedDeity = deity
      this.showDeityDetail = true
    })
  }

  @Builder
  ArticleCard(article: CultureArticle) {
    Row() {
      Text(article.icon)
        .fontSize(24)
        .width(40)
        .textAlign(TextAlign.Center)
      Text(article.title)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#fdf6e3')
        .layoutWeight(1)
        .margin({ left: 10 })
      Text('阅读 ›')
        .fontSize(12)
        .fontColor('#f9ca24')
    }
    .width('100%')
    .padding(14)
    .backgroundColor('rgba(249, 202, 36, 0.05)')
    .border({ width: 1, color: 'rgba(249, 202, 36, 0.12)', radius: 10 })
    .margin({ bottom: 10 })
    .onClick((): void => {
      this.selectedArticle = article
      this.showArticleDetail = true
    })
  }

  /** 财神详情覆层 */
  @Builder
  DeityDetailOverlay() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.65)')
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
        .onClick((): void => { this.showDeityDetail = false })

      Column() {
        Row() {
          MahjongTile({ icon: this.selectedDeity.icon, tileSize: 54 })
          Text(`${this.selectedDeity.name} · ${this.selectedDeity.title}`)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#f9ca24')
            .margin({ left: 10 })
        }
        .width('100%')

        Scroll() {
          Column() {
            Text('来历传说')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor('rgba(249, 202, 36, 0.8)')
              .width('100%')
              .margin({ top: 14, bottom: 6 })
            Text(this.selectedDeity.story)
              .fontSize(13)
              .fontColor('rgba(253, 246, 227, 0.85)')
              .lineHeight(21)

            Text('掌管领域')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor('rgba(249, 202, 36, 0.8)')
              .width('100%')
              .margin({ top: 14, bottom: 6 })
            Text(this.selectedDeity.domain)
              .fontSize(13)
              .fontColor('rgba(253, 246, 227, 0.85)')
              .lineHeight(21)

            Text('祭拜要点')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor('rgba(249, 202, 36, 0.8)')
              .width('100%')
              .margin({ top: 14, bottom: 6 })
            Text(this.selectedDeity.worship)
              .fontSize(13)
              .fontColor('rgba(253, 246, 227, 0.85)')
              .lineHeight(21)

            Text(`对应花色：${this.selectedDeity.tile} · 方位：${this.selectedDeity.direction}`)
              .fontSize(12)
              .fontColor('rgba(249, 202, 36, 0.7)')
              .width('100%')
              .margin({ top: 14 })
          }
          .width('100%')
        }
        .height(420)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .scrollBar(BarState.Off)

        Button('收下')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1a1a0a')
          .backgroundColor('#f9ca24')
          .borderRadius(18)
          .width('100%')
          .margin({ top: 18 })
          .onClick((): void => { this.showDeityDetail = false })
      }
      .width('84%')
      .padding(22)
      .backgroundColor('#241f12')
      .border({ width: 1, color: 'rgba(249, 202, 36, 0.35)', radius: 16 })
      .shadow({ radius: 30, color: 'rgba(0, 0, 0, 0.5)', offsetY: 8 })
    }
    .width('100%')
    .height('100%')
  }

  /** 文化文章详情覆层 */
  @Builder
  ArticleDetailOverlay() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.65)')
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
        .onClick((): void => { this.showArticleDetail = false })

      Column() {
        Row() {
          Text(this.selectedArticle.icon)
            .fontSize(30)
          Text(this.selectedArticle.title)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#f9ca24')
            .margin({ left: 10 })
        }
        .width('100%')

        Scroll() {
          Text(this.selectedArticle.content)
            .fontSize(13)
            .fontColor('rgba(253, 246, 227, 0.85)')
            .lineHeight(23)
            .width('100%')
            .margin({ top: 16 })
        }
        .height(320)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .scrollBar(BarState.Off)

        Button('收下')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1a1a0a')
          .backgroundColor('#f9ca24')
          .borderRadius(18)
          .width('100%')
          .margin({ top: 18 })
          .onClick((): void => { this.showArticleDetail = false })
      }
      .width('84%')
      .padding(22)
      .backgroundColor('#241f12')
      .border({ width: 1, color: 'rgba(249, 202, 36, 0.35)', radius: 16 })
      .shadow({ radius: 30, color: 'rgba(0, 0, 0, 0.5)', offsetY: 8 })
    }
    .width('100%')
    .height('100%')
  }
}
