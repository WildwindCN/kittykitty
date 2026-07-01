# KittyKitty 小程序 — UI/前端交接文档

> 写给接手的 UI/前端同学 | 2026-07-01

---

## 一、项目概况

KittyKitty 是一款猫咪收集小程序（类似 Pokémon GO）。用户拍摄现实猫咪 → AI 识别猫脸 → 随机生成属性/技能 → 收藏卡片 → 自动对战。

```
当前状态: 所有页面功能逻辑完成，可直接在此基础上做 UI 优化
代码分支: miniprogram
项目路径: miniprogram/
```

---

## 二、目录结构

```
miniprogram/
├── app.js              ← 入口：CloudBase初始化 + Token过期校验
├── app.json            ← 全局配置：路由/TabBar/权限
├── app.wxss            ← 全局样式：稀有度颜色/卡片/按钮/输入框/属性条
│
├── utils/              ← 🔑 你的工具箱（下面详细展开）
│   ├── api.js          ← HTTP请求封装 + Token自动刷新
│   ├── auth.js         ← 登录/登出/获取用户
│   ├── generator.js    ← 猫咪随机生成器
│   ├── image.js        ← 图片加载(fileID转换+缓存)
│   └── sha256.js       ← SHA256加密(对战校验用)
│
├── pages/
│   ├── index/          ← 启动页(自动跳转)
│   ├── login/          ← 登录页(SMS + 微信)
│   ├── explore/        ← 探索页(附近猫咪列表)
│   ├── capture/        ← 拍摄页(相机+上传+识别)
│   ├── collection/     ← 图鉴页(我的猫咪网格)
│   ├── card/           ← 猫咪详情卡片
│   ├── battle/         ← 自动对战动画
│   └── profile/        ← 个人中心
│
└── images/             ← Tab栏图标
```

---

## 三、工具箱：你可以直接调用的 API

每个页面文件顶部 `require('../../utils/xxx')` 引入即可。

### 3.1 api.js — HTTP 请求（自动处理 Token）

```javascript
const api = require('../../utils/api');

// 所有方法返回 Promise<{code, data, message}>，已自动携带 Token
// Token 过期时自动刷新，无需手动处理

// --- 认证 ---
await api.sendSms(phone);
await api.login(phone, code);
await api.wechatLogin(wxCode);

// --- 猫咪 ---
await api.getNearbyCats(lat, lng, radius);   // 附近猫咪
await api.getMyCats();                       // 我的图鉴
await api.captureCat(catData);               // 捕捉入库
await api.getCatDetail(catId);               // 猫咪详情(仅自己的)

// --- 识别 ---
await api.matchCatFace(imageUrl, lat, lng);  // 猫脸匹配

// --- 对战 ---
await api.getBattleHistory();                // 对战历史
await api.submitBattle({ attackerId, defenderId, won, rounds, seed, battleHash });

// --- 上传 ---
await api.uploadImage(filePath);             // 上传到云存储，返回 cloud:// fileID
```

### 3.2 auth.js — 用户认证

```javascript
const auth = require('../../utils/auth');

const result = await auth.login(phone, code);     // {ok, user?, error?}
const result = await auth.wechatLogin();           // {ok, user?, error?}
const result = await auth.sendSms(phone);          // {ok, devCode?, error?}

auth.logout();           // 清除登录态
auth.isLoggedIn();       // boolean
auth.getUser();          // {id, phone, nickname, avatarUrl, ...}
```

### 3.3 generator.js — 猫咪生成器

```javascript
const gen = require('../../utils/generator');

const cat = gen.generateCat({
  id: 'cat_xxx',           // 可选，不传自动生成
  name: '橘咪',            // 可选，不传随机名
  rarity: 'epic',          // 可选，不传按权重随机(普通60%/稀有25%/史诗12%/传说3%)
  type: 'agility',         // 可选，agility/strength/endurance
  imageUrl: 'cloud://xxx',
  captureLocation: { latitude: 31.23, longitude: 121.47 },
});

// cat 对象完整结构见下方"数据模型"
```

### 3.4 image.js — 图片加载

```javascript
const image = require('../../utils/image');

// cloud:// fileID 转 HTTPS 临时链接(90分钟缓存)
const url = await image.getTempUrl('cloud://xxx.jpg');

// 批量转换
const map = await image.getTempUrls(['cloud://a.jpg', 'cloud://b.jpg']);
```

---

## 四、数据模型

