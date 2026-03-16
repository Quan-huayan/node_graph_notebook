/// 合并规则，定义如何将多个节点合并为单个 Markdown 文档
class MergeRule {
  /// 创建合并规则
  /// 
  /// [strategy] - 合并策略
  /// [hierarchyRule] - 层级合并规则，当 strategy 为 hierarchy 时使用
  /// [sequenceRule] - 顺序合并规则，当 strategy 为 sequence 时使用
  /// [customRule] - 自定义合并规则，当 strategy 为 custom 时使用
  const MergeRule({
    required this.strategy,
    this.hierarchyRule,
    this.sequenceRule,
    this.customRule,
  });

  /// 合并策略
  final MergeStrategy strategy;
  /// 层级合并规则
  final HierarchyMergeRule? hierarchyRule;
  /// 顺序合并规则
  final SequenceMergeRule? sequenceRule;
  /// 自定义合并规则
  final CustomMergeRule? customRule;
}

/// 合并策略
enum MergeStrategy {
  /// 按层级合并
  hierarchy,
  /// 按顺序合并
  sequence,
  /// 自定义合并
  custom
}

/// 层级合并规则
class HierarchyMergeRule {
  /// 创建层级合并规则
  /// 
  /// [rootNodeId] - 根节点 ID，默认为空字符串
  /// [addToc] - 是否添加目录，默认为 true
  /// [headingLevels] - 是否使用标题层级，默认为 true
  /// [separator] - 节点之间的分隔符，默认为 '\n\n---\n\n'
  const HierarchyMergeRule({
    this.rootNodeId = '',
    this.addToc = true,
    this.headingLevels = true,
    this.separator = '\n\n---\n\n',
  });

  /// 根节点 ID
  final String rootNodeId;
  /// 是否添加目录
  final bool addToc;
  /// 是否使用标题层级
  final bool headingLevels;
  /// 节点之间的分隔符
  final String separator;
}

/// 顺序合并规则
class SequenceMergeRule {
  /// 创建顺序合并规则
  /// 
  /// [sortBy] - 排序方式，默认为 SortBy.createdAt
  /// [separator] - 节点之间的分隔符，默认为 '\n\n---\n\n'
  /// [addMetadata] - 是否添加元数据，默认为 false
  const SequenceMergeRule({
    this.sortBy = SortBy.createdAt,
    this.separator = '\n\n---\n\n',
    this.addMetadata = false,
  });

  /// 排序方式
  final SortBy sortBy;
  /// 节点之间的分隔符
  final String separator;
  /// 是否添加元数据
  final bool addMetadata;
}

/// 自定义合并规则
class CustomMergeRule {
  /// 创建自定义合并规则
  /// 
  /// [template] - 自定义模板
  const CustomMergeRule({required this.template});

  /// 自定义模板
  final String template;
}

/// 排序方式
enum SortBy {
  /// 按创建时间排序
  createdAt,
  /// 按更新时间排序
  updatedAt,
  /// 按标题排序
  title
}
