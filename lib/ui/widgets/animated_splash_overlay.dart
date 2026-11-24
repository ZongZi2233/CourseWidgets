import 'dart:async';
import 'dart:io';
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../../main.dart' show globalDarkModeNotifier;
import '../../providers/schedule_provider.dart';
import '../../services/static_blur_service.dart';
import '../animations/app_motion.dart';
import '../theme/squircle_geometry.dart';
import 'zero_flicker_splash_preloader.dart';

/// [v3.1.8] 秒开开屏加载动画与主界面并行渲染就绪门 (AnimatedSplashOverlay)
///
/// 核心特性：
/// 1. 【第0帧秒开】：在桌面端首次启动时首帧仅渲染极轻量的 [ZeroFlickerSplashPreloader]，
///    待首帧光栅化落盘并显示窗口后立即在开屏背后延迟挂载重型主界面（避免重组件/着色器阻塞首帧）；
/// 2. 【并行预渲染】：底层并行唤醒真实主界面（SQLite 数据装载、字体、着色器、静态壁纸模糊烘焙）；
/// 3. 【真实可视计时】：680ms 最小品牌动效时长从窗口真正可见那一刻开始计时，绝不在隐藏阶段提前消耗；
/// 4. 【零重建平滑揭晓】：淡出卸载时保持底层 `widget.child` 始终位于 Stack 同槽位，零闪烁零重建。
class AnimatedSplashOverlay extends StatefulWidget {
  final Widget child;
  final ValueNotifier<bool>? startupReadyNotifier;
  final bool deferChildUntilFirstFrame;
  final Future<void> Function()? onSplashShown;

  const AnimatedSplashOverlay({
    super.key,
    required this.child,
    this.startupReadyNotifier,
    this.deferChildUntilFirstFrame = false,
    this.onSplashShown,
  });

  @override
  State<AnimatedSplashOverlay> createState() => _AnimatedSplashOverlayState();
}

