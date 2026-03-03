import 'conversion_rule.dart';

/// 转换配置
class ConversionConfig {
  const ConversionConfig({
    required this.rule,
    this.createConceptNodes = false,
    this.preserveOriginalFiles = true,
  });

  final ConversionRule rule;
  final bool createConceptNodes;
  final bool preserveOriginalFiles;
}