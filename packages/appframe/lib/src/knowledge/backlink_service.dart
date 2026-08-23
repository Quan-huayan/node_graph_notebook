/// BacklinkService —— 反链读侧服务（A3：Obsidian Backlinks 语义，壳层）。
///
/// 打开节点时编辑器展示两段反链（node_editor 消费，经 DI 解析）：
///
/// 1. **图引用（linked）**：关系实例（connect 两端 / contain 父子 /
///    chat 的 ai·source）指向目标 → 呈现**对端节点**（关系实例本身不
///    上屏——它只是边，00 §2.2）。
/// 2. **内容提及（unlinked）**：普通内容节点（references 空）的 content
///    含目标标题（≥2 字，大小写不敏感）→ 用户尚未建立图引用、但已
///    口头提及——Obsidian unlinked mentions 同款。
///
/// 排除规则：纯 UI 代理节点（工具栏/画布/设置/搜索/标签/最近面板等
/// kind）不参与任何反链；目标自身恒排除；提及匹配短标题（<2 字）不
/// 匹配（防泛标题误报）。
///
/// 纯读侧、零写；10⁶ 优化 = 反查索引归 architecture.md [计划]。
library;

import 'package:core_data/core_data.dart';

/// 反链服务。
class BacklinkService {
  /// 注入结构存储。
  BacklinkService({required this.graph});

  /// 结构存储（读侧）。
  final Graph graph;

  /// 图引用反链：关系实例指向目标 → 对端节点（去重、按标题排序）。
  List<Node> linkedBacklinks(String nodeId) {
    final result = <String, Node>{};
    for (final relation in graph.getAll()) {
      if (relation.id == nodeId ||
          isUiProxy(relation) ||
          !relation.references.values.contains(nodeId)) {
        continue;
      }
      for (final endpoint in relation.references.values) {
        if (endpoint == nodeId) {
          continue;
        }
        final target = graph.get(endpoint);
        if (target != null && !isUiProxy(target)) {
          result[target.id] = target;
        }
      }
    }
    final list = result.values.toList()
      ..sort((a, b) => a.title.compareTo(b.title));
    return list;
  }

  /// 内容提及反链：普通内容节点 content 含目标标题（≥2 字）。
  List<Node> unlinkedMentions(String nodeId) {
    final title = graph.get(nodeId)?.title.trim() ?? '';
    if (title.length < 2) {
      return const <Node>[]; // 短标题不参与提及匹配（防泛标题误报）。
    }
    final needle = title.toLowerCase();
    final result = <String, Node>{};
    for (final node in graph.getAll()) {
      if (node.id == nodeId ||
          node.references.isNotEmpty ||
          isUiProxy(node)) {
        continue;
      }
      final content = node.content;
      if (content != null && content.toLowerCase().contains(needle)) {
        result[node.id] = node;
      }
    }
    final list = result.values.toList()
      ..sort((a, b) => a.title.compareTo(b.title));
    return list;
  }

  /// UI 代理判定：kind 属于纯 UI 节点（工具栏/画布/搜索/标签/最近/
  /// 设置及 settings-*/toolbar-*/ai-panel 前缀）——不参与知识反链。
  ///
  /// 公开（B2 快速切换/标签面板等共用同一判定——纯读侧工具）。
  static bool isUiProxy(Node node) {
    final kind = node.metadata['kind'] as String?;
    if (kind == null) {
      return false;
    }
    if (kind.startsWith('settings-') ||
        kind.startsWith('toolbar-') ||
        kind.startsWith('ai-panel') ||
        kind.startsWith('recent-')) {
      return true;
    }
    return const <String>{
      'toolbar-root',
      'toolbar',
      'canvas',
      'search-panel',
      'tags-panel',
      'recent-panel',
      'settings-root',
    }.contains(kind);
  }
}