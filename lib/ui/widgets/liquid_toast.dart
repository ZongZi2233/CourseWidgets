import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../constants/theme_constants.dart';

/// 液态玻璃 Toast 通知组件
/// 遵循 liquid_glass_widgets API 规范
class LiquidToast {
  /// 显示 Toast 通知
  static void show(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 2),
    ToastType type = ToastType.info,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _LiquidToastWidget(
        message: message,
        type: type,
        onDismiss: () => overlayEntry.remove(),
      ),
    );

    overlay.insert(overlayEntry);

    // 自动移除
    Future.delayed(duration, () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  /// 显示成功 Toast
  static void success(BuildContext context, String message) {
    show(context, message: message, type: ToastType.success);
  }

  /// 显示错误 Toast
  static void error(BuildContext context, String message) {
    show(context, message: message, type: ToastType.error);
  }

  /// 显示警告 Toast
  static void warning(BuildContext context, String message) {
    show(context, message: message, type: ToastType.warning);
  }

  /// 显示信息 Toast
  static void info(BuildContext context, String message) {
    show(context, message: message, type: ToastType.info);
  }
}

/// Toast 类型
enum ToastType { success, error, warning, info }

/// Toast Widget
class _LiquidToastWidget extends StatefulWidget {
  final String message;
  final ToastType type;
  final VoidCallback onDismiss;

  const _LiquidToastWidget({
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  @override
  State<_LiquidToastWidget> createState() => _LiquidToastWidgetState();
}

class _LiquidToastWidgetState extends State<_LiquidToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getColor() {
    switch (widget.type) {
      case ToastType.success:
        return Colors.green;
      case ToastType.error:
        return Colors.red;
      case ToastType.warning:
        return Colors.orange;
      case ToastType.info:
        return AppThemeColors.babyPink;
    }
  }

  IconData _getIcon() {
    switch (widget.type) {
      case ToastType.success:
        return Icons.check_circle;
      case ToastType.error:
        return Icons.error;
      case ToastType.warning:
        return Icons.warning;
      case ToastType.info:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 60,
      left: 16,
      right: 16,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SafeArea(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: GlassContainer(
                useOwnLayer: true, // [v2.8.9] 独立离屏折射图层，真实折射底层页面内容
                shape: const LiquidRoundedSuperellipse(borderRadius: 16),
                settings: const LiquidGlassSettings(
                  glassColor: Color(0x1AFFFFFF), // [v2.9.0] 纯净无色中性液态玻璃，拒绝人造绿色/暗色浑浊染色
                  blur: 2.5,
                  thickness: 20.0,
                  refractiveIndex: 1.45,
                  lightIntensity: 0.70,
                  ambientStrength: 0.45,
                  ambientRim: 0.0, // [v2.9.0] 彻底消除黑边与暗角
                  edgeAbsorption: 0.0, // [v2.9.0] 消除边缘发黑吸光
                  fresnelStrength: 0.05,
                  saturation: 1.20,
                ),
                quality: GlassQuality.premium,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(_getIcon(), color: _getColor(), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DefaultTextStyle(
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none, // [v2.3.0修复] 移除下划线
                            fontFamily: 'PingFangSC',
                          ),
                          child: Text(
                            widget.message,
                            style: const TextStyle(
                              decoration:
                                  TextDecoration.none, // [v2.3.0修复] 双重保险移除下划线
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
