import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:provider/provider.dart';
import '../../constants/theme_constants.dart';
import '../../constants/version.dart';
import '../../providers/schedule_provider.dart';
import '../../services/notification_manager.dart';
import '../../services/theme_service.dart';
import '../../utils/responsive_utils.dart';
import 'new_settings_screen.dart';
import 'settings_general_screen.dart';
import 'settings_about_screen.dart';
import 'settings_data_screen.dart';
import 'settings_notification_screen.dart';
import '../widgets/app_update_dialog.dart';
import '../widgets/liquid_components.dart' as liquid;
import '../transitions/smooth_slide_transitions.dart';
import '../animations/app_motion.dart';

/// [v2.8.4] 设置主界面 - 全面迁移官方 GlassCard 与 AdaptiveLiquidGlassLayer
class SettingsMainScreen extends StatefulWidget {
  const SettingsMainScreen({super.key});
  @override
  State<SettingsMainScreen> createState() => _SettingsMainScreenState();
}

class _SettingsMainScreenState extends State<SettingsMainScreen> {
  bool _isCheckingUpdate = false;

  ScheduleProvider? _watchScheduleSafe(BuildContext context) {
    try {
      return Provider.of<ScheduleProvider>(context);
    } catch (_) {
      return null;
    }
  }

  String _courseSummarySubtitle(ScheduleProvider? schedule) {
    if (schedule == null || schedule.courses.isEmpty) {
      return '添加课程、作息时间与开学校准';
    }
    final firstStart = schedule.currentConfig.sectionStartTimes[1] ?? 480;
    final h = (firstStart ~/ 60).toString().padLeft(2, '0');
    final m = (firstStart % 60).toString().padLeft(2, '0');
    return '已录入 ${schedule.courses.length} 条记录 · 第 ${schedule.currentWeek} 周 · $h:$m 起课';
  }

  String _notificationSummarySubtitle() {
    final nm = NotificationManager();
    if (!nm.isNotificationEnabled && !nm.isLiveActivitiesEnabled) {
      return '课程提醒与实况导视均已关闭';
    }
    if (nm.isLiveActivitiesEnabled) {
      final mode = nm.liveProgressStyle == NotificationManager.styleDurationSegments
          ? '时长分段'
          : '居中圆点';
      return '实况导视已开启 · $mode · ${nm.isDoubleReminderEnabled ? "双次提醒" : "单次提醒"}';
    }
    return nm.isDoubleReminderEnabled ? '课前常规 + 5分钟二次提醒' : '课前单次通知提醒';
  }

  String _generalSummarySubtitle(bool isDark) {
    final ts = ThemeService();
    final darkLabel = isDark ? '夜间深色' : '日间浅色';
    final glassLabel = ts.glassQuality == GlassQuality.premium ? '旗舰折射' : '流畅高帧';
    return '$darkLabel · $glassLabel · 个性壁纸';
  }

