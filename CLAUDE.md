# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## CloudBase 后端

本项目使用腾讯云 CloudBase 作为后端。MCP 已配置 (`.mcp.json`)，`@cloudbase/cloudbase-mcp` 提供 `envQuery`、`manageFunctions`、`callCloudApi` 等工具。

- **Flutter 端** (= Native App)：必须通过 **HTTP API** 调用 CloudBase（不支持 SDK）
- **云函数**：位于 `cloudfunctions/` 目录，直接部署
- **规则文件**：`rules/` 目录包含完整开发规范，Native App 优先读 `rules/http-api/rule.md`
- **控制台**：https://tcb.cloud.tencent.com/dev?envId=${envId}#/scf
- **生产 URL**：https://kittykitty-d0go1pcqbe5e83de6-1318430011.tcloudbaseapp.com/kittykitty/
- **API 域名**：https://kittykitty-d0go1pcqbe5e83de6.service.tcloudbase.com

### 常用 MCP 操作
```
envQuery(action=info)                        → 查环境信息
manageFunctions(action="updateFunctionCode") → 部署云函数
callCloudApi                               → 调任意云 API
```

## 项目概述

一款类似 Pokémon GO 的移动端猫咪收集游戏。核心玩法：现实世界拍摄猫咪 → AI 抠图 + 个体识别 → 随机生成属性/技能 → 生成收藏卡片 → 地图探索 → 自动对战。

目标平台：Android + iOS。

## 完整功能清单

1. **AR 相机取景** — 实时预览，叠加瞄准/捕捉 UI
2. **猫咪检测与抠图** — 识别画面中猫咪，像素级分割去背景
3. **猫脸个体识别** — 判断是否为同一只真实猫咪，支持浏览不同玩家拍摄的同一只猫的多个版本
4. **猫咪属性随机生成** — 名字、稀有度、HP/ATK/DEF/SPD/CRIT、战斗技能、生活技能
5. **收藏卡片系统** — 抠图 + 属性合成卡片，本地持久化，可分享
6. **地图定位与猫咪分布** — GPS 地图，标记所有玩家发现猫咪的位置，显示附近猫咪热度
7. **自动对战系统** — 发现新猫咪后可选已收集猫咪与之对战，回合制全自动
8. **等级与养成** — 战斗胜利获经验升级，属性成长，传说/史诗可进化
9. **用户系统** — 手机号 + 短信验证码登录
10. **云端同步** — 猫咪数据、玩家数据、地图 POI 全部云端存储

## 技术选型（已调研确定）

### 移动端框架：Flutter

- 自渲染引擎 Impeller，60fps 动画保障，适合游戏化 UI
- `google_maps_flutter`、`camera` 插件成熟
- `tflite_flutter` + `google_ml_kit` 覆盖端侧 ML
- AR 通过 Platform Channel 桥接 ARKit/ARCore
- Dart 单代码库双端复用率 90%+
- 风险：复杂 AR 场景下 Platform Channel 可能有延迟，需实测

### 猫咪检测与抠图（双平台差异化）

| 平台 | 方案 | 理由 |
|------|------|------|
| **iOS** | Vision Framework (VNGenerateForegroundInstanceMask) | Neural Engine 原生加速、零模型下载、边缘细腻 |
| **Android** | YOLOv8n-seg + NCNN Vulkan | 640x640 mask 精度高，~13MB，高端芯片 NPU 推理 200+ FPS |

- Android 需做设备分级：高端 NPU 跑 640，低端降分辨率或切 MediaPipe DeepLab 兜底
- MediaPipe 257x257 分辨率不够用，仅作低端兜底

### 猫脸个体识别：两步走

**第一阶段（上线）**：云端方案。AvitoTech/SigLIP-Base 预训练模型生成 512 维特征向量，云端 Faiss/ANNOY 近邻检索，前端让玩家确认匹配。

**第二阶段（优化）**：用积累数据微调 MobileNetV3-Small/TinyViT-5M 蒸馏到设备端，端侧提取特征，云端只做索引匹配。

- 猫鼻纹方案不可行（角度苛刻、遮挡严重）
- Petnow CatFaceNet 已在产品中验证猫脸识别可行（Rank-1 99.96%）

### 地图：高德地图（纯中国大陆市场）

- 高德地图 SDK，中国定位精度最优
- 社区 fork `gmm_amap_flutter_map` v3.1.4（官方包已停更）
- 自定义地图样式（游戏化暗色主题）
- 不做全球版，无需双通道

