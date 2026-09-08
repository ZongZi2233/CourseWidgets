import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// [v2.8.4] 传感器物理重力倾角与姿态运动服务
/// 基于加速度计物理重力矢量计算屏幕倾斜角，以 30Hz 节流 + 死区滤波驱动 GlassMotionScope
class SensorMotionService {
  static final SensorMotionService _instance = SensorMotionService._internal();
  factory SensorMotionService() => _instance;
  SensorMotionService._internal() {
    _initialize();
  }

  final StreamController<double> _angleController =
      StreamController<double>.broadcast();

  Stream<double> get angleStream => _angleController.stream;

  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  Timer? _fallbackTimer;

  // 默认基准光照角度 (45度 = π/4)
  double _lastEmittedAngle = math.pi / 4;
  double _filteredAx = 0.0;
  double _filteredAy = 9.8;
  int _lastEmitTimestamp = 0;
  bool _hasReceivedSensorData = false;

  void _initialize() {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      _startAccelerometer();
    } else {
      _startAmbientDrift();
    }
  }

  void _startAccelerometer() {
    try {
      _accelSubscription = accelerometerEventStream().listen(
        (AccelerometerEvent event) {
          _hasReceivedSensorData = true;

          // 低通一阶滤波，抹除人手微弱生理震颤
          _filteredAx = _filteredAx * 0.85 + event.x * 0.15;
          _filteredAy = _filteredAy * 0.85 + event.y * 0.15;

          final now = DateTime.now().millisecondsSinceEpoch;
          // 节流至最高 30Hz (最小间隔 33ms)
          if (now - _lastEmitTimestamp < 33) return;

          // 根据物理重力矢量在屏幕平面的投影计算设备绝对物理倾角
          // 手机直立时 (x=0, y=9.8) 倾角为 0，叠加 45度 (π/4) 基础光照
          final double tilt = math.atan2(-_filteredAx, _filteredAy);
          final double targetAngle = (math.pi / 4) + tilt;

          // 死区检测：角度变化大于 0.025 弧度（约 1.5 度）时才广播刷新，静止时 0 绘制
          if ((targetAngle - _lastEmittedAngle).abs() > 0.025) {
            _lastEmittedAngle = targetAngle;
            _lastEmitTimestamp = now;

            if (!_angleController.isClosed) {
              _angleController.add(_lastEmittedAngle);
            }
          }
        },
        onError: (err) {
          debugPrint('加速度传感器不可用: $err，切换到平滑环境光漂移');
          _startAmbientDrift();
        },
      );

      // 若 2 秒内未收到传感器数据（如模拟器），平滑启动环境流
      Future.delayed(const Duration(seconds: 2), () {
        if (!_hasReceivedSensorData && _fallbackTimer == null) {
          _startAmbientDrift();
        }
      });
    } catch (e) {
      debugPrint('启动加速度传感器监听异常: $e');
      _startAmbientDrift();
    }
  }

  /// 桌面端与无传感器环境的极微量正弦呼吸柔光
  void _startAmbientDrift() {
    if (_fallbackTimer != null) return;
    int tick = 0;
    _fallbackTimer = Timer.periodic(const Duration(milliseconds: 120), (timer) {
      tick++;
      // 微弱正弦呼吸漂移 (45° ± 10°)
      final angle = (math.pi / 4) + 0.18 * math.sin(tick * 0.04);
      if (!_angleController.isClosed) {
        _angleController.add(angle);
      }
    });
  }

  void dispose() {
    _accelSubscription?.cancel();
    _fallbackTimer?.cancel();
    _angleController.close();
  }
}
