# Models - lib/models

这里容纳并定义了程序中最抽象的 **纯业务数据结构体 (Entities & Models)**，使得任何 JSON 或外部导入文件流最终都可以规范化校验到这个标准库。

## 文件索引

*   `course.dart`: 
    - 核心业务模型：**课程实体**。
    - 定义了包括 `id`, `name`, `teacher`, `location`, `weeks` (上课的周次数组), `dayOfWeek` (周几), 行列定位 `startSection` & `endSection` 等基本要素。
    - **行为提供**：
        - `toJson()`, `fromJson()`: 提供跨网络环境及本地 MMKV 的标准字符串编解码器。
        - 包含合并课表算法或判断本周是否活跃（`isActiveInWeek`）的逻辑函数。
*   （可能扩展其它支持环境包如 `user_profile.dart`, `school_info.dart` 等辅助配置实体）。

## 高级用法约束
*   这里的包**必须**保持绝对独立。绝不允许内部依赖 UI（比如混入 `Colors` 或者 `Widgets`）。其内部的色彩等标识请用 `String` 的 hex 值代替或通过 `ThemeService` 去解开映射。
