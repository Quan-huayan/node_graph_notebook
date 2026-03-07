import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// Markdown 预览 widget
class MarkdownPreviewWidget extends StatefulWidget {
  const MarkdownPreviewWidget({
    super.key,
    required this.markdown,
    this.isRenderMode = false,
  });

  final String markdown;
  final bool isRenderMode;

  @override
  State<MarkdownPreviewWidget> createState() => _MarkdownPreviewWidgetState();
}

class _MarkdownPreviewWidgetState extends State<MarkdownPreviewWidget> {
  late bool _isRenderMode;

  @override
  void initState() {
    super.initState();
    _isRenderMode = widget.isRenderMode;
  }

  @override
  void didUpdateWidget(MarkdownPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRenderMode != oldWidget.isRenderMode) {
      _isRenderMode = widget.isRenderMode;
    }
  }

  void _toggleMode() {
    setState(() {
      _isRenderMode = !_isRenderMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 工具栏
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.visibility, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Preview',
                    style: Theme.of(context).textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // 使用图标按钮节省空间，添加工具提示说明功能
                // 使用 style 替代 isSelected 以确保更好的兼容性
                IconButton(
                  icon: Icon(_isRenderMode ? Icons.visibility : Icons.code),
                  iconSize: 16,
                  tooltip: _isRenderMode ? 'Switch to Text' : 'Switch to Render',
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: _toggleMode,
                  style: IconButton.styleFrom(
                    backgroundColor: _isRenderMode
                        ? Theme.of(context).colorScheme.secondaryContainer
                        : null,
                    foregroundColor: _isRenderMode
                        ? Theme.of(context).colorScheme.onSecondaryContainer
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),

        // 内容区域 - 使用 Flexible 而非 Expanded，避免过度约束
        // 当父组件有明确高度约束时，Flexible 可以正确处理内容溢出
        Flexible(
          child: widget.markdown.isEmpty
              ? const Center(child: Text('No preview available'))
              : _isRenderMode
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: MarkdownBody(
                        data: widget.markdown,
                        selectable: true,
                        onTapLink: (text, href, title) {
                          // 可选：处理链接点击
                        },
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: SelectableText(
                        widget.markdown,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
        ),
      ],
    );
  }
}
