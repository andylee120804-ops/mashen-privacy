// entry/src/main/ets/components/TipModal.ets
// 供奉麻神弹窗（IAP 供奉台）。
// 5 档金元宝金额卡（AGC 消耗型商品 tip_06/6/18/66/88）+ 云端累计功德显示 +
// 华为收银台直购 + 成功烟花粒子 + 功德滚动动画。
// 时序契约（设计文档第 5 节）：purchase 只买不消耗；云端记账成功才 finishPurchase，
// 失败保持订单未完成，EntryAbility 启动补单（幂等不双记）。
// WCAG（规则 common/wcag-contrast.md，弹窗底 #1a1a0a）：金实色 #f9ca24 仅用于
// 大字/实底钮（≥3:1 或钮上深字），正文米色 alpha≥0.5、金色 alpha≥0.6，深字实色 #1a1a0a。
import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { BusinessError } from '@kit.BasicServicesKit'
import { IapPaymentService } from '../service/IapPaymentService'
import { TipProduct, TIP_PRODUCTS, PaymentError, PaymentErrorKind } from '../service/IPaymentService'
import { CloudService } from '../service/CloudService'
import { MeritInfo } from '../model/EnrichTypes'

/** 烟花粒子静态参数（构造时随机生成，避免动画期间重算） */
interface FireParticle {
  id: number
  angle: number      // 发射角度（度）
  dist: number       // 飞行距离（vp）
  delay: number      // 起飞延迟（ms）
  size: number       // 字号
}

const MERIT_CACHE_KEY = 'myMerit'
const ROLL_STEPS = 20
const ROLL_INTERVAL_MS = 40

/** 金额显示：整数不带小数（¥6），非整数一位小数（¥0.6） */
function formatAmount(n: number): string {
  return Number.isInteger(n) ? ('¥' + n) : ('¥' + n.toFixed(1))
}

