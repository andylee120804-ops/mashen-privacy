import { PrayerViewModel } from '../viewmodels/PrayerViewModel'
import { EnrichViewModel } from '../viewmodels/EnrichViewModel'
import { DeityArrayView } from '../components/DeityArrayView'
import { WorshipperView } from '../components/WorshipperView'
import { IncenseAltarView } from '../components/IncenseAltarView'
import { FloatingBlessing } from '../components/FloatingBlessing'
import { ParticleCanvas, ParticleType } from '../components/ParticleCanvas'
import { AnimController } from '../engine/AnimController'
import { AnimStage, FIVE_DEITIES, DEFAULT_KOWTOW_COUNT, BLESSING_PHRASES, FULFILL_PHRASES } from '../model/PrayerTypes'
import { AudioManager } from '../service/AudioManager'
import { KowtowFrameCache } from '../service/KowtowFrameCache'
import { CloudService } from '../service/CloudService'
import { router } from '@kit.ArkUI'
import { vibrator } from '@kit.SensorServiceKit'

/** 飘字祝福条目 */
interface FloatingBlessingItem {
  id: number
  text: string
  offsetX: number
  delayMs: number
}

@Entry
@Component
struct PrayerCard {
  @StorageLink('viewModel') viewModel: PrayerViewModel = new PrayerViewModel()
  @State animStage: AnimStage = AnimStage.APPEAR
  @State appearProgress: number = 0
  @State incenseProgress: number = 0
  @State bowFrame: number = 0
  @State blessingProgress: number = 0
  @State showGoldParticles: boolean = false
  @State showSmokeParticles: boolean = false
  @State kowtowDoneCount: number = 0
  @State floatingBlessings: FloatingBlessingItem[] = []
  @State isBowing: boolean = false
  @State canFinish: boolean = false
  @State autoKowtowRemaining: number = 0
  /** 还愿模式：从还愿页导航进来时携带的心愿 ID */
  @State fulfillWishId: string = ''
  private animController: AnimController = new AnimController()
  private isRepeat: boolean = false
  private lastSoundStage: AnimStage | null = null
  private lastIncenseIdx: number = -1
  private kowtowTimerId: number = -1
  private nextBlessingId: number = 0
  private autoKowtowTimerId: number = -1
  /** 页面正在离开（跳过/完成导航后置 true，阻止 orphan 定时器继续触发副作用） */
  private isLeaving: boolean = false

  aboutToAppear(): void {
    const params = this.getUIContext().getRouter().getParams() as Record<string, Object>
    if (params && params['repeat'] === true) {
      this.isRepeat = true
      this.animController.setSpeedMultiplier(1.5)
    }
    // 还愿模式：从还愿页导航进来，携带 fulfillWishId
    if (params && params['fulfillWishId']) {
      this.fulfillWishId = params['fulfillWishId'] as string
      // 还愿模式使用上次祈福者姓名（跳过了 NameCard）
      const lastName: string = AppStorage.get<string>('lastPrayerName') || '善信'
      this.viewModel.confirmName(lastName)
    }
    this.lastSoundStage = null
    this.lastIncenseIdx = -1
    AudioManager.getInstance().startBgm()
    this.startAnimation()
    // 兜底预解码磕头帧（通常 NameCard 已启动，幂等），
    // 后台 native 解码不占主线程，不影响入场动画与点击完成时延
    const ctx = this.getUIContext().getHostContext()
    if (ctx) {
      KowtowFrameCache.preload(ctx)
    }
  }

  aboutToDisappear(): void {
    this.isLeaving = true
    if (this.kowtowTimerId !== -1) {
      clearInterval(this.kowtowTimerId)
      this.kowtowTimerId = -1
    }
    if (this.autoKowtowTimerId !== -1) {
      clearTimeout(this.autoKowtowTimerId)
      this.autoKowtowTimerId = -1
    }
    this.animController.stop()
  }

