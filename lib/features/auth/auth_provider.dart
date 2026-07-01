import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_config.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/wechat_service.dart';

// 重新导出 UserInfo 方便使用
export '../../services/auth_service.dart' show UserInfo;

/// API 客户端单例
final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  return ApiClient(baseUrl: config.apiBaseUrl);
});

/// Auth 服务
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(apiClient: ref.watch(apiClientProvider));
});

/// 微信登录服务
final wechatServiceProvider = Provider<WechatService>((ref) {
  return WechatService(authService: ref.watch(authServiceProvider));
});

/// App 配置（从 main.dart 通过 dart-define 注入）
final appConfigProvider = Provider<AppConfig>((ref) {
  // 从 main.dart 的 flavor 获取，默认为 dev
  const env = String.fromEnvironment('ENVIRONMENT', defaultValue: 'dev');
  return switch (env) {
    'prod' => AppConfig.prod(),
    'staging' => AppConfig.staging(),
    _ => AppConfig.dev(),
  };
});

/// 认证状态
enum AuthStatus { unknown, authenticated, unauthenticated }

/// 认证状态管理
class AuthState {
  final AuthStatus status;
  final UserInfo? user;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserInfo? user,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Auth Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._authService) : super(const AuthState()) {
    _checkAuth();
  }

  final AuthService _authService;

  Future<void> _checkAuth() async {
    final loggedIn = await _authService.isLoggedIn;
    if (loggedIn) {
      final resp = await _authService.getProfile();
      if (resp.isSuccess && resp.data != null) {
        state = AuthState(
          status: AuthStatus.authenticated,
          user: resp.data,
        );
        return;
      }
    }
    state = state.copyWith(status: AuthStatus.unauthenticated);
  }

  /// 手机号登录
  Future<void> loginWithPhone(String phone, String code) async {
    state = state.copyWith(isLoading: true, error: null);
    final resp = await _authService.login(phone, code);
    if (resp.isSuccess && resp.data != null) {
      state = AuthState(
        status: AuthStatus.authenticated,
        user: resp.data!.user,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        status: AuthStatus.unauthenticated,
        error: resp.message ?? '登录失败',
      );
    }
  }

  /// 发送验证码，返回 devCode（开发环境）
  Future<String?> sendSms(String phone) async {
    final result = await _authService.sendSms(phone);
    if (!result.success) {
      state = state.copyWith(error: result.message ?? '发送失败');
      return null;
    }
    return result.devCode;
  }

  /// 退出登录
  Future<void> logout() async {
    await _authService.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// 微信登录结果直接设置
  void setWechatLoginResult(LoginResult result) {
    state = AuthState(
      status: AuthStatus.authenticated,
      user: result.user,
    );
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(error: null);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authServiceProvider));
});
