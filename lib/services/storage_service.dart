import 'package:mmkv/mmkv.dart';
import 'package:flutter/foundation.dart';

/// MMKV 存储服务 - 替代 SharedPreferences
/// 性能更高，支持 AGP 9.0
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  MMKV? _mmkv;
  bool _isInitialized = false;
  final Map<String, dynamic> _memoryFallback = {};

  /// 初始化 MMKV
  Future<void> initialize() async {
    if (_isInitialized && _mmkv != null) return;
    
    try {
      final rootDir = await MMKV.initialize();
      debugPrint('MMKV 初始化成功: $rootDir');
      
      _mmkv = MMKV.defaultMMKV();
      _isInitialized = true;

      // 同步内存兜底数据至 MMKV
      for (final entry in _memoryFallback.entries) {
        final val = entry.value;
        if (val is String) _mmkv?.encodeString(entry.key, val);
        else if (val is int) _mmkv?.encodeInt(entry.key, val);
        else if (val is bool) _mmkv?.encodeBool(entry.key, val);
        else if (val is double) _mmkv?.encodeDouble(entry.key, val);
      }
    } catch (e) {
      debugPrint('MMKV 初始化失败（启用内存安全兜底）: $e');
    }
  }

  /// 确保已初始化（宽容容错）
  void _ensureInitialized() {
    if (!_isInitialized || _mmkv == null) {
      try {
        _mmkv = MMKV.defaultMMKV();
        _isInitialized = true;
      } catch (_) {
        // 保持内存兜底运作，不抛出致命异常中断 UI
      }
    }
  }

  // ==================== String ====================
  
  Future<bool> setString(String key, String value) async {
    _ensureInitialized();
    _memoryFallback[key] = value;
    if (_mmkv != null) {
      return _mmkv!.encodeString(key, value);
    }
    return true;
  }

  String? getString(String key, {String? defaultValue}) {
    _ensureInitialized();
    if (_mmkv != null) {
      final value = _mmkv!.decodeString(key);
      return value ?? defaultValue;
    }
    return (_memoryFallback[key] as String?) ?? defaultValue;
  }

  // ==================== Int ====================
  
  Future<bool> setInt(String key, int value) async {
    _ensureInitialized();
    _memoryFallback[key] = value;
    if (_mmkv != null) {
      return _mmkv!.encodeInt(key, value);
    }
    return true;
  }

  int? getInt(String key, {int? defaultValue}) {
    _ensureInitialized();
    if (_mmkv != null) {
      final value = _mmkv!.decodeInt(key);
      return value == 0 && !_mmkv!.containsKey(key) ? defaultValue : value;
    }
    return (_memoryFallback[key] as int?) ?? defaultValue;
  }

  // ==================== Bool ====================
  
  Future<bool> setBool(String key, bool value) async {
    _ensureInitialized();
    _memoryFallback[key] = value;
    if (_mmkv != null) {
      return _mmkv!.encodeBool(key, value);
    }
    return true;
  }

  bool? getBool(String key, {bool? defaultValue}) {
    _ensureInitialized();
    if (_mmkv != null) {
      if (!_mmkv!.containsKey(key)) return defaultValue;
      return _mmkv!.decodeBool(key);
    }
    return (_memoryFallback[key] as bool?) ?? defaultValue;
  }

  // ==================== Double ====================
  
  Future<bool> setDouble(String key, double value) async {
    _ensureInitialized();
    _memoryFallback[key] = value;
    if (_mmkv != null) {
      return _mmkv!.encodeDouble(key, value);
    }
    return true;
  }

  double? getDouble(String key, {double? defaultValue}) {
    _ensureInitialized();
    if (_mmkv != null) {
      if (!_mmkv!.containsKey(key)) return defaultValue;
      return _mmkv!.decodeDouble(key);
    }
    return (_memoryFallback[key] as double?) ?? defaultValue;
  }

  // ==================== 删除和清空 ====================
  
  Future<bool> remove(String key) async {
    _ensureInitialized();
    _memoryFallback.remove(key);
    if (_mmkv != null) {
      _mmkv!.removeValue(key);
    }
    return true;
  }

  Future<bool> clear() async {
    _ensureInitialized();
    _memoryFallback.clear();
    if (_mmkv != null) {
      _mmkv!.clearAll();
    }
    return true;
  }

  // ==================== 检查键是否存在 ====================
  
  bool containsKey(String key) {
    _ensureInitialized();
    if (_mmkv != null) {
      return _mmkv!.containsKey(key);
    }
    return _memoryFallback.containsKey(key);
  }

  // ==================== 获取所有键 ====================
  
  List<String> getAllKeys() {
    _ensureInitialized();
    if (_mmkv != null) {
      return _mmkv!.allKeys;
    }
    return _memoryFallback.keys.toList();
  }

  // ==================== 常用键定义 ====================
  
  static const String keyDarkMode = 'dark_mode';
  static const String keyAdaptiveDarkMode = 'adaptive_dark_mode';
  static const String keyBackgroundPath = 'background_path';
  static const String keyThemeMode = 'theme_mode'; // 'default', 'system', 'monet'
  static const String keyCustomThemeColor = 'custom_theme_color';
  static const String keyEnableAcrylicBackdrop = 'enable_acrylic_backdrop';
}
