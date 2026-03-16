import 'split_rules.dart';

/// 转换规则，定义如何将 Markdown 转换为节点
class ConversionRule {
  /// 创建转换规则
  /// 
  /// [splitStrategy] - 拆分策略
  /// [headingRule] - 标题拆分规则，当 splitStrategy 为 heading 时使用
  /// [separatorRule] - 分隔符拆分规则，当 splitStrategy 为 separator 时使用
  /// [aiRule] - AI 智能拆分规则，当 splitStrategy 为 aiSmart 时使用
  /// [customRule] - 自定义正则拆分规则，当 splitStrategy 为 customRegex 时使用
  /// [extractConnections] - 是否提取连接关系，默认为 true
  /// [extractTags] - 是否提取标签，默认为 true
  /// [parseFrontmatter] - 是否解析 Frontmatter，默认为 true
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

  /// 拆分策略
  final SplitStrategy splitStrategy;
  /// 标题拆分规则
  final HeadingSplitRule? headingRule;
  /// 分隔符拆分规则
  final SeparatorSplitRule? separatorRule;
  /// AI 智能拆分规则
  final AISmartSplitRule? aiRule;
  /// 自定义正则拆分规则
  final CustomRegexRule? customRule;
  /// 是否提取连接关系
  final bool extractConnections;
  /// 是否提取标签
  final bool extractTags;
  /// 是否解析 Frontmatter
  final bool parseFrontmatter;

  /// 创建修改后的转换规则
  /// 
  /// 返回一个新的 ConversionRule 实例，包含指定的修改
  ConversionRule copyWith({
    SplitStrategy? splitStrategy,
    HeadingSplitRule? headingRule,
    SeparatorSplitRule? separatorRule,
    AISmartSplitRule? aiRule,
    CustomRegexRule? customRule,
    bool? extractConnections,
    bool? extractTags,
    bool? parseFrontmatter,
  }) => ConversionRule(
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
