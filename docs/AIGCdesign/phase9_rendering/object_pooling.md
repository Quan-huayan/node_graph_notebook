# 对象池设计文档

## 1. 概述

### 1.1 职责
对象池系统负责管理和复用临时对象，减少 GC（垃圾回收）压力，实现：
- 对象复用
- 内存分配优化
- 减少 GC 停顿
- 提高帧率稳定性

### 1.2 目标
- **性能**: 减少 80% 的临时对象分配
- **内存**: 控制对象池内存占用
- **稳定**: 降低 GC 停顿时间 50%
- **通用**: 支持多种对象类型

### 1.3 关键挑战
- **池大小**: 确定合适的池大小
- **对象重置**: 正确重置对象状态
- **线程安全**: 多线程环境下的对象访问
- **内存泄漏**: 避免对象池内存泄漏
- **类型安全**: 保持强类型检查

## 2. 架构设计

### 2.1 组件结构

```
ObjectPoolingSystem
    │
    ├── ObjectPool (对象池接口)
    │   ├── acquire() (获取对象)
    │   ├── release() (释放对象)
    │   ├── resize() (调整池大小)
    │   └── clear() (清空池)
    │
    ├── GenericObjectPool (通用对象池)
    │   ├── factory (对象工厂)
    │   ├── reset (重置函数)
    │   ├── available (可用对象)
    │   └── inUse (使用中对象)
    │
    ├── FixedSizePool (固定大小池)
    │   ├── maxSize (最大大小)
    │   └── preAllocate() (预分配)
    │
    ├── GrowingPool (可增长池)
    │   ├── initialSize (初始大小)
    │   ├── maxSize (最大大小)
    │   └── grow() (增长)
    │
    └── SpecializedPools (专用池)
        ├── Vector2Pool
        ├── Matrix4Pool
        ├── PaintPool
        └── PathPool
```

### 2.2 接口定义

#### 对象池接口

```dart
/// 对象池接口
abstract class ObjectPool<T> {
  /// 获取对象
  T acquire();

  /// 释放对象
  void release(T object);

  /// 调整池大小
  void resize(int newSize);

  /// 清空池
  void clear();

  /// 当前池大小
  int get size;

  /// 可用对象数量
  int get availableCount;

  /// 使用中对象数量
  int get inUseCount;
}

/// 对象工厂
typedef ObjectFactory<T> = T Function();

/// 对象重置函数
typedef ObjectReset<T> = void Function(T object);
```

#### 通用对象池

```dart
/// 通用对象池
class GenericObjectPool<T> implements ObjectPool<T> {
  /// 对象工厂
  final ObjectFactory<T> factory;

  /// 对象重置函数
  final ObjectReset<T>? reset;

  /// 可用对象队列
  final Queue<T> _available = Queue<T>();

  /// 使用中对象集合
  final Set<T> _inUse = {};

  /// 最大池大小
  final int maxSize;

  /// 当前池大小
  int _size = 0;

  GenericObjectPool({
    required this.factory,
    this.reset,
    this.maxSize = 100,
    int initialSize = 0,
  }) {
    if (initialSize > 0) {
      _preAllocate(initialSize);
    }
  }

  /// 预分配对象
  void _preAllocate(int count) {
    for (int i = 0; i < count; i++) {
      if (_size >= maxSize) break;
      final object = factory();
      _available.add(object);
      _size++;
    }
  }

  @override
  T acquire() {
    // 从可用队列中获取对象
    if (_available.isNotEmpty) {
      final object = _available.removeFirst();
      _inUse.add(object);
      return object;
    }

    // 如果没有可用对象，创建新对象
    if (_size < maxSize) {
      final object = factory();
      _inUse.add(object);
      _size++;
      return object;
    }

    // 池已满，等待或抛出异常
    throw StateError('对象池已满');
  }

  @override
  void release(T object) {
    // 检查对象是否在使用中
    if (!_inUse.remove(object)) {
      throw ArgumentError('对象不在使用中');
    }

    // 重置对象状态
    if (reset != null) {
      reset!(object);
    }

    // 将对象返回到可用队列
    _available.add(object);
  }

  @override
  void resize(int newSize) {
    if (newSize < 0) {
      throw ArgumentError('池大小不能为负数');
    }

    if (newSize < _size) {
      // 缩小池
      final excessCount = _size - newSize;
      for (int i = 0; i < excessCount; i++) {
        if (_available.isNotEmpty) {
          _available.removeFirst();
          _size--;
        }
      }
    } else if (newSize > maxSize) {
      // 扩大池
      maxSize = newSize;
    }
  }

  @override
  void clear() {
    _available.clear();
    _inUse.clear();
    _size = 0;
  }

  @override
  int get size => _size;

  @override
  int get availableCount => _available.length;

  @override
  int get inUseCount => _inUse.length;
}
```