  private startAnimation(): void {
    this.animController.on('progress', (stage: AnimStage, progress: number) => {
      if (stage !== this.lastSoundStage) {
        this.lastSoundStage = stage
        this.onStageEnter(stage)
      }
      this.animStage = stage
      switch (stage) {
        case AnimStage.APPEAR: {
          this.appearProgress = progress
          this.showGoldParticles = true
          break
        }
        case AnimStage.INCENSE: {
          this.appearProgress = 1
          this.incenseProgress = progress
          this.showSmokeParticles = true
          const incIdx = Math.min(Math.floor(progress * 3), 2)
          if (incIdx !== this.lastIncenseIdx) {
            this.lastIncenseIdx = incIdx
            AudioManager.getInstance().playSound('incense')
          }
          break
        }
        case AnimStage.KOWTOW: {
          this.incenseProgress = 1
          this.bowFrame = 0
          this.showGoldParticles = true
          // 初始3次自动磕头，无需手点
          this.autoKowtowRemaining = DEFAULT_KOWTOW_COUNT
          setTimeout(() => this.performAutoKowtow(), 600)
          break
        }
        case AnimStage.BLESSING: {
          this.appearProgress = 1
          this.bowFrame = 0
          this.blessingProgress = progress
          this.showGoldParticles = true
          break
        }
      }
    })

    this.animController.on('complete', (stage: AnimStage) => {
      if (stage === AnimStage.BLESSING) {
        this.viewModel.onAnimationComplete(this.kowtowDoneCount)
        AudioManager.getInstance().stopBgm()

        if (this.fulfillWishId) {
          // 还愿模式：磕头完成后标记心愿达成
          CloudService.fulfillWish(this.fulfillWishId).then((ok: boolean) => {
            if (ok) {
              const vm: EnrichViewModel = AppStorage.get<EnrichViewModel>('enrichViewModel') as EnrichViewModel
              if (vm) { vm.incWishFulfilled() }
              // 通知还愿页刷新列表
              AppStorage.setOrCreate('wishFulfilledAt', Date.now())
            }
          }).catch((e: Object) => {
            console.error('[PrayerCard] fulfillWish failed:', JSON.stringify(e))
          })
          this.getUIContext().getPromptAction().showToast({ message: '🙏 还愿成功！' })
          // 延迟返回，让 toast 可见（点击完成时延预算 ≤2000ms：BLESSING 1500 + 700 + 路由 < 2400）
          setTimeout(() => {
            this.getUIContext().getRouter().back()
          }, 700)
        } else {
          // 正常祈福模式：导航到祝福卡
          setTimeout(() => {
            this.getUIContext().getRouter().replaceUrl({ url: 'pages/BlessingCard' }, router.RouterMode.Standard)
          }, 0)
        }
      }
    })

    this.animController.start()
  }

  private onStageEnter(stage: AnimStage): void {
    if (stage === AnimStage.APPEAR) {
      AudioManager.getInstance().playSound('appear')
    } else if (stage === AnimStage.BLESSING) {
      AudioManager.getInstance().playSound('blessing')
    }
  }

  private vibrate(duration: number): void {
    try {
      vibrator.startVibration({
        type: 'time',
        duration: duration
      }, { id: 0, usage: 'unknown' })
    } catch (err) {
      console.error('Vibration failed:', JSON.stringify(err))
    }
  }

