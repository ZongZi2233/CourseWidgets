# liquid_glass_widgets 调优与动效实施指南

> **目标包版本**：`liquid_glass_widgets` 1.11.0（请对照你 `pubspec.yaml` 的实际版本）  
> **适用环境**：Flutter ≥ 3.41 + Impeller 渲染后端  
> **文档用途**：交给 AI agent 按阶段执行的实施指南，含设计方案、代码骨架、验收标准  
> **最后校准**：2026-10

---

## 硬约束（贯穿全文）

**不修改包内的官方 morph engine。**

`lib/engine/` 下的下列类型属于不可修改范围：  
`GlassMorphController` · `LiquidMorphState` · `LiquidMorphPhysics` · `MorphPhase` · `MorphSpeed`

**允许**：

- 通过 `GlassMorphController` 的公开 API 读取状态与速度
- 在 morph 之外叠加独立的动效层
- 使用 `GlassMaterialize` / `GlassMaterializeTransition` 等包内公开 widget
- 用 `PageRouteBuilder`、`RepaintBoundary`、`CustomPainter` 等 Flutter 原生能力包装

**不允许**：

- fork 包源码
- 修改 `lib/engine/` 下任何文件
- 依赖包的私有 API（`_` 前缀成员）

> 本指南中若有任何方案必须改源码，会明确标注「**需 fork，暂缓**」。目前的全部方案均不涉及。

---

## 目录

