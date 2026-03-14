import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:node_graph_notebook/core/models/models.dart';
import 'package:node_graph_notebook/core/commands/command_bus.dart';
import 'package:node_graph_notebook/core/commands/command.dart';
import 'package:node_graph_notebook/core/commands/impl/node_commands.dart';
import 'package:node_graph_notebook/core/repositories/node_repository.dart';
import 'package:node_graph_notebook/core/events/app_events.dart';
import 'package:node_graph_notebook/bloc/node/node_bloc.dart';
import 'package:node_graph_notebook/bloc/node/node_event.dart';
import 'package:node_graph_notebook/bloc/node/node_state.dart';
import '../../test_helpers.dart';

@GenerateNiceMocks([
  MockSpec<CommandBus>(),
  MockSpec<NodeRepository>(),
])
import 'node_bloc_test.mocks.dart';

void main() {
  late MockCommandBus mockCommandBus;
  late MockNodeRepository mockNodeRepository;
  late AppEventBus eventBus;
  late NodeBloc nodeBloc;

  setUp(() {
    mockCommandBus = MockCommandBus();
    mockNodeRepository = MockNodeRepository();
    eventBus = AppEventBus.createForTest();

    // 不在这里设置默认返回值，让每个测试自己设置
    // 这样可以避免类型转换问题

    // 创建 NodeBloc（新架构：CommandBus + Repository）
    nodeBloc = NodeBloc(
      commandBus: mockCommandBus,
      nodeRepository: mockNodeRepository,
      eventBus: eventBus,
    );
  });

  tearDown(() {
    nodeBloc.close();
    eventBus.dispose();
  });

  group('NodeBloc - New Architecture', () {
    // === 初始化测试 ===
    group('Initialization', () {
      test('initial state should be NodeState.initial()', () {
        expect(nodeBloc.state, equals(NodeState.initial()));
      });

      blocTest<NodeBloc, NodeState>(
        'should load nodes on NodeLoadEvent',
        build: () {
          final nodes = [
            NodeTestHelpers.test(id: '1', title: 'Node 1', content: 'Content 1'),
            NodeTestHelpers.test(id: '2', title: 'Node 2', content: 'Content 2'),
          ];
          when(mockNodeRepository.queryAll()).thenAnswer((_) async => nodes);
          return nodeBloc;
        },
        act: (bloc) => bloc.add(const NodeLoadEvent()),
        expect: () => [
          NodeState.initial().copyWith(isLoading: true, error: null),
          predicate<NodeState>((state) =>
              state.nodes.isNotEmpty &&
              state.nodes.length == 2 &&
              state.isLoading == false &&
              state.error == null),
        ],
        verify: (_) {
          verify(mockNodeRepository.queryAll()).called(1);
        },
      );

      blocTest<NodeBloc, NodeState>(
        'should handle error when loading nodes fails',
        build: () {
          when(mockNodeRepository.queryAll()).thenThrow(Exception('Failed to load'));
          return nodeBloc;
        },
        act: (bloc) => bloc.add(const NodeLoadEvent()),
        expect: () => [
          NodeState.initial().copyWith(isLoading: true, error: null),
          NodeState.initial().copyWith(
            isLoading: false,
            error: 'Exception: Failed to load',
          ),
        ],
      );
    });

    // === 创建节点测试 ===
    group('Create Node', () {
      blocTest<NodeBloc, NodeState>(
        'should create node successfully',
        build: () {
          final newNode = NodeTestHelpers.test(id: '1', title: 'New Node');
          // 重置 mock 并设置正确的返回类型
          reset(mockCommandBus);
          when(mockCommandBus.dispatch(any))
              .thenAnswer((_) async => CommandResult<Node>.success(newNode));
          return nodeBloc;
        },
        act: (bloc) => bloc.add(const NodeCreateEvent(
          title: 'New Node',
          content: 'Content',
        )),
        expect: () => [
          NodeState.initial().copyWith(isLoading: true, error: null),
          predicate<NodeState>((state) =>
              state.nodes.length == 1 &&
              state.nodes.first.title == 'New Node' &&
              state.isLoading == false),
        ],
        verify: (_) {
          final captured = verify(mockCommandBus.dispatch(captureAny))
              .captured.single as CreateNodeCommand;
          expect(captured.title, 'New Node');
          expect(captured.content, 'Content');
        },
      );

      blocTest<NodeBloc, NodeState>(
        'should handle error when creating node fails',
        build: () {
          // 重置 mock 并设置返回错误
          reset(mockCommandBus);
          when(mockCommandBus.dispatch(any))
              .thenAnswer((_) async => CommandResult<Node>.failure('Creation failed'));
          return nodeBloc;
        },
        act: (bloc) => bloc.add(const NodeCreateEvent(title: 'Test')),
        expect: () => [
          NodeState.initial().copyWith(isLoading: true, error: null),
          NodeState.initial().copyWith(
            isLoading: false,
            error: 'Creation failed',
          ),
        ],
      );
    });

    // === 更新节点测试 ===
    group('Update Node', () {
      blocTest<NodeBloc, NodeState>(
        'should update node successfully',
        build: () {
          final existingNode = NodeTestHelpers.test(
            id: '1',
            title: 'Old Title',
          );
          final updatedNode = NodeTestHelpers.test(
            id: '1',
            title: 'New Title',
          );

          // 重置 mock 并设置正确的返回类型
          reset(mockCommandBus);
          when(mockCommandBus.dispatch(any))
              .thenAnswer((_) async => CommandResult<Node>.success(updatedNode));

          // 设置初始状态
          nodeBloc.emit(NodeState.initial().copyWith(nodes: [existingNode]));
          return nodeBloc;
        },
        act: (bloc) => bloc.add(const NodeUpdateEvent(
          '1',
          title: 'New Title',
        )),
        expect: () => [
          // 使用 predicate 来检查第一个状态，因为 Node 对象可能不完全相同
          predicate<NodeState>((state) =>
              state.nodes.length == 1 &&
              state.nodes.first.id == '1' &&
              state.nodes.first.title == 'Old Title' &&
              state.isLoading == true),
          predicate<NodeState>((state) =>
              state.nodes.length == 1 &&
              state.nodes.first.title == 'New Title' &&
              state.isLoading == false),
        ],
        verify: (_) {
          final captured = verify(mockCommandBus.dispatch(captureAny))
              .captured.single as UpdateNodeCommand;
          expect(captured.newNode.title, 'New Title');
        },
      );
    });

    // === 删除节点测试 ===
    group('Delete Node', () {
      blocTest<NodeBloc, NodeState>(
        'should delete node successfully',
        build: () {
          final node1 = NodeTestHelpers.test(id: '1', title: 'Node 1');
          final node2 = NodeTestHelpers.test(id: '2', title: 'Node 2');

          // 重置 mock 并设置返回值
          reset(mockCommandBus);
          when(mockCommandBus.dispatch(any))
              .thenAnswer((_) async => CommandResult.success(null));

          // 设置初始状态
          nodeBloc.emit(NodeState.initial().copyWith(
            nodes: [node1, node2],
            selectedNodeIds: {'1'},
          ));
          return nodeBloc;
        },
        act: (bloc) => bloc.add(const NodeDeleteEvent('1')),
        expect: () => [
          predicate<NodeState>((state) =>
              state.nodes.length == 2 &&
              state.isLoading == true),
          predicate<NodeState>((state) =>
              state.nodes.length == 1 &&
              state.nodes.first.id == '2' &&
              state.selectedNodeIds.isEmpty &&
              state.isLoading == false),
        ],
        verify: (_) {
          final captured = verify(mockCommandBus.dispatch(captureAny))
              .captured.single as DeleteNodeCommand;
          expect(captured.node.id, '1');
        },
      );
    });

    // === 搜索节点测试 ===
    group('Search Nodes', () {
      blocTest<NodeBloc, NodeState>(
        'should search nodes by query',
        build: () {
          final searchResults = [
            NodeTestHelpers.test(id: '1', title: 'Python Guide'),
            NodeTestHelpers.test(id: '2', title: 'Python Tutorial'),
          ];

          when(mockNodeRepository.search(title: 'Python', content: 'Python'))
              .thenAnswer((_) async => searchResults);

          return nodeBloc;
        },
        act: (bloc) => bloc.add(const NodeSearchEvent('Python')),
        expect: () => [
          NodeState.initial().copyWith(isLoading: true, error: null),
          predicate<NodeState>((state) =>
              state.nodes.length == 2 &&
              state.nodes.every((n) => n.title.contains('Python')) &&
              state.isLoading == false),
        ],
        verify: (_) {
          verify(mockNodeRepository.search(title: 'Python', content: 'Python'))
              .called(1);
        },
      );

      blocTest<NodeBloc, NodeState>(
        'should load all nodes when query is empty',
        build: () {
          final allNodes = [
            NodeTestHelpers.test(id: '1', title: 'Node 1'),
            NodeTestHelpers.test(id: '2', title: 'Node 2'),
          ];
          when(mockNodeRepository.queryAll()).thenAnswer((_) async => allNodes);
          return nodeBloc;
        },
        act: (bloc) => bloc.add(const NodeSearchEvent('')),
        expect: () => [
          NodeState.initial().copyWith(isLoading: true, error: null),
          predicate<NodeState>((state) =>
              state.nodes.length == 2 &&
              state.isLoading == false),
        ],
        verify: (_) {
          verify(mockNodeRepository.queryAll()).called(1);
          verifyNever(mockNodeRepository.search(
            title: anyNamed('title'),
            content: anyNamed('content'),
          ));
        },
      );
    });

    // === 连接节点测试 ===
    group('Connect Nodes', () {
      blocTest<NodeBloc, NodeState>(
        'should connect two nodes successfully',
        build: () {
          final fromNode = NodeTestHelpers.test(
            id: '1',
            title: 'Node 1',
          );
          final toNode = NodeTestHelpers.test(
            id: '2',
            title: 'Node 2',
          );
          final updatedNode = NodeTestHelpers.test(
            id: '1',
            title: 'Node 1',
            references: {
              '2': const NodeReference(
                nodeId: '2',
                type: ReferenceType.references,
              )
            },
          );

          // 重置 mock 并设置返回值
          reset(mockCommandBus);
          when(mockCommandBus.dispatch(any))
              .thenAnswer((_) async => CommandResult.success(null));
          when(mockNodeRepository.load('1'))
              .thenAnswer((_) async => updatedNode);

          // 设置初始状态
          nodeBloc.emit(NodeState.initial().copyWith(nodes: [fromNode, toNode]));
          return nodeBloc;
        },
        act: (bloc) => bloc.add(const NodeConnectEvent(
          fromNodeId: '1',
          toNodeId: '2',
          type: ReferenceType.references,
        )),
        expect: () => [
          predicate<NodeState>((state) => state.isLoading == true),
          predicate<NodeState>((state) =>
              state.nodes.length == 2 &&
              state.isLoading == false),
        ],
        verify: (_) {
          final captured = verify(mockCommandBus.dispatch(captureAny))
              .captured.single as ConnectNodesCommand;
          expect(captured.sourceId, '1');
          expect(captured.targetId, '2');
          expect(captured.type, ReferenceType.references);
          verify(mockNodeRepository.load('1')).called(1);
        },
      );
    });

    // === EventBus 集成测试 ===
    group('EventBus Integration', () {
      test('should update state when NodeDataChangedEvent is received', () async {
        // 设置初始状态
        final initialNodes = [
          NodeTestHelpers.test(id: '1', title: 'Node 1'),
        ];
        nodeBloc.emit(NodeState.initial().copyWith(nodes: initialNodes));

        // 发布节点创建事件
        final newNode = NodeTestHelpers.test(id: '2', title: 'Node 2');
        eventBus.publish(NodeDataChangedEvent(
          changedNodes: [newNode],
          action: DataChangeAction.create,
        ));

        // 等待事件处理
        await Future.delayed(const Duration(milliseconds: 100));

        // 验证状态已更新
        expect(nodeBloc.state.nodes.length, 2);
        expect(nodeBloc.state.nodes.any((n) => n.id == '2'), true);
      });

      test('should update node when NodeDataChangedEvent.update is received', () async {
        // 设置初始状态
        final initialNode = NodeTestHelpers.test(id: '1', title: 'Old Title');
        nodeBloc.emit(NodeState.initial().copyWith(nodes: [initialNode]));

        // 发布节点更新事件
        final updatedNode = NodeTestHelpers.test(id: '1', title: 'New Title');
        eventBus.publish(NodeDataChangedEvent(
          changedNodes: [updatedNode],
          action: DataChangeAction.update,
        ));

        // 等待事件处理
        await Future.delayed(const Duration(milliseconds: 100));

        // 验证状态已更新
        expect(nodeBloc.state.nodes.length, 1);
        expect(nodeBloc.state.nodes.first.title, 'New Title');
      });

      test('should remove node when NodeDataChangedEvent.delete is received', () async {
        // 设置初始状态
        final nodes = [
          NodeTestHelpers.test(id: '1', title: 'Node 1'),
          NodeTestHelpers.test(id: '2', title: 'Node 2'),
        ];
        nodeBloc.emit(NodeState.initial().copyWith(nodes: nodes));

        // 发布节点删除事件
        final deletedNode = nodes.first;
        eventBus.publish(NodeDataChangedEvent(
          changedNodes: [deletedNode],
          action: DataChangeAction.delete,
        ));

        // 等待事件处理
        await Future.delayed(const Duration(milliseconds: 100));

        // 验证状态已更新
        expect(nodeBloc.state.nodes.length, 1);
        expect(nodeBloc.state.nodes.first.id, '2');
      });
    });

    // === 错误处理测试 ===
    group('Error Handling', () {
      blocTest<NodeBloc, NodeState>(
        'should clear error on NodeClearErrorEvent',
        build: () {
          nodeBloc.emit(NodeState.initial().copyWith(
            error: 'Some error',
          ));
          return nodeBloc;
        },
        act: (bloc) => bloc.add(const NodeClearErrorEvent()),
        expect: () => [
          predicate<NodeState>((state) => state.error == null),
        ],
      );
    });
  });
}
