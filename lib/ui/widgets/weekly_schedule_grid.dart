import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:provider/provider.dart';
import '../../constants/theme_constants.dart';
import '../../models/course_event.dart';
import '../../models/schedule_config.dart';
import '../../providers/schedule_provider.dart';
import '../screens/course_edit_screen.dart';
import 'liquid_components.dart' as liquid;
import 'course_color_helper.dart';
import 'course_name_formatter.dart';
import 'glass_context_menu.dart';
import '../theme/squircle_geometry.dart';
import '../transitions/smooth_slide_transitions.dart';
import 'package:smooth_scroll_multiplatform/smooth_scroll_multiplatform.dart';
import '../animations/app_motion.dart';
import '../../services/theme_service.dart' as theme;
import '../../utils/responsive_utils.dart';

/// [v2.9.0] 本周课程网格视图（支持平板与手机竖屏全看板）
class WeeklyScheduleGrid extends StatefulWidget {
  final bool showControlBar;
  final EdgeInsetsGeometry contentPadding;
  final bool isPhone;

  const WeeklyScheduleGrid({
    super.key,
    this.showControlBar = true,
    this.contentPadding = EdgeInsets.zero,
    this.isPhone = false,
  });

  @override
  State<WeeklyScheduleGrid> createState() => _WeeklyScheduleGridState();
}

class _WeeklyScheduleGridState extends State<WeeklyScheduleGrid> {
  static const double kSectionRowHeight = 68.0; // [v2.9.0] 适当增加卡片高度与字体空间
  static const int kTotalSections = 13;
  final ValueNotifier<bool> _isBackgroundFrozen = ValueNotifier<bool>(false);
  PageController? _weekPageController;
  int _lastSyncedWeek = -1;
  bool _isProgrammaticScroll = false;

  int _programmaticScrollToken = 0;

