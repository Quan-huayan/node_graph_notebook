import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/i18n.dart';
import '../../graph/bloc/graph_bloc.dart';
import '../../graph/bloc/graph_event.dart';
import '../bloc/search_bloc.dart';
import '../bloc/search_event.dart';
import '../bloc/search_state.dart';
import '../model/search_preset_model.dart';
import '../model/search_query.dart';
import 'searched_node_item.dart';

/// 搜索侧边栏面板
class SearchSidebarPanel extends StatefulWidget {
  /// 构造函数
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

  // 防抖定时器，避免频繁搜索
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _searchFocusNode.requestFocus();
  }

  void _performSearch() {
    // 取消之前的定时器
    _debounceTimer?.cancel();

    // 设置新的防抖定时器（500毫秒后执行搜索）
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      final query = SearchQuery(
        searchText: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
        titleQuery: _titleController.text.trim().isEmpty
            ? null
            : _titleController.text.trim(),
        contentQuery: _contentController.text.trim().isEmpty
            ? null
            : _contentController.text.trim(),
        tags: _selectedTags.isEmpty ? null : _selectedTags,
      );

      context.read<SearchBloc>().add(SearchPerformEvent(query));
    });
  }

  /// 立即执行搜索（用于用户提交时）
  void _performImmediateSearch() {
    // 取消之前的定时器
    _debounceTimer?.cancel();

    final query = SearchQuery(
      searchText: _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim(),
      titleQuery: _titleController.text.trim().isEmpty
          ? null
          : _titleController.text.trim(),
      contentQuery: _contentController.text.trim().isEmpty
          ? null
          : _contentController.text.trim(),
      tags: _selectedTags.isEmpty ? null : _selectedTags,
    );

    context.read<SearchBloc>().add(SearchPerformEvent(query));
  }

  void _saveAsPreset() {
    final i18n = I18n.of(context);

    if (_searchController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(i18n.t('Please enter a search query first'))),
      );
      return;
    }

    final query = SearchQuery(
      searchText: _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim(),
      titleQuery: _titleController.text.trim().isEmpty
          ? null
          : _titleController.text.trim(),
      contentQuery: _contentController.text.trim().isEmpty
          ? null
          : _contentController.text.trim(),
      tags: _selectedTags.isEmpty ? null : _selectedTags,
    );

    // 显示对话框输入预设名称
    showDialog<String>(
      context: context,
      builder: (dialogCtx) {
        final i18n = I18n.of(dialogCtx);
        final nameController = TextEditingController(
          text: _searchController.text.trim().substring(
            0,
            _searchController.text.trim().length > 20
                ? 20
                : _searchController.text.trim().length,
          ),
        );
        return AlertDialog(
          title: Text(i18n.t('Save Search')),
          content: TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: i18n.t('Preset Name'),
              border: const OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(i18n.t('Cancel')),
            ),
            TextButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(dialogCtx, name);
                }
              },
              child: Text(i18n.t('Save')),
            ),
          ],
        );
      },
    ).then((name) {
      if (name != null && name.isNotEmpty && mounted) {
        context.read<SearchBloc>().add(SearchSavePresetEvent(name, query));
      }
    });
  }

  void _loadPreset(SearchPreset preset) {
    setState(() {
      _selectedPreset = preset;
      _titleController.text = preset.titleQuery ?? '';
      _contentController.text = preset.contentQuery ?? '';
      _selectedTags = List<String>.from(preset.tags ?? []);
    });
    context.read<SearchBloc>().add(SearchLoadPresetEvent(preset));
  }

  void _deletePreset(String id) {
    showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        final i18n = I18n.of(dialogCtx);
        return AlertDialog(
          title: Text(i18n.t('Delete Preset')),
          content: Text(
            i18n.t('Are you sure you want to delete this search preset?'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: Text(i18n.t('Cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: Text(i18n.t('Delete')),
            ),
          ],
        );
      },
    ).then((confirmed) {
      if (confirmed ?? false) {
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
    // 删除标签后触发搜索
    _performSearch();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<I18n>(
      builder: (context, i18n, child) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
        // 搜索栏
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            decoration: InputDecoration(
              labelText: i18n.t('Search'),
              hintText: i18n.t('Enter search query...'),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _selectedPreset != null
                  ? const Icon(Icons.star, color: Colors.amber)
                  : PopupMenuButton<String>(
                      icon: const Icon(Icons.star_border),
                      tooltip: i18n.t('Saved searches'),
                      onSelected: (presetId) {
                        // 这个会在下面的 BlocBuilder 中处理
                      },
                      itemBuilder: (context) => [
                          PopupMenuItem(
                            enabled: false,
                            child: Text(i18n.t('Saved searches')),
                          ),
                          const PopupMenuDivider(),
                        ],
                    ),
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => _performSearch(), // 添加防抖搜索
            onSubmitted: (_) => _performImmediateSearch(), // 提交时立即搜索
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
                  icon: Icon(
                    _showAdvanced ? Icons.expand_less : Icons.expand_more,
                  ),
                  label: Text(i18n.t('Advanced Filters')),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.star),
                tooltip: i18n.t('Save as preset'),
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
                    Text(i18n.t('Advanced Filters'), style: theme.textTheme.titleSmall),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: i18n.t('Title contains'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => _performSearch(), // 添加防抖搜索
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _contentController,
                      decoration: InputDecoration(
                        labelText: i18n.t('Content contains'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => _performSearch(), // 添加防抖搜索
                    ),
                    const SizedBox(height: 8),
                    // 标签选择
                    Wrap(
                      spacing: 4,
                      children: _selectedTags.map((tag) => Chip(
                          label: Text(tag),
                          onDeleted: () => _removeTag(tag),
                        )).toList(),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _tagController,
                            decoration: InputDecoration(
                              labelText: i18n.t('Add tag'),
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            onSubmitted: (_) => _addTag(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: _addTag,
                          tooltip: i18n.t('Add tag'),
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
                      child: Text(i18n.t('Clear Filters')),
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
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
        Flexible(
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
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                );
              }

              if (!state.hasResults) {
                return Center(child: Text(i18n.t('No results found')));
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
                  Flexible(
                    child: ListView.builder(
                      itemCount: state.results.length,
                      itemBuilder: (context, index) {
                        final node = state.results[index];
                        // === 搜索高亮策略 ===
                        // 优先使用主要搜索文本，其次使用标题或内容查询
                        // 这样可以确保用户输入的内容能够被高亮显示
                        final highlightQuery =
                            state.currentQuery?.searchText ??
                            state.currentQuery?.titleQuery ??
                            state.currentQuery?.contentQuery;

                        return SearchedNodeItem(
                          node: node,
                          query: highlightQuery,
                          onTap: () {
                            // === 架构说明：位置转换 ===
                            // NodeAddEvent 的 position 参数约定为中心位置
                            // node.position 是 Node 模型的 position 字段（左上角位置）
                            // 需要将左上角位置转换为中心位置
                            final centerPosition = Offset(
                              node.position.dx + node.size.width / 2,
                              node.position.dy + node.size.height / 2,
                            );
                            context.read<GraphBloc>().add(
                              NodeAddEvent(node.id, position: centerPosition),
                            );
                            context.read<GraphBloc>().add(
                              NodeSelectEvent(node.id),
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
    ),
    );
  }

  String _getPresetDescription(SearchPreset preset) {
    final parts = <String>[];
    if (preset.titleQuery != null) parts.add('Title: ${preset.titleQuery}');
    if (preset.contentQuery != null) {
      parts.add('Content: ${preset.contentQuery}');
    }
    if (preset.tags != null && preset.tags!.isNotEmpty) {
      parts.add('Tags: ${preset.tags!.join(', ')}');
    }
    return parts.isEmpty ? 'No filters' : parts.join(' | ');
  }
}
