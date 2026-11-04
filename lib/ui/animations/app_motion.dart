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

/// [v3.1.3] 物理速度同步 + FlClash SnapshotWidget 静态光栅冻结的 1D 运动动态模糊组件
///
/// 架构特性：
/// 1. 采用与 [AppCurves.pageSlide] 瞬时速度导数同相位的偏态钟形包络，适度收敛峰值模糊度 (maxBlur ≈ 5.0)；
/// 2. 借鉴 FlClash (`prism_ui`) 核心架构：在动画进行期间开启 [SnapshotWidget] (`SnapshotMode.permissive`)，
///    将运动子树冻结为单张 GPU 静态纹理，消除动画期间子树重绘及 BackdropFilter 采样透明底导致的明暗闪烁；
/// 3. 量化 sigmaX 步进 (0.25px) 并缓存 ImageFilter 实例，落位尾段 (t > 0.88 或 sigmaX < 0.30) 自动关闭离屏层。
class MotionBlurTransition extends StatefulWidget {
  final Animation<double> animation;
  final Widget child;
  final double maxBlur;
  final bool isEntering;

  const MotionBlurTransition({
    super.key,
    required this.animation,
    required this.child,
    this.maxBlur = 5.0,
    this.isEntering = true,
  });

  @override
  State<MotionBlurTransition> createState() => _MotionBlurTransitionState();
}

class _MotionBlurTransitionState extends State<MotionBlurTransition> {
  static final ImageFilter _zeroFilter = ImageFilter.blur(sigmaX: 0.0, sigmaY: 0.0);
  double _lastQuantizedSigma = 0.0;
  ImageFilter _cachedFilter = _zeroFilter;
  late final SnapshotController _snapshotController;

  @override
  void initState() {
    super.initState();
    _snapshotController = SnapshotController(
      allowSnapshotting: widget.animation.isAnimating,
    );
    widget.animation.addStatusListener(_onStatusChanged);
  }

  @override
  void didUpdateWidget(MotionBlurTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      oldWidget.animation.removeStatusListener(_onStatusChanged);
      widget.animation.addStatusListener(_onStatusChanged);
      _updateSnapshotting();
    }
  }

  void _onStatusChanged(AnimationStatus status) {
    _updateSnapshotting();
  }

  void _updateSnapshotting() {
    final moving = widget.animation.isAnimating;
    if (_snapshotController.allowSnapshotting != moving) {
      _snapshotController.allowSnapshotting = moving;
    }
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_onStatusChanged);
    _snapshotController.dispose();
    super.dispose();
  }

  ImageFilter _resolveFilter(double quantizedSigma) {
    if (quantizedSigma <= 0.30) return _zeroFilter;
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
    final snapshotChild = SnapshotWidget(
      controller: _snapshotController,
      mode: SnapshotMode.permissive,
      autoresize: true,
      child: widget.child,
    );

    return AnimatedBuilder(
      animation: widget.animation,
      child: snapshotChild,
      builder: (context, child) {
        final isReversing = widget.animation.status == AnimationStatus.reverse;
        final progress = widget.animation.value.clamp(0.0, 1.0);
        final t = isReversing ? (1.0 - progress) : progress;
        final envelope = AppCurves.velocityBlurEnvelope(t);
        final rawSigma = envelope * widget.maxBlur;
        final quantizedSigma = (rawSigma * 4.0).roundToDouble() * 0.25;
        final bool hasBlur = quantizedSigma > 0.30;

        return ImageFiltered(
          enabled: hasBlur,
          imageFilter: _resolveFilter(quantizedSigma),
          child: child!,
        );
      },
    );
  }
}

