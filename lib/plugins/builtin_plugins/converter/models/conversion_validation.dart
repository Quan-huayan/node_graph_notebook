/// 转换验证结果
class ConversionValidation {
  /// 创建转换验证结果
  /// 
  /// [isValid] - 转换是否有效
  /// [warnings] - 警告信息列表
  /// [suggestions] - 建议信息列表
  const ConversionValidation({
    required this.isValid,
    required this.warnings,
    required this.suggestions,
  });

  /// 转换是否有效
  final bool isValid;
  /// 警告信息列表
  final List<String> warnings;
  /// 建议信息列表
  final List<String> suggestions;
}
