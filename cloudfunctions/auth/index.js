const cloud = require('@cloudbase/node-sdk');
const jwt = require('jsonwebtoken');
const https = require('https');
const crypto = require('crypto');

const app = cloud.init({
  env: process.env.TCB_ENV || cloud.SYMBOL_DEFAULT_ENV,
});
const db = app.database();
const _ = db.command;

const JWT_SECRET = process.env.JWT_SECRET;
if (!JWT_SECRET) throw new Error('[FATAL] JWT_SECRET 未在环境变量中配置');

const WECHAT_APP_ID = process.env.WECHAT_APP_ID;
const WECHAT_APP_SECRET = process.env.WECHAT_APP_SECRET;
const IS_PROD = process.env.NODE_ENV === 'production';

// Token 有效期：access 15分钟，refresh 7天
const ACCESS_TOKEN_TTL = '15m';
const REFRESH_TOKEN_TTL = '7d';

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
  const { action } = body;

  switch (action) {
    case 'send-sms':
      return sendSms(body.phone);
    case 'login':
      return login(body.phone, body.code);
    case 'wechat-login':
      return wechatLogin(body.code);
    case 'refresh-token':
      return refreshToken(body.refreshToken);
    case 'profile':
      return withAuth(event, context, body, getProfile);
    case 'update-profile':
      return withAuth(event, context, body, updateProfile);
    default:
      return { code: 400, message: 'Unknown action' };
  }
};

// ===== JWT 鉴权中间件 =====

function withAuth(event, context, body, handler) {
  // 从 header 或 body 获取 token
  let token = extractToken(event);
  if (!token && body && body.token) token = body.token;
  if (!token) return { code: 401, message: '未提供认证令牌' };

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    return handler(decoded.userId, body);
  } catch (err) {
    if (err.name === 'TokenExpiredError') return { code: 401, message: '令牌已过期，请重新登录' };
    return { code: 401, message: '令牌无效' };
  }
}

function extractToken(event) {
  // 优先从 X-Auth-Token header 取（CloudBase 网关会清空带 Authorization 的 body）
  const authHeader = event.headers?.['x-auth-token']
    || event.headers?.['authorization'] || event.headers?.['Authorization'] || '';
  const match = authHeader.match(/^Bearer\s+(.+)$/i);
  return match ? match[1] : null;
}

// 导出供其他云函数使用
module.exports.verifyToken = (token) => {
  if (!token) return null;
  try { return jwt.verify(token, JWT_SECRET); } catch { return null; }
};
module.exports.extractToken = extractToken;

// ===== 短信验证码 =====

async function sendSms(phone) {
  if (!phone || !/^1[3-9]\d{9}$/.test(phone)) {
    return { code: 400, message: '手机号格式不正确' };
  }

  const oneMinAgo = new Date(Date.now() - 60000);
  const oneHourAgo = new Date(Date.now() - 3600000);

  const recentMin = await db.collection('sms_logs')
    .where({ phone, createdAt: _.gte(oneMinAgo) }).count();
  if (recentMin.total > 0) {
    return { code: 429, message: '发送过于频繁，请稍后再试' };
  }

  const recentHour = await db.collection('sms_logs')
    .where({ phone, createdAt: _.gte(oneHourAgo) }).count();
  if (recentHour.total >= 5) {
    return { code: 429, message: '发送次数已达今日上限' };
  }

  // 使用加密安全的随机数
  const smsCode = String(crypto.randomInt(100000, 1000000));

  await db.collection('sms_logs').add({
    phone,
    code: smsCode,
    used: false,
    expiresAt: new Date(Date.now() + 300000),
    createdAt: new Date(),
  });

  // 生产环境严禁打印验证码；开发环境仅在本地调试时输出
  if (!IS_PROD) {
    console.log(`[DEV] SMS sent to *******${phone.slice(-4)}`);
  }

  return {
    code: 200,
    message: '验证码已发送',
    // 仅开发环境返回验证码，生产环境删除此行
    ...(!IS_PROD ? { devCode: smsCode } : {}),
  };
}

// ===== 手机号登录 =====

async function login(phone, code) {
  const smsLogs = await db.collection('sms_logs')
    .where({ phone, code, used: false, expiresAt: _.gte(new Date()) })
    .orderBy('createdAt', 'desc').limit(1).get();

  if (smsLogs.data.length === 0) {
    return { code: 401, message: '验证码错误或已过期' };
  }

  const updateResult = await db.collection('sms_logs')
    .where({ _id: smsLogs.data[0]._id, used: false })
    .update({ used: true });

  if (updateResult.updated === 0) {
    return { code: 401, message: '验证码已被使用' };
  }

  return buildLoginResult(phone, null);
}

// ===== 微信登录 =====

async function wechatLogin(wxCode) {
  if (!WECHAT_APP_ID || !WECHAT_APP_SECRET) {
    return { code: 500, message: '微信登录未配置' };
  }

  const wxData = await requestWechatAccessToken(wxCode);
  if (!wxData || wxData.errcode) {
    return { code: 401, message: '微信授权失败' };
  }

  return buildLoginResult(null, wxData.openid, wxData.unionid);
}

