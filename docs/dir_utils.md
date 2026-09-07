# Utils - lib/utils

包含纯静态函数的各种底层通用逻辑帮助或工具类封装。旨在提升整个应用的 DRY (Don't Repeat Yourself) 特性，通常不存在内部状态和上下文副作用。

## 文件索引

*   `responsive_utils.dart`: 
    - 包含了 `DeviceType` 检测、窗口大小适配策略。
    - 用以在 UI 代码中调用 `isMobile()`, `isTablet()`, `isWindows()` 以展示两套或三套排版控件结构。
*   `glass_settings_helper.dart`:
    - 非常重要！所有的统一 `LiquidGlassSettings` 构建器汇聚之处。
    - 通过如 `getStandardSettings()`, `getCardSettings()` 返回一个预调好的标准高斯模糊加边框透通白参数集，减少不同开发者手写玻璃的不一致锯齿感。
*   `color_utils.dart` / `time_utils.dart`:
    - 提取并转换类似于 `#FFFFFF` 或者将当前 `DateTime` 组合输出成为 `星期 X / 第 N 周`。
    - 纯辅助无负担单元结构。
