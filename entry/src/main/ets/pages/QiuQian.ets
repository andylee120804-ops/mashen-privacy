// entry/src/main/ets/pages/QiuQian.ets
// 求签 tab：摇晃手机求签（每次独立随机抽签，36 签真随机）。
// 动画模拟「抱机磕头 + 摇晃出签」：三拜 → 摇签筒 → 签支弹出 → 签文翻牌揭晓。
// 仅靠摇晃手机触发（无按钮）。揭签自动记入签录（每日最多求 3 签，跨天重置）；
// 右上角「📜 签录」可回看历史签（点行看完整签文）；另有解签 / 去祈福 / 再求一签。
import { SignEntry, SignLevel, SIGN_TABLE, QiuRecord } from '../model/CultureContent'
import { PrayerViewModel } from '../viewmodels/PrayerViewModel'
import { QiuQianViewModel, MAX_DAILY_QIU } from '../viewmodels/QiuQianViewModel'
import { ParticleCanvas, ParticleType } from '../components/ParticleCanvas'
import { PageBack } from '../components/PageBack'
import { pasteboard, BusinessError } from '@kit.BasicServicesKit'
import { common } from '@kit.AbilityKit'
import { router } from '@kit.ArkUI'
import { sensor, vibrator } from '@kit.SensorServiceKit'
import { IapPaymentService } from '../service/IapPaymentService'
import { PaymentError, PaymentErrorKind, UnlockPurchaseResult, UNLOCK_PRODUCT } from '../service/IPaymentService'
import { CloudService } from '../service/CloudService'

/** 吉凶等级 → 颜色（深底 #1a1a0a / #241f12 上 ≥4.5:1；浅色签纸不用本表，见 SignPaperCard） */
const LEVEL_COLOR: Record<string, string> = {
  '上上签': '#d4a017',
  '上吉签': '#2ecc71',
  '中吉签': '#3a8fd4',
  '中平签': '#9a9a9a',
  '下签': '#f0533f'
}

/** 求签流程阶段 */
enum QiuPhase {
  IDLE = 0,    // 待求签
  KOWTOW = 1,  // 三拜
  SHAKING = 2, // 摇签筒
  LAUNCH = 3,  // 签支弹出
  REVEAL = 4   // 签文揭晓
}

// ── 动画参数 ──
const QIUQIAN_ENTRY_ID = 'qiuqian'
const KOWTOW_BOWS = 3
const BOW_ANGLE = 16              // 一拜俯身角度（°）
const BOW_HOLD_MS = 300           // 俯身停留
const BOW_GAP_MS = 220            // 拜与拜之间停顿
const SHAKE_STEPS = 10            // 摇晃摆动次数
const SHAKE_STEP_MS = 90          // 每次摆动间隔
const SHAKE_ANGLE = 11            // 摆动幅度（°）
const LAUNCH_RISE = -160          // 签支弹出上升距离（终点签底悬在素材冠顶上方）
const LAUNCH_MS = 820             // 弹出阶段时长
// ── 摇晃检测参数（加速度计）──
// 用「合加速度偏离重力 + 迟滞翻转计数」检测：摇晃一个来回 = 合加速度在
// 高于/低于重力之间翻转一次。拿手机/旋转时合加速度始终≈9.8 不翻转，
// 普通走路摆幅 <4 也不翻转；只有真实摇晃才累积翻转次数并出签。
const GRAVITY = 9.8               // 重力加速度 m/s²
const SHAKE_HYST = 4              // 翻转迟滞幅度（偏离重力阈值，真机校准值）
const SHAKE_WINDOW_MS = 2000      // 翻转统计窗口（放宽以兼容较慢的摇晃节奏）
const SHAKE_FLIPS = 3             // 窗口内翻转次数即出签（约 1.5 个来回）
const SHAKE_COOLDOWN_MS = 2000    // 触发后冷却，防连击
// 摇晃同步触感：每记一次翻转给一记轻震，最短间隔防连震
const FLIP_VIBRATE_MS = 22
const FLIP_VIBRATE_GAP_MS = 120

// ── 舞台素材 ──
// 签筒画面直接用用户提供的参考图素材（props/qiu_art.png，透明底，272×483），
// 动画（俯身/摇摆/出签）在整图上做，不再程序化重绘签筒。
const QIU_ART_W = 169             // 素材显示宽（vp，按 272:483 等比）
const QIU_ART_H = 300             // 素材显示高（vp）
const WIGGLE_AMP = 2.2            // 摇筒时整图附加的小幅摆动（叠在筒身摇摆上）
// 弹出签素材：直接从求签素材裁出的「筒内同款」单签（13×100 原图，
// 红漆身 #ff0000 + 金竖高光，scripts/crop-qiu-stick.py 生成）
const QIU_STICK_IMG_W = 10        // 弹出签显示宽（vp，13:100 等比）
const QIU_STICK_IMG_H = 76        // 弹出签显示高（vp）
const LIST_OPEN_GRACE_MS = 350    // 签录打开后忽略遮罩点击的窗口（防同一点击立即误关）

