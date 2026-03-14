# LOD（细节层次）系统设计文档

## 1. 概述

### 1.1 职责
LOD 系统负责根据对象与观察者的距离或缩放级别动态调整渲染细节，实现：
- 自适应渲染质量
- 减少 GPU 负载
- 提高大场景性能
- 保持视觉质量

### 1.2 目标
- **性能**: GPU 负载降低 30-50%
- **质量**: 视觉质量无明显下降
- **平滑**: LOD 切换无突兀感
- **可配置**: 支持自定义 LOD 策略

### 1.3 关键挑战
- **LOD 级别定义**: 合理划分细节级别
- **过渡平滑**: LOD 切换的平滑过渡
- **缓存管理**: 不同 LOD 资源的缓存
- **性能监控**: 实时监控 LOD 效果

## 2. 架构设计

### 2.1 组件结构

```
LODSystem
    │
    ├── LODLevel (LOD 级别)
    │   ├── level (级别编号)
    │   ├── minDistance (最小距离)
    │   ├── maxDistance (最大距离)
    │   └── renderer (渲染器)
    │
    ├── LODObject (LOD 对象)
    │   ├── levels (LOD 级别列表)
    │   ├── currentLevel (当前级别)
    │   └── transition (过渡状态)
    │
    ├── LODManager (LOD 管理器)
    │   ├── updateLOD() (更新 LOD)
    │   ├── calculateLevel() (计算级别)
    │   └── smoothTransition() (平滑过渡)
    │
    └── LODStrategy (LOD 策略)
        ├── DistanceLODStrategy (距离策略)
        ├── ScreenSizeLODStrategy (屏幕大小策略)
        └── ZoomLODStrategy (缩放策略)
```

### 2.2 接口定义

#### LOD 级别

```dart
/// LOD 级别
class LODLevel {
  /// 级别编号（0 = 最高质量）
  final int level;

  /// 最小距离（世界坐标）
  final double minDistance;

  /// 最大距离（世界坐标）
  final double maxDistance;

  /// 最小缩放级别
  final double minZoom;

  /// 最大缩放级别
  final double maxZoom;

  /// 渲染器
  final LODRenderer renderer;

  LODLevel({
    required this.level,
    required this.minDistance,
    required this.maxDistance,
    required this.minZoom,
    required this.maxZoom,
    required this.renderer,
  });

  /// 检查是否适用于给定距离
  bool isApplicableForDistance(double distance) {
    return distance >= minDistance && distance < maxDistance;
  }

  /// 检查是否适用于给定缩放级别
  bool isApplicableForZoom(double zoom) {
    return zoom >= minZoom && zoom < maxZoom;
  }
}

/// LOD 渲染器接口
abstract class LODRenderer {
  /// 渲染对象
  void render(Canvas canvas, Vector2 position, Size size);

  /// 获取渲染复杂度（用于性能分析）
  int get complexity;
}
```

#### LOD 对象

