import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:node_graph_notebook/core/cqrs/commands/command_bus.dart';
import 'package:node_graph_notebook/core/cqrs/commands/models/command.dart';
import 'package:node_graph_notebook/core/cqrs/queries/advanced_search_query.dart';
import 'package:node_graph_notebook/core/cqrs/query/query.dart';
import 'package:node_graph_notebook/core/cqrs/query/query_bus.dart';
import 'package:node_graph_notebook/core/models/enums.dart';
import 'package:node_graph_notebook/core/models/node.dart';
import 'package:node_graph_notebook/plugins/graph/service/node_service.dart';
import 'package:node_graph_notebook/plugins/search/bloc/search_bloc.dart';
import 'package:node_graph_notebook/plugins/search/bloc/search_event.dart';
import 'package:node_graph_notebook/plugins/search/model/search_preset_model.dart';
import 'package:node_graph_notebook/plugins/search/model/search_query.dart';
import 'package:node_graph_notebook/plugins/search/service/search_preset_service.dart';

@GenerateMocks([
  NodeService,
  SearchPresetService,
  CommandBus,
  QueryBus,
])
import 'search_bloc_test.mocks.dart';

Node createTestNode({
  required String id,
  required String title,
  String? content,
  Map<String, dynamic>? metadata,
}) => Node(
    id: id,
    title: title,
    content: content,
    references: const {},
    position: const Offset(0, 0),
    size: const Size(100, 100),
    viewMode: NodeViewMode.titleOnly,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    metadata: metadata ?? {},
  );

