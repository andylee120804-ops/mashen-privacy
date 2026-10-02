// entry/src/main/ets/service/AudioManager.ets
import { media } from '@kit.MediaKit'
import { audio } from '@kit.AudioKit'

const RAW_APPEAR = 'sounds/appear.mp3'
const RAW_INCENSE = 'sounds/incense.mp3'
const RAW_KOWTOW = 'sounds/kowtow.mp3'
const RAW_BLESSING = 'sounds/blessing.mp3'
const RAW_BGM = 'sounds/bgm.mp3'

/**
 * 短音/瞬态音并发策略：share（与其他音频流并发，互不干扰）。
 * 短音播放体验规范要求短音不得以 stop 策略抢占焦点，
 * 须采用 share/duck/pause 之一；未激活 AudioSession 时系统按独占焦点处理。
 * 采用 MIX_WITH_OTHERS（share）而非 DUCK：
 * - 审核要求「静音播放场景焦点策略为 share」——音量过低/静音播放时不得压低其他 App 音频；
 * - share 既不 stop 也不 duck 其他音频，对短音/瞬态音是三者中最保守的策略。
 */
const TRANSIENT_CONCURRENCY: audio.AudioSessionStrategy = {
  concurrencyMode: audio.AudioConcurrencyMode.CONCURRENCY_MIX_WITH_OTHERS
}

/** 音效文件映射 */
const SOUND_FILES: Record<string, string> = {
  'appear': RAW_APPEAR,
  'incense': RAW_INCENSE,
  'kowtow': RAW_KOWTOW,
  'blessing': RAW_BLESSING,
}

/**
 * 音频管理 - 单例。
 * SoundPool 播放短音效（低延迟，适合磕头点击触发）；
 * AVPlayer 播放 BGM（循环）。资源从 rawfile 加载。
 *
 * 遵循 HarmonyOS 短音/瞬态音播放体验规范：
 * - 预加载所有音效到 SoundPool，避免播放时延迟
 * - 配置 AudioRendererInfo（STREAM_USAGE_MUSIC）参与系统音频焦点
 * - 激活 AudioSession（share 策略），短音播放与系统其他音频并发、互不干扰
 * - 监听 loadComplete 事件追踪加载状态
 * - BGM 设置 audioRendererInfo + audioInterrupt 监听，来电等场景自动暂停/恢复；
 *   BGM 播放期间取消 transient 会话（长音频应使用默认独占焦点）
 * - App 后台/销毁时及时释放资源
 */
export class AudioManager {
  private static instance: AudioManager | null = null
  private soundPool: media.SoundPool | null = null
  private bgmPlayer: media.AVPlayer | null = null
  private context: Context | null = null
  private sessionManager: audio.AudioSessionManager | null = null

  /** 音效 ID 映射（key -> soundID） */
  private soundIds: Map<string, number> = new Map()
  private initialized: boolean = false

  /** BGM 被音频中断暂停（区别于用户主动 stop） */
  private bgmInterrupted: boolean = false

  static getInstance(): AudioManager {
    if (AudioManager.instance === null) {
      AudioManager.instance = new AudioManager()
    }
    return AudioManager.instance
  }

  /**
   * 激活短音并发策略（share/mix）。幂等。
   */
  private async activateTransientSession(): Promise<void> {
    const mgr = this.sessionManager
    if (mgr === null || mgr.isAudioSessionActivated()) return
    try {
      await mgr.activateAudioSession(TRANSIENT_CONCURRENCY)
    } catch (err) {
      console.error('[AudioManager] activate transient session failed:', JSON.stringify(err))
    }
  }

  /**
   * 取消短音并发策略，恢复默认焦点行为（长音频 BGM 使用）。幂等。
   */
  private async deactivateTransientSession(): Promise<void> {
    const mgr = this.sessionManager
    if (mgr === null || !mgr.isAudioSessionActivated()) return
    try {
      await mgr.deactivateAudioSession()
    } catch (err) {
      console.error('[AudioManager] deactivate transient session failed:', JSON.stringify(err))
    }
  }

  /**
   * 初始化 SoundPool 并预加载短音效。
   * 在 EntryAbility.onCreate 调用。
   */
  async init(context: Context): Promise<void> {
    if (this.initialized) return
    this.context = context
    try {
      this.sessionManager = audio.getAudioManager().getSessionManager()
      // 先激活 transient 会话，确保首个短音效即采用 share 策略而非 stop
      await this.activateTransientSession()

      this.soundPool = (await media.createSoundPool(
        4,
        { usage: audio.StreamUsage.STREAM_USAGE_MUSIC, rendererFlags: 0 } as audio.AudioRendererInfo
      )) as Object as media.SoundPool

      // 监听音效加载完成
      this.soundPool.on('loadComplete', (soundID: number) => {
        console.info(`[AudioManager] sound loaded: ${soundID}`)
      })

      // 预加载所有音效
      const keys = Object.keys(SOUND_FILES)
      await Promise.all(keys.map(async (key: string) => {
        try {
          const path = SOUND_FILES[key]
          const fd = await this.context!.resourceManager.getRawFd(path)
          const soundId = await this.soundPool!.load(fd.fd, fd.offset, fd.length)
          this.soundIds.set(key, soundId)
        } catch (err) {
          console.error(`[AudioManager] load ${key} failed:`, JSON.stringify(err))
        }
      }))

      this.initialized = true
    } catch (err) {
      console.error('[AudioManager] init failed:', JSON.stringify(err))
    }
  }

