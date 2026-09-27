// cloud/jieqian-unlock/handler.js
// 解签买断解锁记录（IAP 非消耗型商品 jieqian_unlock）：
//   action=record —— 上报解锁购买，幂等（同 purchaseToken 只记一条）
//   action=query  —— 查该 uid 是否已解锁 { unlocked: bool }
// 客户端 data: { action, __uid, productId?, purchaseToken?, purchaseData?, orderId? }
// 非消耗型无「消耗」动作，时序简单：客户端支付成功 → 本地置位立即解锁 →
//   云端记录（失败不阻塞解锁，重装/换机后由客户端 isOwned() 恢复 + 幂等补记）。
const { wrapHttp, success, fail, CODE } = require('./shared/response');
const { getDB, toGenericObjects, toPlainObject, withTimeout, DB_TIMEOUT_MS } = require('./shared/db');

var UNLOCK_TYPE = 'SignUnlock';

// 商品白名单：唯一非消耗型商品。必须与 AGC 控制台「应用内购买服务」配置一致。
var ALLOWED_PRODUCT_ID = 'jieqian_unlock';

// 客户端可控字段长度上限（伪造面缓解：防大对象滥用存储/拖垮查询）
var MAX_TOKEN_LEN = 256;    // purchaseToken
// purchaseData 上限实测受控制台字段容量限制（真实 Cloud DB 二分验证：
//   200 字符 PASS、255 字符 3007007 out of range）。华为 JWS（含 x5c 证书链）
//   2500+ 字符，控制台字段装不下完整 JWS —— 这里只截断存证，真正的校验键是
//   purchaseToken（已单独存储，v2 action=verify 走 token 调华为订单服务）。
var MAX_DATA_LEN = 200;     // purchaseData（截断存证，勿再调大）
var MAX_ORDER_LEN = 128;    // purchaseOrderId

async function handler(body, event, context, log) {
  var action = body.action;
  var uid = body.__uid;

  if (!uid) {
    // 诊断模式（规则要求）：requestKeys 空数组 = 客户端 data 内容为空/未传
    var reqObj = event && event.request && typeof event.request === 'object' ? event.request : null;
    var diag = {
      requestKeys: reqObj ? Object.keys(reqObj) : [],
      bodyKeys: body ? Object.keys(body) : []
    };
    log.error('[jieqian-unlock] UID NOT FOUND, diag: ' + JSON.stringify(diag));
    return fail(CODE.UNAUTHORIZED, 'uid required: ' + JSON.stringify(diag));
  }

  var db = getDB();

  try {
    switch (action) {
      case 'record': {
        // ---- 参数校验（类型 + 长度，客户端可控字段一律不信任）----
        var productId = body.productId;
        var purchaseToken = body.purchaseToken;
        var orderId = typeof body.orderId === 'string' ? body.orderId.slice(0, MAX_ORDER_LEN) : '';
        var purchaseData = typeof body.purchaseData === 'string' ? body.purchaseData.slice(0, MAX_DATA_LEN) : '';
        if (productId !== ALLOWED_PRODUCT_ID) {
          return fail(CODE.PARAM_ERROR, 'invalid productId: ' + productId);
        }
        if (typeof purchaseToken !== 'string' || !purchaseToken || purchaseToken.length > MAX_TOKEN_LEN) {
          return fail(CODE.PARAM_ERROR, 'invalid purchaseToken');
        }

        // ---- 幂等检查：同 purchaseToken 只记一条（重复上报/补记不双记）----
        // 依赖 SignUnlock 表 purchaseToken 索引（控制台手动建，见 Task 13）。
        var existing = await withTimeout(
          db.collection(UNLOCK_TYPE).query().equalTo('purchaseToken', purchaseToken).get(),
          DB_TIMEOUT_MS,
          'jieqian-unlock:idem-query'
        );
        if (existing && existing.length > 0) {
          log.info('[jieqian-unlock] duplicate purchaseToken, skip uid=' + uid);
          return success({ unlocked: true }, 'duplicate ignored');
        }

        // ---- 落解锁记录 ----
        var unlock = {
          id: orderId || ('u_' + Date.now() + '_' + Math.random().toString(36).substring(2, 8)),
          uid: uid,
          productId: productId,
          purchaseToken: purchaseToken,
          purchaseData: purchaseData,
          createdAt: new Date().toISOString()
        };
        await withTimeout(
          db.collection(UNLOCK_TYPE).upsert(toGenericObjects(UNLOCK_TYPE, unlock)),
          DB_TIMEOUT_MS,
          'jieqian-unlock:unlock-upsert'
        );
        log.info('[jieqian-unlock] recorded id=' + unlock.id + ' productId=' + productId + ' uid=' + uid);
        return success({ unlocked: true });
      }

      case 'query': {
        // 依赖 SignUnlock 表 uid 索引（控制台手动建，见 Task 13）
        var rows = await withTimeout(
          db.collection(UNLOCK_TYPE).query().equalTo('uid', uid).get(),
          DB_TIMEOUT_MS,
          'jieqian-unlock:query'
        );
        return success({ unlocked: !!(rows && rows.length > 0) });
      }

      default:
        return fail(CODE.PARAM_ERROR, 'unknown action: ' + action);
    }
  } catch (err) {
    log.error('[jieqian-unlock] DB error: ' + (err && err.message));
    return fail(CODE.SERVER_ERROR, 'db error: ' + (err && err.message));
  }
}

module.exports.myHandler = wrapHttp(handler);
