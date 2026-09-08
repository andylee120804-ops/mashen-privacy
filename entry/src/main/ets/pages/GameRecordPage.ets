// entry/src/main/ets/pages/GameRecordPage.ets
// 记录牌局：可配置底部 Tab 的完整内容页，也是「我的」页汇总卡「查看明细」的落点
// （Tab 模式由 MainTabs 渲染；独立模式 standalone=true，返回键并入大标题行）。
// 布局：顶部 = 汇总卡（周/月/年统计 + 记一笔），下方 = 按日分组的每笔明细。
// 数据与「我的」页固定汇总卡共用同一 enrichViewModel（AppStorage 全局单例），两边实时一致。
import { EnrichViewModel } from '../viewmodels/EnrichViewModel'
import { GameRecordCard } from '../components/GameRecordCard'
import { GameRecordDetailList } from '../components/GameRecordDetailList'
import { PageBack } from '../components/PageBack'

@Component
export struct GameRecordPage {
  /** 独立模式（EntryShell 从「我的」进入）：返回键并入大标题行；Tab 模式不带 */
  @Prop standalone: boolean = false
  @StorageLink('enrichViewModel') enrichVM: EnrichViewModel = new EnrichViewModel()
  /** 最近一次成功云备份时间（ISO，空=从未备份）。由 EnrichViewModel 写入 AppStorage */
  @StorageLink('lastGameRecordBackupAt') lastBackupAt: string = ''

  /** 把 ISO 时间转成本地「MM-DD HH:mm」展示 */
  private formatBackupTime(iso: string): string {
    if (!iso) return ''
    try {
      const d = new Date(iso)
      const pad = (n: number) => String(n).padStart(2, '0')
      return `${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`
    } catch {
      return ''
    }
  }

  build() {
    Column() {
      // 标题（与其他 Tab 页统一：20sp 金色粗体 + 入口同款 emoji，见黄历/木鱼/求签；
      // 独立模式返回键并入同行且标题居中；Tab 模式不带返回，标题保持左对齐）
      Row() {
        if (this.standalone) {
          PageBack()
        }
        Text('🎲 记录牌局')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#f9ca24')
          .layoutWeight(1)
          .textAlign(this.standalone ? TextAlign.Center : TextAlign.Start)
        if (this.standalone) {
          Text(' ')
            .fontSize(14)
            .width(76)
        }
      }
      .width('100%')
      .padding({ left: this.standalone ? 6 : 20, top: 44, bottom: 6 })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

      // 云端备份状态行（P1 同设备云备份：防本地数据丢失）
      Row() {
        Text(this.lastBackupAt
          ? `☁ 已云备份 ${this.formatBackupTime(this.lastBackupAt)}`
          : '☁ 联网后自动备份牌局记录，防丢失')
          .fontSize(11)
          .fontColor('rgba(253, 246, 227, 0.5)')
      }
      .width('100%')
      .padding({ left: this.standalone ? 6 : 20, right: 20, bottom: 4 })

      Scroll() {
        Column() {
          // 顶部：汇总 + 记一笔（贴近标题，减少上方留白）
          GameRecordCard({ enrichVM: $enrichVM })
            .margin({ top: 2 })

          // 下方：每笔明细（标题与空态由 DetailList 自行管理）
          GameRecordDetailList({ enrichVM: $enrichVM })

          Blank()
            .width(1)
            .height(20)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
      .layoutWeight(1)
      // alwaysEnabled：无记录/内容不足一屏时拖拽也有回弹（AGC 滑动动效标准）
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1a1a0a')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
  }
}
