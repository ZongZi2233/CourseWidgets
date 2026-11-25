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
          _buildLivePreviewNotificationCard(
            isCentered: isCentered,
            isDark: isDark,
          ),
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

  double _wcagContrastRatio(Color a, Color b) {
    final l1 = a.computeLuminance();
    final l2 = b.computeLuminance();
    final lighter = l1 > l2 ? l1 : l2;
    final darker = l1 > l2 ? l2 : l1;
    return (lighter + 0.05) / (darker + 0.05);
  }

  (Color, Color) _resolveHeroBadgeGradient(Color accent) {
    var hsv = HSVColor.fromColor(accent);
    if (hsv.saturation > 0.12) {
      hsv = hsv.withSaturation((hsv.saturation * 1.06).clamp(0.45, 0.94));
    }
    var topColor = hsv.toColor();
    int steps = 0;
    while (_wcagContrastRatio(topColor, Colors.white) < 4.8 &&
        hsv.value > 0.18 &&
        steps < 28) {
      final nextVal = (hsv.value - 0.03).clamp(0.18, 1.0);
      final nextSat = hsv.saturation > 0.12
          ? (hsv.saturation + 0.01).clamp(0.0, 0.96)
          : hsv.saturation;
      hsv = hsv.withValue(nextVal).withSaturation(nextSat);
      topColor = hsv.toColor();
      steps++;
    }
    final bottomColor = hsv
        .withValue((hsv.value * 0.88).clamp(0.14, 1.0))
        .toColor();
    return (topColor, bottomColor);
  }

  Color _resolveThemeSafeAccentText(Color accent, bool isDark) {
    var hsv = HSVColor.fromColor(accent);
    if (isDark) {
      const darkSurface = Color(0xFF14171F);
      var candidate = accent;
      int steps = 0;
      while (_wcagContrastRatio(candidate, darkSurface) < 4.6 &&
          hsv.value < 0.98 &&
          steps < 20) {
        hsv = hsv.withValue((hsv.value + 0.04).clamp(0.0, 0.98));
        candidate = hsv.toColor();
        steps++;
      }
      return candidate;
    } else {
      if (hsv.saturation > 0.12) {
        hsv = hsv.withSaturation((hsv.saturation * 1.08).clamp(0.42, 0.96));
      }
      var candidate = hsv.toColor();
      int steps = 0;
      while (_wcagContrastRatio(candidate, Colors.white) < 4.8 &&
          hsv.value > 0.18 &&
          steps < 28) {
        hsv = hsv.withValue((hsv.value - 0.03).clamp(0.18, 1.0));
        candidate = hsv.toColor();
        steps++;
      }
      return candidate;
    }
  }

  Widget _buildLivePreviewNotificationCard({
    required bool isCentered,
    required bool isDark,
  }) {
    final isEmptyDay = _previewScenario == _PreviewScenario.emptyDay;
    final isWaiting = _previewScenario == _PreviewScenario.longClassroom;

    final String headerText;
    final String? chronometerText;
    final String capsuleText;
    final IconData statusIcon;
    final String courseTitle;
    final String rawRoom;
    final String badgeSecondary;
    final String heroAccentText;
    final String heroTitleSuffix;
    final String? detailPrimaryBold;
    final String? nextCourseAccent;
    final String? nextCourseName;
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
      badgeSecondary = '周一·3门';
      heroAccentText = '18:30–20:05';
      heroTitleSuffix = ' · 第 9-10 节';
      detailPrimaryBold = courseTitle;
      nextCourseAccent = null;
      nextCourseName = null;
      thirdMetaLine = '今日无课 · 龚鸣敏';
      barCourses = const [];
      barActiveIdx = 0;
    } else if (isWaiting) {
      headerText = '即将开课';
      chronometerText = '15:00';
      capsuleText = '中1203·15分';
      statusIcon = Icons.schedule_rounded;
      courseTitle = '嵌入式系统原理与应用';
      rawRoom = '中1203室（信工学院基础实验室（4））';
      badgeSecondary = '3-4节';
      heroAccentText = '10:00–11:40';
      heroTitleSuffix = ' · $courseTitle';
      detailPrimaryBold = null;
      nextCourseAccent = null;
      nextCourseName = null;
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
      badgeSecondary = '1-2节';
      heroAccentText = '09:40 下课';
      heroTitleSuffix = ' · $courseTitle';
      detailPrimaryBold = null;
      nextCourseAccent = 'C302';
      nextCourseName = '数据结构';
      thirdMetaLine = null;
      barCourses = const ['早读', '高等数学', '嵌入式系统原理与应用', '数据结构'];
      barActiveIdx = 1;
    }

    final roomInfo = ClassroomDisplayInfo.parse(rawRoom);
    final Color themeColor =
        CourseColorPalette.getNotificationAccentColor(courseTitle);
    final Color accentTextColor =
        _resolveThemeSafeAccentText(themeColor, isDark);
    final (Color badgeTopColor, Color badgeBottomColor) =
        _resolveHeroBadgeGradient(themeColor);

    final Color cardBg = isDark ? const Color(0xFF14171F) : Colors.white;
    final Color cardBorder = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);
    final Color primaryInk =
        isDark ? Colors.white : const Color(0xFF111827);
    final Color secondaryInk =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color mutedInk =
        isDark ? const Color(0xFF8E95A3) : const Color(0xFF6B7280);
    final Color nextAccentColor = nextCourseName != null
        ? _resolveThemeSafeAccentText(
            CourseColorPalette.getNotificationAccentColor(nextCourseName),
            isDark,
          )
        : accentTextColor;

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
              Expanded(
                child: Text(
                  '状态栏实况胶囊',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: mutedInk,
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
            color: cardBg,
            borderRadius: SquircleGeometry.smoothRadius(20),
            border: Border.all(color: cardBorder),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 1. 顶部精简状态行（12sp 功能导视单色图标 + 状态/日期 + 系统原样纯文本计时器）
              Row(
                children: [
                  Icon(
                    statusIcon,
                    color: accentTextColor,
                    size: 13,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      headerText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: secondaryInk,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (chronometerText != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      chronometerText,
                      style: TextStyle(
                        color: primaryInk,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),

              // 2. 与 Android 16 实体 1:1 对齐：左侧 16sp 粗体主标题 + 14sp 次要信息 | 右侧 60dp 高对比纯白字教室大色块 + 节次底栏
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: heroAccentText,
                                style: TextStyle(
                                  color: accentTextColor,
                                  fontSize: 16.0,
                                  fontWeight: FontWeight.w700,
                                  height: 1.25,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                              TextSpan(
                                text: heroTitleSuffix,
                                style: TextStyle(
                                  color: primaryInk,
                                  fontSize: 16.0,
                                  fontWeight: FontWeight.w700,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (detailPrimaryBold != null) ...[
                          const SizedBox(height: 5),
                          Text(
                            detailPrimaryBold,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: primaryInk,
                              fontSize: 14.0,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                          ),
                        ],
                        if (roomInfo.hasVenue || nextCourseName != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (roomInfo.hasVenue && nextCourseName != null)
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 96,
                                  ),
                                  child: _MarqueeVenueText(
                                    text: roomInfo.venue,
                                    style: TextStyle(
                                      color: secondaryInk,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                )
                              else if (roomInfo.hasVenue)
                                Expanded(
                                  child: _MarqueeVenueText(
                                    text: roomInfo.venue,
                                    style: TextStyle(
                                      color: secondaryInk,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                              if (nextCourseName != null)
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: ' · 下节 ',
                                          style: TextStyle(
                                            color: secondaryInk,
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                        if (nextCourseAccent != null)
                                          TextSpan(
                                            text: nextCourseAccent,
                                            style: TextStyle(
                                              color: nextAccentColor,
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        TextSpan(
                                          text: ' $nextCourseName',
                                          style: TextStyle(
                                            color: secondaryInk,
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w400,
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
                        ],
                        if (thirdMetaLine != null) ...[
                          const SizedBox(height: 3.5),
                          Text(
                            thirdMetaLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: mutedInk,
                              fontSize: 13.0,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    key: const ValueKey('live_hero_room_badge'),
                    width: 60,
                    height: 60,
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [badgeTopColor, badgeBottomColor],
                      ),
                      borderRadius: SquircleGeometry.smoothRadius(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                roomInfo.code,
                                maxLines: 1,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22.0,
                                  fontWeight: FontWeight.w800,
                                  height: 1.04,
                                  letterSpacing: -0.4,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          alignment: Alignment.center,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              badgeSecondary,
                              maxLines: 1,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // 3. 底部按课程区分颜色的多节点进度条（浅/深色自适应轨道，无课时自动隐藏并维持饱满高度）
              if (!isEmptyDay) ...[
                const SizedBox(height: 12),
                if (isWaiting)
                  _buildBreakCountdownBar(
                    color: themeColor,
                    progressFraction: 0.66,
                    height: 7,
                    trackerIcon: statusIcon,
                    isDark: isDark,
                  )
                else if (isCentered)
                  _buildMultiCourseDotsBar(
                    courseNames: barCourses,
                    activeIndex: barActiveIdx,
                    progressFraction: 0.60,
                    height: 7,
                    trackerIcon: statusIcon,
                    isDark: isDark,
                  )
                else
                  _buildMultiCourseSegmentsBar(
                    courseNames: barCourses,
                    weights: const [20, 32, 24, 24],
                    activeIndex: barActiveIdx,
                    progressFraction: 0.62,
                    height: 7,
                    trackerIcon: statusIcon,
                    isDark: isDark,
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
    bool isDark = true,
  }) {
    final track = Color.lerp(
      color,
      isDark ? const Color(0xFF161A22) : const Color(0xFFE2E8F0),
      isDark ? 0.72 : 0.78,
    )!;
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
        _buildTrackerBadge(color, trackerIcon, isDark: isDark),
      ],
    );
  }

  Widget _buildTrackerBadge(
    Color color,
    IconData icon, {
    bool isDark = true,
  }) {
    final safeColor = _resolveThemeSafeAccentText(color, isDark);
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121318) : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: safeColor, width: 1.2),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 10, color: safeColor),
    );
  }

  Widget _buildMultiCourseDotsBar({
    required List<String> courseNames,
    required int activeIndex,
    required double progressFraction,
    required double height,
    IconData? trackerIcon,
    bool isDark = true,
  }) {
    final activeColor = CourseColorPalette.getNotificationAccentColor(
      courseNames[activeIndex.clamp(0, courseNames.length - 1)],
    );
    final pastTarget =
        isDark ? const Color(0xFF3E4452) : const Color(0xFF94A3B8);
    final futureTarget =
        isDark ? const Color(0xFF232833) : const Color(0xFFCBD5E1);
    final trackTarget =
        isDark ? const Color(0xFF161A22) : const Color(0xFFE2E8F0);
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
                  Color.lerp(courseColor, pastTarget, 0.5)!,
                  size: height,
                );
              }
              if (i == activeIndex) {
                final track = Color.lerp(
                  courseColor,
                  trackTarget,
                  isDark ? 0.72 : 0.78,
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
                Color.lerp(
                  courseColor,
                  futureTarget,
                  isDark ? 0.45 : 0.58,
                )!,
                size: height,
              );
            },
          ),
        ],
        if (trackerIcon != null) ...[
          const SizedBox(width: 6),
          _buildTrackerBadge(activeColor, trackerIcon, isDark: isDark),
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
    bool isDark = true,
  }) {
    final activeColor = CourseColorPalette.getNotificationAccentColor(
      courseNames[activeIndex.clamp(0, courseNames.length - 1)],
    );
    final pastTarget =
        isDark ? const Color(0xFF3E4452) : const Color(0xFF94A3B8);
    final futureTarget =
        isDark ? const Color(0xFF232833) : const Color(0xFFCBD5E1);
    final trackTarget =
        isDark ? const Color(0xFF161A22) : const Color(0xFFE2E8F0);
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
                    trackTarget,
                    isDark ? 0.72 : 0.78,
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
                    ? Color.lerp(courseColor, pastTarget, 0.5)!
                    : Color.lerp(
                        courseColor,
                        futureTarget,
                        isDark ? 0.45 : 0.58,
                      )!;
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
          _buildTrackerBadge(activeColor, trackerIcon, isDark: isDark),
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
            '采用与 Android 16 原生实况模板 1:1 对齐的 4 层导视排版：右侧 64dp 高饱和教室主导视方块（浅/深色下字迹恒为纯白）+ 16sp 主标题关键时间与课程名 + 14sp 次要场地与下节预告 + 12sp 状态页眉；状态栏胶囊按紧迫度分级，仅上课中与 60 分钟内候课显示教室和余分，跨天预告自动精简为「周一·3节」。\n\n'
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