void main() {
  group('SearchBloc', () {
    late SearchBloc searchBloc;
    late MockNodeService mockNodeService;
    late MockSearchPresetService mockPresetService;
    late MockCommandBus mockCommandBus;
    late MockQueryBus mockQueryBus;

    setUp(() {
      mockNodeService = MockNodeService();
      mockPresetService = MockSearchPresetService();
      mockCommandBus = MockCommandBus();
      mockQueryBus = MockQueryBus();

      when(mockPresetService.getAllPresets()).thenAnswer((_) async => []);
      when(mockCommandBus.dispatch(any)).thenAnswer(
        (_) async => CommandResult.success(null),
      );
      when(mockQueryBus.dispatch(any)).thenAnswer(
        (_) async => QueryResult.success([]),
      );

      searchBloc = SearchBloc(
        nodeService: mockNodeService,
        presetService: mockPresetService,
        commandBus: mockCommandBus,
        queryBus: mockQueryBus,
      );
    });

    tearDown(() {
      if (!searchBloc.isClosed) {
        searchBloc.close();
      }
    });

    test('初始状态正确', () {
      expect(searchBloc.state.results, isEmpty);
      expect(searchBloc.state.presets, isEmpty);
      expect(searchBloc.state.isLoading, false);
      expect(searchBloc.state.isSavingPreset, false);
      expect(searchBloc.state.currentQuery, null);
      expect(searchBloc.state.error, null);
    });

    test('初始化时应加载预设', () async {
      final presets = [
        SearchPreset(
          id: '1',
          name: 'Test Preset',
          createdAt: DateTime.now(),
        ),
      ];

      when(mockPresetService.getAllPresets()).thenAnswer((_) async => presets);

      searchBloc = SearchBloc(
        nodeService: mockNodeService,
        presetService: mockPresetService,
        commandBus: mockCommandBus,
        queryBus: mockQueryBus,
      );

      await Future.delayed(const Duration(milliseconds: 50));

      expect(searchBloc.state.presets, equals(presets));
    });

    test('处理空查询的 SearchPerformEvent', () async {
      const query = SearchQuery(searchText: '');

      await Future.delayed(const Duration(milliseconds: 100));

      searchBloc.add(const SearchPerformEvent(query));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(searchBloc.state.results.isEmpty, true);
      expect(searchBloc.state.currentQuery, query);
      expect(searchBloc.state.isLoading, false);
    });

    test('处理带 searchText 的 SearchPerformEvent', () async {
      final nodes = <Node>[
        createTestNode(
          id: '1',
          title: 'Test Node',
          content: 'This is a test content',
        ),
        createTestNode(
          id: '2',
          title: 'Another Node',
          content: 'Different content',
        ),
      ];

      // 创建新的 SearchBloc，使用正确配置的 mock
      // 使用 AdvancedSearchQuery 作为类型参数
      when(mockQueryBus.dispatch<List<Node>, AdvancedSearchQuery>(any)).thenAnswer(
        (_) async => QueryResult<List<Node>>.success(nodes),
      );

      searchBloc.close();
      searchBloc = SearchBloc(
        nodeService: mockNodeService,
        presetService: mockPresetService,
        commandBus: mockCommandBus,
        queryBus: mockQueryBus,
      );

      await Future.delayed(const Duration(milliseconds: 100));

      const query = SearchQuery(searchText: 'test');
      searchBloc.add(const SearchPerformEvent(query));

      await Future.delayed(const Duration(milliseconds: 100));

      expect(searchBloc.state.isLoading, false);
      expect(searchBloc.state.results.isNotEmpty, true);
      expect(searchBloc.state.results.any((n) => n.title.toLowerCase().contains('test')), true);
    });

    test('处理带 titleQuery 的 SearchPerformEvent', () async {
      final nodes = <Node>[
        createTestNode(
          id: '1',
          title: 'Test Node',
          content: 'Some content',
        ),
      ];

      // 模拟 QueryBus 返回过滤后的结果
      when(mockQueryBus.dispatch<List<Node>, AdvancedSearchQuery>(any)).thenAnswer(
        (_) async => QueryResult<List<Node>>.success(nodes),
      );

      searchBloc.close();
      searchBloc = SearchBloc(
        nodeService: mockNodeService,
        presetService: mockPresetService,
        commandBus: mockCommandBus,
        queryBus: mockQueryBus,
      );

      await Future.delayed(const Duration(milliseconds: 100));

      const query = SearchQuery(titleQuery: 'test');
      searchBloc.add(const SearchPerformEvent(query));

      await Future.delayed(const Duration(milliseconds: 100));

      expect(searchBloc.state.isLoading, false);
      expect(searchBloc.state.results.length, 1);
      expect(searchBloc.state.results.first.title.toLowerCase().contains('test'), true);
    });

    test('处理带 contentQuery 的 SearchPerformEvent', () async {
      final nodes = <Node>[
        createTestNode(
          id: '1',
          title: 'Node One',
          content: 'This is a test',
        ),
      ];

      // 模拟 QueryBus 返回过滤后的结果
      when(mockQueryBus.dispatch<List<Node>, AdvancedSearchQuery>(any)).thenAnswer(
        (_) async => QueryResult<List<Node>>.success(nodes),
      );

      searchBloc.close();
      searchBloc = SearchBloc(
        nodeService: mockNodeService,
        presetService: mockPresetService,
        commandBus: mockCommandBus,
        queryBus: mockQueryBus,
      );

      await Future.delayed(const Duration(milliseconds: 100));

      const query = SearchQuery(contentQuery: 'test');
      searchBloc.add(const SearchPerformEvent(query));

      await Future.delayed(const Duration(milliseconds: 100));

      expect(searchBloc.state.isLoading, false);
      expect(searchBloc.state.results.length, 1);
      expect(searchBloc.state.results.first.content!.toLowerCase().contains('test'), true);
    });

    test('处理带 tags 的 SearchPerformEvent', () async {
      final nodes = <Node>[
        createTestNode(
          id: '1',
          title: 'Node One',
          content: 'This has #important tag',
        ),
      ];

      // 模拟 QueryBus 返回过滤后的结果
      when(mockQueryBus.dispatch<List<Node>, AdvancedSearchQuery>(any)).thenAnswer(
        (_) async => QueryResult<List<Node>>.success(nodes),
      );

      searchBloc.close();
      searchBloc = SearchBloc(
        nodeService: mockNodeService,
        presetService: mockPresetService,
        commandBus: mockCommandBus,
        queryBus: mockQueryBus,
      );

      await Future.delayed(const Duration(milliseconds: 100));

      const query = SearchQuery(tags: ['important']);
      searchBloc.add(const SearchPerformEvent(query));

      await Future.delayed(const Duration(milliseconds: 100));

      expect(searchBloc.state.isLoading, false);
      expect(searchBloc.state.results.length, 1);
      expect(searchBloc.state.results.first.content!.contains('#important'), true);
    });

    test('处理带 isFolder 过滤器的 SearchPerformEvent', () async {
      final nodes = <Node>[
        createTestNode(
          id: '1',
          title: 'Folder',
          metadata: {'isFolder': true},
        ),
      ];

      // 模拟 QueryBus 返回过滤后的结果
      when(mockQueryBus.dispatch<List<Node>, AdvancedSearchQuery>(any)).thenAnswer(
        (_) async => QueryResult<List<Node>>.success(nodes),
      );

      searchBloc.close();
      searchBloc = SearchBloc(
        nodeService: mockNodeService,
        presetService: mockPresetService,
        commandBus: mockCommandBus,
        queryBus: mockQueryBus,
      );

      await Future.delayed(const Duration(milliseconds: 100));

      const query = SearchQuery(isFolder: true);
      searchBloc.add(const SearchPerformEvent(query));

      await Future.delayed(const Duration(milliseconds: 100));

      expect(searchBloc.state.isLoading, false);
      expect(searchBloc.state.results.length, 1);
      expect(searchBloc.state.results.first.isFolder, true);
    });

    test('处理带日期过滤器的 SearchPerformEvent', () async {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      final nodes = <Node>[
        createTestNode(
          id: '2',
          title: 'New Node',
        ),
      ];

      // 模拟 QueryBus 返回过滤后的结果
      when(mockQueryBus.dispatch<List<Node>, AdvancedSearchQuery>(any)).thenAnswer(
        (_) async => QueryResult<List<Node>>.success(nodes),
      );

      searchBloc.close();
      searchBloc = SearchBloc(
        nodeService: mockNodeService,
        presetService: mockPresetService,
        commandBus: mockCommandBus,
        queryBus: mockQueryBus,
      );

      await Future.delayed(const Duration(milliseconds: 100));

      final query = SearchQuery(createdAfter: yesterday);
      searchBloc.add(SearchPerformEvent(query));

      await Future.delayed(const Duration(milliseconds: 100));

      expect(searchBloc.state.isLoading, false);
      expect(searchBloc.state.results.length, 1);
      expect(searchBloc.state.results.first.id, '2');
    });

    test('处理出错的 SearchPerformEvent', () async {
      when(mockNodeService.getAllNodes()).thenThrow(Exception('Test error'));

      await Future.delayed(const Duration(milliseconds: 100));

      const query = SearchQuery(searchText: 'test');
      searchBloc.add(const SearchPerformEvent(query));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(searchBloc.state.isLoading, false);
      expect(searchBloc.state.error, isNotNull);
    });

    test('处理 SearchLoadPresetsEvent', () async {
      final presets = [
        SearchPreset(
          id: '1',
          name: 'Preset 1',
          createdAt: DateTime.now(),
        ),
        SearchPreset(
          id: '2',
          name: 'Preset 2',
          createdAt: DateTime.now(),
        ),
      ];

      when(mockPresetService.getAllPresets()).thenAnswer((_) async => presets);

      await Future.delayed(const Duration(milliseconds: 100));

      searchBloc.add(const SearchLoadPresetsEvent());

      await Future.delayed(const Duration(milliseconds: 50));

      expect(searchBloc.state.presets.length, 2);
      expect(searchBloc.state.error, null);
    });

    test('成功处理 SearchSavePresetEvent', () async {
      const query = SearchQuery(
        titleQuery: 'test',
        contentQuery: 'content',
        tags: ['tag1'],
      );

      final savedPreset = SearchPreset(
        id: '1',
        name: 'Test Preset',
        titleQuery: 'test',
        contentQuery: 'content',
        tags: ['tag1'],
        createdAt: DateTime.now(),
        lastUsed: DateTime.now(),
      );

      var callCount = 0;
      when(mockPresetService.getAllPresets()).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) {
          return [];
        } else {
          return [savedPreset];
        }
      });
      when(mockCommandBus.dispatch(any)).thenAnswer((invocation) async => CommandResult<SearchPreset>.success(savedPreset));

      searchBloc.close();
      searchBloc = SearchBloc(
        nodeService: mockNodeService,
        presetService: mockPresetService,
        commandBus: mockCommandBus,
        queryBus: mockQueryBus,
      );

      await Future.delayed(const Duration(milliseconds: 200));

      searchBloc.add(const SearchSavePresetEvent('Test Preset', query));

      await Future.delayed(const Duration(milliseconds: 300));

      expect(searchBloc.state.isSavingPreset, false);
      expect(searchBloc.state.presets.length, 1);
      expect(searchBloc.state.presets.first.id, '1');
      expect(searchBloc.state.presets.first.name, 'Test Preset');
      expect(searchBloc.state.error, null);
    });

    test('处理失败的 SearchSavePresetEvent', () async {
      const query = SearchQuery(searchText: 'test');

      when(mockCommandBus.dispatch(any)).thenAnswer(
        (_) async => CommandResult<SearchPreset>.failure('Save failed'),
      );

      await Future.delayed(const Duration(milliseconds: 100));

      searchBloc.add(const SearchSavePresetEvent('Test Preset', query));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(searchBloc.state.isSavingPreset, false);
      expect(searchBloc.state.error, 'Save failed');
    });

    test('处理 SearchLoadPresetEvent', () async {
      final preset = SearchPreset(
        id: '1',
        name: 'Test Preset',
        titleQuery: 'test',
        createdAt: DateTime.now(),
      );

      final nodes = <Node>[
        createTestNode(
          id: '1',
          title: 'test node',
        ),
      ];

      when(mockPresetService.updateLastUsed('1')).thenAnswer((_) async {});
      // 模拟 QueryBus 返回过滤后的结果
      when(mockQueryBus.dispatch<List<Node>, AdvancedSearchQuery>(any)).thenAnswer(
        (_) async => QueryResult<List<Node>>.success(nodes),
      );

      searchBloc.close();
      searchBloc = SearchBloc(
        nodeService: mockNodeService,
        presetService: mockPresetService,
        commandBus: mockCommandBus,
        queryBus: mockQueryBus,
      );

      await Future.delayed(const Duration(milliseconds: 100));

      searchBloc.add(SearchLoadPresetEvent(preset));

      await Future.delayed(const Duration(milliseconds: 500));

      expect(searchBloc.state.currentQuery?.titleQuery, 'test');
      expect(searchBloc.state.results.isNotEmpty, true);

      verify(mockPresetService.updateLastUsed('1')).called(1);
    });

    test('成功处理 SearchDeletePresetEvent', () async {
      final preset = SearchPreset(
        id: '1',
        name: 'Test Preset',
        createdAt: DateTime.now(),
      );

      var callCount = 0;
      when(mockPresetService.getAllPresets()).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) {
          return [preset];
        } else {
          return [];
        }
      });
      when(mockCommandBus.dispatch(any)).thenAnswer(
        (_) async => CommandResult.success(null),
      );

      searchBloc.close();
      searchBloc = SearchBloc(
        nodeService: mockNodeService,
        presetService: mockPresetService,
        commandBus: mockCommandBus,
        queryBus: mockQueryBus,
      );

      await Future.delayed(const Duration(milliseconds: 100));

      searchBloc.add(const SearchDeletePresetEvent('1'));

      await Future.delayed(const Duration(milliseconds: 200));

      expect(searchBloc.state.presets.isEmpty, true);
      expect(searchBloc.state.error, null);
    });

    test('处理失败的 SearchDeletePresetEvent', () async {
      final preset = SearchPreset(
        id: '1',
        name: 'Test Preset',
        createdAt: DateTime.now(),
      );

      when(mockPresetService.getAllPresets()).thenAnswer((_) async => [preset]);
      when(mockCommandBus.dispatch(any)).thenAnswer(
        (_) async => CommandResult.failure('Delete failed'),
      );

      await Future.delayed(const Duration(milliseconds: 100));

      searchBloc.add(const SearchDeletePresetEvent('1'));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(searchBloc.state.error, 'Delete failed');
    });

    test('处理 SearchClearEvent', () async {
      final nodes = <Node>[
        createTestNode(
          id: '1',
          title: 'Test Node',
        ),
      ];

      // 模拟 QueryBus 返回过滤后的结果
      when(mockQueryBus.dispatch<List<Node>, AdvancedSearchQuery>(any)).thenAnswer(
        (_) async => QueryResult<List<Node>>.success(nodes),
      );

      searchBloc.close();
      searchBloc = SearchBloc(
        nodeService: mockNodeService,
        presetService: mockPresetService,
        commandBus: mockCommandBus,
        queryBus: mockQueryBus,
      );

      await Future.delayed(const Duration(milliseconds: 100));

      const query = SearchQuery(searchText: 'test');
      searchBloc.add(const SearchPerformEvent(query));

      await Future.delayed(const Duration(milliseconds: 100));

      searchBloc.add(const SearchClearEvent());

      await Future.delayed(const Duration(milliseconds: 50));

      expect(searchBloc.state.results.isEmpty, true);
      expect(searchBloc.state.currentQuery, null);
      expect(searchBloc.state.error, null);
    });

    test('处理不区分大小写的搜索', () async {
      final nodes = <Node>[
        createTestNode(
          id: '1',
          title: 'TEST NODE',
          content: 'This is a test',
        ),
      ];

      // 模拟 QueryBus 返回过滤后的结果
      when(mockQueryBus.dispatch<List<Node>, AdvancedSearchQuery>(any)).thenAnswer(
        (_) async => QueryResult<List<Node>>.success(nodes),
      );

      searchBloc.close();
      searchBloc = SearchBloc(
        nodeService: mockNodeService,
        presetService: mockPresetService,
        commandBus: mockCommandBus,
        queryBus: mockQueryBus,
      );

      await Future.delayed(const Duration(milliseconds: 100));

      const query = SearchQuery(searchText: 'test');
      searchBloc.add(const SearchPerformEvent(query));

      await Future.delayed(const Duration(milliseconds: 100));

      expect(searchBloc.state.isLoading, false);
      expect(searchBloc.state.results.isNotEmpty, true);
    });

    test('处理多标签过滤', () async {
      final nodes = <Node>[
        createTestNode(
          id: '1',
          title: 'Node One',
          content: 'Has #important and #urgent tags',
        ),
      ];

      // 模拟 QueryBus 返回过滤后的结果
      when(mockQueryBus.dispatch<List<Node>, AdvancedSearchQuery>(any)).thenAnswer(
        (_) async => QueryResult<List<Node>>.success(nodes),
      );

      searchBloc.close();
      searchBloc = SearchBloc(
        nodeService: mockNodeService,
        presetService: mockPresetService,
        commandBus: mockCommandBus,
        queryBus: mockQueryBus,
      );

      await Future.delayed(const Duration(milliseconds: 100));

      const query = SearchQuery(tags: ['important', 'urgent']);
      searchBloc.add(const SearchPerformEvent(query));

      await Future.delayed(const Duration(milliseconds: 100));

      expect(searchBloc.state.isLoading, false);
      expect(searchBloc.state.results.length, 1);
      expect(searchBloc.state.results.first.id, '1');
    });
  });
}
