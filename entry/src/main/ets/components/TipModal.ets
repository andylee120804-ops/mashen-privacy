import { QrCodePayment } from '../service/QrCodePayment'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { fileIo } from '@kit.CoreFileKit'
import { BusinessError } from '@kit.BasicServicesKit'

@CustomDialog
export struct TipModal {
  controller: CustomDialogController
  private paymentService: QrCodePayment = new QrCodePayment(
    $rawfile('qrcode_wechat.png'),
    $rawfile('qrcode_alipay.png')
  )

  private async saveToGallery(): Promise<void> {
    try {
      const uiContext = this.getUIContext()
      const context = uiContext.getHostContext()
      if (!context) {
        this.getUIContext().getPromptAction().showToast({ message: '保存失败' })
        return
      }

      const rawData = await context.resourceManager.getRawFileContent('qrcode_wechat.png')
      const buffer: ArrayBuffer = rawData.buffer.slice(0) as ArrayBuffer

      // SaveButton 点击后系统临时授予媒体库写入权限，可直接调用 createAsset，
      // 不需要在 module.json5 中声明 WRITE_IMAGEVIDEO 权限。
      const helper = photoAccessHelper.getPhotoAccessHelper(context)
      const uri = await helper.createAsset(photoAccessHelper.PhotoType.IMAGE, 'png')
      const destFile = await fileIo.open(uri, fileIo.OpenMode.WRITE_ONLY)
      fileIo.writeSync(destFile.fd, buffer)
      fileIo.closeSync(destFile)

      this.getUIContext().getPromptAction().showToast({ message: '二维码已保存到相册' })
    } catch (err) {
      const error = err as BusinessError
      console.error(`[saveToGallery] code=${error.code} message=${error.message}`)
      this.getUIContext().getPromptAction().showToast({ message: '保存失败，请重试' })
    }
  }

  build() {
    Column() {
      // ── 顶部红色装饰条（与令牌/金榜风格呼应）──
      Row()
        .width('100%')
        .height(4)
        .backgroundColor('#c0392b')

      // ── 标题区 ──
      Text('✦  供奉麻神  ✦')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#f9ca24')
        .letterSpacing(2)
        .margin({ top: 22, bottom: 6 })

      Text('「心诚则灵 · 福报自来」')
        .fontSize(12)
        .fontColor('rgba(253, 246, 227, 0.5)')
        .fontStyle(FontStyle.Italic)
        .margin({ bottom: 18 })

      // ── 二维码金框区（双框呼应金榜）──
      Stack() {
        Image(this.paymentService.getQrCodeImage())
          .width(186)
          .height(186)
          .objectFit(ImageFit.Contain)
          .borderRadius(6)
      }
      .width(202)
      .height(202)
      .backgroundColor('rgba(26, 26, 10, 0.8)')
      .border({ width: 2, color: '#f9ca24', radius: 10 })
      .padding(8)

      // ── 扫码提示 ──
      Text('请用微信扫码')
        .fontSize(14)
        .fontColor('#f9ca24')
        .fontWeight(FontWeight.Medium)
        .margin({ top: 16 })

      Text('心诚则灵 · 助力公益')
        .fontSize(11)
        .fontColor('rgba(253, 246, 227, 0.5)')
        .margin({ top: 4, bottom: 16 })

      // ── 分隔线 ──
      Row()
        .width('48%')
        .height(1)
        .backgroundColor('rgba(249, 202, 36, 0.25)')
        .margin({ bottom: 16 })

      // ── 操作按钮组 ──
      Row() {
        SaveButton({ text: SaveDescription.SAVE_IMAGE, buttonType: ButtonType.Normal })
          .fontSize(13)
          .fontColor('rgba(249, 202, 36, 0.85)')
          .backgroundColor('rgba(249, 202, 36, 0.1)')
          .borderColor('rgba(249, 202, 36, 0.35)')
          .borderWidth(1)
          .borderRadius(20)
          .onClick((event: ClickEvent, result: SaveButtonOnClickResult) => {
            if (result === SaveButtonOnClickResult.SUCCESS) {
              this.saveToGallery()
            }
          })

        Button('关闭')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1a1a0a')
          .backgroundColor('#f9ca24')
          .borderRadius(20)
          .height(36)
          .padding({ left: 28, right: 28 })
          .onClick(() => this.controller.close())
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceEvenly)
      .margin({ bottom: 8 })
    }
    .width('78%')
    .backgroundColor('#1a1a0a')
    .borderRadius(16)
    .border({ width: 1.5, color: 'rgba(249, 202, 36, 0.3)' })
    .shadow({ radius: 30, color: 'rgba(0, 0, 0, 0.6)', offsetY: 6 })
    .clip(true)
  }
}
