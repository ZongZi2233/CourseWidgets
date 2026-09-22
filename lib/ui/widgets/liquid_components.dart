import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Material, Theme, Orientation, MediaQuery;
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:flutter_miuix/miuix.dart';
import '../../constants/theme_constants.dart';
import '../../utils/glass_settings_helper.dart';
import '../../utils/responsive_utils.dart';
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
    final isLandscapeOrDesktop = Platform.isWindows ||
        Platform.isMacOS ||
        Platform.isLinux ||
        MediaQuery.of(context).orientation == Orientation.landscape ||
        ResponsiveUtils.isTabletMode(context);

    return Positioned(
      top: isLandscapeOrDesktop ? (MediaQuery.of(context).padding.top + 16) : null,
      left: isLandscapeOrDesktop ? 20 : null,
      bottom: isLandscapeOrDesktop ? null : 24,
      right: isLandscapeOrDesktop ? null : 20,
      child: SafeArea(
        top: isLandscapeOrDesktop,
        bottom: !isLandscapeOrDesktop,
        left: isLandscapeOrDesktop,
        right: !isLandscapeOrDesktop,
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
    this.cornerRadius = 28, // [v2.9.7] 超椭圆 28，对齐全新旗舰大圆角
    this.padding = const EdgeInsets.all(12),
    this.color,
    this.contentColor,
    this.useBlur = true, // [v3.0.0] 默认开启静态模糊遮罩，极速无损呈现真实亚克力混色
    this.blurRadius = 10.0,
    this.feedbackType = MiuixPressFeedbackType.sink,
    this.border,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = globalDarkModeNotifier.value;
    final primary = theme.ThemeService().primaryColor;

    // [v3.0.0] HyperOS 混色半透明丙烯酸质感：通透柔和，透出背景模糊壁纸与主题色融合
    final defaultBgColor = isDark
        ? Color.alphaBlend(primary.withValues(alpha: 0.14), const Color(0x3814171E))
        : Color.alphaBlend(primary.withValues(alpha: 0.10), const Color(0x30FFFFFF));

    // 如果指定了自定义颜色（例如课程卡片自定义整卡染色），直接应用；否则使用默认半透明丙烯酸底色
    final effectiveColor = color ?? defaultBgColor;

    // [v2.9.0] 字体颜色根据最终背景计算明度（computeLuminance），确保黑白高对比 100% 极速自适应
    final lum = effectiveColor.computeLuminance();
    final autoTextColor = lum > 0.45 ? const Color(0xFF1B1D24) : const Color(0xFFF2F5FA);
    final effectiveTextColor = contentColor ?? autoTextColor;

    // [v2.9.6] 纯色混色超椭圆质感：彻底废除顶部白光与暗面渐变，呈现温润均匀的纯色混色微透卡片
    final effectiveBorderSide = border ?? BorderSide.none;

    // 采用与 liquid_glass_widgets 内部一致的 RoundedSuperellipseBorder，保证曲率完全对齐统一
    final shape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.all(Radius.circular(cornerRadius)),
      side: effectiveBorderSide,
    );

    // [v3.0.0] 精简阴影分层：浅色与深色模式均采用精炼的环境光与主投影，降低光栅化负担
    final effectiveShadows = shadows ?? [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.12),
        blurRadius: isDark ? 12 : 10,
        offset: const Offset(0, 3),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.06),
        blurRadius: 4,
        offset: const Offset(0, 1),
      ),
    ];

    Widget cardBody;
    if (useBlur) {
      // [v3.0.0] 静态单次烘焙遮罩架构：卡片滑动时作为视口移动采样预烘焙模糊壁纸，
      // 叠加上层亚克力混色与超椭圆，0 动态 BackdropFilter 损耗，120Hz 满帧
      cardBody = DecoratedBox(
        decoration: ShapeDecoration(
          color: Colors.transparent,
          shape: shape,
          shadows: effectiveShadows,
        ),
        child: _StaticMaskCardDecorator(
          shape: shape,
          acrylicColor: effectiveColor,
          border: effectiveBorderSide,
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
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

/// [v3.0.0] 静态单次壁纸模糊遮罩渲染组件
class _StaticMaskCardDecorator extends SingleChildRenderObjectWidget {
  final RoundedSuperellipseBorder shape;
  final Color acrylicColor;
  final BorderSide border;

  const _StaticMaskCardDecorator({
    required this.shape,
    required this.acrylicColor,
    required this.border,
    required super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderStaticMaskCard(
      shape: shape,
      acrylicColor: acrylicColor,
      border: border,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderStaticMaskCard renderObject,
  ) {
    renderObject
      ..shape = shape
      ..acrylicColor = acrylicColor
      ..border = border;
    renderObject.markNeedsPaint();
  }
}

class _RenderStaticMaskCard extends RenderProxyBox {
  RoundedSuperellipseBorder _shape;
  Color _acrylicColor;
  BorderSide _border;

  Path? _cachedPath;
  Size? _cachedSize;

  _RenderStaticMaskCard({
    required RoundedSuperellipseBorder shape,
    required Color acrylicColor,
    required BorderSide border,
    RenderBox? child,
  })  : _shape = shape,
        _acrylicColor = acrylicColor,
        _border = border,
        super(child);

  RoundedSuperellipseBorder get shape => _shape;
  set shape(RoundedSuperellipseBorder value) {
    if (_shape != value) {
      _shape = value;
      _cachedPath = null;
      markNeedsPaint();
    }
  }

  Color get acrylicColor => _acrylicColor;
  set acrylicColor(Color value) {
    if (_acrylicColor != value) {
      _acrylicColor = value;
      markNeedsPaint();
    }
  }

  BorderSide get border => _border;
  set border(BorderSide value) {
    if (_border != value) {
      _border = value;
      markNeedsPaint();
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    StaticBlurredWallpaperService.instance.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    StaticBlurredWallpaperService.instance.removeListener(markNeedsPaint);
    super.detach();
  }

  Path _getOrUpdatePath(Size currentSize) {
    if (_cachedPath == null || _cachedSize != currentSize) {
      _cachedPath = shape.getOuterPath(Offset.zero & currentSize);
      _cachedSize = currentSize;
    }
    return _cachedPath!;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final service = StaticBlurredWallpaperService.instance;
    final blurredImage = service.blurredImage;
    final localPath = _getOrUpdatePath(size);

    context.canvas.save();
    context.canvas.translate(offset.dx, offset.dy);

    if (blurredImage != null) {
      // 0 开销从 Canvas 矩阵获取全局平移坐标，消除 localToGlobal 全树回溯
      final matrix = context.canvas.getTransform();
      final globalX = matrix[12];
      final globalY = matrix[13];

      final view = WidgetsBinding.instance.platformDispatcher.views.firstOrNull;
      final dpr = (view != null && view.devicePixelRatio > 0) ? view.devicePixelRatio : 1.0;
      final screenW = view != null ? view.physicalSize.width / dpr : 1080.0;
      final screenH = view != null ? view.physicalSize.height / dpr : 2400.0;

      if (screenW > 0 && screenH > 0) {
        final imgW = blurredImage.width.toDouble();
        final imgH = blurredImage.height.toDouble();

        // 智能 BoxFit.cover 比例映射：无论处于稳态还是横竖屏旋转过渡期，
        // 确保采样切片始终与底层高清壁纸保持几何居中对齐，杜绝拉伸变形与坐标漂移。
        final scale = math.max(imgW / screenW, imgH / screenH);
        final offsetX = (imgW - screenW * scale) / 2.0;
        final offsetY = (imgH - screenH * scale) / 2.0;

        final srcLeft = globalX * scale + offsetX;
        final srcTop = globalY * scale + offsetY;
        final srcRight = (globalX + size.width) * scale + offsetX;
        final srcBottom = (globalY + size.height) * scale + offsetY;

        final srcRect = Rect.fromLTRB(
          srcLeft.clamp(0.0, imgW),
          srcTop.clamp(0.0, imgH),
          srcRight.clamp(0.0, imgW),
          srcBottom.clamp(0.0, imgH),
        );

        context.canvas.clipPath(localPath);

        // 1. 绘制对应屏幕物理视口的静态模糊壁纸切片
        if (srcRect.width > 0 && srcRect.height > 0) {
          context.canvas.drawImageRect(
            blurredImage,
            srcRect,
            Offset.zero & size,
            Paint()..filterQuality = FilterQuality.low,
          );
        }

        // 2. 叠加上层混色半透明丙烯酸质感
        context.canvas.drawPath(
          localPath,
          Paint()..color = acrylicColor,
        );
      } else {
        context.canvas.drawPath(localPath, Paint()..color = acrylicColor);
      }
    } else {
      // 首次纹理尚未就绪时的优雅纯色降级
      context.canvas.drawPath(localPath, Paint()..color = acrylicColor);
    }

    // 3. 边框绘制
    if (border.style != BorderStyle.none && border.width > 0) {
      context.canvas.drawPath(
        localPath,
        Paint()
          ..color = border.color
          ..strokeWidth = border.width
          ..style = PaintingStyle.stroke,
      );
    }

    context.canvas.restore();

    // 绘制子组件（内容）
    super.paint(context, offset);
  }
}
