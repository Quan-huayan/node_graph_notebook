import 'dart:io';
import 'package:worker_pool/worker_pool.dart';
import 'cpu_task.dart';
import 'task_registry.dart';

/// 执行引擎（基于 worker_pool 0.0.5）
///
/// 提供跨 isolates 的 CPU 密集型任务执行能力
/// 自动管理 worker pool，支持常量共享和资源复用
///
/// ### 架构说明
///
/// 由于 Dart isolate 不共享内存，静态变量在 isolate 之间是独立的。
/// 因此我们采用以下策略：
/// - 使用 `constantProviders` 传递任务工厂函数名映射
/// - 工厂函数必须是顶层函数或静态方法，通过名称引用
/// - 在 isolate 中通过 `FunctionRegistry` 获取工厂函数
///
/// ### TaskRegistry 设计
///
/// 使用 TaskRegistry 模式消除硬编码的任务类型依赖：
/// - 插件通过 TaskRegistry 注册任务类型和结果转换器
/// - ExecutionEngine 通过注册表动态反序列化和转换结果
/// - 不再依赖具体任务实现，实现完全解耦
class ExecutionEngine {
  /// 创建执行引擎实例
  ExecutionEngine();

  WorkerPool? _pool;
  TaskRegistry? _taskRegistry;
  final Map<String, String> _taskTypeToFunctionName = {};

  /// 初始化执行引擎
  ///
  /// [maxWorkers] 最大 worker 数量，默认为 CPU 核心数 - 1（范围 1-16）
  /// [taskRegistry] 任务注册表，用于任务类型和结果转换
  Future<void> initialize({
    int? maxWorkers,
    TaskRegistry? taskRegistry,
  }) async {
    _taskRegistry = taskRegistry;

    final actualWorkers =
        (maxWorkers ?? (Platform.numberOfProcessors - 1)).clamp(1, 16);

    final predefinedFunctions = <String, Function>{
      '_executeTask': _executeTaskInIsolate,
    };

    if (taskRegistry != null) {
      for (final taskType in taskRegistry.taskTypes) {
        final functionName = '_taskFactory_$taskType';
        final factory = taskRegistry.getFactory(taskType);
        if (factory != null) {
          predefinedFunctions[functionName] = factory;
          _taskTypeToFunctionName[taskType] = functionName;
        }
      }
    }

    final constantProviders = <ConstantProvider>[
      () async => {'taskTypeToFunctionName': _taskTypeToFunctionName},
    ];

    final config = WorkerPoolConfig(
      poolSize: actualWorkers,
      predefinedFunctions: predefinedFunctions,
      constantProviders: constantProviders,
    );

    _pool = await WorkerPool.initialize(config);
  }

  /// 执行 CPU 密集型任务
  ///
  /// [task] 要执行的 CPU 任务
  /// 返回任务执行结果
  ///
  /// 抛出 [StateError] 如果引擎未初始化
  Future<T> executeCPU<T>(CPUTask<T> task) async {
    if (_pool == null) {
      throw StateError('ExecutionEngine not initialized. Call initialize() first.');
    }

    final taskData = _serializeTask(task);

    final result = await _pool!.submit<dynamic, dynamic>(
      '_executeTask',
      taskData,
    );

    return _convertResult<T>(task, result);
  }

  T _convertResult<T>(CPUTask task, dynamic result) {
    if (_taskRegistry == null) {
      throw StateError('TaskRegistry not initialized. '
          'Did you forget to pass TaskRegistry to initialize()?');
    }

    return _taskRegistry!.convertResult<T>(task.taskType, result);
  }

  /// 获取 worker pool 统计信息
  ///
  /// 返回包含 worker 状态、任务队列等信息的 Map
  ///
  /// 抛出 [StateError] 如果引擎未初始化
  Map<String, dynamic> get stats {
    if (_pool == null) {
      throw StateError('ExecutionEngine not initialized.');
    }
    return _pool!.getStatistics();
  }

  /// 检查执行引擎是否已初始化
  bool get isInitialized => _pool != null;

  /// 关闭执行引擎
  ///
  /// 释放所有 worker 资源，清理任务类型映射
  /// 关闭后引擎需要重新初始化才能使用
  Future<void> shutdown() async {
    if (_pool != null) {
      await _pool!.dispose();
      _pool = null;
      _taskTypeToFunctionName.clear();
    }
  }

  Map<String, dynamic> _serializeTask(CPUTask task) => task.serialize();

  static Future<dynamic> _executeTaskInIsolate(dynamic taskData) async {
    try {
      final data = taskData as Map<String, dynamic>;
      final taskType = data['taskType'] as String;

      final mapping = IsolateConstantManager.getConstant<Map<String, String>>(
        'taskTypeToFunctionName',
      );

      if (mapping == null) {
        throw StateError('taskTypeToFunctionName not found in constants');
      }

      final functionName = mapping[taskType];
      if (functionName == null) {
        throw StateError('No factory function for task type: $taskType');
      }

      final factory = FunctionRegistry.get(functionName);
      if (factory == null) {
        throw StateError('Factory function not found: $functionName');
      }

      final task = (factory as CPUTaskFactory)(data);
      return await task.execute();
    } catch (e) {
      rethrow;
    }
  }
}
