// entry/src/main/ets/pages/MuyuPage.ets
// 电子木鱼：轻触敲击，计数功德。短音复用 kowtow.mp3（DUCK 策略），
// 轻触感复用 VIBRATE 权限（已声明）。高频解压 + 每日打开场景。
import { MuyuViewModel } from '../viewmodels/MuyuViewModel'
import { AudioManager } from '../service/AudioManager'
import { vibrator } from '@kit.SensorServiceKit'

@Component
export struct MuyuPage {
  @StorageLink('muyuVM') muyuVM: MuyuViewModel = new MuyuViewModel()
  @State isTapping: boolean = false

  build() {
    Column() {
      // 标题
      Text('🪵 电子木鱼')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#f9ca24')
        .width('100%')
        .padding({ left: 20, top: 44, bottom: 8 })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

      // 计数
      Column() {
        Text(`今日 ${this.muyuVM.todayCount} 下`)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#fdf6e3')
        Text(`累计功德 ${this.muyuVM.totalCount}`)
          .fontSize(12)
          .fontColor('rgba(249, 202, 36, 0.7)')
          .margin({ top: 4 })
      }
      .margin({ top: 20 })

      // 木鱼主体：轻触敲击
      Column() {
        Text('🪵')
          .fontSize(110)
          .scale({ x: this.isTapping ? 0.9 : 1, y: this.isTapping ? 0.9 : 1 })
          .animation({ duration: 90, curve: Curve.EaseOut })
        Text('轻触木鱼 · 功德 +1')
          .fontSize(13)
          .fontColor('rgba(253, 246, 227, 0.6)')
          .margin({ top: 16 })
      }
      .justifyContent(FlexAlign.Center)
      .layoutWeight(1)
      .width('100%')
      .onClick(() => this.knock())
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1a1a0a')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
  }

  private knock(): void {
    this.muyuVM.knock()
    AudioManager.getInstance().playSound('kowtow')
    this.vibrate()
    this.isTapping = true
    setTimeout(() => {
      this.isTapping = false
    }, 110)
  }

  private vibrate(): void {
    try {
      vibrator.startVibration({
        type: 'time',
        duration: 18
      }, { id: 0, usage: 'unknown' })
    } catch (err) {
      console.error('[MuyuPage] vibrate failed:', JSON.stringify(err))
    }
  }
}
