/// 转换结果
class ConversionResult {
  /// 创建转换结果
  /// 
  /// [successCount] - 成功转换的数量
  /// [failureCount] - 失败转换的数量
  /// [errors] - 错误信息列表
  /// [duration] - 转换持续时间
  /// [createdNodeIds] - 创建的节点 ID 列表
  const ConversionResult({
    required this.successCount,
    required this.failureCount,
    required this.errors,
    required this.duration,
    required this.createdNodeIds,
  });

  /// 成功转换的数量
  final int successCount;
  /// 失败转换的数量
  final int failureCount;
  /// 错误信息列表
  final List<String> errors;
  /// 转换持续时间
  final Duration duration;
  /// 创建的节点 ID 列表
  final List<String> createdNodeIds;
}
