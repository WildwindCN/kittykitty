const cloud = require('@cloudbase/node-sdk');
const jwt = require('jsonwebtoken');
const https = require('https');
const http = require('http');
const crypto = require('crypto');

const app = cloud.init({ env: process.env.TCB_ENV || cloud.SYMBOL_DEFAULT_ENV });
const db = app.database();
const _ = db.command;

const JWT_SECRET = process.env.JWT_SECRET;
if (!JWT_SECRET) throw new Error('[FATAL] JWT_SECRET 未在环境变量中配置');
const PYTHON_FN_URL = process.env.EXTERNAL_RECOGNITION_URL || 'https://kittykitty-d0go1pcqbe5e83de6.service.tcloudbase.com/recognition-py';
// 本地测试设置: EXTERNAL_RECOGNITION_URL=http://your-ip:8765

// 相似度阈值：超过此值判定为同一只猫
const SIMILARITY_THRESHOLD = 0.82;
// 搜索半径（米）
const SEARCH_RADIUS = 5000;
// 简单的 IP 限流缓存（15分钟窗口，最多10次）
const RATE_LIMIT_MAP = new Map();
const RATE_LIMIT_WINDOW = 15 * 60 * 1000; // 15分钟
const RATE_LIMIT_MAX = 10;

function extractToken(event) {
  const authHeader = event.headers?.['x-auth-token']
    || event.headers?.['authorization'] || event.headers?.['Authorization'] || '';
  const match = authHeader.match(/^Bearer\s+(.+)$/i);
  if (match) return match[1];
  if (event.queryStringParameters?.token) return event.queryStringParameters.token;
  return null;
}

function getClientIp(event) {
  return event.headers?.['x-forwarded-for']?.split(',')[0]?.trim()
    || event.headers?.['x-real-ip']
    || event.requestContext?.sourceIp
    || 'unknown';
}

function checkRateLimit(ip) {
  const now = Date.now();
  const entry = RATE_LIMIT_MAP.get(ip);
  if (entry && now - entry.windowStart < RATE_LIMIT_WINDOW) {
    if (entry.count >= RATE_LIMIT_MAX) return false;
    entry.count++;
    return true;
  }
  RATE_LIMIT_MAP.set(ip, { count: 1, windowStart: now });
  return true;
}

function verifyAuth(event, body) {
  let token = extractToken(event);
  if (!token && body && body.token) token = body.token;
  if (!token) return null;
  try { return jwt.verify(token, JWT_SECRET); } catch { return null; }
}

// 允许的图片域名白名单（防 SSRF）
const ALLOWED_IMAGE_DOMAINS = [
  '.cos.ap-shanghai.myqcloud.com',
  '.cos.ap-guangzhou.myqcloud.com',
  '.tcloudbaseapp.com',
  '.tcb.qcloud.la',
  'kittykitty-d0go1pcqbe5e83de6.service.tcloudbase.com',
];
function isAllowedImageUrl(url) {
  try {
    const u = new URL(url);
    if (u.protocol !== 'https:') return false;
    return ALLOWED_IMAGE_DOMAINS.some(d => u.hostname.endsWith(d));
  } catch { return false; }
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
  const { action, imageUrl, catFaceId } = body;

  if (action === 'match') {
    return matchCatFace(imageUrl, body.latitude, body.longitude, getClientIp(event));
  }

  const auth = verifyAuth(event, body);
  if (!auth) return { code: 401, message: '请先登录' };

  switch (action) {
    case 'register':
      return registerCatFace(imageUrl, body.featureVector, body.latitude, body.longitude);
    case 'get-versions':
      return getCatVersions(catFaceId);
    default:
      return { code: 400, message: 'Unknown action' };
  }
};

// ===== 调用 Python 函数提取特征（失败时降级为 JS 感知哈希）=====

function extractFeatures(imageUrl) {
  return new Promise((resolve, reject) => {
    // 方案1: 尝试直接调 Python/E CS /extract (ECS 自行下载)
    const data = JSON.stringify({ action: 'match', imageUrl });
    const url = new URL(PYTHON_FN_URL);
    const isHttps = url.protocol === 'https:';
    const transport = isHttps ? https : http;

    url.pathname = '/extract';
    const req = transport.request(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      timeout: 25000,
    }, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        try {
          const result = JSON.parse(body);
          if (result.code === 200 && result.data) {
            resolve(result.data);
          } else {
            reject(new Error(result.message || 'Feature extraction failed'));
          }
        } catch (e) {
          reject(e);
        }
      });
    });
    req.on('error', () => {
      // 方案2: ECS 直接下载失败 → CloudBase 下载后上传到 /extract_upload
      console.log('[recognition] Direct extract failed, trying upload method...');
      resolve(extractViaUpload(imageUrl));
    });
    req.on('timeout', () => {
      req.destroy();
      console.log('[recognition] Direct extract timeout, trying upload method...');
      resolve(extractViaUpload(imageUrl));
    });
    req.write(data);
    req.end();
  });
}

/**
 * CloudBase 下载图片 → 上传到 ECS /extract_upload → 获取特征
 */
