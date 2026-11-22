import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import '../widgets/app_background_layer.dart';
import '../widgets/windows_desktop_title_bar.dart'
    show kWindowsDesktopTitleBarHeight;
import '../animations/app_motion.dart';

/// 路由专属的 SharedElement 容器形变与预见性返回状态元数据
class _RouteMorphMetadata {
  bool initialized = false;

  /// 全局窗口坐标系下的点击源卡片矩形与圆角
  Rect? globalSourceRect;
  double sourceRadius = 20.0;

  /// 当用户通过预见性侧滑手势松手触发返回时，记录松手瞬间（导航器局部坐标）的浮窗矩形、圆角与手指速度，
  /// 使退出动画直接从手指松开处继承速度并平滑缩回原始点击卡片位置
  Rect? dragReleaseRect;
  double? dragReleaseRadius;
  Offset dragReleaseVelocity = Offset.zero;

  /// 若在入场动画尚未完成时提前返回，记录中断瞬间的局部矩形与进度实现无缝折返
  Rect? interruptFromRect;
  double? interruptFromRadius;
  double? interruptAtValue;

  /// 预见性手势实时进度 (0.0 = 未拖拽/全屏, 1.0 = 最大拖拽缩放)
  final ValueNotifier<double> predictiveDragProgress =
      ValueNotifier<double>(0.0);

  void ensureInitialized(Size windowSize) {
    if (initialized || windowSize.isEmpty) return;
    initialized = true;
    final consumed = SharedElementSourceRegistry.consumeSource(windowSize);
    if (consumed != null) {
      globalSourceRect = consumed.rect;
      final maxRadius =
          (math.min(consumed.rect.width, consumed.rect.height) * 0.36)
              .clamp(12.0, 26.0);
      sourceRadius = consumed.cornerRadius.clamp(12.0, maxRadius);
    }
  }

  /// 将记录的全局窗口源矩形精确映射为当前路由视口（如 Windows 标题栏下方 Navigator）局部坐标
  Rect resolveLocalSourceRect(Size viewportSize, Offset viewportOrigin) {
    if (globalSourceRect != null &&
        viewportSize.width > 0 &&
        viewportSize.height > 0) {
      final shifted = globalSourceRect!.shift(-viewportOrigin);
      final double w = shifted.width.clamp(56.0, viewportSize.width).toDouble();
      final double h =
          shifted.height.clamp(38.0, viewportSize.height * 0.85).toDouble();
      final double left = shifted.left
          .clamp(0.0, math.max(0.0, viewportSize.width - w))
          .toDouble();
      final double top = shifted.top
          .clamp(0.0, math.max(0.0, viewportSize.height - h))
          .toDouble();
      return Rect.fromLTWH(left, top, w, h);
    }

    // 若无显式点击源（如快捷键或代码触发推入），采用标准圆角矩形卡片作为默认展开锚点
    final double w = (viewportSize.width - 32.0).clamp(180.0, 760.0);
    const double h = 64.0;
    return Rect.fromCenter(
      center: Offset(viewportSize.width * 0.5, viewportSize.height * 0.62),
      width: w,
      height: h,
    );
  }
}

final Expando<_RouteMorphMetadata> _routeMorphExpando =
    Expando<_RouteMorphMetadata>('RouteMorphMetadata');

_RouteMorphMetadata _metadataForRoute(PageRoute<dynamic> route) {
  var meta = _routeMorphExpando[route];
  if (meta == null) {
    meta = _RouteMorphMetadata();
    _routeMorphExpando[route] = meta;
  }
  return meta;
}

