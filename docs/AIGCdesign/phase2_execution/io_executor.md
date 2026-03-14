# IO 执行器设计文档

## 1. 概述

### 1.1 职责
IO 执行器专门负责处理 IO 密集型任务，包括：
- 文件读写操作
- 网络请求
- 数据库访问
- 序列化/反序列化

### 1.2 目标
- **高吞吐**: 最大化 IO 吞吐量
- **低延迟**: 最小化 IO 延迟
- **非阻塞**: 异步非阻塞操作
- **可靠性**: IO 错误处理和恢复

### 1.3 关键挑战
- **IO 等待**: 避免阻塞其他操作
- **资源限制**: 文件句柄、连接池限制
- **错误恢复**: IO 失败的处理
- **并发控制**: 多个 IO 操作的协调

## 2. 架构设计

### 2.1 组件结构

```
IOExecutor
    │
    ├── Task Queue (任务队列)
    │   ├── Pending Queue (等待队列)
    │   ├── Processing Queue (处理队列)
    │   └── Completed Queue (完成队列)
    │
    ├── Worker Pool (工作线程池)
    │   ├── IO Workers (IO 工作线程)
    │   └── Worker Management (工作线程管理)
    │
    ├── Resource Pool (资源池)
    │   ├── File Handle Pool (文件句柄池)
    │   ├── Connection Pool (连接池)
    │   └── Buffer Pool (缓冲池)
    │
    └── IO Operations (IO 操作)
        ├── File Operations (文件操作)
        ├── Network Operations (网络操作)
        └── Serialization Operations (序列化操作)
```

### 2.2 接口定义

#### IOExecutor 接口

```dart
/// IO 执行器
class IOExecutor extends Executor {
  final ThreadPool _workerPool;
  final ResourcePool _resourcePool;
  final Queue<IOTask> _taskQueue = Queue();
  final int _maxConcurrent;

  IOExecutor({
    required int maxConcurrent,
    required ThreadPool workerPool,
    required ResourcePool resourcePool,
  })  : _maxConcurrent = maxConcurrent,
        _workerPool = workerPool,
        _resourcePool = resourcePool {
    _start();
  }

  @override
  ExecutorType get type => ExecutorType.io;

  @override
  Future<TaskResult> execute(Task task) async {
    if (task.data is! IOTaskData) {
      return TaskResult.failure(
        taskId: task.id,
        error: '无效的任务数据类型',
        executionTime: Duration.zero,
      );
    }

    final ioTask = task.data as IOTaskData;

    // 添加到队列
    _taskQueue.add(IOTask(task: task, data: ioTask));

    // 等待执行完成
    final completer = Completer<TaskResult>();

    // TODO: 实现等待逻辑

    return completer.future;
  }

  @override
  double get load => _taskQueue.length / _maxConcurrent;

  @override
  int get queueLength => _taskQueue.length;

  @override
  bool get isAvailable => _taskQueue.length < _maxConcurrent;

  void _start() {
    // 启动工作循环
    for (int i = 0; i < _maxConcurrent; i++) {
      _workerPool.submit(_worker);
    }
  }

  Future<void> _worker() async {
    while (true) {
      if (_taskQueue.isEmpty) {
        await Future.delayed(Duration(milliseconds: 100));
        continue;
      }

      final ioTask = _taskQueue.removeFirst();

      try {
        final result = await _executeIOTask(ioTask);
        ioTask.task.callback?.call(result);
      } catch (e) {
        final result = TaskResult.failure(
          taskId: ioTask.task.id,
          error: e.toString(),
          executionTime: Duration.zero,
        );
        ioTask.task.callback?.call(result);
      }
    }
  }

  Future<TaskResult> _executeIOTask(IOTask ioTask) async {
    final stopwatch = Stopwatch()..start();

    try {
      final data = await _executeOperation(ioTask.data);

      stopwatch.stop();

      return TaskResult.success(
        taskId: ioTask.task.id,
        data: data,
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();

      return TaskResult.failure(
        taskId: ioTask.task.id,
        error: e.toString(),
        executionTime: stopwatch.elapsed,
      );
    }
  }

  Future<dynamic> _executeOperation(IOTaskData data) async {
    switch (data.operation) {
      case 'readFile':
        return await _readFile(data.parameters);
      case 'writeFile':
        return await _writeFile(data.parameters);
      case 'httpRequest':
        return await _httpRequest(data.parameters);
      case 'serialize':
        return await _serialize(data.parameters);
      case 'deserialize':
        return await _deserialize(data.parameters);
      default:
        throw UnimplementedError('未知操作: ${data.operation}');
    }
  }

  // IO 操作实现
  Future<String> _readFile(Map<String, dynamic> params) async {
    final path = params['path'] as String;
    final file = File(path);
    return await file.readAsString();
  }

  Future<void> _writeFile(Map<String, dynamic> params) async {
    final path = params['path'] as String;
    final content = params['content'] as String;
    final file = File(path);
    await file.writeAsString(content);
  }

  Future<String> _httpRequest(Map<String, dynamic> params) async {
    // TODO: 实现网络请求
    throw UnimplementedError();
  }

  Future<List<int>> _serialize(Map<String, dynamic> params) async {
    final data = params['data'];
    return utf8.encode(jsonEncode(data));
  }

  Future<dynamic> _deserialize(Map<String, dynamic> params) async {
    final bytes = params['bytes'] as List<int>;
    return jsonDecode(utf8.decode(bytes));
  }

  @override
  Future<void> pause() async {
    // TODO: 实现暂停
  }

  @override
  Future<void> resume() async {
    // TODO: 实现恢复
  }

  @override
  Future<void> close() async {
    await _workerPool.shutdown();
  }

  @override
  ExecutorStats get stats {
    // TODO: 实现统计
    return ExecutorStats(
      totalTasks: 0,
      succeededTasks: 0,
      failedTasks: 0,
      totalExecutionTime: Duration.zero,
      averageExecutionTime: 0,
      currentQueueLength: queueLength,
    );
  }
}

class IOTask {
  final Task task;
  final IOTaskData data;

  IOTask({required this.task, required this.data});
}
```