#### 固定大小对象池

```dart
/// 固定大小对象池
class FixedSizePool<T> extends GenericObjectPool<T> {
  FixedSizePool({
    required ObjectFactory<T> factory,
    ObjectReset<T>? reset,
    required int size,
  }) : super(
          factory: factory,
          reset: reset,
          maxSize: size,
          initialSize: size,
        );

  @override
  void resize(int newSize) {
    throw UnsupportedError('固定大小池不支持调整大小');
  }
}
```

#### 可增长对象池

```dart
/// 可增长对象池
class GrowingPool<T> extends GenericObjectPool<T> {
  /// 初始大小
  final int initialSize;

  /// 增长因子
  final double growthFactor;

  GrowingPool({
    required ObjectFactory<T> factory,
    ObjectReset<T>? reset,
    this.initialSize = 10,
    this.maxSize = 1000,
    this.growthFactor = 2.0,
  }) : super(
          factory: factory,
          reset: reset,
          maxSize: maxSize,
          initialSize: initialSize,
        );

  @override
  T acquire() {
    // 如果池快满了，自动增长
    if (availableCount == 0 && size < maxSize) {
      final growthSize = min(
        (size * growthFactor).floor(),
        maxSize - size,
      );
      if (growthSize > 0) {
        _preAllocate(growthSize);
      }
    }

    return super.acquire();
  }
}
```

### 2.3 专用对象池

#### Vector2 对象池

```dart
/// Vector2 对象池
class Vector2Pool {
  late final GenericObjectPool<Vector2> _pool;

  Vector2Pool({
    int initialSize = 50,
    int maxSize = 500,
  }) {
    _pool = GenericObjectPool<Vector2>(
      factory: () => Vector2.zero(),
      reset: (v) => v.setValues(0, 0),
      maxSize: maxSize,
      initialSize: initialSize,
    );
  }

  /// 获取 Vector2 对象
  Vector2 acquire() => _pool.acquire();

  /// 释放 Vector2 对象
  void release(Vector2 v) => _pool.release(v);

  /// 创建 Vector2（便捷方法）
  Vector2 create(double x, double y) {
    final v = acquire();
    v.setValues(x, y);
    return v;
  }
}
```

#### Paint 对象池

```dart
/// Paint 对象池
class PaintPool {
  late final GenericObjectPool<Paint> _pool;

  PaintPool({
    int initialSize = 20,
    int maxSize = 100,
  }) {
    _pool = GenericObjectPool<Paint>(
      factory: () => Paint(),
      reset: (p) {
        p.color = const Color(0xFF000000);
        p.style = PaintingStyle.fill;
        p.strokeWidth = 1.0;
        p.isAntiAlias = true;
      },
      maxSize: maxSize,
      initialSize: initialSize,
    );
  }

  /// 获取 Paint 对象
  Paint acquire() => _pool.acquire();

  /// 释放 Paint 对象
  void release(Paint p) => _pool.release(p);

  /// 创建 Paint（便捷方法）
  Paint create({
    Color? color,
    PaintingStyle? style,
    double? strokeWidth,
  }) {
    final p = acquire();
    if (color != null) p.color = color;
    if (style != null) p.style = style;
    if (strokeWidth != null) p.strokeWidth = strokeWidth;
    return p;
  }
}
```

#### Path 对象池

```dart
/// Path 对象池
class PathPool {
  late final GenericObjectPool<Path> _pool;

  PathPool({
    int initialSize = 20,
    int maxSize = 100,
  }) {
    _pool = GenericObjectPool<Path>(
      factory: () => Path(),
      reset: (p) => p.reset(),
      maxSize: maxSize,
      initialSize: initialSize,
    );
  }

  /// 获取 Path 对象
  Path acquire() => _pool.acquire();

  /// 释放 Path 对象
  void release(Path p) => _pool.release(p);
}
```

## 3. 核心算法

### 3.1 对象池管理

**问题描述**:
高效管理对象池的分配和回收。

**算法描述**:
使用队列存储可用对象，集合跟踪使用中对象。

