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
import '../widgets/immersive_status_bar_backdrop.dart';
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

    final topPadding = MediaQuery.paddingOf(context).top + 54;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 1. 全出血自由滑动内容区：穿透顶栏与状态栏，消除截断，满帧 120 FPS
          Positioned.fill(
            child: DynMouseScroll(
              durationMS: 250,
              scrollSpeed: 1.2,
              builder: (context, controller, physics) => ListView(
                controller: controller,
                padding: EdgeInsets.fromLTRB(16, topPadding, 16, 100),
                physics: physics,
                children: [
                        // [v3.0.0] 大卡片 1：数据导入
                        _buildSectionHeader('数据导入', isDark),
                        _buildCardGroup([
                          _buildActionRow(
                            '教务系统导入',
                            '支持超星、正方、青果等主流系统',
                            CupertinoIcons.globe,
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
                            isDark,
                          ),
                          _buildActionRow(
                            '导入 ICS 日历',
                            '通用日历 iCalendar 格式文件',
                            Icons.calendar_month_rounded,
                            () async {
                              final success = await provider.importData();
                              if (success && context.mounted) {
                                _showToast(context, 'ICS 导入成功');
                              }
                            },
                            isDark,
                          ),
                          _buildActionRow(
                            '导入 HTML 课表',
                            '教务网课程表离线网页文件',
                            Icons.code_rounded,
                            () async {
                              final success = await provider.importHtmlData();
                              if (success && context.mounted) {
                                _showToast(context, 'HTML 导入成功');
                              }
                            },
                            isDark,
                          ),
                          _buildActionRow(
                            '导入 JSON 课表',
                            '备份数据与自定义时间配置',
                            Icons.receipt_long_rounded,
                            () async {
                              final success = await provider.importJsonFile();
                              if (success && context.mounted) {
                                _showToast(context, 'JSON 导入成功，已同步时间配置');
                              }
                            },
                            isDark,
                          ),
                          _buildActionRow(
                            '导入测试数据',
                            '加载官方示例课表快速体验',
                            Icons.data_exploration_rounded,
                            () async {
                              final success = await provider.importFromAssets();
                              if (success && context.mounted) {
                                _showToast(context, '测试数据已导入');
                              }
                            },
                            isDark,
                          ),
                        ], isDark),

                        const SizedBox(height: 20),

                        // [v3.0.0] 大卡片 2：数据导出
                        _buildSectionHeader('数据导出', isDark),
                        _buildCardGroup([
                          _buildActionRow(
                            '导出为 ICS 日历',
                            '供手机日历与其他应用同步显示',
                            Icons.ios_share_rounded,
                            () async {
                              final path = await dataImportService.exportCurrentScheduleToIcs();
                              if (path != null && context.mounted) {
                                _showToast(context, 'ICS 日历已成功导出到:\n$path');
                              } else if (context.mounted) {
                                _showToast(context, '当前课表为空，无法导出');
                              }
                            },
                            isDark,
                          ),
                          _buildActionRow(
                            '导出为 JSON',
                            '完整导出包含作息时间与所有课程',
                            Icons.data_object_rounded,
                            () async {
                              final success = await provider.exportData();
                              if (success && context.mounted) {
                                _showToast(context, 'JSON 导出成功');
                              }
                            },
                            isDark,
                          ),
                          _buildActionRow(
                            '导出系统诊断与日志',
                            '导出 Logcat 日志至公共下载目录',
                            CupertinoIcons.doc_text_viewfinder,
                            () async {
                              final path = await AppLogger.exportLogsToPublicDownloads(
                                tag: 'USER_EXPORT',
                              );
                              if (context.mounted) {
                                if (path != null) {
                                  _showToast(context, '诊断日志已导出至公共下载目录:\n$path');
                                } else {
                                  _showToast(context, '日志导出失败，请检查存储权限');
                                }
                              }
                            },
                            isDark,
                          ),
                        ], isDark),

                        const SizedBox(height: 20),

                        // [v3.0.0] 大卡片 3：维护与管理（清除数据红色标记）
                        _buildSectionHeader('维护与管理', isDark),
                        _buildCardGroup([
                          _buildActionRow(
                            '历史记录管理',
                            '查看与切换已导入的历史课表版本',
                            CupertinoIcons.time,
                            () => _showHistoryDialog(
                              context,
                              dataImportService,
                              provider,
                              isDark,
                            ),
                            isDark,
                          ),
                          _buildActionRow(
                            '清除所有数据',
                            '删除所有已保存课程及作息配置',
                            Icons.delete_forever_rounded,
                            () => _confirmClear(context, provider),
                            isDark,
                            isDestructive: true,
                          ),
                        ], isDark),

                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),

          // 2. 状态栏微模糊避让 (0..48dp)
          const ImmersiveStatusBarBackdrop(),

          // 3. 悬浮标题栏
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Text(
                      '数据管理',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4. [v2.9.7] 悬浮右下角返回按钮
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

  static const double kSettingsItemHeight = 56.0;

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white60 : const Color(0xFF6B7280),
        ),
      ),
    );
  }

  Widget _buildCardGroup(List<Widget> children, bool isDark) {
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.05);

    return liquid.HyperOSCard(
      cornerRadius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 0.6,
                indent: 48,
                color: dividerColor,
              ),
            children[i],
          ],
        ],
      ),
    );
  }

  Widget _buildActionRow(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
    bool isDark, {
    bool isDestructive = false,
  }) {
    final primaryColor = isDestructive
        ? const Color(0xFFFF5252)
        : (isDark ? Colors.white : const Color(0xFF1B1D24));
    final iconColor = isDestructive
        ? const Color(0xFFFF5252)
        : (isDark ? const Color(0xFFD6DBE5) : const Color(0xFF3A4150));
    final subColor = isDestructive
        ? const Color(0xFFFF5252).withValues(alpha: 0.7)
        : (isDark ? Colors.white60 : const Color(0xFF718096));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: kSettingsItemHeight,
        child: Row(
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: Center(
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: subColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.right_chevron,
              color: isDestructive
                  ? const Color(0xFFFF5252).withValues(alpha: 0.6)
                  : (isDark ? Colors.white38 : Colors.black26),
              size: 15,
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
