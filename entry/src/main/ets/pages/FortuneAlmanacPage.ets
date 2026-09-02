// entry/src/main/ets/pages/FortuneAlmanacPage.ets
// 运势·黄历 + 财神历·神诞（v1.3.0 反馈合并：原独立神诞入口并入本页段内切换）：
// - 运势·黄历：任意日期黄历 + 属相运势（星级/牌运/宜忌/幸运数字/幸运色）
//   + 星座运势（爱情/事业/财运），日期前后翻看
// - 财神历·神诞：神诞列表 + 收藏（收藏自动置前）
// 属相/星座选择用页面内覆层（非 CustomDialog，见项目弹层经验）。
// 数据由 FortuneTypes 确定性 PRNG 生成。
import { FortuneViewModel } from '../viewmodels/FortuneViewModel'
import {
  ShengxiaoFortune, ZodiacFortune, SHENGXIAO, ZODIAC_SIGNS, PAIYUN_LEVELS,
  EMPTY_SHENGXIAO_FORTUNE, EMPTY_ZODIAC_FORTUNE,
  getAlmanacForDate, formatDate, dateOffsetStr, weekdayOf, starText,
  ShendanEntry, SHENDAN_LIST
} from '../model/FortuneTypes'

@Component
export struct FortuneAlmanacPage {
  @StorageLink('fortuneVM') fortuneVM: FortuneViewModel = new FortuneViewModel()
  // UI v1：@StorageLink 不通知 @Observed 嵌套变更；偏好（属相/星座/收藏）变更后
  // VM bump fortuneRev，这里 @Watch 重建神诞列表快照（连带全页重建读最新偏好）。
  @StorageLink('fortuneRev') @Watch('onFortuneRev') fortuneRev: number = 0
  @State seg: string = 'fortune'   // fortune=运势·黄历；shendan=财神历·神诞
  @State selDate: string = ''
  @State showProfileOverlay: boolean = false
  @State shendanRows: ShendanEntry[] = []

  aboutToAppear(): void {
    if (this.selDate === '') {
      this.selDate = formatDate(new Date())
    }
    this.syncShendan()
  }

  onFortuneRev(): void {
    this.syncShendan()
  }

  /** 神诞列表快照：收藏置前，其余按定义顺序（收藏切换即时重排） */
  private syncShendan(): void {
    const favs = this.fortuneVM.shendanFavorites
    const fav = SHENDAN_LIST.filter((s: ShendanEntry): boolean => favs.includes(s.id))
    const rest = SHENDAN_LIST.filter((s: ShendanEntry): boolean => !favs.includes(s.id))
    this.shendanRows = [...fav, ...rest]
  }

