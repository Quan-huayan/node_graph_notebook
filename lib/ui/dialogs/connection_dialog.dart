import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/models.dart';
import '../../core/services/theme_service.dart';
import '../models/models.dart';

/// 创建连接对话框
class ConnectionDialog extends StatefulWidget {
  const ConnectionDialog({
    super.key,
    required this.sourceNode,
    required this.availableNodes,
  });

  final Node sourceNode;
  final List<Node> availableNodes;

  @override
  State<ConnectionDialog> createState() => _ConnectionDialogState();
}

class _ConnectionDialogState extends State<ConnectionDialog> {
  Node? _selectedTargetNode;
  ReferenceType _selectedType = ReferenceType.relatesTo;
  final TextEditingController _roleController = TextEditingController();
  bool _isCreating = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.read<ThemeService>().themeData;
    return AlertDialog(
      backgroundColor: theme.backgrounds.primary,
      title: const Text('Create Connection'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 源节点
            Text(
              'From: ${widget.sourceNode.title}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 16),

            // 目标节点选择
            const Text('To:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<Node>(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Select target node',
              ),
              items: widget.availableNodes
                  .where((n) => n.id != widget.sourceNode.id)
                  .map((node) {
                return DropdownMenuItem(
                  value: node,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        node.isFolder
                            ? Icons.folder
                            : (node.isConcept ? Icons.category : Icons.note),
                        size: 16,
                        color: node.isFolder ? Colors.amber : null,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          node.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (node) {
                setState(() {
                  _selectedTargetNode = node;
                });
              },
            ),
            const SizedBox(height: 16),

            // 引用类型选择
            const Text('Type:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<ReferenceType>(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              items: ReferenceType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(_getTypeLabel(type)),
                );
              }).toList(),
              onChanged: (type) {
                setState(() {
                  _selectedType = type ?? ReferenceType.relatesTo;
                });
              },
            ),
            const SizedBox(height: 16),

            // 角色标签（可选）
            TextField(
              controller: _roleController,
              decoration: const InputDecoration(
                labelText: 'Role (optional)',
                hintText: 'e.g., "related to", "depends on", "parent of"',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isCreating || _selectedTargetNode == null
              ? null
              : _createConnection,
          child: _isCreating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Connect'),
        ),
      ],
    );
  }

  String _getTypeLabel(ReferenceType type) {
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
        return 'Relates To';
      case ReferenceType.references:
        return 'References';
      case ReferenceType.instanceOf:
        return 'Instance Of';
    }
  }

  Future<void> _createConnection() async {
    if (_selectedTargetNode == null) return;

    setState(() {
      _isCreating = true;
    });

    final nodeModel = context.read<NodeModel>();
    final role = _roleController.text.trim().isEmpty
        ? null
        : _roleController.text.trim();

    try {
      await nodeModel.connectNodes(
        fromNodeId: widget.sourceNode.id,
        toNodeId: _selectedTargetNode!.id,
        type: _selectedType,
        role: role,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Connected: ${widget.sourceNode.title} → ${_selectedTargetNode!.title}${role != null ? ' ($role)' : ''}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create connection: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _roleController.dispose();
    super.dispose();
  }
}

/// 断开连接对话框
class DisconnectDialog extends StatelessWidget {
  const DisconnectDialog({
    super.key,
    required this.sourceNode,
    required this.connectedNodes,
  });

  final Node sourceNode;
  final List<Node> connectedNodes;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Disconnect Nodes'),
      content: connectedNodes.isEmpty
          ? const Text('No connections to disconnect.')
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Disconnect from ${sourceNode.title}:'),
                const SizedBox(height: 16),
                ...connectedNodes.map((node) => ListTile(
                      title: Text(node.title),
                      trailing: IconButton(
                        icon: const Icon(Icons.link_off),
                        onPressed: () => _disconnect(context, node),
                      ),
                    )),
              ],
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Future<void> _disconnect(BuildContext context, Node targetNode) async {
    final nodeModel = context.read<NodeModel>();

    try {
      await nodeModel.disconnectNodes(
        fromNodeId: sourceNode.id,
        toNodeId: targetNode.id,
      );

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Disconnected: ${sourceNode.title} ←→ ${targetNode.title}',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to disconnect: $e')),
        );
      }
    }
  }
}
