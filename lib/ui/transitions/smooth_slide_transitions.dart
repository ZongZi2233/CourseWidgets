import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:io';
import 'page_blur_controller.dart';

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
    // [v2.9.0 修复] 通透半透磨砂底色：透出底层高斯模糊截图的深度光韵，杜绝死白遮挡前级
    final frostedBg = isDark
        ? const Color(0x3512151B)
        : const Color(0x28FFFFFF);

    Widget transitionChild = SlideTransition(
      position: inSlide,
      child: FadeTransition(
        opacity: inFade,
        child: SlideTransition(
          position: secondarySlide,
          child: ScaleTransition(
            scale: secondaryScale,
            child: (!route.opaque)
                ? DecoratedBox(
                    decoration: BoxDecoration(color: frostedBg),
                    child: child,
                  )
                : child,
          ),
        ),
      ),
    );

    if (route.opaque) {
      // 首页 (opaque=true)：不渲染任何遮罩
      return transitionChild;
    }

    // === 二级/三级页面 (opaque=false) 的转场渲染 ===
    final bool isMobile = Platform.isAndroid || Platform.isIOS;
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
        animation: Listenable.merge([animation, secondaryAnimation, PageBlurController.instance]),
        builder: (context, _) {
          final effectiveAlpha = scrimAnimation.value * secondaryFade.value;
          if (effectiveAlpha <= 0.002) return const SizedBox.shrink();

          if (PageBlurController.instance.hasCapture) {
            return Opacity(
              opacity: effectiveAlpha.clamp(0.0, 1.0),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
                child: RawImage(
                  image: PageBlurController.instance.capturedImage,
                  fit: BoxFit.cover,
                ),
              ),
            );
          }

          // [v2.9.0 修复] 截图尚未就绪时的安全降级：45% 雾化遮罩，兼顾层次与通透感
          final scrimWidget = ColoredBox(
            color: (isDark ? Colors.black : const Color(0xFFF2F4F7))
                .withValues(alpha: effectiveAlpha * 0.45),
          );

          if (!isMobile) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
              child: scrimWidget,
            );
          }
          return scrimWidget;
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
    // [v2.6.0.19] 安卓双弹彻底消灭指南：抛弃任何针对 Android 的手写平滑，强制归宗至系统默认的 ZoomPageTransitionsBuilder
    // 在 main.dart 中我们已经切掉它了。这里仅作兼容保留。
    return const ZoomPageTransitionsBuilder().buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}

/// [v2.5.0] 非不透明路由 — 让退出页面在动画期间可见
/// [v2.7.3] 统一使用底层 BackdropFilter，消除页面层级遮罩与重影
class TransparentMaterialPageRoute<T> extends MaterialPageRoute<T> {
  /// 绑定到主页面内容区的 RepaintBoundary 的 GlobalKey
  /// 在 android_liquid_glass_main.dart 或 schedule_screen.dart 中设置
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
  bool get opaque => false; // 确保不产生白底遮罩

  @override
  Duration get transitionDuration => const Duration(milliseconds: 280);

  @override
  TickerFuture didPush() {
    // [v2.9.0] 触发一次静态模糊截图，供次级转场底层平滑展示，彻底杜绝文字穿透与叠化
    PageBlurController.instance.capture(contentBoundaryKey);
    return super.didPush();
  }

  bool _isPopping = false;

  @override
  bool didPop(T? result) {
    if (_isPopping) return false;
    _isPopping = true;
    // 延迟清除，等动画结束
    Future.delayed(transitionDuration, () {
      PageBlurController.instance.clear();
    });
    return super.didPop(result);
  }
}
