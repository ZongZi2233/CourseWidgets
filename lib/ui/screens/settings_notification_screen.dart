import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../services/notification_manager.dart';
import '../../services/live_notification_service_v2.dart';
import '../../services/data_import_service.dart';
import '../../services/theme_service.dart';
import '../../utils/classroom_parser.dart';
import '../../utils/glass_settings_helper.dart';
import '../theme/squircle_geometry.dart';
import '../widgets/adaptive_smooth_scroll.dart';
import '../widgets/course_color_helper.dart';
import '../widgets/liquid_components.dart' as liquid;
import '../widgets/immersive_status_bar_backdrop.dart';
import '../widgets/windows_desktop_title_bar.dart'
    show setWindowsDesktopTitle, clearWindowsDesktopTitle;

/// [v2.2.8 / v3.1.0] 课程通知设置页面
class SettingsNotificationScreen extends StatefulWidget {
  const SettingsNotificationScreen({super.key});

  @override
  State<SettingsNotificationScreen> createState() =>
      _SettingsNotificationScreenState();
}

enum _PreviewScenario { ongoing, longClassroom, emptyDay }

class _SettingsNotificationScreenState
    extends State<SettingsNotificationScreen> {
  final NotificationManager _notificationManager = NotificationManager();

  bool _notificationEnabled = true;
  bool _doubleReminder = true;
  bool _liveActivitiesEnabled = true;
  String _liveProgressStyle = NotificationManager.styleCenteredDots;
  _PreviewScenario _previewScenario = _PreviewScenario.ongoing;

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
          // 1. 全出血自由滑动内容区：独立 RepaintBoundary 隔离重绘，满帧 120 FPS
          Positioned.fill(
            child: RepaintBoundary(
              child: AdaptiveSmoothScroll(
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

  /// [v3.2.1] 全新实况导视风格卡片实时预览 + 多课程分色进度条双模式选择器
  Widget _buildProgressStyleCard(bool isDark) {
    final accent = ThemeService().primaryColor;
    final isCentered =
        _liveProgressStyle == NotificationManager.styleCenteredDots;

    return liquid.HyperOSCard(
      cornerRadius: 26,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildScenarioSwitcher(isDark),
          const SizedBox(height: 10),
          _buildLivePreviewNotificationCard(isCentered: isCentered),
          const SizedBox(height: 12),
          _buildStyleOptionTile(
            styleKey: NotificationManager.styleCenteredDots,
            title: '居中样式（推荐）',
            subtitle: '按每门课程主题色区分过去圆点、当前展开胶囊与待上节点',
            isSelected: isCentered,
            isDark: isDark,
            accent: accent,
            previewBuilder: () => _buildMultiCourseDotsBar(
              courseNames: const ['线性代数', '高等数学', '大学物理', '数据结构'],
              activeIndex: 1,
              progressFraction: 0.58,
              height: 8,
            ),
          ),
          const SizedBox(height: 10),
          _buildStyleOptionTile(
            styleKey: NotificationManager.styleDurationSegments,
            title: '按时长分段',
            subtitle: '全天每门课程按真实课时比例分段排布，并用独立课程色彩标识',
            isSelected: !isCentered,
            isDark: isDark,
            accent: accent,
            previewBuilder: () => _buildMultiCourseSegmentsBar(
              courseNames: const ['线性代数', '高等数学', '大学物理', '离散数学', '数据结构'],
              weights: const [20, 26, 22, 14, 18],
              activeIndex: 1,
              progressFraction: 0.62,
              height: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScenarioSwitcher(bool isDark) {
    const items = [
      (_PreviewScenario.ongoing, '正在上课'),
      (_PreviewScenario.longClassroom, '课间候课'),
      (_PreviewScenario.emptyDay, '今日无课'),
    ];
    final bg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.05);

    return Container(
      padding: const EdgeInsets.all(3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: SquircleGeometry.smoothRadius(14),
      ),
      child: Row(
        children: items.map((item) {
          final selected = _previewScenario == item.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (_previewScenario == item.$1) return;
                HapticFeedback.selectionClick();
                setState(() => _previewScenario = item.$1);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: selected
                      ? (isDark
                          ? Colors.white.withValues(alpha: 0.14)
                          : Colors.white)
                      : Colors.transparent,
                  borderRadius: SquircleGeometry.smoothRadius(11),
                ),
                alignment: Alignment.center,
                child: Text(
                  item.$2,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? GlassSettingsHelper.getTextColor(context)
                        : GlassSettingsHelper.getSecondaryTextColor(context),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLivePreviewNotificationCard({required bool isCentered}) {
    final isEmptyDay = _previewScenario == _PreviewScenario.emptyDay;
    final isWaiting = _previewScenario == _PreviewScenario.longClassroom;

    final String headerText;
    final String? chronometerText;
    final String capsuleText;
    final IconData statusIcon;
    final String courseTitle;
    final String rawRoom;
    final String badgePrimary;
    final String badgeSecondary;
    final String largeTimeText;
    final String? timeMiddleText;
    final String? timeSuffixText;
    final String? thirdMetaLine;
    final List<String> barCourses;
    final int barActiveIdx;

    if (isEmptyDay) {
      headerText = '11月30日 · 第 12 周';
      chronometerText = null;
      capsuleText = '周一·3节';
      statusIcon = Icons.calendar_view_week_rounded;
      courseTitle = '人工智能—AI绘画从入门到精通';
      rawRoom = '中1203室（信工学院基础实验室（4））';
      badgePrimary = '周一';
      badgeSecondary = '3门';
      largeTimeText = '18:30–20:05';
      timeMiddleText = null;
      timeSuffixText = null;
      thirdMetaLine = '第 9-10 节 · 今日无课 · 龚鸣敏';
      barCourses = const [];
      barActiveIdx = 0;
    } else if (isWaiting) {
      headerText = '即将开课';
      chronometerText = '15:00';
      capsuleText = '中1203·15分';
      statusIcon = Icons.schedule_rounded;
      courseTitle = '嵌入式系统原理与应用';
      rawRoom = '中1203室（信工学院基础实验室（4））';
      badgePrimary = '3-4';
      badgeSecondary = '节';
      largeTimeText = '10:00–11:40';
      timeMiddleText = null;
      timeSuffixText = null;
      thirdMetaLine = '距开课 15分钟 · 今日余 3 门 · 李教授';
      barCourses = const ['嵌入式系统原理与应用'];
      barActiveIdx = 0;
    } else {
      headerText = '进行中 · 08:00–09:40';
      chronometerText = '24:18';
      capsuleText = 'A101·剩24分';
      statusIcon = Icons.menu_book_rounded;
      courseTitle = '高等数学';
      rawRoom = 'A101逸夫楼';
      badgePrimary = '1-2';
      badgeSecondary = '节';
      largeTimeText = '09:40';
      timeMiddleText = ' 下课';
      timeSuffixText = ' · 下节 C302 数据结构';
      thirdMetaLine = null;
      barCourses = const ['早读', '高等数学', '嵌入式系统原理与应用', '数据结构'];
      barActiveIdx = 1;
    }

    final roomInfo = ClassroomDisplayInfo.parse(rawRoom);
    final Color themeColor =
        CourseColorPalette.getNotificationAccentColor(courseTitle);
    final Color badgeBg = Color.lerp(
      themeColor,
      const Color(0xFF0A0E16),
      0.24,
    )!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1:1 状态栏实况胶囊预览（仅在校时显示教室与剩余分钟，跨天显示次日/星期与课程数）
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 2, right: 2),
          child: Row(
            children: [
              Container(
                key: const ValueKey('live_capsule_preview'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4.5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1117),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: themeColor.withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: themeColor, size: 12),
                    const SizedBox(width: 5),
                    Text(
                      capsuleText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '状态栏实况胶囊',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          key: const ValueKey('live_preview_card'),
          constraints: const BoxConstraints(minHeight: 176),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0E1117),
            borderRadius: SquircleGeometry.smoothRadius(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 1. 顶部精简状态行（功能导视单色图标 + 状态/日期 + 系统原样纯文本计时器）
              Row(
                children: [
                  Icon(
                    statusIcon,
                    color: themeColor,
                    size: 13,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      headerText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (chronometerText != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      chronometerText,
                      style: const TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 9),

              // 2. 原生大字号 Title 槽（超大对比教室底块 + 核心时间）> 次行中等字号课程名 > 小号场地与详情 > 右侧 56dp 独立节次/星期徽章
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (!roomInfo.isEmpty &&
                                roomInfo.code.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: badgeBg,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  roomInfo.code,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18.5,
                                    fontWeight: FontWeight.w800,
                                    height: 1.08,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: largeTimeText,
                                      style: TextStyle(
                                        color: themeColor,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                    if (timeMiddleText != null)
                                      TextSpan(
                                        text: timeMiddleText,
                                        style: TextStyle(
                                          color: themeColor,
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          courseTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.0,
                            fontWeight: FontWeight.w700,
                            height: 1.22,
                          ),
                        ),
                        if (roomInfo.hasVenue || timeSuffixText != null) ...[
                          const SizedBox(height: 3.5),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (roomInfo.hasVenue && timeSuffixText != null)
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 120,
                                  ),
                                  child: _MarqueeVenueText(
                                    text: roomInfo.venue,
                                    style: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                )
                              else if (roomInfo.hasVenue)
                                Expanded(
                                  child: _MarqueeVenueText(
                                    text: roomInfo.venue,
                                    style: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              if (timeSuffixText != null)
                                Expanded(
                                  child: Text(
                                    timeSuffixText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFFCBD5E1),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                        if (thirdMetaLine != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            thirdMetaLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF8E95A3),
                              fontSize: 11,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 56,
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: SquircleGeometry.smoothRadius(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            badgePrimary,
                            maxLines: 1,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              height: 1.08,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          badgeSecondary,
                          maxLines: 1,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // 3. 底部按课程区分颜色的多节点进度条（课间 45 分钟内展示候课单条，无课时自动隐藏并维持饱满高度）
              if (!isEmptyDay) ...[
                const SizedBox(height: 12),
                if (isWaiting)
                  _buildBreakCountdownBar(
                    color: themeColor,
                    progressFraction: 0.66,
                    height: 7,
                    trackerIcon: statusIcon,
                  )
                else if (isCentered)
                  _buildMultiCourseDotsBar(
                    courseNames: barCourses,
                    activeIndex: barActiveIdx,
                    progressFraction: 0.60,
                    height: 7,
                    trackerIcon: statusIcon,
                  )
                else
                  _buildMultiCourseSegmentsBar(
                    courseNames: barCourses,
                    weights: const [20, 32, 24, 24],
                    activeIndex: barActiveIdx,
                    progressFraction: 0.62,
                    height: 7,
                    trackerIcon: statusIcon,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBreakCountdownBar({
    required Color color,
    required double progressFraction,
    required double height,
    required IconData trackerIcon,
  }) {
    final track = Color.lerp(color, const Color(0xFF161A22), 0.72)!;
    return Row(
      children: [
        Expanded(
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: track,
              borderRadius: BorderRadius.circular(99),
            ),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: progressFraction,
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        _buildTrackerBadge(color, trackerIcon),
      ],
    );
  }

  Widget _buildTrackerBadge(Color color, IconData icon) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: const Color(0xFF121318),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.2),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 10, color: color),
    );
  }

  Widget _buildMultiCourseDotsBar({
    required List<String> courseNames,
    required int activeIndex,
    required double progressFraction,
    required double height,
    IconData? trackerIcon,
  }) {
    final activeColor = CourseColorPalette.getNotificationAccentColor(
      courseNames[activeIndex.clamp(0, courseNames.length - 1)],
    );
    return Row(
      children: [
        for (int i = 0; i < courseNames.length; i++) ...[
          if (i > 0) const SizedBox(width: 5.5),
          Builder(
            builder: (_) {
              final courseColor =
                  CourseColorPalette.getNotificationAccentColor(courseNames[i]);
              if (i < activeIndex) {
                return _buildPreviewDot(
                  Color.lerp(courseColor, const Color(0xFF3E4452), 0.5)!,
                  size: height,
                );
              }
              if (i == activeIndex) {
                final track = Color.lerp(
                  courseColor,
                  const Color(0xFF161A22),
                  0.72,
                )!;
                return Expanded(
                  child: Container(
                    height: height,
                    decoration: BoxDecoration(
                      color: track,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: progressFraction,
                      child: Container(
                        height: height,
                        decoration: BoxDecoration(
                          color: courseColor,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ),
                );
              }
              return _buildPreviewDot(
                Color.lerp(courseColor, const Color(0xFF232833), 0.45)!,
                size: height,
              );
            },
          ),
        ],
        if (trackerIcon != null) ...[
          const SizedBox(width: 6),
          _buildTrackerBadge(activeColor, trackerIcon),
        ],
      ],
    );
  }

  Widget _buildMultiCourseSegmentsBar({
    required List<String> courseNames,
    required List<int> weights,
    required int activeIndex,
    required double progressFraction,
    required double height,
    IconData? trackerIcon,
  }) {
    final activeColor = CourseColorPalette.getNotificationAccentColor(
      courseNames[activeIndex.clamp(0, courseNames.length - 1)],
    );
    return Row(
      children: [
        for (int i = 0; i < courseNames.length; i++) ...[
          if (i > 0) const SizedBox(width: 5),
          Expanded(
            flex: weights[i],
            child: Builder(
              builder: (_) {
                final courseColor =
                    CourseColorPalette.getNotificationAccentColor(
                      courseNames[i],
                    );
                if (i == activeIndex) {
                  final track = Color.lerp(
                    courseColor,
                    const Color(0xFF161A22),
                    0.72,
                  )!;
                  return Container(
                    height: height,
                    decoration: BoxDecoration(
                      color: track,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: progressFraction,
                      child: Container(
                        height: height,
                        decoration: BoxDecoration(
                          color: courseColor,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  );
                }
                final muted = i < activeIndex
                    ? Color.lerp(courseColor, const Color(0xFF3E4452), 0.5)!
                    : Color.lerp(courseColor, const Color(0xFF232833), 0.45)!;
                return Container(
                  height: height,
                  decoration: BoxDecoration(
                    color: muted,
                    borderRadius: BorderRadius.circular(99),
                  ),
                );
              },
            ),
          ),
        ],
        if (trackerIcon != null) ...[
          const SizedBox(width: 6),
          _buildTrackerBadge(activeColor, trackerIcon),
        ],
      ],
    );
  }

  Widget _buildPreviewDot(Color color, {double size = 8}) {
    return Container(
      width: size,
      height: size,
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
          borderRadius: SquircleGeometry.smoothRadius(18),
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
                borderRadius: SquircleGeometry.smoothRadius(12),
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
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kSettingsItemHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            liquid.LiquidSwitch(value: value, onChanged: onChanged),
          ],
        ),
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
      borderRadius: SquircleGeometry.smoothRadius(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kSettingsItemHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
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
                        color: GlassSettingsHelper.getSecondaryTextColor(
                          context,
                        ),
                      ),
                      maxLines: 2,
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
              Expanded(
                child: Text(
                  'Live Activities 实况通知',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: GlassSettingsHelper.getTextColor(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '采用全新实况导视字号层级排版（放大高对比教室编号色块与具体时间范围、缩小次要场地说明，并搭配课本/钟表/课表三态单色功能图标），同时状态栏胶囊智能区分紧急程度：仅在上课中或临近开课 60 分钟内显示教室与剩余时间，今日无课或跨天预告精简为「周一·3节」等下次上课概览。\n\n'
            '• 按课程分色引擎：通知主题色、右侧徽章、进度圆点与分段条均自动对齐各课程独立色彩\n'
            '• 秒级实时倒计时：由系统底层 Chronometer 驱动跳秒，零额外功耗\n'
            '• 双模节点时间轴：支持「居中圆点样式」与「按时长分段样式」实时切换',
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

/// 场地说明自适应文本组件：短文本静态零开销展示；仅在超出可用宽度时启动平滑往返跑马灯滚动。
class _MarqueeVenueText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _MarqueeVenueText({
    required this.text,
    required this.style,
  });

  @override
  State<_MarqueeVenueText> createState() => _MarqueeVenueTextState();
}

class _MarqueeVenueTextState extends State<_MarqueeVenueText>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  double _overflowPx = 0.0;

  @override
  void didUpdateWidget(covariant _MarqueeVenueText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _controller?.stop();
      _overflowPx = 0.0;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _syncAnimation(double overflowPx) {
    if (!mounted) return;
    if (overflowPx <= 0.5) {
      final wasActive = _overflowPx > 0.5 || (_controller?.isAnimating ?? false);
      if (wasActive) {
        _controller?.stop();
        setState(() => _overflowPx = 0.0);
      }
      return;
    }

    if (_controller == null || (overflowPx - _overflowPx).abs() > 1.0) {
      final durationMs = ((overflowPx + 60.0) * 45.0).round().clamp(3600, 9000);
      _controller ??= AnimationController(
        vsync: this,
        duration: Duration(milliseconds: durationMs),
      );
      _controller!.duration = Duration(milliseconds: durationMs);
      if (!_controller!.isAnimating) {
        _controller!.repeat();
      }
      setState(() => _overflowPx = overflowPx);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        if (!maxW.isFinite || maxW <= 0) {
          return Text(
            widget.text,
            style: widget.style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }

        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: 1,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();

        final overflow = (painter.width - maxW).clamp(0.0, double.infinity);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _syncAnimation(overflow);
        });

        if (overflow <= 0.5) {
          return Text(
            widget.text,
            style: widget.style,
            maxLines: 1,
            overflow: TextOverflow.clip,
          );
        }

        final controller = _controller;
        if (controller == null) {
          return Text(
            widget.text,
            style: widget.style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }

        final slideAnim = TweenSequence<double>([
          TweenSequenceItem(tween: ConstantTween(0.0), weight: 18),
          TweenSequenceItem(
            tween: Tween(begin: 0.0, end: -overflow)
                .chain(CurveTween(curve: Curves.easeInOut)),
            weight: 34,
          ),
          TweenSequenceItem(tween: ConstantTween(-overflow), weight: 16),
          TweenSequenceItem(
            tween: Tween(begin: -overflow, end: 0.0)
                .chain(CurveTween(curve: Curves.easeInOut)),
            weight: 32,
          ),
        ]).animate(controller);

        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            minWidth: 0,
            maxWidth: painter.width + 2,
            child: AnimatedBuilder(
              animation: slideAnim,
              builder: (_, child) => Transform.translate(
                offset: Offset(slideAnim.value, 0),
                child: child,
              ),
              child: Text(
                widget.text,
                style: widget.style,
                maxLines: 1,
                softWrap: false,
              ),
            ),
          ),
        );
      },
    );
  }
}
