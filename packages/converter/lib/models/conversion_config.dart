import 'conversion_rule.dart';

/// 转换配置
class ConversionConfig {
  /// 创建转换配置
  /// 
  /// [rule] - 转换规则
  /// [preserveOriginalFiles] - 是否保留原始文件，默认为 true
  const ConversionConfig({
    required this.rule,
    this.preserveOriginalFiles = true,
  });

  /// 转换规则
  final ConversionRule rule;
  /// 是否保留原始文件
  final bool preserveOriginalFiles;
}
