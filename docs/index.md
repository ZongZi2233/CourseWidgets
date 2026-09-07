# CourseWidgets Codebase Documentation Index

这份文档库旨在详细说明 `CourseWidgets` (v2.5.5+) 每部分代码的功能、联系及相互依赖关系。当功能或架构发生改变时，请同步更新此处的文档。

## 目录结构

*   [lib/main.dart](lib_main.md) - **应用程序入口与初始化**
*   [lib/constants/](dir_constants.md) - **全局常量与主题配置**
*   [lib/models/](dir_models.md) - **核心数据模型与反序列化**
*   [lib/providers/](dir_providers.md) - **全局状态管理中心**
*   [lib/services/](dir_services.md) - **后台服务与各类API交互**
*   [lib/ui/screens/](dir_ui_screens.md) - **应用的主要可见全屏屏幕**
*   [lib/ui/widgets/](dir_ui_widgets.md) - **应用组件与玻璃组件库**
*   [lib/ui/transitions/](dir_ui_transitions.md) - **动画引擎与路由侧滑包装**
*   [lib/utils/](dir_utils.md) - **环境感知与辅组支持函数库**

## 更新维护原则
- 如果新增了屏幕页面（Screen），请立刻在 `dir_ui_screens.md` 中进行说明。
- 数据序列化结构修改后，请调整 `dir_models.md` 中的说明。
- 每篇文档需记录主要导入了哪些关键组件库，以证明其耦合度与引用树。
