import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/models/models.dart';
import '../../core/services/theme_service.dart';
import '../blocs/blocs.dart';
import '../pages/markdown_editor_page.dart';

/// 搜索对话框
class SearchDialog extends StatefulWidget {
  const SearchDialog({super.key});

  @override
  State<SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<SearchDialog> {
  final _searchController = TextEditingController();
  bool _isSearching = false;
  List<Node> _results = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题
            AppBar(
              title: const Text('Search Nodes'),
              automaticallyImplyLeading: false,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            // 搜索框
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search by title or content...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _results = [];
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                ),
                onChanged: (value) {
                  if (value.trim().isNotEmpty) {
                    _performSearch(value.trim());
                  } else {
                    setState(() {
                      _results = [];
                    });
                  }
                },
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    _performSearch(value.trim());
                  }
                },
              ),
            ),

            // 搜索提示或结果
            Expanded(
              child: _isSearching
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Searching...'),
                        ],
                      ),
                    )
                  : _results.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: _results.length,
                          itemBuilder: (ctx, i) {
                            final node = _results[i];
                            return _buildResultTile(context, node, i);
                          },
                        ),
            ),

            // 结果计数
            if (_results.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Found ${_results.length} result${_results.length == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _results = [];
                        });
                      },
                      icon: const Icon(Icons.clear_all, size: 18),
                      label: const Text('Clear'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    if (_searchController.text.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Search Your Nodes',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Type in the search box above',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
            ),
            const SizedBox(height: 24),
            _buildSearchTips(),
          ],
        ),
      );
    } else {
      return Builder(
        builder: (context) {
          final theme = context.watch<ThemeService>().themeData;
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: theme.status.warning.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No Results Found',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: theme.status.warning,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Try different keywords',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: theme.text.secondary,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'or use Advanced Search for more options',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: theme.text.secondary,
                      ),
                ),
              ],
            ),
          );
        },
      );
    }
  }

  /// 构建搜索提示
  Widget _buildSearchTips() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Search Tips',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildTip('• Search looks in both title and content'),
          _buildTip('• Partial matches are supported'),
          _buildTip('• Use Advanced Search for filters'),
        ],
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
      ),
    );
  }

  Widget _buildResultTile(BuildContext context, Node node, int index) {
    final nodeBloc = context.read<NodeBloc>();
    final theme = context.watch<ThemeService>().themeData;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.nodes.nodeBackground,
          child: Icon(
            Icons.note,
            color: theme.nodes.nodePrimary,
            size: 20,
          ),
        ),
        title: Text(
          node.title,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (node.content != null && node.content!.isNotEmpty)
              Text(
                _getPreview(node.content!),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: theme.text.secondary,
                    ),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Chip(
                  label: Text(
                    node.isConcept ? 'Concept' : 'Content',
                    style: const TextStyle(fontSize: 10),
                  ),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                if (node.references.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.link,
                    size: 14,
                    color: theme.text.secondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${node.references.length}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: theme.text.secondary,
                        ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.pop(context);
          nodeBloc.add(NodeSelectEvent(node.id));

          // 打开编辑器
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => MarkdownEditorPage(node: node),
            ),
          );
        },
      ),
    );
  }

  /// 获取内容预览
  String _getPreview(String content, {int maxLength = 100}) {
    // 移除Markdown语法标记
    final preview = content
        .replaceAll(RegExp(r'^#+\s'), '') // 移除标题标记
        .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'\1') // 移除粗体
        .replaceAll(RegExp(r'\*([^*]+)\*'), r'\1') // 移除斜体
        .replaceAll(RegExp(r'`([^`]+)`'), r'\1') // 移除代码
        .replaceAll(RegExp(r'\n'), ' '); // 换行替换为空格

    if (preview.length > maxLength) {
      return '${preview.substring(0, maxLength)}...';
    }
    return preview;
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isSearching = true;
    });

    final nodeBloc = context.read<NodeBloc>();
    nodeBloc.add(NodeSearchEvent(query));

    // 等待搜索完成
    await Future.delayed(const Duration(milliseconds: 100));

    setState(() {
      _results = nodeBloc.state.nodes;
      _isSearching = false;
    });
  }
}

/// 快速搜索栏
class SearchBar extends StatefulWidget {
  const SearchBar({super.key, this.onNodeSelected});
  
  final Function(Node)? onNodeSelected;