- [第 0 部分：边界与已内建能力](#第-0-部分边界与已内建能力)
- [第 1 部分：saveLayer 完全指南](#第-1-部分savelayer-完全指南)
- [第 2 部分：动效决策框架](#第-2-部分动效决策框架)
- [第 3 部分：Spring 与贝塞尔曲线](#第-3-部分spring-与贝塞尔曲线)
- [第 4 部分：预烘焙体系（LUT / Mipmap / 帧缓存）](#第-4-部分预烘焙体系)
- [第 5 部分：动态模糊完整方案](#第-5-部分动态模糊完整方案)
- [第 6 部分：页面转场动态模糊实施](#第-6-部分页面转场动态模糊实施)
- [第 7 部分：全局其他优化项](#第-7-部分全局其他优化项)
- [第 8 部分：给 AI agent 的分阶段执行指令](#第-8-部分给-ai-agent-的分阶段执行指令)
- [附录 A：GlassBackdropGroup 的 6 条限制](#附录-aglassbackdropgroup-的-6-条限制)
- [附录 B：设计层硬约束](#附录-b设计层硬约束)
- [附录 C：其他必须知道的限制](#附录-c其他必须知道的限制)

---

# 第 0 部分：边界与已内建能力

## 0.1 已内建能力速查 —— 不要重复实现

| 能力                 | 实现方式                                                        | 实测效果                                                                                     |
| ------------------ | ----------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| **共享 backdrop 读取** | `GlassBackdropGroup`（对标 SwiftUI `GlassEffectContainer`）     | iPhone Air + `ios27Light`，app bar（3 按钮）+ tab bar 下打开 sheet：**23.6ms → 9.3ms 平均 GPU 帧时间** |
| **shader 预热**      | `initialize()` 纯 async 磁盘到内存 I/O，**零 GPU 调用、零 toImageSync** | Frame 1 立即呈现                                                                             |
| **设备自动分级**         | `GlassAdaptiveScope` 启动基准测试                                 | 自动选 minimal / standard / premium                                                         |
| **GPU 预算监控**       | `GlassPerformanceMonitor`                                   | release 构建零开销                                                                            |
| **GLES 降级路径**      | Android GLES 走 **8-shape AST**（Metal/Vulkan 走 16-shape）     | zero ANR                                                                                 |
| **specular 去超越函数** | 固定 2 的幂指数 + 零超越函数乘法链                                        | 消除 `pow()` 开销                                                                            |
| **桌面/Web 静态封顶**    | `GlassAdaptiveScope` 锁 Windows/Linux/Web 在 `standard`       | 开箱 60/120fps                                                                             |
| **无障碍零成本降级**       | High Contrast 激活时完全绕过 glass shader                          | 走 Flutter 原生 paint layer                                                                 |

**渲染管线（Impeller，`GlassQuality.premium`）**：

```
Pass 1  Blur   ── BackdropFilterLayer(ImageFilter.blur)，裁剪到精确 widget 形状
Pass 2  Shader ── BackdropFilterLayer(ImageFilter.shader)：折射 + 边缘光照 + 色调 + 色散
```

## 0.2 必做的配置改动（按优先级）

### ① 自适应质量 + 跨冷启动持久化 —— 最高优先级

**问题**：`adaptiveQuality: true` 每次冷启动都会跑约 **3 秒**基准测试，期间质量降级。进程内缓存，**跨冷启动不缓存**。Pixel 4a 上用户每开一次 App 都会看到 3 秒降级质量。

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('glass_quality');
  final initial = saved != null ? GlassQuality.values.byName(saved) : null;

  await LiquidGlassWidgets.initialize();

  runApp(LiquidGlassWidgets.wrap(
    child: const MyApp(),
    adaptiveQuality: true,
    adaptiveConfig: GlassAdaptiveScopeConfig(
      initialQuality: initial,        // 直接恢复，无 warmup 窗口
      allowStepUp: true,              // 热节流后可恢复
      onQualityChanged: (_, to) => prefs.setString('glass_quality', to.name),
    ),
  ));
}
```

### ② 开启 frostStep

```dart
GlassAdaptiveScope(frostStep: true, ...)
```

从 premium 降级时**先只关 frost**（iOS 27 材质最贵的部分），之后才降到 standard。

### ③ 对列表 / 背景面板使用 `minimal`

README 原话：**一屏 15 个 `minimal` 玻璃列表卡片，滚动期间触发零次 shader 调用。**

| 用途                                | 推荐档位                                                      |
| --------------------------------- | --------------------------------------------------------- |
| 背景面板、列表卡片（大量、可滚动）                 | `minimal`                                                 |
| 常规可滚动内容、表单、交互控件                   | `standard`（默认）                                            |
| **静态、非滚动**的焦点表面（hero 区、feature 卡） | `premium`                                                 |
| App bar / bottom bar              | `GlassScaffold` 经 `GlassIsolationScope` **自动提升为 premium** |

> **警告**：`premium` **只能用于静态非滚动表面**。在 `ListView` / `CustomScrollView` 中可能渲染不正确。

### ④ 按刷新率校准 GPU 预算

```dart
GlassPerformanceMonitor.rasterBudget = const Duration(microseconds: 8333); // 120Hz
GlassPerformanceMonitor.sustainedFrameThreshold = 120;
```

---

# 第 1 部分：saveLayer 完全指南

## 1.1 它到底做了什么

`saveLayer` 是 Flutter 渲染管线中**单项最贵的操作**。它做三件事：

1. 分配一张离屏 render target（显存分配）
2. 把当前绘制内容 flush 进去（一次全写）
3. 后续内容在这张离屏上绘制，最后合成回主帧缓冲（一次全读）

在 Impeller 上还有额外代价 —— 这是做玻璃效果必须知道的：

> **每次 `BackdropFilter` 都会终止当前 render pass，并拷贝整个屏幕，不管玻璃多小。**（README 原文）

## 1.2 隐式触发源清单

| 触发源                                              | 说明                     |
| ------------------------------------------------ | ---------------------- |
| `BackdropFilter`                                 | 必然触发，且终止 render pass   |
| `Opacity`（非 0/1 值）                               | 触发                     |
| `ShaderMask`                                     | 触发                     |
| `ColorFiltered`                                  | 触发                     |
| `ImageFiltered`                                  | 触发                     |
| `ClipRRect` / `ClipOval` / `ClipPath`            | 在频繁重绘的 subtree 上会创建合成层 |
| `BoxDecoration` 同时含 `boxShadow` + `borderRadius` | 为正确合成圆角下的阴影而触发         |
| `Clip.antiAliasWithSaveLayer`                    | 显式触发                   |
| 非常规 `BlendMode`                                  | 可能触发                   |

**grep 定位**：

```bash
grep -rn "BackdropFilter\|ShaderMask\|ColorFiltered\|ImageFiltered" lib/ --include="*.dart"
grep -rn "Opacity(" lib/ --include="*.dart"
grep -rn "boxShadow.*borderRadius\|borderRadius.*boxShadow" lib/ --include="*.dart"
grep -rn "antiAliasWithSaveLayer" lib/ --include="*.dart"
```

## 1.3 玻璃场景的 saveLayer 预算表

| 质量档                              | 每表面 backdrop 拷贝次数 |
| -------------------------------- | ----------------- |
| `minimal`                        | 1                 |
| `standard`                       | 1                 |
| `premium`                        | **2**             |
| `premium` + `ios27Light/Dark` 材质 | **3**             |

**含义**：3 个 premium 玻璃 = 6–9 次全屏拷贝。这就是 `GlassBackdropGroup` 能把 23.6ms 压到 9.3ms 的原因。

## 1.4 什么时候「值得」一次 saveLayer

不是所有 saveLayer 都要消灭。判定标准：

**✅ 值得**：

- 静态或低频变化的表面 —— 一次 saveLayer 换长期视觉质量
- 被 `RepaintBoundary` 隔离，不会在动画帧里重复触发
- 区域很小（用 `ClipRect` 严格限制）

**❌ 不值得**：

- 在动画路径上每帧触发
- 在 `ListView.builder` 的 item 里（每 item 每帧）
- 全屏且无裁剪
- 多层嵌套

## 1.5 消除手段（按收益排序）

| # | 手段      | 做法                                                                                                                                                    |
| - | ------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 | **换实现** | `Opacity(driven by animation)` → `FadeTransition`；`ClipRRect` 用于静态圆角 → `BoxDecoration(borderRadius:)`；`Clip.antiAliasWithSaveLayer` → `Clip.hardEdge` |
| 2 | **共享**  | 同屏多个玻璃用 `GlassBackdropGroup` 合并为一次读取                                                                                                                  |
| 3 | **隔离**  | `RepaintBoundary` 包住，防止外部重绘传播进来                                                                                                                       |
| 4 | **裁剪**  | `ClipRect` 严格限制边界（`BackdropFilter` 的 saveLayer 边界默认扩展到全屏）                                                                                             |
| 5 | **降级**  | 动画期间切到 `minimal` 或纯色                                                                                                                                  |

---

# 第 2 部分：动效决策框架

## 2.1 三个档次

| 档次           | 工具                                                                                       | 何时用          |
| ------------ | ---------------------------------------------------------------------------------------- | ------------ |
| **Implicit** | `AnimatedContainer` / `AnimatedOpacity` / `AnimatedPositioned` / `TweenAnimationBuilder` | 单次、非交互、不关心细节 |
| **Explicit** | `AnimationController` + `Tween` + `Curve`                                                | 循环、分段、状态驱动   |
| **Physics**  | `controller.animateWith(Simulation)`                                                     | 用户能碰的、可被打断的  |

## 2.2 唯一的决策问句

> **对每个动画问：第二个手势能在这个还在运行时落下吗？**
>
> - 能 → 必须用 Physics
> - 不能 → 曲线完全可以

这一条比任何性能指标都重要 —— 用错模型造成的手感损伤远大于性能损耗。

**审计现有页面的方法**：逐个动画过一遍这个问句。每个「能」都是 Physics 的候选。每个「不能」都可以安心留在曲线上。

## 2.3 编排（Orchestration）

成熟的动作编排**整个屏幕**，而不是单个 widget。

- **12 个元素同时动画 = 眼睛没有锚点**，是十二个东西齐声喊同一个词
- **stagger 20–40ms** 会产生阅读顺序，眼睛自上而下跟随 —— 恰好就是你希望用户扫内容的顺序

```dart
Widget buildItem(int index) {
  final start = (index * 0.05).clamp(0.0, 0.5);
  final anim = CurvedAnimation(
    parent: controller,
    curve: Interval(start, (start + 0.4).clamp(0.0, 1.0), curve: Curves.easeOut),
  );
  return FadeTransition(
    opacity: anim,
    child: SlideTransition(
      position: Tween(begin: const Offset(0, 0.1), end: Offset.zero).animate(anim),
      child: row,
    ),
  );
}
```

**全局元素切换的正确做法**：共享**一条** spring 参数，只用 stagger 区分元素，而不是每个元素配独立曲线。

---

# 第 3 部分：Spring 与贝塞尔曲线

## 3.1 性能真相：先破除一个误解

**曲线求值本身完全不吃性能。**

- `Curves.easeOutCubic` 求值 = 一次三次多项式运算 ≈ **10 纳秒**
- `SpringSimulation` 求值 = 一次半隐式欧拉积分（几行浮点运算）≈ **50 纳秒**
- 120Hz 下每秒 120 次求值 → **Spring 每秒的求值开销约 0.006ms**

**结论：Spring 与贝塞尔的求值性能差异可以完全忽略。选择依据应该是手感，不是性能。**

**真正的差异来自它们的副作用**：

| 维度              | 贝塞尔曲线   | Spring                                  |
| --------------- | ------- | --------------------------------------- |
| 求值成本            | ~10ns   | ~50ns                                   |
| 时长              | 固定      | 不固定（物理收敛）                               |
| 可中断性            | 差（速度归零） | 好（速度继承）                                 |
| 帧数              | 可预测     | 取决于参数                                   |
| 对 saveLayer 的影响 | 无差别     | 无差别                                     |
| **隐性风险**        | 无       | **参数不当会导致长时间高频抖动，让下游 shader / 玻璃层持续重绘** |

> **Spring 唯一真正的性能风险不是求值，而是它驱动的动画持续时间。** `stiffness` 过高 + `damping` 过低 → 长时间余振 → 下游持续重绘。用 `withDampingRatio(ratio: 1.0)` 可以根除。

## 3.2 核心区别（手感层面）

> **Curves 是运动的描述。Springs 是运动的模型。**  
> 描述说的是"在时钟的这个比例上处于这个值"。  
> 模型说的是"这里是力；不管你在哪、你多快，接下来会发生这个"。

**曲线无法诚实地被中断。** 一个 300ms 的滑动在 40% 处被重定向时，基于曲线的系统最多只能从当前位置重新开始一个 0→1 的动画 —— **速度在那一刻归零。眼睛会把那个零速度的瞬间读成一次小卡顿。**

这个"零速度瞬间"在页面转场、元素 morph、拖拽弹窗里都会被看到，而且无法用调曲线参数来修复。

## 3.3 选择标准（针对本项目）

| 场景                             | 推荐           | 理由           |
| ------------------------------ | ------------ | ------------ |
| 页面入场（不可打断、固定时长）                | 贝塞尔          | 可预测、易编排      |
| **页面转场（手势驱动）**                 | **Spring**   | 需要速度继承       |
| 页面转场（点击触发、固定时长）                | 贝塞尔 + 动态模糊包络 | 时长可控，模糊强度用包络 |
| Toast / 提示消失                   | 贝塞尔          | 不需要中断        |
| 底部弹窗拖拽                         | Spring       | 必须有速度继承      |
| 列表 stagger 入场                  | 贝塞尔          | 固定时长         |
| **元素 morph（含包内 morph engine）** | **Spring**   | 通常可被打断       |
| **全局元素切换**                     | **Spring**   | 用户可能中途反向     |
| 玻璃 bar 的 minimize / expand     | Spring       | 跟手           |

## 3.4 iOS 参数换算

苹果用 `response` / `dampingFraction`，Flutter 用 `stiffness` / `damping`：

```dart
SpringDescription iosSpring({
  double response = 0.35,          // 苹果的 response，单位秒
  double dampingFraction = 1.0,    // 1.0 = 临界阻尼
  double mass = 1.0,
}) {
  final w0 = 2 * math.pi / response;
  return SpringDescription(
    mass: mass,
    stiffness: w0 * w0,                          // k = ω₀²
    damping: 2 * mass * w0 * dampingFraction,    // c = 2mω₀ζ
  );
}
```

或直接用 Flutter 内置的人性化 API：

```dart
SpringDescription.withDampingRatio(
  mass: 1.0,
  stiffness: 500.0,
  ratio: 1.0,   // <1 过冲、反弹；=1 临界阻尼；>1 迟滞沉重
)
```

**参数建议**：

- 大多数产品 UI：让 `dampingFraction` 产生**零过冲或仅一次极小过冲**
- 「一个要弹三次才停的结账按钮，是一个不信任自己的按钮」

**苹果动效参考值**（WWDC *Designing Fluid Interfaces*）：

- 默认：`response ≈ 0.35s`，`dampingFraction ≈ 1.0`
- 更跟手：`response ≈ 0.25s`

## 3.5 速度继承 —— 零成本、巨大收益

```dart
controller.animateWith(SpringSimulation(
  iosSpring(),
  controller.value,      // 从当前位置开始
  1.0,                   // 目标
  controller.velocity,   // 关键：继承手势速度
));
```

**这是跟手感的全部秘密，且零性能成本。** Flutter 默认不给你，必须手写。

## 3.6 性能优化守则（Spring 侧）

| 症状           | 原因             | 修复                                 |
| ------------ | -------------- | ---------------------------------- |
| 动画拖尾过长       | `stiffness` 太低 | 提高 `stiffness`                     |
| 高频抖动         | `damping` 太低   | 提高至 `ratio ≥ 1.0`                  |
| 抖动持续很久       | 两者都偏低          | 改用 `withDampingRatio(ratio: 1.0)`  |
| 重绘扩散到整屏      | 未隔离            | `AnimatedBuilder` 只包最小叶子           |
| 动画在页面不可见时仍运行 | 未用 `vsync`     | 用 `SingleTickerProviderStateMixin` |

**`AnimatedBuilder` 的 `child` 逃生舱（必用）**：

```dart
AnimatedBuilder(
  animation: _controller,
  builder: (context, child) => Transform.scale(
    scale: _controller.value,
    child: child,        // 只构建一次，不随动画重建
  ),
  child: const ExpensiveStaticContent(),
)
```

**性能优化守则（贝塞尔侧）**：

| 症状         | 原因             | 修复                                            |
| ---------- | -------------- | --------------------------------------------- |
| 大量元素同时动画   | 无编排            | 加 20–40ms stagger                             |
| 元素在屏幕外仍在动画 | 未裁剪            | 用 `Visibility` / `Offstage` / `TickerMode` 停止 |
| 每帧重建子树     | 未用 `child` 逃生舱 | 同上                                            |

---

# 第 4 部分：预烘焙体系

## 4.1 三条铁律

1. **烘焙中间数据，不烘焙帧序列。**  
   1080p RGBA 单帧 8MB，60 帧 = **500MB**。绝对不能烘焙全帧序列。
2. **只烘焙与运行时输入无关的部分。**  
   判断标准：这个数据依赖于「背后是什么内容」吗？依赖 → 不能烘。
3. **烘焙产物必须 GPU 友好。**  
   Flutter 不支持 3D 纹理 → LUT 必须 2D 展平；mip 用等比降采样；顶点序列用紧凑 float 数组。


**能烘 / 不能烘的判定表**：

| 数据 | 能否烘焙 | 原因 |
|---|---|---|
| 折射**结果** | ❌ | 依赖任意背景像素 |
| 折射**位移场** | ✅ | 只依赖玻璃形状与曲率 |
| 高光 / 边缘提亮 LUT | ✅ | 只依赖光照方向与形状 |
| RGB 色散偏移量 | ✅ | 只依赖玻璃厚度 |
| 背景模糊的 mip 链 | ⚠️ 半烘 | 内容变化时需重建，但重建成本远低于实时高斯 |
| 动画帧序列 | ❌ | 内存爆炸 |
| morph 的顶点序列 | ✅ | 只依赖起止形状 |
| Spring / 贝塞尔曲线 | ❌ 且无必要 | 求值只需纳秒，烘了也没收益 |

## 4.2 LUT（颜色查找表）

**典型用途**：色散偏移量、高光强度曲线、玻璃厚度映射、饱和度矩阵

**原理**：
- 3D LUT 划分 32 阶（32×32×32）= 32768 项，RGBA8888 存储 = **128KB**，精度足够
- **Flutter 不支持 3D 纹理** → 必须展平成 2D 图（32×32 格 → **1024×32 像素**）

**离线生成（Python）**：

```python
from PIL import Image
import numpy as np

SIZE = 32  # 每个通道的阶数
img = np.zeros((SIZE, SIZE * SIZE, 3), dtype=np.uint8)

for b in range(SIZE):          # 蓝通道决定第几个切片
    for g in range(SIZE):      # 绿通道 = y
        for r in range(SIZE):  # 红通道 = x（切片内）
            # 替换成你的映射函数
            out_r = r * 255 // (SIZE - 1)
            out_g = g * 255 // (SIZE - 1)
            out_b = b * 255 // (SIZE - 1)
            img[g, b * SIZE + r] = [out_r, out_g, out_b]

Image.fromarray(img).save('lut_flat.png')
```

**shader 侧采样**：

```glsl
uniform sampler2D uLUT;   // 1024x32 的展平 LUT

vec3 sampleLUT(vec3 color) {
    const float SIZE = 32.0;
    float sliceW  = 1.0 / SIZE;                 // 单个切片占的 UV 宽度
    float pixelW  = sliceW / SIZE;              // 单个像素宽
    float innerW  = pixelW * (SIZE - 1.0);      // 切片内的有效宽度

    float z0 = floor(color.b * (SIZE - 1.0));
    float z1 = min(z0 + 1.0, SIZE - 1.0);
    float xOff = pixelW * 0.5 + color.r * innerW;

    vec3 c0 = texture(uLUT, vec2(z0 * sliceW + xOff, color.g)).rgb;
    vec3 c1 = texture(uLUT, vec2(z1 * sliceW + xOff, color.g)).rgb;

    return mix(c0, c1, fract(color.b * (SIZE - 1.0)));
}
```

**成本**：2 次额外纹理采样。1024×32 的 LUT 完全可以常驻纹理缓存，**几乎免费**。

## 4.3 Mipmap 高斯

**核心数学依据** —— 高斯模糊是**线性算子**：

```
blur_σ(a·I₁ + b·I₂) = a·blur_σ(I₁) + b·blur_σ(I₂)
```

所以：预烘焙离散级别（σ = 1, 2, 4, 8, 16, 32），运行时在相邻两级间线性插值，即可得到**任意中间半径**，误差肉眼不可见。

**为什么用 mipmap 形态**：
- 内存总量 = 原图 **1/3**（等比数列 1/4 + 1/16 + …）
- 生成成本 = 一次简单降采样链（O(w·h)），比高斯便宜一个数量级
- 采样时天然带硬件三线性过滤 —— **连插值都是免费的**

**生成代码（Flutter 侧，只在初始化时跑一次）**：

```dart
/// 构建 mip 链：每级尺寸减半、sigma 翻倍
/// 注意：这是初始化期的操作，绝不在动画帧中调用
Future<List<ui.Image>> buildMipChain(ui.Image src, {int levels = 5}) async {
  final chain = <ui.Image>[src];
  var current = src;

  for (var i = 1; i <= levels; i++) {
    final w = (current.width ~/ 2).clamp(1, 1 << 20);
    final h = (current.height ~/ 2).clamp(1, 1 << 20);
    final sigma = math.pow(2, i).toDouble();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(w / current.width, h / current.height);

    final paint = Paint()
      ..imageFilter = ui.ImageFilter.blur(
        sigmaX: sigma.toDouble(),
        sigmaY: sigma.toDouble(),
        tileMode: TileMode.decal,
      );

    canvas.drawImage(current, Offset.zero, paint);

    final img = await recorder.endRecording().toImage(w, h);
    chain.add(img);
    current = img;
  }
  return chain;
}
```

> **性能警告**：`toImage()` 会分配内存并可能 stall 渲染管线。**只能在初始化或内容真正变化时调用。** 动画帧里绝不调用。

**运行时插值（shader 侧）**：

Flutter 不支持在 shader 里动态索引 sampler，所以用条件分支：

```glsl
uniform sampler2D uMip0;
uniform sampler2D uMip1;
uniform sampler2D uMip2;
uniform sampler2D uMip3;
uniform sampler2D uMip4;
uniform float uBlurLevel;   // 连续值，0.0 ~ 4.0

vec4 sampleBlur(vec2 uv) {
    float l = clamp(uBlurLevel, 0.0, 4.0);
    if (l < 1.0)      return mix(texture(uMip0, uv), texture(uMip1, uv), l);
    else if (l < 2.0) return mix(texture(uMip1, uv), texture(uMip2, uv), l - 1.0);
    else if (l < 3.0) return mix(texture(uMip2, uv), texture(uMip3, uv), l - 2.0);
    else              return mix(texture(uMip3, uv), texture(uMip4, uv), l - 3.0);
}
```

**成本对比**：

| 方案 | 每帧成本 | 内存 | 数据来源 |
|---|---|---|---|
| 实时高斯 σ=8 | **约 13.7ms**（Android Skia 实测）| 0 | Flutter 3.22 + Skia 112.0 实测 |
| 实时高斯 σ=4 | 约 4.2ms（Android Skia 实测）| 0 | 同上 |
| **mip 链采样** | **约 0.1ms（2 次采样）** | 原图 1/3 | — |

> **注**：上表的实时高斯数据来自 Skia 时代（Flutter 3.22）。Impeller 下会显著改善，但「越模糊越贵」的规律依然成立，且 Android 端的衰减比 iOS 剧烈得多（σ 从 4 到 8，Android 涨 226%，iOS 涨 152%）。

**关键设计决策**：mip 链**只在内容变化时重建**。如果玻璃下方的背景是静态的，mip 链只需生成一次，之后整个 App 生命周期内零成本。

## 4.4 帧缓存

**用途**：把「计算出来的中间结果」缓存成 `ui.Image`，跨帧复用。

**适用场景**：
1. 静态背景 + 玻璃 → 缓存整张合成结果
2. 复杂 morph → 缓存**顶点序列**（不是图像）
3. 方向性模糊的结果 → 缓存为纹理

**实现骨架**：

```dart
class PrebakedFrameCache {
  ui.Image? _cached;
  Object? _cacheKey;
  bool _disposed = false;

  /// 只在 key 变化时重新生成
  ui.Image? get(Object key, ui.Image Function() build) {
    if (_disposed) return null;
    if (_cacheKey == key && _cached != null) return _cached;
    _cached?.dispose();          // 必须先释放旧的
    _cached = build();
    _cacheKey = key;
    return _cached;
  }

  void dispose() {
    _disposed = true;
    _cached?.dispose();          // ui.Image 必须显式释放，否则 GPU 纹理泄漏
    _cached = null;
  }
}
```

**必须遵守**：
- `ui.Image` 必须显式 `dispose()`。它的析构**不会**自动释放 GPU 纹理，不释放就是显存泄漏。
- 缓存 key 要能准确反映「内容是否变化」，否则会显示旧内容。
- 在 `dispose()` 里清理，且要防重入（`_disposed` 标志）。

**缓存失效策略**：

| 触发条件 | 是否失效 |
|---|---|
| 背景内容变化 | ✅ |
| 布局尺寸变化 | ✅ |
| 主题 / 亮暗模式变化 | ✅ |
| 玻璃在屏幕上移动 | ❌（若烘焙的是局部坐标） |
| 动画进度变化 | ❌（这正是缓存的意义） |
| 设备旋转 | ✅ |

---

# 第 5 部分：动态模糊完整方案

## 5.1 原理

**动态模糊 = 沿运动方向的一维卷积**，不是各向同性高斯。

数学形式：
```
color(uv) = ∫ w(t) · texture(uv - v · t) dt
```
`v` 是速度矢量，`w(t)` 是权重函数。离散实现 = 沿速度方向采样 N 个点加权平均。

**物理直觉**：把过去一小段时间内物体经过的位置积分起来。人眼在快速运动时天然产生这种积分，所以动态模糊会让动画"读起来更顺"。

## 5.2 在 Flutter 里的三条实现路径

| 路径 | 成本 | 适用 |
|---|---|---|
| **方向性 FragmentShader**（多次采样） | 中（N 次采样） | **主力方案** |
| **「压缩—模糊—拉伸」技巧** | 低 | 快速近似 |
| 多帧累积（accumulation buffer） | 高 | 不推荐 |

**路径 2 的原理**：
```
scale(1+k, 1/(1+k)) → ImageFilter.blur → scale(1/(1+k), 1+k)
```
先在运动方向压缩，用各向同性模糊，再拉伸回来。
**优点**：直接用 Flutter 内置 `ImageFilter.blur`，无需自定义 shader。
**缺点**：会改变物体形状（只适合圆形 / 近似方形），两端有变形。

**路径 1 的 shader（主力方案）**：

```glsl
#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2  uSize;
uniform sampler2D uTexture;
uniform vec2  uVelocity;    // 归一化速度方向 (dx, dy)，模长 = 强度
uniform float uStrength;    // 全局强度倍率

out vec4 fragColor;

const int TAPS = 12;        // 8–16 是甜点区

void main() {
    vec2 uv = FlutterFragCoord().xy / uSize;

    vec2 dir = uVelocity;
    float len = length(dir);
    if (len < 0.0001) {                 // 速度极小时走快速路径
        fragColor = texture(uTexture, uv);
        return;
    }
    dir /= len;                         // 归一化方向

    float trail = len * uStrength;      // 拖尾总长度（UV 单位）
    vec2 step = dir * trail / float(TAPS - 1);

    vec4 acc = vec4(0.0);
    float wsum = 0.0;

    for (int i = 0; i < TAPS; i++) {
        float t = float(i) / float(TAPS - 1) - 0.5;   // -0.5 ~ 0.5
        float w = 1.0 - abs(t) * 1.4;                 // 线性衰减权重
        w = max(w, 0.0);
        acc += texture(uTexture, uv - step * float(i) + step * float(TAPS - 1) * 0.5) * w;
        wsum += w;
    }

    fragColor = acc / max(wsum, 0.0001);
}
```

**关键参数**：
- `TAPS`：采样数，**8–16 是甜点区**，超过 16 收益递减
- `uStrength` / `len`：共同决定拖尾长度，**步长自动随强度增大**，所以强度变大时不需要增加 taps

## 5.3 强度应该跟什么挂钩（关键设计决策）

**错误做法**：跟动画进度挂钩
```dart
shader.setFloat(2, controller.value * 0.05);   // ❌ 手指停下会闪
```

**正确做法**：跟**瞬时速度**挂钩，并做低通滤波

```dart
/// 一阶低通速度平滑器
class VelocitySmoother {
  double _smoothed = 0;
  double _lastValue = 0;
  bool _primed = false;

  /// alpha 越小越平滑；0.2–0.3 是经验值
  double update(double current, double dt, {double alpha = 0.25}) {
    if (!_primed || dt <= 0) {
      _primed = true;
      _lastValue = current;
      return 0;
    }
    final raw = (current - _lastValue) / dt;
    _lastValue = current;
    _smoothed = _smoothed * (1 - alpha) + raw.abs() * alpha;
    return _smoothed;
  }

  void reset() {
    _smoothed = 0;
    _lastValue = 0;
    _primed = false;
  }
}
```

**为什么必须低通**：原始速度信号含数值噪声（尤其转场时每帧的 progress 增量不稳定），直接映射到模糊强度会闪烁。社区实测的有效配置是 **90ms 滑动窗口 + sub-pixel jitter filter**（参考 `cupertino_liquid_glass` 的实现），或等价的**一阶低通 alpha ≈ 0.2–0.3**。

**两条规则**：
1. **手势驱动**（拖拽、滑动返回）→ 用真实速度测量 + 低通
2. **点击触发的固定时长转场** → 用**时间包络**，不需要测速度（见 6.3）

## 5.4 强度数值锚点（"开大一点"的量化依据）

**基准原则**：拖尾长度 ≈ 物体**每帧位移**的 **3–6 倍**。

设物体每帧位移 `d` 像素，拖尾长度应为 `3d ~ 6d`。

| 场景 | 每帧位移 | 建议拖尾长度 | `uStrength`（相对屏幕宽度） |
|---|---|---|---|
| 页面转场（全屏水平滑动） | ~15–25px | 45–150px | **0.03–0.10** |
| 元素切换（卡片 morph） | ~8–15px | 24–90px | **0.02–0.06** |
| 二级页面进入（位移 + 缩放） | ~10–20px | 30–120px | **0.025–0.08** |
| 三级页面（更深层级） | ~12–22px | 36–130px | **0.03–0.09** |
| 快速滚动 | ~30–60px | 90–360px | **0.06–0.20** |

### 关于「需要开大一点」

**开大是合理的，而且有技术依据**：

1. **高刷新率下同强度看起来更弱** —— 120Hz 每帧位移只有 60Hz 的一半，同样的模糊在世界坐标下更短。人眼积分时间不变，所以 **120Hz 下强度应该乘以约 1.5–2.0 才能匹配 60Hz 的观感**。
2. **更强的拖尾能掩盖运动中的细节缺失** —— 反而让动画"读起来更顺"，这与 `minimal` 质量档在滚动时零 shader 调用的思路一致。
3. iOS 26 的转场本身就带明显的 motion blur 观感，弱了会显得"干"。

**推荐实践值**：把上表的值 **× 1.5–2.0**，即：

| 层级 | 基础值 | **开大后（推荐）** |
|---|---|---|
| L0 ↔ L1（主页 ↔ 设置） | 0.035 | **0.055–0.070** |
| L1 ↔ L2 | 0.045 | **0.070–0.090** |
| L2 ↔ L3 | 0.055 | **0.085–0.110** |
| 深层返回 | 同上 × 0.85 | — |

**但开大必须配套降采样**，见 6.6。

## 5.5 与玻璃叠加的硬约束

> **动态模糊 shader 会给玻璃表面再插一层 saveLayer。**

premium 玻璃本身已占 2–3 次 backdrop 拷贝，再叠会直接超预算。

**正确做法**：
- 动态模糊**只作用在内容层**，不要作用在玻璃表面本身
- 玻璃表面在运动中的模糊观感，改用**降级 + 方向性拉伸**，而不是叠加 blur shader

**层级顺序**（从下到上）：

```
1. 背景（静态图 / 渐变 / 壁纸）
2. 内容层   ← 动态模糊作用在这里
3. 玻璃层（app bar / tab bar / 玻璃卡片）  ← 不叠动态模糊，用质量降级
4. 浮层（dialog / sheet / menu）
```

## 5.6 质量分级（必做）

| 档位 | 触发条件 | taps | 分辨率 |
|---|---|---|---|
| **Full** | 静止 / 极慢（< 300 px/s） | 16 | 全分辨率 |
| **Reduced** | 中速（300–2500 px/s） | 8 | 1/2 |
| **Minimal** | 高速（> 2500 px/s） | 4 | 1/4 |
| **Off** | 低端设备 / 低电量 / 无障碍「减弱动态效果」 | 0 | — |

**关键洞察**：高速时用更少的 taps **反而更好看** —— 高速时人眼本来就看不清细节，运动本身提供了模糊。这不是妥协。

**必须尊重系统设置**：
```dart
final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
if (reduceMotion) { /* 降级到 Off */ }
```

---

# 第 6 部分：页面转场动态模糊实施

> **需求**：主页面 ↔ 设置页切换、二级页面、三级页面**均需**应用动态模糊，且强度「开大一点」。

## 6.1 层级与强度设计

**核心原则**：越深的层级，模糊强度递增。

| 转场 | 视觉动作 | 推荐 `uStrength` | 时长 |
|---|---|---|---|
| **L0 ↔ L1**（主页 ↔ 设置） | 水平滑入 | **0.055–0.070** | 320ms |
| **L1 ↔ L2**（设置 → 子设置） | 水平滑入 + 轻微缩放 | **0.070–0.090** | 300ms |
| **L2 ↔ L3**（子设置 → 详情） | 水平滑入 + 更明显缩放 | **0.085–0.110** | 280ms |
| **返回**（任意层级） | 反向 | 同上 × 0.85 | 稍快（× 0.8） |

**为什么深层更强**：深层的转场通常伴随更大的缩放和更复杂的 morph，更强的模糊能统一视觉、掩盖细节跳变。

**为什么返回稍弱**：返回是"回到熟悉的地方"，视觉应该更沉稳；而且返回通常更快，强模糊会显得仓促。


## 6.2 实现骨架（不修改包，纯包装）

**路由封装**：

```dart
class MotionBlurPageRoute<T> extends PageRouteBuilder<T> {
  MotionBlurPageRoute({
    required this.builder,
    this.blurStrength = 0.07,
    this.duration = const Duration(milliseconds: 300),
  }) : super(
          transitionDuration: duration,
          reverseTransitionDuration: Duration(
            milliseconds: (duration.inMilliseconds * 0.8).round(),
          ),
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return MotionBlurTransition(
              animation: animation,
              // 返回时强度降为 0.85
              strength: blurStrength,
              child: child,
            );
          },
        );

  final WidgetBuilder builder;
  final double blurStrength;
  final Duration duration;
}
```

**核心转场组件**：

```dart
class MotionBlurTransition extends StatefulWidget {
  const MotionBlurTransition({
    super.key,
    required this.animation,
    required this.child,
    this.strength = 0.07,
    this.direction = const Offset(1, 0),   // 滑入方向
    this.useEnvelope = true,               // 点击触发 → true；手势驱动 → false
  });

  final Animation<double> animation;
  final Widget child;
  final double strength;
  final Offset direction;
  final bool useEnvelope;

  @override
  State<MotionBlurTransition> createState() => _MotionBlurTransitionState();
}

class _MotionBlurTransitionState extends State<MotionBlurTransition> {
  final _smoother = VelocitySmoother();
  final _blurStrength = ValueNotifier<double>(0.0);
  double _lastMicros = 0;

  late final Animation<double> _progress = CurvedAnimation(
    parent: widget.animation,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    _progress.addListener(_tick);
  }

  void _tick() {
    final now = DateTime.now().microsecondsSinceEpoch.toDouble();
    final dt = _lastMicros == 0 ? 1 / 60 : (now - _lastMicros) / 1e6;
    _lastMicros = now;
    if (dt <= 0 || dt > 0.1) return;   // 丢帧保护

    final double raw;
    if (widget.useEnvelope) {
      // 点击触发的固定时长转场：用时间包络，不测速度
      raw = _envelope(_progress.value);
    } else {
      // 手势驱动：真实速度
      raw = _smoother.update(_progress.value, dt);
    }
    _blurStrength.value = raw * widget.strength * 60;
  }

  /// 钟形包络：开始 0 → 中途最大 → 结束 0
  /// 指数 0.7 让顶部更平坦，模糊维持更久
  static double _envelope(double t) {
    final s = math.sin(t * math.pi);
    return s <= 0 ? 0 : math.pow(s, 0.7).toDouble();
  }

  @override
  void dispose() {
    _progress.removeListener(_tick);
    _blurStrength.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, child) {
        final t = _progress.value;
        final offset = widget.direction * (1.0 - t);
        return FractionalTranslation(
          translation: offset,
          child: ValueListenableBuilder<double>(
            valueListenable: _blurStrength,
            builder: (context, strength, inner) => MotionBlurLayer(
              velocity: offset,          // 方向即速度方向
              strength: strength,
              child: inner!,
            ),
            child: child,
          ),
        );
      },
      // 关键：child 只构建一次，不随动画重建
      child: widget.child,
    );
  }
}
```

**`MotionBlurLayer` 的接口约定**（由 agent 实现）：

```dart
/// 约定：
/// - 内部用 CustomPaint + FragmentShader（见 5.2 的 shader）
/// - velocity 为归一化方向与长度；strength 为全局倍率
/// - 必须按 5.6 做质量分级
/// - 必须在 reduce motion 时短路为直接返回 child
class MotionBlurLayer extends StatelessWidget {
  const MotionBlurLayer({
    super.key,
    required this.child,
    required this.velocity,
    required this.strength,
  });

  final Widget child;
  final Offset velocity;
  final double strength;
  // ...
}
```

## 6.3 速度来源：两种转场，两种策略

| 转场类型 | 速度来源 | 原因 |
|---|---|---|
| **点击触发**（固定时长，如点击"设置"） | **时间包络** `sin(t·π)^0.7` | 曲线解析已知，用包络更稳定，无数值噪声 |
| **手势驱动**（滑动返回、拖拽） | **真实速度测量 + 低通** | 速度由用户手指决定，必须实测 |

**为什么点击触发的转场不用测速度**：
- 转场是固定时长的曲线动画，速度曲线解析已知
- 数值微分会引入噪声，反而需要额外滤波
- 包络能精确控制"何时最模糊"，且峰值位置可调

**包络形状对比**：

| 包络 | 峰值位置 | 观感 |
|---|---|---|
| `sin(t·π)` | t = 0.5 | 对称，标准 |
| `sin(t·π)^0.7` | t = 0.5，顶部更平 | **推荐** —— 模糊维持更久，更"开大" |
| `sin(t·π)^1.5` | t = 0.5，顶部更尖 | 模糊一闪而过 |

## 6.4 二三级页面的叠加处理

当 L2 在 L1 之上转场时，**L1 需要在背景中被模糊**（视觉上被"推走"）。

```dart
transitionsBuilder: (context, animation, secondaryAnimation, child) {
  return Stack(
    children: [
      // 下层页面：由 secondaryAnimation 反向驱动，强度弱一些
      SlideTransition(
        position: Tween(
          begin: Offset.zero,
          end: const Offset(-0.3, 0),   // 只推 30%，不是全屏
        ).animate(CurvedAnimation(
          parent: secondaryAnimation,
          curve: Curves.easeOutCubic,
        )),
        child: MotionBlurLayer(
          velocity: const Offset(-1, 0),
          // 下层强度 = 上层的 0.5–0.7 倍
          strength: blurStrength * 0.6,
          child: secondaryChild,
        ),
      ),
      // 上层页面
      MotionBlurTransition(
        animation: animation,
        strength: blurStrength,
        child: child,
      ),
    ],
  );
},
```

**关键约束**：
- **下层页面的模糊强度应比上层弱（0.5–0.7 倍）** —— 下层的模糊是"被推走"的暗示，不是主体运动
- 下层只推 30% 而不是全屏滑出，配合模糊形成纵深感
- 如果下层是玻璃密集的页面，转场期间应把它降级到 `minimal`

## 6.5 与玻璃层的交互（重要）

**问题**：转场时 app bar / tab bar 如果也是玻璃的，会不会被卷进转场？

**分两种情况**：

| 结构 | 行为 | 处理 |
|---|---|---|
| 玻璃 bar 在每页的 `Scaffold` 里 | **会跟着转场** | 转场期间降级为 `minimal`，或干脆不给它叠动态模糊 |
| 玻璃 bar 在 `NavigationShell` 级别常驻 | **不参与转场** | 无需处理，**推荐** |

**推荐做法**：用 `GlassNavigationShell` 让 bar 常驻：

```dart
GlassNavigationShell(
  child: Navigator(...),   // 页面在内部切换
)
```

好处：
- bar 不参与转场动画 → 不需要模糊处理
- bar 的 `GlassBackdropGroup` 不会因转场被打断
- 符合 iOS 26 设计（pinned navigation chrome 在路由间 morph）

> **注意**：如果你的动态模糊层包住了整棵 widget 树（包括 bar），**玻璃会跟着被模糊**，产生双重视觉叠加且性能翻倍。一定要让玻璃层在模糊层之外。

## 6.6 「开大」与性能的平衡（四道保障）

用户要求开大。**开大可行，但必须配套以下四项**：

### ① 扩大降采样比例

模糊是低频信号，**在 1/2 甚至 1/4 分辨率上做视觉无损**。像素量降 4–16 倍，足以抵消强度的增加。

### ② 步长自适应

shader 里步长自动随 `len * uStrength` 增大（见 5.2 代码），所以**强度变大不需要增加 taps**。

### ③ 峰值帧降级

在包络峰值附近（`|t - 0.5| < 0.15`）自动降到 `Reduced` 档 —— 那一帧人眼最不敏感。

### ④ 模糊层独立于内容层分辨率

```dart
// 半分辨率渲染模糊层（注意配合 OverflowBox 处理布局）
RepaintBoundary(
  child: OverflowBox(
    maxWidth: double.infinity,
    maxHeight: double.infinity,
    child: Transform.scale(
      scale: 0.5,
      child: MotionBlurLayer(...),
    ),
  ),
)
```

**结论**：开到 **0.055–0.110**（约基准的 1.5–2.0 倍）是安全区间，前提是配套降采样。

---

# 第 7 部分：全局其他优化项

## 7.1 绘制层

| 项 | 做法 | 收益 |
|---|---|---|
| 消除动画驱动的 `Opacity` | → `FadeTransition` | 高 |
| 静态圆角 | `ClipRRect` → `BoxDecoration(borderRadius:)` | 中 |
| 阴影 | `boxShadow` + `borderRadius` 组合 → 预烘焙阴影资源 / 渐变近似 | 中 |
| 裁剪模式 | `Clip.antiAliasWithSaveLayer` → `Clip.hardEdge` | 中 |
| 玻璃分组 | 同屏并列玻璃 → `GlassBackdropGroup` | **极高** |
| 模糊区域 | `ClipRect` 严格限制边界 | 高 |
| 离屏内容 | `Offstage` / `TickerMode` 停止非可见动画 | 中 |
| 圆角矩形模糊 | 优先用 `BorderRadius` 承载模糊（命中 `SolidRRectBlurContents` 解析快路径） | 中 |

## 7.2 构建层

| 项 | 做法 |
|---|---|
| `const` 化 | 开启 `prefer_const_constructors` + `prefer_const_literals_to_create_immutables` 让 linter 强制 |
| `setState` 作用域 | 收缩到最小的 StatefulWidget，不要放在屏幕顶部 |
| `AnimatedBuilder.child` | 不变的内容走 `child` 逃生舱，不随动画重建 |
| `RepaintBoundary` | 每个独立动画 / 频繁更新的子树加，但**存在甜点区**（过多会 churn 纹理内存，只能靠 profile 找） |
| 列表 | 一律 `ListView.builder`，设 `itemExtent`；图片设 `cacheWidth` / `cacheHeight` |
| 布局 | 避免 `IntrinsicHeight` / `IntrinsicWidth`（尤其在滚动容器内，O(n²)） |

## 7.3 资源与内存

| 项 | 做法 |
|---|---|
| `ui.Image` 生命周期 | 必须显式 `dispose()`；否则 GPU 纹理泄漏 |
| 图片尺寸 | 提供匹配显示尺寸的资源，加载时降采样 |
| 预烘焙产物 | 只烘中间数据；绝不烘帧序列（1080p RGBA 单帧 8MB） |
| 缓存失效 | 明确的失效条件表（见 4.4） |
| mip 链 | 只在内容变化时重建 |

## 7.4 平台差异

| 平台 | 注意点 |
|---|---|
| **Android Vulkan**（旗舰） | 16-shape 全管线，异步预加载，与 iOS Metal 帧级对齐 |
| **Android GLES**（中低端） | 8-shape AST；模糊半径衰减远高于 iOS（σ 4→8 时 +226% vs iOS +152%）；建议 `androidBlurSigma` 封顶 6–8 |
| **iOS / macOS** | Metal，AOT `.metallib`，最优路径 |
| **Web / Windows / Linux** | 轻量 2D shader，静态封顶 `standard`；shader 由驱动运行时编译 |

**低端机必须验证**：Adreno 610 / Mali-G52 级别，profile 模式，目标 60Hz 下 p95 < 16.67ms。

---

# 第 8 部分：给 AI agent 的分阶段执行指令

**按阶段执行，每阶段独立验证。不要跨阶段批量改动。**

## 阶段 1：审计（不改任何代码）

1. 读 `pubspec.yaml`，确认 `liquid_glass_widgets` 版本与 `cupertino_icons` 是否为直接依赖。
2. 检查 `main.dart`：是否有 `initialize()`、`wrap()`、是否接了 `initialQuality` + `onQualityChanged` 持久化。
3. 跑第 1.2 节的 4 条 grep，列出所有隐式 saveLayer 触发点（文件:行号）。
4. grep `GlassQuality.premium`，逐处验证该表面是否**静态且不在滚动容器内**。
5. grep `FadeTransition` / `AnimatedOpacity` / `Opacity`，检查是否包裹了玻璃控件。
6. 检查是否存在「玻璃套玻璃」（`GlassCard` 内放 `GlassButton` / `GlassSlider` 等）。
7. 检查路由结构：玻璃 bar 是每页一套还是 shell 级常驻。

**输出**：问题清单表格（文件:行号 → 问题类型 → 修复建议 → 预期收益），按收益排序。

## 阶段 2：配置修复（低风险，立即做）

1. 接上 `adaptiveConfig` 的持久化（第 0.2 节 ① 的代码）。
2. 开启 `GlassAdaptiveScope(frostStep: true)`。
3. 按刷新率设置 `GlassPerformanceMonitor.rasterBudget`。
4. 修复阶段 1 中发现的反模式（`Opacity` → `FadeTransition` 等）。
5. 对并列玻璃补上 `GlassBackdropGroup`。

**验收**：冷启动无 3 秒降级；`GlassPerformanceMonitor` 无超预算告警。

## 阶段 3：质量分级

1. 列表卡片 / 背景面板 → `GlassQuality.minimal`。
2. 滚动容器内的 `premium` → 降级为 `standard` 或 `minimal`。
3. 焦点元素保留 `standard` / `premium`。

**验收**：滚动时零 shader 调用（用 `GlassPerformanceMonitor` 或 DevTools Raster 线程验证）。

## 阶段 4：预烘焙引入

1. 识别「背景不变的玻璃」→ 用 `PrebakedFrameCache` 缓存合成结果。
2. 若采用 mip 方案：实现 `buildMipChain`，**在 `initState` 或首帧后触发，不在 build 里**。
3. 实现 LUT 离线生成脚本（若需要色散 / 高光 LUT）。
4. 建立缓存失效条件表并写成注释。

**验收**：p95 帧时间相比阶段 3 下降；无 `ui.Image` 泄漏（用 DevTools Memory 对比前后快照）。

**红线**：任何 `toImage` / `toImageSync` 调用都不得出现在动画帧路径上。

## 阶段 5：动态模糊

1. 写 `motion_blur.frag`（第 5.2 节代码）。
2. 实现 `MotionBlurLayer`（含 5.6 的质量分级与 reduce motion 短路）。
3. 实现 `MotionBlurTransition` 与 `MotionBlurPageRoute`（第 6.2 节骨架）。
4. **只在内容层应用**，确保玻璃层在模糊层之外（第 5.5 节的层级顺序）。
5. 按第 6.1 节的表设置各层级强度（开大后值）。
6. 实现包络（点击触发）与速度测量（手势驱动）双路径。

**验收**：
- 玻璃 bar 不被模糊
- 转场中 p95 帧时间 < 目标刷新率预算
- reduce motion 开启时完全无模糊
- 快速连续转场不闪烁（低通滤波有效）

## 阶段 6：参数调优

1. 用第 5.4 节的表校准各层级强度，从推荐值中点开始。
2. 调整 `TAPS`（8 → 16 之间）。
3. 调整降采样比例（先 1/2，不够再 1/4）。
4. 调整包络指数（`sin^0.7` → `sin^0.5` 让模糊更持久）。
5. 在**真实低端机**上验证。

**验收**：120Hz 下 p95 < 8.33ms；60Hz 下 p95 < 16.67ms（Adreno 610 级别设备，profile 模式）。

---

# 附录 A：GlassBackdropGroup 的 6 条限制

1. `GlassTabBar` 与 `GlassAppBar` **默认 `groupBackdrop: true`**，自带分组。自己包一个 group 时，bar 会**加入**你的 group 而不是另起一个 —— 所以一个 group 包住 app bar + tab bar 能让两者共享**一次**读取。
2. **同 group 内的玻璃看不到彼此**。一个表面叠在另一个上，它的 frost 会显示两层背后的内容。
3. **重叠的玻璃必须排除**：`GlassBackdropGroup(enabled: false, ...)`。
4. **`Opacity` / `FadeTransition` / `AnimatedOpacity` 下的玻璃会自动退出 group**（任何 opacity 值，包括 1.0）。
5. **嵌套在另一玻璃表面内的玻璃也会自动退出 group**。
6. **包 screen 的 bars，不要包 `Navigator` 或 tab stack** —— offstage 的玻璃仍然算作成员。

> **第 4 条是全局动效方案的关键约束**：用 `FadeTransition` 做元素切换的淡入淡出时，玻璃会**静默脱离** backdrop group，性能直接掉回未分组状态，且不报错。
> 替代：用 `GlassMaterialize` / `GlassMaterializeTransition`，或让淡入淡出的对象是**外层容器**而不是玻璃本身。

---

# 附录 B：设计层硬约束

## 「Glass is a platter, not a wrapper」

`GlassContainer` 会给子元素设置 `avoidsRefraction: true`，**嵌套玻璃无法折射，内层效果按设计降级**。
Impeller 上开启 `useOwnLayer: true` 时，容器自身 layer 的裁剪还会**切掉交互动画中的 jelly 物理过冲**（分段控件药丸、滑块拇指）。

**不要在 `GlassCard` / `GlassContainer` 内放置**：`GlassSegmentedControl`、`GlassSlider`、`GlassSwitch`、`GlassButton`、`GlassChip`、`GlassIconButton`，或任何其他折射玻璃控件。

**可以放**：`Text`、`Icon`、`ListTile`、`CupertinoListTile`、`GlassListTile`、`GlassDivider`、标准 Flutter 表单控件。

## iOS 26 设计原则

glass **只用于导航与控制层**（nav bar、tab bar、toolbar、浮动按钮、sheet、菜单、开关类控件）。
内容区（列表单元、表格行、滚动卡片、文章块、媒体播放器）**保持不透明**。

> 这条约束直接影响「全局各元素切换」的设计：如果让内容元素也变成玻璃，是逆着 iOS 26 设计走的，且性能上最贵。

---

# 附录 C：其他必须知道的限制

1. **`cupertino_icons` 必须是直接依赖**。否则图标渲染成 `?` 方块。
   ```yaml
   dependencies:
     cupertino_icons: ^1.0.8
   ```
2. **`MaterialApp` 下需要 `Material` ancestor**（包是 Material-free 设计）：
   ```dart
   MaterialApp(
     builder: (context, child) => Material(
       type: MaterialType.transparency,
       child: child!,
     ),
     home: const MyHomePage(),
   )
   ```
   新项目直接用 `CupertinoApp` 更干净。
3. **`GlassScaffold.backgroundColor` 有双重角色**：既是无 `background:` 时的纯色底，**也是滚动边缘渐隐遮罩的颜色**。深色渐变看起来像脏灰时，显式设置它。
4. **`GlassPage.enableBackgroundSampling`**：设置了 `background:` 时默认 `true`，会做 GPU 纹理捕获。性能吃紧时显式设为 `false`。
5. **包内有 Liquid Morph Engine，不要自研**：`lib/engine/` 提供 `GlassMorphController` / `LiquidMorphState` / `LiquidMorphPhysics` / `MorphPhase` / `MorphSpeed`，已接入 `GlassMenu` 与 `GlassModalSheet.show(morphFrom:)`。文档见仓库 `docs/LIQUID_MORPH_ENGINE.md`。
6. **跨 widget 的 morph 目前无解**：包内每个原生玻璃表面是独立 view，兄弟表面无法共享一个原生效果容器。真正的跨 widget morphing 需要未来「单一原生宿主」。纯 Dart 近似路径不受此限。

---

## 参考资料

- `liquid_glass_widgets` README 与pub.dev 元数据（1.11.0）
- Flutter Impeller 源码：`GaussianBlurFilterContents`、`SolidRRectBlurContents`、`kGaussianBlurMaxKernelSize`
- flutter/flutter#170310（官方 Liquid Glass 立场）
- flutter/flutter#193366（Flutter GPU 实测限制）
- Flutter 3.41 release notes（bounded blur 修复）
- 动态模糊实现参考：`flutterfx_widgets` 的 MotionBlur 系统
- 降采样与多 pass 优化：Flutter shader 多 pass 渲染实践
- Spring vs Curve 分析：Flutter 动效模型对比
- 实时高斯模糊成本：Flutter 3.22 + Skia 112.0 实测数据（Android/iOS 对比）
- 3D LUT 展平方案：颜色查找表渲染实践
