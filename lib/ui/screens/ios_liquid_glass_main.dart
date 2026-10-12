import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../providers/schedule_provider.dart';
import '../../constants/theme_constants.dart';
import 'dart:ui';

import '../../utils/responsive_utils.dart';
import 'course_edit_screen.dart';
import 'calendar_view_screen.dart';
import 'settings_main_screen.dart';
import '../widgets/liquid_components.dart' as liquid;
import '../widgets/tablet_sidebar.dart';
import '../widgets/weekly_schedule_grid.dart';

class IosLiquidGlassMain extends StatefulWidget {
  const IosLiquidGlassMain({super.key});
  @override
  State<IosLiquidGlassMain> createState() => _IosLiquidGlassMainState();
}

class _IosLiquidGlassMainState extends State<IosLiquidGlassMain> {
  int _currentIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final provider = context.read<ScheduleProvider>();
      await provider.loadSavedData();

      // 注意：iOS环境不支持Android原生的LiveNotificationServiceV2
      // 如果将来集成 Live Activities (iOS 16+)，应该在这里初始化

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('❌ iOS 加载数据失败: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CupertinoActivityIndicator(color: Colors.white)),
      );
    }

    return _buildPhoneLayout(context);
  }

  /// iPad 布局
  Widget _buildTabletLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Row(
        children: [
          TabletSideBar(
            selectedIndex: _currentIndex,
            onTabSelected: (index) {
              HapticFeedback.selectionClick();
              setState(() => _currentIndex = index);
            },
            items: const [
              TabletSideBarItem(
                icon: CupertinoIcons.square_grid_2x2,
                selectedIcon: CupertinoIcons.square_grid_2x2_fill,
                label: '课程',
              ),
              TabletSideBarItem(
                icon: CupertinoIcons.calendar,
                selectedIcon: CupertinoIcons.calendar,
                label: '日历',
              ),
              TabletSideBarItem(
                icon: CupertinoIcons.settings,
                selectedIcon: CupertinoIcons.settings_solid,
                label: '设置',
              ),
            ],
          ),
          Expanded(
            child: RepaintBoundary(
              child: IndexedStack(
                key: ValueKey(_currentIndex),
                index: _currentIndex,
                children: [
                  _buildTabletSchedulePage(),
                  const CalendarViewScreen(),
                  const SettingsMainScreen(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// iPhone 布局
  Widget _buildPhoneLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: Stack(
        children: [
          RepaintBoundary(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                _buildPageWithHeader(0, _buildSchedulePage()),
                _buildPageWithHeader(1, const CalendarViewScreen()),
                _buildPageWithHeader(2, const SettingsMainScreen()),
              ],
            ),
          ),
          if (_currentIndex == 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 80,
              child: _buildWeekAndDaySelectorWrapper(),
            ),
        ],
      ),
      bottomNavigationBar: RepaintBoundary(
        child: GlassBottomBar(
          selectedIndex: _currentIndex,
          onTabSelected: (index) {
            HapticFeedback.selectionClick();
            setState(() => _currentIndex = index);
          },
          glassSettings: LiquidGlassSettings(
            blur: 3.0,
            thickness: 30.0,
            refractiveIndex: 1.59,
          ),
          indicatorColor: AppThemeColors.babyPink.withValues(alpha: 0.3),
          tabs: const [
            GlassBottomBarTab(
              icon: CupertinoIcons.square_grid_2x2_fill,
              label: '课程',
            ),
            GlassBottomBarTab(icon: CupertinoIcons.calendar, label: '日历'),
            GlassBottomBarTab(icon: CupertinoIcons.settings_solid, label: '设置'),
          ],
        ),
      ),
    );
  }

  Widget _buildTabletSchedulePage() {
    return const SafeArea(
      child: Padding(padding: EdgeInsets.all(20), child: WeeklyScheduleGrid()),
    );
  }

  Widget _buildWeekAndDaySelectorWrapper() {
    return Consumer<ScheduleProvider>(
      builder: (context, provider, _) => Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.15),
                    ),
                    child: SizedBox(
                      height: 44,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: provider.availableWeeks.length,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemBuilder: (context, index) {
                          final week = provider.availableWeeks[index];
                          final isSelected = week == provider.currentWeek;
                          final isCurrent =
                              week ==
                              provider.currentWeek; // simplified for now

                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              provider.setCurrentWeek(week);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppThemeColors.babyPink
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                                border: isCurrent && !isSelected
                                    ? Border.all(
                                        color: AppThemeColors.babyPink
                                            .withValues(alpha: 0.5),
                                        width: 1,
                                      )
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  '第$week周',
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white70,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            liquid.LiquidCard(
              borderRadius: 20,
              padding: 0,
              glassColor: Colors.black.withValues(alpha: 0.1),
              child: SizedBox(
                height: 60,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    provider.currentConfig.showWeekends ? 7 : 5,
                    (index) {
                      final day = index + 1;
                      final isSelected = day == provider.currentDay;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          provider.setCurrentDay(day);
                        },
                        child: Container(
                          width: 40,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                ['一', '二', '三', '四', '五', '六', '日'][index],
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white60,
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSchedulePage() {
    return const WeeklyScheduleGrid();
  }

  Widget _buildPageWithHeader(int index, Widget content) {
    String title = '';
    switch (index) {
      case 0:
        title = '课程表';
        break;
      case 1:
        title = '日历';
        break;
      case 2:
        title = '设置';
        break;
    }

    return Column(
      children: [
        _buildDynamicHeader(title, index),
        Expanded(child: content),
      ],
    );
  }

  Widget _buildDynamicHeader(String title, int index) {
    final topPadding = MediaQuery.of(context).padding.top;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(
            top: topPadding + 10,
            bottom: 10,
            left: 20,
            right: 20,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.1),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.05),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              if (index == 0)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showAddCourseMenu(context);
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppThemeColors.babyPink.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      CupertinoIcons.add,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddCourseMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 20,
          left: 20,
          right: 20,
          top: 20,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E), // iOS风格深色背景
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            const Text(
              '添加课程',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildMenuOption(
              icon: CupertinoIcons.pen,
              title: '手动添加',
              subtitle: '自定义课程详情',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  CupertinoPageRoute(builder: (_) => const CourseEditScreen()),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildMenuOption(
              icon: CupertinoIcons.doc_text_search,
              title: '从教务系统导入',
              subtitle: '支持各大高校课表快速导入',
              onTap: () {
                Navigator.pop(context);
                _showImportDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppThemeColors.babyPink.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppThemeColors.babyPink, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              color: Colors.white.withValues(alpha: 0.3),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showImportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => liquid.LiquidCard(
        borderRadius: 24,
        padding: 0,
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2C),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.doc_text_search,
                size: 48,
                color: AppThemeColors.babyPink,
              ),
              const SizedBox(height: 16),
              const Text(
                '导入提示',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '教务系统导入功能需要特定适配，请选择对应的学校模板进行导入。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        '取消',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppThemeColors.babyPink,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('敬请期待：正在适配各大高校...'),
                            backgroundColor: Color(0xFF333333),
                          ),
                        );
                      },
                      child: const Text('确定'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