### Cat（猫咪完整对象）

```javascript
{
  _id: "abc123",                    // MongoDB ID
  userId: "user_xxx",
  name: "橘咪",
  rarity: "rare",                   // common | rare | epic | legendary
  type: "agility",                  // agility | strength | endurance
  baseHp: 90,  baseAtk: 70,
  baseDef: 55, baseSpd: 65,
  baseCrit: 0.07,                   // 0.00 ~ 0.15
  cp: 180,                          // 综合战力
  level: 1, exp: 0,
  battleSkills: [
    {
      id: "bite",
      name: "利齿撕咬",
      type: "attack",               // attack | defense | control
      power: 55,                    // 0-100，威力
      accuracy: 0.90,               // 0-1，命中率
      description: "锋利的牙齿造成较高伤害",
      minRarity: "rare"             // 最低稀有度要求
      // 防御/控制技额外字段：
      // defMod: 0.4,  atkMod: -0.25,  spdMod: -0.3
      // modDuration: 2,  healRatio: 0.15
    }
  ],
  lifeSkills: [
    {
      id: "gold_nose",
      name: "寻宝嗅觉",
      effect: "goldBonus",          // 当前仅存储，未消费
      value: 0.15,
      description: "探索时额外获得15%金币",
      minRarity: "common"
    }
  ],
  imageUrl: "cloud://xxx.jpg",      // 永久链接，展示时需通过 image.js 转临时URL
  cardImageUrl: null,
  captureLocation: { type: "Point", coordinates: [121.47, 31.23] },
  featureVector: [0.12, -0.34, ...], // 384维(DINOv2) 或 144维(降级)
  totalBattles: 3, totalWins: 2,
  capturedAt: "2026-07-01T10:00:00.000Z"
}
```

### User（用户对象）

```javascript
{
  id: "user_xxx",
  phone: "138****8000",
  nickname: "猫友8000",
  avatarUrl: null,
  totalCatches: 5,
  totalBattles: 12,
  totalWins: 8
}
```

---

## 五、开发模式：如何写一个新页面

以「某个需要加载猫咪数据的页面」为例：

```javascript
const api = require('../../utils/api');
const image = require('../../utils/image');
const auth = require('../../utils/auth');

Page({
  data: {
    cats: [],
    loading: false,
  },

  onShow() {
    this.loadData();
  },

  async loadData() {
    this.setData({ loading: true });
    try {
      const res = await api.getMyCats();
      if (res.code === 200 && res.data) {
        const cats = res.data;

        // 🔑 关键：图片链接必须转换！cloud:// → HTTPS临时URL
        const fileIDs = cats.map(c => c.imageUrl).filter(Boolean);
        const urlMap = await image.getTempUrls(fileIDs);
        const catsWithUrls = cats.map(c => ({
          ...c,
          imageUrl: urlMap[c.imageUrl] || c.imageUrl,
        }));

        this.setData({ cats: catsWithUrls, loading: false });
      }
    } catch (_) {
      this.setData({ loading: false });
    }
  },

  // 检查登录
  checkAuth() {
    if (!auth.isLoggedIn()) {
      wx.reLaunch({ url: '/pages/login/login' });
      return false;
    }
    return true;
  },
});
```

### 页面 JSON 配置

```json
{
  "usingComponents": {},
  "navigationBarTitleText": "页面标题",
  "enablePullDownRefresh": true   // 需要下拉刷新时加上
}
```

如需下拉刷新，在 JS 中添加：
```javascript
onPullDownRefresh() {
  this.loadData().then(() => wx.stopPullDownRefresh());
},
```

---

## 六、现有页面速览

| 页面 | 职责 | 你主要关心 |
|------|------|-----------|
| `index` | 启动页，检测登录态自动跳转 | WXML/WXSS 可改为品牌页 |
| `login` | SMS + 微信双通道登录 | **UI 重设计重点**：品牌logo、输入框样式、微信按钮 |
| `explore` | 附近猫咪列表 | 列表卡片样式、空状态插画、位置提示 |
| `capture` | 相机 + AR 瞄准框 + 处理进度 | 快门按钮、AR 框线、进度动画 |
| `collection` | 2列网格图鉴 | 卡片网格、稀有度边框、空图鉴引导 |
| `card` | 详情卡片：属性条+技能列表+对战按钮 | **UI 重设计重点**：类似宝可梦卡牌 |
| `battle` | VS 对阵 + HP 条 + 回合日志动画 | 对战动画、HP 条颜色过渡、结果页 |
| `profile` | 头像+统计数+最强猫咪 | 个人信息卡片、数据可视化 |