## 3. 核心算法

### 3.1 异步 IO 模型

**问题描述**:
如何实现非阻塞的 IO 操作。

**算法描述**:
使用 Future 和 async/await 实现异步 IO。

**伪代码**:
```
function asyncReadFile(path):
    future = Future()

    // 在后台线程读取
    backgroundThread.execute {
        try:
            data = readFile(path)
            future.complete(data)
        catch error:
            future.completeError(error)
    }

    return future
```

**复杂度分析**:
- 时间复杂度: O(n)，n 为文件大小
- 空间复杂度: O(n)

### 3.2 IO 合并

**问题描述**:
如何合并多个小 IO 操作以提高性能。

**算法描述**:
将相邻的读操作合并为一个大操作。

**伪代码**:
```
function mergeIOOperations(operations):
    // 按文件分组
    grouped = groupBy(operations, 'file')

    results = []

    for file, ops in grouped:
        // 按位置排序
        sorted = sortBy(ops, 'position')

        // 合并相邻操作
        merged = []
        current = sorted[0]

        for op in sorted[1:]:
            if op.position == current.position + current.size:
                // 合并
                current.size += op.size
            else:
                merged.add(current)
                current = op

        merged.add(current)

        // 执行合并后的操作
        for op in merged:
            result = executeIO(file, op)
            results.extend(distributeResult(result, op))

    return results
```

**复杂度分析**:
- 时间复杂度: O(n log n)，n 为操作数
- 空间复杂度: O(n)

## 4. 资源管理

### 4.1 文件句柄池

**描述**:
复用文件句柄以减少系统调用开销。

**实现**:

