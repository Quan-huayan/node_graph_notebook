/// 拆分策略
enum SplitStrategy {
  heading,
  separator,
  aiSmart,
  customRegex,
}


/// 标题拆分规则
class HeadingSplitRule {
  const HeadingSplitRule({
    required this.level,
    this.minContentLength,
    this.keepOriginalHeading = true,
  });

  final int level;
  final int? minContentLength;
  final bool keepOriginalHeading;
}

/// 分隔符拆分规则
class SeparatorSplitRule {
  const SeparatorSplitRule({
    required this.pattern,
    this.keepSeparator = false,
    this.regexFlags = 'gm',
  });

  final String pattern;
  final bool keepSeparator;
  final String regexFlags;
}

/// AI 智能拆分规则
class AISmartSplitRule {
  const AISmartSplitRule({
    this.minSectionLength = 200,
    this.semanticSimilarityThreshold = 0.7,
    this.maxSections,
  });

  final int minSectionLength;
  final double semanticSimilarityThreshold;
  final int? maxSections;
}

/// 自定义正则规则
class CustomRegexRule {
  const CustomRegexRule({
    required this.pattern,
    this.flags = 'gm',
  });

  final String pattern;
  final String flags;
}