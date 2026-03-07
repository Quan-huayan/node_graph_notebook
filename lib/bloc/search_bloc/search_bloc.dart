import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:node_graph_notebook/bloc/blocs.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/node.dart';
import '../../core/services/node_service.dart';
import '../../core/services/search_preset_service.dart';
import '../../ui/models/search_preset_model.dart';
import '../../ui/models/search_query.dart';

/// 搜索 BLoC
class SearchBloc extends Bloc<SearchEvent, SearchState> {
  SearchBloc({
    required NodeService nodeService,
    required SearchPresetService presetService,
  })  : _nodeService = nodeService,
        _presetService = presetService,
        _uuid = const Uuid(),
        super(SearchState.initial()) {
    on<SearchPerformEvent>(_onPerformSearch);
    on<SearchLoadPresetsEvent>(_onLoadPresets);
    on<SearchSavePresetEvent>(_onSavePreset);
    on<SearchLoadPresetEvent>(_onLoadPreset);
    on<SearchDeletePresetEvent>(_onDeletePreset);
    on<SearchClearEvent>(_onClear);

    // 加载预设列表
    add(const SearchLoadPresetsEvent());
  }

  final NodeService _nodeService;
  final SearchPresetService _presetService;
  final Uuid _uuid;

  /// 执行搜索
  Future<void> _onPerformSearch(
    SearchPerformEvent event,
    Emitter<SearchState> emit,
  ) async {
    final query = event.query;

    // 如果是空查询，清除结果
    if (query.isEmpty) {
      emit(state.copyWith(
        results: [],
        currentQuery: query,
        isLoading: false,
        error: null,
      ));
      return;
    }

    emit(state.copyWith(
      isLoading: true,
      currentQuery: query,
      error: null,
    ));

    try {
      // 构建搜索字符串
      final searchParts = <String>[];
      if (query.searchText != null && query.searchText!.isNotEmpty) {
        searchParts.add(query.searchText!);
      }
      if (query.titleQuery != null && query.titleQuery!.isNotEmpty) {
        searchParts.add('title:${query.titleQuery}');
      }
      if (query.contentQuery != null && query.contentQuery!.isNotEmpty) {
        searchParts.add('content:${query.contentQuery}');
      }
      if (query.tags != null && query.tags!.isNotEmpty) {
        for (final tag in query.tags!) {
          searchParts.add('tag:$tag');
        }
      }

      final allNodes = await _nodeService.getAllNodes();

      // 过滤节点
      final results = allNodes.where((node) {
        // 标题过滤
        if (query.titleQuery != null && query.titleQuery!.isNotEmpty) {
          if (!node.title.toLowerCase().contains(query.titleQuery!.toLowerCase())) {
            return false;
          }
        }

        // 内容过滤
        if (query.contentQuery != null && query.contentQuery!.isNotEmpty) {
          final content = node.content ?? '';
          if (!content.toLowerCase().contains(query.contentQuery!.toLowerCase())) {
            return false;
          }
        }

        // 通用搜索文本过滤
        if (query.searchText != null && query.searchText!.isNotEmpty) {
          final searchLower = query.searchText!.toLowerCase();
          final titleMatch = node.title.toLowerCase().contains(searchLower);
          final contentMatch = (node.content ?? '').toLowerCase().contains(searchLower);
          if (!titleMatch && !contentMatch) {
            return false;
          }
        }

        // 标签过滤
        if (query.tags != null && query.tags!.isNotEmpty) {
          final nodeTags = _extractTags(node);
          final hasAllTags = query.tags!.every((tag) => nodeTags.contains(tag));
          if (!hasAllTags) {
            return false;
          }
        }

        // 文件夹过滤
        if (query.isFolder != null) {
          if (node.isFolder != query.isFolder) {
            return false;
          }
        }

        // 日期过滤
        if (query.createdAfter != null) {
          if (node.createdAt.isBefore(query.createdAfter!)) {
            return false;
          }
        }
        if (query.createdBefore != null) {
          if (node.createdAt.isAfter(query.createdBefore!)) {
            return false;
          }
        }

        return true;
      }).toList();

      emit(state.copyWith(
        results: results,
        isLoading: false,
        error: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
    }
  }

  /// 加载预设列表
  Future<void> _onLoadPresets(
    SearchLoadPresetsEvent event,
    Emitter<SearchState> emit,
  ) async {
    try {
      final presets = await _presetService.getAllPresets();
      emit(state.copyWith(
        presets: presets,
        error: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        error: e.toString(),
      ));
    }
  }

  /// 保存预设
  Future<void> _onSavePreset(
    SearchSavePresetEvent event,
    Emitter<SearchState> emit,
  ) async {
    emit(state.copyWith(isSavingPreset: true));

    try {
      final preset = SearchPreset(
        id: _uuid.v4(),
        name: event.name,
        titleQuery: event.query.titleQuery,
        contentQuery: event.query.contentQuery,
        tags: event.query.tags,
        createdAt: DateTime.now(),
        lastUsed: DateTime.now(),
      );

      await _presetService.savePreset(preset);

      // 重新加载预设列表
      final presets = await _presetService.getAllPresets();

      emit(state.copyWith(
        presets: presets,
        isSavingPreset: false,
        error: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        isSavingPreset: false,
        error: e.toString(),
      ));
    }
  }

  /// 加载预设
  Future<void> _onLoadPreset(
    SearchLoadPresetEvent event,
    Emitter<SearchState> emit,
  ) async {
    // 更新预设的最后使用时间
    await _presetService.updateLastUsed(event.preset.id);

    // 构建查询并执行搜索
    final query = SearchQuery(
      titleQuery: event.preset.titleQuery,
      contentQuery: event.preset.contentQuery,
      tags: event.preset.tags,
    );

    add(SearchPerformEvent(query));
  }

  /// 删除预设
  Future<void> _onDeletePreset(
    SearchDeletePresetEvent event,
    Emitter<SearchState> emit,
  ) async {
    try {
      await _presetService.deletePreset(event.id);

      // 重新加载预设列表
      final presets = await _presetService.getAllPresets();

      emit(state.copyWith(
        presets: presets,
        error: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        error: e.toString(),
      ));
    }
  }

  /// 清除搜索
  void _onClear(
    SearchClearEvent event,
    Emitter<SearchState> emit,
  ) {
    emit(state.copyWith(
      results: [],
      currentQuery: null,
      error: null,
    ));
  }

  /// 从节点内容中提取标签
  Set<String> _extractTags(Node node) {
    final tags = <String>{};
    final content = node.content ?? '';

    // 提取 #tag 格式的标签
    final tagRegex = RegExp(r'#(\w+)');
    for (final match in tagRegex.allMatches(content)) {
      tags.add(match.group(1)!);
    }

    // 也可以从元数据中提取标签
    final metadataTags = node.metadata['tags'];
    if (metadataTags is List<String>) {
      tags.addAll(metadataTags);
    }

    return tags;
  }
}
