# Version 2.1.11 构建检查清单

## 📋 构建前检查

### 代码检查
- [x] 所有文件已保存
- [x] 无编译错误
- [x] 无严重警告
- [x] 代码格式化完成

### 版本号检查
- [x] `pubspec.yaml`: 2.1.11+10002111
- [x] `lib/constants/version.dart`: 2.1.11 / 10002111
- [x] `android/app/build.gradle.kts`: versionCode 10002111, versionName "2.1.11"
- [x] `windows/runner/Runner.rc`: 2,1,11,0

### 功能检查
- [x] AGP 9.0 兼容性修复完成
- [x] Android 平板适配完成
- [x] Android 16 Live Updates 实现完成
- [x] 通知点击跳转实现完成
- [x] UI 组件迁移完成

### 文档检查
- [x] `V2.1.11_FINAL.md` 已更新
- [x] `ANDROID_16_LIVE_UPDATES.md` 已创建
- [x] `TESTING_GUIDE_V2.1.11.md` 已创建
- [x] `V2.1.11_RELEASE_NOTES.md` 已创建

---

## 🔨 构建步骤

### 1. 清理构建缓存
```bash
flutter clean
flutter pub get
```

### 2. 构建 Android APK

#### ARM64 版本（推荐）
```bash
flutter build apk --release --target-platform android-arm64 --split-per-abi --obfuscate --split-debug-info=build/debug_info
```

**输出位置**: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`

#### x86-64 版本（模拟器）
```bash
flutter build apk --release --target-platform android-x86_64 --split-per-abi --obfuscate --split-debug-info=build/debug_info
```

**输出位置**: `build/app/outputs/flutter-apk/app-x86_64-release.apk`

#### 通用版本（所有架构）
```bash
flutter build apk --release --obfuscate --split-debug-info=build/debug_info
```

**输出位置**: `build/app/outputs/flutter-apk/app-release.apk`

### 3. 构建 Windows EXE
```bash
flutter build windows --release --obfuscate --split-debug-info=build/debug_info
```

**输出位置**: `build/windows/x64/runner/Release/`

---

## ✅ 构建后检查

### APK 检查
- [ ] APK 文件存在
- [ ] 文件大小合理（< 50MB）
- [ ] 可以正常安装
- [ ] 应用图标正确
- [ ] 版本号正确

### 功能测试
- [ ] 应用正常启动
- [ ] 无崩溃
- [ ] 平板模式正常
- [ ] 通知功能正常
- [ ] 所有页面可访问

### 性能测试
- [ ] 启动时间 < 2 秒
- [ ] 内存占用 < 200MB
- [ ] 无明显卡顿
- [ ] 电池消耗正常

---

## 📦 发布准备

### 文件清单
- [ ] `app-arm64-v8a-release.apk` (Android ARM64)
- [ ] `app-x86_64-release.apk` (Android x86-64)
- [ ] `V2.1.11_RELEASE_NOTES.md` (发布说明)
- [ ] `TESTING_GUIDE_V2.1.11.md` (测试指南)
- [ ] `ANDROID_16_LIVE_UPDATES.md` (功能文档)

### 发布信息
```
版本: 2.1.11
构建号: 10002111
发布日期: 2025-01-23
更新类型: 功能增强 + 兼容性修复

主要更新:
1. Android 平板完整适配
2. Android 16 Live Updates 实时通知
3. AGP 9.0 完全兼容
4. UI 组件统一优化
```

---

## 🚀 快速构建命令

### 一键构建 Android
```bash
flutter clean && flutter pub get && flutter build apk --release --target-platform android-arm64 --split-per-abi --obfuscate --split-debug-info=build/debug_info
```

### 一键构建 Windows
```bash
flutter clean && flutter pub get && flutter build windows --release --obfuscate --split-debug-info=build/debug_info
```

---

## 🐛 常见问题

### 问题 1: 构建失败 - Kotlin 插件冲突
**解决方案**: 已在 v2.1.11 中修复，移除了 dynamic_color 依赖

### 问题 2: APK 安装失败
**解决方案**: 
1. 卸载旧版本
2. 检查签名配置
3. 确保设备支持 Android 14+

### 问题 3: 通知不显示
**解决方案**:
1. 检查通知权限
2. 检查电池优化设置
3. 确保有课程数据

---

## 📊 构建统计

### 预期构建时间
- **Android APK**: 3-5 分钟
- **Windows EXE**: 2-4 分钟

### 预期文件大小
- **ARM64 APK**: 25-35 MB
- **x86-64 APK**: 30-40 MB
- **Windows EXE**: 40-50 MB

---

## 🎯 下一步

### 测试阶段
1. 安装到测试设备
2. 执行完整测试（参考 TESTING_GUIDE_V2.1.11.md）
3. 记录测试结果
4. 修复发现的问题

### 发布阶段
1. 准备发布说明
2. 上传到发布平台
3. 通知用户更新
4. 收集用户反馈

---

## ✨ 构建成功标志

当看到以下输出时，表示构建成功：

```
✓ Built build/app/outputs/flutter-apk/app-arm64-v8a-release.apk (XX.XMB).
```

或

```
✓ Built build\windows\x64\runner\Release\coursewidgets.exe
```

---

**准备好了吗？开始构建吧！** 🚀

---

*文档版本: 1.0*  
*最后更新: 2025-01-23*  
*维护者: CourseWidgets Team*
