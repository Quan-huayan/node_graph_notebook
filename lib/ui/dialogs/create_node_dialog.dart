import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/models.dart';
import '../../core/services/theme_service.dart';
import '../models/models.dart';

// 创建节点对话框
class CreateNodeDialog extends StatefulWidget {
  const CreateNodeDialog({super.key});

  @override
  State<CreateNodeDialog> createState() => _CreateNodeDialogState();
}

class _CreateNodeDialogState extends State<CreateNodeDialog> {
  _CreateNodeDialogState();

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  NodeType _selectedType = NodeType.content;
  bool _isCreating = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isContent = _selectedType == NodeType.content;
    final theme = context.read<ThemeService>().themeData;

    return AlertDialog(
      backgroundColor: theme.backgrounds.primary,
      title: Row(
        children: [
          Icon(isContent ? Icons.note : Icons.category),
          const SizedBox(width: 8),
          const Text('Create Node'),
        ],
      ),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 节点类型选择
              Text(
                'Node Type',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: context.read<ThemeService>().themeData.text.hint,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<NodeType>(
                segments: const [
                  ButtonSegment(
                    value: NodeType.content,
                    label: Text('Content'),
                    icon: Icon(Icons.note),
                  ),
                  ButtonSegment(
                    value: NodeType.concept,
                    label: Text('Concept'),
                    icon: Icon(Icons.category),
                  ),
                ],
                selected: {_selectedType},
                onSelectionChanged: (Set<NodeType> selection) {
                  setState(() {
                    _selectedType = selection.first;
                  });
                },
              ),
              const SizedBox(height: 12),

              // 类型说明
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      isContent ? Icons.info_outline : Icons.lightbulb_outline,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isContent
                            ? 'Content nodes store your notes and ideas in Markdown format.'
                            : 'Concept nodes represent relationships or abstract concepts that organize other nodes.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 标题输入
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Title *',
                  hintText: isContent ? 'Enter note title' : 'Enter concept name',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.title),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),

              // 内容输入 - 统一显示，但根据类型有不同的标签和提示
              TextField(
                controller: _contentController,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: isContent ? 'Content *' : 'Description',
                  hintText: isContent
                      ? 'Write your note in Markdown...'
                      : 'Optional description of this concept...',
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(isContent ? Icons.edit_note : Icons.description),
                  helperText: isContent ? 'Supports Markdown formatting' : 'Optional',
                ),
                textCapitalization: TextCapitalization.sentences,
              ),

              // 概念节点的额外提示
              if (!isContent) ...[
                const SizedBox(height: 12),
                Builder(
                  builder: (context) {
                    final theme = context.read<ThemeService>().themeData;
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.status.info.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.status.info.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.tips_and_updates, size: 16, color: theme.status.info),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'You can connect other nodes to this concept node after creation.',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isCreating ? null : _createNode,
          child: _isCreating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isContent ? 'Create Content' : 'Create Concept'),
        ),
      ],
    );
  }

  void _createNode() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    // 验证标题
    if (title.isEmpty) {
      _showErrorSnackBar('Title cannot be empty');
      _focusTitleField();
      return;
    }

    // 对于内容节点，验证内容
    if (_selectedType == NodeType.content && content.isEmpty) {
      _showErrorSnackBar('Content nodes must have content');
      return;
    }

    setState(() {
      _isCreating = true;
    });

    final nodeModel = context.read<NodeModel>();
    final graphModel = context.read<GraphModel>();

    try {
      Node node;

      if (_selectedType == NodeType.content) {
        node = await nodeModel.createContentNode(
          title: title,
          content: content,
        );
      } else {
        node = await nodeModel.createNode(
          type: NodeType.concept,
          title: title,
          content: content.isEmpty ? '' : content,
        );
      }

      // 添加到当前图
      if (graphModel.hasGraph) {
        await graphModel.addNode(node.id);
      }

      if (mounted) {
        Navigator.pop(context);
        _showSuccessSnackBar('Created: ${node.title}');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to create node: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    final theme = context.read<ThemeService>().themeData;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: theme.text.onDark),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: theme.status.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    final theme = context.read<ThemeService>().themeData;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: theme.text.onDark),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: theme.status.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _focusTitleField() {
    _titleController.selection = TextSelection.fromPosition(
      TextPosition(offset: _titleController.text.length),
    );
  }
}
