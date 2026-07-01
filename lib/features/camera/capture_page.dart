import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import '../../platform/camera_view.dart' show AROverlayPainter;

/// 拍摄页 — 真实相机 + AR 瞄准叠加
class CapturePage extends ConsumerStatefulWidget {
  const CapturePage({super.key});

  @override
  ConsumerState<CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends ConsumerState<CapturePage>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isReady = false;
  bool _isCapturing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller!.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() => _error = '未找到可用相机');
        return;
      }

      // 优先后置摄像头
      final back = _cameras!.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      _controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      if (mounted) setState(() => _isReady = true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _takePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_isCapturing) return;
    setState(() => _isCapturing = true);

    try {
      final file = await _controller!.takePicture();
      if (!mounted) return;

      // 获取 GPS 位置
      double lat = 0, lng = 0;
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
        lat = pos.latitude;
        lng = pos.longitude;
      } catch (_) {}

      if (mounted) {
        context.push('/capture/detecting/${Uri.encodeComponent(file.path)}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拍照失败: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              FilledButton(onPressed: _initCamera, child: const Text('重试')),
            ],
          ),
        ),
      );
    }

    if (!_isReady || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('拍摄猫咪'),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 相机预览
          CameraPreview(_controller!),

          // AR 瞄准叠加层
          Positioned.fill(
            child: CustomPaint(
              painter: AROverlayPainter(hasCat: false),
            ),
          ),

          // 底部控制
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 拍照按钮
                GestureDetector(
                  onTap: _isCapturing ? null : _takePhoto,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: _isCapturing ? 64 : 80,
                    height: _isCapturing ? 64 : 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isCapturing ? Colors.white38 : theme.colorScheme.primary,
                        width: 5,
                      ),
                      color: _isCapturing
                          ? Colors.white.withAlpha(50)
                          : Colors.white.withAlpha(30),
                    ),
                    child: _isCapturing
                        ? const Center(
                            child: SizedBox(
                              width: 24, height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white,
                              ),
                            ),
                          )
                        : Center(
                            child: Container(
                              width: 64, height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.colorScheme.primary.withAlpha(200),
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                // 提示
                Text(
                  '对准猫咪，点击拍摄',
                  style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
