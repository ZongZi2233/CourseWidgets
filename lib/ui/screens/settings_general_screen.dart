import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:file_selector/file_selector.dart';
import 'dart:io';
import '../../constants/theme_constants.dart';
import '../../constants/version.dart' show kSolidColorBackground;
import '../../services/app_update_service.dart';
import '../../services/glass_appearance_service.dart';
import '../../services/storage_service.dart';
import '../../services/theme_service.dart' as theme;
import '../../utils/glass_settings_helper.dart';
import '../../main.dart';
import '../widgets/liquid_components.dart' as liquid;
import '../widgets/immersive_status_bar_backdrop.dart';
import '../widgets/windows_desktop_title_bar.dart'
    show setWindowsDesktopTitle, clearWindowsDesktopTitle;
import '../widgets/adaptive_smooth_scroll.dart';

class SettingsGeneralScreen extends StatefulWidget {
  const SettingsGeneralScreen({super.key});
  @override
  State<SettingsGeneralScreen> createState() => _SettingsGeneralScreenState();
}

class _SettingsGeneralScreenState extends State<SettingsGeneralScreen> {
  final StorageService _storage = StorageService();
  final theme.ThemeService _themeService = theme.ThemeService();

  bool _adaptiveDarkMode = false;
  bool _autoCheckUpdate = true;
  theme.ThemeMode _currentThemeMode = theme.ThemeMode.defaultMode;

  bool get _isDarkMode => _themeService.isDarkMode;

  Color get _textColor => _isDarkMode ? Colors.white : Colors.black87;
  Color get _textSecondaryColor =>
      _isDarkMode ? Colors.white60 : Colors.black54;

  @override
  void initState() {
    super.initState();
    setWindowsDesktopTitle('通用设置');
    _loadSettings();
  }

  @override
  void dispose() {
    clearWindowsDesktopTitle('通用设置');
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final adaptiveMode =
        _storage.getBool(StorageService.keyAdaptiveDarkMode) ?? false;
    final autoCheckUpdate = AppUpdateService.instance.isAutoCheckUpdateEnabled();

    setState(() {
      _adaptiveDarkMode = adaptiveMode;
      _autoCheckUpdate = autoCheckUpdate;
      _currentThemeMode = _themeService.themeMode;
    });
  }

  Future<void> _toggleAutoCheckUpdate(bool value) async {
    HapticFeedback.selectionClick();
    setState(() {
      _autoCheckUpdate = value;
    });
    await AppUpdateService.instance.setAutoCheckUpdateEnabled(value);
    if (mounted) {
      _showToast(value ? '已开启每日自动检查更新' : '已关闭每日自动检查更新');
    }
  }

  void _toggleDarkMode(bool value) async {
    setState(() {
      if (value) _adaptiveDarkMode = false;
    });
    _themeService.setDarkMode(value);
    await _storage.setBool(StorageService.keyDarkMode, value);
    if (value) {
      await _storage.setBool(StorageService.keyAdaptiveDarkMode, false);
    }
  }

  void _toggleAdaptiveMode(bool value) async {
    setState(() {
      _adaptiveDarkMode = value;
    });
    if (value) {
      final brightness = MediaQuery.of(context).platformBrightness;
      _themeService.setDarkMode(brightness == Brightness.dark);
    } else {
      _themeService.setDarkMode(false);
    }
    await _storage.setBool(StorageService.keyAdaptiveDarkMode, value);
    if (value) {
      await _storage.setBool(StorageService.keyDarkMode, false);
    }
  }

