import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    final isLandscapePhone = ResponsiveUtils.isLandscapePhone(context);
    final isDesktopOrTablet = ResponsiveUtils.isTabletMode(context) ||
        ResponsiveUtils.isDesktopOrLandscape(context);
    final isLandscape = ResponsiveUtils.isLandscape(context) || isDesktopOrTablet;

    // 自适应顶部与底部内边距：横屏/桌面端充分避让状态栏，手机竖屏预留顶部标题栏与浮动Dock
    final double topPadding;
    if (isLandscape) {
      topPadding = MediaQuery.paddingOf(context).top + 18.0;
    } else {
      topPadding = 80.0;
    }

    final double bottomPadding;
    if (isLandscape) {
      bottomPadding = MediaQuery.paddingOf(context).bottom + 76.0;
    } else {
      bottomPadding = 120.0;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: SafeArea(
        top: false,
        bottom: false,
        child: isLandscape
            ? _buildLandscapeLayout(isDark, topPadding, bottomPadding)
            : _buildPortraitLayout(isDark, topPadding, bottomPadding),
      ),
    );
  }

  /// [v3.0.0 正式版] 横屏与桌面端左右双栏自适应布局（左栏核心功能，右栏数据与关于，安全避让状态栏与边距）
  Widget _buildLandscapeLayout(bool isDark, double topPadding, double bottomPadding) {
    final leftPadding = 20.0 + MediaQuery.paddingOf(context).left;
    final rightPadding = 20.0 + MediaQuery.paddingOf(context).right;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(leftPadding, topPadding, rightPadding, bottomPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左栏：核心功能设置 (50%)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSectionHeader('核心功能设置', isDark),
                _buildCardGroup([
                  _buildSettingsRow(
                    title: '课程设置',
                    subtitle: '添加课程、学期配置、课时配置',
                    icon: Icons.school_rounded,
                    onTap: () => _navigateTo(const NewSettingsScreen()),
                    isDark: isDark,
                  ),
                  _buildSettingsRow(
                    title: '课程通知',
                    subtitle: '提醒时间、双次提醒、Live Activities',
                    icon: Icons.notifications_rounded,
                    onTap: () => _navigateTo(const SettingsNotificationScreen()),
                    isDark: isDark,
                  ),
                  _buildSettingsRow(
                    title: '通用设置',
                    subtitle: '外观、全局玻璃画质、个性化',
                    icon: Icons.tune_rounded,
                    onTap: () => _navigateTo(const SettingsGeneralScreen()),
                    isDark: isDark,
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // 右栏：数据与关于 (50%)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSectionHeader('数据与关于', isDark),
                _buildCardGroup([
                  _buildSettingsRow(
                    title: '数据管理',
                    subtitle: '导入导出、历史备份、清理数据',
                    icon: Icons.cloud_sync_rounded,
                    onTap: () => _navigateTo(const SettingsDataScreen()),
                    isDark: isDark,
                  ),
                  _buildSettingsRow(
                    title: '关于软件',
                    subtitle: '版本信息、开源协议、检查更新',
                    icon: Icons.info_outline_rounded,
                    onTap: () => _navigateTo(const SettingsAboutScreen()),
                    isDark: isDark,
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 手机竖屏经典单列滚动布局
  Widget _buildPortraitLayout(bool isDark, double topPadding, double bottomPadding) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(16, topPadding, 16, bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('核心功能设置', isDark),
          _buildCardGroup([
            _buildSettingsRow(
              title: '课程设置',
              subtitle: '添加课程、学期配置、课时配置',
              icon: Icons.school_rounded,
              onTap: () => _navigateTo(const NewSettingsScreen()),
              isDark: isDark,
            ),
            _buildSettingsRow(
              title: '课程通知',
              subtitle: '提醒时间、双次提醒、Live Activities',
              icon: Icons.notifications_rounded,
              onTap: () => _navigateTo(const SettingsNotificationScreen()),
              isDark: isDark,
            ),
            _buildSettingsRow(
              title: '通用设置',
              subtitle: '外观、全局玻璃画质、个性化',
              icon: Icons.tune_rounded,
              onTap: () => _navigateTo(const SettingsGeneralScreen()),
              isDark: isDark,
            ),
          ]),
          const SizedBox(height: 20),
          _buildSectionHeader('数据与关于', isDark),
          _buildCardGroup([
            _buildSettingsRow(
              title: '数据管理',
              subtitle: '导入导出、历史备份、清理数据',
              icon: Icons.cloud_sync_rounded,
              onTap: () => _navigateTo(const SettingsDataScreen()),
              isDark: isDark,
            ),
            _buildSettingsRow(
              title: '关于软件',
              subtitle: '版本信息、开源协议、检查更新',
              icon: Icons.info_outline_rounded,
              onTap: () => _navigateTo(const SettingsAboutScreen()),
              isDark: isDark,
            ),
          ]),
        ],
      ),
    );
  }

  static const double kSettingsItemHeight = 58.0;

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white54 : Colors.black45,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildCardGroup(List<Widget> children) {
    final isDark = ThemeService().isDarkMode;
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

  Widget _buildSettingsRow({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
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
                  color: isDark ? const Color(0xFFD6DBE5) : const Color(0xFF3A4150),
                  size: 24,
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
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
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
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateTo(Widget screen) {
    Navigator.push(
      context,
      TransparentMaterialPageRoute(builder: (context) => screen),
    );
  }
}

