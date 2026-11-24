// Miuix Flutter 移植版 - GlassBottomSheet / GlassBottomSheetSurface
// 源自 compose-miuix-ui/miuix 的 GlassBottomSheet.kt 与 GlassBottomSheetSurface.kt。
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';

import '../blur/miuix_backdrop.dart';
import '../foundation/miuix_popup_utils.dart';
import '../glass/miuix_glass_decoration.dart';
import '../glass/miuix_glass_material.dart';
import '../glass/miuix_glass_shape.dart';
import '../theme/miuix_theme.dart';
import 'miuix_bottom_sheet.dart';
import 'miuix_glass.dart';
import 'miuix_glass_dialog.dart';

/// 玻璃底部抽屉默认值。对应 Kotlin `GlassBottomSheetDefaults`。
class MiuixGlassBottomSheetDefaults {
  MiuixGlassBottomSheetDefaults._();

  /// 应用动画进度前的默认遮罩色。
  static const Color scrimColor = MiuixGlassDialogDefaults.scrimColor;

  /// 当前主题下的底部抽屉三层材质。
  static MiuixGlassMaterial material(BuildContext context) =>
      MiuixGlassMaterials.dialogGlass(
        MiuixTheme.of(context).colors.background.computeLuminance() < 0.5,
      );

  /// 当前主题下的底部抽屉中号高光描边。
  static MiuixGlassStroke stroke(BuildContext context) =>
      MiuixGlassStrokes.forTheme(
        MiuixTheme.of(context).colors.background.computeLuminance() < 0.5,
      );

  /// 无 backdrop 时的不透明兜底背景色。
  static Color containerColor(BuildContext context) =>
      MiuixTheme.of(context).colors.background;
}

/// 供 [MiuixOverlayBottomSheet.surfaceBuilder] 使用的玻璃表面构建器。
/// 对应 Kotlin `glassBottomSheetSurface`。
///
/// 仅顶部圆角，底部直角；背景在模糊前先按当前遮罩色压暗；
/// 向上过拖延展区（`isOverscroll == true`）省略描边，避免出现接缝高光。
MiuixBottomSheetSurfaceBuilder miuixGlassBottomSheetSurface({
  MiuixBackdrop? backdrop,
  MiuixGlassMaterial? material,
  MiuixGlassStroke? stroke,
  bool showStroke = true,
  Color? containerColor,
}) => (context, cornerRadius, scrimColor, isOverscroll, child) {
  final effectiveMaterial =
      material ?? MiuixGlassBottomSheetDefaults.material(context);
  final effectiveStroke = !isOverscroll && showStroke
      ? (stroke ?? MiuixGlassBottomSheetDefaults.stroke(context))
      : null;
  final effectiveFill =
      containerColor ?? MiuixGlassBottomSheetDefaults.containerColor(context);
  return _ScrimGlassBottomSheetSurface(
    backdrop: backdrop,
    scrimColor: scrimColor,
    cornerRadius: isOverscroll ? 0 : cornerRadius,
    material: effectiveMaterial,
    stroke: effectiveStroke,
    containerColor: effectiveFill,
    child: child,
  );
};

class _ScrimGlassBottomSheetSurface extends StatefulWidget {
  const _ScrimGlassBottomSheetSurface({
    required this.backdrop,
    required this.scrimColor,
    required this.cornerRadius,
    required this.material,
    required this.stroke,
    required this.containerColor,
    required this.child,
  });

  final MiuixBackdrop? backdrop;
  final Color scrimColor;
  final double cornerRadius;
  final MiuixGlassMaterial material;
  final MiuixGlassStroke? stroke;
  final Color containerColor;
  final Widget child;

  @override
  State<_ScrimGlassBottomSheetSurface> createState() =>
      _ScrimGlassBottomSheetSurfaceState();
}

class _ScrimGlassBottomSheetSurfaceState
    extends State<_ScrimGlassBottomSheetSurface> {
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
      );
    } else {
      _scrimBackdrop!.update(backdrop: source, scrimColor: widget.scrimColor);
    }
  }

  @override
  void initState() {
    super.initState();
    _syncBackdrop();
  }

  @override
  void didUpdateWidget(_ScrimGlassBottomSheetSurface oldWidget) {
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
    final shape = widget.cornerRadius > 0
        ? MiuixGlassShape(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(widget.cornerRadius),
            ),
          )
        : const MiuixGlassShape(cornerRadius: 0);
    return MiuixGlassPanel(
      backdrop: _scrimBackdrop,
      shape: shape,
      material: widget.material,
      stroke: widget.stroke,
      shadow: null,
      shading: false,
      fill: widget.containerColor,
      child: widget.child,
    );
  }
}