/// [v3.1.3] 零 Timer 分配、单 Ticker 物理阻尼平滑的页面切周 1D 运动动态模糊包装器
///
/// 核心性能优化：
/// 1. 恢复细腻丝滑的 1D 水平运动模糊，将默认峰值模糊度收敛至柔和的 3.8px，兼顾灵动速度感与文字清晰度；
/// 2. 采用按需唤醒的原生 [Ticker] 指数阻尼滤波追踪瞬时切页速度，静止时 Ticker 完全休眠 (0 CPU 占用)；
/// 3. 对 sigmaX 进行 0.25px 步进量化并缓存 [ImageFilter]，仅当量化值变化时通知重绘；
/// 4. 配合内部全面静态纹理化的 [HyperOSCard]，彻底杜绝动态模糊期间采样透明底变暗的问题。
class PageControllerMotionBlur extends StatefulWidget {
  final PageController controller;
  final Widget child;
  final double maxBlur;
  final double downscaleFraction;

  const PageControllerMotionBlur({
    super.key,
    required this.controller,
    required this.child,
    this.maxBlur = 3.8,
    this.downscaleFraction = 1.0,
  });

  @override
  State<PageControllerMotionBlur> createState() => _PageControllerMotionBlurState();
}

class _PageControllerMotionBlurState extends State<PageControllerMotionBlur>
    with SingleTickerProviderStateMixin {
  static final ImageFilter _zeroFilter = ImageFilter.blur(sigmaX: 0.0, sigmaY: 0.0);

  late final Ticker _ticker;
  double? _lastPage;
  Duration? _lastTickElapsed;
  double _currentSigma = 0.0;
  double _targetSigma = 0.0;
  double _quantizedSigma = 0.0;
  double _lastFilterSigma = 0.0;
  ImageFilter _cachedFilter = _zeroFilter;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    widget.controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(PageControllerMotionBlur oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
      _lastPage = null;
    }
  }

  void _onScroll() {
    if (!widget.controller.hasClients || !widget.controller.position.hasContentDimensions) {
      return;
    }
    final page = widget.controller.page;
    if (page == null) return;

    if (_lastPage != null) {
      final deltaPage = (page - _lastPage!).abs();
      // 将每帧页位移量映射为柔和的 1D 水平动态模糊强度 (上限受 widget.maxBlur 约束)
      final effectiveMax = math.min(widget.maxBlur, 4.5);
      final velocityFactor = (deltaPage * 22.0).clamp(0.0, 1.0);
      final computed = velocityFactor * effectiveMax;
      if (computed > _targetSigma) {
        _targetSigma = computed;
      }
      if (_targetSigma > 0.25 && !_ticker.isActive) {
        _lastTickElapsed = null;
        _ticker.start();
      }
    }
    _lastPage = page;
  }

  void _onTick(Duration elapsed) {
    final dt = _lastTickElapsed == null
        ? 0.016
        : ((elapsed - _lastTickElapsed!).inMicroseconds / 1000000.0).clamp(0.001, 0.05);
    _lastTickElapsed = elapsed;

    // 目标值自然指数衰减 + 当前值平滑追随
    _targetSigma *= math.exp(-14.0 * dt);
    final lerpRate = (1.0 - math.exp(-22.0 * dt)).clamp(0.0, 1.0);
    _currentSigma += (_targetSigma - _currentSigma) * lerpRate;

    final nextQuantized = _currentSigma < 0.28
        ? 0.0
        : ((_currentSigma * 4.0).roundToDouble() * 0.25);

    if ((nextQuantized - _quantizedSigma).abs() >= 0.20) {
      setState(() {
        _quantizedSigma = nextQuantized;
      });
    }

    if (_currentSigma < 0.22 && _targetSigma < 0.22) {
      _currentSigma = 0.0;
      _targetSigma = 0.0;
      if (_quantizedSigma != 0.0) {
        setState(() {
          _quantizedSigma = 0.0;
        });
      }
      _ticker.stop();
      _lastTickElapsed = null;
    }
  }

  ImageFilter _resolveFilter(double sigma) {
    if (sigma <= 0.28) return _zeroFilter;
    if ((sigma - _lastFilterSigma).abs() < 0.01) {
      return _cachedFilter;
    }
    _lastFilterSigma = sigma;
    _cachedFilter = ImageFilter.blur(
      sigmaX: sigma,
      sigmaY: 0.0,
      tileMode: TileMode.clamp,
    );
    return _cachedFilter;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasBlur = _quantizedSigma > 0.28;
    return ImageFiltered(
      enabled: hasBlur,
      imageFilter: _resolveFilter(_quantizedSigma),
      child: widget.child,
    );
  }
}

