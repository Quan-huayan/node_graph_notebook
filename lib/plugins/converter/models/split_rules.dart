/// 拆分策略
enum SplitStrategy {
  /// 按标题拆分
  heading,
  /// 按分隔符拆分
  separator,
  /// AI 智能拆分
  aiSmart,
  /// 自定义正则拆分
  customRegex
}

/// 标题拆分规则
class HeadingSplitRule {
  /// 创建标题拆分规则
  /// 
  /// [level] - 标题级别，1-6
  /// [minContentLength] - 最小内容长度，可选
  /// [keepOriginalHeading] - 是否保留原始标题，默认为 true
  const HeadingSplitRule({
    required this.level,
    this.minContentLength,
    this.keepOriginalHeading = true,
  });

  /// 标题级别
  final int level;
  /// 最小内容长度
  final int? minContentLength;
  /// 是否保留原始标题
  final bool keepOriginalHeading;
}

/// 分隔符拆分规则
class SeparatorSplitRule {
  /// 创建分隔符拆分规则
  /// 
  /// [pattern] - 分隔符模式
  /// [keepSeparator] - 是否保留分隔符，默认为 false
  /// [regexFlags] - 正则表达式标志，默认为 'gm'
  const SeparatorSplitRule({
    required this.pattern,
    this.keepSeparator = false,
    this.regexFlags = 'gm',
  });

  /// 分隔符模式
  final String pattern;
  /// 是否保留分隔符
  final bool keepSeparator;
  /// 正则表达式标志
  final String regexFlags;
}

/// AI 智能拆分规则
class AISmartSplitRule {
  /// 创建 AI 智能拆分规则
  /// 
  /// [minSectionLength] - 最小章节长度，默认为 200
  /// [semanticSimilarityThreshold] - 语义相似度阈值，默认为 0.7
  /// [maxSections] - 最大章节数，可选
  const AISmartSplitRule({
    this.minSectionLength = 200,
    this.semanticSimilarityThreshold = 0.7,
    this.maxSections,
  });

  /// 最小章节长度
  final int minSectionLength;
  /// 语义相似度阈值
  final double semanticSimilarityThreshold;
  /// 最大章节数
  final int? maxSections;
}

/// 自定义正则规则
class CustomRegexRule {
  /// 创建自定义正则规则
  /// 
  /// [pattern] - 正则表达式模式
  /// [flags] - 正则表达式标志，默认为 'gm'
  const CustomRegexRule({required this.pattern, this.flags = 'gm'});

  /// 正则表达式模式
  final String pattern;
  /// 正则表达式标志
  final String flags;
}
