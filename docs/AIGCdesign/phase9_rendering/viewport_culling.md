# 视口裁剪设计文档

## 1. 概述

### 1.1 职责
视口裁剪系统负责优化图形渲染性能，通过只渲染视口内可见的节点和连接，实现：
- 减少渲染对象数量
- 提高 FPS（帧率）
- 降低 CPU 和 GPU 负载
- 支持大图渲染（10000+ 节点）

### 1.2 目标
- **性能**: 大图场景下 FPS > 60
- **精度**: 准确识别可见对象
- **响应性**: 视口变化快速响应（< 16ms）
- **可配置**: 支持不同裁剪策略

### 1.3 关键挑战
- **边界计算**: 快速判断对象是否在视口内
- **部分可见**: 处理部分可见的对象
- **动态更新**: 视口变化时的快速更新
- **层次结构**: 处理嵌套对象的裁剪
- **连接线**: 复杂连接线的裁剪

## 2. 架构设计

### 2.1 组件结构

```
ViewportCullingSystem
    │
    ├── Viewport (视口定义)
    │   ├── position (位置)
    │   ├── size (大小)
    │   └── zoom (缩放级别)
    │
    ├── Cullable (可裁剪对象接口)
    │   ├── boundingBox (边界框)
    │   ├── isVisible() (可见性判断)
    │   └── onCullStateChanged() (裁剪状态变化回调)
    │
    ├── CullingStrategy (裁剪策略)
    │   ├── BoundingBoxCulling (边界框裁剪)
    │   ├── CircleCulling (圆形裁剪)
    │   └── PreciseCulling (精确裁剪)
    │
    ├── CullingManager (裁剪管理器)
    │   ├── updateViewport() (更新视口)
    │   ├── cullObjects() (执行裁剪)
    │   └── getVisibleObjects() (获取可见对象)
    │
    └── VisibilityCache (可见性缓存)
        ├── isVisible() (缓存查询)
        └── invalidate() (缓存失效)
```

### 2.2 接口定义

#### 视口定义

```dart
/// 视口
class Viewport {
  /// 视口中心位置（世界坐标）
  Vector2 center;

  /// 视口大小（像素）
  Vector2 size;

  /// 缩放级别
  double zoom;

  /// 视口边界（世界坐标）
  Rect get bounds {
    final halfSize = size / (2 * zoom);
    return Rect.fromCenter(
      center: Offset(center.x, center.y),
      width: halfSize.x * 2,
      height: halfSize.y * 2,
    );
  }

  /// 视口边界（带缓冲区）
  Rect get boundsWithBuffer {
    final buffer = size.x * 0.1 / zoom; // 10% 缓冲
    final bounds = this.bounds;
    return bounds.inflate(buffer);
  }

  Viewport({
    required this.center,
    required this.size,
    this.zoom = 1.0,
  });

  /// 将屏幕坐标转换为世界坐标
  Vector2 screenToWorld(Vector2 screenPos) {
    final halfSize = size / 2;
    final worldPos = (screenPos - halfSize) / zoom + center;
    return worldPos;
  }

  /// 将世界坐标转换为屏幕坐标
  Vector2 worldToScreen(Vector2 worldPos) {
    final halfSize = size / 2;
    final screenPos = (worldPos - center) * zoom + halfSize;
    return screenPos;
  }

  /// 检查点是否在视口内
  bool contains(Vector2 point) {
    return bounds.contains(Offset(point.x, point.y));
  }

  /// 检查矩形是否与视口相交
  bool intersects(Rect rect) {
    return bounds.overlap(rect) != null;
  }
}
```

#### 可裁剪对象接口

