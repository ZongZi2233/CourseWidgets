import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/onboarding_service.dart';
import 'onboarding_welcome.dart';
import 'onboarding_theme.dart';
import 'onboarding_config.dart';
import 'onboarding_import.dart';

/// [v2.2.8/v2.9.0] 首次启动引导主框架
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final OnboardingService _onboardingService = OnboardingService();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      HapticFeedback.selectionClick();
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      HapticFeedback.selectionClick();
      _pageController.animateToPage(
        _currentPage - 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeOnboarding() async {
    await _onboardingService.completeOnboarding();

    if (mounted) {
      HapticFeedback.heavyImpact();

      // 直接调用 onComplete 回调平滑过渡进入主页
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(), // 禁用手势滑动
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            children: [
              // 第零步：欢迎页面（高清应用图标 + 品牌介绍）
              OnboardingWelcome(
                onNext: _nextPage,
              ),

              // 第一步：个性化主题设置
              OnboardingTheme(
                onComplete: _nextPage,
                onBack: _previousPage,
                isLastPage: false,
                showBackButton: true,
              ),

              // 第二步：导入课表
              OnboardingImport(
                onNext: _nextPage,
                onBack: _previousPage,
                onComplete: _completeOnboarding,
                isLastPage: false,
              ),

              // 第三步：课时配置与时间自定义确认
              OnboardingConfig(
                onNext: _completeOnboarding,
                onBack: _previousPage,
                isLastPage: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