/// [v3.1.3] 全面借鉴 FlClash (`chen08209/FlClash` & `prism_ui`) 的主导航切页引擎：
/// 常驻预热页面池 + SnapshotWidget 静态 GPU 纹理冻结 + 速度包络 1D 动态模糊
///
/// 核心突破：
/// 1. 解决“课程页 ↔ 日历页”切页首帧掉帧：首帧渲染完成后自动在后台 Offstage 预热全部主页面并常驻保活，
///    固定 Stack 槽位顺序 `[0, 1, 2]`，切页触发瞬间 **0 Widget 重建、0 Layout 布局、0 Element 重排**；
/// 2. 借鉴 FlClash `SnapshotWidget` (`SnapshotMode.permissive`)：在页面离开静止位（切页动画进行中）时，
///    将进出场页面直接冻结为单张静态 GPU 光栅纹理，彻底消除 Impeller 对移动页面的每帧全量重绘；
/// 3. 恢复细腻丝滑的 1D 运动模糊 (`maxBlur: 4.5`)：在静态纹理快照外层施加水平方向速度导数模糊，
///    既有高速切换的流光动感，又彻底杜绝“先变暗再变亮”闪烁。
class DirectionalMotionBlurSwitcher extends StatefulWidget {
  final int selectedIndex;
  final int pageCount;
  final Widget Function(BuildContext context, int index) builder;
  final Duration duration;
  final Curve curve;
  final double maxBlur;
  final double downscaleFraction;

  const DirectionalMotionBlurSwitcher({
    super.key,
    required this.selectedIndex,
    required this.builder,
    this.pageCount = 3,
    this.duration = const Duration(milliseconds: 360),
    this.curve = AppCurves.pageSlide,
    this.maxBlur = 4.5,
    this.downscaleFraction = 0.45,
  });

  @override
  State<DirectionalMotionBlurSwitcher> createState() =>
      _DirectionalMotionBlurSwitcherState();
}