@Component
export struct QiuQianPage {
  /** 独立模式（EntryShell 从「我的」进入）：返回键并入大标题行；Tab 模式不带 */
  @Prop standalone: boolean = false
  @StorageLink('viewModel') viewModel: PrayerViewModel = new PrayerViewModel()
  @StorageLink('qiuVM') qiuVM: QiuQianViewModel = new QiuQianViewModel()
  /** 当前激活入口 id（MainTabs onChange / EntryShell aboutToAppear 写入），仅在本入口激活时响应摇晃 */
  @StorageLink('activeEntryId') @Watch('onSensorGateChanged') activeEntryId: string = ''
  /** App 前后台状态（EntryAbility onForeground/onBackground 写入）：
   *  退后台禁止占用传感器，必须与 activeEntryId 一起门控加速度计订阅 */
  @StorageLink('appInForeground') @Watch('onSensorGateChanged') appInForeground: boolean = true
  @State sign: SignEntry = SIGN_TABLE[0]
  @State phase: QiuPhase = QiuPhase.IDLE
  @State bowAngle: number = 0
  @State shakeAngle: number = 0
  @State fanSway: number = 0     // 摇筒时整图附加的小幅摆动（与筒身摇摆叠加）
  @State bowIndex: number = 0
  @State stickRiseY: number = 0
  @State stageOpacity: number = 1
  @State cardFlipAngle: number = 90
  @State cardOpacity: number = 0
  @State showQiuList: boolean = false      // 签录覆层开关
  @State showDetail: boolean = false       // 解签详情覆层开关（当前签 / 记录行共用）
  @State detail: SignEntry = SIGN_TABLE[0] // 当前展示的签快照（showDetail=true 时有效）
  @State qiuRecords: QiuRecord[] = []      // 签录快照（新→旧）
  @State todayUsed: number = 0             // 今日已求次数（0..3）
  @State clearArmed: boolean = false       // 清空签录二次确认
  @State unlocked: boolean = false       // 解签买断解锁状态（快照自 qiuVM）
  private unlocking: boolean = false     // 解锁进行中（防重入）
  private restoreCheckDone: boolean = false  // 本页会话内只做一次权益恢复检查
  private timers: number[] = []
  private shakeTimerId: number = -1
  private swayPhase: number = 0   // 摆动相位推进器（随摇筒 step 递增）
  private sensorOn: boolean = false
  private leaving: boolean = false
  // 摇晃检测状态（迟滞翻转计数）
  private aboveThreshold: boolean = false
  private belowThreshold: boolean = false
  private flipTimes: number[] = []
  private drawCooldownUntil: number = 0
  private lastFlipVibrateMs: number = 0
  private qiuListOpenedAt: number = 0    // 签录打开时刻（防开窗点击误关）
  private detailOpenedAt: number = 0     // 详情打开时刻（同上）

  aboutToAppear(): void {
    // 传感器订阅由 syncSensorState 统一门控（前台 + 求签 tab 激活才占用）
    this.syncSensorState()
    this.syncFromVM()
  }

  aboutToDisappear(): void {
    this.leaving = true
    this.clearAllTimers()
    this.unregisterShakeSensor()
  }

  /** 真随机抽签：每次求签独立随机（36 签等概率） */
  private drawSign(): void {
    this.sign = SIGN_TABLE[Math.floor(Math.random() * SIGN_TABLE.length)]
  }

  // ── 摇晃手机检测 ──

  /**
   * 传感器门控：仅在前台 + 求签 tab 激活时订阅加速度计。
   * 退后台（appInForeground=false）或切走入口（activeEntryId≠求签）立即注销，
   * 满足「应用退后台禁止使用传感器」审核标准，同时省电。
   */
  private onSensorGateChanged(): void {
    this.syncSensorState()
  }

  private syncSensorState(): void {
    // 不依赖 leaving：leaving 仅在页面销毁时置 true 且不重置，
    // 若 Tab 切换触发 aboutToAppear/aboutToDisappear 会误挡恢复。
    const shouldRun = this.appInForeground && this.activeEntryId === QIUQIAN_ENTRY_ID
    if (shouldRun && !this.sensorOn) {
      this.registerShakeSensor()
    } else if (!shouldRun && this.sensorOn) {
      this.unregisterShakeSensor()
    }
  }

  private registerShakeSensor(): void {
    try {
      // interval 'game' = 20ms 采样：默认 200ms 采样会把摇晃周期混叠掉，检测不到
      sensor.on(sensor.SensorId.ACCELEROMETER, (data: sensor.AccelerometerResponse): void => {
        this.onAccelData(data)
      }, { interval: 'game' })
      this.sensorOn = true
      console.info('[QiuQian] shake sensor registered (interval=game)')
    } catch (err) {
      // 部分设备/模拟器无传感器：静默降级
      console.error('[QiuQian] sensor.on failed:', JSON.stringify(err))
    }
  }

  private unregisterShakeSensor(): void {
    if (!this.sensorOn) return
    try {
      sensor.off(sensor.SensorId.ACCELEROMETER)
    } catch (err) {
      console.error('[QiuQian] sensor.off failed:', JSON.stringify(err))
    }
    this.sensorOn = false
  }

