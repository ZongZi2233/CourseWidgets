import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../constants/theme_constants.dart';
import '../../services/theme_service.dart';
import '../../utils/glass_settings_helper.dart'; // Added import
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

    // [v2.2.8] 自适应顶部间距：平板16，手机8
    final topPadding = isTablet ? 16.0 : 8.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: AdaptiveLiquidGlassLayer(
        quality: GlassQuality.premium,
        settings: const LiquidGlassSettings(
          blur: 4.0,
          thickness: 16.0,
          glassColor: Color(0x15FFFFFF),
          lightIntensity: 0.75,
          ambientStrength: 0.50,
          ambientRim: 0.18,
          fresnelStrength: 0.85,
          saturation: 1.20,
          refractiveIndex: 1.38,
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
    // [v2.8.4] 迁移官方 GlassCard，享受共享着色器与高光折射，零生硬白边与黑阴影
    return GlassCard(
      shape: const LiquidRoundedSuperellipse(borderRadius: 24),
      quality: GlassQuality.premium,
      useOwnLayer: false,
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            HapticFeedback.lightImpact(); // [v2.4.0] 添加触控震动
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withValues(alpha: 0.8),
                        color.withValues(alpha: 0.4),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: Colors.white, size: 26),
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
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
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
                const Icon(Icons.chevron_right_rounded, color: Colors.white30),
              ],
            ),
          ),
        ),
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
