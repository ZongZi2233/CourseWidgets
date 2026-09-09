import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../utils/glass_settings_helper.dart';
import '../widgets/liquid_components.dart' as liquid;
import 'android_schedule_config_screen.dart';

/// [v2.2.8/v2.8.7] 引导页面 - 课时配置
/// 复用现有的课时配置页面，并支持自动持久化与统一液态玻璃折射
class OnboardingConfig extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;
  final GlobalKey<AndroidScheduleConfigScreenState> _configKey =
      GlobalKey<AndroidScheduleConfigScreenState>();

  OnboardingConfig({
    super.key,
    required this.onNext,
    required this.onBack,
  });

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
              // 嵌入课时配置页面内容 (全幅滚动，穿透到顶部与底部)
              Positioned.fill(
                child: AndroidScheduleConfigScreen(
                  key: _configKey,
                  showNavigation: false,
                  contentPadding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 130,
                    bottom: MediaQuery.of(context).padding.bottom + 110,
                    left: 20,
                    right: 20,
                  ),
                ),
              ),

              // Header (浮动折射)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                    child: Center(
                      child: liquid.HyperOSCard(
                        cornerRadius: 24,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              '课时配置',
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                color: GlassSettingsHelper.getTextColor(),
                                decoration: TextDecoration.none,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '设置开学日期和课程时间',
                              style: TextStyle(
                                fontSize: 15,
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

              // Navigation (浮动底栏磨砂托盘)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: ShapeDecoration(
                        color: isDark
                            ? const Color(0xCC1E2028)
                            : const Color(0xCCFFFFFF),
                        shape: const RoundedSuperellipseBorder(
                          borderRadius: BorderRadius.all(Radius.circular(24)),
                          side: BorderSide(
                            color: Color(0x22FFFFFF),
                            width: 0.8,
                          ),
                        ),
                        shadows: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: liquid.LiquidButton(
                              text: '上一步',
                              onTap: onBack,
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: liquid.LiquidButton(
                              text: '下一步',
                              onTap: () {
                                // [v2.8.7] 显式触发课时配置静默保存并更新课表
                                _configKey.currentState?.saveConfigFromParent();
                                onNext();
                              },
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
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
}
