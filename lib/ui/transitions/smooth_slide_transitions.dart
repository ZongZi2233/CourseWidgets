import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/app_background_layer.dart';
import '../animations/app_motion.dart';

/// 路由专属的 SharedElement 容器形变与预见性返回状态元数据
class _RouteMorphMetadata {
  bool initialized = false;
  Rect? sourceRect;
  double sourceRadius = 22.0;

  /// 当用户通过预见性侧滑手势松手触发返回时，记录松手瞬间的浮窗矩形与圆角，
  /// 使退出动画直接从手指松开处的缩放卡片无缝缩回原始点击组件位置 (sourceRect)
  Rect? dragReleaseRect;
  double? dragReleaseRadius;

  /// 预见性手势实时进度 (0.0 = 未拖拽/全屏, 1.0 = 最大拖拽缩放)
  final ValueNotifier<double> predictiveDragProgress =
      ValueNotifier<double>(0.0);

  void ensureInitialized(Size screenSize) {
    if (initialized || screenSize.isEmpty) return;
    initialized = true;
    final consumed = SharedElementSourceRegistry.consumeSource(screenSize);
    if (consumed != null) {
      sourceRect = consumed.rect;
      sourceRadius = consumed.cornerRadius;
    } else {
      // 若无显式点击源（如快捷键或代码触发推入），采用屏幕中下部灵动胶囊区作为默认展开锚点
      final w = (screenSize.width * 0.76).clamp(180.0, 420.0);
      const h = 64.0;
      sourceRect = Rect.fromCenter(
        center: Offset(screenSize.width * 0.5, screenSize.height * 0.78),
        width: w,
        height: h,
      );
      sourceRadius = 22.0;
    }
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
  static final ImageFilter _zeroFilter =
      ImageFilter.blur(sigmaX: 0.0, sigmaY: 0.0);

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

  // 拖拽速度驱动的 1D 动态模糊状态
  double _lastDragDx = 0.0;
  double _dragBlurSigma = 0.0;
  double _lastQuantizedSigma = 0.0;
  ImageFilter _cachedFilter = _zeroFilter;

  late final AnimationController _cancelReboundController;

  @override
  void initState() {
    super.initState();
    _meta = _metadataForRoute(widget.route);
    WidgetsBinding.instance.addObserver(this);
    widget.animation.addStatusListener(_onRouteAnimationStatus);

    _cancelReboundController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..addListener(() {
        final t = AppCurves.spring.transform(_cancelReboundController.value);
        setState(() {
          _dragCurrentOffset =
              Offset.lerp(_cancelStartOffset, Offset.zero, t) ?? Offset.zero;
          _dragProgress =
              lerpDouble(_cancelStartProgress, 0.0, t)?.clamp(0.0, 1.0) ?? 0.0;
          _meta.predictiveDragProgress.value = _dragProgress;
          _dragBlurSigma =
              AppCurves.velocityBlurEnvelope(_cancelReboundController.value) *
                  3.2;
        });
      })..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _isDraggingBack = false;
            _isCancellingDrag = false;
            _dragCurrentOffset = Offset.zero;
            _dragProgress = 0.0;
            _dragBlurSigma = 0.0;
            _meta.predictiveDragProgress.value = 0.0;
          });
        }
      });
  }

  void _onRouteAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.forward) {
      // 重新进入时清理上次退出遗留的松手矩形
      _meta.dragReleaseRect = null;
      _meta.dragReleaseRadius = null;
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
      _lastDragDx = 0.0;
      _dragBlurSigma = 0.0;
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

    final screenWidth = MediaQuery.sizeOf(context).width;
    final rawDx = curX - _dragStartPos.dx;
    final rawDy = curY - _dragStartPos.dy;
    final signedDx = _swipeEdge == 1
        ? math.min(0.0, rawDx != 0.0 ? rawDx : -rawProgress * screenWidth * 0.45)
        : math.max(0.0, rawDx != 0.0 ? rawDx : rawProgress * screenWidth * 0.45);

    final deltaDx = (signedDx - _lastDragDx).abs();
    _lastDragDx = signedDx;
    final targetBlur = (deltaDx * 0.28).clamp(0.0, 4.2);

    setState(() {
      _dragProgress = math.max(
        rawProgress,
        (signedDx.abs() / math.max(1.0, screenWidth * 0.75)).clamp(0.0, 1.0),
      );
      _dragCurrentOffset = Offset(signedDx, rawDy);
      _dragBlurSigma = (_dragBlurSigma * 0.55 + targetBlur * 0.45).clamp(0.0, 4.2);
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
      _lastDragDx = 0.0;
      _dragBlurSigma = 0.0;
      _meta.predictiveDragProgress.value = 0.0;
    });
  }

  void _onEdgeHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_isDraggingBack || _isCancellingDrag || !mounted) return;
    final screenSize = MediaQuery.sizeOf(context);
    final rawDx = math.max(0.0, details.globalPosition.dx - _dragStartPos.dx);
    final rawDy = details.globalPosition.dy - _dragStartPos.dy;
    final deltaDx = (rawDx - _lastDragDx).abs();
    _lastDragDx = rawDx;
    final targetBlur = (deltaDx * 0.28).clamp(0.0, 4.2);

    setState(() {
      _dragCurrentOffset = Offset(rawDx, rawDy);
      _dragProgress =
          (rawDx / math.max(1.0, screenSize.width * 0.78)).clamp(0.0, 1.0);
      _dragBlurSigma =
          (_dragBlurSigma * 0.55 + targetBlur * 0.45).clamp(0.0, 4.2);
      _meta.predictiveDragProgress.value = _dragProgress;
    });
  }

  void _onEdgeHorizontalDragEnd(DragEndDetails details) {
    if (!_isDraggingBack || _isCancellingDrag || !mounted) return;
    final vx = details.velocity.pixelsPerSecond.dx;
    if (_dragProgress >= 0.22 || vx >= 540.0) {
      _commitPredictivePop();
    } else {
      _startCancelRebound();
    }
  }

  void _startCancelRebound() {
    _isCancellingDrag = true;
    _cancelStartOffset = _dragCurrentOffset;
    _cancelStartProgress = _dragProgress;
    _cancelReboundController.forward(from: 0.0);
  }

  void _commitPredictivePop() {
    final screenSize = MediaQuery.sizeOf(context);
    final currentRect = _computePredictiveDragRect(screenSize);
    final currentRadius = _computePredictiveDragRadius();
    _meta.dragReleaseRect = currentRect;
    _meta.dragReleaseRadius = currentRadius;

    setState(() {
      _isDraggingBack = false;
      _isCancellingDrag = false;
      _dragBlurSigma = 0.0;
      _meta.predictiveDragProgress.value = 0.0;
    });

    widget.route.navigator?.maybePop();
  }

  /// 计算预见性侧滑拖拽期间次级页面的实时缩放与跟手浮窗矩形 (对标 FlClash `drag_back.dart`)
  Rect _computePredictiveDragRect(Size screenSize) {
    final eased = Curves.easeOutCubic.transform(_dragProgress.clamp(0.0, 1.0));
    final scale = lerpDouble(1.0, 0.70, eased)!;
    final w = screenSize.width * scale;
    final h = screenSize.height * scale;

    final baseLeft = (screenSize.width - w) * 0.5;
    final baseTop = (screenSize.height - h) * 0.5;

    final shiftX = _dragCurrentOffset.dx * 0.62;
    final shiftY = (_dragCurrentOffset.dy * 0.28)
        .clamp(-screenSize.height * 0.16, screenSize.height * 0.22);

    return Rect.fromLTWH(baseLeft + shiftX, baseTop + shiftY, w, h);
  }

  double _computePredictiveDragRadius() {
    return lerpDouble(0.0, 28.0, (_dragProgress * 3.2).clamp(0.0, 1.0))!;
  }

  ImageFilter _resolveFilter(double quantizedSigma) {
    if (quantizedSigma <= 0.28) return _zeroFilter;
    if ((quantizedSigma - _lastQuantizedSigma).abs() < 0.01) {
      return _cachedFilter;
    }
    _lastQuantizedSigma = quantizedSigma;
    _cachedFilter = ImageFilter.blur(
      sigmaX: quantizedSigma,
      sigmaY: 0.0,
      tileMode: TileMode.clamp,
    );
    return _cachedFilter;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    _meta.ensureInitialized(screenSize);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 1. 构建次级页面内容并挂载左缘预见性返回手势热区
    final Widget rawPageContent = (!widget.route.opaque)
        ? Stack(
            fit: StackFit.expand,
            children: [
              const AppBackgroundLayer(blur: 0.0, tintColor: Colors.transparent),
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

    return AnimatedBuilder(
      animation: listenable,
      child: interactivePageContent,
      builder: (context, cachedChild) {
        final status = widget.animation.status;
        final isReversing = status == AnimationStatus.reverse;
        final isAnimating = widget.animation.isAnimating;
        final rawT = widget.animation.value.clamp(0.0, 1.0);

        // 2. 计算速度包络 1D 动态模糊 (覆盖：进入动画、所有退出动画、预见性侧滑拖拽与回弹)
        final animBlurT = isReversing ? (1.0 - rawT) : rawT;
        final animSigma = isAnimating
            ? AppCurves.velocityBlurEnvelope(animBlurT) * 4.2
            : 0.0;
        final combinedSigma = math.max(animSigma, _dragBlurSigma);
        final quantizedSigma = (combinedSigma * 4.0).roundToDouble() * 0.25;
        final hasBlur = quantizedSigma > 0.28;

        // 3. 计算次级页面被更上层页面覆盖时的后退微缩 (secondaryAnimation)
        final secRaw = widget.secondaryAnimation.value.clamp(0.0, 1.0);
        final secCurved = AppCurves.pageSlide.transform(secRaw);
        final secondaryScale = lerpDouble(1.0, 0.945, secCurved)!;
        final secondaryDx = lerpDouble(0.0, -screenSize.width * 0.05, secCurved)!;

        // 4. 计算当前容器形变矩形 (currentRect) 与超椭圆圆角 (currentRadius)
        final Rect fullScreenRect = Offset.zero & screenSize;
        final Rect sourceRect = _meta.sourceRect ?? fullScreenRect;
        final double sourceRadius = _meta.sourceRadius;

        Rect currentRect;
        double currentRadius;
        double containerOpacity = 1.0;
        double contentOpacity = 1.0;
        double placeholderVeilAlpha = 0.0;

        if (_isDraggingBack) {
          // 状态 I：用户正在手指拖拽预见性侧滑返回
          currentRect = _computePredictiveDragRect(screenSize);
          currentRadius = _computePredictiveDragRadius();
          containerOpacity = 1.0;
          contentOpacity = 1.0;
        } else if (rawT >= 0.999 && !isAnimating) {
          // 状态 II：次级页面完全展开静止态 (零裁剪、零缩放开销)
          currentRect = fullScreenRect;
          currentRadius = 0.0;
        } else {
          // 状态 III：SharedElement 容器展开 (Push) 或缩回原组件位置 (Pop)
          final double curvedT = (isReversing
                  ? AppCurves.pageSlideReverse
                  : AppCurves.pageSlide)
              .transform(rawT)
              .clamp(0.0, 1.0);

          final Rect openAnchorRect = (isReversing && _meta.dragReleaseRect != null)
              ? _meta.dragReleaseRect!
              : fullScreenRect;
          final double openAnchorRadius =
              (isReversing && _meta.dragReleaseRadius != null)
                  ? _meta.dragReleaseRadius!
                  : 0.0;

          currentRect = Rect.lerp(sourceRect, openAnchorRect, curvedT)!;
          currentRadius =
              lerpDouble(sourceRadius, openAnchorRadius, curvedT)!.clamp(0.0, 44.0);

          if (!isReversing) {
            // 进入时 (Push)：前 18% 快速浮现容器，前 42% 页面内容渐显，源卡片底色平滑消退
            containerOpacity = (rawT / 0.18).clamp(0.0, 1.0);
            contentOpacity =
                Curves.easeOut.transform(((rawT - 0.05) / 0.38).clamp(0.0, 1.0));
            placeholderVeilAlpha = (1.0 - (rawT / 0.36).clamp(0.0, 1.0)) * 0.45;
          } else {
            // 退出时 (Pop - 含按钮返回、系统返回、ESC、侧滑释放)：
            // 缩回原组件位置并在最后 34% 平滑消融回原卡片/按钮
            containerOpacity =
                Curves.easeOutCubic.transform((rawT / 0.34).clamp(0.0, 1.0));
            contentOpacity =
                Curves.easeIn.transform(((rawT - 0.08) / 0.36).clamp(0.0, 1.0));
            placeholderVeilAlpha =
                (1.0 - (rawT / 0.40).clamp(0.0, 1.0)) * 0.35;
          }
        }

        // 5. 构建借鉴 FlClash `_openingFrame` / `_closingFrame` 的无重排等比缩放超椭圆容器
        Widget morphingContainer;
        final bool isFullScreenIdle =
            !_isDraggingBack && !isAnimating && rawT >= 0.999 && secRaw <= 0.001;

        if (isFullScreenIdle) {
          morphingContainer = cachedChild!;
        } else {
          final double scaleX = screenSize.width > 0
              ? (currentRect.width / screenSize.width).clamp(0.05, 1.05)
              : 1.0;

          Widget scaledPage = SizedBox(
            width: screenSize.width,
            height: screenSize.height,
            child: cachedChild,
          );

          if (contentOpacity < 0.999) {
            scaledPage = Opacity(
              opacity: contentOpacity,
              child: scaledPage,
            );
          }

          if (placeholderVeilAlpha > 0.005) {
            final placeholderColor = isDark
                ? const Color(0xFF1E222D)
                : const Color(0xFFF4F6FA);
            scaledPage = Stack(
              fit: StackFit.expand,
              children: [
                scaledPage,
                IgnorePointer(
                  child: ColoredBox(
                    color: placeholderColor.withValues(alpha: placeholderVeilAlpha),
                  ),
                ),
              ],
            );
          }

          Widget clippedCard = ClipRSuperellipse(
            borderRadius: BorderRadius.circular(currentRadius),
            child: OverflowBox(
              alignment: Alignment.topCenter,
              minWidth: currentRect.width,
              maxWidth: currentRect.width,
              minHeight: currentRect.height,
              maxHeight: currentRect.height,
              child: Transform.scale(
                scale: scaleX,
                alignment: Alignment.topCenter,
                child: OverflowBox(
                  alignment: Alignment.topCenter,
                  minWidth: screenSize.width,
                  maxWidth: screenSize.width,
                  minHeight: screenSize.height,
                  maxHeight: screenSize.height,
                  child: scaledPage,
                ),
              ),
            ),
          );

          // 缩放或预见性返回期间为浮窗卡片赋予柔和立体漫反射阴影与微高光描边
          if (currentRadius > 1.5) {
            clippedCard = DecoratedBox(
              decoration: ShapeDecoration(
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(currentRadius),
                  side: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.16)
                        : Colors.white.withValues(alpha: 0.75),
                    width: 0.9,
                  ),
                ),
                shadows: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.42 : 0.16),
                    blurRadius: 28,
                    spreadRadius: -4,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              position: DecorationPosition.foreground,
              child: clippedCard,
            );
          }

          if (containerOpacity < 0.999) {
            clippedCard = Opacity(
              opacity: containerOpacity,
              child: clippedCard,
            );
          }

          morphingContainer = Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fromRect(
                rect: currentRect,
                child: clippedCard,
              ),
            ],
          );
        }

        // 应用二级页面叠加退后变换与 1D 运动模糊
        if (secRaw > 0.001) {
          morphingContainer = Transform.translate(
            offset: Offset(secondaryDx, 0.0),
            child: Transform.scale(
              scale: secondaryScale,
              child: morphingContainer,
            ),
          );
        }

        morphingContainer = ImageFiltered(
          enabled: hasBlur,
          imageFilter: _resolveFilter(quantizedSigma),
          child: morphingContainer,
        );

        if (widget.route.opaque) {
          return morphingContainer;
        }

        // 6. 背景遮罩层 (随打开进度与预见性返回拖拽进度实时平滑明暗过渡)
        final dragDimFactor = (1.0 - _dragProgress * 0.75).clamp(0.0, 1.0);
        final effectiveScrimAlpha =
            rawT * (1.0 - secRaw) * dragDimFactor * (isDark ? 0.42 : 0.22);

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
  Duration get transitionDuration => const Duration(milliseconds: 380);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 340);

  bool _isPopping = false;

  @override
  bool didPop(T? result) {
    if (_isPopping) return true;
    _isPopping = true;
    return super.didPop(result);
  }
}
