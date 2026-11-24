// Miuix Flutter 移植版 - GlassTopAppBar
// 源自 compose-miuix-ui/miuix 的 GlassTopAppBar.kt。
// SPDX-License-Identifier: Apache-2.0
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import '../blur/miuix_backdrop.dart';
import '../blur/miuix_layer_backdrop.dart';
import '../glass/miuix_glass_decoration.dart';
import '../glass/miuix_glass_material.dart';
import '../glass/miuix_glass_motion.dart';
import '../glass/miuix_glass_shape.dart';
import '../glass/miuix_glass_style.dart';
import '../glass/internal/bar_scope.dart';
import '../theme/miuix_theme.dart';
import 'miuix_blur_top_app_bar.dart';
import 'miuix_glass.dart';
import 'miuix_top_app_bar.dart';

/// 对应 Kotlin GlassTopAppBarDefaults。
class MiuixGlassTopAppBarDefaults {
  MiuixGlassTopAppBarDefaults._();
  static const horizontalPadding = 12.0,
      rampStart = 0.0,
      rampDistance = 32.0,
      largeTitleBlurRadius = 12.0,
      buttonSize = 44.0,
      progressiveBlurRadius = 80.0,
      progressiveBlurRampDistance = 48.0,
      pressedContentAlpha = .6,
      bandOverhang = 28.0;

  /// 顶栏遮罩的模糊与子控件自身 20dp 遮罩叠加后的等效模糊（源端 NESTED_BLUR）。
  static const nestedBlurLight = 44.72, nestedBlurDark = 63.25;

  /// 栏内按钮/标签的材质。**必须是缓存实例**：每次 `copyWith` 都会生成一个新
  /// 对象，而 _RenderGlass 用它当纹理缓存 key，逐帧新建等于逐帧丢缓存。
  static final _nestedLight = MiuixGlassMaterials.puredThinGlassLight.copyWith(
    blurRadius: nestedBlurLight,
  );
  static final _nestedDark = MiuixGlassMaterials.puredThinGlassDark.copyWith(
    blurRadius: nestedBlurDark,
  );
  static MiuixGlassMaterial nestedMaterial(bool isDark) =>
      isDark ? _nestedDark : _nestedLight;

  static MiuixGlassMaterial buttonMaterial(BuildContext context) =>
      MiuixGlassMaterials.puredThinGlass(
        MiuixTheme.of(context).colors.background.computeLuminance() < .5,
      );

  static MiuixGlassStroke buttonStroke(BuildContext context) =>
      MiuixGlassStrokes.small(
        MiuixTheme.of(context).colors.background.computeLuminance() < .5,
      );

  /// band 默认色调渐变：半透版本——下方有真实高斯模糊垫底，顶部不再需要
  /// 不透明色块（旧版顶部 ~45% 为纯 surface 色，观感是不透明实带，与原生
  /// HyperOS 4「整块高斯模糊 + 半透色调」不符）。如需旧版实色带，给
  /// [MiuixGlassTopAppBar.bandBrush] 传不透明渐变即可。
  static LinearGradient bandBrush(Color color) => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: const [0, .45, .58, .72, .86, 1],
    colors: [
      color.withValues(alpha: .62),
      color.withValues(alpha: .62),
      color.withValues(alpha: .5),
      color.withValues(alpha: .34),
      color.withValues(alpha: .18),
      color.withValues(alpha: 0),
    ],
  );

  /// band 的玻璃材质缓存：**必须是缓存实例**——[MiuixGlassMaterial] 是
  /// _RenderGlass 的纹理缓存 key，逐帧新建等于逐帧丢缓存（同 nestedMaterial
  /// 的注释）。
  static final _bandMaterials = <(bool, double), MiuixGlassMaterial>{};
  static MiuixGlassMaterial bandMaterial(bool isDark, double blurRadius) =>
      _bandMaterials.putIfAbsent(
        (isDark, blurRadius),
        () => MiuixGlassMaterials.puredThinGlass(
          isDark,
        ).copyWith(blurRadius: blurRadius),
      );

  /// 模糊层自身的淡出遮罩（白色=保留，透明=擦除）：让模糊在 band 下缘附近
  /// 平滑消失，避免矩形硬边。
  static LinearGradient bandBlurMask() => const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0, .55, 1],
    colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0x00FFFFFF)],
  );
}

