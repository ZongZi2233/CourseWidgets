# Transitions - lib/ui/transitions

此类用于配置应用内**所有页面路由间**（Push 或 Pop）时的定制视觉动效拦截与包装器。其功能高度集中在保持应用整体非原生态的平滑和连贯体验。

## 主要构建器

*   `smooth_slide_transitions.dart`: 
    - **`SmoothSlideTransitionsBuilder`**
      - 主力使用的 iOS 风格高仿的非线性滑动特效配置。对从右进从左退的操作绑定了强烈减速拉弓抛线（`Curves.easeOutExpo`）与后退出变暗的深层视差隔离 (`FadeTransition` / `dimming`)，解决传统 Zoom 的闪出。
    - **`PredictiveBackPageTransitionsBuilder`** (自 v2.5.5)
      - 面向 `Android 14+` 的纯正 Predictive Back 后退调度器。
      - 原理是通过彻底放弃对 Android 原生推入系统的重写，将其100%交还给底层引擎，解决由于自研包裹器干扰导致的卡片黏连失败或错乱跳帧，保证了卡片拖拽式的真·视差手势。
    - **`TransparentMaterialPageRoute`**
      - 返回透明通道标志不阻挡下一级。用于一些弹窗或不希望覆盖底色背景的高阶特殊页面路由请求。
