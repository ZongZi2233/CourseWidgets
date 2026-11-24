import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';

/// [v3.2.3] 离屏 GPU 渲染管线与着色器 PSO 预热器
///
/// 澄清编译期与运行期管线职责：
/// - `pubspec.yaml` 中声明的 5 份 `.frag` 片段着色器在构建时已由 `impellerc` AOT 预烘焙为二进制字节码（IPLR/SPIR-V/GLSL）；
/// - 但在 Android Vulkan / Windows ANGLE 首次运行瞬间，底层图形驱动仍需为特定组合状态（高斯模糊 `saveLayer`、
///   `RSuperellipse` 解析裁切与阴影、渐变描边等）编译硬件管线状态对象（GPU PSO）。
/// - 本服务在首帧光栅化落盘后延后 `180ms` 自动触发一次轻量化 `64×64` 离屏画面预光栅化，
///   在不拖慢冷启动开屏的前提下预先完成上述高频弹窗/玻璃变形管线预热，消除首次交互动画的掉帧卡顿。
class RenderPipelinePrewarmer {
  RenderPipelinePrewarmer._();

  static bool _hasWarmedUp = false;
  static Future<void>? _inFlight;

  static bool get hasWarmedUp => _hasWarmedUp;

  @visibleForTesting
  static void resetForTest() {
    _hasWarmedUp = false;
    _inFlight = null;
  }

  /// 在首帧光栅化完成 `180ms` 后异步调度一次性离屏管线预热
  static void scheduleAfterFirstFrame() {
    if (_hasWarmedUp || _inFlight != null) return;
    unawaited(
      WidgetsBinding.instance.waitUntilFirstFrameRasterized.then((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 180));
        await warmUp();
      }),
    );
  }

  /// 幂等执行离屏 `64×64` GPU 管线状态预热（单次构建，立即释放显存资源）
  static Future<void> warmUp() async {
    if (_hasWarmedUp) return;
    if (_inFlight != null) {
      return _inFlight!;
    }
    final completer = Completer<void>();
    _inFlight = completer.future;

    try {
      // 查询着色器滤波器支持状态，提前触发后端特性探测
      ui.ImageFilter.isShaderFilterSupported;

      final recorder = ui.PictureRecorder();
      const rect = ui.Rect.fromLTWH(0, 0, 64, 64);
      final canvas = ui.Canvas(recorder, rect);
      final rsuperellipse = ui.RSuperellipse.fromRectAndRadius(
        const ui.Rect.fromLTWH(6, 6, 52, 52),
        const ui.Radius.circular(14),
      );

      // 1. 预热 Impeller 单通解析高斯阴影与超椭圆绘制管线
      try {
        final shadowPaint = ui.Paint()
          ..color = const ui.Color(0x33000000)
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 10.0);
        canvas.drawRSuperellipse(rsuperellipse, shadowPaint);
      } catch (_) {}

      // 2. 预热超椭圆裁切 + 弹窗背景遮罩模糊管线 (sigma 6.5) + 玻璃主体高模糊管线 (sigma 22.0)
      canvas.save();
      try {
        canvas.clipRSuperellipse(rsuperellipse);
      } catch (_) {}

      try {
        canvas.saveLayer(
          rect,
          ui.Paint()
            ..imageFilter = ui.ImageFilter.blur(sigmaX: 6.5, sigmaY: 6.5),
        );
        canvas.drawRect(
          rect,
          ui.Paint()..color = const ui.Color(0x28101420),
        );
        canvas.restore();
      } catch (_) {}

      try {
        canvas.saveLayer(
          rect,
          ui.Paint()
            ..imageFilter = ui.ImageFilter.blur(sigmaX: 22.0, sigmaY: 22.0),
        );
        // 3. 预热渐变玻璃填色、高光细描边与混合模式管线
        final gradientPaint = ui.Paint()
          ..blendMode = ui.BlendMode.srcOver
          ..shader = ui.Gradient.linear(
            ui.Offset.zero,
            const ui.Offset(64, 64),
            const [ui.Color(0xB8FFFFFF), ui.Color(0x88E8EEF9)],
          );
        canvas.drawRSuperellipse(rsuperellipse, gradientPaint);
        canvas.restore();
      } catch (_) {}

      // 4. 预热 ColorFilter + 超椭圆细描边高光管线
      try {
        final strokePaint = ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = const ui.Color(0x99FFFFFF)
          ..colorFilter = const ui.ColorFilter.mode(
            ui.Color(0x40FFFFFF),
            ui.BlendMode.srcATop,
          );
        canvas.drawRSuperellipse(rsuperellipse, strokePaint);
      } catch (_) {}

      canvas.restore();

      final ui.Picture picture = recorder.endRecording();
      ui.Image? baked;
      try {
        baked = await picture.toImage(64, 64);
      } catch (_) {
      } finally {
        baked?.dispose();
        picture.dispose();
      }

      _hasWarmedUp = true;
    } catch (_) {
      _hasWarmedUp = true;
    } finally {
      _inFlight = null;
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }
}