class _DirectionalMotionBlurSwitcherState
    extends State<DirectionalMotionBlurSwitcher>
    with SingleTickerProviderStateMixin {
  static final ImageFilter _zeroFilter = ImageFilter.blur(sigmaX: 0.0, sigmaY: 0.0);

  late int _currentIndex;
  late int _previousIndex;
  late bool _isForward;
  late AnimationController _controller;
  late Animation<double> _animation;

  final Set<int> _activatedIndices = <int>{};
  final Map<int, SnapshotController> _snapshotControllers =
      <int, SnapshotController>{};
  double _lastQuantizedSigma = 0.0;
  ImageFilter _cachedFilter = _zeroFilter;

  SnapshotController _controllerFor(int index) {
    return _snapshotControllers.putIfAbsent(
      index,
      () => SnapshotController(allowSnapshotting: false),
    );
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.selectedIndex;
    _previousIndex = widget.selectedIndex;
    _isForward = true;
    _activatedIndices.add(_currentIndex);
    _controllerFor(_currentIndex);

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
        _setSnapshottingForTransition(false);
        if (mounted) {
          setState(() {});
        }
      }
    });

    // 首帧渲染完毕后，在下一空闲帧静默预热其余主页面 (如日历页、设置页)，
    // 确保首次点击切换“课程 ↔ 日历”时子树与 Layout 已经 100% 就绪，消除首帧构建卡顿。
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      bool added = false;
      for (int i = 0; i < widget.pageCount; i++) {
        _controllerFor(i);
        if (_activatedIndices.add(i)) {
          added = true;
        }
      }
      if (added) {
        setState(() {});
      }
    });
  }

  void _setSnapshottingForTransition(bool active) {
    for (final entry in _snapshotControllers.entries) {
      final shouldSnapshot = active &&
          (entry.key == _currentIndex || entry.key == _previousIndex);
      if (entry.value.allowSnapshotting != shouldSnapshot) {
        entry.value.allowSnapshotting = shouldSnapshot;
      }
    }
  }

  @override
  void didUpdateWidget(DirectionalMotionBlurSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != _currentIndex) {
      _isForward = widget.selectedIndex > _currentIndex;
      _previousIndex = _currentIndex;
      _currentIndex = widget.selectedIndex;
      _activatedIndices.add(_currentIndex);
      _activatedIndices.add(_previousIndex);
      _controllerFor(_currentIndex);
      _controllerFor(_previousIndex);

      // 开启 FlClash 同款静态纹理快照：运动中的进出场页面直接从单张 GPU 快照绘制
      _setSnapshottingForTransition(true);
      _controller.forward(from: 0.0);
    }
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
  void dispose() {
    _controller.dispose();
    for (final c in _snapshotControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 预先构建固定槽位 [0 .. pageCount - 1] 的页面节点，子组件引用传递给 AnimatedBuilder，
    // 动画全程 0 Subtree Rebuild、0 Element 重排。
    final List<Widget?> pageNodes = List<Widget?>.filled(
      widget.pageCount,
      null,
    );
    for (int i = 0; i < widget.pageCount; i++) {
      if (_activatedIndices.contains(i)) {
        pageNodes[i] = SnapshotWidget(
          key: ValueKey<String>('page_snapshot_$i'),
          controller: _controllerFor(i),
          mode: SnapshotMode.permissive,
          autoresize: true,
          child: RepaintBoundary(
            child: Builder(
              builder: (ctx) => widget.builder(ctx, i),
            ),
          ),
        );
      }
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final bool isAnimating = _controller.isAnimating;
        final double rawT = _controller.value.clamp(0.0, 1.0);
        final double curvedT = _animation.value;
        final double sign = _isForward ? 1.0 : -1.0;

        // 计算物理速度导数包络驱动的 1D 水平运动模糊强度 (0.25px 步进量化)
        final double envelope =
            isAnimating ? AppCurves.velocityBlurEnvelope(rawT) : 0.0;
        final double rawSigma = envelope * widget.maxBlur;
        final double quantizedSigma =
            (rawSigma * 4.0).roundToDouble() * 0.25;
        final bool hasBlur = isAnimating && quantizedSigma > 0.28;
        final ImageFilter activeFilter =
            hasBlur ? _resolveFilter(quantizedSigma) : _zeroFilter;

        return Stack(
          fit: StackFit.expand,
          children: [
            for (int i = 0; i < widget.pageCount; i++)
              if (pageNodes[i] != null)
                _buildPageSlot(
                  index: i,
                  pageNode: pageNodes[i]!,
                  isAnimating: isAnimating,
                  curvedT: curvedT,
                  sign: sign,
                  hasBlur: hasBlur,
                  activeFilter: activeFilter,
                ),
          ],
        );
      },
    );
  }

  Widget _buildPageSlot({
    required int index,
    required Widget pageNode,
    required bool isAnimating,
    required double curvedT,
    required double sign,
    required bool hasBlur,
    required ImageFilter activeFilter,
  }) {
    final bool isCurrent = index == _currentIndex;
    final bool isExiting = isAnimating && index == _previousIndex;
    final bool isVisible = isCurrent || isExiting;

    Offset translation = Offset.zero;
    if (isAnimating) {
      if (isExiting) {
        translation = Offset(-sign * curvedT, 0.0);
      } else if (isCurrent) {
        translation = Offset(sign * (1.0 - curvedT), 0.0);
      }
    }

    return Offstage(
      key: ValueKey<int>(index),
      offstage: !isVisible,
      child: TickerMode(
        enabled: isVisible,
        child: IgnorePointer(
          ignoring: !isCurrent || isAnimating,
          child: FractionalTranslation(
            translation: translation,
            child: ImageFiltered(
              enabled: isVisible && hasBlur,
              imageFilter: activeFilter,
              child: pageNode,
            ),
          ),
        ),
      ),
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
