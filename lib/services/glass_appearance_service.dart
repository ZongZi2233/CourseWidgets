import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'storage_service.dart';

/// [v3.2.4] 全应用玻璃材质与全局界面高斯模糊统一响应式配置服务
///
/// 严格遵循三项相互独立且边界受控的参数规范：
/// 1. [glassOpacity]（玻璃透明度 / 白值）：范围 `[0.0 .. 1.0]`，允许 0% 完全透明，也允许 100% 完全不透明；
///    当达到完全不透明（`>= 0.995`）时，自动跳过玻璃组件的高斯模糊渲染以节省 GPU 带宽；
/// 2. [glassBlur]（玻璃高斯模糊度）：范围 `[0.0 .. 28.0]`，仅控制玻璃组件自身的磨砂模糊强度，
///    与全局界面高斯模糊彻底解耦；
/// 3. [globalUiBlur]（全局界面高斯模糊度）：范围 `[3.0 .. 14.0]`，仅控制弹窗背景幕布、状态栏渐进模糊、
///    滑动动态模糊等非玻璃全局 UI 模糊，不影响玻璃组件自身模糊，且禁止完全关闭（`min > 0`）或设得过大（`max <= 14.0`）。
class GlassAppearanceService extends ChangeNotifier {
  GlassAppearanceService._();
  static final GlassAppearanceService instance = GlassAppearanceService._();

  // ── 玻璃透明度（白值）边界与默认值 ──────────────────────────────────────────
  static const double minGlassOpacity = 0.0;
  static const double maxGlassOpacity = 1.0;
  static const double defaultGlassOpacity = 0.35;
  static const double opaqueBypassThreshold = 0.995;

  // ── 玻璃高斯模糊度边界与默认值 ──────────────────────────────────────────────
  static const double minGlassBlur = 0.0;
  static const double maxGlassBlur = 28.0;
  static const double defaultGlassBlur = 12.0;

  // ── 全局界面高斯模糊度边界与默认值（不可完全关闭，不可过大） ────────────────
  static const double minGlobalUiBlur = 3.0;
  static const double maxGlobalUiBlur = 14.0;
  static const double defaultGlobalUiBlur = 6.5;

  final StorageService _storage = StorageService();
  bool _initialized = false;

  double _glassOpacity = defaultGlassOpacity;
  double _glassBlur = defaultGlassBlur;
  double _globalUiBlur = defaultGlobalUiBlur;

  double get glassOpacity => _glassOpacity;
  double get glassBlur => _glassBlur;
  double get globalUiBlur => _globalUiBlur;

  /// 当玻璃白值/不透明度达到完全不透明时，理论与渲染上均自动跳过玻璃高斯模糊
  bool get isGlassOpaque => _glassOpacity >= opaqueBypassThreshold;

  /// 当玻璃处于完全透明区间
  bool get isGlassTransparent => _glassOpacity <= 0.005;

  /// 玻璃有效模糊强度（完全不透明时强制归零，独立于全局 UI 模糊）
  double get effectiveGlassBlur => isGlassOpaque ? 0.0 : _glassBlur;

  /// 是否需要为玻璃组件挂载模糊管线（`BackdropFilter` / 静态背景采样）
  bool get shouldRenderGlassBlur => !isGlassOpaque && _glassBlur > 0.05;

  /// 当前参数是否均处于出厂默认状态
  bool get isDefault =>
      (_glassOpacity - defaultGlassOpacity).abs() < 0.005 &&
      (_glassBlur - defaultGlassBlur).abs() < 0.05 &&
      (_globalUiBlur - defaultGlobalUiBlur).abs() < 0.05;

  /// 全局界面模糊相对默认基准 (`6.5`) 的倍率（恒 > 0，独立于玻璃模糊）
  double get globalUiBlurScale => _globalUiBlur / defaultGlobalUiBlur;

  /// 从 MMKV 恢复并钳制三项材质参数
  Future<void> initialize() async {
    final savedOpacity = _storage.getDouble(StorageService.keyGlassOpacity);
    final savedBlur = _storage.getDouble(StorageService.keyGlassBlur);
    final savedGlobalBlur = _storage.getDouble(StorageService.keyGlobalUiBlur);

    _glassOpacity = _clampOpacity(savedOpacity ?? defaultGlassOpacity);
    _glassBlur = _clampGlassBlur(savedBlur ?? defaultGlassBlur);
    _globalUiBlur = _clampGlobalUiBlur(savedGlobalBlur ?? defaultGlobalUiBlur);
    _initialized = true;
    notifyListeners();
  }

