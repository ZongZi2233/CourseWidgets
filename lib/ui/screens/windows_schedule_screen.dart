import 'package:flutter/material.dart';
import '../widgets/weekly_schedule_grid.dart';

/// [v3.0.0] CourseWidgets Windows 桌面端课表界面
/// 架构收敛：委托核心 WeeklyScheduleGrid 统一渲染课表网格与微乳亚克力底板。
/// 消除原本 900+ 行重复维护的日列与卡片碰撞计算，全平台共享 120 FPS 双管道渲染引擎。
class WindowsScheduleScreen extends StatelessWidget {
  const WindowsScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RepaintBoundary(
      child: WeeklyScheduleGrid(
        showControlBar: true,
        isPhone: false,
        contentPadding: EdgeInsets.fromLTRB(8.0, 6.0, 8.0, 84.0),
      ),
    );
  }
}