```dart
/// LOD 对象
class LODObject {
  /// 对象 ID
  final String id;

  /// LOD 级别列表（按优先级排序）
  final List<LODLevel> levels;

  /// 当前 LOD 级别
  LODLevel _currentLevel;

  /// 目标 LOD 级别（用于过渡）
  LODLevel? _targetLevel;

  /// 过渡进度（0-1）
  double _transitionProgress = 0.0;

  /// 是否正在过渡
  bool get isTransitioning => _targetLevel != null;

  /// 对象位置
  Vector2 position;

  LODObject({
    required this.id,
    required this.levels,
    required this.position,
  }) : _currentLevel = levels.first;

  /// 当前 LOD 级别
  LODLevel get currentLevel => _currentLevel;

  /// 更新 LOD 级别
  void updateLevel(LODLevel newLevel, {bool smooth = true}) {
    if (newLevel == _currentLevel) return;

    if (smooth && !isTransitioning) {
      // 开始平滑过渡
      _targetLevel = newLevel;
      _transitionProgress = 0.0;
    } else {
      // 直接切换
      _currentLevel = newLevel;
      _targetLevel = null;
    }
  }

  /// 更新过渡
  void updateTransition(double delta) {
    if (!isTransitioning) return;

    _transitionProgress += delta * 2.0; // 0.5 秒过渡时间

    if (_transitionProgress >= 1.0) {
      // 过渡完成
      _currentLevel = _targetLevel!;
      _targetLevel = null;
      _transitionProgress = 0.0;
    }
  }

  /// 渲染（处理过渡）
  void render(Canvas canvas, Vector2 viewportPosition) {
    if (isTransitioning) {
      // 渲染两个级别并混合
      _renderTransition(canvas);
    } else {
      // 渲染当前级别
      _currentLevel.renderer.render(
        canvas,
        position,
        Size(100, 100), // 从组件获取
      );
    }
  }

  /// 渲染过渡
  void _renderTransition(Canvas canvas) {
    final progress = _transitionProgress;
    final alpha = _easeInOutCubic(progress);

    // 渲染当前级别（淡出）
    final paint1 = Paint()..color = Color.fromRGBO(255, 255, 255, 1 - alpha);
    canvas.save();
    _currentLevel.renderer.render(canvas, position, Size(100, 100));
    canvas.restore();

    // 渲染目标级别（淡入）
    final paint2 = Paint()..color = Color.fromRGBO(255, 255, 255, alpha);
    canvas.save();
    canvas.scale(alpha);
    _targetLevel!.renderer.render(canvas, position, Size(100, 100));
    canvas.restore();
  }

  /// 缓动函数
  double _easeInOutCubic(double t) {
    return t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2;
  }
}
```

#### LOD 策略

```dart
/// LOD 策略接口
abstract class LODStrategy {
  /// 计算适用的 LOD 级别
  LODLevel? calculateLevel(
    LODObject object,
    Viewport viewport,
    Vector2 cameraPosition,
  );
}

/// 距离 LOD 策略
class DistanceLODStrategy implements LODStrategy {
  @override
  LODLevel? calculateLevel(
    LODObject object,
    Viewport viewport,
    Vector2 cameraPosition,
  ) {
    // 计算对象到相机的距离
    final distance = (object.position - cameraPosition).length;

    // 查找适用的 LOD 级别
    for (final level in object.levels) {
      if (level.isApplicableForDistance(distance)) {
        return level;
      }
    }

    // 返回最低级别
    return object.levels.last;
  }
}

/// 屏幕大小 LOD 策略
class ScreenSizeLODStrategy implements LODStrategy {
  @override
  LODLevel? calculateLevel(
    LODObject object,
    Viewport viewport,
    Vector2 cameraPosition,
  ) {
    // 计算对象在屏幕上的大小
    final screenPos = viewport.worldToScreen(object.position);
    final screenSize = 100.0 * viewport.zoom; // 假设对象大小为 100

    // 根据屏幕大小选择 LOD
    for (final level in object.levels) {
      final minSize = level.minDistance; // 重用字段表示最小屏幕大小
      final maxSize = level.maxDistance; // 重用字段表示最大屏幕大小

      if (screenSize >= minSize && screenSize < maxSize) {
        return level;
      }
    }

    return object.levels.last;
  }
}

/// 缩放 LOD 策略
class ZoomLODStrategy implements LODStrategy {
  @override
  LODLevel? calculateLevel(
    LODObject object,
    Viewport viewport,
    Vector2 cameraPosition,
  ) {
    final zoom = viewport.zoom;

    // 查找适用的 LOD 级别
    for (final level in object.levels) {
      if (level.isApplicableForZoom(zoom)) {
        return level;
      }
    }

    return object.levels.last;
  }
}
```

#### LOD 管理器

