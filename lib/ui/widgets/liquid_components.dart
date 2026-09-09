import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Material;
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:flutter_miuix/miuix.dart';
import '../../constants/theme_constants.dart';
import '../../utils/glass_settings_helper.dart';
import '../../services/theme_service.dart' as theme;
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
            quality: GlassQuality.premium,
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
              fresnelStrength: 0.05,
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
  final GlassQuality quality;

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
    this.quality = GlassQuality.premium,
    bool? useFakeGlass,
    bool? isDisabled,
  });

  @override
  Widget build(BuildContext context) {
    // [v2.7.8] 智能检测是否位于父级玻璃图层中，实现共享图层与独立渲染自适应
    final inLayer = context.dependOnInheritedWidgetOfExactType<InheritedLiquidGlass>() != null;

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
            fresnelStrength: 0.05,
            specularSharpness: GlassSpecularSharpness.medium,
          )
        : (isPanel
            ? GlassSettingsHelper.panelSettings
            : GlassSettingsHelper.defaultSettings).copyWith(
                bodyMode: GlassBodyMode.adaptive,
                edgeAbsorption: 0.0, // [v2.8.9] 消除边缘吸光暗角
                ambientRim: 0.0,
                fresnelStrength: 0.05,
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
            quality: quality,
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
  });

  @override
  Widget build(BuildContext context) {
    final inLayer = context.dependOnInheritedWidgetOfExactType<InheritedLiquidGlass>() != null;
    final isDark = globalDarkModeNotifier.value;
    final lum = color.computeLuminance();
    final Color effectiveTextColor = textColor ??
        (isOutline
            ? (isDark ? Colors.white70 : const Color(0xFF2D313A))
            : (lum > 0.55 && !isDark ? const Color(0xFF1E2129) : Colors.white));

    return GlassButton.custom(
      onTap: onTap ?? () {},
      width: width,
      height: height ?? 48,
      style: GlassButtonStyle.filled,
      useOwnLayer: useOwnLayer ?? !inLayer,
      quality: GlassQuality.premium,
      settings: LiquidGlassSettings(
        glassColor: isOutline
            ? (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06))
            : color.withValues(alpha: 0.7),
        blur: 2.0,
        thickness: 12.0,
        refractiveIndex: 1.35,
        lightIntensity: 0.65,
        bodyMode: GlassBodyMode.adaptive,
        edgeAbsorption: 0.0,
        ambientRim: 0.0,
        fresnelStrength: 0.05,
        specularSharpness: GlassSpecularSharpness.medium,
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

// [v2.8.6] 统一使用官方 GlassDialog 超椭圆规格，消除 ClipSmoothRect 造成的双重裁剪与形变
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

  @override
  Widget build(BuildContext context) {
    return GlassDialog(
      title: title,
      maxWidth: maxWidth,
      content: DefaultTextStyle(
        style: const TextStyle(
          fontSize: 15,
          color: Colors.white70,
          fontFamily: 'PingFangSC',
          height: 1.5,
        ),
        textAlign: TextAlign.left,
        child: content,
      ),
      actions: actions ??
          [
            GlassDialogAction(
              label: '确定',
              onPressed: () => Navigator.pop(context),
              isPrimary: true,
            ),
          ],
      settings: LiquidGlassSettings(
        glassColor: const Color(0xFF2D2D2D).withValues(alpha: 0.5),
        blur: 4.0,
        thickness: 16.0,
        refractiveIndex: 1.30,
        lightIntensity: 0.70,
        ambientStrength: 0.25,
      ),
    );
  }
}

// [v2.8.6] 平滑丝滑缩放微弹遮罩
Future<T?> showLiquidDialog<T>({
  required BuildContext context,
  required Widget builder,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.25),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, anim1, anim2) => builder,
    transitionBuilder: (ctx, anim1, anim2, child) {
      return Stack(
        children: [
          FadeTransition(
            opacity: anim1,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                color: Colors.black.withValues(alpha: 0.15),
              ),
            ),
          ),
          ScaleTransition(
            scale: CurvedAnimation(
              parent: anim1,
              curve: Curves.easeOutCubic,
            ),
            child: FadeTransition(
              opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOut),
              child: child,
            ),
          ),
        ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 6),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
        ),
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: GlassContainer(
            shape: LiquidRoundedSuperellipse(borderRadius: 18),
            settings: LiquidGlassSettings(
              glassColor: Colors.black.withValues(alpha: 0.3),
              blur: 0,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              cursorColor: AppThemeColors.babyPink,
                              decoration: null,
                              placeholder: placeholder ?? '请输入$label',
                              placeholderStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Text(
                              valueText ?? placeholder ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ),
                  ),
                  if (isReadOnly || controller == null)
                    Icon(
                      CupertinoIcons.chevron_down,
                      color: Colors.white.withValues(alpha: 0.5),
                      size: 16,
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class LiquidBackButton extends StatelessWidget {
  const LiquidBackButton({super.key});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      behavior: HitTestBehavior.opaque,
      child: LiquidStretch(
        stretch: 0.15,
        child: GlassContainer(
          shape: LiquidRoundedSuperellipse(borderRadius: 22),
          settings: LiquidGlassSettings(
            glassColor: Colors.white.withValues(alpha: 0.1),
            blur: 2.0,
            thickness: 12.0,
            refractiveIndex: 1.25,
            lightIntensity: 0.65,
            ambientStrength: 0.15,
          ),
          child: const SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Icon(CupertinoIcons.back, size: 24, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

/// [v2.8.9] 基于 Flutter MiuiX 与 Liquid Glass 规范的 HyperOS 超椭圆混色无边框卡片
///
/// 特性：
/// 1. 采用与 Liquid Glass 完全一致的大曲率 RoundedSuperellipseBorder 连续超椭圆圆角（默认 20.0）
/// 2. 彻底移除生硬边框（BorderSide.none），采用环境光多层立体投影自然界定卡片边界
/// 3. 消除按压时的灰色暗影蒙层（overlayColor: Colors.transparent），仅保留轻快弹性微交互下沉触感 (MiuixPressFeedbackType.sink)
/// 4. 视口级单层模糊共享架构，课程网格多卡片极速满帧渲染
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
    this.cornerRadius = 24, // [v2.9.0] 超椭圆 24，对齐 LiquidRoundedSuperellipse
    this.padding = const EdgeInsets.all(12),
    this.color,
    this.contentColor,
    this.useBlur = false, // [v2.9.0] 默认单层模糊共享架构，避免多卡片离屏模糊爆炸
    this.blurRadius = 10.0,
    this.feedbackType = MiuixPressFeedbackType.sink,
    this.border,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = globalDarkModeNotifier.value;
    final primary = theme.ThemeService().primaryColor;

    // [v2.9.0] HyperOS 混色半透明丙烯酸质感：通透柔和，透出背景壁纸与主题色融合
    final defaultBgColor = isDark
        ? Color.alphaBlend(primary.withValues(alpha: 0.14), const Color(0x991C2028))
        : Color.alphaBlend(primary.withValues(alpha: 0.12), const Color(0xB8FFFFFF));

    // 如果指定了自定义颜色（例如课程卡片自定义整卡染色），直接应用；否则使用默认半透明丙烯酸底色
    final effectiveColor = color ?? defaultBgColor;

    // [v2.9.0] 字体颜色根据最终背景计算明度（computeLuminance），确保黑白高对比 100% 极速自适应
    final lum = effectiveColor.computeLuminance();
    final autoTextColor = lum > 0.45 ? const Color(0xFF1B1D24) : const Color(0xFFF2F5FA);
    final effectiveTextColor = contentColor ?? autoTextColor;

    // [v2.9.0] 用户明确要求：彻底移除生硬边框（默认 BorderSide.none），纯靠柔和投影界定边界
    final effectiveBorderSide = border ?? BorderSide.none;

    // 采用与 liquid_glass_widgets 内部一致的 RoundedSuperellipseBorder，保证曲率完全对齐统一
    final shape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.all(Radius.circular(cornerRadius)),
      side: effectiveBorderSide,
    );

    // [v2.9.0] 增强浅色模式阴影可见度，赋予卡片清晰的物理层次与立体感
    final effectiveShadows = shadows ?? [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.36 : 0.20),
        blurRadius: isDark ? 14 : 16,
        spreadRadius: isDark ? 0 : 0.5,
        offset: const Offset(0, 4),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.12),
        blurRadius: 5,
        offset: const Offset(0, 1.5),
      ),
    ];

    Widget cardBody = DecoratedBox(
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

    if (useBlur) {
      cardBody = ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurRadius, sigmaY: blurRadius),
          child: cardBody,
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
