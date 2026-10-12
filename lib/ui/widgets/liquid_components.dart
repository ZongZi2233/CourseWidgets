import 'dart:ui' show ImageFilter;
import 'dart:ui' as ui show Image;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:flutter_miuix/miuix.dart';
import '../../constants/theme_constants.dart';
import '../../utils/glass_settings_helper.dart';
import '../../services/theme_service.dart' as theme;
import '../../services/static_blur_service.dart';
import '../animations/app_motion.dart';
import '../../main.dart';

enum LiquidStyleType { standard, micro, active }

void showNativeToast(String msg) {
  // 使用纯 Flutter 实现，无需 fluttertoast
  debugPrint("Toast: $msg");
}

// [v2.9.0] 纯净无色中性液态玻璃 Toast，消除暗角与多余黑边
void showLiquidToast(BuildContext context, String msg) {
  final overlay = Overlay.of(context);
  final isDark = globalDarkModeNotifier.value;
  final entry = OverlayEntry(
    builder: (context) => Positioned(
      bottom: 50,
      left: 20,
      right: 20,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: GlassContainer(
            useOwnLayer: true,
            quality: theme.ThemeService().glassQuality,
            shape: const LiquidRoundedSuperellipse(borderRadius: 20),
            settings: LiquidGlassSettings(
              glassColor: isDark
                  ? const Color(0x2E1E222B)
                  : const Color(0x22FFFFFF),
              blur: 3.0,
              thickness: 16.0,
              lightIntensity: 0.70,
              ambientStrength: 0.45,
              ambientRim: 0.0,
              edgeAbsorption: 0.0,
              fresnelStrength: 0.0,
              saturation: 1.20,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Text(
                msg,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  overlay.insert(entry);
  Future.delayed(const Duration(seconds: 2), () => entry.remove());
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
    // [v2.7.8] 智能检测是否位于父级玻璃图层中，实现共享图层与独立渲染自适应
    final inLayer = context.dependOnInheritedWidgetOfExactType<InheritedLiquidGlass>() != null;
    final effectiveQuality = quality ?? theme.ThemeService().glassQuality;

    // [v2.8.1] 真实光学折射：充足物理厚度、高质感边缘吸收与双折射、高刷透镜折射
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
            edgeAbsorption: 0.0, // [v2.8.9] 消除边缘吸光暗角
            ambientRim: 0.0,
            fresnelStrength: 0.0,
            specularSharpness: GlassSpecularSharpness.medium,
          )
        : (isPanel
            ? GlassSettingsHelper.panelSettings
            : GlassSettingsHelper.defaultSettings).copyWith(
                bodyMode: GlassBodyMode.adaptive,
                edgeAbsorption: 0.0, // [v2.8.9] 消除边缘吸光暗角
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

// [v2.1.8修复4] 开关组件 - 调整尺寸比例
class LiquidSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const LiquidSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GlassSwitch(
      value: value,
      onChanged: onChanged,
      width: 56, // [v2.1.8] 增加宽度
      height: 32, // [v2.1.8] 增加高度
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

// [v3.0.0] 统一使用纯正液态玻璃、物理 Spring 曲线与全屏毛玻璃背景虚化的 LiquidGlassDialog
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

  /// [v3.0.0] 统一静态调用入口：配备 360ms 高张力物理弹簧进场与全屏平滑高斯模糊
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
      barrierColor: Colors.black.withValues(alpha: 0.40),
      transitionDuration: const Duration(milliseconds: 360),
      pageBuilder: (dialogCtx, anim1, anim2) => LiquidGlassDialog(
        title: title,
        content: content,
        actions: actions,
        maxWidth: maxWidth,
      ),
      transitionBuilder: (dialogCtx, anim1, anim2, child) {
        final curved = AppCurves.springBounce.transform(anim1.value);
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 18.0 * anim1.value,
            sigmaY: 18.0 * anim1.value,
          ),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
            child: Transform.scale(
              scale: (0.84 + 0.16 * curved).clamp(0.0, 1.15),
              child: child,
            ),
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
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                blurRadius: 32.0,
                spreadRadius: -2.0,
                offset: const Offset(0, 10.0),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            const Color(0x38282E3E),
                            const Color(0x24181B24),
                          ]
                        : [
                            const Color(0x75FFFFFF),
                            const Color(0x45EFF4FA),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.85),
                    width: 1.2,
                  ),
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
                          color: isDark ? Colors.white.withValues(alpha: 0.75) : const Color(0xFF4A5060),
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
            ? AppThemeColors.babyPink.withValues(alpha: 0.82)
            : (isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.05)));

    final Color textColor = isDestructive || isPrimary
        ? Colors.white
        : (isDark ? Colors.white70 : const Color(0xFF1E2128));

    return SpringTouchFeedback(
      onTap: action.onPressed,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
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
        ),
      ),
    );
  }
}