### 后端：CloudBase (TCB) 验证期 → ECS + PostgreSQL 规模化

- **验证期**：腾讯云 CloudBase — 3000 资源点/月免费，微信生态原生支持（LeanCloud 2027 停服已排除）
- **规模化期**：阿里云 ECS + PostgreSQL 16 + PostGIS 3 + Redis 7
- 短信：阿里云「短信认证」(个人开发者版)，¥0.045/条，无需企业资质
- 微信登录：`fluwx` v4.6.3（OpenFlutter 维护），中国市场用户转化率最高的登录方式
- 推送：极光推送 JPush (`jpush_flutter`)，份额第一 34.7%
- 存储：腾讯云 COS + 数据万象 (10TB/月免费图片处理)

## 游戏系统设计

### 核心属性

| 属性 | 说明 |
|------|------|
| HP | 生命值，归零即败 |
| ATK | 基础伤害输出 |
| DEF | 减伤系数 |
| SPD | 决定出手顺序 |
| CRIT | 天生暴击率 0~15% |
| CP | 综合战力 = (HP×0.4 + ATK×1.2 + DEF×0.8 + SPD×0.6) × 稀有度倍率 |

### 稀有度

| 稀有度 | 捕捉概率 | CP 倍率 | 色标 |
|--------|----------|---------|------|
| 普通 | 60% | ×1.0 | 灰 |
| 稀有 | 25% | ×1.3 | 蓝 |
| 史诗 | 12% | ×1.7 | 紫 |
| 传说 | 3% | ×2.2 | 金 |

### 技能系统

- 每只猫随机 1~3 个战斗技能 + 1~2 个生活技能
- 战斗技能池 20 个（攻击 12 / 防御 4 / 控制 4），稀有度加权抽取
- 生活技能池 10 个，影响收集收益（如金币加成、道具掉落）
- 技能在捕捉时随机生成，同一只真实猫咪不同玩家可获得不同技能

### 等级系统

- 经验公式：`EXP_to_Next = 50 × Lv × (1 + 0.1 × Lv)`
- 每级成长：HP+3%、ATK+2.5%、DEF+2%、SPD+1.5%
- 封顶 Lv.50（传说 Lv.25，但属性曲线更高）
- 史诗/传说 Lv.20 触发进化，外观变化 + 解锁第 4 战斗技能

### 自动对战（回合制）

- 按 SPD 降序出手，单局上限 10 回合
- 伤害 = ATK × 技能倍率 × (1 - DEF/(DEF+200)) × (1±10%随机浮动)
- 暴击 ×1.6，闪避率固定 5%/回合
- 属性克制（敏捷→力量→耐力→敏捷）：克制 +20% 伤害
- 单局约 30~90 秒

## 架构概览

```
lib/
├── main.dart                  # 入口
├── app/                       # App 配置、路由、主题
├── features/
│   ├── camera/                # 相机取景 + AR 叠加
│   ├── detection/             # 猫咪检测 + 分割 (Platform Channel → Native ML)
│   ├── recognition/           # 猫脸个体识别
│   ├── card/                  # 收藏卡片生成与展示
│   ├── map/                   # 高德地图 + 猫咪分布
│   ├── battle/                # 自动对战（UI + WebSocket）
│   ├── auth/                  # 手机号+微信登录
│   └── profile/               # 玩家个人主页
├── game/                      # 游戏逻辑（纯 Dart，平台无关）
│   ├── models/                # 数据模型（Cat, Card, Player, Battle...）
│   ├── generator/             # 属性/技能随机生成
│   ├── battle_engine/         # 对战引擎（伤害计算、回合判定）
│   └── leveling/              # 经验曲线与升级逻辑
├── services/                  # CloudBase API、COS 上传、JPush
└── widgets/                   # 共享 UI 组件
```

Platform Channel 桥接层：
- iOS: Swift → Vision / ARKit
- Android: Kotlin → NCNN + YOLOv8 / ARCore

后端：CloudBase 云函数 (Node.js) → 规模化迁至 ECS + Go + PostgreSQL + PostGIS

## 开发约定

- 所有交流使用中文
- 游戏逻辑集中在 `lib/game/`，纯 Dart 可测试
- 设备端 ML 优先，云端仅做索引匹配和持久化
- UI 参考 Pokémon GO 卡片风格和 AR 交互模式
- 先做全球版（Mapbox + Firebase Auth），中国市场后续适配
