// entry/src/main/ets/service/IapPaymentService.ets
// 解签每日解锁支付实现（华为 IAP Kit，@kit.IAPKit，消耗型商品 jieqian_unlock）。
// API 事实（本机 SDK @hms.core.iap.d.ts 实测核对）：
//  - createPurchase(context, { productId, productType: CONSUMABLE, developerPayload })
//    → CreatePurchaseResult.purchaseData（JWS，payload 才含 productId/purchaseToken/purchaseOrderId）
//  - finishPurchase(context, { productType: CONSUMABLE, purchaseToken, purchaseOrderId })：消耗
//  - queryPurchases(context, { productType: CONSUMABLE, queryType: UNFINISHED })
//    → 已支付未消耗订单（崩溃补单；消耗型无权益恢复，靠本地解锁日期 + 补单）
//  - queryEnvironmentStatus(context)：未登录抛 1001860050，地区不支持 1001860054
// 时序：支付成功 → 本地置「今日解锁」（立即生效）→ 云端 record（异步幂等）→ consume（下次可再买）；
//  崩溃在消耗前 → EntryAbility / QiuQian 打开详情时 recoverPending() 补单（今日解锁 + 幂等补记 + 消耗）。
import { iap } from '@kit.IAPKit'
import { common } from '@kit.AbilityKit'
import { util } from '@kit.ArkTS'
import { BusinessError } from '@kit.BasicServicesKit'
import { IUnlockService, UnlockProduct, UnlockPurchaseResult, UNLOCK_PRODUCT, PaymentError, PaymentErrorKind } from './IPaymentService'

// IAP 错误码（@hms.core.iap）
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

/** JWS 三段紧凑格式（header.payload.signature）：base64url 解码 payload 段，返回 JSON 字符串 */
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
 * ⚠️ productId 在 JWS 载荷里不在顶层；解析失败返回 null——调用方不得对空 token 记账/消耗。
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
      console.error('[IapUnlock] purchaseData 无 jwsPurchaseOrder 字段 | keys='
        + Object.keys(wrapper).join(',') + ' | raw(0-300)=' + raw.substring(0, 300))
      return null
    }
    const payloadStr: string = decodeJwsPayload(jws as string)
    const payload: PurchaseOrderPayload = JSON.parse(payloadStr) as PurchaseOrderPayload
    if (!payload.productId || !payload.purchaseToken || !payload.purchaseOrderId) {
      console.error('[IapUnlock] PurchaseOrderPayload 字段缺失 productId=' + (payload.productId || '')
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
    console.error('[IapUnlock] purchaseData 解析失败: ' + JSON.stringify(err)
      + ' | raw(0-300)=' + raw.substring(0, 300))
    return null
  }
}

/** 设备匿名 ID（EntryAbility 启动时写入 AppStorage），随订单进 developerPayload——
 *  华为会将其签名进 purchaseData，是未来 action=verify 服务端校验的 uid 锚点 */
function getDeviceUid(): string {
  try {
    const uid: string | undefined = AppStorage.get<string>('deviceUserId')
    return uid || ''
  } catch {
    return ''
  }
}

export class IapPaymentService implements IUnlockService {
  private readonly context: common.UIAbilityContext

  constructor(context: common.UIAbilityContext) {
    this.context = context
  }

  getProduct(): UnlockProduct {
    return UNLOCK_PRODUCT
  }

