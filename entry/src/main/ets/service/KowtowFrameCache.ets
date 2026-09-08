// entry/src/main/ets/service/KowtowFrameCache.ets
import { image } from '@kit.ImageKit'

const FRAME_COUNT = 51
const FRAME_WIDTH = 240
const FRAME_HEIGHT = 240

/**
 * 磕头帧 PixelMap 预解码缓存（静态单例）。
 *
 * 点击完成时延优化：51 帧 PNG 若在磕头动画播放时逐帧解码，
 * 每次帧切换都伴随一次图片解码，首帧响应慢、动画易卡顿。
 * 本缓存在用户输入姓名期间（NameCard.aboutToAppear）后台异步解码全部帧，
 * 解码在 native 线程完成，不占用 UI 主线程、不触发任何 @State 刷新。
 * 帧切换时 Image 直接提交已解码位图，首帧即点即显。
 *
 * 内存占用：51 × 240×240 × 4B ≈ 11.7MB，可接受。
 */
export class KowtowFrameCache {
  private static frames: (image.PixelMap | undefined)[] = []
  private static started: boolean = false

  /**
   * 启动后台预解码（幂等，重复调用只生效一次）。
   * 在 NameCard.aboutToAppear 调用；PrayerCard 兜底再调一次防直接跳转场景。
   */
  static preload(context: Context): void {
    if (KowtowFrameCache.started) return
    KowtowFrameCache.started = true
    KowtowFrameCache.doPreload(context).catch((err: Object) => {
      console.error('[KowtowFrameCache] preload failed:', JSON.stringify(err))
    })
  }

  private static async doPreload(context: Context): Promise<void> {
    for (let i = 1; i <= FRAME_COUNT; i++) {
      try {
        const name = `animations/kowtow_${String(i).padStart(2, '0')}.png`
        const fd = await context.resourceManager.getRawFd(name)
        // createImageSource 直接接收 RawFileDescriptor（含 offset/length），无需手动拆 fd
        const src = image.createImageSource(fd)
        const pm = await src.createPixelMap({
          desiredSize: { width: FRAME_WIDTH, height: FRAME_HEIGHT }
        })
        KowtowFrameCache.frames.push(pm)
        src.release()
      } catch (err) {
        // 单帧失败不阻断整体，该帧回退到 Resource 路径
        console.error(`[KowtowFrameCache] frame ${i} decode failed:`, JSON.stringify(err))
        KowtowFrameCache.frames.push(undefined)
      }
    }
  }

  /**
   * 取已解码帧。未解码完成（或失败）返回 undefined，调用方回退 $rawfile Resource。
   */
  static getFrame(index: number): image.PixelMap | undefined {
    return KowtowFrameCache.frames[index]
  }
}
