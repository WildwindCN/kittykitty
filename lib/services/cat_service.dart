import 'api_client.dart';

/// 猫咪服务 — 调用 CloudBase cats 云函数
class CatService {
  CatService({required this.apiClient});

  final ApiClient apiClient;

  /// 附近猫咪查询
  Future<ApiResponse<List<Map<String, dynamic>>>> getNearbyCats({
    required double latitude,
    required double longitude,
    double radius = 5000,
  }) async {
    return apiClient.post(
      '/cats',
      data: {
        'action': 'nearby',
        'latitude': latitude,
        'longitude': longitude,
        'radius': radius,
      },
      parser: (data) => List<Map<String, dynamic>>.from(data as List),
    );
  }

  /// 捕捉猫咪（上传已生成的猫咪数据）
  Future<ApiResponse<String>> captureCat(Map<String, dynamic> catData) async {
    return apiClient.post(
      '/cats',
      data: {
        'action': 'capture',
        'catData': catData,
      },
      parser: (data) => data['catId'] as String,
    );
  }

  /// 我的猫咪列表
  Future<ApiResponse<List<Map<String, dynamic>>>> getMyCats() async {
    return apiClient.post(
      '/cats',
      data: {'action': 'my-cats'},
      parser: (data) => List<Map<String, dynamic>>.from(data as List),
    );
  }

  /// 猫咪详情
  Future<ApiResponse<Map<String, dynamic>>> getCatDetail(String catId) async {
    return apiClient.post(
      '/cats',
      data: {'action': 'cat-detail', 'catId': catId},
      parser: (data) => data as Map<String, dynamic>,
    );
  }

  /// 同一猫脸的所有版本
  Future<ApiResponse<List<Map<String, dynamic>>>> getCatVersions(
      String catFaceId) async {
    return apiClient.post(
      '/cats',
      data: {'action': 'cat-versions', 'catFaceId': catFaceId},
      parser: (data) => List<Map<String, dynamic>>.from(data as List),
    );
  }
}
