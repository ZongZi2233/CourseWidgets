import 'dart:ui' show ImageFilter;
import 'dart:ui' as ui show Image;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:flutter_miuix/miuix.dart';
import '../../constants/theme_constants.dart';
import '../../constants/version.dart' show kSolidColorBackground;
import '../../utils/glass_settings_helper.dart';
import '../../services/theme_service.dart' as theme;
import '../../services/static_blur_service.dart';
import '../animations/app_motion.dart';
import '../../main.dart';

enum LiquidStyleType { standard, micro, active }

void showNativeToast(String msg) {
  debugPrint("Toast: $msg");
}

// [v3.1.0] 搭载灵动弹簧进出场动效与深浅色自适应高对比文字的液态玻璃 Toast
void showLiquidToast(BuildContext context, String msg) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;
  final isDark = globalDarkModeNotifier.value;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _AnimatedLiquidToast(
      message: msg,
      isDark: isDark,
      onDismissed: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );
  overlay.insert(entry);
}

class _AnimatedLiquidToast extends StatefulWidget {
  final String message;
  final bool isDark;
  final VoidCallback onDismissed;

  const _AnimatedLiquidToast({
    required this.message,
    required this.isDark,
    required this.onDismissed,
  });

  @override
  State<_AnimatedLiquidToast> createState() => _AnimatedLiquidToastState();
}

class _AnimatedLiquidToastState extends State<_AnimatedLiquidToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _scale = Tween<double>(begin: 0.86, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: AppCurves.spring,
        reverseCurve: AppCurves.easeAccel,
      ),
    );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: AppCurves.easeDecel,
      reverseCurve: Curves.easeIn,
    );
    _controller.forward();
    Future.delayed(const Duration(milliseconds: 1850), () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onDismissed());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark ? Colors.white : const Color(0xFF1D2129);
    return Positioned(
      bottom: 54,
      left: 20,
      right: 20,
      child: IgnorePointer(
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Material(
                color: Colors.transparent,
                child: GlassContainer(
                  useOwnLayer: true,
                  quality: theme.ThemeService().glassQuality,
                  shape: const LiquidRoundedSuperellipse(borderRadius: 20),
                  settings: LiquidGlassSettings(
                    glassColor: widget.isDark
                        ? const Color(0x551E222B)
                        : const Color(0x66FFFFFF),
                    blur: 8.0,
                    thickness: 16.0,
                    lightIntensity: 0.70,
                    ambientStrength: 0.45,
                    ambientRim: 0.0,
                    edgeAbsorption: 0.0,
                    fresnelStrength: 0.0,
                    saturation: 1.20,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 11,
                    ),
                    child: Text(
                      widget.message,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
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

/// 核心容器适配器
class LiquidCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? glassColor;
  final double borderRadius;
  final double padding;
  final bool isSelected;
  final LiquidStyleType styleType;
  final bool isPanel;
  final double? stretch;
  final GlassQuality? quality;

  const LiquidCard({
    super.key,
    required this.child,
    this.onTap,
    this.glassColor,
    this.borderRadius = 24,
    this.padding = 0,
    this.isSelected = false,
    this.styleType = LiquidStyleType.standard,
    this.isPanel = false,
    this.stretch,
    this.quality,
    bool? useFakeGlass,
    bool? isDisabled,
  });

  @override
  Widget build(BuildContext context) {
    final inLayer = context.dependOnInheritedWidgetOfExactType<InheritedLiquidGlass>() != null;
    final effectiveQuality = quality ?? theme.ThemeService().glassQuality;

    final settings = glassColor != null
        ? LiquidGlassSettings(
            thickness: styleType == LiquidStyleType.micro ? 12.0 : 16.0,
            blur: (styleType == LiquidStyleType.micro) ? 2.0 : 4.0,
            glassColor: glassColor!,
            refractiveIndex: 1.40,
            lightIntensity: 0.70,
            ambientStrength: 0.45,
            saturation: 1.25,
            bodyMode: GlassBodyMode.adaptive,
            edgeAbsorption: 0.0,
            ambientRim: 0.0,
            fresnelStrength: 0.0,
            specularSharpness: GlassSpecularSharpness.medium,
          )
        : (isPanel
            ? GlassSettingsHelper.panelSettings
            : GlassSettingsHelper.defaultSettings).copyWith(
                bodyMode: GlassBodyMode.adaptive,
                edgeAbsorption: 0.0,
                ambientRim: 0.0,
                fresnelStrength: 0.0,
                specularSharpness: GlassSpecularSharpness.medium,
              );

    final effectiveColor = settings.glassColor;

    return Semantics(
      button: onTap != null,
      selected: isSelected,
      child: GestureDetector(
        onTap: onTap != null
            ? () {
                HapticFeedback.lightImpact();
                onTap!();
              }
            : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: const Color(0x20FF9A9E).withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: 1,
                )
              else
                BoxShadow(
                  color: globalUseDarkMode
                      ? Colors.black.withValues(alpha: 0.20)
                      : Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  spreadRadius: 0,
                  offset: const Offset(0, 3),
                ),
            ],
          ),
          child: GlassContainer(
            useOwnLayer: !inLayer,
            shape: LiquidRoundedSuperellipse(borderRadius: borderRadius),
            settings: settings.copyWith(glassColor: effectiveColor),
            quality: effectiveQuality,
            child: Padding(padding: EdgeInsets.all(padding), child: child),
          ),
        ),
      ),
    );
  }
}

class LiquidButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final Color color;
  final bool isOutline;
  final double? width;
  final double? height;
  final Color? textColor;
  final bool? useOwnLayer;
  final GlassQuality? quality;

  const LiquidButton({
    super.key,
    required this.text,
    required this.onTap,
    required this.color,
    this.isOutline = false,
    this.width,
    this.height,
    this.textColor,
    this.useOwnLayer,
    this.quality,
  });

  @override
  Widget build(BuildContext context) {
    final inLayer = context.dependOnInheritedWidgetOfExactType<InheritedLiquidGlass>() != null;
    final themeDark = Theme.of(context).brightness == Brightness.dark;
    final isDark = themeDark || globalDarkModeNotifier.value;
    final lum = color.computeLuminance();
    final Color effectiveTextColor = textColor ??
        (isOutline
            ? (isDark ? Colors.white70 : const Color(0xFF2D313A))
            : (isDark
                ? (lum > 0.65 ? const Color(0xFF1E2129) : Colors.white)
                : (lum > 0.35 ? const Color(0xFF1E2129) : Colors.white)));
    final effectiveQuality = quality ?? theme.ThemeService().glassQuality;

    return GlassButton.custom(
      onTap: onTap ?? () {},
      width: width,
      height: height ?? 48,
      style: GlassButtonStyle.filled,
      useOwnLayer: useOwnLayer ?? !inLayer,
      quality: effectiveQuality,
      interactionScale: 1.05,
      glowColor: color.withValues(alpha: 0.35),
      glowRadius: 22,
      settings: LiquidGlassSettings(
        glassColor: isOutline
            ? (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06))
            : color.withValues(alpha: 0.7),
        blur: 0.6,
        thickness: 16.0,
        refractiveIndex: 1.48,
        chromaticAberration: 0.08,
        lightIntensity: 0.75,
        bodyMode: GlassBodyMode.adaptive,
        edgeAbsorption: 0.0,
        ambientRim: 0.0,
        fresnelStrength: 0.0,
        specularSharpness: GlassSpecularSharpness.sharp,
      ),
      shape: const LiquidRoundedSuperellipse(borderRadius: 16),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: effectiveTextColor,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

class LiquidSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const LiquidSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GlassSwitch(
      value: value,
      onChanged: onChanged,
      width: 56,
      height: 32,
      activeColor: AppThemeColors.babyPink,
      settings: const LiquidGlassSettings(
        thickness: 10,
        blur: 2.0,
        refractiveIndex: 1.35,
        lightIntensity: 0.6,
      ),
    );
  }
}