  Future<void> _pickBackgroundImage() async {
    try {
      if (Platform.isAndroid) {
        const platform = MethodChannel('com.zongzi.schedule/image_picker');
        final String? imagePath = await platform.invokeMethod('pickImage');

        if (imagePath != null) {
          globalBackgroundPath.value = imagePath;
          await _storage.setString(StorageService.keyBackgroundPath, imagePath);

          if (_currentThemeMode == theme.ThemeMode.monet) {
            await _themeService.extractColorsFromImage(imagePath);
            setState(() {});
          }

          if (mounted) _showToast('背景设置成功');
        }
      } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        final XFile? file = await openFile(
          acceptedTypeGroups: [
            const XTypeGroup(
              label: '图片',
              extensions: ['jpg', 'jpeg', 'png', 'bmp', 'webp'],
            ),
          ],
        );

        if (file != null) {
          globalBackgroundPath.value = file.path;
          await _storage.setString(StorageService.keyBackgroundPath, file.path);

          if (_currentThemeMode == theme.ThemeMode.monet) {
            await _themeService.extractColorsFromImage(file.path);
            setState(() {});
          }

          if (mounted) _showToast('背景设置成功');
        }
      } else {
        _showToast('当前平台不支持');
      }
    } on PlatformException catch (e) {
      if (e.code == 'UNSUPPORTED') {
        if (mounted) _showToast('需要 Android 14+');
      } else if (e.code == 'CANCELLED') {
        // 用户取消，不显示错误
      } else {
        if (mounted) _showToast('选择图片失败: ${e.message}');
      }
    } catch (e) {
      if (mounted) _showToast('选择图片失败: $e');
    }
  }

  void _showThemeModeBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      enableDrag: true,
      showDragHandle: false,
      isScrollControlled: true,
      builder: (BuildContext context) => RepaintBoundary(
        child: GlassSheet(
          settings: GlassSettingsHelper.getDialogSettings(),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    '主题色设置',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _textColor,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _buildThemeModeOption(
                        theme.ThemeMode.defaultMode,
                        '默认主题',
                        '使用应用默认的嫩粉色主题',
                        CupertinoIcons.paintbrush,
                      ),
                      const SizedBox(height: 12),
                      if (Platform.isAndroid || Platform.isWindows) ...[
                        _buildThemeModeOption(
                          theme.ThemeMode.system,
                          '系统主题',
                          Platform.isWindows
                              ? '跟随 Windows 系统强调色'
                              : 'Android 12+ Material You 动态颜色',
                          Platform.isWindows
                              ? CupertinoIcons.desktopcomputer
                              : CupertinoIcons.device_phone_portrait,
                        ),
                        const SizedBox(height: 12),
                      ],
                      _buildThemeModeOption(
                        theme.ThemeMode.monet,
                        '莫奈取色',
                        '从背景图片提取主题色',
                        CupertinoIcons.photo,
                      ),
                      const SizedBox(height: 12),
                      _buildThemeModeOption(
                        theme.ThemeMode.custom,
                        '自定义主题色',
                        '选择你喜欢的任意颜色',
                        CupertinoIcons.color_filter,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeModeOption(
    theme.ThemeMode mode,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final isSelected = _currentThemeMode == mode;

    return GestureDetector(
      onTap: () async {
        HapticFeedback.selectionClick();

        if (mode == theme.ThemeMode.custom) {
          Navigator.pop(context);
          await _showColorPicker();
          return;
        }

        if (mode == theme.ThemeMode.monet) {
          setState(() => _currentThemeMode = theme.ThemeMode.monet);
          await _themeService.setThemeMode(theme.ThemeMode.monet);
          final rawBg = globalBackgroundPath.value;
          final bgPath = (rawBg == null || rawBg.isEmpty || rawBg == kSolidColorBackground)
              ? (_isDarkMode ? 'asset:assets/Dark.png' : 'asset:assets/Light.png')
              : rawBg;
          await _themeService.extractColorsFromImage(bgPath);
          if (mounted) {
            setState(() {});
            Navigator.pop(context);
            _showToast('已切换为莫奈取色');
          }
          return;
        }

        setState(() => _currentThemeMode = mode);
        await _themeService.setThemeMode(mode);

        if (mode == theme.ThemeMode.system &&
            (Platform.isAndroid || Platform.isWindows) &&
            mounted) {
          await _themeService.applySystemTheme(context);
        }

        setState(() {});
        if (mounted) Navigator.pop(context);
        _showToast('主题已切换');
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    AppThemeColors.babyPink.withValues(alpha: 0.35),
                    AppThemeColors.softCoral.withValues(alpha: 0.35),
                  ],
                )
              : null,
          color: isSelected
              ? null
              : (_isDarkMode
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.85)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: Center(
                child: Icon(icon, color: _textColor, size: 22),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: _textSecondaryColor),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                CupertinoIcons.check_mark_circled_solid,
                color: AppThemeColors.babyPink,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  void _showToast(String msg) {
    if (mounted) liquid.showLiquidToast(context, msg);
  }

  Future<void> _toggleSolidColorBackground(bool useSolid) async {
    HapticFeedback.selectionClick();
    if (useSolid) {
      globalBackgroundPath.value = kSolidColorBackground;
      await _storage.setString(StorageService.keyBackgroundPath, kSolidColorBackground);
      if (mounted) {
        _showToast('已切换为纯色极简背景');
      }
    } else {
      globalBackgroundPath.value = null;
      await _storage.remove(StorageService.keyBackgroundPath);
      if (mounted) {
        _showToast('已恢复默认渐变壁纸');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
            child: AdaptiveSmoothScroll(
              durationMS: 250,
              scrollSpeed: 1.2,
              builder: (context, controller, physics) => SingleChildScrollView(
                controller: controller,
                physics: physics,
                padding: EdgeInsets.fromLTRB(16, topPadding, 16, isDesktop ? 32 : 100),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 860),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // [v3.0.0] 外观设置大卡片（合并自适应与强制深色）
                        _buildSection('外观'),
                        _buildCardGroup([
                          _buildSwitchRow(
                            '自适应深色模式',
                            '跟随系统设置',
                            CupertinoIcons.circle_righthalf_fill,
                            _adaptiveDarkMode,
                            _toggleAdaptiveMode,
                          ),
                          IgnorePointer(
                            ignoring: _adaptiveDarkMode,
                            child: _buildSwitchRow(
                              '强制深色模式',
                              '手动覆盖系统设置',
                              CupertinoIcons.moon_fill,
                              globalUseDarkMode,
                              _toggleDarkMode,
                              disabled: _adaptiveDarkMode,
                            ),
                          ),
                        ]),
                        const SizedBox(height: 20),

                        // [v3.0.0] 主题色大卡片
                        _buildSection('主题色'),
                        _buildCardGroup([
                          _buildActionRow(
                            '主题色设置',
                            _getThemeModeText(),
                            CupertinoIcons.color_filter,
                            _showThemeModeBottomSheet,
                          ),
                        ]),

                        const SizedBox(height: 20),

                        // [v3.1.0] 个性化大卡片（更换壁纸 / 恢复默认渐变壁纸 / 去掉默认壁纸纯色模式）
                        _buildSection('个性化'),
                        ValueListenableBuilder<String?>(
                          valueListenable: globalBackgroundPath,
                          builder: (context, bgPath, _) {
                            final isSolidColor = bgPath == kSolidColorBackground;
                            return _buildCardGroup([
                              _buildActionRow(
                                '更换背景图片',
                                '从本地相册选择自定义壁纸并支持莫奈取色',
                                CupertinoIcons.photo,
                                _pickBackgroundImage,
                              ),
                              _buildActionRow(
                                '恢复默认壁纸',
                                '重置为内置低噪点渐变壁纸',
                                CupertinoIcons.arrow_counterclockwise,
                                () async {
                                  globalBackgroundPath.value = null;
                                  await _storage.remove(StorageService.keyBackgroundPath);
                                  _showToast('已恢复默认渐变壁纸');
                                },
                              ),
                              _buildSwitchRow(
                                '纯色极简背景',
                                '关闭背景壁纸（浅色纯白 / 夜间深灰护眼）',
                                CupertinoIcons.paintbrush_fill,
                                isSolidColor,
                                _toggleSolidColorBackground,
                              ),
                            ]);
                          },
                        ),

                        const SizedBox(height: 20),

                        // [v3.0.0] 渲染性能大卡片（Premium 旗舰画质 vs Standard 流畅高帧切换）
                        _buildSection('渲染与性能'),
                        _buildCardGroup([
                          ListenableBuilder(
                            listenable: theme.ThemeService.globalGlassQualityNotifier,
                            builder: (context, _) {
                              final isPremium = theme.ThemeService.globalGlassQualityNotifier.value == GlassQuality.premium;
                              return _buildActionRow(
                                '玻璃渲染画质',
                                isPremium
                                    ? '旗舰折射 (Premium) · 光学折射质感优先'
                                    : '流畅高帧 (Standard) · 120Hz 省电高帧优先',
                                CupertinoIcons.speedometer,
                                _toggleGlassQuality,
                                trailing: liquid.LiquidSwitch(
                                  value: isPremium,
                                  onChanged: (_) => _toggleGlassQuality(),
                                ),
                              );
                            },
                          ),
                        ]),

                        const SizedBox(height: 20),

                        // [v3.2.4] 全应用玻璃白值、玻璃模糊与全局界面高斯模糊统一控制（3.2.4–3.2.5 分两阶段迁移）
                        _buildSection('玻璃与模糊材质'),
                        ListenableBuilder(
                          listenable: GlassAppearanceService.instance,
                          builder: (context, _) {
                            final glass = GlassAppearanceService.instance;
                            final int opacityPct =
                                (glass.glassOpacity * 100).round();
                            final String opacitySubtitle;
                            if (glass.isGlassOpaque) {
                              opacitySubtitle =
                                  '已设为完全不透明，玻璃组件高斯模糊已自动关闭以降低功耗';
                            } else if (glass.isGlassTransparent) {
                              opacitySubtitle =
                                  '已设为 0% 完全透明，保留纯净折射与边线层次';
                            } else {
                              opacitySubtitle =
                                  '控制底栏、顶栏、菜单、弹窗与按钮白值 (0% – 100%)';
                            }

                            final String glassBlurSubtitle = glass.isGlassOpaque
                                ? '当前玻璃为完全不透明，已自动跳过高斯模糊渲染'
                                : '控制玻璃组件自身的磨砂模糊强度，独立于全局模糊 (0.0 – 28.0)';

                            return _buildCardGroup([
                              _buildSliderRow(
                                sliderKey: const ValueKey('glass_opacity_slider'),
                                title: '玻璃透明度（白值）',
                                subtitle: opacitySubtitle,
                                icon: CupertinoIcons.drop_triangle_fill,
                                valueText: '$opacityPct%',
                                value: glass.glassOpacity,
                                min: GlassAppearanceService.minGlassOpacity,
                                max: GlassAppearanceService.maxGlassOpacity,
                                onChanged: (v) =>
                                    glass.setGlassOpacity(v, persist: false),
                                onChangeEnd: (v) =>
                                    glass.setGlassOpacity(v, persist: true),
                              ),
                              _buildSliderRow(
                                sliderKey: const ValueKey('glass_blur_slider'),
                                title: '玻璃高斯模糊度',
                                subtitle: glassBlurSubtitle,
                                icon: CupertinoIcons.sparkles,
                                valueText: glass.isGlassOpaque
                                    ? '已关闭'
                                    : glass.glassBlur.toStringAsFixed(1),
                                value: glass.glassBlur,
                                min: GlassAppearanceService.minGlassBlur,
                                max: GlassAppearanceService.maxGlassBlur,
                                disabled: glass.isGlassOpaque,
                                onChanged: (v) =>
                                    glass.setGlassBlur(v, persist: false),
                                onChangeEnd: (v) =>
                                    glass.setGlassBlur(v, persist: true),
                              ),
                              _buildSliderRow(
                                sliderKey:
                                    const ValueKey('global_ui_blur_slider'),
                                title: '全局界面高斯模糊度',
                                subtitle:
                                    '控制弹窗背景幕布、状态栏与动效模糊（独立于玻璃组件，不可完全关闭）',
                                icon: CupertinoIcons.rectangle_stack_fill,
                                valueText:
                                    glass.globalUiBlur.toStringAsFixed(1),
                                value: glass.globalUiBlur,
                                min: GlassAppearanceService.minGlobalUiBlur,
                                max: GlassAppearanceService.maxGlobalUiBlur,
                                onChanged: (v) =>
                                    glass.setGlobalUiBlur(v, persist: false),
                                onChangeEnd: (v) =>
                                    glass.setGlobalUiBlur(v, persist: true),
                              ),
                              _buildActionRow(
                                '恢复默认',
                                '将玻璃透明度、玻璃模糊与全局界面模糊重置为默认参数',
                                CupertinoIcons.arrow_counterclockwise,
                                () async {
                                  HapticFeedback.lightImpact();
                                  await glass.resetToDefaults();
                                  _showToast('已恢复默认玻璃与模糊参数');
                                },
                                rowKey: const ValueKey(
                                  'reset_glass_appearance_button',
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (glass.isDefault
                                            ? _textSecondaryColor
                                            : _themeService.primaryColor)
                                        .withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    glass.isDefault ? '已是默认' : '重置',
                                    style: TextStyle(
                                      color: glass.isDefault
                                          ? _textSecondaryColor
                                          : _themeService.primaryColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ]);
                          },
                        ),

                        const SizedBox(height: 20),

                        _buildSection('应用更新'),
                        _buildCardGroup([
                          _buildSwitchRow(
                            '每日自动检查更新',
                            '每天首次打开软件后自动检测新版本并提示更新',
                            CupertinoIcons.arrow_2_circlepath,
                            _autoCheckUpdate,
                            _toggleAutoCheckUpdate,
                          ),
                        ]),

                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: const [
                      liquid.FloatingGlassHeaderButton(title: '通用设置'),
                    ],
                  ),
                ),
              ),
            ),

          // 4. [v2.9.7] 悬浮右下角返回按钮（仅移动端展示）
          if (!isDesktop) const liquid.FloatingLiquidBackButton(),
        ],
      ),
    );
  }

  String _getThemeModeText() {
    switch (_currentThemeMode) {
      case theme.ThemeMode.defaultMode:
        return '默认主题';
      case theme.ThemeMode.system:
        return '系统主题';
      case theme.ThemeMode.monet:
        return '莫奈取色';
      case theme.ThemeMode.custom:
        return '自定义主题色';
    }
  }

  /// [v2.3.0] 显示颜色选择器
  Future<void> _showColorPicker() async {
    final presetColors = [
      AppThemeColors.babyPink,
      const Color(0xFFFF6B6B),
      const Color(0xFFFFB347),
      const Color(0xFFFFD93D),
      const Color(0xFF6BCB77),
      const Color(0xFF4D96FF),
      const Color(0xFF9D84B7),
      const Color(0xFFFF85A2),
      const Color(0xFF00C9A7),
      const Color(0xFF845EC2),
      const Color(0xFFFF9671),
      const Color(0xFF0081C9),
      const Color(0xFFB0A8B9),
      const Color(0xFFC34A36),
      const Color(0xFF537188),
      const Color(0xFFE2B714),
    ];

    Color? selectedColor;

    await liquid.showLiquidDialog(
      context: context,
      builder: liquid.LiquidGlassDialog(
        title: '选择主题色',
        content: SizedBox(
          width: double.maxFinite,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: presetColors.map((color) {
              return GestureDetector(
                onTap: () {
                  selectedColor = color;
                  Navigator.pop(context);
                },
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          GlassDialogAction(
            label: '取消',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );

    if (selectedColor != null) {
      setState(() => _currentThemeMode = theme.ThemeMode.custom);
      await _themeService.setThemeMode(theme.ThemeMode.custom);
      await _themeService.setCustomColor(selectedColor!);
      if (mounted) {
        setState(() {});
        _showToast('主题色已更新');
      }
    }
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        title,
        style: TextStyle(
          color: _textSecondaryColor,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  static const double kSettingsItemHeight = 56.0;

  Widget _buildCardGroup(List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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

  Widget _buildSwitchRow(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged, {
    bool disabled = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                    color: _textColor.withValues(alpha: disabled ? 0.45 : 1.0),
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: _textSecondaryColor.withValues(alpha: disabled ? 0.45 : 1.0),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          liquid.LiquidSwitch(
            value: value,
            onChanged: disabled ? (v) {} : onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSliderRow({
    required Key sliderKey,
    required String title,
    required String subtitle,
    required IconData icon,
    required String valueText,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    ValueChanged<double>? onChangeEnd,
    bool disabled = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _themeService.primaryColor;
    final double titleAlpha = disabled ? 0.45 : 1.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: Center(
                  child: Icon(
                    icon,
                    color: (isDark
                            ? const Color(0xFFD6DBE5)
                            : const Color(0xFF3A4150))
                        .withValues(alpha: titleAlpha),
                    size: 21,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: _textColor.withValues(alpha: titleAlpha),
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: _textSecondaryColor.withValues(alpha: titleAlpha),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: disabled ? 0.08 : 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  valueText,
                  style: TextStyle(
                    color: disabled
                        ? _textSecondaryColor.withValues(alpha: 0.7)
                        : accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 40, right: 2, top: 2),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4.0,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 15.0),
                activeTrackColor:
                    disabled ? _textSecondaryColor.withValues(alpha: 0.25) : accent,
                inactiveTrackColor: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.09),
                thumbColor: disabled ? _textSecondaryColor : Colors.white,
              ),
              child: Slider(
                key: sliderKey,
                value: value.clamp(min, max),
                min: min,
                max: max,
                onChanged: disabled ? null : onChanged,
                onChangeEnd: disabled ? null : onChangeEnd,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap, {
    Key? rowKey,
    Widget? trailing,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      key: rowKey,
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
                      color: _textColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: _textSecondaryColor,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            trailing ??
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

  void _toggleGlassQuality() async {
    HapticFeedback.selectionClick();
    final currentQuality = theme.ThemeService().glassQuality;
    final newQuality = currentQuality == GlassQuality.premium
        ? GlassQuality.standard
        : GlassQuality.premium;
    await theme.ThemeService().setGlassQuality(newQuality);
    if (!mounted) return;
    setState(() {});
    liquid.showLiquidToast(
      context,
      '已切换至${newQuality == GlassQuality.premium ? "旗舰画质 (Premium)" : "流畅高帧 (Standard)"}模式',
    );
  }
}
