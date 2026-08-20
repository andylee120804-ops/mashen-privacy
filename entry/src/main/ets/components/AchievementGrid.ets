import { Achievement } from '../model/EnrichTypes'
import { EnrichViewModel } from '../viewmodels/EnrichViewModel'
import { promptAction } from '@kit.ArkUI'

@Component
export struct AchievementGrid {
  @Link enrichVM: EnrichViewModel

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
      .width('90%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  BadgeItem(badge: Achievement) {
    Column() {
      Text(badge.icon)
        .fontSize(28)
        .opacity(badge.unlocked ? 1 : 0.25)
        .grayscale(badge.unlocked ? 0 : 1)

      Text(badge.name)
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor(badge.unlocked ? '#f9ca24' : 'rgba(253, 246, 227, 0.3)')
        .margin({ top: 4 })
        .textAlign(TextAlign.Center)

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
    .border({ width: badge.unlocked ? 1 : 0, color: 'rgba(249, 202, 36, 0.2)', radius: 8 })
    .onClick(() => {
      const msg: string = badge.unlocked
        ? `${badge.name}：${badge.desc}（${badge.unlockDate} 解锁）`
        : `${badge.name}：${badge.desc}（进度 ${Math.round(badge.progress * 100)}%）`
      this.getUIContext().getPromptAction().showToast({ message: msg })
    })
  }
}