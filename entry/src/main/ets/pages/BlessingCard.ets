import { PrayerViewModel } from '../viewmodels/PrayerViewModel'
import { ParticleCanvas, ParticleType } from '../components/ParticleCanvas'
import { TipModal } from '../components/TipModal'
import { AudioManager } from '../service/AudioManager'
import { router } from '@kit.ArkUI'

/**
 * 叩拜结束 · 赐福结算页。
 *
 * 视觉定为「金榜赐福」：红底金边神位令牌 + 双框祝福金榜 + 「賜」字朱印，
 * 搭配分阶段入场动画（令牌 -> 金榜 -> 朱印 -> 操作），把"狠狠的祝福"砸出来。
 */
@Entry
@Component
struct BlessingCard {
  @StorageLink('viewModel') viewModel: PrayerViewModel = new PrayerViewModel()
  @State showFirework: boolean = false
  @State headerShown: boolean = false
  @State blessingShown: boolean = false
  @State sealShown: boolean = false
  @State buttonsShown: boolean = false
  // 惰性创建弹窗控制器：避免页面入场时提前构建 TipModal 子树，降低点击完成时延
  private tipDialogController: CustomDialogController | null = null

  private openTipDialog(): void {
    if (this.tipDialogController === null) {
      this.tipDialogController = new CustomDialogController({
        builder: TipModal({}),
        autoCancel: true,
        alignment: DialogAlignment.Center,
        customStyle: true
      })
    }
    this.tipDialogController.open()
  }

  aboutToAppear(): void {
    // 依次触发各区块入场动画，节奏：令牌 -> 烟花/金榜 -> 朱印 -> 操作
    // 时延优化：整体排期压缩至 ~1.1s 内完成（原 1.86s），确保点击完成时延达标
    setTimeout(() => {
      this.getUIContext().animateTo({ duration: 400, curve: Curve.EaseOut }, () => { this.headerShown = true })
    }, 60)
    setTimeout(() => { this.showFirework = true }, 180)
    setTimeout(() => {
      this.getUIContext().animateTo({ duration: 600, curve: Curve.EaseOut }, () => { this.blessingShown = true })
    }, 300)
    setTimeout(() => {
      this.getUIContext().animateTo({ duration: 340, curve: Curve.EaseOut }, () => { this.sealShown = true })
    }, 620)
    setTimeout(() => {
      this.getUIContext().animateTo({ duration: 380, curve: Curve.EaseOut }, () => { this.buttonsShown = true })
    }, 760)
  }

  build() {
    Stack() {
      // 背景（延伸至安全区，消除白边）
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#1a1a0a')
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])

