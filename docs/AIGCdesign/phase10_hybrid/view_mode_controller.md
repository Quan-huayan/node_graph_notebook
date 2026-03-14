# 视图模式控制器设计文档

## 1. 概述

### 1.1 职责
视图模式控制器负责在 Canvas 渲染和 WebGL 渲染之间切换，实现：
- 自动模式选择
- 平滑的模式切换
- 性能监控
- 降级策略

### 1.2 目标
- **性能**: 自动选择最佳渲染模式
- **平滑**: 模式切换无感知
- **稳定**: 出现问题时自动降级
- **可配置**: 支持手动模式选择

### 1.3 关键挑战
- **状态同步**: 两种模式之间的状态同步
- **资源管理**: 正确切换渲染资源
- **性能监控**: 实时评估渲染性能
- **降级决策**: 何时触发模式切换

## 2. 架构设计

### 2.1 组件结构

```
ViewModeController
    │
    ├── ViewMode (视图模式)
    │   ├── canvas (Canvas 模式)
    │   ├── webgl (WebGL 模式)
    │   └── auto (自动模式)
    │
    ├── RenderContext (渲染上下文)
    │   ├── canvasRenderer (Canvas 渲染器)
    │   ├── webglRenderer (WebGL 渲染器)
    │   └── currentMode (当前模式)
    │
    ├── PerformanceMonitor (性能监控器)
    │   ├── fps (帧率)
    │   ├── frameTime (帧时间)
    │   └── drawCalls (绘制调用数)
    │
    ├── ModeSwitcher (模式切换器)
    │   ├── switchTo() (切换到指定模式)
    │   ├── switchToCanvas() (切换到 Canvas)
    │   └── switchToWebGL() (切换到 WebGL)
    │
    └── FallbackStrategy (降级策略)
        ├── onWebGLFailure() (WebGL 失败降级)
        └── onPerformanceDegraded() (性能降级)
```

### 2.2 接口定义

#### 视图模式

```dart
/// 视图模式
enum ViewMode {
  /// Canvas 模式（软件渲染）
  canvas,

  /// WebGL 模式（硬件加速）
  webgl,

  /// 自动模式（根据性能自动选择）
  auto,
}

/// 渲染模式状态
class RenderModeState {
  /// 当前模式
  final ViewMode mode;

  /// 是否支持 WebGL
  final bool webGLSupported;

  /// 是否正在切换
  final bool isSwitching;

  /// 切换进度（0-1）
  final double switchProgress;

  /// 上次切换时间
  final DateTime? lastSwitchTime;

  RenderModeState({
    required this.mode,
    this.webGLSupported = true,
    this.isSwitching = false,
    this.switchProgress = 0.0,
    this.lastSwitchTime,
  });

  /// 复制并修改
  RenderModeState copyWith({
    ViewMode? mode,
    bool? webGLSupported,
    bool? isSwitching,
    double? switchProgress,
    DateTime? lastSwitchTime,
  }) {
    return RenderModeState(
      mode: mode ?? this.mode,
      webGLSupported: webGLSupported ?? this.webGLSupported,
      isSwitching: isSwitching ?? this.isSwitching,
      switchProgress: switchProgress ?? this.switchProgress,
      lastSwitchTime: lastSwitchTime ?? this.lastSwitchTime,
    );
  }
}
```

#### 性能监控器

