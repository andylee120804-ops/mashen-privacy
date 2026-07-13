export interface IPaymentService {
  getQrCodeImage(): ResourceStr
  getPaymentDescription(): string
}