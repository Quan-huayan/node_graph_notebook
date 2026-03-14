# 并发控制设计文档

## 1. 概述

### 1.1 职责
并发控制是系统数据一致性的核心组件，负责：
- 协调多个操作的并发访问
- 保证数据一致性和完整性
- 避免竞态条件和死锁
- 优化并发性能

### 1.2 目标
- **一致性**: 保证 ACID 特性
- **性能**: 最小化锁开销
- **可扩展性**: 支持高并发场景
- **正确性**: 避免死锁和饥饿

### 1.3 关键挑战
- **读写冲突**: 读操作不阻塞写操作
- **写写冲突**: 写操作的串行化
- **死锁预防**: 避免循环等待
- **性能平衡**: 一致性与性能的权衡

## 2. 架构设计

### 2.1 并发模型

采用**简化版 MVCC（Multi-Version Concurrency Control）**模式：

```
┌─────────────────────────────────────────────────────────────┐
│                     并发控制层                               │
└─────────────────────────────────────────────────────────────┘

读操作 (Read)
    ↓
无锁访问 (Lock-Free)
    ↓
读取最新版本 (Latest Version)
    ↓
返回数据

写操作 (Write)
    ↓
写队列 (Write Queue)
    ↓
串行执行 (Serialized)
    ↓
创建新版本 (New Version)
    ↓
更新索引 (Update Index)
    ↓
返回结果
```

### 2.2 设计原则

1. **读操作无锁**: 读操作不阻塞任何操作
2. **写操作串行化**: 写操作按顺序执行
3. **版本不可变**: 数据版本一旦创建不可修改
4. **最终一致性**: 允许短暂的不一致窗口

## 3. 核心数据结构

### 3.1 WriteQueue（写队列）

**描述**:
串行化所有写操作的队列。

**数据结构**:

```dart
/// 写操作队列
class WriteQueue {
  final Queue<_WriteOperation> _queue = Queue();
  bool _isProcessing = false;
  final _lock = Lock();

  /// 添加写操作到队列
  Future<T> enqueue<T>(Future<T> Function() operation) async {
    final completer = Completer<T>();

    final op = _WriteOperation<T>(
      fn: operation,
      completer: completer,
    );

    _queue.add(op);
    _processQueue();

    return completer.future;
  }

  /// 处理队列
  void _processQueue() async {
    if (_isProcessing || _queue.isEmpty) return;

    await _lock.synchronized(() async {
      _isProcessing = true;

      while (_queue.isNotEmpty) {
        final op = _queue.removeFirst();

        try {
          final result = await op.fn();
          op.completer.complete(result);
        } catch (e) {
          op.completer.completeError(e);
        }
      }

      _isProcessing = false;
    });
  }
}

class _WriteOperation<T> {
  final Future<T> Function() fn;
  final Completer<T> completer;

  _WriteOperation({
    required this.fn,
    required this.completer,
  });
}

/// 简单的锁实现
class Lock {
  int _lockCount = 0;
  final Completer<void>? _completer;

  Future<T> synchronized<T>(Future<T> Function() fn) async {
    while (_lockCount > 0) {
      await Future.delayed(Duration(microseconds: 100));
    }

    _lockCount++;

    try {
      return await fn();
    } finally {
      _lockCount--;
    }
  }
}
```

### 3.2 VersionedData（版本化数据）

**描述**:
支持多版本并发访问的数据容器。

**数据结构**:

```dart
/// 版本化数据
class VersionedData<T> {
  /// 当前版本
  volatile VersionedValue<T> current;

  /// 版本历史（用于垃圾回收）
  final List<VersionedValue<T>> _history = [];

  VersionedData(T initialValue) {
    current = VersionedValue<T>(
      version: 1,
      data: initialValue,
      createdAt: DateTime.now(),
    );
  }

  /// 读取当前版本（无锁）
  VersionedValue<T> read() {
    return current;
  }

  /// 更新数据（需要通过 WriteQueue）
  VersionedValue<T> write(T newData) {
    final newVersion = VersionedValue<T>(
      version: current.version + 1,
      data: newData,
      createdAt: DateTime.now(),
    );

    // 保留旧版本
    _history.add(current);

    // 更新当前版本
    current = newVersion;

    return newVersion;
  }

  /// 清理旧版本
  void cleanup(int keepVersions) {
    while (_history.length > keepVersions) {
      _history.removeAt(0);
    }
  }
}

/// 版本化值
class VersionedValue<T> {
  final int version;
  final T data;
  final DateTime createdAt;

  VersionedValue({
    required this.version,
    required this.data,
    required this.createdAt,
  });
}
```

