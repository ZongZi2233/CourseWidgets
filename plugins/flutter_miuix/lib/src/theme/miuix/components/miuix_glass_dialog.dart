// Miuix Flutter 移植版 - GlassDialog / GlassDialogSurface
// 源自 compose-miuix-ui/miuix 的 GlassDialog.kt 与 GlassDialogSurface.kt。
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../blur/miuix_backdrop.dart';
import '../foundation/miuix_popup_utils.dart';
import '../glass/miuix_glass_decoration.dart';
import '../glass/miuix_glass_material.dart';
import '../glass/miuix_glass_motion.dart';
import '../glass/miuix_glass_shape.dart';
import '../glass/internal/animation.dart';
import '../theme/miuix_text_styles.dart';
import '../theme/miuix_theme.dart';
import 'miuix_glass.dart';
import 'miuix_overlay_dialog.dart';

/// 玻璃对话框默认值。对应 Kotlin `GlassDialogDefaults`。
class MiuixGlassDialogDefaults {
  MiuixGlassDialogDefaults._();

  /// 应用动画进度前的默认遮罩色。
  static const Color scrimColor = Color(0x33000000);

  /// 当前主题下的对话框三层材质。
  static MiuixGlassMaterial material(BuildContext context) =>
      MiuixGlassMaterials.dialogGlass(
        MiuixTheme.of(context).colors.background.computeLuminance() < 0.5,
      );

  /// 当前主题下的对话框小号高光描边。
  static MiuixGlassStroke stroke(BuildContext context) =>
      MiuixGlassStrokes.small(
        MiuixTheme.of(context).colors.background.computeLuminance() < 0.5,
      );

  /// 无 backdrop 时的不透明兜底背景色。
  static Color containerColor(BuildContext context) =>
      MiuixTheme.of(context).colors.background;
}

/// 供 [MiuixOverlayDialog.surfaceBuilder] 使用的玻璃表面构建器。
/// 对应 Kotlin `glassDialogSurface`。
///
/// 背景在模糊前先按当前遮罩色压暗，并在缩放动画期间抵消宿主缩放以保持屏幕坐标对齐；
/// 对话框内容本身不参与折射，也不额外绘制投影。
MiuixDialogSurfaceBuilder miuixGlassDialogSurface({
  MiuixBackdrop? backdrop,
  MiuixGlassMaterial? material,
  MiuixGlassStroke? stroke,
  bool showStroke = true,
  Color? containerColor,
}) => (context, cornerRadius, scrimColor, scale, child) {
  final effectiveMaterial =
      material ?? MiuixGlassDialogDefaults.material(context);
  final effectiveStroke = showStroke
      ? (stroke ?? MiuixGlassDialogDefaults.stroke(context))
      : null;
  final effectiveFill =
      containerColor ?? MiuixGlassDialogDefaults.containerColor(context);
  return _ScrimGlassDialogSurface(
    backdrop: backdrop,
    scrimColor: scrimColor,
    scale: scale,
    cornerRadius: cornerRadius,
    material: effectiveMaterial,
    stroke: effectiveStroke,
    containerColor: effectiveFill,
    child: child,
  );
};

class _ScrimGlassDialogSurface extends StatefulWidget {
  const _ScrimGlassDialogSurface({
    required this.backdrop,
    required this.scrimColor,
    required this.scale,
    required this.cornerRadius,
    required this.material,
    required this.stroke,
    required this.containerColor,
    required this.child,
  });

  final MiuixBackdrop? backdrop;
  final Color scrimColor;
  final double scale;
  final double cornerRadius;
  final MiuixGlassMaterial material;
  final MiuixGlassStroke? stroke;
  final Color containerColor;
  final Widget child;

  @override
  State<_ScrimGlassDialogSurface> createState() =>
      _ScrimGlassDialogSurfaceState();
}

class _ScrimGlassDialogSurfaceState extends State<_ScrimGlassDialogSurface> {
  MiuixScrimBackdrop? _scrimBackdrop;