  // 按一次按钮 = 一次完整磕头（51 帧视频抽帧序列逐帧推进）
  // 每帧 40ms（25fps），总时长 2.0s。帧率与时长约束：AGC 点击完成时延标准 2400ms，
  // 动画本身须控制在 ~2s 内（留测量开销余量）。帧序列完整保留，仅提高播放速率，
  // 比原 75ms/帧（13fps）更流畅。勿再调大帧间隔！
  // 正向下拜 -> 触地伏地停留（不起身）；再按从站立(0)重新开始。
  private performKowtow(): void {
    if (this.isBowing || this.isLeaving) return
    this.isBowing = true
    this.kowtowDoneCount += 1
    if (this.kowtowDoneCount >= DEFAULT_KOWTOW_COUNT) {
      this.canFinish = true
    }
    AudioManager.getInstance().playSound('kowtow')
    this.vibrate(60)
    this.spawnFloatingBlessing()

    // 重置到站立（如果之前停在触地状态）
    this.bowFrame = 0

    // 单 interval 替代 50 个 setTimeout，减少主线程定时器注册开销
    if (this.kowtowTimerId !== -1) {
      clearInterval(this.kowtowTimerId)
    }
    let frame = 0
    this.kowtowTimerId = setInterval(() => {
      frame++
      if (frame <= 50) {
        this.bowFrame = frame
      } else {
        clearInterval(this.kowtowTimerId)
        this.kowtowTimerId = -1
        this.isBowing = false
      }
    }, 40)
  }

  /** 自动磕头：初始3次无需手点，依次播放 */
  private performAutoKowtow(): void {
    if (this.autoKowtowRemaining <= 0 || this.isLeaving) return
    this.performKowtow()
    this.autoKowtowRemaining -= 1
    // 每次磕头动画 50帧×40ms + 40ms = 2040ms，再加 500ms 停顿
    const kowtowDurationMs = 50 * 40 + 40
    const pauseBetweenMs = 500
    if (this.autoKowtowRemaining > 0) {
      this.autoKowtowTimerId = setTimeout(() => {
        this.autoKowtowTimerId = -1
        this.performAutoKowtow()
      }, kowtowDurationMs + pauseBetweenMs)
    }
  }

  private spawnFloatingBlessing(): void {
    // 还愿模式飘答谢词，普通祈福飘麻将喜话；每次磕头飘 2~3 条，狠狠说喜话
    const phrases: string[] = this.fulfillWishId ? FULFILL_PHRASES : BLESSING_PHRASES
    const count = 2 + Math.floor(Math.random() * 2) // 2 or 3
    const newItems: FloatingBlessingItem[] = []
    for (let i = 0; i < count; i++) {
      const id = this.nextBlessingId++
      const idx = Math.floor(Math.random() * phrases.length)
      // 水平偏移：-100 ~ +100 px，多条飘字大幅错开
      const offsetX = Math.floor(Math.random() * 201) - 100
      // 每条延迟不同，依次飘出而不是同时涌出
      const delayMs = i * 300
      newItems.push({ id, text: phrases[idx], offsetX, delayMs })
    }
    // 一次性加入全部飘字，用单 setTimeout 批量移除，减少定时器注册开销
    // 移除时机与 FloatingBlessing 动画时长对齐：phase1(150ms) + phase2(1200ms) + 50ms 余量
    this.floatingBlessings = [...this.floatingBlessings, ...newItems]
    const maxDelay = newItems[newItems.length - 1].delayMs
    const itemIds = newItems.map(item => item.id)
    setTimeout(() => {
      this.floatingBlessings = this.floatingBlessings.filter(b => !itemIds.includes(b.id))
    }, 1400 + maxDelay)
  }