/// 对应 Kotlin GlassTopAppBar。操作区使用 MiuixGlassIconButton，旧顶栏保持不变。
/// [isContentScrolled] 传入列表是否离开顶部，避免标题锁定折叠后材质不能复位。
class MiuixGlassTopAppBar extends StatefulWidget {
  const MiuixGlassTopAppBar({
    super.key,
    required this.title,
    this.backdrop,
    this.progressiveBlur = false,
    this.largeTitle,
    this.subtitle = '',
    this.scrollBehavior,
    this.isContentScrolled,
    this.style,
    this.material,
    this.alpha = 1,
    this.titleAlpha = 1,
    this.backgroundAlpha = 1,
    this.buttonSize = 44,
    this.buttonShape,
    this.fill,
    this.stroke,
    this.showStroke = true,
    this.buttonShadow = MiuixGlassShadows.regular,
    this.largeTitleBlurRadius = 12,
    this.bandOverhang = 28,
    this.bandHeightFactor = 1,
    this.bandBrush,
    this.bandBlurRadius = 24,
    this.defaultWindowInsetsPadding = true,
    this.navigationIcon,
    this.actions = const [],
    this.bottomContent,
  });

  final String title, subtitle;
  final String? largeTitle;
  final MiuixBackdrop? backdrop;

  /// 是否启用渐进模糊顶栏背景，并让顶栏内按钮直接采样该渲染后的渐进模糊场景。
  /// 需要非空 [backdrop]；启用时按钮不再叠加 `actionBarMask` 底衬，避免双重压暗。
  final bool progressiveBlur;
  final MiuixScrollBehavior? scrollBehavior;
  final bool? isContentScrolled;
  final MiuixGlassStyle? style;
  final MiuixGlassMaterial? material;
  final double alpha,
      titleAlpha,
      backgroundAlpha,
      buttonSize,
      largeTitleBlurRadius,
      bandOverhang;
  final MiuixGlassShape? buttonShape;
  final Color? fill;
  final MiuixGlassStroke? stroke;
  final bool showStroke;
  final MiuixGlassShadow? buttonShadow;
  final Gradient? bandBrush;

  /// band 实际高度占「顶栏高度 + [bandOverhang]」的比例，从顶部量起。
  /// 默认 1；调小可让模糊带更矮（色调渐变与淡出遮罩按缩短后的高度重新铺开，
  /// 下缘仍平滑淡出）。取值 (0, 1]。
  final double bandHeightFactor;

  /// band 区域对身后内容的实时高斯模糊半径（sigma，dp）。0 关闭模糊，只剩
  /// [bandBrush] 色调层。默认 24，与 [MiuixTopAppBar.blurred] 的默认一致。
  final double bandBlurRadius;
  final bool defaultWindowInsetsPadding;
  final Widget? navigationIcon, bottomContent;
  final List<Widget> actions;

  @override
  State<MiuixGlassTopAppBar> createState() => _MiuixGlassTopAppBarState();
}

class _MiuixGlassTopAppBarState extends State<MiuixGlassTopAppBar> {
  MiuixLayerBackdrop? _progressiveBackdrop;
  MiuixCombinedBackdrop? _combinedButtonBackdrop;

