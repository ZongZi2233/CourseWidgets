import 'dart:io';
import 'package:flutter/material.dart';
import 'package:smooth_scroll_multiplatform/smooth_scroll_multiplatform.dart';

/// 跨平台自适应平滑滚动包装器：
/// - 桌面端（Windows / macOS / Linux）：复用 [DynMouseScroll] 消除鼠标滚轮阶跃感；
/// - 移动端（Android / iOS）：跳过 `ChangeNotifierProvider` + `Listener` 逐帧开销，
///   直接使用原生 [ScrollController] 与高帧率弹簧阻尼物理特性，保障 120Hz 滚动流畅度。
class AdaptiveSmoothScroll extends StatefulWidget {
  final int durationMS;
  final double scrollSpeed;
  final Widget Function(
    BuildContext context,
    ScrollController controller,
    ScrollPhysics physics,
  ) builder;

  const AdaptiveSmoothScroll({
    super.key,
    this.durationMS = 250,
    this.scrollSpeed = 1.2,
    required this.builder,
  });

  @override
  State<AdaptiveSmoothScroll> createState() => _AdaptiveSmoothScrollState();
}

class _AdaptiveSmoothScrollState extends State<AdaptiveSmoothScroll> {
  ScrollController? _mobileController;

  bool get _isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  @override
  void initState() {
    super.initState();
    if (!_isDesktop) {
      _mobileController = ScrollController();
    }
  }

  @override
  void dispose() {
    _mobileController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isDesktop) {
      return DynMouseScroll(
        durationMS: widget.durationMS,
        scrollSpeed: widget.scrollSpeed,
        builder: widget.builder,
      );
    }
    return widget.builder(
      context,
      _mobileController!,
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
    );
  }
}