// [v3.1.0] 统一使用纯正液态玻璃与 AppCurves.spring 灵动弹簧的 LiquidGlassDialog（消除双层全屏高斯模糊掉帧）
class LiquidGlassDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<GlassDialogAction>? actions;
  final double maxWidth;

  const LiquidGlassDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions,
    this.maxWidth = 320,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget content,
    List<GlassDialogAction>? actions,
    double maxWidth = 320,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.38),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (dialogCtx, anim1, anim2) => LiquidGlassDialog(
        title: title,
        content: content,
        actions: actions,
        maxWidth: maxWidth,
      ),
      transitionBuilder: (dialogCtx, anim1, anim2, child) {
        final isReversing = anim1.status == AnimationStatus.reverse;
        final double scale;
        if (isReversing) {
          scale = 1.0;
        } else {
          final curved = AppCurves.spring.transform(anim1.value);
          scale = (1.10 - 0.10 * curved).clamp(0.96, 1.12);
        }
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: anim1,
            curve: AppCurves.easeDecel,
            reverseCurve: AppCurves.easeAccel,
          ),
          child: Transform.scale(
            scale: scale,
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveActions = actions ?? [
      GlassDialogAction(
        label: '确定',
        onPressed: () => Navigator.pop(context),
        isPrimary: true,
      ),
    ];

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: HyperOSShadows.modal(isDark),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? const [
                              Color(0xCC242936),
                              Color(0xB8181B24),
                            ]
                          : const [
                              Color(0xE0FFFFFF),
                              Color(0xC8F2F6FC),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1E2128),
                          letterSpacing: -0.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Flexible(
                        child: DefaultTextStyle(
                          style: TextStyle(
                            fontSize: 14.5,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.78)
                                : const Color(0xFF4A5060),
                            height: 1.45,
                          ),
                          textAlign: TextAlign.center,
                          child: content,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildActions(context, effectiveActions, isDark),
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

  Widget _buildActions(BuildContext context, List<GlassDialogAction> actionsList, bool isDark) {
    if (actionsList.length <= 2) {
      return Row(
        children: actionsList.asMap().entries.map((entry) {
          final idx = entry.key;
          final act = entry.value;
          return Expanded(
            child: Padding(
              padding: EdgeInsetsDirectional.only(
                start: idx > 0 ? 10 : 0,
              ),
              child: _buildActionButton(context, act, isDark),
            ),
          );
        }).toList(),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: actionsList.asMap().entries.map((entry) {
        final idx = entry.key;
        final act = entry.value;
        return Padding(
          padding: EdgeInsets.only(top: idx > 0 ? 8 : 0),
          child: SizedBox(
            width: double.infinity,
            child: _buildActionButton(context, act, isDark),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionButton(BuildContext context, GlassDialogAction action, bool isDark) {
    final bool isPrimary = action.isPrimary;
    final bool isDestructive = action.isDestructive;

    final Color tintColor = isDestructive
        ? const Color(0xCCFF453A)
        : (isPrimary
            ? AppThemeColors.babyPink.withValues(alpha: 0.85)
            : (isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.06)));

    final Color textColor = isDestructive || isPrimary
        ? Colors.white
        : (isDark ? Colors.white70 : const Color(0xFF1E2128));

    return SpringTouchFeedback(
      onTap: action.onPressed,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: tintColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPrimary || isDestructive
                ? Colors.white.withValues(alpha: 0.35)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.14)
                    : Colors.black.withValues(alpha: 0.08)),
            width: 0.8,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          action.label,
          style: TextStyle(
            color: textColor,
            fontWeight: isPrimary ? FontWeight.bold : FontWeight.w600,
            fontSize: 14.5,
          ),
        ),
      ),
    );
  }
}

// [v3.1.6] 统一灵动弹簧弹窗入口（对标 FlClash / iOS 原生弹窗 1.10x->1.0x 入场，1.0x 淡出退场）
Future<T?> showLiquidDialog<T>({
  required BuildContext context,
  required Widget builder,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.38),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (ctx, anim1, anim2) => builder,
    transitionBuilder: (ctx, anim1, anim2, child) {
      final isReversing = anim1.status == AnimationStatus.reverse;
      final double scale;
      if (isReversing) {
        scale = 1.0;
      } else {
        final curved = AppCurves.spring.transform(anim1.value);
        scale = (1.10 - 0.10 * curved).clamp(0.96, 1.12);
      }
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: anim1,
          curve: AppCurves.easeDecel,
          reverseCurve: AppCurves.easeAccel,
        ),
        child: Transform.scale(
          scale: scale,
          child: child,
        ),
      );
    },
  );
}

