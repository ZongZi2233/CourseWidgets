import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../constants/theme_constants.dart';
import '../../services/theme_service.dart';
import '../../utils/responsive_utils.dart';
import 'new_settings_screen.dart';
import 'settings_general_screen.dart';
import 'settings_about_screen.dart';
import 'settings_data_screen.dart';
import 'settings_notification_screen.dart';
import '../widgets/liquid_components.dart' as liquid;
import '../transitions/smooth_slide_transitions.dart';

/// [v2.8.4] 设置主界面 - 全面迁移官方 GlassCard 与 AdaptiveLiquidGlassLayer
class SettingsMainScreen extends StatefulWidget {
  const SettingsMainScreen({super.key});
  @override
  State<SettingsMainScreen> createState() => _SettingsMainScreenState();
}

class _SettingsMainScreenState extends State<SettingsMainScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService().isDarkMode;
    final isTablet = ResponsiveUtils.isTabletMode(context);

    // [v2.9.8] 自适应顶部间距：平板16，手机80（避开悬浮毛玻璃顶栏64pt并保留16pt呼吸距离，彻底消除重叠）
    final topPadding = isTablet ? 16.0 : 80.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: Stack(
        children: [
          // [v2.10.0] 彻底移除视口预模糊壁纸，让全局高清壁纸清晰透显，与主课表视觉统一
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
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverSafeArea(
              bottom: false,
              sliver: SliverPadding(
                padding: EdgeInsets.fromLTRB(16, topPadding, 16, 120),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildSettingsEntry(
                    title: '课程设置',
                    subtitle: '添加课程、学期配置、课时配置',
                    icon: Icons.school_rounded,
                    color: AppThemeColors.babyPink,
                    onTap: () => _navigateTo(const NewSettingsScreen()),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),
                  _buildSettingsEntry(
                    title: '课程通知',
                    subtitle: '提醒时间、双次提醒、Live Activities',
                    icon: Icons.notifications_rounded,
                    color: AppThemeColors.softCoral,
                    onTap: () =>
                        _navigateTo(const SettingsNotificationScreen()),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),
                  _buildSettingsEntry(
                    title: '通用设置',
                    subtitle: '深色模式、历史记录、背景图片',
                    icon: Icons.tune_rounded,
                    color: AppThemeColors.paleApricot,
                    onTap: () => _navigateTo(const SettingsGeneralScreen()),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),
                  _buildSettingsEntry(
                    title: '数据管理',
                    subtitle: '导入导出、清理数据',
                    icon: Icons.cloud_sync_rounded,
                    color: Colors.blueAccent,
                    onTap: () => _navigateTo(const SettingsDataScreen()),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),
                  _buildSettingsEntry(
                    title: '关于软件',
                    subtitle: '版本信息、开发者信息',
                    icon: Icons.info_outline_rounded,
                    color: Colors.purpleAccent,
                    onTap: () => _navigateTo(const SettingsAboutScreen()),
                    isDark: isDark,
                  ),
                ]),
              ),
            ),
          ),
        ],
      ),
    ),
    ],
    ),
    );
  }

  Widget _buildSettingsEntry({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    // [v2.8.5] 迁移至 HyperOSCard：超椭圆平滑曲率与轻量高斯模糊，带来极低重绘开销与 120Hz 满帧
    return liquid.HyperOSCard(
      cornerRadius: 22,
      padding: const EdgeInsets.all(18),
      onTap: () {
        HapticFeedback.lightImpact(); // [v2.4.0] 添加触控震动
        onTap();
      },
      child: Row(
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: Center(
              child: Icon(
                icon,
                color: isDark ? const Color(0xFFE2E7F0) : const Color(0xFF2C3240),
                size: 26,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: isDark ? Colors.white30 : Colors.black26,
          ),
        ],
      ),
    );
  }

  void _navigateTo(Widget screen) {
    // [v2.3.0修复] 使用 MaterialPageRoute 提供原生流畅动画
    Navigator.push(
      context,
      TransparentMaterialPageRoute(builder: (context) => screen),
    );
  }
}
