import { PrayerViewModel } from '../viewmodels/PrayerViewModel'
import { KowtowFrameCache } from '../service/KowtowFrameCache'
import { CloudService } from '../service/CloudService'
import { MahjongTile } from '../components/MahjongTile'
import { FIVE_DEITIES, DeityInfo } from '../model/PrayerTypes'
import { WISH_TEMPLATES } from '../model/CultureContent'
import { router } from '@kit.ArkUI'

@Entry
@Component
struct NameCard {
  @StorageLink('viewModel') viewModel: PrayerViewModel = new PrayerViewModel()
  @State inputName: string = ''
  @State wishContent: string = ''
  @State selectedDeity: number = 0

  aboutToAppear(): void {
    // 用户输入姓名期间后台预解码磕头帧（native 线程，不占主线程），
    // 进入 PrayerCard 磕头阶段时帧缓存已就绪，首帧即点即显
    const ctx = this.getUIContext().getHostContext()
    if (ctx) {
      KowtowFrameCache.preload(ctx)
    }
  }

  build() {
    Column() {
      // 祥云装饰
      Text('☁')
        .fontSize(40)
        .fontColor('rgba(249, 202, 36, 0.45)')
        .position({ x: 20, y: 40 })

      Column() {
        // 标题
        Text('🙏 祈福者')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#f9ca24')
          .margin({ bottom: 32 })

        // 输入框
        Stack() {
          TextInput({ placeholder: '输入祈福者的姓名', text: this.inputName })
            .fontSize(16)
            .fontColor('#fdf6e3')
            .placeholderColor('rgba(253, 246, 227, 0.5)')
            .backgroundColor('rgba(249, 202, 36, 0.06)')
            .border({ width: 2, color: 'rgba(249, 202, 36, 0.35)', radius: 8 })
            .padding(16)
            .width('75%')
            .onChange((value: string) => {
              this.inputName = value
            })
        }
        .width('100%')

        // 最近使用
        if (this.viewModel.recentNames.length > 0) {
          Column() {
            Text('最近使用')
              .fontSize(11)
              .fontColor('rgba(249, 202, 36, 0.6)')
              .margin({ top: 16, bottom: 8 })

            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
              ForEach(this.viewModel.recentNames, (name: string) => {
                Row() {
                  MahjongTile({ icon: '🀅', tileSize: 20 })
                  Text(name)
                    .fontSize(12)
                    .fontColor('rgba(249, 202, 36, 0.7)')
                    .margin({ left: 6 })
                  Text(' ×')
                    .fontSize(10)
                    .fontColor('rgba(249, 202, 36, 0.7)')
                }
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .backgroundColor('rgba(249, 202, 36, 0.1)')
                .border({ width: 1, color: 'rgba(249, 202, 36, 0.2)', radius: 20 })
                .margin({ right: 8 })
                .onClick(() => {
                  this.inputName = name
                })
                .gesture(
                  LongPressGesture({ repeat: false })
                    .onAction(() => {
                      this.showDeleteNameConfirm(name)
                    })
                )
              })
            }
          }
          .width('75%')
        }

        // 许愿区域（可选，磕头前许下心愿）
        Row()
          .width('60%')
          .height(0.5)
          .backgroundColor('rgba(249, 202, 36, 0.15)')
          .margin({ top: 24, bottom: 16 })

        Text('🙏 许愿（可选）')
          .fontSize(13)
          .fontColor('rgba(249, 202, 36, 0.6)')
          .margin({ bottom: 8 })

        TextInput({ text: this.wishContent, placeholder: '写下你的心愿（最多30字）' })
          .fontSize(14)
          .fontColor('#fdf6e3')
          .placeholderColor('rgba(253, 246, 227, 0.5)')
          .backgroundColor('rgba(249, 202, 36, 0.06)')
          .border({ width: 1, color: 'rgba(249, 202, 36, 0.25)', radius: 8 })
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .width('75%')
          .maxLength(30)
          .onChange((value: string) => { this.wishContent = value })
          .margin({ bottom: 8 })

        // 快捷心愿模板：点选即填入心愿框
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
          ForEach(WISH_TEMPLATES, (tpl: string) => {
            Text(`✨ ${tpl}`)
              .fontSize(11)
              .fontColor(this.wishContent === tpl ? '#1a1a0a' : 'rgba(249, 202, 36, 0.75)')
              .padding({ left: 10, right: 10, top: 4, bottom: 4 })
              .backgroundColor(this.wishContent === tpl ? '#f9ca24' : 'rgba(249, 202, 36, 0.08)')
              .borderRadius(14)
              .margin({ right: 6, bottom: 6 })
              .onClick(() => { this.wishContent = tpl })
          })
        }
        .width('75%')
        .margin({ bottom: 12 })

        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
          ForEach(FIVE_DEITIES, (deity: DeityInfo) => {
            Column() {
              Text(deity.direction)
                .fontSize(9)
                .fontColor(this.selectedDeity === deity.id ? '#1a1a0a' : 'rgba(253, 246, 227, 0.5)')
              Text(deity.name)
                .fontSize(13)
                .fontWeight(this.selectedDeity === deity.id ? FontWeight.Bold : FontWeight.Normal)
                .fontColor(this.selectedDeity === deity.id ? '#1a1a0a' : '#fdf6e3')
                .margin({ top: 1 })
            }
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .borderRadius(10)
            .backgroundColor(this.selectedDeity === deity.id ? '#f9ca24' : 'rgba(249, 202, 36, 0.06)')
            .border({
              width: this.selectedDeity === deity.id ? 1.5 : 0.5,
              color: this.selectedDeity === deity.id ? '#f9ca24' : 'rgba(249, 202, 36, 0.2)'
            })
            .alignItems(HorizontalAlign.Center)
            .margin({ right: 6, bottom: 6 })
            .onClick(() => { this.selectedDeity = this.selectedDeity === deity.id ? 0 : deity.id })
          })
        }
        .width('75%')
        .margin({ bottom: 8 })

