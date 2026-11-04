import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../providers/schedule_provider.dart';
import '../../constants/theme_constants.dart';
import '../../constants/version.dart' show kSolidColorBackground;
import '../../services/live_notification_service_v2.dart';
import '../../utils/responsive_utils.dart';
import '../../main.dart' hide globalUseDarkMode; // [v2.6.0] 引用全局 routeObserver
import 'course_edit_screen.dart';
import 'calendar_view_screen.dart';
import 'settings_main_screen.dart';
import 'android_schedule_config_screen.dart';
import '../widgets/liquid_components.dart' as liquid;
import '../transitions/smooth_slide_transitions.dart';
import '../widgets/tablet_sidebar.dart';
import '../widgets/weekly_schedule_grid.dart';
import '../widgets/immersive_status_bar_backdrop.dart';
import '../animations/app_motion.dart';
import '../../services/theme_service.dart' as theme;
class AndroidLiquidGlassMain extends StatefulWidget {
  const AndroidLiquidGlassMain({super.key});
  @override
  State<AndroidLiquidGlassMain> createState() => _AndroidLiquidGlassMainState();
}

class _AndroidLiquidGlassMainState extends State<AndroidLiquidGlassMain>
    with RouteAware {
  int _currentIndex = 0;
  bool _isBottomNavVisible = true;
  final ValueNotifier<bool> _isBackgroundFrozen = ValueNotifier<bool>(false);

  void _onTabSelected(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
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


  // [v2.8.9/v3.0.0] 被其他页面覆盖时：冻结底层课表动画并隐藏底栏，二级页面转场满帧 120 FPS
  @override
  void didPushNext() {
    if (mounted) {
      _isBackgroundFrozen.value = true;
      setState(() {
        _isBottomNavVisible = false;
      });
    }
  }

  // [v2.8.9/v3.0.0] 上一层页面弹出：平滑解冻课表并恢复底部导航栏
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
    // 停止通知服务
    LiveNotificationServiceV2().dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // [v2.8.5 彻底消灭启动黑屏与白屏停滞] 立即绘制主界面布局，数据异步装载完毕后自动驱动刷新

    // [v3.0.0 正式版] 手机与平板全域统一响应式架构：横屏全量采用双角浮动导航与全幅贯通课表，彻底告别老旧侧边栏
    return ValueListenableBuilder<String?>(
      valueListenable: globalBackgroundPath,
      builder: (context, _, _) {
        return GlassMotionScope(
          child: _buildPhoneLayout(context),
        );
      },
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
              child: DirectionalMotionBlurSwitcher(
                selectedIndex: _currentIndex,
                builder: (context, index) {
                  return index == 0
                      ? _buildTabletSchedulePage()
                      : (index == 1
                          ? const CalendarViewScreen()
                          : const SettingsMainScreen());
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 手机布局
  Widget _buildPhoneLayout(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSolidBg = globalBackgroundPath.value == kSolidColorBackground;
    final isLandscape = ResponsiveUtils.isLandscape(context);

    return Scaffold(
      resizeToAvoidBottomInset: false, // [v2.8.6] 软键盘弹出时防止底层背景被压缩或上移漂移
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: Stack(
        children: [
          RepaintBoundary(
            key: TransparentMaterialPageRoute.contentBoundaryKey,
            child: DirectionalMotionBlurSwitcher(
              selectedIndex: _currentIndex,
              builder: (context, index) {
                if (index == 0) {
                  return _buildSchedulePage();
                } else if (index == 1) {
                  // [v3.0.0-alpha17 彻底消除重叠UI] CalendarViewScreen 自带完整晶透顶栏，直接挂载绝不二次叠加顶栏
                  return const CalendarViewScreen();
                } else {
                  return const SettingsMainScreen();
                }
              },
            ),
          ),
          // [v3.0.0] 物理状态栏 (0..48dp) 顶级沉浸式微模糊避让 (非横屏时生效)
          if (!isLandscape) const ImmersiveStatusBarBackdrop(),

          // [v3.0.0-alpha23] 横屏模式：左下角官方 GlassTabBar 双标签 touch bar + 右下角圆形官方液态玻璃设置按钮，上下左右零挤占
          if (isLandscape) ...[
            // 左下角：官方 GlassTabBar 双按钮玻璃导航栏（课程、日历）
            Positioned(
              left: 16 + MediaQuery.of(context).padding.left,
              bottom: 14 + MediaQuery.of(context).padding.bottom,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                offset: _isBottomNavVisible ? Offset.zero : const Offset(0, 1.4),
                child: RepaintBoundary(
                  child: _buildLandscapeLeftNav(context),
                ),
              ),
            ),

            // 右下角：官方圆形液态玻璃设置按钮，高度 52x52，与左下角严格水平对齐
            Positioned(
              right: 16 + MediaQuery.of(context).padding.right,
              bottom: 14 + MediaQuery.of(context).padding.bottom,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                offset: _isBottomNavVisible ? Offset.zero : const Offset(0, 1.4),
                child: RepaintBoundary(
                  child: _buildLandscapeSettingsButton(context),
                ),
              ),
            ),
          ],
        ],
      ),
      // 竖屏时使用官方原生旗舰 GlassTabBar.bottom；横屏模式使用完全浮动双角布局，彻底释放高度
      bottomNavigationBar: isLandscape
          ? null
          : SafeArea(
              bottom: true,
              top: false,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                offset: _isBottomNavVisible ? Offset.zero : const Offset(0, 1.2),
                child: RepaintBoundary(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GlassTabBar.bottom(
                        selectedIndex: _currentIndex,
                        onTabSelected: (index) {
                          HapticFeedback.selectionClick();
                          _onTabSelected(index);
                        },
                        quality: GlassQuality.premium, // [v3.0.0-alpha19] 全时 100% 极客 Premium 材质，杜绝任何运动降级
                        backgroundQuality: GlassQuality.premium,
                        maskingQuality: MaskingQuality.high,
                        barBorderRadius: 999.0,
                        indicatorBorderRadius: 999.0,
                        adaptiveBrightness: false, // [v2.8.9] 禁用实时纹理反读消除卡顿，保持流畅 120 FPS
                        barHeight: 64.0,
                        horizontalPadding: 16.0,
                        verticalPadding: 8.0,
                        magnification: 1.15,
                        innerBlur: 0.0, // [v3.0.0-alpha19] 绝对消除滑块底衬残留模糊，零 blur 纯净晶体透镜
                        interactionBehavior: GlassInteractionBehavior.full,
                        settings: const LiquidGlassSettings(
                          thickness: 24.0,
                          blur: 0.3, // [v3.0.0-alpha20] 极低 blur 几乎完全通透，只靠 3D 折射与色散勾勒边缘
                          chromaticAberration: 0.12,
                          lightIntensity: 0.75,
                          refractiveIndex: 1.48,
                          saturation: 1.15,
                          ambientStrength: 0.35,
                          ambientRim: 0.0,
                          fresnelStrength: 0.0,
                          glassColor: Color(0x10FFFFFF),
                        ),
                    // [v3.0.0-alpha21] 静态（未触发）呈现实体主题色柔和指示胶囊，按下瞬间平滑激活 3D 凸透镜大范围折射
                    indicatorColor: isDark
                        ? Theme.of(context).primaryColor.withValues(alpha: 0.24)
                        : Theme.of(context).primaryColor.withValues(alpha: 0.16),
                    indicatorSettings: LiquidGlassSettings(
                      thickness: 28.0,
                      blur: 0.0, // [v3.0.0-alpha19] 滑块绝对零模糊（0.0 blur）
                      refractiveIndex: 1.50, // 真实光学玻璃高折射率
                      lightIntensity: 0.70,
                      ambientStrength: 0.25,
                      ambientRim: 0.0, // 消除人造白边描边
                      fresnelStrength: 0.0, // 消除掠射角人造白边
                      chromaticAberration: 0.10, // 优雅物理色散勾勒边缘
                      edgeAbsorption: 0.0,
                      glassColor: isDark
                          ? Theme.of(context).primaryColor.withValues(alpha: 0.08)
                          : Theme.of(context).primaryColor.withValues(alpha: 0.05),
                      shadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.38 : 0.16),
                          blurRadius: 22.0,
                          spreadRadius: -1.0,
                          offset: const Offset(0, 4.0),
                        ),
                      ],
                    ),
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
                      // [纯色背景模式] 仅在玻璃渲染完成后，通过逆向裁剪在胶囊外侧绘制柔光，
                      // 绝不被 BackdropFilter 采样进玻璃内部，100% 保持原玻璃通透度！
                      if (isSolidBg)
                        Positioned(
                          left: 16.0,
                          right: 16.0,
                          top: 8.0,
                          bottom: 8.0,
                          child: liquid.OuterGlowShadowBox(
                            borderRadius: 999.0,
                            isDark: isDark,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  /// [v3.0.0-alpha23] 横屏手机左下角官方 GlassTabBar 双标签 touch bar（课程、日历）
  Widget _buildLandscapeLeftNav(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSolidBg = globalBackgroundPath.value == kSolidColorBackground;
    final primaryColor = Theme.of(context).primaryColor;

    return SizedBox(
      width: 180.0,
      height: 52.0,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GlassTabBar.bottom(
            selectedIndex: _currentIndex == 2 ? 0 : _currentIndex,
            showIndicator: _currentIndex != 2,
            onTabSelected: (index) {
              HapticFeedback.selectionClick();
              _onTabSelected(index);
            },
            quality: GlassQuality.premium,
            backgroundQuality: GlassQuality.premium,
            maskingQuality: MaskingQuality.high,
            barBorderRadius: 999.0,
            indicatorBorderRadius: 999.0,
            adaptiveBrightness: false,
            barHeight: 52.0,
            horizontalPadding: 0.0,
            verticalPadding: 0.0,
            magnification: 1.15,
            innerBlur: 0.0,
            interactionBehavior: GlassInteractionBehavior.full,
            settings: const LiquidGlassSettings(
              thickness: 24.0,
              blur: 0.3,
              chromaticAberration: 0.12,
              lightIntensity: 0.75,
              refractiveIndex: 1.48,
              saturation: 1.15,
              ambientStrength: 0.35,
              ambientRim: 0.0,
              fresnelStrength: 0.0,
              glassColor: Color(0x10FFFFFF),
            ),
            indicatorColor: isDark
                ? primaryColor.withValues(alpha: 0.24)
                : primaryColor.withValues(alpha: 0.16),
            indicatorSettings: LiquidGlassSettings(
              thickness: 28.0,
              blur: 0.0,
              refractiveIndex: 1.50,
              lightIntensity: 0.70,
              ambientStrength: 0.25,
              ambientRim: 0.0,
              fresnelStrength: 0.0,
              chromaticAberration: 0.10,
              edgeAbsorption: 0.0,
              glassColor: isDark
                  ? primaryColor.withValues(alpha: 0.08)
                  : primaryColor.withValues(alpha: 0.05),
              shadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.38 : 0.16),
                  blurRadius: 22.0,
                  spreadRadius: -1.0,
                  offset: const Offset(0, 4.0),
                ),
              ],
            ),
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
            ],
          ),
          if (isSolidBg)
            Positioned.fill(
              child: liquid.OuterGlowShadowBox(
                borderRadius: 999.0,
                isDark: isDark,
              ),
            ),
        ],
      ),
    );
  }

  /// [v3.0.0-alpha25] 横屏手机右下角纯透镜液态玻璃设置按钮（52x52圆形），物理弹簧灵动缩放，杜绝任何实色/Material遮罩
  Widget _buildLandscapeSettingsButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final isSelected = _currentIndex == 2;

    return GlassButton.custom(
      width: 52.0,
      height: 52.0,
      useOwnLayer: true,
      shape: const LiquidOval(),
      quality: GlassQuality.premium,
      stretch: 0.20,
      interactionScale: 1.12,
      showOverlayColor: false,
      ambientBaseLight: 0.0,
      onTap: () {
        HapticFeedback.selectionClick();
        if (_currentIndex == 2) {
          _onTabSelected(0);
        } else {
          _onTabSelected(2);
        }
      },
      settings: LiquidGlassSettings(
        thickness: 16.0,
        blur: 0.3,
        refractiveIndex: 1.44,
        edgeAbsorption: 0.10,
        chromaticAberration: 0.12,
        lightIntensity: 0.75,
        ambientStrength: 0.35,
        ambientRim: 0.0,
        fresnelStrength: 0.0,
        saturation: 1.15,
        glassColor: isSelected
            ? primaryColor.withValues(alpha: isDark ? 0.32 : 0.22)
            : (isDark ? const Color(0x28101216) : const Color(0x25FFFFFF)),
        shadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.38 : 0.14),
            blurRadius: 18.0,
            spreadRadius: -1.0,
            offset: const Offset(0, 4.0),
          ),
        ],
      ),
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            isSelected ? CupertinoIcons.gear_alt_fill : CupertinoIcons.gear_alt,
            key: ValueKey(isSelected),
            size: 22.0,
            color: isSelected
                ? (isDark ? Colors.white : primaryColor)
                : (isDark ? Colors.white70 : const Color(0xFF4A4E58)),
          ),
        ),
      ),
    );
  }


  /// 平板模式的课程页面（本周网格视图）
  Widget _buildTabletSchedulePage() {
    return Consumer<ScheduleProvider>(
      builder: (context, provider, _) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: WeeklyScheduleGrid(
            key: ValueKey('weekly_schedule_grid_tablet_main'),
          ),
        ),
      ),
    );
  }

  /// [v2.8.9/v3.0.0] 重构手机端主课表页面：全周看板网格贯通上下滑动，穿透悬浮标题栏与底栏
  Widget _buildSchedulePage() {
    return Consumer<ScheduleProvider>(
        builder: (context, provider, _) {
          final isLandscape = ResponsiveUtils.isLandscape(context);
          // [v3.0.0-alpha23] 横屏模式彻底移除大标题栏，仅保留左上角节次星期交汇处的悬浮日期胶囊，释放全幅垂直空间
          final topPadding = isLandscape
              ? (MediaQuery.of(context).padding.top + 6)
              : (MediaQuery.of(context).padding.top + 54);

          return Stack(
            children: [
              // 课程网格本周看板：全屏铺满，上下纵向滚动，平滑穿过顶栏与底栏
              Positioned.fill(
                child: WeeklyScheduleGrid(
                  key: const ValueKey('weekly_schedule_grid_main'),
                  showControlBar: false,
                  isPhone: true,
                  contentPadding: EdgeInsets.only(
                    top: topPadding,
                    bottom: isLandscape
                        ? (MediaQuery.of(context).padding.bottom + 72)
                        : 186, // [v2.9.7] 为进一步抬高的浮动胶囊 Dock 留出安全滚动距离
                    left: isLandscape ? (MediaQuery.of(context).padding.left + 4) : 2,
                    right: isLandscape ? (MediaQuery.of(context).padding.right + 4) : 2,
                  ),
                ),
              ),

              // 顶部悬浮标题栏：轻量品牌与日期指示（仅竖屏展示，横屏由左上角胶囊承接）
              if (!isLandscape)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    left: true,
                    right: true,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                      child: RepaintBoundary(
                        child: _buildModernTopBar(provider),
                      ),
                    ),
                  ),
                ),


              // 底部悬浮横向胶囊控制 Dock：
              // 竖屏模式：抬高至 bottom: 120，靠右对齐放置与底栏保持舒适距离
              // 横屏模式：居中对齐在 bottom: 14 + padding.bottom，与左侧导航胶囊及右侧设置按钮在同一水平线上
              if (isLandscape)
                Positioned(
                  bottom: 14 + MediaQuery.of(context).padding.bottom,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: RepaintBoundary(
                      child: _buildFloatingBottomActionDock(provider),
                    ),
                  ),
                )
              else
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
      );
  }

  /// 现代晶透顶部栏：精简为品牌 Logo 与当前日期指示，腾出顶部空间
  /// [v3.1.4] 恢复真实 3D 折射液态玻璃 (GlassContainer Premium)，配合常驻预烘焙几何缓存与动态背景补偿，切页零掉帧且不变暗
  Widget _buildModernTopBar(ScheduleProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    const weekDays = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final dateStr = '${now.month}月${now.day}日 ${weekDays[now.weekday]}';

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: liquid.HyperOSShadows.dock(isDark),
      ),
      child: GlassContainer(
        useOwnLayer: true,
        shape: const LiquidRoundedSuperellipse(borderRadius: 18),
        quality: theme.ThemeService().glassQuality,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        settings: LiquidGlassSettings(
          glassColor: isDark
              ? const Color(0x1812151B)
              : const Color(0x18FFFFFF),
          blur: 0.5,
          thickness: 18.0,
          refractiveIndex: 1.44,
          lightIntensity: 0.70,
          ambientStrength: 0.45,
          ambientRim: 0.0,
          fresnelStrength: 0.0,
          saturation: 1.20,
        ),
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
            // 当前日期指示徽章 (无边框，柔和漫反射阴影)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                boxShadow: liquid.HyperOSShadows.pill(isDark),
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
    );
  }


  /// [v3.1.4] 底部悬浮横向胶囊控制 Dock：恢复真实 3D 液态玻璃 (GlassContainer Premium)
  /// 布局：（（+）（＜）（第 X 周 ▾）（＞）（…））
  Widget _buildFloatingBottomActionDock(ScheduleProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final weeks = provider.availableWeeks.isNotEmpty
        ? provider.availableWeeks
        : List.generate(25, (i) => i + 1);
    final canPrev = provider.currentWeek > weeks.first;
    final canNext = provider.currentWeek < weeks.last;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: liquid.HyperOSShadows.dock(isDark),
      ),
      child: GlassContainer(
        useOwnLayer: true,
        shape: const LiquidRoundedSuperellipse(borderRadius: 26),
        quality: theme.ThemeService().glassQuality,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        settings: LiquidGlassSettings(
          glassColor: isDark
              ? const Color(0x35101216)
              : const Color(0x30FFFFFF),
          blur: 0.5,
          thickness: 20.0,
          refractiveIndex: 1.42,
          lightIntensity: 0.35,
          ambientStrength: 0.20,
          ambientRim: 0.0,
          fresnelStrength: 0.0,
          edgeAbsorption: 0.06,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
              // 1. (+) 添加课程按钮 (纯净无边框，柔粉弥散阴影，Spring 跟手弹性)
              SpringTouchFeedback(
                onTap: () {
                  Navigator.push(
                    context,
                    TransparentMaterialPageRoute(
                      builder: (_) => const CourseEditScreen(),
                    ),
                  );
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppThemeColors.babyPink.withValues(alpha: isDark ? 0.25 : 0.18),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: liquid.HyperOSShadows.pill(isDark, accentColor: AppThemeColors.babyPink),
                  ),
                  child: Icon(
                    CupertinoIcons.add,
                    size: 16,
                    color: isDark ? Colors.white : AppThemeColors.babyPink,
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // 2. (＜) 上一周按钮 (晶透液态玻璃微透晶体，Spring 跟手弹性)
              SpringTouchFeedback(
                onTap: canPrev
                    ? () {
                        HapticFeedback.selectionClick();
                        provider.setCurrentWeek(provider.currentWeek - 1);
                      }
                    : null,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: canPrev ? 0.12 : 0.04)
                        : (canPrev ? Colors.white.withValues(alpha: 0.55) : Colors.white.withValues(alpha: 0.22)),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: canPrev ? 0.12 : 0.04)
                          : Colors.white.withValues(alpha: canPrev ? 0.70 : 0.35),
                      width: 0.8,
                    ),
                    boxShadow: canPrev ? liquid.HyperOSShadows.pill(isDark) : null,
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

              // 3. (第 X 周 ▾) 核心选择胶囊 (纯净无边框，柔粉漫反射阴影，Spring 跟手弹性)
              SpringTouchFeedback(
                onTap: () => _showWeekPickerSheet(context, provider),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppThemeColors.babyPink.withValues(alpha: isDark ? 0.26 : 0.18),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: liquid.HyperOSShadows.pill(isDark, accentColor: AppThemeColors.babyPink),
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

              // 4. (＞) 下一周按钮 (晶透液态玻璃微透晶体，Spring 跟手弹性)
              SpringTouchFeedback(
                onTap: canNext
                    ? () {
                        HapticFeedback.selectionClick();
                        provider.setCurrentWeek(provider.currentWeek + 1);
                      }
                    : null,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: canNext ? 0.12 : 0.04)
                        : (canNext ? Colors.white.withValues(alpha: 0.55) : Colors.white.withValues(alpha: 0.22)),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: canNext ? 0.12 : 0.04)
                          : Colors.white.withValues(alpha: canNext ? 0.70 : 0.35),
                      width: 0.8,
                    ),
                    boxShadow: canNext ? liquid.HyperOSShadows.pill(isDark) : null,
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

              // 5. (⋯) 变形多功能菜单 (纯净无边框，漫反射微阴影)
              GlassMenu(
                menuWidth: 170,
                menuBorderRadius: 20,
                quality: theme.ThemeService().glassQuality,
                settings: LiquidGlassSettings(
                  glassColor: isDark
                      ? const Color(0x35101216)
                      : const Color(0x30FFFFFF),
                  blur: 4.0,
                  thickness: 18.0,
                  refractiveIndex: 1.35,
                  lightIntensity: 0.35,
                  ambientStrength: 0.20,
                  ambientRim: 0.0,
                  fresnelStrength: 0.0,
                  edgeAbsorption: 0.06,
                ),
                triggerBuilder: (context, toggleMenu) {
                  return SpringTouchFeedback(
                    onTap: toggleMenu,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.white.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.white.withValues(alpha: 0.70),
                          width: 0.8,
                        ),
                        boxShadow: liquid.HyperOSShadows.pill(isDark),
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
                      SharedElementSourceRegistry.recordFromContext(
                        context,
                        cornerRadius: 20.0,
                      );
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
      );
  }

  /// [v2.9.6] 优雅的周次选择浮层（打开瞬间冻结背景控件离屏渲染提升帧率，退出动画完成后平滑解锁）
  Future<void> _showWeekPickerSheet(BuildContext context, ScheduleProvider provider) async {
    final weeks = provider.availableWeeks.isNotEmpty
        ? provider.availableWeeks
        : List.generate(25, (i) => i + 1);

    _isBackgroundFrozen.value = true;
    try {
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.20),
        isScrollControlled: true,
        builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final titleColor = isDark ? Colors.white : const Color(0xFF1E2128);
          final closeColor = isDark ? Colors.white70 : const Color(0xFF555B68);
          final closeBg = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05);

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
                            Text(
                              '选择学期周次',
                              style: TextStyle(
                                color: titleColor,
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
                                  color: closeBg,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  CupertinoIcons.xmark,
                                  size: 14,
                                  color: closeColor,
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
                              final unselectedBg = isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : const Color(0xFFF0F2F6);
                              final unselectedText = isDark
                                  ? Colors.white70
                                  : const Color(0xFF555B68);

                              return SpringTouchFeedback(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  _isBackgroundFrozen.value = false;
                                  provider.setCurrentWeek(week);
                                  Navigator.pop(ctx);
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: isCur
                                        ? LinearGradient(
                                            colors: [
                                              AppThemeColors.babyPink.withValues(alpha: 0.5),
                                              AppThemeColors.softCoral.withValues(alpha: 0.4),
                                            ],
                                          )
                                        : null,
                                    color: isCur ? null : unselectedBg,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: isCur
                                        ? liquid.HyperOSShadows.pill(isDark, accentColor: AppThemeColors.babyPink)
                                        : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '第$week周',
                                    style: TextStyle(
                                      color: isCur ? Colors.white : unselectedText,
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

