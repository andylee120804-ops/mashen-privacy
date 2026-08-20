// cloud/shared/db.js
// Cloud DB 访问封装。
// 红线修复（见 ~/.claude/rules/common/agc-cloud-function.md）：
//  1. createInstance 必须传唯一 name，否则文件凭证被 AGC_CONFIG 环境变量实例抢占。
//  2. database() 必须传 { zoneName }（CloudDBZoneConfig 必填），无参会崩。
//  3. upsert/delete 前必须用 toGenericObjects 转换（SDK convertTClass 不更新 fieldMap，
//     直接传普通对象会 3037003 primary key missing）。query 不受影响，无需转换。
//  4. CloudDBZoneGenericObject.getObjectType / CloudDBZoneQuery.where 均不存在；
//     collection 接受字符串对象类型名，query 由 collection(type).query() 链式 .get() 执行。
const { cloud, CloudDBZoneGenericObject } = require('@hw-agconnect/cloud-server');
const fs = require('fs');
const path = require('path');

// API Client 凭证（用户中心 > 凭证管理 > 创建 API Client，关联 Cloud DB 产品）。
// 部署时随 zip 一起上传到函数根目录。
const CRED_FILE = path.join(__dirname, '..', 'agc-credential.json');

// Cloud DB 存储区名称：必须与 AGC 控制台 Cloud DB 存储区逐字一致。
// ⚠️ 存储区必须先在控制台手动创建，database({ zoneName }) 不会自动创建——
//    不存在时直接报 2002037: CloudDBZone does not exist。
// 命名规则：字母开头，仅含字母数字（不能下划线/中划线）。
const CLOUD_DB_ZONE = 'MashenZone';

let cloudInstance = null;
let cachedDB = null;

function getCloud() {
  if (cloudInstance) return cloudInstance;
  if (fs.existsSync(CRED_FILE)) {
    try {
      // 唯一 name，强制以文件凭证初始化新实例（默认 'default' 会被环境变量抢占）
      cloudInstance = cloud.createInstance(CRED_FILE, 'mashen-cloud-db');
      return cloudInstance;
    } catch (e) {
      console.warn('[db] createInstance failed:', e.message);
    }
  }
  cloudInstance = cloud; // 兜底：使用环境变量凭证
  return cloudInstance;
}

/** 获取已配置存储区的 CloudDB 实例（缓存） */
function getDB() {
  if (cachedDB) return cachedDB;
  cachedDB = getCloud().database({ zoneName: CLOUD_DB_ZONE });
  return cachedDB;
}

/**
 * 把普通 JS 对象转为 CloudDBZoneGenericObject（经 addFieldValue 写入 fieldMap）。
 * isPrimaryKey 传 false：服务端从 schema 自知主键，字段值进 fieldMap 即可。
 */
function toGenericObjects(objectTypeName, records) {
  if (!Array.isArray(records)) records = [records];
  return records.map(function (r) {
    if (r instanceof CloudDBZoneGenericObject) return r;
    var obj = CloudDBZoneGenericObject.build(objectTypeName);
    var keys = Object.keys(r);
    for (var i = 0; i < keys.length; i++) {
      var key = keys[i];
      if (typeof r[key] !== 'function' && r[key] !== undefined) {
        obj.addFieldValue(key, r[key], false);
      }
    }
    return obj;
  });
}

/** 计算本周一日期（UTC，YYYY-MM-DD），用于周榜重置 */
function getWeekStart(d) {
  var date = new Date(d);
  var day = date.getUTCDay(); // 0=Sun .. 6=Sat
  var diff = day === 0 ? -6 : 1 - day; // 以周一为起点
  date.setUTCDate(date.getUTCDate() + diff);
  return date.toISOString().split('T')[0];
}

module.exports = {
  getCloud: getCloud,
  getDB: getDB,
  toGenericObjects: toGenericObjects,
  getWeekStart: getWeekStart,
  CLOUD_DB_ZONE: CLOUD_DB_ZONE
};
