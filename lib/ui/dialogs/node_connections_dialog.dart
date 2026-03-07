import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/models/models.dart';
import '../../core/services/theme_service.dart';
import '../../bloc/blocs.dart';
import '../dialogs/connection_dialog.dart';

/// 获取引用类型标签
String getReferenceTypeLabel(ReferenceType type) {
  switch (type) {
    case ReferenceType.mentions:
      return 'Mentions';
    case ReferenceType.contains:
      return 'Contains';
    case ReferenceType.dependsOn:
      return 'Depends On';
    case ReferenceType.causes:
      return 'Causes';
    case ReferenceType.partOf:
      return 'Part Of';
    case ReferenceType.relatesTo:
      return 'Related';
    case ReferenceType.references:
      return 'References';
    case ReferenceType.instanceOf:
      return 'Instance Of';
  }
}

/// 节点连接管理对话框
/// 显示和管理节点的所有连接关系
class NodeConnectionsDialog extends StatefulWidget {
  const NodeConnectionsDialog({
    super.key,
    required this.node,
  });

  final Node node;

  @override
  State<NodeConnectionsDialog> createState() => _NodeConnectionsDialogState();
}

class _NodeConnectionsDialogState extends State<NodeConnectionsDialog> {
  @override
  Widget build(BuildContext context) {
    final theme = context.read<ThemeService>().themeData;

    return BlocBuilder<NodeBloc, NodeState>(
      builder: (context, nodeState) {
        // 获取所有连接的节点
        final connectedNodes = widget.node.references.entries.map((entry) {
          final targetNode = nodeState.nodes.firstWhere(
            (n) => n.id == entry.key,
            orElse: () => widget.node,
          );
          return {
            'node': targetNode,
            'reference': entry.value,
          };
        }).toList();

        return AlertDialog(
          backgroundColor: theme.backgrounds.primary,
          title: Text('Connections: ${widget.node.title}'),
          content: SizedBox(
            width: 500,
            height: 400,
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
                      _buildStat(
                        context,
                        label: 'Total',
                        value: connectedNodes.length.toString(),
                        icon: Icons.link,
                      ),
                      _buildStat(
                        context,
                        label: 'Outgoing',
                        value: widget.node.references.length.toString(),
                        icon: Icons.arrow_forward,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 连接列表
                Expanded(
                  child: connectedNodes.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.link_off, size: 48, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'No connections yet',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: connectedNodes.length,
                          itemBuilder: (context, index) {
                            final item = connectedNodes[index];
                            final targetNode = item['node'] as Node;
                            final reference = item['reference'] as NodeReference;

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _getColorForReference(
                                    reference.type,
                                    context,
                                  ),
                                  child: Icon(
                                    _getIconForReference(reference.type),
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                                title: Text(targetNode.title),
                                subtitle: Text(
                                  getReferenceTypeLabel(reference.type),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (reference.role != null)
                                      Chip(
                                        label: Text(reference.role!),
                                        padding: EdgeInsets.zero,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    IconButton(
                                      icon: const Icon(Icons.link_off),
                                      onPressed: () =>
                                          _disconnect(targetNode.id),
                                      tooltip: 'Disconnect',
                                    ),
                                  ],
                                ),
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
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              onPressed: () => _addConnection(context, nodeState.nodes),
              icon: const Icon(Icons.add_link),
              label: const Text('Add Connection'),
            ),
          ],
        );
      },
    );
  }

  /// 构建统计项
  Widget _buildStat(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  /// 根据引用类型获取颜色
  Color _getColorForReference(ReferenceType type, BuildContext context) {
    switch (type) {
      case ReferenceType.mentions:
        return Colors.blue;
      case ReferenceType.contains:
        return Colors.purple;
      case ReferenceType.dependsOn:
        return Colors.orange;
      case ReferenceType.causes:
        return Colors.red;
      case ReferenceType.partOf:
        return Colors.teal;
      case ReferenceType.relatesTo:
        return Colors.grey;
      case ReferenceType.references:
        return Colors.indigo;
      case ReferenceType.instanceOf:
        return Colors.cyan;
    }
  }

  /// 根据引用类型获取图标
  IconData _getIconForReference(ReferenceType type) {
    switch (type) {
      case ReferenceType.mentions:
        return Icons.chat_bubble;
      case ReferenceType.contains:
        return Icons.folder;
      case ReferenceType.dependsOn:
        return Icons.arrow_downward;
      case ReferenceType.causes:
        return Icons.arrow_upward;
      case ReferenceType.partOf:
        return Icons.view_module;
      case ReferenceType.relatesTo:
        return Icons.link;
      case ReferenceType.references:
        return Icons.format_quote;
      case ReferenceType.instanceOf:
        return Icons.category;
    }
  }

  /// 添加连接
  Future<void> _addConnection(BuildContext context, List<Node> allNodes) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ConnectionDialog(
        sourceNode: widget.node,
        availableNodes: allNodes,
      ),
    );

    if (result == true && mounted) {
      // 连接已添加，对话框会自动刷新
    }
  }

  /// 断开连接
  Future<void> _disconnect(String targetNodeId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect'),
        content: const Text('Are you sure you want to disconnect this node?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final nodeBloc = context.read<NodeBloc>();
      nodeBloc.add(NodeDisconnectEvent(
        fromNodeId: widget.node.id,
        toNodeId: targetNodeId,
      ));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection removed')),
      );
    }
  }
}
