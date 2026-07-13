import { QrCodePayment } from '../service/QrCodePayment'

@CustomDialog
export struct TipModal {
  controller: CustomDialogController
  private paymentService: QrCodePayment = new QrCodePayment(
    $rawfile('qrcode_wechat.png'),
    $rawfile('qrcode_alipay.png')
  )

  build() {
    Column() {
      Text('🧧 供奉麻神')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#f9ca24')
        .margin({ top: 20, bottom: 8 })

      Text(this.paymentService.getPaymentDescription())
        .fontSize(13)
        .fontColor('rgba(253, 246, 227, 0.6)')
        .margin({ bottom: 20 })

      Image(this.paymentService.getQrCodeImage())
        .width(200)
        .height(200)
        .objectFit(ImageFit.Contain)
        .borderRadius(12)
        .border({ width: 2, color: 'rgba(249, 202, 36, 0.3)' })

      Text('请用微信/支付宝扫码')
        .fontSize(12)
        .fontColor('rgba(253, 246, 227, 0.4)')
        .margin({ top: 12, bottom: 20 })

      Button('关闭')
        .fontSize(14)
        .fontColor('#1a1a0a')
        .backgroundColor('#f9ca24')
        .borderRadius(20)
        .padding({ left: 40, right: 40 })
        .onClick(() => this.controller.close())
    }
    .width('80%')
    .backgroundColor('#1a1a0a')
    .borderRadius(16)
    .border({ width: 1, color: 'rgba(249, 202, 36, 0.2)' })
    .padding(20)
  }
}