  private onAccelData(data: sensor.AccelerometerResponse): void {
    if (this.leaving || this.activeEntryId !== QIUQIAN_ENTRY_ID) return
    if (this.phase !== QiuPhase.IDLE) return
    const now = Date.now()
    if (now < this.drawCooldownUntil) return

    // 合加速度：拿起手机/缓慢旋转时其值仍≈重力
    const magnitude = Math.sqrt(data.x * data.x + data.y * data.y + data.z * data.z)
    const diff = magnitude - GRAVITY

    // 翻转窗口超时 → 清空重计
    this.flipTimes = this.flipTimes.filter((t: number): boolean => now - t < SHAKE_WINDOW_MS)

    // 迟滞翻转计数：diff 越过 +HYST 或 -HYST 记为一次方向变化
    let flipped = false
    if (diff > SHAKE_HYST) {
      if (this.belowThreshold) {
        flipped = true
      }
      this.aboveThreshold = true
      this.belowThreshold = false
    } else if (diff < -SHAKE_HYST) {
      if (this.aboveThreshold) {
        flipped = true
      }
      this.belowThreshold = true
      this.aboveThreshold = false
    }

    if (flipped) {
      this.flipTimes.push(now)
      // 同步触感：每摇一个来回给一记轻震（最短间隔限流，防止连震过密）
      if (now - this.lastFlipVibrateMs >= FLIP_VIBRATE_GAP_MS) {
        this.lastFlipVibrateMs = now
        this.vibrate(FLIP_VIBRATE_MS)
      }
    }

    if (this.flipTimes.length >= SHAKE_FLIPS) {
      this.flipTimes = []
      this.aboveThreshold = false
      this.belowThreshold = false
      this.drawCooldownUntil = now + SHAKE_COOLDOWN_MS
      // 出签瞬间强震确认
      this.vibrate(90)
      this.startDraw()
    }
  }

  // ── 求签动画序列 ──

  /** 开始求签（摇晃触发）：先过每日 3 签额度，出签即消费一次 */
  private startDraw(): void {
    if (this.phase !== QiuPhase.IDLE || this.leaving) return
    if (!this.qiuVM.canDraw()) {
      // 今日额度已满：提示后留在待求签态（不进入动画）
      this.vibrate(80)
      this.todayUsed = MAX_DAILY_QIU
      this.toast('今日已求满 3 签 · 明日再来 🙏')
      return
    }
    this.drawSign()
    this.qiuVM.consumeDraw().catch((err: Object) => {
      console.error('[QiuQian] consumeDraw failed:', JSON.stringify(err))
    })
    this.todayUsed = this.qiuVM.usedToday()
    this.phase = QiuPhase.KOWTOW
    this.bowIndex = 0
    this.performBow(0)
  }

  /** 一拜：俯身 → 回正；三拜后进入摇签 */
  private performBow(idx: number): void {
    if (this.leaving || this.phase !== QiuPhase.KOWTOW) return
    this.bowIndex = idx + 1
    this.vibrate(35)
    this.bowAngle = BOW_ANGLE
    this.after(BOW_HOLD_MS, (): void => {
      this.bowAngle = 0
      if (idx + 1 >= KOWTOW_BOWS) {
        this.after(BOW_GAP_MS, (): void => {
          this.startShake()
        })
      } else {
        this.after(BOW_GAP_MS, (): void => {
          this.performBow(idx + 1)
        })
      }
    })
  }

  /** 摇签筒：左右快速摆动，之后签支弹出 */
  private startShake(): void {
    if (this.leaving || this.phase !== QiuPhase.KOWTOW) return
    this.phase = QiuPhase.SHAKING
    let step = 0
    this.shakeTimerId = setInterval((): void => {
      if (this.leaving || this.phase !== QiuPhase.SHAKING) {
        clearInterval(this.shakeTimerId)
        this.shakeTimerId = -1
        return
      }
      step += 1
      if (step > SHAKE_STEPS) {
        clearInterval(this.shakeTimerId)
        this.shakeTimerId = -1
        this.shakeAngle = 0
        this.fanSway = 0
        this.beginLaunch()
        return
      }
      this.shakeAngle = (step % 2 === 0) ? -SHAKE_ANGLE : SHAKE_ANGLE
      // 整图附加摆动：与筒身异相的正弦波（黏性晃动，出签前收拢回正）
      this.swayPhase += 1
      this.fanSway = Math.round(Math.sin(this.swayPhase * 0.9) * WIGGLE_AMP * 10) / 10
      if (step % 2 === 1) {
        this.vibrate(40)
      }
    }, SHAKE_STEP_MS)
  }

  /** 签支弹出：从签筒中升起 */
  private beginLaunch(): void {
    if (this.leaving) return
    this.phase = QiuPhase.LAUNCH
    this.vibrate(70)
    this.stickRiseY = 100
    this.after(30, (): void => {
      this.stickRiseY = LAUNCH_RISE
    })
    this.after(LAUNCH_MS, (): void => {
      this.showReveal()
    })
  }

  /** 揭晓签文：签筒淡出、签纸翻牌入；揭晓即自动记入签录 */
  private showReveal(): void {
    if (this.leaving) return
    this.phase = QiuPhase.REVEAL
    this.stageOpacity = 0
    this.cardOpacity = 1
    this.cardFlipAngle = 0
    this.qiuVM.addRecord(this.sign).catch((err: Object) => {
      console.error('[QiuQian] addRecord failed:', JSON.stringify(err))
    })
    this.qiuRecords = this.qiuVM.records
  }

