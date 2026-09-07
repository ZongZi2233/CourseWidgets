# UI Screens - lib/ui/screens

此目录维护着应用所有占据主屏幕并承载路由导航的“核心全屏界面”（Scenes）。这些屏幕主要负责拼接内部子体、组合各种业务容器以展现完整的视觉交互。

## 目录索引

*   `android_liquid_glass_main.dart`: 
    - **移动端应用全局宿主**。以底层 `IndexedStack` 配置课程、日历与设置三大 `Navigator` 图层，拥有常驻底部的自定义高级玻璃导航栏 `GlassBottomBar` 以保证不打断层级间的背景融合。包含了周次与星期控制悬浮玻璃。
*   `windows_custom_window.dart`:
    - **桌面级主宿主窗口**。替代了原有的丑陋标题栏外加边框。负责通过提供内嵌 `Navigator` 挂载路由以防止深度钻取时顶层窗口控制组件与动画丢失。拥有独立的最小化/还原反向生命周期视觉伸缩。
*   `windows_schedule_screen.dart` / `macos_about_screen.dart` 等：
    - 分别对应平台大屏特有的一些布局排列，例如多列扩展模式、并列展示数据面板和独立日历视图，或者符合 macOS 对话框风格的大面积磨砂关于窗。
*   `calendar_view_screen.dart`:
    - **日历沉浸化展示**。使用了原生 Flutter 或第三方库构建时间线条，并附带了底垫 padding 使得其在滑动时能透过导航栏呈现虚化光影。
*   `course_edit_screen.dart` / `course_list_screen.dart`:
    - 有关单一实体 CRUD (创建、读取、更新、删除) 操作及数据载入展现的子路由对话框设计页。在此处实现对特定周课程的可视化配置与数据更新写入。
*   `settings_main_screen.dart` / `settings_general_screen.dart` / `settings_data_screen.dart` / `settings_about_screen.dart`:
    - **强关联的设置抽屉群**。采用了层级下放的配置视图，例如：
        - `GeneralScreen` 处理颜色深度（莫奈色彩）选取。
        - `DataScreen` 主发对 ICS, School系统直导和导出逻辑。
        - `AboutScreen` 是应用的签名页，其中容纳了极具特色的果冻触摸形变的按键以及版本反馈。

## 模块间调用关系
- 每个页面主要通过 `Navigator.push` 直接拉取同目录对象，不采用过多显式中介。
- 需要修改导航机制时，须首先检查 `transitions/smooth_slide_transitions.dart` 以确认未在路由钩子中丢失视觉动画效果。