  void _syncBackdrop() {
    final source = widget.backdrop;
    if (source == null) {
      _scrimBackdrop?.dispose();
      _scrimBackdrop = null;
      return;
    }
    if (_scrimBackdrop == null) {
      _scrimBackdrop = MiuixScrimBackdrop(
        backdrop: source,
        scrimColor: widget.scrimColor,
        scale: widget.scale,
      );
    } else {
      _scrimBackdrop!.update(
        backdrop: source,
        scrimColor: widget.scrimColor,
        scale: widget.scale,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _syncBackdrop();
  }

  @override
  void didUpdateWidget(_ScrimGlassDialogSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncBackdrop();
  }

  @override
  void dispose() {
    _scrimBackdrop?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MiuixGlassPanel(
      backdrop: _scrimBackdrop,
      shape: MiuixGlassShape(cornerRadius: widget.cornerRadius),
      material: widget.material,
      stroke: widget.stroke,
      shadow: null,
      shading: false,
      fill: widget.containerColor,
      child: widget.child,
    );
  }
}

/// 对应 Kotlin `GlassDialog`。
///
/// 托管在 [MiuixScaffold] 弹层宿主（无宿主时自动退回根 `OverlayPortal`）的玻璃对话框，
/// 支持标题、副说明、遮罩采样、大小屏自适应布局以及配合 [MiuixGlassDialogButton] 使用。
/// [backdrop] 应包含页面与顶底栏，但不包含对话框宿主及其遮罩。
class MiuixGlassDialog extends StatefulWidget {
  const MiuixGlassDialog({
    super.key,
    bool? show,
    bool? visible,
    required this.onDismissRequest,
    required this.child,
    this.backdrop,
    this.enableWindowDim = true,
    this.defaultWindowInsetsPadding = true,
    this.renderInRootScaffold = true,
    this.largeScreen,
    this.title,
    this.titleColor,
    this.summary,
    this.summaryColor,
    this.cornerRadius,
    this.maxWidth = MiuixDialogDefaults.maxWidth,
    this.outsideMargin = MiuixDialogDefaults.outsideMargin,
    this.insideMargin = MiuixDialogDefaults.insideMargin,
    this.material,
    this.stroke,
    this.showStroke = true,
    this.containerColor,
    this.dimColor = MiuixGlassDialogDefaults.scrimColor,
    this.scrimAlpha,
    this.onDismissFinished,
  }) : assert(
         show != null || visible != null,
         'MiuixGlassDialog requires either show or visible.',
       ),
       show = show ?? visible ?? false;

  /// 是否显示对话框（同时兼容旧版 `visible` 参数）。
  final bool show;
  final VoidCallback onDismissRequest;
  final Widget child;
  final MiuixBackdrop? backdrop;
  final bool enableWindowDim;
  final bool defaultWindowInsetsPadding;
  final bool renderInRootScaffold;
  final bool? largeScreen;
  final String? title;
  final Color? titleColor;
  final String? summary;
  final Color? summaryColor;
  final double? cornerRadius;
  final double maxWidth;
  final Size outsideMargin;
  final Size insideMargin;
  final MiuixGlassMaterial? material;
  final MiuixGlassStroke? stroke;
  final bool showStroke;
  final Color? containerColor;
  final Color dimColor;

  /// 兼容旧版遮罩透明度参数；非空时覆盖 [dimColor] 的不透明度。
  final double? scrimAlpha;
  final VoidCallback? onDismissFinished;

  Color get _effectiveDimColor => scrimAlpha == null
      ? dimColor
      : dimColor.withValues(alpha: scrimAlpha!.clamp(0.0, 1.0));

  @override
  State<MiuixGlassDialog> createState() => _MiuixGlassDialogState();
}

class _MiuixGlassDialogState extends State<MiuixGlassDialog> {
  @override
  Widget build(BuildContext context) {
    final surface = miuixGlassDialogSurface(
      backdrop: widget.backdrop,
      material: widget.material,
      stroke: widget.stroke,
      showStroke: widget.showStroke,
      containerColor: widget.containerColor,
    );
    final hasScope =
        MiuixPopupScope.maybeOf(context, root: widget.renderInRootScaffold) !=
        null;
    if (hasScope) {
      return MiuixOverlayDialog(
        show: widget.show,
        title: widget.title,
        titleColor: widget.titleColor,
        summary: widget.summary,
        summaryColor: widget.summaryColor,
        backgroundColor: widget.containerColor,
        enableWindowDim: widget.enableWindowDim,
        dimColor: widget._effectiveDimColor,
        surfaceBuilder: surface,
        onDismissRequest: widget.onDismissRequest,
        onDismissFinished: widget.onDismissFinished,
        outsideMargin: widget.outsideMargin,
        insideMargin: widget.insideMargin,
        defaultWindowInsetsPadding: widget.defaultWindowInsetsPadding,
        renderInRootScaffold: widget.renderInRootScaffold,
        maxWidth: widget.maxWidth,
        largeScreen: widget.largeScreen,
        cornerRadius: widget.cornerRadius,
        content: widget.child,
      );
    }
    return _StandaloneGlassDialog(dialog: widget, surfaceBuilder: surface);
  }
}

/// 在没有 [MiuixScaffold] / [MiuixPopupScope] 祖先时退回根 OverlayPortal 的独立托管层。
class _StandaloneGlassDialog extends StatefulWidget {
  const _StandaloneGlassDialog({
    required this.dialog,
    required this.surfaceBuilder,
  });

  final MiuixGlassDialog dialog;
  final MiuixDialogSurfaceBuilder surfaceBuilder;

  @override
  State<_StandaloneGlassDialog> createState() => _StandaloneGlassDialogState();
}

class _StandaloneGlassDialogState extends State<_StandaloneGlassDialog>
    with TickerProviderStateMixin {
  final _portal = OverlayPortalController();
  late final AnimationController _progress;
  LocalHistoryEntry? _history;
  bool _present = false;
  bool _removingHistory = false;
  int _generation = 0;

  bool get _reduce => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  void _repaint() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _progress = AnimationController.unbounded(vsync: this)
      ..addListener(_repaint);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.dialog.show) _transition(true);
    });
  }

  @override
  void didUpdateWidget(_StandaloneGlassDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dialog.show != oldWidget.dialog.show) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _transition(widget.dialog.show);
      });
    }
  }

  void _removeHistory() {
    _removingHistory = true;
    _history?.remove();
    _history = null;
    _removingHistory = false;
  }

  Future<void> _transition(bool show) async {
    if (!show && !_present) return;
    final generation = ++_generation;
    if (show) {
      if (!_present) {
        _portal.show();
        _present = true;
      }
      if (_history == null) {
        _history = LocalHistoryEntry(
          onRemove: () {
            _history = null;
            if (!_removingHistory && widget.dialog.show) {
              widget.dialog.onDismissRequest();
            }
          },
        );
        ModalRoute.of(context)?.addLocalHistoryEntry(_history!);
      }
    } else {
      _removeHistory();
    }
    final target = show ? 1.0 : 0.0;
    if (_reduce) {
      _progress.value = target;
      if (!show) _finish();
      return;
    }
    try {
      await animateGlassTo(
        _progress,
        target,
        show ? MiuixGlassMotion.dialogEnter : MiuixGlassMotion.dialogExit,
      ).orCancel;
      if (mounted && generation == _generation && !widget.dialog.show) {
        _finish();
      }
    } on TickerCanceled {
      // 被反向切换或销毁接管。
    }
  }

  void _finish() {
    if (!_present) return;
    _portal.hide();
    _present = false;
    widget.dialog.onDismissFinished?.call();
  }

  @override
  void dispose() {
    _generation++;
    _removeHistory();
    _progress.dispose();
    super.dispose();
  }

  Widget _overlay(BuildContext context) {
    final d = widget.dialog;
    final theme = MiuixTheme.of(context);
    final isLarge = d.largeScreen ?? isMiuixLargeScreen(context);
    final system = d.defaultWindowInsetsPadding
        ? MediaQuery.paddingOf(context)
        : EdgeInsets.zero;
    final imeBottom = MediaQuery.viewInsetsOf(context).bottom;
    final radius =
        d.cornerRadius ?? (isLarge ? MiuixDialogDefaults.cornerRadius : 32);
    final p = _progress.value.clamp(0.0, 1.0);
    final baseDim = d._effectiveDimColor;
    final scrim = d.enableWindowDim
        ? baseDim.withValues(alpha: baseDim.a * p)
        : const Color(0x00000000);
    final scale = isLarge ? (0.8 + 0.2 * p) : 1.0;

    final Widget column = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (d.title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              width: double.infinity,
              child: Text(
                d.title!,
                textAlign: TextAlign.center,
                style: theme.textStyles.title4
                    .copyWith(
                      fontWeight: FontWeight.w500,
                      color:
                          d.titleColor ??
                          MiuixDialogDefaults.titleColor(context),
                    )
                    .withMiuixWeight(theme.fontWeightAdjustment),
              ),
            ),
          ),
        if (d.summary != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              width: double.infinity,
              child: Text(
                d.summary!,
                textAlign: TextAlign.center,
                style: theme.textStyles.body1
                    .copyWith(
                      color:
                          d.summaryColor ??
                          MiuixDialogDefaults.summaryColor(context),
                    )
                    .withMiuixWeight(theme.fontWeightAdjustment),
              ),
            ),
          ),
        MiuixDismissScope(onDismissRequest: d.onDismissRequest, child: d.child),
      ],
    );

    final Widget surface = widget.surfaceBuilder(
      context,
      radius,
      scrim,
      scale,
      Padding(
        padding: EdgeInsets.symmetric(
          horizontal: d.insideMargin.width,
          vertical: d.insideMargin.height,
        ),
        child: column,
      ),
    );

    final Widget panel = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: d.maxWidth,
        maxHeight: isLarge
            ? MediaQuery.sizeOf(context).height * (2 / 3)
            : double.infinity,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: isLarge
            ? Opacity(
                opacity: p,
                child: Transform.scale(scale: scale, child: surface),
              )
            : Opacity(opacity: p, child: surface),
      ),
    );

    return Material(
      type: MaterialType.transparency,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): d.onDismissRequest,
        },
        child: FocusScope(
          autofocus: true,
          child: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: d.onDismissRequest,
                child: ColoredBox(color: scrim),
              ),
              AnimatedPadding(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                padding: EdgeInsets.fromLTRB(
                  d.outsideMargin.width,
                  system.top,
                  d.outsideMargin.width,
                  math.max(system.bottom, imeBottom) + d.outsideMargin.height,
                ),
                child: Align(
                  alignment: isLarge
                      ? Alignment.center
                      : Alignment.bottomCenter,
                  child: panel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => OverlayPortal(
    overlayLocation: OverlayChildLocation.rootOverlay,
    controller: _portal,
    overlayChildBuilder: _overlay,
    child: const SizedBox.shrink(),
  );
}