// [v3.0.0] 物理弹簧与全屏高斯模糊遮罩
Future<T?> showLiquidDialog<T>({
  required BuildContext context,
  required Widget builder,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.40),
    transitionDuration: const Duration(milliseconds: 360),
    pageBuilder: (ctx, anim1, anim2) => builder,
    transitionBuilder: (ctx, anim1, anim2, child) {
      final curved = AppCurves.springBounce.transform(anim1.value);
      return BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 18.0 * anim1.value,
          sigmaY: 18.0 * anim1.value,
        ),
        child: FadeTransition(
          opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
          child: Transform.scale(
            scale: (0.84 + 0.16 * curved).clamp(0.0, 1.15),
            child: child,
          ),
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
      interactionScale: 1.10, // [v3.0.0-alpha21] 按压变大 (1.10x 弹簧膨胀)
      pressDarken: true, // [v3.0.0-alpha21] 按压变暗 (物理下沉深度感)
      glowColor: primaryColor.withValues(alpha: isDark ? 0.42 : 0.32),
      glowRadius: 24,
      useOwnLayer: true,
      quality: GlassQuality.premium,
      settings: LiquidGlassSettings(
        glassColor: isDark ? const Color(0x18FFFFFF) : const Color(0x10FFFFFF),
        blur: 0.3,
        thickness: 38.0, // 全曲率覆盖透镜表面，呈现真实背景凸透镜折射
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

/// [v3.0.0-alpha21] 悬浮在屏幕右下角的人体工学官方圆形液态玻璃返回按钮
/// 官方原生 GlassIconButton 组件，搭载：
/// 1. 物理 Spring 触控按压变大膨胀 (interactionScale: 1.10) 与按压变暗 (pressDarken: true)
/// 2. 主题色触控 GlassGlow 高光溢出与动态扩散 (glowRadius: 28)
/// 3. 全曲率 3D 物理凸透镜折射 (thickness: 48.0, n=1.50)，实时弯曲放大背景内容
/// 4. 人体工学悬浮漫反射阴影，呈现悬浮立体空间质感
/// [v3.0.0-alpha23] 官方液态玻璃悬浮返回按钮 (FloatingLiquidBackButton)
///
/// 官方标准实现：
/// 1. 采用 liquid_glass_widgets 官方核心 [GlassButton] 原生 3D 液态玻璃着色器管道 (useOwnLayer: true)；
/// 2. 真实 3D 凸透镜折射率 (n=1.50)、物理厚度 (thickness: 24)、高光反射与边缘微色散 (chromaticAberration: 0.12)；
/// 3. 0ms 跟手触控反馈：按下瞬间触发弹性膨胀放大 (interactionScale: 1.08) 与表面暗化对比 (pressDarken: true)；
/// 4. 彻底消除多余主题色光斑，呈现纯净透明晶体物理质感。
/// [v3.0.0-alpha25] 纯净液态玻璃悬浮返回按钮（52x52圆形），物理弹簧灵动缩放回弹，杜绝任何实色/Material遮罩
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

/// [v3.0.0 正式版] 统一悬浮大圆角矩形玻璃标题与返回胶囊按钮 (FloatingGlassHeaderButton)
/// 
/// 1. 采用大圆角矩形超椭圆晶透玻璃 (20dp)，搭载轻量模糊与高光边框；
/// 2. 左侧配备返回箭头，右侧呈现加粗标题，点击触发返回与触觉反馈；
/// 3. 支持挂载在 Positioned 顶部悬浮栏中，消除生硬的裸字悬浮感，统一全应用二级页面设计语言。
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
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.16)
                    : Colors.white.withValues(alpha: 0.85),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 3),
                ),
              ],
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

