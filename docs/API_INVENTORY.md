# KittyKitty 微信小程序 — API 清单

> 更新日期：2026-07-01 | 环境：kittykitty-d0go1pcqbe5e83de6

---

## 一、架构概览

```
微信小程序 (WXML/WXSS/JS)
    │
    ├── wx.cloud.uploadFile / getTempFileURL  → CloudBase 云存储
    ├── wx.login                              → 微信登录 code
    ├── wx.request ──────────────────────────→ CloudBase HTTP 网关
    │                                               │
    │    Base: https://kittykitty-d0go1pcqbe5e83de6.service.tcloudbase.com
    │                                               │
    │    ┌── /auth          → 认证云函数
    │    ├── /cats          → 猫咪 CRUD 云函数
    │    ├── /recognition   → 猫脸识别云函数
    │    └── /battle        → 对战记录云函数
    │
    └── ECS DINOv2 服务 (36.151.145.33:8765)
         └── 猫脸特征向量提取 (384维)
```

---

## 二、鉴权机制

| 项目 | 值 |
|------|-----|
| 鉴权方式 | JWT (HS256) |
| 传输方式 | Header: `X-Auth-Token: Bearer <token>` 或 Body: `{token: "..."}` |
| Access Token 有效期 | 15 分钟 |
| Refresh Token 有效期 | 7 天 |
| 刷新机制 | 客户端收到 401 自动调 `/auth` (`action=refresh-token`)，并发锁 + 请求排队 |

### Token 自动刷新流程

```
API 请求 → 401 → handle401()
    ├── 其他请求正在刷新 → 排队等待
    └── 开始刷新 → refreshToken API
         ├── 成功 → 存储新 token → 重试所有排队请求
         └── 失败 → reLaunch 到登录页
```

---

## 三、API 详细清单

### 3.1 认证模块 — `/auth`

#### `send-sms` — 发送短信验证码

| 项目 | 值 |
|------|-----|
| 鉴权 | 无 |
| 频率限制 | 1次/分钟, 5次/小时 |
| 开发模式 | 响应中返回 `devCode` 字段 |

**请求:**
```json
POST /auth
{
  "action": "send-sms",
  "phone": "13800138000"
}
```

**响应:**
```json
// 成功
{ "code": 200, "message": "验证码已发送", "devCode": "123456" }

// 频率限制
{ "code": 429, "message": "发送过于频繁，请稍后再试" }

// 格式错误
{ "code": 400, "message": "手机号格式不正确" }
```

---

#### `login` — 手机号 + 验证码登录

| 项目 | 值 |
|------|-----|
| 鉴权 | 无 |

**请求:**
```json
POST /auth
{
  "action": "login",
  "phone": "13800138000",
  "code": "123456"
}
```

**响应:**
```json
{
  "code": 200,
  "data": {
    "token": "eyJhbG...",
    "refreshToken": "eyJhbG...",
    "user": {
      "id": "user_xxx",
      "phone": "13800138000",
      "nickname": "猫友8000",
      "avatarUrl": null,
      "totalCatches": 0
    }
  }
}
```

---

#### `wechat-login` — 微信一键登录

| 项目 | 值 |
|------|-----|
| 鉴权 | 无 |
| 前置条件 | 云函数环境变量已配置 `WECHAT_APP_ID` 和 `WECHAT_APP_SECRET` |
| ⚠️ 状态 | 环境变量未配置，当前返回 500 |

**请求:**
```json
POST /auth
{
  "action": "wechat-login",
  "code": "wx.login() 返回的临时 code"
}
```

**响应:**
```json
// 成功（格式同 login）
{ "code": 200, "data": { "token": "...", "refreshToken": "...", "user": {...} } }

// 未配置
{ "code": 500, "message": "微信登录未配置" }

// code 无效
{ "code": 401, "message": "微信授权失败" }
```

---

#### `refresh-token` — 刷新 Token

