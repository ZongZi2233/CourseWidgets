import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/schedule_provider.dart';
import '../../services/theme_service.dart';
import 'android_schedule_config_screen.dart';
import 'course_edit_screen.dart';
import '../widgets/liquid_components.dart' as liquid;
import '../transitions/smooth_slide_transitions.dart';
import '../widgets/liquid_glass_pickers.dart';
import '../widgets/immersive_status_bar_backdrop.dart';
import '../widgets/windows_desktop_title_bar.dart'
    show setWindowsDesktopTitle, clearWindowsDesktopTitle;
import '../../utils/glass_settings_helper.dart';

class NewSettingsScreen extends StatefulWidget {
  const NewSettingsScreen({super.key});
  @override
  State<NewSettingsScreen> createState() => _NewSettingsScreenState();
}

class _NewSettingsScreenState extends State<NewSettingsScreen> {
  Color get _textColor => GlassSettingsHelper.getTextColor(context);
  Color get _textSecondaryColor => GlassSettingsHelper.getSecondaryTextColor(context);

  @override
  void initState() {
    super.initState();
    setWindowsDesktopTitle('课程设置');
  }

  @override
  void dispose() {
    clearWindowsDesktopTitle('课程设置');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    final topPadding =
        isDesktop ? 20.0 : (MediaQuery.paddingOf(context).top + 60);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 1. 全出血自由滑动内容区
          Positioned.fill(
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, topPadding, 16, isDesktop ? 32 : 100),
              physics: const BouncingScrollPhysics(),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 860),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('课程管理'),
                        _buildCardGroup([
                    _buildSettingRow(
                      title: '添加课程',
                      subtitle: '手动添加新课程',
                      icon: CupertinoIcons.add_circled,
                      onTap: () {
                        final provider = context.read<ScheduleProvider>();
                        Navigator.push(
                          context,
                          TransparentMaterialPageRoute(
                            builder: (_) => CourseEditScreen(
                              week: provider.currentWeek,
                              day: provider.currentDay,
                            ),
                          ),
                        );
                      },
                    ),
                    _buildSettingRow(
                      title: '课时配置',
                      subtitle: '调整每节课的时间',
                      icon: CupertinoIcons.time,
                      onTap: () => Navigator.push(
                        context,
                        TransparentMaterialPageRoute(
                          builder: (_) => const AndroidScheduleConfigScreen(),
                        ),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 24),
                  _buildSectionTitle('学期设置'),
                  Consumer<ScheduleProvider>(
                    builder: (context, provider, _) {
                      final now = DateTime.now();
                      final weeksSinceStart =
                          now.difference(provider.semesterStartDate).inDays ~/
                              7 +
                          1;
                      final weekDisplay = weeksSinceStart < 1
                          ? '尚未开学'
                          : '当前第 $weeksSinceStart 周';
                      return _buildCardGroup([
                        _buildSettingRow(
                          title: '开学日期',
                          subtitle:
                              '${provider.semesterStartDate.year}-${provider.semesterStartDate.month.toString().padLeft(2, '0')}-${provider.semesterStartDate.day.toString().padLeft(2, '0')}  ·  $weekDisplay',
                          icon: CupertinoIcons.time_solid,
                          onTap: _pickSemesterStartDate,
                        ),
                      ]);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),

          // 2. 状态栏微模糊避让 (0..48dp)
          if (!isDesktop) const ImmersiveStatusBarBackdrop(),

          // 3. 悬浮大圆角矩形玻璃标题胶囊（仅移动端展示）
          if (!isDesktop)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: const [
                      liquid.FloatingGlassHeaderButton(title: '课程设置'),
                    ],
                  ),
                ),
              ),
            ),

          // 4. [v2.9.7] 悬浮右下角返回按钮（仅移动端展示）
          if (!isDesktop) const liquid.FloatingLiquidBackButton(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: _textSecondaryColor,
        ),
      ),
    );
  }

  static const double kSettingsItemHeight = 56.0;

  Widget _buildCardGroup(List<Widget> children) {
    final isDark = ThemeService().isDarkMode;
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.05);

    return liquid.HyperOSCard(
      cornerRadius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 0.6,
                indent: 48,
                color: dividerColor,
              ),
            children[i],
          ],
        ],
      ),
    );
  }

  Widget _buildSettingRow({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isDark = ThemeService().isDarkMode;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: kSettingsItemHeight,
        child: Row(
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: Center(
                child: Icon(
                  icon,
                  color: isDark ? const Color(0xFFD6DBE5) : const Color(0xFF3A4150),
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11.5, color: _textSecondaryColor),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.right_chevron,
              color: _textSecondaryColor.withValues(alpha: 0.45),
              size: 15,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickSemesterStartDate() async {
    final provider = context.read<ScheduleProvider>();

    final selectedDate = await showLiquidGlassCalendarPicker(
      context: context,
      initialDate: provider.semesterStartDate,
    );

    if (selectedDate != null) {
      provider.setSemesterStartDate(selectedDate);
    }
  }
}
