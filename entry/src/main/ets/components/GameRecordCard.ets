import { GameRecord, GameResult } from '../model/EnrichTypes'
import { EnrichViewModel } from '../viewmodels/EnrichViewModel'
import { FIVE_DEITIES } from '../model/PrayerTypes'
import { DeityInfo } from '../model/PrayerTypes'

@Component
export struct GameRecordCard {
  @Link enrichVM: EnrichViewModel

  build() {
    Column() {
      // 今日牌运标题
      Row() {
        Text('🀇 今日牌运')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#f9ca24')
        Blank()
        Text('+ 记录牌局')
          .fontSize(12)
          .fontColor('rgba(249, 202, 36, 0.6)')
      }
      .width('100%')
      .margin({ bottom: 12 })

      // 牌局列表
      if (this.enrichVM.gameRecords.length === 0) {
        Text('暂无牌运记录，打牌后来记录吧')
          .fontSize(12)
          .fontColor('rgba(253, 246, 227, 0.3)')
          .fontStyle(FontStyle.Italic)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 20, bottom: 20 })
      } else {
        ForEach(this.enrichVM.gameRecords, (record: GameRecord) => {
          this.RecordItem(record)
        })
      }

      // 本周牌运统计
      if (this.enrichVM.gameRecords.length > 0) {
        Row()
          .width('100%')
          .height(1)
          .backgroundColor('rgba(249, 202, 36, 0.15)')
          .margin({ top: 12, bottom: 12 })

        this.WeekSummary()
      }
    }
    .width('90%')
    .padding(16)
    .backgroundColor('rgba(249, 202, 36, 0.05)')
    .border({ width: 1, color: 'rgba(249, 202, 36, 0.2)', radius: 12 })
  }

  @Builder
  RecordItem(record: GameRecord) {
    Column() {
      Row() {
        Text(`📅 ${record.date}`)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#fdf6e3')
        Blank()
        Text(this.getDeityName(record.deityId))
          .fontSize(11)
          .fontColor('rgba(253, 246, 227, 0.4)')
      }
      .width('100%')

      if (record.games.length > 0) {
        // 符号行
        Row() {
          ForEach(record.games, (game: GameResult) => {
            Text(game.result)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(game.result === '+' ? '#2ecc71' : 'rgba(253, 246, 227, 0.4)')
              .margin({ right: 4 })
          })
        }
        .width('100%')
        .margin({ top: 6 })

        // 数字行
        Row() {
          ForEach(record.games, (game: GameResult) => {
            Text(`${game.magnitude}`)
              .fontSize(12)
              .fontColor(game.result === '+' ? 'rgba(46, 204, 113, 0.7)' : 'rgba(253, 246, 227, 0.3)')
              .margin({ right: 4 })
              .width(20)
              .textAlign(TextAlign.Center)
          })
        }
        .width('100%')
      }

      // 备注
      if (record.note) {
        Text(record.note)
          .fontSize(11)
          .fontColor('rgba(253, 246, 227, 0.4)')
          .fontStyle(FontStyle.Italic)
          .margin({ top: 6 })
      }
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .border({ width: { bottom: 0.5 }, color: 'rgba(249, 202, 36, 0.08)' })
  }

  @Builder
  WeekSummary() {
    Column() {
      Text('📊 本周牌运')
        .fontSize(12)
        .fontColor('rgba(249, 202, 36, 0.7)')
        .margin({ bottom: 6 })

      // 本周符号串
      Row() {
        ForEach(this.getWeekGames(), (game: GameResult) => {
          Text(game.result)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(game.result === '+' ? '#2ecc71' : 'rgba(253, 246, 227, 0.4)')
            .margin({ right: 2 })
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)

      const winRate = this.enrichVM.getWinRate()
      Row() {
        Text(`祈福胜率：${winRate.rate}%`)
          .fontSize(11)
          .fontColor('rgba(253, 246, 227, 0.5)')
        Text(' | ')
          .fontSize(11)
          .fontColor('rgba(253, 246, 227, 0.2)')
        Text(`最佳财神：${this.enrichVM.getBestDeity()}`)
          .fontSize(11)
          .fontColor('rgba(253, 246, 227, 0.5)')
      }
      .margin({ top: 4 })
    }
  }

  private getWeekGames(): GameResult[] {
    const now = new Date()
    const weekAgo: number = now.getTime() - 7 * 86400000
    const weekDate: Date = new Date(weekAgo)
    const weekStr: string = `${weekDate.getFullYear()}-${String(weekDate.getMonth() + 1).padStart(2, '0')}-${String(weekDate.getDate()).padStart(2, '0')}`
    const results: GameResult[] = []
    for (const r of this.enrichVM.gameRecords) {
      if (r.date >= weekStr) {
        for (const g of r.games) {
          results.push(g)
        }
      }
    }
    return results
  }

  private getDeityName(deityId: number): string {
    const deity: DeityInfo | undefined = FIVE_DEITIES.find((d: DeityInfo) => d.id === deityId)
    if (deity) {
      return `${deity.name}（${deity.direction}）`
    }
    return ''
  }
}