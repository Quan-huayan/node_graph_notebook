# 执行引擎架构设计文档

## 1. 概述

### 1.1 职责
执行引擎是系统的核心执行层，负责：
- 协调不同类型的执行器（IO、CPU、GPU）
- 调度和优化任务执行
- 管理执行资源
- 监控执行性能

### 1.2 目标
- **性能**: 最大化系统吞吐量
- **资源利用**: 充分利用硬件资源
- **可扩展性**: 支持添加新的执行器类型
- **容错性**: 执行失败时的恢复机制

### 1.3 关键挑战
- **任务调度**: 如何高效分配任务到合适的执行器
- **负载均衡**: 避免单个执行器过载
- **资源竞争**: 多个执行器竞争共享资源
- **错误处理**: 执行失败的隔离和恢复

## 2. 架构设计

### 2.1 组件结构

```
ExecutionEngine
    │
    ├── Scheduler (调度器)
    │   ├── Task Queue (任务队列)
    │   ├── Priority Manager (优先级管理)
    │   └── Load Balancer (负载均衡)
    │
    ├── Executors (执行器集合)
    │   ├── IO Executor (IO 执行器)
    │   ├── CPU Executor (CPU 执行器)
    │   └── GPU Executor (GPU 执行器)
    │
    ├── Resource Manager (资源管理器)
    │   ├── Memory Manager (内存管理)
    │   ├── Thread Pool (线程池)
    │   └── GPU Manager (GPU 管理)
    │
    └── Monitor (监控器)
        ├── Performance Metrics (性能指标)
        ├── Error Tracking (错误跟踪)
        └── Resource Usage (资源使用)
```

### 2.2 接口定义

#### Task 定义

```dart
/// 执行任务
class Task {
  /// 任务 ID
  final String id;

  /// 任务类型
  final TaskType type;

  /// 任务优先级
  final TaskPriority priority;

  /// 任务数据
  final TaskData data;

  /// 回调函数
  final TaskCallback? callback;

  /// 超时时间
  final Duration? timeout;

  /// 创建时间
  final DateTime createdAt;

  Task({
    required this.id,
    required this.type,
    this.priority = TaskPriority.normal,
    required this.data,
    this.callback,
    this.timeout,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 是否过期
  bool get isExpired {
    if (timeout == null) return false;
    return DateTime.now().isAfter(createdAt.add(timeout!));
  }
}

/// 任务类型
enum TaskType {
  /// IO 密集型任务
  io,

  /// CPU 密集型任务
  cpu,

  /// GPU 加速任务
  gpu,
}

/// 任务优先级
enum TaskPriority {
  low,
  normal,
  high,
  urgent,
}

/// 任务数据
abstract class TaskData {
  /// 序列化
  Map<String, dynamic> toJson();

  /// 反序列化
  static TaskData fromJson(Map<String, dynamic> json) {
    // 根据类型创建具体数据
    final type = json['type'] as String;
    switch (type) {
      case 'io':
        return IOTaskData.fromJson(json);
      case 'cpu':
        return CPUTaskData.fromJson(json);
      case 'gpu':
        return GPUTaskData.fromJson(json);
      default:
        throw ArgumentError('Unknown task type: $type');
    }
  }
}

/// IO 任务数据
class IOTaskData extends TaskData {
  final String operation;
  final Map<String, dynamic> parameters;

  IOTaskData({
    required this.operation,
    required this.parameters,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'io',
        'operation': operation,
        'parameters': parameters,
      };

  static IOTaskData fromJson(Map<String, dynamic> json) => IOTaskData(
        operation: json['operation'] as String,
        parameters: json['parameters'] as Map<String, dynamic>,
      );
}

/// CPU 任务数据
class CPUTaskData extends TaskData {
  final String operation;
  final Map<String, dynamic> parameters;

  CPUTaskData({
    required this.operation,
    required this.parameters,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'cpu',
        'operation': operation,
        'parameters': parameters,
      };

  static CPUTaskData fromJson(Map<String, dynamic> json) => CPUTaskData(
        operation: json['operation'] as String,
        parameters: json['parameters'] as Map<String, dynamic>,
      );
}

/// GPU 任务数据
class GPUTaskData extends TaskData {
  final String operation;
  final Map<String, dynamic> parameters;

  GPUTaskData({
    required this.operation,
    required this.parameters,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'gpu',
        'operation': operation,
        'parameters': parameters,
      };

  static GPUTaskData fromJson(Map<String, dynamic> json) => GPUTaskData(
        operation: json['operation'] as String,
        parameters: json['parameters'] as Map<String, dynamic>,
      );
}

/// 任务回调
typedef TaskCallback = void Function(TaskResult result);

/// 任务结果
class TaskResult {
  final String taskId;
  final bool isSuccess;
  final dynamic data;
  final String? error;
  final Duration executionTime;
  final DateTime completedAt;

  TaskResult({
    required this.taskId,
    required this.isSuccess,
    this.data,
    this.error,
    required this.executionTime,
    required this.completedAt,
  });

  factory TaskResult.success({
    required String taskId,
    required dynamic data,
    required Duration executionTime,
  }) {
    return TaskResult(
      taskId: taskId,
      isSuccess: true,
      data: data,
      executionTime: executionTime,
      completedAt: DateTime.now(),
    );
  }

  factory TaskResult.failure({
    required String taskId,
    required String error,
    required Duration executionTime,
  }) {
    return TaskResult(
      taskId: taskId,
      isSuccess: false,
      error: error,
      executionTime: executionTime,
      completedAt: DateTime.now(),
    );
  }
}
```

