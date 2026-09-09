import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../constants/theme_constants.dart';
import '../../services/theme_service.dart';
import '../../providers/schedule_provider.dart';
import '../../services/test_data_generator.dart';
import '../../services/database_helper.dart';
import '../../utils/glass_settings_helper.dart';
import '../widgets/liquid_components.dart' as liquid;
import '../widgets/liquid_toast.dart';
import 'webview_import_screen.dart'; // [v2.5.9] 引入教务系统导入

/// [v2.2.8/v2.8.8] 引导页面 - 导入课表
/// 全出血 Stack 架构与 HyperOSCard，抗采样塌陷与通透毛玻璃
class OnboardingImport extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;
  final bool isLastPage;

  const OnboardingImport({
    super.key,
    required this.onNext,
    required this.onBack,
    this.isLastPage = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            // 1. Content (全幅穿透滚动，置于底层，接收折射)
            Positioned.fill(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  MediaQuery.of(context).padding.top + 140,
                  20,
                  MediaQuery.of(context).padding.bottom + 120,
                ),
                physics: const BouncingScrollPhysics(),
                children: [
                    _buildImportOption(
                      context,
                      icon: Icons.language_rounded,
                      title: '从教务系统导入',
                      subtitle: '通过内置浏览器登录并自动抓取',
                      color: Colors.blueAccent,
                      onTap: () => _importFromWebview(context),
                    ),
                    const SizedBox(height: 16),

                    _buildImportOption(
                      context,
                      icon: Icons.insert_drive_file_rounded,
                      title: '从 ICS 文件导入',
                      subtitle: '日程/其他课表软件导出的文件',
                      color: AppThemeColors.babyPink,
                      onTap: () => _importFromICS(context),
                    ),
                    const SizedBox(height: 16),

                    _buildImportOption(
                      context,
                      icon: Icons.code_rounded,
                      title: '从 HTML 文件导入',
                      subtitle: '使用脚本导出的教务系统文件',
                      color: AppThemeColors.softCoral,
                      onTap: () => _importFromHTML(context),
                    ),
                    const SizedBox(height: 16),

                    _buildImportOption(
                      context,
                      icon: Icons.data_object_rounded,
                      title: '从 JSON 数据导入',
                      subtitle: '本软件导出的 JSON 数据文件',
                      color: AppThemeColors.paleApricot,
                      onTap: () => _importFromJSON(context),
                    ),
                    const SizedBox(height: 16),

                    _buildImportOption(
                      context,
                      icon: Icons.science_rounded,
                      title: '导入测试数据',
                      subtitle: '生成模拟课表用于体验',
                      color: Colors.purpleAccent,
                      onTap: () => _importTestData(context),
                    ),
                    const SizedBox(height: 16),

                    _buildImportOption(
                      context,
                      icon: isLastPage
                          ? Icons.check_circle_outline_rounded
                          : Icons.skip_next_rounded,
                      title: isLastPage ? '跳过并开始使用' : '暂时不导入',
                      subtitle: isLastPage ? '直接进入软件，稍后可在设置中导入' : '稍后可在设置中导入',
                      color: isLastPage ? Colors.green : Colors.grey,
                      onTap: onNext,
                    ),
                  ],
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
                        styleType: liquid.LiquidStyleType.standard,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              '导入课表',
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
                              '选择一种方式导入你的课程数据',
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
                            onTap: onBack,
                            color: isDark ? Colors.white.withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.08),
                            textColor: isDark ? Colors.white : const Color(0xFF1E2129),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: liquid.LiquidButton(
                            text: isLastPage ? '开始使用' : '下一步',
                            onTap: onNext,
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

  Widget _buildImportOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return liquid.HyperOSCard(
      cornerRadius: 20,
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.8),
                  color.withValues(alpha: 0.4),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: GlassSettingsHelper.getTextColor(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: GlassSettingsHelper.getSecondaryTextColor(context),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: GlassSettingsHelper.getDisabledTextColor(context),
          ),
        ],
      ),
    );
  }

  Future<void> _importFromICS(BuildContext context) async {
    try {
      HapticFeedback.mediumImpact();

      final provider = context.read<ScheduleProvider>();
      final success = await provider.importData();

      if (context.mounted) {
        if (success) {
          LiquidToast.success(context, 'ICS 导入成功');

          // 延迟后进入下一页
          Future.delayed(const Duration(milliseconds: 800), () {
            if (context.mounted) {
              onNext();
            }
          });
        } else {
          LiquidToast.error(context, 'ICS 导入失败或已取消');
        }
      }
    } catch (e) {
      if (context.mounted) {
        LiquidToast.error(context, '导入失败: $e');
      }
    }
  }

  Future<void> _importFromWebview(BuildContext context) async {
    HapticFeedback.mediumImpact();

    // 打开 Webview 导入页面
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const WebviewImportScreen()),
    );

    // 返回后检查是否有数据
    if (context.mounted) {
      final provider = context.read<ScheduleProvider>();
      if (provider.hasData) {
        LiquidToast.success(context, '教务导入成功');
        Future.delayed(const Duration(milliseconds: 800), () {
          if (context.mounted) {
            onNext();
          }
        });
      }
    }
  }

  Future<void> _importFromHTML(BuildContext context) async {
    try {
      HapticFeedback.mediumImpact();

      final provider = context.read<ScheduleProvider>();
      final success = await provider.importHtmlData();

      if (context.mounted) {
        if (success) {
          LiquidToast.success(context, 'HTML 导入成功');

          // 延迟后进入下一页
          Future.delayed(const Duration(milliseconds: 800), () {
            if (context.mounted) {
              onNext();
            }
          });
        } else {
          LiquidToast.error(context, 'HTML 导入失败或已取消');
        }
      }
    } catch (e) {
      if (context.mounted) {
        LiquidToast.error(context, '导入失败: $e');
      }
    }
  }

  Future<void> _importFromJSON(BuildContext context) async {
    try {
      HapticFeedback.mediumImpact();

      final provider = context.read<ScheduleProvider>();
      final success = await provider.importJsonFile();

      if (context.mounted) {
        if (success) {
          LiquidToast.success(context, 'JSON 导入成功');

          // 延迟后进入下一页
          Future.delayed(const Duration(milliseconds: 800), () {
            if (context.mounted) {
              onNext();
            }
          });
        } else {
          LiquidToast.error(context, 'JSON 导入失败或已取消');
        }
      }
    } catch (e) {
      if (context.mounted) {
        LiquidToast.error(context, '导入失败: $e');
      }
    }
  }

  Future<void> _importTestData(BuildContext context) async {
    try {
      HapticFeedback.mediumImpact();

      // 生成测试数据
      final testCourses = TestDataGenerator.generateTestData();

      // 保存到数据库
      final db = DatabaseHelper.instance;
      await db.insertCourses(testCourses);

      // 重新加载数据
      if (context.mounted) {
        await context.read<ScheduleProvider>().loadSavedData();
      }
      if (!context.mounted) return;

      LiquidToast.success(context, '已导入 ${testCourses.length} 节测试课程');

      // 延迟后进入下一页
      Future.delayed(const Duration(milliseconds: 800), () {
        if (context.mounted) {
          onNext();
        }
      });
    } catch (e) {
      if (context.mounted) {
        LiquidToast.error(context, '导入失败: $e');
      }
    }
  }
}