```dart
/// LOD 管理器
class LODManager {
  /// LOD 对象列表
  final List<LODObject> _objects = [];

  /// LOD 策略
  LODStrategy strategy = ZoomLODStrategy();

  /// 视口
  Viewport viewport;

  /// 相机位置
  Vector2 cameraPosition;

  /// 是否启用 LOD
  bool enabled = true;

  /// 是否启用平滑过渡
  bool smoothTransition = true;

  LODManager({
    required this.viewport,
    required this.cameraPosition,
  });

  /// 添加 LOD 对象
  void addObject(LODObject object) {
    _objects.add(object);
  }

  /// 移除 LOD 对象
  void removeObject(LODObject object) {
    _objects.remove(object);
  }

  /// 更新所有 LOD 对象
  void update(double delta) {
    if (!enabled) return;

    for (final object in _objects) {
      // 计算适用的 LOD 级别
      final newLevel = strategy.calculateLevel(
        object,
        viewport,
        cameraPosition,
      );

      if (newLevel != null) {
        // 更新 LOD 级别
        object.updateLevel(newLevel, smooth: smoothTransition);
      }

      // 更新过渡
      if (object.isTransitioning) {
        object.updateTransition(delta);
      }
    }
  }

  /// 设置 LOD 策略
  void setStrategy(LODStrategy newStrategy) {
    strategy = newStrategy;
  }

  /// 清空所有对象
  void clear() {
    _objects.clear();
  }
}
```

## 3. 核心算法

### 3.1 LOD 级别计算

**问题描述**:
根据对象与相机的距离或缩放级别计算适用的 LOD 级别。

**算法描述**:
使用分段函数，根据距离/缩放级别映射到对应的 LOD 级别。

**伪代码**:
```
function calculateLODLevel(distance, levels):
    for level in levels:
        if distance >= level.minDistance and distance < level.maxDistance:
            return level
    return levels.last  // 默认最低级别
```

**复杂度分析**:
- 时间复杂度: O(n)，n 为 LOD 级别数（通常很小，< 5）
- 空间复杂度: O(1)

### 3.2 平滑过渡算法

**问题描述**:
在不同 LOD 级别之间平滑过渡，避免突兀切换。

**算法描述**:
使用插值和透明度混合两个 LOD 级别的渲染结果。

**伪代码**:
```
function renderTransition(currentLevel, targetLevel, progress):
    // 计算混合因子
    alpha = easeInOutCubic(progress)

    // 渲染当前级别（淡出）
    saveCanvas()
    setOpacity(1 - alpha)
    currentLevel.renderer.render()
    restoreCanvas()

    // 渲染目标级别（淡入）
    saveCanvas()
    setOpacity(alpha)
    targetLevel.renderer.render()
    restoreCanvas()
```

**复杂度分析**:
- 时间复杂度: O(1)
- 空间复杂度: O(1)

## 4. 具体 LOD 实现

### 4.1 节点 LOD

```dart
/// 节点 LOD 渲染器
class NodeLODRenderer implements LODRenderer {
  /// LOD 级别
  final int level;

  /// 节点数据
  final Node node;

  NodeLODRenderer({
    required this.level,
    required this.node,
  });

  @override
  void render(Canvas canvas, Vector2 position, Size size) {
    switch (level) {
      case 0: // 高质量：完整渲染
        _renderFull(canvas, position, size);
        break;

      case 1: // 中等质量：简化渲染
        _renderSimplified(canvas, position, size);
        break;

      case 2: // 低质量：仅边框
        _renderBorderOnly(canvas, position, size);
        break;

      case 3: // 最低质量：仅矩形
        _renderRectOnly(canvas, position, size);
        break;
    }
  }

  void _renderFull(Canvas canvas, Vector2 position, Size size) {
    // 完整渲染：背景、边框、文本、图标等
    final rect = Rect.fromCenter(
      center: Offset(position.x, position.y),
      width: size.width,
      height: size.height,
    );

    // 背景
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(rect, bgPaint);

    // 边框
    final borderPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(rect, borderPaint);

    // 文本
    final textPainter = TextPainter(
      text: TextSpan(text: node.content),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(position.x - textPainter.width / 2, position.y - textPainter.height / 2),
    );
  }

  void _renderSimplified(Canvas canvas, Vector2 position, Size size) {
    // 简化渲染：背景、边框、简短文本
    final rect = Rect.fromCenter(
      center: Offset(position.x, position.y),
      width: size.width,
      height: size.height,
    );

    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(rect, bgPaint);

    final borderPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRect(rect, borderPaint);

    // 只显示前10个字符
    final shortContent = node.content.length > 10
        ? '${node.content.substring(0, 10)}...'
        : node.content;

    final textPainter = TextPainter(
      text: TextSpan(text: shortContent),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(position.x - textPainter.width / 2, position.y));
  }

  void _renderBorderOnly(Canvas canvas, Vector2 position, Size size) {
    // 仅边框
    final rect = Rect.fromCenter(
      center: Offset(position.x, position.y),
      width: size.width,
      height: size.height,
    );

    final borderPaint = Paint()
      ..color = Colors.grey
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRect(rect, borderPaint);
  }

  void _renderRectOnly(Canvas canvas, Vector2 position, Size size) {
    // 仅填充矩形
    final rect = Rect.fromCenter(
      center: Offset(position.x, position.y),
      width: size.width,
      height: size.height,
    );

    final paint = Paint()..color = Colors.grey.withOpacity(0.3);
    canvas.drawRect(rect, paint);
  }

  @override
  int get complexity {
    switch (level) {
      case 0: return 100;
      case 1: return 50;
      case 2: return 20;
      case 3: return 5;
      default: return 0;
    }
  }
}
```