function requestWechatAccessToken(code) {
  return new Promise((resolve, reject) => {
    // 注意：微信 /sns/oauth2/access_token 仅支持 GET，secret 在 query string 中
    // 通过 HTTPS 传输，query string 被加密，不会被中间人截获
    // 生产环境确保 TCB 日志不记录完整 URL
    const url = `https://api.weixin.qq.com/sns/oauth2/access_token`
      + `?appid=${encodeURIComponent(WECHAT_APP_ID)}`
      + `&secret=${encodeURIComponent(WECHAT_APP_SECRET)}`
      + `&code=${encodeURIComponent(code)}`
      + `&grant_type=authorization_code`;
    https.get(url, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try { resolve(JSON.parse(data)); } catch (e) { reject(e); }
      });
    }).on('error', reject);
  });
}

async function buildLoginResult(phone, wechatOpenId, wechatUnionId) {
  let user = null;
  if (wechatOpenId) {
    const res = await db.collection('users').where({ wechatOpenId }).limit(1).get();
    user = res.data[0];
  }
  if (!user && phone) {
    const res = await db.collection('users').where({ phone }).limit(1).get();
    user = res.data[0];
  }

  if (user) {
    const updates = { updatedAt: new Date() };
    if (phone && !user.phone) updates.phone = phone;
    if (wechatOpenId && !user.wechatOpenId) updates.wechatOpenId = wechatOpenId;
    if (user.tokenVersion === undefined) updates.tokenVersion = 0;
    if (Object.keys(updates).length > 1) {
      await db.collection('users').doc(user._id).update(updates);
    }
  } else {
    const newUser = {
      phone: phone || null,
      wechatOpenId: wechatOpenId || null,
      nickname: `猫友${(phone || '').slice(-4) || Math.random().toString(36).slice(-4)}`,
      totalCatches: 0, totalBattles: 0, totalWins: 0,
      tokenVersion: 0,
      createdAt: new Date(), updatedAt: new Date(),
    };
    // 清理 null 字段以保持数据干净
    if (!newUser.phone) delete newUser.phone;
    if (!newUser.wechatOpenId) delete newUser.wechatOpenId;
    const res = await db.collection('users').add(newUser);
    user = { _id: res.id, ...newUser };
  }

  const tv = user.tokenVersion || 0;
  const token = jwt.sign({ userId: user._id, tv }, JWT_SECRET, { expiresIn: ACCESS_TOKEN_TTL });
  const refreshToken = jwt.sign(
    { userId: user._id, type: 'refresh', tv }, JWT_SECRET, { expiresIn: REFRESH_TOKEN_TTL },
  );

  return {
    code: 200,
    data: {
      token,
      refreshToken,
      user: {
        id: user._id, phone: user.phone || '', nickname: user.nickname || '',
        avatarUrl: user.avatarUrl || null, totalCatches: user.totalCatches || 0,
      },
    },
  };
}

// ===== Token 刷新 =====

async function refreshToken(refreshToken) {
  try {
    const decoded = jwt.verify(refreshToken, JWT_SECRET);
    if (decoded.type !== 'refresh') return { code: 401, message: 'Token 类型错误' };

    // 检查 token 版本是否和数据库一致（旧 token 自动失效）
    const user = await db.collection('users').doc(decoded.userId).get();
    if (!user.data || (Array.isArray(user.data) && user.data.length === 0)) {
      return { code: 401, message: '用户不存在' };
    }
    const userData = Array.isArray(user.data) ? user.data[0] : user.data;
    const currentTv = userData.tokenVersion || 0;
    if ((decoded.tv || 0) !== currentTv) {
      return { code: 401, message: 'Token 已失效（已在别处刷新）' };
    }

    // 递增版本号使旧 token 失效
    const newTv = currentTv + 1;
    await db.collection('users').doc(decoded.userId).update({ tokenVersion: newTv });

    const newToken = jwt.sign(
      { userId: decoded.userId, tv: newTv }, JWT_SECRET, { expiresIn: ACCESS_TOKEN_TTL },
    );
    const newRefresh = jwt.sign(
      { userId: decoded.userId, type: 'refresh', tv: newTv }, JWT_SECRET, { expiresIn: REFRESH_TOKEN_TTL },
    );

    return { code: 200, data: { token: newToken, refreshToken: newRefresh } };
  } catch (err) {
    if (err.name === 'TokenExpiredError') return { code: 401, message: 'Refresh token 已过期' };
    return { code: 401, message: 'Token 验证失败' };
  }
}

// ===== 用户信息 =====

async function getProfile(userId) {
  const user = await db.collection('users').doc(userId).get();
  if (!user.data || (Array.isArray(user.data) && user.data.length === 0)) {
    return { code: 404, message: '用户不存在' };
  }
  const u = Array.isArray(user.data) ? user.data[0] : user.data;
  return {
    code: 200,
    data: {
      id: u._id, phone: u.phone || '', nickname: u.nickname || '',
      avatarUrl: u.avatarUrl || null, totalCatches: u.totalCatches || 0,
      totalBattles: u.totalBattles || 0, totalWins: u.totalWins || 0, createdAt: u.createdAt,
    },
  };
}

async function updateProfile(userId, body) {
  const updates = { updatedAt: new Date() };
  if (body.nickname !== undefined) updates.nickname = String(body.nickname).substring(0, 50);
  // 校验 avatarUrl 协议
  if (body.avatarUrl !== undefined) {
    const url = String(body.avatarUrl);
    if (!url.startsWith('https://') && !url.startsWith('http://')) {
      return { code: 400, message: 'avatarUrl 协议不支持' };
    }
    updates.avatarUrl = url;
  }
  await db.collection('users').doc(userId).update(updates);
  return { code: 200, message: '更新成功' };
}
