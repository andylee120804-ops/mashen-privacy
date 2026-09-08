// entry/src/main/ets/pages/FortuneAlmanacPage.ets
// 运势·黄历 + 财神历·神诞（v1.3.0 反馈合并：原独立神诞入口并入本页段内切换）：
// - 运势·黄历：任意日期黄历 + 属相运势（星级/牌运/宜忌/幸运数字/幸运色）
//   + 星座运势（爱情/事业/财运），日期前后翻看
// - 财神历·神诞：神诞列表 + 收藏（收藏自动置前）
// 属相/星座选择用页面内覆层（非 CustomDialog，见项目弹层经验）。
// 数据由 FortuneTypes 确定性 PRNG 生成。
import { FortuneViewModel } from '../viewmodels/FortuneViewModel'
import { PageBack } from '../components/PageBack'
import {
  ShengxiaoFortune, ZodiacFortune, SHENGXIAO, ZODIAC_SIGNS, PAIYUN_LEVELS,
  EMPTY_SHENGXIAO_FORTUNE, EMPTY_ZODIAC_FORTUNE,
  getAlmanacForDate, formatDate, dateOffsetStr, weekdayOf, starText,
  ShendanEntry, SHENDAN_LIST
} from '../model/FortuneTypes'
import { lunarTextOf } from '../model/LunarCalendar'

