# CourseWidgets AI Context & Quick Handoff (AI_CONTEXT.md)

本文件为开发助手与 AI Pair Programmer 快速交接指引。

## 快速恢复上下文（复制以下指令发给新会话）：

```text
你好！本项目是 CourseWidgets（当前版本 v2.6.0 正式版）。
请在回答或开始任何任务前，务必先完整阅读项目根目录下的 PROJECT_MEMORY.md 和 .clinerules/flutter-project-workflow.md。
其中包含了关于：
1. Android 侧滑返回/转场动画（全平台统一 BackdropFilter，严禁使用 Stack 兄弟节点的截图层，严禁破坏 route.opaque 区分机制）；
2. 教务系统 WebView 抓取防爆（严禁通过 JS 跨端传输巨型 Base64，采用 DOM 隐藏注入 + 原生轻量抽取）；
3. AGP 9.0+ / Gradle 9.3.1 / Kotlin 2.3.0 本地插件重载覆盖机制（plugins/ 下本地模块严禁擅自删除）；
4. 液态玻璃微质感美学（控制 thickness: 8~16, blur: 6~8，严禁使用 500 极端畸变厚度）；
5. 版本统一管理（通过 python sync_versions.py 自动化同步）。
请严格遵循上述架构约束开展工作！
```

详见完整技术全书：[`PROJECT_MEMORY.md`](./PROJECT_MEMORY.md)
