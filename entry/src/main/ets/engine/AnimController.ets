// entry/src/main/ets/engine/AnimController.ets
import { AnimStage } from '../model/PrayerTypes'

/** 动画进度回调 */
export type AnimProgressCallback = (stage: AnimStage, progress: number) => void

/** 动画完成回调 */
export type AnimCompleteCallback = (stage: AnimStage) => void

export class AnimController {
  private currentStage: AnimStage = AnimStage.APPEAR
  private isPlaying: boolean = false
  private speedMultiplier: number = 1.0
  private timerId: number = -1
  private elapsedMs: number = 0
  private stageDurations: Record<AnimStage, number> = {
    [AnimStage.APPEAR]: 1500,
    [AnimStage.INCENSE]: 2500,
    [AnimStage.KOWTOW]: 2500,
    [AnimStage.BLESSING]: 1500
  }
  private onProgress: AnimProgressCallback | null = null
  private onComplete: AnimCompleteCallback | null = null

  /** 总时长 */
  get totalDuration(): number {
    return Object.values(this.stageDurations).reduce((a, b) => a + b, 0) / this.speedMultiplier
  }

  /** 设置倍速（再拜一次用 1.5x） */
  setSpeedMultiplier(multiplier: number): void {
    this.speedMultiplier = multiplier
  }

  /** 注册回调 */
  on(event: 'progress' | 'complete', callback: AnimProgressCallback | AnimCompleteCallback): void {
    if (event === 'progress') {
      this.onProgress = callback as AnimProgressCallback
    } else {
      this.onComplete = callback as AnimCompleteCallback
    }
  }

  /** 开始播放 */
  start(): void {
    this.isPlaying = true
    this.elapsedMs = 0
    this.currentStage = AnimStage.APPEAR
    this.runLoop()
  }

  /** 跳过动画 */
  skip(): void {
    this.stop()
    this.onComplete?.(AnimStage.BLESSING)
  }

  /** 停止动画 */
  stop(): void {
    this.isPlaying = false
    if (this.timerId !== -1) {
      clearInterval(this.timerId)
      this.timerId = -1
    }
  }

  /** 触发磕头（用户交互） */
  triggerKowtow(): boolean {
    if (this.currentStage !== AnimStage.KOWTOW) return false
    this.onComplete?.(AnimStage.KOWTOW)
    return true
  }

  private runLoop(): void {
    if (!this.isPlaying) return

    this.timerId = setInterval(() => {
      this.elapsedMs += 16 * this.speedMultiplier // ~60fps

      // 确定当前阶段
      let accumulated = 0
      for (const stage of [AnimStage.APPEAR, AnimStage.INCENSE, AnimStage.KOWTOW, AnimStage.BLESSING]) {
        const duration = this.stageDurations[stage]
        if (this.elapsedMs < accumulated + duration) {
          const stageElapsed = this.elapsedMs - accumulated
          const progress = Math.min(stageElapsed / duration, 1.0)

          if (this.currentStage !== stage) {
            this.currentStage = stage
          }

          this.onProgress?.(stage, progress)
          return
        }
        accumulated += duration
      }

      // 动画全部完成
      this.stop()
      this.onComplete?.(AnimStage.BLESSING)
    }, 16)
  }
}