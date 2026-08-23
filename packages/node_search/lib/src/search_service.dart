/// SearchService —— 节点搜索（M7，01 拍板 #36）。
///
/// 标题/内容包含匹配（大小写不敏感）；可加 kind 过滤（metadata.kind）。
/// 纯读侧——不写存储、不触发命令（02 §1.5：读优化归实现层）。
library;

import 'package:appframe/appframe.dart';
import 'package:core_data/core_data.dart';

/// 搜索查询。
class SearchQuery {
  /// 构造查询。
  const SearchQuery({required this.text, this.kind, this.tag, this.folderId});

  /// 搜索文本（空 = 全部）。
  final String text;

  /// kind 过滤（metadata.kind 精确匹配；null = 不过滤）。
  final String? kind;

  /// 标签过滤（A2：内容 `#tag` 解析 ∪ metadata.tags；null = 不过滤）。
  final String? tag;

  /// 文件夹过滤（C3：contain.parent == folderId 的成员；null = 不过滤）。
  final String? folderId;
}

/// 搜索服务（10⁶ 优化项：物化搜索索引——M7 数据量小全量扫描）。
class SearchService {
  /// 注入结构存储。
  SearchService({required this.graph});

  /// 结构存储。
  final Graph graph;

  /// 执行搜索（标签过滤 + 标题匹配优先排序，次按内容匹配）。
  List<Node> search(SearchQuery query) {
    final needle = query.text.trim().toLowerCase();
    final tag = query.tag;
    // 标签过滤（TagService 同源规则：内容 `#tag` 解析 ∪ metadata.tags）。
    final tagHits = tag == null
        ? null
        : TagService(graph: graph).nodesForTag(tag).map((n) => n.id).toSet();
    // 文件夹过滤（C3：contain.parent == folderId 的成员——读侧反查）。
    final folderId = query.folderId;
    final folderHits = folderId == null
        ? null
        : graph
            .getAll()
            .where((n) => n.references['parent'] == folderId)
            .map((n) => n.references['child']!)
            .toSet();
    final results = <Node>[];
    for (final node in graph.getAll()) {
      final kind = query.kind;
      if (kind != null && node.metadata['kind'] != kind) {
        continue;
      }
      if (tagHits != null && !tagHits.contains(node.id)) {
        continue;
      }
      if (folderHits != null && !folderHits.contains(node.id)) {
        continue;
      }
      final title = node.title.toLowerCase();
      final content = (node.content ?? '').toLowerCase();
      final titleHit = needle.isEmpty || title.contains(needle);
      final contentHit = needle.isNotEmpty && content.contains(needle);
      if (titleHit || contentHit) {
        results.add(node);
      }
    }
    // 标题命中优先（相关性启发式）。
    results.sort((a, b) {
      final aTitle = a.title.toLowerCase().contains(needle) ? 0 : 1;
      final bTitle = b.title.toLowerCase().contains(needle) ? 0 : 1;
      return aTitle.compareTo(bTitle);
    });
    return results;
  }
}
