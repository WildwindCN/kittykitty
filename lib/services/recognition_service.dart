import 'api_client.dart';

/// 猫脸识别服务 — 调用 CloudBase recognition 云函数
class RecognitionService {
  RecognitionService({required this.apiClient});

  final ApiClient apiClient;

  /// 匹配猫脸（就近 5km 范围），返回匹配结果 + 特征向量
  Future<MatchResult> matchCatFace({
    required String imageUrl,
    required double latitude,
    required double longitude,
  }) async {
    final resp = await apiClient.post<dynamic>(
      '/recognition',
      data: {
        'action': 'match',
        'imageUrl': imageUrl,
        'latitude': latitude,
        'longitude': longitude,
      },
      parser: (data) => data as Map<String, dynamic>,
    );

    return MatchResult(
      matched: resp.data?['matched'] as bool? ?? false,
      catFaceId: resp.data?['catFaceId'] as String?,
      confidence: (resp.data?['confidence'] as num?)?.toDouble() ?? 0,
      featureVector: (resp.data?['featureVector'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      featureDim: (resp.data?['featureDim'] as num?)?.toInt() ?? 0,
      method: resp.data?['method'] as String?,
      error: resp.isSuccess ? null : resp.message,
    );
  }

  /// 注册新猫脸
  Future<ApiResponse<String>> registerCatFace({
    required String imageUrl,
    List<double>? featureVector,
  }) async {
    return apiClient.post(
      '/recognition',
      data: {
        'action': 'register',
        'imageUrl': imageUrl,
        'featureVector': featureVector,
      },
      parser: (data) => data['catFaceId'] as String,
    );
  }

  /// 获取猫脸所有版本
  Future<ApiResponse<Map<String, dynamic>>> getCatFaceVersions(
      String catFaceId) async {
    return apiClient.post(
      '/recognition',
      data: {'action': 'get-versions', 'catFaceId': catFaceId},
      parser: (data) => data as Map<String, dynamic>,
    );
  }
}

/// 匹配结果
class MatchResult {
  final bool matched;
  final String? catFaceId;
  final double confidence;
  final List<double>? featureVector;
  final int featureDim;
  final String? method;
  final String? error;

  const MatchResult({
    required this.matched,
    this.catFaceId,
    this.confidence = 0,
    this.featureVector,
    this.featureDim = 0,
    this.method,
    this.error,
  });
}
