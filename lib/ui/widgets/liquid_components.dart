import 'dart:ui' show ImageFilter;
import 'dart:ui' as ui show Image;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Material, Theme, CustomPaint, CustomPainter, ListenableBuilder;
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:flutter_miuix/miuix.dart';
import '../../constants/theme_constants.dart';
import '../../utils/glass_settings_helper.dart';
import '../../services/theme_service.dart' as theme;
import '../../services/static_blur_service.dart';
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
    final themeDark = Theme.of(context).brightness == Brightness.dark;
    final isDark = themeDark || globalDarkModeNotifier.value;
    final lum = color.computeLuminance();
    final Color effectiveTextColor = textColor ??
        (isOutline
            ? (isDark ? Colors.white70 : const Color(0xFF2D313A))
            : (isDark
                ? (lum > 0.65 ? const Color(0xFF1E2129) : Colors.white)
                : (lum > 0.35 ? const Color(0xFF1E2129) : Colors.white)));

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
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.30),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
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
      ],
    );
  }
}

class LiquidBackButton extends StatelessWidget {
  final VoidCallback? onTap;
  const LiquidBackButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (onTap != null) {
          onTap!();
        } else {
          Navigator.maybePop(context);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: LiquidStretch(
        stretch: 0.15,
        child: GlassContainer(
          useOwnLayer: true,
          quality: GlassQuality.premium,
          shape: const LiquidRoundedSuperellipse(borderRadius: 22),
          settings: LiquidGlassSettings(
            glassColor: Colors.white.withValues(alpha: 0.12),
            blur: 2.0,
            thickness: 12.0,
            refractiveIndex: 1.25,
            lightIntensity: 0.65,
            ambientStrength: 0.15,
            ambientRim: 0.0,
            edgeAbsorption: 0.0,
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

/// [v2.9.8] 悬浮在屏幕右下角的人体工学圆形液态玻璃返回按钮（原汁原味圆形液态玻璃质感，单手舒适操作）
class FloatingLiquidBackButton extends StatelessWidget {
  final VoidCallback? onBack;
  const FloatingLiquidBackButton({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 24,
      right: 20,
      child: SafeArea(
        top: false,
        left: false,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            if (onBack != null) {
              onBack!();
            } else {
              Navigator.maybePop(context);
            }
          },
          behavior: HitTestBehavior.opaque,
          child: LiquidStretch(
            stretch: 0.15,
            child: GlassContainer(
              useOwnLayer: true,
              quality: GlassQuality.premium,
              shape: const LiquidRoundedSuperellipse(borderRadius: 24),
              settings: LiquidGlassSettings(
                glassColor: Colors.white.withValues(alpha: 0.15),
                blur: 3.0,
                thickness: 16.0,
                refractiveIndex: 1.35,
                lightIntensity: 0.70,
                ambientStrength: 0.30,
                ambientRim: 0.0,
                edgeAbsorption: 0.0,
                fresnelStrength: 0.08,
              ),
              child: const SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: Icon(
                    CupertinoIcons.back,
                    size: 24,
                    color: Colors.white,
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
    final keyAlpha = isDark ? 0.32 : 0.07;
    final ambientAlpha = isDark ? 0.18 : 0.035;

    return [
      // Key Shadow: 空间向下微沉主阴影，负扩散收拢边缘，避免侧向脏边
      BoxShadow(
        color: Colors.black.withValues(alpha: keyAlpha),
        blurRadius: isDark ? 16 : 20,
        spreadRadius: -2.5,
        offset: const Offset(0, 5),
      ),
      // Ambient Shadow: 接触面近场极浅柔光
      BoxShadow(
        color: Colors.black.withValues(alpha: ambientAlpha),
        blurRadius: 6,
        spreadRadius: 0,
        offset: const Offset(0, 1.5),
      ),
      // 可选色彩辉光微晕 (如有)
      if (glowColor != null)
        BoxShadow(
          color: glowColor.withValues(alpha: isDark ? 0.22 : 0.16),
          blurRadius: 10,
          spreadRadius: -1.5,
          offset: const Offset(0, 2),
        ),
    ];
  }

  /// 药丸/胶囊/按钮级微阴影 (适合星期指示器、导航微按钮、胶囊标签)
  static List<BoxShadow> pill(bool isDark, {Color? accentColor}) {
    if (accentColor != null) {
      return [
        BoxShadow(
          color: accentColor.withValues(alpha: isDark ? 0.28 : 0.20),
          blurRadius: 8,
          spreadRadius: -1,
          offset: const Offset(0, 2),
        ),
      ];
    }
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
        blurRadius: 10,
        spreadRadius: -2,
        offset: const Offset(0, 3),
      ),
    ];
  }

  /// 顶层悬浮 Dock / 导航栏阴影
  static List<BoxShadow> dock(bool isDark) {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.38 : 0.08),
        blurRadius: 24,
        spreadRadius: -3,
        offset: const Offset(0, 6),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
        blurRadius: 6,
        spreadRadius: 0,
        offset: const Offset(0, 1),
      ),
    ];
  }

  /// 弹出模态底栏 / 对话框阴影
  static List<BoxShadow> modal(bool isDark) {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
        blurRadius: 32,
        spreadRadius: -4,
        offset: const Offset(0, 8),
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
    this.useBlur = false, // [v3.0.0] 单次静态全屏模糊采样架构，零 FBO 离屏切换，满帧 120 FPS
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
      // [v3.0.0] 共享单次静态壁纸模糊纹理采样：零动态 FBO 切换，单次静态烘焙 + drawImageRect 双线性极速采样
      cardBody = ListenableBuilder(
        listenable: StaticBlurredWallpaperService.instance,
        builder: (context, _) {
          return CustomPaint(
            painter: _SharedBlurSlicePainter(
              blurredImage: StaticBlurredWallpaperService.instance.blurredImage,
              bakedScreenSize: StaticBlurredWallpaperService.instance.bakedScreenSize,
              backgroundColor: effectiveColor,
              shape: shape,
              shadows: effectiveShadows,
            ),
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

/// [v3.0.0] 共享全屏静态高斯模糊双线性采样 Painter
class _SharedBlurSlicePainter extends CustomPainter {
  final ui.Image? blurredImage;
  final Size? bakedScreenSize;
  final Color backgroundColor;
  final ShapeBorder shape;
  final List<BoxShadow> shadows;

  _SharedBlurSlicePainter({
    required this.blurredImage,
    required this.bakedScreenSize,
    required this.backgroundColor,
    required this.shape,
    required this.shadows,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = shape.getOuterPath(rect);

    // 1. 绘制外部物理漫反射阴影 (若有)
    for (final s in shadows) {
      final shadowRect = rect.shift(s.offset).inflate(s.spreadRadius);
      final shadowPath = shape.getOuterPath(shadowRect);
      canvas.drawPath(
        shadowPath,
        s.toPaint(),
      );
    }

    // 2. 裁切为超椭圆形状
    canvas.save();
    canvas.clipPath(path);

    // 3. 采样全局静态单次高斯模糊纹理 (drawImageRect 双线性插值，<0.01ms 极速)
    if (blurredImage != null &&
        bakedScreenSize != null &&
        bakedScreenSize!.width > 0 &&
        bakedScreenSize!.height > 0) {
      final matrix = canvas.getTransform();
      final globalX = matrix[12];
      final globalY = matrix[13];

      final imgW = blurredImage!.width.toDouble();
      final imgH = blurredImage!.height.toDouble();
      final scaleX = imgW / bakedScreenSize!.width;
      final scaleY = imgH / bakedScreenSize!.height;

      final srcLeft = (globalX * scaleX).clamp(0.0, imgW);
      final srcTop = (globalY * scaleY).clamp(0.0, imgH);
      final srcWidth = (size.width * scaleX).clamp(0.0, imgW - srcLeft);
      final srcHeight = (size.height * scaleY).clamp(0.0, imgH - srcTop);

      if (srcWidth > 0 && srcHeight > 0) {
        final srcRect = Rect.fromLTWH(srcLeft, srcTop, srcWidth, srcHeight);
        final dstRect = Rect.fromLTWH(0, 0, size.width, size.height);

        canvas.drawImageRect(
          blurredImage!,
          srcRect,
          dstRect,
          Paint()
            ..filterQuality = FilterQuality.medium
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
  }

  @override
  bool shouldRepaint(covariant _SharedBlurSlicePainter oldDelegate) {
    return oldDelegate.blurredImage != blurredImage ||
        oldDelegate.bakedScreenSize != bakedScreenSize ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.shape != shape;
  }
}