```dart
/// 性能监控器
class PerformanceMonitor {
  /// 帧率（FPS）
  double _fps = 60.0;

  /// 帧时间（毫秒）
  double _frameTime = 16.67;

  /// 绘制调用数
  int _drawCalls = 0;

  /// 渲染对象数
  int _renderedObjects = 0;

  /// GPU 内存使用（MB）
  double _gpuMemory = 0.0;

  /// 监控历史
  final List<double> _fpsHistory = [];
  final int _historySize = 60; // 保留最近 60 帧

  /// 最小可接受 FPS
  final double minAcceptableFPS = 30.0;

  /// 最大可接受帧时间（毫秒）
  final double maxAcceptableFrameTime = 33.33;

  /// 更新性能指标
  void update({
    required double frameTime,
    required int drawCalls,
    required int renderedObjects,
    double? gpuMemory,
  }) {
    _frameTime = frameTime;
    _fps = 1000.0 / frameTime;
    _drawCalls = drawCalls;
    _renderedObjects = renderedObjects;
    if (gpuMemory != null) {
      _gpuMemory = gpuMemory;
    }

    // 更新历史
    _fpsHistory.add(_fps);
    if (_fpsHistory.length > _historySize) {
      _fpsHistory.removeAt(0);
    }
  }

  /// 获取当前 FPS
  double get fps => _fps;

  /// 获取平均 FPS
  double get averageFPS {
    if (_fpsHistory.isEmpty) return _fps;
    return _fpsHistory.reduce((a, b) => a + b) / _fpsHistory.length;
  }

  /// 获取帧时间
  double get frameTime => _frameTime;

  /// 获取绘制调用数
  int get drawCalls => _drawCalls;

  /// 获取渲染对象数
  int get renderedObjects => _renderedObjects;

  /// 获取 GPU 内存使用
  double get gpuMemory => _gpuMemory;

  /// 检查性能是否可接受
  bool get isPerformanceAcceptable {
    return averageFPS >= minAcceptableFPS &&
        _frameTime <= maxAcceptableFrameTime;
  }

  /// 检查是否需要降级
  bool get shouldDowngrade {
    return averageFPS < minAcceptableFPS * 0.8; // 低于 80% 阈值
  }

  /// 检查是否可以升级
  bool get shouldUpgrade {
    return averageFPS > minAcceptableFPS * 1.5; // 高于 150% 阈值
  }

  /// 获取性能报告
  PerformanceReport getReport() {
    return PerformanceReport(
      fps: _fps,
      averageFPS: averageFPS,
      frameTime: _frameTime,
      drawCalls: _drawCalls,
      renderedObjects: _renderedObjects,
      gpuMemory: _gpuMemory,
      isAcceptable: isPerformanceAcceptable,
    );
  }

  /// 重置监控
  void reset() {
    _fpsHistory.clear();
    _drawCalls = 0;
    _renderedObjects = 0;
  }
}

/// 性能报告
class PerformanceReport {
  final double fps;
  final double averageFPS;
  final double frameTime;
  final int drawCalls;
  final int renderedObjects;
  final double gpuMemory;
  final bool isAcceptable;

  PerformanceReport({
    required this.fps,
    required this.averageFPS,
    required this.frameTime,
    required this.drawCalls,
    required this.renderedObjects,
    required this.gpuMemory,
    required this.isAcceptable,
  });

  @override
  String toString() {
    return 'PerformanceReport('
        'FPS: ${fps.toStringAsFixed(1)}, '
        'Avg FPS: ${averageFPS.toStringAsFixed(1)}, '
        'Frame Time: ${frameTime.toStringAsFixed(2)}ms, '
        'Draw Calls: $drawCalls, '
        'Objects: $renderedObjects, '
        'GPU Memory: ${gpuMemory.toStringAsFixed(1)}MB, '
        'Acceptable: $isAcceptable'
        ')';
  }
}
```

#### 视图模式控制器

