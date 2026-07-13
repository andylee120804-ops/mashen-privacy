import { IPaymentService } from './IPaymentService'

export class QrCodePayment implements IPaymentService {
  private wechatQr: ResourceStr
  private alipayQr: ResourceStr

  constructor(wechatQr: ResourceStr, alipayQr: ResourceStr) {
    this.wechatQr = wechatQr
    this.alipayQr = alipayQr
  }

  getQrCodeImage(): ResourceStr {
    return this.wechatQr
  }

  getPaymentDescription(): string {
    return '感谢供奉麻神，心诚则灵 🙏'
  }
}