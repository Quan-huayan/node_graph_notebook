import 'task_registry.dart';

/// CPU 密集型任务接口
///
/// 定义可由 ExecutionEngine 在后台 isolates 中执行的任务
/// 任务必须是自包含的，不能依赖外部可变状态
abstract class CPUTask<T> {
  /// 任务名称（用于调试和监控）
  String get name;

  /// 任务类型标识（用于 isolate 中的任务分发）
  String get taskType;

  /// 执行任务逻辑
  ///
  /// 此方法将在后台 isolate 中运行，不能访问 UI 线程的资源
  /// 必须是纯函数，相同的输入应产生相同的输出
  Future<T> execute();

  /// 序列化任务数据为可传输的 Map
  ///
  /// 此方法将任务的所有必要参数序列化为 Map，以便通过 isolate 传递
  /// 子类必须实现此方法以提取执行任务所需的所有数据
  Map<String, dynamic> serialize();

  /// 从序列化的 Map 创建任务对象
  ///
  /// 此静态方法用于在 isolate 中反序列化任务数据
  /// 使用 TaskRegistry 进行动态任务类型注册和创建
  ///
  /// [registry] 任务注册表，包含所有已注册的任务类型
  /// [data] 序列化的任务数据（必须包含 'taskType' 字段）
  ///
  /// 返回任务实例
  ///
  /// 抛出 UnsupportedError 如果任务类型未注册
  static CPUTask<dynamic> deserialize(
    Map<String, dynamic> data,
    TaskRegistry registry,
  ) => registry.deserialize(data);
}

/// 任务优先级
///
/// 用于控制任务执行顺序（未来扩展）
enum TaskPriority {
  /// 高优先级任务（如用户交互响应）
  high,

  /// 普通优先级任务（如后台计算）
  normal,

  /// 低优先级任务（如预处理）
  low,
}

/// CPU 任务执行结果
///
/// 包装任务执行结果，包含执行元数据
class CPUTaskResult<T> {
  /// 构造函数
  const CPUTaskResult({
    required this.data, // 任务返回的数据
    this.executionTime, // 执行耗时（毫秒）
  });

  /// 任务返回的数据
  final T data;

  /// 执行耗时（毫秒）
  final int? executionTime;
}