class _AnimatedSplashOverlayState extends State<AnimatedSplashOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  bool _isDismissed = false;
  bool _isGatePassed = false;
  late bool _childMounted;
  DateTime _visibleStartTime = DateTime.now();

  Timer? _safetyTimer;
  ScheduleProvider? _scheduleProvider;

  @override
  void initState() {
    super.initState();
    _childMounted = !widget.deferChildUntilFirstFrame;

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeOutCubic,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.035).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeOutCubic,
      ),
    );

    _fadeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() {
            _isDismissed = true;
          });
        }
      }
    });

    // 建立对静态壁纸模糊服务的监听
    StaticBlurredWallpaperService.instance.addListener(_onBlurServiceChanged);
    widget.startupReadyNotifier?.addListener(_onStartupReadyChanged);

    // 安全超时保护：若后台数据或着色器异常，2500ms 强制开门揭晓主界面，确保永远不卡死
    _safetyTimer = Timer(const Duration(milliseconds: 2500), () {
      _triggerDismiss();
    });

    if (widget.deferChildUntilFirstFrame) {
      // 等待极轻量开屏第 1 帧完成 GPU 光栅化并显示窗口后，再开始计时并在幕后挂载主工作区
      unawaited(
        WidgetsBinding.instance.waitUntilFirstFrameRasterized.then((_) async {
          if (!mounted) return;
          if (widget.onSplashShown != null) {
            await widget.onSplashShown!();
          }
          if (!mounted) return;
          _visibleStartTime = DateTime.now();
          setState(() {
            _childMounted = true;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkReadiness();
          });
        }),
      );
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkReadiness();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = Provider.of<ScheduleProvider>(context, listen: false);
    if (_scheduleProvider != provider) {
      _scheduleProvider?.removeListener(_onProviderChanged);
      _scheduleProvider = provider;
      _scheduleProvider?.addListener(_onProviderChanged);
    }
  }

  void _onProviderChanged() {
    _checkReadiness();
  }

  void _onBlurServiceChanged() {
    _checkReadiness();
  }

  void _onStartupReadyChanged() {
    _checkReadiness();
  }

  /// 综合判定渲染与数据准备完成度
  void _checkReadiness() {
    if (_isGatePassed || !mounted || !_childMounted) return;

    final provider = _scheduleProvider;
    final isStartupReady = widget.startupReadyNotifier?.value ?? true;
    final isDataReady =
        isStartupReady && provider != null && !provider.isLoading;

    // [v3.1.4] 后台启动任务与数据加载完毕后放行开屏门禁
    if (isDataReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _triggerDismiss();
        }
      });
    }
  }

  void _triggerDismiss() {
    if (_isGatePassed || !mounted) return;
    if (!_childMounted) {
      setState(() {
        _childMounted = true;
      });
    }
    _isGatePassed = true;
    _safetyTimer?.cancel();

    // 确保在窗口真正显示后至少呈现简洁丝滑的品牌开屏动效 220ms，兼顾极速冷启动与零闪跳
    final elapsedMs =
        DateTime.now().difference(_visibleStartTime).inMilliseconds;
    final remainingMs = 220 - elapsedMs;

    if (remainingMs > 0) {
      Future.delayed(Duration(milliseconds: remainingMs), () {
        if (mounted) {
          _fadeController.forward();
        }
      });
    } else {
      _fadeController.forward();
    }
  }

  @override
  void dispose() {
    _safetyTimer?.cancel();
    _scheduleProvider?.removeListener(_onProviderChanged);
    widget.startupReadyNotifier?.removeListener(_onStartupReadyChanged);
    StaticBlurredWallpaperService.instance.removeListener(_onBlurServiceChanged);
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    // 保持底层 widget.child 始终在 Stack 槽位 0，防止开屏卸载时销毁重建导航树造成二次闪烁
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_childMounted)
          widget.child
        else
          const SizedBox.expand(),
        if (!_isDismissed)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _fadeController,
              builder: (context, child) {
                return IgnorePointer(
                  ignoring: _isGatePassed,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          const ZeroFlickerSplashPreloader(),
                          if (isDesktop)
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              height: 36,
                              child: DragToMoveArea(
                                child: const SizedBox.expand(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// [v3.2.2] 移动端 GPU 零掉帧优雅开屏揭晓过渡层
///
/// 无缝承接原生单层开屏画面（零拉伸模糊、精确色彩 #F6F8FC / #0D0F14 对齐），
/// 仅采用纯硬件合成的 Transform + Opacity 完成紧凑高清 Logo 轻柔上浮消隐与主界面沉稳入场，
/// 彻底规避 BackdropFilter 渲染峰值与任何跳帧问题。
class AndroidSplashRevealOverlay extends StatefulWidget {
  final Widget child;
  final VoidCallback? onCompleted;

  const AndroidSplashRevealOverlay({
    super.key,
    required this.child,
    this.onCompleted,
  });

  @override
  State<AndroidSplashRevealOverlay> createState() =>
      _AndroidSplashRevealOverlayState();
}

class _AndroidSplashRevealOverlayState extends State<AndroidSplashRevealOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _revealController;
  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 440),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() {
            _isDismissed = true;
          });
          widget.onCompleted?.call();
        }
      });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_revealController.isAnimating && !_isDismissed) {
        _revealController.forward();
      }
    });
  }

  @override
  void dispose() {
    _revealController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = globalDarkModeNotifier.value;
    final bgColor = isDark ? const Color(0xFF0D0F14) : const Color(0xFFF6F8FC);
    final preloaded = preloadedSplashUiImage;

    final Widget logoCore = ClipRSuperellipse(
      borderRadius: BorderRadius.circular(20),
      child: preloaded != null
          ? RawImage(
              image: preloaded,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            )
          : Image(
              image: kSplashIconProvider,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.high,
            ),
    );

    final Widget splashArtwork = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: SquircleGeometry.smoothRadius(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.34 : 0.10),
                blurRadius: 24,
                spreadRadius: -3,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: logoCore,
        ),
        const SizedBox(height: 18),
        Text(
          'CourseWidgets',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF14171F),
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );

    return AnimatedBuilder(
      animation: _revealController,
      child: widget.child,
      builder: (context, cachedChild) {
        final rawT = _revealController.value.clamp(0.0, 1.0);
        final double childScale = _isDismissed
            ? 1.0
            : lerpDouble(
                0.978,
                1.0,
                AppCurves.easeDecel.transform(((rawT - 0.12) / 0.88).clamp(0.0, 1.0)),
              )!;
        final Widget stabilizedChild = _isDismissed
            ? cachedChild!
            : Transform.scale(
                scale: childScale,
                alignment: Alignment.center,
                child: cachedChild,
              );

        if (_isDismissed) {
          return stabilizedChild;
        }

        final double veilFadeOut = 1.0 -
            AppCurves.easeDecel
                .transform(((rawT - 0.18) / 0.82).clamp(0.0, 1.0));
        final double wordmarkIn =
            Curves.easeOutCubic.transform((rawT / 0.32).clamp(0.0, 1.0));
        final double exitT =
            AppCurves.easeDecel.transform(((rawT - 0.18) / 0.82).clamp(0.0, 1.0));
        final double logoScale = lerpDouble(1.0, 1.07, exitT)!;
        final double logoLiftY = lerpDouble(0.0, -10.0, exitT)!;

        return Stack(
          fit: StackFit.expand,
          children: [
            stabilizedChild,
            Positioned.fill(
              child: IgnorePointer(
                ignoring: rawT > 0.18,
                child: Opacity(
                  opacity: veilFadeOut.clamp(0.0, 1.0),
                  child: ColoredBox(
                    color: bgColor,
                    child: Center(
                      child: Transform.translate(
                        offset: Offset(0, logoLiftY),
                        child: Transform.scale(
                          scale: logoScale,
                          child: Opacity(
                            opacity: wordmarkIn.clamp(0.65, 1.0),
                            child: splashArtwork,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