```dart
class FileHandlePool {
  final int _maxHandles;
  final Map<String, FileHandle> _handles = {};
  final Map<String, int> _refCounts = {};

  FileHandlePool({required int maxHandles}) : _maxHandles = maxHandles;

  /// 获取文件句柄
  Future<FileHandle> acquire(String path) async {
    // 检查是否已存在
    if (_handles.containsKey(path)) {
      _refCounts[path] = (_refCounts[path] ?? 0) + 1;
      return _handles[path]!;
    }

    // 检查是否超过限制
    if (_handles.length >= _maxHandles) {
      await _releaseLeastRecentlyUsed();
    }

    // 创建新句柄
    final handle = await FileHandle.open(path);
    _handles[path] = handle;
    _refCounts[path] = 1;

    return handle;
  }

  /// 释放文件句柄
  void release(String path) {
    _refCounts[path] = (_refCounts[path] ?? 1) - 1;

    if (_refCounts[path]! <= 0) {
      _handles[path]?.close();
      _handles.remove(path);
      _refCounts.remove(path);
    }
  }

  /// 释放最少使用的句柄
  Future<void> _releaseLeastRecentlyUsed() async {
    // TODO: 实现 LRU 策略
  }
}

class FileHandle {
  final String path;
  final RandomAccessFile raf;

  FileHandle(this.path, this.raf);

  static Future<FileHandle> open(String path) async {
    final raf = await File(path).open();
    return FileHandle(path, raf);
  }

  Future<void> close() async {
    await raf.close();
  }
}
```

### 4.2 连接池

**描述**:
复用网络连接以减少连接建立开销。

**实现**:

```dart
class ConnectionPool {
  final String _host;
  final int _port;
  final int _maxConnections;
  final Queue<Connection> _idleConnections = Queue();
  int _activeConnections = 0;

  ConnectionPool({
    required String host,
    required int port,
    required int maxConnections,
  })  : _host = host,
        _port = port,
        _maxConnections = maxConnections;

  /// 获取连接
  Future<Connection> acquire() async {
    // 检查空闲连接
    if (_idleConnections.isNotEmpty) {
      return _idleConnections.removeFirst();
    }

    // 检查是否超过限制
    if (_activeConnections >= _maxConnections) {
      await _waitForConnection();
      return acquire();
    }

    // 创建新连接
    final connection = await Connection.connect(_host, _port);
    _activeConnections++;

    return connection;
  }

  /// 释放连接
  void release(Connection connection) {
    if (connection.isClosed) {
      _activeConnections--;
    } else {
      _idleConnections.add(connection);
    }
  }

  Future<void> _waitForConnection() async {
    while (_activeConnections >= _maxConnections) {
      await Future.delayed(Duration(milliseconds: 100));
    }
  }
}

class Connection {
  final String host;
  final int port;
  final Socket _socket;

  Connection(this.host, this.port, this._socket);

  static Future<Connection> connect(String host, int port) async {
    final socket = await Socket.connect(host, port);
    return Connection(host, port, socket);
  }

  Future<void> close() async {
    await _socket.close();
  }

  bool get isClosed => _socket.done;
}
```

## 5. 性能优化

### 5.1 批量 IO

**描述**:
将多个小 IO 操作合并为批量操作。

**实现**:

```dart
class BatchIOWriter {
  final List<_WriteOperation> _batch = [];
  final int _maxBatchSize;
  final Duration _maxBatchDelay;
  Timer? _timer;

  BatchIOWriter({
    required int maxBatchSize,
    required Duration maxBatchDelay,
  })  : _maxBatchSize = maxBatchSize,
        _maxBatchDelay = maxBatchDelay {
    _startTimer();
  }

  /// 添加写入操作
  Future<void> write(String path, String content) async {
    final completer = Completer<void>();
    _batch.add(_WriteOperation(path, content, completer));

    if (_batch.length >= _maxBatchSize) {
      await _flush();
    }

    return completer.future;
  }

  /// 刷新批次
  Future<void> _flush() async {
    if (_batch.isEmpty) return;

    final operations = _batch.toList();
    _batch.clear();

    // 批量写入
    for (final op in operations) {
      try {
        final file = File(op.path);
        await file.writeAsString(op.content);
        op.completer.complete();
      } catch (e) {
        op.completer.completeError(e);
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(_maxBatchDelay, (_) => _flush());
  }

  void dispose() {
    _timer?.cancel();
    _flush();
  }
}

class _WriteOperation {
  final String path;
  final String content;
  final Completer<void> completer;

  _WriteOperation(this.path, this.content, this.completer);
}
```

