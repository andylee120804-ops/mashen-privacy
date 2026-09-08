// cloud/wish-wall/handler.js
// 心愿墙：list / create / fulfill / delete。
// 客户端 data: { action, __uid, content?, deityId?, nickname?, wishId? }
const { wrapHttp, success, fail, CODE } = require('./shared/response');
const { getDB, toGenericObjects, toPlainObject, withTimeout, DB_TIMEOUT_MS } = require('./shared/db');

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
        var t0 = Date.now();
        log.info('[wish-wall] list start uid=' + uid);
        var result = await withTimeout(
          db.collection(TYPE).query().orderByDesc('createdAt').limit(50).get(),
          DB_TIMEOUT_MS,
          'wish-wall:list'
        );
        log.info('[wish-wall] list raw ' + (Date.now() - t0) + 'ms count=' + (result ? result.length : 0));
        var wishes = (result || []).map(function (item) {
          var obj = toPlainObject(item);
          return {
            id: obj.id || '',
            userId: obj.userId || '',
            nickname: obj.nickname || '麻***',
            content: obj.content || '',
            deityId: obj.deityId || 0,
            fulfilled: obj.fulfilled || false,
            createdAt: obj.createdAt || '',
            fulfilledAt: obj.fulfilledAt || ''
          };
        }).filter(function (w) {
          return w.userId === uid;
        });
        log.info('[wish-wall] list after filter uid=' + uid + ' count=' + wishes.length);
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
        await withTimeout(db.collection(TYPE).upsert(toGenericObjects(TYPE, data)), DB_TIMEOUT_MS, 'wish-wall:create');
        log.info('[wish-wall] create ok id=' + id);
        return success({ id: id, createdAt: now });
      }

      case 'fulfill': {
        var wishId = body.wishId;
        if (!wishId) return fail(CODE.PARAM_ERROR, 'wishId required');

        var existing = await withTimeout(
          db.collection(TYPE).query().equalTo('id', wishId).get(),
          DB_TIMEOUT_MS,
          'wish-wall:fulfill-query'
        );
        if (!existing || existing.length === 0) {
          return fail(CODE.NOT_FOUND, 'wish not found');
        }

        var wish = toPlainObject(existing[0]);
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
        await withTimeout(db.collection(TYPE).upsert(toGenericObjects(TYPE, updated)), DB_TIMEOUT_MS, 'wish-wall:fulfill-upsert');
        return success({ fulfilled: true, fulfilledAt: now });
      }

      case 'delete': {
        var wishId = body.wishId;
        if (!wishId) return fail(CODE.PARAM_ERROR, 'wishId required');

        var existing = await withTimeout(
          db.collection(TYPE).query().equalTo('id', wishId).get(),
          DB_TIMEOUT_MS,
          'wish-wall:delete-query'
        );
        if (!existing || existing.length === 0) {
          return fail(CODE.NOT_FOUND, 'wish not found');
        }

        var wish = toPlainObject(existing[0]);
        // 仅心愿发布者可删除
        if (wish.userId !== uid) return fail(CODE.FORBIDDEN, 'not your wish');

        // 用查询返回的完整 CloudDBZoneGenericObject 删除，而非仅含 id 的新对象。
        // toGenericObjects({ id }) 仅写 id 进 fieldMap，Cloud DB delete 需完整对象才能定位记录。
        await withTimeout(db.collection(TYPE).delete(existing[0]), DB_TIMEOUT_MS, 'wish-wall:delete');
        log.info('[wish-wall] delete ok id=' + wishId);
        return success({ deleted: true });
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
