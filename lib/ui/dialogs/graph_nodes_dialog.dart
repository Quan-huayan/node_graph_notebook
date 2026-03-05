import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/services/theme_service.dart';
import '../../core/services/settings_service.dart';
import '../blocs/blocs.dart';

/// 图节点管理对话框
/// 允许用户选择哪些节点显示在节点图中
class GraphNodesDialog extends StatefulWidget {
  const GraphNodesDialog({
    super.key,
    required this.graphBloc,
    required this.nodeBloc,
  });

  final GraphBloc graphBloc;
  final NodeBloc nodeBloc;

  @override
  State<GraphNodesDialog> createState() => _GraphNodesDialogState();
}

class _GraphNodesDialogState extends State<GraphNodesDialog> {
  late Set<String> _selectedNodeIds;

  @override
  void initState() {
    super.initState();
    // 初始化选中的节点ID - 当前图中所有节点的ID
    final state = widget.graphBloc.state;
    _selectedNodeIds = state.nodes
        .map((n) => n.id)
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final settings = context.watch<SettingsService>();
    final theme = themeService.getThemeForMode(
      settings.themeMode,
      MediaQuery.of(context).platformBrightness,
    );

    // 过滤掉文件夹节点 - 文件夹不应该显示在节点图中
    final availableNodes = widget.nodeBloc.state.nodes
        .where((n) => !n.isFolder)
        .toList();

    return AlertDialog(
      backgroundColor: theme.backgrounds.primary,
      title: const Row(
        children: [
          Icon(Icons.graphic_eq),
          SizedBox(width: 8),
          Text('Manage Graph Nodes'),
        ],
      ),
      content: SizedBox(
        width: 500,
        height: 500,
        child: Column(
          children: [
            // 统计信息
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.backgrounds.secondary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        '${_selectedNodeIds.length}',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: theme.nodes.nodePrimary,
                        ),
                      ),
                      Text(
                        'Selected',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        '${availableNodes.length}',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: theme.text.secondary,
                        ),
                      ),
                      Text(
                        'Available',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 搜索框
            TextField(
              decoration: InputDecoration(
                hintText: 'Search nodes...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) {
                setState(() {});
              },
            ),
            const SizedBox(height: 16),

            // 节点列表
            Expanded(
              child: ListView.builder(
                itemCount: availableNodes.length,
                itemBuilder: (context, index) {
                  final node = availableNodes[index];
                  final isSelected = _selectedNodeIds.contains(node.id);

                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedNodeIds.add(node.id);
                        } else {
                          _selectedNodeIds.remove(node.id);
                        }
                      });
                    },
                    title: Text(node.title),
                    subtitle: Text(
                      node.isConcept ? 'Concept' : 'Content',
                      style: TextStyle(
                        color: theme.text.secondary,
                        fontSize: 12,
                      ),
                    ),
                    secondary: Icon(
                      Icons.note,
                      color: theme.nodes.nodePrimary,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _applyChanges,
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Future<void> _applyChanges() async {
    final state = widget.graphBloc.state;

    final currentIds = state.nodes.map((n) => n.id).toSet();

    // 找出需要添加的节点
    final toAdd = _selectedNodeIds.difference(currentIds);
    // 找出需要移除的节点
    final toRemove = currentIds.difference(_selectedNodeIds);

    try {
      // 移除节点
      for (final nodeId in toRemove) {
        widget.graphBloc.add(NodeDeleteEvent(nodeId));
      }

      // 添加节点
      for (final nodeId in toAdd) {
        widget.graphBloc.add(NodeAddEvent(nodeId));
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added ${toAdd.length} node(s), removed ${toRemove.length} node(s)',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update graph: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
