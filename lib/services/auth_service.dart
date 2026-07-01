import 'api_client.dart';

/// 认证服务 — 短信登录、微信登录、Token 管理
class AuthService {
  AuthService({required this.apiClient});

  final ApiClient apiClient;

  /// 发送短信验证码（开发环境返回 devCode）
  Future<SmsResult> sendSms(String phone) async {
    final resp = await apiClient.rawPost(
      '/auth/send-sms',
      data: {'phone': phone},
    );
    final body = resp as Map<String, dynamic>;
    return SmsResult(
      success: (body['code'] as int? ?? 500) < 300,
      message: body['message'] as String?,
      devCode: body['devCode'] as String?,
    );
  }

  /// 手机号 + 验证码登录
  Future<ApiResponse<LoginResult>> login(String phone, String code) async {
    final resp = await apiClient.post<dynamic>(
      '/auth/login',
      data: {'phone': phone, 'code': code},
    );

    if (resp.isSuccess && resp.data != null) {
      final data = resp.data as Map<String, dynamic>;
      final token = data['token'] as String;
      final refreshToken = data['refreshToken'] as String?;
      await apiClient.saveTokens(token: token, refreshToken: refreshToken);

      final userData = data['user'] as Map<String, dynamic>;
      return ApiResponse.success(
        data: LoginResult(
          token: token,
          user: UserInfo(
            id: userData['id'] as String,
            nickname: userData['nickname'] as String? ?? '',
            phone: userData['phone'] as String? ?? '',
            avatarUrl: userData['avatarUrl'] as String?,
          ),
        ),
      );
    }

    return ApiResponse.error(code: resp.code, message: resp.message);
  }

  /// 微信登录
  Future<ApiResponse<LoginResult>> wechatLogin(String code) async {
    final resp = await apiClient.post<dynamic>(
      '/auth/wechat-login',
      data: {'code': code},
    );

    if (resp.isSuccess && resp.data != null) {
      final data = resp.data as Map<String, dynamic>;
      final token = data['token'] as String;
      await apiClient.saveTokens(token: token);

      final userData = data['user'] as Map<String, dynamic>;
      return ApiResponse.success(
        data: LoginResult(
          token: token,
          user: UserInfo(
            id: userData['id'] as String,
            nickname: userData['nickname'] as String? ?? '',
            phone: userData['phone'] as String? ?? '',
            avatarUrl: userData['avatarUrl'] as String?,
          ),
        ),
      );
    }

    return ApiResponse.error(code: resp.code, message: resp.message);
  }

  /// 获取当前用户信息
  Future<ApiResponse<UserInfo>> getProfile() async {
    return apiClient.get<UserInfo>(
      '/user/profile',
      parser: (data) => UserInfo.fromJson(data as Map<String, dynamic>),
    );
  }

  /// 退出登录
  Future<void> logout() async {
    await apiClient.clearTokens();
  }

  /// 是否已登录
  Future<bool> get isLoggedIn => apiClient.hasToken;
}

class LoginResult {
  final String token;
  final UserInfo user;

  const LoginResult({required this.token, required this.user});
}

class SmsResult {
  final bool success;
  final String? message;
  final String? devCode;

  const SmsResult({required this.success, this.message, this.devCode});
}

class UserInfo {
  final String id;
  final String nickname;
  final String phone;
  final String? avatarUrl;

  const UserInfo({
    required this.id,
    required this.nickname,
    required this.phone,
    this.avatarUrl,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) => UserInfo(
        id: json['id'] as String,
        nickname: json['nickname'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        avatarUrl: json['avatarUrl'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nickname': nickname,
        'phone': phone,
        'avatarUrl': avatarUrl,
      };
}