#### Executor 接口

```dart
/// 执行器接口
abstract class Executor {
  /// 执行器类型
  ExecutorType get type;

  /// 执行任务
  Future<TaskResult> execute(Task task);

  /// 获取负载
  double get load;

  /// 获取队列长度
  int get queueLength;

  /// 是否可用
  bool get isAvailable;

  /// 暂停执行器
  Future<void> pause();

  /// 恢复执行器
  Future<void> resume();

  /// 关闭执行器
  Future<void> close();

  /// 获取统计信息
  ExecutorStats get stats;
}

/// 执行器类型
enum ExecutorType {
  io,
  cpu,
  gpu,
}

/// 执行器统计信息
class ExecutorStats {
  final int totalTasks;
  final int succeededTasks;
  final int failedTasks;
  final Duration totalExecutionTime;
  final double averageExecutionTime;
  final int currentQueueLength;

  ExecutorStats({
    required this.totalTasks,
    required this.succeededTasks,
    required this.failedTasks,
    required this.totalExecutionTime,
    required this.averageExecutionTime,
    required this.currentQueueLength,
  });
}
```

#### ExecutionEngine 接口

```dart
/// 执行引擎接口
abstract class IExecutionEngine {
  /// 执行任务
  Future<TaskResult> execute(Task task);

  /// 批量执行任务
  Future<List<TaskResult>> executeBatch(List<Task> tasks);

  /// 添加执行器
  void addExecutor(Executor executor);

  /// 移除执行器
  void removeExecutor(ExecutorType type);

  /// 获取执行器
  Executor? getExecutor(ExecutorType type);

  /// 获取所有执行器
  List<Executor> get executors;

  /// 暂停引擎
  Future<void> pause();

  /// 恢复引擎
  Future<void> resume();

  /// 关闭引擎
  Future<void> close();

  /// 获取统计信息
  ExecutionEngineStats get stats;
}

/// 执行引擎统计信息
class ExecutionEngineStats {
  final int totalTasks;
  final int succeededTasks;
  final int failedTasks;
  final Duration totalExecutionTime;
  final double averageExecutionTime;
  final Map<ExecutorType, ExecutorStats> executorStats;

  ExecutionEngineStats({
    required this.totalTasks,
    required this.succeededTasks,
    required this.failedTasks,
    required this.totalExecutionTime,
    required this.averageExecutionTime,
    required this.executorStats,
  });
}
```

