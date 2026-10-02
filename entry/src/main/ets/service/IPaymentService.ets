// entry/src/main/ets/service/IPaymentService.ets
// 解签每日解锁支付服务接口（华为 IAP 消耗型商品）。
// 供奉打赏（5 档消耗型 tip_06~88）已随审核整改移除（2026-09-27 封建迷信拒审）；
// 2026-09-28 由「解签一次性买断（jieqian_unlock 非消耗型）」改为「每日解锁」：
// jieqian_unlock（¥1）消耗型，一次付款解锁「当天」最多 3 个签的解签，次日重新付费。
// 消耗型需在解锁落账后 finishPurchase 消耗，否则下次购买被 1001860051 拦截；
// 崩溃在消耗前 → recoverPending 补单（queryPurchases UNFINISHED 拉已支付未消耗订单）。

/** 解签每日解锁商品（与 AGC 控制台消耗型商品 jieqian_unlock 唯一对应） */
export interface UnlockProduct {
  productId: string      // AGC 商品 ID（jieqian_unlock，与服务端 jieqian-unlock 白名单一致）
  amount: number          // 本地展示金额（¥1，与 AGC 定价档一致）
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
  ALREADY_OWNED = 'already_owned'  // 1001860051 同商品有未完成订单（上次购买成功未消耗），应补单恢复
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

/** 解签每日解锁商品静态配置（三方一致：AGC 控制台 / 云函数 jieqian-unlock 白名单 / 本表） */
export const UNLOCK_PRODUCT: UnlockProduct = {
  productId: 'jieqian_unlock',
  amount: 1,
  label: '解锁今日三只签'
}

export interface IUnlockService {
  /** 解签每日解锁商品信息 */
  getProduct(): UnlockProduct

  /**
   * 发起购买（拉起华为收银台，消耗型）。
   * 用户取消 → { success: false, canceled: true }；
   * 前置错误（未登录/地区/商品未发布/有未完成订单）→ 抛 PaymentError（UI 引导后处理）；
   * 其他错误 → 抛 Error（UI toast「购买失败请重试」）。
   */
  purchase(): Promise<UnlockPurchaseResult>

  /**
   * 补单恢复：queryPurchases(CONSUMABLE, UNFINISHED) 查已支付未消耗的今日解锁订单。
   * 覆盖崩溃在消耗前 / 上次云端未记的场景。返回找到的首笔 jieqian_unlock 订单
   * （含 purchaseToken 供云端幂等补记）；无未完成订单/查询失败返回 null。
   */
  recoverPending(): Promise<UnlockPurchaseResult | null>

  /** 消耗商品（finishPurchase）——今日解锁落账后调用，否则下次购买被 1001860051 拦截 */
  consume(result: UnlockPurchaseResult): Promise<void>
}