/// 对应 Kotlin `GlassBottomSheet`。
///
/// 托管在 [MiuixScaffold] 弹层宿主（无宿主时自动退回窗口级 [MiuixWindowBottomSheet]）的
/// 玻璃底部抽屉，支持拖拽关闭、向上过拖玻璃延展与遮罩预压暗采样。
/// [backdrop] 应包含页面与顶底栏，但不包含抽屉宿主及其遮罩。
class MiuixGlassBottomSheet extends StatelessWidget {
  const MiuixGlassBottomSheet({
    super.key,
    required this.show,
    required this.onDismissRequest,
    required this.child,
    this.backdrop,
    this.enableWindowDim = true,
    this.defaultWindowInsetsPadding = true,
    this.allowDismiss = true,
    this.enableNestedScroll = true,
    this.renderInRootScaffold = true,
    this.title,
    this.startAction,
    this.endAction,
    this.cornerRadius = MiuixBottomSheetDefaults.cornerRadius,
    this.sheetMaxWidth = MiuixBottomSheetDefaults.maxWidth,
    this.outsideMargin = MiuixBottomSheetDefaults.outsideMargin,
    this.insideMargin = MiuixBottomSheetDefaults.insideMargin,
    this.dragHandleColor,
    this.material,
    this.stroke,
    this.showStroke = true,
    this.containerColor,
    this.dimColor = MiuixGlassBottomSheetDefaults.scrimColor,
    this.onDismissFinished,
  });

  final bool show;
  final VoidCallback onDismissRequest;
  final Widget child;
  final MiuixBackdrop? backdrop;
  final bool enableWindowDim;
  final bool defaultWindowInsetsPadding;
  final bool allowDismiss;
  final bool enableNestedScroll;
  final bool renderInRootScaffold;
  final String? title;
  final Widget? startAction;
  final Widget? endAction;
  final double cornerRadius;
  final double sheetMaxWidth;
  final Size outsideMargin;
  final Size insideMargin;
  final Color? dragHandleColor;
  final MiuixGlassMaterial? material;
  final MiuixGlassStroke? stroke;
  final bool showStroke;
  final Color? containerColor;
  final Color dimColor;
  final VoidCallback? onDismissFinished;

  @override
  Widget build(BuildContext context) {
    final surface = miuixGlassBottomSheetSurface(
      backdrop: backdrop,
      material: material,
      stroke: stroke,
      showStroke: showStroke,
      containerColor: containerColor,
    );
    final hasScope =
        MiuixPopupScope.maybeOf(context, root: renderInRootScaffold) != null;
    if (hasScope) {
      return MiuixOverlayBottomSheet(
        show: show,
        title: title,
        startAction: startAction,
        endAction: endAction,
        backgroundColor: containerColor,
        enableWindowDim: enableWindowDim,
        dimColor: dimColor,
        surfaceBuilder: surface,
        cornerRadius: cornerRadius,
        sheetMaxWidth: sheetMaxWidth,
        onDismissRequest: onDismissRequest,
        onDismissFinished: onDismissFinished,
        outsideMargin: outsideMargin,
        insideMargin: insideMargin,
        defaultWindowInsetsPadding: defaultWindowInsetsPadding,
        dragHandleColor: dragHandleColor,
        allowDismiss: allowDismiss,
        enableNestedScroll: enableNestedScroll,
        renderInRootScaffold: renderInRootScaffold,
        content: child,
      );
    }
    return MiuixWindowBottomSheet(
      show: show,
      title: title,
      startAction: startAction,
      endAction: endAction,
      backgroundColor: containerColor,
      enableWindowDim: enableWindowDim,
      dimColor: dimColor,
      surfaceBuilder: surface,
      cornerRadius: cornerRadius,
      sheetMaxWidth: sheetMaxWidth,
      onDismissRequest: onDismissRequest,
      onDismissFinished: onDismissFinished,
      outsideMargin: outsideMargin,
      insideMargin: insideMargin,
      defaultWindowInsetsPadding: defaultWindowInsetsPadding,
      dragHandleColor: dragHandleColor,
      allowDismiss: allowDismiss,
      enableNestedScroll: enableNestedScroll,
      content: child,
    );
  }
}
