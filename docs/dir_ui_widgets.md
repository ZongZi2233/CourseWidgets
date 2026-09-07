# UI Widgets - lib/ui/widgets

此目录包含了大量无状态 (Stateless) 及极少状态 (Stateful) 的可复用**积木级视觉组件**。这些组件脱离业务流存在，主要为界面提供玻璃拟态化特性。

## 主要文件与功能

*   `liquid_components.dart`: 
    - 应用程序视觉系统的底座。**一切皆玻璃！**
    - 暴露或再封装了外部组件库的底层 API (`liquid_glass_widgets`)。提供 `LiquidCard`, `GlassBottomBar`, `GlassPanel`, `GlassButton` 等通用实体。其特色是将色彩剔透的硬编码统一提取到统一的透明度，从而在亮暗模式与相册壁纸背板间来回折射背景影像，而非独立涂色。
*   `glass_context_menu.dart`: 
    - 右键/长按弹出操作面板的外包装。给予悬浮级阴影，并将操作切割为高反差的磨砂层容器。
*   `glass_time_indicator.dart`: 
    - 在课程/日程网格中，表示当前真实时间流动的一条具备阴影与波纹描边光效的指示横线，具备自动重绘。
*   `weekly_schedule_grid.dart`: 
    - **课程可视化的最核心模块**。通过双轴 `CustomScrollView` + `Sliver` 进行排布的时间/日期十字架坐标系。依赖 `ScheduleProvider` 拿取课程并绘制方块，依赖 `LiquidCard` 实现格子的光泽触感。
*   `course_card.dart` / `current_course_card.dart`: 
    - 单节具体“可操作小卡片”（卡牌）组件。其中负责识别长短双课时合并、是否当前发生、颜色标识等渲染分发任务。
*   `adaptive_dialog.dart` / `animated_toast.dart`: 
    - 对用户系统弹窗动作（Dialog 和 Toast）的适应性补丁。桌面端使用特制的圆角窗扣并搭配模糊进场动画；移动端则视情况采用贴边展示提示或直接全屏。

## 使用规则
*   在此处新增 Widgets 时**严禁**内置强业务服务获取，只能通过传递构造器属性（Props）以保持解耦和组件复用性。
