/// 合并规则
class MergeRule {
  const MergeRule({
    required this.strategy,
    this.hierarchyRule,
    this.sequenceRule,
    this.customRule,
  });

  final MergeStrategy strategy;
  final HierarchyMergeRule? hierarchyRule;
  final SequenceMergeRule? sequenceRule;
  final CustomMergeRule? customRule;
}


/// 合并策略
enum MergeStrategy {
  hierarchy,
  sequence,
  custom,
}

/// 层级合并规则
class HierarchyMergeRule {
  const HierarchyMergeRule({
    this.rootNodeId = '',
    this.addToc = true,
    this.headingLevels = true,
    this.separator = '\n\n---\n\n',
  });

  final String rootNodeId;
  final bool addToc;
  final bool headingLevels;
  final String separator;
}

/// 顺序合并规则
class SequenceMergeRule {
  const SequenceMergeRule({
    this.sortBy = SortBy.createdAt,
    this.separator = '\n\n---\n\n',
    this.addMetadata = false,
  });

  final SortBy sortBy;
  final String separator;
  final bool addMetadata;
}

/// 自定义合并规则
class CustomMergeRule {
  const CustomMergeRule({
    required this.template,
  });

  final String template;
}

/// 排序方式
enum SortBy {
  createdAt,
  updatedAt,
  title,
}







