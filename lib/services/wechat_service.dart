import 'api_client.dart';
import 'auth_service.dart';

/// 微信登录服务 — 封装 fluwx SDK
///
/// 真机构建步骤:
/// 1. 微信开放平台注册应用，获取 AppID
/// 2. iOS: 配置 Universal Link + URL Scheme
/// 3. Android: 配置应用签名 + 回调 Activity
/// 4. 在 AppConfig 填入 wechatAppId 和 wechatUniversalLink
/// 5. 调用 WechatService.init() 初始化
class WechatService {
  WechatService({required this.authService});

  final AuthService authService;

  /// 是否已初始化
  bool _initialized = false;

  /// 初始化微信 SDK（真机调用前需确保 fluwx 已正确配置原生端）
  Future<void> init({
    required String appId,
    required String universalLink,
  }) async {
    if (_initialized) return;
    // TODO: 真机取消注释
    // fluwx.registerWxApi(appId: appId, universalLink: universalLink);
    _initialized = true;
  }

  /// 发起微信授权登录
  /// 真机返回 code → 调用 completeLogin(code) 换取 token
  Future<WechatLoginResult> login() async {
    if (!_initialized) {
      return const WechatLoginResult(
        success: false,
        error: '微信 SDK 未初始化，请在真机运行',
      );
    }

    // TODO: 真机取消注释
    // final result = await fluwx.sendWeChatAuth(
    //   scope: 'snsapi_userinfo',
    //   state: 'kittykitty_login',
    // ).timeout(const Duration(seconds: 30));
    //
    // if (result is fluwx.WeChatAuthResponse) {
    //   return WechatLoginResult(
    //     success: true,
    //     code: result.code ?? '',
    //     state: result.state ?? '',
    //   );
    // }

    return const WechatLoginResult(
      success: false,
      error: '微信登录需在真机运行',
    );
  }

  /// 用微信 code 换后端 token
  Future<ApiResponse<LoginResult>> completeLogin(String code) async {
    return authService.wechatLogin(code);
  }
}

class WechatLoginResult {
  final bool success;
  final String code;
  final String state;
  final String? error;

  const WechatLoginResult({
    required this.success,
    this.code = '',
    this.state = '',
    this.error,
  });
}