/// [v3.1.4] 全面借鉴 FlClash (`chen08209/prism_ui` `open_container.dart` & `drag_back.dart`) 的次级页面转场引擎：
/// SharedElement 实际位置超椭圆容器展开/缩回 + 全手势预见性侧滑返回 + 速度包络 1D 动态模糊
///
/// 核心特性：
/// 1. 【从实际点击位置展开与缩回】：自动读取被点击卡片/按钮的真实屏幕 [Rect] 与圆角，
///    进入时从该实际位置平滑超椭圆放大展开至全屏；退出（含左上角返回按钮、系统返回键、Windows ESC、侧滑松手）时
///    平滑缩回该组件的实际屏幕位置并消融；
/// 2. 【修复 1 帧卡死 Bug】：彻底移除外层错误的 SnapshotWidget 静态冻结，内部采用恒定屏幕尺寸 `OverflowBox` +
///    硬件加速 `Transform.scale` + `ClipRSuperellipse`，动画全程 **0 Subtree Relayout**，满帧 120Hz 丝滑运行；
/// 3. 【全场景预见性侧滑返回 (Predictive Back)】：同时接管 Android 14/15/16 系统级预见性返回手势与跨平台左缘侧滑手势，
///    手指滑动时次级页面实时跟手缩小、超椭圆圆角化、露出底层主页并叠加瞬时速度 1D 动态模糊。
class SmoothSlideTransitionsBuilder extends PageTransitionsBuilder {
  const SmoothSlideTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _SharedElementMorphTransition(
      route: route,
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}

class CustomPredictiveSlideTransitionsBuilder extends PageTransitionsBuilder {
  const CustomPredictiveSlideTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _SharedElementMorphTransition(
      route: route,
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}

class _SharedElementMorphTransition extends StatefulWidget {
  final PageRoute<dynamic> route;
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  const _SharedElementMorphTransition({
    required this.route,
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  @override
  State<_SharedElementMorphTransition> createState() =>
      _SharedElementMorphTransitionState();
}

class _SharedElementMorphTransitionState
    extends State<_SharedElementMorphTransition>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static final SpringDescription _cancelReboundSpring =
      SpringDescription.withDurationAndBounce(
        duration: const Duration(milliseconds: 280),
        bounce: 0.08,
      );

  late final _RouteMorphMetadata _meta;

  // 预见性返回手势状态 (同时支持 Android 系统级 Predictive Back 与应用内左缘跟手拖拽)
  bool _isDraggingBack = false;
  bool _isCancellingDrag = false;
  int _swipeEdge = 0; // 0: 左边缘, 1: 右边缘
  Offset _dragStartPos = Offset.zero;
  Offset _dragCurrentOffset = Offset.zero;
  Offset _cancelStartOffset = Offset.zero;
  double _dragProgress = 0.0;
  double _cancelStartProgress = 0.0;

  Size _lastViewportSize = Size.zero;
  Rect? _lastRenderedRect;
  double _lastRenderedRadius = 0.0;

  late final AnimationController _cancelReboundController;

  @override
  void initState() {
    super.initState();
    _meta = _metadataForRoute(widget.route);
    WidgetsBinding.instance.addObserver(this);
    widget.animation.addStatusListener(_onRouteAnimationStatus);

    _cancelReboundController = AnimationController(
      vsync: this,
      lowerBound: -0.25,
      upperBound: 1.25,
      value: 0.0,
    )..addListener(() {
        final double t = _cancelReboundController.value;
        final double clampedProgressT = t.clamp(0.0, 1.0);
        setState(() {
          _dragCurrentOffset =
              Offset.lerp(_cancelStartOffset, Offset.zero, t) ?? Offset.zero;
          _dragProgress =
              lerpDouble(_cancelStartProgress, 0.0, clampedProgressT)
                  ?.clamp(0.0, 1.0) ??
                  0.0;
          _meta.predictiveDragProgress.value = _dragProgress;
        });
      })..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _isDraggingBack = false;
            _isCancellingDrag = false;
            _dragCurrentOffset = Offset.zero;
            _dragProgress = 0.0;
            _meta.predictiveDragProgress.value = 0.0;
          });
        }
      });
  }

  void _onRouteAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.forward) {
      // 重新进入时清理上次退出遗留的松手与中断矩形
      _meta.dragReleaseRect = null;
      _meta.dragReleaseRadius = null;
      _meta.dragReleaseVelocity = Offset.zero;
      _meta.interruptFromRect = null;
      _meta.interruptFromRadius = null;
      _meta.interruptAtValue = null;
    } else if (status == AnimationStatus.completed ||
        status == AnimationStatus.dismissed) {
      _meta.interruptFromRect = null;
      _meta.interruptFromRadius = null;
      _meta.interruptAtValue = null;
      if (status == AnimationStatus.dismissed) {
        _meta.dragReleaseRect = null;
        _meta.dragReleaseRadius = null;
        _meta.dragReleaseVelocity = Offset.zero;
      }
    } else if (status == AnimationStatus.reverse) {
      final rawVal = widget.animation.value;
      if (!_isDraggingBack &&
          _meta.dragReleaseRect == null &&
          rawVal > 0.02 &&
          rawVal < 0.992 &&
          _lastRenderedRect != null) {
        _meta.interruptFromRect = _lastRenderedRect;
        _meta.interruptFromRadius = _lastRenderedRadius;
        _meta.interruptAtValue = rawVal;
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.animation.removeStatusListener(_onRouteAnimationStatus);
    _cancelReboundController.dispose();
    super.dispose();
  }

  bool get _canHandlePredictiveBack {
    if (!mounted) return false;
    final route = widget.route;
    if (!route.isCurrent) return false;
    if (route.isFirst) return false;
    if (widget.animation.status != AnimationStatus.completed) return false;
    return route.navigator?.canPop() ?? false;
  }

  Size _activeViewportSize() {
    if (_lastViewportSize.width > 0 && _lastViewportSize.height > 0) {
      return _lastViewportSize;
    }
    return MediaQuery.sizeOf(context);
  }

  Offset _resolveViewportOrigin(BuildContext context) {
    try {
      final navRo = Navigator.maybeOf(context)?.context.findRenderObject();
      if (navRo is RenderBox && navRo.attached && navRo.hasSize) {
        final origin = navRo.localToGlobal(Offset.zero);
        if (origin.dx.isFinite && origin.dy.isFinite) {
          return origin;
        }
      }
      final ro = context.findRenderObject();
      if (ro is RenderBox && ro.attached && ro.hasSize) {
        final origin = ro.localToGlobal(Offset.zero);
        if (origin.dx.isFinite && origin.dy.isFinite) {
          return origin;
        }
      }
    } catch (_) {}
    return Offset(
      0.0,
      Platform.isWindows ? kWindowsDesktopTitleBarHeight : 0.0,
    );
  }

  // ==================== Android 14/15/16 原生系统级预见性返回手势接管 ====================
  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    if (!_canHandlePredictiveBack) return false;
    _cancelReboundController.stop();
    final touchOffset = backEvent.touchOffset;
    final isRightEdge = backEvent.swipeEdge == SwipeEdge.right;

    setState(() {
      _isDraggingBack = true;
      _isCancellingDrag = false;
      _swipeEdge = isRightEdge ? 1 : 0;
      _dragStartPos = touchOffset ?? Offset.zero;
      _dragCurrentOffset = Offset.zero;
      _dragProgress = 0.0;
      _meta.predictiveDragProgress.value = 0.0;
    });
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) {
    if (!_isDraggingBack || !mounted) return;
    final rawProgress = backEvent.progress.clamp(0.0, 1.0);
    final touchOffset = backEvent.touchOffset;
    final curX = touchOffset?.dx ?? _dragStartPos.dx;
    final curY = touchOffset?.dy ?? _dragStartPos.dy;

    final viewportWidth = _activeViewportSize().width;
    final rawDx = curX - _dragStartPos.dx;
    final rawDy = curY - _dragStartPos.dy;
    final signedDx = _swipeEdge == 1
        ? math.min(0.0, rawDx != 0.0 ? rawDx : -rawProgress * viewportWidth * 0.5)
        : math.max(0.0, rawDx != 0.0 ? rawDx : rawProgress * viewportWidth * 0.5);

    setState(() {
      _dragProgress = math.max(
        rawProgress,
        (signedDx.abs() / math.max(1.0, viewportWidth * 0.72)).clamp(0.0, 1.0),
      );
      _dragCurrentOffset = Offset(signedDx, rawDy);
      _meta.predictiveDragProgress.value = _dragProgress;
    });
  }

  @override
  void handleCommitBackGesture() {
    if (!_isDraggingBack || !mounted) return;
    _commitPredictivePop();
  }

  @override
  void handleCancelBackGesture() {
    if (!_isDraggingBack || !mounted) return;
    _startCancelRebound();
  }

  // ==================== 跨平台左边缘跟手侧滑返回识别 ====================
  void _onEdgeHorizontalDragStart(DragStartDetails details) {
    if (!_canHandlePredictiveBack) return;
    _cancelReboundController.stop();
    setState(() {
      _isDraggingBack = true;
      _isCancellingDrag = false;
      _swipeEdge = 0;
      _dragStartPos = details.globalPosition;
      _dragCurrentOffset = Offset.zero;
      _dragProgress = 0.0;
      _meta.predictiveDragProgress.value = 0.0;
    });
  }

  void _onEdgeHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_isDraggingBack || _isCancellingDrag || !mounted) return;
    final viewportSize = _activeViewportSize();
    final rawDx = math.max(0.0, details.globalPosition.dx - _dragStartPos.dx);
    final rawDy = details.globalPosition.dy - _dragStartPos.dy;

    setState(() {
      _dragCurrentOffset = Offset(rawDx, rawDy);
      _dragProgress =
          (rawDx / math.max(1.0, viewportSize.width * 0.72)).clamp(0.0, 1.0);
      _meta.predictiveDragProgress.value = _dragProgress;
    });
  }

  void _onEdgeHorizontalDragEnd(DragEndDetails details) {
    if (!_isDraggingBack || _isCancellingDrag || !mounted) return;
    final velocity = details.velocity.pixelsPerSecond;
    if (_dragProgress >= 0.20 || velocity.dx >= 420.0) {
      _commitPredictivePop(velocity: velocity);
    } else {
      _startCancelRebound();
    }
  }

  void _startCancelRebound() {
    _isCancellingDrag = true;
    _cancelStartOffset = _dragCurrentOffset;
    _cancelStartProgress = _dragProgress;
    _cancelReboundController.value = 0.0;
    _cancelReboundController.animateWith(
      SpringSimulation(_cancelReboundSpring, 0.0, 1.0, 0.0),
    );
  }

  void _commitPredictivePop({Offset velocity = Offset.zero}) {
    final viewportSize = _activeViewportSize();
    final currentRect = _computePredictiveDragRect(viewportSize);
    final currentRadius = _computePredictiveDragRadius();
    _meta.dragReleaseRect = currentRect;
    _meta.dragReleaseRadius = currentRadius;
    _meta.dragReleaseVelocity = velocity;

    setState(() {
      _isDraggingBack = false;
      _isCancellingDrag = false;
      _meta.predictiveDragProgress.value = 0.0;
    });

    widget.route.navigator?.maybePop();
  }

  /// 双曲橡皮筋物理阻尼跟手限幅：兼顾小幅划动时的灵敏跟手与大距离拖拽的居中稳重感
  double _rubberBand(double delta, double maxLimit) {
    if (delta == 0.0 || maxLimit <= 0.0) return 0.0;
    final sign = delta.sign;
    final damped = delta.abs() * 0.42;
    return sign * maxLimit * (damped / (damped + maxLimit * 0.65));
  }

  /// 计算预见性侧滑拖拽期间次级页面的实时缩放与跟手浮窗矩形（视口局部坐标）
  Rect _computePredictiveDragRect(Size viewportSize) {
    final eased = Curves.easeOutCubic.transform(_dragProgress.clamp(0.0, 1.0));
    final scale = lerpDouble(1.0, 0.82, eased)!;
    final w = viewportSize.width * scale;
    final h = viewportSize.height * scale;

    final baseLeft = (viewportSize.width - w) * 0.5;
    final baseTop = (viewportSize.height - h) * 0.5;

    final maxShiftX = math.min(72.0, viewportSize.width * 0.16);
    final maxShiftY = math.min(44.0, viewportSize.height * 0.07);
    final shiftX = _rubberBand(_dragCurrentOffset.dx, maxShiftX);
    final shiftY = _rubberBand(_dragCurrentOffset.dy, maxShiftY);

    return Rect.fromLTWH(baseLeft + shiftX, baseTop + shiftY, w, h);
  }

  double _computePredictiveDragRadius() {
    return lerpDouble(0.0, 26.0, (_dragProgress * 2.4).clamp(0.0, 1.0))!;
  }

  @override
  Widget build(BuildContext context) {
    final Size windowSize = MediaQuery.sizeOf(context);
    _meta.ensureInitialized(windowSize);
    final Offset viewportOrigin = _resolveViewportOrigin(context);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // 1. 构建次级页面内容并挂载左缘预见性返回手势热区；
    // 非不透明路由内的背景层与主窗口坐标严格像素对齐，消除进出及切换页面时壁纸上下跳动
    final Widget rawPageContent = (!widget.route.opaque)
        ? Stack(
            fit: StackFit.expand,
            children: [
              IgnorePointer(
                child: AppBackgroundLayer(
                  blur: 0.0,
                  tintColor: Colors.transparent,
                  viewportOffset: viewportOrigin,
                ),
              ),
              widget.child,
            ],
          )
        : widget.child;

    final Widget interactivePageContent = Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(child: rawPageContent),
        // 左侧边缘 34px 预见性跟手返回热区（全平台通用，不干扰页面内部列表上下滚动）
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 34,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: _onEdgeHorizontalDragStart,
            onHorizontalDragUpdate: _onEdgeHorizontalDragUpdate,
            onHorizontalDragEnd: _onEdgeHorizontalDragEnd,
            onHorizontalDragCancel: () {
              if (_isDraggingBack) _startCancelRebound();
            },
          ),
        ),
      ],
    );

    final listenable = Listenable.merge([
      widget.animation,
      widget.secondaryAnimation,
      _meta.predictiveDragProgress,
    ]);

    return LayoutBuilder(
      builder: (context, constraints) {
        final Size viewportSize = (constraints.hasBoundedWidth &&
                constraints.hasBoundedHeight &&
                constraints.biggest.width > 0 &&
                constraints.biggest.height > 0)
            ? constraints.biggest
            : Size(
                windowSize.width,
                math.max(1.0, windowSize.height - viewportOrigin.dy),
              );
        _lastViewportSize = viewportSize;

        final Rect fullViewportRect = Offset.zero & viewportSize;
        final Rect sourceRect =
            _meta.resolveLocalSourceRect(viewportSize, viewportOrigin);
        final double sourceRadius = _meta.sourceRadius;

        return AnimatedBuilder(
          animation: listenable,
          child: interactivePageContent,
          builder: (context, cachedChild) {
            final status = widget.animation.status;
            final isReversing = status == AnimationStatus.reverse;
            final isAnimating = widget.animation.isAnimating;
            final rawT = widget.animation.value.clamp(0.0, 1.0);

            // 2. 次级页面被更上层页面覆盖时保持居中景深微缩（0.965），绝不横向偏移导致与点击卡片脱节
            final secRaw = widget.secondaryAnimation.value.clamp(0.0, 1.0);
            final secCurved = AppCurves.pageSlide.transform(secRaw);
            final secondaryScale = lerpDouble(1.0, 0.965, secCurved)!;

            // 3. 计算物理弹簧容器形变边界 (currentRect) 与超椭圆圆角半径 (currentRadius)
            Rect currentRect;
            double currentRadius;
            double containerOpacity = 1.0;
            double sheenAlpha = 0.0;

            if (_isDraggingBack) {
              // 状态 I：用户正在手指拖拽预见性侧滑返回
              currentRect = _computePredictiveDragRect(viewportSize);
              currentRadius = _computePredictiveDragRadius();
              containerOpacity = 1.0;
              sheenAlpha = 0.0;
            } else if (rawT >= 0.999 && !isAnimating) {
              // 状态 II：次级页面完全展开静止态（零裁剪、零缩放、零离屏合成开销）
              currentRect = fullViewportRect;
              currentRadius = 0.0;
            } else if (!isReversing) {
              // 状态 III (Push)：从被点击卡片视口局部位置以临界阻尼物理弹簧展开至全视口
              final double p = AppCurves.sharedElementOpen.transform(rawT);
              final double openWidth = math.max(1.0, fullViewportRect.width);
              final double fromScale =
                  (sourceRect.width / openWidth).clamp(0.10, 1.0);
              final double scale = lerpDouble(fromScale, 1.0, p)!;
              final double unscaledHeight = lerpDouble(
                sourceRect.height / fromScale,
                fullViewportRect.height,
                p,
              )!;
              final double currentWidth = openWidth * scale;
              final double currentHeight = unscaledHeight * scale;
              final Offset currentCenter = Offset.lerp(
                sourceRect.center,
                fullViewportRect.center,
                p,
              )!;
              currentRect = Rect.fromCenter(
                center: currentCenter,
                width: currentWidth,
                height: currentHeight,
              );
              currentRadius = lerpDouble(
                sourceRadius,
                0.0,
                Curves.easeInOutCubic.transform(p),
              )!
                  .clamp(0.0, 28.0);
              containerOpacity = 1.0;
              // 极轻量微晶高光覆盖层替代双层 Opacity saveLayer，0 离屏渲染开销
              final fadeT = (rawT / 0.40).clamp(0.0, 1.0);
              sheenAlpha = (1.0 - Curves.easeOut.transform(fadeT)) *
                  (isDark ? 0.36 : 0.44);
            } else {
              // 状态 IV (Pop / 中断折返 / 拖拽释放惯性回归)：平滑物理弹簧缩回原卡片
              final double activeSpan =
                  (_meta.interruptAtValue ?? 1.0).clamp(0.05, 1.0);
              final double normalizedRawT = (rawT / activeSpan).clamp(0.0, 1.0);
              final double closeT = (1.0 - normalizedRawT).clamp(0.0, 1.0);
              final double p =
                  (1.0 - AppCurves.sharedElementClose.transform(closeT))
                      .clamp(0.0, 1.0);

              final Rect openAnchorRect = _meta.dragReleaseRect ??
                  _meta.interruptFromRect ??
                  fullViewportRect;
              final double openAnchorRadius = _meta.dragReleaseRadius ??
                  _meta.interruptFromRadius ??
                  0.0;

              Rect baseRect = Rect.lerp(sourceRect, openAnchorRect, p)!;
              if (_meta.dragReleaseVelocity != Offset.zero) {
                final double inertiaFactor =
                    closeT * math.pow(1.0 - closeT, 2.2) * 0.08;
                baseRect = baseRect.shift(
                  Offset(
                    (_meta.dragReleaseVelocity.dx * inertiaFactor)
                        .clamp(-42.0, 42.0),
                    (_meta.dragReleaseVelocity.dy * inertiaFactor)
                        .clamp(-28.0, 28.0),
                  ),
                );
              }
              currentRect = baseRect;
              currentRadius =
                  lerpDouble(sourceRadius, openAnchorRadius, p)!.clamp(0.0, 28.0);

              // 仅在贴合原卡片的最后 24% 施加单层 Opacity 消融，此前保持 100% 不透明零 saveLayer
              containerOpacity = Curves.easeOutCubic.transform(
                (normalizedRawT / 0.24).clamp(0.0, 1.0),
              );
              final closeFadeT = (normalizedRawT / 0.38).clamp(0.0, 1.0);
              sheenAlpha = (1.0 - Curves.easeOut.transform(closeFadeT)) *
                  (isDark ? 0.28 : 0.34);
            }

            _lastRenderedRect = currentRect;
            _lastRenderedRadius = currentRadius;

            // 4. 构建零子树重排、单层 OverflowBox + 硬件 Transform.scale 容器
            Widget morphingContainer;
            final bool isFullScreenIdle =
                !_isDraggingBack && !isAnimating && rawT >= 0.999 && secRaw <= 0.001;

            if (isFullScreenIdle) {
              morphingContainer = cachedChild!;
            } else {
              final double scaleX = viewportSize.width > 0
                  ? (currentRect.width / viewportSize.width).clamp(0.05, 1.08)
                  : 1.0;

              final Widget scaledPage = OverflowBox(
                alignment: Alignment.topLeft,
                minWidth: viewportSize.width,
                maxWidth: viewportSize.width,
                minHeight: viewportSize.height,
                maxHeight: viewportSize.height,
                child: Transform.scale(
                  scale: scaleX,
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: viewportSize.width,
                    height: viewportSize.height,
                    child: cachedChild,
                  ),
                ),
              );

              final Widget innerMorphStack = Stack(
                fit: StackFit.expand,
                children: [
                  scaledPage,
                  if (sheenAlpha > 0.005)
                    IgnorePointer(
                      child: ColoredBox(
                        color: (isDark
                                ? const Color(0xFF1E2430)
                                : Colors.white)
                            .withValues(alpha: sheenAlpha),
                      ),
                    ),
                  if (currentRadius > 1.0)
                    IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(currentRadius),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.16)
                                : Colors.white.withValues(alpha: 0.72),
                            width: 0.8,
                          ),
                        ),
                      ),
                    ),
                ],
              );

              Widget cardWidget = ClipRSuperellipse(
                borderRadius: BorderRadius.circular(currentRadius),
                child: innerMorphStack,
              );

              // 背景层绘制轻量化柔和悬浮投影，避免前景 evenOdd 路径细分开销
              if (currentRadius > 1.5) {
                final double shadowFactor =
                    (currentRadius / 24.0).clamp(0.0, 1.0) * rawT;
                if (shadowFactor > 0.01) {
                  cardWidget = DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(currentRadius),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: (isDark ? 0.36 : 0.14) * shadowFactor,
                          ),
                          blurRadius: 24,
                          spreadRadius: -4,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: cardWidget,
                  );
                }
              }

              if (containerOpacity < 0.999) {
                cardWidget = Opacity(
                  opacity: containerOpacity,
                  child: cardWidget,
                );
              }

              morphingContainer = Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fromRect(
                    rect: currentRect,
                    child: cardWidget,
                  ),
                ],
              );
            }

            // 次级页面被覆盖时保持居中 Z 轴退后缩放（无横向偏移）
            if (secRaw > 0.001) {
              morphingContainer = Transform.scale(
                scale: secondaryScale,
                alignment: Alignment.center,
                child: morphingContainer,
              );
            }

            if (widget.route.opaque) {
              return morphingContainer;
            }

            // 5. 背景遮罩层 (随打开进度与预见性返回拖拽进度实时平滑明暗过渡)
            final dragDimFactor = (1.0 - _dragProgress * 0.75).clamp(0.0, 1.0);
            final effectiveScrimAlpha =
                rawT * (1.0 - secRaw) * dragDimFactor * (isDark ? 0.36 : 0.18);

            if (effectiveScrimAlpha <= 0.003) {
              return morphingContainer;
            }

            return Stack(
              fit: StackFit.expand,
              children: [
                IgnorePointer(
                  child: ColoredBox(
                    color: (isDark ? Colors.black : const Color(0xFF141820))
                        .withValues(alpha: effectiveScrimAlpha),
                  ),
                ),
                morphingContainer,
              ],
            );
          },
        );
      },
    );
  }
}

