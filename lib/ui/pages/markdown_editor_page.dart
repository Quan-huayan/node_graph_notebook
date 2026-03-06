import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/models/models.dart';
import '../../bloc/blocs.dart';

/// Markdown 编辑器页面
class MarkdownEditorPage extends StatefulWidget {
  const MarkdownEditorPage({
    super.key,
    this.node,
  });

  final Node? node;

  @override
  State<MarkdownEditorPage> createState() => _MarkdownEditorPageState();
}

class _MarkdownEditorPageState extends State<MarkdownEditorPage> {
  _MarkdownEditorPageState();

  late TextEditingController _titleController;
  late TextEditingController _contentController;
  bool _isPreviewMode = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.node?.title ?? '');
    _contentController = TextEditingController(text: widget.node?.content ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Markdown Editor'),
        actions: [
          // 切换预览/编辑模式
          IconButton(
            icon: Icon(_isPreviewMode ? Icons.edit : Icons.preview),
            onPressed: () {
              setState(() {
                _isPreviewMode = !_isPreviewMode;
              });
            },
            tooltip: _isPreviewMode ? 'Edit' : 'Preview',
          ),
          // 保存
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveNode,
            tooltip: 'Save',
          ),
        ],
      ),
      body: _isPreviewMode ? _buildPreview() : _buildEditor(),
    );
  }

  Widget _buildEditor() {
    return Column(
      children: [
        // 标题编辑
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _titleController,
            style: Theme.of(context).textTheme.headlineSmall,
            decoration: const InputDecoration(
              hintText: 'Title',
              border: OutlineInputBorder(),
            ),
          ),
        ),

        const Divider(height: 1),

        // 内容编辑
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _contentController,
              maxLines: null,
              expands: true,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
              ),
              decoration: const InputDecoration(
                hintText: 'Write your content in Markdown...',
                border: InputBorder.none,
              ),
            ),
          ),
        ),

        // Markdown 工具栏
        _buildMarkdownToolbar(),
      ],
    );
  }

  Widget _buildPreview() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          if (title.isNotEmpty)
            Text(
              '# $title',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          const SizedBox(height: 16),

          // 内容
          if (content.isNotEmpty)
            MarkdownBody(
              data: content,
              selectable: true,
            )
          else
            Text(
              'Nothing to preview',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
            ),
        ],
      ),
    );
  }

  Widget _buildMarkdownToolbar() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Wrap(
        spacing: 8,
        children: [
          _ToolbarButton(
            icon: Icons.format_bold,
            label: 'Bold',
            onPressed: () => _insertMarkdown('**', '**'),
          ),
          _ToolbarButton(
            icon: Icons.format_italic,
            label: 'Italic',
            onPressed: () => _insertMarkdown('*', '*'),
          ),
          _ToolbarButton(
            icon: Icons.title,
            label: 'H1',
            onPressed: () => _insertMarkdown('# ', ''),
          ),
          _ToolbarButton(
            icon: Icons.title,
            label: 'H2',
            onPressed: () => _insertMarkdown('## ', ''),
          ),
          _ToolbarButton(
            icon: Icons.format_list_bulleted,
            label: 'List',
            onPressed: () => _insertMarkdown('- ', ''),
          ),
          _ToolbarButton(
            icon: Icons.code,
            label: 'Code',
            onPressed: () => _insertMarkdown('`', '`'),
          ),
          _ToolbarButton(
            icon: Icons.link,
            label: 'Link',
            onPressed: () => _insertMarkdown('[', '](url)'),
          ),
          _ToolbarButton(
            icon: Icons.image,
            label: 'Image',
            onPressed: () => _insertMarkdown('![alt](', ')'),
          ),
        ],
      ),
    );
  }

  void _insertMarkdown(String prefix, String suffix) {
    final controller = _contentController;
    final text = controller.text;
    final selection = controller.selection;

    if (selection.isValid) {
      final start = selection.start;
      final end = selection.end;

      final newText = text.replaceRange(
        start,
        end,
        '$prefix${text.substring(start, end)}$suffix',
      );

      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: start + prefix.length + (end - start) + suffix.length,
        ),
      );
    } else {
      final cursorPosition = selection.baseOffset;
      final newText = text.replaceRange(
        cursorPosition,
        cursorPosition,
        '$prefix$suffix',
      );

      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: cursorPosition + prefix.length,
        ),
      );
    }
  }

  Future<void> _saveNode() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title cannot be empty')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final nodeBloc = context.read<NodeBloc>();

    try {
      if (widget.node == null) {
        // 创建新节点
        nodeBloc.add(NodeCreateContentEvent(
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
        ));
      } else {
        // 更新现有节点
        nodeBloc.add(NodeUpdateEvent(
          widget.node!.id,
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
        ));
      }

      // 等待操作完成
      await Future.delayed(const Duration(milliseconds: 100));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.node == null ? 'Node created' : 'Node saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}

/// 工具栏按钮
class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: IconButton(
        icon: Icon(icon),
        onPressed: onPressed,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(
          minWidth: 32,
          minHeight: 32,
        ),
      ),
    );
  }
}

/// Markdown 查看器组件
class MarkdownViewer extends StatelessWidget {
  const MarkdownViewer({
    super.key,
    required this.content,
  });

  final String content;

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: content,
      selectable: true,
      onTapLink: (text, href, title) {
        _handleLinkClick(href, context);
      },
    );
  }

  Future<void> _handleLinkClick(String? url, BuildContext context) async {
    if (url == null || url.isEmpty) return;

    // 处理内部链接（wiki-links [[node]]）
    if (url.startsWith('[[') && url.endsWith(']]')) {
      final nodeName = url.substring(2, url.length - 2);
      // TODO: 导航到对应的节点
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('跳转到节点: $nodeName')),
      );
      return;
    }

    // 处理外部链接
    final uri = Uri.tryParse(url);
    if (uri != null && uri.hasScheme) {
      // HTTP/HTTPS 链接
      if (uri.scheme == 'http' || uri.scheme == 'https') {
        try {
          if (Platform.isWindows) {
            await Process.run('cmd', ['/c', 'start', '', uri.toString()]);
          } else if (Platform.isMacOS) {
            await Process.run('open', [uri.toString()]);
          } else if (Platform.isLinux) {
            await Process.run('xdg-open', [uri.toString()]);
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('无法打开链接: $e')),
          );
        }
      }
      // 文件链接
      else if (uri.scheme == 'file') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('文件链接: $uri')),
        );
      }
      // 其他协议
      else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('不支持的协议: ${uri.scheme}')),
        );
      }
    }
    // 可能是相对路径或内部链接
    else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('内部链接: $url')),
      );
    }
  }
}