  static double _clampOpacity(double value) {
    if (!value.isFinite) return defaultGlassOpacity;
    return value.clamp(minGlassOpacity, maxGlassOpacity).toDouble();
  }

  static double _clampGlassBlur(double value) {
    if (!value.isFinite) return defaultGlassBlur;
    return value.clamp(minGlassBlur, maxGlassBlur).toDouble();
  }

  static double _clampGlobalUiBlur(double value) {
    if (!value.isFinite) return defaultGlobalUiBlur;
    return value.clamp(minGlobalUiBlur, maxGlobalUiBlur).toDouble();
  }

  /// 更新玻璃透明度（白值）
  void setGlassOpacity(double value, {bool persist = true}) {
    final clamped = _clampOpacity(value);
    final changed = (clamped - _glassOpacity).abs() >= 0.001;
    if (changed) {
      _glassOpacity = clamped;
      notifyListeners();
    }
    if (persist) {
      _storage.setDouble(StorageService.keyGlassOpacity, clamped);
    }
  }

  /// 更新玻璃高斯模糊度（独立于全局界面高斯模糊）
  void setGlassBlur(double value, {bool persist = true}) {
    final clamped = _clampGlassBlur(value);
    final changed = (clamped - _glassBlur).abs() >= 0.01;
    if (changed) {
      _glassBlur = clamped;
      notifyListeners();
    }
    if (persist) {
      _storage.setDouble(StorageService.keyGlassBlur, clamped);
    }
  }

  /// 更新全局界面高斯模糊度（独立于玻璃模糊，且受限于 `[3.0, 14.0]`）
  void setGlobalUiBlur(double value, {bool persist = true}) {
    final clamped = _clampGlobalUiBlur(value);
    final changed = (clamped - _globalUiBlur).abs() >= 0.01;
    if (changed) {
      _globalUiBlur = clamped;
      notifyListeners();
    }
    if (persist) {
      _storage.setDouble(StorageService.keyGlobalUiBlur, clamped);
    }
  }

  /// 恢复全部三项玻璃与模糊参数到出厂默认值
  Future<void> resetToDefaults() async {
    _glassOpacity = defaultGlassOpacity;
    _glassBlur = defaultGlassBlur;
    _globalUiBlur = defaultGlobalUiBlur;
    await Future.wait([
      _storage.setDouble(StorageService.keyGlassOpacity, defaultGlassOpacity),
      _storage.setDouble(StorageService.keyGlassBlur, defaultGlassBlur),
      _storage.setDouble(StorageService.keyGlobalUiBlur, defaultGlobalUiBlur),
    ]);
    notifyListeners();
  }

  /// 分段线性映射表层不透明度：
  /// - 在 `defaultGlassOpacity (0.35)` 时 100% 精准保持组件原始 `defaultAlpha`
  /// - 向下到 `0.0` 时线性平滑收敛至 `0.0`（完全透明）
  /// - 向上到 `1.0` 时线性平滑提升至 `1.0`（完全不透明）
  double resolveSurfaceAlpha(double defaultAlpha) {
    final baseAlpha = defaultAlpha.clamp(0.0, 1.0);
    if (_glassOpacity <= 0.001) return 0.0;
    if (_glassOpacity >= opaqueBypassThreshold) return 1.0;

    if (_glassOpacity <= defaultGlassOpacity) {
      return (baseAlpha * (_glassOpacity / defaultGlassOpacity))
          .clamp(0.0, 1.0);
    }
    final t = (_glassOpacity - defaultGlassOpacity) /
        (opaqueBypassThreshold - defaultGlassOpacity);
    return (baseAlpha + (1.0 - baseAlpha) * t).clamp(0.0, 1.0);
  }

  /// 默认不透明表面色（用于高不透明度与完全不透明模式，确保深浅主题观感纯净且对比清晰）
  Color defaultOpaqueSurfaceColor(bool isDark) {
    return isDark ? const Color(0xFF1A1E28) : const Color(0xFFF6F8FC);
  }

