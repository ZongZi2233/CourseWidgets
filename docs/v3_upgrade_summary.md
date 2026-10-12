# 课表助手 CourseWidgets v3.0.0 正式版全量升级总结报告

> **发布版本**: `v3.0.0` (Build `3000`)  
> **开源协议**: GNU Affero General Public License v3.0 (AGPL-3.0)  
> **迁移基线**: 从 `v2.6.0-legacy` 尾声历经 `v3.0.0-alpha1` ~ `v3.0.0-alpha28` 演进，正式合并发布至 `main` 主线。

---

## 目录
1. [升级概述与核心突破](#1-升级概述与核心突破)
2. [数据层架构升级与防破坏设计 (SQLite Schema v4)](#2-数据层架构升级与防破坏设计-sqlite-schema-v4)
3. [教务系统抓取与多格式导入导出系统](#3-教务系统抓取与多格式导入导出系统)
4. [液态玻璃与物理动效引擎 (HyperOS / VisionOS)](#4-液态玻璃与物理动效引擎-hyperos--visionos)
5. [跨平台适配与桌面级体验 (Android / Windows / macOS)](#5-跨平台适配与桌面级体验-android--windows--macos)
6. [从 2.x 到 3.0.0 全版本演进足迹 (CHANGELOG 摘要)](#6-从-2x-到-300-全版本演进足迹-changelog-摘要)
7. [主线迁移说明与后续维护建议](#7-主线迁移说明与后续维护建议)

---

## 1. 升级概述与核心突破

课表助手 `v3.0.0` 是自项目创建以来最大规模的重构与技术升级。本次升级彻底摆脱了早期版本过度依赖绝对时间戳的局限，重构了底层数据流、导入导出链路与渲染引擎，带来了四大突破：

1. **核心课程语义节次固化 (Schema v4)**：彻底根除了修改课时导致“早八课被吃掉、第二节课前移”的移位问题；
2. **多端教务与格式无损流通**：全面兼容 ICS 日历、第三方课程表导出的 HTML 文件、以及本软件的 JSON 全量配置备份，支持双向无损导出；
3. **WebView 登录态与凭据持久化**：解决 Android 与 Windows 端教务系统 CAS 单点登录 Cookie 丢失及无法记住账号密码的痛点；
4. **旗舰级液态玻璃与物理弹簧动效**：基于自研 Liquid Glass 渲染架构，结合高张力 Spring 物理曲线，打造通透纯净、无暗角污浊的视觉与触控体验。

---

## 2. 数据层架构升级与防破坏设计 (SQLite Schema v4)

### 2.1 节次移位历史根因与数学重构
在 2.x 版本中，数据库 `courses` 表仅记录了 `startTime` 与 `endTime`（毫秒时间戳），未持久化课程实际属于“第几节到第几节”。当用户在“课时设置”中修改早间第一节作息（如从 08:00 改为 08:30）时，系统采用模糊时间范围对齐，导致原有 08:00 课程因时间偏移被判定落入空档或被后续节次截断吸收，引发“吃课”现象。

### 2.2 Schema v4 架构落地
- **字段持久化**：在 `courses` 表中新增 `startSection` 与 `endSection` 物理字段；
- **全链路贯通**：
  - `CourseEvent`: 字段纳入 `toMap()` / `fromMap()` / `copyWith()`；
  - `MigrationRunner`: 提供向后完全兼容的自动迁移逻辑（v1 -> v2 -> v3 -> v4），平滑升级无锁无损；
  - `ScheduleProvider`: 当用户修改课时作息时，基于课程固有的 `startSection`/`endSection` 动态重新计算 `startTime` 与 `endTime`，节次物理绑定，数据永不移位；
  - `WeeklyScheduleGrid`: 渲染以节次为金标准，结合当前作息完美展示。

---

## 3. 教务系统抓取与多格式导入导出系统

### 3.1 WebView Cookie 与凭据持久化
- **Windows (WebView2)**：通过显式调用 `WebviewController.initializeEnvironment(userDataPath: webviewDataDir.path)`，将用户 Profile 锁定在应用持久化支持目录，保留会话 Cookie、LocalStorage 与 Chromium 密码管理器；
- **Android (WebView)**：开启 `setAcceptThirdPartyCookies(true)`，完美穿透 CAS / IAM 单点登录跨子域跳转；
- **智能凭据助手**：注入轻量级凭据捕获与自动回填脚本，配合 MMKV 本地安全存储，实现高校教务系统账号密码的自动记忆与一键填充。

### 3.2 全链路导入导出验证
| 格式 | 输入场景 | 输出场景 | 兼容特性与保障 |
| :--- | :--- | :--- | :--- |
| **ICS (iCalendar)** | 导入学校教务系统日历、第三方导出的 `.ics` | 导出供系统日历、ClassIsland 或其他应用同步 | 遵循 RFC 5545 标准，嵌入自定义 `X-SCHEDULE-CONFIG` 与 `X-SECTION` 标签，实现双向无损回环 |
| **HTML** | 导入醒目课表 (WakeUp)、小爱课表、正方/强智/青果/树维网页导出文件 | - | 支持 DOM 表格解析、周次位串与单双周提取、跨节合并算法 |
| **JSON** | 导入本软件的完整快照备份文件 | 导出全量课表与课时作息备份文件 | 完整打包 `version`、`config`（作息设置）及所有 `courses`（含节次信息），支持一键无缝还原 |

---

## 4. 液态玻璃与物理动效引擎 (HyperOS / VisionOS)

### 4.1 通透 Dialog 与单层 Spring 弹簧
- 彻底解决外层路由动画与内层 State 重复缩放导致的“下半部闪跳”与“直接闪现”问题；
- 采用统一的 `AppCurves.springBounce` 曲线（360ms）驱动，初速度饱满，微过冲回弹丝滑；
- 背景搭载全屏 `BackdropFilter` 高斯模糊（动态增长至 18 sigma），对话框本体采用超椭圆双层物理投影与 24 sigma 磨砂玻璃，杜绝扁平塑料感与实色遮罩。

### 4.2 细节视觉调优
- **课时设置按钮底色统一**：“对齐课表”与“智慧推算”移除突兀的高饱和亮蓝底色，统一为优雅微透的玻璃晶体；
- **课程详情弹出层按钮恢复磨砂质感**：“编辑课程”与“关闭”按钮重构为磨砂液态玻璃容器，辅以 SpringTouchFeedback 触控物理微缩放反馈；
- **全曲率悬浮返回按钮**：人体工学圆形液态玻璃返回按钮，触控跟手，光泽内敛。

---

## 5. 跨平台适配与桌面级体验 (Android / Windows / macOS)

1. **Android 端**：
   - **包名正式定型**：正式发布为 `com.zongzi.schedule`，彻底剔除 `.beta` 标识；
   - **平板横屏全域统一**：废除老旧平板侧边栏，全面采用双角微透悬浮 Touch Bar 与全出血主课表；
   - **日历零死区流式铺满**：移除多余的 76dp Dock 避让与截断边框，小屏与折叠屏横屏完全舒展；
   - **通用悬浮玻璃标题返回胶囊**：所有子页面（课程通知、通用设置、数据管理、关于、课时配置、课程设置、课程编辑）采用 `FloatingGlassHeaderButton` 替换裸字大标题，消除裁断并全幅穿透滑动；
   - 适配沉浸式状态栏与手势返回，支持桌面微件 (AppWidget) 与后台实时任务。
2. **Windows 桌面端**：
   - **二进制正式发布**：输出文件名正式定为 `CourseWidgets.exe`，互斥体与 AppUserModelID 统一为 `CourseWidgets`；
   - 支持自定义标题栏、亚克力/Mica 背景与窗口自适应；
   - 快捷侧边导航与键盘快捷键交互；
   - 独立的 WebView2 桌面教务模拟系统。

---

## 6. 从 2.x 到 3.0.0 全版本演进足迹 (CHANGELOG 摘要)

- **v3.0.0-alpha1 ~ alpha8**: 架构解耦，引入 `plugins/liquid_glass_widgets` 官方液态玻璃组件库，奠定 3.0 全局玻璃质感基础；
- **v3.0.0-alpha9 ~ alpha15**: 重构非线性动效曲线系统 `AppCurves`，引入 1D 页面运动动态模糊组件与钟形包络正弦算法；
- **v3.0.0-alpha16 ~ alpha20**: 实现横竖屏响应式栅格切换，大屏双栏设置面板，完善 Android 端与 Windows 端的窗口自适应；
- **v3.0.0-alpha21 ~ alpha25**: 官方液态玻璃返回按钮（悬浮与内置）、微透胶囊控制器、周次切换平滑切页重构；
- **v3.0.0-alpha26 ~ alpha28**: 修复课程节次移位，固化 SQLite Schema v4 字段，完成 ICS/HTML/JSON 格式闭环；
- **v3.0.0 正式版 (Build 3000)**:
  - 正式包名 `com.zongzi.schedule` 与 Windows 二进制 `CourseWidgets.exe` 就位；
  - 手机/平板/桌面全平台统一新版横屏双角悬浮 touch bar 与全出血课表；
  - 日历横屏消除 dock 76dp 死区与截断边框；
  - 设置主页横屏优化状态栏避让间隙；
  - 全域二级子页面落地大圆角矩形玻璃胶囊标题返回按钮 (`FloatingGlassHeaderButton`)；
  - 课程编辑页面全出血流式铺满；
  - 修复 WebView Cookie 持久化与教务账号密码自动填充；
  - 统一配置面板按钮与详情弹窗磨砂玻璃质感；
  - 重构 Dialog 为纯正 Spring 弹性进场动画；
  - 开源协议升级为 AGPL-3.0；
  - 代码全量合并至 `main` 主线。

---

## 7. 主线迁移说明与后续维护建议

1. **分支状态**：
   - `main`: 主线正式版代码仓，基线版本 `3.0.0` (Build `3000`)；
   - `v3beta`: 演进测试分支，已完成向 `main` 的对齐与合并；
2. **后续开发指引**：
   - 后续维护与功能迭代直接在 `main` 主线操作；
   - 如需引入大型破坏性实验特性，可在本地新开 feature 分支验证后合并。
