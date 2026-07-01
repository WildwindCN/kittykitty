const cloud = require('@cloudbase/node-sdk');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');

const app = cloud.init({ env: process.env.TCB_ENV || cloud.SYMBOL_DEFAULT_ENV });
const db = app.database();
const _ = db.command;

const JWT_SECRET = process.env.JWT_SECRET;
if (!JWT_SECRET) throw new Error('[FATAL] JWT_SECRET 未在环境变量中配置');

function extractToken(event) {
  const authHeader = event.headers?.['x-auth-token']
    || event.headers?.['authorization'] || event.headers?.['Authorization'] || '';
  const match = authHeader.match(/^Bearer\s+(.+)$/i);
  if (match) return match[1];
  if (event.queryStringParameters?.token) return event.queryStringParameters.token;
  return null;
}

function verifyAuth(event, body) {
  let token = extractToken(event);
  if (!token && body && body.token) token = body.token;
  if (!token) return null;
  try { return jwt.verify(token, JWT_SECRET); } catch { return null; }
}

/**
 * 解析 HTTP event body — 兼容 CloudBase 网关的各种编码
 */
function parseBody(event) {
  if (typeof event.body === 'object' && event.body !== null && !Buffer.isBuffer(event.body)) {
    return event.body;
  }
  if (typeof event.body === 'string') {
    let raw = event.body;
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
  return event;
}

exports.main = async (event, context) => {
  const body = parseBody(event);
  const auth = verifyAuth(event, body);
  if (!auth) return { code: 401, message: '请先登录' };

  const { action } = body;
  switch (action) {
    case 'submit':
      return submitBattleResult(auth.userId, body);
    case 'history':
      return getBattleHistory(auth.userId);
    default:
      return { code: 400, message: 'Unknown action' };
  }
};

/**
 * 提交对战结果（服务端验证）
 * 客户端计算 battleHash = SHA256(attackerId + defenderId + rounds + seed)
 * 服务端重新计算并比对，防止伪造
 */
async function submitBattleResult(userId, body) {
  const { attackerId, defenderId, won, battleHash, rounds, seed } = body;
  if (!attackerId || !defenderId || battleHash === undefined) {
    return { code: 400, message: '参数不完整' };
  }

  // 验证 hash
  const expectedHash = crypto.createHash('sha256')
    .update(`${attackerId}|${defenderId}|${rounds || 0}|${seed || 0}|${won ? 1 : 0}`)
    .digest('hex')
    .substring(0, 16);
  if (battleHash !== expectedHash) {
    return { code: 400, message: '对战数据校验失败' };
  }

  // 验证 attacker 归属权
  const attacker = await db.collection('cats').doc(attackerId).get();
  const attackerData = Array.isArray(attacker.data) ? attacker.data[0] : attacker.data;
  if (!attackerData || attackerData.userId !== userId) {
    return { code: 403, message: '猫咪不属于你' };
  }

  // 更新对战统计
  const updates = {
    totalBattles: _.inc(1),
  };
  if (won) {
    updates.totalWins = _.inc(1);
  }
  await db.collection('cats').doc(attackerId).update(updates);
  await db.collection('users').doc(userId).update({ totalBattles: _.inc(1) });

  // 记录对战日志
  await db.collection('battle_logs').add({
    attackerId, defenderId, userId,
    won: !!won, rounds: rounds || 0, seed: seed || 0,
    createdAt: new Date(),
  });

  return { code: 200, message: 'ok' };
}

async function getBattleHistory(userId) {
  try {
    const logs = await db.collection('battle_logs')
      .where({ userId })
      .limit(50)
      .get();
    const sorted = (logs.data || []).sort((a, b) => {
      const da = a.createdAt ? new Date(a.createdAt).getTime() : 0;
      const db = b.createdAt ? new Date(b.createdAt).getTime() : 0;
      return db - da;
    });
    return { code: 200, data: sorted };
  } catch (e) {
    // 集合不存在时返回空列表
    return { code: 200, data: [] };
  }
}
