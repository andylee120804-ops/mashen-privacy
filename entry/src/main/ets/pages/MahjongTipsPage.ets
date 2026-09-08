// entry/src/main/ets/pages/MahjongTipsPage.ets
// 麻将技巧：通用打法知识/教程（入门认知/打法技巧/防守与听牌/口诀与心态）。
// 从「我的」功能入口或底部 Tab（界面定制）进入，同财神百科的百科式阅读：
// 分区段内切换 → 文章卡片 → 详情覆层（遮罩点击/「收下」确定性关闭）。
import { TipsSection, TipsArticle, TipBlock, TIPS_SECTIONS, QuizQuestion, QUIZ_QUESTIONS } from '../model/MahjongTipsContent'
import { PageBack } from '../components/PageBack'

/** 选项前缀（金色序号，对错揭示时改绿/红，见 OptionRow） */
const OPTION_MARKS: string[] = ['①', '②', '③', '④']

@Component
export struct MahjongTipsPage {
  /** 独立模式（EntryShell 从「我的」进入）：返回键并入大标题行；Tab 模式不带 */
  @Prop standalone: boolean = false
  @State currentSectionId: string = TIPS_SECTIONS[0].id
  @State showDetail: boolean = false
  @State selectedArticle: TipsArticle = TIPS_SECTIONS[0].articles[0]
  // —— 实战小测状态（不做持久化，重进即重置）——
  @State quizOpen: boolean = false
  @State qIndex: number = 0
  @State qPicked: number = -1   // -1 = 未作答
  @State qCorrect: number = 0
  @State qOrder: number[] = []  // 本局题目顺序（洗牌后的下标序列，每次开始重排）

  build() {
    Stack() {
      Column() {
        // 标题（Tab 模式直接展示；独立模式返回键并入同行且标题居中）
        Row() {
          if (this.standalone) {
            PageBack()
          }
          Text('💡 麻将技巧')
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

        // 分区切换：四个分区各占 1/4 弹性单元（内容宽度各异，按内容排会溢出 360vp 窄屏）
        Row() {
          ForEach(TIPS_SECTIONS, (section: TipsSection) => {
            this.SectionTab(section)
          }, (section: TipsSection) => section.id)
        }
        .width('100%')
        .padding({ left: 8, right: 8, bottom: 8 })

        // 实战小测入口卡：固定于分区 Tab 之下，任意分区都可进入练习
        Row() {
          Row() {
            Text('📝')
              .fontSize(16)
              .margin({ right: 8 })
            Text('实战小测')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('#f9ca24')
            Blank()
            Text(`检验成果 · ${QUIZ_QUESTIONS.length} 题 ›`)
              .fontSize(11)
              .fontColor('rgba(253, 246, 227, 0.5)')
          }
          // 15/11sp 混排标题行：底对齐
          .alignItems(VerticalAlign.Bottom)
          .width('100%')
          .padding(12)
          .backgroundColor('rgba(249, 202, 36, 0.05)')
          .border({ width: 1, color: 'rgba(249, 202, 36, 0.12)', radius: 10 })
          .onClick((): void => { this.openQuiz() })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 2, bottom: 8 })

        // 当前分区文章列表
        Scroll() {
          Column() {
            Text(this.currentSection().subtitle)
              .fontSize(11)
              .fontColor('rgba(253, 246, 227, 0.5)')
              .margin({ bottom: 10 })
            ForEach(this.currentSection().articles, (article: TipsArticle) => {
              this.ArticleCard(article)
            }, (article: TipsArticle) => article.id)
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 28 })
        }
        .layoutWeight(1)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#1a1a0a')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])

      // 详情覆层
      if (this.showDetail) {
        this.DetailOverlay()
      }
      // 实战小测覆层
      if (this.quizOpen) {
        this.QuizOverlay()
      }
    }
    .width('100%')
    .height('100%')
  }

  private currentSection(): TipsSection {
    const found = TIPS_SECTIONS.find((s: TipsSection): boolean => s.id === this.currentSectionId)
    return found ? found : TIPS_SECTIONS[0]
  }

