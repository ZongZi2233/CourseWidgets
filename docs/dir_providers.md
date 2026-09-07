# Providers - lib/providers

应用的 **全局状态管理大脑**。结合了 `provider` 包与 `ChangeNotifier` 机制。这里将 UI 表现层与下面的 Services、Models 数据层执行完全桥接解耦。

## 原理与核心文件

*   `schedule_provider.dart`: 
    - 极其核心的单一庞大状态树。管理了应用中**课表系统**的整个生命周期结构，包括：
        *   当前所被选定的 `currentWeek`（当前学轴周次）、`currentDay`。
        *   所有的课程记录表 `List<Course> _courses = []`。
        *   开学时间基准 `_semesterStartDate` 的锚定与自动推算逻辑。
    - **方法动作**：提供了一系列行为去“修改状态”并广域触发 `notifyListeners()`，如：
        *   `addCourse()`, `updateCourse()`, `deleteCourse()`: 触发 UI 并异步回写 `StorageService`。
        *   `setCurrentWeek()`, `setSemesterStart()`: 调整视觉展示周期。
    - 所有被 `Consumer<ScheduleProvider>` 或者 `context.watch<ScheduleProvider>()` 包裹的网格、日历都会跟随它的变化产生液态般地无缝过渡刷新效果。

## 关于副作用 (Side-Effects) 的处理
*   Provider 只应当专注于状态的分发更新和业务验证流。具体的后台操作请仍然引入对 `services/` 的调用（例如将解析的负担推给 `DataImportService`）。避免此文件过长。
