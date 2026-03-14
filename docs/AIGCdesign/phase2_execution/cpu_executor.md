# CPU 执行器设计文档

## 1. 概述

### 1.1 职责
CPU 执行器专门负责处理 CPU 密集型任务，包括：
- 图算法计算（BFS、DFS、最短路径）
- 数据转换和处理
- 排序和搜索
- 加密解密操作

### 1.2 目标
- **高吞吐**: 最大化 CPU 利用率
- **低延迟**: 最小化计算延迟
- **负载均衡**: 均衡使用 CPU 核心
- **可扩展**: 支持多核并行

### 1.3 关键挑战
- **CPU 密集**: 避免阻塞事件循环
- **线程管理**: 合理分配线程资源
- **负载均衡**: 避免单核过载
- **内存管理**: 控制内存使用

## 2. 架构设计

### 2.1 组件结构

```
CPUExecutor
    │
    ├── Thread Pool (线程池)
    │   ├── Worker Threads (工作线程)
    │   ├── Task Queue (任务队列)
    │   └── Thread Management (线程管理)
    │
    ├── Task Scheduler (任务调度器)
    │   ├── Priority Queue (优先级队列)
    │   ├── Load Balancer (负载均衡)
    │   └── Affinity Manager (亲和性管理)
    │
    ├── Compute Operations (计算操作)
    │   ├── Graph Algorithms (图算法)
    │   ├── Data Processing (数据处理)
    │   └── Crypto Operations (加密操作)
    │
    └── Performance Monitor (性能监控)
        ├── CPU Usage (CPU 使用率)
        ├── Task Timing (任务计时)
        └── Throughput (吞吐量)
```

### 2.2 接口定义

#### CPUExecutor 接口

```dart
/// CPU 执行器
class CPUExecutor extends Executor {
  final List<CPUWorker> _workers;
  final TaskScheduler _scheduler;
  final PerformanceMonitor _monitor;

  CPUExecutor({
    required int numWorkers,
    required TaskScheduler scheduler,
    required PerformanceMonitor monitor,
  })  : _workers = List.generate(
          numWorkers,
          (i) => CPUWorker(id: i, scheduler: scheduler),
        ),
        _scheduler = scheduler,
        _monitor = monitor {
    _start();
  }

  @override
  ExecutorType get type => ExecutorType.cpu;

  @override
  Future<TaskResult> execute(Task task) async {
    if (task.data is! CPUTaskData) {
      return TaskResult.failure(
        taskId: task.id,
        error: '无效的任务数据类型',
        executionTime: Duration.zero,
      );
    }

    final cpuTask = task.data as CPUTaskData;

    // 添加到调度器
    await _scheduler.schedule(task);

    // 等待执行完成
    final completer = Completer<TaskResult>();

    // TODO: 实现等待逻辑

    return completer.future;
  }

  @override
  double get load {
    final active = _workers.where((w) => w.isBusy).length;
    return active / _workers.length;
  }

  @override
  int get queueLength => _scheduler.queueLength;

  @override
  bool get isAvailable => _scheduler.hasAvailableWorker;

  void _start() {
    for (final worker in _workers) {
      worker.start();
    }
  }

  @override
  Future<void> pause() async {
    for (final worker in _workers) {
      await worker.pause();
    }
  }

  @override
  Future<void> resume() async {
    for (final worker in _workers) {
      await worker.resume();
    }
  }

  @override
  Future<void> close() async {
    for (final worker in _workers) {
      await worker.stop();
    }
  }

  @override
  ExecutorStats get stats {
    return ExecutorStats(
      totalTasks: _monitor.totalTasks,
      succeededTasks: _monitor.succeededTasks,
      failedTasks: _monitor.failedTasks,
      totalExecutionTime: _monitor.totalExecutionTime,
      averageExecutionTime: _monitor.averageExecutionTime,
      currentQueueLength: queueLength,
    );
  }
}

/// CPU 工作线程
class CPUWorker {
  final int id;
  final TaskScheduler _scheduler;
  Isolate? _isolate;
  bool _isRunning = false;
  bool _isPaused = false;

  CPUWorker({required this.id, required TaskScheduler scheduler})
      : _scheduler = scheduler;

  void start() {
    if (_isRunning) return;

    _isRunning = true;

    // 启动 Isolate
    Isolate.spawn(_workerMain, _WorkerConfig(id: id)).then((isolate) {
      _isolate = isolate;
    });
  }

  static void _workerMain(_WorkerConfig config) {
    // 工作线程主循环
    while (true) {
      // 从调度器获取任务
      final task = _getTask();

      if (task == null) {
        sleep(Duration(milliseconds: 100));
        continue;
      }

      // 执行任务
      final result = _executeTask(task);

      // 返回结果
      _completeTask(task, result);
    }
  }

  Future<void> pause() async {
    _isPaused = true;
  }

  Future<void> resume() async {
    _isPaused = false;
  }

  Future<void> stop() async {
    _isRunning = false;
    await _isolate?.kill();
  }

  bool get isBusy => _isPaused;

  static Task? _getTask() {
    // TODO: 从调度器获取任务
    return null;
  }

  static TaskResult _executeTask(Task task) {
    // TODO: 执行任务
    return TaskResult.success(
      taskId: task.id,
      data: null,
      executionTime: Duration.zero,
    );
  }

  static void _completeTask(Task task, TaskResult result) {
    // TODO: 完成任务
  }
}

class _WorkerConfig {
  final int id;
  _WorkerConfig({required this.id});
}
```

