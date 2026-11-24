// Miuix Flutter 移植版 - GlassIconDropdownMenu
// 源自 compose-miuix-ui/miuix 的 GlassIconDropdownMenu.kt。
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';

import '../blur/miuix_backdrop.dart';
import '../glass/miuix_glass_motion.dart';
import '../glass/miuix_glass_popup_anchor.dart';
import '../glass/miuix_glass_popup_style.dart';
import '../glass/internal/animation.dart';
import 'miuix_divider.dart';
import 'miuix_dropdown.dart';
import 'miuix_glass_popup_item.dart';
import 'miuix_glass_secondary_popup.dart';
import 'miuix_glass_transform_popup.dart';

/// 从 [MiuixGlassIconButton] 锚点展开的级联玻璃菜单。
/// 对应 Kotlin `GlassIconDropdownMenu`。
///
/// 包含子项（`children` 非空）的条目点击后展开二级玻璃面板，并带返回标题与分隔线；
/// 一级与二级菜单自动共享展开态材质与宽度下限。
class MiuixGlassIconDropdownMenu extends StatefulWidget {
  const MiuixGlassIconDropdownMenu({
    super.key,
    required this.show,
    required this.onDismissRequest,
    required this.anchor,
    required this.anchorContent,
    required this.entries,
    this.backdrop,
    this.secondaryBackdrop,
    this.sizing = const MiuixGlassPopupSizing(),
    this.visuals = const MiuixGlassPopupVisuals(),
    this.collapseOnSelection,
  });

  final bool show;
  final VoidCallback onDismissRequest;
  final MiuixGlassPopupAnchor anchor;
  final Widget anchorContent;
  final List<MiuixDropdownEntry> entries;
  final MiuixBackdrop? backdrop;

  /// 二级菜单采样的背景；未传入时默认复用 [backdrop]。
  final MiuixBackdrop? secondaryBackdrop;
  final MiuixGlassPopupSizing sizing;
  final MiuixGlassPopupVisuals visuals;

  /// 选中叶子条目后是否自动收起菜单；留空时仅单分组自动收起（`entries.length <= 1`）。
  final bool? collapseOnSelection;

  @override
  State<MiuixGlassIconDropdownMenu> createState() =>
      _MiuixGlassIconDropdownMenuState();
}

