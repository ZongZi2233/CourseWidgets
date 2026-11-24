// Miuix Flutter 移植版 - Backdrop 抽象
// 源自 compose-miuix-ui/miuix 的 miuix-blur/Backdrop.kt + LayerBackdrop.kt。
// Backdrop 定义"模糊表面背后要绘制的内容"如何提供；MiuixLayerBackdrop 通过
// 一个被捕获的图层快照（ui.Image）+ 全局坐标提供背景，供模糊组件按偏移取样。
// SPDX-License-Identifier: Apache-2.0

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// 背景内容提供者。对应 Kotlin `interface Backdrop`。
///
/// 模糊组件（[MiuixTextureBlur] 等）通过它拿到"自己背后的内容"来做模糊。
/// 阶段 5A 只实现 [MiuixLayerBackdrop]（图层快照捕获）。
abstract class MiuixBackdrop extends ChangeNotifier {
  /// 是否需要布局坐标来正确定位（图层型 backdrop 为 true）。
  /// 对应 Kotlin `isCoordinatesDependent`。
  bool get isCoordinatesDependent;

  /// 当前可用于取样的背景快照；未捕获时为 null。
  ui.Image? get snapshot;

  /// 背景快照在全局（窗口）坐标系中的左上角位置。用于与模糊表面对齐。
  Offset? get globalOffset;

  /// 快照的设备像素比（快照按此比例录制）。
  double get pixelRatio;

  /// 当前是否已有可供采样的背景内容。
  bool get hasContent => snapshot != null && globalOffset != null;

  /// 供玻璃纹理缓存使用的采样键；当快照、偏移或派生参数变化时应返回不同键。
  Object? cacheKey(Offset surfaceGlobalOrigin) {
    final origin = globalOffset;
    return (snapshot, origin == null ? null : surfaceGlobalOrigin - origin);
  }

  /// 将背景内容绘制到以逻辑像素计的离屏画布（含四周 [padding]）。
  void paintBackdrop(
    Canvas canvas,
    Offset surfaceGlobalOrigin,
    Size surfaceSize,
    double padding,
  ) {
    final image = snapshot;
    final offset = globalOffset;
    if (image == null || offset == null) return;
    final origin = surfaceGlobalOrigin - offset;
    final dest = Rect.fromLTWH(
      -origin.dx + padding,
      -origin.dy + padding,
      image.width / pixelRatio,
      image.height / pixelRatio,
    );
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      dest,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }
}

/// 在模糊之前对背景叠加遮罩色并可选抵消宿主缩放的 [MiuixBackdrop]。
/// 对应 Kotlin `internal class ScrimBackdrop`。
class MiuixScrimBackdrop extends MiuixBackdrop {
  MiuixScrimBackdrop({
    required MiuixBackdrop backdrop,
    Color scrimColor = const Color(0x00000000),
    double scale = 1.0,
    // ignore: prefer_initializing_formals
  }) : _backdrop = backdrop,
       // ignore: prefer_initializing_formals
       _scrimColor = scrimColor,
       // ignore: prefer_initializing_formals
       _scale = scale {
    _backdrop.addListener(_forward);
  }

  MiuixBackdrop _backdrop;
  Color _scrimColor;
  double _scale;

  MiuixBackdrop get backdrop => _backdrop;
  Color get scrimColor => _scrimColor;
  double get scale => _scale;