class LiquidInput extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final IconData icon;
  final bool isReadOnly;
  final VoidCallback? onTap;
  final String? placeholder;
  final String? valueText;

  const LiquidInput({
    super.key,
    this.controller,
    required this.label,
    required this.icon,
    this.isReadOnly = false,
    this.onTap,
    this.placeholder,
    this.valueText,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF555B68),
            ),
          ),
        ),
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.28)
                  : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.08),
                width: 0.8,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                Icon(icon, color: AppThemeColors.babyPink, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: controller != null
                      ? IgnorePointer(
                          ignoring: isReadOnly,
                          child: CupertinoTextField(
                            controller: controller,
                            readOnly: isReadOnly,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF1E2128),
                              fontSize: 16,
                            ),
                            cursorColor: AppThemeColors.babyPink,
                            decoration: null,
                            placeholder: placeholder ?? '请输入$label',
                            placeholderStyle: TextStyle(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.4)
                                  : const Color(0x60000000),
                              fontSize: 16,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              valueText ?? placeholder ?? '',
                              maxLines: 1,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF1E2128),
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                ),
                if (isReadOnly || controller == null)
                  Icon(
                    CupertinoIcons.chevron_down,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.5)
                        : const Color(0x60000000),
                    size: 16,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class LiquidBackButton extends StatelessWidget {
  final VoidCallback? onTap;
  const LiquidBackButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return GlassIconButton(
      icon: const Icon(
        CupertinoIcons.back,
        size: 22,
        color: Colors.white,
      ),
      onPressed: () {
        HapticFeedback.lightImpact();
        if (onTap != null) {
          onTap!();
        } else {
          Navigator.maybePop(context);
        }
      },
      size: 44,
      shape: GlassIconButtonShape.roundedSquare,
      borderRadius: 16,
      interactionScale: 1.10,
      pressDarken: true,
      glowColor: primaryColor.withValues(alpha: isDark ? 0.42 : 0.32),
      glowRadius: 24,
      useOwnLayer: true,
      quality: GlassQuality.premium,
      settings: LiquidGlassSettings(
        glassColor: isDark ? const Color(0x18FFFFFF) : const Color(0x10FFFFFF),
        blur: 0.3,
        thickness: 38.0,
        refractiveIndex: 1.50,
        chromaticAberration: 0.10,
        lightIntensity: 0.80,
        ambientStrength: 0.35,
        edgeAbsorption: 0.0,
        ambientRim: 0.10,
        fresnelStrength: 0.25,
        specularSharpness: GlassSpecularSharpness.sharp,
        shadow: [
          BoxShadow(
            color: (isDark ? Colors.black : const Color(0xFF1E2129))
                .withValues(alpha: isDark ? 0.36 : 0.14),
            blurRadius: 14.0,
            spreadRadius: -2.0,
            offset: const Offset(0, 3.0),
          ),
        ],
      ),
    );
  }
}

class FloatingLiquidBackButton extends StatelessWidget {
  final VoidCallback? onBack;
  const FloatingLiquidBackButton({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      bottom: 24,
      right: 20,
      child: SafeArea(
        top: false,
        left: false,
        child: GlassButton.custom(
          width: 52,
          height: 52,
          useOwnLayer: true,
          shape: const LiquidOval(),
          quality: theme.ThemeService().glassQuality,
          stretch: 0.25,
          interactionScale: 1.12,
          showOverlayColor: false,
          ambientBaseLight: 0.0,
          onTap: () {
            HapticFeedback.lightImpact();
            if (onBack != null) {
              onBack!();
            } else {
              Navigator.maybePop(context);
            }
          },
          settings: LiquidGlassSettings(
            glassColor: isDark
                ? const Color(0x35101216)
                : const Color(0x30FFFFFF),
            blur: 0.35,
            thickness: 16.0,
            refractiveIndex: 1.44,
            edgeAbsorption: 0.10,
            chromaticAberration: 0.12,
            lightIntensity: 0.75,
            ambientStrength: 0.35,
            ambientRim: 0.0,
            fresnelStrength: 0.0,
            saturation: 1.15,
            specularSharpness: GlassSpecularSharpness.sharp,
            shadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.38 : 0.14),
                blurRadius: 18.0,
                spreadRadius: -1.0,
                offset: const Offset(0, 4.0),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              CupertinoIcons.back,
              size: 22,
              color: isDark ? Colors.white : const Color(0xFF1D2129),
            ),
          ),
        ),
      ),
    );
  }
}