```dart
/// 可裁剪对象接口
abstract class Cullable {
  /// 获取边界框（世界坐标）
  Rect getBoundingBox();

  /// 是否可见
  bool get isVisible;

  /// 设置可见性
  set isVisible(bool value);

  /// 裁剪状态变化回调
  void onCullStateChanged(bool isVisible);

  /// 获取裁剪优先级（数值越大越优先）
  int get cullingPriority => 0;
}

/// 节点可裁剪组件
class CullableNodeComponent extends PositionComponent implements Cullable {
  /// 节点数据
  final Node node;

  /// 是否可见
  bool _isVisible = true;

  CullableNodeComponent({
    required this.node,
    required Vector2 position,
  }) : super(position: position);

  @override
  Rect getBoundingBox() {
    // 计算节点的边界框
    final size = node.size ?? Size(100, 100);
    return Rect.fromCenter(
      center: Offset(position.x, position.y),
      width: size.width,
      height: size.height,
    );
  }

  @override
  bool get isVisible => _isVisible;

  @override
  set isVisible(bool value) {
    if (_isVisible != value) {
      _isVisible = value;
      onCullStateChanged(value);
    }
  }

  @override
  void onCullStateChanged(bool isVisible) {
    if (isVisible) {
      // 对象变为可见
      opacity = 1.0;
    } else {
      // 对象变为不可见
      opacity = 0.0;
    }
  }

  @override
  void render(Canvas canvas) {
    // 只在可见时渲染
    if (_isVisible) {
      super.render(canvas);
    }
  }

  @override
  int get cullingPriority => 100; // 节点优先级高
}
```

#### 裁剪策略

```dart
/// 裁剪策略接口
abstract class CullingStrategy {
  /// 判断对象是否可见
  bool isVisible(Cullable object, Viewport viewport);

  /// 批量判断对象可见性
  List<bool> batchIsVisible(List<Cullable> objects, Viewport viewport);
}

/// 边界框裁剪策略
class BoundingBoxCulling implements CullingStrategy {
  final bool useBuffer;

  BoundingBoxCulling({this.useBuffer = true});

  @override
  bool isVisible(Cullable object, Viewport viewport) {
    final bounds = object.getBoundingBox();
    final viewportBounds = useBuffer
        ? viewport.boundsWithBuffer
        : viewport.bounds;

    return viewportBounds.overlap(bounds) != null;
  }

  @override
  List<bool> batchIsVisible(List<Cullable> objects, Viewport viewport) {
    final viewportBounds = useBuffer
        ? viewport.boundsWithBuffer
        : viewport.bounds;

    return objects.map((obj) {
      final bounds = obj.getBoundingBox();
      return viewportBounds.overlap(bounds) != null;
    }).toList();
  }
}

/// 圆形裁剪策略
class CircleCulling implements CullingStrategy {
  final double bufferRadius;

  CircleCulling({this.bufferRadius = 0.0});

  @override
  bool isVisible(Cullable object, Viewport viewport) {
    final bounds = object.getBoundingBox();
    final center = viewport.center;

    // 计算对象中心到视口中心的距离
    final objCenter = Vector2(
      bounds.left + bounds.width / 2,
      bounds.top + bounds.height / 2,
    );

    final distance = (objCenter - center).length;
    final radius = (viewport.size.x / 2 / viewport.zoom) + bufferRadius;

    return distance < radius;
  }

  @override
  List<bool> batchIsVisible(List<Cullable> objects, Viewport viewport) {
    return objects.map((obj) => isVisible(obj, viewport)).toList();
  }
}

/// 精确裁剪策略（考虑对象形状）
class PreciseCulling implements CullingStrategy {
  @override
  bool isVisible(Cullable object, Viewport viewport) {
    // 先进行快速边界框检测
    final bounds = object.getBoundingBox();
    if (!viewport.intersects(bounds)) {
      return false;
    }

    // 精确检测（子类实现）
    return preciseIsVisible(object, viewport);
  }

  @override
  List<bool> batchIsVisible(List<Cullable> objects, Viewport viewport) {
    return objects.map((obj) => isVisible(obj, viewport)).toList();
  }

  /// 精确可见性检测
  bool preciseIsVisible(Cullable object, Viewport viewport) {
    // 默认使用边界框
    return true;
  }
}
```

#### 裁剪管理器