```dart
/// 视图模式控制器
class ViewModeController {
  /// 当前状态
  RenderModeState _state = RenderModeState(mode: ViewMode.auto);

  /// 性能监控器
  final PerformanceMonitor _performanceMonitor = PerformanceMonitor();

  /// Canvas 渲染器
  CanvasRenderer? _canvasRenderer;

  /// WebGL 渲染器
  WebGLRenderer? _webglRenderer;

  /// 当前渲染器
  Renderer? _currentRenderer;

  /// 是否启用自动切换
  bool autoSwitchEnabled = true;

  /// 模式切换冷却时间（秒）
  final int switchCooldownSeconds = 5;

  /// 上次切换时间
  DateTime? _lastSwitchTime;

  /// 状态变化监听器
  final List<Function(RenderModeState)> _listeners = [];

  ViewModeController();

  /// 初始化
  Future<void> initialize() async {
    // 检查 WebGL 支持
    final webGLSupported = await _checkWebGLSupport();

    _state = RenderModeState(
      mode: ViewMode.auto,
      webGLSupported: webGLSupported,
    );

    // 根据支持情况选择初始模式
    if (webGLSupported) {
      await switchToWebGL();
    } else {
      await switchToCanvas();
    }

    // 启动性能监控
    _startPerformanceMonitoring();
  }

  /// 检查 WebGL 支持
  Future<bool> _checkWebGLSupport() async {
    try {
      // 尝试创建 WebGL 上下文
      // 这里需要根据实际平台实现
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 切换到指定模式
  Future<void> switchTo(ViewMode mode) async {
    if (_state.isSwitching) {
      throw StateError('正在切换中，请稍后');
    }

    // 检查冷却时间
    if (_lastSwitchTime != null) {
      final elapsed = DateTime.now().difference(_lastSwitchTime!);
      if (elapsed.inSeconds < switchCooldownSeconds) {
        throw StateError('切换冷却中，请稍后再试');
      }
    }

    // 更新状态
    _state = _state.copyWith(
      isSwitching: true,
      switchProgress: 0.0,
    );
    _notifyListeners();

    try {
      switch (mode) {
        case ViewMode.canvas:
          await _performSwitchToCanvas();
          break;

        case ViewMode.webgl:
          await _performSwitchToWebGL();
          break;

        case ViewMode.auto:
          await _performAutoSwitch();
          break;
      }

      _lastSwitchTime = DateTime.now();
    } finally {
      _state = _state.copyWith(
        isSwitching: false,
        switchProgress: 1.0,
        lastSwitchTime: _lastSwitchTime,
      );
      _notifyListeners();
    }
  }

  /// 切换到 Canvas 模式
  Future<void> switchToCanvas() async {
    await switchTo(ViewMode.canvas);
  }

  /// 切换到 WebGL 模式
  Future<void> switchToWebGL() async {
    if (!_state.webGLSupported) {
      throw StateError('WebGL 不支持');
    }
    await switchTo(ViewMode.webgl);
  }

  /// 执行切换到 Canvas
  Future<void> _performSwitchToCanvas() async {
    // 1. 准备切换
    _updateSwitchProgress(0.1);

    // 2. 保存当前渲染状态
    final currentState = await _currentRenderer?.saveState();
    _updateSwitchProgress(0.3);

    // 3. 切换渲染器
    _currentRenderer = _canvasRenderer;
    _updateSwitchProgress(0.6);

    // 4. 恢复渲染状态
    if (currentState != null) {
      await _currentRenderer?.restoreState(currentState);
    }
    _updateSwitchProgress(0.9);

    // 5. 完成切换
    _state = _state.copyWith(mode: ViewMode.canvas);
    _updateSwitchProgress(1.0);
  }

  /// 执行切换到 WebGL
  Future<void> _performSwitchToWebGL() async {
    // 1. 准备切换
    _updateSwitchProgress(0.1);

    // 2. 保存当前渲染状态
    final currentState = await _currentRenderer?.saveState();
    _updateSwitchProgress(0.3);

    // 3. 切换渲染器
    _currentRenderer = _webglRenderer;
    _updateSwitchProgress(0.6);

    // 4. 恢复渲染状态
    if (currentState != null) {
      await _currentRenderer?.restoreState(currentState);
    }
    _updateSwitchProgress(0.9);

    // 5. 完成切换
    _state = _state.copyWith(mode: ViewMode.webgl);
    _updateSwitchProgress(1.0);
  }

  /// 执行自动切换
  Future<void> _performAutoSwitch() async {
    if (_performanceMonitor.shouldDowngrade && _state.mode == ViewMode.webgl) {
      await _performSwitchToCanvas();
    } else if (_performanceMonitor.shouldUpgrade && _state.mode == ViewMode.canvas) {
      await _performSwitchToWebGL();
    }
  }

  /// 更新切换进度
  void _updateSwitchProgress(double progress) {
    _state = _state.copyWith(switchProgress: progress);
    _notifyListeners();
  }

  /// 启动性能监控
  void _startPerformanceMonitoring() {
    // 每秒检查一次性能
    Timer.periodic(const Duration(seconds: 1), (_) {
      if (autoSwitchEnabled && _state.mode == ViewMode.auto) {
        _performAutoSwitch();
      }
    });
  }

  /// 添加监听器
  void addListener(Function(RenderModeState) listener) {
    _listeners.add(listener);
  }

  /// 移除监听器
  void removeListener(Function(RenderModeState) listener) {
    _listeners.remove(listener);
  }

  /// 通知监听器
  void _notifyListeners() {
    for (final listener in _listeners) {
      listener(_state);
    }
  }

  /// 获取当前状态
  RenderModeState get state => _state;

  /// 获取性能监控器
  PerformanceMonitor get performanceMonitor => _performanceMonitor;

  /// 获取当前渲染器
  Renderer? get currentRenderer => _currentRenderer;
}
```