  @Builder
  SectionTab(section: TipsSection) {
    // 外层弹性单元铺满 1/4 宽（整格可点），内层胶囊随文字收窄居中
    Row() {
      Text(section.title)
        .fontSize(13)
        .fontWeight(this.currentSectionId === section.id ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.currentSectionId === section.id ? '#f9ca24' : 'rgba(253, 246, 227, 0.5)')
        .padding({ left: 8, right: 8, top: 5, bottom: 5 })
        .backgroundColor(this.currentSectionId === section.id ? 'rgba(249, 202, 36, 0.12)' : 'transparent')
        .borderRadius(13)
    }
    .justifyContent(FlexAlign.Center)
    .layoutWeight(1)
    .onClick((): void => { this.currentSectionId = section.id })
  }

  @Builder
  ArticleCard(article: TipsArticle) {
    Row() {
      Text(article.icon)
        .fontSize(24)
        .width(40)
        .textAlign(TextAlign.Center)
      Column() {
        Text(article.title)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#fdf6e3')
        Text(article.summary)
          .fontSize(11)
          .fontColor('rgba(253, 246, 227, 0.5)')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 3 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 6 })

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
      this.showDetail = true
    })
  }

  // ── 实战小测：逐题四选一，选完即显对错+解析，结束看成绩 ──

  private quizDone(): boolean {
    return this.qIndex >= QUIZ_QUESTIONS.length
  }

  private currentQuizQuestion(): QuizQuestion {
    if (this.qOrder.length === 0) {
      return QUIZ_QUESTIONS[0]
    }
    const idx = Math.min(this.qIndex, this.qOrder.length - 1)
    return QUIZ_QUESTIONS[this.qOrder[idx]]
  }

  /** Fisher-Yates 洗牌：题序每次随机，重练不背顺序 */
  private shuffledOrder(): number[] {
    const n = QUIZ_QUESTIONS.length
    const arr: number[] = []
    for (let i = 0; i < n; i++) {
      arr.push(i)
    }
    for (let i = n - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1))
      const t = arr[i]
      arr[i] = arr[j]
      arr[j] = t
    }
    return arr
  }

  private openQuiz(): void {
    this.qOrder = this.shuffledOrder()
    this.qIndex = 0
    this.qPicked = -1
    this.qCorrect = 0
    this.quizOpen = true
  }

  /** 作答：只允许一次；答对计数（UI 刷新靠 qPicked/@State 派生，无需手写通知） */
  private onPick(idx: number): void {
    if (this.qPicked >= 0) {
      return
    }
    this.qPicked = idx
    if (idx === this.currentQuizQuestion().answer) {
      this.qCorrect++
    }
  }

  private onNext(): void {
    this.qIndex++
    this.qPicked = -1
  }

  private quizSummaryEmoji(): string {
    const pct = this.qCorrect / QUIZ_QUESTIONS.length
    if (pct >= 1) {
      return '🎉'
    }
    if (pct >= 0.75) {
      return '💪'
    }
    if (pct >= 0.5) {
      return '🤔'
    }
    return '📖'
  }

  private quizSummaryMsg(): string {
    const pct = this.qCorrect / QUIZ_QUESTIONS.length
    if (pct >= 1) {
      return '全对！你已经可以上桌指点江山了。'
    }
    if (pct >= 0.75) {
      return '掌握得不错，错掉的题再翻翻对应章节，效果更好。'
    }
    if (pct >= 0.5) {
      return '及格边缘——建议回看「入门认知」与「打法技巧」。'
    }
    return '别灰心，把四个分区读一遍再来挑战。'
  }

  @Builder
  QuizOverlay() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.65)')
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
        .onClick((): void => { this.quizOpen = false })

      Column() {
        Row() {
          Text('📝 实战小测')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#f9ca24')
          Blank()
          Text(this.quizDone() ? `已答 ${QUIZ_QUESTIONS.length} 题` : `第 ${this.qIndex + 1} / ${QUIZ_QUESTIONS.length} 题`)
            .fontSize(11)
            .fontColor('rgba(253, 246, 227, 0.5)')
        }
        // 16/11sp 混排：底对齐
        .alignItems(VerticalAlign.Bottom)
        .width('100%')

        if (this.quizDone()) {
          // 成绩页
          Column() {
            Text(this.quizSummaryEmoji())
              .fontSize(44)
            Text(`答对 ${this.qCorrect} / ${QUIZ_QUESTIONS.length}`)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#f9ca24')
              .margin({ top: 10 })
            Text(this.quizSummaryMsg())
              .fontSize(13)
              .fontColor('rgba(253, 246, 227, 0.85)')
              .lineHeight(21)
              .textAlign(TextAlign.Center)
              .margin({ top: 10 })
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)

          Row() {
            Button('再练一次')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1a1a0a')
              .backgroundColor('#f9ca24')
              .borderRadius(20)
              .layoutWeight(1)
              .onClick((): void => { this.openQuiz() })
            Button('收下')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor('#f9ca24')
              .backgroundColor('rgba(249, 202, 36, 0.08)')
              .borderRadius(20)
              .layoutWeight(1)
              .margin({ left: 10 })
              .onClick((): void => { this.quizOpen = false })
          }
          .width('100%')
          .margin({ top: 16 })
        } else {
          // 答题区（题干 + 选项 + 反馈 一起滚动，防小屏/大字体溢出）
          Scroll() {
            Column() {
              Text(this.currentQuizQuestion().question)
                .fontSize(15)
                .fontColor('rgba(253, 246, 227, 0.9)')
                .lineHeight(24)
                .width('100%')
                .margin({ bottom: 10 })
              ForEach(this.currentQuizQuestion().options, (opt: string, idx: number) => {
                this.OptionRow(idx, opt)
              }, (opt: string, idx: number) => `${this.qIndex}-${idx}`)

              if (this.qPicked >= 0) {
                Column() {
                  Row() {
                    Text(this.qPicked === this.currentQuizQuestion().answer ? '✓' : '✗')
                      .fontSize(15)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(this.qPicked === this.currentQuizQuestion().answer ? '#2ecc71' : '#f0533f')
                      .margin({ right: 6 })
                    Text(this.qPicked === this.currentQuizQuestion().answer ? '回答正确' : '再想想，看解析')
                      .fontSize(14)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(this.qPicked === this.currentQuizQuestion().answer ? '#2ecc71' : '#f0533f')
                  }
                  Text(`💡 ${this.currentQuizQuestion().explain}`)
                    .fontSize(12)
                    .fontColor('rgba(253, 246, 227, 0.85)')
                    .lineHeight(20)
                    .width('100%')
                    .padding(10)
                    .backgroundColor('rgba(249, 202, 36, 0.1)')
                    .border({ width: 1, color: 'rgba(249, 202, 36, 0.35)', radius: 8 })
                    .margin({ top: 8 })
                }
                .width('100%')
                .margin({ top: 4 })
              }
            }
            .width('100%')
          }
          .layoutWeight(1)
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
          .scrollBar(BarState.Off)
          .margin({ top: 12 })

          Row() {
            if (this.qPicked >= 0) {
              Button('收下')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor('#f9ca24')
                .backgroundColor('rgba(249, 202, 36, 0.08)')
                .borderRadius(20)
                .layoutWeight(1)
                .onClick((): void => { this.quizOpen = false })
              Button(this.qIndex + 1 >= QUIZ_QUESTIONS.length ? '查看成绩' : '下一题')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor('#1a1a0a')
                .backgroundColor('#f9ca24')
                .borderRadius(20)
                .layoutWeight(1)
                .margin({ left: 10 })
                .onClick((): void => { this.onNext() })
            } else {
              Button('收下')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor('#f9ca24')
                .backgroundColor('rgba(249, 202, 36, 0.08)')
                .borderRadius(20)
                .layoutWeight(1)
                .onClick((): void => { this.quizOpen = false })
            }
          }
          .width('100%')
          .margin({ top: 14 })
        }
      }
      .width('86%')
      .height('82%')
      .padding({ left: 22, right: 22, top: 18, bottom: 16 })
      .backgroundColor('#241f12')
      .border({ width: 1, color: 'rgba(249, 202, 36, 0.35)', radius: 16 })
      .shadow({ radius: 30, color: 'rgba(0, 0, 0, 0.5)', offsetY: 8 })
    }
    .width('100%')
    .height('100%')
  }

  // 选项行派生状态（@Builder 内不能写局部变量，只能调用方法）
  private revealed(): boolean {
    return this.qPicked >= 0
  }

  private answerRevealed(idx: number): boolean {
    return this.qPicked >= 0 && idx === this.currentQuizQuestion().answer
  }

  private wrongPicked(idx: number): boolean {
    return this.qPicked >= 0 && idx === this.qPicked && idx !== this.currentQuizQuestion().answer
  }

  /** 选项行：默认金调；作答后正确项绿框/错选项红框（序号同步变色） */
  @Builder
  OptionRow(idx: number, opt: string) {
    Row() {
      Text(OPTION_MARKS[idx])
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.answerRevealed(idx) ? '#2ecc71' : (this.wrongPicked(idx) ? '#f0533f' : 'rgba(249, 202, 36, 0.85)'))
      Text(opt)
        .fontSize(13)
        .fontColor('rgba(253, 246, 227, 0.9)')
        .lineHeight(20)
        .layoutWeight(1)
        .margin({ left: 8 })
    }
    .width('100%')
    .padding(12)
    .backgroundColor(this.answerRevealed(idx) ? 'rgba(46, 204, 113, 0.1)' : (this.wrongPicked(idx) ? 'rgba(240, 83, 63, 0.1)' : 'rgba(249, 202, 36, 0.05)'))
    .border({
      width: 1,
      color: this.answerRevealed(idx) ? '#2ecc71' : (this.wrongPicked(idx) ? '#f0533f' : 'rgba(249, 202, 36, 0.15)'),
      radius: 8
    })
    .margin({ bottom: 8 })
    .onClick((): void => { this.onPick(idx) })
  }

  /** 详情覆层：遮罩点击关闭 + 底部金色「收下」确定性关闭 */
  @Builder
  DetailOverlay() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.65)')
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
        .onClick((): void => { this.showDetail = false })

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

        // 块数越多越长：覆层内 Scroll 需定高，280~460 自适应
        Scroll() {
          Column() {
            ForEach(this.selectedArticle.blocks, (block: TipBlock) => {
              if (block.kind === 'h') {
                Text(block.text)
                  .fontSize(13)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('rgba(249, 202, 36, 0.85)')
                  .width('100%')
                  .margin({ top: 12, bottom: 4 })
              } else if (block.kind === 'b') {
                Text(`· ${block.text}`)
                  .fontSize(13)
                  .fontColor('rgba(253, 246, 227, 0.85)')
                  .lineHeight(21)
                  .width('100%')
                  .margin({ top: 2 })
              } else if (block.kind === 't') {
                Text(block.text)
                  .fontSize(12)
                  .fontColor('rgba(253, 246, 227, 0.85)')
                  .lineHeight(20)
                  .width('100%')
                  .padding(10)
                  .backgroundColor('rgba(249, 202, 36, 0.1)')
                  .border({ width: 1, color: 'rgba(249, 202, 36, 0.35)', radius: 8 })
                  .margin({ top: 10 })
              } else {
                Text(block.text)
                  .fontSize(13)
                  .fontColor('rgba(253, 246, 227, 0.85)')
                  .lineHeight(21)
                  .width('100%')
                  .margin({ top: 2 })
              }
            }, (block: TipBlock, idx: number) => `${this.selectedArticle.id}-${idx}`)
          }
          .width('100%')
        }
        .height(Math.min(460, Math.max(280, 150 + this.selectedArticle.blocks.length * 30)))
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .scrollBar(BarState.Off)
        .margin({ top: 14 })

        Button('收下')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1a1a0a')
          .backgroundColor('#f9ca24')
          .borderRadius(18)
          .width('100%')
          .margin({ top: 18 })
          .onClick((): void => { this.showDetail = false })
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
