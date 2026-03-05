import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:node_graph_notebook/core/models/models.dart';
import '../../core/services/theme_service.dart';
import '../blocs/blocs.dart';

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
  bool _isCreating = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.read<ThemeService>().themeData;

    return AlertDialog(
      backgroundColor: theme.backgrounds.primary,
      title: const Row(
        children: [
          Icon(Icons.category),
          SizedBox(width: 8),
          Text('Create Node'),
        ],
      ),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题输入
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  hintText: 'Enter note title',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),

              // 内容输入 - 统一显示，但根据类型有不同的标签和提示
              TextField(
                controller: _contentController,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText:'Write your note in Markdown...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit_note),
                  helperText: 'Supports Markdown formatting',
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
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
              : const Text('Create Node'),
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

    setState(() {
      _isCreating = true;
    });

    final nodeBloc = context.read<NodeBloc>();
    final graphBloc = context.read<GraphBloc>();

    try {
      // 发送创建节点事件
      nodeBloc.add(NodeCreateEvent(
        title: title,
        content: content.isEmpty ? '' : content,
      ));

      // 等待节点创建完成
      await Future.delayed(const Duration(milliseconds: 100));

      // 获取新创建的节点
      final Node newNode = nodeBloc.state.nodes.lastWhere(
        (n) => n.title == title
      );

      // 添加到当前图
      final state = graphBloc.state;
      if (state.hasGraph) {
        graphBloc.add(NodeAddEvent(newNode.id));
      }

      if (mounted) {
        Navigator.pop(context);
        _showSuccessSnackBar('Created: ${newNode.title}');
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
