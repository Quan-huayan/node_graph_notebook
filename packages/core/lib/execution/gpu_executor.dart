/// GPU 执行器接口（预留）
///
/// 为未来 GPU 加速功能预留的接口
/// 可用于 Compute Shader、Metal、Vulkan 等 GPU 计算任务
abstract class GPUExecutor {
  /// 检查 GPU 执行器是否可用
  bool get isAvailable;

  /// 执行 GPU 任务
  ///
  /// [task] 要执行的 GPU 任务
  /// 返回任务执行结果
  Future<T> execute<T>(GPUTask<T> task);
}

/// GPU 任务接口（预留）
///
/// 定义可在 GPU 上执行的计算任务
/// 适用于大规模并行计算（如矩阵运算、物理模拟等）
abstract class GPUTask<T> {
  /// 任务名称（用于调试和监控）
  String get name;

  /// 执行任务逻辑
  ///
  /// 此方法将在 GPU 上运行
  /// 注意：GPU 任务有特定的限制和要求
  Future<T> execute(GPUExecutor executor);
}