```dart
/// 裁剪管理器
class CullingManager {
  /// 当前视口
  Viewport viewport;

  /// 裁剪策略
  CullingStrategy strategy;

  /// 可裁剪对象列表
  final List<Cullable> _objects = [];

  /// 可见性缓存
  final VisibilityCache _cache = VisibilityCache();

  /// 是否启用裁剪
  bool cullingEnabled = true;

  CullingManager({
    required this.viewport,
    CullingStrategy? strategy,
  }) : strategy = strategy ?? BoundingBoxCulling();

  /// 添加可裁剪对象
  void addObject(Cullable object) {
    _objects.add(object);
    // 按优先级排序
    _objects.sort((a, b) => b.cullingPriority.compareTo(a.cullingPriority));
  }

  /// 移除可裁剪对象
  void removeObject(Cullable object) {
    _objects.remove(object);
    _cache.invalidate(object);
  }

  /// 更新视口
  void updateViewport(Viewport newViewport) {
    viewport = newViewport;
    _cache.invalidateAll();
    performCulling();
  }

  /// 执行裁剪
  void performCulling() {
    if (!cullingEnabled) {
      // 禁用裁剪，所有对象可见
      for (final obj in _objects) {
        obj.isVisible = true;
      }
      return;
    }

    // 批量判断可见性
    final visibility = strategy.batchIsVisible(_objects, viewport);

    // 更新对象可见性
    for (int i = 0; i < _objects.length; i++) {
      final obj = _objects[i];
      final visible = visibility[i];

      // 检查缓存
      if (_cache.isCached(obj)) {
        final cachedVisible = _cache.isVisible(obj);
        if (cachedVisible == visible) {
          continue; // 状态未变化
        }
      }

      // 更新可见性
      obj.isVisible = visible;
      _cache.setIsVisible(obj, visible);
    }
  }

  /// 获取可见对象
  List<Cullable> getVisibleObjects() {
    return _objects.where((obj) => obj.isVisible).toList();
  }

  /// 获取不可见对象
  List<Cullable> getInvisibleObjects() {
    return _objects.where((obj) => !obj.isVisible).toList();
  }

  /// 设置裁剪策略
  void setStrategy(CullingStrategy newStrategy) {
    strategy = newStrategy;
    _cache.invalidateAll();
    performCulling();
  }

  /// 清空所有对象
  void clear() {
    _objects.clear();
    _cache.invalidateAll();
  }
}
```

#### 可见性缓存

```dart
/// 可见性缓存
class VisibilityCache {
  /// 对象到可见性的映射
  final Map<int, bool> _cache = {};

  /// 对象哈希到对象 ID 的映射
  final Map<int, int> _objectIdMap = {};

  /// 下一个对象 ID
  int _nextId = 0;

  /// 检查对象是否已缓存
  bool isCached(Cullable object) {
    final hash = object.hashCode;
    return _objectIdMap.containsKey(hash);
  }

  /// 获取对象可见性
  bool isVisible(Cullable object) {
    final id = _objectIdMap[object.hashCode]!;
    return _cache[id]!;
  }

  /// 设置对象可见性
  void setIsVisible(Cullable object, bool visible) {
    final hash = object.hashCode;
    final id = _objectIdMap.putIfAbsent(hash, () => _nextId++);
    _cache[id] = visible;
  }

  /// 使对象缓存失效
  void invalidate(Cullable object) {
    final id = _objectIdMap[object.hashCode];
    if (id != null) {
      _cache.remove(id);
      _objectIdMap.remove(object.hashCode);
    }
  }

  /// 使所有缓存失效
  void invalidateAll() {
    _cache.clear();
    _objectIdMap.clear();
    _nextId = 0;
  }
}
```

## 3. 核心算法

### 3.1 快速视口裁剪

**问题描述**:
快速判断大量对象是否在视口内可见。

**算法描述**:
使用边界框相交测试，先进行快速排除，再进行精确判断。

**伪代码**:
```
function isVisible(object, viewport):
    // 1. 获取对象边界框
    bounds = object.getBoundingBox()

    // 2. 检查边界框是否与视口相交
    if not viewport.intersects(bounds):
        return false

    // 3. 可选：进行更精确的检测
    if preciseCullingEnabled:
        return preciseCheck(object, viewport)

    return true
```

**复杂度分析**:
- 时间复杂度: O(n)，n 为对象数量
- 空间复杂度: O(1)

**实现**:

```dart
/// 快速裁剪器
class FastCuller {
  /// 执行快速裁剪
  List<Cullable> cull(List<Cullable> objects, Viewport viewport) {
    final visible = <Cullable>[];
    final viewportBounds = viewport.bounds;

    for (final obj in objects) {
      if (_isFastVisible(obj, viewportBounds)) {
        visible.add(obj);
      }
    }

    return visible;
  }

  /// 快速可见性检测
  bool _isFastVisible(Cullable obj, Rect viewportBounds) {
    final bounds = obj.getBoundingBox();

    // 快速排斥测试
    if (bounds.right < viewportBounds.left) return false;
    if (bounds.left > viewportBounds.right) return false;
    if (bounds.bottom < viewportBounds.top) return false;
    if (bounds.top > viewportBounds.bottom) return false;

    return true;
  }
}
```