class FloatingGlassHeaderButton extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  const FloatingGlassHeaderButton({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1D2129);

    return SpringTouchFeedback(
      onTap: () {
        HapticFeedback.lightImpact();
        if (onBack != null) {
          onBack!();
        } else {
          Navigator.maybePop(context);
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(20),
              boxShadow: HyperOSShadows.pill(isDark),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.chevron_left,
                  size: 18,
                  color: textColor.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    letterSpacing: 0.3,
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// [v3.1.1] 纯色模式导航栏专用逆向裁剪外沿柔光组件：
/// 采用 PathFillType.evenOdd 逆向挖空胶囊内部，并配合 BlurStyle.normal 触发 Impeller 硬件 RRect SDF 阴影，
/// 确保阴影 100% 只绘制在胶囊外侧，绝不向玻璃内部或下方填充任何像素，零改变玻璃通透度！
class OuterGlowShadowBox extends StatelessWidget {
  final double borderRadius;
  final bool isDark;

  const OuterGlowShadowBox({
    super.key,
    required this.borderRadius,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _InverseRRectShadowPainter(
            borderRadius: borderRadius,
            shadows: HyperOSShadows.navBar(isDark, isSolidBg: true),
          ),
        ),
      ),
    );
  }
}

class _InverseRRectShadowPainter extends CustomPainter {
  final double borderRadius;
  final List<BoxShadow> shadows;

  const _InverseRRectShadowPainter({
    required this.borderRadius,
    required this.shadows,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (shadows.isEmpty || size.isEmpty) return;
    final rect = Offset.zero & size;
    final radius = Radius.circular(borderRadius);
    final pillRRect = RRect.fromRectAndRadius(rect, radius);

    // 逆向裁剪：挖空胶囊内部区域，只允许在胶囊外部绘制柔光
    final clipPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(rect.inflate(60.0))
      ..addRRect(pillRRect);

    canvas.save();
    canvas.clipPath(clipPath);
    for (final s in shadows) {
      final shadowRect = rect.shift(s.offset).inflate(s.spreadRadius);
      canvas.drawRRect(
        RRect.fromRectAndRadius(shadowRect, radius),
        s.toPaint(),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _InverseRRectShadowPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius ||
        oldDelegate.shadows != shadows;
  }
}

/// [v3.1.1] 阴影常量池：与 v3.0.x 保持一致，[navBar] 仅在纯色背景模式下供导航栏逆向裁剪外沿柔光使用。
class HyperOSShadows {
  HyperOSShadows._();

  static const List<BoxShadow> _navLightSolid = [
    BoxShadow(
      color: Color(0x18182238),
      blurRadius: 20.0,
      spreadRadius: -1.0,
      offset: Offset(0, 3.0),
    ),
    BoxShadow(
      color: Color(0x0E0F172A),
      blurRadius: 10.0,
      spreadRadius: 0.0,
      offset: Offset(0, 1.5),
    ),
  ];

  static const List<BoxShadow> _navDarkSolid = [
    BoxShadow(
      color: Color(0x66000000),
      blurRadius: 22.0,
      spreadRadius: -1.0,
      offset: Offset(0, 4.0),
    ),
  ];

  static const List<BoxShadow> _none = <BoxShadow>[];

  static List<BoxShadow> navBar(bool isDark, {bool isSolidBg = false}) {
    if (!isSolidBg) return _none;
    return isDark ? _navDarkSolid : _navLightSolid;
  }

  static List<BoxShadow> card(bool isDark, {Color? glowColor}) {
    if (!isDark) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 14.0,
          spreadRadius: -1.0,
          offset: const Offset(0, 3.5),
        ),
        if (glowColor != null)
          BoxShadow(
            color: glowColor.withValues(alpha: 0.14),
            blurRadius: 12.0,
            spreadRadius: -1.0,
            offset: const Offset(0, 2),
          ),
      ];
    }

    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.35),
        blurRadius: 22.0,
        spreadRadius: -2.0,
        offset: const Offset(0, 6),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.20),
        blurRadius: 8.0,
        spreadRadius: 0,
        offset: const Offset(0, 2),
      ),
      if (glowColor != null)
        BoxShadow(
          color: glowColor.withValues(alpha: 0.25),
          blurRadius: 14.0,
          spreadRadius: -1.0,
          offset: const Offset(0, 2.5),
        ),
    ];
  }

  static List<BoxShadow> pill(bool isDark, {Color? accentColor}) {
    if (accentColor != null) {
      return [
        BoxShadow(
          color: accentColor.withValues(alpha: isDark ? 0.30 : 0.22),
          blurRadius: 12.0,
          spreadRadius: -1.0,
          offset: const Offset(0, 2.5),
        ),
      ];
    }
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
        blurRadius: 14.0,
        spreadRadius: -1.5,
        offset: const Offset(0, 3.5),
      ),
    ];
  }

  static List<BoxShadow> dock(bool isDark) {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.42 : 0.10),
        blurRadius: 32.0,
        spreadRadius: -2.0,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.05),
        blurRadius: 8.0,
        spreadRadius: 0,
        offset: const Offset(0, 2),
      ),
    ];
  }

  static List<BoxShadow> modal(bool isDark) {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.48 : 0.14),
        blurRadius: 40.0,
        spreadRadius: -3.0,
        offset: const Offset(0, 10),
      ),
    ];
  }
}

