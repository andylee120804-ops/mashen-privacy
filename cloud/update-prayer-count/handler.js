// cloud/update-prayer-count/handler.js
// 祈福完成后上报：累加今日/本周/总次数与磕头数，按天/周重置。
// 客户端 data: { __uid, nickname, kowtowCount, streak }
const { wrapHttp, success, fail, CODE } = require('./shared/response');
const { getDB, toGenericObjects, getWeekStart } = require('./shared/db');

var TYPE = 'Leaderboard';

async function handler(body, event, context, log) {
  var uid = body.__uid;
  var nickname = body.nickname || '麻***';
  var kowtowCount = body.kowtowCount || 0;
  var streak = body.streak || 0;

  if (!uid) return fail(CODE.UNAUTHORIZED, 'uid required');

  var db = getDB();
  var now = new Date().toISOString();
  var today = now.split('T')[0];
  var weekStart = getWeekStart(now);

  try {
    // 查询当前用户现有记录
    var existing = await db.collection(TYPE).query().equalTo('userId', uid).get();

    var data;
    if (existing && existing.length > 0) {
      var record = existing[0];
      var updatedAt = record.updatedAt || '';
      var recordWeekStart = record.weekStart || '';
      var isNewDay = !updatedAt.startsWith(today);
      var isNewWeek = recordWeekStart !== weekStart;

      data = {
        userId: uid,
        nickname: nickname,
        todayCount: isNewDay ? 1 : (record.todayCount || 0) + 1,
        weekCount: isNewWeek ? 1 : (record.weekCount || 0) + 1,
        totalCount: (record.totalCount || 0) + 1,
        totalKowtow: (record.totalKowtow || 0) + kowtowCount,
        streak: streak,
        updatedAt: now,
        weekStart: weekStart
      };
    } else {
      data = {
        userId: uid,
        nickname: nickname,
        todayCount: 1,
        weekCount: 1,
        totalCount: 1,
        totalKowtow: kowtowCount,
        streak: streak,
        updatedAt: now,
        weekStart: weekStart
      };
    }

    // upsert 必须经 toGenericObjects 转换（SDK convertTClass bug）
    await db.collection(TYPE).upsert(toGenericObjects(TYPE, data));
    return success({ updated: true });
  } catch (err) {
    log.error('[update-prayer-count] DB error: ' + (err && err.message));
    return fail(CODE.SERVER_ERROR, 'db error: ' + (err && err.message));
  }
}

module.exports.myHandler = wrapHttp(handler);