function extractViaUpload(imageUrl) {
  return new Promise((resolve, reject) => {
    const url = new URL(PYTHON_FN_URL);
    const isHttps = url.protocol === 'https:';
    const transport = isHttps ? https : http;

    // Step 1: 下载图片
    const imgUrl = new URL(imageUrl);
    const imgTransport = imgUrl.protocol === 'https:' ? https : http;
    imgTransport.get(imageUrl, { timeout: 15000, headers: { 'User-Agent': 'KittyKitty/1.0' } }, (imgRes) => {
      const chunks = [];
      imgRes.on('data', c => chunks.push(c));
      imgRes.on('end', () => {
        const imgData = Buffer.concat(chunks);
        if (imgData.length === 0 || imgData.length > 10 * 1024 * 1024) {
          reject(new Error('图片无效或过大'));
          return;
        }

        // Step 2: 上传到 ECS /extract_upload
        const boundary = '----kittykitty' + Date.now();
        const CRLF = '\r\n';
        const header = [
          `--${boundary}`,
          'Content-Disposition: form-data; name="file"; filename="cat.jpg"',
          'Content-Type: image/jpeg',
          '', ''
        ].join(CRLF);
        const footer = `${CRLF}--${boundary}--${CRLF}`;
        const body = Buffer.concat([
          Buffer.from(header),
          imgData,
          Buffer.from(footer)
        ]);

        url.pathname = '/extract_upload';
        const req2 = transport.request(url, {
          method: 'POST',
          headers: {
            'Content-Type': `multipart/form-data; boundary=${boundary}`,
            'Content-Length': body.length,
          },
          timeout: 30000,
        }, (res2) => {
          let respBody = '';
          res2.on('data', c => respBody += c);
          res2.on('end', () => {
            try {
              const result = JSON.parse(respBody);
              if (result.code === 200 && result.data) {
                resolve(result.data);
              } else {
                reject(new Error(result.message || 'Feature extraction failed'));
              }
            } catch (e) {
              reject(e);
            }
          });
        });
        req2.on('error', reject);
        req2.write(body);
        req2.end();
      });
      imgRes.on('error', reject);
    }).on('error', () => {
      // 最终降级 → JS 感知哈希
      console.log('[recognition] All external methods failed, using JS fallback');
      resolve(extractFeaturesJSFallback(imageUrl));
    });
  });
}

/**
 * 纯 JS 感知哈希 + 颜色直方图 (144维)
 * Python 函数不可用时的降级方案
 */
function extractFeaturesJSFallback(imageUrl) {
  return new Promise((resolve, reject) => {
    https.get(imageUrl, { timeout: 15000, headers: { 'User-Agent': 'KittyKitty/1.0' } }, (res) => {
      const chunks = [];
      res.on('data', c => chunks.push(c));
      res.on('end', () => {
        const imgData = Buffer.concat(chunks);
        if (imgData.length === 0 || imgData.length > 10 * 1024 * 1024) {
          reject(new Error('图片无效或过大'));
          return;
        }

        // 感知哈希: 取图像前 64 字节，每字节生成一个二值特征
        const aHash = [];
        const pixelCount = Math.min(imgData.length, 2048);
        for (let i = 0; i < pixelCount; i += 32) {
          const byte = imgData[i] || 0;
          aHash.push(byte > 128 ? 1.0 : 0.0);
        }
        // 填充到 64 维
        while (aHash.length < 64) aHash.push(0);

        // RGB 颜色直方图: 48 维 (16 bins × 3 channels)
        const colorHist = new Array(48).fill(0);
        const step = Math.max(1, Math.floor(imgData.length / 512));
        let r = 0, g = 0, b = 0, count = 0;
        for (let i = 0; i < imgData.length - 2 && count < 512; i += step) {
          r += imgData[i] || 0;
          g += imgData[i + 1] || 0;
          b += imgData[i + 2] || 0;
          count++;
        }
        if (count > 0) {
          const binR = Math.min(15, Math.floor((r / count) / 16));
          const binG = Math.min(15, Math.floor((g / count) / 16));
          const binB = Math.min(15, Math.floor((b / count) / 16));
          colorHist[binR] = 1;
          colorHist[16 + binG] = 1;
          colorHist[32 + binB] = 1;
        }

        // 纹理特征: 32 维 (相邻像素差值)
        const texture = new Array(32).fill(0);
        for (let i = 0; i < imgData.length - 1 && i < 1024; i += 32) {
          const diff = Math.abs((imgData[i] || 0) - (imgData[i + 1] || 0)) / 255;
          const bin = Math.min(31, Math.floor(diff * 32));
          texture[bin] += 0.1;
        }

        const features = [...aHash, ...colorHist, ...texture];
        const norm = Math.sqrt(features.reduce((s, f) => s + f * f, 0)) || 1;
        const normalized = features.map(f => parseFloat((f / norm).toFixed(6)));

        resolve({
          method: 'js_perceptual_hash',
          featureDim: normalized.length,
          featureVector: normalized,
          imageHash: crypto.createHash('sha256').update(imgData).digest('hex').substring(0, 16),
          imageSize: imgData.length,
        });
      });
      res.on('error', reject);
    }).on('error', reject);
  });
}

