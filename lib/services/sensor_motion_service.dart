import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// [v2.8.0] 传感器光照与姿态运动服务
/// 用于捕获设备陀螺仪与加速度，转换为动态光照角度弧度流，供 GlassMotionScope 使用
class SensorMotionService {
  static final SensorMotionService _instance = SensorMotionService._internal();
  factory SensorMotionService() => _instance;
  SensorMotionService._internal() {
    _initialize();
  }

  final StreamController<double> _angleController =
      StreamController<double>.broadcast();

  Stream<double> get angleStream => _angleController.stream;

  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  Timer? _fallbackTimer;

  // 默认光照角度 (π/4 = 45度)
  double _currentAngle = math.pi / 4;
  double _filteredVx = 0.0;
  double _filteredVy = 0.0;
  bool _hasReceivedGyroData = false;

  void _initialize() {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      _startGyroscope();
    } else {
      _startAmbientDrift();
    }
  }

  void _startGyroscope() {
    try {
      _gyroSubscription = gyroscopeEventStream().listen(
        (GyroscopeEvent event) {
          _hasReceivedGyroData = true;

          // 低通滤波减少手震抖动
          _filteredVx = _filteredVx * 0.80 + event.x * 0.20;
          _filteredVy = _filteredVy * 0.80 + event.y * 0.20;

          // 依据设备角速度计算微小倾角偏移
          // 基础光角 45° (约 0.785 弧度)
          final double delta = math.atan2(_filteredVy, _filteredVx);
          final double speed = math.sqrt(_filteredVx * _filteredVx + _filteredVy * _filteredVy);

          if (speed > 0.05) {
            _currentAngle = (math.pi / 4) + (delta * 0.35);
          }

          if (!_angleController.isClosed) {
            _angleController.add(_currentAngle);
          }
        },
        onError: (err) {
          debugPrint('陀螺仪传感器不可用: $err，切换到环境光漂移模式');
          _startAmbientDrift();
        },
      );

      // 若 2 秒内未收到任何陀螺仪数据（如模拟器），启动平滑环境流
      Future.delayed(const Duration(seconds: 2), () {
        if (!_hasReceivedGyroData && _fallbackTimer == null) {
          _startAmbientDrift();
        }
      });
    } catch (e) {
      debugPrint('启动陀螺仪监听异常: $e');
      _startAmbientDrift();
    }
  }

  /// 桌面端与无传感器设备的环境柔光微动
  void _startAmbientDrift() {
    if (_fallbackTimer != null) return;
    int tick = 0;
    _fallbackTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      tick++;
      // 微弱正弦呼吸漂移 (45° ± 15°)
      final angle = (math.pi / 4) + 0.25 * math.sin(tick * 0.05);
      if (!_angleController.isClosed) {
        _angleController.add(angle);
      }
    });
  }

  void dispose() {
    _gyroSubscription?.cancel();
    _fallbackTimer?.cancel();
    _angleController.close();
  }
}