  /// 依据当前玻璃白值与深浅色主题解析最终玻璃表面底色
  Color resolveGlassColor({
    required Color baseColor,
    required bool isDark,
    double? defaultAlphaOverride,
    Color? opaqueColorOverride,
  }) {
    final targetAlpha = resolveSurfaceAlpha(
      defaultAlphaOverride ?? baseColor.a,
    );

    final Color opaqueTarget;
    if (opaqueColorOverride != null) {
      opaqueTarget = opaqueColorOverride.withValues(alpha: 1.0);
    } else {
      final solidBase = baseColor.withValues(alpha: 1.0);
      final maxChannel = math.max(solidBase.r, math.max(solidBase.g, solidBase.b));
      final minChannel = math.min(solidBase.r, math.min(solidBase.g, solidBase.b));
      final chroma = maxChannel - minChannel;
      opaqueTarget =
          chroma > 0.16 ? solidBase : defaultOpaqueSurfaceColor(isDark);
    }

    if (isGlassOpaque) {
      return opaqueTarget;
    }
    if (_glassOpacity <= defaultGlassOpacity) {
      return baseColor.withValues(alpha: targetAlpha);
    }
    final t = ((_glassOpacity - defaultGlassOpacity) /
            (opaqueBypassThreshold - defaultGlassOpacity))
        .clamp(0.0, 1.0);
    final blendedRgb = Color.lerp(
          baseColor.withValues(alpha: 1.0),
          opaqueTarget,
          t,
        ) ??
        opaqueTarget;
    return blendedRgb.withValues(alpha: targetAlpha);
  }

  /// 解析玻璃组件自身的高斯模糊半径（与 [globalUiBlur] 完全隔离）：
  /// - 当玻璃处于完全不透明 (`isGlassOpaque`) 或 `glassBlur <= 0.05` 时强制返回 `0.0`（跳过模糊渲染）；
  /// - 在默认值 `12.0` 时严格等于 `defaultSigma`；
  /// - 高于默认值时按区间平滑增稠（对超通透折射玻璃封顶于 [maxUltraLightSigma] 以保留边缘折射，对 BackdropFilter/大模糊组件延伸至 [maxSigma]）。
  double resolveGlassBlur(
    double defaultSigma, {
    double maxSigma = maxGlassBlur,
    double maxUltraLightSigma = 8.0,
  }) {
    if (isGlassOpaque || _glassBlur <= 0.05) {
      return 0.0;
    }
    if (defaultSigma <= 0.0) {
      return 0.0;
    }
    if (_glassBlur <= defaultGlassBlur) {
      return (defaultSigma * (_glassBlur / defaultGlassBlur))
          .clamp(0.0, math.max(maxSigma, defaultSigma));
    }
    final double upperTarget = defaultSigma < 4.0
        ? math.min(maxSigma, maxUltraLightSigma)
        : math.max(defaultSigma, maxSigma);
    final double t = (_glassBlur - defaultGlassBlur) /
        (maxGlassBlur - defaultGlassBlur);
    return (defaultSigma + (upperTarget - defaultSigma) * t)
        .clamp(0.0, math.max(maxSigma, defaultSigma));
  }

  /// 解析全局非玻璃 UI 高斯模糊强度（弹窗背景幕布、状态栏渐进模糊、滑动动态模糊等）：
  /// - 严格独立于玻璃模糊与玻璃透明度（即使玻璃完全不透明，全局界面模糊仍正常受控生效）；
  /// - 严格禁止关闭至 `0` 或超限设大。
  double resolveGlobalUiBlur(
    double defaultSigma, {
    double? minSigma,
    double? maxSigma,
  }) {
    final safeDefault = math.max(1.0, defaultSigma);
    final minAllowed = math.max(
      0.8,
      minSigma ?? (safeDefault * (minGlobalUiBlur / defaultGlobalUiBlur)),
    );
    final maxAllowed = math.max(
      minAllowed,
      maxSigma ?? (safeDefault * (maxGlobalUiBlur / defaultGlobalUiBlur)),
    );
    final scaled = safeDefault * globalUiBlurScale;
    return scaled.clamp(minAllowed, maxAllowed).toDouble();
  }

  /// 将当前玻璃白值与玻璃模糊统一注入任意 `LiquidGlassSettings`
  LiquidGlassSettings applyToSettings(
    LiquidGlassSettings base, {
    required bool isDark,
    double? defaultAlpha,
    double? defaultBlur,
    Color? opaqueColorOverride,
    double maxBlur = maxGlassBlur,
    double maxUltraLightBlur = 8.0,
  }) {
    final resolvedColor = resolveGlassColor(
      baseColor: base.glassColor,
      isDark: isDark,
      defaultAlphaOverride: defaultAlpha,
      opaqueColorOverride: opaqueColorOverride,
    );
    final double rawBlur = defaultBlur ?? base.blur;
    final double resolvedBlur = rawBlur <= 0.0
        ? 0.0
        : resolveGlassBlur(
            rawBlur,
            maxSigma: maxBlur,
            maxUltraLightSigma: maxUltraLightBlur,
          );
    return base.copyWith(
      glassColor: resolvedColor,
      blur: resolvedBlur,
    );
  }

  bool get isInitialized => _initialized;
}