| 项目 | 值 |
|------|-----|
| 鉴权 | 无（凭 refreshToken 本身验证） |

**请求:**
```json
POST /auth
{
  "action": "refresh-token",
  "refreshToken": "eyJhbG..."
}
```

**响应:**
```json
{
  "code": 200,
  "data": {
    "token": "eyJhbG...（新 access token）",
    "refreshToken": "eyJhbG...（新 refresh token，旧 token 同时失效）"
  }
}
```

---

#### `profile` — 获取用户信息

| 项目 | 值 |
|------|-----|
| 鉴权 | JWT |
| 调用方 | 当前未使用 |

**请求:**
```json
POST /auth
{
  "action": "profile",
  "token": "eyJhbG..."
}
```

**响应:**
```json
{
  "code": 200,
  "data": {
    "id": "user_xxx",
    "phone": "13800138000",
    "nickname": "猫友8000",
    "avatarUrl": null,
    "totalCatches": 5,
    "totalBattles": 12,
    "totalWins": 8,
    "createdAt": "2026-07-01T10:00:00.000Z"
  }
}
```

---

#### `update-profile` — 更新用户信息

| 项目 | 值 |
|------|-----|
| 鉴权 | JWT |
| 调用方 | 当前未使用 |

**请求:**
```json
POST /auth
{
  "action": "update-profile",
  "token": "eyJhbG...",
  "nickname": "新昵称",
  "avatarUrl": "https://..."
}
```

**响应:**
```json
{ "code": 200, "message": "更新成功" }
```

---

### 3.2 猫咪模块 — `/cats`

#### `nearby` — 附近猫咪

| 项目 | 值 |
|------|-----|
| 鉴权 | 无 |
| 坐标校验 | lat [-90, 90], lng [-180, 180] |
| 最大半径 | 50000m |
| 返回上限 | 50 条 |

**请求:**
```json
POST /cats
{
  "action": "nearby",
  "latitude": 31.23,
  "longitude": 121.47,
  "radius": 5000
}
```

**响应:**
```json
{
  "code": 200,
  "data": [
    {
      "id": "cat_mongodb_id",
      "name": "橘咪",
      "rarity": "rare",
      "cp": 180,
      "imageUrl": "cloud://xxx.jpg",
      "cardImageUrl": null,
      "location": { "type": "Point", "coordinates": [121.47, 31.23] },
      "capturedAt": "2026-07-01T10:00:00.000Z",
      "ownerNickname": "猫友8000"
    }
  ]
}
```

---

#### `my-cats` — 我的图鉴

| 项目 | 值 |
|------|-----|
| 鉴权 | JWT |
| 返回上限 | 100 条（按 capturedAt 降序） |
| 字段 | 返回完整猫文档（含 battleSkills, lifeSkills, featureVector 等） |

**请求:**
```json
POST /cats
{
  "action": "my-cats",
  "token": "eyJhbG..."
}
```

**响应:**
```json
{
  "code": 200,
  "data": [
    {
      "_id": "cat_mongodb_id",
      "userId": "user_xxx",
      "name": "橘咪",
      "rarity": "rare",
      "type": "agility",
      "baseHp": 90, "baseAtk": 70, "baseDef": 55, "baseSpd": 65, "baseCrit": 0.07,
      "cp": 180,
      "level": 1, "exp": 0,
      "battleSkills": [
        { "id": "bite", "name": "利齿撕咬", "type": "attack", "power": 55, "accuracy": 0.9, "minRarity": "common" }
      ],
      "lifeSkills": [
        { "id": "gold_nose", "name": "寻宝嗅觉", "effect": "goldBonus", "value": 0.15, "minRarity": "common" }
      ],
      "imageUrl": "cloud://xxx.jpg",
      "captureLocation": { "type": "Point", "coordinates": [121.47, 31.23] },
      "featureVector": [0.12, -0.34, ...],
      "totalBattles": 3, "totalWins": 2,
      "capturedAt": "2026-07-01T10:00:00.000Z"
    }
  ]
}
```

