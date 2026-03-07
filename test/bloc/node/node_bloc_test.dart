import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:node_graph_notebook/core/models/models.dart';
import 'package:node_graph_notebook/core/services/node_service.dart';
import 'package:node_graph_notebook/core/events/app_events.dart';
import 'package:node_graph_notebook/bloc/node/node_bloc.dart';
import 'package:node_graph_notebook/bloc/node/node_event.dart';
import 'package:node_graph_notebook/bloc/node/node_state.dart';
import '../../test_helpers.dart';

@GenerateNiceMocks([MockSpec<NodeService>()])
import 'node_bloc_test.mocks.dart';

void main() {
  late MockNodeService mockNodeService;
  late AppEventBus eventBus;
  late NodeBloc nodeBloc;

  setUp(() {
    mockNodeService = MockNodeService();
    eventBus = AppEventBus.createForTest();
    nodeBloc = NodeBloc(
      nodeService: mockNodeService,
      eventBus: eventBus,
    );
  });

  tearDown(() {
    nodeBloc.close();
    eventBus.dispose();
  });

  group('NodeBloc', () {
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
          when(mockNodeService.getAllNodes()).thenAnswer((_) async => nodes);
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
          verify(mockNodeService.getAllNodes()).called(1);
        },
      );

      blocTest<NodeBloc, NodeState>(
        'should handle error when loading nodes fails',
        build: () {
          when(mockNodeService.getAllNodes()).thenThrow(Exception('Failed to load'));
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
        'should create node and publish event',
        build: () {
          final newNode = NodeTestHelpers.test(
            id: '1',
            title: 'New Node',
            content: 'New Content',
          );
          when(mockNodeService.createNode(
            title: 'New Node',
            content: 'New Content',
          )).thenAnswer((_) async => newNode);
          return nodeBloc;
        },
        act: (bloc) => bloc.add(const NodeCreateEvent(
          title: 'New Node',
          content: 'New Content',
        )),
        expect: () => [
          predicate<NodeState>((state) =>
              state.nodes.isNotEmpty &&
              state.nodes.first.id == '1' &&
              state.error == null),
        ],
        verify: (_) {
          verify(mockNodeService.createNode(
            title: 'New Node',
            content: 'New Content',
          )).called(1);
        },
      );

      blocTest<NodeBloc, NodeState>(
        'should handle error when creating node fails',
        build: () {
          when(mockNodeService.createNode(
            title: 'Error Node',
            content: 'Error Content',
          )).thenThrow(Exception('Failed to create'));
          return nodeBloc;
        },
        act: (bloc) => bloc.add(const NodeCreateEvent(
          title: 'Error Node',
          content: 'Error Content',
        )),
        expect: () => [
          NodeState.initial().copyWith(error: 'Exception: Failed to create'),
        ],
      );
    });

    // === 更新节点测试 ===
    group('Update Node', () {
      blocTest<NodeBloc, NodeState>(
        'should update node and publish event',
        seed: () {
          final originalNode = NodeTestHelpers.test(
            id: '1',
            title: 'Original Title',
            content: 'Original Content',
          );
          return NodeState.initial().copyWith(nodes: [originalNode]);
        },
        build: () {
          final updatedNode = NodeTestHelpers.test(
            id: '1',
            title: 'Updated Title',
            content: 'Updated Content',
          );
          when(mockNodeService.updateNode(
            '1',
            title: 'Updated Title',
            content: 'Updated Content',
          )).thenAnswer((_) async => updatedNode);
          return nodeBloc;
        },
        act: (bloc) => bloc.add(const NodeUpdateEvent(
          '1',
          title: 'Updated Title',
          content: 'Updated Content',
        )),
        expect: () => [
          predicate<NodeState>((state) =>
              state.nodes.isNotEmpty &&
              state.nodes.first.id == '1' &&
              state.error == null),
        ],
        verify: (_) {
          verify(mockNodeService.updateNode(
            '1',
            title: 'Updated Title',
            content: 'Updated Content',
          )).called(1);
        },
      );
    });

    // === 删除节点测试 ===
    group('Delete Node', () {
      blocTest<NodeBloc, NodeState>(
        'should delete node and publish delete event',
        seed: () {
          final nodeToDelete = NodeTestHelpers.test(
            id: '1',
            title: 'To Delete',
            content: 'Will be deleted',
          );
          final otherNode = NodeTestHelpers.test(
            id: '2',
            title: 'Keep',
            content: 'Will stay',
          );
          return NodeState.initial().copyWith(
            nodes: [nodeToDelete, otherNode],
            selectedNodeIds: {'1', '2'},
          );
        },
        build: () {
          when(mockNodeService.deleteNode('1')).thenAnswer((_) async => Future.value());
          return nodeBloc;
        },
        act: (bloc) => bloc.add(const NodeDeleteEvent('1')),
        expect: () => [
          predicate<NodeState>((state) =>
              state.nodes.length == 1 &&
              state.selectedNodeIds.length == 1 &&
              state.nodes.first.id == '2' &&
              state.error == null),
        ],
        verify: (_) {
          verify(mockNodeService.deleteNode('1')).called(1);
        },
      );
    });

    // === 连接节点测试 ===
    group('Connect Nodes', () {
      blocTest<NodeBloc, NodeState>(
        'should connect two nodes',
        seed: () {
          final node1 = NodeTestHelpers.test(
            id: '1',
            title: 'Node 1',
            content: 'Content 1',
          );
          final node2 = NodeTestHelpers.test(
            id: '2',
            title: 'Node 2',
            content: 'Content 2',
          );
          return NodeState.initial().copyWith(nodes: [node1, node2]);
        },
        build: () {
          final updatedNode1 = NodeTestHelpers.test(
            id: '1',
            title: 'Node 1',
            content: 'Content 1',
            references: {
              '2': const NodeReference(
                nodeId: '2',
                type: ReferenceType.relatesTo,
              ),
            },
          );
          when(mockNodeService.connectNodes(
            fromNodeId: '1',
            toNodeId: '2',
            type: ReferenceType.relatesTo,
          )).thenAnswer((_) async => Future.value());
          when(mockNodeService.getNode('1')).thenAnswer((_) async => updatedNode1);
          return nodeBloc;
        },
        act: (bloc) => bloc.add(const NodeConnectEvent(
          fromNodeId: '1',
          toNodeId: '2',
          type: ReferenceType.relatesTo,
        )),
        expect: () => [
          predicate<NodeState>((state) =>
              state.nodes.length == 2 &&
              state.nodes.first.references.containsKey('2') &&
              state.error == null),
        ],
        verify: (_) {
          verify(mockNodeService.connectNodes(
            fromNodeId: '1',
            toNodeId: '2',
            type: ReferenceType.relatesTo,
          )).called(1);
        },
      );
    });

    // === 搜索节点测试 ===
    group('Search Nodes', () {
      blocTest<NodeBloc, NodeState>(
        'should search nodes by query',
        build: () {
          final searchResults = [
            NodeTestHelpers.test(id: '1', title: 'Python', content: 'Programming language'),
          ];
          when(mockNodeService.searchNodes('Python')).thenAnswer((_) async => searchResults);
          return nodeBloc;
        },
        act: (bloc) => bloc.add(const NodeSearchEvent('Python')),
        expect: () => [
          NodeState.initial().copyWith(isLoading: true, error: null),
          predicate<NodeState>((state) =>
              state.nodes.isNotEmpty &&
              state.nodes.first.id == '1' &&
              state.isLoading == false &&
              state.error == null),
        ],
        verify: (_) {
          verify(mockNodeService.searchNodes('Python')).called(1);
        },
      );

      blocTest<NodeBloc, NodeState>(
        'should load all nodes when query is empty',
        build: () {
          final allNodes = [
            NodeTestHelpers.test(id: '1', title: 'Node 1', content: 'Content 1'),
          ];
          when(mockNodeService.getAllNodes()).thenAnswer((_) async => allNodes);
          return nodeBloc;
        },
        act: (bloc) => bloc.add(const NodeSearchEvent('')),
        expect: () => [
          NodeState.initial().copyWith(isLoading: true, error: null),
          predicate<NodeState>((state) =>
              state.nodes.isNotEmpty &&
              state.nodes.first.id == '1' &&
              state.isLoading == false &&
              state.error == null),
        ],
        verify: (_) {
          verify(mockNodeService.getAllNodes()).called(1);
        },
      );
    });
  });
}