  build() {
    Stack() {
      Column() {
        // 标题
        Text('🗓️ 运势 · 黄历')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#f9ca24')
          .width('100%')
          .padding({ left: 20, top: 44, bottom: 8 })
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

        // 段切换：运势·黄历 / 财神历·神诞（合并自独立神诞入口）
        this.SegBar()

        Scroll() {
          Column() {
            if (this.seg === 'fortune') {
              this.DateNav()
              this.AlmanacCard()
              this.ShengxiaoCard()
              this.ZodiacCard()
            } else {
              this.ShendanSection()
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 20 })
        }
        .layoutWeight(1)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#1a1a0a')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])

      // 属相/星座选择覆层
      if (this.showProfileOverlay) {
        this.ProfileOverlay()
      }
    }
    .width('100%')
    .height('100%')
  }

  private isToday(): boolean {
    return this.selDate === formatDate(new Date())
  }

  /** 属相运势（未选择时返回空结果，由守卫分支处理） */
  private sxFortune(): ShengxiaoFortune {
    const f = this.fortuneVM.getShengxiaoFortune(this.selDate)
    if (f !== null) {
      return f
    }
    return EMPTY_SHENGXIAO_FORTUNE
  }

  private zxFortune(): ZodiacFortune {
    const f = this.fortuneVM.getZodiacFortune(this.selDate)
    if (f !== null) {
      return f
    }
    return EMPTY_ZODIAC_FORTUNE
  }

  // ── 段切换栏 ──
  @Builder
  SegBar() {
    Row() {
      Blank()
      this.SegChip('fortune', '🗓️ 运势 · 黄历')
      this.SegChip('shendan', '🧧 财神历 · 神诞')
      Blank()
    }
    .width('100%')
    .margin({ bottom: 10 })
  }

  @Builder
  SegChip(id: string, label: string) {
    Text(label)
      .fontSize(13)
      .fontWeight(this.seg === id ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.seg === id ? '#1a1a0a' : 'rgba(253, 246, 227, 0.7)')
      .padding({ left: 14, right: 14, top: 6, bottom: 6 })
      .backgroundColor(this.seg === id ? '#f9ca24' : 'rgba(249, 202, 36, 0.08)')
      .borderRadius(14)
      .margin({ left: 6, right: 6 })
      .onClick(() => {
        this.seg = id
      })
  }

  // ── 财神历 · 神诞（收藏置前）──
  @Builder
  ShendanSection() {
    Column() {
      Text('记住财神圣诞，逢诞祈福更灵验 · 点 ☆ 收藏后自动置前')
        .fontSize(10)
        .fontColor('rgba(253, 246, 227, 0.5)')
        .width('100%')
        .margin({ bottom: 10 })

      ForEach(this.shendanRows, (s: ShendanEntry) => {
        this.ShendanRow(s)
      }, (s: ShendanEntry) => s.id)
    }
    .width('100%')
  }

  @Builder
  ShendanRow(s: ShendanEntry) {
    Row() {
      Text(s.icon)
        .fontSize(26)
        .width(42)
        .textAlign(TextAlign.Center)

      Column() {
        Row() {
          Text(s.name)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#fdf6e3')
          Text(s.lunarDate)
            .fontSize(10)
            .fontColor('rgba(249, 202, 36, 0.85)')
            .margin({ left: 8 })
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .border({ width: 1, color: 'rgba(249, 202, 36, 0.3)', radius: 8 })
        }

        Text(s.desc)
          .fontSize(12)
          .fontColor('rgba(253, 246, 227, 0.65)')
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 8 })

      Text(this.fortuneVM.shendanFavorites.includes(s.id) ? '★ 已收藏' : '☆ 收藏')
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

  // ── 日期切换 ──
  @Builder
  DateNav() {
    Row() {
      Text('‹')
        .fontSize(22)
        .fontColor('#f9ca24')
        .padding(10)
        .onClick(() => {
          this.selDate = dateOffsetStr(this.selDate, -1)
        })

      Column() {
        Text(this.isToday() ? '今天' : this.selDate)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#fdf6e3')
        Text(`星期${weekdayOf(this.selDate)} · 点击日期回到今天`)
          .fontSize(10)
          .fontColor('rgba(253, 246, 227, 0.6)')
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)
      .onClick(() => {
        this.selDate = formatDate(new Date())
      })

      Text('›')
        .fontSize(22)
        .fontColor('#f9ca24')
        .padding(10)
        .onClick(() => {
          this.selDate = dateOffsetStr(this.selDate, 1)
        })
    }
    .width('100%')
    .padding(10)
    .backgroundColor('rgba(249, 202, 36, 0.05)')
    .border({ width: 1, color: 'rgba(249, 202, 36, 0.12)', radius: 10 })
    .margin({ bottom: 12 })
  }

  // ── 当日黄历 ──
  @Builder
  AlmanacCard() {
    Column() {
      Text('📜 当日黄历')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#f9ca24')
        .width('100%')
        .margin({ bottom: 8 })

      Row() {
        this.AlmanacCol('宜', getAlmanacForDate(this.selDate).suitable)
        this.AlmanacCol('忌', getAlmanacForDate(this.selDate).avoid)
      }
      .width('100%')

      Row() {
        Text(`吉位：${getAlmanacForDate(this.selDate).direction}`)
          .fontSize(11)
          .fontColor('rgba(253, 246, 227, 0.7)')
          .layoutWeight(1)
        Text(`幸运花色：${getAlmanacForDate(this.selDate).luckySuit}`)
          .fontSize(11)
          .fontColor('rgba(249, 202, 36, 0.8)')
      }
      .width('100%')
      .margin({ top: 10 })
    }
    .width('100%')
    .padding(14)
    .backgroundColor('rgba(249, 202, 36, 0.05)')
    .border({ width: 1, color: 'rgba(249, 202, 36, 0.12)', radius: 10 })
    .margin({ bottom: 12 })
  }

  @Builder
  AlmanacCol(label: string, value: string) {
    Column() {
      Text(label)
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(label === '宜' ? '#2ecc71' : '#e74c3c')
      Text(value)
        .fontSize(13)
        .fontColor('#fdf6e3')
        .margin({ top: 4 })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  // ── 属相运势卡（含今日牌运醒目大卡）──
  @Builder
  ShengxiaoCard() {
    Column() {
      Row() {
        Text('🀄 属相运势')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#f9ca24')
        Blank()
        Text(this.fortuneVM.shengxiaoIdx >= 0 ? SHENGXIAO[this.fortuneVM.shengxiaoIdx] : '点击设置')
          .fontSize(12)
          .fontColor('rgba(249, 202, 36, 0.8)')
          .onClick(() => {
            this.showProfileOverlay = true
          })
      }
      .width('100%')
      .margin({ bottom: 10 })

      if (this.fortuneVM.shengxiaoIdx < 0) {
        Text('设置属相后，查看今日牌运、宜忌与幸运数字')
          .fontSize(12)
          .fontColor('rgba(253, 246, 227, 0.6)')
          .padding({ top: 8, bottom: 8 })
          .onClick(() => {
            this.showProfileOverlay = true
          })
      } else {
        // 星级 + 总评
        Text(starText(this.sxFortune().stars))
          .fontSize(16)
          .fontColor('#f9ca24')
          .margin({ bottom: 4 })
        Text(this.sxFortune().summary)
          .fontSize(13)
          .fontColor('rgba(253, 246, 227, 0.85)')
          .margin({ bottom: 10 })

        // 今日牌运（全页视觉重点）
        Row() {
          Text('🀄 今日牌运')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor('#fdf6e3')
            .layoutWeight(1)
          Column() {
            Text(PAIYUN_LEVELS[this.sxFortune().paiyun].level)
              .fontSize(34)
              .fontWeight(FontWeight.Bold)
              .fontColor(PAIYUN_LEVELS[this.sxFortune().paiyun].color)
            Text(PAIYUN_LEVELS[this.sxFortune().paiyun].text)
              .fontSize(11)
              .fontColor('rgba(253, 246, 227, 0.6)')
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')
        .padding({ top: 14, bottom: 14 })
        .backgroundColor('rgba(249, 202, 36, 0.06)')
        .border({ width: 1.5, color: PAIYUN_LEVELS[this.sxFortune().paiyun].color, radius: 12 })
        .margin({ bottom: 10 })

        // 宜 / 忌 chips
        this.ChipsRow('✅', this.sxFortune().yi, true)
        this.ChipsRow('❌', this.sxFortune().ji, false)

        // 幸运数字 + 幸运颜色
        this.LuckyRow(this.sxFortune().luckyNumbers, this.sxFortune().luckyColor.name, this.sxFortune().luckyColor.hex)
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor('rgba(249, 202, 36, 0.05)')
    .border({ width: 1, color: 'rgba(249, 202, 36, 0.12)', radius: 10 })
    .margin({ bottom: 12 })
  }

  // ── 星座运势卡 ──
  @Builder
  ZodiacCard() {
    Column() {
      Row() {
        Text('✨ 星座运势')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#f9ca24')
        Blank()
        Text(this.fortuneVM.zodiacIdx >= 0 ? ZODIAC_SIGNS[this.fortuneVM.zodiacIdx] : '点击设置')
          .fontSize(12)
          .fontColor('rgba(249, 202, 36, 0.8)')
          .onClick(() => {
            this.showProfileOverlay = true
          })
      }
      .width('100%')
      .margin({ bottom: 10 })

      if (this.fortuneVM.zodiacIdx < 0) {
        Text('设置星座后，查看爱情 / 事业 / 财运短评')
          .fontSize(12)
          .fontColor('rgba(253, 246, 227, 0.6)')
          .padding({ top: 8, bottom: 8 })
          .onClick(() => {
            this.showProfileOverlay = true
          })
      } else {
        Text(starText(this.zxFortune().stars))
          .fontSize(16)
          .fontColor('#f9ca24')
          .margin({ bottom: 8 })

        this.ZodiacLine('💕 爱情', this.zxFortune().love)
        this.ZodiacLine('💼 事业', this.zxFortune().career)
        this.ZodiacLine('💰 财运', this.zxFortune().wealth)

        this.LuckyRow(this.zxFortune().luckyNumbers, this.zxFortune().luckyColor.name, this.zxFortune().luckyColor.hex)
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor('rgba(249, 202, 36, 0.05)')
    .border({ width: 1, color: 'rgba(249, 202, 36, 0.12)', radius: 10 })
  }

  @Builder
  ZodiacLine(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(12)
        .fontColor('rgba(249, 202, 36, 0.8)')
        .width(64)
      Text(value)
        .fontSize(13)
        .fontColor('rgba(253, 246, 227, 0.85)')
        .layoutWeight(1)
    }
    .width('100%')
    .margin({ bottom: 8 })
  }

  // ── 宜 / 忌 chips 行 ──
  @Builder
  ChipsRow(icon: string, items: string[], isYi: boolean) {
    Row() {
      Text(icon)
        .fontSize(14)
        .width(24)
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(items, (it: string) => {
          Text(it)
            .fontSize(11)
            .fontColor(isYi ? '#2ecc71' : '#e74c3c')
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor(isYi ? 'rgba(46, 204, 113, 0.1)' : 'rgba(231, 76, 60, 0.1)')
            .borderRadius(10)
            .margin({ right: 6, bottom: 6 })
        }, (it: string) => it)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .margin({ bottom: 8 })
  }

  // ── 幸运数字 + 幸运颜色 ──
  @Builder
  LuckyRow(nums: number[], colorName: string, colorHex: string) {
    Row() {
      Column() {
        Text('幸运数字')
          .fontSize(10)
          .fontColor('rgba(253, 246, 227, 0.6)')
        Text(nums.join(' · '))
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#f9ca24')
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)

      Blank()

      Column() {
        Text('幸运颜色')
          .fontSize(10)
          .fontColor('rgba(253, 246, 227, 0.6)')
        Row() {
          Text('●')
            .fontSize(16)
            .fontColor(colorHex)
          Text(colorName)
            .fontSize(14)
            .fontColor('#fdf6e3')
            .margin({ left: 6 })
        }
        .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .margin({ top: 6, bottom: 4 })
  }

  // ── 属相 / 星座选择覆层（页面内覆层，非 CustomDialog）──
  @Builder
  ProfileOverlay() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.65)')
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
        .onClick(() => {
          this.showProfileOverlay = false
        })

      Column() {
        Text('选择属相')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#f9ca24')
          .width('100%')
          .margin({ bottom: 10 })

        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
          ForEach(SHENGXIAO, (s: string, idx: number) => {
            Text(s)
              .fontSize(13)
              .fontColor(this.fortuneVM.shengxiaoIdx === idx ? '#1a1a0a' : '#fdf6e3')
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .backgroundColor(this.fortuneVM.shengxiaoIdx === idx ? '#f9ca24' : 'rgba(249, 202, 36, 0.08)')
              .borderRadius(14)
              .margin({ right: 6, bottom: 8 })
              .onClick(() => {
                this.fortuneVM.setShengxiao(idx)
              })
          }, (s: string) => s)
        }
        .width('100%')
        .margin({ bottom: 16 })

        Row()
          .width('60%')
          .height(0.5)
          .backgroundColor('rgba(249, 202, 36, 0.15)')
          .margin({ bottom: 16 })

        Text('选择星座')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#f9ca24')
          .width('100%')
          .margin({ bottom: 10 })

        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
          ForEach(ZODIAC_SIGNS, (s: string, idx: number) => {
            Text(s)
              .fontSize(13)
              .fontColor(this.fortuneVM.zodiacIdx === idx ? '#1a1a0a' : '#fdf6e3')
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .backgroundColor(this.fortuneVM.zodiacIdx === idx ? '#f9ca24' : 'rgba(249, 202, 36, 0.08)')
              .borderRadius(14)
              .margin({ right: 6, bottom: 8 })
              .onClick(() => {
                this.fortuneVM.setZodiac(idx)
              })
          }, (s: string) => s)
        }
        .width('100%')

        Button('完成')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1a1a0a')
          .backgroundColor('#f9ca24')
          .borderRadius(18)
          .width('100%')
          .margin({ top: 18 })
          .onClick(() => {
            this.showProfileOverlay = false
          })
      }
      .width('86%')
      .padding(20)
      .backgroundColor('#241f12')
      .border({ width: 1, color: 'rgba(249, 202, 36, 0.35)', radius: 16 })
      .shadow({ radius: 30, color: 'rgba(0, 0, 0, 0.5)', offsetY: 8 })
    }
    .width('100%')
    .height('100%')
  }
}