### 4.2 连接线 LOD

```dart
/// 连接线 LOD 渲染器
class ConnectionLODRenderer implements LODRenderer {
  /// LOD 级别
  final int level;

  /// 连接数据
  final Connection connection;

  ConnectionLODRenderer({
    required this.level,
    required this.connection,
  });

  @override
  void render(Canvas canvas, Vector2 position, Size size) {
    switch (level) {
      case 0: // 高质量：贝塞尔曲线 + 箭头
        _renderBezier(canvas, position, size);
        break;

      case 1: // 中等质量：直线 + 箭头
        _renderStraight(canvas, position, size);
        break;

      case 2: // 低质量：细直线
        _renderThin(canvas, position, size);
        break;
    }
  }

  void _renderBezier(Canvas canvas, Vector2 position, Size size) {
    // 绘制贝塞尔曲线
    final path = Path();
    // ... 贝塞尔曲线逻辑

    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, paint);

    // 绘制箭头
    _drawArrow(canvas, position);
  }

  void _renderStraight(Canvas canvas, Vector2 position, Size size) {
    // 绘制直线
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(position.x, position.y),
      Offset(position.x + size.width, position.y + size.height),
      paint,
    );

    _drawArrow(canvas, position);
  }

  void _renderThin(Canvas canvas, Vector2 position, Size size) {
    // 绘制细直线
    final paint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(position.x, position.y),
      Offset(position.x + size.width, position.y + size.height),
      paint,
    );
  }

  void _drawArrow(Canvas canvas, Vector2 position) {
    // 绘制箭头
    final arrowPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    // ... 箭头绘制逻辑
  }

  @override
  int get complexity {
    switch (level) {
      case 0: return 50;
      case 1: return 20;
      case 2: return 5;
      default: return 0;
    }
  }
}
```

## 5. 性能考虑

### 5.1 概念性性能指标

| 指标 | 目标值 | 说明 |
|------|--------|------|
| GPU 负载降低 | 30-50% | 启用 LOD 后 |
| FPS 提升 | > 1.5x | 大场景下 |
| LOD 更新开销 | < 1ms | 每帧计算 LOD 级别 |
| 内存开销 | < 20MB | LOD 资源缓存 |

### 5.2 优化策略

1. **LOD 级别复用**:
   - 共享相同级别的渲染资源
   - 减少内存占用

2. **延迟更新**:
   - 只在对象移动时更新 LOD
   - 静态对象缓存计算结果

3. **批量更新**:
   - 批量处理 LOD 更新
   - 减少函数调用开销

## 6. 关键文件清单

```
lib/flame/rendering/lod/
├── lod_level.dart                 # LOD 级别定义
├── lod_object.dart                # LOD 对象
├── lod_manager.dart               # LOD 管理器
├── strategies/
│   ├── lod_strategy.dart          # LOD 策略基类
│   ├── distance_lod.dart          # 距离策略
│   ├── screen_size_lod.dart       # 屏幕大小策略
│   └── zoom_lod.dart              # 缩放策略
└── renderers/
    ├── lod_renderer.dart          # LOD 渲染器基类
    ├── node_lod_renderer.dart     # 节点 LOD 渲染器
    └── connection_lod_renderer.dart # 连接线 LOD 渲染器
```

---

**文档所有者**: Node Graph Notebook 架构组
**最后更新**: 2025-01-14
