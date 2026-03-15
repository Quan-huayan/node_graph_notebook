/// 转换验证
class ConversionValidation {
  const ConversionValidation({
    required this.isValid,
    required this.warnings,
    required this.suggestions,
  });

  final bool isValid;
  final List<String> warnings;
  final List<String> suggestions;
}