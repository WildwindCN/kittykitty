import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// 腾讯云 COS 存储服务
///
/// 上传流程:
/// 1. 浏览器/Flutter Web: 使用 CloudBase 云存储 HTTP API 上传
/// 2. 原生平台: 先调用云函数获取临时密钥，再直传 COS
class StorageService {
  StorageService({
    required this.bucket,
    required this.region,
    required this.apiBaseUrl,
    this.baseUrl,
  });

  final String bucket;
  final String region;
  final String apiBaseUrl;
  final String? baseUrl;

  /// 上传文件到 COS
  ///
  /// Web 平台使用 CloudBase HTTP API 上传
  /// 原生平台使用预签名 URL PUT 上传
  Future<StorageUploadResult> uploadFile(
    String filePath,
    String cosKey,
  ) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return StorageUploadResult(
          success: false,
          error: '文件不存在: $filePath',
        );
      }

      final bytes = await file.readAsBytes();
      return uploadBytes(bytes, cosKey, _contentType(cosKey));
    } catch (e) {
      return StorageUploadResult(success: false, error: e.toString());
    }
  }

  /// 上传字节数据
  Future<StorageUploadResult> uploadBytes(
    List<int> bytes,
    String cosKey,
    String contentType,
  ) async {
    try {
      if (kIsWeb) {
        return await _uploadViaCloudBase(bytes, cosKey, contentType);
      } else {
        return await _uploadViaSignedUrl(bytes, cosKey, contentType);
      }
    } catch (e) {
      return StorageUploadResult(success: false, error: e.toString());
    }
  }

  /// Web: 通过 CloudBase HTTP API 上传
  Future<StorageUploadResult> _uploadViaCloudBase(
    List<int> bytes, String cosKey, String contentType) async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));

    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: cosKey.split('/').last),
      'cloudPath': cosKey,
    });

    final resp = await dio.post(
      '$apiBaseUrl/storage/upload',
      data: formData,
      options: Options(headers: {'Content-Type': 'multipart/form-data'}),
    );

    final data = resp.data as Map<String, dynamic>;
    if (data['code'] == 200 && data['data'] != null) {
      final url = data['data']['downloadUrl'] as String? ?? _buildUrl(cosKey);
      return StorageUploadResult(success: true, url: url);
    }
    return StorageUploadResult(
      success: false,
      error: data['message'] as String? ?? '上传失败',
    );
  }

  /// 原生: 通过预签名 URL 上传
  Future<StorageUploadResult> _uploadViaSignedUrl(
    List<int> bytes, String cosKey, String contentType) async {
    // 1. 获取预签名 URL (需要云函数支持)
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
    ));
    final signResp = await dio.post(
      '$apiBaseUrl/storage/getUploadUrl',
      data: {'cloudPath': cosKey, 'contentType': contentType},
    );
    final signData = signResp.data as Map<String, dynamic>;
    if (signData['code'] != 200 || signData['data'] == null) {
      return StorageUploadResult(
        success: false,
        error: signData['message'] as String? ?? '获取上传凭证失败',
      );
    }

    // 2. PUT 上传到 COS
    final signedUrl = signData['data']['uploadUrl'] as String;
    final putResp = await dio.put(
      signedUrl,
      data: bytes,
      options: Options(
        headers: {'Content-Type': contentType},
        contentType: contentType,
      ),
    );

    if (putResp.statusCode == 200) {
      final downloadUrl = signData['data']['downloadUrl'] as String? ?? _buildUrl(cosKey);
      return StorageUploadResult(success: true, url: downloadUrl);
    }
    return StorageUploadResult(success: false, error: 'COS 上传失败: ${putResp.statusCode}');
  }

  String _buildUrl(String cosKey) {
    if (baseUrl != null) return '$baseUrl/$cosKey';
    return 'https://$bucket.cos.$region.myqcloud.com/$cosKey';
  }

  String _contentType(String path) {
    if (path.endsWith('.png')) return 'image/png';
    if (path.endsWith('.jpg') || path.endsWith('.jpeg')) return 'image/jpeg';
    if (path.endsWith('.webp')) return 'image/webp';
    return 'application/octet-stream';
  }

  /// 生成猫咪图片的 COS 路径
  static String catImagePath(String catId) => 'cats/$catId/image.png';

  /// 生成猫咪卡片的 COS 路径
  static String catCardPath(String catId) => 'cats/$catId/card.png';

  /// 生成用户头像的 COS 路径
  static String avatarPath(String userId) => 'users/$userId/avatar.png';
}

class StorageUploadResult {
  final bool success;
  final String? url;
  final String? error;

  const StorageUploadResult({
    required this.success,
    this.url,
    this.error,
  });
}
