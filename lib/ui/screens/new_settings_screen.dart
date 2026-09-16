import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../providers/schedule_provider.dart';
import '../../constants/theme_constants.dart';
import 'android_schedule_config_screen.dart';
import 'course_edit_screen.dart';
import '../widgets/liquid_components.dart' as liquid;
import '../transitions/smooth_slide_transitions.dart';
import '../widgets/liquid_glass_pickers.dart';
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Text(
                          '课程设置',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: _textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildSectionTitle('课程管理'),
                  _buildSettingCard(
                    title: '添加课程',
                    subtitle: '手动添加新课程',
                    icon: CupertinoIcons.add_circled,
                    color: AppThemeColors.babyPink,
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
                  _buildSettingCard(
                    title: '课时配置',
                    subtitle: '调整每节课的时间',
                    icon: CupertinoIcons.time,
                    color: AppThemeColors.softCoral,
                    onTap: () => Navigator.push(
                      context,
                      TransparentMaterialPageRoute(
                        builder: (_) => const AndroidScheduleConfigScreen(),
                      ),
                    ),
                  ),

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
                      return _buildSettingCard(
                        title: '开学日期',
                        subtitle:
                            '${provider.semesterStartDate.year}-${provider.semesterStartDate.month.toString().padLeft(2, '0')}-${provider.semesterStartDate.day.toString().padLeft(2, '0')}  ·  $weekDisplay',
                        icon: CupertinoIcons.time_solid,
                        color: Colors.purpleAccent,
                        onTap: _pickSemesterStartDate,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const liquid.FloatingLiquidBackButton(),
      ],
    ),
  );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: _textColor,
        ),
      ),
    );
  }

  Widget _buildSettingCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: liquid.HyperOSCard(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: _textSecondaryColor),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.right_chevron,
              color: _textSecondaryColor.withValues(alpha: 0.5),
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
