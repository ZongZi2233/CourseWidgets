import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// [v3.0.0] macOS 27 Golden Gate 风格一体化交通灯窗口控制组件
/// 严格对齐 Apple HIG 规范：
/// - 直径 12.0pt，间距 8.0pt
/// - 纯正三色：关闭 (#FF5F56)、最小化 (#FFBD2E)、最大化/还原 (#27C93F)
/// - 0.5pt 精致内描边
/// - 鼠标滑入交通灯热区整体时，微缩矢量符号 (✕, ─, ＋) 柔和淡入 (120ms)
class MacosTrafficLights extends StatefulWidget {
  final VoidCallback? onClose;
  final VoidCallback? onMinimize;
  final VoidCallback? onMaximize;

  const MacosTrafficLights({
    super.key,
    this.onClose,
    this.onMinimize,
    this.onMaximize,
  });

  @override
  State<MacosTrafficLights> createState() => _MacosTrafficLightsState();
}

class _MacosTrafficLightsState extends State<MacosTrafficLights> {
  bool _isHovering = false;

  void _handleClose() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      windowManager.close();
    }
  }

  void _handleMinimize() {
    if (widget.onMinimize != null) {
      widget.onMinimize!();
    } else {
      windowManager.minimize();
    }
  }

  void _handleMaximize() async {
    if (widget.onMaximize != null) {
      widget.onMaximize!();
    } else {
      final isMax = await windowManager.isMaximized();
      if (isMax) {
        await windowManager.unmaximize();
      } else {
        await windowManager.maximize();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TrafficLightButton(
            color: const Color(0xFFFF5F56),
            borderColor: const Color(0xFFE0443E),
            glyphColor: const Color(0xFF4D0000).withValues(alpha: 0.85),
            isHovering: _isHovering,
            glyphType: _TrafficLightGlyphType.close,
            onTap: _handleClose,
          ),
          const SizedBox(width: 8),
          _TrafficLightButton(
            color: const Color(0xFFFFBD2E),
            borderColor: const Color(0xFFDEA123),
            glyphColor: const Color(0xFF995700).withValues(alpha: 0.85),
            isHovering: _isHovering,
            glyphType: _TrafficLightGlyphType.minimize,
            onTap: _handleMinimize,
          ),
          const SizedBox(width: 8),
          _TrafficLightButton(
            color: const Color(0xFF27C93F),
            borderColor: const Color(0xFF1AAB29),
            glyphColor: const Color(0xFF006500).withValues(alpha: 0.85),
            isHovering: _isHovering,
            glyphType: _TrafficLightGlyphType.maximize,
            onTap: _handleMaximize,
          ),
        ],
      ),
    );
  }
}

enum _TrafficLightGlyphType { close, minimize, maximize }

class _TrafficLightButton extends StatefulWidget {
  final Color color;
  final Color borderColor;
  final Color glyphColor;
  final bool isHovering;
  final _TrafficLightGlyphType glyphType;
  final VoidCallback onTap;

  const _TrafficLightButton({
    required this.color,
    required this.borderColor,
    required this.glyphColor,
    required this.isHovering,
    required this.glyphType,
    required this.onTap,
  });

  @override
  State<_TrafficLightButton> createState() => _TrafficLightButtonState();
}

class _TrafficLightButtonState extends State<_TrafficLightButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final currentColor = _isPressed
        ? widget.borderColor
        : widget.color;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: currentColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: widget.borderColor,
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 1.0,
              offset: const Offset(0, 0.5),
            ),
          ],
        ),
        child: Center(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeInOut,
            opacity: widget.isHovering ? 1.0 : 0.0,
            child: CustomPaint(
              size: const Size(6, 6),
              painter: _GlyphPainter(
                type: widget.glyphType,
                color: widget.glyphColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  final _TrafficLightGlyphType type;
  final Color color;

  _GlyphPainter({required this.type, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    switch (type) {
      case _TrafficLightGlyphType.close:
        // ✕
        canvas.drawLine(const Offset(0.5, 0.5), Offset(size.width - 0.5, size.height - 0.5), paint);
        canvas.drawLine(Offset(size.width - 0.5, 0.5), Offset(0.5, size.height - 0.5), paint);
        break;
      case _TrafficLightGlyphType.minimize:
        // ─
        final midY = size.height / 2;
        canvas.drawLine(Offset(0, midY), Offset(size.width, midY), paint);
        break;
      case _TrafficLightGlyphType.maximize:
        // ＋
        final midX = size.width / 2;
        final midY = size.height / 2;
        canvas.drawLine(Offset(midX, 0), Offset(midX, size.height), paint);
        canvas.drawLine(Offset(0, midY), Offset(size.width, midY), paint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.color != color;
}
