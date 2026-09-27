// entry/src/main/ets/service/IapPaymentService.ets
// 供奉打赏支付实现（华为 IAP Kit，@kit.IAPKit）。
// API 事实（本机 SDK @hms.core.iap.d.ts 实测核对）：
//  - createPurchase(context, { productId, productType }) → CreatePurchaseResult.purchaseData
//    （官方结构 { jwsPurchaseOrder: JWS }，JWS payload 才含 productId/purchaseToken/purchaseOrderId）
//  - finishPurchase(context, { productType, purchaseToken, purchaseOrderId })（旧 consumePurchase 已废弃）
//  - queryPurchases(context, { productType }) → QueryPurchaseResult.purchaseDataList（未完成订单，同样 JWS 结构）
//  - queryEnvironmentStatus(context)：未登录抛 1001860050，地区不支持 1001860054
// 时序契约：purchase 只买不消耗；云端记账（CloudService.recordDonation，幂等）
// 成功后才 finishPurchase——失败订单保持未完成，由 EntryAbility 启动补单。
import { iap } from '@kit.IAPKit'
import { common } from '@kit.AbilityKit'
import { util } from '@kit.ArkTS'
import { BusinessError } from '@kit.BasicServicesKit'
import { ITipPaymentService, TipProduct, TipPurchaseResult, TIP_PRODUCTS, PaymentError, PaymentErrorKind } from './IPaymentService'
import { CloudService } from './CloudService'

// IAP 错误码（@hms.core.iap，设计文档第 8 节错误表）
const ERR_USER_CANCEL = 1001860000
const ERR_ALREADY_OWNED = 1001860051  // 同商品存在未完成订单（上次支付成功未消耗）时再购买被拒
const ERR_NOT_LOGIN = 1001860050
const ERR_REGION_UNSUPPORTED = 1001860054
const ERR_PRODUCT_UNAVAILABLE = 1001860007

/** 华为签名 purchaseData 解析后需要的关键字段 */
interface HuaweiPurchaseData {
  productId: string
  purchaseToken: string
  purchaseOrderId: string
}

/** JWS 载荷（PurchaseOrderPayload，华为 IAP 文档）字段 */
interface PurchaseOrderPayload {
  productId: string
  purchaseToken: string
  purchaseOrderId: string
  productType: number
}

/** productId -> 白名单金额（与云端 donation-record 白名单同源口径） */
function amountOf(productId: string): number {
  for (const p of TIP_PRODUCTS) {
    if (p.productId === productId) {
      return p.amount
    }
  }
  return 0
}

/** JWS 三段紧凑格式（header.payload.signature）：base64url 解码 payload 段，返回 JSON 字符串。
 *  华为 IAP 官方 codelab 同款实现（util.Base64Helper + BASIC_URL_SAFE）。 */
function decodeJwsPayload(jws: string): string {
  const parts: string[] = jws.split('.')
  if (parts.length < 2) {
    throw new Error('jws format error: parts=' + parts.length)
  }
  const base64 = new util.Base64Helper()
  const payloadBytes: Uint8Array = base64.decodeSync(parts[1], util.Type.BASIC_URL_SAFE)
  return util.TextDecoder.create('utf-8').decodeToString(payloadBytes)
}

/**
 * 解析华为 purchaseData。官方结构（华为 IAP 文档/codelab 实测）：
 *   purchaseData = { "jwsPurchaseOrder": "<header.payload.signature>" }
 * 链路：JSON.parse → 取 jwsPurchaseOrder → base64url 解码 JWS payload → JSON.parse 得
 * PurchaseOrderPayload（含 productId / purchaseToken / purchaseOrderId）。
 * ⚠️ 之前版本直接 JSON.parse 后取顶层 productId 全是 undefined——productId 在 JWS 载荷里，
 * 导致补单 finishPurchase 空 token 401、商品永久锁死。解析失败返回 null——
 * 调用方绝不能对空 purchaseToken 调 finishPurchase（必 401 且丢单）。
 */
