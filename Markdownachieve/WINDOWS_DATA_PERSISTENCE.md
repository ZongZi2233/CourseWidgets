# Windows 数据持久化说明

## 问题

每次构建 Windows 端后，即使清理了 `build` 文件夹，应用仍然保留了之前的课程数据和设置。

## 原因

这是**正常的设计行为**，因为：

### 1. MMKV 数据存储位置

MMKV 数据存储在用户目录下，**不在项目的 build 文件夹中**：

```
Windows: C:\Users\[用户名]\AppData\Local\[应用名称]\mmkv\
```

### 2. SQLite 数据库位置

SQLite 数据库也存储在用户目录下：

```
Windows: C:\Users\[用户名]\AppData\Local\[应用名称]\databases\
```

### 3. 为什么这样设计？

- **数据持久化** - 用户的课程数据、设置应该在应用重启后保留
- **用户体验** - 用户不希望每次打开应用都要重新导入数据
- **标准做法** - 所有桌面应用都是这样设计的

---

## 清除数据的方法

### 方法 1: 使用应用内的"清除所有数据"功能 ✅ 推荐

1. 打开应用
2. 进入 **设置** → **数据管理**
3. 点击 **"清除所有数据"**
4. 确认删除

**效果：**
- ✅ 清除所有课程数据（数据库）
- ✅ 清除课程配置（开学日期、课时配置等）
- ✅ 保留用户设置（主题、深色模式、背景图片等）

**代码实现：**
```dart
// lib/providers/schedule_provider.dart
Future<void> clearData() async {
  // 清除数据库中的课程数据
  await _importService.clearAllData();
  
  // [v2.3.0修复] 清除 MMKV 中的课程相关配置
  final storage = StorageService();
  await storage.remove('semester_start_date');
  await storage.remove('schedule_config');
  await storage.remove('current_week');
  await storage.remove('current_day');
  
  // 重置状态
  _courses = [];
  _currentWeek = 1;
  _currentDay = 1;
  _semesterStartDate = DateTime(2025, 9, 1);
  _currentConfig = ScheduleConfigModel.defaultConfig();
  
  notifyListeners();
}
```

---

### 方法 2: 手动删除数据文件夹

如果你想完全清除所有数据（包括用户设置），可以手动删除数据文件夹：

**Windows:**
```powershell
# 删除 MMKV 数据
Remove-Item -Recurse -Force "$env:LOCALAPPDATA\coursewidgets\mmkv"

# 删除 SQLite 数据库
Remove-Item -Recurse -Force "$env:LOCALAPPDATA\coursewidgets\databases"

# 或者删除整个应用数据文件夹
Remove-Item -Recurse -Force "$env:LOCALAPPDATA\coursewidgets"
```

**效果：**
- ✅ 清除所有课程数据
- ✅ 清除所有配置
- ✅ 清除所有用户设置
- ⚠️ 应用会回到初始状态（显示引导页面）

---

### 方法 3: 在代码中添加调试开关（开发用）

如果你在开发时经常需要清除数据，可以添加一个调试开关：

```dart
// lib/main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // [调试] 开发时清除所有数据
  const bool clearDataOnStart = false; // 改为 true 时清除数据
  if (clearDataOnStart && kDebugMode) {
    await StorageService().initialize();
    await StorageService().clear();
    await DatabaseHelper.instance.clearAll();
    debugPrint('🗑️ 调试模式：已清除所有数据');
  }
  
  // ... 其他初始化代码
}
```

---

## MMKV 存储的数据

### 课程相关（会被"清除所有数据"删除）
- `semester_start_date` - 开学日期
- `schedule_config` - 课时配置
- `current_week` - 当前周次
- `current_day` - 当前星期

### 用户设置（不会被"清除所有数据"删除）
- `dark_mode` - 深色模式
- `adaptive_dark_mode` - 自适应深色模式
- `background_path` - 背景图片路径
- `theme_mode` - 主题模式
- `custom_theme_color` - 自定义主题色

---

## SQLite 存储的数据

### 课程表（会被"清除所有数据"删除）
- `courses` 表 - 所有课程数据
- `import_history` 表 - 导入历史记录

---

## 常见问题

### Q1: 为什么清理 build 文件夹后数据还在？

**A:** 因为数据存储在用户目录（`AppData`），不在项目的 `build` 文件夹中。这是标准做法。

### Q2: 如何在测试时快速清除数据？

**A:** 使用应用内的"清除所有数据"功能，或者在代码中添加调试开关。

### Q3: 清除数据后会丢失什么？

**A:** 
- ✅ 使用"清除所有数据"：只清除课程数据和配置，保留用户设置
- ⚠️ 手动删除文件夹：清除所有数据，包括用户设置

### Q4: 如何只清除课程数据，保留设置？

**A:** 使用应用内的"清除所有数据"功能（已在 V2.3.0 中优化）。

### Q5: 发布版本时用户的数据会保留吗？

**A:** 是的，这是正常的。用户升级应用后，数据会保留。如果需要清除数据，用户可以使用"清除所有数据"功能。

---

## 数据存储架构

```
用户目录 (AppData/Local/coursewidgets/)
├── mmkv/                          # MMKV 数据
│   ├── mmkv.default              # 默认 MMKV 实例
│   └── mmkv.default.crc          # CRC 校验文件
├── databases/                     # SQLite 数据库
│   ├── courses.db                # 课程数据库
│   └── courses.db-journal        # 日志文件
└── files/                         # 其他文件
    └── backgrounds/              # 背景图片（如果有）
```

---

## V2.3.0 改进

### 优化"清除所有数据"功能

**改进前：**
- 只清除数据库中的课程数据
- MMKV 中的配置（开学日期、课时配置）不会被清除
- 导致清除后仍然显示旧的配置

**改进后：**
- ✅ 清除数据库中的课程数据
- ✅ 清除 MMKV 中的课程相关配置
- ✅ 保留用户设置（主题、深色模式等）
- ✅ 重置到初始状态

---

## 总结

- ✅ **数据持久化是正常的设计行为**
- ✅ **使用"清除所有数据"功能来清除课程数据**
- ✅ **V2.3.0 已优化清除功能，更彻底**
- ⚠️ **不要手动删除文件夹，除非你想清除所有设置**

---

**文档创建时间：** 2026-01-29
**版本：** V2.3.0
**状态：** ✅ 已优化
