import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:system_theme/system_theme.dart';
import 'storage_service.dart';
import '../main.dart'; // For globalUseDarkMode
import '../utils/glass_opacity_manager.dart';

/// 主题模式
enum ThemeMode {
  defaultMode, // 默认主题色（嫩粉色+柔珊瑚）
  system, // 系统主题色（Android 12+ Material You）
  monet, // 莫奈取色（从背景图片提取）
  custom, // 自定义主题色
}

/// 主题服务 - 管理应用主题色
class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  final StorageService _storage = StorageService();

  // 默认主题色
  static const Color defaultPrimaryColor = Color(0xFFFF9A9E); // 嫩粉色
  static const Color defaultSecondaryColor = Color(0xFFFAD0C4); // 柔珊瑚

  // 当前主题色
  Color _primaryColor = defaultPrimaryColor;
  Color _secondaryColor = defaultSecondaryColor;
  ThemeMode _themeMode = ThemeMode.monet; // [v2.9.0] 莫奈取色设为默认色彩模式

  // Getters
  Color get primaryColor => _primaryColor;
  Color get secondaryColor => _secondaryColor;
  ThemeMode get themeMode => _themeMode;

  // [v2.5.0/v2.8.5] 快捷获取深色模式状态
  bool get isDarkMode => globalDarkModeNotifier.value;

  // [v2.8.5] 响应式切换深色模式，实时通知整个应用重新渲染
  void setDarkMode(bool dark) {
    globalDarkModeNotifier.value = dark;
    globalUseDarkMode = dark;
    GlassOpacityManager().setDarkMode(dark);
    if (_themeMode == ThemeMode.monet) {
      refreshMonetColors();
    }
    notifyListeners();
  }

  /// [v2.9.5] 监听壁纸路径或深色模式变动并动态更新莫奈色彩
  void _onBackgroundOrThemeChanged() {
    if (_themeMode == ThemeMode.monet) {
      refreshMonetColors();
    }
  }

  /// [v2.9.5] 动态刷新莫奈取色（根据当前背景壁纸与深浅色模式自动重新取色并广播）
  Future<void> refreshMonetColors() async {
    if (_themeMode != ThemeMode.monet) return;
    final dark = isDarkMode;
    String? bgPath = globalBackgroundPath.value;
    if (bgPath == null || bgPath.isEmpty) {
      bgPath = dark ? 'asset:assets/Dark.png' : 'asset:assets/Light.png';
    } else if (bgPath.startsWith('asset:')) {
      final raw = bgPath.substring(6);
      if (raw == 'assets/Dark.png' || raw == 'assets/Light.png') {
        bgPath = dark ? 'asset:assets/Dark.png' : 'asset:assets/Light.png';
      }
    }
    await extractColorsFromImage(bgPath, brightness: dark ? Brightness.dark : Brightness.light);
  }

  /// 初始化主题服务
  Future<void> initialize() async {
    // 监听壁纸和深色模式全局广播，自动触发动态莫奈重新取色
    globalBackgroundPath.removeListener(_onBackgroundOrThemeChanged);
    globalBackgroundPath.addListener(_onBackgroundOrThemeChanged);
    globalDarkModeNotifier.removeListener(_onBackgroundOrThemeChanged);
    globalDarkModeNotifier.addListener(_onBackgroundOrThemeChanged);

    // 加载保存的主题模式 (Windows 端强制固定为莫奈取色)
    if (Platform.isWindows) {
      _themeMode = ThemeMode.monet;
      await _storage.setString(StorageService.keyThemeMode, ThemeMode.monet.name);
    } else {
      final savedMode = _storage.getString(StorageService.keyThemeMode);
      if (savedMode != null) {
        _themeMode = ThemeMode.values.firstWhere(
          (e) => e.name == savedMode,
          orElse: () => ThemeMode.monet,
        );
      } else {
        _themeMode = ThemeMode.monet;
      }
    }

    // [v2.9.5] 恢复颜色或从壁纸提取默认莫奈色调
    if (_themeMode == ThemeMode.monet) {
      final savedColor = _storage.getInt(StorageService.keyCustomThemeColor);
      if (savedColor != null) {
        _primaryColor = Color(savedColor);
        _secondaryColor = _generateSecondaryColor(_primaryColor);
        debugPrint('✅ 恢复莫奈取色: $_primaryColor');
      }
      // 启动后异步自动校准当前壁纸与深浅色模式色彩
      refreshMonetColors();
    } else if (_themeMode == ThemeMode.defaultMode) {
      _primaryColor = defaultPrimaryColor;
      _secondaryColor = defaultSecondaryColor;
    }

    notifyListeners();
    debugPrint('主题服务初始化完成: $_themeMode');
  }

  /// 设置主题模式
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _storage.setString(StorageService.keyThemeMode, mode.name);

    switch (mode) {
      case ThemeMode.defaultMode:
        _primaryColor = defaultPrimaryColor;
        _secondaryColor = defaultSecondaryColor;
        // [v2.3.0修复] 保存默认颜色到存储
        // 使用 toARGB32() 方法（Flutter 3.33+ 推荐）
        await _storage.setInt(
          StorageService.keyCustomThemeColor,
          _primaryColor.toARGB32(),
        );
        debugPrint(
          '✅ 默认主题已设置: $_primaryColor (ARGB: ${_primaryColor.toARGB32()})',
        );
        break;
      case ThemeMode.system:
        // 系统主题色将在 applySystemTheme 中设置
        debugPrint('✅ 系统主题模式已设置，等待 applySystemTheme 调用');
        break;
      case ThemeMode.monet:
        // 莫奈取色将在 extractColorsFromImage 中设置
        debugPrint('✅ 莫奈取色模式已设置，等待 extractColorsFromImage 调用');
        break;
      case ThemeMode.custom:
        // 自定义主题色将在 setCustomColor 中设置
        debugPrint('✅ 自定义主题色模式已设置，等待 setCustomColor 调用');
        break;
    }

    notifyListeners();
    debugPrint('✅ 主题模式已切换: $mode, 颜色: $_primaryColor');
  }

  /// [v2.3.0] 设置自定义主题色
  Future<void> setCustomColor(Color color) async {
    _primaryColor = color;
    _secondaryColor = _generateSecondaryColor(color);
    await _storage.setInt(
      StorageService.keyCustomThemeColor,
      _primaryColor.toARGB32(),
    );
    notifyListeners();
    debugPrint('✅ 自定义主题色已设置: $_primaryColor');
  }

  /// 应用系统主题色（Android 12+ Material You / Windows 强调色）
  Future<void> applySystemTheme(BuildContext context) async {
    if (Platform.isWindows) {
      try {
        await SystemTheme.fallbackColor;
        _primaryColor = SystemTheme.accentColor.accent;
        _secondaryColor = _generateSecondaryColor(_primaryColor);

        await _storage.setInt(
          StorageService.keyCustomThemeColor,
          _primaryColor.toARGB32(),
        );
        notifyListeners();
        debugPrint('✅ Windows 系统主题色已应用: $_primaryColor');
      } catch (e) {
        debugPrint('获取 Windows 系统主题色失败: $e');
        _primaryColor = defaultPrimaryColor;
        _secondaryColor = defaultSecondaryColor;
        notifyListeners();
      }
      return;
    }

    if (!Platform.isAndroid) {
      debugPrint('系统主题色仅支持 Android 12+ 或 Windows');
      return;
    }

    try {
      // 使用 MethodChannel 获取系统主题色
      const platform = MethodChannel('com.zongzi.schedule/theme');
      final int? systemColor = await platform.invokeMethod(
        'getSystemAccentColor',
      );

      if (systemColor != null) {
        // 使用系统主色调生成调色板
        final corePalette = CorePalette.of(systemColor);
        _primaryColor = Color(corePalette.primary.get(40));
        _secondaryColor = Color(corePalette.secondary.get(40));

        await _storage.setInt(
          StorageService.keyCustomThemeColor,
          _primaryColor.toARGB32(),
        );
        notifyListeners();
        debugPrint('系统主题色已应用: $_primaryColor');
      } else {
        debugPrint('无法获取系统主题色，使用默认主题');
        _primaryColor = defaultPrimaryColor;
        _secondaryColor = defaultSecondaryColor;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('获取系统主题色失败: $e，使用默认主题');
      _primaryColor = defaultPrimaryColor;
      _secondaryColor = defaultSecondaryColor;
      notifyListeners();
    }
  }

  /// 从图片提取莫奈颜色（背景图片取色，自适应深浅色模式）
  Future<void> extractColorsFromImage(String imagePath, {Brightness? brightness}) async {
    try {
      final effectiveBrightness = brightness ?? (isDarkMode ? Brightness.dark : Brightness.light);
      ImageProvider provider;
      if (imagePath.startsWith('asset:')) {
        provider = AssetImage(imagePath.substring(6));
      } else {
        final imageFile = File(imagePath);
        if (!await imageFile.exists()) {
          debugPrint('图片文件不存在: $imagePath');
          return;
        }
        provider = FileImage(imageFile);
      }

      // [v2.5.5修复/v2.9.5升级] 根据传入或当前界面的明度提取原生 Material You 色系
      final colorScheme = await ColorScheme.fromImageProvider(
        provider: provider,
        brightness: effectiveBrightness,
      );

      _primaryColor = colorScheme.primary;
      _secondaryColor = colorScheme.secondary;

      await _storage.setInt(
        StorageService.keyCustomThemeColor,
        _primaryColor.toARGB32(),
      );
      notifyListeners();
      debugPrint('✅ 莫奈取色原生提取完成: $_primaryColor (亮度: $effectiveBrightness)');
    } catch (e) {
      debugPrint('莫奈取色失败: $e');
      _primaryColor = defaultPrimaryColor;
      _secondaryColor = defaultSecondaryColor;
      notifyListeners();
    }
  }

  /// 生成次要颜色（基于主色调）
  Color _generateSecondaryColor(Color primary) {
    final hsl = HSLColor.fromColor(primary);
    return hsl.withLightness((hsl.lightness + 0.1).clamp(0.0, 1.0)).toColor();
  }

  /// 重置为默认主题
  Future<void> resetToDefault() async {
    await setThemeMode(ThemeMode.defaultMode);
    _primaryColor = defaultPrimaryColor;
    _secondaryColor = defaultSecondaryColor;
    await _storage.remove(StorageService.keyCustomThemeColor);
    notifyListeners();
    debugPrint('主题已重置为默认');
  }

  /// 获取主题色的渐变
  LinearGradient getGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_primaryColor, _secondaryColor],
    );
  }

  /// 获取主题色的半透明版本
  Color getPrimaryWithAlpha(double alpha) {
    return _primaryColor.withValues(alpha: alpha);
  }

  Color getSecondaryWithAlpha(double alpha) {
    return _secondaryColor.withValues(alpha: alpha);
  }
}