### 3.3 ConcurrentMap（并发映射）

**描述**:
线程安全的键值存储。

**数据结构**:

```dart
/// 并发映射
class ConcurrentMap<K, V> {
  final Map<K, VersionedData<V>> _map = {};
  final ReadWriteLock _lock = ReadWriteLock();

  /// 读取值（无锁）
  V? get(K key) {
    final versionedData = _map[key];
    return versionedData?.read().data;
  }

  /// 写入值（需要写锁）
  Future<void> put(K key, V value) async {
    await _lock.acquireWrite();

    try {
      var versionedData = _map[key];

      if (versionedData == null) {
        versionedData = VersionedData<V>(value);
        _map[key] = versionedData;
      } else {
        versionedData.write(value);
      }
    } finally {
      _lock.releaseWrite();
    }
  }

  /// 删除值（需要写锁）
  Future<void> remove(K key) async {
    await _lock.acquireWrite();

    try {
      _map.remove(key);
    } finally {
      _lock.releaseWrite();
    }
  }

  /// 获取所有键（无锁）
  Set<K> get keys => _map.keys.toSet();

  /// 检查键是否存在（无锁）
  bool containsKey(K key) => _map.containsKey(key);
}
```

### 3.4 ReadWriteLock（读写锁）

**描述**:
允许多个读操作或一个写操作的锁。

**数据结构**:

```dart
/// 读写锁
class ReadWriteLock {
  int _readers = 0;
  bool _writer = false;
  final Queue<Completer<void>> _writeQueue = Queue();

  /// 获取读锁
  Future<void> acquireRead() async {
    while (_writer || _writeQueue.isNotEmpty) {
      await Future.delayed(Duration(microseconds: 100));
    }
    _readers++;
  }

  /// 释放读锁
  void releaseRead() {
    _readers--;
  }

  /// 获取写锁
  Future<void> acquireWrite() async {
    final completer = Completer<void>();
    _writeQueue.add(completer);

    while (_readers > 0 || _writer) {
      await Future.delayed(Duration(microseconds: 100));
    }

    _writeQueue.remove(completer);
    _writer = true;
  }

  /// 释放写锁
  void releaseWrite() {
    _writer = false;
  }
}
```

## 4. 并发控制算法

### 4.1 写操作串行化

**问题描述**:
如何保证写操作的原子性和顺序性。

**算法描述**:
使用单一队列串行化所有写操作。

**伪代码**:
```
writeQueue = Queue()

function enqueueWrite(operation):
    completer = Completer()
    writeQueue.add((operation, completer))
    processQueue()
    return completer.future

function processQueue():
    if isProcessing or writeQueue.isEmpty:
        return

    isProcessing = true

    while writeQueue.isNotEmpty:
        (operation, completer) = writeQueue.remove()
        try:
            result = await operation()
            completer.complete(result)
        catch error:
            completer.completeError(error)

    isProcessing = false
```

**复杂度分析**:
- 时间复杂度: O(n)，n 为队列中操作数
- 空间复杂度: O(n)

### 4.2 读操作无锁

**问题描述**:
如何实现读操作不阻塞任何操作。

**算法描述**:
读操作直接读取不可变版本的最新数据。

**伪代码**:
```
function read(key):
    versionedData = map.get(key)
    if versionedData == null:
        return null

    return versionedData.current.data
```

**复杂度分析**:
- 时间复杂度: O(1)
- 空间复杂度: O(1)

### 4.3 死锁预防

**问题描述**:
如何避免死锁。

**策略**:
1. **写操作串行化**: 所有写操作按顺序执行
2. **无锁读**: 读操作不需要锁
3. **超时机制**: 操作超时自动放弃

**实现**:

```dart
/// 带超时的写操作
Future<T> writeWithTimeout<T>(
  Future<T> Function() operation, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  return operation().timeout(
    timeout,
    onTimeout: () => throw TimeoutException('写操作超时'),
  );
}
```

## 5. 并发安全保证

### 5.1 原子性

**保证**:
- 写操作通过 WriteQueue 串行化
- 要么全部成功，要么全部失败
- 使用事务确保跨操作的原子性

**实现**:

