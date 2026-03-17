import 'cpu_task.dart';

/// 任务工厂函数签名
///
/// 从序列化的数据创建任务实例
/// 用于在 isolate 中反序列化任务
typedef CPUTaskFactory = CPUTask<dynamic> Function(Map<String, dynamic> data);

/// 结果转换器函数签名
///
/// 将 isolate 执行返回的原始结果转换为正确的类型
/// 允许插件自定义结果转换逻辑
typedef ResultConverter<T> = T Function(dynamic result);

/// 任务注册表
///
/// 集中管理所有可执行的任务类型
/// 插件在 onLoad() 时注册其提供的任务
///
/// ### 设计理念
///
/// 1. **插件可扩展性**：插件通过 `registerTaskType()` 动态注册任务类型
/// 2. **消除硬编码**：不再需要在 CPUTask.deserialize() 中使用 switch 语句
/// 3. **类型安全**：通过泛型 `ResultConverter<T>` 提供类型安全的结果转换
/// 4. **解耦架构**：ExecutionEngine 不依赖具体的任务实现
///
/// ### 使用示例
///
/// ```dart
/// // 在插件的 onLoad() 中注册任务类型
/// context.taskRegistry.registerTaskType(
///   'TextLayout',
///   (data) => _TextLayoutTaskSerialized(data),
///   (result) => TextLayoutResult(
///     width: result['width'] as double,
///     height: result['height'] as double,
///     didExceedMaxWidth: result['didExceedMaxWidth'] as bool? ?? false,
///     lineCount: const [],
///   ),
/// );
///
/// // ExecutionEngine 自动使用注册表反序列化和转换结果
/// final result = await engine.executeCPU(myTask);
/// ```
class TaskRegistry {
  /// 任务工厂函数映射
  ///
  /// 键为任务类型，值为工厂函数
  final Map<String, CPUTaskFactory> _factories = {};

  /// 结果转换器映射
  ///
  /// 键为任务类型，值为转换器函数
  final Map<String, ResultConverter> _converters = {};

  /// 注册任务类型
  ///
  /// ### 参数
  /// - `taskType` - 任务类型标识（必须唯一，如 "TextLayout", "NodeSizing"）
  /// - `factory` - 任务工厂函数，从序列化数据创建任务实例
  /// - `converter` - 结果转换器函数，将原始结果转换为正确类型
  ///
  /// ### 注意事项
  /// - 任务类型必须全局唯一，建议使用插件前缀（如 "ai.analyze"）
  /// - 如果任务类型已存在，将覆盖现有的注册
  /// - 工厂函数必须创建可序列化的任务实例
  ///
  /// ### 示例
  /// ```dart
  /// registerTaskType(
  ///   'MyTask',
  ///   (data) => MyTaskSerialized(data),
  ///   (result) => MyResult.fromMap(result),
  /// );
  /// ```
  void registerTaskType(
    String taskType,
    CPUTaskFactory factory,
    ResultConverter converter,
  ) {
    _factories[taskType] = factory;
    _converters[taskType] = converter;
  }

  /// 批量注册任务类型
  ///
  /// 用于一次性注册多个任务类型
  void registerAll(Map<String, CPUTaskFactory> factories, Map<String, ResultConverter> converters) {
    for (final entry in factories.entries) {
      _factories[entry.key] = entry.value;
    }
    for (final entry in converters.entries) {
      _converters[entry.key] = entry.value;
    }
  }

  /// 注销任务类型
  ///
  /// ### 参数
  /// - `taskType` - 任务类型标识
  ///
  /// 如果任务类型不存在，什么都不做
  void unregister(String taskType) {
    _factories.remove(taskType);
    _converters.remove(taskType);
  }

  /// 检查任务类型是否已注册
  bool isRegistered(String taskType) => _factories.containsKey(taskType);

  /// 获取所有已注册的任务类型
  List<String> get taskTypes => _factories.keys.toList();

  /// 获取指定任务类型的工厂函数
  ///
  /// 用于 ExecutionEngine 将工厂函数注册到 worker pool
  CPUTaskFactory? getFactory(String taskType) => _factories[taskType];

  /// 从数据反序列化任务
  ///
  /// ### 参数
  /// - `data` - 序列化的任务数据（必须包含 'taskType' 字段）
  ///
  /// ### 返回
  /// 任务实例
  ///
  /// ### 抛出
  /// - `UnsupportedError` 如果任务类型未注册
  CPUTask<dynamic> deserialize(Map<String, dynamic> data) {
    final taskType = data['taskType'] as String;
    final factory = _factories[taskType];

    if (factory == null) {
      throw UnsupportedError('Unknown task type: $taskType. '
          'Did you forget to register it in the plugin\'s onLoad()?');
    }

    return factory(data);
  }

  /// 根据任务类型转换结果
  ///
  /// ### 泛型参数
  /// - `T` - 期望的结果类型
  ///
  /// ### 参数
  /// - `taskType` - 任务类型标识
  /// - `result` - 原始结果（通常来自 isolate 执行）
  ///
  /// ### 返回
  /// 转换后的结果
  ///
  /// ### 抛出
  /// - `UnsupportedError` 如果任务类型未注册或没有转换器
  T convertResult<T>(String taskType, dynamic result) {
    final converter = _converters[taskType];

    if (converter == null) {
      throw UnsupportedError('No result converter for task type: $taskType. '
          'Did you forget to register a converter?');
    }

    return converter(result) as T;
  }

  /// 尝试转换结果（失败时返回默认值）
  ///
  /// ### 参数
  /// - `taskType` - 任务类型标识
  /// - `result` - 原始结果
  /// - `defaultValue` - 转换失败时的默认值
  ///
  /// ### 返回
  /// 转换后的结果或默认值
  T? tryConvertResult<T>(String taskType, dynamic result, {T? defaultValue}) {
    try {
      return convertResult<T>(taskType, result);
    } catch (_) {
      return defaultValue;
    }
  }

  /// 清除所有注册的任务类型
  void clear() {
    _factories.clear();
    _converters.clear();
  }

  /// 获取注册表统计信息
  ///
  /// 返回注册表的统计信息，用于调试
  Map<String, dynamic> get statistics => {
      'totalTaskTypes': _factories.length,
      'taskTypes': taskTypes,
      'tasksWithConverters': _converters.length,
    };

  /// 导出注册信息为 JSON
  ///
  /// 用于调试或序列化注册表状态
  Map<String, dynamic> exportToJson() => {
      'taskTypes': taskTypes,
      'statistics': statistics,
    };

  /// 根据插件 ID 获取任务类型
  ///
  /// 假设任务类型使用插件前缀（如 "ai.analyze", "graph.layout"）
  /// 返回属于特定插件的所有任务类型
  List<String> getTaskTypesByPlugin(String pluginId) => taskTypes
        .where((type) => type.startsWith('$pluginId.') || type.startsWith(pluginId))
        .toList();

  /// 移除插件的所有任务类型
  ///
  /// ### 参数
  /// - `pluginId` - 插件 ID
  ///
  /// 移除所有以 "{pluginId}." 开头的任务类型
  void removePluginTasks(String pluginId) {
    getTaskTypesByPlugin(pluginId).forEach(unregister);
  }
}
