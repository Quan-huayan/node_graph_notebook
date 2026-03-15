import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:node_graph_notebook/core/models/models.dart';
import 'package:node_graph_notebook/core/services/graph_service.dart';
import 'package:node_graph_notebook/core/repositories/graph_repository.dart';
import 'package:node_graph_notebook/core/repositories/node_repository.dart';
import 'package:node_graph_notebook/core/events/app_events.dart';
import 'package:node_graph_notebook/bloc/graph/graph_bloc.dart';
import 'package:node_graph_notebook/bloc/graph/graph_event.dart';
import 'package:node_graph_notebook/bloc/graph/graph_state.dart';
import 'package:node_graph_notebook/core/commands/command_bus.dart';
import '../../test_helpers.dart';

@GenerateNiceMocks([
  MockSpec<GraphService>(),
  MockSpec<GraphRepository>(),
  MockSpec<NodeRepository>(),
  MockSpec<CommandBus>(),
])
import 'graph_bloc_test.mocks.dart';

void main() {
  late MockGraphService mockGraphService;
  late MockGraphRepository mockGraphRepository;
  late MockNodeRepository mockNodeRepository;
  late MockCommandBus mockCommandBus;
  late AppEventBus eventBus;
  late GraphBloc graphBloc;

  setUp(() {
    mockGraphService = MockGraphService();
    mockGraphRepository = MockGraphRepository();
    mockNodeRepository = MockNodeRepository();
    mockCommandBus = MockCommandBus();
    eventBus = AppEventBus.createForTest();
    graphBloc = GraphBloc(
      commandBus: mockCommandBus,
      graphRepository: mockGraphRepository,
      nodeRepository: mockNodeRepository,
      eventBus: eventBus,
    );
  });

  tearDown(() {
    graphBloc.close();
    eventBus.dispose();
  });

  group('GraphBloc', () {
    // === 初始化测试 ===
    group('Initialization', () {
      test('initial state should be GraphState.initial()', () {
        // 检查初始状态的各个属性，而不是完全相等
        // 因为 DateTime.now() 会导致每次 GraphState.initial() 创建不同的对象
        expect(graphBloc.state.graph.id, isEmpty);
        expect(graphBloc.state.graph.name, isEmpty);
        expect(graphBloc.state.nodes, isEmpty);
        expect(graphBloc.state.connections, isEmpty);
        expect(graphBloc.state.selectedNodeIds, isEmpty);
        expect(graphBloc.state.loadingState, LoadingState.initial);
        expect(graphBloc.state.error, isNull);
      });

      blocTest<GraphBloc, GraphState>(
        'should initialize current graph',
        build: () {
          final graph = Graph(
            id: 'graph-1',
            name: 'Test Graph',
            nodeIds: ['node-1', 'node-2'],
            nodePositions: const {},
            viewConfig: GraphViewConfig.defaultConfig,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          final nodes = [
            NodeTestHelpers.test(id: 'node-1', title: 'Node 1', content: 'Content 1'),
            NodeTestHelpers.test(id: 'node-2', title: 'Node 2', content: 'Content 2'),
          ];

          when(mockGraphService.getCurrentGraph()).thenAnswer((_) async => graph);
          when(mockGraphService.getGraphNodes('graph-1')).thenAnswer((_) async => nodes);
          return graphBloc;
        },
        act: (bloc) => bloc.add(const GraphInitializeEvent()),
        expect: () => [
          predicate<GraphState>((s) => s.loadingState == LoadingState.loading),
          predicate<GraphState>((s) =>
              s.graph.id == 'graph-1' &&
              s.nodes.length == 2 &&
              s.loadingState == LoadingState.loaded),
        ],
        verify: (_) {
          verify(mockGraphService.getCurrentGraph()).called(1);
          verify(mockGraphService.getGraphNodes('graph-1')).called(1);
        },
      );
    });

    // === 节点数据同步测试（通过事件总线） ===
    group('Node Data Sync via Event Bus', () {
      blocTest<GraphBloc, GraphState>(
        'should update nodes when NodeDataChangedEvent is published (update action)',
        setUp: () {
          final graph = Graph(
            id: 'graph-1',
            name: 'Test Graph',
            nodeIds: ['node-1', 'node-2'],
            nodePositions: const {},
            viewConfig: GraphViewConfig.defaultConfig,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          final originalNodes = [
            NodeTestHelpers.test(id: 'node-1', title: 'Original Title 1', content: 'Original Content 1'),
            NodeTestHelpers.test(id: 'node-2', title: 'Original Title 2', content: 'Original Content 2'),
          ];

          when(mockGraphService.getCurrentGraph()).thenAnswer((_) async => graph);
          when(mockGraphService.getGraphNodes('graph-1')).thenAnswer((_) async => originalNodes);
        },
        build: () => graphBloc,
        seed: () {
          // 初始化图状态
          final graph = Graph(
            id: 'graph-1',
            name: 'Test Graph',
            nodeIds: ['node-1', 'node-2'],
            nodePositions: const {},
            viewConfig: GraphViewConfig.defaultConfig,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          final originalNodes = [
            NodeTestHelpers.test(id: 'node-1', title: 'Original Title 1', content: 'Original Content 1'),
            NodeTestHelpers.test(id: 'node-2', title: 'Original Title 2', content: 'Original Content 2'),
          ];

          return graphBloc.state.copyWith(
            graph: graph,
            nodes: originalNodes,
            loadingState: LoadingState.loaded,
          );
        },
        act: (bloc) async {
          // 发布节点更新事件
          final updatedNode = NodeTestHelpers.test(
            id: 'node-1',
            title: 'Updated Title 1',
            content: 'Updated Content 1',
          );

          eventBus.publish(NodeDataChangedEvent(
            changedNodes: [updatedNode],
            action: DataChangeAction.update,
          ));

          // 等待事件处理
          await Future.delayed(const Duration(milliseconds: 50));
        },
        expect: () => [
          predicate<GraphState>((s) =>
              s.nodes.length == 2 &&
              s.nodes.where((n) => n.id == 'node-1').first.title == 'Updated Title 1' &&
              s.nodes.where((n) => n.id == 'node-2').first.title == 'Original Title 2'),
        ],
      );

      blocTest<GraphBloc, GraphState>(
        'should remove nodes when NodeDataChangedEvent is published (delete action)',
        setUp: () {
          final graph = Graph(
            id: 'graph-1',
            name: 'Test Graph',
            nodeIds: ['node-1', 'node-2'],
            nodePositions: const {},
            viewConfig: GraphViewConfig.defaultConfig,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          final originalNodes = [
            NodeTestHelpers.test(id: 'node-1', title: 'Node 1', content: 'Content 1'),
            NodeTestHelpers.test(id: 'node-2', title: 'Node 2', content: 'Content 2'),
          ];

          when(mockGraphService.getCurrentGraph()).thenAnswer((_) async => graph);
          when(mockGraphService.getGraphNodes('graph-1')).thenAnswer((_) async => originalNodes);
        },
        build: () => graphBloc,
        seed: () {
          final graph = Graph(
            id: 'graph-1',
            name: 'Test Graph',
            nodeIds: ['node-1', 'node-2'],
            nodePositions: const {},
            viewConfig: GraphViewConfig.defaultConfig,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          final originalNodes = [
            NodeTestHelpers.test(id: 'node-1', title: 'Node 1', content: 'Content 1'),
            NodeTestHelpers.test(id: 'node-2', title: 'Node 2', content: 'Content 2'),
          ];

          return graphBloc.state.copyWith(
            graph: graph,
            nodes: originalNodes,
            loadingState: LoadingState.loaded,
          );
        },
        act: (bloc) async {
          final deletedNode = NodeTestHelpers.test(
            id: 'node-1',
            title: 'Node 1',
            content: 'Content 1',
          );

          eventBus.publish(NodeDataChangedEvent(
            changedNodes: [deletedNode],
            action: DataChangeAction.delete,
          ));

          await Future.delayed(const Duration(milliseconds: 50));
        },
        expect: () => [
          predicate<GraphState>((s) =>
              s.nodes.length == 1 &&
              s.nodes.first.id == 'node-2'),
        ],
      );

      blocTest<GraphBloc, GraphState>(
        'should ignore NodeDataChangedEvent for nodes not in current graph',
        setUp: () {
          final graph = Graph(
            id: 'graph-1',
            name: 'Test Graph',
            nodeIds: ['node-1'],
            nodePositions: const {},
            viewConfig: GraphViewConfig.defaultConfig,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          final originalNodes = [
            NodeTestHelpers.test(id: 'node-1', title: 'Node 1', content: 'Content 1'),
          ];

          when(mockGraphService.getCurrentGraph()).thenAnswer((_) async => graph);
          when(mockGraphService.getGraphNodes('graph-1')).thenAnswer((_) async => originalNodes);
        },
        build: () => graphBloc,
        seed: () {
          final graph = Graph(
            id: 'graph-1',
            name: 'Test Graph',
            nodeIds: ['node-1'],
            nodePositions: const {},
            viewConfig: GraphViewConfig.defaultConfig,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          final originalNodes = [
            NodeTestHelpers.test(id: 'node-1', title: 'Node 1', content: 'Content 1'),
          ];

          return graphBloc.state.copyWith(
            graph: graph,
            nodes: originalNodes,
            loadingState: LoadingState.loaded,
          );
        },
        act: (bloc) async {
          final otherNode = NodeTestHelpers.test(
            id: 'node-999',
            title: 'Other Node',
            content: 'Other Content',
          );

          eventBus.publish(NodeDataChangedEvent(
            changedNodes: [otherNode],
            action: DataChangeAction.update,
          ));

          await Future.delayed(const Duration(milliseconds: 50));
        },
        expect: () => [], // 不应该有状态变化
        verify: (_) {
          expect(graphBloc.state.nodes.length, 1);
        },
      );
    });

    // === 节点选择测试 ===
    group('Node Selection', () {
      blocTest<GraphBloc, GraphState>(
        'should select single node',
        build: () => graphBloc,
        act: (bloc) => bloc.add(const NodeSelectEvent('node-1')),
        expect: () => [
          predicate<GraphState>((s) =>
              s.selectedNodeIds.length == 1 &&
              s.selectedNodeIds.contains('node-1') &&
              s.selectionState.selectionMode == SelectionMode.single),
        ],
      );

      blocTest<GraphBloc, GraphState>(
        'should select multiple nodes with addToSelection',
        seed: () {
          return graphBloc.state.copyWith(
            selectionState: graphBloc.state.selectionState.copyWith(
              selectedNodeIds: {'node-1'},
            ),
          );
        },
        build: () => graphBloc,
        act: (bloc) => bloc.add(const NodeSelectEvent('node-2', addToSelection: true)),
        expect: () => [
          predicate<GraphState>((s) =>
              s.selectedNodeIds.length == 2 &&
              s.selectedNodeIds.contains('node-1') &&
              s.selectedNodeIds.contains('node-2') &&
              s.selectionState.selectionMode == SelectionMode.multi),
        ],
      );

      blocTest<GraphBloc, GraphState>(
        'should clear selection',
        seed: () {
          return graphBloc.state.copyWith(
            selectionState: graphBloc.state.selectionState.copyWith(
              selectedNodeIds: {'node-1', 'node-2'},
            ),
          );
        },
        build: () => graphBloc,
        act: (bloc) => bloc.add(const SelectionClearEvent()),
        expect: () => [
          predicate<GraphState>((s) => s.selectedNodeIds.isEmpty),
        ],
      );
    });

    // === 节点移动测试 ===
    group('Node Movement', () {
      blocTest<GraphBloc, GraphState>(
        'should move single node',
        setUp: () {
          final graph = Graph(
            id: 'graph-1',
            name: 'Test Graph',
            nodeIds: ['node-1'],
            nodePositions: const {'node-1': Offset(100, 100)},
            viewConfig: GraphViewConfig.defaultConfig,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          final updatedGraph = graph.copyWith(
            nodePositions: {'node-1': const Offset(200, 200)},
          );

          when(mockGraphService.updateGraph(
            any,
            nodePositions: anyNamed('nodePositions'),
          )).thenAnswer((_) async => updatedGraph);
        },
        seed: () {
          final graph = Graph(
            id: 'graph-1',
            name: 'Test Graph',
            nodeIds: ['node-1'],
            nodePositions: const {'node-1': Offset(100, 100)},
            viewConfig: GraphViewConfig.defaultConfig,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          final nodes = [
            NodeTestHelpers.test(id: 'node-1', title: 'Node 1', content: 'Content 1'),
          ];

          return GraphState(
            graph: graph,
            nodes: nodes,
            connections: const [],
            selectionState: const SelectionState(),
            viewState: const ViewState(),
            loadingState: LoadingState.loaded,
          );
        },
        build: () => graphBloc,
        act: (bloc) => bloc.add(const NodeMoveEvent('node-1', Offset(200, 200))),
        expect: () => [
          predicate<GraphState>((s) =>
              s.graph.id == 'graph-1' &&
              s.graph.nodePositions['node-1'] == const Offset(200, 200)),
        ],
      );

      blocTest<GraphBloc, GraphState>(
        'should move multiple nodes',
        setUp: () {
          final graph = Graph(
            id: 'graph-1',
            name: 'Test Graph',
            nodeIds: ['node-1', 'node-2'],
            nodePositions: const {
              'node-1': Offset(100, 100),
              'node-2': Offset(200, 200),
            },
            viewConfig: GraphViewConfig.defaultConfig,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          final updatedGraph = graph.copyWith(
            nodePositions: {
              'node-1': const Offset(150, 150),
              'node-2': const Offset(250, 250),
            },
          );

          when(mockGraphService.updateGraph(
            any,
            nodePositions: anyNamed('nodePositions'),
          )).thenAnswer((_) async => updatedGraph);
        },
        seed: () {
          final graph = Graph(
            id: 'graph-1',
            name: 'Test Graph',
            nodeIds: ['node-1', 'node-2'],
            nodePositions: const {
              'node-1': Offset(100, 100),
              'node-2': Offset(200, 200),
            },
            viewConfig: GraphViewConfig.defaultConfig,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          final nodes = [
            NodeTestHelpers.test(id: 'node-1', title: 'Node 1', content: 'Content 1'),
            NodeTestHelpers.test(id: 'node-2', title: 'Node 2', content: 'Content 2'),
          ];

          return GraphState(
            graph: graph,
            nodes: nodes,
            connections: const [],
            selectionState: const SelectionState(),
            viewState: const ViewState(),
            loadingState: LoadingState.loaded,
          );
        },
        build: () => graphBloc,
        act: (bloc) => bloc.add(const NodeMultiMoveEvent({
          'node-1': Offset(150, 150),
          'node-2': Offset(250, 250),
        })),
        expect: () => [
          predicate<GraphState>((s) =>
              s.graph.id == 'graph-1' &&
              s.graph.nodePositions['node-1'] == const Offset(150, 150) &&
              s.graph.nodePositions['node-2'] == const Offset(250, 250)),
        ],
      );
    });

    // === 视图操作测试 ===
    group('View Operations', () {
      blocTest<GraphBloc, GraphState>(
        'should zoom view',
        build: () => graphBloc,
        act: (bloc) => bloc.add(const ViewZoomEvent(2.0)),
        expect: () => [
          predicate<GraphState>((s) => s.viewState.zoomLevel == 2.0),
        ],
      );

      blocTest<GraphBloc, GraphState>(
        'should move camera',
        seed: () {
          final graph = Graph(
            id: 'graph-1',
            name: 'Test Graph',
            nodeIds: const [],
            nodePositions: const {},
            viewConfig: GraphViewConfig.defaultConfig,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          final updatedGraph = graph.copyWith(
            viewConfig: graph.viewConfig.copyWith(
              camera: const Camera(x: 500, y: 500, zoom: 1.0),
            ),
          );

          when(mockGraphService.updateGraph(
            'graph-1',
            viewConfig: argThat(
              predicate((GraphViewConfig c) =>
                c.camera.x == 500 && c.camera.y == 500),
              named: 'viewConfig',
            ),
          )).thenAnswer((_) async => updatedGraph);

          return graphBloc.state.copyWith(graph: graph);
        },
        build: () => graphBloc,
        act: (bloc) => bloc.add(const ViewMoveEvent(Offset(500, 500))),
        expect: () => [
          predicate<GraphState>((s) =>
              s.viewState.camera.position.dx == 500 &&
              s.viewState.camera.position.dy == 500),
        ],
      );

      blocTest<GraphBloc, GraphState>(
        'should toggle connections visibility',
        seed: () {
          return graphBloc.state.copyWith(
            viewState: graphBloc.state.viewState.copyWith(showConnections: true),
          );
        },
        build: () => graphBloc,
        act: (bloc) => bloc.add(const ViewToggleConnectionsEvent()),
        expect: () => [
          predicate<GraphState>((s) => s.viewState.showConnections == false),
        ],
      );

      blocTest<GraphBloc, GraphState>(
        'should toggle grid visibility',
        seed: () {
          return graphBloc.state.copyWith(
            viewState: graphBloc.state.viewState.copyWith(gridVisible: true),
          );
        },
        build: () => graphBloc,
        act: (bloc) => bloc.add(const ViewToggleGridEvent()),
        expect: () => [
          predicate<GraphState>((s) => s.viewState.gridVisible == false),
        ],
      );
    });

    // === 图操作测试 ===
    group('Graph Operations', () {
      blocTest<GraphBloc, GraphState>(
        'should rename graph',
        build: () {
          final graph = Graph(
            id: 'graph-1',
            name: 'Old Name',
            nodeIds: const [],
            nodePositions: const {},
            viewConfig: GraphViewConfig.defaultConfig,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          final renamedGraph = graph.copyWith(name: 'New Name');

          when(mockGraphService.getCurrentGraph()).thenAnswer((_) async => graph);
          when(mockGraphService.getGraphNodes('graph-1')).thenAnswer((_) async => []);
          when(mockGraphService.updateGraph('graph-1', name: 'New Name'))
              .thenAnswer((_) async => renamedGraph);

          return graphBloc;
        },
        act: (bloc) async {
          bloc.add(const GraphInitializeEvent());
          await Future.delayed(const Duration(milliseconds: 50));
          bloc.add(const GraphRenameEvent('New Name'));
        },
        wait: const Duration(milliseconds: 100),
        skip: 2,
        expect: () => [
          predicate<GraphState>((s) => s.graph.name == 'New Name'),
        ],
      );

      blocTest<GraphBloc, GraphState>(
        'should create new graph',
        build: () {
          final newGraph = Graph(
            id: 'graph-new',
            name: 'New Graph',
            nodeIds: const [],
            nodePositions: const {},
            viewConfig: GraphViewConfig.defaultConfig,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          when(mockGraphService.createGraph(name: 'New Graph'))
              .thenAnswer((_) async => newGraph);
          when(mockGraphService.getGraphNodes('graph-new'))
              .thenAnswer((_) async => []);

          return graphBloc;
        },
        act: (bloc) => bloc.add(const GraphCreateEvent('New Graph')),
        expect: () => [
          predicate<GraphState>((s) =>
              s.graph.id == 'graph-new' &&
              s.graph.name == 'New Graph' &&
              s.loadingState == LoadingState.loaded),
        ],
      );

      blocTest<GraphBloc, GraphState>(
        'should load existing graph',
        build: () {
          final graph = Graph(
            id: 'graph-1',
            name: 'Test Graph',
            nodeIds: const [],
            nodePositions: const {},
            viewConfig: GraphViewConfig.defaultConfig,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          when(mockGraphService.getGraph('graph-1')).thenAnswer((_) async => graph);
          when(mockGraphService.getGraphNodes('graph-1')).thenAnswer((_) async => []);

          return graphBloc;
        },
        act: (bloc) => bloc.add(const GraphLoadEvent('graph-1')),
        expect: () => [
          predicate<GraphState>((s) => s.loadingState == LoadingState.loading),
          predicate<GraphState>((s) =>
              s.graph.id == 'graph-1' &&
              s.loadingState == LoadingState.loaded),
        ],
      );
    });
  });
}
