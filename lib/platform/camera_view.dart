import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

/// CameraView — Platform View 包装原生相机预览
///
/// Android: 使用 Texture 或 PlatformView 渲染
/// iOS: 使用 PlatformView 渲染 AVCaptureVideoPreviewLayer
///
/// 叠加层方案：此 Widget 嵌入原生相机预览，上层用 Flutter CustomPaint 画 AR 覆盖层。
class CameraView extends StatelessWidget {
  const CameraView({
    super.key,
    this.onFrameAvailable,
    this.resolutionPreset = 'medium',
  });

  final void Function()? onFrameAvailable;
  final String resolutionPreset;

  @override
  Widget build(BuildContext context) {
    // 真机构建时使用 AndroidView / UiKitView
    // 开发阶段显示占位
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.camera_alt, size: 48, color: Colors.white.withAlpha(60)),
            const SizedBox(height: 8),
            Text('相机预览 (真机激活)',
                style: TextStyle(color: Colors.white.withAlpha(40), fontSize: 12)),
          ],
        ),
      ),
    );

    // 真机代码 (iOS):
    // if (defaultTargetPlatform == TargetPlatform.iOS) {
    //   return UiKitView(
    //     viewType: 'com.kittykitty/camera_view',
    //     creationParams: {'resolution': resolutionPreset},
    //     creationParamsCodec: const StandardMessageCodec(),
    //     onPlatformViewCreated: (_) => onFrameAvailable?.call(),
    //   );
    // }
    //
    // 真机代码 (Android):
    // return AndroidView(
    //   viewType: 'com.kittykitty/camera_view',
    //   creationParams: {'resolution': resolutionPreset},
    //   creationParamsCodec: const StandardMessageCodec(),
    //   onPlatformViewCreated: (_) => onFrameAvailable?.call(),
    // );
  }
}

/// AR 叠加层 — 在相机预览上方绘制瞄准框和检测框
class AROverlayPainter extends CustomPainter {
  AROverlayPainter({
    this.detectionRect,
    this.hasCat = false,
  });

  final Rect? detectionRect;
  final bool hasCat;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = hasCat ? Colors.greenAccent : Colors.white.withAlpha(120)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // 瞄准框
    final center = Offset(size.width / 2, size.height / 2);
    const boxSize = Size(250, 250);
    final boxRect = Rect.fromCenter(center: center, width: boxSize.width, height: boxSize.height);

    // 圆角矩形
    final rrect = RRect.fromRectAndRadius(boxRect, const Radius.circular(16));
    canvas.drawRRect(rrect, paint);

    // 四角标记
    const cornerLen = 30.0;
    paint.strokeWidth = 3;
    paint.color = hasCat ? Colors.greenAccent : Colors.white54;

    // 左上
    canvas.drawLine(
        Offset(boxRect.left, boxRect.top + cornerLen),
        Offset(boxRect.left, boxRect.top), paint);
    canvas.drawLine(
        Offset(boxRect.left, boxRect.top),
        Offset(boxRect.left + cornerLen, boxRect.top), paint);
    // 右上
    canvas.drawLine(
        Offset(boxRect.right - cornerLen, boxRect.top),
        Offset(boxRect.right, boxRect.top), paint);
    canvas.drawLine(
        Offset(boxRect.right, boxRect.top),
        Offset(boxRect.right, boxRect.top + cornerLen), paint);
    // 左下
    canvas.drawLine(
        Offset(boxRect.left, boxRect.bottom - cornerLen),
        Offset(boxRect.left, boxRect.bottom), paint);
    canvas.drawLine(
        Offset(boxRect.left, boxRect.bottom),
        Offset(boxRect.left + cornerLen, boxRect.bottom), paint);
    // 右下
    canvas.drawLine(
        Offset(boxRect.right - cornerLen, boxRect.bottom),
        Offset(boxRect.right, boxRect.bottom), paint);
    canvas.drawLine(
        Offset(boxRect.right, boxRect.bottom),
        Offset(boxRect.right, boxRect.bottom - cornerLen), paint);

    // 提示文字
    if (!hasCat) {
      final textSpan = TextSpan(
        text: '将猫咪放入框内',
        style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 14),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(center.dx - textPainter.width / 2, boxRect.bottom + 16),
      );
    }

    // 检测框
    if (detectionRect != null && hasCat) {
      paint.color = Colors.greenAccent;
      paint.strokeWidth = 2;
      canvas.drawRect(detectionRect!, paint);
    }
  }

  @override
  bool shouldRepaint(covariant AROverlayPainter oldDelegate) {
    return oldDelegate.hasCat != hasCat || oldDelegate.detectionRect != detectionRect;
  }
}
