import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/models/node.dart';
import '../blocs/search_bloc/search_bloc.dart';
import '../blocs/search_bloc/search_event.dart';
import '../blocs/search_bloc/search_state.dart';
import '../blocs/node_bloc.dart';
import '../blocs/node_event.dart';
import '../blocs/graph_bloc.dart';
import '../models/search_query.dart';
import '../models/search_preset_model.dart';

/// 搜索侧边栏面板
class SearchSidebarPanel extends StatefulWidget {
  const SearchSidebarPanel({super.key});

  @override
  State<SearchSidebarPanel> createState() => _SearchSidebarPanelState();
}

class _SearchSidebarPanelState extends State<SearchSidebarPanel> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  bool _showAdvanced = false;
  List<String> _selectedTags = [];
  SearchPreset? _selectedPreset;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _performSearch() {
    final query = SearchQuery(
      searchText: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      titleQuery: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
      contentQuery: _contentController.text.trim().isEmpty ? null : _contentController.text.trim(),
      tags: _selectedTags.isEmpty ? null : _selectedTags,
    );

    context.read<SearchBloc>().add(SearchPerformEvent(query));
  }

  void _saveAsPreset() {
    if (_searchController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a search query first')),
      );
      return;
    }

    final query = SearchQuery(
      searchText: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      titleQuery: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
      contentQuery: _contentController.text.trim().isEmpty ? null : _contentController.text.trim(),
      tags: _selectedTags.isEmpty ? null : _selectedTags,
    );

    // 显示对话框输入预设名称
    showDialog<String>(
      context: context,
      builder: (dialogCtx) {
        final nameController = TextEditingController(
          text: _searchController.text.trim().substring(0, _searchController.text.trim().length > 20 ? 20 : _searchController.text.trim().length),
        );
        return AlertDialog(
          title: const Text('Save Search'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Preset Name',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(dialogCtx, name);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    ).then((name) {
      if (name != null && name.isNotEmpty) {
        context.read<SearchBloc>().add(SearchSavePresetEvent(name, query));
      }
    });
  }

  void _loadPreset(SearchPreset preset) {
    setState(() {
      _selectedPreset = preset;
      _titleController.text = preset.titleQuery ?? '';
      _contentController.text = preset.contentQuery ?? '';
      _selectedTags = List.from(preset.tags ?? []);
    });
    context.read<SearchBloc>().add(SearchLoadPresetEvent(preset));
  }

  void _deletePreset(String id) {
    showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Delete Preset'),
          content: const Text('Are you sure you want to delete this search preset?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    ).then((confirmed) {
      if (confirmed == true) {
        context.read<SearchBloc>().add(SearchDeletePresetEvent(id));
        if (_selectedPreset?.id == id) {
          setState(() {
            _selectedPreset = null;
          });
        }
      }
    });
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_selectedTags.contains(tag)) {
      setState(() {
        _selectedTags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _selectedTags.remove(tag);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // 搜索栏
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            decoration: InputDecoration(
              labelText: 'Search',
              hintText: 'Enter search query...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_selectedPreset != null)
                    IconButton(
                      icon: const Icon(Icons.star),
                      color: Colors.amber,
                      tooltip: _selectedPreset!.name,
                      onPressed: () {},
                    ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.star_border),
                    tooltip: 'Saved searches',
                    onSelected: (presetId) {
                      // 这个会在下面的 BlocBuilder 中处理
                    },
                    itemBuilder: (context) {
                      return [
                        const PopupMenuItem(
                          enabled: false,
                          child: Text('Saved Searches'),
                        ),
                        const PopupMenuDivider(),
                      ];
                    },
                  ),
                ],
              ),
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _performSearch(),
          ),
        ),

        // 高级过滤器切换
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _showAdvanced = !_showAdvanced;
                    });
                  },
                  icon: Icon(_showAdvanced ? Icons.expand_less : Icons.expand_more),
                  label: const Text('Advanced Filters'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.star),
                tooltip: 'Save as preset',
                onPressed: _saveAsPreset,
              ),
            ],
          ),
        ),

        // 高级过滤器面板
        if (_showAdvanced)
          Padding(
            padding: const EdgeInsets.all(16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: theme.dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Advanced Filters',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title contains',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _contentController,
                      decoration: const InputDecoration(
                        labelText: 'Content contains',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 标签选择
                    Wrap(
                      spacing: 4,
                      children: _selectedTags.map((tag) {
                        return Chip(
                          label: Text(tag),
                          onDeleted: () => _removeTag(tag),
                        );
                      }).toList(),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _tagController,
                            decoration: const InputDecoration(
                              labelText: 'Add tag',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onSubmitted: (_) => _addTag(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: _addTag,
                          tooltip: 'Add tag',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        _titleController.clear();
                        _contentController.clear();
                        _tagController.clear();
                        setState(() {
                          _selectedTags.clear();
                        });
                      },
                      child: const Text('Clear Filters'),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // 预设列表
        BlocBuilder<SearchBloc, SearchState>(
          buildWhen: (previous, current) => previous.presets != current.presets,
          builder: (context, state) {
            if (!state.hasPresets) {
              return const SizedBox.shrink();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    'Saved Searches',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                for (final preset in state.presets)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.star, size: 16),
                    title: Text(preset.name),
                    subtitle: Text(
                      _getPresetDescription(preset),
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () => _deletePreset(preset.id),
                    ),
                    onTap: () => _loadPreset(preset),
                  ),
                const Divider(height: 32),
              ],
            );
          },
        ),

        // 搜索结果
        Expanded(
          child: BlocBuilder<SearchBloc, SearchState>(
            buildWhen: (previous, current) =>
                previous.results != current.results ||
                previous.isLoading != current.isLoading ||
                previous.error != current.error,
            builder: (context, state) {
              if (state.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state.error != null) {
                return Center(
                  child: Text(
                    'Error: ${state.error}',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                );
              }

              if (!state.hasResults) {
                return const Center(child: Text('No results found'));
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      'Results (${state.resultCount})',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: state.results.length,
                      itemBuilder: (context, index) {
                        final node = state.results[index];
                        return _SearchResultTile(
                          node: node,
                          query: state.currentQuery,
                          onTap: () {
                            context.read<NodeBloc>().add(NodeSelectEvent(node.id));
                            context.read<GraphBloc>().add(
                              NodeAddEvent(
                                node.id,
                                position: node.position,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  String _getPresetDescription(SearchPreset preset) {
    final parts = <String>[];
    if (preset.titleQuery != null) parts.add('Title: ${preset.titleQuery}');
    if (preset.contentQuery != null) parts.add('Content: ${preset.contentQuery}');
    if (preset.tags != null && preset.tags!.isNotEmpty) parts.add('Tags: ${preset.tags!.join(', ')}');
    return parts.isEmpty ? 'No filters' : parts.join(' | ');
  }
}

/// 搜索结果项
class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({
    required this.node,
    required this.query,
    required this.onTap,
  });

  final Node node;
  final SearchQuery? query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(node.isFolder ? Icons.folder : Icons.description),
      title: _HighlightText(
        text: node.title,
        query: query?.searchText ?? query?.titleQuery,
      ),
      subtitle: node.content != null && node.content!.isNotEmpty
          ? _HighlightText(
              text: node.content!.length > 100
                  ? '${node.content!.substring(0, 100)}...'
                  : node.content!,
              query: query?.searchText ?? query?.contentQuery,
              maxLines: 2,
            )
          : null,
      onTap: onTap,
    );
  }
}

/// 高亮文本组件
class _HighlightText extends StatelessWidget {
  const _HighlightText({
    required this.text,
    required this.query,
    this.maxLines,
  });

  final String text;
  final String? query;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    if (query == null || query!.isEmpty) {
      return Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    final matches = RegExp(query!, caseSensitive: false).allMatches(text);

    if (matches.isEmpty) {
      return Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    final List<TextSpan> spans = [];
    int lastIndex = 0;

    for (final match in matches) {
      // 添加匹配前的文本
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: text.substring(lastIndex, match.start)));
      }

      // 添加高亮的匹配文本
      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: TextStyle(
            backgroundColor: Colors.yellow.shade200,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

      lastIndex = match.end;
    }

    // 添加剩余文本
    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex)));
    }

    return RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(context).style,
        children: spans,
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}
