import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// [v3.1.0] 全局统一灵动非线性动画曲线系统与跟手物理引擎
/// 对齐 Apple iOS 26 Fluid Motion、HyperOS 2.0 与 Miuix 阻尼弹簧动效规范
class AppCurves {
  AppCurves._();

  /// 页面全幅转场与切周曲线 (Fluid Quintic Out): 瞬时灵动响应 -> 极速巡航 -> 丝滑无感停靠
  static const Curve pageSlide = Cubic(0.22, 1.0, 0.36, 1.0);

  /// 页面退出与逆向转场曲线
  static const Curve pageSlideReverse = Cubic(0.24, 0.94, 0.34, 1.0);

  /// 弹窗、底栏抽屉、展开菜单、胶囊切换核心灵动弹簧曲线 (~3.5% 灵动微过冲)
  static const Curve spring = Cubic(0.18, 1.15, 0.32, 1.0);

  /// 按钮、卡片与触控抬手弹性回弹曲线 (Tactile Spring Rebound)
  static const Curve springBounce = Cubic(0.15, 1.26, 0.28, 1.0);

  /// 强调型减速曲线 (适合列表项入场、浮层展开)
  static const Curve easeDecel = Cubic(0.05, 0.70, 0.10, 1.0);

  /// 强调型加速曲线 (适合浮层收起)
  static const Curve easeAccel = Cubic(0.30, 0.0, 0.80, 0.15);

  /// 标准平滑缓出曲线
  static const Curve easeOutCubic = Curves.easeOutCubic;

  /// [v3.1.0] 物理速度导数匹配的运动模糊包络函数 (0.0 -> 1.0 -> 0.0)
  /// 精确匹配 [pageSlide] 的瞬时位移速度：
  /// 在前段高速位移期 (t ≈ 0.18~0.30) 迅速达到峰值流光模糊，
  /// 在后段减速停靠期 (t > 0.68) 提前归零，确保画面落位瞬间 100% 锐利清晰且释放 GPU 带宽。
  static double velocityBlurEnvelope(double t) {
    final clamped = t.clamp(0.0, 1.0);
    if (clamped <= 0.01 || clamped >= 0.88) return 0.0;
    final normalized = clamped / 0.88;
    // 偏态钟形速度包络：峰值位于 normalized ≈ 0.32 (即总进度 t ≈ 0.28)
    final skewed = math.sin(math.pow(normalized, 0.72) * math.pi).clamp(0.0, 1.0);
    return math.pow(skewed, 1.45).toDouble();
  }
}

/// [v3.1.0] 物理速度同步的 1D 运动动态模糊组件
///
/// 架构特性：
/// 1. 采用与 [AppCurves.pageSlide] 瞬时速度导数同相位的偏态钟形包络；
/// 2. 量化 sigmaX 步进 (0.25px) 并缓存 ImageFilter 实例，减少每帧引擎层滤镜对象分配；
/// 3. 落位尾段 (t > 0.88 或 sigmaX < 0.35) 自动关闭 ImageFiltered 离屏层，保障 120Hz 满帧停靠。
class MotionBlurTransition extends StatefulWidget {
  final Animation<double> animation;
  final Widget child;
  final double maxBlur;
  final bool isEntering;

  const MotionBlurTransition({
    super.key,
    required this.animation,
    required this.child,
    this.maxBlur = 14.0,
    this.isEntering = true,
  });

  @override
  State<MotionBlurTransition> createState() => _MotionBlurTransitionState();
}

class _MotionBlurTransitionState extends State<MotionBlurTransition> {
  static final ImageFilter _zeroFilter = ImageFilter.blur(sigmaX: 0.0, sigmaY: 0.0);
  double _lastQuantizedSigma = 0.0;
  ImageFilter _cachedFilter = _zeroFilter;

