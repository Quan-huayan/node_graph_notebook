import 'package:flutter/material.dart';
import '../../core/models/models.dart';

/// 节点选择器 widget
class NodeSelectorWidget extends StatefulWidget {
  const NodeSelectorWidget({
    super.key,
    required this.nodes,
    required this.selectedIndices,
    required this.onSelectionChanged,
    this.searchHint = 'Search nodes...',
  });

  final List<Node> nodes;
  final Set<int> selectedIndices;
  final ValueChanged<Set<int>> onSelectionChanged;
  final String searchHint;

  @override
  State<NodeSelectorWidget> createState() => _NodeSelectorWidgetState();
}

class _NodeSelectorWidgetState extends State<NodeSelectorWidget> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Node> get _filteredNodes {
    if (_searchQuery.isEmpty) {
      return widget.nodes;
    }

    final query = _searchQuery.toLowerCase();
    return widget.nodes.where((node) {
      return node.title.toLowerCase().contains(query) ||
          (node.content?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  void _toggleAll(bool selected) {
    final newSelection = <int>{};
    if (selected) {
      for (var i = 0; i < widget.nodes.length; i++) {
        newSelection.add(i);
      }
    }
    widget.onSelectionChanged(newSelection);
  }

  void _toggleIndex(int index) {
    final newSelection = Set<int>.from(widget.selectedIndices);
    if (newSelection.contains(index)) {
      newSelection.remove(index);
    } else {
      newSelection.add(index);
    }
    widget.onSelectionChanged(newSelection);
  }

  @override
  Widget build(BuildContext context) {
    final filteredNodes = _filteredNodes;
    final allSelected = widget.selectedIndices.length == widget.nodes.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            // 搜索框
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search',
                  hintText: widget.searchHint,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),

            // 操作按钮
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Checkbox(
                    value: allSelected,
                    tristate: true,
                    onChanged: (value) {
                      _toggleAll(value ?? false);
                    },
                  ),
                  TextButton(
                    onPressed: () => _toggleAll(true),
                    child: const Text('Select All'),
                  ),
                  TextButton(
                    onPressed: () => widget.onSelectionChanged({}),
                    child: const Text('Clear'),
                  ),
                  const Spacer(),
                  Text(
                    '${widget.selectedIndices.length} selected',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // 节点列表 - 始终返回相同类型的 widget
            Expanded(
              child: filteredNodes.isEmpty
                  ? const Center(child: Text('No nodes found'))
                  : ListView.builder(
                      key: ValueKey('nodes-${filteredNodes.length}'),
                      itemCount: filteredNodes.length,
                      itemExtent: 60, // 固定每个 item 的高度，避免重新计算
                      itemBuilder: (context, index) {
                        final node = filteredNodes[index];
                        final originalIndex = widget.nodes.indexOf(node);
                        final isSelected = widget.selectedIndices.contains(originalIndex);

                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (_) => _toggleIndex(originalIndex),
                          title: Text(
                            node.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: node.content != null && node.content!.isNotEmpty
                              ? Text(
                                  node.content!.length > 50
                                      ? '${node.content!.substring(0, 50)}...'
                                      : node.content!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          dense: true,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
