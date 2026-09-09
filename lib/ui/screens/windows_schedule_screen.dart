import 'package:flutter/material.dart';
import '../widgets/weekly_schedule_grid.dart';

/// [v2.8.9] 现代化桌面端全周课表页面，统一复用 WeeklyScheduleGrid
/// 具备半透明混色 HyperOSCard、黑白模式自适应高对比度字体与多周切换看板
class WindowsScheduleScreen extends StatelessWidget {
  const WindowsScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const WeeklyScheduleGrid(
      showControlBar: true,
      isPhone: false,
    );
  }
}
