/// 转换结果
class ConversionResult {
  const ConversionResult({
    required this.successCount,
    required this.failureCount,
    required this.errors,
    required this.duration,
    required this.createdNodeIds,
  });

  final int successCount;
  final int failureCount;
  final List<String> errors;
  final Duration duration;
  final List<String> createdNodeIds;
}