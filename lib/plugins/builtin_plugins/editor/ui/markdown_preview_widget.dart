import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// Markdown 预览 widget
class MarkdownPreviewWidget extends StatefulWidget {
  /// 创建 Markdown 预览 widget
  /// 
  /// [markdown] - 要预览的 Markdown 内容
  /// [isRenderMode] - 是否以渲染模式显示，默认为 false
  const MarkdownPreviewWidget({
    super.key,
    required this.markdown,
    this.isRenderMode = false,
  });

  /// 要预览的 Markdown 内容
  final String markdown;
  
  /// 是否以渲染模式显示
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
  Widget build(BuildContext context) => Column(
      children: [
        // 工具栏
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.visibility, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Preview',
                    style: Theme.of(context).textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                // 使用图标按钮替代 SegmentedButton，节省空间
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ModeButton(
                      icon: Icons.code,
                      isSelected: !_isRenderMode,
                      tooltip: 'View as text',
                      onTap: () {
                        if (_isRenderMode) _toggleMode();
                      },
                    ),
                    const SizedBox(width: 2),
                    _ModeButton(
                      icon: Icons.visibility,
                      isSelected: _isRenderMode,
                      tooltip: 'View as rendered',
                      onTap: () {
                        if (!_isRenderMode) _toggleMode();
                      },
                    ),
                  ],
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
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Markdown(
                    data: widget.markdown,
                    selectable: true,
                    padding: EdgeInsets.zero,
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  // 同时支持水平和垂直滚动
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
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
        ),
      ],
    );
}

/// 模式切换按钮（紧凑型）
class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.icon,
    required this.isSelected,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final bool isSelected;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primaryContainer
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).dividerColor,
            ),
          ),
          child: Icon(
            icon,
            size: 16,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
}