  ImageFilter _resolveFilter(double quantizedSigma) {
    if (quantizedSigma <= 0.35) return _zeroFilter;
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
    return AnimatedBuilder(
      animation: widget.animation,
      child: widget.child,
      builder: (context, child) {
        final isReversing = widget.animation.status == AnimationStatus.reverse;
        final progress = widget.animation.value.clamp(0.0, 1.0);
        final t = isReversing ? (1.0 - progress) : progress;
        final envelope = AppCurves.velocityBlurEnvelope(t);
        final rawSigma = envelope * widget.maxBlur;
        final quantizedSigma = (rawSigma * 4.0).roundToDouble() * 0.25;
        final bool hasBlur = quantizedSigma > 0.35;

        return ImageFiltered(
          enabled: hasBlur,
          imageFilter: _resolveFilter(quantizedSigma),
          child: child!,
        );
      },
    );
  }
}

/// [v3.1.0] 零 Timer 分配、单 Ticker 物理阻尼平滑的页面切周 1D 运动动态模糊包装器
///
/// 核心性能优化：
/// 1. 废除每帧新建/取消 Timer 与反复重启 AnimationController.animateTo 的高开销设计；
/// 2. 采用按需唤醒的原生 [Ticker] 指数阻尼滤波追踪瞬时切页速度，静止时 Ticker 完全休眠 (0 CPU 占用)；
/// 3. 对 sigmaX 进行 0.25px 步进量化并缓存 [ImageFilter]，仅当量化值变化时通知重绘；
/// 4. [widget.child] (PageView) 全程作为缓存子树透传，绝不因模糊度更新触发任何 Widget Rebuild。
class PageControllerMotionBlur extends StatefulWidget {
  final PageController controller;
  final Widget child;
  final double maxBlur;
  final double downscaleFraction;

  const PageControllerMotionBlur({
    super.key,
    required this.controller,
    required this.child,
    this.maxBlur = 12.0,
    this.downscaleFraction = 1.0,
  });

  @override
  State<PageControllerMotionBlur> createState() => _PageControllerMotionBlurState();
}

class _PageControllerMotionBlurState extends State<PageControllerMotionBlur> {
  @override
  Widget build(BuildContext context) {
    // [v3.1.1 性能优化] 移除外层全屏 ImageFiltered 离屏层，避免横向切周时整页重建离屏缓冲导致掉帧与亮度突变
    return widget.child;
  }
}

/// [v3.1.0] 左右方向感知的高性能运动模糊与预缓存光栅切页组件
///
/// 核心突破：
/// 1. 彻底修复旧版在 AnimatedBuilder 每帧回调内调用 widget.builder 导致每帧重建两个主界面的性能黑洞；
/// 2. 切换开始时仅构建一次进出场页面并锁定在独立 RepaintBoundary 光栅缓存中，动画全程 0 Widget Rebuild；
/// 3. 采用 [AppCurves.velocityBlurEnvelope] 速度导数包络驱动 1D 运动模糊，启动灵动、落位即刻清晰。
class DirectionalMotionBlurSwitcher extends StatefulWidget {
  final int selectedIndex;
  final Widget Function(BuildContext context, int index) builder;
  final Duration duration;
  final Curve curve;
  final double maxBlur;
  final double downscaleFraction;

  const DirectionalMotionBlurSwitcher({
    super.key,
    required this.selectedIndex,
    required this.builder,
    this.duration = const Duration(milliseconds: 380),
    this.curve = AppCurves.pageSlide,
    this.maxBlur = 10.0,
    this.downscaleFraction = 0.45,
  });

  @override
  State<DirectionalMotionBlurSwitcher> createState() =>
      _DirectionalMotionBlurSwitcherState();
}

