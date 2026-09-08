import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../utils/glass_settings_helper.dart';
import '../widgets/liquid_components.dart' as liquid;
import 'android_schedule_config_screen.dart';

/// [v2.2.8] 引导页面 - 课时配置
/// 复用现有的课时配置页面
class OnboardingConfig extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;
  
  const OnboardingConfig({
    super.key,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 嵌入课时配置页面内容 (全幅滚动，穿透到顶部与底部)
          Positioned.fill(
            child: AndroidScheduleConfigScreen(
              showNavigation: false,
              contentPadding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 130,
                bottom: MediaQuery.of(context).padding.bottom + 90,
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
                  child: liquid.LiquidCard(
                    borderRadius: 24,
                    padding: 20,
                    quality: GlassQuality.premium,
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

          // Navigation (浮动底栏)
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
                          // 配置会自动保存，直接进入下一步
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
        ],
      ),
    );
  }
}
