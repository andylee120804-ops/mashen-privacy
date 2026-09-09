// cloud/game-record-backup/handler.js
// 牌局记录云备份：push（幂等全量 upsert）/ pull（仅本人，按日期倒序）。
// 客户端 data: { action, __uid, records? }
// GameBackup schema: userId,date,deityId,kowtowCount,games(String=JSON 数组),note,updatedAt
//   主键 (userId, date)：每用户每天一条。push 全量覆盖，pull 把 games 反序列化回数组，
//   返回与客户端 GameRecord 同构的对象（client GameRecord.games 是 GameResult[]）。
//   查询走 date 索引（schema 已建 date DESC），userId 过滤在内存做（同 wish-wall list 先例）。
const { wrapHttp, success, fail, CODE } = require('./shared/response');
const { getDB, toGenericObjects, toPlainObject, withTimeout, DB_TIMEOUT_MS } = require('./shared/db');

var TYPE = 'GameBackup';
var MAX_RECORDS = 500;
var DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

/** 服务端权威字段：userId 一律以 __uid 为准，客户端传的其他 userId 一律忽略（防伪造他人数据） */
function toDbRecord(uid, r) {
  var games = Array.isArray(r.games) ? JSON.stringify(r.games) : '[]';
  return {
    userId: uid,
    date: String(r.date || ''),
    deityId: typeof r.deityId === 'number' ? r.deityId : 0,
    kowtowCount: typeof r.kowtowCount === 'number' ? r.kowtowCount : 0,
    games: games,
    note: typeof r.note === 'string' ? r.note : '',
    updatedAt: new Date().toISOString()
  };
}

/** 反序列化回客户端同构对象（games String → GameResult[]，历史脏数据容错为空数组） */
function toClientRecord(obj) {
  var games = [];
  try {
    var parsed = JSON.parse(obj.games || '[]');
    if (Array.isArray(parsed)) games = parsed;
  } catch (e) {
    // 历史脏数据容错
  }
  return {
    date: obj.date || '',
    deityId: obj.deityId || 0,
    kowtowCount: obj.kowtowCount || 0,
    games: games,
    note: obj.note || ''
  };
}

async function handler(body, event, context, log) {
  var action = body.action;
  var uid = body.__uid;

  if (!uid) return fail(CODE.UNAUTHORIZED, 'uid required');

  var db = getDB();

  try {
    switch (action) {
      case 'pull': {
        var t0 = Date.now();
        log.info('[game-record-backup] pull start uid=' + uid);
        var result = await withTimeout(
          db.collection(TYPE).query().orderByDesc('date').limit(1000).get(),
          DB_TIMEOUT_MS,
          'game-record-backup:pull'
        );
        var mine = (result || [])
          .map(function (item) { return toPlainObject(item); })
          .filter(function (o) { return o.userId === uid; })
          .map(toClientRecord);
        log.info('[game-record-backup] pull raw ' + (Date.now() - t0) + 'ms uid=' + uid + ' count=' + mine.length);
        return success(mine);
      }

      case 'push': {
        var records = body.records;
        if (!Array.isArray(records) || records.length === 0) {
          return fail(CODE.PARAM_ERROR, 'records required');
        }
        if (records.length > MAX_RECORDS) {
          return fail(CODE.PARAM_ERROR, 'too many records, max ' + MAX_RECORDS);
        }
        // date 必填且格式合法；同 date 多条取最后一条（主键 userId+date 唯一，先自去重）
        var seen = {};
        var rows = [];
        for (var i = 0; i < records.length; i++) {
          var r = records[i];
          if (!r || typeof r !== 'object') continue;
          var date = String(r.date || '');
          if (!DATE_RE.test(date)) continue;
          if (seen[date]) continue;
          seen[date] = true;
          rows.push(toDbRecord(uid, r));
        }
        if (rows.length === 0) {
          return fail(CODE.PARAM_ERROR, 'records require valid date (YYYY-MM-DD)');
        }
        var t1 = Date.now();
        await withTimeout(
          db.collection(TYPE).upsert(toGenericObjects(TYPE, rows)),
          DB_TIMEOUT_MS,
          'game-record-backup:push'
        );
        log.info('[game-record-backup] push ok uid=' + uid + ' records=' + rows.length + ' ' + (Date.now() - t1) + 'ms');
        return success({ pushed: rows.length });
      }

      case 'delete': {
        var dates = body.dates;
        if (!Array.isArray(dates) || dates.length === 0) {
          return fail(CODE.PARAM_ERROR, 'dates required');
        }
        if (dates.length > 50) {
          return fail(CODE.PARAM_ERROR, 'too many dates, max 50');
        }
        // 去重 + 只留合法日期
        var targets = [];
        for (var di = 0; di < dates.length; di++) {
          var dd = String(dates[di] || '');
          if (DATE_RE.test(dd) && targets.indexOf(dd) < 0) targets.push(dd);
        }
        if (targets.length === 0) {
          return fail(CODE.PARAM_ERROR, 'dates require valid format (YYYY-MM-DD)');
        }
        var deleted = 0;
        var t2 = Date.now();
        for (var dj = 0; dj < targets.length; dj++) {
          var found = await withTimeout(
            db.collection(TYPE).query().equalTo('date', targets[dj]).limit(100).get(),
            DB_TIMEOUT_MS,
            'game-record-backup:delete-query'
          );
          // 只删本人行
          var mine = (found || []).filter(function (it) {
            return toPlainObject(it).userId === uid;
          });
          if (mine.length > 0) {
            // 用查询返回的完整对象删除（同 wish-wall 删除红线：仅含 id 的新对象无法定位记录）
            await withTimeout(db.collection(TYPE).delete(mine), DB_TIMEOUT_MS, 'game-record-backup:delete');
            deleted += mine.length;
          }
        }
        log.info('[game-record-backup] delete ok uid=' + uid + ' dates=' + targets.length + ' deleted=' + deleted + ' ' + (Date.now() - t2) + 'ms');
        return success({ deleted: deleted });
      }

      default:
        return fail(CODE.PARAM_ERROR, 'unknown action: ' + action);
    }
  } catch (err) {
    log.error('[game-record-backup] DB error: ' + (err && err.message));
    return fail(CODE.SERVER_ERROR, 'db error: ' + (err && err.message));
  }
}

module.exports.myHandler = wrapHttp(handler);
