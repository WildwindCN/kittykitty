import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 统一 API 客户端
///
/// 封装 Dio，自动注入 JWT Token、处理 Token 过期刷新、统一错误处理。
class ApiClient {
  ApiClient({
    required String baseUrl,
    FlutterSecureStorage? storage,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          headers: {'Content-Type': 'application/json'},
        )) {
    _dio.interceptors.add(_AuthInterceptor(this));
    _dio.interceptors.add(LogInterceptor(
      requestBody: false,
      responseBody: false,
      logPrint: (obj) => print('[API] $obj'),
    ));
  }

  final Dio _dio;
  final FlutterSecureStorage _storage;

  static const _tokenKey = 'auth_token';
  static const _refreshTokenKey = 'auth_refresh_token';

  // ===== Token 管理 =====

  Future<String?> get token => _storage.read(key: _tokenKey);
  Future<String?> get refreshToken => _storage.read(key: _refreshTokenKey);

  Future<void> saveTokens({required String token, String? refreshToken}) async {
    await _storage.write(key: _tokenKey, value: token);
    if (refreshToken != null) {
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    }
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  Future<bool> get hasToken async {
    final t = await token;
    return t != null && t.isNotEmpty;
  }

  // ===== 原始请求（不做 _parseResponse 包装）=====

  Future<Map<String, dynamic>> rawPost(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    final resp = await _dio.post(path, data: data);
    return resp.data as Map<String, dynamic>;
  }

  // ===== 标准 HTTP 方法 =====

  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic data)? parser,
  }) async {
    final resp = await _dio.get(path, queryParameters: queryParameters);
    return _parseResponse(resp, parser);
  }

  Future<ApiResponse<T>> post<T>(
    String path, {
    dynamic data,
    T Function(dynamic data)? parser,
  }) async {
    final resp = await _dio.post(path, data: data);
    return _parseResponse(resp, parser);
  }

  Future<ApiResponse<T>> put<T>(
    String path, {
    dynamic data,
    T Function(dynamic data)? parser,
  }) async {
    final resp = await _dio.put(path, data: data);
    return _parseResponse(resp, parser);
  }

  ApiResponse<T> _parseResponse<T>(
    Response resp,
    T Function(dynamic data)? parser,
  ) {
    final body = resp.data as Map<String, dynamic>;
    final code = body['code'] as int? ?? resp.statusCode ?? 500;

    if (code >= 200 && code < 300) {
      final data = body['data'];
      return ApiResponse.success(
        data: parser != null && data != null ? parser(data) : data as T?,
        message: body['message'] as String?,
      );
    }

    return ApiResponse.error(
      code: code,
      message: body['message'] as String? ?? '请求失败',
    );
  }
}

/// 请求/响应拦截器 — 注入 Token
class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this.client);

  final ApiClient client;
  bool _isRefreshing = false;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await client.token;
    if (token != null) {
      // X-Auth-Token header 避免 CloudBase 网关清空 body
      options.headers['X-Auth-Token'] = 'Bearer $token';
      // 同时在 body 中注入 token 作为兜底
      if (options.data is Map) {
        (options.data as Map)['token'] = token;
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      if (_isRefreshing) {
        // 等待刷新完成后重试
        await Future.delayed(const Duration(milliseconds: 100));
        try {
          final token = await client.token;
          if (token != null) {
            err.requestOptions.headers['Authorization'] = 'Bearer $token';
            final retryResp = await Dio().fetch(err.requestOptions);
            handler.resolve(retryResp);
            return;
          }
        } catch (_) {}
        handler.next(err);
        return;
      }

      _isRefreshing = true;
      try {
        final refresh = await client.refreshToken;
        if (refresh != null) {
          final resp = await Dio().post(
            '${err.requestOptions.baseUrl}/auth/refresh',
            data: {'refreshToken': refresh},
          );
          final newToken = resp.data['data']['token'] as String;
          final newRefresh = resp.data['data']['refreshToken'] as String?;
          await client.saveTokens(token: newToken, refreshToken: newRefresh);

          err.requestOptions.headers['X-Auth-Token'] = 'Bearer $newToken';
          final retryResp = await Dio().fetch(err.requestOptions);
          handler.resolve(retryResp);
          return;
        }
      } catch (_) {
        await client.clearTokens();
      } finally {
        _isRefreshing = false;
      }
    }
    handler.next(err);
  }
}

class ApiResponse<T> {
  final T? data;
  final int code;
  final String? message;
  final bool isSuccess;

  const ApiResponse._({
    this.data,
    required this.code,
    this.message,
    required this.isSuccess,
  });

  factory ApiResponse.success({T? data, String? message}) =>
      ApiResponse._(data: data, code: 200, message: message, isSuccess: true);

  factory ApiResponse.error({required int code, String? message}) =>
      ApiResponse._(code: code, message: message, isSuccess: false);
}