## 3. 核心算法

### 3.1 并行任务执行

**问题描述**:
如何利用多核 CPU 并行执行任务。

**算法描述**:
使用 Isolate 实现真正的并行执行。

**伪代码**:
```
function parallelExecute(tasks):
    // 创建多个 Isolate
    isolates = []
    for i in range(numCores):
        isolate = Isolate.spawn(workerMain)
        isolates.add(isolate)

    // 分配任务到 Isolate
    results = []
    for task in tasks:
        isolate = selectLeastBusyIsolate(isolates)
        result = isolate.execute(task)
        results.add(result)

    return results
```

**复杂度分析**:
- 时间复杂度: O(n/p)，n 为任务数，p 为处理器数
- 空间复杂度: O(n)

### 3.2 工作窃取（Work Stealing）

**问题描述**:
如何平衡多个工作线程的负载。

**算法描述**:
空闲线程从忙碌线程的队列中窃取任务。

**伪代码**:
```
function workStealingScheduler():
    workers = createWorkers(numCores)
    queues = [Queue() for _ in workers]

    function workerLoop(workerId):
        while true:
            task = queues[workerId].dequeue()

            if task == null:
                // 窃取任务
                victimId = randomWorkerId(except: workerId)
                task = queues[victimId].steal()

            if task != null:
                execute(task)

    function steal():
        // 从队列尾部窃取一半任务
        return queue.stealHalf()
```

**复杂度分析**:
- 时间复杂度: O(1) 平均情况
- 空间复杂度: O(n)

## 4. 计算操作

### 4.1 图算法

**BFS 并行实现**:

```dart
class ParallelBFS {
  final int numWorkers;
  final List<CPUWorker> workers;

  ParallelBFS({required this.numWorkers});

  Future<List<String>> execute(
    String startNodeId,
    IReferenceStorage refStorage,
  ) async {
    final visited = <String>{};
    final queue = Queue<String>();
    final results = <String>[];

    queue.add(startNodeId);

    // 创建多个 Isolate 并行处理
    final isolates = <Future<List<String>>>[];

    for (int i = 0; i < numWorkers; i++) {
      isolates.add(Isolate.run(() => _bfsWorker(
            queue: queue,
            visited: visited,
            refStorage: refStorage,
          )));
    }

    final parallelResults = await Future.wait(isolates);

    for (final result in parallelResults) {
      results.addAll(result);
    }

    return results;
  }

  static List<String> _bfsWorker({
    required Queue<String> queue,
    required Set<String> visited,
    required IReferenceStorage refStorage,
  }) {
    final results = <String>[];

    while (queue.isNotEmpty) {
      final nodeId = queue.removeFirst();

      if (visited.contains(nodeId)) continue;

      visited.add(nodeId);
      results.add(nodeId);

      // 获取邻居
      final neighbors = refStorage.getForwardReferences(nodeId);

      for (final ref in neighbors) {
        if (!visited.contains(ref.targetId)) {
          queue.add(ref.targetId);
        }
      }
    }

    return results;
  }
}
```

### 4.2 数据处理

**并行排序**:

