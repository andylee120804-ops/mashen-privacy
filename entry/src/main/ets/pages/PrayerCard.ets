import { PrayerViewModel } from '../viewmodels/PrayerViewModel'
import { DeityView } from '../components/DeityView'
import { ParticleCanvas, ParticleType } from '../components/ParticleCanvas'
import { AnimController } from '../engine/AnimController'
import { AnimStage } from '../model/PrayerTypes'
import { router } from '@kit.ArkUI'
import { vibrator } from '@kit.SensorServiceKit'

@Entry
@Component
struct PrayerCard {
  @Consume viewModel: PrayerViewModel
  @State animStage: AnimStage = AnimStage.APPEAR
  @State deityScale: number = 0
  @State deityOpacity: number = 0
  @State incenseOpacity: number = 0
  @State showGoldParticles: boolean = false
  @State showSmokeParticles: boolean = false
  @State showKowtowHint: boolean = false
  private animController: AnimController = new AnimController()
  private isRepeat: boolean = false

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>
    if (params && params['repeat'] === true) {
      this.isRepeat = true
      this.animController.setSpeedMultiplier(1.5)
    }
    this.startAnimation()
  }

  private startAnimation(): void {
    this.animController.on('progress', (stage: AnimStage, progress: number) => {
      this.animStage = stage
      switch (stage) {
        case AnimStage.APPEAR:
          this.deityScale = progress
          this.deityOpacity = progress
          this.showGoldParticles = true
          break
        case AnimStage.INCENSE:
          this.incenseOpacity = progress
          this.showSmokeParticles = true
          break
        case AnimStage.KOWTOW:
          this.showKowtowHint = true
          this.showGoldParticles = true
          break
        case AnimStage.BLESSING:
          this.deityScale = 1.0 + progress * 0.2
          this.showGoldParticles = true
          break
      }
    })

    this.animController.on('complete', (stage: AnimStage) => {
      if (stage === AnimStage.BLESSING) {
        this.viewModel.onAnimationComplete()
        router.replaceUrl({ url: 'pages/BlessingCard' })
      }
    })

    this.animController.start()
  }

  private onKowtowClick(): void {
    try {
      vibrator.startVibration({
        type: 'time',
        duration: 50
      })
    } catch (err) {
      console.error('Vibration failed:', JSON.stringify(err))
    }
    this.animController.triggerKowtow()
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#1a1a0a')

      ParticleCanvas({
        particleType: ParticleType.GOLD,
        isActive: this.showGoldParticles
      })

      ParticleCanvas({
        particleType: ParticleType.SMOKE,
        isActive: this.showSmokeParticles
      })

      Column() {
        DeityView({
          deity: this.viewModel.todayDeity,
          scale: this.deityScale,
          opacity: this.deityOpacity
        })
      }
      .width('100%')
      .height('60%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      if (this.animStage === AnimStage.INCENSE || this.animStage === AnimStage.KOWTOW) {
        Column() {
          Text('🪔')
            .fontSize(36)
            .opacity(this.incenseOpacity)
          Text('三炷香已点燃')
            .fontSize(13)
            .fontColor('rgba(253, 246, 227, 0.5)')
            .opacity(this.incenseOpacity)
        }
        .position({ x: '50%', y: '75%' })
        .translate({ x: '-50%', y: '-50%' })
      }

      if (this.showKowtowHint) {
        Column() {
          Text('🙇 叩拜麻神')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#f9ca24')
          Text('点击屏幕磕头祈福')
            .fontSize(12)
            .fontColor('rgba(253, 246, 227, 0.5)')
            .margin({ top: 4 })
        }
        .position({ x: '50%', y: '88%' })
        .translate({ x: '-50%', y: '-50%' })
        .onClick(() => this.onKowtowClick())
      }

      Button('跳过')
        .fontSize(12)
        .fontColor('rgba(253, 246, 227, 0.4)')
        .backgroundColor('rgba(255, 255, 255, 0.05)')
        .borderRadius(15)
        .padding({ left: 16, right: 16, top: 6, bottom: 6 })
        .position({ x: '85%', y: 48 })
        .onClick(() => {
          this.animController.skip()
        })
    }
    .width('100%')
    .height('100%')
    .onClick(() => {
      if (this.animStage === AnimStage.KOWTOW) {
        this.onKowtowClick()
      }
    })
  }
}