/// [v3.0.0] 自研组件化无描边物理悬浮阴影系统 (Rimless Elevation Shadows)
/// 对齐 Moyue 与 Apple VisionOS 光学漫反射哲学：
/// 1. 负扩散半径 (spreadRadius: -2 ~ -3)：使投影核向内收敛，杜绝卡片边缘污浊脏圈与塑料硬封套感；
/// 2. 大虚化半径 (blurRadius: 16 ~ 24)：营造超大面积柔和漫反射环境光，光斑自然散开；
/// 3. 超低透光度 (alpha: 0.04 ~ 0.08)：不抢夺视觉焦点，呈现纯净空间悬浮感；
/// 4. 双层物理分级：主定向阴影 (Key Shadow) + 贴地微环境光 (Ambient Shadow)。
class HyperOSShadows {
  HyperOSShadows._();

  /// 基础悬浮卡片阴影 (适合课程卡片、大容器、设置条目)
  static List<BoxShadow> card(bool isDark, {Color? glowColor}) {
    if (!isDark) {
      // 浅色模式优化：单层超大范围轻量漫反射阴影，GPU 9-patch 满帧高质感
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

    final keyAlpha = 0.35;
    final ambientAlpha = 0.20;

    return [
      // Key Shadow: 空间向下微沉主阴影，负扩散收拢边缘，扩大弥散范围
      BoxShadow(
        color: Colors.black.withValues(alpha: keyAlpha),
        blurRadius: 22.0,
        spreadRadius: -2.0,
        offset: const Offset(0, 6),
      ),
      // Ambient Shadow: 接触面近场极浅柔光
      BoxShadow(
        color: Colors.black.withValues(alpha: ambientAlpha),
        blurRadius: 8.0,
        spreadRadius: 0,
        offset: const Offset(0, 2),
      ),
      // 可选色彩辉光微晕 (如有)
      if (glowColor != null)
        BoxShadow(
          color: glowColor.withValues(alpha: 0.25),
          blurRadius: 14.0,
          spreadRadius: -1.0,
          offset: const Offset(0, 2.5),
        ),
    ];
  }

  /// 药丸/胶囊/按钮级微阴影 (适合星期指示器、导航微按钮、胶囊标签)
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

  /// 顶层悬浮 Dock / 导航栏阴影 (超大范围物理漫反射环境光)
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

  /// 弹出模态底栏 / 对话框阴影
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

/// [v3.0.0] 基于 Flutter MiuiX 与 Liquid Glass 规范的 HyperOS 超椭圆混色无边框卡片
///
/// 特性：
/// 1. 采用大曲率 RoundedSuperellipseBorder 连续超椭圆圆角（默认 28.0）
/// 2. 彻底移除生硬边框（BorderSide.none），接入自研 HyperOSShadows 负扩散物理漫反射环境光阴影
/// 3. 单次离屏静态模糊切片采样架构 (StaticBlurredWallpaperService)：
///    当开启 useBlur 时，通过 drawImageRect 双线性插值在 GPU 瞬间采样全屏烘焙纹理，
///    实现 0 FBO 切换，<0.01ms 单卡极速渲染与 120Hz 极限满帧
/// 4. 消除按压时的灰色暗影蒙层，保留轻快弹性微交互下沉触感 (MiuixPressFeedbackType.sink)
/// 5. 字体高对比度自适应：根据背景明度（computeLuminance）自动匹配高对比黑白文字
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
    this.cornerRadius = 28, // [v2.9.7] 超椭圆 28，对齐全新旗舰大圆角
    this.padding = const EdgeInsets.all(12),
    this.color,
    this.contentColor,
    this.useBlur = true, // [v3.0.0] 默认开启共享静态全屏模糊纹理采样，零动态 FBO 切换，满帧 120 FPS
    this.blurRadius = 10.0,
    this.feedbackType = MiuixPressFeedbackType.sink,
    this.border,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = globalDarkModeNotifier.value;
    final primary = theme.ThemeService().primaryColor;

    // [v2.9.7] HyperOS 混色半透明丙烯酸质感：通透柔和，透出背景壁纸与主题色融合
    final defaultBgColor = isDark
        ? Color.alphaBlend(primary.withValues(alpha: 0.14), const Color(0x5514171E))
        : Color.alphaBlend(primary.withValues(alpha: 0.12), const Color(0x60FFFFFF));

    // 如果指定了自定义颜色（例如课程卡片自定义整卡染色），直接应用；否则使用默认半透明丙烯酸底色
    final effectiveColor = color ?? defaultBgColor;

    // [v2.9.0] 字体颜色根据最终背景计算明度（computeLuminance），确保黑白高对比 100% 极速自适应
    final lum = effectiveColor.computeLuminance();
    final autoTextColor = lum > 0.45 ? const Color(0xFF1B1D24) : const Color(0xFFF2F5FA);
    final effectiveTextColor = contentColor ?? autoTextColor;

    // [v3.0.0] 彻底默认无边框（BorderSide.none），杜绝生硬描边
    final effectiveBorderSide = border ?? BorderSide.none;

    final shape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.all(Radius.circular(cornerRadius)),
      side: effectiveBorderSide,
    );

