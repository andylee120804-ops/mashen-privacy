import { AnimStage } from '../model/PrayerTypes'

export type AnimProgressCallback = (stage: AnimStage, progress: number) => void
export type AnimCompleteCallback = (stage: AnimStage) => void

export class AnimController {
  private currentStage: AnimStage = AnimStage.APPEAR
  private isPlaying: boolean = false
  private speedMultiplier: number = 1.0
  private timerId: number = -1
  private elapsedMs: number = 0
  private blessingStarted: boolean = false
  private readonly stageDurations: Record<AnimStage, number> = {
    [AnimStage.APPEAR]: 1600,   // 五神弧形绽放
    [AnimStage.INCENSE]: 2400,  // 三炷香逐根点燃（0.8s/根）
    [AnimStage.KOWTOW]: 0,      // 交互阶段，不自动推进
    // 五神齐放金光。时长约束：AGC 点击完成时延标准 2400ms，
    // 实测链路 = 本阶段 + 跳转/BlessingCard 首帧 ~400ms，故定 1500ms（合计 ~1900ms，留 500ms 余量）。
    // 祝福音效由 SoundPool fire-and-forget 播放，与页面生命周期无关，
    // 跳转后余音自然延续覆盖金榜入场，无需靠延长本阶段实现。勿再调大！
    [AnimStage.BLESSING]: 1500
  }
  private onProgress: AnimProgressCallback | null = null
  private onComplete: AnimCompleteCallback | null = null

  get totalDuration(): number {
    return Object.values(this.stageDurations).reduce((a, b) => a + b, 0) / this.speedMultiplier
  }

  setSpeedMultiplier(multiplier: number): void {
    if (multiplier <= 0 || !isFinite(multiplier)) {
      this.speedMultiplier = 1.0
      return
    }
    this.speedMultiplier = multiplier
  }

  on(event: 'progress' | 'complete', callback: AnimProgressCallback | AnimCompleteCallback): void {
    if (event === 'progress') {
      this.onProgress = callback as AnimProgressCallback
    } else {
      this.onComplete = callback as AnimCompleteCallback
    }
  }

  start(): void {
    this.stop()
    this.isPlaying = true
    this.elapsedMs = 0
    this.blessingStarted = false
    this.currentStage = AnimStage.APPEAR
    this.runLoop()
  }

  // 交互阶段结束，用户点"完成祈福"后推进到 BLESSING
  proceedToBlessing(): void {
    if (this.blessingStarted) return
    this.clearTimer()
    this.blessingStarted = true
    this.elapsedMs = this.stageDurations[AnimStage.APPEAR] + this.stageDurations[AnimStage.INCENSE]
    this.isPlaying = true
    this.currentStage = AnimStage.BLESSING
    this.runLoop()
  }

  skip(): void {
    this.clearTimer()
    this.isPlaying = false
    try {
      this.onComplete?.(AnimStage.BLESSING)
    } catch (err) {
      console.error('AnimController onComplete error:', JSON.stringify(err))
    }
  }

  stop(): void {
    this.clearTimer()
    this.isPlaying = false
  }

  reset(): void {
    this.stop()
    this.currentStage = AnimStage.APPEAR
    this.elapsedMs = 0
    this.blessingStarted = false
    this.speedMultiplier = 1.0
    this.onProgress = null
    this.onComplete = null
  }

  private clearTimer(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId)
      this.timerId = -1
    }
  }

  private runLoop(): void {
    if (!this.isPlaying) return

    this.timerId = setInterval(() => {
      if (!this.isPlaying) {
        this.clearTimer()
        return
      }

      this.elapsedMs += 16 * this.speedMultiplier

      const incenseEnd = this.stageDurations[AnimStage.APPEAR] + this.stageDurations[AnimStage.INCENSE]

      // 进香结束 → 进入交互磕头阶段，暂停等待用户
      if (!this.blessingStarted && this.elapsedMs >= incenseEnd) {
        this.currentStage = AnimStage.KOWTOW
        this.clearTimer()
        this.isPlaying = false
        try {
          this.onProgress?.(AnimStage.KOWTOW, 0)
        } catch (err) {
          console.error('AnimController progress callback error:', JSON.stringify(err))
        }
        return
      }

      // 完成祈福后跑 BLESSING
      if (this.blessingStarted) {
        const blessingDur = this.stageDurations[AnimStage.BLESSING]
        const blessingElapsed = this.elapsedMs - incenseEnd
        const progress = Math.min(blessingElapsed / blessingDur, 1.0)
        if (this.currentStage !== AnimStage.BLESSING) {
          this.currentStage = AnimStage.BLESSING
        }
        try {
          this.onProgress?.(AnimStage.BLESSING, progress)
        } catch (err) {
          console.error('AnimController progress callback error:', JSON.stringify(err))
        }
        if (progress >= 1.0) {
          this.clearTimer()
          this.isPlaying = false
          try {
            this.onComplete?.(AnimStage.BLESSING)
          } catch (err) {
            console.error('AnimController complete callback error:', JSON.stringify(err))
          }
        }
        return
      }

      // APPEAR / INCENSE 正常推进
      let accumulated = 0
      for (const stage of [AnimStage.APPEAR, AnimStage.INCENSE]) {
        const duration = this.stageDurations[stage]
        if (this.elapsedMs < accumulated + duration) {
          const stageElapsed = this.elapsedMs - accumulated
          const progress = Math.min(stageElapsed / duration, 1.0)
          if (this.currentStage !== stage) {
            this.currentStage = stage
          }
          try {
            this.onProgress?.(stage, progress)
          } catch (err) {
            console.error('AnimController progress callback error:', JSON.stringify(err))
          }
          return
        }
        accumulated += duration
      }
    }, 16)
  }
}