# Services - lib/services

此目录包含了应用程序中的非视觉核心**系统服务库**(Services)。主要负责跨越外设和系统通信层、进行数据拉取/解析、持久化状态以及后台运作的包装类。

## 服务索引

*   `storage_service.dart`: 
    - **本地存储与缓存引擎**。封装了腾讯的 `MMKV` 以达到毫秒级的同步持久化能力。接管用户身份标识设定、全局主题序列化存储、开关锁等核心存取。
*   `theme_service.dart`:
    - **主题色彩引擎库**。支持从本机系统、浅/深色自定义预设或者通过 `ColorScheme.fromImageProvider` 动态从图片（相册）提取 Monet（Material You）色板，并通知所有 UI 更新光影环境。
*   `live_notification_service_v2.dart` / `notification_manager.dart`:
    - **通知系统组**。V2 重点集成了 Android 14 兼容的高版本 `flutter_local_notifications` 以及可选的 Foreground/Live 活动常驻进度条提醒。处理不同平台的本地日程警告触发逻辑。管理器则作为顶层门面（Facade）模式提供易用接口。
*   `windows_tray_service.dart`:
    - 针对桌面级应用在 `window_manager` 处理窗口隐藏后的附加挂载组件。通过 `system_tray` 映射出系统任务栏小图标，完成对关闭截拦与系统静默常驻的接管。
*   `data_import_service.dart`:
    - **外部数据解析引擎**。负责处理读取标准 `.ics` 日历文件串，或者专门针对“强智教务管理系统”(qz/hnu) 的原始 JSON，再通过正则映射将其转化为内部适用的标准 `Course` 数组，最终通过 `ScheduleProvider` 存入本地。
*   `background_task_service.dart`:
    - 结合了 `workmanager` 和 `flutter_foreground_task` 等手段的辅助心跳包或定时触发器，保障能在完全关闭软件界面的情形内继续核对“上课时间”。

## 设计模式
- 该目录下的服务多采用**单例模式 (Singleton) 或混入 `ChangeNotifier`**，作为 `main.dart` 中不可分割的基础建设底盘。
- 若需调用获取，请尽量从 Provider 获取引用或依赖注入（DI），以免在各界面重复构造高消耗服务。
