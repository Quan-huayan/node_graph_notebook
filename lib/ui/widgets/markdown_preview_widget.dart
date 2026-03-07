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
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('Text', style: TextStyle(fontSize: 12)),
                      icon: Icon(Icons.code, size: 16),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('Render', style: TextStyle(fontSize: 12)),
                      icon: Icon(Icons.visibility, size: 16),
                    ),
                  ],
                  selected: {_isRenderMode},
                  onSelectionChanged: (Set<bool> selected) {
                    _toggleMode();
                  },
                ),
              ],
            ),
          ),
        ),

        // 内容区域
        Expanded(
          child: widget.markdown.isEmpty
              ? const Center(child: Text('No preview available'))
              : _isRenderMode
                  ? MarkdownBody(
                      data: widget.markdown,
                      selectable: true,
                      onTapLink: (text, href, title) {
                        // 可选：处理链接点击
                      },
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
