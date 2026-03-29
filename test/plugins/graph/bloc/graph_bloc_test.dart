import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:node_graph_notebook/core/commands/command_bus.dart';
import 'package:node_graph_notebook/core/commands/models/command.dart';
import 'package:node_graph_notebook/core/commands/models/command_context.dart';
import 'package:node_graph_notebook/core/models/models.dart';
import 'package:node_graph_notebook/core/repositories/graph_repository.dart';
import 'package:node_graph_notebook/core/repositories/node_repository.dart';
import 'package:node_graph_notebook/plugins/graph/bloc/graph_bloc.dart';
import 'package:node_graph_notebook/plugins/graph/bloc/graph_event.dart';
import 'package:node_graph_notebook/plugins/graph/bloc/graph_state.dart';

@GenerateMocks([CommandBus, GraphRepository, NodeRepository])
import 'graph_bloc_test.mocks.dart';

class TestCommand extends Command<void> {
  @override
  String get name => 'TestCommand';

  @override
  String get description => 'Test command description';

  @override
  Future<CommandResult<void>> execute(CommandContext context) async => CommandResult.success(null);
}

void main() {
  group('GraphBloc', () {
    late GraphBloc graphBloc;
    late MockCommandBus mockCommandBus;
    late MockGraphRepository mockGraphRepository;
    late MockNodeRepository mockNodeRepository;

    setUp(() {
      mockCommandBus = MockCommandBus();
      mockGraphRepository = MockGraphRepository();
      mockNodeRepository = MockNodeRepository();

      // Mock the eventStream
      when(mockCommandBus.eventStream).thenAnswer((_) => const Stream.empty());

      graphBloc = GraphBloc(
        commandBus: mockCommandBus,
        graphRepository: mockGraphRepository,
        nodeRepository: mockNodeRepository,
      );
    });

    tearDown(() {
      graphBloc.close();
    });

    test('初始状态正确', () {
      expect(graphBloc.state.loadingState, LoadingState.initial);
      expect(graphBloc.state.nodes, []);
      expect(graphBloc.state.connections, []);
      expect(graphBloc.state.selectionState.selectedNodeIds, isEmpty);
      expect(graphBloc.state.viewState.showConnections, true);
      expect(graphBloc.state.viewState.gridVisible, true);
    });

    test('应该处理节点选择事件', () async {
      graphBloc.add(const NodeSelectEvent('node_1', addToSelection: false));

      await expectLater(
        graphBloc.stream,
        emits(predicate<GraphState>((state) => state.selectionState.selectedNodeIds.contains('node_1'))),
      );
    });

    test('应该处理清除选择事件', () async {
      graphBloc.add(const NodeSelectEvent('node_1', addToSelection: false));
      await Future.delayed(const Duration(milliseconds: 50));

      graphBloc.add(const SelectionClearEvent());

      await expectLater(
        graphBloc.stream,
        emits(predicate<GraphState>((state) => state.selectionState.selectedNodeIds.isEmpty)),
      );
    });

    test('应该处理切换连接显示事件', () async {
      graphBloc.add(const ViewToggleConnectionsEvent());

      await expectLater(
        graphBloc.stream,
        emits(predicate<GraphState>((state) => !state.viewState.showConnections)),
      );
    });

    test('应该处理切换网格显示事件', () async {
      graphBloc.add(const ViewToggleGridEvent());

      await expectLater(
        graphBloc.stream,
        emits(predicate<GraphState>((state) => !state.viewState.gridVisible)),
      );
    });

    test('应该处理存在图的初始化事件', () async {
      final mockGraph = Graph(
        id: 'graph_1',
        name: 'Test Graph',
        nodeIds: [],
        viewConfig: const GraphViewConfig(
          camera: Camera(x: 0, y: 0, zoom: 1, centerWidth: 0, centerHeight: 0),
          autoLayoutEnabled: false,
          backgroundStyle: BackgroundStyle.grid,
          layoutAlgorithm: LayoutAlgorithm.forceDirected,
          showConnectionLines: true,
        ),
        nodePositions: {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      when(mockGraphRepository.getCurrent()).thenAnswer((_) async => mockGraph);
      when(mockNodeRepository.loadAll([])).thenAnswer((_) async => []);

      graphBloc.add(const GraphInitializeEvent());

      await expectLater(
        graphBloc.stream,
        emitsInOrder([
          predicate<GraphState>((state) => state.loadingState == LoadingState.loading),
          predicate<GraphState>((state) => state.loadingState == LoadingState.loaded && state.graph.id == 'graph_1'),
        ]),
      );
    });

    test('应该处理无图的初始化事件', () async {
      when(mockGraphRepository.getCurrent()).thenAnswer((_) async => null);

      graphBloc.add(const GraphInitializeEvent());

      await expectLater(
        graphBloc.stream,
        emitsInOrder([
          predicate<GraphState>((state) => state.loadingState == LoadingState.loading),
          predicate<GraphState>((state) => state.loadingState == LoadingState.loaded),
        ]),
      );
    });

    test('应该处理初始化错误事件', () async {
      when(mockGraphRepository.getCurrent()).thenThrow(Exception('Test error'));

      graphBloc.add(const GraphInitializeEvent());

      await expectLater(
        graphBloc.stream,
        emitsInOrder([
          predicate<GraphState>((state) => state.loadingState == LoadingState.loading),
          predicate<GraphState>((state) => state.loadingState == LoadingState.error && state.error != null),
        ]),
      );
    });

    test('应该成功处理图加载事件', () async {
      final mockGraph = Graph(
        id: 'graph_1',
        name: 'Test Graph',
        nodeIds: [],
        viewConfig: const GraphViewConfig(
          camera: Camera(x: 0, y: 0, zoom: 1, centerWidth: 0, centerHeight: 0),
          autoLayoutEnabled: false,
          backgroundStyle: BackgroundStyle.grid,
          layoutAlgorithm: LayoutAlgorithm.forceDirected,
          showConnectionLines: true,
        ),
        nodePositions: {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      when(mockGraphRepository.load('graph_1')).thenAnswer((_) async => mockGraph);
      when(mockNodeRepository.loadAll([])).thenAnswer((_) async => []);

      graphBloc.add(const GraphLoadEvent('graph_1'));

      await expectLater(
        graphBloc.stream,
        emitsInOrder([
          predicate<GraphState>((state) => state.loadingState == LoadingState.loading),
          predicate<GraphState>((state) => state.loadingState == LoadingState.loaded && state.graph.id == 'graph_1'),
        ]),
      );
    });

    test('图未找到时应该处理加载事件', () async {
      when(mockGraphRepository.load('non_existent')).thenAnswer((_) async => null);

      graphBloc.add(const GraphLoadEvent('non_existent'));

      await expectLater(
        graphBloc.stream,
        emitsInOrder([
          predicate<GraphState>((state) => state.loadingState == LoadingState.loading),
          predicate<GraphState>((state) => state.loadingState == LoadingState.error && state.error != null),
        ]),
      );
    });

    test('应该处理加载错误事件', () async {
      when(mockGraphRepository.load('graph_1')).thenThrow(Exception('Test error'));

      graphBloc.add(const GraphLoadEvent('graph_1'));

      await expectLater(
        graphBloc.stream,
        emitsInOrder([
          predicate<GraphState>((state) => state.loadingState == LoadingState.loading),
          predicate<GraphState>((state) => state.loadingState == LoadingState.error && state.error != null),
        ]),
      );
    });

    test('应该成功处理图创建事件', () async {
      final mockGraph = Graph(
        id: 'graph_1',
        name: 'New Graph',
        nodeIds: [],
        viewConfig: const GraphViewConfig(
          camera: Camera(x: 0, y: 0, zoom: 1, centerWidth: 0, centerHeight: 0),
          autoLayoutEnabled: false,
          backgroundStyle: BackgroundStyle.grid,
          layoutAlgorithm: LayoutAlgorithm.forceDirected,
          showConnectionLines: true,
        ),
        nodePositions: {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      when(mockCommandBus.dispatch<Graph>(argThat(isA<Command<Graph>>()))).thenAnswer((_) async => CommandResult<Graph>.success(mockGraph));
      when(mockGraphRepository.load('graph_1')).thenAnswer((_) async => mockGraph);
      when(mockNodeRepository.loadAll([])).thenAnswer((_) async => []);

      graphBloc.add(const GraphCreateEvent('New Graph'));

      await expectLater(
        graphBloc.stream,
        emitsInOrder([
          predicate<GraphState>((state) => state.loadingState == LoadingState.loading),
          predicate<GraphState>((state) => state.loadingState == LoadingState.loaded && state.graph.id == 'graph_1'),
        ]),
      );
    });

    test('应该处理图创建失败事件', () async {
      when(mockCommandBus.dispatch<Graph>(argThat(isA<Command<Graph>>()))).thenAnswer((_) async => CommandResult<Graph>.failure('Creation failed'));

      graphBloc.add(const GraphCreateEvent('New Graph'));

      await expectLater(
        graphBloc.stream,
        emitsInOrder([
          predicate<GraphState>((state) => state.loadingState == LoadingState.loading),
          predicate<GraphState>((state) => state.loadingState == LoadingState.error && state.error == 'Creation failed'),
        ]),
      );
    });

    test('应该处理图创建错误事件', () async {
      when(mockCommandBus.dispatch<Graph>(argThat(isA<Command<Graph>>()))).thenThrow(Exception('Test error'));

      graphBloc.add(const GraphCreateEvent('New Graph'));

      await expectLater(
        graphBloc.stream,
        emitsInOrder([
          predicate<GraphState>((state) => state.loadingState == LoadingState.loading),
          predicate<GraphState>((state) => state.loadingState == LoadingState.error && state.error != null),
        ]),
      );
    });

    test('应该成功处理节点添加事件', () async {
      final mockGraph = Graph(
        id: 'graph_1',
        name: 'Test Graph',
        nodeIds: [],
        viewConfig: const GraphViewConfig(
          camera: Camera(x: 0, y: 0, zoom: 1, centerWidth: 0, centerHeight: 0),
          autoLayoutEnabled: false,
          backgroundStyle: BackgroundStyle.grid,
          layoutAlgorithm: LayoutAlgorithm.forceDirected,
          showConnectionLines: true,
        ),
        nodePositions: {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      graphBloc.emit(graphBloc.state.copyWith(graph: mockGraph));

      when(mockCommandBus.dispatch<void>(argThat(isA<Command<void>>()))).thenAnswer((_) async => CommandResult<void>.success(null));

      graphBloc.add(const NodeAddEvent('node_1', position: Offset(100, 200)));

      await expectLater(
        graphBloc.stream,
        emits(predicate<GraphState>((state) => true)),
      );
    });

    test('应该处理节点添加失败事件', () async {
      final mockGraph = Graph(
        id: 'graph_1',
        name: 'Test Graph',
        nodeIds: [],
        viewConfig: const GraphViewConfig(
          camera: Camera(x: 0, y: 0, zoom: 1, centerWidth: 0, centerHeight: 0),
          autoLayoutEnabled: false,
          backgroundStyle: BackgroundStyle.grid,
          layoutAlgorithm: LayoutAlgorithm.forceDirected,
          showConnectionLines: true,
        ),
        nodePositions: {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      graphBloc.emit(graphBloc.state.copyWith(graph: mockGraph));

      when(mockCommandBus.dispatch<void>(argThat(isA<Command<void>>()))).thenAnswer((_) async => CommandResult<void>.failure('Add node failed'));

      graphBloc.add(const NodeAddEvent('node_1'));

      await expectLater(
        graphBloc.stream,
        emits(predicate<GraphState>((state) => state.error == 'Add node failed')),
      );
    });

    test('应该处理节点移动事件', () async {
      final mockGraph = Graph(
        id: 'graph_1',
        name: 'Test Graph',
        nodeIds: ['node_1'],
        viewConfig: const GraphViewConfig(
          camera: Camera(x: 0, y: 0, zoom: 1, centerWidth: 0, centerHeight: 0),
          autoLayoutEnabled: false,
          backgroundStyle: BackgroundStyle.grid,
          layoutAlgorithm: LayoutAlgorithm.forceDirected,
          showConnectionLines: true,
        ),
        nodePositions: {'node_1': const Offset(100, 200)},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      graphBloc.emit(graphBloc.state.copyWith(graph: mockGraph));

      when(mockCommandBus.dispatch<void>(argThat(isA<Command<void>>()))).thenAnswer((_) async => CommandResult<void>.success(null));

      graphBloc.add(const NodeMoveEvent('node_1', Offset(300, 400)));

      await expectLater(
        graphBloc.stream,
        emits(predicate<GraphState>((state) => 
          state.graph.nodePositions['node_1'] == const Offset(300, 400)
        )),
      );
    });

    test('应该处理节点多选事件', () async {
      final nodeIds = {'node_1', 'node_2', 'node_3'};

      graphBloc.add(NodeMultiSelectEvent(nodeIds));

      await expectLater(
        graphBloc.stream,
        emits(predicate<GraphState>((state) => 
          state.selectionState.selectedNodeIds.containsAll(nodeIds) &&
          state.selectionState.selectionMode == SelectionMode.multi
        )),
      );
    });

    test('应该处理无图时的视图缩放事件', () async {
      graphBloc.add(const ViewZoomEvent(2));

      await expectLater(
        graphBloc.stream,
        emits(predicate<GraphState>((state) => 
          state.viewState.zoomLevel == 2
        )),
      );
    });

    test('应该处理有图时的视图缩放事件', () async {
      final mockGraph = Graph(
        id: 'graph_1',
        name: 'Test Graph',
        nodeIds: [],
        viewConfig: const GraphViewConfig(
          camera: Camera(x: 0, y: 0, zoom: 1, centerWidth: 0, centerHeight: 0),
          autoLayoutEnabled: false,
          backgroundStyle: BackgroundStyle.grid,
          layoutAlgorithm: LayoutAlgorithm.forceDirected,
          showConnectionLines: true,
        ),
        nodePositions: {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      graphBloc.emit(graphBloc.state.copyWith(graph: mockGraph));

      when(mockCommandBus.dispatch<Graph>(argThat(isA<Command<Graph>>()))).thenAnswer((_) async => CommandResult<Graph>.success(mockGraph));

      graphBloc.add(const ViewZoomEvent(2, position: Offset(100, 200)));

      await expectLater(
        graphBloc.stream,
        emits(predicate<GraphState>((state) => 
          state.viewState.zoomLevel == 2
        )),
      );
    });

    test('应该处理有图时的视图移动事件', () async {
      final mockGraph = Graph(
        id: 'graph_1',
        name: 'Test Graph',
        nodeIds: [],
        viewConfig: const GraphViewConfig(
          camera: Camera(x: 0, y: 0, zoom: 1, centerWidth: 0, centerHeight: 0),
          autoLayoutEnabled: false,
          backgroundStyle: BackgroundStyle.grid,
          layoutAlgorithm: LayoutAlgorithm.forceDirected,
          showConnectionLines: true,
        ),
        nodePositions: {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      graphBloc.emit(graphBloc.state.copyWith(graph: mockGraph));

      when(mockCommandBus.dispatch<Graph>(argThat(isA<Command<Graph>>()))).thenAnswer((_) async => CommandResult<Graph>.success(mockGraph));

      graphBloc.add(const ViewMoveEvent(Offset(150, 250)));

      await expectLater(
        graphBloc.stream,
        emits(predicate<GraphState>((state) => 
          state.viewState.camera.position == const Offset(150, 250)
        )),
      );
    });

    test('应该处理错误清除事件', () async {
      graphBloc..emit(graphBloc.state.copyWith(error: 'Test error'))

      ..add(const ErrorClearEvent());

      await expectLater(
        graphBloc.stream,
        emits(predicate<GraphState>((state) => 
          state.error == null
        )),
      );
    });

    test('应该处理重试事件', () async {
      when(mockGraphRepository.getCurrent()).thenAnswer((_) async => null);

      graphBloc.add(const RetryEvent());

      await expectLater(
        graphBloc.stream,
        emits(predicate<GraphState>((state) => 
          state.loadingState == LoadingState.loading
        )),
      );
    });
  });
}