---

#### `capture` — 捕捉猫咪

| 项目 | 值 |
|------|-----|
| 鉴权 | JWT |
| 校验 | name 1-50字符, imageUrl 需 https:// 或 cloud://, 数字字段类型校验 |

**请求:**
```json
POST /cats
{
  "action": "capture",
  "token": "eyJhbG...",
  "catData": {
    "name": "橘咪",
    "rarity": "rare",
    "type": "agility",
    "baseHp": 90,
    "baseAtk": 70,
    "baseDef": 55,
    "baseSpd": 65,
    "baseCrit": 0.07,
    "cp": 180,
    "imageUrl": "cloud://env-id.xxx/cats/abc.jpg",
    "battleSkills": [{ "id": "bite", "name": "利齿撕咬", "type": "attack", "power": 55, "accuracy": 0.9, "minRarity": "common" }],
    "lifeSkills": [{ "id": "gold_nose", "name": "寻宝嗅觉", "effect": "goldBonus", "value": 0.15, "minRarity": "common" }],
    "captureLocation": { "latitude": 31.23, "longitude": 121.47 },
    "featureVector": [0.12, -0.34, ...]
  }
}
```

**响应:**
```json
{ "code": 200, "data": { "catId": "new_cat_mongodb_id" } }
```

**已校验字段:**

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| name | string | 否(1-50字符) | 猫咪名称 |
| rarity | string | 否 | common / rare / epic / legendary |
| type | string | 否 | agility / strength / endurance |
| baseHp | number | 否 | 基础生命值 |
| baseAtk | number | 否 | 基础攻击力 |
| baseDef | number | 否 | 基础防御力 |
| baseSpd | number | 否 | 基础速度 |
| baseCrit | number | 否 | 基础暴击率(小数) |
| cp | number | 否 | 综合战力 |
| imageUrl | string | 否(https:// 或 cloud://) | 猫咪照片 |
| cardImageUrl | string | 否 | 卡片图 |
| battleSkills | array | 否 | 战斗技能列表 |
| lifeSkills | array | 否 | 生活技能列表 |
| captureLocation | object | 是 | {latitude, longitude} |
| featureVector | array | 否 | 384维特征向量 |

---

#### `cat-detail` — 猫咪详情

| 项目 | 值 |
|------|-----|
| 鉴权 | JWT + 所有权校验 |
| 注意 | 仅返回属于当前用户的猫，否则 403 |

**请求:**
```json
POST /cats
{
  "action": "cat-detail",
  "token": "eyJhbG...",
  "catId": "cat_mongodb_id"
}
```

**响应:**
```json
// 成功 — 返回完整猫文档
{ "code": 200, "data": { "_id": "...", "name": "橘咪", ... } }

// 不存在
{ "code": 404, "message": "猫咪不存在" }

// 不是自己的
{ "code": 403, "message": "无权查看此猫咪" }
```

---

#### `cat-versions` — 猫脸版本列表

| 项目 | 值 |
|------|-----|
| 鉴权 | JWT |
| 调用方 | 当前未使用 |

**请求:**
```json
POST /cats
{
  "action": "cat-versions",
  "token": "eyJhbG...",
  "catFaceId": "face_uuid"
}
```

**响应:**
```json
{
  "code": 200,
  "data": {
    "catFaceId": "face_uuid",
    "sightingCount": 5,
    "cats": [
      { "id": "...", "name": "橘咪", "rarity": "rare", "cp": 180, "level": 1, "imageUrl": "...", "ownerId": "...", "capturedAt": "..." }
    ]
  }
}
```

---

### 3.3 识别模块 — `/recognition`

#### `match` — 猫脸匹配

| 项目 | 值 |
|------|-----|
| 鉴权 | 无 |
| IP 限流 | 15分钟窗口内最多 10 次 |
| SSRF 防护 | imageUrl 域名必须在白名单内(.cos.ap-shanghai.myqcloud.com, .tcloudbaseapp.com, .tcb.qcloud.la) |
| 相似度阈值 | 0.82 (余弦相似度) |
| 搜索半径 | 5000m |
| DINOv2 | 调用 ECS /extract 或 /extract_upload (超时25s→降级JS哈希) |
| JS 降级 | 144维感知哈希 (64 aHash + 48 颜色直方图 + 32 纹理) |

**请求:**
```json
POST /recognition
{
  "action": "match",
  "imageUrl": "https://xxx.tcb.qcloud.la/cats/abc.jpg",
  "latitude": 31.23,
  "longitude": 121.47
}
```

**响应 (匹配成功):**
```json
{
  "code": 200,
  "data": {
    "matched": true,
    "catFaceId": "face_uuid",
    "confidence": 0.89,
    "sightingCount": 5,
    "matchedCatName": "橘咪",
    "matchedCatImage": "cloud://...",
    "similarity": 0.89,
    "method": "dinov2"
  }
}
```

**响应 (未匹配):**
```json
{
  "code": 200,
  "data": {
    "matched": false,
    "confidence": 0.45,
    "nearbyChecked": 12,
    "method": "dinov2",
    "featureVector": [0.12, -0.34, ...],
    "featureDim": 384,
    "message": "最相似度 45.0%，未达阈值 82%"
  }
}
```

---

#### `register` — 注册猫脸特征

| 项目 | 值 |
|------|-----|
| 鉴权 | JWT |
| 调用方 | 当前未使用 |

**请求:**
```json
POST /recognition
{
  "action": "register",
  "token": "eyJhbG...",
  "imageUrl": "https://...",
  "featureVector": [0.12, -0.34, ...],
  "latitude": 31.23,
  "longitude": 121.47
}
```

**响应:**
```json
{ "code": 200, "data": { "catFaceId": "generated_uuid", "featureDim": 384 } }
```

---

#### `get-versions` — 查询猫脸的所有目击版本

| 项目 | 值 |
|------|-----|
| 鉴权 | JWT |
| 调用方 | 当前未使用 |

**响应格式同 cats/cat-versions。**

---

### 3.4 对战模块 — `/battle`

#### `submit` — 提交对战结果

| 项目 | 值 |
|------|-----|
| 鉴权 | JWT |
| 校验 | SHA256 哈希验证 (attackerId\|defenderId\|rounds\|seed\|won) |
| ⚠️ 状态 | 云函数代码已写，待部署 |

**请求:**
```json
POST /battle
{
  "action": "submit",
  "token": "eyJhbG...",
  "attackerId": "cat_mongodb_id",
  "defenderId": "cat_mongodb_id",
  "won": true,
  "rounds": 3,
  "seed": 1234,
  "battleHash": "a1b2c3d4e5f6a7b8"
}
```

**响应:**
```json
{ "code": 200, "message": "ok" }
```

---

#### `history` — 对战历史

| 项目 | 值 |
|------|-----|
| 鉴权 | JWT |
| 返回上限 | 50 条（按时间降序） |

**请求:**
```json
POST /battle
{
  "action": "history",
  "token": "eyJhbG..."
}
```

**响应:**
```json
{
  "code": 200,
  "data": [
    {
      "attackerId": "cat_xxx",
      "defenderId": "cat_yyy",
      "userId": "user_xxx",
      "won": true,
      "rounds": 3,
      "createdAt": "2026-07-01T12:00:00.000Z"
    }
  ]
}
```

---

### 3.5 微信原生 API（非 HTTP）

| API | 用途 | 调用位置 |
|-----|------|----------|
| `wx.cloud.uploadFile({cloudPath, filePath})` | 上传照片到 CloudBase 云存储 | capture.js |
| `wx.cloud.getTempFileURL({fileList})` | cloud:// fileID → 临时 HTTPS URL (2h有效) | capture.js, image.js |
| `wx.login()` | 获取微信临时 code | auth.js |
| `wx.getLocation({type:'gcj02'})` | 获取 GPS (国测局坐标) | explore.js, capture.js |
| `wx.createCameraContext().takePhoto({quality:'high'})` | 拍照 | capture.js |

---

## 四、数据模型

### 猫咪 (cats 集合)

```typescript
interface Cat {
  _id: string;              // MongoDB ObjectId
  userId: string;           // 所属用户 ID
  name: string;             // 名称 (1-50字符)
  rarity: 'common' | 'rare' | 'epic' | 'legendary';
  type: 'agility' | 'strength' | 'endurance';
  baseHp: number;
  baseAtk: number;
  baseDef: number;
  baseSpd: number;
  baseCrit: number;         // 0.0-0.15
  cp: number;               // 综合战力
  level: number;            // 等级 (默认1)
  exp: number;              // 经验值
  battleSkills: BattleSkill[];
  lifeSkills: LifeSkill[];
  imageUrl: string;         // cloud:// 或 https://
  cardImageUrl?: string;
  captureLocation: GeoPoint; // { type: "Point", coordinates: [lng, lat] }
  featureVector?: number[];  // 384-dim (DINOv2) 或 144-dim (JS降级)
  catFaceId?: string;        // 猫脸唯一ID
  totalBattles: number;
  totalWins: number;
  capturedAt: Date;
}

interface BattleSkill {
  id: string;       // 技能ID (scratch, bite, ...)
  name: string;     // 中文名
  type: 'attack' | 'defense' | 'control';
  power: number;    // 威力 (0-100)
  accuracy: number; // 命中率 (0.0-1.0)
  description: string;
  minRarity: string; // 最低稀有度要求
  // 可选 — 防御/控制效果
  defMod?: number;
  atkMod?: number;
  spdMod?: number;
  modDuration?: number;
  healRatio?: number;
  selfDamageRatio?: number;
}

interface LifeSkill {
  id: string;
  name: string;
  effect: string;   // goldBonus, itemDrop, expBoost, ...
  value: number;
  description: string;
  minRarity: string;
}
```

### 用户 (users 集合)

```typescript
interface User {
  _id: string;
  phone?: string;
  wechatOpenId?: string;
  nickname: string;
  avatarUrl?: string;
  totalCatches: number;
  totalBattles: number;
  totalWins: number;
  tokenVersion: number;  // token 刷新时递增，旧 token 自动失效
  createdAt: Date;
  updatedAt: Date;
}
```

---

## 五、页面 → API 调用关系

```
pages/index/index.js
    └── auth.isLoggedIn() → 本地 token 检查

pages/login/login.js
    ├── auth.sendSms(phone)        → /auth (send-sms)
    ├── auth.login(phone, code)    → /auth (login)
    └── auth.wechatLogin()         → wx.login() → /auth (wechat-login)

pages/explore/explore.js
    ├── wx.getLocation()           → GPS
    ├── api.getNearbyCats()        → /cats (nearby)
    └── image.getTempUrls()        → wx.cloud.getTempFileURL

pages/capture/capture.js
    ├── wx.createCameraContext()   → 拍照
    ├── wx.cloud.uploadFile()      → 云存储
    ├── wx.cloud.getTempFileURL()  → 临时链接
    ├── wx.getLocation()           → GPS
    ├── api.matchCatFace()         → /recognition (match)
    ├── generator.generateCat()    → 本地生成
    └── api.captureCat()           → /cats (capture)

pages/collection/collection.js
    ├── api.getMyCats()            → /cats (my-cats)
    └── image.getTempUrls()        → wx.cloud.getTempFileURL

pages/card/card.js
    ├── api.getCatDetail(id)       → /cats (cat-detail)
    ├── api.getMyCats()            → /cats (my-cats) [回退]
    ├── app.globalData._viewingCat → explore 页暂存 [回退2]
    ├── URL query params           → 分享链接 [回退3]
    └── image.getTempUrl()         → wx.cloud.getTempFileURL

pages/battle/battle.js
    ├── api.getMyCats()            → /cats (my-cats)
    ├── generator.generateCat()    → 本地生成野猫
    └── api.submitBattle()         → /battle (submit)

pages/profile/profile.js
    ├── api.getMyCats()            → /cats (my-cats)
    ├── api.getBattleHistory()     → /battle (history)
    └── auth.logout()              → 清除本地 token
```

---

## 六、部署状态

| 云函数 | 状态 | 最近部署 |
|--------|------|----------|
| auth | ✅ 已部署 | 2026-06-30 |
| cats | ✅ 已部署 | 2026-07-01 (支持 cloud:// + cp字段) |
| recognition | ✅ 已部署 | 2026-06-30 |
| battle | ❌ 未部署 | — |

| 依赖服务 | 状态 |
|-----------|------|
| ECS DINOv2 服务器 (36.151.145.33:8765) | ⚠️ 未确认 |
| 微信小程序 AppID | ❌ YOUR_APPID |
| WECHAT_APP_ID / WECHAT_APP_SECRET | ❌ 未配置 |

---

## 七、前端开放 API（utils 层 → 页面层）

### `utils/api.js`

```javascript
api.sendSms(phone)              → Promise<{code, message, devCode?}>
api.login(phone, code)           → Promise<{code, data: {token, refreshToken, user}}>
api.wechatLogin(wxCode)          → Promise<{code, data: {token, refreshToken, user}}>
api.getProfile()                 → Promise<{code, data: User}>
api.refreshToken(refreshToken)   → Promise<{code, data: {token, refreshToken}}>
api.getNearbyCats(lat, lng, rad) → Promise<{code, data: CatSummary[]}>
api.getMyCats()                  → Promise<{code, data: Cat[]}>
api.captureCat(catData)          → Promise<{code, data: {catId}}>
api.getCatDetail(catId)          → Promise<{code, data: Cat}>
api.matchCatFace(url, lat, lng)  → Promise<{code, data: MatchResult}>
api.getBattleHistory()           → Promise<{code, data: BattleLog[]}>
api.submitBattle(data)           → Promise<{code, message}>
api.uploadImage(filePath)        → Promise<fileID>
```

### `utils/auth.js`

```javascript
auth.login(phone, code)      → Promise<{ok, user?, error?}>
auth.wechatLogin()            → Promise<{ok, user?, error?}>
auth.sendSms(phone)           → Promise<{ok, devCode?, error?}>
auth.logout()                 → void
auth.isLoggedIn()             → boolean
auth.getUser()                → User | null
```

### `utils/generator.js`

```javascript
generator.generateCat(options?) → Cat {
  id, name, rarity, type,
  baseHp, baseAtk, baseDef, baseSpd, baseCrit, cp,
  level, exp,
  battleSkills: BattleSkill[],
  lifeSkills: LifeSkill[],
  imageUrl, cardImageUrl, captureLocation, capturedAt
}
```

### `utils/image.js`

```javascript
image.getTempUrls(fileIDs[])  → Promise<{[fileID]: tempUrl}>
image.getTempUrl(fileID)       → Promise<tempUrl>
image.clearCache()             → void
```

### `utils/sha256.js`

```javascript
sha256(str) → hexString (64 chars, 小写)
```

### 页面路由

| 路径 | 参数 | 类型 |
|------|------|------|
| `/pages/index/index` | — | 入口页 |
| `/pages/login/login` | — | 登录页 |
| `/pages/explore/explore` | — | Tab 页 |
| `/pages/capture/capture` | — | Tab 页 |
| `/pages/collection/collection` | — | Tab 页 |
| `/pages/card/card` | `?id=<catId>&name=<>&rarity=<>&cp=<>` | 卡片详情 |
| `/pages/battle/battle` | `?id=<catId>` | 对战 |
| `/pages/profile/profile` | — | Tab 页 |
