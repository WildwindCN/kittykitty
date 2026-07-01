import 'dart:typed_data';
import 'package:flutter/services.dart';

/// 猫咪检测结果
class CatDetectionResult {
  final bool hasCat;
  final double confidence;
  final Uint8List? maskImage; // 分割 mask
  final Uint8List? cutoutImage; // 抠出的猫图 (PNG)
  final Map<String, dynamic>? metadata;

  const CatDetectionResult({
    required this.hasCat,
    this.confidence = 0,
    this.maskImage,
    this.cutoutImage,
    this.metadata,
  });

  factory CatDetectionResult.noCat() =>
      const CatDetectionResult(hasCat: false);

  factory CatDetectionResult.fromMap(Map<String, dynamic> map) {
    return CatDetectionResult(
      hasCat: map['hasCat'] as bool? ?? false,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0,
      maskImage: map['maskImage'] as Uint8List?,
      cutoutImage: map['cutoutImage'] as Uint8List?,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// 猫咪检测器 — Platform Channel 统一接口
///
/// iOS: Vision Framework (VNRecognizeAnimalsRequest + VNGenerateForegroundInstanceMask)
/// Android: YOLOv8n-seg + NCNN Vulkan / MediaPipe fallback
class CatDetector {
  static const _channel = MethodChannel('com.kittykitty/detector');

  /// 从图片路径检测猫咪
  static Future<CatDetectionResult> detectFromPath(String imagePath) async {
    try {
      final result = await _channel.invokeMethod('detectFromPath', {
        'path': imagePath,
      });
      return CatDetectionResult.fromMap(
        Map<String, dynamic>.from(result as Map),
      );
    } on MissingPluginException {
      return CatDetectionResult(hasCat: false);
    } catch (e) {
      return CatDetectionResult(hasCat: false);
    }
  }

  /// 从字节数据检测猫咪
  static Future<CatDetectionResult> detectFromBytes(Uint8List bytes) async {
    try {
      final result = await _channel.invokeMethod('detectFromBytes', {
        'bytes': bytes,
      });
      return CatDetectionResult.fromMap(
        Map<String, dynamic>.from(result as Map),
      );
    } on MissingPluginException {
      return CatDetectionResult(hasCat: false);
    } catch (e) {
      return CatDetectionResult(hasCat: false);
    }
  }

  /// 检查设备是否支持检测
  static Future<bool> isSupported() async {
    try {
      final result = await _channel.invokeMethod('isSupported');
      return result as bool? ?? false;
    } catch (_) {
      return false;
    }
  }
}