## 3. 核心算法

### 3.1 任务调度算法

**问题描述**:
如何高效地将任务分配到合适的执行器。

**算法描述**:
基于任务类型和执行器负载进行智能调度。

**伪代码**:
```
function scheduleTask(task):
    // 1. 确定执行器类型
    executorType = task.type

    // 2. 获取该类型的所有执行器
    executors = getExecutors(executorType)

    // 3. 选择负载最低的执行器
    selectedExecutor = null
    minLoad = Infinity

    for executor in executors:
        if executor.isAvailable and executor.load < minLoad:
            minLoad = executor.load
            selectedExecutor = executor

    // 4. 如果没有可用执行器，等待
    if selectedExecutor == null:
        await waitForAvailableExecutor(executorType)
        return scheduleTask(task)

    // 5. 提交任务到执行器
    return selectedExecutor.execute(task)
```

**复杂度分析**:
- 时间复杂度: O(n)，n 为执行器数量
- 空间复杂度: O(1)

**实现**:

```dart
class ExecutionEngine implements IExecutionEngine {
  final Map<ExecutorType, List<Executor>> _executors = {};
  final Scheduler _scheduler;

  ExecutionEngine(this._scheduler);

  @override
  Future<TaskResult> execute(Task task) async {
    // 1. 调度任务
    final executor = await _scheduler.schedule(task);

    if (executor == null) {
      return TaskResult.failure(
        taskId: task.id,
        error: '没有可用的执行器',
        executionTime: Duration.zero,
      );
    }

    // 2. 执行任务
    final stopwatch = Stopwatch()..start();

    try {
      final result = await executor.execute(task);

      stopwatch.stop();

      if (result.isSuccess) {
        return TaskResult.success(
          taskId: task.id,
          data: result.data,
          executionTime: stopwatch.elapsed,
        );
      } else {
        return TaskResult.failure(
          taskId: task.id,
          error: result.error ?? '执行失败',
          executionTime: stopwatch.elapsed,
        );
      }
    } catch (e) {
      stopwatch.stop();

      return TaskResult.failure(
        taskId: task.id,
        error: e.toString(),
        executionTime: stopwatch.elapsed,
      );
    }
  }

  @override
  void addExecutor(Executor executor) {
    _executors
        .putIfAbsent(executor.type, () => [])
        .add(executor);
  }

  @override
  List<Executor> get executors {
    final result = <Executor>[];
    for (final list in _executors.values) {
      result.addAll(list);
    }
    return result;
  }
}
```

### 3.2 负载均衡算法

**问题描述**:
如何平衡多个执行器的负载。

**算法描述**:
使用加权轮询（Weighted Round Robin）算法。

**伪代码**:
```
class WeightedRoundRobin:
    weights = Map<Executor, int>
    currentWeights = Map<Executor, int>

    function select(executors):
        // 1. 计算当前权重
        totalWeight = 0
        bestExecutor = null
        maxCurrentWeight = -Infinity

        for executor in executors:
            if not executor.isAvailable:
                continue

            weight = weights[executor]
            current = currentWeights.get(executor, 0) + weight

            currentWeights[executor] = current
            totalWeight += weight

            if current > maxCurrentWeight:
                maxCurrentWeight = current
                bestExecutor = executor

        // 2. 减少选中执行器的当前权重
        if bestExecutor != null:
            currentWeights[bestExecutor] -= totalWeight

        return bestExecutor
```

**复杂度分析**:
- 时间复杂度: O(n)，n 为执行器数量
- 空间复杂度: O(n)

### 3.3 优先级调度算法

**问题描述**:
如何处理不同优先级的任务。

**算法描述**:
使用多级优先级队列。

**伪代码**:
```
class PriorityQueue:
    queues = {
        urgent: Queue(),
        high: Queue(),
        normal: Queue(),
        low: Queue(),
    }

    function enqueue(task):
        queues[task.priority].enqueue(task)

    function dequeue():
        // 按优先级顺序检查
        for priority in [urgent, high, normal, low]:
            if not queues[priority].isEmpty():
                return queues[priority].dequeue()

        return null  // 队列为空
```

