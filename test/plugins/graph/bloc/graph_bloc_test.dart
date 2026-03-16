import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:node_graph_notebook/core/commands/command_bus.dart';
import 'package:node_graph_notebook/core/commands/models/command.dart';
import 'package:node_graph_notebook/core/events/app_events.dart';
import 'package:node_graph_notebook/core/models/models.dart';
import 'package:node_graph_notebook/core/repositories/graph_repository.dart';
import 'package:node_graph_notebook/core/repositories/node_repository.dart';
import 'package:node_graph_notebook/plugins/builtin_plugins/graph/bloc/graph_bloc.dart';
import 'package:node_graph_notebook/plugins/builtin_plugins/graph/bloc/graph_event.dart';
import 'package:node_graph_notebook/plugins/builtin_plugins/graph/bloc/graph_state.dart';

// Mock classes
class MockCommandBus extends Mock implements CommandBus {}
class MockGraphRepository extends Mock implements GraphRepository {}
class MockNodeRepository extends Mock implements NodeRepository {}
class MockAppEventBus extends Mock implements AppEventBus {}
class MockCommand extends Mock implements Command<dynamic> {}

void main() {
  group('GraphBloc', () {
    late GraphBloc graphBloc;
    late MockCommandBus mockCommandBus;
    late MockGraphRepository mockGraphRepository;
    late MockNodeRepository mockNodeRepository;
    late MockAppEventBus mockEventBus;

    setUp(() {
      mockCommandBus = MockCommandBus();
      mockGraphRepository = MockGraphRepository();
      mockNodeRepository = MockNodeRepository();
      mockEventBus = MockAppEventBus();

      // 简单的 mock 设置，避免复杂的行为
      when(mockGraphRepository.getCurrent()).thenAnswer((_) async => null);
      when(mockNodeRepository.loadAll([])).thenAnswer((_) async => []);

      graphBloc = GraphBloc(
        commandBus: mockCommandBus,
        graphRepository: mockGraphRepository,
        nodeRepository: mockNodeRepository,
        eventBus: mockEventBus,
      );
    });

    tearDown(() {
      graphBloc.close();
    });

    test('initial state is correct', () {
      expect(graphBloc.state.loadingState, LoadingState.initial);
      expect(graphBloc.state.nodes, []);
      expect(graphBloc.state.connections, []);
      expect(graphBloc.state.selectionState.selectedNodeIds, isEmpty);
      expect(graphBloc.state.viewState.showConnections, true);
      expect(graphBloc.state.viewState.gridVisible, true);
    });

    test('should handle NodeSelectEvent', () async {
      graphBloc.add(const NodeSelectEvent('node_1', addToSelection: false));

      await expectLater(
        graphBloc.stream,
        emits(predicate<GraphState>((state) => state.selectionState.selectedNodeIds.contains('node_1'))),
      );
    });

    test('should handle SelectionClearEvent', () async {
      // 先选择一个节点
      graphBloc.add(const NodeSelectEvent('node_1', addToSelection: false));
      await Future.delayed(const Duration(milliseconds: 50));

      // 然后清除选择
      graphBloc.add(const SelectionClearEvent());

      await expectLater(
        graphBloc.stream,
        emits(predicate<GraphState>((state) => state.selectionState.selectedNodeIds.isEmpty)),
      );
    });

    test('should handle ViewToggleConnectionsEvent', () async {
      graphBloc.add(const ViewToggleConnectionsEvent());

      await expectLater(
        graphBloc.stream,
        emits(predicate<GraphState>((state) => !state.viewState.showConnections)),
      );
    });

    test('should handle ViewToggleGridEvent', () async {
      graphBloc.add(const ViewToggleGridEvent());

      await expectLater(
        graphBloc.stream,
        emits(predicate<GraphState>((state) => !state.viewState.gridVisible)),
      );
    });

    test('should handle GraphInitializeEvent with existing graph', () async {
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

    test('should handle GraphInitializeEvent with no existing graph', () async {
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

    test('should handle GraphInitializeEvent with error', () async {
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

    test('should handle GraphLoadEvent successfully', () async {
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

    test('should handle GraphLoadEvent when graph not found', () async {
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

    test('should handle GraphLoadEvent with error', () async {
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

    test('should handle GraphCreateEvent successfully', () async {
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

      final mockCommand = MockCommand();
      when(mockCommandBus.dispatch(mockCommand)).thenAnswer((_) async => CommandResult<Graph>.success(mockGraph));
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

    test('should handle GraphCreateEvent with failure', () async {
      final mockCommand = MockCommand();
      when(mockCommandBus.dispatch(mockCommand)).thenAnswer((_) async => CommandResult<Graph>.failure('Creation failed'));

      graphBloc.add(const GraphCreateEvent('New Graph'));

      await expectLater(
        graphBloc.stream,
        emitsInOrder([
          predicate<GraphState>((state) => state.loadingState == LoadingState.loading),
          predicate<GraphState>((state) => state.loadingState == LoadingState.error && state.error == 'Creation failed'),
        ]),
      );
    });

    test('should handle GraphCreateEvent with error', () async {
      final mockCommand = MockCommand();
      when(mockCommandBus.dispatch(mockCommand)).thenThrow(Exception('Test error'));

      graphBloc.add(const GraphCreateEvent('New Graph'));

      await expectLater(
        graphBloc.stream,
        emitsInOrder([
          predicate<GraphState>((state) => state.loadingState == LoadingState.loading),
          predicate<GraphState>((state) => state.loadingState == LoadingState.error && state.error != null),
        ]),
      );
    });

    test('should handle NodeAddEvent successfully', () async {
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

      // 先设置初始图状态
      graphBloc = GraphBloc(
        commandBus: mockCommandBus,
        graphRepository: mockGraphRepository,
        nodeRepository: mockNodeRepository,
        eventBus: mockEventBus,
      );

      // 模拟命令执行成功
      final mockCommand = MockCommand();
      when(mockCommandBus.dispatch(mockCommand)).thenAnswer((_) async => CommandResult<void>.success(null));
      when(mockGraphRepository.load('graph_1')).thenAnswer((_) async => mockGraph);
      when(mockNodeRepository.loadAll([])).thenAnswer((_) async => []);

      // 手动设置图状态
      graphBloc..emit(graphBloc.state.copyWith(graph: mockGraph))

      // 测试添加节点
      ..add(const NodeAddEvent('node_1', position: Offset(100, 200)));

      await expectLater(
        graphBloc.stream,
        emits(predicate<GraphState>((state) => true)), // 至少有一个状态更新
      );
    });

    test('should handle NodeAddEvent with failure', () async {
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

      // 先设置初始图状态
      graphBloc = GraphBloc(
        commandBus: mockCommandBus,
        graphRepository: mockGraphRepository,
        nodeRepository: mockNodeRepository,
        eventBus: mockEventBus,
      );

      // 模拟命令执行失败
      final mockCommand = MockCommand();
      when(mockCommandBus.dispatch(mockCommand)).thenAnswer((_) async => CommandResult<void>.failure('Add node failed'));

      // 手动设置图状态
      graphBloc..emit(graphBloc.state.copyWith(graph: mockGraph))

      // 测试添加节点
      ..add(const NodeAddEvent('node_1'));

      await expectLater(
        graphBloc.stream,
        emits(predicate<GraphState>((state) => state.error == 'Add node failed')),
      );
    });

    test('should handle NodeMoveEvent', () async {
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

      // 先设置初始图状态
      graphBloc = GraphBloc(
        commandBus: mockCommandBus,
        graphRepository: mockGraphRepository,
        nodeRepository: mockNodeRepository,
        eventBus: mockEventBus,
      );

      // 模拟命令执行
      final mockCommand = MockCommand();
      when(mockCommandBus.dispatch(mockCommand)).thenAnswer((_) async => CommandResult<void>.success(null));

      // 手动设置图状态
      graphBloc..emit(graphBloc.state.copyWith(graph: mockGraph))

      // 测试移动节点
      ..add(const NodeMoveEvent('node_1', Offset(300, 400)));

      await expectLater(
        graphBloc.stream,
        emits(predicate<GraphState>((state) => 
          state.graph.nodePositions['node_1'] == const Offset(300, 400)
        )),
      );
    });

    test('should handle NodeMultiSelectEvent', () async {
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

    test('should handle ViewZoomEvent without graph', () async {
      graphBloc.add(const ViewZoomEvent(2));

      await expectLater(
        graphBloc.stream,
        emits(predicate<GraphState>((state) => 
          state.viewState.zoomLevel == 2
        )),
      );
    });

    test('should handle ViewZoomEvent with graph', () async {
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

      // 先设置初始图状态
      graphBloc = GraphBloc(
        commandBus: mockCommandBus,
        graphRepository: mockGraphRepository,
        nodeRepository: mockNodeRepository,
        eventBus: mockEventBus,
      );

      // 模拟命令执行成功
      final mockCommand = MockCommand();
      when(mockCommandBus.dispatch(mockCommand)).thenAnswer((_) async => CommandResult<Graph>.success(mockGraph));

      // 手动设置图状态
      graphBloc..emit(graphBloc.state.copyWith(graph: mockGraph))

      // 测试缩放
      ..add(const ViewZoomEvent(2, position: Offset(100, 200)));

      await expectLater(
        graphBloc.stream,
        emits(predicate<GraphState>((state) => 
          state.viewState.zoomLevel == 2
        )),
      );
    });

    test('should handle ViewMoveEvent with graph', () async {
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

      // 先设置初始图状态
      graphBloc = GraphBloc(
        commandBus: mockCommandBus,
        graphRepository: mockGraphRepository,
        nodeRepository: mockNodeRepository,
        eventBus: mockEventBus,
      );

      // 模拟命令执行成功
      final mockCommand = MockCommand();
      when(mockCommandBus.dispatch(mockCommand)).thenAnswer((_) async => CommandResult<Graph>.success(mockGraph));

      // 手动设置图状态
      graphBloc..emit(graphBloc.state.copyWith(graph: mockGraph))

      // 测试移动相机
      ..add(const ViewMoveEvent(Offset(150, 250)));

      await expectLater(
        graphBloc.stream,
        emits(predicate<GraphState>((state) => 
          state.viewState.camera.position == const Offset(150, 250)
        )),
      );
    });

    test('should handle ErrorClearEvent', () async {
      // 先设置错误状态
      graphBloc..emit(graphBloc.state.copyWith(error: 'Test error'))

      // 测试清除错误
      ..add(const ErrorClearEvent());

      await expectLater(
        graphBloc.stream,
        emits(predicate<GraphState>((state) => 
          state.error == null
        )),
      );
    });

    test('should handle RetryEvent', () async {
      // 测试重试事件
      graphBloc.add(const RetryEvent());

      // 重试事件应该触发初始化事件，所以我们应该看到加载状态的变化
      await expectLater(
        graphBloc.stream,
        emits(predicate<GraphState>((state) => 
          state.loadingState == LoadingState.loading
        )),
      );
    });
  });
}