function parsePurchaseData(raw: string): HuaweiPurchaseData | null {
  try {
    const wrapper: Object = JSON.parse(raw) as Object
    const w = wrapper as Record<string, Object>
    let jws: Object = w['jwsPurchaseOrder']
    // 兜底：个别版本可能把 JWS 再包一层字符串，救一层
    if (typeof jws !== 'string' && typeof wrapper === 'string') {
      const inner: Object = JSON.parse(wrapper as string) as Object
      jws = (inner as Record<string, Object>)['jwsPurchaseOrder']
    }
    if (typeof jws !== 'string' || (jws as string) === '') {
      console.error('[IapPayment] purchaseData 无 jwsPurchaseOrder 字段 | keys='
        + Object.keys(wrapper).join(',') + ' | raw(0-300)=' + raw.substring(0, 300))
      return null
    }
    const payloadStr: string = decodeJwsPayload(jws as string)
    const payload: PurchaseOrderPayload = JSON.parse(payloadStr) as PurchaseOrderPayload
    if (!payload.productId || !payload.purchaseToken || !payload.purchaseOrderId) {
      console.error('[IapPayment] PurchaseOrderPayload 字段缺失 productId=' + (payload.productId || '')
        + ' token=' + (payload.purchaseToken ? 'set' : 'empty')
        + ' order=' + (payload.purchaseOrderId || '')
        + ' | payload(0-300)=' + payloadStr.substring(0, 300))
      return null
    }
    return {
      productId: payload.productId,
      purchaseToken: payload.purchaseToken,
      purchaseOrderId: payload.purchaseOrderId
    }
  } catch (err) {
    console.error('[IapPayment] purchaseData 解析失败: ' + JSON.stringify(err)
      + ' | raw(0-300)=' + raw.substring(0, 300))
    return null
  }
}

/** 设备匿名 ID（EntryAbility 启动时写入 AppStorage），随订单进 developerPayload——
 *  华为会将其签名进 purchaseData，是未来 action=verify 服务端校验的 uid 锚点
 *  （只影响新订单，无法回补，故 v1 即传） */
function getDeviceUid(): string {
  try {
    const uid: string | undefined = AppStorage.get<string>('deviceUserId')
    return uid || ''
  } catch {
    return ''
  }
}

export class IapPaymentService implements ITipPaymentService {
  private readonly context: common.UIAbilityContext

  constructor(context: common.UIAbilityContext) {
    this.context = context
  }

  getProducts(): TipProduct[] {
    return TIP_PRODUCTS
  }

  async purchase(productId: string): Promise<TipPurchaseResult> {
    // ① 环境检查：华为帐号登录 / 地区支持（不依赖 AGC Auth，系统级帐号）
    try {
      await iap.queryEnvironmentStatus(this.context)
    } catch (err) {
      const e = err as BusinessError
      if (e.code === ERR_NOT_LOGIN) {
        throw new PaymentError(PaymentErrorKind.NEED_LOGIN, '供奉需登录华为帐号', e.code)
      }
      if (e.code === ERR_REGION_UNSUPPORTED) {
        throw new PaymentError(PaymentErrorKind.REGION, '当前地区暂不支持供奉', e.code)
      }
      throw new Error('支付环境检查失败：' + e.message)
    }

    // ② 拉起收银台（金额以收银台实际价格为准，收银台显示 AGC 配置价）
    let raw: string
    let data: HuaweiPurchaseData | null
    try {
      const result = await iap.createPurchase(this.context, {
        productId: productId,
        productType: iap.ProductType.CONSUMABLE,
        developerPayload: getDeviceUid()
      })
      raw = result.purchaseData
      console.info('[IapPayment] purchaseData raw(0-500): ' + raw.substring(0, 500))
      // 官方结构：{ jwsPurchaseOrder: JWS }，JWS payload 才含 productId/purchaseToken/purchaseOrderId
      data = parsePurchaseData(raw)
      if (data === null) {
        // 解析不出关键字段：无法记账/消耗。钱已扣，订单保持未完成留给启动补单
        console.error('[IapPayment] 购买成功但 purchaseData 解析失败，订单留给补单处理')
      }
    } catch (err) {
      const e = err as BusinessError
      if (e.code === ERR_USER_CANCEL) {
        // 用户取消：静默返回，弹窗不关可重选档位
        return { success: false, canceled: true, productId: productId, amount: amountOf(productId), purchaseToken: '', orderId: '', purchaseData: '' }
      }
      if (e.code === ERR_PRODUCT_UNAVAILABLE) {
        throw new PaymentError(PaymentErrorKind.PRODUCT, '供奉服务准备中', e.code)
      }
      if (e.code === ERR_ALREADY_OWNED) {
        // 上一笔同商品订单未消耗（记账失败或补单未跑）→ 触发补单消耗后重试
        console.warn('[IapPayment] 同商品有未完成订单，先补单再重试: ' + e.message)
        try {
          await this.completePendingOrders()
        } catch (err) {
          console.error('[IapPayment] 补单失败:', JSON.stringify(err))
        }
        throw new PaymentError(PaymentErrorKind.RETRY_AFTER_COMPLETE, '检测到上一笔供奉未入账，已自动补录，请重试', e.code)
      }
      throw new Error('支付失败：' + e.message)
    }

    // ③ 组装结果：amount 用白名单（记账口径与服务端一致，不解析华为价格字符串）
    // productId 兜底用请求值：JWS 载荷解析不出（异常版本）时，用户在收银台点选的商品
    // 就是权威值，云端也按白名单校验，不会错
    const resolvedProductId: string = (data !== null && data.productId !== '') ? data.productId : productId
    return {
      success: true,
      canceled: false,
      productId: resolvedProductId,
      amount: amountOf(resolvedProductId),
      purchaseToken: (data !== null) ? data.purchaseToken : '',
      orderId: (data !== null) ? data.purchaseOrderId : '',
      purchaseData: raw
    }
  }

