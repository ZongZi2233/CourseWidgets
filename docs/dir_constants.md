# Constants - lib/constants

常量包存储了应用的静态预置规则与无需状态管理的字符串定义仓库。

## 主要内容
*   `theme_constants.dart`: 
    - 存储预定义的“应用主题配色”方案，比如 `AppThemeColors.babyPink`, `softCoral` 一类现代、具有较高通透性适配的纯数值化常量。避免全局充斥分散的 Color(...)
*   `app_strings.dart` / `env.dart`:
    - 应用程序内需要固定输出的系统文案，又或者是开发或生产服务器的基础域（baseUrl）常量等。
*   `version.dart`:
    - 保存内部关于/设置页面所需的展示型版本号 (如 `'2.5.4'`)，供其它 UI 直接抽取组合而不必每次进行 PlatformChannel 桥接拿包信息。

## 约定
*   本文件夹内容仅能为 `const`, `static final` 的变量定义或者无状态 `abstract class` 的命名空间集合，不做任何含有副作用的方法调用。
