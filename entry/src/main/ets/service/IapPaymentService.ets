// entry/src/main/ets/service/IapPaymentService.ets
// 解签买断支付实现（华为 IAP Kit，@kit.IAPKit，非消耗型商品 jieqian_unlock）。
// API 事实（本机 SDK @hms.core.iap.d.ts 实测核对）：
//  - createPurchase(context, { productId, productType: NONCONSUMABLE, developerPayload })
//    → CreatePurchaseResult.purchaseData（JWS，payload 才含 productId/purchaseToken/purchaseOrderId）
//  - queryPurchases(context, { productType: NONCONSUMABLE, queryType: CURRENT_ENTITLEMENT })
//    → 已购商品列表（权益恢复；非消耗型无需 finishPurchase）
//  - queryEnvironmentStatus(context)：未登录抛 1001860050，地区不支持 1001860054
// 时序：支付成功 → 本地置解锁标志（立即生效）→ 云端 record（异步幂等）；
//  重装/换机 → restoreOwned() 恢复本地标志 + 云端幂等补记。
import { iap } from '@kit.IAPKit'
import { common } from '@kit.AbilityKit'
import { util } from '@kit.ArkTS'
import { BusinessError } from '@kit.BasicServicesKit'
import { IUnlockService, UnlockProduct, UnlockPurchaseResult, UNLOCK_PRODUCT, PaymentError, PaymentErrorKind } from './IPaymentService'

// IAP 错误码（@hms.core.iap）
const ERR_USER_CANCEL = 1001860000
const ERR_ALREADY_OWNED = 1001860051  // 非消耗型重复购买（已拥有）被拒
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
 * ⚠️ productId 在 JWS 载荷里不在顶层；解析失败返回 null——调用方不得对空 token 记账。
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
      throw new Error('支付环境检查失败：' + e.message)
    }

    // ② 拉起收银台（非消耗型：买断即永久拥有，无消耗动作）
    let raw: string
    let data: HuaweiPurchaseData | null
    try {
      const result = await iap.createPurchase(this.context, {
        productId: UNLOCK_PRODUCT.productId,
        productType: iap.ProductType.NONCONSUMABLE,
        developerPayload: getDeviceUid()
      })
      raw = result.purchaseData
      data = parsePurchaseData(raw)
      if (data === null) {
        // 解析不出关键字段：无法云端记账。本地解锁不受影响（isOwned 兜底恢复）
        console.error('[IapUnlock] 购买成功但 purchaseData 解析失败，走 restoreOwned 兜底')
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
        // 非消耗型重复购买：已拥有，UI 引导走 restoreOwned 恢复
        throw new PaymentError(PaymentErrorKind.ALREADY_OWNED, '已拥有解签权益', e.code)
      }
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

  async restoreOwned(): Promise<UnlockPurchaseResult | null> {
    // 权益恢复：queryPurchases CURRENT_ENTITLEMENT 拉已购非消耗型商品（华为帐号权益，
    // 重装/换机可恢复）。未登录华为帐号会抛错——记日志返回 null（下次再试）。
    let list: string[]
    try {
      const result = await iap.queryPurchases(this.context, {
        productType: iap.ProductType.NONCONSUMABLE,
        queryType: iap.PurchaseQueryType.CURRENT_ENTITLEMENT
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
      // 只认本商品订单：防未来新增其他非消耗型商品时跨产品权益泄露
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

  async isOwned(): Promise<boolean> {
    const owned: UnlockPurchaseResult | null = await this.restoreOwned()
    return owned !== null
  }
}