  void _navigateToPage(int targetPage) {
    if (_weekPageController == null || !_weekPageController!.hasClients) return;
    final cur = _weekPageController!.page?.round() ?? _weekPageController!.initialPage;
    if (cur == targetPage) return;

    final token = ++_programmaticScrollToken;
    _isProgrammaticScroll = true;
    _weekPageController!
        .animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 380),
          curve: AppCurves.pageSlide,
        )
        .then((_) {
          if (mounted && _programmaticScrollToken == token) {
            _isProgrammaticScroll = false;
          }
        }, onError: (_) {
          if (mounted && _programmaticScrollToken == token) {
            _isProgrammaticScroll = false;
          }
        });
  }

  @override
  void dispose() {
    _weekPageController?.dispose();
    _isBackgroundFrozen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ScheduleProvider>(
      builder: (context, provider, _) {
        final weeks = provider.availableWeeks.isNotEmpty
            ? provider.availableWeeks
            : List.generate(25, (i) => i + 1);

        final targetPage = (provider.currentWeek - 1).clamp(0, weeks.length - 1);

        // 初始化或平滑同步 PageController
        if (_weekPageController == null) {
          _weekPageController = PageController(initialPage: targetPage);
          _lastSyncedWeek = provider.currentWeek;
        } else if (_lastSyncedWeek != provider.currentWeek) {
          _lastSyncedWeek = provider.currentWeek;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted &&
                _weekPageController != null &&
                _weekPageController!.hasClients) {
              final cur = _weekPageController!.page?.round() ?? _weekPageController!.initialPage;
              if (cur != targetPage) {
                _navigateToPage(targetPage);
              }
            }
          });
        }

        // [v3.0.0-alpha20] 稳定流畅的原生 PageView.builder 配合 1D 水平高斯动态模糊：
        // 1. 100% 跟手弹性滑动 (BouncingScrollPhysics)，手指拖拽时当前周与目标周平滑跟随；
        // 2. 多设备全平台支持（触摸屏、鼠标拖拽、触控板手势）；
        // 3. 页面 settle 自动触发 provider.setCurrentWeek 与高精触觉反馈；
        // 4. Excel 冻结窗格架构：纵向滚动查看各节课程时星期胶囊固定置顶，横向滑动切周时整页联袂滑动；
        // 5. 采用恒定挂载的 PageControllerMotionBlur，彻底解决 UI 刷新冻结，同时呈现灵动切周动态模糊；
        // 6. 为各周注入唯一 KeyedSubtree(key: ValueKey<int>(week))，保证各周网格渲染树独立稳定。
        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
              PointerDeviceKind.stylus,
            },
          ),
          child: PageControllerMotionBlur(
            controller: _weekPageController!,
            maxBlur: 16.0,
            child: PageView.builder(
              controller: _weekPageController,
              itemCount: weeks.length,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              onPageChanged: (pageIndex) {
                final targetWeek = weeks[pageIndex];
                if (_isProgrammaticScroll) {
                  // 程序性切页期间忽略回写，杜绝状态竞态与跳帧
                  return;
                }
                _lastSyncedWeek = targetWeek;
                if (targetWeek != provider.currentWeek) {
                  HapticFeedback.selectionClick();
                  provider.setCurrentWeek(targetWeek);
                }
              },
              itemBuilder: (context, pageIndex) {
                final week = weeks[pageIndex];
                return KeyedSubtree(
                  key: ValueKey<int>(week),
                  child: _buildWeekGrid(context, provider, week),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _changeWeek(ScheduleProvider provider, int targetWeek) {
    final weeks = provider.availableWeeks.isNotEmpty
        ? provider.availableWeeks
        : List.generate(25, (i) => i + 1);
    final validWeek = targetWeek.clamp(weeks.first, weeks.last);
    if (validWeek != provider.currentWeek) {
      HapticFeedback.selectionClick();
      _lastSyncedWeek = validWeek;
      provider.setCurrentWeek(validWeek);
      final targetPage = (validWeek - 1).clamp(0, weeks.length - 1);
      _navigateToPage(targetPage);
    }
  }

  void _showWeekPicker(BuildContext context, ScheduleProvider provider) async {
    final weeks = provider.availableWeeks.isNotEmpty
        ? provider.availableWeeks
        : List.generate(25, (i) => i + 1);
    if (!context.mounted) return;

    final primaryColor = Theme.of(context).primaryColor;

    await showGeneralDialog(
      context: context,
      useRootNavigator: false,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 320),
      transitionBuilder: (dialogCtx, anim1, anim2, child) {
        final curved = AppCurves.spring.transform(anim1.value);
        return Transform.scale(
          scale: 0.90 + 0.10 * curved,
          child: Opacity(
            opacity: anim1.value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      pageBuilder: (dialogCtx, anim1, anim2) {
        final dialogDark = Theme.of(dialogCtx).brightness == Brightness.dark;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Material(
              type: MaterialType.transparency,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 24.0, sigmaY: 24.0),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: dialogDark
                            ? const Color(0xB8141720)
                            : const Color(0x65FFFFFF),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: dialogDark
                              ? Colors.white.withValues(alpha: 0.14)
                              : Colors.white.withValues(alpha: 0.70),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: dialogDark ? 0.35 : 0.12),
                            blurRadius: 28,
                            spreadRadius: -2,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '选择周次',
                                style: TextStyle(
                                  color: dialogDark ? Colors.white : const Color(0xFF1E2128),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SpringTouchFeedback(
                                onTap: () => Navigator.pop(dialogCtx),
                                child: Icon(
                                  CupertinoIcons.xmark_circle_fill,
                                  color: dialogDark ? Colors.white38 : Colors.black26,
                                  size: 22,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 280),
                            child: GridView.builder(
                              shrinkWrap: true,
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 5,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                childAspectRatio: 1.3,
                              ),
                              itemCount: weeks.length,
                              itemBuilder: (context, index) {
                                final w = weeks[index];
                                final isCur = w == provider.currentWeek;
                                return SpringTouchFeedback(
                                  onTap: () {
                                    _changeWeek(provider, w);
                                    Navigator.pop(dialogCtx);
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isCur
                                          ? primaryColor.withValues(alpha: dialogDark ? 0.85 : 0.90)
                                          : (dialogDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
                                      borderRadius: SquircleGeometry.smoothRadius(12),
                                      border: Border.all(
                                        color: isCur
                                            ? primaryColor.withValues(alpha: 0.3)
                                            : (dialogDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.06)),
                                        width: 0.8,
                                      ),
                                      boxShadow: isCur
                                          ? [
                                              BoxShadow(
                                                color: primaryColor.withValues(alpha: 0.35),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '第$w周',
                                      style: TextStyle(
                                        color: isCur
                                            ? Colors.white
                                            : (dialogDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF2D3139)),
                                        fontWeight: isCur ? FontWeight.bold : FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWeekControl(BuildContext context, ScheduleProvider provider, {required int week}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SpringTouchFeedback(
            onTap: () => _changeWeek(provider, week - 1),
            child: GlassButton.custom(
              onTap: () => _changeWeek(provider, week - 1),
              width: 88,
              height: 38,
              style: GlassButtonStyle.filled,
              settings: LiquidGlassSettings(
                glassColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.35),
                blur: 0.5,
                thickness: 14,
                lightIntensity: 0.35,
                ambientStrength: 0.20,
                ambientRim: 0.0,
                fresnelStrength: 0.0,
                edgeAbsorption: 0.06,
              ),
              shape: const LiquidRoundedSuperellipse(borderRadius: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.left_chevron, color: isDark ? Colors.white70 : const Color(0xFF1E2128), size: 14),
                  const SizedBox(width: 4),
                  Text('上一周', style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF1E2128), fontSize: 12)),
                ],
              ),
            ),
          ),
          SpringTouchFeedback(
            onTap: () => _showWeekPicker(context, provider),
            child: GlassContainer(
              useOwnLayer: true,
              shape: const LiquidRoundedSuperellipse(borderRadius: 14),
              settings: LiquidGlassSettings(
                glassColor: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.35),
                blur: 0.5,
                thickness: 16.0,
                refractiveIndex: 1.40,
                lightIntensity: 0.35,
                ambientStrength: 0.20,
                ambientRim: 0.0,
                fresnelStrength: 0.0,
                edgeAbsorption: 0.06,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '第 $week 周',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF1E2128),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      CupertinoIcons.chevron_down,
                      color: isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF555B68),
                      size: 13,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SpringTouchFeedback(
            onTap: () => _changeWeek(provider, week + 1),
            child: GlassButton.custom(
              onTap: () => _changeWeek(provider, week + 1),
              width: 88,
              height: 38,
              style: GlassButtonStyle.filled,
              settings: LiquidGlassSettings(
                glassColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.35),
                blur: 0.5,
                thickness: 14,
                lightIntensity: 0.35,
                ambientStrength: 0.20,
                ambientRim: 0.0,
                fresnelStrength: 0.0,
                edgeAbsorption: 0.06,
              ),
              shape: const LiquidRoundedSuperellipse(borderRadius: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('下一周', style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF1E2128), fontSize: 12)),
                  const SizedBox(width: 4),
                  Icon(CupertinoIcons.right_chevron, color: isDark ? Colors.white70 : const Color(0xFF1E2128), size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _getSectionForTime(
    int timestamp,
    ScheduleConfigModel config, {
    bool isEnd = false,
  }) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final totalMinutes = dt.hour * 60 + dt.minute;

    // [v2.9.0 修复] 严格按时段范围限制候选节次，彻底杜绝跨午休/跨晚饭吸附
    int minSec = 1;
    int maxSec = 13;
    if (totalMinutes < 12 * 60 + 30) {
      minSec = 1;
      maxSec = 4;
    } else if (totalMinutes < 17 * 60 + 45) {
      minSec = 5;
      maxSec = 8;
    } else {
      minSec = 9;
      maxSec = 13;
    }

    int bestSection = minSec;
    int minDiff = 10000;

    for (var entry in config.sectionStartTimes.entries) {
      if (entry.key < minSec || entry.key > maxSec) continue;
      int sectionMin = entry.value;
      if (isEnd) {
        int duration = config.isEqualDuration
            ? config.defaultDuration
            : (config.sectionDurations[entry.key] ?? config.defaultDuration);
        sectionMin += duration;
      }

      int diff = (sectionMin - totalMinutes).abs();
      if (diff < minDiff) {
        minDiff = diff;
        bestSection = entry.key;
      }
    }
    return bestSection;
  }

  /// [v2.9.3] 7 天或 5 天全景课程网格（Excel 冻结窗格架构：星期行固定置顶，课程卡片与参考线从底部穿过）
  Widget _buildWeekGrid(BuildContext context, ScheduleProvider provider, int week) {
    final showWeekends = provider.currentConfig.showWeekends;
    final int daysCount = showWeekends ? 7 : 5;
    final config = provider.currentConfig;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLandscape = ResponsiveUtils.isLandscape(context) ||
        ResponsiveUtils.isDesktopOrLandscape(context);
    final timeColWidth = isLandscape ? (widget.isPhone ? 56.0 : 60.0) : (widget.isPhone ? 32.0 : 38.0);
    const headerHeight = 54.0;
    const controlBarHeight = 46.0;
    final resolvedPadding = widget.contentPadding.resolve(Directionality.of(context));
    final topPadding = resolvedPadding.top;

    // [v3.0.0] 无论是否开启周次控制栏，均作为悬浮层置于 Stack 顶层，课程卡片从其下方平滑穿过，彻底告别硬截断
    final weekdayTop = widget.showControlBar ? (topPadding + controlBarHeight + 6) : (topPadding + 2);
    final contentTop = widget.showControlBar
        ? (topPadding + controlBarHeight + 6 + headerHeight + 6)
        : (topPadding + headerHeight + 6);

    return Stack(
      children: [
        // 1. 纵向滚动内容区：全屏铺满，直接浮于高清壁纸之上，从悬浮星期胶囊与控制栏下方平滑穿过，不截断卡片
        Positioned.fill(
          child: DynMouseScroll(
            durationMS: 250,
            scrollSpeed: 1.2,
            builder: (context, controller, physics) => SingleChildScrollView(
              controller: controller,
              physics: physics,
              clipBehavior: Clip.none, // 平滑穿透悬浮胶囊与周次控制栏，零生硬裁剪
              padding: EdgeInsets.only(
                top: contentTop,
                bottom: resolvedPadding.bottom,
                left: resolvedPadding.left,
                right: resolvedPadding.right,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 左侧时间轴 (1~13 节课，直接对齐课程网格)
                  SizedBox(
                    width: timeColWidth,
                    child: Column(
                      children: List.generate(kTotalSections, (i) {
                        final section = i + 1;
                        final startMin = config.sectionStartTimes[section] ?? (480 + (i < 5 ? i * 50 : 360 + i * 50));
                        final hour = (startMin ~/ 60).toString().padLeft(2, '0');
                        final min = (startMin % 60).toString().padLeft(2, '0');
                        final timeStr = '$hour:$min';

                        return SizedBox(
                          height: kSectionRowHeight,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$section',
                                style: TextStyle(
                                  color: isDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF2D3139),
                                  fontSize: widget.isPhone ? 11 : 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                timeStr,
                                style: TextStyle(
                                  color: isDark ? Colors.white.withValues(alpha: 0.45) : const Color(0xFF7A808C),
                                  fontSize: widget.isPhone ? 8.5 : 9.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),

                  // 周一至周日各列的课程网格
                  ...List.generate(daysCount, (dayIndex) {
                    final day = dayIndex + 1;
                    final courses = provider.getCoursesForDayAndWeek(day, week);

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.5),
                        child: _buildDayGridStack(context, day, courses, provider, isDark, week: week),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),

        // 2. [v3.0.0] 悬浮星期行（周一~周日独立微乳胶囊，悬浮于各列上方，对齐列宽，不作为截断表格头）
        Positioned(
          top: weekdayTop,
          left: resolvedPadding.left,
          right: resolvedPadding.right,
          height: headerHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // [v3.0.0-alpha25] 竖屏时已有顶部大标题栏，仅放置空白占位对齐节次列；
                // 横屏时展示加长微缩悬浮玻璃日期胶囊（10月10日 周六），排版与比例更协调舒展
                if (isLandscape)
                  _buildCornerDateBadge(context, isDark, timeColWidth)
                else
                  SizedBox(width: timeColWidth),
                // 周一至周日标题列独立悬浮胶囊
                ...List.generate(daysCount, (dayIndex) {
                  final day = dayIndex + 1;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: _buildDayHeaderCell(context, day, provider, isDark, week: week),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),


        // 3. [v3.0.0] 悬浮周次切换与指示控制栏（置于悬浮星期行上方，支持上一周/周次菜单/下一周）
        if (widget.showControlBar)
          Positioned(
            top: topPadding + 2,
            left: resolvedPadding.left,
            right: resolvedPadding.right,
            height: controlBarHeight,
            child: _buildWeekControl(context, provider, week: week),
          ),
      ],
    );
  }

  /// [v3.0.0-alpha23/alpha25] 横屏左上角节次列与星期栏交界处的加长悬浮玻璃日期指示胶囊（10月10日 周六）
  Widget _buildCornerDateBadge(
    BuildContext context,
    bool isDark,
    double width,
  ) {
    final now = DateTime.now();
    const weekdays = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      width: width,
      height: 44,
      margin: const EdgeInsets.only(right: 3.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: GlassContainer(
        useOwnLayer: true,
        quality: theme.ThemeService().glassQuality,
        shape: const LiquidRoundedSuperellipse(borderRadius: 13),
        settings: LiquidGlassSettings(
          glassColor: isDark
              ? const Color(0x2812151B)
              : const Color(0x35FFFFFF),
          blur: 0.5,
          thickness: 16.0,
          refractiveIndex: 1.44,
          lightIntensity: 0.70,
          ambientStrength: 0.35,
          ambientRim: 0.0,
          fresnelStrength: 0.0,
          edgeAbsorption: 0.10,
          saturation: 1.15,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${now.month}月${now.day}日',
                style: TextStyle(
                  fontSize: 10.0,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF2D3139),
                  height: 1.1,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                weekdays[now.weekday],
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 单日星期标题胶囊（固定在冻结栏中）
  Widget _buildDayHeaderCell(
    BuildContext context,
    int day,
    ScheduleProvider provider,
    bool isDark, {
    required int week,
  }) {
    final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final semesterStart = provider.semesterStartDate;
    final weekOffset = (week - 1) * 7;
    final semesterStartDateOnly = DateTime(semesterStart.year, semesterStart.month, semesterStart.day);
    final firstMonday = semesterStartDateOnly.subtract(Duration(days: semesterStartDateOnly.weekday - 1));
    final dayDate = firstMonday.add(Duration(days: weekOffset + day - 1));
    final dateLabel = '${dayDate.month}/${dayDate.day}';

    final now = DateTime.now();
    final isToday = now.year == dayDate.year &&
        now.month == dayDate.month &&
        now.day == dayDate.day;

    return Container(
      height: 44,
      width: double.infinity,
      decoration: isToday
          ? BoxDecoration(
              color: AppThemeColors.babyPink.withValues(alpha: isDark ? 0.28 : 0.18),
              borderRadius: BorderRadius.circular(10),
              boxShadow: liquid.HyperOSShadows.pill(isDark, accentColor: AppThemeColors.babyPink),
            )
          : null, // 非今日：纯净无边框透明，彻底摒弃厚重卡片盒子堆叠
      child: widget.isPhone
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  weekdays[day - 1],
                  style: TextStyle(
                    color: isToday
                        ? (isDark ? AppThemeColors.babyPink : const Color(0xFFC84B66))
                        : (isDark ? Colors.white60 : const Color(0xFF6B7280)),
                    fontSize: 11.5,
                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 1.5),
                Text(
                  '${dayDate.day}',
                  style: TextStyle(
                    color: isToday
                        ? (isDark ? AppThemeColors.babyPink : const Color(0xFFC84B66))
                        : (isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF1F2228)),
                    fontSize: 12.0,
                    fontWeight: isToday ? FontWeight.w900 : FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  weekdays[day - 1],
                  style: TextStyle(
                    color: isToday
                        ? AppThemeColors.babyPink
                        : (isDark ? Colors.white70 : const Color(0xFF6B7280)),
                    fontSize: 13,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  dateLabel,
                  style: TextStyle(
                    color: isToday
                        ? AppThemeColors.babyPink
                        : (isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF1F2228)),
                    fontSize: 11.5,
                    fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }

  /// 单日课程网格 Stack（横向辅助线 + 课程卡片）
  Widget _buildDayGridStack(
    BuildContext context,
    int day,
    List<CourseEvent> courses,
    ScheduleProvider provider,
    bool isDark, {
    required int week,
  }) {
    return SizedBox(
      height: kTotalSections * kSectionRowHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 浅色参考辅助横线
          ...List.generate(kTotalSections, (i) {
            return Positioned(
              top: (i + 1) * kSectionRowHeight - 1,
              left: 0,
              right: 0,
              child: Container(
                height: 0.6,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.03),
              ),
            );
          }),

          // 实际课程卡片
          ...courses.map((course) {
            final config = provider.currentConfig;
            int start = course.startSection ?? _getSectionForTime(course.startTime, config);
            int end = course.endSection ?? _getSectionForTime(
              course.endTime,
              config,
              isEnd: true,
            );

            // [v2.9.0 修复] 严格禁止单卡片跨越午休（4->5）与跨越晚餐（8->9）
            if (start <= 4) {
              end = end.clamp(start, 4);
            } else if (start <= 8) {
              end = end.clamp(start, 8);
            } else {
              end = end.clamp(start, 13);
            }

            final finalStart = start > 0 ? start : 1;
            final finalEnd = end >= finalStart ? end : finalStart;

            final topOffset = (finalStart - 1) * kSectionRowHeight;
            final courseHeight =
                (finalEnd - finalStart + 1) * kSectionRowHeight - 2.0;

            return Positioned(
              key: ValueKey('pos_w${week}_${course.id ?? course.name}_${course.startTime}'),
              top: topOffset,
              left: 0,
              right: 0,
              height: courseHeight,
              child: _buildCourseCard(context, course, isDark, week),
            );
          }),
        ],
      ),
    );
  }

  /// 课程卡片：整卡染色 (CourseColorPalette) + 柔和通透质感 + 底部三点小横条 Morph Engine
  Widget _buildCourseCard(BuildContext context, CourseEvent course, bool isDark, int currentWeek) {
    final cardBgColor = CourseColorPalette.getCardColor(course.name, isDark);
    final titleColor = CourseColorPalette.getTitleTextColor(course.name, isDark);
    final subTextColor = CourseColorPalette.getSubTextColor(course.name, isDark);
    final glowColor = CourseColorPalette.getCardGlowShadow(course.name, isDark);
    final hasLocation = course.location.trim().isNotEmpty &&
        !course.location.contains('未知') &&
        !course.location.contains('未指定');

    return liquid.HyperOSCard(
      key: ValueKey('card_w${currentWeek}_${course.id ?? course.name}_${course.startTime}'),
      useBlur: true, // [v3.0.0] 共享单次静态全屏高斯模糊双线性采样，零 FBO 离屏开销，极高质量磨砂质感
      cornerRadius: widget.isPhone ? 16 : 18,
      padding: EdgeInsets.all(widget.isPhone ? 6.0 : 8.0),
      color: cardBgColor,
      contentColor: titleColor,
      shadows: liquid.HyperOSShadows.card(isDark, glowColor: glowColor),
      // [v2.9.0] 移除主体直接展开详情，避免与底部三点操作条冲突
      onTap: null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // [v2.9.5] 课程名称：自然语义智能排版（中英文换行、中文词组保持完整），留出边缘安全距离
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                CourseNameFormatter.format(course.name, isPhone: widget.isPhone),
                style: TextStyle(
                  color: titleColor,
                  fontSize: widget.isPhone ? 12.0 : 13.5,
                  fontWeight: FontWeight.bold,
                  height: 1.16,
                ),
                maxLines: widget.isPhone ? 5 : 6,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Spacer(),

            // [v2.9.5] 老师与地点：字号加大至 11.0pt（清晰易读杜绝过小），若无教室则直接留空
            if (course.teacher.isNotEmpty || hasLocation) ...[
              if (course.teacher.isNotEmpty)
                Text(
                  course.teacher,
                  style: TextStyle(
                    color: subTextColor,
                    fontSize: widget.isPhone ? 11.0 : 12.0,
                    fontWeight: FontWeight.w600,
                    height: 1.20,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              if (hasLocation)
                Text(
                  course.location,
                  style: TextStyle(
                    color: subTextColor,
                    fontSize: widget.isPhone ? 11.0 : 12.0,
                    fontWeight: FontWeight.w600,
                    height: 1.20,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],

            // [v2.9.6] 底部三点横条：加大至 15.0pt 高度、46.0pt 宽度、3.8pt 圆点，留出充足安全距离
            Center(
              child: GlassContextMenu(
                menuWidth: 170,
                menuAlignment: GlassMenuAlignment.none,
                items: [
                  GlassContextMenuItem(
                    title: '课程详情',
                    icon: CupertinoIcons.info,
                    onTap: () => _showCourseDetail(context, course),
                  ),
                  GlassContextMenuItem(
                    title: '编辑课程',
                    icon: CupertinoIcons.pencil,
                    onTap: () {
                      Navigator.push(
                        context,
                        TransparentMaterialPageRoute(
                          builder: (_) => CourseEditScreen(course: course),
                        ),
                      );
                    },
                  ),
                  GlassContextMenuItem(
                    title: '删除课程',
                    icon: CupertinoIcons.trash,
                    isDestructive: true,
                    onTap: () {
                      GlassDialog.show(
                        context: context,
                        title: '删除课程',
                        message: '确定要删除课程「${course.name}」吗？此操作不可撤销。',
                        actions: [
                          GlassDialogAction(
                            label: '取消',
                            onPressed: () => Navigator.pop(context, false),
                          ),
                          GlassDialogAction(
                            label: '删除',
                            isDestructive: true,
                            onPressed: () => Navigator.pop(context, true),
                          ),
                        ],
                      ).then((confirmed) async {
                        if (confirmed == true && context.mounted) {
                          final provider = Provider.of<ScheduleProvider>(context, listen: false);
                          await provider.deleteCourse(course);
                          if (context.mounted) {
                            liquid.showLiquidToast(context, '已删除课程: ${course.name}');
                          }
                        }
                      });
                    },
                  ),
                ],
                trigger: Container(
                  height: widget.isPhone ? 16.0 : 18.0,
                  width: widget.isPhone ? 46.0 : 50.0,
                  margin: const EdgeInsets.only(top: 4, bottom: 2),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: isDark ? 0.18 : 0.09),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.more_horiz_rounded,
                    size: widget.isPhone ? 16.0 : 18.0,
                    color: subTextColor.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ),
          ],
        ),
    );
  }

  /// 官方 Liquid Glass 风格课程详情底板（离屏冻结背景加速，BackdropFilter 确保课表网格清晰微透）
  void _showCourseDetail(BuildContext context, CourseEvent course) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1A1A2E);

    _isBackgroundFrozen.value = true;
    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.35),
        useRootNavigator: true,
        builder: (sheetContext) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24.0, sigmaY: 24.0),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xD9161922)
                    : const Color(0xE6FFFFFF),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.85),
                    width: 1.0,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 38,
                          height: 4.5,
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        course.name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDetailRow(sheetContext, '时间', course.timeStr),
                      const SizedBox(height: 10),
                      _buildDetailRow(
                        sheetContext,
                        '地点',
                        (course.location.isEmpty || course.location.contains('未知'))
                            ? '未指定地点'
                            : course.location,
                      ),
                      const SizedBox(height: 10),
                      _buildDetailRow(
                        sheetContext,
                        '教师',
                        course.teacher.isEmpty ? '未指定教师' : course.teacher,
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: SpringTouchFeedback(
                              onTap: () {
                                Navigator.pop(sheetContext);
                                Navigator.push(
                                  context,
                                  TransparentMaterialPageRoute(
                                    builder: (_) => CourseEditScreen(course: course),
                                  ),
                                );
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
                                  child: Container(
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: AppThemeColors.babyPink.withValues(alpha: 0.82),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.35),
                                        width: 1.0,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      '编辑课程',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SpringTouchFeedback(
                            onTap: () => Navigator.pop(sheetContext),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
                                child: Container(
                                  width: 88,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.12)
                                        : Colors.black.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.15)
                                          : Colors.black.withValues(alpha: 0.08),
                                      width: 0.8,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '关闭',
                                    style: TextStyle(
                                      color: isDark ? Colors.white70 : const Color(0xFF1E2128),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        _isBackgroundFrozen.value = false;
      }
    }
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 50,
          child: Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF6B7280),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1E2128),
            ),
          ),
        ),
      ],
    );
  }
}
