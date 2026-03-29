import '../../models/node.dart';
import '../../repositories/node_repository.dart';
import '../queries/advanced_search_query.dart';
import '../query/query.dart';

/// 高级搜索查询处理器
///
/// 处理复杂的多条件搜索查询，支持：
/// - 通用搜索文本（同时搜索标题和内容）
/// - 单独的标题查询
/// - 单独的内容查询
/// - 标签过滤（AND 逻辑）
/// - 文件夹过滤
/// - 创建时间范围过滤
class AdvancedSearchQueryHandler extends QueryHandler<List<Node>, AdvancedSearchQuery> {
  /// 创建高级搜索查询处理器
  ///
  /// [nodeRepository] 节点仓储，用于访问节点数据
  AdvancedSearchQueryHandler(this._nodeRepository);

  final NodeRepository _nodeRepository;

  @override
  Future<QueryResult<List<Node>>> handle(AdvancedSearchQuery query) async {
    try {
      // 获取所有节点
      final allNodes = await _nodeRepository.queryAll();

      // 应用过滤条件
      final results = allNodes.where((node) {
        // 标题过滤
        if (query.titleQuery != null && query.titleQuery!.isNotEmpty) {
          if (!node.title.toLowerCase().contains(
            query.titleQuery!.toLowerCase(),
          )) {
            return false;
          }
        }

        // 内容过滤
        if (query.contentQuery != null && query.contentQuery!.isNotEmpty) {
          final content = node.content ?? '';
          if (!content.toLowerCase().contains(
            query.contentQuery!.toLowerCase(),
          )) {
            return false;
          }
        }

        // 通用搜索文本过滤
        if (query.searchText != null && query.searchText!.isNotEmpty) {
          final searchLower = query.searchText!.toLowerCase();
          final titleMatch = node.title.toLowerCase().contains(searchLower);
          final contentMatch = (node.content ?? '').toLowerCase().contains(
            searchLower,
          );
          if (!titleMatch && !contentMatch) {
            return false;
          }
        }

        // 标签过滤（AND 逻辑：必须包含所有指定标签）
        if (query.tags != null && query.tags!.isNotEmpty) {
          final nodeTags = _extractTags(node);
          final hasAllTags = query.tags!.every(nodeTags.contains);
          if (!hasAllTags) {
            return false;
          }
        }

        // 文件夹过滤
        if (query.isFolder != null) {
          if (node.isFolder != query.isFolder) {
            return false;
          }
        }

        // 创建时间范围过滤
        if (query.createdAfter != null) {
          if (node.createdAt.isBefore(query.createdAfter!)) {
            return false;
          }
        }
        if (query.createdBefore != null) {
          if (node.createdAt.isAfter(query.createdBefore!)) {
            return false;
          }
        }

        return true;
      }).toList();

      // 应用限制
      final limitedResults = results.take(query.limit).toList();

      return QueryResult.success(limitedResults);
    } catch (error, stackTrace) {
      return QueryResult.failure(
        'Failed to perform advanced search: ${error.toString()}',
        stackTrace,
      );
    }
  }

  /// 从节点元数据中提取标签列表
  ///
  /// 标签存储在节点的 metadata['tags'] 字段中
  /// 返回空列表如果节点没有标签
  List<String> _extractTags(Node node) {
    final tags = node.metadata['tags'] as List<dynamic>?;
    return tags?.cast<String>() ?? [];
  }
}
