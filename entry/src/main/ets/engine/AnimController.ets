import { AnimStage } from '../model/PrayerTypes'

export type AnimProgressCallback = (stage: AnimStage, progress: number) => void
export type AnimCompleteCallback = (stage: AnimStage) => void

export class AnimController {
  private currentStage: AnimStage = AnimStage.APPEAR
  private isPlaying: boolean = false
  private speedMultiplier: number = 1.0
  private timerId: number = -1
  private elapsedMs: number = 0
  private readonly stageDurations: Record<AnimStage, number> = {
    [AnimStage.APPEAR]: 1500,
    [AnimStage.INCENSE]: 2500,
    [AnimStage.KOWTOW]: 2500,
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
    this.currentStage = AnimStage.APPEAR
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

  triggerKowtow(): boolean {
    if (this.currentStage !== AnimStage.KOWTOW) return false
    try {
      this.onComplete?.(AnimStage.KOWTOW)
    } catch (err) {
      console.error('AnimController kowtow callback error:', JSON.stringify(err))
    }
    return true
  }

  reset(): void {
    this.stop()
    this.currentStage = AnimStage.APPEAR
    this.elapsedMs = 0
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

      let accumulated = 0
      for (const stage of [AnimStage.APPEAR, AnimStage.INCENSE, AnimStage.KOWTOW, AnimStage.BLESSING]) {
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

      this.clearTimer()
      this.isPlaying = false
      try {
        this.onComplete?.(AnimStage.BLESSING)
      } catch (err) {
        console.error('AnimController complete callback error:', JSON.stringify(err))
      }
    }, 16)
  }
}