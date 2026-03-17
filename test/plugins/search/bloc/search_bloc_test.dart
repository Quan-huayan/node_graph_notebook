import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:node_graph_notebook/core/commands/command_bus.dart';
import 'package:node_graph_notebook/core/commands/models/command.dart';
import 'package:node_graph_notebook/core/models/enums.dart';
import 'package:node_graph_notebook/core/models/node.dart';
import 'package:node_graph_notebook/plugins/graph/service/node_service.dart';
import 'package:node_graph_notebook/plugins/search/bloc/search_bloc.dart';
import 'package:node_graph_notebook/plugins/search/bloc/search_event.dart';
import 'package:node_graph_notebook/plugins/search/bloc/search_state.dart';
import 'package:node_graph_notebook/plugins/search/model/search_preset_model.dart';
import 'package:node_graph_notebook/plugins/search/model/search_query.dart';
import 'package:node_graph_notebook/plugins/search/service/search_preset_service.dart';

@GenerateMocks([
  NodeService,
  SearchPresetService,
  CommandBus,
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

    setUp(() {
      mockNodeService = MockNodeService();
      mockPresetService = MockSearchPresetService();
      mockCommandBus = MockCommandBus();

      when(mockPresetService.getAllPresets()).thenAnswer((_) async => []);
      when(mockCommandBus.dispatch(any)).thenAnswer(
        (_) async => CommandResult.success(null),
      );

      searchBloc = SearchBloc(
        nodeService: mockNodeService,
        presetService: mockPresetService,
        commandBus: mockCommandBus,
      );
    });

    tearDown(() {
      searchBloc.close();
    });

    test('initial state is correct', () {
      expect(searchBloc.state.results, isEmpty);
      expect(searchBloc.state.presets, isEmpty);
      expect(searchBloc.state.isLoading, false);
      expect(searchBloc.state.isSavingPreset, false);
      expect(searchBloc.state.currentQuery, null);
      expect(searchBloc.state.error, null);
    });

    test('should load presets on initialization', () async {
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
      );

      await Future.delayed(const Duration(milliseconds: 50));

      expect(searchBloc.state.presets, equals(presets));
    });

    test('should handle SearchPerformEvent with empty query', () async {
      const query = SearchQuery(searchText: '');

      searchBloc.add(const SearchPerformEvent(query));

      await expectLater(
        searchBloc.stream,
        emits(
          predicate<SearchState>((state) =>
              state.results.isEmpty &&
              state.currentQuery == query &&
              !state.isLoading),
        ),
      );
    });

    test('should handle SearchPerformEvent with searchText', () async {
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

      when(mockNodeService.getAllNodes()).thenAnswer((_) async => nodes);

      const query = SearchQuery(searchText: 'test');
      searchBloc.add(const SearchPerformEvent(query));

      await expectLater(
        searchBloc.stream,
        emitsInOrder([
          predicate<SearchState>((state) => state.isLoading),
          predicate<SearchState>((state) =>
              !state.isLoading &&
              state.results.isNotEmpty &&
              state.results.any((n) => n.title.contains('test'))),
        ]),
      );
    });

    test('should handle SearchPerformEvent with titleQuery', () async {
      final nodes = <Node>[
        createTestNode(
          id: '1',
          title: 'Test Node',
          content: 'Some content',
        ),
        createTestNode(
          id: '2',
          title: 'Another Node',
          content: 'Test content',
        ),
      ];

      when(mockNodeService.getAllNodes()).thenAnswer((_) async => nodes);

      const query = SearchQuery(titleQuery: 'test');
      searchBloc.add(const SearchPerformEvent(query));

      await expectLater(
        searchBloc.stream,
        emitsInOrder([
          predicate<SearchState>((state) => state.isLoading),
          predicate<SearchState>((state) =>
              !state.isLoading &&
              state.results.length == 1 &&
              state.results.first.title.toLowerCase().contains('test')),
        ]),
      );
    });

    test('should handle SearchPerformEvent with contentQuery', () async {
      final nodes = <Node>[
        createTestNode(
          id: '1',
          title: 'Node One',
          content: 'This is a test',
        ),
        createTestNode(
          id: '2',
          title: 'Node Two',
          content: 'No match here',
        ),
      ];

      when(mockNodeService.getAllNodes()).thenAnswer((_) async => nodes);

      const query = SearchQuery(contentQuery: 'test');
      searchBloc.add(const SearchPerformEvent(query));

      await expectLater(
        searchBloc.stream,
        emitsInOrder([
          predicate<SearchState>((state) => state.isLoading),
          predicate<SearchState>((state) =>
              !state.isLoading &&
              state.results.length == 1 &&
              state.results.first.content!.toLowerCase().contains('test')),
        ]),
      );
    });

    test('should handle SearchPerformEvent with tags', () async {
      final nodes = <Node>[
        createTestNode(
          id: '1',
          title: 'Node One',
          content: 'This has #important tag',
        ),
        createTestNode(
          id: '2',
          title: 'Node Two',
          content: 'This has #urgent tag',
        ),
      ];

      when(mockNodeService.getAllNodes()).thenAnswer((_) async => nodes);

      const query = SearchQuery(tags: ['important']);
      searchBloc.add(const SearchPerformEvent(query));

      await expectLater(
        searchBloc.stream,
        emitsInOrder([
          predicate<SearchState>((state) => state.isLoading),
          predicate<SearchState>((state) =>
              !state.isLoading &&
              state.results.length == 1 &&
              state.results.first.content!.contains('#important')),
        ]),
      );
    });

    test('should handle SearchPerformEvent with isFolder filter', () async {
      final nodes = <Node>[
        createTestNode(
          id: '1',
          title: 'Folder',
          metadata: {'isFolder': true},
        ),
        createTestNode(
          id: '2',
          title: 'File',
          metadata: {'isFolder': false},
        ),
      ];

      when(mockNodeService.getAllNodes()).thenAnswer((_) async => nodes);

      const query = SearchQuery(isFolder: true);
      searchBloc.add(const SearchPerformEvent(query));

      await expectLater(
        searchBloc.stream,
        emitsInOrder([
          predicate<SearchState>((state) => state.isLoading),
          predicate<SearchState>((state) =>
              !state.isLoading &&
              state.results.length == 1 &&
              state.results.first.isFolder),
        ]),
      );
    });

    test('should handle SearchPerformEvent with date filters', () async {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      final nodes = <Node>[
        createTestNode(
          id: '1',
          title: 'Old Node',
        ).copyWith(createdAt: yesterday, updatedAt: yesterday),
        createTestNode(
          id: '2',
          title: 'New Node',
        ),
      ];

      when(mockNodeService.getAllNodes()).thenAnswer((_) async => nodes);

      final query = SearchQuery(createdAfter: yesterday);
      searchBloc.add(SearchPerformEvent(query));

      await expectLater(
        searchBloc.stream,
        emitsInOrder([
          predicate<SearchState>((state) => state.isLoading),
          predicate<SearchState>((state) =>
              !state.isLoading &&
              state.results.length == 1 &&
              state.results.first.id == '2'),
        ]),
      );
    });

    test('should handle SearchPerformEvent with error', () async {
      when(mockNodeService.getAllNodes()).thenThrow(Exception('Test error'));

      const query = SearchQuery(searchText: 'test');
      searchBloc.add(const SearchPerformEvent(query));

      await expectLater(
        searchBloc.stream,
        emitsInOrder([
          predicate<SearchState>((state) => state.isLoading),
          predicate<SearchState>((state) =>
              !state.isLoading && state.error != null),
        ]),
      );
    });

    test('should handle SearchLoadPresetsEvent', () async {
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

      searchBloc.add(const SearchLoadPresetsEvent());

      await expectLater(
        searchBloc.stream,
        emits(
          predicate<SearchState>((state) =>
              state.presets.length == 2 && state.error == null),
        ),
      );
    });

    test('should handle SearchSavePresetEvent successfully', () async {
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

      when(mockCommandBus.dispatch(any)).thenAnswer(
        (_) async => CommandResult.success(savedPreset),
      );
      when(mockPresetService.getAllPresets()).thenAnswer((_) async => [savedPreset]);

      searchBloc.add(const SearchSavePresetEvent('Test Preset', query));

      await expectLater(
        searchBloc.stream,
        emitsInOrder([
          predicate<SearchState>((state) => state.isSavingPreset),
          predicate<SearchState>((state) =>
              !state.isSavingPreset &&
              state.presets.contains(savedPreset) &&
              state.error == null),
        ]),
      );
    });

    test('should handle SearchSavePresetEvent with failure', () async {
      const query = SearchQuery(searchText: 'test');

      when(mockCommandBus.dispatch(any)).thenAnswer(
        (_) async => CommandResult.failure('Save failed'),
      );

      searchBloc.add(const SearchSavePresetEvent('Test Preset', query));

      await expectLater(
        searchBloc.stream,
        emitsInOrder([
          predicate<SearchState>((state) => state.isSavingPreset),
          predicate<SearchState>((state) =>
              !state.isSavingPreset && state.error == 'Save failed'),
        ]),
      );
    });

    test('should handle SearchLoadPresetEvent', () async {
      final preset = SearchPreset(
        id: '1',
        name: 'Test Preset',
        titleQuery: 'test',
        createdAt: DateTime.now(),
      );

      when(mockPresetService.updateLastUsed('1')).thenAnswer((_) async {});
      when(mockNodeService.getAllNodes()).thenAnswer((_) async => [
            createTestNode(
              id: '1',
              title: 'test node',
            ),
          ]);

      searchBloc.add(SearchLoadPresetEvent(preset));

      await expectLater(
        searchBloc.stream,
        emits(
          predicate<SearchState>((state) =>
              state.currentQuery?.titleQuery == 'test' &&
              state.results.isNotEmpty),
        ),
      );

      verify(mockPresetService.updateLastUsed('1')).called(1);
    });

    test('should handle SearchDeletePresetEvent successfully', () async {
      final preset = SearchPreset(
        id: '1',
        name: 'Test Preset',
        createdAt: DateTime.now(),
      );

      when(mockPresetService.getAllPresets()).thenAnswer((_) async => [preset]);
      when(mockCommandBus.dispatch(any)).thenAnswer(
        (_) async => CommandResult.success(null),
      );

      searchBloc.add(const SearchDeletePresetEvent('1'));

      await expectLater(
        searchBloc.stream,
        emits(
          predicate<SearchState>((state) =>
              state.presets.isEmpty && state.error == null),
        ),
      );
    });

    test('should handle SearchDeletePresetEvent with failure', () async {
      final preset = SearchPreset(
        id: '1',
        name: 'Test Preset',
        createdAt: DateTime.now(),
      );

      when(mockPresetService.getAllPresets()).thenAnswer((_) async => [preset]);
      when(mockCommandBus.dispatch(any)).thenAnswer(
        (_) async => CommandResult.failure('Delete failed'),
      );

      searchBloc.add(const SearchDeletePresetEvent('1'));

      await expectLater(
        searchBloc.stream,
        emits(
          predicate<SearchState>((state) => state.error == 'Delete failed'),
        ),
      );
    });

    test('should handle SearchClearEvent', () async {
      final nodes = <Node>[
        createTestNode(
          id: '1',
          title: 'Test Node',
        ),
      ];

      when(mockNodeService.getAllNodes()).thenAnswer((_) async => nodes);

      const query = SearchQuery(searchText: 'test');
      searchBloc.add(const SearchPerformEvent(query));

      await Future.delayed(const Duration(milliseconds: 50));

      searchBloc.add(const SearchClearEvent());

      await expectLater(
        searchBloc.stream,
        emits(
          predicate<SearchState>((state) =>
              state.results.isEmpty &&
              state.currentQuery == null &&
              state.error == null),
        ),
      );
    });

    test('should handle case-insensitive search', () async {
      final nodes = <Node>[
        createTestNode(
          id: '1',
          title: 'TEST NODE',
          content: 'This is a test',
        ),
      ];

      when(mockNodeService.getAllNodes()).thenAnswer((_) async => nodes);

      const query = SearchQuery(searchText: 'test');
      searchBloc.add(const SearchPerformEvent(query));

      await expectLater(
        searchBloc.stream,
        emits(
          predicate<SearchState>((state) =>
              !state.isLoading && state.results.isNotEmpty),
        ),
      );
    });

    test('should handle multiple tag filtering', () async {
      final nodes = <Node>[
        createTestNode(
          id: '1',
          title: 'Node One',
          content: 'Has #important and #urgent tags',
        ),
        createTestNode(
          id: '2',
          title: 'Node Two',
          content: 'Has #important tag only',
        ),
      ];

      when(mockNodeService.getAllNodes()).thenAnswer((_) async => nodes);

      const query = SearchQuery(tags: ['important', 'urgent']);
      searchBloc.add(const SearchPerformEvent(query));

      await expectLater(
        searchBloc.stream,
        emits(
          predicate<SearchState>((state) =>
              !state.isLoading &&
              state.results.length == 1 &&
              state.results.first.id == '1'),
        ),
      );
    });
  });
}
