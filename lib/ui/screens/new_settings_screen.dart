import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../providers/schedule_provider.dart';
import '../../services/theme_service.dart';
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
          AdaptiveLiquidGlassLayer(
            quality: ThemeService().glassQuality,
            settings: const LiquidGlassSettings(
              blur: 3.0,
              thickness: 24.0,
              glassColor: Color(0x0EFFFFFF),
              lightIntensity: 0.70,
              ambientStrength: 0.45,
              ambientRim: 0.0,
              fresnelStrength: 0.0,
              saturation: 1.20,
              refractiveIndex: 1.46,
            ),
            child: Column(
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
          ],
        ),
      ),
      const liquid.FloatingLiquidBackButton(),
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