### 3.2 分层裁剪

**问题描述**:
支持对象层次结构的裁剪。

**算法描述**:
递归检查父对象可见性，如果父对象不可见，则子对象也不可见。

**伪代码**:
```
function isHierarchyVisible(object, viewport):
    // 检查父对象
    if object.parent != null:
        if not isHierarchyVisible(object.parent, viewport):
            return false

    // 检查当前对象
    return isVisible(object, viewport)
```

**复杂度分析**:
- 时间复杂度: O(h * n)，h 为层次深度，n 为对象数量
- 空间复杂度: O(h)，递归调用栈

**实现**:

```dart
/// 分层可裁剪对象
abstract class HierarchicalCullable extends Cullable {
  /// 父对象
  HierarchicalCullable? parent;

  /// 子对象
  final List<HierarchicalCullable> children = [];

  @override
  bool get isVisible {
    // 如果父对象不可见，则也不可见
    if (parent != null && !parent!.isVisible) {
      return false;
    }
    return _isVisible;
  }

  @override
  set isVisible(bool value) {
    _isVisible = value;
    // 级联更新子对象
    for (final child in children) {
      child.isVisible = value;
    }
  }

  bool _isVisible = true;
}
```

## 4. 连接线裁剪

### 4.1 连接线裁剪策略

```dart
/// 连接线裁剪组件
class CullableConnectionComponent extends Component implements Cullable {
  /// 源节点
  final CullableNodeComponent source;

  /// 目标节点
  final CullableNodeComponent target;

  bool _isVisible = true;

  CullableConnectionComponent({
    required this.source,
    required this.target,
  });

  @override
  Rect getBoundingBox() {
    // 计算连接线的边界框
    final sourceBounds = source.getBoundingBox();
    final targetBounds = target.getBoundingBox();

    return Rect.fromLTRB(
      min(sourceBounds.left, targetBounds.left),
      min(sourceBounds.top, targetBounds.top),
      max(sourceBounds.right, targetBounds.right),
      max(sourceBounds.bottom, targetBounds.bottom),
    );
  }

  @override
  bool get isVisible => _isVisible;

  @override
  set isVisible(bool value) {
    if (_isVisible != value) {
      _isVisible = value;
      onCullStateChanged(value);
    }
  }

  @override
  void onCullStateChanged(bool isVisible) {
    // 连接线可见性取决于端点是否可见
    final isVisibleEffective = isVisible && source.isVisible && target.isVisible;
    this._isVisible = isVisibleEffective;
  }

  /// 更新可见性（由端点触发）
  void updateVisibility() {
    onCullStateChanged(true);
  }
}
```

## 5. 性能考虑

### 5.1 概念性性能指标

| 指标 | 目标值 | 说明 |
|------|--------|------|
| 裁剪延迟 | < 5ms | 10000 个对象的裁剪时间 |
| 内存开销 | < 10MB | 可见性缓存内存 |
| FPS 提升 | > 2x | 大图场景下的 FPS 提升 |

### 5.2 优化策略

1. **空间分区**:
   - 结合四叉树等空间分区结构
   - 先进行粗粒度裁剪

2. **增量更新**:
   - 只重新检测变化的对象
   - 缓存未变化的检测结果

3. **异步裁剪**:
   - 在后台线程执行裁剪计算
   - 主线程只应用结果

## 6. 关键文件清单

```
lib/flame/rendering/culling/
├── viewport.dart                  # 视口定义
├── cullable.dart                  # 可裁剪对象接口
├── strategies/
│   ├── culling_strategy.dart      # 裁剪策略基类
│   ├── bounding_box_culling.dart  # 边界框裁剪
│   ├── circle_culling.dart        # 圆形裁剪
│   └── precise_culling.dart       # 精确裁剪
├── culling_manager.dart           # 裁剪管理器
├── visibility_cache.dart          # 可见性缓存
└── connection_culling.dart        # 连接线裁剪
```

---

**文档所有者**: Node Graph Notebook 架构组
**最后更新**: 2025-01-14