  /**
   * 播放短音效（fire-and-forget，播放完自动结束）。
   * 未初始化或加载失败时静默跳过。
   */
  playSound(key: string): void {
    if (this.soundPool === null || !this.initialized) return
    const soundId = this.soundIds.get(key)
    if (soundId === undefined || soundId < 0) return
    this.soundPool.play(soundId).catch((err: Object) => {
      console.error(`[AudioManager] play ${key} failed:`, JSON.stringify(err))
    })
  }

  /**
   * 启动 BGM 循环播放。进入 PrayerCard 时调用。
   */
  async startBgm(): Promise<void> {
    if (this.bgmPlayer !== null || this.context === null) return
    // BGM 为长音频，取消 transient 会话，使用默认独占焦点（来电/其他音乐可正常暂停它）
    await this.deactivateTransientSession()
    try {
      this.bgmPlayer = await media.createAVPlayer()
      this.bgmPlayer.on('stateChange', (state: string, reason: media.StateChangeReason) => {
        // AVPlayer 状态机：设 fdSrc -> initialized -> prepare -> prepared -> play
        if (state === 'initialized') {
          // loop 必须在 initialized 之后设置才生效；在 idle 状态设置会被忽略
          this.bgmPlayer!.loop = true
          // 设置 audioRendererInfo 使 BGM 参与系统音频焦点管理
          this.bgmPlayer!.audioRendererInfo = {
            usage: audio.StreamUsage.STREAM_USAGE_MUSIC,
            rendererFlags: 0
          } as audio.AudioRendererInfo
          this.bgmPlayer?.prepare()
        } else if (state === 'prepared') {
          this.bgmPlayer?.play()
        } else if (state === 'completed') {
          // loop=true 理论上自动循环，部分设备/版本不生效时手动兜底重启
          this.bgmPlayer?.play()
        }
      })
      this.bgmPlayer.on('error', (err: Object) => {
        console.error('[AudioManager] BGM error:', JSON.stringify(err))
      })
      // 监听音频中断事件（来电、其他 App 播放音乐等）
      // InterruptType: BEGIN(0)=中断开始（系统自动暂停），END(1)=中断结束（需手动恢复）
      this.bgmPlayer.on('audioInterrupt', (info: audio.InterruptEvent) => {
        if (info.eventType === audio.InterruptType.INTERRUPT_TYPE_BEGIN) {
          // 高优先级音频抢占焦点，系统自动暂停 BGM
          this.bgmInterrupted = true
        } else if (info.eventType === audio.InterruptType.INTERRUPT_TYPE_END) {
          // 焦点归还，系统不自动恢复，需手动 play()
          if (this.bgmInterrupted && this.bgmPlayer !== null) {
            this.bgmPlayer.play()
            this.bgmInterrupted = false
          }
        }
      })
      const fd = await this.context.resourceManager.getRawFd(RAW_BGM)
      this.bgmPlayer.fdSrc = { fd: fd.fd, offset: fd.offset, length: fd.length }
    } catch (err) {
      console.error('[AudioManager] startBgm failed:', JSON.stringify(err))
      this.bgmPlayer = null
      // BGM 启动失败，恢复短音 transient 会话
      await this.activateTransientSession()
    }
  }

  /**
   * 停止 BGM。离开 PrayerCard 或 App 进入后台时调用。
   */
  async stopBgm(): Promise<void> {
    if (this.bgmPlayer === null) return
    try {
      this.bgmPlayer.stop()
      await this.bgmPlayer.release()
    } catch (err) {
      console.error('[AudioManager] stopBgm failed:', JSON.stringify(err))
    }
    this.bgmPlayer = null
    this.bgmInterrupted = false
    // BGM 停止后恢复短音 transient 会话
    await this.activateTransientSession()
  }

  /**
   * 释放所有音频资源。App 销毁时调用。
   */
  async release(): Promise<void> {
    await this.stopBgm()
    await this.deactivateTransientSession()
    if (this.soundPool !== null) {
      try {
        this.soundPool.off('loadComplete')
        await this.soundPool.release()
      } catch (err) {
        console.error('[AudioManager] soundPool release failed:', JSON.stringify(err))
      }
      this.soundPool = null
    }
    this.soundIds.clear()
    this.initialized = false
  }
}
