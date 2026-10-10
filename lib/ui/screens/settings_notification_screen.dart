import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../services/notification_manager.dart';
import '../../services/data_import_service.dart';
import '../../services/theme_service.dart';
import '../../utils/glass_settings_helper.dart';
import '../widgets/liquid_components.dart' as liquid;
import '../widgets/immersive_status_bar_backdrop.dart';
import 'package:smooth_scroll_multiplatform/smooth_scroll_multiplatform.dart';

/// [v2.2.8] 课程通知设置页面
class SettingsNotificationScreen extends StatefulWidget {
  const SettingsNotificationScreen({super.key});

  @override
  State<SettingsNotificationScreen> createState() =>
      _SettingsNotificationScreenState();
}

class _SettingsNotificationScreenState
    extends State<SettingsNotificationScreen> {
  final NotificationManager _notificationManager = NotificationManager();

  bool _notificationEnabled = true;
  bool _doubleReminder = true;
  bool _liveActivitiesEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _notificationEnabled = _notificationManager.isNotificationEnabled;
      _doubleReminder = _notificationManager.isDoubleReminderEnabled;
      _liveActivitiesEnabled = _notificationManager.isLiveActivitiesEnabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService().isDarkMode;
    final topPadding = MediaQuery.paddingOf(context).top + 54;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 1. 全出血自由滑动内容区：穿透顶栏与状态栏，消除截断，满帧 120 FPS
          Positioned.fill(
            child: DynMouseScroll(
              durationMS: 250,
              scrollSpeed: 1.2,
              builder: (context, controller, physics) => ListView(
                controller: controller,
                padding: EdgeInsets.fromLTRB(16, topPadding, 16, 100),
                physics: physics,
                children: [
                  _buildSectionHeader('通知提醒与实况', isDark),
                  _buildCardGroup([
                    _buildSwitchRow(
                      title: '启用课程通知',
                      subtitle: '在课程开始前提醒你',
                      icon: CupertinoIcons.bell_fill,
                      value: _notificationEnabled,
                      onChanged: (value) async {
                        setState(() => _notificationEnabled = value);
                        await _notificationManager.setNotificationEnabled(value);
                      },
                      isDark: isDark,
                    ),
                    _buildSwitchRow(
                      title: '双次提醒',
                      subtitle: '在上课前 5 分钟再次提醒',
                      icon: CupertinoIcons.bell_circle_fill,
                      value: _doubleReminder,
                      onChanged: (value) async {
                        setState(() => _doubleReminder = value);
                        await _notificationManager.setDoubleReminder(value);
                      },
                      isDark: isDark,
                    ),
                    _buildSwitchRow(
                      title: '开启实况通知 (Live Activities)',
                      subtitle: 'Android 16 实时活动与 iOS 灵动岛常驻支持',
                      icon: CupertinoIcons.sparkles,
                      value: _liveActivitiesEnabled,
                      onChanged: (value) async {
                        setState(() => _liveActivitiesEnabled = value);
                        await _notificationManager.setLiveActivitiesEnabled(value);
                      },
                      isDark: isDark,
                    ),
                  ], isDark),

                  const SizedBox(height: 20),

                  _buildSectionHeader('系统日历同步', isDark),
                  _buildCardGroup([
                    _buildActionRow(
                      title: '同步课表到系统日程 (ICS)',
                      subtitle: '一键将全学期课程表同步导入到手机自带系统日历',
                      icon: CupertinoIcons.calendar_badge_plus,
                      onTap: () async {
                        HapticFeedback.selectionClick();
                        liquid.showLiquidToast(context, '正在生成课表并拉起系统日历...');
                        final success = await DataImportService().openIcsInSystemCalendar();
                        if (context.mounted) {
                          if (success) {
                            liquid.showLiquidToast(context, '已拉起系统日历，请在日历中确认导入');
                          } else {
                            liquid.showLiquidToast(context, '拉起系统日历失败，请检查日程应用');
                          }
                        }
                      },
                      isDark: isDark,
                    ),
                  ], isDark),

                  const SizedBox(height: 20),

                  // Live Activities 说明
                  _buildInfoCard(),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),

          // 2. 状态栏微模糊避让 (0..48dp)
          const ImmersiveStatusBarBackdrop(),

          // 3. 悬浮标题栏
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Text(
                      '课程通知',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: GlassSettingsHelper.getTextColor(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4. [v2.9.7] 悬浮右下角返回按钮
          const liquid.FloatingLiquidBackButton(),
        ],
      ),
    );
  }

  static const double kSettingsItemHeight = 56.0;

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white60 : const Color(0xFF6B7280),
        ),
      ),
    );
  }

  Widget _buildCardGroup(List<Widget> children, bool isDark) {
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

  Widget _buildSwitchRow({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return SizedBox(
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
                    color: GlassSettingsHelper.getTextColor(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: GlassSettingsHelper.getSecondaryTextColor(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          liquid.LiquidSwitch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
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
                      color: GlassSettingsHelper.getTextColor(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: GlassSettingsHelper.getSecondaryTextColor(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.right_chevron,
              size: 15,
              color: GlassSettingsHelper.getSecondaryTextColor(context).withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildInfoCard() {
    return liquid.HyperOSCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.info_circle_fill,
                color: Colors.blue.withValues(alpha: 0.8),
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Live Activities',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: GlassSettingsHelper.getTextColor(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '支持 Android 16 (Live Updates) 和 iOS/iPadOS 16.1+、macOS 设备的主屏幕实况通知，可以在锁屏及通知栏实时显示课程倒计时。\n\n'
            '• 实时更新：显示距离上课/下课的实时倒计时\n'
            '• 开启此功能后：若你的系统或 OEM 厂商支持，将优先展示动态面板。',
            style: TextStyle(
              fontSize: 13,
              color: GlassSettingsHelper.getSecondaryTextColor(context),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
