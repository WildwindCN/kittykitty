/**
 * KittyKitty 共享鉴权模块
 * 被 auth、cats、recognition 三个云函数共用
 */

const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET;
if (!JWT_SECRET) throw new Error('[FATAL] JWT_SECRET 未在环境变量中配置');

/** 从 HTTP event 提取 Bearer Token */
function extractToken(event) {
  const authHeader = event.headers?.['authorization'] || event.headers?.['Authorization'] || '';
  const match = authHeader.match(/^Bearer\s+(.+)$/i);
  return match ? match[1] : null;
}

/** 验证 JWT，返回 decoded payload 或 null */
function verifyToken(token) {
  if (!token) return null;
  try { return jwt.verify(token, JWT_SECRET); } catch { return null; }
}

/** 从 event 直接鉴权，返回 decoded 或 null */
function verifyAuth(event) {
  const token = extractToken(event);
  if (!token) return null;
  return verifyToken(token);
}

/** JWT 中间件包装器 */
function withAuth(event, context, body, handler) {
  const token = extractToken(event);
  if (!token) return { code: 401, message: '未提供认证令牌' };
  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    return handler(decoded.userId, body);
  } catch (err) {
    if (err.name === 'TokenExpiredError') return { code: 401, message: '令牌已过期，请重新登录' };
    return { code: 401, message: '令牌无效' };
  }
}

/** 获取客户端 IP（用于限流） */
function getClientIp(event) {
  return event.headers?.['x-forwarded-for']?.split(',')[0]?.trim()
    || event.headers?.['x-real-ip']
    || event.requestContext?.sourceIp
    || 'unknown';
}

/** 验证图片 URL 域名白名单（防 SSRF） */
const ALLOWED_IMAGE_DOMAINS = [
  '.cos.ap-shanghai.myqcloud.com',
  '.cos.ap-guangzhou.myqcloud.com',
  '.tcloudbaseapp.com',
];

function isAllowedImageUrl(url) {
  try {
    const u = new URL(url);
    if (u.protocol !== 'https:') return false;
    return ALLOWED_IMAGE_DOMAINS.some(d => u.hostname.endsWith(d));
  } catch { return false; }
}

module.exports = {
  JWT_SECRET,
  extractToken,
  verifyToken,
  verifyAuth,
  withAuth,
  getClientIp,
  isAllowedImageUrl,
};