// ===== 余弦相似度 =====

function cosineSimilarity(a, b) {
  if (!a || !b || a.length !== b.length) return 0;
  let dot = 0, normA = 0, normB = 0;
  for (let i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  if (normA === 0 || normB === 0) return 0;
  return dot / (Math.sqrt(normA) * Math.sqrt(normB));
}

// ===== 猫脸匹配 =====

async function matchCatFace(imageUrl, latitude, longitude, clientIp) {
  if (!imageUrl || typeof imageUrl !== 'string') {
    return { code: 400, message: 'imageUrl 不能为空' };
  }

  // 速率限制
  if (!checkRateLimit(clientIp)) {
    return { code: 429, message: '请求过于频繁，请稍后再试' };
  }

  // SSRF 防护：只允许 COS / CloudBase 域名
  if (!isAllowedImageUrl(imageUrl)) {
    return { code: 400, message: 'imageUrl 域名不在白名单内' };
  }

  const lat = Number(latitude);
  const lng = Number(longitude);

  try {
    // 1. 调用 Python 函数提取特征向量
    console.log(`[recognition] extracting features from: ${imageUrl}`);
    const features = await extractFeatures(imageUrl);
    const featureVector = features.featureVector;
    if (!featureVector || featureVector.length === 0) {
      return { code: 500, message: '特征提取失败' };
    }
    console.log(`[recognition] features extracted: ${features.featureDim}d, method=${features.method}`);

    // 2. 查询 5km 内已有特征向量的猫咪
    if (!isNaN(lat) && !isNaN(lng)) {
      const nearbyCats = await db.collection('cats')
        .where({
          captureLocation: db.command.geoNear({
            geometry: new db.Geo.Point(lng, lat),
            maxDistance: SEARCH_RADIUS, minDistance: 0,
          }),
          featureVector: _.exists(true),
        })
        .limit(20)
        .get();

      console.log(`[recognition] nearby cats with features: ${nearbyCats.data.length}`);

      // 3. 逐一计算余弦相似度
      let bestMatch = null;
      let bestSimilarity = 0;

      for (const cat of nearbyCats.data) {
        const storedFeatures = cat.featureVector;
        if (!storedFeatures || storedFeatures.length === 0) continue;

        const similarity = cosineSimilarity(featureVector, storedFeatures);
        if (similarity > bestSimilarity) {
          bestSimilarity = similarity;
          bestMatch = cat;
        }
      }

      // 4. 判断是否匹配
      if (bestMatch && bestSimilarity >= SIMILARITY_THRESHOLD) {
        const sightingCount = await db.collection('cat_sightings')
          .where({ catFaceId: bestMatch.catFaceId || bestMatch._id })
          .count();

        return {
          code: 200,
          data: {
            matched: true,
            catFaceId: bestMatch.catFaceId || bestMatch._id,
            confidence: bestSimilarity,
            sightingCount: sightingCount.total,
            matchedCatName: bestMatch.name,
            matchedCatImage: bestMatch.imageUrl,
            similarity: Math.round(bestSimilarity * 100) / 100,
            method: features.method,
          },
        };
      }

      // 未达阈值
      return {
        code: 200,
        data: {
          matched: false,
          confidence: bestSimilarity,
          nearbyChecked: nearbyCats.data.length,
          method: features.method,
          featureVector: features.featureVector,
          featureDim: features.featureDim,
          message: bestSimilarity > 0
            ? `最相似度 ${(bestSimilarity*100).toFixed(1)}%，未达阈值 ${(SIMILARITY_THRESHOLD*100).toFixed(0)}%`
            : '5km内无可比对的猫咪',
        },
      };
    }

    return { code: 200, data: { matched: false, method: features.method, featureVector: features.featureVector } };
  } catch (e) {
    console.error(`[recognition] error:`, e.message);
    return { code: 500, message: `识别失败: ${e.message}` };
  }
}

// ===== 注册猫脸（存储特征向量）=====

async function registerCatFace(imageUrl, featureVector, latitude, longitude) {
  if (!imageUrl) return { code: 400, message: 'imageUrl 不能为空' };

  // 如果没有提供特征向量，自动提取
  let features = featureVector;
  if (!features || features.length === 0) {
    try {
      const result = await extractFeatures(imageUrl);
      features = result.featureVector;
    } catch (e) {
      return { code: 500, message: `特征提取失败: ${e.message}` };
    }
  }

  if (!Array.isArray(features) || features.length === 0) {
    return { code: 400, message: 'featureVector 不能为空' };
  }

  const catFaceId = crypto.randomUUID();

  await db.collection('cat_faces').add({
    _id: catFaceId, imageUrl,
    featureVector: features,
    verified: false, createdAt: new Date(),
  });

  return { code: 200, data: { catFaceId, featureDim: features.length } };
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
      id: c._id, name: c.name, rarity: c.rarity, cp: c.cp,
      level: c.level, imageUrl: c.imageUrl,
      ownerId: c.userId, capturedAt: c.capturedAt,
    }));
  }
  return { code: 200, data: { catFaceId, sightingCount: sightings.data.length, cats } };
}
