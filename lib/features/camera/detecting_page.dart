import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../game/generator/cat_generator.dart';
import '../../game/models/models.dart';
import '../../services/cat_service.dart';
import '../../services/recognition_service.dart';
import '../../services/storage_service.dart';
import '../../services/api_client.dart';
import '../../platform/cat_detector.dart';
import '../auth/auth_provider.dart';
import '../card/collection_provider.dart';

/// 检测流程页 — 相机拍照后进入此页
/// 流程: Vision检测 → 抠图 → Cos上传 → DINOv2特征 → 入库
class DetectingPage extends ConsumerStatefulWidget {
  const DetectingPage({super.key, required this.imagePath});
  final String imagePath;

  @override
  ConsumerState<DetectingPage> createState() => _DetectingPageState();
}

class _DetectingPageState extends ConsumerState<DetectingPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  int _step = 0;
  String _statusText = '正在检测猫咪...';
  bool _hasError = false;
  String? _errorMessage;

  static const _stepLabels = [
    '正在检测猫咪...',
    '正在抠图...',
    '正在上传...',
    '正在识别特征...',
  ];
  static const _icons = [
    Icons.search,
    Icons.auto_fix_high,
    Icons.cloud_upload,
    Icons.fingerprint,
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animController.repeat(reverse: true);
    _runPipeline();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _runPipeline() async {
    try {
      final file = File(widget.imagePath);
      if (!await file.exists()) throw Exception('图片文件不存在');
      final imageBytes = await file.readAsBytes();
      if (!mounted) return;

      // === Step 1: iOS Vision 猫咪检测 ===
      setState(() { _step = 0; _statusText = _stepLabels[0]; });
      final detection = await CatDetector.detectFromBytes(imageBytes);
      if (!mounted) return;

      if (!detection.hasCat) {
        setState(() {
          _hasError = true;
          _errorMessage = '未检测到猫咪，请重新拍摄。\n置信度: ${(detection.confidence * 100).round()}%';
        });
        return;
      }
      final confidence = detection.confidence;

      // === Step 2: 上传原图 + 抠图到 COS ===
      setState(() { _step = 2; _statusText = _stepLabels[2]; });
      final config = ref.read(appConfigProvider);
      final storage = StorageService(
        bucket: config.cosBucket,
        region: config.cosRegion,
        apiBaseUrl: config.apiBaseUrl,
      );
      final catId = const Uuid().v4();

      // 上传原图
      final origUpload = await storage.uploadBytes(
        imageBytes, StorageService.catImagePath(catId), 'image/jpeg',
      );
      String? cutoutUrl;
      if (detection.cutoutImage != null) {
        final cutoutUpload = await storage.uploadBytes(
          detection.cutoutImage!, StorageService.catCardPath(catId), 'image/png',
        );
        if (cutoutUpload.success) cutoutUrl = cutoutUpload.url;
      }
      if (!origUpload.success) throw Exception('图片上传失败');
      if (!mounted) return;

      // === Step 3: DINOv2 特征提取 ===
      setState(() { _step = 3; _statusText = _stepLabels[3]; });
      final apiClient = ref.read(apiClientProvider);
      final recogService = RecognitionService(apiClient: apiClient);
      List<double>? featureVector;
      String? matchedCatFaceId;

      try {
        final matchResult = await recogService.matchCatFace(
          imageUrl: origUpload.url!,
          latitude: 0, longitude: 0,
        );
        featureVector = matchResult.featureVector;
        if (matchResult.matched) {
          matchedCatFaceId = matchResult.catFaceId;
        }
      } catch (_) {
        // DINOv2 离线时降级
      }
      if (!mounted) return;

      // === Step 4: 生成猫咪并入库 ===
      final authUser = ref.read(authProvider).user;
      final ownerId = authUser?.id ?? 'unknown';
      final generator = CatGenerator(random: Random());
      final cat = generator.generateBaseCat(
        catId: catId,
        ownerId: ownerId,
        imageUrl: origUpload.url!,
        latitude: 0, longitude: 0,
      );

      // 将特征向量存入猫咪数据
      final enrichedCat = cat.copyWith(cardImageUrl: cutoutUrl);
      final catJson = _catToJson(enrichedCat);
      if (featureVector != null) {
        catJson['featureVector'] = featureVector;
      }
      catJson['catFaceId'] = 'face-$catId'; // 暂时自引用，后续 matching 会关联

      await ref.read(collectionProvider.notifier).addCatWithData(catJson);

      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      // 成功 → 跳转卡片详情
      if (mounted) context.pushReplacement('/card/$catId');
    } catch (e) {
      if (!mounted) return;
      setState(() { _hasError = true; _errorMessage = e.toString(); });
    }
  }

  Map<String, dynamic> _catToJson(Cat cat) => {
    'name': cat.name, 'rarity': cat.rarity.name, 'type': cat.type.name,
    'baseHp': cat.baseHp, 'baseAtk': cat.baseAtk,
    'baseDef': cat.baseDef, 'baseSpd': cat.baseSpd, 'baseCrit': cat.baseCrit,
    'battleSkills': cat.battleSkills.map((s) => {
      'id': s.id, 'name': s.name, 'type': s.type.name,
      'power': s.power, 'accuracy': s.accuracy, 'description': s.description,
    }).toList(),
    'lifeSkills': cat.lifeSkills.map((s) => {
      'id': s.id, 'name': s.name, 'effect': s.effect.name,
      'value': s.value, 'description': s.description,
    }).toList(),
    'level': cat.level, 'exp': cat.exp,
    'imageUrl': cat.imageUrl, 'cardImageUrl': cat.cardImageUrl,
    'captureLocation': {
      'latitude': cat.captureLocation.latitude,
      'longitude': cat.captureLocation.longitude,
    },
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F23),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return Opacity(
                    opacity: 0.3 + _animController.value * 0.7,
                    child: Transform.scale(
                      scale: 0.9 + _animController.value * 0.2,
                      child: Icon(
                        _hasError ? Icons.error_outline : _icons[_step.clamp(0, _icons.length - 1)],
                        size: 100,
                        color: _hasError ? Colors.redAccent : theme.colorScheme.primary,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              Text(
                _hasError ? '处理失败' : _statusText,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: _hasError ? Colors.redAccent : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (_hasError) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    _errorMessage ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () {
                    setState(() { _hasError = false; _errorMessage = null; });
                    _runPipeline();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('重试'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('返回', style: TextStyle(color: Colors.white38)),
                ),
              ] else
                SizedBox(
                  width: 200,
                  child: LinearProgressIndicator(
                    value: null,
                    color: theme.colorScheme.primary,
                    backgroundColor: theme.colorScheme.primary.withAlpha(30),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