@CustomDialog
export struct TipModal {
  controller: CustomDialogController
  @State selectedProductId: string = 'tip_6'
  @State meritAmount: number = 0
  @State meritCount: number = 0
  @State paying: boolean = false
  @State successPhase: boolean = false
  @State rollAmount: number = 0
  @State particleAnim: boolean = false
  private iapService: IapPaymentService | null = null
  private prefs: preferences.Preferences | null = null
  private rollTimer: number = -1
  private particles: FireParticle[] = []

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext()
    this.iapService = new IapPaymentService(hostContext as common.UIAbilityContext)
    // 烟花粒子：10 颗随机角度/距离
    for (let i = 0; i < 10; i++) {
      this.particles.push({
        id: i,
        angle: Math.random() * 360,
        dist: 60 + Math.random() * 90,
        delay: i * 45,
        size: 12 + Math.random() * 10
      })
    }
    this.loadMerit()
  }

  aboutToDisappear(): void {
    if (this.rollTimer >= 0) {
      clearInterval(this.rollTimer)
      this.rollTimer = -1
    }
  }

  /** 功德显示：本地缓存先兜底，云端最新值覆盖并回写缓存 */
  private async loadMerit(): Promise<void> {
    try {
      // getHostContext() 返回 Context | undefined，必须显式转型否则
      // getPreferences 重载解析失败（void & Promise<Preferences>）
      const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext
      const prefs = await preferences.getPreferences(hostContext, 'mashen_user_prefs')
      this.prefs = prefs
      const cached = await prefs.get(MERIT_CACHE_KEY, '') as string
      if (cached) {
        const m = JSON.parse(cached) as MeritInfo
        this.meritAmount = m.totalAmount
        this.meritCount = m.totalCount
      }
    } catch (err) {
      console.error('[TipModal] read merit cache failed:', JSON.stringify(err))
    }
    const merit = await CloudService.getMyMerit()
    if (merit !== null) {
      this.meritAmount = merit.totalAmount
      this.meritCount = merit.totalCount
      this.saveMeritCache(merit)
    }
  }

  private saveMeritCache(merit: MeritInfo): void {
    if (this.prefs === null) {
      return
    }
    this.prefs.put(MERIT_CACHE_KEY, JSON.stringify(merit)).then(() => {
      return this.prefs!.flush()
    }).catch((err: Object) => {
      console.error('[TipModal] save merit cache failed:', JSON.stringify(err))
    })
  }

  /** 确认供奉：收银台 → 云端记账 → 消耗 → 成功动画 */
  private async confirmTip(): Promise<void> {
    if (this.paying || this.iapService === null) {
      return
    }
    this.paying = true
    try {
      const result = await this.iapService.purchase(this.selectedProductId)
      if (!result.success) {
        // 用户取消：静默返回，弹窗不关可重选
        this.paying = false
        return
      }
      // 记账在消耗之前：云端幂等记账成功才 finishPurchase
      const merit = await CloudService.recordDonation({
        productId: result.productId,
        amount: result.amount,
        purchaseToken: result.purchaseToken,
        purchaseData: result.purchaseData,
        orderId: result.orderId
      })
      if (merit === null) {
        // 记账失败（断网/云端 5xx）：不消耗，下次启动补单自动入账
        this.getUIContext().getPromptAction().showToast({ message: '供奉已收到，功德稍后自动入账' })
        this.paying = false
        return
      }
      // 消耗确认失败不影响用户结果（钱已付、功德已入账），仅记日志留待启动补单；
      // 不能落到「支付失败请重试」——会诱导重复付费
      try {
        await this.iapService.finishPurchase(result)
      } catch (err) {
        console.error('[TipModal] finishPurchase deferred (retry on next launch):', JSON.stringify(err))
      }
      this.saveMeritCache(merit)
      this.playSuccess(result.amount, merit)
    } catch (err) {
      this.handlePurchaseError(err)
      this.paying = false
    }
  }

  private handlePurchaseError(err: Object): void {
    if (err instanceof PaymentError) {
      const pe = err as PaymentError
      if (pe.kind === PaymentErrorKind.NEED_LOGIN) {
        // v1：指引系统设置登录（LoginWithHuaweiID 引导留 v2，依赖 AGC 华为帐号服务配置）
        this.getUIContext().getPromptAction().showToast({ message: '供奉需登录华为帐号，请在系统设置中登录后重试' })
      } else if (pe.kind === PaymentErrorKind.RETRY_AFTER_COMPLETE) {
        // 上一笔同商品未消耗（云端记账失败所致），已自动补单消耗，让用户重试
        this.getUIContext().getPromptAction().showToast({ message: '检测到上一笔供奉未入账，已自动补录，请再次供奉' })
      } else {
        this.getUIContext().getPromptAction().showToast({ message: pe.message })
      }
      console.error('[TipModal] payment error: kind=' + pe.kind + ' code=' + pe.rawCode)
      return
    }
    const e = err as BusinessError
    console.error('[TipModal] purchase error: code=' + e.code + ' msg=' + e.message)
    this.getUIContext().getPromptAction().showToast({ message: '支付失败请重试' })
  }

  /** 清功德滚动定时器（防重入/防泄漏：旧定时器残留会双倍速滚动并错杀新定时器） */
  private clearRollTimer(): void {
    if (this.rollTimer >= 0) {
      clearInterval(this.rollTimer)
      this.rollTimer = -1
    }
  }

  /** 成功态：烟花粒子 + 「功德 +N」滚动 */
  private playSuccess(amount: number, merit: MeritInfo): void {
    this.paying = false
    this.successPhase = true
    this.meritAmount = merit.totalAmount
    this.meritCount = merit.totalCount
    // 粒子：先复位再触发，保证动画从头播
    this.particleAnim = false
    setTimeout(() => {
      this.particleAnim = true
    }, 50)
    // 功德 +N 滚动
    this.clearRollTimer()
    this.rollAmount = 0
    const step = amount / ROLL_STEPS
    this.rollTimer = setInterval(() => {
      const next = this.rollAmount + step
      if (next >= amount) {
        this.rollAmount = amount
        clearInterval(this.rollTimer)
        this.rollTimer = -1
      } else {
        this.rollAmount = next
      }
    }, ROLL_INTERVAL_MS)
  }

  /** 回到选择态（继续供奉） */
  private backToSelect(): void {
    this.clearRollTimer()
    this.successPhase = false
    this.particleAnim = false
    this.rollAmount = 0
  }

  build() {
    Column() {
      if (this.successPhase) {
        this.SuccessView()
      } else {
        this.SelectView()
      }
    }
    .width('78%')
    .backgroundColor('#1a1a0a')
    .borderRadius(16)
    .border({ width: 1.5, color: 'rgba(249, 202, 36, 0.3)' })
    .shadow({ radius: 30, color: 'rgba(0, 0, 0, 0.6)', offsetY: 6 })
    .clip(true)
  }

  // ── 供奉台（选择态） ──
  @Builder
  SelectView() {
    Column() {
      // 顶部红色装饰条
      Row()
        .width('100%')
        .height(4)
        .backgroundColor('#c0392b')

      Text('✦  供奉麻神  ✦')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#f9ca24')
        .letterSpacing(2)
        .margin({ top: 20, bottom: 6 })

      Text('「心诚则灵 · 福报自来」')
        .fontSize(12)
        .fontColor('rgba(253, 246, 227, 0.5)')
        .fontStyle(FontStyle.Italic)
        .margin({ bottom: 14 })

      // 我的累计功德（云端拉取，本地缓存兜底）
      Row() {
        Text('我的累计功德')
          .fontSize(12)
          .fontColor('rgba(249, 202, 36, 0.7)')
          .margin({ right: 8 })
        Text(this.meritCount > 0
          ? formatAmount(this.meritAmount) + ' · ' + this.meritCount + ' 次供奉'
          : '尚无供奉')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor('#f9ca24')
        Blank()
        Text('🧧')
          .fontSize(14)
          .opacity(1)
      }
      .width('86%')
      .padding({ top: 8, bottom: 8, left: 12, right: 12 })
      .borderRadius(10)
      .border({ width: 1, color: 'rgba(249, 202, 36, 0.35)' })
      .backgroundColor('rgba(249, 202, 36, 0.06)')
      .margin({ bottom: 16 })

      // 5 档金元宝金额卡
      Row() {
        ForEach(TIP_PRODUCTS, (p: TipProduct) => {
          Column() {
            Text('🧧')
              .fontSize(18)
              .opacity(1)
              .margin({ bottom: 2 })
            Text(formatAmount(p.amount))
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#f9ca24')
            Text(p.label)
              .fontSize(9)
              .fontColor('rgba(253, 246, 227, 0.6)')
              .margin({ top: 2 })
          }
          .layoutWeight(1)
          .padding({ top: 10, bottom: 8 })
          .borderRadius(10)
          .backgroundColor(this.selectedProductId === p.productId
            ? 'rgba(249, 202, 36, 0.14)'
            : 'rgba(249, 202, 36, 0.04)')
          .border({
            width: this.selectedProductId === p.productId ? 1.5 : 1,
            color: this.selectedProductId === p.productId ? '#f9ca24' : 'rgba(249, 202, 36, 0.3)'
          })
          .margin({ left: p.productId === TIP_PRODUCTS[0].productId ? 0 : 4 })
          .onClick(() => {
            this.selectedProductId = p.productId
          })
        }, (p: TipProduct) => p.productId)
      }
      .width('86%')
      .margin({ bottom: 18 })

      // 确认供奉（金底深字，WCAG 11.29:1；禁用仅用 enabled，不压暗——压暗态深字对比度不足）
      Button(this.paying ? '供奉中…' : '确认供奉')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1a1a0a')
        .backgroundColor('#f9ca24')
        .borderRadius(20)
        .height(40)
        .width('60%')
        .enabled(!this.paying)
        .margin({ bottom: 10 })
        .onClick(() => {
          this.confirmTip()
        })

      Text('供奉善款将支持联合国儿童公益事业')
        .fontSize(9)
        .fontColor('rgba(253, 246, 227, 0.5)')
        .margin({ bottom: 8 })

      Button('关闭')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#f9ca24')
        .backgroundColor(Color.Transparent)
        .border({ width: 1, color: 'rgba(249, 202, 36, 0.4)' })
        .borderRadius(20)
        .height(34)
        .padding({ left: 28, right: 28 })
        .margin({ bottom: 12 })
        .onClick(() => {
          this.controller.close()
        })
    }
    .width('100%')
  }

  // ── 成功态（烟花 + 功德滚动） ──
  @Builder
  SuccessView() {
    Column() {
      // 烟花粒子层
      Stack() {
        ForEach(this.particles, (p: FireParticle) => {
          Text('✦')
            .fontSize(p.size)
            .fontColor('#f9ca24')
            .opacity(this.particleAnim ? 0 : 0.9)
            .translate({
              x: this.particleAnim ? Math.cos(p.angle * Math.PI / 180) * p.dist : 0,
              y: this.particleAnim ? Math.sin(p.angle * Math.PI / 180) * p.dist - 20 : 0
            })
            .animation({
              duration: 1100,
              delay: p.delay,
              curve: Curve.EaseOut
            })
        }, (p: FireParticle) => 'p' + p.id)
      }
      .width('100%')
      .height(80)
      .margin({ top: 26 })

      Text('功德 +' + formatAmount(this.rollAmount))
        .fontSize(30)
        .fontWeight(FontWeight.Bold)
        .fontColor('#f9ca24')
        .margin({ bottom: 8 })

      Text('✦ 功德已记入云簿 ✦')
        .fontSize(13)
        .fontColor('rgba(253, 246, 227, 0.7)')
        .margin({ bottom: 6 })

      Text('累计功德 ' + formatAmount(this.meritAmount) + ' · ' + this.meritCount + ' 次供奉')
        .fontSize(12)
        .fontColor('rgba(253, 246, 227, 0.6)')
        .margin({ bottom: 24 })

      Row() {
        Button('继续供奉')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#f9ca24')
          .backgroundColor(Color.Transparent)
          .border({ width: 1, color: 'rgba(249, 202, 36, 0.4)' })
          .borderRadius(20)
          .height(34)
          .padding({ left: 20, right: 20 })
          .margin({ right: 10 })
          .onClick(() => {
            this.backToSelect()
          })

        Button('心满意足')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1a1a0a')
          .backgroundColor('#f9ca24')
          .borderRadius(20)
          .height(34)
          .padding({ left: 20, right: 20 })
          .onClick(() => {
            this.controller.close()
          })
      }
      .margin({ bottom: 26 })
    }
    .width('100%')
  }
}
