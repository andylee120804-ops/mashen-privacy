// entry/src/main/ets/components/LeaderboardItem.ets
import { LeaderboardEntry } from '../model/EnrichTypes'

@Component
export struct LeaderboardItem {
  @Prop entry: LeaderboardEntry
  @Prop isMe: boolean = false

  build() {
    Row() {
      // 排名
      Text(this.getRankText())
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.getRankColor())
        .width(40)
        .textAlign(TextAlign.Center)

      // 昵称
      Text(this.entry.nickname)
        .fontSize(14)
        .fontColor('#fdf6e3')
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      // 祈福次数
      Text(`${this.entry.count}次`)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#f9ca24')
        .margin({ right: 12 })

      // 磕头
      Text(`🙏${this.entry.kowtow}`)
        .fontSize(12)
        .fontColor('rgba(253, 246, 227, 0.5)')
    }
    .width('100%')
    .padding(12)
    .backgroundColor(this.isMe ? 'rgba(249, 202, 36, 0.12)' : 'transparent')
    .border({ width: { bottom: 0.5 }, color: 'rgba(249, 202, 36, 0.08)' })
    .borderRadius(this.isMe ? 8 : 0)
  }

  private getRankText(): string {
    if (this.entry.rank <= 0) return '···'
    if (this.entry.rank === 1) return '🥇'
    if (this.entry.rank === 2) return '🥈'
    if (this.entry.rank === 3) return '🥉'
    return `${this.entry.rank}`
  }

  private getRankColor(): string {
    if (this.entry.rank === 1) return '#f9ca24'
    if (this.entry.rank === 2) return '#c0c0c0'
    if (this.entry.rank === 3) return '#cd7f32'
    return 'rgba(253, 246, 227, 0.5)'
  }
}
