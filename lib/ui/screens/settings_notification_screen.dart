import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../constants/theme_constants.dart';
import '../../services/notification_manager.dart';
import '../../services/data_import_service.dart';
import '../../utils/glass_settings_helper.dart';
import '../widgets/liquid_components.dart' as liquid;
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          AdaptiveLiquidGlassLayer(
            quality: GlassQuality.premium,
            settings: const LiquidGlassSettings(
              blur: 3.0,
              thickness: 24.0,
              glassColor: Color(0x0EFFFFFF),
              lightIntensity: 0.70,
              ambientStrength: 0.45,
              ambientRim: 0.0,
              fresnelStrength: 0.05,
              saturation: 1.20,
              refractiveIndex: 1.46,
            ),
            child: Column(
              children: [
                // Header
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        const liquid.LiquidBackButton(),
                        const SizedBox(width: 12),
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

                // Content
                Expanded(
                  child: DynMouseScroll(
                    durationMS: 250,
                    scrollSpeed: 1.2,
                    builder: (context, controller, physics) => ListView(
                      controller: controller,
                      padding: const EdgeInsets.all(20),
                      physics: physics,
                      children: [
                        // 启用通知
                        _buildSwitchCard(
                          title: '启用课程通知',
                          subtitle: '在课程开始前提醒你',
                          icon: CupertinoIcons.bell_fill,
                          value: _notificationEnabled,
                          onChanged: (value) async {
                            setState(() => _notificationEnabled = value);
                            await _notificationManager.setNotificationEnabled(value);
                          },
                        ),

                        const SizedBox(height: 16),

                        // 双次提醒
                        _buildSwitchCard(
                          title: '双次提醒',
                          subtitle: '在上课前 5 分钟再次提醒\n(Android API < 34 和 Windows)',
                          icon: CupertinoIcons.bell_circle_fill,
                          value: _doubleReminder,
                          onChanged: (value) async {
                            setState(() => _doubleReminder = value);
                            await _notificationManager.setDoubleReminder(value);
                          },
                        ),

                        const SizedBox(height: 16),

                        // Live Activities 开关
                        _buildSwitchCard(
                          title: '开启实况通知 (Live Activities)',
                          subtitle:
                              'Android 16 实时活动 (Live Update) 与 iOS 灵动岛 (Live Activities) 支持',
                          icon: CupertinoIcons.sparkles,
                          value: _liveActivitiesEnabled,
                          onChanged: (value) async {
                            setState(() => _liveActivitiesEnabled = value);
                            await _notificationManager.setLiveActivitiesEnabled(
                              value,
                            );
                          },
                        ),

                        const SizedBox(height: 16),

                        // [v2.9.7] 同步课表到系统日程 (ICS)
                        _buildActionCard(
                          title: '同步课表到系统日程 (ICS)',
                          subtitle: '一键将全学期课程表同步导入到手机自带系统日历与日程提醒中',
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
                        ),

                        const SizedBox(height: 16),

                        // Live Activities 说明
                        _buildInfoCard(),

                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // [v2.9.7] 悬浮右下角返回按钮
          const liquid.FloatingLiquidBackButton(),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return liquid.HyperOSCard(
      padding: const EdgeInsets.all(20),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppThemeColors.babyPink.withValues(alpha: 0.8),
                  AppThemeColors.softCoral.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
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
                    color: GlassSettingsHelper.getTextColor(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: GlassSettingsHelper.getSecondaryTextColor(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            CupertinoIcons.chevron_forward,
            size: 16,
            color: GlassSettingsHelper.getSecondaryTextColor(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return liquid.HyperOSCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppThemeColors.babyPink.withValues(alpha: 0.8),
                  AppThemeColors.softCoral.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
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
                    color: GlassSettingsHelper.getTextColor(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: GlassSettingsHelper.getSecondaryTextColor(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeColor: AppThemeColors.babyPink,
          ),
        ],
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