  async finishPurchase(result: TipPurchaseResult): Promise<void> {
    await iap.finishPurchase(this.context, {
      productType: iap.ProductType.CONSUMABLE,
      purchaseToken: result.purchaseToken,
      purchaseOrderId: result.orderId
    })
  }

  async completePendingOrders(): Promise<number> {
    // 启动补单：queryPurchases 拉已支付未消耗的订单（queryType 显式 UNFINISHED——
    // SDK 两版注释对默认值说法不一，显式传参消除歧义；误回 ALL 会全量重放历史订单）。
    // 未登录华为帐号会抛错——记日志跳过，下次启动再补（订单在华为侧不会丢）。
    let list: string[]
    try {
      const result = await iap.queryPurchases(this.context, {
        productType: iap.ProductType.CONSUMABLE,
        queryType: iap.PurchaseQueryType.UNFINISHED
      })
      list = result.purchaseDataList || []
    } catch (err) {
      console.warn('[IapPayment] queryPurchases 跳过（未登录/网络）:', JSON.stringify(err))
      return 0
    }

    let finished = 0
    for (const raw of list) {
      try {
        const data = parsePurchaseData(raw)
        // 不可解析（结构异常/字段缺失）：绝不能盲目 finishPurchase——空 token 必 401 且丢单；
        // 保持未完成留待核对（人工按华为后台订单流水补偿）
        if (data === null) {
          console.error('[IapPayment] 补单跳过不可解析订单（保持未完成）: raw(0-300)=' + raw.substring(0, 300))
          continue
        }
        const amount = amountOf(data.productId)
        if (amount <= 0) {
          // 真正的白名单外商品（有明确 productId 但不在白名单，AGC 改价/下架配置漂移）：
          // 无法记账，直接消耗掉防每次启动无限重试；功德损失按华为后台流水人工补偿
          console.error('[IapPayment] 补单遇白名单外商品，丢弃订单（人工核对补偿）: productId='
            + data.productId + ' order=' + data.purchaseOrderId)
          await this.finishPurchase({
            success: true,
            canceled: false,
            productId: data.productId,
            amount: 0,
            purchaseToken: data.purchaseToken,
            orderId: data.purchaseOrderId,
            purchaseData: raw
          })
          continue
        }
        const pending: TipPurchaseResult = {
          success: true,
          canceled: false,
          productId: data.productId,
          amount: amount,
          purchaseToken: data.purchaseToken,
          orderId: data.purchaseOrderId,
          purchaseData: raw
        }
        // 记账在消耗之前：云端幂等记账（同 purchaseToken 只记一次）成功才消耗
        const merit = await CloudService.recordDonation({
          productId: pending.productId,
          amount: pending.amount,
          purchaseToken: pending.purchaseToken,
          purchaseData: pending.purchaseData,
          orderId: pending.orderId
        })
        if (merit === null) {
          // 记账失败（断网/云端 5xx）：保持未完成，下次启动再补，不丢钱
          console.warn('[IapPayment] 补单记账失败，订单保持未完成: ' + pending.orderId)
          continue
        }
        await this.finishPurchase(pending)
        finished++
        console.info('[IapPayment] 补单完成: productId=' + pending.productId + ' amount=' + pending.amount
          + ' order=' + pending.orderId + ' finished累计=' + finished)
      } catch (err) {
        console.error('[IapPayment] 补单单条失败:', JSON.stringify(err))
      }
    }
    return finished
  }
}