  async purchase(): Promise<UnlockPurchaseResult> {
    // ① 环境检查：华为帐号登录 / 地区支持（不依赖 AGC Auth，系统级帐号）
    try {
      await iap.queryEnvironmentStatus(this.context)
    } catch (err) {
      const e = err as BusinessError
      if (e.code === ERR_NOT_LOGIN) {
        throw new PaymentError(PaymentErrorKind.NEED_LOGIN, '解锁需登录华为帐号', e.code)
      }
      if (e.code === ERR_REGION_UNSUPPORTED) {
        throw new PaymentError(PaymentErrorKind.REGION, '当前地区暂不支持', e.code)
      }
      // 未知环境错误：显式记录错误码（BusinessError.message 可能不带码，丢了无法定位）
      console.error('[IapUnlock] queryEnvironmentStatus failed: code=' + e.code + ' msg=' + e.message)
      throw new Error('支付环境检查失败：' + e.message)
    }

    // ② 拉起收银台（消耗型：每次付款解锁当天，需 finishPurchase 消耗后才能再买）
    let raw: string
    let data: HuaweiPurchaseData | null
    try {
      const result = await iap.createPurchase(this.context, {
        productId: UNLOCK_PRODUCT.productId,
        productType: iap.ProductType.CONSUMABLE,
        developerPayload: getDeviceUid()
      })
      raw = result.purchaseData
      data = parsePurchaseData(raw)
      if (data === null) {
        // 解析不出关键字段：无法云端记账/消耗。钱已扣，订单保持未完成留给补单处理
        console.error('[IapUnlock] 购买成功但 purchaseData 解析失败，走 recoverPending 兜底')
      }
    } catch (err) {
      const e = err as BusinessError
      if (e.code === ERR_USER_CANCEL) {
        return { success: false, canceled: true, productId: UNLOCK_PRODUCT.productId, purchaseToken: '', orderId: '', purchaseData: '' }
      }
      if (e.code === ERR_PRODUCT_UNAVAILABLE) {
        throw new PaymentError(PaymentErrorKind.PRODUCT, '解锁服务准备中', e.code)
      }
      if (e.code === ERR_ALREADY_OWNED) {
        // 消耗型同商品有未完成订单（上次购买成功未消耗）→ 触发补单恢复今日权益
        throw new PaymentError(PaymentErrorKind.ALREADY_OWNED, '检测到未完成的今日解锁订单', e.code)
      }
      // 未知购买错误：错误码必须落日志（grep IapUnlock 定位），UI 只显示笼统提示
      console.error('[IapUnlock] createPurchase failed: code=' + e.code + ' msg=' + e.message)
      throw new Error('购买失败：' + e.message)
    }

    // productId 兜底用配置值：JWS 载荷解析不出（异常版本）时，配置常量即权威值
    const resolvedProductId: string = (data !== null && data.productId !== '') ? data.productId : UNLOCK_PRODUCT.productId
    return {
      success: true,
      canceled: false,
      productId: resolvedProductId,
      purchaseToken: (data !== null) ? data.purchaseToken : '',
      orderId: (data !== null) ? data.purchaseOrderId : '',
      purchaseData: raw
    }
  }

  async recoverPending(): Promise<UnlockPurchaseResult | null> {
    // 补单恢复：queryPurchases 拉已支付未消耗的订单（queryType 显式 UNFINISHED——
    // SDK 两版注释对默认值说法不一，显式传参消除歧义；误回 ALL 会全量重放历史订单）。
    // 未登录华为帐号会抛错——记日志返回 null（下次再试；订单在华为侧不会丢）。
    let list: string[]
    try {
      const result = await iap.queryPurchases(this.context, {
        productType: iap.ProductType.CONSUMABLE,
        queryType: iap.PurchaseQueryType.UNFINISHED
      })
      list = result.purchaseDataList || []
    } catch (err) {
      console.warn('[IapUnlock] queryPurchases 跳过（未登录/网络）:', JSON.stringify(err))
      return null
    }
    for (const raw of list) {
      const data = parsePurchaseData(raw)
      if (data === null) {
        // 不可解析：跳过该条，继续看下一条（不因单条异常放弃整个恢复）
        console.error('[IapUnlock] 恢复遇不可解析订单，跳过: raw(0-300)=' + raw.substring(0, 300))
        continue
      }
      // 只认本商品订单：防未来新增其他消耗型商品时跨产品权益泄露
      if (data.productId !== UNLOCK_PRODUCT.productId) {
        continue
      }
      return {
        success: true,
        canceled: false,
        productId: data.productId,
        purchaseToken: data.purchaseToken,
        orderId: data.purchaseOrderId,
        purchaseData: raw
      }
    }
    return null
  }

  async consume(result: UnlockPurchaseResult): Promise<void> {
    await iap.finishPurchase(this.context, {
      productType: iap.ProductType.CONSUMABLE,
      purchaseToken: result.purchaseToken,
      purchaseOrderId: result.orderId
    })
  }
}