**伪代码**:
```
function acquire(pool):
    if pool.available.isNotEmpty:
        object = pool.available.dequeue()
        pool.inUse.add(object)
        return object
    else if pool.size < pool.maxSize:
        object = pool.factory.create()
        pool.inUse.add(object)
        pool.size++
        return object
    else:
        throw Exception("Pool exhausted")

function release(pool, object):
    if object not in pool.inUse:
        throw Exception("Object not in use")

    pool.inUse.remove(object)
    if pool.reset != null:
        pool.reset(object)
    pool.available.enqueue(object)
```

**复杂度分析**:
- 时间复杂度: O(1)
- 空间复杂度: O(n)，n 为池大小

### 3.2 自适应池大小

**问题描述**:
根据使用情况动态调整池大小。

**算法描述**:
监控对象使用峰值，自动调整池大小。

**伪代码**:
```
function adaptiveResize(pool):
    peakUsage = max(pool.inUseCount, peakUsage)
    currentUsage = pool.inUseCount

    if currentUsage > pool.size * 0.8:
        // 使用率超过 80%，扩大池
        newSize = min(pool.size * 1.5, pool.maxSize)
        pool.resize(newSize)
    elif currentUsage < pool.size * 0.2:
        // 使用率低于 20%，缩小池
        newSize = max(pool.size * 0.8, pool.minSize)
        pool.resize(newSize)
```

**实现**:

```dart
/// 自适应对象池
class AdaptivePool<T> extends GenericObjectPool<T> {
  /// 最小池大小
  final int minSize;

  /// 峰值使用量
  int _peakUsage = 0;

  /// 调整间隔（帧数）
  final int adjustInterval;

  /// 帧计数器
  int _frameCount = 0;

  AdaptivePool({
    required ObjectFactory<T> factory,
    ObjectReset<T>? reset,
    this.minSize = 10,
    int initialSize = 50,
    int maxSize = 500,
    this.adjustInterval = 60, // 每秒调整一次（60 FPS）
  }) : super(
          factory: factory,
          reset: reset,
          maxSize: maxSize,
          initialSize: initialSize,
        );

  @override
  T acquire() {
    final object = super.acquire();

    // 更新峰值使用量
    if (inUseCount > _peakUsage) {
      _peakUsage = inUseCount;
    }

    // 定期调整池大小
    _frameCount++;
    if (_frameCount >= adjustInterval) {
      _adaptiveResize();
      _frameCount = 0;
    }

    return object;
  }

  /// 自适应调整池大小
  void _adaptiveResize() {
    final currentUsage = inUseCount;
    final currentSize = size;

    // 使用率超过 80%，扩大池
    if (currentUsage > currentSize * 0.8) {
      final newSize = min(
        (currentSize * 1.5).floor(),
        maxSize,
      );
      if (newSize > currentSize) {
        resize(newSize);
      }
    }
    // 使用率低于 20%，缩小池
    else if (currentUsage < currentSize * 0.2) {
      final newSize = max(
        (currentSize * 0.8).floor(),
        minSize,
      );
      if (newSize < currentSize) {
        resize(newSize);
      }
    }

    // 重置峰值
    _peakUsage = currentUsage;
  }
}
```

## 4. 对象池管理器

### 4.1 全局对象池管理器

```dart
/// 对象池管理器
class ObjectPoolManager {
  /// 单例实例
  static final ObjectPoolManager _instance = ObjectPoolManager._internal();
  factory ObjectPoolManager() => _instance;
  ObjectPoolManager._internal();

  /// 对象池映射
  final Map<Type, dynamic> _pools = {};

  /// 获取或创建对象池
  ObjectPool<T> getPool<T>(
    ObjectFactory<T> factory, {
    ObjectReset<T>? reset,
    int initialSize = 10,
    int maxSize = 100,
  }) {
    final type = T;

    if (!_pools.containsKey(type)) {
      _pools[type] = GenericObjectPool<T>(
        factory: factory,
        reset: reset,
        maxSize: maxSize,
        initialSize: initialSize,
      );
    }

    return _pools[type] as ObjectPool<T>;
  }

  /// 获取 Vector2 池
  Vector2Pool getVector2Pool({int initialSize = 50, int maxSize = 500}) {
    final type = Vector2;
    if (!_pools.containsKey(type)) {
      _pools[type] = Vector2Pool(
        initialSize: initialSize,
        maxSize: maxSize,
      );
    }
    return _pools[type] as Vector2Pool;
  }

  /// 获取 Paint 池
  PaintPool getPaintPool({int initialSize = 20, int maxSize = 100}) {
    final type = Paint;
    if (!_pools.containsKey(type)) {
      _pools[type] = PaintPool(
        initialSize: initialSize,
        maxSize: maxSize,
      );
    }
    return _pools[type] as PaintPool;
  }

  /// 获取 Path 池
  PathPool getPathPool({int initialSize = 20, int maxSize = 100}) {
    final type = Path;
    if (!_pools.containsKey(type)) {
      _pools[type] = PathPool(
        initialSize: initialSize,
        maxSize: maxSize,
      );
    }
    return _pools[type] as PathPool;
  }

  /// 清空所有池
  void clearAll() {
    for (final pool in _pools.values) {
      if (pool is ObjectPool) {
        pool.clear();
      }
    }
  }

  /// 获取池统计信息
  Map<String, dynamic> getStats() {
    final stats = <String, dynamic>{};

    for (final entry in _pools.entries) {
      final type = entry.key.toString();
      final pool = entry.value;

      if (pool is ObjectPool) {
        stats[type] = {
          'size': pool.size,
          'available': pool.availableCount,
          'inUse': pool.inUseCount,
        };
      }
    }

    return stats;
  }
}
```

