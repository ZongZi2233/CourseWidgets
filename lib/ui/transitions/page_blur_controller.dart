import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// [v2.7.0] 页面转场截图模糊控制器
///
/// 进入二级页面前截图当前页面内容，存储为模糊图片。
/// SmoothSlideTransitionsBuilder 在 secondaryAnimation 阶段读取此截图
/// 替代实时 BackdropFilter，大幅提升性能。
class PageBlurController extends ChangeNotifier {
  PageBlurController._();
  static final PageBlurController instance = PageBlurController._();

  /// 截图数据
  ui.Image? _capturedImage;
  ui.Image? get capturedImage => _capturedImage;

  /// 截图是否可用
  bool get hasCapture => _capturedImage != null;

  /// 从 RepaintBoundary 截图（异步版本，更安全）
  Future<bool> capture(GlobalKey boundaryKey) async {
    try {
      final boundary =
          boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null || !boundary.hasSize) return false;

      // pixelRatio=0.5 降低内存占用，截图仅用于模糊背景（模糊后细节不可见）
      final image = await boundary.toImage(pixelRatio: 0.5);
      _capturedImage?.dispose(); // 释放旧截图
      _capturedImage = image;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('⚠️ PageBlurController.capture 失败: $e');
      return false;
    }
  }

  /// 同步截图（用于 didPush 等无法 await 的场景）
  /// 注意：toImageSync 仅在 Impeller 渲染器上可用
  /// 在 Skia（旧渲染器）上会抛出 UnsupportedError
  bool captureSync(GlobalKey boundaryKey) {
    try {
      final boundary =
          boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null || !boundary.hasSize) return false;

      // 先尝试同步截图（Impeller 支持）
      // 失败时静默降级（截图不可用，转场将使用简单暗化回退）
      final image = boundary.toImageSync(pixelRatio: 0.5);
      _capturedImage?.dispose();
      _capturedImage = image;
      notifyListeners();
      return true;
    } catch (e) {
      // toImageSync 在 Skia 上不支持，静默忽略
      debugPrint('⚠️ PageBlurController.captureSync 不支持: $e');
      return false;
    }
  }

  /// 清除截图（返回前页时调用）
  void clear() {
    _capturedImage?.dispose();
    _capturedImage = null;
    notifyListeners();
  }
}