  void update({MiuixBackdrop? backdrop, Color? scrimColor, double? scale}) {
    var changed = false;
    if (backdrop != null && !identical(_backdrop, backdrop)) {
      _backdrop.removeListener(_forward);
      _backdrop = backdrop;
      _backdrop.addListener(_forward);
      changed = true;
    }
    if (scrimColor != null && _scrimColor != scrimColor) {
      _scrimColor = scrimColor;
      changed = true;
    }
    if (scale != null && _scale != scale) {
      _scale = scale;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  void _forward() => notifyListeners();

  @override
  bool get isCoordinatesDependent => _backdrop.isCoordinatesDependent;

  @override
  ui.Image? get snapshot => _backdrop.snapshot;

  @override
  Offset? get globalOffset => _backdrop.globalOffset;

  @override
  double get pixelRatio => _backdrop.pixelRatio;

  @override
  bool get hasContent => _backdrop.hasContent;

  @override
  Object? cacheKey(Offset surfaceGlobalOrigin) =>
      (_backdrop.cacheKey(surfaceGlobalOrigin), _scrimColor, _scale);

  @override
  void paintBackdrop(
    Canvas canvas,
    Offset surfaceGlobalOrigin,
    Size surfaceSize,
    double padding,
  ) {
    final fullRect = Rect.fromLTWH(
      0,
      0,
      surfaceSize.width + padding * 2,
      surfaceSize.height + padding * 2,
    );
    final invertScale = _scale > 0.001 && (_scale - 1.0).abs() > 0.0005;
    if (invertScale) {
      final cx = padding + surfaceSize.width / 2;
      final cy = padding + surfaceSize.height / 2;
      canvas.save();
      canvas.translate(cx, cy);
      canvas.scale(1 / _scale, 1 / _scale);
      canvas.translate(-cx, -cy);
      _backdrop.paintBackdrop(
        canvas,
        surfaceGlobalOrigin,
        surfaceSize,
        padding,
      );
      canvas.restore();
    } else {
      _backdrop.paintBackdrop(
        canvas,
        surfaceGlobalOrigin,
        surfaceSize,
        padding,
      );
    }
    if (_scrimColor.a > 0) {
      canvas.drawRect(
        fullRect,
        Paint()
          ..color = _scrimColor
          ..blendMode = BlendMode.srcATop,
      );
    }
  }

  @override
  void dispose() {
    _backdrop.removeListener(_forward);
    super.dispose();
  }
}

/// 按顺序叠加两个 [MiuixBackdrop] 的合成背景（如页面背景 + 一级弹窗快照，或页面 + 渐进模糊顶栏）。
class MiuixCombinedBackdrop extends MiuixBackdrop {
  MiuixCombinedBackdrop({
    required MiuixBackdrop first,
    required MiuixBackdrop second,
    // ignore: prefer_initializing_formals
  }) : _first = first,
       // ignore: prefer_initializing_formals
       _second = second {
    _first.addListener(_forward);
    _second.addListener(_forward);
  }

  MiuixBackdrop _first;
  MiuixBackdrop _second;

  void update({MiuixBackdrop? first, MiuixBackdrop? second}) {
    var changed = false;
    if (first != null && !identical(_first, first)) {
      _first.removeListener(_forward);
      _first = first;
      _first.addListener(_forward);
      changed = true;
    }
    if (second != null && !identical(_second, second)) {
      _second.removeListener(_forward);
      _second = second;
      _second.addListener(_forward);
      changed = true;
    }
    if (changed) notifyListeners();
  }

  void _forward() => notifyListeners();

  @override
  bool get isCoordinatesDependent =>
      _first.isCoordinatesDependent || _second.isCoordinatesDependent;

  @override
  ui.Image? get snapshot => _second.snapshot ?? _first.snapshot;

  @override
  Offset? get globalOffset => _second.globalOffset ?? _first.globalOffset;

  @override
  double get pixelRatio =>
      _second.snapshot != null ? _second.pixelRatio : _first.pixelRatio;

  @override
  bool get hasContent => _first.hasContent || _second.hasContent;

  @override
  Object? cacheKey(Offset surfaceGlobalOrigin) => (
    _first.cacheKey(surfaceGlobalOrigin),
    _second.cacheKey(surfaceGlobalOrigin),
  );

  @override
  void paintBackdrop(
    Canvas canvas,
    Offset surfaceGlobalOrigin,
    Size surfaceSize,
    double padding,
  ) {
    if (_first.hasContent) {
      _first.paintBackdrop(canvas, surfaceGlobalOrigin, surfaceSize, padding);
    }
    if (_second.hasContent) {
      _second.paintBackdrop(canvas, surfaceGlobalOrigin, surfaceSize, padding);
    }
  }

  @override
  void dispose() {
    _first.removeListener(_forward);
    _second.removeListener(_forward);
    super.dispose();
  }
}

/// 通过捕获的图层快照提供背景的 [MiuixBackdrop]。对应 Kotlin `LayerBackdrop`。
///
/// 用 [MiuixLayerBackdropCapture] 包裹背景容器来录制其渲染输出，再把本对象传给
/// 模糊组件。用 [rememberMiuixLayerBackdrop] 或直接 `MiuixLayerBackdrop()` 创建，
/// 需在 dispose 时释放。
class MiuixLayerBackdrop extends MiuixBackdrop {
  MiuixLayerBackdrop();

  @override
  bool get isCoordinatesDependent => true;

  ui.Image? _snapshot;
  Offset? _globalOffset;
  double _pixelRatio = 1.0;
  RenderBox? _capture;

  @override
  ui.Image? get snapshot => _snapshot;

  /// 快照左上角的全局坐标，**读取时**才计算。对应 Kotlin `LayerBackdrop.layerCoordinates`
  /// 在消费者绘制时读 `positionInWindow()`，而不是记录录制那一刻的位置。
  ///
  /// 捕获子树是重绘边界：路由转场、顶栏量完后的内容内缩、滚动都只更新它的图层变换而
  /// 不会重新 paint。若把录制时的坐标冻住，消费者就会按旧原点去采样快照——采样窗口整体
  /// 偏移，落在快照外的部分取到透明，玻璃表面被切成"一半有背景、一半全透"。
  @override
  Offset? get globalOffset {
    final capture = _capture;
    if (capture != null && capture.attached && capture.hasSize) {
      return capture.localToGlobal(Offset.zero);
    }
    return _globalOffset;
  }

  @override
  double get pixelRatio => _pixelRatio;

  /// 由 [MiuixLayerBackdropCapture] 的渲染对象在 attach 时登记自身，供 [globalOffset] 实时取坐标。
  void registerCapture(RenderBox capture) => _capture = capture;

  /// 由 [MiuixLayerBackdropCapture] 的渲染对象在 detach / 换 backdrop 时注销。
  void unregisterCapture(RenderBox capture) {
    if (identical(_capture, capture)) _capture = null;
  }

  /// 由 [MiuixLayerBackdropCapture] 在每帧录制后调用，更新快照与坐标。
  ///
  /// [globalOffset] 只作为捕获节点未挂载时的兜底；正常路径走实时坐标。
  /// 旧快照在替换后被释放（Flutter 的 [ui.Image] 需显式 dispose）。
  void updateSnapshot(ui.Image image, Offset globalOffset, double pixelRatio) {
    final old = _snapshot;
    _snapshot = image;
    _globalOffset = globalOffset;
    _pixelRatio = pixelRatio;
    // 先通知再释放旧图，避免正在使用旧图的绘制被拉黑。
    notifyListeners();
    if (old != null && !identical(old, image)) {
      old.dispose();
    }
  }

  @override
  void dispose() {
    _snapshot?.dispose();
    _snapshot = null;
    super.dispose();
  }
}