## 3. 核心算法

### 3.1 自动模式选择

**问题描述**:
根据性能指标自动选择最佳渲染模式。

**算法描述**:
基于 FPS、帧时间等指标，动态切换渲染模式。

**伪代码**:
```
function autoSelectMode(monitor, currentMode):
    if monitor.shouldDowngrade and currentMode == webgl:
        return canvas
    elif monitor.shouldUpgrade and currentMode == canvas:
        return webgl
    else:
        return currentMode
```

**复杂度分析**:
- 时间复杂度: O(1)
- 空间复杂度: O(1)

### 3.2 平滑模式切换

**问题描述**:
在两种渲染模式之间平滑切换，避免画面闪烁。

**算法描述**:
使用双缓冲和交叉淡入淡出实现平滑切换。

**伪代码**:
```
function smoothSwitch(fromRenderer, toRenderer, progress):
    // 渲染到两个缓冲区
    fromBuffer = fromRenderer.render()
    toBuffer = toRenderer.render()

    // 混合两个缓冲区
    alpha = easeInOut(progress)
    finalBuffer = blend(fromBuffer, toBuffer, alpha)

    return finalBuffer
```

**实现**:

```dart
/// 平滑切换渲染器
class SmoothSwitchRenderer extends Renderer {
  /// 源渲染器
  Renderer? _fromRenderer;

  /// 目标渲染器
  Renderer? _toRenderer;

  /// 切换进度（0-1）
  double _progress = 0.0;

  /// 切换持续时间（秒）
  final double switchDuration = 0.5;

  /// 开始切换
  void startSwitch(Renderer from, Renderer to) {
    _fromRenderer = from;
    _toRenderer = to;
    _progress = 0.0;
  }

  /// 更新切换进度
  void update(double delta) {
    if (_progress < 1.0) {
      _progress += delta / switchDuration;
      _progress = _progress.clamp(0.0, 1.0);
    }
  }

  @override
  void render(Canvas canvas) {
    if (_fromRenderer == null || _toRenderer == null) {
      return;
    }

    // 渲染两个场景
    final fromCanvas = _fromRenderer!.renderToCanvas();
    final toCanvas = _toRenderer!.renderToCanvas();

    // 计算混合因子
    final alpha = _easeInOutCubic(_progress);

    // 混合两个场景
    canvas.save();
    canvas.saveLayer(null, Paint());

    // 绘制源场景（淡出）
    canvas.save();
    final paint1 = Paint()..color = Color.fromRGBO(255, 255, 255, 1 - alpha);
    canvas.paint(paint1);
    _fromRenderer!.render(canvas);
    canvas.restore();

    // 绘制目标场景（淡入）
    canvas.save();
    final paint2 = Paint()..color = Color.fromRGBO(255, 255, 255, alpha);
    canvas.paint(paint2);
    _toRenderer!.render(canvas);
    canvas.restore();

    canvas.restore();
    canvas.restore();
  }

  /// 缓动函数
  double _easeInOutCubic(double t) {
    return t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2;
  }
}
```

