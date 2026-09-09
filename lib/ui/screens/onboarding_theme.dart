import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'dart:io';
import '../../constants/theme_constants.dart';
import '../../main.dart';
import '../../services/storage_service.dart';
import '../../services/theme_service.dart' as theme;
import '../../utils/glass_settings_helper.dart';
import '../widgets/liquid_components.dart' as liquid;
import '../widgets/liquid_toast.dart';
import '../../services/notification_manager.dart';

/// [v2.2.9] 引导页面 - 主题设置
/// 与通用设置保持一致：默认/系统/莫奈三种模式
class OnboardingTheme extends StatefulWidget {
  final VoidCallback onComplete;
  final VoidCallback onBack;
  final bool isLastPage;
  final bool showBackButton;

  const OnboardingTheme({
    super.key,
    required this.onComplete,
    required this.onBack,
    this.isLastPage = false,
    this.showBackButton = false,
  });

  @override
  State<OnboardingTheme> createState() => _OnboardingThemeState();
}

class _OnboardingThemeState extends State<OnboardingTheme> {
  final StorageService _storage = StorageService();
  final theme.ThemeService _themeService = theme.ThemeService();

  theme.ThemeMode _selectedThemeMode = theme.ThemeMode.monet;
  bool _liveActivitiesEnabled = true;

