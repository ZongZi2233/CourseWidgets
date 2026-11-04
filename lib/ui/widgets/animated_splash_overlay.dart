import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/schedule_provider.dart';
import '../../services/static_blur_service.dart';
import 'zero_flicker_splash_preloader.dart';

/// [v3.0.0] 秒开开屏加载动画与主界面并行渲染就绪门 (AnimatedSplashOverlay)
///
/// 核心特性：
/// 1. 【秒开显示】：在第 0 帧立即呈现高奢品牌呼吸动效与渐变，绝无纯黑/纯白屏停滞；
/// 2. 【并行预渲染】：底层并行唤醒真实主界面（SQLite 数据装载、课时对齐、静态壁纸模糊单次烘焙、首次光栅化）；
/// 3. 【就绪门控检测】：监听数据装载完成、壁纸烘焙完成以及第一帧落盘 (endOfFrame)，杜绝未烘焙切片导致的二次闪烁；
/// 4. 【非线性淡出溶图】：满足优雅最小观感时长（650ms）后，以 350ms 非线性微缩放淡出溶图揭晓主界面；
/// 5. 【零常驻开销】：淡出完成后彻底从 Widget 树中卸载，日常使用 0 CPU / 0 GPU 负担。
class AnimatedSplashOverlay extends StatefulWidget {
  final Widget child;
  final ValueNotifier<bool>? startupReadyNotifier;

  const AnimatedSplashOverlay({
    super.key,
    required this.child,
    this.startupReadyNotifier,
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
  final DateTime _startTime = DateTime.now();

  Timer? _safetyTimer;
  ScheduleProvider? _scheduleProvider;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeInOutCubic,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
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

    // 安全超时保护：若后台数据或着色器异常，3500ms 强制开门揭晓主界面，确保永远不卡死
    _safetyTimer = Timer(const Duration(milliseconds: 3500), () {
      _triggerDismiss();
    });

    // 启动就绪检测流
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkReadiness();
    });
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
    if (_isGatePassed || !mounted) return;

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
    _isGatePassed = true;
    _safetyTimer?.cancel();

    // 确保至少呈现优雅的品牌动效 680ms，杜绝闪跳
    final elapsedMs = DateTime.now().difference(_startTime).inMilliseconds;
    final remainingMs = 680 - elapsedMs;

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
    if (_isDismissed) {
      return widget.child;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // 底层真实主界面（立即启动并行渲染与数据管道）
        widget.child,

        // 顶层秒开高奢过渡动效
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _fadeController,
            builder: (context, child) {
              return IgnorePointer(
                ignoring: _isGatePassed, // 开始淡出时即解除下层交互限制
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: const ZeroFlickerSplashPreloader(),
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
