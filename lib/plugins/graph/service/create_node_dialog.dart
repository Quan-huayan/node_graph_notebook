import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/i18n.dart';
import '../../../../core/services/theme_service.dart';
import '../bloc/graph_bloc.dart';
import '../bloc/graph_event.dart';
import '../bloc/node_bloc.dart';
import '../bloc/node_event.dart';

/// 创建节点对话框
class CreateNodeDialog extends StatefulWidget {
  /// 构造函数
  const CreateNodeDialog({super.key});

  @override
  State<CreateNodeDialog> createState() => _CreateNodeDialogState();
}

class _CreateNodeDialogState extends State<CreateNodeDialog> {
  /// 构造函数
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

    return Consumer<I18n>(
      builder: (context, i18n, child) {
        return AlertDialog(
          backgroundColor: theme.backgrounds.primary,
          title: Row(
            children: [
              const Icon(Icons.category),
              const SizedBox(width: 8),
              Text(i18n.t('Create Node')),
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
                    decoration: InputDecoration(
                      labelText: '${i18n.t('Title')} *',
                      hintText: i18n.t('Enter note title'),
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
                      labelText: i18n.t('Description'),
                      hintText: i18n.t('Write your note in Markdown...'),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.edit_note),
                      helperText: i18n.t('Supports Markdown formatting'),
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
              child: Text(i18n.t('Cancel')),
            ),
            ElevatedButton(
              onPressed: _isCreating ? null : _createNode,
              child: _isCreating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(i18n.t('Create Node')),
            ),
          ],
        );
      },
    );
  }

  void _createNode() async {
    final i18n = I18n.of(context);
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    // 验证标题
    if (title.isEmpty) {
      _showErrorSnackBar(i18n.t('Title cannot be empty'));
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
      nodeBloc.add(
        NodeCreateEvent(title: title, content: content.isEmpty ? '' : content),
      );

      // 等待节点创建完成
      await Future.delayed(const Duration(milliseconds: 100));

      // 获取新创建的节点
      final newNode = nodeBloc.state.nodes.lastWhere(
        (n) => n.title == title,
      );

      // 添加到当前图
      final state = graphBloc.state;
      if (state.hasGraph) {
        graphBloc.add(NodeAddEvent(newNode.id));
      }

      if (mounted) {
        Navigator.pop(context);
        _showSuccessSnackBar('${i18n.t('Created:')} ${newNode.title}');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('${i18n.t('Failed to create node:')} $e');
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
