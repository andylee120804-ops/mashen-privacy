// entry/src/main/ets/service/IPaymentService.ets
// 供奉打赏支付服务接口（华为 IAP）。
// 旧二维码支付（QrCodePayment）已随供奉弹窗重设计整体移除：
// AppGallery 要求虚拟商品/打赏必须走华为应用内支付（审核 3.5）。
// 时序契约（设计文档第 5 节）：记账在消耗之前——云端上报成功后才 finishPurchase，
// 失败则订单保持未完成，留给 EntryAbility 启动补单（幂等不双记）。

/** 供奉档位（与 AGC 控制台消耗型商品一一对应，真实价格以收银台/控制台为准） */
export interface TipProduct {
  productId: string      // AGC 商品 ID（tip_06 等，与服务端白名单一致）
  amount: number          // 本地展示金额（记账口径与服务端白名单一致）
  label: string           // 文化标签
}

/** 购买结果。success 时含云端记账所需全部字段 */
export interface TipPurchaseResult {
  success: boolean
  canceled: boolean       // 用户取消（1001860000），静默返回不弹错
  productId: string
  amount: number          // 白名单定价（与服务端 donation-record 白名单一致）
  purchaseToken: string   // 幂等去重键
  orderId: string          // purchaseOrderId
  purchaseData: string    // 华为签名原文（云端存证，未来 verify 用）
}

/** 支付前置错误（UI 按 kind 引导处理，设计文档第 8 节错误表） */
export enum PaymentErrorKind {
  NEED_LOGIN = 'need_login',   // 1001860050 未登录华为帐号
  REGION = 'region',           // 1001860054 地区不支持
  PRODUCT = 'product',          // 1001860007 商品未发布
  RETRY_AFTER_COMPLETE = 'retry_after_complete'  // 1001860051 同商品有未完成订单，已补单，请重试
}

export class PaymentError extends Error {
  readonly kind: PaymentErrorKind
  readonly rawCode: number
  constructor(kind: PaymentErrorKind, message: string, rawCode: number) {
    super(message)
    this.kind = kind
    this.rawCode = rawCode
  }
}

/**
 * 供奉档位静态表。
 * ⚠️ productId/amount 必须三方一致：AGC 控制台商品配置、云函数
 * donation-record/handler.js 的 PRODUCT_IDS 白名单、本表。控制台改价需同步两处。
 */
export const TIP_PRODUCTS: TipProduct[] = [
  { productId: 'tip_06', amount: 0.6, label: '小小心意' },
  { productId: 'tip_6', amount: 6, label: '顺顺供奉' },
  { productId: 'tip_18', amount: 18, label: '财运供奉' },
  { productId: 'tip_66', amount: 66, label: '大吉供奉' },
  { productId: 'tip_88', amount: 88, label: '至尊供奉' }
]

export interface ITipPaymentService {
  /** 供奉档位列表 */
  getProducts(): TipProduct[]

  /**
   * 发起供奉（拉起华为收银台）。
   * 用户取消 → { success: false, canceled: true }；
   * 前置错误（未登录/地区/商品未发布）→ 抛 PaymentError（UI 引导后可重试）；
   * 其他错误 → 抛 Error（UI toast「支付失败请重试」）。
   */
  purchase(productId: string): Promise<TipPurchaseResult>

  /**
   * 确认消耗（finishPurchase）。时序契约：云端记账成功后才调用——
   * 云端没记上绝不消耗，订单保持未完成留给启动补单。
   */
  finishPurchase(result: TipPurchaseResult): Promise<void>

  /** 启动补单：queryPurchases 拉未完成订单（已支付未消耗），逐条记账+消耗。返回补单数 */
  completePendingOrders(): Promise<number>
}