  /** 跳过动画直接看签 */
  private skipToReveal(): void {
    if (this.leaving || this.phase === QiuPhase.REVEAL) return
    this.clearAllTimers()
    this.shakeAngle = 0
    this.fanSway = 0
    this.bowAngle = 0
    this.showReveal()
  }

  /** 再求一签：回到待求签初始状态 */
  private resetDraw(): void {
    if (this.leaving) return
    this.clearAllTimers()
    this.showQiuList = false
    this.showDetail = false
    this.clearArmed = false
    this.phase = QiuPhase.IDLE
    this.cardOpacity = 0
    this.cardFlipAngle = 90
    this.stageOpacity = 1
    this.stickRiseY = 0
    this.shakeAngle = 0
    this.fanSway = 0
    this.swayPhase = 0
    this.bowAngle = 0
  }

  /** 去祈福：进入祈福流程（NameCard → PrayerCard） */
  private goPray(): void {
    this.showQiuList = false
    this.showDetail = false
    this.viewModel.startPrayer()
    setTimeout((): void => {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/NameCard' }, router.RouterMode.Standard)
    }, 0)
  }

  private copySignText(sign: SignEntry): void {
    const text = `【${sign.level}】${sign.title}\n${sign.poem}\n解签：${sign.interpretation}\n建议：${sign.advice}\n——来自麻神祈福`
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text)
      pasteboard.getSystemPasteboard().setData(data)
      this.getUIContext().getPromptAction().showToast({ message: '签文已复制，可分享给牌友 🙏' })
    } catch (err) {
      console.error('[QiuQian] copy failed:', JSON.stringify(err))
      this.getUIContext().getPromptAction().showToast({ message: '复制失败，请重试' })
    }
  }

  // ── 工具 ──

  private vibrate(duration: number): void {
    try {
      vibrator.startVibration({
        type: 'time',
        duration: duration
      }, { id: 0, usage: 'unknown' })
    } catch (err) {
      console.error('[QiuQian] vibrate failed:', JSON.stringify(err))
    }
  }

  private after(ms: number, fn: () => void): void {
    this.timers.push(setTimeout(fn, ms))
  }

  private clearAllTimers(): void {
    for (const id of this.timers) {
      clearTimeout(id)
    }
    this.timers = []
    if (this.shakeTimerId !== -1) {
      clearInterval(this.shakeTimerId)
      this.shakeTimerId = -1
    }
  }

  private getLevelColor(level: SignLevel): string {
    return LEVEL_COLOR[level] || '#9a9a9a'
  }

  private statusText(): string {
    switch (this.phase) {
      case QiuPhase.KOWTOW:
        return `诚心叩拜 · 第 ${this.bowIndex} / ${KOWTOW_BOWS} 拜`
      case QiuPhase.SHAKING:
        return '签筒摇动 · 静候神示'
      case QiuPhase.LAUNCH:
        return '出签！'
      case QiuPhase.REVEAL:
        return `第 ${this.sign.id} 签 · ${this.sign.level}`
      default:
        return '双手持机 · 摇晃手机出签'
    }
  }

  build() {
    Stack() {
      // 背景
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#1a1a0a')
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])

      // 揭签后金色粒子氛围
      ParticleCanvas({
        particleType: ParticleType.GOLD,
        isActive: this.phase === QiuPhase.REVEAL
      })

      // 顶部标题（与电子木鱼/运势黄历一致的标题位：左上角、状态栏下；
      // 独立模式返回键并入同行且标题居中，签录胶囊保持在行尾；Tab 模式标题左对齐）
      Row() {
        if (this.standalone) {
          PageBack()
        }
        Text('🎋 求签问运')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#f9ca24')
          .layoutWeight(1)
          .textAlign(this.standalone ? TextAlign.Center : TextAlign.Start)
        this.QiuHistoryPill()
      }
      .width('100%')
      .position({ x: 0, y: 0 })
      .padding({ left: this.standalone ? 6 : 20, right: 14, top: 44, bottom: 8 })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

      // 主舞台：签筒 / 签文
      Column() {
        this.StageView()
        Text(this.statusText())
          .fontSize(13)
          .fontColor(this.phase === QiuPhase.REVEAL ? '#f9ca24' : 'rgba(253, 246, 227, 0.6)')
          .margin({ top: 10 })
      }
      .position({ x: '50%', y: '48%' })
      .translate({ x: '-50%', y: '-50%' })

      // 底部操作区
      Column() {
        if (this.phase === QiuPhase.IDLE) {
          // 无按钮：仅摇晃出签
          Text('📳')
            .fontSize(26)
          Text('双手持机，摇晃手机出签')
            .fontSize(13)
            .fontColor('rgba(249, 202, 36, 0.75)')
            .margin({ top: 8 })
          Text(this.idleSubText())
            .fontSize(11)
            .fontColor(this.todayUsed >= MAX_DAILY_QIU ? 'rgba(249, 202, 36, 0.8)' : 'rgba(253, 246, 227, 0.5)')
            .margin({ top: 6 })
        } else if (this.phase === QiuPhase.REVEAL) {
          Row() {
            Button('📜 解签详情')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor('#f9ca24')
              .backgroundColor('rgba(249, 202, 36, 0.12)')
              .border({ width: 1, color: '#f9ca24' })
              .borderRadius(22)
              .layoutWeight(1)
              .padding({ top: 11, bottom: 11 })
              .onClick((): void => { this.openDetail(this.sign) })
            Button('🎋 再求一签')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor('#f9ca24')
              .backgroundColor('rgba(249, 202, 36, 0.12)')
              .border({ width: 1, color: '#f9ca24' })
              .borderRadius(22)
              .layoutWeight(1)
              .margin({ left: 12 })
              .padding({ top: 11, bottom: 11 })
              .onClick((): void => { this.resetDraw() })
          }
          .width('76%')

          Button('🙏 去祈福')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1a1a0a')
            .backgroundColor('#f9ca24')
            .borderRadius(22)
            .width('76%')
            .margin({ top: 12 })
            .padding({ top: 11, bottom: 11 })
            .onClick((): void => { this.goPray() })
        } else {
          Text('跳过动画 · 直接看签 ›')
            .fontSize(12)
            .fontColor('rgba(253, 246, 227, 0.5)')
            .padding({ top: 8, bottom: 8, left: 16, right: 16 })
            .onClick((): void => { this.skipToReveal() })
        }
      }
      .position({ x: '50%', y: '86%' })
      .translate({ x: '-50%', y: '-50%' })

      // 签录覆层（记录列表）
      if (this.showQiuList) {
        this.QiuRecordListOverlay()
      }

      // 解签详情覆层（当前签 / 签录记录行共用；✕ 或点遮罩关闭）
      if (this.showDetail) {
        this.SignDetailOverlay(this.detail)
      }
    }
    .width('100%')
    .height('100%')
  }

  /** 主舞台：签筒（求签过程）或签纸（已揭晓） */
  @Builder
  StageView() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.phase !== QiuPhase.REVEAL) {
        // 磕头（绕 X 轴俯身，有动画）→ 淡出 → 摇晃（绕 Z 轴，无动画瞬时摆动）
        Column() {
          Column() {
            Column() {
              this.TubeView()
            }
            .rotate({ z: 1, centerX: '50%', centerY: '100%', angle: this.shakeAngle })
          }
          .opacity(this.stageOpacity)
          .animation({ duration: 300, curve: Curve.EaseInOut })
        }
        .rotate({ x: 1, centerX: '50%', centerY: '100%', angle: this.bowAngle })
        .animation({ duration: BOW_HOLD_MS, curve: Curve.EaseInOut })
      }

      // 弹出签支（仅 LAUNCH 阶段渲染，从签筒中升起；Friction 带回弹下落感）
      if (this.phase === QiuPhase.LAUNCH) {
        Column() {
          this.LaunchStick()
        }
        .translate({ y: this.stickRiseY })
        .animation({ duration: LAUNCH_MS - 60, curve: Curve.Friction })
      }

      // 签纸（REVEAL 阶段：翻牌入场）
      if (this.phase === QiuPhase.REVEAL) {
        this.SignPaperCard()
      }
    }
    .width('100%')
    .height(360)
  }

  /** 求签舞台画面：直接使用用户提供的签筒素材（props/qiu_art.png，透明底）。
   *  动画为整图俯身 / 摇摆 / 附加正弦微摆；出签的签支由 SignStick 程序化绘制 */
  @Builder
  TubeView() {
    Column() {
      Image($rawfile('props/qiu_art.png'))
        .width(QIU_ART_W)
        .height(QIU_ART_H)
        .objectFit(ImageFit.Fill)
        .interpolation(ImageInterpolation.High)
        .shadow({ radius: 30, color: 'rgba(0, 0, 0, 0.55)', offsetY: 10 })
    }
    .width(QIU_ART_W)
    .height(QIU_ART_H)
    // 摇筒时整图附加小幅摆动（叠加于 StageView 的摇摆之上）；静止/出签归 0
    .rotate({ z: 1, centerX: '50%', centerY: '100%', angle: this.fanSway })
    .animation({ duration: SHAKE_STEP_MS, curve: Curve.Smooth })
  }

  /** 弹出签支（LAUNCH）：直接使用从求签素材裁出的筒内同款签原图
   *  （props/qiu_stick_pick.png，13×100，红漆身+金竖高光），非程序化重绘 */
  @Builder
  LaunchStick() {
    Column() {
      Image($rawfile('props/qiu_stick_pick.png'))
        .width(QIU_STICK_IMG_W)
        .height(QIU_STICK_IMG_H)
        .objectFit(ImageFit.Contain)
        .interpolation(ImageInterpolation.High)
    }
    .width(QIU_STICK_IMG_W)
    .height(QIU_STICK_IMG_H)
    .shadow({ radius: 10, color: 'rgba(255, 190, 60, 0.35)', offsetY: 2 })
  }

  /** 签纸卡片：签号/吉凶/签名/签诗，翻牌动画，点击看解签 */
  @Builder
  SignPaperCard() {
    Column() {
      Text(`第 ${this.sign.id} 签`)
        .fontSize(11)
        .fontColor('#a0342b')
      Text(this.sign.level)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        // 浅色签纸用深色油墨（LEVEL_COLOR 的亮色在 #f5e6c8 上对比度不足 3:1）
        .fontColor('#4a3520')
        .margin({ top: 6 })
      Text(this.sign.title)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor('#4a3520')
        .margin({ top: 8 })
      Text('· ─ ─ ─ ·')
        .fontSize(11)
        .fontColor('#a0342b')
        .margin({ top: 10, bottom: 10 })
      Text(this.sign.poem)
        .fontSize(14)
        .fontStyle(FontStyle.Italic)
        .fontColor('#4a3520')
        .textAlign(TextAlign.Center)
        .lineHeight(22)
      // 朱印
      Stack() {
        Circle({ width: 46, height: 46 })
          .fill('#c0392b')
        Text(this.sign.level.replace('签', ''))
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#fdf6e3')
      }
      .margin({ top: 14 })
    }
    .width('56%')
    .padding({ top: 24, bottom: 24, left: 18, right: 18 })
    .backgroundColor('#f5e6c8')
    .border({ width: 2, color: '#c04a32', radius: 12 })
    .shadow({ radius: 28, color: 'rgba(0, 0, 0, 0.55)', offsetY: 10 })
    .opacity(this.cardOpacity)
    .rotate({ y: 1, angle: this.cardFlipAngle })
    .animation({ duration: 550, curve: Curve.Friction })
    .onClick((): void => { this.openDetail(this.sign) })
  }

  /** 解签详情覆层（当前签 / 签录记录行共用，sign 参数化）。
   *  签已自动记入签录，无需「收下」；关闭 = 右上角 ✕ 或点遮罩。 */
  @Builder
  SignDetailOverlay(sign: SignEntry) {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.65)')
        .onClick((): void => { this.tryCloseDetail() })

      Column() {
        Row() {
          Text(`第 ${sign.id} 签`)
            .fontSize(12)
            .fontColor('rgba(253, 246, 227, 0.5)')
          Blank()
          Text(sign.level)
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getLevelColor(sign.level))
            .padding({ left: 10, right: 10, top: 3, bottom: 3 })
            .border({ width: 1, color: this.getLevelColor(sign.level), radius: 12 })
          Text('✕')
            .fontSize(17)
            .fontColor('rgba(253, 246, 227, 0.8)')
            .padding({ left: 14 })
            .onClick((): void => { this.showDetail = false })
        }
        .width('100%')

        Text(sign.title)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#f9ca24')
          .margin({ top: 16 })

        Text(sign.poem)
          .fontSize(16)
          .fontColor('#fdf6e3')
          .fontStyle(FontStyle.Italic)
          .textAlign(TextAlign.Center)
          .margin({ top: 10 })

        if (this.unlocked) {
          Text(`解签：${sign.interpretation}`)
            .fontSize(13)
            .fontColor('rgba(253, 246, 227, 0.85)')
            .lineHeight(20)
            .margin({ top: 16 })

          Text(`今日建议：${sign.advice}`)
            .fontSize(12)
            .fontColor('rgba(249, 202, 36, 0.8)')
            .lineHeight(19)
            .margin({ top: 10 })
        } else {
          // 锁占位：解签文 + 买断入口（WCAG：金底深字 #1a1a0a 实色，禁用仅用 enabled 不压暗）
          Column() {
            Text('🔒 解签文已锁')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('rgba(253, 246, 227, 0.85)')
            Text(`¥${UNLOCK_PRODUCT.amount} 买断 · 一次解锁永久畅看`)
              .fontSize(11)
              .fontColor('rgba(253, 246, 227, 0.5)')
              .margin({ top: 4 })
            Button(this.unlocking ? '解锁中…' : '🔓 永久解锁')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1a1a0a')
              .backgroundColor('#f9ca24')
              .borderRadius(20)
              .padding({ left: 26, right: 26, top: 9, bottom: 9 })
              .margin({ top: 12 })
              .enabled(!this.unlocking)
              .onClick((): void => { this.unlockJieqian() })
          }
          .width('100%')
          .padding({ top: 14, bottom: 14 })
          .border({ width: 1, color: 'rgba(249, 202, 36, 0.35)', radius: 12 })
          .backgroundColor('rgba(249, 202, 36, 0.06)')
          .margin({ top: 14 })
        }

        Row() {
          Button(this.unlocked ? '📋 复制签文' : '🔒 解锁后可复制')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor('#f9ca24')
            .backgroundColor('rgba(249, 202, 36, 0.12)')
            .border({ width: 1, color: '#f9ca24' })
            .borderRadius(20)
            .layoutWeight(1)
            .padding({ top: 11, bottom: 11 })
            .enabled(this.unlocked)
            .onClick((): void => { this.copySignText(sign) })
          Button('🙏 去祈福')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1a1a0a')
            .backgroundColor('#f9ca24')
            .borderRadius(20)
            .layoutWeight(1)
            .margin({ left: 10 })
            .padding({ top: 11, bottom: 11 })
            .onClick((): void => { this.goPray() })
        }
        .width('100%')
        .margin({ top: 22 })
      }
      .width('82%')
      .padding(24)
      .backgroundColor('#241f12')
      .border({ width: 1, color: 'rgba(249, 202, 36, 0.35)', radius: 16 })
      .shadow({ radius: 30, color: 'rgba(0, 0, 0, 0.5)', offsetY: 8 })
    }
    .width('100%')
    .height('100%')
  }

  /** 签录入口（标题下方小胶囊：📜 签录 + 条数角标） */
  @Builder
  QiuHistoryPill() {
    Row() {
      Text('📜 签录')
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor('#f9ca24')
      if (this.qiuRecords.length > 0) {
        Text(`${this.qiuRecords.length}`)
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1a1a0a')
          .backgroundColor('#f9ca24')
          .borderRadius(8)
          .padding({ left: 5, right: 5, top: 1, bottom: 1 })
          .margin({ left: 5 })
      }
    }
    .padding({ left: 13, right: 13, top: 9, bottom: 9 })
    .backgroundColor('rgba(249, 202, 36, 0.08)')
    .border({ width: 1, color: 'rgba(249, 202, 36, 0.25)', radius: 15 })
    .onClick((): void => {
      this.openList()
    })
  }

  /** 签录覆层：今日额度 + 记录列表（自动记录，点行看完整签文；清空需二次确认） */
  @Builder
  QiuRecordListOverlay() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.65)')
        .onClick((): void => { this.tryCloseList() })

      Column() {
        Row() {
          Text('📜 求签记录')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#f9ca24')
          Blank()
          Text(`今日已求 ${this.todayUsed}/${MAX_DAILY_QIU} 签`)
            .fontSize(12)
            .fontColor('rgba(253, 246, 227, 0.6)')
          Text('✕')
            .fontSize(17)
            .fontColor('rgba(253, 246, 227, 0.8)')
            .padding({ left: 14 })
            .onClick((): void => {
              this.showQiuList = false
              this.clearArmed = false
            })
        }
        .width('100%')

        if (this.qiuRecords.length === 0) {
          Column() {
            Text('🍂')
              .fontSize(30)
            Text('尚无签录')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor('rgba(253, 246, 227, 0.7)')
              .margin({ top: 8 })
            Text('摇一签即自动记入，每日最多 3 签')
              .fontSize(11)
              .fontColor('rgba(253, 246, 227, 0.55)')
              .margin({ top: 6 })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          Scroll() {
            Column() {
              ForEach(this.qiuRecords, (rec: QiuRecord) => {
                this.QiuRecordRow(rec)
              }, (rec: QiuRecord): string => rec.recId)
            }
            .width('100%')
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
          .margin({ top: 8 })

          Text(this.clearArmed ? '⚠ 再点一次确认清空' : '清空记录')
            .fontSize(12)
            .fontColor(this.clearArmed ? '#f0533f' : 'rgba(253, 246, 227, 0.55)')
            .padding({ top: 10, bottom: 10 })
            .width('100%')
            .textAlign(TextAlign.Center)
            .onClick((): void => { this.onClearTap() })
        }
      }
      .width('88%')
      .height('76%')
      .padding({ left: 18, right: 18, top: 18, bottom: 14 })
      .backgroundColor('#241f12')
      .border({ width: 1, color: 'rgba(249, 202, 36, 0.35)', radius: 16 })
      .shadow({ radius: 30, color: 'rgba(0, 0, 0, 0.5)', offsetY: 8 })
    }
    .width('100%')
    .height('100%')
  }

  /** 签录单行：日期时间 + 等级·签名（等级色）+ 签诗摘要，点击看完整签文 */
  @Builder
  QiuRecordRow(rec: QiuRecord) {
    Column() {
      Row() {
        Column() {
          Text(this.fmtDate(rec.ts))
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor('rgba(253, 246, 227, 0.75)')
          Text(this.fmtClock(rec.ts))
            .fontSize(10)
            .fontColor('rgba(253, 246, 227, 0.5)')
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .width(72)

        Column() {
          Text(`${rec.sign.level} · ${rec.sign.title}`)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getLevelColor(rec.sign.level))
          Text(rec.sign.poem)
            .fontSize(11)
            .fontColor('rgba(253, 246, 227, 0.5)')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 3 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 6 })

        Text('›')
          .fontSize(16)
          .fontColor('rgba(253, 246, 227, 0.5)')
          .margin({ left: 6 })
      }
      .width('100%')
      .padding({ top: 10, bottom: 10 })
      .onClick((): void => { this.openDetail(rec.sign) })

      Divider()
        .color('rgba(253, 246, 227, 0.07)')
        .strokeWidth(1)
    }
    .width('100%')
  }

  // ── 签录工具 ──

  /** 打开解签详情（当前签揭晓 / 签录记录行共用入口） */
  private openDetail(sign: SignEntry): void {
    this.detail = sign
    this.detailOpenedAt = Date.now()
    this.showDetail = true
    this.tryRestoreUnlock()
  }

  /** 未解锁时静默恢复权益（重装/换机/上次云端未记）：打开详情即自动解锁 */
  private tryRestoreUnlock(): void {
    if (this.qiuVM.isUnlocked() || this.restoreCheckDone) {
      return
    }
    this.restoreCheckDone = true
    const iap = new IapPaymentService(this.getUIContext().getHostContext() as common.UIAbilityContext)
    iap.restoreOwned().then(async (owned: UnlockPurchaseResult | null) => {
      if (owned !== null) {
        await this.applyUnlock(owned)
      }
    }).catch((err: Object) => {
      console.error('[QiuQian] restoreUnlock failed:', JSON.stringify(err))
    })
  }

  /** 解锁流程：已购恢复 → 买断 → 本地置位 + 云端幂等补记 */
  private async unlockJieqian(): Promise<void> {
    if (this.unlocking) {
      return
    }
    this.unlocking = true
    try {
      const iap = new IapPaymentService(this.getUIContext().getHostContext() as common.UIAbilityContext)
      // ① 已购恢复（重装/换机/上次云端未记）
      const owned: UnlockPurchaseResult | null = await iap.restoreOwned()
      if (owned !== null) {
        await this.applyUnlock(owned)
        return
      }
      // ② 买断
      const result: UnlockPurchaseResult = await iap.purchase()
      if (result.canceled) {
        return  // 用户取消：静默
      }
      await this.applyUnlock(result)
    } catch (err) {
      this.handleUnlockError(err)
    } finally {
      this.unlocking = false
    }
  }

  /** 解锁落账：本地置位（主权益源，立即生效）+ 云端幂等补记（失败不阻塞解锁） */
  private async applyUnlock(result: UnlockPurchaseResult): Promise<void> {
    if (this.unlocked) {
      return  // 已解锁（恢复/买断并发竞态）：幂等短路，避免双 toast 与重复记账
    }
    await this.qiuVM.setUnlocked(true)
    this.unlocked = true
    this.toast('解签已解锁 · 功德圆满 🙏')
    CloudService.recordSignUnlock({
      productId: result.productId,
      purchaseToken: result.purchaseToken,
      purchaseData: result.purchaseData,
      orderId: result.orderId
    })
  }

  private handleUnlockError(err: Object): void {
    if (err instanceof PaymentError) {
      const pe = err as PaymentError
      if (pe.kind === PaymentErrorKind.NEED_LOGIN) {
        // 与供奉弹窗同款 v1 指引：系统设置登录（LoginWithHuaweiID 引导留 v2）
        this.toast('解锁需登录华为帐号，请在系统设置中登录后重试')
      } else if (pe.kind === PaymentErrorKind.ALREADY_OWNED) {
        // 已拥有但 restoreOwned 未生效（queryPurchases 瞬断）：重置恢复标记直接再恢复，
        // 成功路径走 applyUnlock 的「解签已解锁」toast
        this.restoreCheckDone = false
        this.tryRestoreUnlock()
      } else {
        this.toast(pe.message)
      }
      console.error('[QiuQian] unlock error: kind=' + pe.kind + ' code=' + pe.rawCode)
      return
    }
    const e = err as BusinessError
    console.error('[QiuQian] unlock error: code=' + e.code + ' msg=' + e.message)
    this.toast('购买失败请重试')
  }

  /** 打开签录（记录开启时刻，供遮罩点击保护） */
  private openList(): void {
    this.qiuListOpenedAt = Date.now()
    this.showQiuList = true
    this.clearArmed = false
    console.info(`[QiuQian] open qiu list, records=${this.qiuRecords.length}`)
  }

  /** 关签录（打开后短窗口内的点击可能是开窗动作本身，忽略） */
  private tryCloseList(): void {
    if (Date.now() - this.qiuListOpenedAt < LIST_OPEN_GRACE_MS) {
      return
    }
    this.showQiuList = false
    this.clearArmed = false
  }

  /** 关详情（同上的开窗保护） */
  private tryCloseDetail(): void {
    if (Date.now() - this.detailOpenedAt < LIST_OPEN_GRACE_MS) {
      return
    }
    this.showDetail = false
  }

  /** 从 VM 同步签录与今日额度快照（本页为唯一写入方，揭晓/清空后自行刷新） */
  private syncFromVM(): void {
    this.qiuRecords = this.qiuVM.records
    this.todayUsed = this.qiuVM.usedToday()
    this.unlocked = this.qiuVM.isUnlocked()
  }

  private onClearTap(): void {
    if (this.qiuRecords.length === 0) return
    if (!this.clearArmed) {
      this.clearArmed = true
      this.toast('再点一次确认清空全部签录')
      this.after(2600, (): void => { this.clearArmed = false })
      return
    }
    this.clearArmed = false
    this.qiuVM.clearRecords().catch((err: Object) => {
      console.error('[QiuQian] clearRecords failed:', JSON.stringify(err))
    })
    this.qiuRecords = []
    this.toast('签录已清空')
  }

  private idleSubText(): string {
    if (this.todayUsed >= MAX_DAILY_QIU) {
      return '今日已满 3 签 · 明日再来 🙏'
    }
    if (this.todayUsed > 0) {
      return `今日已求 ${this.todayUsed}/${MAX_DAILY_QIU} 签 · 心诚则灵`
    }
    return '摇得越诚心 · 签文越灵验'
  }

  private toast(msg: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg })
    } catch (err) {
      console.error('[QiuQian] toast failed:', JSON.stringify(err))
    }
  }

  private fmtDate(ts: number): string {
    const d = new Date(ts)
    return `${this.pad(d.getMonth() + 1)}-${this.pad(d.getDate())}`
  }

  private fmtClock(ts: number): string {
    const d = new Date(ts)
    return `${this.pad(d.getHours())}:${this.pad(d.getMinutes())}`
  }

  private pad(n: number): string {
    return n < 10 ? `0${n}` : `${n}`
  }
}