**复杂度分析**:
- 入队时间复杂度: O(1)
- 出队时间复杂度: O(1)

## 4. 资源管理

### 4.1 内存管理

**策略**:
- 为每个执行器分配内存配额
- 监控内存使用
- 超限时拒绝新任务

**实现**:

```dart
class MemoryManager {
  final int _totalMemory;
  final Map<ExecutorType, int> _allocatedMemory = {};
  final Map<ExecutorType, int> _usedMemory = {};

  MemoryManager(this._totalMemory);

  /// 分配内存
  bool allocate(ExecutorType type, int size) {
    final allocated = _allocatedMemory[type] ?? 0;
    final used = _usedMemory[type] ?? 0;

    if (used + size > allocated) {
      return false;  // 超出配额
    }

    _usedMemory[type] = used + size;
    return true;
  }

  /// 释放内存
  void release(ExecutorType type, int size) {
    final used = _usedMemory[type] ?? 0;
    _usedMemory[type] = max(0, used - size);
  }

  /// 设置执行器配额
  void setQuota(ExecutorType type, int quota) {
    _allocatedMemory[type] = quota;
  }

  /// 获取可用内存
  int getAvailable(ExecutorType type) {
    final allocated = _allocatedMemory[type] ?? 0;
    final used = _usedMemory[type] ?? 0;
    return allocated - used;
  }
}
```

### 4.2 线程池管理

**策略**:
- 为 CPU 执行器维护线程池
- 动态调整线程数量
- 复用线程减少开销

**实现**:

```dart
class ThreadPool {
  final int _maxThreads;
  final List<Thread> _threads = [];
  final Queue<_ThreadPoolTask> _taskQueue = Queue();

  ThreadPool({int maxThreads = 4}) : _maxThreads = maxThreads {
    _initialize();
  }

  void _initialize() {
    for (int i = 0; i < _maxThreads; i++) {
      final thread = Thread(_worker);
      _threads.add(thread);
      thread.start();
    }
  }

  void _worker() {
    while (true) {
      final task = _taskQueue.dequeue();
      if (task == null) break;

      try {
        task();
      } catch (e) {
        // 错误处理
      }
    }
  }

  /// 提交任务
  Future<T> submit<T>(Future<T> Function() fn) async {
    final completer = Completer<T>();

    _taskQueue.add(() async {
      try {
        final result = await fn();
        completer.complete(result);
      } catch (e) {
        completer.completeError(e);
      }
    });

    return completer.future;
  }

  /// 关闭线程池
  Future<void> shutdown() async {
    for (final thread in _threads) {
      thread.stop();
    }
  }
}
```

## 5. 监控和统计

### 5.1 性能指标

```dart
class PerformanceMonitor {
  final List<TaskExecutionRecord> _records = [];

  /// 记录任务执行
  void record(Task task, TaskResult result) {
    _records.add(TaskExecutionRecord(
      taskId: task.id,
      type: task.type,
      priority: task.priority,
      isSuccess: result.isSuccess,
      executionTime: result.executionTime,
      timestamp: DateTime.now(),
    ));
  }

  /// 获取平均执行时间
  Duration getAverageExecutionTime() {
    if (_records.isEmpty) return Duration.zero;

    final total = _records
        .map((r) => r.executionTime.inMicroseconds)
        .reduce((a, b) => a + b);

    return Duration(microseconds: total ~/ _records.length);
  }

  /// 获取成功率
  double getSuccessRate() {
    if (_records.isEmpty) return 0.0;

    final succeeded = _records.where((r) => r.isSuccess).length;
    return succeeded / _records.length;
  }

  /// 获取吞吐量（任务/秒）
  double getThroughput() {
    if (_records.isEmpty) return 0.0;

    final now = DateTime.now();
    final oneMinuteAgo = now.subtract(Duration(minutes: 1));

    final recent = _records.where((r) => r.timestamp.isAfter(oneMinuteAgo));
    return recent.length / 60.0;  // 每秒任务数
  }
}

class TaskExecutionRecord {
  final String taskId;
  final TaskType type;
  final TaskPriority priority;
  final bool isSuccess;
  final Duration executionTime;
  final DateTime timestamp;

  TaskExecutionRecord({
    required this.taskId,
    required this.type,
    required this.priority,
    required this.isSuccess,
    required this.executionTime,
    required this.timestamp,
  });
}
```