## 5. 使用示例

### 5.1 在渲染中使用对象池

```dart
/// 使用对象池的渲染组件
class PooledRenderComponent extends Component {
  final ObjectPoolManager _poolManager = ObjectPoolManager();

  @override
  void render(Canvas canvas) {
    // 从对象池获取 Paint
    final paint = _poolManager.getPaintPool().create(
          color: Colors.blue,
          style: PaintingStyle.fill,
        );

    // 从对象池获取 Path
    final path = _poolManager.getPathPool().acquire();

    try {
      // 使用对象进行渲染
      path.addRect(Rect.fromCenter(
        center: Offset.zero,
        width: 100,
        height: 100,
      ));

      canvas.drawPath(path, paint);
    } finally {
      // 释放对象回池
      _poolManager.getPathPool().release(path);
      _poolManager.getPaintPool().release(paint);
    }
  }
}
```

### 5.2 批量操作中使用对象池

```dart
/// 批量节点渲染
class BatchNodeRenderer {
  final ObjectPoolManager _poolManager = ObjectPoolManager();

  void renderNodes(Canvas canvas, List<Node> nodes) {
    final paintPool = _poolManager.getPaintPool();
    final pathPool = _poolManager.getPathPool();

    // 预先获取所有需要的对象
    final paints = List.generate(
      nodes.length,
      (_) => paintPool.create(color: Colors.blue),
    );

    final paths = List.generate(
      nodes.length,
      (_) => pathPool.acquire(),
    );

    try {
      // 批量渲染
      for (int i = 0; i < nodes.length; i++) {
        final node = nodes[i];
        final paint = paints[i];
        final path = paths[i];

        path.reset();
        path.addRect(node.bounds);
        canvas.drawPath(path, paint);
      }
    } finally {
      // 批量释放对象
      for (final paint in paints) {
        paintPool.release(paint);
      }

      for (final path in paths) {
        pathPool.release(path);
      }
    }
  }
}
```

## 6. 性能考虑

### 6.1 概念性性能指标

| 指标 | 目标值 | 说明 |
|------|--------|------|
| 对象分配减少 | > 80% | 相比无池的情况 |
| GC 停顿减少 | > 50% | GC 停顿时间 |
| 内存开销 | < 5MB | 对象池内存 |
| 获取延迟 | < 1μs | 从池获取对象 |

### 6.2 优化策略

1. **预分配**:
   - 启动时预分配常用对象
   - 避免运行时分配

2. **批量操作**:
   - 批量获取和释放对象
   - 减少函数调用开销

3. **类型特化**:
   - 为常用类型创建专用池
   - 优化重置逻辑

## 7. 关键文件清单

```
lib/flame/rendering/pooling/
├── object_pool.dart                # 对象池接口
├── generic_pool.dart               # 通用对象池
├── fixed_size_pool.dart            # 固定大小池
├── growing_pool.dart               # 可增长池
├── adaptive_pool.dart              # 自适应池
├── pool_manager.dart               # 对象池管理器
└── specialized/
    ├── vector2_pool.dart           # Vector2 池
    ├── matrix4_pool.dart           # Matrix4 池
    ├── paint_pool.dart             # Paint 池
    └── path_pool.dart              # Path 池
```

---

**文档所有者**: Node Graph Notebook 架构组
**最后更新**: 2025-01-14
