import 'package:flutter/material.dart';

class AppConfig {
  const AppConfig({
    required this.environment,
    required this.themeColor,
    required this.apiBaseUrl,
    required this.authApiBaseUrl,
    required this.amapApiKey,
    required this.amapAndroidKey,
    required this.cosBucket,
    required this.cosRegion,
    required this.wechatAppId,
    required this.wechatUniversalLink,
    this.recognitionEndpoint = '',
  });

  final Environment environment;
  final Color themeColor;
  final String apiBaseUrl;
  final String authApiBaseUrl;
  final String amapApiKey;
  final String amapAndroidKey;
  final String cosBucket;
  final String cosRegion;
  final String wechatAppId;
  final String wechatUniversalLink;
  final String recognitionEndpoint; // 猫脸识别独立服务器 (空=用CloudBase)

  factory AppConfig.dev() => AppConfig(
        environment: Environment.dev,
        themeColor: const Color(0xFFE94560),
        apiBaseUrl: 'https://kittykitty-d0go1pcqbe5e83de6.service.tcloudbase.com',
        authApiBaseUrl: 'https://kittykitty-d0go1pcqbe5e83de6.api.tcloudbasegateway.com',
        amapApiKey: 'YOUR_AMAP_IOS_KEY',
        amapAndroidKey: 'YOUR_AMAP_ANDROID_KEY',
        cosBucket: '6b69-kittykitty-d0go1pcqbe5e83de6-1318430011',
        cosRegion: 'ap-shanghai',
        wechatAppId: 'YOUR_WECHAT_APP_ID',
        wechatUniversalLink: 'https://dev.kittykitty.app/wechat/',
    recognitionEndpoint: 'http://127.0.0.1:8765', // 本地测试；生产改为实际服务器地址
      );

  factory AppConfig.staging() => AppConfig(
        environment: Environment.staging,
        themeColor: const Color(0xFFFF6B35),
        // TODO: 创建独立 staging CloudBase 环境后替换
        apiBaseUrl: 'https://kittykitty-staging-xxxxxxxx.service.tcloudbase.com',
        authApiBaseUrl: 'https://kittykitty-staging-xxxxxxxx.api.tcloudbasegateway.com',
        amapApiKey: 'YOUR_AMAP_IOS_KEY',
        amapAndroidKey: 'YOUR_AMAP_ANDROID_KEY',
        cosBucket: 'kittykitty-staging',
        cosRegion: 'ap-guangzhou',
        wechatAppId: 'YOUR_WECHAT_APP_ID',
        wechatUniversalLink: 'https://staging.kittykitty.app/wechat/',
    recognitionEndpoint: '', // staging: 部署后填入
      );

  factory AppConfig.prod() => AppConfig(
        environment: Environment.prod,
        themeColor: const Color(0xFFFFD700),
        // TODO: 创建独立 prod CloudBase 环境后替换
        apiBaseUrl: 'https://kittykitty-prod-xxxxxxxx.service.tcloudbase.com',
        authApiBaseUrl: 'https://kittykitty-prod-xxxxxxxx.api.tcloudbasegateway.com',
        amapApiKey: 'YOUR_AMAP_IOS_KEY',
        amapAndroidKey: 'YOUR_AMAP_ANDROID_KEY',
        cosBucket: 'kittykitty-prod',
        cosRegion: 'ap-guangzhou',
        wechatAppId: 'YOUR_WECHAT_APP_ID',
        wechatUniversalLink: 'https://kittykitty.app/wechat/',
    recognitionEndpoint: '', // production: 部署后填入
      );
}

enum Environment { dev, staging, prod }

extension EnvironmentExt on Environment {
  bool get isDev => this == Environment.dev;
  bool get isProd => this == Environment.prod;
  String get label => name.toUpperCase();
}