/// [v3.1.4] 非不透明次级路由 — 支持从点击组件实际位置超椭圆展开/缩回、预见性侧滑返回与 1D 动态模糊
class TransparentMaterialPageRoute<T> extends PageRoute<T> {
  static final GlobalKey contentBoundaryKey = GlobalKey(
    debugLabel: 'contentBoundary',
  );

  final WidgetBuilder builder;

  TransparentMaterialPageRoute({
    required this.builder,
    super.settings,
    this.maintainState = true,
    super.fullscreenDialog,
    super.allowSnapshotting = false,
    super.barrierDismissible = false,
  });

  @override
  final bool maintainState;

  @override
  bool get opaque => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  TickerFuture didPush() {
    // 路由入栈瞬间锁定最近一次点击的组件矩形
    final view = PlatformDispatcher.instance.implicitView;
    if (view != null && view.physicalSize.width > 0) {
      final logicalSize = view.physicalSize / view.devicePixelRatio;
      _metadataForRoute(this).ensureInitialized(logicalSize);
    }
    return super.didPush();
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final PageTransitionsTheme theme = Theme.of(context).pageTransitionsTheme;
    return theme.buildTransitions<T>(
      this,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }

  @override
  Duration get transitionDuration => const Duration(milliseconds: 360);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 320);

  bool _isPopping = false;

  @override
  bool didPop(T? result) {
    if (_isPopping) return true;
    _isPopping = true;
    return super.didPop(result);
  }
}