## 6. 错误处理

### 6.1 重试策略

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

  Future<T> execute<T>(Future<T> Function() fn) async {
    int attempts = 0;
    var delay = initialDelay;

    while (attempts < maxAttempts) {
      try {
        return await fn();
      } catch (e) {
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

    throw Exception('重试次数耗尽');
  }
}
```

### 6.2 熔断机制

```dart
class CircuitBreaker {
  final int failureThreshold;
  final Duration timeout;

  int _failureCount = 0;
  DateTime? _lastFailureTime;
  bool _isOpen = false;

  CircuitBreaker({
    required this.failureThreshold,
    required this.timeout,
  });

  Future<T> execute<T>(Future<T> Function() fn) async {
    if (_isOpen) {
      // 检查是否可以尝试恢复
      if (_lastFailureTime != null &&
          DateTime.now().difference(_lastFailureTime!) > timeout) {
        _isOpen = false;
        _failureCount = 0;
      } else {
        throw CircuitBreakerOpenException('熔断器打开');
      }
    }

    try {
      final result = await fn();
      _failureCount = 0;
      return result;
    } catch (e) {
      _failureCount++;
      _lastFailureTime = DateTime.now();

      if (_failureCount >= failureThreshold) {
        _isOpen = true;
      }

      rethrow;
    }
  }
}

class CircuitBreakerOpenException implements Exception {
  final String message;
  CircuitBreakerOpenException(this.message);

  @override
  String toString() => 'CircuitBreakerOpenException: $message';
}
```

## 7. 性能考虑

### 7.1 概念性性能指标

| 指标 | 目标值 | 说明 |
|------|--------|------|
| 任务调度延迟 | < 1ms | 从提交到开始执行 |
| IO 任务吞吐 | > 1000 ops/s | 每秒操作数 |
| CPU 任务吞吐 | > 100 ops/s | CPU 密集型任务 |
| GPU 任务吞吐 | > 50 ops/s | GPU 加速任务 |

### 7.2 优化方向

1. **任务批处理**:
   - 合并相似任务
   - 减少调度开销
   - 提高吞吐量

2. **资源预分配**:
   - 预先分配资源
   - 减少等待时间
   - 提高响应速度

3. **异步执行**:
   - 非阻塞执行
   - 并行处理
   - 提高并发度

## 8. 关键文件清单

```
lib/core/execution/
├── execution_engine.dart         # IExecutionEngine 接口
├── task.dart                    # Task 和 TaskResult 定义
├── executor.dart                # Executor 接口
├── scheduler.dart               # 调度器
├── load_balancer.dart           # 负载均衡器
├── resource_manager.dart        # 资源管理器
├── memory_manager.dart          # 内存管理器
├── thread_pool.dart             # 线程池
├── monitor.dart                 # 性能监控器
├── retry_policy.dart            # 重试策略
├── circuit_breaker.dart         # 熔断器
└── stats.dart                   # 统计信息
```

## 9. 参考资料

### 执行引擎设计
- Executor Pattern
- Thread Pool Pattern
- Actor Model

### 调度算法
- Round Robin Scheduling
- Priority Scheduling
- Weighted Fair Queuing

### 资源管理
- Memory Management Techniques
- Thread Pool Implementation
- GPU Resource Management

---

**文档所有者**: Node Graph Notebook 架构组
**最后更新**: 2025-01-14
