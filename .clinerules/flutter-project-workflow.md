## Brief overview

这是一套针对Flutter课程表项目的开发工作流程规则。项目使用自动化版本管理，每次迭代版本号+1，并且必须在每次操作前阅读PROJECT_STATUS.md了解项目状态，操作后更新该文件。

## 版本管理规则

- **自动版本更新**: 每次运行必须执行 `python sync_versions.py` 将版本号+1
- **版本号格式**: $appVersion → $appVersion+1 ($buildNumber → $buildNumber + 1)
- **版本同步**: 更新lib/constants/version.dart后必须运行sync_versions.py同步所有配置
- **下次预期版本**: 当前$appVersion，下次运行应为$appVersion+1 ($buildNumber + 1)

## 项目状态管理规则

**每次操作前必须执行**:

1. **阅读PROJECT_STATUS.md**: 了解项目当前状态、已完成事项、待办事项
2. **分析用户需求**: 对比项目状态，确定需要做什么
3. **制定执行计划**: 基于项目状态和用户需求制定具体步骤

**每次操作后必须执行**:

1. **更新PROJECT_STATUS.md**: 记录新完成的功能和状态变化
2. **记录所有变更**: 包括代码修改、新增文件、修复的问题
3. **更新待办事项**: 标记已完成的任务，添加新的任务

## 完整文件阅读流程

**必须阅读的相关文件**:

- `PROJECT_MEMORY.md` - [最高优先级] 项目持久化全景记忆、技术陷阱红线与架构约束
- `PROJECT_STATUS.md` - 项目状态和历史记录
- `pubspec.yaml` - 依赖和版本配置
- `lib/constants/version.dart` - 版本常量
- `lib/main.dart` - 主入口和平台选择逻辑
- `sync_versions.py` - 版本同步脚本
- `android/app/build.gradle.kts` - Android构建配置
- `windows/runner/Runner.rc` - Windows版本信息
- 当前正在编辑的文件
- 与当前任务相关的所有UI组件文件

**阅读顺序**:

1. PROJECT_STATUS.md (了解整体状态)
2. 版本相关文件 (了解当前版本)
3. `Liquid_Glass_Renderer_README.md`
4. liquid_glass_widgets_README.md
5. [liquid_glass_widgets - Dart API docs](https://pub.dev/documentation/liquid_glass_widgets/latest/index.html)（这是widgets官方的接入文档说明，任何API问题请直接查询网页说明）
6. 主程序文件 (了解架构) 
7. 相关UI组件 (了解当前实现)
8. 构建配置 (了解构建状态)

## Flutter开发工作流程

**标准迭代流程**:

1. **需求分析**: 阅读PROJECT_STATUS.md + 用户需求
2. **方案设计**: 阅读所有相关文件，制定技术方案
3. **版本更新**: 执行 `python sync_versions.py` 更新版本号
4. **代码实现**: 修改/创建文件
5. **测试验证**: 构建Android APK + Windows EXE
6. **状态更新**: 更新PROJECT_STATUS.md记录成果

**关键检查点**:

- 是否已阅读PROJECT_STATUS.md？
- 是否已更新版本号？
- 是否阅读了所有相关文件？
- 是否实现了完整功能？
- 是否构建成功？
- 是否已更新项目状态？

## 代码质量要求

- **完整实现**: 必须实现用户要求的所有功能，不能遗漏
- **错误处理**: 添加适当的错误处理和用户提示
- **代码注释**: 关键逻辑添加注释说明
- **命名规范**: 使用清晰的变量和函数命名
- **UI一致性**: 保持界面风格统一

## 构建和发布

- **Android**: `flutter build apk --release --target-platform android-arm64 --split-per-abi --obfuscate --split-debug-info=build/debug_info`
- **Windows**: `flutter build windows --release`
- **代码混淆**: Android构建必须启用混淆和分包
- **构建成功后**: 记录构建产物信息到PROJECT_STATUS.md

## 通信风格

- **简洁明了**: 直接说明需要做什么，为什么
- **进度反馈**: 关键步骤完成后简要反馈
- **错误说明**: 出现问题时说明原因和解决方案
- **完成确认**: 任务完成后明确说明完成状态

## 特殊注意事项

- **Liquid Glass Renderer**: 使用最新液态玻璃渲染引擎包
- ###### Liquid Glass Widgets: 现在使用的液态玻璃组件包
- **版本号冲突**: 如果遇到版本号冲突，手动检查并修正
- **构建缓存**: 构建失败时清理缓存重新构建
- **依赖更新**: 新增依赖后必须运行flutter pub get
- **文件占用**: Windows构建失败时检查是否有进程占用文件

## 错误处理流程

1. **构建失败**: 清理build目录 → 重新构建
2. **依赖冲突**: 检查pubspec.yaml → 更新依赖版本
3. **版本错误**: 手动检查version.dart → 运行sync_versions.py
4. **文件缺失**: 检查文件路径 → 确认文件存在
5. **状态不一致**: 重新阅读所有文件 → 修正不一致处

## 每次任务必须检查清单

- [ ] 已阅读PROJECT_STATUS.md了解当前状态
- [ ] 已阅读所有相关文件了解完整上下文
- [ ] 已执行python sync_versions.py更新版本号
- [ ] 已制定完整的实现方案
- [ ] 已实现所有要求的功能
- [ ] 已构建Android APK验证
- [ ] 已构建Windows EXE验证
- [ ] 已更新PROJECT_STATUS.md记录成果
- [ ] 已确认所有功能正常工作
