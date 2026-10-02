import { UIAbility, Want, AbilityConstant } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { AudioManager } from '../service/AudioManager'
import { PrayerViewModel } from '../viewmodels/PrayerViewModel'
import { EnrichViewModel } from '../viewmodels/EnrichViewModel'
import { preferences } from '@kit.ArkData'
import { util } from '@kit.ArkTS'
import { EntryConfigVM } from '../viewmodels/EntryConfigVM'
import { FortuneViewModel } from '../viewmodels/FortuneViewModel'
import { MuyuViewModel } from '../viewmodels/MuyuViewModel'
import { QiuQianViewModel } from '../viewmodels/QiuQianViewModel'
import { IapPaymentService } from '../service/IapPaymentService'
import { UnlockPurchaseResult } from '../service/IPaymentService'
import { CloudService } from '../service/CloudService'

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // 预加载音效到 SoundPool
    AudioManager.getInstance().init(this.context).catch((err: Object) => {
      console.error('AudioManager init failed:', JSON.stringify(err))
    })

    // 全局共享的祈福视图模型；各页面通过 @StorageLink('viewModel') 读取，
    // 避免跨路由页面使用 @Provide/@Consume 导致取不到值。
    const viewModel = new PrayerViewModel()
    AppStorage.setOrCreate('viewModel', viewModel)
    viewModel.initialize(this.context).catch((err: Object) => {
      console.error('PrayerViewModel init failed:', JSON.stringify(err))
    })

    // 全局共享的增值内容视图模型（黄历/磕头/财神追踪）
    const enrichVM = new EnrichViewModel()
    AppStorage.setOrCreate('enrichViewModel', enrichVM)
    enrichVM.initialize(this.context).catch((err: Object) => {
      console.error('EnrichViewModel init failed:', JSON.stringify(err))
    })

    // 全局共享的入口配置（界面定制：Tab 开关与排序）
    const entryConfigVM = new EntryConfigVM()
    AppStorage.setOrCreate('entryConfigVM', entryConfigVM)
    entryConfigVM.initialize(this.context).catch((err: Object) => {
      console.error('EntryConfigVM init failed:', JSON.stringify(err))
    })

    // 全局共享的运势视图模型（星座/属相偏好、神诞收藏）
    const fortuneVM = new FortuneViewModel()
    AppStorage.setOrCreate('fortuneVM', fortuneVM)
    fortuneVM.initialize(this.context).catch((err: Object) => {
      console.error('FortuneViewModel init failed:', JSON.stringify(err))
    })

    // 全局共享的电子木鱼计数
    const muyuVM = new MuyuViewModel()
    AppStorage.setOrCreate('muyuVM', muyuVM)
    muyuVM.initialize(this.context).catch((err: Object) => {
      console.error('MuyuViewModel init failed:', JSON.stringify(err))
    })

    // 全局共享的求签记录/每日额度（自动记签 + 每日最多 3 签）
    const qiuVM = new QiuQianViewModel()
    AppStorage.setOrCreate('qiuVM', qiuVM)
    qiuVM.initialize(this.context).catch((err: Object) => {
      console.error('QiuQianViewModel init failed:', JSON.stringify(err))
    })

    // 生成或读取设备用户 ID（供 CloudService 匿名标识使用）
    preferences.getPreferences(this.context, 'mashen_user_prefs').then((prefs: preferences.Preferences) => {
      prefs.get('deviceUserId', '').then((val: preferences.ValueType) => {
        let uid: string = val as string
        if (!uid) {
          uid = 'u_' + util.generateRandomUUID(true)
          prefs.put('deviceUserId', uid)
          prefs.flush()
        }
        AppStorage.setOrCreate('deviceUserId', uid)
        // 设备 ID 就绪后启动牌局记录云同步（P1：同设备云备份，防本地数据丢失）。
        // enrichVM 在 onCreate 前文已初始化；startCloudSync 幂等，离线时安全跳过。
        enrichVM.startCloudSync().catch((err: Object) => {
          console.error('EnrichViewModel startCloudSync failed:', JSON.stringify(err))
        })

        // 解签每日解锁补单恢复：消耗型商品已支付未消耗（崩溃在消耗前/换机重装）→
        // 置本地「今日解锁」 + 云端幂等补记 + 消耗。今日已在本地解锁（跨天自愈）则跳过。
        // deviceUserId 就绪后才有 __uid 可记账；未登录华为帐号时 queryPurchases 会安全跳过，
        // 下次启动/打开详情再补。setUnlockedForToday 与 deviceUserId 同文件持久化，无需另写。
        if (!qiuVM.isUnlocked()) {
          const iapService = new IapPaymentService(this.context)
          iapService.recoverPending().then((owned: UnlockPurchaseResult | null) => {
            if (owned === null) {
              return
            }
            qiuVM.setUnlockedForToday().catch((err: Object) => {
              console.error('QiuQianViewModel setUnlockedForToday failed:', JSON.stringify(err))
            })
            CloudService.recordSignUnlock({
              productId: owned.productId,
              purchaseToken: owned.purchaseToken,
              purchaseData: owned.purchaseData,
              orderId: owned.orderId
            })
            iapService.consume(owned).catch((err: Object) => {
              console.error('EntryAbility consume pending failed:', JSON.stringify(err))
            })
          }).catch((err: Object) => {
            console.error('IapPaymentService recoverPending failed:', JSON.stringify(err))
          })
        }
      })
    })
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // App 前后台状态标记：求签页据此注册/注销加速度计。
    // 审核标准「应用退后台禁止使用传感器」：退后台必须释放传感器占用。
    AppStorage.setOrCreate('appInForeground', true)

    // 沉浸式：内容延伸到状态栏与导航栏区域，系统栏透明，
    // 消除屏幕上下白边，使深色背景铺满全屏。
    const mainWindow = windowStage.getMainWindowSync()
    mainWindow.setWindowLayoutFullScreen(true).then(() => {
      return mainWindow.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        statusBarContentColor: '#f9ca24',
        navigationBarColor: '#00000000',
        navigationBarContentColor: '#f9ca24'
      })
    }).catch((err: Object) => {
      console.error('Immersive window setup failed:', JSON.stringify(err))
    })

    // 改为加载 MainTabs（四 Tab 主框架）
    windowStage.loadContent('pages/MainTabs', (err) => {
      if (err.code) {
        console.error('Failed to load content:', JSON.stringify(err))
      }
    })
  }

  onForeground(): void {
    // App 回到前台：求签页据此恢复加速度计订阅（仅前台 + 求签 tab 激活时占用传感器）
    AppStorage.setOrCreate('appInForeground', true)
  }

  onBackground(): void {
    // App 进入后台时停止 BGM
    AudioManager.getInstance().stopBgm()
    // 退后台禁止占用传感器：通知求签页立即注销加速度计订阅
    AppStorage.setOrCreate('appInForeground', false)
  }

  onDestroy(): void {
    // 释放所有音频资源
    AudioManager.getInstance().release()
  }
}
