import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import '../utilwidgets/highlight_text.dart';

/// 搜索结果节点项组件
class SearchedNodeItem extends StatelessWidget {
  const SearchedNodeItem({
    super.key,
    required this.node,
    this.query,
    required this.onTap,
  });

  final Node node;
  final String? query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(node.isFolder ? Icons.folder : Icons.description),
      title: HighlightText(
        text: node.title,
        query: query,
      ),
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