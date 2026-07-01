const cloud = require('@cloudbase/node-sdk');
const jwt = require('jsonwebtoken');
const app = cloud.init({ env: process.env.TCB_ENV || cloud.SYMBOL_DEFAULT_ENV });
const db = app.database();
const _ = db.command;

const JWT_SECRET = process.env.JWT_SECRET;
if (!JWT_SECRET) throw new Error('[FATAL] JWT_SECRET 未在环境变量中配置');

const CAPTURE_ALLOWED_FIELDS = [
  'name', 'rarity', 'type',
  'baseHp', 'baseAtk', 'baseDef', 'baseSpd', 'baseCrit', 'cp',
  'battleSkills', 'lifeSkills', 'imageUrl', 'cardImageUrl',
  'captureLocation', 'catFaceId', 'featureVector',
];

// 字段类型校验规则
const CAPTURE_FIELD_TYPES = {
  name: 'string',
  rarity: 'string',
  type: 'string',
  baseHp: 'number',
  baseAtk: 'number',
  baseDef: 'number',
  baseSpd: 'number',
  baseCrit: 'number',
  imageUrl: 'string',
  capturedAt: 'string',
};

function validateCaptureData(catData) {
  for (const [field, expectedType] of Object.entries(CAPTURE_FIELD_TYPES)) {
    if (catData[field] !== undefined && catData[field] !== null) {
      if (expectedType === 'number' && typeof catData[field] !== 'number') {
        return `${field} 必须是数字类型`;
      }
      if (expectedType === 'string' && typeof catData[field] !== 'string') {
        return `${field} 必须是字符串类型`;
      }
    }
  }
  if (catData.battleSkills !== undefined && !Array.isArray(catData.battleSkills)) {
    return 'battleSkills 必须是数组';
  }
  if (catData.lifeSkills !== undefined && !Array.isArray(catData.lifeSkills)) {
    return 'lifeSkills 必须是数组';
  }
  if (catData.name !== undefined && (catData.name.length < 1 || catData.name.length > 50)) {
    return 'name 长度需在1-50字符之间';
  }
  if (catData.imageUrl !== undefined && typeof catData.imageUrl === 'string') {
    const url = catData.imageUrl;
    // 允许 HTTPS 链接和 CloudBase 内部 cloud:// fileID
    if (!url.startsWith('https://') && !url.startsWith('cloud://')) {
      return 'imageUrl 必须使用 HTTPS 或 cloud:// 链接';
    }
  }
  return null;
}

// ===== JWT 鉴权工具 =====

function extractToken(event) {
  // 尝试从多个来源获取 token：header / body / query
  const authHeader = event.headers?.['x-auth-token']
    || event.headers?.['authorization'] || event.headers?.['Authorization'] || '';
  const match = authHeader.match(/^Bearer\s+(.+)$/i);
  if (match) return match[1];
  // CloudBase 网关可能在有 auth header 时清空 body，因此从 query 参数获取
  if (event.queryStringParameters?.token) return event.queryStringParameters.token;
  return null;
}

function verifyAuth(event, body) {
  let token = extractToken(event);
  // 最可靠：从 body 中获取 token
  if (!token && body && body.token) token = body.token;
  if (!token) return null;
  try { return jwt.verify(token, JWT_SECRET); } catch { return null; }
}

/**
 * 解析 HTTP event body — 兼容 CloudBase 网关的各种编码
 */
function parseBody(event) {
  // 已解析对象
  if (typeof event.body === 'object' && event.body !== null && !Buffer.isBuffer(event.body)) {
    return event.body;
  }
  // String (可能为空、JSON、或 base64)
  if (typeof event.body === 'string') {
    let raw = event.body;
    // 网关可能 base64 编码 body
    if (event.isBase64Encoded && raw.length > 0) {
      raw = Buffer.from(raw, 'base64').toString('utf-8');
    }
    if (raw.length > 0) {
      try { return JSON.parse(raw); } catch { /* fall through */ }
    }
  }
  if (Buffer.isBuffer(event.body)) {
    try { return JSON.parse(event.body.toString('utf-8')); } catch { /* fall through */ }
  }
  // 最终回退：尝试从 httpMethod + body 重建
  if (typeof event.body === 'string' && event.body.length === 0) {
    // CloudBase 网关在某些情况下清空 body —— 从原始 event 提取参数
    return { action: event.action, ...event };
  }
  return event;
}
exports.main = async (event, context) => {
  const body = parseBody(event);
  const { action } = body;

  // nearby 公开接口，无需鉴权
  if (action === 'nearby') {
    return getNearbyCats(body.latitude, body.longitude, body.radius || 5000);
  }

  // 其他接口需要鉴权
  const auth = verifyAuth(event, body);
  if (!auth) return { code: 401, message: '请先登录' };

  const userId = auth.userId;

  switch (action) {
    case 'capture':
      return captureCat(userId, body.catData);
    case 'my-cats':
      return getMyCats(userId);
    case 'cat-detail':
      return getCatDetail(body.catId, userId);
    case 'cat-versions':
      return getCatVersions(body.catFaceId);
    default:
      return { code: 400, message: 'Unknown action' };
  }
};