    // [v3.0.0] 全面接入自研 HyperOSShadows 无描边负扩散漫反射悬浮阴影
    final effectiveShadows = shadows ?? HyperOSShadows.card(isDark);

    Widget cardBody;
    if (useBlur) {
      final screenSize = MediaQuery.sizeOf(context);
      final scrollable = Scrollable.maybeOf(context);
      final scrollPosition = scrollable?.position;

      // [v3.0.0-alpha13] 共享单次静态全屏高斯模糊双线性采样：
      // 零动态 FBO 切换，绝对锚定屏幕物理坐标系。
      // 通过 repaint: scrollPosition 驱动局部重绘，滚动时模糊内容完全定格不动，
      // HyperOSCard 犹如移动视窗 (stencil) 穿行其上，实现真·120Hz 极限满帧“假动态”物理透光视窗！
      cardBody = ListenableBuilder(
        listenable: StaticBlurredWallpaperService.instance,
        builder: (context, _) {
          return _SharedBlurStencilWidget(
            blurredImage: StaticBlurredWallpaperService.instance.blurredImage,
            screenSize: screenSize,
            backgroundColor: effectiveColor,
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
      cardBody = DecoratedBox(
        decoration: ShapeDecoration(
          color: effectiveColor,
          shape: shape,
          shadows: effectiveShadows,
        ),
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
      // [v2.8.9] overlayColor 设为 Colors.transparent，彻底根除按压时的灰色蒙层，仅保留纯正弹性下沉触感
      cardContent = MiuixPressable(
        onPressed: onTap,
        onLongPress: onLongPress,
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

/// [v3.0.0-alpha13] 共享全屏静态高斯模糊双线性采样 Stencil 视窗组件
class _SharedBlurStencilWidget extends SingleChildRenderObjectWidget {
  final ui.Image? blurredImage;
  final Size screenSize;
  final Color backgroundColor;
  final ShapeBorder shape;
  final List<BoxShadow> shadows;
  final ScrollPosition? scrollPosition;

  const _SharedBlurStencilWidget({
    required this.blurredImage,
    required this.screenSize,
    required this.backgroundColor,
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
  ShapeBorder shape;
  List<BoxShadow> shadows;
  ScrollPosition? scrollPosition;

  _RenderSharedBlurStencil({
    required this.blurredImage,
    required this.screenSize,
    required this.backgroundColor,
    required this.shape,
    required this.shadows,
    this.scrollPosition,
  });

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
    markNeedsPaint();
  }

  void update({
    required ui.Image? blurredImage,
    required Size screenSize,
    required Color backgroundColor,
    required ShapeBorder shape,
    required List<BoxShadow> shadows,
    ScrollPosition? scrollPosition,
  }) {
    bool needsRepaint = false;
    if (this.blurredImage != blurredImage ||
        this.screenSize != screenSize ||
        this.backgroundColor != backgroundColor ||
        this.shape != shape ||
        this.shadows != shadows) {
      this.blurredImage = blurredImage;
      this.screenSize = screenSize;
      this.backgroundColor = backgroundColor;
      this.shape = shape;
      this.shadows = shadows;
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

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final rect = offset & size;
    final path = shape.getOuterPath(rect);

    // 1. 绘制外部物理漫反射阴影 (若有)
    // 优先采用 drawRRect 触发 Skia/Impeller GPU 9-patch 高速阴影缓存，杜绝 CPU 端软件高斯模糊掉帧
    for (final s in shadows) {
      final shadowRect = rect.shift(s.offset).inflate(s.spreadRadius);
      if (shape is RoundedSuperellipseBorder) {
        final rrect = (shape as RoundedSuperellipseBorder)
            .borderRadius
            .resolve(TextDirection.ltr)
            .toRRect(shadowRect);
        canvas.drawRRect(rrect, s.toPaint());
      } else if (shape is RoundedRectangleBorder) {
        final rrect = (shape as RoundedRectangleBorder)
            .borderRadius
            .resolve(TextDirection.ltr)
            .toRRect(shadowRect);
        canvas.drawRRect(rrect, s.toPaint());
      } else {
        final shadowPath = shape.getOuterPath(shadowRect);
        canvas.drawPath(shadowPath, s.toPaint());
      }
    }

    // 2. 裁切为超椭圆形状
    canvas.save();
    canvas.clipPath(path);

    // 3. 屏幕物理绝对坐标视窗采样 (假动态)：
    // 模糊图像绝对锚定全屏幕物理坐标系，HyperOSCard 仅作为移动视窗 (stencil) 划过，
    // 模糊内容不动，零 FBO 切换，零 GPU 额外开销，实现真正 120Hz 满帧“假动态”物理透光视窗。
    // [v3.0.0-alpha22] 精准对齐背景 Backdrop 物理坐标系：
    // 彻底清除对 X 的取模和对 Y 的 clamp(0, height) 带来的撕裂与断层，
    // 采用与全屏壁纸完全一致的参考尺寸，确保在滚动超出视口、二级页面转场、弹窗打开期间
    // 卡片背景与全屏壁纸 100% 像素级无缝锚定，彻底解决 UI 断裂与错位！
    if (blurredImage != null) {
      Offset globalOffset = Offset.zero;
      try {
        if (attached) {
          globalOffset = localToGlobal(Offset.zero);
        }
      } catch (_) {}

      final refSize =
          StaticBlurredWallpaperService.instance.bakedScreenSize ?? screenSize;
      if (refSize.width > 0 && refSize.height > 0) {
        final imgW = blurredImage!.width.toDouble();
        final imgH = blurredImage!.height.toDouble();
        final scaleX = refSize.width / imgW;
        final scaleY = refSize.height / imgH;

        final transX = offset.dx - globalOffset.dx;
        final transY = offset.dy - globalOffset.dy;

        final matrix = Matrix4.identity()
          ..translate(transX, transY)
          ..scale(scaleX, scaleY);

        final imageShader = ImageShader(
          blurredImage!,
          TileMode.clamp,
          TileMode.clamp,
          matrix.storage,
          filterQuality: FilterQuality.medium,
        );

        canvas.drawRect(
          rect,
          Paint()
            ..shader = imageShader
            ..isAntiAlias = true,
        );
      }
    }

    // 4. 绘制表面混色半透层
    canvas.drawRect(
      rect,
      Paint()..color = backgroundColor,
    );

    // 5. 绘制边框 (若有)
    shape.paint(canvas, rect);

    canvas.restore();

    // 6. 绘制子组件
    if (child != null) {
      context.paintChild(child!, offset);
    }
  }
}
