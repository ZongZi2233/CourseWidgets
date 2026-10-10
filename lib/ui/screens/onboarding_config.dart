import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../services/theme_service.dart';
import '../../utils/glass_settings_helper.dart';
import '../widgets/liquid_components.dart' as liquid;
import 'android_schedule_config_screen.dart';

/// [v2.2.8/v2.9.0] 引导页面 - 课时配置
/// 复用现有的课时配置页面，并支持自动持久化与统一液态玻璃折射
class OnboardingConfig extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;
  final bool isLastPage;

  const OnboardingConfig({
    super.key,
    required this.onNext,
    required this.onBack,
    this.isLastPage = true,
  });

  @override
  State<OnboardingConfig> createState() => _OnboardingConfigState();
}

class _OnboardingConfigState extends State<OnboardingConfig> {
  final GlobalKey<AndroidScheduleConfigScreenState> _configKey =
      GlobalKey<AndroidScheduleConfigScreenState>();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            // 1. 嵌入课时配置页面内容 (底层全幅滚动，穿透到顶部与底部，接受折射)
            Positioned.fill(
              child: AndroidScheduleConfigScreen(
                key: _configKey,
                showNavigation: false,
                contentPadding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 140,
                  bottom: MediaQuery.of(context).padding.bottom + 120,
                  left: 20,
                  right: 20,
                ),
              ),
            ),

            // 2. 顶部浮动液态玻璃 Header (置于顶层，穿透折射)
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
                            '课时配置',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: GlassSettingsHelper.getTextColor(context),
                              decoration: TextDecoration.none,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '设置开学日期和课程时间',
                            style: TextStyle(
                              fontSize: 14,
                              color: GlassSettingsHelper.getSecondaryTextColor(context),
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

            // 3. 底部浮动 Navigation 按钮栏（置于顶层，独立液态玻璃折射下方滑动卡片）
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                  child: AdaptiveLiquidGlassLayer(
                    quality: GlassQuality.premium,
                    settings: const LiquidGlassSettings(
                      blur: 3.0,
                      thickness: 16.0,
                      glassColor: Color(0x18FFFFFF),
                      lightIntensity: 0.70,
                      ambientStrength: 0.45,
                      ambientRim: 0.0,
                      fresnelStrength: 0.05,
                      saturation: 1.20,
                      refractiveIndex: 1.40,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: liquid.LiquidButton(
                            text: '上一步',
                            onTap: widget.onBack,
                            color: isDark ? Colors.white.withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.08),
                            textColor: isDark ? Colors.white : const Color(0xFF1E2129),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: liquid.LiquidButton(
                            text: widget.isLastPage ? '开始使用' : '下一步',
                            onTap: () {
                              // [v2.9.0] 显式触发课时配置静默保存并更新课表
                              _configKey.currentState?.saveConfigFromParent();
                              widget.onNext();
                            },
                            color: ThemeService().primaryColor,
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
    );
  }
}
