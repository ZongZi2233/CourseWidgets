// Miuix Flutter 移植版 - GlassDropdownPreference
// 源自 compose-miuix-ui/miuix 的 GlassDropdownPreference.kt。
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../blur/miuix_backdrop.dart';
import '../glass/miuix_glass_popup_anchor.dart';
import '../glass/miuix_glass_popup_style.dart';
import '../theme/miuix_theme.dart';
import 'miuix_basic_component.dart';
import 'miuix_dropdown.dart';
import 'miuix_glass_dropdown_popup.dart';
import 'miuix_glass_popup_item.dart';
import 'miuix_text.dart';

/// 带玻璃弧线下拉菜单（[MiuixGlassDropdownPopup]）的偏好设置行。
/// 对应 Kotlin `GlassDropdownPreference`。
///
/// 选中项由调用方受控管理；[backdrop] 需排除弹窗层本身以避免自采样。
class MiuixGlassDropdownPreference extends StatefulWidget {
  const MiuixGlassDropdownPreference({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelectedIndexChange,
    required this.title,
    this.backdrop,
    this.enabled = true,
    this.showValue = true,
    this.titleColor,
    this.summary,
    this.summaryColor,
    this.startAction,
    this.bottomAction,
    this.insideMargin = MiuixBasicComponentDefaults.insideMargin,
    this.sizing = const MiuixGlassPopupSizing(),
    this.visuals = const MiuixGlassPopupVisuals(),
    this.onExpandedChange,
  });

  final List<String> items;
  final int selectedIndex;
  final ValueChanged<int> onSelectedIndexChange;
  final String title;
  final MiuixBackdrop? backdrop;
  final bool enabled;
  final bool showValue;
  final MiuixBasicComponentColors? titleColor;
  final String? summary;
  final MiuixBasicComponentColors? summaryColor;
  final Widget? startAction;
  final Widget? bottomAction;
  final EdgeInsetsGeometry insideMargin;
  final MiuixGlassPopupSizing sizing;
  final MiuixGlassPopupVisuals visuals;
  final ValueChanged<bool>? onExpandedChange;

  @override
  State<MiuixGlassDropdownPreference> createState() =>
      _MiuixGlassDropdownPreferenceState();
}

class _MiuixGlassDropdownPreferenceState
    extends State<MiuixGlassDropdownPreference> {
  final _anchor = MiuixGlassPopupAnchor();
  bool _expanded = false;
  bool _mounted = false;

  bool get _actualEnabled => widget.enabled && widget.items.isNotEmpty;

  void _setExpanded(bool next) {
    if (_expanded == next) return;
    setState(() {
      _expanded = next;
      if (next) _mounted = true;
    });
    widget.onExpandedChange?.call(next);
  }

  @override
  void didUpdateWidget(MiuixGlassDropdownPreference oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_actualEnabled && _expanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_actualEnabled) _setExpanded(false);
      });
    }
  }

  @override
  void dispose() {
    _anchor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = MiuixTheme.of(context);
    final actionColor = _actualEnabled
        ? theme.colors.onSurfaceVariantActions
        : theme.colors.disabledOnSecondaryVariant;
    final String? value =
        widget.showValue &&
            widget.selectedIndex >= 0 &&
            widget.selectedIndex < widget.items.length
        ? widget.items[widget.selectedIndex]
        : null;

    return Stack(
      children: [
        KeyedSubtree(
          key: _anchor.key,
          child: MiuixBasicComponent(
            title: widget.title,
            titleColor: widget.titleColor,
            summary: widget.summary,
            summaryColor: widget.summaryColor,
            startAction: widget.startAction,
            endActions: <Widget>[
              MiuixGlassValueAnchor(
                anchor: _anchor,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (value != null && value.isNotEmpty)
                      Flexible(
                        fit: FlexFit.loose,
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: MiuixText(
                            value,
                            fontSize: theme.textStyles.body2.fontSize,
                            color: actionColor,
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    MiuixDropdownArrowEndAction(actionColor: actionColor),
                  ],
                ),
              ),
            ],
            bottomAction: widget.bottomAction,
            insideMargin: widget.insideMargin,
            onClick: _actualEnabled
                ? () {
                    final next = !_expanded;
                    _setExpanded(next);
                    if (next) HapticFeedback.selectionClick();
                  }
                : null,
            role: MiuixBasicComponentRole.dropdownList,
            holdDownState: _mounted,
            enabled: _actualEnabled,
          ),
        ),
        if (_mounted)
          MiuixGlassDropdownPopup(
            show: _expanded && _actualEnabled,
            onDismissRequest: () => _setExpanded(false),
            anchor: _anchor,
            backdrop: widget.backdrop,
            sizing: widget.sizing,
            visuals: widget.visuals,
            onDismissFinished: () {
              if (mounted) setState(() => _mounted = false);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (var i = 0; i < widget.items.length; i++)
                  MiuixGlassPopupItem(
                    text: widget.items[i],
                    selected: widget.selectedIndex == i,
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      _setExpanded(false);
                      widget.onSelectedIndexChange(i);
                    },
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