      // 喜庆暖红底晕，把暗色背景往"红"里拉
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(192, 57, 43, 0.08)')
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])

      ParticleCanvas({
        particleType: ParticleType.FIREWORK,
        isActive: this.showFirework
      })

      // GOLD 粒子随烟花一同出现（300ms 后），减轻首帧渲染压力
      ParticleCanvas({
        particleType: ParticleType.GOLD,
        isActive: this.showFirework
      })

      Column() {
        // ── 顶部装饰文字 ──
        Text('✦  敕赐 · 五路财神 · 金牌赐福  ✦')
          .fontSize(12)
          .fontColor('rgba(249, 202, 36, 0.6)')
          .letterSpacing(2)
          .opacity(this.headerShown ? 1 : 0)
          .margin({ bottom: 14 })

        // ── 主位令牌（红底金字金边）──
        Row() {
          Text(`🪷  ${this.viewModel.todayDeity.name} · ${this.viewModel.todayDeity.direction}主位  🪷`)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#fdf6e3')
            .letterSpacing(1)
        }
        .padding({ left: 24, right: 24, top: 10, bottom: 10 })
        .backgroundColor('#c0392b')
        .border({ width: 1.5, color: '#f9ca24', radius: 6 })
        .shadow({ radius: 18, color: 'rgba(192, 57, 43, 0.6)', offsetY: 4 })
        .opacity(this.headerShown ? 1 : 0)
        .scale({ x: this.headerShown ? 1 : 0.9, y: this.headerShown ? 1 : 0.9 })
        .margin({ bottom: 22 })

        // ── 祝福金榜（HERO）── 朱印贴在右下角
        Stack({ alignContent: Alignment.BottomEnd }) {
          Column() {
            Column() {
              // 状态条：祈福已成 · 麻神已准
              Text('🎊  祈福已成 · 麻神已准  🎊')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor('#f9ca24')
                .letterSpacing(1)
                .textShadow({ radius: 10, color: 'rgba(249,202,36,0.6)', offsetX: 0, offsetY: 0 })
                .margin({ bottom: 12 })

              // 上分隔线
              Row()
                .width('62%')
                .height(1)
                .backgroundColor('rgba(249, 202, 36, 0.35)')
                .margin({ bottom: 18 })

              // 贺词大字横批：招财进宝 -- 视觉焦点，砸出"赢钱"的祝福
              Text('招财进宝')
                .fontSize(38)
                .fontWeight(FontWeight.Bold)
                .fontColor('#f9ca24')
                .textShadow({ radius: 22, color: 'rgba(231, 76, 60, 0.95)', offsetX: 0, offsetY: 0 })
                .letterSpacing(14)
                .margin({ bottom: 12 })

              // 贺词与正文之间的钻石分隔
              Text('◆  ◆  ◆')
                .fontSize(11)
                .fontColor('rgba(249, 202, 36, 0.55)')
                .letterSpacing(6)
                .margin({ bottom: 14 })

              // 祝福正文 -- 略减字号与光晕，让贺词成为视觉焦点
              Text(this.viewModel.blessing)
                .fontSize(22)
                .fontWeight(FontWeight.Medium)
                .fontColor('#f9ca24')
                .textShadow({ radius: 10, color: 'rgba(231, 76, 60, 0.5)', offsetX: 0, offsetY: 0 })
                .textAlign(TextAlign.Center)
                .width('100%')
                .lineHeight(38)
                .letterSpacing(1)
                .margin({ bottom: 14 })

              // 正文与尾联之间的钻石分隔
              Text('◆  ◆  ◆')
                .fontSize(11)
                .fontColor('rgba(249, 202, 36, 0.55)')
                .letterSpacing(6)
                .margin({ bottom: 12 })

              // 尾联：金玉满堂 · 福禄双至 -- 兼顾财富与幸福
              Text('金玉满堂  ·  福禄双至')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor('#f9ca24')
                .letterSpacing(4)
                .textShadow({ radius: 8, color: 'rgba(231, 76, 60, 0.55)', offsetX: 0, offsetY: 0 })

              // 下分隔线
              Row()
                .width('62%')
                .height(1)
                .backgroundColor('rgba(249, 202, 36, 0.35)')
                .margin({ top: 16, bottom: 14 })

              // 麻将吉牌
              Text('🀇   🀅   🀄   🀅   🀇')
                .fontSize(22)
                .letterSpacing(6)
                .opacity(0.85)
            }
            .width('100%')
            .padding({ left: 22, right: 22, top: 22, bottom: 18 })
            .alignItems(HorizontalAlign.Center)
            .border({ width: 1, color: 'rgba(231, 76, 60, 0.75)', radius: 10 })
          }
          .width('100%')
          .backgroundColor('rgba(26, 26, 10, 0.55)')
          .border({ width: 2, color: '#f9ca24', radius: 12 })
          .padding(3)

          // 「賜」字朱印：从上方落下并轻微旋转，盖在金榜右下角
          Text('賜')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#fdf6e3')
            .textAlign(TextAlign.Center)
            .width(46)
            .height(46)
            .backgroundColor('#c0392b')
            .border({ width: 2, color: '#fdf6e3', radius: 4 })
            .rotate({ angle: this.sealShown ? -12 : 0 })
            .scale({ x: this.sealShown ? 1 : 1.5, y: this.sealShown ? 1 : 1.5 })
            .opacity(this.sealShown ? 0.95 : 0)
            .margin({ right: 14, bottom: 14 })
        }
        .width('86%')
        .opacity(this.blessingShown ? 1 : 0)
        .scale({ x: this.blessingShown ? 1 : 0.85, y: this.blessingShown ? 1 : 0.85 })
        .margin({ bottom: 20 })

        // ── 诚心徽章：叩拜次数换来的福报 ──
        Text(`🙏  诚心叩拜 ${this.viewModel.kowtowCount} 次 · 福报已生`)
          .fontSize(12)
          .fontColor('rgba(253, 246, 227, 0.6)')
          .letterSpacing(1)
          .opacity(this.sealShown ? 1 : 0)
          .margin({ bottom: 22 })

        // ── 操作按钮组 ──
        Row() {
          Button('🙇  再拜一次')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#f9ca24')
            .backgroundColor('rgba(249, 202, 36, 0.1)')
            .border({ width: 1, color: 'rgba(249, 202, 36, 0.45)', radius: 25 })
            .padding({ left: 26, right: 26, top: 11, bottom: 11 })
            .onClick(() => {
              this.viewModel.resetPrayer()
              // 延迟导航到下一帧，让按钮点击反馈先渲染
              setTimeout(() => {
                this.getUIContext().getRouter().replaceUrl({
                  url: 'pages/PrayerCard',
                  params: { repeat: true }
                }, router.RouterMode.Standard)
              }, 0)
            })

          Button('🧧  供奉麻神')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1a1a0a')
            .backgroundColor('#f9ca24')
            .borderRadius(25)
            .shadow({ radius: 14, color: 'rgba(249, 202, 36, 0.45)', offsetY: 3 })
            .padding({ left: 26, right: 26, top: 11, bottom: 11 })
            .margin({ left: 14 })
            .onClick(() => this.openTipDialog())
        }
        .opacity(this.buttonsShown ? 1 : 0)
        .translate({ y: this.buttonsShown ? 0 : 12 })
        .margin({ bottom: 18 })

        // ── 返回首页 ──
        Button('返回首页')
          .fontSize(13)
          .fontColor('rgba(253, 246, 227, 0.45)')
          .backgroundColor('transparent')
          .opacity(this.buttonsShown ? 1 : 0)
          .onClick(() => {
            this.viewModel.resetPrayer()
            // 延迟音频停止和导航到下一帧，让按钮点击反馈先渲染
            setTimeout(() => {
              AudioManager.getInstance().stopBgm()
              this.getUIContext().getRouter().clear()
              this.getUIContext().getRouter().pushUrl({ url: 'pages/MainTabs' }, router.RouterMode.Standard)
            }, 0)
          })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
  }
}