class _MiuixGlassIconDropdownMenuState
    extends State<MiuixGlassIconDropdownMenu> {
  bool _submenu = false;
  bool _submenuPresent = false;
  (int, int)? _submenuPath;
  Rect _submenuAnchor = Rect.zero;
  double? _primaryWidth;
  final Map<(int, int), GlobalKey> _rowKeys = {};

  bool get _collapse =>
      widget.collapseOnSelection ?? widget.entries.length <= 1;

  List<MiuixDropdownEntry> get _groups =>
      widget.entries.where((e) => e.items.isNotEmpty).toList(growable: false);

  GlobalKey _keyFor(int groupIndex, int itemIndex) =>
      _rowKeys.putIfAbsent((groupIndex, itemIndex), GlobalKey.new);

  Rect? _measureRow(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & box.size,
    );
  }

  @override
  void didUpdateWidget(MiuixGlassIconDropdownMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.show && _submenu) {
      _submenu = false;
    }
  }

  Widget _divider() => const Padding(
    padding: EdgeInsets.symmetric(
      horizontal: MiuixGlassPopupDefaults.dividerPaddingHorizontal,
      vertical: MiuixGlassPopupDefaults.dividerPaddingVertical,
    ),
    child: MiuixHorizontalDivider(
      thickness: MiuixGlassPopupDefaults.dividerThickness,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final groups = _groups;
    final path = _submenuPath;
    final MiuixDropdownEntry? submenuEntry =
        path != null && path.$1 < groups.length ? groups[path.$1] : null;
    final MiuixDropdownItem? submenuItem =
        path != null &&
            submenuEntry != null &&
            path.$2 < submenuEntry.items.length
        ? submenuEntry.items[path.$2]
        : null;
    final submenuShown =
        widget.show &&
        _submenu &&
        submenuItem?.children != null &&
        submenuItem!.children!.isNotEmpty;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final arrowTurn = rtl ? 90.0 : -90.0;
    final secondaryBackdrop = widget.secondaryBackdrop ?? widget.backdrop;

    return ListenableBuilder(
      listenable: widget.anchor,
      builder: (context, _) {
        final backFactor = 1.0 - widget.anchor.secondaryBackProgress;
        return GlassSpringBuilder(
          value: submenuShown ? arrowTurn : 0.0,
          spring: MiuixGlassMotion.secondaryPopup(submenuShown),
          builder: (context, arrowDeg, _) {
            final effectiveArrow = arrowDeg * backFactor;
            return Stack(
              children: [
                MiuixGlassTransformPopup(
                  show: widget.show,
                  onDismissRequest: () {
                    if (_submenu) setState(() => _submenu = false);
                    widget.onDismissRequest();
                  },
                  anchor: widget.anchor,
                  backdrop: widget.backdrop,
                  anchorContent: widget.anchorContent,
                  stacked: submenuShown,
                  sizing: widget.sizing,
                  visuals: widget.visuals,
                  onMeasured: (size) {
                    if (_primaryWidth != size.width && mounted) {
                      setState(() => _primaryWidth = size.width);
                    }
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var g = 0; g < groups.length; g++) ...[
                        for (var i = 0; i < groups[g].items.length; i++)
                          Builder(
                            builder: (context) {
                              final entry = groups[g];
                              final item = entry.items[i];
                              final children = item.children;
                              final hasChildren =
                                  children != null && children.isNotEmpty;
                              final isActiveSubmenuRow =
                                  path?.$1 == g && path?.$2 == i;
                              final rowKey = hasChildren ? _keyFor(g, i) : null;
                              return KeyedSubtree(
                                key: rowKey,
                                child: MiuixGlassPopupItem(
                                  text: item.text,
                                  icon: item.icon,
                                  summary: item.summary,
                                  enabled: entry.enabled && item.enabled,
                                  selected: item.selected,
                                  showArrow: hasChildren,
                                  arrowRotation: isActiveSubmenuRow
                                      ? effectiveArrow
                                      : 0,
                                  onPressed: () {
                                    if (hasChildren) {
                                      if (widget.show && !_submenuPresent) {
                                        final rect = _measureRow(rowKey!);
                                        if (rect != null) {
                                          setState(() {
                                            _submenuAnchor = rect;
                                            _submenuPath = (g, i);
                                            _submenuPresent = true;
                                            _submenu = true;
                                          });
                                        }
                                      }
                                    } else {
                                      item.onClick?.call();
                                      if (_collapse) {
                                        if (_submenu) {
                                          setState(() => _submenu = false);
                                        }
                                        widget.onDismissRequest();
                                      }
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                        if (g < groups.length - 1) _divider(),
                      ],
                    ],
                  ),
                ),
                MiuixGlassSecondaryPopup(
                  show: submenuShown,
                  onDismissRequest: () => setState(() => _submenu = false),
                  anchorBounds: _submenuAnchor,
                  backdrop: secondaryBackdrop,
                  materialAnchor: widget.anchor,
                  sizing: _primaryWidth == null
                      ? widget.sizing
                      : MiuixGlassPopupSizing(
                          minWidth: _primaryWidth!.clamp(
                            0.0,
                            widget.sizing.maxWidth,
                          ),
                          maxWidth: widget.sizing.maxWidth,
                          maxHeight: widget.sizing.maxHeight,
                          safeMargin: widget.sizing.safeMargin,
                        ),
                  visuals: widget.visuals,
                  onDismissFinished: () {
                    if (mounted) {
                      setState(() {
                        _submenuPresent = false;
                        _submenuPath = null;
                      });
                    }
                  },
                  child: submenuItem == null
                      ? const SizedBox.shrink()
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            MiuixGlassPopupItem(
                              text: submenuItem.text,
                              icon: submenuItem.icon,
                              summary: submenuItem.summary,
                              selected: submenuItem.selected,
                              showArrow: true,
                              arrowRotation: effectiveArrow,
                              onPressed: () => setState(() => _submenu = false),
                            ),
                            _divider(),
                            for (final child
                                in submenuItem.children ?? const [])
                              MiuixGlassPopupItem(
                                text: child.text,
                                icon: child.icon,
                                summary: child.summary,
                                enabled:
                                    (submenuEntry?.enabled ?? false) &&
                                    submenuItem.enabled &&
                                    child.enabled,
                                selected: child.selected,
                                onPressed: () {
                                  child.onClick?.call();
                                  if (_collapse) {
                                    setState(() => _submenu = false);
                                    widget.onDismissRequest();
                                  }
                                },
                              ),
                          ],
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
