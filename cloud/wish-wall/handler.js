// cloud/wish-wall/handler.js
// 心愿墙：list（列表）/ create（发布）/ fulfill（还愿）。
// 客户端 data: { action, __uid, content?, deityId?, nickname?, wishId? }
const { wrapHttp, success, fail, CODE } = require('./shared/response');
const { getDB, toGenericObjects } = require('./shared/db');

var TYPE = 'Wish';
var MAX_CONTENT = 30;

async function handler(body, event, context, log) {
  var action = body.action;
  var uid = body.__uid;

  if (!uid) return fail(CODE.UNAUTHORIZED, 'uid required');

  var db = getDB();

  try {
    switch (action) {
      case 'list': {
        var result = await db.collection(TYPE).query()
          .orderByDesc('createdAt').limit(50).get();
        var wishes = (result || []).map(function (item) {
          return {
            id: item.id || '',
            userId: item.userId || '',
            nickname: item.nickname || '麻***',
            content: item.content || '',
            deityId: item.deityId || 0,
            fulfilled: item.fulfilled || false,
            createdAt: item.createdAt || '',
            fulfilledAt: item.fulfilledAt || ''
          };
        });
        return success(wishes);
      }

      case 'create': {
        var content = body.content;
        var deityId = body.deityId || 0;
        var nickname = body.nickname || '麻***';

        if (!content || typeof content !== 'string' || content.length > MAX_CONTENT) {
          return fail(CODE.PARAM_ERROR, 'content required, max ' + MAX_CONTENT + ' chars');
        }

        var id = 'w_' + Date.now() + '_' + Math.random().toString(36).substring(2, 8);
        var now = new Date().toISOString();
        var data = {
          id: id,
          userId: uid,
          nickname: nickname,
          content: content,
          deityId: deityId,
          fulfilled: false,
          createdAt: now,
          fulfilledAt: ''
        };
        await db.collection(TYPE).upsert(toGenericObjects(TYPE, data));
        return success({ id: id, createdAt: now });
      }

      case 'fulfill': {
        var wishId = body.wishId;
        if (!wishId) return fail(CODE.PARAM_ERROR, 'wishId required');

        var existing = await db.collection(TYPE).query()
          .equalTo('id', wishId).get();
        if (!existing || existing.length === 0) {
          return fail(CODE.NOT_FOUND, 'wish not found');
        }

        var wish = existing[0];
        // 仅心愿发布者可还愿
        if (wish.userId !== uid) return fail(CODE.FORBIDDEN, 'not your wish');

        var now = new Date().toISOString();
        var updated = {
          id: wishId,
          userId: uid,
          nickname: wish.nickname || '麻***',
          content: wish.content || '',
          deityId: wish.deityId || 0,
          fulfilled: true,
          createdAt: wish.createdAt || '',
          fulfilledAt: now
        };
        await db.collection(TYPE).upsert(toGenericObjects(TYPE, updated));
        return success({ fulfilled: true, fulfilledAt: now });
      }

      default:
        return fail(CODE.PARAM_ERROR, 'unknown action: ' + action);
    }
  } catch (err) {
    log.error('[wish-wall] DB error: ' + (err && err.message));
    return fail(CODE.SERVER_ERROR, 'db error: ' + (err && err.message));
  }
}

module.exports.myHandler = wrapHttp(handler);
