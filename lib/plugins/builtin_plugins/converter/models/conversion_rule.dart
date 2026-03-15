import 'split_rules.dart';

/// 转换规则
class ConversionRule {
  const ConversionRule({
    required this.splitStrategy,
    this.headingRule,
    this.separatorRule,
    this.aiRule,
    this.customRule,
    this.extractConnections = true,
    this.extractTags = true,
    this.parseFrontmatter = true,
  });

  final SplitStrategy splitStrategy;
  final HeadingSplitRule? headingRule;
  final SeparatorSplitRule? separatorRule;
  final AISmartSplitRule? aiRule;
  final CustomRegexRule? customRule;
  final bool extractConnections;
  final bool extractTags;
  final bool parseFrontmatter;

  ConversionRule copyWith({
    SplitStrategy? splitStrategy,
    HeadingSplitRule? headingRule,
    SeparatorSplitRule? separatorRule,
    AISmartSplitRule? aiRule,
    CustomRegexRule? customRule,
    bool? extractConnections,
    bool? extractTags,
    bool? parseFrontmatter,
  }) {
    return ConversionRule(
      splitStrategy: splitStrategy ?? this.splitStrategy,
      headingRule: headingRule ?? this.headingRule,
      separatorRule: separatorRule ?? this.separatorRule,
      aiRule: aiRule ?? this.aiRule,
      customRule: customRule ?? this.customRule,
      extractConnections: extractConnections ?? this.extractConnections,
      extractTags: extractTags ?? this.extractTags,
      parseFrontmatter: parseFrontmatter ?? this.parseFrontmatter,
    );
  }
}