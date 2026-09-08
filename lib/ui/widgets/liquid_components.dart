import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Material;
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:flutter_miuix/miuix.dart';
import '../../constants/theme_constants.dart';
import '../../utils/glass_settings_helper.dart';
import '../../main.dart';

enum LiquidStyleType { standard, micro, active }

void showNativeToast(String msg) {
  // 使用纯 Flutter 实现，无需 fluttertoast
  debugPrint("Toast: $msg");
}

// [修复3] Toast透明度优化 - 更透明
void showLiquidToast(BuildContext context, String msg) {
  final overlay = Overlay.of(context);
  final entry = OverlayEntry(
    builder: (context) => Positioned(
      bottom: 50,
      left: 20,
      right: 20,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: GlassContainer(
            shape: LiquidRoundedSuperellipse(borderRadius: 20),
            settings: LiquidGlassSettings(
              glassColor: Colors.black.withValues(alpha: 0.4), // [修复] 降低不透明度
              blur: 3.0,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                msg,
                style: const TextStyle(color: Colors.white, fontSize: 14),
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
            edgeAbsorption: 0.18,
            ambientRim: 0.0,
            fresnelStrength: 0.05,
            specularSharpness: GlassSpecularSharpness.medium,
          )
        : (isPanel
            ? GlassSettingsHelper.panelSettings
            : GlassSettingsHelper.defaultSettings).copyWith(
                bodyMode: GlassBodyMode.adaptive,
                edgeAbsorption: 0.18,
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

  const LiquidButton({
    super.key,
    required this.text,
    required this.onTap,
    required this.color,
    this.isOutline = false,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return GlassButton.custom(
      onTap: onTap ?? () {},
      width: width,
      height: height ?? 48,
      style: GlassButtonStyle.filled,
      settings: LiquidGlassSettings(
        glassColor: isOutline
            ? Colors.white.withValues(alpha: 0.1)
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
      shape: LiquidRoundedSuperellipse(borderRadius: 16),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: isOutline ? Colors.white70 : Colors.white,
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

/// [v2.8.6] 基于 Flutter MiuiX (HyperOS) 的高性能轻量级卡片
///
/// 专用于频繁重绘与高速滚动的课程卡片、日历网格卡片以及设置界面列表卡片。
/// 特性：
/// 1. 采用 MiuixSquircleBorder 完美平滑连续超椭圆圆角与细腻边框
/// 2. 具备 HyperOS 原生按压动效与反馈 (MiuixPressFeedbackType.sink)
/// 3. 混色半透明背景 (Color.alphaBlend 主题微透)，零 Impeller 多通道着色器负担
/// 4. 默认关闭 BackdropFilter (useBlur: false)，彻底解放 GPU 渲染算力，保障全局 120 FPS 满帧运行
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

  const HyperOSCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.cornerRadius = 16,
    this.padding = const EdgeInsets.all(12),
    this.color,
    this.contentColor,
    this.useBlur = false, // [v2.8.6] 默认关闭多通道模糊以维持 120 FPS 满帧
    this.blurRadius = 6.0,
    this.feedbackType = MiuixPressFeedbackType.sink,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = globalDarkModeNotifier.value;
    final primary = AppThemeColors.babyPink;

    // HyperOS 混色半透明背景：微透主题粉色与高品质中性底色融合
    final defaultBgColor = isDark
        ? Color.alphaBlend(primary.withValues(alpha: 0.10), const Color(0x331C202A))
        : Color.alphaBlend(primary.withValues(alpha: 0.08), const Color(0x38FFFFFF));

    final effectiveColor = color ?? defaultBgColor;
    final effectiveTextColor = contentColor ??
        (isDark ? const Color(0xFFF0F3F8) : Colors.white);

    final effectiveBorderSide = border ??
        BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.white.withValues(alpha: 0.40),
          width: 0.8,
        );

    final shape = MiuixSquircleBorder(
      cornerRadius: cornerRadius,
      side: effectiveBorderSide,
      enabled: cornerRadius > 0,
    );

    Widget innerContent = Padding(
      padding: padding,
      child: child,
    );

    if (useBlur) {
      innerContent = ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurRadius, sigmaY: blurRadius),
          child: innerContent,
        ),
      );
    }

    Widget cardContent = MiuixContentColor(
      color: effectiveTextColor,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: effectiveColor,
          shape: shape,
        ),
        child: innerContent,
      ),
    );

    if (onTap != null || onLongPress != null || feedbackType != MiuixPressFeedbackType.none) {
      cardContent = MiuixPressable(
        onPressed: onTap,
        onLongPress: onLongPress,
        feedbackType: feedbackType,
        borderRadius: BorderRadius.circular(cornerRadius),
        child: cardContent,
      );
    }

    return cardContent;
  }
}
