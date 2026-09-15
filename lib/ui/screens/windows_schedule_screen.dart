import 'package:flutter/material.dart';
import '../widgets/weekly_schedule_grid.dart';
import '../transitions/smooth_slide_transitions.dart';

/// [v3.0.0] CourseWidgets Windows 桌面端课表界面
/// 架构收敛：委托核心 WeeklyScheduleGrid 统一渲染课表网格与微乳亚克力底板。
/// 消除原本 900+ 行重复维护的日列与卡片碰撞计算，全平台共享 120 FPS 双管道渲染引擎。
class WindowsScheduleScreen extends StatelessWidget {
  const WindowsScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: TransparentMaterialPageRoute.contentBoundaryKey,
      child: const Padding(
        padding: EdgeInsets.only(top: 4.0, bottom: 8.0, left: 4.0, right: 4.0),
        child: WeeklyScheduleGrid(
          showControlBar: true,
          isPhone: false,
          contentPadding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
        ),
      ),
    );
  }
}
