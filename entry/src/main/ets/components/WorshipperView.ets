/**
 * 祈福者小人：51 帧视频抽帧磕头序列（animations/kowtow_01~51.png）。
 * 来源：Wan2.2-T2V 生成背视磕头视频 -> ffmpeg 抽帧 @10fps -> rembg 去背景。
 *
 * 性能优化：用单 Image + Resource 数组替代 51 个堆叠 Image 组件，
 * 将渲染树节点从 51 减至 1，大幅降低磕头动画帧切换时的重绘开销。
 * 帧源优先取 KowtowFrameCache 预解码的 PixelMap（零解码延迟），
 * 缓存未就绪时回退 $rawfile Resource。$rawfile 必须用字面量路径，故逐帧显式声明。
 */
import { KowtowFrameCache } from '../service/KowtowFrameCache'

/** 51 帧磕头序列的 Resource 引用（$rawfile 编译期解析） */
export const KOWTOW_FRAMES: Resource[] = [
  $rawfile('animations/kowtow_01.png'),
  $rawfile('animations/kowtow_02.png'),
  $rawfile('animations/kowtow_03.png'),
  $rawfile('animations/kowtow_04.png'),
  $rawfile('animations/kowtow_05.png'),
  $rawfile('animations/kowtow_06.png'),
  $rawfile('animations/kowtow_07.png'),
  $rawfile('animations/kowtow_08.png'),
  $rawfile('animations/kowtow_09.png'),
  $rawfile('animations/kowtow_10.png'),
  $rawfile('animations/kowtow_11.png'),
  $rawfile('animations/kowtow_12.png'),
  $rawfile('animations/kowtow_13.png'),
  $rawfile('animations/kowtow_14.png'),
  $rawfile('animations/kowtow_15.png'),
  $rawfile('animations/kowtow_16.png'),
  $rawfile('animations/kowtow_17.png'),
  $rawfile('animations/kowtow_18.png'),
  $rawfile('animations/kowtow_19.png'),
  $rawfile('animations/kowtow_20.png'),
  $rawfile('animations/kowtow_21.png'),
  $rawfile('animations/kowtow_22.png'),
  $rawfile('animations/kowtow_23.png'),
  $rawfile('animations/kowtow_24.png'),
  $rawfile('animations/kowtow_25.png'),
  $rawfile('animations/kowtow_26.png'),
  $rawfile('animations/kowtow_27.png'),
  $rawfile('animations/kowtow_28.png'),
  $rawfile('animations/kowtow_29.png'),
  $rawfile('animations/kowtow_30.png'),
  $rawfile('animations/kowtow_31.png'),
  $rawfile('animations/kowtow_32.png'),
  $rawfile('animations/kowtow_33.png'),
  $rawfile('animations/kowtow_34.png'),
  $rawfile('animations/kowtow_35.png'),
  $rawfile('animations/kowtow_36.png'),
  $rawfile('animations/kowtow_37.png'),
  $rawfile('animations/kowtow_38.png'),
  $rawfile('animations/kowtow_39.png'),
  $rawfile('animations/kowtow_40.png'),
  $rawfile('animations/kowtow_41.png'),
  $rawfile('animations/kowtow_42.png'),
  $rawfile('animations/kowtow_43.png'),
  $rawfile('animations/kowtow_44.png'),
  $rawfile('animations/kowtow_45.png'),
  $rawfile('animations/kowtow_46.png'),
  $rawfile('animations/kowtow_47.png'),
  $rawfile('animations/kowtow_48.png'),
  $rawfile('animations/kowtow_49.png'),
  $rawfile('animations/kowtow_50.png'),
  $rawfile('animations/kowtow_51.png'),
]

/**
 * 磕头小人：单 Image 组件根据 bowFrame 切换帧源。
 * 优先用 KowtowFrameCache 预解码的 PixelMap（帧切换零解码），
 * 缓存未就绪时回退 Resource（ArkUI 图片缓存兜底）。
 */
@Component
export struct WorshipperView {
  @Prop bowFrame: number = 0

  build() {
    Image(KowtowFrameCache.getFrame(this.bowFrame) ?? KOWTOW_FRAMES[this.bowFrame])
      .width(240)
      .height(240)
      .objectFit(ImageFit.Contain)
  }
}
