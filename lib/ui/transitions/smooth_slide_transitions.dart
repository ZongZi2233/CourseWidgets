import 'package:flutter/material.dart';
import '../widgets/app_background_layer.dart';
import '../animations/app_motion.dart';

/// [v3.0.0-alpha14] 自定义页面过渡动画 — iOS/HyperOS 非线性全幅平移与 1D 运动动态模糊
///
/// 进入页面从右侧 100% 滑入，携带瞬时速度衰减的横向 1D 动态模糊
/// 退出页面向左 100% 滑出
/// 非线性贝塞尔曲线: 极速启动 → 平缓柔和减速到位
/// 退出页面轻微暗化增强层次感
class SmoothSlideTransitionsBuilder extends PageTransitionsBuilder {
  const SmoothSlideTransitionsBuilder();

  // [v3.0.0-alpha14] 采用专业级非线性贝塞尔曲线，启动极快、归位极柔
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
    // [v3.0.0-alpha14] 进入动画：从右边 100% 完全滑入，并辅以 0.85->1.0 细腻淡入
    final inSlide =
        Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: animation,
            curve: _iosDecelerateCurve,
            reverseCurve: _iosAccelerateCurve,
          ),
        );

    final inFade = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: animation,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    // [v2.8.9] 次级页面被更深层页面推入覆盖时，当前页面轻微向左平移 (-25%) 并轻微缩放 (0.96)
    final secondarySlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.25, 0.0),
    ).animate(
      CurvedAnimation(
        parent: secondaryAnimation,
        curve: _iosDecelerateCurve,
        reverseCurve: _iosAccelerateCurve,
      ),
    );

    final secondaryScale = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(
      CurvedAnimation(
        parent: secondaryAnimation,
        curve: _iosDecelerateCurve,
        reverseCurve: _iosAccelerateCurve,
      ),
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // [v2.10.0/v3.0.0-alpha23] 二级页面保持全局壁纸纯净清晰（blur: 0.0, tintColor: transparent），
    // 杜绝转场与二级界面的模糊混杂，彻底根除浅色模式下叠加 21% 白色底色导致的转场先变亮再变暗
    final pageContent = (!route.opaque)
        ? Stack(
            fit: StackFit.expand,
            children: [
              const AppBackgroundLayer(blur: 0.0, tintColor: Colors.transparent),
              child,
            ],
          )
        : child;

    // [v3.0.0-alpha18/alpha23] 注入与 AppCurves.pageSlide 物理同频的 18.0px 优雅动态模糊 (避免浅色模式过曝发白)
    Widget transitionChild = MotionBlurTransition(
      animation: animation,
      isEntering: true,
      maxBlur: 18.0,
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
      // 首页 (opaque=true)：不渲染任何遮罩
      return transitionChild;
    }

    // === 二级/三级页面 (opaque=false) 的转场渲染 ===
    final scrimAnimation = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 1.0, curve: Curves.easeIn),
      reverseCurve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    final secondaryFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOut),
    );

    final veil = Positioned.fill(
      child: AnimatedBuilder(
        animation: Listenable.merge([animation, secondaryAnimation]),
        builder: (context, _) {
          final effectiveAlpha = scrimAnimation.value * secondaryFade.value;
          if (effectiveAlpha <= 0.002) return const SizedBox.shrink();

          // 自然暗化遮罩，营造细腻的前后景深
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

/// [v2.5.0] 非不透明路由 — 让退出页面在动画期间可见
/// [v2.9.3] 搭载全局壁纸与单次弹栈锁，彻底根除白屏、进场掉帧与双弹
/// [v3.0.0-alpha23] 继承 PageRoute<T>，彻底根除 Flutter MaterialPageRoute 的 assert(opaque) 崩溃
class TransparentMaterialPageRoute<T> extends PageRoute<T> {
  /// 绑定到主页面内容区的 RepaintBoundary 的 GlobalKey
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
  bool get opaque => false; // 确保不产生原生死白遮罩

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
  Duration get transitionDuration => const Duration(milliseconds: 400);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 360);

  bool _isPopping = false;

  @override
  bool didPop(T? result) {
    if (_isPopping) return true; // [v2.9.3 核心修复] 锁住二次调用，彻底消灭双弹
    _isPopping = true;
    return super.didPop(result);
  }
}