        // 确认按钮
        Button(this.wishContent.trim().length > 0 ? '许愿叩拜 →' : '叩拜麻神 →')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1a1a0a')
          .backgroundColor('#f9ca24')
          .borderRadius(25)
          .padding({ left: 48, right: 48, top: 12, bottom: 12 })
          .shadow({
            radius: 15,
            color: 'rgba(249, 202, 36, 0.3)',
            offsetY: 4
          })
          .margin({ top: 40 })
          .enabled(this.inputName.trim().length > 0)
          .opacity(this.inputName.trim().length > 0 ? 1.0 : 0.5)
          .onClick(() => {
            // 如果用户选了财神，更新 viewModel.todayDeity 使后续页面（PrayerCard/BlessingCard）
            // 高亮和显示用户选的那位，而非日期轮换的默认财神
            if (this.selectedDeity > 0) {
              const chosen: DeityInfo | undefined = FIVE_DEITIES.find((d: DeityInfo) => d.id === this.selectedDeity)
              if (chosen) {
                this.viewModel.todayDeity = chosen
              }
            }
            this.viewModel.confirmName(this.inputName.trim())
            // 如果填写了心愿，异步创建（不阻塞导航，磕头时心愿已入云）
            const wish: string = this.wishContent.trim()
            if (wish.length > 0) {
              const deityId: number = this.viewModel.todayDeity.id
              CloudService.createWish(wish, deityId).catch((e: Object) => {
                console.error('[NameCard] createWish failed:', JSON.stringify(e))
              })
            }
            // 延迟导航到下一帧，让按钮点击反馈先渲染
            setTimeout(() => {
              this.getUIContext().getRouter().pushUrl({ url: 'pages/PrayerCard' }, router.RouterMode.Standard)
            }, 0)
          })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1a1a0a')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
  }

  private showDeleteNameConfirm(name: string): void {
    AlertDialog.show({
      title: '删除曾用名',
      message: `确定删除「${name}」吗？`,
      primaryButton: {
        value: '删除',
        action: () => { this.viewModel.removeRecentName(name) }
      },
      secondaryButton: {
        value: '取消',
        action: () => {}
      }
    })
  }
}