@Component
export struct FortuneAlmanacPage {
  /** 独立模式（EntryShell 从「我的」进入）：返回键并入大标题行；Tab 模式不带 */
  @Prop standalone: boolean = false
  @StorageLink('fortuneVM') fortuneVM: FortuneViewModel = new FortuneViewModel()
  // UI v1：@StorageLink 不通知 @Observed 嵌套变更；偏好（属相/星座/收藏）变更后
  // VM bump fortuneRev，这里 @Watch 重建神诞列表快照（连带全页重建读最新偏好）。
  @StorageLink('fortuneRev') @Watch('onFortuneRev') fortuneRev: number = 0
  @State seg: string = 'fortune'   // fortune=运势·黄历；shendan=财神历·神诞
  @State selDate: string = ''
  /** 属相/星座选择覆层：''=收起；'sx'=选属相；'zx'=选星座（两者独立弹层，可分开修改） */
  @State overlayMode: string = ''
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
        // 标题（独立模式返回键并入同行且标题居中，右侧配平占位与返回键等宽；
        // Tab 模式不带返回，标题保持左对齐）
        Row() {
          if (this.standalone) {
            PageBack()
          }
          Text('☯ 运势 · 黄历')
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

        // 段切换：运势·黄历 / 财神历·神诞（合并自独立神诞入口）
        this.SegBar()

        Scroll() {
          Column() {
            if (this.seg === 'fortune') {
              // 顶部主卡（日期+牌运+黄历一体）→ 属相运势 → 星座运势
              this.DateNav()
              this.ShengxiaoCard()
              this.ZodiacCard()
            } else {
              this.ShendanSection()
            }
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

      // 属相/星座选择覆层（模式驱动：'' 收起）
      if (this.overlayMode !== '') {
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

  /** 属相头部 chip：未选「点击设置」，已选「🐭鼠 · 修改」明确可再改 */
  private sxChipLabel(): string {
    if (this.fortuneVM.shengxiaoIdx >= 0) {
      return `${SHENGXIAO[this.fortuneVM.shengxiaoIdx]} · 修改`
    }
    return '点击设置'
  }

  private zxChipLabel(): string {
    if (this.fortuneVM.zodiacIdx >= 0) {
      return `${ZODIAC_SIGNS[this.fortuneVM.zodiacIdx]} · 修改`
    }
    return '点击设置'
  }

  /** 选属相：点选即生效并收起（单模式弹层，可随时重选） */
  private pickShengxiao(idx: number): void {
    this.fortuneVM.setShengxiao(idx)
    this.overlayMode = ''
  }

  private pickZodiac(idx: number): void {
    this.fortuneVM.setZodiac(idx)
    this.overlayMode = ''
  }

  /** 弹层副行：显示当前已选值，明确可随时更换 */
  private overlayCurrent(): string {
    if (this.overlayMode === 'sx') {
      if (this.fortuneVM.shengxiaoIdx >= 0) {
        return `当前：${SHENGXIAO[this.fortuneVM.shengxiaoIdx]}，点选即可更换`
      }
      return '尚未设置属相，点选即生效'
    }
    if (this.fortuneVM.zodiacIdx >= 0) {
      return `当前：${ZODIAC_SIGNS[this.fortuneVM.zodiacIdx]}，点选即可更换`
    }
    return '尚未设置星座，点选即生效'
  }

  // ── 段切换栏 ──
  @Builder
  SegBar() {
    Row() {
      Blank()
      // 短标签（页头大标题已含「运势 · 黄历」全名，胶囊只做段指示，避免同屏重复文案）
      this.SegChip('fortune', '☯ 黄历')
      this.SegChip('shendan', '🀅 神诞')
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

  // ── 顶部「今日」主卡：日期导航 + 牌运大字 + 当日黄历（宜/忌/吉位/花色）整合一体 ──
  // 金线分区替代嵌套盒子，主卡不再出现属相信息（设置入口收敛到属相卡）。
  @Builder
  DateNav() {
    Column() {
      // ① 日期导航行
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
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#fdf6e3')
          Text(this.dateSubLine())
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

      // 金线分区
      Row()
        .width('100%')
        .height(0.5)
        .backgroundColor('rgba(249, 202, 36, 0.14)')

      // ② 牌运大区：适不适合打牌一眼可见
      if (this.fortuneVM.shengxiaoIdx < 0) {
        Row() {
          Column() {
            Text(this.isToday() ? '🀄 今日牌运' : '🀄 当日牌运')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor('#fdf6e3')
            Text(this.isToday() ? '选属相，看今天适不适合打牌' : '选属相，看当日牌运')
              .fontSize(10)
              .fontColor('rgba(249, 202, 36, 0.8)')
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          Text('去设置 ›')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1a1a0a')
            .padding({ left: 12, right: 12, top: 5, bottom: 5 })
            .backgroundColor('#f9ca24')
            .borderRadius(13)
        }
        .width('100%')
        .padding({ top: 12, bottom: 12 })
        .onClick(() => {
          this.overlayMode = 'sx'
        })
      } else {
        Row() {
          Column() {
            Text(this.isToday() ? '🀄 今日牌运' : '🀄 当日牌运')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor('#fdf6e3')
            Text(PAIYUN_LEVELS[this.sxFortune().paiyun].text)
              .fontSize(12)
              .fontColor('rgba(253, 246, 227, 0.9)')
              .margin({ top: 6 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Text(PAIYUN_LEVELS[this.sxFortune().paiyun].level)
            .fontSize(46)
            .fontWeight(FontWeight.Bold)
            .fontColor(PAIYUN_LEVELS[this.sxFortune().paiyun].color)
            .lineHeight(54)
        }
        .width('100%')
        .padding({ top: 8, bottom: 8 })
      }

      // 金线分区
      Row()
        .width('100%')
        .height(0.5)
        .backgroundColor('rgba(249, 202, 36, 0.14)')

      // ③ 当日黄历：宜/忌 短句 + 吉位/幸运花色/幸运数字（并入主卡，不再单独成卡）
      Row() {
        this.AlmanacCol('宜', getAlmanacForDate(this.selDate).suitable)
        this.AlmanacCol('忌', getAlmanacForDate(this.selDate).avoid)
      }
      .width('100%')
      .padding({ top: 10 })

      Column() {
        Text() {
          Span(`吉位 ${getAlmanacForDate(this.selDate).direction} · 幸运花色 `)
          Span(this.suitNameOf(getAlmanacForDate(this.selDate).luckySuit))
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor('#f9ca24')
        }
          .fontSize(11)
          .fontColor('rgba(253, 246, 227, 0.6)')
        Row() {
          Blank()
          Text('幸运数字')
            .fontSize(11)
            .fontColor('rgba(253, 246, 227, 0.6)')
          ForEach(this.luckyNumsOf(), (n: number) => {
            Text(String(n))
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1a1a0a')
              .width(22)
              .height(22)
              .textAlign(TextAlign.Center)
              .backgroundColor('#f9ca24')
              .borderRadius(11)
              .margin({ left: 6 })
          }, (n: number) => String(n))
          Blank()
        }
        .width('100%')
        .margin({ top: 7 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .margin({ top: 8 })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 6, bottom: 12 })
    .backgroundColor('rgba(249, 202, 36, 0.05)')
    .border({ width: 1, color: 'rgba(249, 202, 36, 0.12)', radius: 12 })
    .margin({ bottom: 12 })
  }

  /** 日期副行：今天=阳历几号·星期·农历；其他日期=星期·农历·回今天提示 */
  private dateSubLine(): string {
    const parts: string[] = []
    if (this.isToday()) {
      parts.push(`阳历 ${this.solarMD()}`)
    }
    parts.push(`星期${weekdayOf(this.selDate)}`)
    const lunar = lunarTextOf(this.selDate)
    if (lunar !== '') {
      parts.push(lunar)
    }
    if (!this.isToday()) {
      parts.push('点日期回今天')
    }
    return parts.join(' · ')
  }

  /** 幸运花色去牌面 emoji 前缀：'🀇 条子' → '条子'（花色名已表意，emoji 只留重复信息） */
  private suitNameOf(s: string): string {
    const parts = s.split(' ')
    return parts.length > 1 ? parts[parts.length - 1] : s
  }

  /** '2026-09-02' → '9月2日' */
  private solarMD(): string {
    const parts = this.selDate.split('-')
    if (parts.length !== 3) {
      return this.selDate
    }
    return `${Number(parts[1])}月${Number(parts[2])}日`
  }

  /** 主卡幸运数字：已选属相用属相运势数字；未选按日期确定性生成（同天恒定，1-9 不重复） */
  private luckyNumsOf(): number[] {
    if (this.fortuneVM.shengxiaoIdx >= 0) {
      const nums = this.sxFortune().luckyNumbers
      if (nums.length === 2) {
        return nums
      }
    }
    const parts = this.selDate.split('-')
    if (parts.length !== 3) {
      return [6, 8]
    }
    const base = Number(parts[0]) * 10000 + Number(parts[1]) * 100 + Number(parts[2])
    let a = (base * 7) % 9 + 1
    let b = (base * 13) % 9 + 1
    if (b === a) {
      b = (b % 8) + 1
    }
    if (a > b) {
      const tmp = a
      a = b
      b = tmp
    }
    return [a, b]
  }

  @Builder
  AlmanacCol(label: string, value: string) {
    Column() {
      Text(label)
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(label === '宜' ? '#2ecc71' : '#f0533f')
      Text(value)
        .fontSize(13)
        .fontColor('#fdf6e3')
        .margin({ top: 4 })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  // ── 属相运势卡（牌运大字已并入顶部日期卡）──
  @Builder
  ShengxiaoCard() {
    Column() {
      Row() {
        Text('🀄 属相运势')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#f9ca24')
        Blank()
        Text(this.sxChipLabel())
          .fontSize(12)
          .fontColor('rgba(249, 202, 36, 0.8)')
          .onClick(() => {
            this.overlayMode = 'sx'
          })
      }
      .width('100%')
      .margin({ bottom: 10 })

      if (this.fortuneVM.shengxiaoIdx < 0) {
        Text('设置属相后，查看牌运、宜忌与幸运数字')
          .fontSize(12)
          .fontColor('rgba(253, 246, 227, 0.6)')
          .padding({ top: 8, bottom: 8 })
          .onClick(() => {
            this.overlayMode = 'sx'
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

        // 宜 / 忌 chips（牌运已并入顶部日期卡）
        this.ChipsRow(this.sxFortune().yi, true)
        this.ChipsRow(this.sxFortune().ji, false)

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
        Text('🀄 星座运势')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#f9ca24')
        Blank()
        Text(this.zxChipLabel())
          .fontSize(12)
          .fontColor('rgba(249, 202, 36, 0.8)')
          .onClick(() => {
            this.overlayMode = 'zx'
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
            this.overlayMode = 'zx'
          })
      } else {
        Text(starText(this.zxFortune().stars))
          .fontSize(16)
          .fontColor('#f9ca24')
          .margin({ bottom: 8 })

        this.ZodiacLine('✦ 爱情', this.zxFortune().love)
        this.ZodiacLine('✦ 事业', this.zxFortune().career)
        this.ZodiacLine('✦ 财运', this.zxFortune().wealth)

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

  // ── 宜 / 忌 chips 行（✓/✗ 为随文字色的字形符号，非彩色 emoji）──
  @Builder
  ChipsRow(items: string[], isYi: boolean) {
    Row() {
      Text(isYi ? '✓' : '✗')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(isYi ? '#2ecc71' : '#e74c3c')
        .width(24)
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(items, (it: string) => {
          Text(it)
            .fontSize(11)
            .fontColor(isYi ? '#2ecc71' : '#ff6b5e')
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
          // 颜色用图形色块而非字形：字形会被按文字对比度采样（紫气东来等暗色不达标）
          Row()
            .width(14)
            .height(14)
            .borderRadius(7)
            .backgroundColor(colorHex)
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

  // ── 属相 / 星座选择覆层（独立弹层：overlayMode='sx' 只选属相，'zx' 只选星座）──
  @Builder
  ProfileOverlay() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.65)')
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
        .onClick(() => {
          this.overlayMode = ''
        })

      Column() {
        Text(this.overlayMode === 'sx' ? '选择属相' : '选择星座')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#f9ca24')
          .width('100%')
          .margin({ bottom: 8 })

        Text(this.overlayCurrent())
          .fontSize(11)
          .fontColor('rgba(253, 246, 227, 0.65)')
          .width('100%')
          .margin({ bottom: 12 })

        if (this.overlayMode === 'sx') {
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
                  this.pickShengxiao(idx)
                })
            }, (s: string) => s)
          }
          .width('100%')
        } else {
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
                  this.pickZodiac(idx)
                })
            }, (s: string) => s)
          }
          .width('100%')
        }

        Button('完成')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1a1a0a')
          .backgroundColor('#f9ca24')
          .borderRadius(18)
          .width('100%')
          .margin({ top: 18 })
          .onClick(() => {
            this.overlayMode = ''
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