  private finishPrayer(): void {
    if (!this.canFinish) return
    this.animController.proceedToBlessing()
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#1a1a0a')
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])

      ParticleCanvas({
        particleType: ParticleType.GOLD,
        isActive: this.showGoldParticles
      })

      ParticleCanvas({
        particleType: ParticleType.SMOKE,
        isActive: this.showSmokeParticles
      })

      // 五神弧形阵（上方·远景）
      Column() {
        DeityArrayView({
          deities: FIVE_DEITIES,
          highlightId: this.viewModel.todayDeity.id,
          appearProgress: this.appearProgress,
          blessingProgress: this.blessingProgress
        })
      }
      .width('100%')
      .height('50%')
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Center)

      // 顶部祈福祝语（神明最上方，页面加载即显示，为祈福者加持好运）
      // 拆成两短行：每行宽度都够窄，不会遮住右上角"跳过"按钮
      Column() {
        Text(this.fulfillWishId ? '✦ 诚心还愿 ✦' : '✦ 心诚则灵 ✦')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#f9ca24')
        Text(this.fulfillWishId ? '磕头还愿 · 谢谢神恩' : '诚心叩拜 · 牌运亨通')
          .fontSize(12)
          .fontColor('rgba(253, 246, 227, 0.7)')
          .margin({ top: 4 })
      }
      .position({ x: '50%', y: 64 })
      .translate({ x: '-50%', y: '0' })

      // 香炉（进香/磕头阶段·近景）
      if (this.animStage === AnimStage.INCENSE || this.animStage === AnimStage.KOWTOW) {
        IncenseAltarView({
          lightProgress: this.incenseProgress
        })
          .position({ x: '50%', y: '70%' })
          .translate({ x: '-50%', y: '-50%' })
      }

      // 磕头阶段：小人居中于香炉下方，按钮行独立定位在 88% 高度
      if (this.animStage === AnimStage.KOWTOW) {
        WorshipperView({
          bowFrame: this.bowFrame
        })
          .position({ x: '50%', y: '76%' })
          .translate({ x: '-50%', y: '-50%' })

        // 飘字层：全屏，飘字在祈福者上方升起
        Stack() {
          ForEach(this.floatingBlessings, (b: FloatingBlessingItem) => {
            FloatingBlessing({ text: b.text, offsetX: b.offsetX, delayMs: b.delayMs })
          }, (b: FloatingBlessingItem) => b.id.toString())
        }
        .width('100%')
        .height('100%')
        .position({ x: '50%', y: '70%' })
        .translate({ x: '-50%', y: '-50%' })

        // 磕头计数（香炉下方右侧，避开神明）
        Text(`已磕头 ${this.kowtowDoneCount} 次`)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#f9ca24')
          .position({ x: '78%', y: '63%' })
          .translate({ x: '-50%', y: '-50%' })

        // 交互按钮区（y 90%：沉浸式全屏下按钮底部需避让系统导航条（≥28vp））
        Row() {
          Button('磕头')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.autoKowtowRemaining > 0 ? '#fdf6e3' : '#1a1a0a')
            .backgroundColor(this.autoKowtowRemaining > 0 ? 'rgba(249,202,36,0.4)' : '#f9ca24')
            .borderRadius(28)
            .height(55)
            .padding({ left: 40, right: 40 })
            .enabled(this.autoKowtowRemaining === 0 && !this.isBowing)
            .onClick(() => this.performKowtow())

          if (this.canFinish && this.autoKowtowRemaining === 0) {
            Button(this.fulfillWishId ? '完成还愿' : '完成祈福')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#f9ca24')
              .backgroundColor('rgba(249,202,36,0.12)')
              .border({ width: 1, color: '#f9ca24' })
              .borderRadius(28)
              .height(55)
              .padding({ left: 24, right: 24 })
              .margin({ left: 16 })
              .onClick(() => this.finishPrayer())
          }
        }
        .position({ x: '50%', y: '90%' })
        .translate({ x: '-50%', y: '-50%' })
      }

      // 进香提示
      if (this.animStage === AnimStage.INCENSE) {
        Text('三炷香 · 敬献麻神')
          .fontSize(14)
          .fontColor('rgba(253, 246, 227, 0.6)')
          .position({ x: '50%', y: '76%' })
          .translate({ x: '-50%', y: '-50%' })
      }

      // 跳过
      Button('跳过')
        .fontSize(12)
        .fontColor('rgba(253, 246, 227, 0.5)')
        .backgroundColor('rgba(255, 255, 255, 0.05)')
        .borderRadius(15)
        .padding({ left: 16, right: 16, top: 6, bottom: 6 })
        .position({ x: '85%', y: 64 })
        .translate({ x: '-50%', y: '0' })
        .onClick(() => {
          this.animController.skip()
        })
    }
    .width('100%')
    .height('100%')
  }
}
