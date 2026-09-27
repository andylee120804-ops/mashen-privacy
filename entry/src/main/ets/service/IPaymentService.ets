// entry/src/main/ets/service/IPaymentService.ets
// 解签买断支付服务接口（华为 IAP 非消耗型商品）。
// 供奉打赏（5 档消耗型 tip_06~88）已随审核整改移除（2026-09-27 封建迷信拒审），
// 改为解签一次性买断：jieqian_unlock（¥0.9）非消耗型，买断一次永久解锁全部解签。
// 非消耗型无「消耗」动作：支付成功即拥有；权益靠本地标志（主）+ restoreOwned 恢复。

/** 解签买断商品（与 AGC 控制台非消耗型商品 jieqian_unlock 唯一对应） */
export interface UnlockProduct {
  productId: string      // AGC 商品 ID（jieqian_unlock，与服务端 jieqian-unlock 白名单一致）
  amount: number          // 本地展示金额（¥0.9；AGC 无 0.9 档则落 1，标签同步改）
  label: string           // 文化标签
}

/** 购买结果。success 时含云端记录所需全部字段 */
export interface UnlockPurchaseResult {
  success: boolean
  canceled: boolean       // 用户取消（1001860000），静默返回不弹错
  productId: string       // 白名单商品 ID（与云端 jieqian-unlock 白名单一致）
  purchaseToken: string   // 幂等去重键
  orderId: string          // purchaseOrderId，SignUnlock 主键
  purchaseData: string    // 华为签名原文（云端存证，未来 verify 用）
}

/** 支付前置错误（UI 按 kind 引导处理） */
export enum PaymentErrorKind {
  NEED_LOGIN = 'need_login',   // 1001860050 未登录华为帐号
  REGION = 'region',           // 1001860054 地区不支持
  PRODUCT = 'product',          // 1001860007 商品未发布
  ALREADY_OWNED = 'already_owned'  // 1001860051 已拥有（非消耗型重复购买被拒，应走恢复）
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

/** 解签买断商品静态配置（三方一致：AGC 控制台 / 云函数 jieqian-unlock 白名单 / 本表） */
export const UNLOCK_PRODUCT: UnlockProduct = {
  productId: 'jieqian_unlock',
  amount: 0.9,
  label: '永久解锁解签'
}

export interface IUnlockService {
  /** 解签买断商品信息 */
  getProduct(): UnlockProduct

  /**
   * 发起买断（拉起华为收银台）。
   * 用户取消 → { success: false, canceled: true }；
   * 前置错误（未登录/地区/商品未发布/已拥有）→ 抛 PaymentError（UI 引导后处理）；
   * 其他错误 → 抛 Error（UI toast「购买失败请重试」）。
   */
  purchase(): Promise<UnlockPurchaseResult>

  /**
   * 权益恢复：queryPurchases(NONCONSUMABLE, FINISHED) 查已购订单。
   * 重装/换机/离线恢复走此路径（华为帐号权益）。返回已购订单
   * （含 purchaseToken 供云端幂等补记）；未购/查询失败返回 null。
   */
  restoreOwned(): Promise<UnlockPurchaseResult | null>

  /** 是否已购（restoreOwned 的布尔形态，UI 快速判断用） */
  isOwned(): Promise<boolean>
}