```dart
class Transaction {
  final List<Future<void> Function()> _operations = [];
  final WriteQueue _writeQueue;

  Transaction(this._writeQueue);

  /// 添加操作
  void add(Future<void> Function() operation) {
    _operations.add(operation);
  }

  /// 提交事务
  Future<void> commit() async {
    await _writeQueue.enqueue(() async {
      // 执行所有操作
      for (final operation in _operations) {
        await operation();
      }
    });
  }
}
```

### 5.2 一致性

**保证**:
- 版本化数据保证一致性
- 索引更新与数据更新同步
- 引用完整性约束

**实现**:

```dart
class ConsistencyChecker {
  /// 检查引用完整性
  static Future<bool> checkReferenceIntegrity(
    IReferenceStorage refStorage,
    IStorageEngine storage,
  ) async {
    final allRefs = await _getAllReferences(refStorage);

    for (final ref in allRefs) {
      final sourceExists = await storage.exists(ref.sourceId);
      final targetExists = await storage.exists(ref.targetId);

      if (!sourceExists || !targetExists) {
        return false; // 不一致
      }
    }

    return true;
  }

  static Future<List<Reference>> _getAllReferences(
    IReferenceStorage refStorage,
  ) async {
    // TODO: 实现获取所有引用
    return [];
  }
}
```

### 5.3 隔离性

**保证**:
- 读操作看到一致的数据快照
- 写操作相互隔离
- 使用版本号实现隔离

**实现**:

```dart
class Snapshot {
  final int version;
  final DateTime createdAt;
  final Map<String, dynamic> _data;

  Snapshot(this.version, this._data) : createdAt = DateTime.now();

  /// 从快照读取
  dynamic get(String key) {
    return _data[key];
  }
}

class SnapshotManager {
  int _currentVersion = 0;
  final List<Snapshot> _snapshots = [];

  /// 创建快照
  Snapshot createSnapshot(Map<String, dynamic> data) {
    _currentVersion++;
    final snapshot = Snapshot(_currentVersion, Map.from(data));
    _snapshots.add(snapshot);
    return snapshot;
  }

  /// 清理旧快照
  void cleanup(int keepSnapshots) {
    while (_snapshots.length > keepSnapshots) {
      _snapshots.removeAt(0);
    }
  }
}
```

### 5.4 持久性

**保证**:
- 写操作先写 WAL
- WAL 刷新到磁盘
- 然后更新内存数据

**实现**:

```dart
class PersistentStorage {
  final WalFile _wal;
  final IStorageEngine _storage;

  PersistentStorage(this._wal, this._storage);

  /// 持久化写入
  Future<void> put(String key, dynamic value) async {
    // 1. 写入 WAL
    await _wal.append(WalEntry.put(key, value));
    await _wal.flush();

    // 2. 更新存储
    await _storage.put(key, value);
  }
}
```

## 6. 性能优化

### 6.1 批量操作

**描述**:
将多个写操作合并为一次。

**实现**:

```dart
class BatchWriter {
  final WriteQueue _writeQueue;
  final List<_BatchOperation> _batch = [];
  Timer? _timer;
  final Duration _flushInterval;

  BatchWriter(
    this._writeQueue, {
    Duration flushInterval = const Duration(milliseconds: 100),
  }) : _flushInterval = flushInterval {
    _startTimer();
  }

  /// 添加操作到批次
  Future<void> add(Future<void> Function() operation) async {
    final completer = Completer<void>();
    _batch.add(_BatchOperation(operation, completer));

    if (_batch.length >= 100) {
      await _flush();
    }

    return completer.future;
  }

  /// 刷新批次
  Future<void> _flush() async {
    if (_batch.isEmpty) return;

    final operations = _batch.toList();
    _batch.clear();

    await _writeQueue.enqueue(() async {
      for (final op in operations) {
        try {
          await op.operation();
          op.completer.complete();
        } catch (e) {
          op.completer.completeError(e);
        }
      }
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(_flushInterval, (_) => _flush());
  }

  void dispose() {
    _timer?.cancel();
    _flush();
  }
}

class _BatchOperation {
  final Future<void> Function() operation;
  final Completer<void> completer;

  _BatchOperation(this.operation, this.completer);
}
```

### 6.2 并行读操作

**描述**:
多个读操作可以并行执行。

**实现**:

```dart
class ParallelReader {
  /// 并行读取多个键
  static Future<List<dynamic>> readAll(
    ConcurrentMap<String, dynamic> map,
    List<String> keys,
  ) async {
    final futures = keys.map((key) => Future.value(map.get(key)));
    return Future.wait(futures);
  }
}
```

