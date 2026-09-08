import { Achievement } from '../model/EnrichTypes'
import { EnrichViewModel } from '../viewmodels/EnrichViewModel'
import { MahjongTile } from './MahjongTile'

// 麻将牌 emoji（深色牌面在深色背景上不可见，需主题金底牌面展示）
const MAHJONG_ICONS: string[] = ['🀄', '🀇', '🀈', '🀉', '🀊', '🀋', '🀌', '🀍', '🀅']

function isMahjongIcon(icon: string): boolean {
  return MAHJONG_ICONS.includes(icon)
}

@Component
export struct AchievementGrid {
  @Link enrichVM: EnrichViewModel
  @State newlyUnlockedId: string = ''
  @State glowScale: number = 1.0
  @State glowOpacity: number = 0

  aboutToAppear(): void {
    // 如果进入成就页时有新解锁的徽章，播放动画
    // 使用 enrichVM.lastUnlockedBadgeId（非 AppStorage，MainTabs 不会清掉它）
    const badgeId: string = this.enrichVM.lastUnlockedBadgeId
    if (badgeId !== '') {
      this.enrichVM.lastUnlockedBadgeId = ''
      setTimeout(() => { this.playUnlockAnimation(badgeId) }, 200)
    }
  }

  build() {
    Column() {
      Text('🏅 成就徽章')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#f9ca24')
        .width('90%')
        .margin({ bottom: 12 })

      Grid() {
        ForEach(this.enrichVM.achievements, (badge: Achievement) => {
          GridItem() {
            this.BadgeItem(badge)
          }
        })
      }
      .columnsTemplate('1fr 1fr 1fr 1fr')
      .rowsGap(12)
      .columnsGap(8)
      // alwaysEnabled：内容不满一屏时也回弹，满足 AGC「滑动到边界有反馈动效」
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .width('90%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  BadgeItem(badge: Achievement) {
    Stack() {
      // 解锁光晕效果（仅新解锁的成就显示）
      if (badge.unlocked && badge.badgeId === this.newlyUnlockedId) {
        Column()
          .width(60)
          .height(60)
          .borderRadius(30)
          .backgroundColor('rgba(249, 202, 36, 0.4)')
          .opacity(this.glowOpacity)
          .scale({ x: this.glowScale, y: this.glowScale })
      }

      Column() {
        if (isMahjongIcon(badge.icon)) {
          MahjongTile({ icon: badge.icon, tileSize: 36 })
            .opacity(badge.unlocked ? 1 : 0.6)
            .scale(badge.unlocked && badge.badgeId === this.newlyUnlockedId
              ? { x: this.glowScale, y: this.glowScale } : { x: 1, y: 1 })
        } else {
          Text(badge.icon)
            .fontSize(28)
            .opacity(badge.unlocked ? 1 : 0.6)
            .grayscale(badge.unlocked ? 0 : 1)
            .scale(badge.unlocked && badge.badgeId === this.newlyUnlockedId
              ? { x: this.glowScale, y: this.glowScale } : { x: 1, y: 1 })
        }

        Text(badge.name)
          .fontSize(10)
          .fontWeight(FontWeight.Medium)
          .fontColor(badge.unlocked ? '#f9ca24' : 'rgba(253, 246, 227, 0.5)')
          .margin({ top: 4 })
          .textAlign(TextAlign.Center)

        // 解锁标记
        if (badge.unlocked) {
          Text('✦ 已解锁')
            .fontSize(8)
            .fontColor('rgba(249, 202, 36, 0.7)')
            .margin({ top: 2 })
        }

        if (!badge.unlocked && badge.progress > 0) {
          Stack() {
            Row()
              .width('80%')
              .height(3)
              .backgroundColor('rgba(253, 246, 227, 0.1)')
              .borderRadius(2)
            Row()
              .width(`${badge.progress * 80}%`)
              .height(3)
              .backgroundColor('#f9ca24')
              .borderRadius(2)
          }
          .width('80%')
          .margin({ top: 4 })
        }
      }
      .width('100%')
      .padding({ top: 8, bottom: 8 })
      .alignItems(HorizontalAlign.Center)
      .borderRadius(8)
      .backgroundColor(badge.unlocked ? 'rgba(249, 202, 36, 0.08)' : 'rgba(253, 246, 227, 0.03)')
      .border({
        width: badge.unlocked ? 1.5 : 0,
        color: badge.badgeId === this.newlyUnlockedId ? '#f9ca24' : 'rgba(249, 202, 36, 0.2)',
        radius: 8
      })
      .shadow(badge.unlocked && badge.badgeId === this.newlyUnlockedId
        ? { radius: 12, color: 'rgba(249, 202, 36, 0.5)', offsetY: 0 }
        : { radius: 0, color: 'transparent', offsetY: 0 })
      .onClick(() => {
        const msg: string = badge.unlocked
          ? `${badge.name}：${badge.desc}（${badge.unlockDate} 解锁）`
          : `${badge.name}：${badge.desc}（进度 ${Math.round(badge.progress * 100)}%）`
        this.getUIContext().getPromptAction().showToast({ message: msg })
      })
    }
    .width('100%')
    .alignContent(Alignment.Center)
  }

  /** 触发解锁动画（由外部调用，如 refreshAchievements 检测到新解锁时） */
  playUnlockAnimation(badgeId: string): void {
    this.newlyUnlockedId = badgeId
    // 光晕脉冲动画：scale 1→1.5→1，opacity 0.8→0
    animateTo({
      duration: 300,
      curve: Curve.EaseOut,
      onFinish: () => {
        animateTo({
          duration: 400,
          curve: Curve.EaseInOut,
          onFinish: () => {
            this.newlyUnlockedId = ''
          }
        }, () => {
          this.glowScale = 1.0
          this.glowOpacity = 0
        })
      }
    }, () => {
      this.glowScale = 1.5
      this.glowOpacity = 0.8
    })
  }
}