  @override
  State<SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {
  final _controller = TextEditingController();
  bool _isExpanded = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _isExpanded ? 400 : 56,
      height: 56,
      child: _isExpanded ? _buildExpandedSearch() : _buildCollapsedSearch(),
    );
  }

  Widget _buildCollapsedSearch() {
    return IconButton(
      icon: const Icon(Icons.search),
      onPressed: () {
        setState(() {
          _isExpanded = true;
        });
      },
    );
  }

  Widget _buildExpandedSearch() {
    final nodeBloc = context.watch<NodeBloc>();

    return TextField(
      controller: _controller,
      autofocus: true,
      decoration: InputDecoration(
        hintText: 'Search...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            _controller.clear();
            nodeBloc.add(const NodeClearErrorEvent());
            setState(() {
              _isExpanded = false;
            });
          },
        ),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
      ),
      onChanged: (value) {
        if (value.trim().isEmpty) {
          // 重新加载所有节点
          nodeBloc.add(const NodeLoadEvent());
        } else {
          nodeBloc.add(NodeSearchEvent(value.trim()));
        }
      },
    );
  }
}

/// 高级搜索对话框
class AdvancedSearchDialog extends StatefulWidget {
  const AdvancedSearchDialog({super.key});

  @override
  State<AdvancedSearchDialog> createState() => _AdvancedSearchDialogState();
}

class _AdvancedSearchDialogState extends State<AdvancedSearchDialog> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagsController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      title: const Row(
        children: [
          Icon(Icons.filter_list),
          SizedBox(width: 8),
          Text('Advanced Search'),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 提示信息
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Fill any field to filter. Leave empty to ignore.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),

              // 标题搜索
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  hintText: 'Search in title...',
                  prefixIcon: const Icon(Icons.title),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                ),
              ),
              const SizedBox(height: 16),

              // 内容搜索
              TextField(
                controller: _contentController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Content',
                  hintText: 'Search in content...',
                  prefixIcon: const Icon(Icons.text_snippet),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                ),
              ),
              const SizedBox(height: 16),

              // 标签搜索
              TextField(
                controller: _tagsController,
                decoration: InputDecoration(
                  labelText: 'Tags',
                  hintText: 'tag1, tag2, tag3...',
                  prefixIcon: const Icon(Icons.tag),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  helperText: 'Separate multiple tags with commas',
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () {
            _titleController.clear();
            _contentController.clear();
            _tagsController.clear();
          },
          icon: const Icon(Icons.clear_all, size: 18),
          label: const Text('Clear All'),
        ),
        ElevatedButton.icon(
          onPressed: _isSearching ? null : _performSearch,
          icon: _isSearching
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.search, size: 18),
          label: Text(_isSearching ? 'Searching...' : 'Search'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: _isSearching ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Future<void> _performSearch() async {
    setState(() {
      _isSearching = true;
    });

    final nodeBloc = context.read<NodeBloc>();

    // 构建搜索条件
    List<Node> results = nodeBloc.state.nodes;

    // 标题过滤
    if (_titleController.text.trim().isNotEmpty) {
      final query = _titleController.text.trim().toLowerCase();
      results = results
          .where((n) => n.title.toLowerCase().contains(query))
          .toList();
    }

    // 内容过滤
    if (_contentController.text.trim().isNotEmpty) {
      final query = _contentController.text.trim().toLowerCase();
      results = results
          .where((n) =>
              n.content?.toLowerCase().contains(query) ?? false)
          .toList();
    }

    // 标签过滤
    if (_tagsController.text.trim().isNotEmpty) {
      final tags = _tagsController.text
          .split(',')
          .map((t) => t.trim().toLowerCase())
          .where((t) => t.isNotEmpty)
          .toList();

      results = results.where((n) {
        final nodeTags =
            (n.metadata['tags'] as List<dynamic>?)?.map((t) => t.toString()) ?? [];
        return tags.any((tag) => nodeTags.contains(tag));
      }).toList();
    }

    setState(() {
      _isSearching = false;
    });

    if (mounted) {
      Navigator.pop(context);

      // 显示结果
      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No results found')),
        );
      } else {
        _showResults(context, results);
      }
    }
  }

  void _showResults(BuildContext context, List<Node> results) {
    final theme = context.read<ThemeService>().themeData;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: Text('Search Results (${results.length})'),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (ctx, i) {
                    final node = results[i];
                    return ListTile(
                      leading: Icon(
                        Icons.note,
                        color: theme.nodes.nodePrimary,
                      ),
                      title: Text(node.title),
                      subtitle: Text(
                        'Content',
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        context.read<NodeBloc>().add(NodeSelectEvent(node.id));

                        // 打开编辑器
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => MarkdownEditorPage(node: node),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
