import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../providers/schedule_provider.dart';
import '../../services/data_import_service.dart';
import '../../constants/theme_constants.dart';
import '../../services/theme_service.dart'; // Added this import
import '../widgets/liquid_components.dart' as liquid;
import '../widgets/liquid_toast.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'webview_import_screen.dart';
import '../../services/app_logger.dart';
import 'package:smooth_scroll_multiplatform/smooth_scroll_multiplatform.dart';

class SettingsDataScreen extends StatelessWidget {
  const SettingsDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ScheduleProvider>();
    final dataImportService = DataImportService();
    final isDark = ThemeService().isDarkMode; // Added this line

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          AdaptiveLiquidGlassLayer(
        quality: GlassQuality.premium,
        settings: const LiquidGlassSettings(
          blur: 3.0,
          thickness: 24.0,
          glassColor: Color(0x0EFFFFFF),
          lightIntensity: 0.70,
          ambientStrength: 0.45,
          ambientRim: 0.0,
          fresnelStrength: 0.05,
          saturation: 1.20,
          refractiveIndex: 1.46,
        ),
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const liquid.LiquidBackButton(),
                    const SizedBox(width: 8),
                    Text(
                      '数据管理',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: DynMouseScroll(
                durationMS: 250,
                scrollSpeed: 1.2,
                builder: (context, controller, physics) => ListView(
                  controller: controller,
                  padding: const EdgeInsets.all(16),
                  physics: physics,
                  children: [
                    liquid.HyperOSCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '数据操作',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // [v2.5.9] 教务系统导入（WebView）
                          _buildActionCard(
                            '教务系统导入',
                            '',
                            CupertinoIcons.globe,
                            AppThemeColors.babyPink,
                            () {
                              if (Platform.isAndroid ||
                                  Platform.isIOS ||
                                  Platform.isWindows ||
                                  Platform.isMacOS) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const WebviewImportScreen(),
                                  ),
                                );
                              } else {
                                LiquidToast.success(
                                  context,
                                  '桌面端请在浏览器中登录教务系统，下载课表 ICS/HTML 文件后使用下方导入功能',
                                );
                              }
                            },
                          ),
                          _buildActionCard(
                            '导入 ICS 日历',
                            '',
                            Icons.calendar_month_rounded,
                            Colors.orangeAccent,
                            () async {
                              final success = await provider.importData();
                              if (success && context.mounted)
                                _showToast(context, 'ICS 导入成功');
                            },
                          ),
                          _buildActionCard(
                            '导入 HTML 课表',
                            '',
                            Icons.code_rounded,
                            Colors.deepPurpleAccent,
                            () async {
                              final success = await provider.importHtmlData();
                              if (success && context.mounted)
                                _showToast(context, 'HTML 导入成功');
                            },
                          ),
                          _buildActionCard(
                            '导入 JSON 课表',
                            '',
                            Icons.receipt_long_rounded,
                            Colors.blueAccent,
                            () async {
                              final success = await provider.importJsonFile();
                              if (success && context.mounted) {
                                _showToast(context, 'JSON 导入成功，已同步时间配置');
                              }
                            },
                          ),
                          _buildActionCard(
                            '导入测试数据',
                            '',
                            Icons.data_exploration_rounded,
                            Colors.teal,
                            () async {
                              final success = await provider.importFromAssets();
                              if (success && context.mounted)
                                _showToast(context, '测试数据已导入');
                            },
                          ),

                          const SizedBox(height: 16),
                          _buildActionCard(
                            '导出为 ICS',
                            '',
                            Icons.ios_share_rounded,
                            Colors.green,
                            () async {
                              final activeSchedule = await dataImportService
                                  .getActiveSchedule();
                              if (activeSchedule != null) {
                                final path = await dataImportService
                                    .exportHistoryToIcs(activeSchedule['id']);
                                if (path != null && context.mounted)
                                  _showToast(context, 'ICS 已导出到:\n$path');
                              } else {
                                if (context.mounted)
                                  _showToast(context, '未找到当前课表');
                              }
                            },
                          ),
                          _buildActionCard(
                            '导出为 JSON',
                            '',
                            Icons.data_object_rounded,
                            Colors.blueAccent,
                            () async {
                              final success = await provider.exportData();
                              if (success && context.mounted)
                                _showToast(context, 'JSON 导出成功');
                            },
                          ),
                          _buildActionCard(
                            '导出系统诊断与Logcat日志',
                            '',
                            CupertinoIcons.doc_text_viewfinder,
                            Colors.cyanAccent,
                            () async {
                              final path = await AppLogger.exportLogsToPublicDownloads(tag: 'USER_EXPORT');
                              if (context.mounted) {
                                if (path != null) {
                                  _showToast(context, '诊断日志已导出至公共下载目录:\n$path');
                                } else {
                                  _showToast(context, '日志导出失败，请检查存储权限');
                                }
                              }
                            },
                          ),

                          const SizedBox(height: 16),
                          _buildActionCard(
                            '清除所有数据',
                            '',
                            Icons.delete_forever_rounded,
                            Colors.redAccent,
                            () => _confirmClear(context, provider),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    // [v2.2.2] 历史记录管理移到数据管理
                    _buildActionCard(
                      '历史记录管理',
                      '',
                      CupertinoIcons.time,
                      Colors.purpleAccent,
                      () => _showHistoryDialog(
                        context,
                        dataImportService,
                        provider,
                        isDark, // Pass isDark
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // [v2.9.7] 悬浮右下角返回按钮
      const liquid.FloatingLiquidBackButton(),
    ],
  ),
);
  }

  // [v2.2.2] 历史记录对话框
  void _showHistoryDialog(
    BuildContext context,
    DataImportService dataImportService,
    ScheduleProvider provider,
    bool isDark, // isDark is now a parameter
  ) {
    liquid.showLiquidDialog(
      context: context,
      builder: Builder(
        builder: (dialogContext) => liquid.LiquidGlassDialog(
          title: '历史记录',
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: dataImportService.getAllHistory(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CupertinoActivityIndicator(color: Colors.white),
                  );
                }
                final history = snapshot.data!;
                if (history.isEmpty) {
                  return const Center(
                    child: Text(
                      '暂无历史记录',
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final item = history[index];
                    final isActive = item['is_active'] == 1;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GestureDetector(
                        // [v2.7.0] 整行可点击切换课表
                        onTap: isActive
                            ? null
                            : () async {
                                await dataImportService.switchToHistory(
                                  item['id'],
                                );
                                if (dialogContext.mounted) {
                                  Navigator.of(dialogContext).pop();
                                  await provider.loadSavedData();
                                  _showToast(dialogContext, '已切换到该课表');
                                }
                              },
                        child: MouseRegion(
                          cursor: isActive
                              ? SystemMouseCursors.basic
                              : SystemMouseCursors.click,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppThemeColors.babyPink.withValues(
                                      alpha: 0.2,
                                    )
                                  : (isDark
                                        ? Colors.white.withValues(alpha: 0.05)
                                        : Colors.black.withValues(alpha: 0.05)),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isActive
                                    ? AppThemeColors.babyPink.withValues(
                                        alpha: 0.3,
                                      )
                                    : Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['name'],
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${item['semester']} | ${item['source_type']}',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.6),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isActive)
                                  Icon(
                                    CupertinoIcons.checkmark_alt,
                                    color: AppThemeColors.babyPink,
                                    size: 24,
                                  )
                                else
                                  const Icon(
                                    CupertinoIcons.arrow_right_circle,
                                    color: Colors.white70,
                                    size: 22,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            GlassDialogAction(
              label: '关闭',
              isPrimary: true,
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    // [v2.3.0修复] 使用 GestureDetector 确保整个卡片可点击
    final isDark = ThemeService().isDarkMode;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: liquid.HyperOSCard(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ],
        ),
      ),
    );
  }

  // [v2.3.0修复] 使用 LiquidToast 替代 SnackBar
  void _showToast(BuildContext context, String message) {
    LiquidToast.success(context, message);
  }

  void _confirmClear(BuildContext context, ScheduleProvider provider) {
    liquid.showLiquidDialog(
      context: context,
      builder: liquid.LiquidGlassDialog(
        title: '确认清除',
        content: const Text('确定要删除所有数据吗？此操作无法撤销。'),
        actions: [
          GlassDialogAction(
            label: '取消',
            onPressed: () => Navigator.pop(context),
          ),
          GlassDialogAction(
            label: '删除',
            isPrimary: true,
            onPressed: () async {
              await provider.clearData();
              if (context.mounted) {
                // [v2.5.6修复] 清除数据后，重新显示系统启动图动画和重置教程，解决 Windows 端看不到引导页的问题
                Phoenix.rebirth(context);
              }
            },
          ),
        ],
      ),
    );
  }
}