### 5.2 缓冲池

**描述**:
复用缓冲区以减少内存分配。

**实现**:

```dart
class BufferPool {
  final int _bufferSize;
  final int _maxBuffers;
  final List<List<int>> _buffers = [];

  BufferPool({
    required int bufferSize,
    required int maxBuffers,
  })  : _bufferSize = bufferSize,
        _maxBuffers = maxBuffers;

  /// 获取缓冲区
  List<int> acquire() {
    if (_buffers.isNotEmpty) {
      return _buffers.removeLast();
    }

    return List<int>.filled(_bufferSize, 0);
  }

  /// 释放缓冲区
  void release(List<int> buffer) {
    if (_buffers.length < _maxBuffers) {
      _buffers.add(buffer);
    }
  }
}
```

## 6. 错误处理

### 6.1 IO 错误重试

**策略**:
- 网络错误自动重试
- 文件错误不重试
- 指数退避

**实现**:

```dart
class IORetryPolicy {
  final int maxAttempts;
  final Duration initialDelay;

  IORetryPolicy({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(milliseconds: 100),
  });

  Future<T> execute<T>(
    Future<T> Function() operation,
    bool shouldRetry(Object error),
  ) async {
    int attempts = 0;
    var delay = initialDelay;

    while (attempts < maxAttempts) {
      try {
        return await operation();
      } catch (e) {
        attempts++;

        if (attempts >= maxAttempts || !shouldRetry(e)) {
          rethrow;
        }

        await Future.delayed(delay);
        delay = Duration(
          microseconds: (delay.inMicroseconds * 2).round(),
        );
      }
    }

    throw Exception('重试次数耗尽');
  }
}

// 使用示例
final retryPolicy = IORetryPolicy();

final result = await retryPolicy.execute(
  () => File(path).readAsString(),
  (error) => error is FileSystemException,
);
```

## 7. 性能考虑

### 7.1 概念性性能指标

| 操作 | 目标延迟 | 说明 |
|------|----------|------|
| 文件读取 (1MB) | < 10ms | SSD 顺序读 |
| 文件写入 (1MB) | < 20ms | SSD 顺序写 |
| 网络请求 | < 100ms | 取决于网络 |
| 序列化 (1KB) | < 1ms | JSON 序列化 |

### 7.2 优化方向

1. **异步操作**:
   - 使用 async/await
   - 避免阻塞线程
   - 提高并发度

2. **批量操作**:
   - 合并小 IO
   - 减少系统调用
   - 提高吞吐量

3. **资源复用**:
   - 句柄池
   - 连接池
   - 缓冲池

## 8. 关键文件清单

```
lib/core/execution/io/
├── io_executor.dart              # IOExecutor 实现
├── file_handle_pool.dart         # 文件句柄池
├── connection_pool.dart          # 连接池
├── buffer_pool.dart              # 缓冲池
├── batch_io.dart                 # 批量 IO
├── io_retry_policy.dart          # IO 重试策略
└── io_operations.dart            # IO 操作定义
```

## 9. 参考资料

### 异步 IO
- Dart Async/Await
- Event Loop
- Non-blocking IO

### 资源池
- Object Pool Pattern
- Connection Pooling
- Resource Management

---

**文档所有者**: Node Graph Notebook 架构组
**最后更新**: 2025-01-14
