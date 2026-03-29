import '../../models/node.dart';
import '../query/query.dart';

/// 高级搜索查询
///
/// 支持复杂的多条件搜索，包括：
/// - 通用搜索文本（同时搜索标题和内容）
/// - 单独的标题查询
/// - 单独的内容查询
/// - 标签过滤
/// - 文件夹过滤
/// - 创建时间范围过滤
class AdvancedSearchQuery extends CacheableQuery<List<Node>> {
  /// 创建高级搜索查询
  ///
  /// 所有参数都是可选的，至少提供一个搜索条件才能获得有意义的结果
  const AdvancedSearchQuery({
    this.searchText,
    this.titleQuery,
    this.contentQuery,
    this.tags,
    this.isFolder,
    this.createdAfter,
    this.createdBefore,
    this.limit = 100,
  });

  /// 通用搜索文本
  ///
  /// 如果提供，将同时在标题和内容中搜索
  final String? searchText;

  /// 标题查询
  ///
  /// 如果提供，只在标题中搜索
  final String? titleQuery;

  /// 内容查询
  ///
  /// 如果提供，只在内容中搜索
  final String? contentQuery;

  /// 标签过滤
  ///
  /// 如果提供，节点必须包含所有指定的标签
  final List<String>? tags;

  /// 文件夹过滤
  ///
  /// 如果提供，只返回匹配条件的节点（true=只返回文件夹，false=只返回非文件夹）
  final bool? isFolder;

  /// 创建时间范围起始
  ///
  /// 如果提供，只返回在此时间之后创建的节点
  final DateTime? createdAfter;

  /// 创建时间范围结束
  ///
  /// 如果提供，只返回在此时间之前创建的节点
  final DateTime? createdBefore;

  /// 返回结果最大数量
  ///
  /// 默认为 100，用于限制返回结果数量以提高性能
  final int limit;

  @override
  String get cacheKey => 'AdvancedSearch:'
      '${searchText ?? ""}:'
      '${titleQuery ?? ""}:'
      '${contentQuery ?? ""}:'
      '${tags?.join(',') ?? ""}:'
      '${isFolder ?? ""}:'
      '${createdAfter?.millisecondsSinceEpoch ?? ""}:'
      '${createdBefore?.millisecondsSinceEpoch ?? ""}:'
      '$limit';

  @override
  Duration? get cacheTtl => const Duration(minutes: 5);
}
