import 'package:flutter/material.dart';
import '../widgets/app_background_layer.dart';

/// [v2.5.0] 自定义页面过渡动画 — iOS 非线性全幅平移
///
/// 进入页面从右侧 100% 滑入
/// 退出页面向左 100% 滑出
/// iOS UIKit 风格非线性曲线: 快速启动 → 平缓减速
/// 退出页面轻微暗化增强层次感
class SmoothSlideTransitionsBuilder extends PageTransitionsBuilder {
  const SmoothSlideTransitionsBuilder();

  // [v2.5.0] 改用更强烈的非线性曲线，让启动更快、停止更平滑
  static const _iosDecelerateCurve = Curves.fastOutSlowIn;
  static const _iosAccelerateCurve = Curves.fastOutSlowIn;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // [v2.8.6] 进入动画：从右边 100% 完全滑入，并辅以 0.85->1.0 细腻淡入，消除画面硬切
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

    // [v2.8.9] 次级页面被更深层页面推入覆盖时，当前页面轻微向左平移 (-25%) 并轻微缩放 (0.96)，营造细腻的 iOS/HyperOS 景深层次感
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

    // [v2.9.3 核心升级] 二级页面直接挂载全局动态壁纸与清润亚克力景深，彻底告别死白与截图卡顿
    final pageContent = (!route.opaque)
        ? Stack(
            fit: StackFit.expand,
            children: [
              const AppBackgroundLayer(blur: 16.0),
              child,
            ],
          )
        : child;

    Widget transitionChild = SlideTransition(
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
class TransparentMaterialPageRoute<T> extends MaterialPageRoute<T> {
  /// 绑定到主页面内容区的 RepaintBoundary 的 GlobalKey
  static final GlobalKey contentBoundaryKey = GlobalKey(
    debugLabel: 'contentBoundary',
  );

  TransparentMaterialPageRoute({
    required super.builder,
    super.settings,
    super.maintainState,
    super.fullscreenDialog,
  });

  @override
  bool get opaque => false; // 确保不产生原生死白遮罩

  @override
  Duration get transitionDuration => const Duration(milliseconds: 280);

  bool _isPopping = false;

  @override
  bool didPop(T? result) {
    if (_isPopping) return true; // [v2.9.3 核心修复] 锁住二次调用，彻底消灭双弹
    _isPopping = true;
    return super.didPop(result);
  }
}

