import 'dart:io';
import 'package:worker_pool/worker_pool.dart';
import 'cpu_task.dart';
import 'task_registry.dart';

/// 执行引擎（基于 worker_pool 0.0.5）
///
/// 提供跨 isolates 的 CPU 密集型任务执行能力
/// 自动管理 worker pool，支持常量共享和资源复用
///
/// ### 架构改进
///
/// 使用 TaskRegistry 模式消除硬编码的任务类型依赖：
/// - 插件通过 TaskRegistry 注册任务类型和结果转换器
/// - ExecutionEngine 通过注册表动态反序列化和转换结果
/// - 不再依赖具体任务实现，实现完全解耦
class ExecutionEngine {
  /// 私有构造函数，使用工厂模式创建单例实例
  ExecutionEngine();

  WorkerPool? _pool;
  final Map<String, CPUTask<dynamic>> _registeredTasks = {};
  TaskRegistry? _taskRegistry;

  /// 初始化执行引擎
  ///
  /// [maxWorkers] 最大 worker 数量（默认为 CPU 核心数 - 1）
  /// [taskRegistry] 任务注册表，用于任务类型注册和结果转换
  /// 注意：Dart VM 硬限制约 16 个并发 isolates
  Future<void> initialize({
    int? maxWorkers,
    TaskRegistry? taskRegistry,
  }) async {
    _taskRegistry = taskRegistry;

    // 设置全局任务注册表，供 isolate 使用
    if (taskRegistry != null) {
      setGlobalTaskRegistry(taskRegistry);
    }

    // Dart VM 硬限制：16 个并发 isolates
    // 自动 clamp 在 1-16 范围内
    final actualWorkers =
        (maxWorkers ?? (Platform.numberOfProcessors - 1)).clamp(1, 16);

    // 注册通用的任务执行函数
    final predefinedFunctions = <String, Function>{
      '_executeTask': _executeTaskInIsolate,
    };

    final config = WorkerPoolConfig(
      poolSize: actualWorkers,
      predefinedFunctions: predefinedFunctions,
    );

    _pool = await WorkerPool.initialize(config);
  }

  /// 执行 CPU 密集型任务
  ///
  /// [task] 要执行的 CPU 任务
  /// 返回任务执行结果
  ///
  /// 示例：
  /// ```dart
  /// final result = await engine.executeCPU(
  ///   TextLayoutTask(text: 'Hello', fontSize: 14.0),
  /// );
  /// ```
  Future<T> executeCPU<T>(CPUTask<T> task) async {
    if (_pool == null) {
      throw StateError('ExecutionEngine not initialized. Call initialize() first.');
    }

    // 注册任务实例（使用唯一 ID）
    final taskId = task.name;
    _registeredTasks[taskId] = task;

    try {
      // 序列化任务数据
      final taskData = _serializeTask(task);

      // 通过 worker pool 执行任务
      final result = await _pool!.submit<dynamic, dynamic>(
        '_executeTask',
        taskData,
      );

      // 根据任务类型转换结果
      return _convertResult<T>(task, result);
    } finally {
      // 清理注册的任务
      _registeredTasks.remove(taskId);
    }
  }

  /// 将序列化的结果转换为正确的类型
  ///
  /// 使用 TaskRegistry 中的结果转换器，不再硬编码任务类型
  T _convertResult<T>(CPUTask task, dynamic result) {
    if (_taskRegistry == null) {
      throw StateError('TaskRegistry not initialized. '
          'Did you forget to pass TaskRegistry to initialize()?');
    }

    // 使用注册表转换结果
    return _taskRegistry!.convertResult<T>(task.taskType, result);
  }

  /// 获取统计信息
  ///
  /// 返回 worker pool 的运行统计
  Map<String, dynamic> get stats {
    if (_pool == null) {
      throw StateError('ExecutionEngine not initialized.');
    }
    return _pool!.getStatistics();
  }

  /// 检查引擎是否已初始化
  bool get isInitialized => _pool != null;

  /// 关闭引擎并释放资源
  ///
  /// 等待所有正在执行的任务完成，然后关闭所有 workers
  Future<void> shutdown() async {
    if (_pool != null) {
      await _pool!.dispose();
      _pool = null;
      _registeredTasks.clear();
    }
  }

  /// 序列化任务数据
  Map<String, dynamic> _serializeTask(CPUTask task) => task.serialize();

  /// 设置全局任务注册表
  ///
  /// 此方法用于在 isolate 中访问 TaskRegistry
  static void setGlobalTaskRegistry(TaskRegistry registry) {
    _globalTaskRegistry = registry;
  }

  /// 在 isolate 中执行任务的静态函数
  ///
  /// 这个函数将被注册到 worker pool 中
  /// 通过反序列化任务数据并调用 execute() 方法执行任务
  ///
  /// 注意：此函数访问 TaskRegistry 需要通过特殊方式传递
  /// 由于 isolate 无法访问主线程的 TaskRegistry，我们使用全局注册表
  static TaskRegistry? _globalTaskRegistry;

  static Future<dynamic> _executeTaskInIsolate(dynamic taskData) async {
    try {
      // 反序列化任务数据
      // 使用全局 TaskRegistry 进行反序列化
      if (_globalTaskRegistry == null) {
        throw StateError('Global TaskRegistry not set. '
            'Call ExecutionEngine.setGlobalTaskRegistry() first.');
      }

      final task = _globalTaskRegistry!.deserialize(taskData as Map<String, dynamic>);

      // 执行任务并返回结果
      return await task.execute();
    } catch (e) {
      // 重新抛出异常，让调用者处理
      rethrow;
    }
  }
}