## 4. 降级策略

### 4.1 WebGL 失败降级

```dart
/// WebGL 失败降级策略
class WebGLFallbackStrategy {
  /// 最大重试次数
  final int maxRetries = 3;

  /// 当前重试次数
  int _currentRetries = 0;

  /// 处理 WebGL 失败
  Future<void> handleWebGLFailure(
    ViewModeController controller,
    Object error,
  ) async {
    // 记录错误
    debugPrint('WebGL 渲染失败: $error');

    // 检查是否可以重试
    if (_currentRetries < maxRetries) {
      _currentRetries++;
      debugPrint('尝试重新初始化 WebGL ($_currentRetries/$maxRetries)');

      try {
        await controller.switchToWebGL();
        return;
      } catch (e) {
        debugPrint('WebGL 重试失败: $e');
      }
    }

    // 降级到 Canvas
    debugPrint('降级到 Canvas 模式');
    await controller.switchToCanvas();
    controller.autoSwitchEnabled = false; // 禁用自动切换
  }
}
```

### 4.2 性能降级

```dart
/// 性能降级策略
class PerformanceFallbackStrategy {
  /// 低性能持续时间阈值（秒）
  final int lowPerformanceThresholdSeconds = 10;

  /// 低性能开始时间
  DateTime? _lowPerformanceStartTime;

  /// 检查是否需要降级
  bool shouldDowngrade(PerformanceMonitor monitor) {
    if (!monitor.isPerformanceAcceptable) {
      if (_lowPerformanceStartTime == null) {
        _lowPerformanceStartTime = DateTime.now();
        return false;
      }

      final elapsed = DateTime.now()
          .difference(_lowPerformanceStartTime!)
          .inSeconds;

      return elapsed >= lowPerformanceThresholdSeconds;
    } else {
      _lowPerformanceStartTime = null;
      return false;
    }
  }

  /// 执行降级
  Future<void> performDowngrade(ViewModeController controller) async {
    if (controller.state.mode == ViewMode.webgl) {
      debugPrint('性能不足，降级到 Canvas 模式');
      await controller.switchToCanvas();
    }
  }
}
```

## 5. 性能考虑

### 5.1 概念性性能指标

| 指标 | Canvas 模式 | WebGL 模式 |
|------|-------------|-----------|
| 最大对象数 | 1000 | 10000+ |
| 平均 FPS | 30-45 | 60 |
| 内存使用 | 低 | 中 |
| CPU 使用 | 高 | 低 |
| GPU 使用 | 低 | 高 |

### 5.2 模式选择建议

```dart
/// 模式选择建议
class ViewModeRecommendation {
  /// 根据场景特征推荐模式
  static ViewMode recommendMode({
    required int objectCount,
    required bool hasComplexEffects,
    required bool requiresHighFrameRate,
    required bool webGLSupported,
  }) {
    // WebGL 不支持
    if (!webGLSupported) {
      return ViewMode.canvas;
    }

    // 大量对象
    if (objectCount > 5000) {
      return ViewMode.webgl;
    }

    // 复杂效果
    if (hasComplexEffects) {
      return ViewMode.webgl;
    }

    // 需要高帧率
    if (requiresHighFrameRate) {
      return ViewMode.webgl;
    }

    // 默认自动模式
    return ViewMode.auto;
  }
}
```

## 6. 关键文件清单

```
lib/flame/rendering/hybrid/
├── view_mode_controller.dart       # 视图模式控制器
├── view_mode.dart                  # 视图模式定义
├── render_mode_state.dart          # 渲染模式状态
├── performance_monitor.dart        # 性能监控器
├── mode_switcher.dart              # 模式切换器
├── fallback_strategy.dart          # 降级策略
└── smooth_switch_renderer.dart     # 平滑切换渲染器
```

---

**文档所有者**: Node Graph Notebook 架构组
**最后更新**: 2025-01-14