  @override
  void initState() {
    super.initState();
    _liveActivitiesEnabled = NotificationManager().isLiveActivitiesEnabled;
    final savedModeStr = _storage.getString(StorageService.keyThemeMode);
    if (savedModeStr != null) {
      _selectedThemeMode = _themeService.themeMode;
    } else {
      _selectedThemeMode = theme.ThemeMode.monet;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Material(
        type: MaterialType.transparency,
        child: AdaptiveLiquidGlassLayer(
          quality: GlassQuality.premium,
          settings: const LiquidGlassSettings(
            blur: 3.0,
            thickness: 20.0,
            glassColor: Color(0x12FFFFFF),
            lightIntensity: 0.70,
            ambientStrength: 0.45,
            ambientRim: 0.0,
            fresnelStrength: 0.05,
            saturation: 1.20,
            refractiveIndex: 1.46,
          ),
          child: Stack(
            children: [
              // 1. 底层全屏全幅流式滚动区域 (穿透到屏幕顶部和底部，折射完全可见)
              Positioned.fill(
                child: ListView(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 130, // 避让顶部浮动玻璃卡片
                    bottom: MediaQuery.of(context).padding.bottom + 160, // 避让底部操作栏
                    left: 20,
                    right: 20,
                  ),
                physics: const BouncingScrollPhysics(),
                children: [
                  // 主题色模式选择 -> HyperOSCard
                  liquid.HyperOSCard(
                    cornerRadius: 24,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '主题色',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: GlassSettingsHelper.getTextColor(),
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 默认主题
                        _buildThemeModeOption(
                          theme.ThemeMode.defaultMode,
                          '默认主题',
                          '使用应用默认的嫩粉色主题',
                          Icons.palette,
                        ),

                        const SizedBox(height: 12),

                        // 系统主题（仅 Android）
                        if (Platform.isAndroid) ...[
                          _buildThemeModeOption(
                            theme.ThemeMode.system,
                            '系统主题',
                            'Android 12+ Material You 动态颜色',
                            Icons.phone_android,
                          ),
                          const SizedBox(height: 12),
                        ],

                        // 莫奈取色
                        _buildThemeModeOption(
                          theme.ThemeMode.monet,
                          '莫奈取色',
                          '从背景图片提取主题色',
                          Icons.color_lens,
                        ),

                        const SizedBox(height: 12),

                        // [v2.3.0] 自定义主题色
                        _buildThemeModeOption(
                          theme.ThemeMode.custom,
                          '自定义主题色',
                          '选择你喜欢的任意颜色',
                          Icons.palette_outlined,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 实况通知 (Live Activities) -> HyperOSCard
                  liquid.HyperOSCard(
                    cornerRadius: 24,
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppThemeColors.babyPink,
                                AppThemeColors.softCoral,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.bolt_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '实况通知与灵动岛',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: GlassSettingsHelper.getTextColor(),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '支持 Android 16 与 iOS',
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      GlassSettingsHelper.getSecondaryTextColor(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _liveActivitiesEnabled,
                          activeColor: AppThemeColors.babyPink,
                          onChanged: (val) {
                            setState(() => _liveActivitiesEnabled = val);
                            NotificationManager().setLiveActivitiesEnabled(val);
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 背景图片 -> HyperOSCard
                  liquid.HyperOSCard(
                    cornerRadius: 24,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '背景图片',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: GlassSettingsHelper.getTextColor(),
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ValueListenableBuilder<String?>(
                          valueListenable: globalBackgroundPath,
                          builder: (context, path, _) {
                            final hasCustomBg = path != null && path.isNotEmpty;
                            return InkWell(
                              onTap: _pickBackgroundImage,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0x22FFFFFF)
                                      : const Color(0x12000000),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(0x33FFFFFF)
                                        : const Color(0x22000000),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: AppThemeColors.babyPink.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.image_rounded,
                                        color: AppThemeColors.babyPink,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            hasCustomBg ? '已设置自定义壁纸' : '使用内置精美壁纸',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: GlassSettingsHelper.getTextColor(),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            hasCustomBg ? '点击更换相册壁纸' : '点击选择相册或本地壁纸',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: GlassSettingsHelper.getSecondaryTextColor(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: GlassSettingsHelper.getSecondaryTextColor(),
                                      size: 22,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 2. 顶部浮动液态玻璃 Header (穿透折射)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                  child: Center(
                    child: liquid.LiquidCard(
                      borderRadius: 24,
                      padding: 20,
                      quality: GlassQuality.premium,
                      styleType: liquid.LiquidStyleType.standard,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '个性化',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: GlassSettingsHelper.getTextColor(),
                              decoration: TextDecoration.none,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '选择你喜欢的主题色和背景',
                            style: TextStyle(
                              fontSize: 14,
                              color: GlassSettingsHelper.getSecondaryTextColor(),
                              decoration: TextDecoration.none,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 3. 底部浮动 Navigation 按钮栏（纯透光液态按钮 Row 布局）
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                  child: Row(
                    children: [
                      if (widget.showBackButton) ...[
                        Expanded(
                          child: liquid.LiquidButton(
                            text: '上一步',
                            onTap: widget.onBack,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      Expanded(
                        child: liquid.LiquidButton(
                          text: widget.isLastPage ? '完成设置' : '下一步',
                          onTap: _completeOnboarding,
                          color: AppThemeColors.babyPink,
                        ),
                      ),
                    ],
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

  Widget _buildThemeModeOption(
    theme.ThemeMode mode,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final isSelected = _selectedThemeMode == mode;

    return GestureDetector(
      onTap: () async {
        HapticFeedback.selectionClick();

        // [v2.3.0] 自定义主题色需要打开颜色选择器
        if (mode == theme.ThemeMode.custom) {
          await _showColorPicker();
          return;
        }

        setState(() => _selectedThemeMode = mode);

        debugPrint('🎨 用户选择主题: $mode');
        await _themeService.setThemeMode(mode);
        debugPrint('✅ 主题模式已设置: $mode, 当前颜色: ${_themeService.primaryColor}');

        if (mode == theme.ThemeMode.system && Platform.isAndroid && mounted) {
          await _themeService.applySystemTheme(context);
          debugPrint('✅ 系统主题已应用: ${_themeService.primaryColor}');
        } else if (mode == theme.ThemeMode.monet) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final defaultAsset = isDark ? 'asset:assets/Dark.png' : 'asset:assets/Light.png';
          final bgPath = globalBackgroundPath.value ?? defaultAsset;
          await _themeService.extractColorsFromImage(bgPath);
          debugPrint('✅ 莫奈取色已自动应用: ${_themeService.primaryColor}');
        }

        if (mounted) {
          setState(() {}); // 刷新 UI
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    AppThemeColors.babyPink.withValues(alpha: 0.3),
                    AppThemeColors.softCoral.withValues(alpha: 0.3),
                  ],
                )
              : null,
          border: Border.all(
            color: isSelected
                ? AppThemeColors.babyPink.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(
                        colors: [
                          AppThemeColors.babyPink,
                          AppThemeColors.softCoral,
                        ],
                      )
                    : null,
                color: isSelected ? null : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
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
                      color: GlassSettingsHelper.getTextColor(),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: GlassSettingsHelper.getSecondaryTextColor(),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: AppThemeColors.babyPink,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickBackgroundImage() async {
    try {
      if (Platform.isAndroid) {
        // Android 14+ Photo Picker
        const platform = MethodChannel('com.zongzi.schedule/image_picker');
        final String? imagePath = await platform.invokeMethod('pickImage');

        if (imagePath != null && mounted) {
          globalBackgroundPath.value = imagePath;
          await _storage.setString(StorageService.keyBackgroundPath, imagePath);

          // 如果是莫奈取色模式，立即提取颜色
          if (_selectedThemeMode == theme.ThemeMode.monet) {
            await _themeService.extractColorsFromImage(imagePath);
            setState(() {});
          }

          if (mounted) {
            LiquidToast.success(context, '背景已更新');
          }
        }
      } else {
        // Windows/macOS/Linux
        const XTypeGroup typeGroup = XTypeGroup(
          label: 'images',
          extensions: ['jpg', 'jpeg', 'png', 'bmp', 'webp'],
        );

        final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);

        if (file != null && mounted) {
          globalBackgroundPath.value = file.path;
          await _storage.setString(StorageService.keyBackgroundPath, file.path);

          // 如果是莫奈取色模式，立即提取颜色
          if (_selectedThemeMode == theme.ThemeMode.monet) {
            await _themeService.extractColorsFromImage(file.path);
            setState(() {});
          }

          if (mounted) {
            LiquidToast.success(context, '背景已更新');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        LiquidToast.error(context, '选择图片失败: $e');
      }
    }
  }

  Future<void> _completeOnboarding() async {
    HapticFeedback.heavyImpact();

    try {
      // [v2.3.0修复] 确保主题色模式已保存
      await _themeService.setThemeMode(_selectedThemeMode);
      debugPrint('✅ 引导完成 - 主题色模式已保存: $_selectedThemeMode');

      // 应用主题色
      if (_selectedThemeMode == theme.ThemeMode.system && Platform.isAndroid) {
        if (mounted) {
          await _themeService.applySystemTheme(context);
          debugPrint('✅ 引导完成 - 系统主题已应用');
        }
      } else if (_selectedThemeMode == theme.ThemeMode.monet) {
        final bgPath = globalBackgroundPath.value ?? 'asset:assets/Light.png';
        await _themeService.extractColorsFromImage(bgPath);
        debugPrint('✅ 引导完成 - 莫奈取色已应用: ${_themeService.primaryColor}');
      } else if (_selectedThemeMode == theme.ThemeMode.defaultMode) {
        debugPrint('✅ 引导完成 - 默认主题已应用: ${_themeService.primaryColor}');
      } else if (_selectedThemeMode == theme.ThemeMode.custom) {
        debugPrint('✅ 引导完成 - 自定义主题已应用: ${_themeService.primaryColor}');
      }

      // 验证保存的主题模式
      final savedMode = _storage.getString(StorageService.keyThemeMode);
      final savedColor = _storage.getInt(StorageService.keyCustomThemeColor);
      debugPrint('✅ 验证存储 - 主题模式: $savedMode, 颜色: $savedColor');

      // 等待一小段时间确保设置已保存
      await Future.delayed(const Duration(milliseconds: 100));

      // 完成引导
      widget.onComplete();
    } catch (e) {
      debugPrint('❌ 完成引导失败: $e');
      if (mounted) {
        LiquidToast.error(context, '设置保存失败: $e');
      }
    }
  }

  /// [v2.3.0] 显示颜色选择器
  Future<void> _showColorPicker() async {
    // 预设颜色
    final presetColors = [
      AppThemeColors.babyPink, // 默认粉色
      const Color(0xFFFF6B6B), // 红色
      const Color(0xFFFFB347), // 橙色
      const Color(0xFFFFD93D), // 黄色
      const Color(0xFF6BCB77), // 绿色
      const Color(0xFF4D96FF), // 蓝色
      const Color(0xFF9D84B7), // 紫色
      const Color(0xFFFF85A2), // 粉红
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
      setState(() => _selectedThemeMode = theme.ThemeMode.custom);
      await _themeService.setThemeMode(theme.ThemeMode.custom);
      await _themeService.setCustomColor(selectedColor!);
      if (mounted) {
        setState(() {});
        LiquidToast.success(context, '主题色已更新');
      }
    }
  }
}
