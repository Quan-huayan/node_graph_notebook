import 'package:flutter/material.dart';
import '../../../../core/models/models.dart';
import '../../../../ui/utilwidgets/highlight_text.dart';

/// 搜索结果节点项组件
class SearchedNodeItem extends StatelessWidget {
  /// 创建搜索结果节点项组件
  /// 
  /// [node] - 节点数据
  /// [query] - 搜索查询字符串，用于高亮显示
  /// [onTap] - 点击事件回调
  const SearchedNodeItem({
    super.key,
    required this.node,
    this.query,
    required this.onTap,
  });

  /// 节点数据
  final Node node;
  
  /// 搜索查询字符串，用于高亮显示
  final String? query;
  
  /// 点击事件回调
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // === 架构说明：自定义图标显示 ===
    // 设计意图：优先显示自定义图标（metadata['icon']），否则显示默认图标
    // 优先级：自定义图标 > 文件夹图标 > 默认文档图标
    Widget leading;
    if (node.metadata.containsKey('icon') &&
        node.metadata['icon'] != null &&
        node.metadata['icon'].toString().isNotEmpty) {
      // 显示自定义 emoji 图标
      leading = Text(
        node.metadata['icon'].toString(),
        style: const TextStyle(fontSize: 24),
      );
    } else {
      // 显示默认图标
      leading = Icon(node.isFolder ? Icons.folder : Icons.description);
    }

    return ListTile(
      leading: leading,
      title: HighlightText(text: node.title, query: query),
      subtitle: node.content != null && node.content!.isNotEmpty
          ? HighlightText(
              text: node.content!.length > 100
                  ? '${node.content!.substring(0, 100)}...'
                  : node.content!,
              query: query,
              maxLines: 2,
            )
          : null,
      onTap: onTap,
    );
  }
}