/// [v3.1.0] 基于 Flutter MiuiX 与 Liquid Glass 规范的 HyperOS 超椭圆混色无边框卡片
class HyperOSCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double cornerRadius;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? contentColor;
  final bool useBlur;
  final double blurRadius;
  final MiuixPressFeedbackType feedbackType;
  final BorderSide? border;
  final List<BoxShadow>? shadows;

  const HyperOSCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.cornerRadius = 28,
    this.padding = const EdgeInsets.all(12),
    this.color,
    this.contentColor,
    this.useBlur = true,
    this.blurRadius = 10.0,
    this.feedbackType = MiuixPressFeedbackType.sink,
    this.border,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = globalDarkModeNotifier.value;
    final isSolidBg = globalBackgroundPath.value == kSolidColorBackground;
    final primary = theme.ThemeService().primaryColor;

    // [v3.1.0] 在纯色无壁纸模式下（浅色纯白 #FFFFFF / 夜间微信深灰 #111111），
    // 为卡片赋予层次分明的温润微表面色（浅色 #F6F7FA 融合微主题色，夜间 #191919 微信深色卡片底色）
    final defaultBgColor = isSolidBg
        ? (isDark
            ? Color.alphaBlend(primary.withValues(alpha: 0.06), const Color(0xFF191919))
            : Color.alphaBlend(primary.withValues(alpha: 0.05), const Color(0xFFF6F7FB)))
        : (isDark
            ? Color.alphaBlend(primary.withValues(alpha: 0.14), const Color(0x5514171E))
            : Color.alphaBlend(primary.withValues(alpha: 0.12), const Color(0x60FFFFFF)));

    final effectiveColor = color ?? defaultBgColor;

    final lum = effectiveColor.computeLuminance();
    final autoTextColor = lum > 0.45 ? const Color(0xFF1B1D24) : const Color(0xFFF2F5FA);
    final effectiveTextColor = contentColor ?? autoTextColor;

    final effectiveBorderSide = border ?? BorderSide.none;

    final shape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.all(Radius.circular(cornerRadius)),
      side: effectiveBorderSide,
    );

    final effectiveShadows = shadows ?? HyperOSShadows.card(isDark);

    final screenSize = MediaQuery.sizeOf(context);
    final scrollable = Scrollable.maybeOf(context);
    final scrollPosition = scrollable?.position;

    Widget cardBody;
    if (useBlur && !isSolidBg) {
      cardBody = ListenableBuilder(
        listenable: StaticBlurredWallpaperService.instance,
        builder: (context, _) {
          return _SharedBlurStencilWidget(
            blurredImage: StaticBlurredWallpaperService.instance.blurredImage,
            screenSize: screenSize,
            backgroundColor: effectiveColor,
            cornerRadius: cornerRadius,
            shape: shape,
            shadows: effectiveShadows,
            scrollPosition: scrollPosition,
            child: Padding(
              padding: padding,
              child: child,
            ),
          );
        },
      );
    } else {
      cardBody = _SharedBlurStencilWidget(
        blurredImage: null,
        screenSize: screenSize,
        backgroundColor: effectiveColor,
        cornerRadius: cornerRadius,
        shape: shape,
        shadows: effectiveShadows,
        scrollPosition: null,
        child: Padding(
          padding: padding,
          child: child,
        ),
      );
    }

    Widget cardContent = MiuixContentColor(
      color: effectiveTextColor,
      child: cardBody,
    );

    if (onTap != null || onLongPress != null || feedbackType != MiuixPressFeedbackType.none) {
      cardContent = MiuixPressable(
        onPressed: onTap != null
            ? () {
                SharedElementSourceRegistry.recordFromContext(
                  context,
                  cornerRadius: cornerRadius,
                );
                onTap!();
              }
            : null,
        onLongPress: onLongPress != null
            ? () {
                SharedElementSourceRegistry.recordFromContext(
                  context,
                  cornerRadius: cornerRadius,
                );
                onLongPress!();
              }
            : null,
        feedbackType: feedbackType,
        sinkAmount: 0.96,
        overlayColor: Colors.transparent,
        borderRadius: BorderRadius.circular(cornerRadius),
        child: cardContent,
      );
    }

    return cardContent;
  }
}

/// [v3.1.1] 共享全屏静态高斯模糊双线性采样 Stencil 视窗组件
class _SharedBlurStencilWidget extends SingleChildRenderObjectWidget {
  final ui.Image? blurredImage;
  final Size screenSize;
  final Color backgroundColor;
  final double cornerRadius;
  final ShapeBorder shape;
  final List<BoxShadow> shadows;
  final ScrollPosition? scrollPosition;

