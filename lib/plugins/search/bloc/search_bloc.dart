import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/cqrs/queries/advanced_search_query.dart';
import '../../../../core/cqrs/query/query_bus.dart';
import '../../../../core/models/node.dart';
import '../../../core/cqrs/commands/command_bus.dart';
import '../../graph/service/node_service.dart';
import '../command/search_commands.dart';
import '../model/search_query.dart';
import '../service/search_preset_service.dart';
import 'search_event.dart';
import 'search_state.dart';

/// 搜索 BLoC
class SearchBloc extends Bloc<SearchEvent, SearchState> {
  /// 创建搜索 BLoC
  ///
  /// [nodeService] - 节点服务（用于获取所有节点）
  /// [presetService] - 搜索预设服务
  /// [commandBus] - 命令总线
  /// [queryBus] - 查询总线（用于复杂搜索查询）
  SearchBloc({
    required NodeService nodeService,
    required SearchPresetService presetService,
    required CommandBus commandBus,
    required QueryBus queryBus,
  }) : _nodeService = nodeService,
       _presetService = presetService,
       _commandBus = commandBus,
       _queryBus = queryBus,
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

  // ignore: unused_field
  final NodeService _nodeService;
  final SearchPresetService _presetService;
  final CommandBus _commandBus;
  final QueryBus _queryBus;

  /// 执行搜索
  Future<void> _onPerformSearch(
    SearchPerformEvent event,
    Emitter<SearchState> emit,
  ) async {
    final query = event.query;

    // 如果是空查询，清除结果
    if (query.isEmpty) {
      emit(
        state.copyWith(
          results: [],
          currentQuery: query,
          isLoading: false,
          error: null,
        ),
      );
      return;
    }

    emit(state.copyWith(isLoading: true, currentQuery: query, error: null));

    try {
      // 通过 QueryBus 执行复杂搜索查询
      final result = await _queryBus.dispatch<List<Node>, AdvancedSearchQuery>(
        AdvancedSearchQuery(
          searchText: query.searchText,
          titleQuery: query.titleQuery,
          contentQuery: query.contentQuery,
          tags: query.tags,
          isFolder: query.isFolder,
          createdAfter: query.createdAfter,
          createdBefore: query.createdBefore,
          limit: 100,
        ),
      );

      if (result.isSuccess) {
        emit(state.copyWith(
          results: result.data ?? [],
          isLoading: false,
          error: null,
        ));
      } else {
        emit(state.copyWith(
          isLoading: false,
          error: result.error,
        ));
      }
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  /// 加载预设列表
  Future<void> _onLoadPresets(
    SearchLoadPresetsEvent event,
    Emitter<SearchState> emit,
  ) async {
    try {
      final presets = await _presetService.getAllPresets();
      emit(state.copyWith(presets: presets, error: null));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  /// 保存预设
  Future<void> _onSavePreset(
    SearchSavePresetEvent event,
    Emitter<SearchState> emit,
  ) async {
    emit(state.copyWith(isSavingPreset: true));

    try {
      // 写操作：通过 CommandBus
      final command = SaveSearchPresetCommand(
        presetName: event.name,
        titleQuery: event.query.titleQuery,
        contentQuery: event.query.contentQuery,
        tags: event.query.tags,
      );
      final result = await _commandBus.dispatch(command);

      if (result.isSuccess) {
        // 重新加载预设列表
        final presets = await _presetService.getAllPresets();

        emit(
          state.copyWith(presets: presets, isSavingPreset: false, error: null),
        );
      } else {
        emit(state.copyWith(isSavingPreset: false, error: result.error));
      }
    } catch (e) {
      emit(state.copyWith(isSavingPreset: false, error: e.toString()));
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
      // 写操作：通过 CommandBus
      final command = DeleteSearchPresetCommand(id: event.id);
      final result = await _commandBus.dispatch(command);

      if (result.isSuccess) {
        // 重新加载预设列表
        final presets = await _presetService.getAllPresets();

        emit(state.copyWith(presets: presets, error: null));
      } else {
        emit(state.copyWith(error: result.error));
      }
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  /// 清除搜索
  void _onClear(SearchClearEvent event, Emitter<SearchState> emit) {
    emit(SearchState(
      results: const [],
      presets: state.presets,
      isLoading: false,
      isSavingPreset: state.isSavingPreset,
      currentQuery: null,
      error: null,
    ));
  }
}
