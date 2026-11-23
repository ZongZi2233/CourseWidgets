import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../services/notification_manager.dart';
import '../../services/live_notification_service_v2.dart';
import '../../services/data_import_service.dart';
import '../../services/theme_service.dart';
import '../../utils/glass_settings_helper.dart';
import '../widgets/liquid_components.dart' as liquid;
import '../widgets/immersive_status_bar_backdrop.dart';
import '../widgets/windows_desktop_title_bar.dart'
    show setWindowsDesktopTitle, clearWindowsDesktopTitle;
import 'package:smooth_scroll_multiplatform/smooth_scroll_multiplatform.dart';

/// [v2.2.8 / v3.1.0] 课程通知设置页面
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
  String _liveProgressStyle = NotificationManager.styleCenteredDots;

  @override
  void initState() {
    super.initState();
    setWindowsDesktopTitle('课程通知');
    _loadSettings();
  }

  @override
  void dispose() {
    clearWindowsDesktopTitle('课程通知');
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _notificationEnabled = _notificationManager.isNotificationEnabled;
      _doubleReminder = _notificationManager.isDoubleReminderEnabled;
      _liveActivitiesEnabled = _notificationManager.isLiveActivitiesEnabled;
      _liveProgressStyle = _notificationManager.liveProgressStyle;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService().isDarkMode;
    final isDesktop =
        Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    final topPadding =
        isDesktop ? 20.0 : (MediaQuery.paddingOf(context).top + 60);

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
                padding: EdgeInsets.fromLTRB(
                  16,
                  topPadding,
                  16,
                  isDesktop ? 32 : 100,
                ),
                physics: physics,
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 860),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('通知提醒与实况', isDark),
                          _buildCardGroup([
                            _buildSwitchRow(
                              title: '启用课程通知',
                              subtitle: '课前准时弹出上课提醒横幅与声音提示',
                              icon: CupertinoIcons.bell_fill,
                              value: _notificationEnabled,
                              onChanged: (value) async {
                                setState(() => _notificationEnabled = value);
                                await _notificationManager
                                    .setNotificationEnabled(value);
                              },
                              isDark: isDark,
                            ),
                            _buildSwitchRow(
                              title: '双次提醒',
                              subtitle: '课前 5 分钟二次强提醒，防匆忙遗漏',
                              icon: CupertinoIcons.bell_circle_fill,
                              value: _doubleReminder,
                              onChanged: (value) async {
                                setState(() => _doubleReminder = value);
                                await _notificationManager.setDoubleReminder(
                                  value,
                                );
                              },
                              isDark: isDark,
                            ),
                            _buildSwitchRow(
                              title: '开启实况通知 (Live Activities)',
                              subtitle: 'Android 16 状态栏胶囊与实况导视常驻看板',
                              icon: CupertinoIcons.sparkles,
                              value: _liveActivitiesEnabled,
                              onChanged: (value) async {
                                setState(() => _liveActivitiesEnabled = value);
                                await _notificationManager
                                    .setLiveActivitiesEnabled(value);
                                if (value) {
                                  await LiveNotificationServiceV2()
                                      .forceRefreshNotification();
                                } else {
                                  await LiveNotificationServiceV2()
                                      .cancelNotification();
                                }
                              },
                              isDark: isDark,
                            ),
                          ], isDark),

                          const SizedBox(height: 20),

                          _buildSectionHeader('实况导视样式预览', isDark),
                          _buildProgressStyleCard(isDark),

                          const SizedBox(height: 20),

                          _buildSectionHeader('系统日历同步', isDark),
                          _buildCardGroup([
                            _buildActionRow(
                              title: '同步课表到系统日程 (ICS)',
                              subtitle: '一键将全学期课程表同步导入到手机自带系统日历',
                              icon: CupertinoIcons.calendar_badge_plus,
                              onTap: () async {
                                HapticFeedback.selectionClick();
                                liquid.showLiquidToast(
                                  context,
                                  '正在生成课表并拉起系统日历...',
                                );
                                final success = await DataImportService()
                                    .openIcsInSystemCalendar();
                                if (context.mounted) {
                                  if (success) {
                                    liquid.showLiquidToast(
                                      context,
                                      '已拉起系统日历，请在日历中确认导入',
                                    );
                                  } else {
                                    liquid.showLiquidToast(
                                      context,
                                      '拉起系统日历失败，请检查日程应用',
                                    );
                                  }
                                }
                              },
                              isDark: isDark,
                            ),
                          ], isDark),

                          const SizedBox(height: 20),

                          _buildInfoCard(),

                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: const [
                      liquid.FloatingGlassHeaderButton(title: '课程通知'),
                    ],
                  ),
                ),
              ),
            ),

          // 4. 悬浮右下角返回按钮（仅移动端展示）
          if (!isDesktop) const liquid.FloatingLiquidBackButton(),
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

  /// [v3.2.0] 全新实况导视风格卡片实时预览 + 进度条双模式选择器
  Widget _buildProgressStyleCard(bool isDark) {
    final accent = ThemeService().primaryColor;
    final isCentered =
        _liveProgressStyle == NotificationManager.styleCenteredDots;

    return liquid.HyperOSCard(
      cornerRadius: 24,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部 1:1 实况通知导视预览卡片（完全对齐 Android 16 原生通知层级与真圆角徽章）
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0E1117),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.circle,
                      color: Color(0xFF10B981),
                      size: 8,
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        '课表 · 进行中 · 08:00–09:40',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: const Text(
                        '24:18',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: const [
                                TextSpan(
                                  text: 'A101',
                                  style: TextStyle(
                                    color: Color(0xFF10B981),
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                TextSpan(
                                  text: ' · ',
                                  style: TextStyle(
                                    color: Color(0xFF8E95A3),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                TextSpan(
                                  text: '高等数学（教室置前防截断）',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text.rich(
                            TextSpan(
                              children: const [
                                TextSpan(
                                  text: '09:40',
                                  style: TextStyle(
                                    color: Color(0xFF10B981),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                TextSpan(
                                  text: ' 下课  ·  下节 ',
                                  style: TextStyle(
                                    color: Color(0xFF8E95A3),
                                    fontSize: 11.5,
                                  ),
                                ),
                                TextSpan(
                                  text: 'C302',
                                  style: TextStyle(
                                    color: Color(0xFF10B981),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                TextSpan(
                                  text: ' 数据结构',
                                  style: TextStyle(
                                    color: Color(0xFFE5E7EB),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            '1-2',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              height: 1.05,
                            ),
                          ),
                          Text(
                            '节',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              fontSize: 9.8,
                              fontWeight: FontWeight.w600,
                              height: 1.15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 11),
                if (isCentered)
                  Row(
                    children: [
                      _buildPreviewDot(const Color(0xFF6B7280)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Container(
                          height: 7,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F4235),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: 0.60,
                            child: Container(
                              height: 7,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _buildPreviewDot(const Color(0xFF323743)),
                      const SizedBox(width: 5),
                      _buildPreviewDot(const Color(0xFF323743)),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        flex: 20,
                        child: Container(
                          height: 7,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6B7280),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        flex: 32,
                        child: Container(
                          height: 7,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F4235),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: 0.62,
                            child: Container(
                              height: 7,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        flex: 24,
                        child: Container(
                          height: 7,
                          decoration: BoxDecoration(
                            color: const Color(0xFF323743),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        flex: 24,
                        child: Container(
                          height: 7,
                          decoration: BoxDecoration(
                            color: const Color(0xFF323743),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 6),
                const Text(
                  '无课或今日已结课时自动隐藏进度条',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildStyleOptionTile(
            styleKey: NotificationManager.styleCenteredDots,
            title: '居中样式（推荐）',
            subtitle: '当前课程或课间居中展开为长胶囊，其余节次缩为圆点',
            isSelected:
                _liveProgressStyle == NotificationManager.styleCenteredDots,
            isDark: isDark,
            accent: accent,
            previewBuilder: () => Row(
              children: [
                _buildPreviewDot(const Color(0xFF5A5A60)),
                const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C4332),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: 0.58,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFF8AE29A),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _buildPreviewDot(const Color(0xFF34343A)),
                const SizedBox(width: 5),
                _buildPreviewDot(const Color(0xFF34343A)),
                const SizedBox(width: 5),
                _buildPreviewDot(const Color(0xFF34343A)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _buildStyleOptionTile(
            styleKey: NotificationManager.styleDurationSegments,
            title: '按时长分段',
            subtitle: '全天每门课程与课间按真实时长比例分段排布',
            isSelected:
                _liveProgressStyle == NotificationManager.styleDurationSegments,
            isDark: isDark,
            accent: accent,
            previewBuilder: () => Row(
              children: [
                Expanded(
                  flex: 22,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFF5A5A60),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  flex: 25,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C4332),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: 0.62,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFF8AE29A),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  flex: 24,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFF34343A),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  flex: 12,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFF34343A),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  flex: 20,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFF34343A),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewDot(Color color) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _buildStyleOptionTile({
    required String styleKey,
    required String title,
    required String subtitle,
    required bool isSelected,
    required bool isDark,
    required Color accent,
    required Widget Function() previewBuilder,
  }) {
    return GestureDetector(
      onTap: () async {
        if (_liveProgressStyle == styleKey) return;
        HapticFeedback.selectionClick();
        setState(() => _liveProgressStyle = styleKey);
        await _notificationManager.setLiveProgressStyle(styleKey);
        await LiveNotificationServiceV2().forceRefreshNotification();
        if (mounted) {
          liquid.showLiquidToast(
            context,
            styleKey == NotificationManager.styleCenteredDots
                ? '已切换为「居中圆点样式」'
                : '已切换为「按时长分段样式」',
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withValues(alpha: isDark ? 0.16 : 0.10)
              : (isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.black.withValues(alpha: 0.025)),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? accent.withValues(alpha: 0.65)
                : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSelected
                      ? CupertinoIcons.checkmark_circle_fill
                      : CupertinoIcons.circle,
                  size: 19,
                  color: isSelected
                      ? accent
                      : GlassSettingsHelper.getSecondaryTextColor(context),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: GlassSettingsHelper.getTextColor(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: GlassSettingsHelper.getSecondaryTextColor(
                            context,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFF0B0B0E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: previewBuilder(),
            ),
          ],
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
                color: isDark
                    ? const Color(0xFFD6DBE5)
                    : const Color(0xFF3A4150),
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
          liquid.LiquidSwitch(value: value, onChanged: onChanged),
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
                  color: isDark
                      ? const Color(0xFFD6DBE5)
                      : const Color(0xFF3A4150),
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
              color: GlassSettingsHelper.getSecondaryTextColor(
                context,
              ).withValues(alpha: 0.6),
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
                'Live Activities 实况通知',
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
            '采用全新实况导视信息分级排版（教室号置前高对比高亮 + 右侧真圆角节次徽章 + 简洁下节指引），长课程名不遮挡教室，当日无课或已结课时自动隐藏进度条。\n\n'
            '• 秒级实时倒计时：由系统底层 Chronometer 驱动跳秒，零额外功耗\n'
            '• 双模节点时间轴：支持「居中圆点样式」与「按时长分段样式」实时切换\n'
            '• 跨天防歧义：午夜零点自动刷新今日/明日归属与状态栏胶囊摘要',
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
