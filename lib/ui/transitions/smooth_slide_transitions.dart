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
    // 进入动画：从右边 100% 完全滑入
    final inSlide =
        Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: animation,
            curve: _iosDecelerateCurve,
            reverseCurve: _iosAccelerateCurve,
          ),
        );

    Widget transitionChild = SlideTransition(position: inSlide, child: child);

    // [v2.9.8] 模糊渲染：全平台统一使用 BackdropFilter
    //
    // 为什么不能用 ImageFiltered(RawImage(截图))？
    // 因为它是 Stack 中的兄弟元素，会被滑入的二级页面内容完全遮盖，
    // 用户根本看不到。而 BackdropFilter 作用于渲染树的 **底层背景**，
    // 即透过透明路由(opaque=false)看到的首页内容。
    // 即使二级页面铺满全屏，透过玻璃控件的半透明区域仍能看到模糊效果。
    //
    // 性能：移动端 sigma 降为 10，减少 GPU 采样负担。
    if (route.opaque) {
      // 首页 (opaque=true)：不渲染任何遮罩
      return transitionChild;
    }

    // === 二级/三级页面 (opaque=false) 的转场渲染 ===
    final bool isMobile = Platform.isAndroid || Platform.isIOS;
    // [v2.8.3 性能与视觉重构]
    // 1. 彻底解决“进入三级页面后变暗特别明显”：
    //    此前硬编码 ColoredBox(color: Colors.black26) 在层级推入时会双重/三重叠加大面积变黑。
    //    现改用极清透遮罩 (0.05)，并在 secondaryAnimation（推入下级页面）时自动淡出本级遮罩，保证无论推入多少层画面均保持纯净通透。
    // 2. 彻底解决“切入切出很卡”：
    //    移动端转场滑入期间严禁全屏 BackdropFilter，消除 GPU 逐帧分配 FBO 造成的 120Hz 掉帧。
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
          final effectiveAlpha = scrimAnimation.value * secondaryFade.value * 0.05;
          if (effectiveAlpha <= 0.002) return const SizedBox.shrink();

          final scrimWidget = ColoredBox(
            color: Colors.black.withValues(alpha: effectiveAlpha),
          );

          if (!isMobile) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0),
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
    // [v2.7.2 性能优化] 严禁在转场刚启动时同步捕获 RepaintBoundary 截图（GPU 回读会阻塞 UI 线程导致掉帧）
    // 全平台统一由 SmoothSlideTransitionsBuilder 中的 BackdropFilter 负责背景微模糊
    return super.didPush();
  }

  @override
  bool didPop(T? result) {
    // 延迟清除，等动画结束
    Future.delayed(transitionDuration, () {
      PageBlurController.instance.clear();
    });
    return super.didPop(result);
  }
}