  const _SharedBlurStencilWidget({
    required this.blurredImage,
    required this.screenSize,
    required this.backgroundColor,
    required this.cornerRadius,
    required this.shape,
    required this.shadows,
    this.scrollPosition,
    required super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderSharedBlurStencil(
      blurredImage: blurredImage,
      screenSize: screenSize,
      backgroundColor: backgroundColor,
      cornerRadius: cornerRadius,
      shape: shape,
      shadows: shadows,
      scrollPosition: scrollPosition,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSharedBlurStencil renderObject,
  ) {
    renderObject.update(
      blurredImage: blurredImage,
      screenSize: screenSize,
      backgroundColor: backgroundColor,
      cornerRadius: cornerRadius,
      shape: shape,
      shadows: shadows,
      scrollPosition: scrollPosition,
    );
  }
}

class _RenderSharedBlurStencil extends RenderProxyBox {
  ui.Image? blurredImage;
  Size screenSize;
  Color backgroundColor;
  double cornerRadius;
  ShapeBorder shape;
  List<BoxShadow> shadows;
  ScrollPosition? scrollPosition;

  final Paint _shaderPaint = Paint()..isAntiAlias = true;
  final Paint _bgPaint = Paint()..isAntiAlias = true;
  double _lastScrollPixels = double.nan;

  // [v3.1.3 FlClash 级渲染优化] 缓存 ImageShader 与变换参数，消除每帧重复创建 Matrix4 与引擎层 Shader 实例
  ui.Image? _cachedShaderImage;
  double _cachedTransX = double.nan;
  double _cachedTransY = double.nan;
  double _cachedScaleX = double.nan;
  double _cachedScaleY = double.nan;

  _RenderSharedBlurStencil({
    required this.blurredImage,
    required this.screenSize,
    required this.backgroundColor,
    required this.cornerRadius,
    required this.shape,
    required this.shadows,
    this.scrollPosition,
  }) {
    _bgPaint.color = backgroundColor;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    scrollPosition?.addListener(_onScroll);
  }

  @override
  void detach() {
    scrollPosition?.removeListener(_onScroll);
    super.detach();
  }

  void _onScroll() {
    if (blurredImage == null || !attached) return;
    final currentPixels = scrollPosition?.pixels ?? 0.0;
    if ((currentPixels - _lastScrollPixels).abs() < 0.4) return;
    _lastScrollPixels = currentPixels;
    markNeedsPaint();
  }

  void update({
    required ui.Image? blurredImage,
    required Size screenSize,
    required Color backgroundColor,
    required double cornerRadius,
    required ShapeBorder shape,
    required List<BoxShadow> shadows,
    ScrollPosition? scrollPosition,
  }) {
    bool needsRepaint = false;
    if (this.blurredImage != blurredImage ||
        this.screenSize != screenSize ||
        this.backgroundColor != backgroundColor ||
        this.cornerRadius != cornerRadius ||
        this.shape != shape ||
        this.shadows != shadows) {
      if (!identical(this.blurredImage, blurredImage)) {
        _cachedShaderImage = null;
      }
      this.blurredImage = blurredImage;
      this.screenSize = screenSize;
      this.backgroundColor = backgroundColor;
      this.cornerRadius = cornerRadius;
      this.shape = shape;
      this.shadows = shadows;
      _bgPaint.color = backgroundColor;
      needsRepaint = true;
    }

    if (this.scrollPosition != scrollPosition) {
      if (attached) {
        this.scrollPosition?.removeListener(_onScroll);
        scrollPosition?.addListener(_onScroll);
      }
      this.scrollPosition = scrollPosition;
      needsRepaint = true;
    }

    if (needsRepaint) {
      markNeedsPaint();
    }
  }

  /// 解析卡片在当前页面视口中的稳态坐标，剥离横向切页 (FractionalTranslation / SlideTransition / PageView)
  /// 带来的整屏瞬时位移，彻底消除多页面切换或切周时卡片采样出界变灰/变亮闪烁。
  Offset _resolvePageGlobalOffset(Size refSize) {
    if (!attached) return Offset.zero;
    try {
      RenderBox? pageRoot;
      RenderObject? current = parent;
      RenderBox? lastBox;
      while (current != null) {
        if (current is RenderFractionalTranslation) {
          if (lastBox != null &&
              lastBox.hasSize &&
              lastBox.size.width >= refSize.width * 0.85 &&
              lastBox.size.height >= refSize.height * 0.85) {
            pageRoot = lastBox;
          }
        }
        if (current is RenderBox) {
          lastBox = current;
        }
        current = current.parent;
      }
      Offset pos = localToGlobal(Offset.zero, ancestor: pageRoot);
      if (refSize.width > 0 && (pos.dx < 0.0 || pos.dx >= refSize.width)) {
        pos = Offset(
          ((pos.dx % refSize.width) + refSize.width) % refSize.width,
          pos.dy,
        );
      }
      return pos;
    } catch (_) {
      return Offset.zero;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final rect = offset & size;
    final radius = Radius.circular(cornerRadius);
    final rsuperellipse = RSuperellipse.fromRectAndRadius(rect, radius);

    // 1. [v3.1.3 采用 Impeller 超椭圆单通解析阴影优化]
    //    在 Impeller 下，drawRSuperellipse 采用硬件单通解析高斯模糊 (analytic single-pass)，
    //    比 PathFillType.evenOdd + clipPath 快 10 倍以上！
    //    当存在静态模糊壁纸采样 (blurredImage != null) 时，卡片内部紧接着会被 100% 不透明的
    //    壁纸模糊纹理完全覆盖，因此根本不需要昂贵的逆向 Path 裁剪；仅在无壁纸纯色半透模式下保留逆向裁剪。
    if (shadows.isNotEmpty) {
      final bool needsInverseClip =
          blurredImage == null && backgroundColor.a < 0.99;
      if (needsInverseClip) {
        final path = shape.getOuterPath(rect);
        final invPath = Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(rect.inflate(48.0))
          ..addPath(path, Offset.zero);
        canvas.save();
        canvas.clipPath(invPath);
        for (final s in shadows) {
          final shadowRect = rect.shift(s.offset).inflate(s.spreadRadius);
          canvas.drawRSuperellipse(
            RSuperellipse.fromRectAndRadius(shadowRect, radius),
            s.toPaint(),
          );
        }
        canvas.restore();
      } else {
        for (final s in shadows) {
          final shadowRect = rect.shift(s.offset).inflate(s.spreadRadius);
          canvas.drawRSuperellipse(
            RSuperellipse.fromRectAndRadius(shadowRect, radius),
            s.toPaint(),
          );
        }
      }
    }

    // 2. [v3.1.3 采用 Impeller 硬件级超椭圆裁剪]
    //    直接使用 canvas.clipRSuperellipse 替代 canvas.clipPath(shape.getOuterPath(rect))，
    //    彻底消除每张卡片每帧的 Path 顶点细分与 Stencil 多边形光栅化开销！
    canvas.save();
    canvas.clipRSuperellipse(rsuperellipse);

    // 3. 屏幕物理绝对坐标视窗采样 (带 ImageShader 缓存)
    if (blurredImage != null) {
      final refSize =
          StaticBlurredWallpaperService.instance.bakedScreenSize ?? screenSize;
      if (refSize.width > 0 && refSize.height > 0) {
        final globalOffset = _resolvePageGlobalOffset(refSize);
        final imgW = blurredImage!.width.toDouble();
        final imgH = blurredImage!.height.toDouble();
        final scaleX = refSize.width / imgW;
        final scaleY = refSize.height / imgH;

        final transX = offset.dx - globalOffset.dx;
        final transY = offset.dy - globalOffset.dy;

        if (!identical(_cachedShaderImage, blurredImage) ||
            _shaderPaint.shader == null ||
            (transX - _cachedTransX).abs() > 0.25 ||
            (transY - _cachedTransY).abs() > 0.25 ||
            (scaleX - _cachedScaleX).abs() > 0.001 ||
            (scaleY - _cachedScaleY).abs() > 0.001) {
          _cachedShaderImage = blurredImage;
          _cachedTransX = transX;
          _cachedTransY = transY;
          _cachedScaleX = scaleX;
          _cachedScaleY = scaleY;

          final matrix = Matrix4.identity()
            ..translate(transX, transY)
            ..scale(scaleX, scaleY);

          _shaderPaint.shader = ImageShader(
            blurredImage!,
            TileMode.clamp,
            TileMode.clamp,
            matrix.storage,
            filterQuality: FilterQuality.medium,
          );
        }

        canvas.drawRect(rect, _shaderPaint);
      }
    }

    // 4. 绘制表面混色半透层
    canvas.drawRect(rect, _bgPaint);

    // 5. 绘制边框 (若有显式传入边框)
    if (shape is OutlinedBorder && (shape as OutlinedBorder).side != BorderSide.none) {
      shape.paint(canvas, rect);
    }

    canvas.restore();

    // 6. 绘制子组件
    if (child != null) {
      context.paintChild(child!, offset);
    }
  }
}