  void _syncProgressiveBackdrop() {
    final active = widget.progressiveBlur && widget.backdrop != null;
    if (!active) {
      _combinedButtonBackdrop?.dispose();
      _combinedButtonBackdrop = null;
      _progressiveBackdrop?.dispose();
      _progressiveBackdrop = null;
      return;
    }
    _progressiveBackdrop ??= MiuixLayerBackdrop();
    if (_combinedButtonBackdrop == null) {
      _combinedButtonBackdrop = MiuixCombinedBackdrop(
        first: widget.backdrop!,
        second: _progressiveBackdrop!,
      );
    } else {
      _combinedButtonBackdrop!.update(
        first: widget.backdrop!,
        second: _progressiveBackdrop!,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _syncProgressiveBackdrop();
  }

  @override
  void didUpdateWidget(MiuixGlassTopAppBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progressiveBlur != widget.progressiveBlur ||
        !identical(oldWidget.backdrop, widget.backdrop)) {
      _syncProgressiveBackdrop();
    }
  }

  @override
  void dispose() {
    _combinedButtonBackdrop?.dispose();
    _progressiveBackdrop?.dispose();
    super.dispose();
  }

  Widget _buildBar(BuildContext context) {
    final dark =
        MiuixTheme.of(context).colors.background.computeLuminance() < .5;
    final scrollOffset = widget.scrollBehavior?.state.contentOffset;
    final floating =
        widget.isContentScrolled ?? (scrollOffset?.isNegative ?? true);
    final ramp = scrollOffset == null
        ? 1.0
        : ((-scrollOffset - MiuixGlassTopAppBarDefaults.rampStart) /
                  MiuixGlassTopAppBarDefaults.rampDistance)
              .clamp(0.0, 1.0);
    final disabled = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final useProgressive =
        widget.progressiveBlur &&
        widget.backdrop != null &&
        _progressiveBackdrop != null &&
        _combinedButtonBackdrop != null;
    final underlay = widget.backdrop != null
        ? MiuixGlassMaterials.actionBarMask(dark)
        : null;
    final buttonUnderlay = useProgressive ? null : underlay;
    final baseMaterial =
        widget.material ?? MiuixGlassMaterials.puredThinGlass(dark);
    final resolvedButtonMaterial = buttonUnderlay == null
        ? baseMaterial
        : (widget.material == null
              ? MiuixGlassTopAppBarDefaults.nestedMaterial(dark)
              : baseMaterial.withUnderlayBlur(buttonUnderlay));
    final bgAlpha = widget.backgroundAlpha.clamp(0.0, 1.0);

    return TweenAnimationBuilder<double>(
      duration: disabled ? Duration.zero : MiuixGlassMotion.topBarButtonFloat,
      tween: Tween(begin: floating ? 1 : 0, end: floating ? 1 : 0),
      builder: (context, value, child) {
        final keepMaterial = floating || value > 0;
        final activeUnderlay = keepMaterial ? underlay : null;
        final activeButtonUnderlay = keepMaterial ? buttonUnderlay : null;
        return GlassBarScope(
          backdrop: widget.backdrop,
          buttonBackdrop: useProgressive
              ? _combinedButtonBackdrop
              : widget.backdrop,
          material: resolvedButtonMaterial,
          underlay: activeUnderlay,
          buttonUnderlay: activeButtonUnderlay,
          style: widget.style ?? MiuixGlassDefaults.style(context),
          progress: (value * widget.alpha).clamp(0.0, 1.0),
          alpha: widget.alpha.clamp(0.0, 1.0),
          floating: floating,
          ramp: ramp,
          buttonSize: widget.buttonSize,
          buttonShape: widget.buttonShape,
          fill: widget.fill,
          stroke: widget.stroke,
          showStroke: widget.showStroke,
          buttonShadow: widget.buttonShadow,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                bottom: -widget.bandOverhang,
                child: IgnorePointer(
                  child: TweenAnimationBuilder<double>(
                    duration: disabled
                        ? Duration.zero
                        : MiuixGlassMotion.topBarMask,
                    tween: Tween(
                      begin: floating ? 1 : 0,
                      end: floating ? 1 : 0,
                    ),
                    builder: (context, p, _) {
                      final rawProgress = useProgressive && scrollOffset != null
                          ? (-scrollOffset /
                                    MiuixGlassTopAppBarDefaults
                                        .progressiveBlurRampDistance)
                                .clamp(0.0, 1.0)
                          : p.clamp(0.0, 1.0);
                      final progress = (rawProgress * bgAlpha).clamp(0.0, 1.0);
                      // 完全收起时不挂模糊层，避免无谓的采样/合成开销。
                      if (progress < .001 && !useProgressive) {
                        return const SizedBox.shrink();
                      }
                      final surface = MiuixTheme.of(context).colors.surface;
                      Widget band = Opacity(
                        opacity: progress,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // 模糊层：优先走库的液态玻璃路径（采样
                            // [backdrop] 捕获快照，与底部玻璃导航同一机制）；
                            // 没有 backdrop 时退回 BackdropFilter。dstIn 渐变
                            // 遮罩让模糊在 band 下缘平滑淡出。
                            if (widget.bandBlurRadius > 0 || useProgressive)
                              ShaderMask(
                                blendMode: BlendMode.dstIn,
                                shaderCallback:
                                    MiuixGlassTopAppBarDefaults.bandBlurMask()
                                        .createShader,
                                child: widget.backdrop != null
                                    ? MiuixGlassPanel(
                                        backdrop: widget.backdrop,
                                        material:
                                            MiuixGlassTopAppBarDefaults.bandMaterial(
                                              dark,
                                              useProgressive
                                                  ? MiuixGlassTopAppBarDefaults
                                                        .progressiveBlurRadius
                                                  : widget.bandBlurRadius,
                                            ),
                                        shape: const MiuixGlassShape(
                                          cornerRadius: 0,
                                        ),
                                        stroke: null,
                                        shadow: null,
                                        shading: false,
                                        child: const SizedBox.expand(),
                                      )
                                    : BackdropFilter(
                                        filter: ui.ImageFilter.blur(
                                          sigmaX: widget.bandBlurRadius,
                                          sigmaY: widget.bandBlurRadius,
                                        ),
                                        child: const SizedBox.expand(),
                                      ),
                              ),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient:
                                    widget.bandBrush ??
                                    (useProgressive
                                        ? LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              surface.withValues(alpha: .3),
                                              surface.withValues(alpha: 0),
                                            ],
                                          )
                                        : MiuixGlassTopAppBarDefaults.bandBrush(
                                            surface,
                                          )),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (widget.bandHeightFactor < 1) {
                        band = FractionallySizedBox(
                          alignment: Alignment.topCenter,
                          heightFactor: widget.bandHeightFactor.clamp(0.0, 1.0),
                          child: band,
                        );
                      }
                      if (useProgressive) {
                        band = MiuixLayerBackdropCapture(
                          backdrop: _progressiveBackdrop!,
                          child: band,
                        );
                      }
                      return band;
                    },
                  ),
                ),
              ),
              MiuixBlurTopAppBar(
                title: widget.title,
                largeTitle: widget.largeTitle,
                subtitle: widget.subtitle,
                titleAlpha: widget.titleAlpha,
                largeTitleBlurRadius: widget.largeTitleBlurRadius,
                color: const Color(0x00000000),
                scrollBehavior: widget.scrollBehavior,
                defaultWindowInsetsPadding: widget.defaultWindowInsetsPadding,
                navigationIconPadding: 12,
                actionIconPadding: 12,
                clipBehavior: Clip.none,
                navigationIcon: widget.navigationIcon,
                actions: widget.actions,
                bottomContent: widget.bottomContent,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.scrollBehavior?.state;
    return state == null
        ? _buildBar(context)
        : ListenableBuilder(
            listenable: state,
            builder: (context, _) => _buildBar(context),
          );
  }
}
