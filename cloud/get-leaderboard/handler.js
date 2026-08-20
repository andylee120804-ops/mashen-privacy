// cloud/get-leaderboard/handler.js
// 排行榜查询：日榜/周榜/总榜 + 今日香火人数。
// 客户端 data: { type: 'daily'|'weekly'|'total'|'daily-count', __uid }
// 查询由 collection(type).query() 链式条件后 .get() 执行（返回 Promise<T[]>）。
const { wrapHttp, success, fail, CODE } = require('./shared/response');
const { getDB, getWeekStart } = require('./shared/db');

var TYPE = 'Leaderboard';

function countOf(type, item) {
  if (type === 'daily') return item.todayCount || 0;
  if (type === 'weekly') return item.weekCount || 0;
  return item.totalCount || 0;
}

async function handler(body, event, context, log) {
  var type = body.type || 'daily';
  var uid = body.__uid || '';
  var db = getDB();
  var now = new Date().toISOString();
  var today = now.split('T')[0];
  var weekStart = getWeekStart(now);

  // 今日香火人数：统计今日有祈福记录的用户数
  if (type === 'daily-count') {
    try {
      var cntResult = await db.collection(TYPE).query()
        .greaterThanOrEqualTo('updatedAt', today).get();
      return success({ count: cntResult ? cntResult.length : 0 });
    } catch (err) {
      log.error('[get-leaderboard] daily-count error: ' + (err && err.message));
      return success({ count: 0 }); // 降级：不阻断黄历展示
    }
  }

  try {
    var query;
    switch (type) {
      case 'daily':
        // 今日有祈福记录的用户，按今日次数降序
        query = db.collection(TYPE).query()
          .greaterThan('todayCount', 0)
          .greaterThanOrEqualTo('updatedAt', today)
          .orderByDesc('todayCount')
          .limit(50);
        break;
      case 'weekly':
        // 本周有祈福记录的用户，按本周次数降序
        query = db.collection(TYPE).query()
          .greaterThan('weekCount', 0)
          .greaterThanOrEqualTo('updatedAt', weekStart)
          .orderByDesc('weekCount')
          .limit(50);
        break;
      case 'total':
      default:
        query = db.collection(TYPE).query()
          .greaterThan('totalCount', 0)
          .orderByDesc('totalCount')
          .limit(50);
        break;
    }

    var result = await query.get();
    var entries = (result || []).map(function (item, index) {
      return {
        userId: item.userId || '',
        nickname: item.nickname || '麻***',
        count: countOf(type, item),
        kowtow: item.totalKowtow || 0,
        rank: index + 1
      };
    });

    // 当前用户不在前 50 时，追加自己的排名（rank=0 表示未上榜）
    if (uid) {
      var inList = false;
      for (var i = 0; i < entries.length; i++) {
        if (entries[i].userId === uid) { inList = true; break; }
      }
      if (!inList) {
        var userResult = await db.collection(TYPE).query()
          .equalTo('userId', uid).get();
        if (userResult && userResult.length > 0) {
          var u = userResult[0];
          entries.push({
            userId: u.userId || '',
            nickname: u.nickname || '麻***',
            count: countOf(type, u),
            kowtow: u.totalKowtow || 0,
            rank: 0
          });
        }
      }
    }

    return success(entries);
  } catch (err) {
    log.error('[get-leaderboard] DB error: ' + (err && err.message));
    return fail(CODE.SERVER_ERROR, 'query error: ' + (err && err.message));
  }
}

module.exports.myHandler = wrapHttp(handler);
