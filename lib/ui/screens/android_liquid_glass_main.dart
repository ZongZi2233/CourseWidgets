import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../providers/schedule_provider.dart';
import '../../constants/version.dart';
import '../../constants/theme_constants.dart';
import '../../services/live_notification_service_v2.dart';
import '../../services/data_import_service.dart';
import '../../models/course_event.dart';
import '../../models/schedule_config.dart';
import '../../utils/responsive_utils.dart';
import '../../main.dart' hide globalUseDarkMode; // [v2.6.0] 引用全局 routeObserver
import 'course_edit_screen.dart';
import 'calendar_view_screen.dart';
import 'settings_main_screen.dart';
import 'android_schedule_config_screen.dart';
import '../widgets/liquid_components.dart' as liquid;
import '../transitions/smooth_slide_transitions.dart';
import '../widgets/glass_context_menu.dart';
import '../widgets/tablet_sidebar.dart';
import '../widgets/weekly_schedule_grid.dart';
class AndroidLiquidGlassMain extends StatefulWidget {
  const AndroidLiquidGlassMain({super.key});
  @override
  State<AndroidLiquidGlassMain> createState() => _AndroidLiquidGlassMainState();
}

class _AndroidLiquidGlassMainState extends State<AndroidLiquidGlassMain>
    with RouteAware {
  int _currentIndex = 0;
  late final PageController _pageController = PageController();
  bool _isBottomNavVisible = true;
  final ValueNotifier<bool> _isBackgroundFrozen = ValueNotifier<bool>(false);
  final DataImportService _importService = DataImportService();

  void _onTabSelected(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 注册路由监听
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }


  // [v2.8.9/v2.10.3] 被其他页面覆盖时：冻结底层课表动画并隐藏底栏，二级页面转场满帧 120 FPS
  @override
  void didPushNext() {
    if (mounted) {
      _isBackgroundFrozen.value = true;
      setState(() {
        _isBottomNavVisible = false;
      });
    }
  }

  // [v2.8.9/v2.10.3] 上一层页面弹出：平滑解冻课表并恢复底部导航栏
  @override
  void didPopNext() {
    if (mounted) {
      _isBackgroundFrozen.value = false;
      setState(() {
        _isBottomNavVisible = true;
      });
    }
  }

  ScheduleProvider? _scheduleProvider;

  void _onScheduleChanged() {
    if (!mounted || _scheduleProvider == null) return;
    final nextCourse = _scheduleProvider!.getCurrentOrNextCourse();
    LiveNotificationServiceV2().updateCourses(_scheduleProvider!.courses, nextCourse: nextCourse);
  }

  Future<void> _loadData() async {
    try {
      _scheduleProvider = context.read<ScheduleProvider>();
      _scheduleProvider?.removeListener(_onScheduleChanged);
      _scheduleProvider?.addListener(_onScheduleChanged);
      await _scheduleProvider!.loadSavedData();

      // 初始化 Android 16 Live Updates 通知服务
      final liveService = LiveNotificationServiceV2();
      await liveService.initialize();

      // 设置通知点击回调 - 跳转到课程页面
      liveService.setOnNotificationTapCallback((course) {
        if (mounted) {
          _onTabSelected(0);
        }
      });

      // [v2.8.5] 获取当前或下一节课并启动全天候实时常驻通知（智能日程计算与微缩胶囊）
      final nextCourse = _scheduleProvider!.getCurrentOrNextCourse();
      await liveService.startLiveUpdate(nextCourse, allCourses: _scheduleProvider!.courses);

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('❌ 加载数据失败: $e');
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this); // [v2.6.0] 卸载路由监听
    _isBackgroundFrozen.dispose();
    _scheduleProvider?.removeListener(_onScheduleChanged);
    _pageController.dispose();
    // 停止通知服务
    LiveNotificationServiceV2().dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // [v2.8.5 彻底消灭启动黑屏与白屏停滞] 立即绘制主界面布局，数据异步装载完毕后自动驱动刷新

    final isTablet = ResponsiveUtils.isTabletMode(context);
    final Widget rootLayout = isTablet
        ? _buildTabletLayout(context)
        : _buildPhoneLayout(context);

    // [v2.9.0] 彻底关闭陀螺仪持续重绘，提供丝滑稳定 120 FPS
    return GlassMotionScope(
      child: rootLayout,
    );
  }

  /// 平板布局
  Widget _buildTabletLayout(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, // [v2.8.6] 软键盘弹出时防止底层背景与冻结快照被压缩或上移漂移
      backgroundColor: Colors.transparent,
      body: Row(
        children: [
          // 左侧导航栏
          TabletSideBar(
            selectedIndex: _currentIndex,
            onTabSelected: (index) {
              HapticFeedback.selectionClick();
              _onTabSelected(index);
            },
            items: const [
              TabletSideBarItem(
                icon: CupertinoIcons.square_grid_2x2,
                selectedIcon: CupertinoIcons.square_grid_2x2_fill,
                label: '课程',
              ),
              TabletSideBarItem(
                icon: CupertinoIcons.calendar,
                selectedIcon: CupertinoIcons.calendar_today,
                label: '日历',
              ),
              TabletSideBarItem(
                icon: CupertinoIcons.gear_alt,
                selectedIcon: CupertinoIcons.gear_alt_fill,
                label: '设置',
              ),
            ],
          ),

          // 右侧内容区
          Expanded(
            child: RepaintBoundary(
              key: TransparentMaterialPageRoute.contentBoundaryKey,
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  TickerMode(
                    enabled: _currentIndex == 0,
                    child: RepaintBoundary(
                      child: _buildTabletSchedulePage(),
                    ),
                  ),
                  TickerMode(
                    enabled: _currentIndex == 1,
                    child: const RepaintBoundary(
                      child: CalendarViewScreen(),
                    ),
                  ),
                  TickerMode(
                    enabled: _currentIndex == 2,
                    child: const RepaintBoundary(
                      child: SettingsMainScreen(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 手机布局
  Widget _buildPhoneLayout(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, // [v2.8.6] 软键盘弹出时防止底层背景被压缩或上移漂移
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: RepaintBoundary(
        key: TransparentMaterialPageRoute.contentBoundaryKey,
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            TickerMode(
              enabled: _currentIndex == 0,
              child: RepaintBoundary(
                child: _buildSchedulePage(),
              ),
            ),
            TickerMode(
              enabled: _currentIndex == 1,
              child: const RepaintBoundary(
                child: CalendarViewScreen(),
              ),
            ),
            TickerMode(
              enabled: _currentIndex == 2,
              child: RepaintBoundary(
                child: _buildPageWithHeader(2, const SettingsMainScreen(), '设置'),
              ),
            ),
          ],
        ),
      ),
      // 官方原生旗舰 GlassTabBar.bottom 专用导航栏
      bottomNavigationBar: SafeArea(
        bottom: true,
        top: false,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          offset: _isBottomNavVisible ? Offset.zero : const Offset(0, 1.2),
          child: RepaintBoundary(
            child: GlassTabBar.bottom(
              selectedIndex: _currentIndex,
              onTabSelected: (index) {
                HapticFeedback.selectionClick();
                _onTabSelected(index);
              },
              quality: GlassQuality.premium,
              maskingQuality: MaskingQuality.high,
              barBorderRadius: 999.0,
              indicatorBorderRadius: 999.0,
              adaptiveBrightness: false, // [v2.8.9] 禁用实时纹理反读消除卡顿，保持流畅 120 FPS
              barHeight: 64.0,
              horizontalPadding: 16.0,
              verticalPadding: 8.0,
              magnification: 1.12,
              interactionBehavior: GlassInteractionBehavior.full,
              settings: const LiquidGlassSettings(
                thickness: 24.0,
                blur: 4.0,
                chromaticAberration: 0.15,
                lightIntensity: 0.70,
                refractiveIndex: 1.46,
                saturation: 1.20,
                ambientStrength: 0.45,
                ambientRim: 0.0,
                fresnelStrength: 0.05,
                glassColor: Color(0x18FFFFFF),
              ),
              // [v2.8.4] 遵循官方演示：采用 100% 纯澈透光的物理凸透镜滑块（blur: 0，无任何高斯模糊浑浊感）
              indicatorSettings: AnimatedGlassIndicator.baseIndicatorSettings,
              tabs: const [
                GlassTab(
                  icon: Icon(CupertinoIcons.square_grid_2x2),
                  activeIcon: Icon(CupertinoIcons.square_grid_2x2_fill),
                  label: '课程',
                ),
                GlassTab(
                  icon: Icon(CupertinoIcons.calendar),
                  activeIcon: Icon(CupertinoIcons.calendar_today),
                  label: '日历',
                ),
                GlassTab(
                  icon: Icon(CupertinoIcons.gear_alt),
                  activeIcon: Icon(CupertinoIcons.gear_alt_fill),
                  label: '设置',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 手机端单页面动态渲染，彻底杜绝多页面在 GPU 着色器中叠加
  Widget _buildCurrentPhonePage() {
    switch (_currentIndex) {
      case 0:
        return _buildSchedulePage();
      case 1:
        return const CalendarViewScreen();
      case 2:
        return _buildPageWithHeader(2, const SettingsMainScreen(), '设置');
      default:
        return _buildSchedulePage();
    }
  }

  /// 平板端单页面动态渲染
  Widget _buildCurrentTabletPage() {
    switch (_currentIndex) {
      case 0:
        return _buildTabletSchedulePage();
      case 1:
        return const CalendarViewScreen();
      case 2:
        return const SettingsMainScreen();
      default:
        return _buildTabletSchedulePage();
    }
  }

  /// 平板模式的课程页面（本周网格视图）
  Widget _buildTabletSchedulePage() {
    return const SafeArea(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: WeeklyScheduleGrid(),
      ),
    );
  }

  /// 优雅的次级页面顶部包裹栏（日历、设置）
  Widget _buildPageWithHeader(int index, Widget child, String title) {
    return Stack(
      children: [
        Positioned.fill(
          child: child,
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: GlassContainer(
                  useOwnLayer: true,
                  quality: GlassQuality.premium,
                  shape: const LiquidRoundedSuperellipse(borderRadius: 20),
                  settings: const LiquidGlassSettings(
                    glassColor: Color(0x12FFFFFF),
                    blur: 2.5,
                    thickness: 20.0,
                    refractiveIndex: 1.45,
                    lightIntensity: 0.70,
                    ambientStrength: 0.45,
                    ambientRim: 0.0,
                    fresnelStrength: 0.05,
                    saturation: 1.20,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    child: Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const Spacer(),
                        liquid.LiquidCard(
                          borderRadius: 10,
                          padding: 5,
                          styleType: liquid.LiquidStyleType.micro,
                          quality: GlassQuality.standard,
                          child: Text(
                            'v$appVersion',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
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
      ],
    );
  }

  /// [v2.8.9] 重构手机端主课表页面：全周看板网格贯通上下滑动，穿透悬浮标题栏与底栏
  Widget _buildSchedulePage() {
    return AdaptiveLiquidGlassLayer(
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
      child: Consumer<ScheduleProvider>(
        builder: (context, provider, _) {
          // [v2.9.7 星期栏抬高接近顶栏] 顶部安全留白调整至 top + 54，布局更紧致
          final topPadding = MediaQuery.of(context).padding.top + 54;
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Stack(
            children: [
              // 课程网格本周看板：全屏铺满，上下纵向滚动，平滑穿过顶栏与底栏
              // [v2.9.6] 课程网格本周看板：支持背景控件离屏冻结优化，全周贯通穿透
              Positioned.fill(
                child: ValueListenableBuilder<bool>(
                  valueListenable: _isBackgroundFrozen,
                  builder: (context, isFrozen, child) {
                    return RepaintBoundary(
                      child: IgnorePointer(
                        ignoring: isFrozen,
                        child: TickerMode(
                          enabled: !isFrozen,
                          child: child!,
                        ),
                      ),
                    );
                  },
                  child: WeeklyScheduleGrid(
                    key: ValueKey('weekly_grid_${provider.currentWeek}'),
                    showControlBar: false,
                    isPhone: true,
                    contentPadding: EdgeInsets.only(
                      top: topPadding,
                      bottom: 186, // [v2.9.7] 为进一步抬高的浮动胶囊 Dock 留出安全滚动距离
                      left: 2,
                      right: 2,
                    ),
                  ),
                ),
              ),

              // [v2.9.7] 课表网格进入屏幕顶底边缘的渐进柔和渐变过渡带
              Positioned(
                top: topPadding + 54.0, // 紧跟星期栏下方
                left: 0,
                right: 0,
                height: 18,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          (isDark ? const Color(0x55101216) : Colors.white.withValues(alpha: 0.30)),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 64, // 导航栏上方
                left: 0,
                right: 0,
                height: 56,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          (isDark ? Colors.black.withValues(alpha: 0.28) : Colors.white.withValues(alpha: 0.25)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 顶部悬浮标题栏：轻量品牌与日期指示，独立 RepaintBoundary 缓存
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                    child: RepaintBoundary(
                      child: _buildModernTopBar(provider),
                    ),
                  ),
                ),
              ),

              // [v2.9.7] 底部悬浮横向胶囊控制 Dock：抬高至 bottom: 120，靠右对齐放置与底栏保持舒适距离
              Positioned(
                bottom: 120,
                right: 16,
                child: RepaintBoundary(
                  child: _buildFloatingBottomActionDock(provider),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 现代晶透顶部栏：精简为品牌 Logo 与当前日期指示，腾出顶部空间
  Widget _buildModernTopBar(ScheduleProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    const weekDays = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final dateStr = '${now.month}月${now.day}日 ${weekDays[now.weekday]}';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: GlassContainer(
        useOwnLayer: true,
        quality: GlassQuality.premium,
        shape: const LiquidRoundedSuperellipse(borderRadius: 18),
        settings: LiquidGlassSettings(
          glassColor: isDark ? const Color(0x1812151B) : const Color(0x18FFFFFF),
          blur: 3.5,
          thickness: 18.0,
          refractiveIndex: 1.44,
          lightIntensity: 0.70,
          ambientStrength: 0.45,
          ambientRim: 0.0,
          fresnelStrength: 0.05,
          saturation: 1.20,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            children: [
              Icon(
                CupertinoIcons.book_fill,
                color: AppThemeColors.babyPink,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                "CourseWidgets",
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1E2128),
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              // 当前日期指示徽章
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0x30000000) : const Color(0x12000000),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.calendar,
                      size: 12,
                      color: isDark ? Colors.white70 : const Color(0xFF555B68),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      dateStr,
                      style: TextStyle(
                        color: isDark ? Colors.white70 : const Color(0xFF333842),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  /// [v2.9.6] 底部悬浮横向胶囊控制 Dock：靠右布局，加深同系色描边，杜绝任何黑描边
  /// 布局：（（+）（＜）（第 X 周 ▾）（＞）（…））
  Widget _buildFloatingBottomActionDock(ScheduleProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final weeks = provider.availableWeeks;
    final canPrev = weeks.isNotEmpty && provider.currentWeek > weeks.first;
    final canNext = weeks.isNotEmpty && provider.currentWeek < weeks.last;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.14),
            blurRadius: 18,
            spreadRadius: 1,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: GlassContainer(
        useOwnLayer: true,
        quality: GlassQuality.premium,
        shape: const LiquidRoundedSuperellipse(borderRadius: 26),
        settings: LiquidGlassSettings(
          glassColor: isDark
              ? const Color(0x35101216)
              : const Color(0x30FFFFFF),
          blur: 5.0,
          thickness: 20.0,
          refractiveIndex: 1.45,
          lightIntensity: 0.75,
          ambientStrength: 0.45,
          ambientRim: 0.0,
          fresnelStrength: 0.06,
          edgeAbsorption: 0.0,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. (+) 添加课程按钮
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.push(
                    context,
                    TransparentMaterialPageRoute(
                      builder: (_) => const CourseEditScreen(),
                    ),
                  );
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppThemeColors.babyPink.withValues(alpha: isDark ? 0.25 : 0.18),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFFE56A85).withValues(alpha: isDark ? 0.55 : 0.40),
                      width: 1.0,
                    ),
                  ),
                  child: Icon(
                    CupertinoIcons.add,
                    size: 16,
                    color: isDark ? Colors.white : AppThemeColors.babyPink,
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // 2. (＜) 上一周按钮（加深同系色描边，无黑边）
              GestureDetector(
                onTap: canPrev
                    ? () {
                        HapticFeedback.selectionClick();
                        provider.setCurrentWeek(provider.currentWeek - 1);
                      }
                    : null,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: canPrev ? 0.10 : 0.04)
                        : (canPrev ? const Color(0xFFEFF1F5) : const Color(0xFFF7F8FA)),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark
                          ? (canPrev ? const Color(0x40000000) : const Color(0x18000000))
                          : (canPrev ? const Color(0xFFCDD3DE) : const Color(0xFFE4E7ED)),
                      width: 0.9,
                    ),
                  ),
                  child: Icon(
                    CupertinoIcons.chevron_left,
                    size: 15,
                    color: canPrev
                        ? (isDark ? Colors.white : const Color(0xFF1E2128))
                        : (isDark ? Colors.white24 : Colors.black26),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // 3. (第 X 周 ▾) 核心选择胶囊（加深柔粉描边）
              GestureDetector(
                onTap: () => _showWeekPickerSheet(context, provider),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppThemeColors.babyPink.withValues(alpha: isDark ? 0.26 : 0.18),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFFE56A85).withValues(alpha: isDark ? 0.55 : 0.42),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '第 ${provider.currentWeek} 周',
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF1E2128),
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        CupertinoIcons.chevron_down,
                        size: 11,
                        color: isDark ? Colors.white70 : const Color(0xFF555B68),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // 4. (＞) 下一周按钮（加深同系色描边，无黑边）
              GestureDetector(
                onTap: canNext
                    ? () {
                        HapticFeedback.selectionClick();
                        provider.setCurrentWeek(provider.currentWeek + 1);
                      }
                    : null,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: canNext ? 0.10 : 0.04)
                        : (canNext ? const Color(0xFFEFF1F5) : const Color(0xFFF7F8FA)),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark
                          ? (canNext ? const Color(0x40000000) : const Color(0x18000000))
                          : (canNext ? const Color(0xFFCDD3DE) : const Color(0xFFE4E7ED)),
                      width: 0.9,
                    ),
                  ),
                  child: Icon(
                    CupertinoIcons.chevron_right,
                    size: 15,
                    color: canNext
                        ? (isDark ? Colors.white : const Color(0xFF1E2128))
                        : (isDark ? Colors.white24 : Colors.black26),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // 5. (⋯) 变形多功能菜单（加深同系色描边，无黑边）
              GlassMenu(
                menuWidth: 170,
                menuBorderRadius: 20,
                triggerBuilder: (context, toggleMenu) {
                  return GestureDetector(
                    onTap: toggleMenu,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.10)
                            : const Color(0xFFEFF1F5),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark
                              ? const Color(0x40000000)
                              : const Color(0xFFCDD3DE),
                          width: 0.9,
                        ),
                      ),
                      child: Icon(
                        CupertinoIcons.ellipsis,
                        size: 15,
                        color: isDark ? Colors.white : const Color(0xFF1E2128),
                      ),
                    ),
                  );
                },
                items: [
                  GlassMenuItem(
                    icon: const Icon(CupertinoIcons.calendar_today, size: 18, color: Colors.white),
                    title: '回到本周',
                    onTap: () {
                      final now = DateTime.now();
                      final start = provider.currentConfig.semesterStartDate;
                      final week = (now.difference(start).inDays ~/ 7) + 1;
                      provider.setCurrentWeek(week);
                      provider.setCurrentDay(now.weekday);
                    },
                  ),
                  GlassMenuItem(
                    icon: const Icon(CupertinoIcons.slider_horizontal_3, size: 18, color: Colors.white),
                    title: '课时设置',
                    onTap: () {
                      Navigator.push(
                        context,
                        TransparentMaterialPageRoute(
                          builder: (_) => const AndroidScheduleConfigScreen(),
                        ),
                      );
                    },
                  ),
                  GlassMenuItem(
                    icon: const Icon(CupertinoIcons.square_grid_2x2, size: 18, color: Colors.white),
                    title: '周次管理',
                    onTap: () => _showWeekPickerSheet(context, provider),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 现代紧凑星期日历选择器（顶部胶囊式）
  Widget _buildModernDaySelector(ScheduleProvider provider) {
    final daysCount = provider.currentConfig.showWeekends ? 7 : 5;
    final weekdayNames = ['一', '二', '三', '四', '五', '六', '日'];
    final semesterStart = provider.semesterStartDate;
    final weekOffset = (provider.currentWeek - 1) * 7;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: GlassContainer(
        useOwnLayer: true,
        quality: GlassQuality.premium,
        shape: const LiquidRoundedSuperellipse(borderRadius: 18),
        settings: const LiquidGlassSettings(
          glassColor: Color(0x12FFFFFF),
          blur: 2.5,
          thickness: 18.0,
          refractiveIndex: 1.45,
          lightIntensity: 0.70,
          ambientStrength: 0.45,
          ambientRim: 0.0,
          fresnelStrength: 0.05,
          saturation: 1.20,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(daysCount, (index) {
              final day = index + 1;
              final isSelected = day == provider.currentDay;
              final dayDate = semesterStart.add(Duration(days: weekOffset + day - 1));
              final dateLabel = '${dayDate.month}/${dayDate.day}';

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      provider.setCurrentDay(day);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppThemeColors.babyPink.withValues(alpha: 0.35)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.4)
                              : Colors.transparent,
                          width: 0.8,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            weekdayNames[index],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? Colors.white : Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateLabel,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.85)
                                  : Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  /// [v2.7.6] 安全解析节次文本，兼容 CourseEvent 时间戳与 ScheduleConfigModel
  String _getCourseSectionText(dynamic course, dynamic config) {
    try {
      if (course is CourseEvent) {
        final startDt = DateTime.fromMillisecondsSinceEpoch(course.startTime);
        final endDt = DateTime.fromMillisecondsSinceEpoch(course.endTime);
        final startMinutes = startDt.hour * 60 + startDt.minute;
        final endMinutes = endDt.hour * 60 + endDt.minute;

        int? startSec;
        int? endSec;

        if (config is ScheduleConfigModel) {
          final Map<int, int> startTimes = Map<int, int>.from(config.sectionStartTimes);
          final Map<int, int> durations = Map<int, int>.from(config.sectionDurations);
          final int defaultDur = config.defaultDuration;

          for (final entry in startTimes.entries) {
            if ((entry.value - startMinutes).abs() <= 15) {
              startSec = entry.key;
              break;
            }
          }

          if (startSec != null) {
            for (final entry in startTimes.entries) {
              final dur = durations[entry.key] ?? defaultDur;
              final secEnd = entry.value + dur;
              if ((secEnd - endMinutes).abs() <= 15) {
                endSec = entry.key;
                break;
              }
            }
            endSec ??= startSec;
            return startSec == endSec ? '第$startSec节' : '$startSec-$endSec节';
          }
        }
      } else {
        final dynamic c = course;
        if (c.startSection != null) {
          final int start = c.startSection;
          final int step = (c.step != null && c.step > 0) ? c.step : 1;
          return '$start-${start + step - 1}节';
        }
      }
    } catch (_) {}

    final timeStr = course.timeStr?.toString() ?? '';
    final parts = timeStr.split('-');
    return parts.isNotEmpty ? parts[0].trim() : '课程';
  }

  /// [v2.8.0] 遵循官方“Glass is a platter, not a wrapper”原则的高性能混色背板课程卡片，消除滚动掉帧并自适应文字对比度
  Widget _buildModernCourseCard(dynamic course, [dynamic config]) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final secondaryTextColor =
        isDark ? Colors.white70 : const Color(0x991A1A2E);

    final timeStr = course.timeStr?.toString() ?? '';
    final timeStart = timeStr.contains('-')
        ? timeStr.split('-')[0].trim()
        : timeStr;
    final timeEnd = timeStr.contains('-')
        ? timeStr.split('-')[1].trim()
        : '';
    final sectionText = _getCourseSectionText(course, config);

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: liquid.HyperOSCard(
          cornerRadius: 20,
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
                // 左侧时间胶囊条
                Container(
                  width: 58,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeStart,
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (timeEnd.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          timeEnd,
                          style: TextStyle(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.8)
                                : const Color(0x991A1A2E),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppThemeColors.babyPink.withValues(alpha: 0.35)
                              : AppThemeColors.babyPink.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          sectionText,
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 14),

                // 中间课程详情
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        course.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: primaryTextColor,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (course.location.trim().isNotEmpty && !course.location.contains('未知'))
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    CupertinoIcons.location_solid,
                                    size: 11,
                                    color: AppThemeColors.babyPink,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    course.location,
                                    style: TextStyle(
                                      color: secondaryTextColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (course.location.trim().isNotEmpty &&
                              !course.location.contains('未知') &&
                              course.teacher.isNotEmpty)
                            const SizedBox(width: 8),
                          if (course.teacher.isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.person_fill,
                                  size: 11,
                                  color: isDark
                                      ? Colors.white54
                                      : const Color(0x8A1A1A2E),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  course.teacher,
                                  style: TextStyle(
                                    color: secondaryTextColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                  // 右侧操作菜单
                  GlassContextMenu(
                    items: [
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
                        title: '删除本节课程',
                        icon: CupertinoIcons.delete,
                        isDestructive: true,
                        onTap: () async {
                          final provider = Provider.of<ScheduleProvider>(
                            context,
                            listen: false,
                          );
                          await _importService.deleteCourse(course);
                          await provider.loadSavedData();
                          if (mounted) {
                            liquid.showLiquidToast(context, '已删除本节课程');
                          }
                        },
                      ),
                      GlassContextMenuItem(
                        title: '删除所有本课程',
                        icon: CupertinoIcons.trash,
                        isDestructive: true,
                        onTap: () async {
                          final provider = Provider.of<ScheduleProvider>(
                            context,
                            listen: false,
                          );
                          await _importService.deleteAllCoursesWithName(course.name);
                          await provider.loadSavedData();
                          if (mounted) {
                            liquid.showLiquidToast(context, '已删除所有${course.name}课程');
                          }
                        },
                      ),
                    ],
                    trigger: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.16)
                              : Colors.black.withValues(alpha: 0.08),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          CupertinoIcons.ellipsis,
                          color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

  /// 优雅的无课程占位视图
  Widget _buildEmptyCourseView() {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.45,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 0.8,
                ),
              ),
              child: Icon(
                CupertinoIcons.sparkles,
                size: 30,
                color: AppThemeColors.babyPink.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '今天没有课',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '享受自由时光，好好休息吧~',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// [v2.9.6] 优雅的周次选择浮层（打开瞬间冻结背景控件离屏渲染提升帧率，退出动画完成后平滑解锁）
  Future<void> _showWeekPickerSheet(BuildContext context, ScheduleProvider provider) async {
    final weeks = provider.availableWeeks;
    if (weeks.isEmpty) return;

    _isBackgroundFrozen.value = true;
    try {
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.20),
        isScrollControlled: true,
        builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xB8161922)
                      : Colors.white.withValues(alpha: 0.85),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? const Color(0x35000000)
                          : const Color(0x12000000),
                      width: 0.8,
                    ),
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          '选择学期周次',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              CupertinoIcons.xmark,
                              size: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.4,
                      ),
                      child: GridView.builder(
                        shrinkWrap: true,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.8,
                        ),
                        itemCount: weeks.length,
                        itemBuilder: (context, idx) {
                          final week = weeks[idx];
                          final isCur = week == provider.currentWeek;
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              _isBackgroundFrozen.value = false;
                              provider.setCurrentWeek(week);
                              Navigator.pop(ctx);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              decoration: BoxDecoration(
                                gradient: isCur
                                    ? LinearGradient(
                                        colors: [
                                          AppThemeColors.babyPink.withValues(alpha: 0.5),
                                          AppThemeColors.softCoral.withValues(alpha: 0.4),
                                        ],
                                      )
                                    : null,
                                color: isCur
                                    ? null
                                    : Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isCur
                                      ? AppThemeColors.babyPink.withValues(alpha: 0.65)
                                      : (isDark ? const Color(0x30000000) : const Color(0x0E000000)),
                                  width: 0.8,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '第$week周',
                                style: TextStyle(
                                  color: isCur ? Colors.white : Colors.white70,
                                  fontSize: 13,
                                  fontWeight: isCur ? FontWeight.w700 : FontWeight.w500,
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
      );
    },
  );
    } finally {
      if (mounted) {
        _isBackgroundFrozen.value = false;
      }
    }
  }
}

