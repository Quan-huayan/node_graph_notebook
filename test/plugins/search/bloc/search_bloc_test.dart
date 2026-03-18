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
      if (!searchBloc.isClosed) {
        searchBloc.close();
      }
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

      await Future.delayed(const Duration(milliseconds: 100));

      searchBloc.add(const SearchPerformEvent(query));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(searchBloc.state.results.isEmpty, true);
      expect(searchBloc.state.currentQuery, query);
      expect(searchBloc.state.isLoading, false);
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

      await Future.delayed(const Duration(milliseconds: 100));

      const query = SearchQuery(searchText: 'test');
      searchBloc.add(const SearchPerformEvent(query));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(searchBloc.state.isLoading, false);
      expect(searchBloc.state.results.isNotEmpty, true);
      expect(searchBloc.state.results.any((n) => n.title.toLowerCase().contains('test')), true);
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

      await Future.delayed(const Duration(milliseconds: 100));

      const query = SearchQuery(titleQuery: 'test');
      searchBloc.add(const SearchPerformEvent(query));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(searchBloc.state.isLoading, false);
      expect(searchBloc.state.results.length, 1);
      expect(searchBloc.state.results.first.title.toLowerCase().contains('test'), true);
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

      await Future.delayed(const Duration(milliseconds: 100));

      const query = SearchQuery(contentQuery: 'test');
      searchBloc.add(const SearchPerformEvent(query));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(searchBloc.state.isLoading, false);
      expect(searchBloc.state.results.length, 1);
      expect(searchBloc.state.results.first.content!.toLowerCase().contains('test'), true);
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

      await Future.delayed(const Duration(milliseconds: 100));

      const query = SearchQuery(tags: ['important']);
      searchBloc.add(const SearchPerformEvent(query));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(searchBloc.state.isLoading, false);
      expect(searchBloc.state.results.length, 1);
      expect(searchBloc.state.results.first.content!.contains('#important'), true);
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

      await Future.delayed(const Duration(milliseconds: 100));

      const query = SearchQuery(isFolder: true);
      searchBloc.add(const SearchPerformEvent(query));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(searchBloc.state.isLoading, false);
      expect(searchBloc.state.results.length, 1);
      expect(searchBloc.state.results.first.isFolder, true);
    });

    test('should handle SearchPerformEvent with date filters', () async {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final dayBeforeYesterday = now.subtract(const Duration(days: 2));

      final nodes = <Node>[
        createTestNode(
          id: '1',
          title: 'Old Node',
        ).copyWith(createdAt: dayBeforeYesterday, updatedAt: dayBeforeYesterday),
        createTestNode(
          id: '2',
          title: 'New Node',
        ),
      ];

      when(mockNodeService.getAllNodes()).thenAnswer((_) async => nodes);

      await Future.delayed(const Duration(milliseconds: 100));

      final query = SearchQuery(createdAfter: yesterday);
      searchBloc.add(SearchPerformEvent(query));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(searchBloc.state.isLoading, false);
      expect(searchBloc.state.results.length, 1);
      expect(searchBloc.state.results.first.id, '2');
    });

    test('should handle SearchPerformEvent with error', () async {
      when(mockNodeService.getAllNodes()).thenThrow(Exception('Test error'));

      await Future.delayed(const Duration(milliseconds: 100));

      const query = SearchQuery(searchText: 'test');
      searchBloc.add(const SearchPerformEvent(query));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(searchBloc.state.isLoading, false);
      expect(searchBloc.state.error, isNotNull);
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

      await Future.delayed(const Duration(milliseconds: 100));

      searchBloc.add(const SearchLoadPresetsEvent());

      await Future.delayed(const Duration(milliseconds: 50));

      expect(searchBloc.state.presets.length, 2);
      expect(searchBloc.state.error, null);
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

    test('should handle SearchSavePresetEvent with failure', () async {
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

      searchBloc.close();
      searchBloc = SearchBloc(
        nodeService: mockNodeService,
        presetService: mockPresetService,
        commandBus: mockCommandBus,
      );

      await Future.delayed(const Duration(milliseconds: 100));

      searchBloc.add(SearchLoadPresetEvent(preset));

      await Future.delayed(const Duration(milliseconds: 500));

      expect(searchBloc.state.currentQuery?.titleQuery, 'test');
      expect(searchBloc.state.results.isNotEmpty, true);

      verify(mockPresetService.updateLastUsed('1')).called(1);
    });

    test('should handle SearchDeletePresetEvent successfully', () async {
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
      );

      await Future.delayed(const Duration(milliseconds: 100));

      searchBloc.add(const SearchDeletePresetEvent('1'));

      await Future.delayed(const Duration(milliseconds: 200));

      expect(searchBloc.state.presets.isEmpty, true);
      expect(searchBloc.state.error, null);
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

      await Future.delayed(const Duration(milliseconds: 100));

      searchBloc.add(const SearchDeletePresetEvent('1'));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(searchBloc.state.error, 'Delete failed');
    });

    test('should handle SearchClearEvent', () async {
      final nodes = <Node>[
        createTestNode(
          id: '1',
          title: 'Test Node',
        ),
      ];

      when(mockNodeService.getAllNodes()).thenAnswer((_) async => nodes);

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

    test('should handle case-insensitive search', () async {
      final nodes = <Node>[
        createTestNode(
          id: '1',
          title: 'TEST NODE',
          content: 'This is a test',
        ),
      ];

      when(mockNodeService.getAllNodes()).thenAnswer((_) async => nodes);

      await Future.delayed(const Duration(milliseconds: 100));

      const query = SearchQuery(searchText: 'test');
      searchBloc.add(const SearchPerformEvent(query));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(searchBloc.state.isLoading, false);
      expect(searchBloc.state.results.isNotEmpty, true);
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

      await Future.delayed(const Duration(milliseconds: 100));

      const query = SearchQuery(tags: ['important', 'urgent']);
      searchBloc.add(const SearchPerformEvent(query));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(searchBloc.state.isLoading, false);
      expect(searchBloc.state.results.length, 1);
      expect(searchBloc.state.results.first.id, '1');
    });
  });
}