  void _triggerUpdateCheck() {
    if (_isCheckingUpdate) return;
    AppUpdateDialog.checkAndShow(
      context,
      onStart: () {
        if (mounted) setState(() => _isCheckingUpdate = true);
      },
      onFinish: () {
        if (mounted) setState(() => _isCheckingUpdate = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isDesktopOrTablet = ResponsiveUtils.isTabletMode(context) ||
        ResponsiveUtils.isDesktopOrLandscape(context);
    final isLandscape = ResponsiveUtils.isLandscape(context) || isDesktopOrTablet;

    // 自适应顶部与底部内边距：横屏/桌面端充分避让状态栏，手机竖屏预留顶部标题栏与浮动Dock
    final double topPadding;
    if (isLandscape) {
      topPadding = MediaQuery.paddingOf(context).top + 18.0;
    } else {
      topPadding = 80.0;
    }

    final double bottomPadding;
    if (isLandscape) {
      bottomPadding = MediaQuery.paddingOf(context).bottom + 76.0;
    } else {
      bottomPadding = 120.0;
    }

    final schedule = _watchScheduleSafe(context);
    final courseSub = _courseSummarySubtitle(schedule);
    final notifySub = _notificationSummarySubtitle();
    final generalSub = _generalSummarySubtitle(isDark);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: SafeArea(
        top: false,
        bottom: false,
        child: isLandscape
            ? _buildLandscapeLayout(
                isDark,
                topPadding,
                bottomPadding,
                courseSub: courseSub,
                notifySub: notifySub,
                generalSub: generalSub,
              )
            : _buildPortraitLayout(
                isDark,
                topPadding,
                bottomPadding,
                courseSub: courseSub,
                notifySub: notifySub,
                generalSub: generalSub,
              ),
      ),
    );
  }

  /// [v3.0.0 正式版] 横屏与桌面端左右双栏自适应布局（左栏课表与体验，右栏数据与系统，安全避让状态栏与边距）
  Widget _buildLandscapeLayout(
    bool isDark,
    double topPadding,
    double bottomPadding, {
    required String courseSub,
    required String notifySub,
    required String generalSub,
  }) {
    final leftPadding = 20.0 + MediaQuery.paddingOf(context).left;
    final rightPadding = 20.0 + MediaQuery.paddingOf(context).right;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(leftPadding, topPadding, rightPadding, bottomPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左栏：课表与体验 (50%)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSectionHeader('课表与体验', isDark),
                _buildCardGroup([
                  _buildSettingsRow(
                    title: '课程设置',
                    subtitle: courseSub,
                    icon: Icons.school_rounded,
                    onTap: () => _navigateTo(const NewSettingsScreen()),
                    isDark: isDark,
                  ),
                  _buildSettingsRow(
                    title: '课程通知',
                    subtitle: notifySub,
                    icon: Icons.notifications_rounded,
                    onTap: () => _navigateTo(const SettingsNotificationScreen()),
                    isDark: isDark,
                  ),
                  _buildSettingsRow(
                    title: '通用设置',
                    subtitle: generalSub,
                    icon: Icons.tune_rounded,
                    onTap: () => _navigateTo(const SettingsGeneralScreen()),
                    isDark: isDark,
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // 右栏：数据与系统 (50%)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSectionHeader('数据与系统', isDark),
                _buildCardGroup([
                  _buildSettingsRow(
                    title: '数据管理',
                    subtitle: '智能教务导入、多格式导出与历史备份',
                    icon: Icons.cloud_sync_rounded,
                    onTap: () => _navigateTo(const SettingsDataScreen()),
                    isDark: isDark,
                  ),
                  _buildSettingsRow(
                    title: '检查更新',
                    subtitle: Platform.isWindows
                        ? '当前 v$appVersion · 文件级差异增量热更新'
                        : '当前 v$appVersion · 自动检测 GitHub 新版发布',
                    icon: Icons.system_update_alt_rounded,
                    onTap: _triggerUpdateCheck,
                    isDark: isDark,
                    recordSharedElement: false,
                    trailing: _isCheckingUpdate
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.0,
                              color: AppThemeColors.babyPink,
                            ),
                          )
                        : null,
                  ),
                  _buildSettingsRow(
                    title: '关于软件',
                    subtitle: '版本信息、开源协议与项目主页',
                    icon: Icons.info_outline_rounded,
                    onTap: () => _navigateTo(const SettingsAboutScreen()),
                    isDark: isDark,
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 手机竖屏经典单列滚动布局
  Widget _buildPortraitLayout(
    bool isDark,
    double topPadding,
    double bottomPadding, {
    required String courseSub,
    required String notifySub,
    required String generalSub,
  }) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(16, topPadding, 16, bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('课表与体验', isDark),
          _buildCardGroup([
            _buildSettingsRow(
              title: '课程设置',
              subtitle: courseSub,
              icon: Icons.school_rounded,
              onTap: () => _navigateTo(const NewSettingsScreen()),
              isDark: isDark,
            ),
            _buildSettingsRow(
              title: '课程通知',
              subtitle: notifySub,
              icon: Icons.notifications_rounded,
              onTap: () => _navigateTo(const SettingsNotificationScreen()),
              isDark: isDark,
            ),
            _buildSettingsRow(
              title: '通用设置',
              subtitle: generalSub,
              icon: Icons.tune_rounded,
              onTap: () => _navigateTo(const SettingsGeneralScreen()),
              isDark: isDark,
            ),
          ]),
          const SizedBox(height: 20),
          _buildSectionHeader('数据与系统', isDark),
          _buildCardGroup([
            _buildSettingsRow(
              title: '数据管理',
              subtitle: '智能教务导入、多格式导出与历史备份',
              icon: Icons.cloud_sync_rounded,
              onTap: () => _navigateTo(const SettingsDataScreen()),
              isDark: isDark,
            ),
            _buildSettingsRow(
              title: '检查更新',
              subtitle: Platform.isWindows
                  ? '当前 v$appVersion · 文件级差异增量热更新'
                  : '当前 v$appVersion · 自动检测 GitHub 新版发布',
              icon: Icons.system_update_alt_rounded,
              onTap: _triggerUpdateCheck,
              isDark: isDark,
              recordSharedElement: false,
              trailing: _isCheckingUpdate
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.0,
                        color: AppThemeColors.babyPink,
                      ),
                    )
                  : null,
            ),
            _buildSettingsRow(
              title: '关于软件',
              subtitle: '版本信息、开源协议与项目主页',
              icon: Icons.info_outline_rounded,
              onTap: () => _navigateTo(const SettingsAboutScreen()),
              isDark: isDark,
            ),
          ]),
        ],
      ),
    );
  }

  static const double kSettingsItemHeight = 58.0;

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white54 : Colors.black45,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildCardGroup(List<Widget> children) {
    return Builder(
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final dividerColor = isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.05);

        return RepaintBoundary(
          child: liquid.HyperOSCard(
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
          ),
        );
      },
    );
  }

  Widget _buildSettingsRow({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
    bool recordSharedElement = true,
    Widget? trailing,
  }) {
    return Builder(
      builder: (rowContext) => InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          if (recordSharedElement) {
            SharedElementSourceRegistry.recordFromContext(
              rowContext,
              cornerRadius: 20.0,
            );
          }
          onTap();
        },
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
                    size: 24,
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
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              trailing ??
                  Icon(
                    Icons.chevron_right_rounded,
                    color: isDark ? Colors.white30 : Colors.black26,
                    size: 20,
                  ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateTo(Widget screen) {
    Navigator.push(
      context,
      TransparentMaterialPageRoute(builder: (context) => screen),
    );
  }
}