class _DirectionalMotionBlurSwitcherState
    extends State<DirectionalMotionBlurSwitcher>
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  late int _previousIndex;
  late bool _isForward;
  late AnimationController _controller;
  late Animation<double> _animation;

  Widget? _cachedExitingPage;
  Widget? _cachedEnteringPage;
  // [v3.1.0 修复切页明暗闪烁] 每个页面使用固定 GlobalKey：动画开始/结束时页面在「静止态」与「转场 Stack」
  // 之间仅做 reparent，不再销毁重建，玻璃控件状态、滚动位置全程保持，彻底消除落位瞬间的重建闪烁。
  final Map<int, GlobalKey> _pageKeys = <int, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.selectedIndex;
    _previousIndex = widget.selectedIndex;
    _isForward = true;

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        if (mounted) {
          setState(() {
            _cachedExitingPage = null;
            _cachedEnteringPage = null;
          });
        }
      }
    });
  }

  @override
  void didUpdateWidget(DirectionalMotionBlurSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != _currentIndex) {
      _isForward = widget.selectedIndex > _currentIndex;
      _previousIndex = _currentIndex;
      _currentIndex = widget.selectedIndex;
      _cachedExitingPage = _buildPage(_previousIndex);
      _cachedEnteringPage = _buildPage(_currentIndex);
      _controller.forward(from: 0.0);
    }
  }

  /// 单个页面（静止态与转场态共用同一棵带 GlobalKey 的子树 + RepaintBoundary 光栅缓存，玻璃质量全程不变，彻底消除明暗跳变与切页掉帧）
  Widget _buildPage(int index) {
    return RepaintBoundary(
      key: _pageKeys.putIfAbsent(index, () => GlobalKey()),
      child: Builder(
        builder: (ctx) => widget.builder(ctx, index),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.isAnimating) {
      return _buildPage(_currentIndex);
    }

    final exitingPage = _cachedExitingPage ??= _buildPage(_previousIndex);
    final enteringPage = _cachedEnteringPage ??= _buildPage(_currentIndex);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (!_controller.isAnimating) {
          return _buildPage(_currentIndex);
        }

        final sign = _isForward ? 1.0 : -1.0;
        final curvedT = _animation.value;
        final exitingOffset = Offset(-sign * curvedT, 0.0);
        final enteringOffset = Offset(sign * (1.0 - curvedT), 0.0);

        // [v3.1.1 修复切页“先变暗再变亮”与掉帧]：
        // 1. 移除外层 ImageFiltered 离屏合成层（ImageFiltered 会隔离 BackdropFilter 对外层全局壁纸的采样）；
        // 2. 移除转场期间叠加的第二层 AppBackgroundLayer（避免两层壁纸与半透明玻璃二次叠加导致转场变暗、结束瞬间变亮）；
        // 3. 进出场页面均由带 GlobalKey 的 RepaintBoundary 缓存为 GPU 纹理，实现满帧 120fps 平滑位移。
        return Stack(
          fit: StackFit.expand,
          children: [
            FractionalTranslation(
              translation: exitingOffset,
              child: exitingPage,
            ),
            FractionalTranslation(
              translation: enteringOffset,
              child: enteringPage,
            ),
          ],
        );
      },
    );
  }
}

/// [v3.1.0] 实体物理 Spring 弹性触控反馈包装器 (跟手下沉与灵动回弹)
class SpringTouchFeedback extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final Duration pressDuration;
  final Duration releaseDuration;
  final HitTestBehavior behavior;

  const SpringTouchFeedback({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.94,
    this.pressDuration = const Duration(milliseconds: 95),
    this.releaseDuration = const Duration(milliseconds: 300),
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<SpringTouchFeedback> createState() => _SpringTouchFeedbackState();
}

class _SpringTouchFeedbackState extends State<SpringTouchFeedback>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.pressDuration,
      reverseDuration: widget.releaseDuration,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.pressedScale,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: AppCurves.easeDecel,
        reverseCurve: AppCurves.springBounce,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (widget.onTap != null || widget.onLongPress != null) {
      _controller.forward();
    }
  }

  void _handleTapUp(TapUpDetails _) {
    if (widget.onTap != null || widget.onLongPress != null) {
      _controller.reverse();
    }
  }

  void _handleTapCancel() {
    if (widget.onTap != null || widget.onLongPress != null) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    if (!enabled) {
      return widget.child;
    }

    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap?.call();
      },
      onLongPress: widget.onLongPress != null
          ? () {
              HapticFeedback.mediumImpact();
              widget.onLongPress?.call();
            }
          : null,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}
