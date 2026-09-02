// entry/src/main/ets/pages/CustomizePage.ets
// 界面定制子页（从「我的」进入）：长按拖拽调整入口顺序 + 开关控制是否显示为底部 Tab。
// 祈福（固定首位）与我的（固定末位）不可开关。列表顺序同时决定底部 Tab 顺序
// 与「我的」页入口顺序（同一 order 字段）。
// 说明：List 绑定 onItemDragStart 后，长按（约 170ms）列表项即可拖拽，onItemDrop 落点回调。
import { EntryConfigVM, EntryItem } from '../viewmodels/EntryConfigVM'

@Entry
@Component
struct CustomizePage {
  @StorageLink('entryConfigVM') entryConfigVM: EntryConfigVM = new EntryConfigVM()
  // UI v1：@StorageLink 不通知 @Observed 嵌套变更，依赖 VM bump 的 rev 信号重建
  @StorageLink('entryConfigRev') @Watch('onEntryConfigRev') entryConfigRev: number = 0
  @State items: EntryItem[] = []
  // 渲染 nonce：并入 ForEach key，开关回滚/顺序变化时强制行重建，
  // 保证 Toggle 视觉与模型一致（仅靠内容 diff 时 Toggle 内部态可能不跟随）
  @State renderNonce: number = 0
  private dragFrom: number = -1
  private dragIcon: string = '🀄'
  private dragTitle: string = ''

  aboutToAppear(): void {
    this.syncItems()
  }

  onEntryConfigRev(): void {
    this.syncItems()
  }

  private syncItems(): void {
    this.items = this.entryConfigVM.getSortedItems()
    this.renderNonce++
  }

  private enabledCount(): number {
    let n: number = 0
    for (const it of this.items) {
      if (it.enabled) {
        n++
      }
    }
    return n
  }

  private onToggle(item: EntryItem, on: boolean): void {
    if (on) {
      const ok = this.entryConfigVM.setEnabled(item.id, true)
      if (!ok) {
        this.toast('最多同时开启 3 个 Tab：请先关闭一个，再开启新的')
        this.syncItems() // setEnabled 拒绝时不会发 rev，这里手动回滚开关视觉
      }
    } else {
      this.entryConfigVM.setEnabled(item.id, false)
    }
  }

  private toast(msg: string): void {
    this.getUIContext().getPromptAction().showToast({ message: msg, duration: 2500 })
  }

  build() {
    Column() {
      // 返回头
      Row() {
        Text('← 返回')
          .fontSize(14)
          .fontColor('#f9ca24')
          .onClick((): void => {
            this.getUIContext().getRouter().back()
          })
        Blank()
        Text('界面定制')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#f9ca24')
        Blank()
        Text(' ')
          .fontSize(14)
          .width(60)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 44, bottom: 6 })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

      // 状态说明
      Column() {
        Row() {
          Text('🀄 祈福（固定首位）')
            .fontSize(11)
            .fontColor('rgba(253, 246, 227, 0.6)')
          Blank()
          Text(`可选已开 ${this.enabledCount()}/3`)
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.enabledCount() >= 3 ? '#e74c3c' : 'rgba(249, 202, 36, 0.9)')
          Text('　🧧 我的（固定末位）')
            .fontSize(11)
            .fontColor('rgba(253, 246, 227, 0.6)')
        }
        .width('100%')
        .margin({ bottom: 4 })

        Text('长按行拖动调整顺序（底部 Tab 与「我的」入口共用此顺序）')
          .fontSize(10)
          .fontColor('rgba(253, 246, 227, 0.45)')
          .width('100%')
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 8 })

      // 排序列表：长按 170ms 进入拖拽
      List({ space: 10 }) {
        ForEach(this.items, (item: EntryItem) => {
          ListItem() {
            this.SortRow(item)
          }
        }, (item: EntryItem) => `${item.id}-${this.renderNonce}`)
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 20 })
      .edgeEffect(EdgeEffect.Spring)
      .scrollBar(BarState.Off)
      .onItemDragStart((event, itemIndex) => {
        this.dragFrom = itemIndex
        const it = this.items[itemIndex]
        if (it) {
          this.dragIcon = this.entryConfigVM.getIcon(it.id)
          this.dragTitle = this.entryConfigVM.getTitle(it.id)
        }
        return this.DragPreview
      })
      .onItemDrop((event, itemIndex, insertIndex, isSuccess) => {
        if (isSuccess && this.dragFrom >= 0) {
          const from = this.dragFrom
          this.dragFrom = -1
          // insertIndex 为落点插入位：目标在拖动项之后时系统计数含自身，需 -1
          let to = insertIndex > from ? insertIndex - 1 : insertIndex
          const max = this.items.length - 1
          if (to < 0) {
            to = 0
          }
          if (to > max) {
            to = max
          }
          if (to !== from) {
            this.entryConfigVM.move(from, to)
          }
        } else {
          this.dragFrom = -1
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1a1a0a')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
  }

  @Builder
  SortRow(item: EntryItem) {
    Row() {
      Text('≡')
        .fontSize(18)
        .fontColor('rgba(253, 246, 227, 0.45)')
        .width(26)
        .textAlign(TextAlign.Center)

      Text(this.entryConfigVM.getIcon(item.id))
        .fontSize(22)
        .fontColor('#f9ca24')
        .margin({ left: 4 })

      Column() {
        Text(this.entryConfigVM.getTitle(item.id))
          .fontSize(14)
          .fontColor('#fdf6e3')
        Text(item.enabled ? '✓ 显示在底部 Tab' : '未开启：从「我的」页进入')
          .fontSize(10)
          .fontColor(item.enabled ? 'rgba(46, 204, 113, 0.9)' : 'rgba(253, 246, 227, 0.5)')
          .margin({ top: 3 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 10 })

      Toggle({ type: ToggleType.Switch, isOn: item.enabled })
        // 已满 3 个 Tab 时未开启行的开关禁用（提示见顶部文案），已开启行仍可关闭
        .enabled(item.enabled || this.enabledCount() < 3)
        .onChange((isOn: boolean) => {
          this.onToggle(item, isOn)
        })
    }
    .width('100%')
    .padding(12)
    .backgroundColor('rgba(249, 202, 36, 0.05)')
    .border({ width: 1, color: 'rgba(249, 202, 36, 0.12)', radius: 10 })
  }

  // 拖拽时的悬浮预览
  @Builder
  DragPreview() {
    Row() {
      Text(this.dragIcon)
        .fontSize(18)
      Text(this.dragTitle)
        .fontSize(14)
        .fontColor('#f9ca24')
        .margin({ left: 8 })
    }
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .backgroundColor('#241f12')
    .border({ width: 1, color: 'rgba(249, 202, 36, 0.5)', radius: 10 })
  }
}