async function getNearbyCats(latitude, longitude, radius) {
  const lat = Number(latitude);
  const lng = Number(longitude);
  const rad = Math.min(Number(radius), 50000);
  if (isNaN(lat) || lat < -90 || lat > 90 || isNaN(lng) || lng < -180 || lng > 180) {
    return { code: 400, message: '坐标参数不合法' };
  }

  const cats = await db.collection('cats')
    .where({
      captureLocation: db.command.geoNear({
        geometry: new db.Geo.Point(lng, lat),
        maxDistance: rad, minDistance: 0,
      }),
    })
    .limit(50)
    .get();

  return {
    code: 200,
    data: cats.data.map(c => ({
      id: c._id, name: c.name, rarity: c.rarity, cp: c.cp,
      imageUrl: c.imageUrl, cardImageUrl: c.cardImageUrl,
      location: c.captureLocation, capturedAt: c.capturedAt,
      ownerNickname: c.ownerNickname,
    })),
  };
}

async function captureCat(userId, catData) {
  if (!catData || typeof catData !== 'object') return { code: 400, message: 'catData 不能为空' };

  // 类型校验
  const validationError = validateCaptureData(catData);
  if (validationError) return { code: 400, message: validationError };

  const safeCat = {};
  for (const field of CAPTURE_ALLOWED_FIELDS) {
    if (catData[field] !== undefined) safeCat[field] = catData[field];
  }
  safeCat.userId = userId;
  safeCat.capturedAt = new Date();
  safeCat.level = 1;
  safeCat.exp = 0;
  safeCat.totalBattles = 0;
  safeCat.totalWins = 0;

  // 转换 captureLocation 为 GeoPoint（2dsphere 索引需要）
  if (safeCat.captureLocation) {
    const loc = safeCat.captureLocation;
    if (loc.latitude != null && loc.longitude != null) {
      safeCat.captureLocation = new db.Geo.Point(
        Number(loc.longitude), Number(loc.latitude)
      );
    } else {
      return { code: 400, message: 'captureLocation 需要 latitude 和 longitude' };
    }
  }

  const result = await db.collection('cats').add(safeCat);
  await db.collection('users').doc(userId).update({ totalCatches: _.inc(1) });
  return { code: 200, data: { catId: result.id } };
}

async function getMyCats(userId) {
  try {
    const cats = await db.collection('cats').where({ userId }).limit(100).get();
    // 客户端排序（避免字段缺失/类型不一致导致的 orderBy 异常）
    const sorted = (cats.data || []).sort((a, b) => {
      const da = a.capturedAt ? new Date(a.capturedAt).getTime() : 0;
      const db = b.capturedAt ? new Date(b.capturedAt).getTime() : 0;
      return db - da;
    });
    return { code: 200, data: sorted };
  } catch (e) {
    return { code: 500, message: `查询失败: ${e.message}` };
  }
}

async function getCatDetail(catId, userId) {
  const cat = await db.collection('cats').doc(catId).get();
  if (!cat.data || (Array.isArray(cat.data) && cat.data.length === 0)) {
    return { code: 404, message: '猫咪不存在' };
  }
  const catData = Array.isArray(cat.data) ? cat.data[0] : cat.data;
  if (catData.userId !== userId) {
    return { code: 403, message: '无权查看此猫咪' };
  }
  return { code: 200, data: catData };
}

async function getCatVersions(catFaceId) {
  if (!catFaceId) return { code: 400, message: 'catFaceId 不能为空' };

  const sightings = await db.collection('cat_sightings').where({ catFaceId })
    .orderBy('createdAt', 'desc').get();

  if (sightings.data.length === 0) {
    return { code: 200, data: { catFaceId, sightingCount: 0, cats: [] } };
  }

  const catIds = sightings.data.map(s => s.catId).filter(Boolean);
  let cats = [];
  if (catIds.length > 0) {
    const catResult = await db.collection('cats').where({ _id: _.in(catIds) }).get();
    cats = catResult.data.map(c => ({
      id: c._id, name: c.name, rarity: c.rarity, type: c.type,
      cp: c.cp, level: c.level, imageUrl: c.imageUrl,
      cardImageUrl: c.cardImageUrl, ownerId: c.userId, capturedAt: c.capturedAt,
    }));
  }
  return { code: 200, data: { catFaceId, sightingCount: sightings.data.length, cats } };
}