---

## 七、全局样式速查

`app.wxss` 中已定义的类，可直接复用：

```css
/* 稀有度文字颜色 */
.rarity-common { color: #9E9E9E; }     /* 灰 */
.rarity-rare { color: #4FC3F7; }        /* 蓝 */
.rarity-epic { color: #CE93D8; }        /* 紫 */
.rarity-legendary { color: #FFD700; }   /* 金 */

/* 稀有度背景（半透明） */
.bg-rarity-common / .bg-rarity-rare / .bg-rarity-epic / .bg-rarity-legendary

/* 通用卡片 .card { 圆角24rpx, 半透明背景 } */
/* 主按钮 .btn-primary { 渐变红, 16rpx圆角 } */
/* 幽灵按钮 .btn-ghost { 透明+白边框 } */
/* 输入框 .input-field { 半透明背景, 16rpx圆角 } */
/* 属性条 .stat-bar + .stat-bar-inner { 12rpx高, 6rpx圆角 } */
```

页面背景色 `#0F0F23`（深蓝黑），全局文字色 `#ffffff`。

---

## 八、路由一览

| 路径 | 入口方式 | 参数 |
|------|---------|------|
| `/pages/index/index` | 小程序首页 | — |
| `/pages/login/login` | `wx.reLaunch` | — |
| `/pages/explore/explore` | Tab 栏 | — |
| `/pages/capture/capture` | Tab 栏 | — |
| `/pages/collection/collection` | Tab 栏 | — |
| `/pages/card/card` | `wx.navigateTo` | `?id=xxx&name=xxx&rarity=xxx&cp=xxx` |
| `/pages/battle/battle` | `wx.navigateTo` | `?id=xxx` |
| `/pages/profile/profile` | Tab 栏 | — |

**注意**: Tab 页之间用 `wx.switchTab`，非 Tab 页用 `wx.navigateTo`，登录跳转用 `wx.reLaunch`。

---

## 九、注意事项 & 已知限制

| 事项 | 说明 |
|------|------|
| **图片显示必须转 URL** | 数据库中存的是 `cloud://xxx`（永久），WXML 的 `<image>` 需要 HTTPS URL，务必通过 `image.getTempUrl()` 转换。直接写 `src="{{item.imageUrl}}"` 会显示空白。 |
| **Token 自动刷新** | 15 分钟过期后自动静默刷新，你无需处理 401 |
| **生活技能未消费** | `lifeSkills` 中的 effect 值（金币加成等）已存储在数据库，但前端暂未使用 |
| **API 响应格式** | 统一 `{code: 200, data: ...}` 或 `{code: 4xx/5xx, message: "..."}` |
| **对战哈希** | 提交战斗结果需要 SHA256 哈希校验，`battle.js` 已实现，你不需要改 |
| **DINOv2 识别** | 猫脸特征提取由后端 ECS 完成，失败时自动降级为 JS 本地哈希 |
| **个人主体小程序** | 不能用微信支付、获取手机号等高级能力，但对当前功能无影响 |

---

## 十、微信开发者工具入门

1. 下载：https://developers.weixin.qq.com/miniprogram/dev/devtools/download.html
2. 打开 → 导入项目 → 选择 `D:\workspace\kittykitty\miniprogram`
3. AppID 填入 (需要注册小程序获取)
4. 开发模式选「小程序」
5. 编辑器左侧是目录树，中间是代码编辑器，右侧是模拟器
6. ` Ctrl+S` 保存自动刷新模拟器
7. 调试器在底部，「Console」看 log，「Network」看请求

---

## 十一、待办

| 优先级 | 任务 | 负责人 |
|--------|------|--------|
| P0 | 注册微信小程序 AppID | 账号管理员 |
| P0 | 配置服务器域名白名单 | 账号管理员 |
| P1 | UI 重设计：登录页 | UI/前端 |
| P1 | UI 重设计：猫咪卡片 | UI/前端 |
| P1 | 卡片渲染：改纯展示为宠物卡牌风格 | UI/前端 |
| P2 | 空白状态插画 | UI/前端 |
| P2 | 对战动画优化 | UI/前端 |
| P2 | 生活技能效果落地 | 前端 |
| P3 | 战斗技能平衡调整 | 策划+前端 |