```dart
class ParallelSort {
  static Future<List<T>> execute<T>(List<T> data) async {
    if (data.length < 1000) {
      // 小数据集直接排序
      return data..sort();
    }

    // 分割数据
    final mid = data.length ~/ 2;
    final left = data.sublist(0, mid);
    final right = data.sublist(mid);

    // 并行排序
    final results = await Future.wait([
      Isolate.run(() => execute(left)),
      Isolate.run(() => execute(right)),
    ]);

    // 合并结果
    return _merge(results[0], results[1]);
  }

  static List<T> _merge<T>(List<T> left, List<T> right) {
    final result = <T>[];
    int i = 0, j = 0;

    while (i < left.length && j < right.length) {
      // TODO: 实现比较逻辑
      if ((left[i] as Comparable).compareTo(right[j]) < 0) {
        result.add(left[i++]);
      } else {
        result.add(right[j++]);
      }
    }

    result.addAll(left.sublist(i));
    result.addAll(right.sublist(j));

    return result;
  }
}
```

## 5. 性能优化

### 5.1 任务分块

**描述**:
将大任务分割为小任务并行执行。

**实现**:

```dart
class TaskChunker {
  static List<List<T>> chunk<T>(List<T> data, int chunkSize) {
    final chunks = <List<T>>[];

    for (int i = 0; i < data.length; i += chunkSize) {
      final end = min(i + chunkSize, data.length);
      chunks.add(data.sublist(i, end));
    }

    return chunks;
  }

  static Future<List<R>> parallelExecute<T, R>(
    List<T> data,
    Future<R> Function(T) operation, {
    int chunkSize = 100,
  }) async {
    final chunks = chunk(data, chunkSize);

    final results = await Future.wait(
      chunks.map((chunk) => Isolate.run(() async {
        final chunkResults = <R>[];
        for (final item in chunk) {
          chunkResults.add(await operation(item));
        }
        return chunkResults;
      })),
    );

    return results.expand((e) => e).toList();
  }
}
```

### 5.2 缓存优化

**描述**:
缓存计算结果以避免重复计算。

**实现**:

```dart
class ComputeCache {
  final Map<String, _CacheEntry> _cache = {};
  final int _maxSize;

  ComputeCache({required int maxSize}) : _maxSize = maxSize;

  Future<T> get<T>(
    String key,
    Future<T> Function() compute,
  ) async {
    // 检查缓存
    final entry = _cache[key];
    if (entry != null && !entry.isExpired) {
      return entry.value as T;
    }

    // 计算结果
    final value = await compute();

    // 更新缓存
    _cache[key] = _CacheEntry(
      value: value,
      createdAt: DateTime.now(),
    );

    // 清理过期缓存
    _cleanup();

    return value;
  }

  void _cleanup() {
    if (_cache.length <= _maxSize) return;

    // 删除最旧的条目
    final entries = _cache.entries.toList()
      ..sort((a, b) => a.value.createdAt.compareTo(b.value.createdAt));

    final toRemove = entries.take(_cache.length - _maxSize);

    for (final entry in toRemove) {
      _cache.remove(entry.key);
    }
  }
}

class _CacheEntry {
  final dynamic value;
  final DateTime createdAt;

  _CacheEntry({required this.value, required this.createdAt});

  bool get isExpired {
    const ttl = Duration(minutes: 5);
    return DateTime.now().difference(createdAt) > ttl;
  }
}
```

## 6. 性能考虑

### 6.1 概念性性能指标

| 操作 | 目标延迟 | 说明 |
|------|----------|------|
| 排序 (10K 元素) | < 100ms | 并行排序 |
| BFS (1K 节点) | < 50ms | 图遍历 |
| 数据转换 (1K 条) | < 10ms | 批量转换 |
| 加密 (1KB) | < 5ms | AES 加密 |

### 6.2 优化方向

1. **并行计算**:
   - 使用 Isolate
   - 任务分块
   - 工作窃取

2. **缓存优化**:
   - 结果缓存
   - 中间结果缓存
   - LRU 策略

3. **算法优化**:
   - 选择高效算法
   - 减少内存分配
   - 优化热点代码

## 7. 关键文件清单

```
lib/core/execution/cpu/
├── cpu_executor.dart             # CPUExecutor 实现
├── cpu_worker.dart               # CPUWorker 实现
├── task_scheduler.dart           # 任务调度器
├── graph_algorithms.dart         # 图算法
├── data_processing.dart          # 数据处理
├── parallel_sort.dart            # 并行排序
├── task_chunker.dart             # 任务分块
├── compute_cache.dart            # 计算缓存
└── performance_monitor.dart      # 性能监控
```

## 8. 参考资料

### 并行计算
- Multi-threading in Dart
- Isolate Communication
- Parallel Algorithms

### CPU 优化
- CPU Cache Optimization
- SIMD Instructions
- Branch Prediction

---

**文档所有者**: Node Graph Notebook 架构组
**最后更新**: 2025-01-14