## 7. 错误处理

### 7.1 并发冲突检测

**策略**:
- 使用版本号检测冲突
- 乐观并发控制
- 冲突时重试或失败

**实现**:

```dart
class ConcurrentConflictException implements Exception {
  final String message;
  final String key;
  final int expectedVersion;
  final int actualVersion;

  ConcurrentConflictException({
    required this.message,
    required this.key,
    required this.expectedVersion,
    required this.actualVersion,
  });

  @override
  String toString() =>
      'ConcurrentConflictException: $message (key: $key, '
      'expected: v$expectedVersion, actual: v$actualVersion)';
}

/// 乐观并发控制
class OptimisticConcurrencyControl {
  final ConcurrentMap<String, VersionedData> _map;

  OptimisticConcurrencyControl(this._map);

  /// 更新数据（带版本检查）
  Future<void> update(
    String key,
    int expectedVersion,
    dynamic newData,
  ) async {
    final versionedData = _map.get(key);

    if (versionedData == null) {
      throw NotFoundException('键不存在: $key');
    }

    final currentVersion = versionedData.read().version;

    if (currentVersion != expectedVersion) {
      throw ConcurrentConflictException(
        message: '版本冲突',
        key: key,
        expectedVersion: expectedVersion,
        actualVersion: currentVersion,
      );
    }

    // 版本匹配，执行更新
    await _map.put(key, newData);
  }
}
```

### 7.2 重试机制

**策略**:
- 冲突时自动重试
- 指数退避
- 最大重试次数

**实现**:

```dart
class RetryPolicy {
  final int maxAttempts;
  final Duration initialDelay;
  final double backoffMultiplier;

  RetryPolicy({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(milliseconds: 100),
    this.backoffMultiplier = 2.0,
  });

  /// 执行带重试的操作
  Future<T> execute<T>(Future<T> Function() operation) async {
    int attempts = 0;
    var delay = initialDelay;

    while (attempts < maxAttempts) {
      try {
        return await operation();
      } on ConcurrentConflictException catch (e) {
        attempts++;

        if (attempts >= maxAttempts) {
          rethrow;
        }

        await Future.delayed(delay);
        delay = Duration(
          microseconds: (delay.inMicroseconds * backoffMultiplier).round(),
        );
      }
    }

    throw RetryExhaustedException('重试次数耗尽');
  }
}

class RetryExhaustedException implements Exception {
  final String message;
  RetryExhaustedException(this.message);

  @override
  String toString() => 'RetryExhaustedException: $message';
}
```

## 8. 性能考虑

### 8.1 概念性性能指标

| 操作 | 目标延迟 | 说明 |
|------|----------|------|
| 读操作 | < 1ms | 无锁访问 |
| 写操作 | < 10ms | 串行化执行 |
| 批量写入 | < 100ms | 100 个操作 |
| 并发读 | 无限制 | 无阻塞 |

### 8.2 优化方向

1. **减少锁竞争**:
   - 读写分离
   - 无锁数据结构
   - 乐观并发控制

2. **批量处理**:
   - 批量写入
   - 批量提交
   - 批量刷新

3. **缓存优化**:
   - 读缓存
   - 写缓存
   - 版本缓存

### 8.3 瓶颈分析

**潜在瓶颈**:
- 写操作队列积压
- 锁竞争
- 版本清理不及时

**解决方案**:
- 扩大队列容量
- 细粒度锁
- 后台清理线程

## 9. 关键文件清单

```
lib/core/concurrency/
├── concurrency_control.dart     # 并发控制接口
├── write_queue.dart             # 写队列
├── versioned_data.dart          # 版本化数据
├── concurrent_map.dart          # 并发映射
├── read_write_lock.dart         # 读写锁
├── transaction.dart             # 事务
├── snapshot.dart                # 快照
├── consistency.dart             # 一致性检查
├── batch_writer.dart            # 批量写入
├── optimistic_cc.dart           # 乐观并发控制
└── retry_policy.dart            # 重试策略
```

## 10. 参考资料

### 并发控制
- MVCC in PostgreSQL
- Concurrency in Java
- Async/Await in Dart

### 锁机制
- Read-Write Locks
- Optimistic Concurrency Control
- Lock-Free Data Structures

### 一致性模型
- ACID Transactions
- CAP Theorem
- Eventual Consistency

---

**文档所有者**: Node Graph Notebook 架构组
**最后更新**: 2025-01-14
