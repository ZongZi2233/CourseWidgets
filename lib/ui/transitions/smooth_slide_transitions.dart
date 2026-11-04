import 'package:flutter/material.dart';
import '../widgets/app_background_layer.dart';
import '../animations/app_motion.dart';

/// [v3.1.0] 自定义页面过渡动画 — iOS/HyperOS 非线性全幅平移与速度导数同步 1D 运动动态模糊
class SmoothSlideTransitionsBuilder extends PageTransitionsBuilder {
  const SmoothSlideTransitionsBuilder();

  static const _iosDecelerateCurve = AppCurves.pageSlide;
  static const _iosAccelerateCurve = AppCurves.pageSlideReverse;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final inSlide =
        Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: animation,
            curve: _iosDecelerateCurve,
            reverseCurve: _iosAccelerateCurve,
          ),
        );

    final inFade = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: animation,
        curve: const Interval(0.0, 0.45, curve: AppCurves.easeDecel),
      ),
    );

    final secondarySlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.24, 0.0),
    ).animate(
      CurvedAnimation(
        parent: secondaryAnimation,
        curve: _iosDecelerateCurve,
        reverseCurve: _iosAccelerateCurve,
      ),
    );

    final secondaryScale = Tween<double>(
      begin: 1.0,
      end: 0.965,
    ).animate(
      CurvedAnimation(
        parent: secondaryAnimation,
        curve: _iosDecelerateCurve,
        reverseCurve: _iosAccelerateCurve,
      ),
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final pageContent = (!route.opaque)
        ? Stack(
            fit: StackFit.expand,
            children: [
              const AppBackgroundLayer(blur: 0.0, tintColor: Colors.transparent),
              child,
            ],
          )
        : child;

    Widget transitionChild = MotionBlurTransition(
      animation: animation,
      isEntering: true,
      maxBlur: 5.0,
      child: SlideTransition(
        position: inSlide,
        child: FadeTransition(
          opacity: inFade,
          child: SlideTransition(
            position: secondarySlide,
            child: ScaleTransition(
              scale: secondaryScale,
              child: RepaintBoundary(child: pageContent),
            ),
          ),
        ),
      ),
    );

    if (route.opaque) {
      return transitionChild;
    }

    final scrimAnimation = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 1.0, curve: AppCurves.easeDecel),
      reverseCurve: const Interval(0.0, 0.65, curve: AppCurves.easeAccel),
    );

    final secondaryFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: secondaryAnimation, curve: AppCurves.easeDecel),
    );

    final veil = Positioned.fill(
      child: AnimatedBuilder(
        animation: Listenable.merge([animation, secondaryAnimation]),
        builder: (context, _) {
          final effectiveAlpha = scrimAnimation.value * secondaryFade.value;
          if (effectiveAlpha <= 0.002) return const SizedBox.shrink();

          return ColoredBox(
            color: (isDark ? Colors.black : const Color(0xFF1E2129))
                .withValues(alpha: effectiveAlpha * (isDark ? 0.35 : 0.18)),
          );
        },
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [veil, transitionChild],
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
    return const SmoothSlideTransitionsBuilder().buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}

/// [v3.1.0] 非不透明路由 — 全平台统一 380ms/330ms 旗舰非线性平移动画与速度同步 1D 动态模糊
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
    super.allowSnapshotting = true,
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
    return theme.buildTransitions<T>(this, context, animation, secondaryAnimation, child);
  }

  @override
  Duration get transitionDuration => const Duration(milliseconds: 380);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 330);

  bool _isPopping = false;

  @override
  bool didPop(T? result) {
    if (_isPopping) return true;
    _isPopping = true;
    return super.didPop(result);
  }
}
