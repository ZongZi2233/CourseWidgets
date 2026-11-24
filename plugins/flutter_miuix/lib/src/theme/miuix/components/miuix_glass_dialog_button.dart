// Miuix Flutter 移植版 - GlassDialogButton
// 源自 compose-miuix-ui/miuix 的 GlassDialogButton.kt。
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

import '../foundation/miuix_content_color.dart';
import '../theme/miuix_text_styles.dart';
import '../theme/miuix_theme.dart';
import 'miuix_button.dart';

/// 玻璃对话框操作按钮的视觉角色。对应 Kotlin `GlassDialogButtonRole`。
enum MiuixGlassDialogButtonRole { normal, primary, destructive }

/// 玻璃对话框按钮默认值。对应 Kotlin `GlassDialogButtonDefaults`。
class MiuixGlassDialogButtonDefaults {
  MiuixGlassDialogButtonDefaults._();

  static const double cornerRadius = 16;
  static const double minWidth = 0;
  static const double minHeight = 50;
  static const EdgeInsets insideMargin = EdgeInsets.symmetric(horizontal: 24);

  /// 当前主题下各角色的启用与禁用颜色。
  static MiuixButtonColors buttonColors(
    BuildContext context, {
    MiuixGlassDialogButtonRole role = MiuixGlassDialogButtonRole.normal,
  }) {
    final scheme = MiuixTheme.of(context).colors;
    final isDark = scheme.background.computeLuminance() < 0.5;
    final tonal = scheme.onBackground.withValues(
      alpha: isDark ? 36 / 255 : 15 / 255,
    );
    final color = role == MiuixGlassDialogButtonRole.primary
        ? scheme.primary
        : tonal;
    final disabledColor = role == MiuixGlassDialogButtonRole.primary
        ? scheme.primary.withValues(alpha: 0.3)
        : tonal;
    final contentColor = switch (role) {
      MiuixGlassDialogButtonRole.normal => scheme.onBackground.withValues(
        alpha: isDark ? 0.8 : 0.9,
      ),
      MiuixGlassDialogButtonRole.primary => scheme.onPrimary,
      MiuixGlassDialogButtonRole.destructive => scheme.error,
    };
    final disabledContentColor = switch (role) {
      MiuixGlassDialogButtonRole.normal => scheme.onBackground.withValues(
        alpha: 0.38,
      ),
      MiuixGlassDialogButtonRole.primary => scheme.onPrimary.withValues(
        alpha: isDark ? 77 / 255 : 1.0,
      ),
      MiuixGlassDialogButtonRole.destructive => scheme.error.withValues(
        alpha: 0.3,
      ),
    };
    return MiuixButtonColors(
      color: color,
      disabledColor: disabledColor,
      contentColor: contentColor,
      disabledContentColor: disabledContentColor,
    );
  }

  /// 按下态前景遮罩颜色。
  static Color pressedColor(BuildContext context) {
    final scheme = MiuixTheme.of(context).colors;
    final isDark = scheme.background.computeLuminance() < 0.5;
    return scheme.onBackground.withValues(alpha: isDark ? 36 / 255 : 31 / 255);
  }
}

/// 配合 [MiuixGlassDialog] / [MiuixGlassBottomSheet] 使用的操作按钮。
/// 对应 Kotlin `GlassDialogButton`。
///
/// 普通与破坏性按钮使用半透明底色，主按钮使用主题主色；不额外叠加背景模糊。
/// 按下态反馈覆盖在底色与内容之上。
class MiuixGlassDialogButton extends StatefulWidget {
  const MiuixGlassDialogButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.enabled = true,
    this.role = MiuixGlassDialogButtonRole.normal,
    this.cornerRadius = MiuixGlassDialogButtonDefaults.cornerRadius,
    this.minWidth = MiuixGlassDialogButtonDefaults.minWidth,
    this.minHeight = MiuixGlassDialogButtonDefaults.minHeight,
    this.colors,
    this.pressedColor,
    this.insideMargin = MiuixGlassDialogButtonDefaults.insideMargin,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final bool enabled;
  final MiuixGlassDialogButtonRole role;
  final double cornerRadius;
  final double minWidth;
  final double minHeight;
  final MiuixButtonColors? colors;
  final Color? pressedColor;
  final EdgeInsetsGeometry insideMargin;

  @override
  State<MiuixGlassDialogButton> createState() => _MiuixGlassDialogButtonState();
}

class _MiuixGlassDialogButtonState extends State<MiuixGlassDialogButton> {
  bool _pressed = false;

  bool get _interactive => widget.enabled && widget.onPressed != null;

  @override
  void didUpdateWidget(MiuixGlassDialogButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_interactive && _pressed) _pressed = false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = MiuixTheme.of(context);
    final colors =
        widget.colors ??
        MiuixGlassDialogButtonDefaults.buttonColors(context, role: widget.role);
    final pressedOverlay =
        widget.pressedColor ??
        MiuixGlassDialogButtonDefaults.pressedColor(context);
    final containerColor = _interactive ? colors.color : colors.disabledColor;
    final contentColor = _interactive
        ? colors.contentColor
        : colors.disabledContentColor;
    final borderRadius = BorderRadius.circular(widget.cornerRadius);
    final textStyle = theme.textStyles.button
        .copyWith(color: contentColor)
        .withMiuixWeight(theme.fontWeightAdjustment);

    return Semantics(
      button: true,
      enabled: _interactive,
      child: FocusableActionDetector(
        enabled: _interactive,
        mouseCursor: _interactive
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _interactive ? widget.onPressed : null,
          onTapDown: _interactive
              ? (_) => setState(() => _pressed = true)
              : null,
          onTapUp: _interactive
              ? (_) => setState(() => _pressed = false)
              : null,
          onTapCancel: _pressed ? () => setState(() => _pressed = false) : null,
          child: ClipRRect(
            borderRadius: borderRadius,
            child: DecoratedBox(
              decoration: BoxDecoration(color: containerColor),
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  color: _pressed && _interactive
                      ? pressedOverlay
                      : const Color(0x00000000),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: widget.minWidth,
                    minHeight: widget.minHeight,
                  ),
                  child: Padding(
                    padding: widget.insideMargin,
                    child: MiuixContentColor(
                      color: contentColor,
                      child: DefaultTextStyle.merge(
                        style: textStyle,
                        child: IconTheme.merge(
                          data: IconThemeData(color: contentColor),
                          child: Center(
                            widthFactor: 1,
                            heightFactor: 1,
                            child: widget.child,
                          ),
                        ),
                      ),
                    ),
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
