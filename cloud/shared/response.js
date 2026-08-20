// cloud/shared/response.js
// AGC 云函数统一响应工具：信封格式 { code, message, data }
// 依据实测：客户端 cloudFunction.call({ data }) 的 data 在 event.request 中（非 event.body）；
// callback 从 context.callback 取且只接受单参数。
const CODE = {
  OK: 0,
  PARAM_ERROR: 400,
  UNAUTHORIZED: 401,
  FORBIDDEN: 403,
  NOT_FOUND: 404,
  CONFLICT: 409,
  SERVER_ERROR: 500
};

function success(data, message) {
  return { code: CODE.OK, message: message || 'success', data: data || null };
}

function fail(code, message, data) {
  return { code: code, message: message || 'error', data: data || null };
}

/**
 * 从 event 提取客户端 data。
 * AGC 客户端 SDK 调用路径：data 内容在 event.request 中（对象或字符串）。
 */
function extractBody(event) {
  if (event && event.request !== undefined && event.request !== null) {
    if (typeof event.request === 'string') {
      try { return JSON.parse(event.request); } catch (e) { return {}; }
    }
    if (typeof event.request === 'object') {
      if (event.request.body !== undefined && event.request.body !== null) {
        if (typeof event.request.body === 'string') {
          try { return JSON.parse(event.request.body); } catch (e) { return {}; }
        }
        return event.request.body;
      }
      return event.request; // request 本身就是 data
    }
  }
  // 兼容 HTTP 触发器场景
  if (event && event.body !== undefined && event.body !== null) {
    if (typeof event.body === 'string') {
      try { return JSON.parse(event.body); } catch (e) { return {}; }
    }
    return event.body;
  }
  return {};
}

/**
 * 包装处理器：统一异常处理 + 参数提取 + callback 适配。
 * AGC 实测调用 handler(event, context)，callback/logger 在 context 中。
 */
function wrapHttp(handler) {
  return async function (event, context, callback, logger) {
    const cb = callback || (context && context.callback) || function () {};
    const log = logger || (context && context.logger) || console;
    try {
      const body = extractBody(event);
      const result = await handler(body, event, context, log);
      cb(result); // 单参数！客户端 result.result = 传入对象
    } catch (err) {
      const msg = (err && err.message) || 'Internal error';
      log.error('[wrapHttp] error: ' + (err && err.stack || msg));
      cb(fail(CODE.SERVER_ERROR, msg));
    }
  };
}

module.exports = { CODE, success, fail, wrapHttp, extractBody };
