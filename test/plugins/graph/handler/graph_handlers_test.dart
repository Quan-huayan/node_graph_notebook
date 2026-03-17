import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:node_graph_notebook/core/commands/models/command_context.dart';
import 'package:node_graph_notebook/core/models/enums.dart';
import 'package:node_graph_notebook/core/models/graph.dart';
import 'package:node_graph_notebook/core/models/node.dart';
import 'package:node_graph_notebook/core/models/node_reference.dart';
import 'package:node_graph_notebook/core/repositories/graph_repository.dart';
import 'package:node_graph_notebook/core/repositories/node_repository.dart';
import 'package:node_graph_notebook/plugins/graph/command/graph_commands.dart';
import 'package:node_graph_notebook/plugins/graph/command/node_commands.dart';
import 'package:node_graph_notebook/plugins/graph/handler/add_node_to_graph_handler.dart';
import 'package:node_graph_notebook/plugins/graph/handler/connect_nodes_handler.dart';
import 'package:node_graph_notebook/plugins/graph/handler/create_graph_handler.dart';
import 'package:node_graph_notebook/plugins/graph/handler/create_node_handler.dart';
import 'package:node_graph_notebook/plugins/graph/handler/delete_node_handler.dart';
import 'package:node_graph_notebook/plugins/graph/handler/disconnect_nodes_handler.dart';
import 'package:node_graph_notebook/plugins/graph/handler/load_graph_handler.dart';
import 'package:node_graph_notebook/plugins/graph/handler/move_node_handler.dart';
import 'package:node_graph_notebook/plugins/graph/handler/remove_node_from_graph_handler.dart';
import 'package:node_graph_notebook/plugins/graph/handler/rename_graph_handler.dart';
import 'package:node_graph_notebook/plugins/graph/handler/resize_node_handler.dart';
import 'package:node_graph_notebook/plugins/graph/handler/update_graph_handler.dart';
import 'package:node_graph_notebook/plugins/graph/handler/update_node_handler.dart';
import 'package:node_graph_notebook/plugins/graph/handler/update_node_position_handler.dart';
import 'package:node_graph_notebook/plugins/graph/service/graph_service.dart';
import 'package:node_graph_notebook/plugins/graph/service/node_service.dart';

@GenerateMocks([
  NodeRepository,
  NodeService,
  GraphService,
  GraphRepository,
  CommandContext,
])
import 'graph_handlers_test.mocks.dart';

void main() {
  group('CreateNodeHandler', () {
    late CreateNodeHandler handler;
    late MockNodeService mockService;
    late MockCommandContext mockContext;

    setUp(() {
      mockService = MockNodeService();
      mockContext = MockCommandContext();
      handler = CreateNodeHandler(mockService);
    });

    test('should create node successfully', () async {
      final command = CreateNodeCommand(
        title: 'Test Node',
        content: 'Test Content',
        position: const Offset(100, 200),
      );

      final createdNode = Node(
        id: 'test-id',
        title: 'Test Node',
        content: 'Test Content',
        references: {},
        position: const Offset(100, 200),
        size: const Size(200, 250),
        viewMode: NodeViewMode.fullContent,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: const {},
      );

      when(mockService.createNode(
        title: anyNamed('title'),
        content: anyNamed('content'),
        position: anyNamed('position'),
      )).thenAnswer((_) async => createdNode);

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, true);
      expect(result.data, isNotNull);
      expect(result.data!.title, 'Test Node');
      verify(mockService.createNode(
        title: 'Test Node',
        content: 'Test Content',
        position: const Offset(100, 200),
      )).called(1);
    });

    test('should fail when title is empty', () async {
      final command = CreateNodeCommand(
        title: '',
        content: 'Test Content',
      );

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, '节点标题不能为空');
      verifyNever(mockService.createNode(
        title: anyNamed('title'),
        content: anyNamed('content'),
        position: anyNamed('position'),
      ));
    });

    test('should fail when title is only whitespace', () async {
      final command = CreateNodeCommand(
        title: '   ',
        content: 'Test Content',
      );

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, '节点标题不能为空');
      verifyNever(mockService.createNode(
        title: anyNamed('title'),
        content: anyNamed('content'),
        position: anyNamed('position'),
      ));
    });

    test('should handle service exceptions', () async {
      final command = CreateNodeCommand(
        title: 'Test Node',
        content: 'Test Content',
      );

      when(mockService.createNode(
        title: anyNamed('title'),
        content: anyNamed('content'),
        position: anyNamed('position'),
      )).thenThrow(Exception('Database error'));

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, contains('Exception'));
    });
  });

  group('UpdateNodeHandler', () {
    late UpdateNodeHandler handler;
    late MockNodeService mockService;
    late MockCommandContext mockContext;

    setUp(() {
      mockService = MockNodeService();
      mockContext = MockCommandContext();
      handler = UpdateNodeHandler(mockService);
    });

    test('should update node successfully', () async {
      final oldNode = Node(
        id: 'test-id',
        title: 'Old Title',
        content: 'Old Content',
        references: {},
        position: const Offset(100, 100),
        size: const Size(200, 250),
        viewMode: NodeViewMode.fullContent,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: const {},
      );

      final newNode = Node(
        id: 'test-id',
        title: 'New Title',
        content: 'New Content',
        references: {},
        position: const Offset(200, 200),
        size: const Size(300, 350),
        viewMode: NodeViewMode.titleOnly,
        createdAt: oldNode.createdAt,
        updatedAt: DateTime.now(),
        metadata: const {},
      );

      final command = UpdateNodeCommand(oldNode: oldNode, newNode: newNode);

      when(mockService.updateNode(
        any,
        title: anyNamed('title'),
        content: anyNamed('content'),
        position: anyNamed('position'),
        size: anyNamed('size'),
        viewMode: anyNamed('viewMode'),
        color: anyNamed('color'),
        metadata: anyNamed('metadata'),
      )).thenAnswer((_) async => newNode);

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, true);
      expect(result.data!.title, 'New Title');
      expect(result.data!.content, 'New Content');
      verify(mockService.updateNode(
        'test-id',
        title: 'New Title',
        content: 'New Content',
        position: const Offset(200, 200),
        size: const Size(300, 350),
        viewMode: NodeViewMode.titleOnly,
        color: null,
        metadata: const {},
      )).called(1);
    });

    test('should fail when node IDs do not match', () async {
      final oldNode = Node(
        id: 'old-id',
        title: 'Old Title',
        content: '',
        references: {},
        position: Offset.zero,
        size: Size.zero,
        viewMode: NodeViewMode.fullContent,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: const {},
      );

      final newNode = Node(
        id: 'new-id',
        title: 'New Title',
        content: '',
        references: {},
        position: Offset.zero,
        size: Size.zero,
        viewMode: NodeViewMode.fullContent,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: const {},
      );

      final command = UpdateNodeCommand(oldNode: oldNode, newNode: newNode);

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, '节点ID不匹配');
      verifyNever(mockService.updateNode(any, title: anyNamed('title')));
    });

    test('should handle service exceptions', () async {
      final node = Node(
        id: 'test-id',
        title: 'Test Node',
        content: 'Content',
        references: {},
        position: Offset.zero,
        size: Size.zero,
        viewMode: NodeViewMode.fullContent,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: const {},
      );

      final command = UpdateNodeCommand(oldNode: node, newNode: node);

      when(mockService.updateNode(
        any,
        title: anyNamed('title'),
        content: anyNamed('content'),
        position: anyNamed('position'),
        size: anyNamed('size'),
        viewMode: anyNamed('viewMode'),
        color: anyNamed('color'),
        metadata: anyNamed('metadata'),
      )).thenThrow(Exception('Update failed'));

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, contains('Exception'));
    });
  });

  group('DeleteNodeHandler', () {
    late DeleteNodeHandler handler;
    late MockNodeService mockService;
    late MockCommandContext mockContext;

    setUp(() {
      mockService = MockNodeService();
      mockContext = MockCommandContext();
      handler = DeleteNodeHandler(mockService);
    });

    test('should delete node successfully', () async {
      final node = Node(
        id: 'test-id',
        title: 'Test Node',
        content: 'Content',
        references: {},
        position: Offset.zero,
        size: Size.zero,
        viewMode: NodeViewMode.fullContent,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: const {},
      );

      final command = DeleteNodeCommand(node: node);

      when(mockService.deleteNode(any)).thenAnswer((_) async {});

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, true);
      verify(mockService.deleteNode('test-id')).called(1);
    });

    test('should handle delete exceptions', () async {
      final node = Node(
        id: 'test-id',
        title: 'Test Node',
        content: '',
        references: {},
        position: Offset.zero,
        size: Size.zero,
        viewMode: NodeViewMode.fullContent,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: const {},
      );

      final command = DeleteNodeCommand(node: node);

      when(mockService.deleteNode(any)).thenThrow(Exception('Delete failed'));

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, contains('Exception'));
    });
  });

  group('ConnectNodesHandler', () {
    late ConnectNodesHandler handler;
    late MockNodeRepository mockRepository;
    late MockCommandContext mockContext;

    setUp(() {
      mockRepository = MockNodeRepository();
      mockContext = MockCommandContext();
      handler = ConnectNodesHandler(mockRepository);
    });

    test('should connect nodes successfully', () async {
      final sourceNode = Node(
        id: 'source-id',
        title: 'Source Node',
        content: 'Source Content',
        references: {},
        position: const Offset(100, 100),
        size: const Size(200, 250),
        viewMode: NodeViewMode.fullContent,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: const {},
      );

      final targetNode = Node(
        id: 'target-id',
        title: 'Target Node',
        content: 'Target Content',
        references: {},
        position: const Offset(300, 300),
        size: const Size(200, 250),
        viewMode: NodeViewMode.fullContent,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: const {},
      );

      when(mockRepository.load('source-id')).thenAnswer((_) async => sourceNode);
      when(mockRepository.load('target-id')).thenAnswer((_) async => targetNode);
      when(mockRepository.save(any)).thenAnswer((_) async {});

      final command = ConnectNodesCommand(
        sourceId: 'source-id',
        targetId: 'target-id',
      );

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, true);
      verify(mockRepository.load('source-id')).called(1);
      verify(mockRepository.load('target-id')).called(1);
      verify(mockRepository.save(any)).called(1);
    });

    test('should fail when source node does not exist', () async {
      when(mockRepository.load('non-existent')).thenAnswer((_) async => null);
      when(mockRepository.load('target-id')).thenAnswer((_) async => Node(
        id: 'target-id',
        title: 'Target',
        content: '',
        references: {},
        position: Offset.zero,
        size: Size.zero,
        viewMode: NodeViewMode.fullContent,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: const {},
      ));

      final command = ConnectNodesCommand(
        sourceId: 'non-existent',
        targetId: 'target-id',
      );

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, contains('源节点不存在'));
    });

    test('should fail when target node does not exist', () async {
      when(mockRepository.load('source-id')).thenAnswer((_) async => Node(
        id: 'source-id',
        title: 'Source',
        content: '',
        references: {},
        position: Offset.zero,
        size: Size.zero,
        viewMode: NodeViewMode.fullContent,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: const {},
      ));
      when(mockRepository.load('non-existent')).thenAnswer((_) async => null);

      final command = ConnectNodesCommand(
        sourceId: 'source-id',
        targetId: 'non-existent',
      );

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, contains('目标节点不存在'));
    });

    test('should fail when connection already exists', () async {
      final sourceNode = Node(
        id: 'source-id',
        title: 'Source Node',
        content: 'Source Content',
        references: {
          'target-id': const NodeReference(nodeId: 'target-id', properties: {}),
        },
        position: const Offset(100, 100),
        size: const Size(200, 250),
        viewMode: NodeViewMode.fullContent,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: const {},
      );

      final targetNode = Node(
        id: 'target-id',
        title: 'Target Node',
        content: 'Target Content',
        references: {},
        position: const Offset(300, 300),
        size: const Size(200, 250),
        viewMode: NodeViewMode.fullContent,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: const {},
      );

      when(mockRepository.load('source-id')).thenAnswer((_) async => sourceNode);
      when(mockRepository.load('target-id')).thenAnswer((_) async => targetNode);

      final command = ConnectNodesCommand(
        sourceId: 'source-id',
        targetId: 'target-id',
      );

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, contains('连接已存在'));
    });

    test('should handle repository exceptions', () async {
      when(mockRepository.load('source-id')).thenThrow(Exception('Database error'));

      final command = ConnectNodesCommand(
        sourceId: 'source-id',
        targetId: 'target-id',
      );

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, contains('Exception'));
    });
  });

  group('DisconnectNodesHandler', () {
    late DisconnectNodesHandler handler;
    late MockNodeRepository mockRepository;
    late MockCommandContext mockContext;

    setUp(() {
      mockRepository = MockNodeRepository();
      mockContext = MockCommandContext();
      handler = DisconnectNodesHandler(mockRepository);
    });

    test('should disconnect nodes successfully', () async {
      final sourceNode = Node(
        id: 'source-id',
        title: 'Source Node',
        content: 'Source Content',
        references: {
          'target-id': const NodeReference(nodeId: 'target-id', properties: {'key': 'value'}),
        },
        position: const Offset(100, 100),
        size: const Size(200, 250),
        viewMode: NodeViewMode.fullContent,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: const {},
      );

      when(mockRepository.load('source-id')).thenAnswer((_) async => sourceNode);
      when(mockRepository.save(any)).thenAnswer((_) async {});

      final command = DisconnectNodesCommand(
        sourceId: 'source-id',
        targetId: 'target-id',
      );

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, true);
      expect(command.originalReference.properties['key'], 'value');
      verify(mockRepository.save(any)).called(1);
    });

    test('should fail when source node does not exist', () async {
      when(mockRepository.load('source-id')).thenAnswer((_) async => null);

      final command = DisconnectNodesCommand(
        sourceId: 'source-id',
        targetId: 'target-id',
      );

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, contains('源节点不存在'));
    });

    test('should fail when connection does not exist', () async {
      final sourceNode = Node(
        id: 'source-id',
        title: 'Source Node',
        content: 'Source Content',
        references: {},
        position: const Offset(100, 100),
        size: const Size(200, 250),
        viewMode: NodeViewMode.fullContent,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: const {},
      );

      when(mockRepository.load('source-id')).thenAnswer((_) async => sourceNode);

      final command = DisconnectNodesCommand(
        sourceId: 'source-id',
        targetId: 'target-id',
      );

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, contains('节点连接不存在'));
    });

    test('should handle repository exceptions', () async {
      when(mockRepository.load('source-id')).thenThrow(Exception('Database error'));

      final command = DisconnectNodesCommand(
        sourceId: 'source-id',
        targetId: 'target-id',
      );

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, contains('Exception'));
    });
  });

  group('MoveNodeHandler', () {
    late MoveNodeHandler handler;
    late MockNodeRepository mockRepository;
    late MockCommandContext mockContext;

    setUp(() {
      mockRepository = MockNodeRepository();
      mockContext = MockCommandContext();
      handler = MoveNodeHandler(mockRepository);
    });

    test('should move node successfully', () async {
      final node = Node(
        id: 'test-id',
        title: 'Test Node',
        content: 'Content',
        references: {},
        position: const Offset(100, 100),
        size: const Size(200, 250),
        viewMode: NodeViewMode.fullContent,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: const {},
      );

      when(mockRepository.load('test-id')).thenAnswer((_) async => node);
      when(mockRepository.save(any)).thenAnswer((_) async {});

      final command = MoveNodeCommand(
        nodeId: 'test-id',
        newPosition: const Offset(200, 200),
      );

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, true);
      expect(command.oldPosition, const Offset(100, 100));
      verify(mockRepository.save(argThat(predicate<Node>((n) =>
        n.position == const Offset(200, 200)
      )))).called(1);
    });

    test('should fail when node does not exist', () async {
      when(mockRepository.load('non-existent')).thenAnswer((_) async => null);

      final command = MoveNodeCommand(
        nodeId: 'non-existent',
        newPosition: const Offset(200, 200),
      );

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, contains('节点不存在'));
    });

    test('should handle repository exceptions', () async {
      when(mockRepository.load('test-id')).thenThrow(Exception('Database error'));

      final command = MoveNodeCommand(
        nodeId: 'test-id',
        newPosition: const Offset(200, 200),
      );

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, contains('Exception'));
    });
  });

  group('ResizeNodeHandler', () {
    late ResizeNodeHandler handler;
    late MockNodeRepository mockRepository;
    late MockCommandContext mockContext;

    setUp(() {
      mockRepository = MockNodeRepository();
      mockContext = MockCommandContext();
      handler = ResizeNodeHandler(mockRepository);
    });

    test('should resize node successfully', () async {
      final node = Node(
        id: 'test-id',
        title: 'Test Node',
        content: 'Content',
        references: {},
        position: const Offset(100, 100),
        size: const Size(200, 250),
        viewMode: NodeViewMode.fullContent,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: const {},
      );

      when(mockRepository.load('test-id')).thenAnswer((_) async => node);
      when(mockRepository.save(any)).thenAnswer((_) async {});

      final command = ResizeNodeCommand(
        nodeId: 'test-id',
        newSize: const Size(300, 350),
      );

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, true);
      expect(command.oldSize, const Size(200, 250));
      verify(mockRepository.save(argThat(predicate<Node>((n) =>
        n.size == const Size(300, 350)
      )))).called(1);
    });

    test('should fail when node does not exist', () async {
      when(mockRepository.load('non-existent')).thenAnswer((_) async => null);

      final command = ResizeNodeCommand(
        nodeId: 'non-existent',
        newSize: const Size(300, 350),
      );

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, contains('节点不存在'));
    });

    test('should handle repository exceptions', () async {
      when(mockRepository.load('test-id')).thenThrow(Exception('Database error'));

      final command = ResizeNodeCommand(
        nodeId: 'test-id',
        newSize: const Size(300, 350),
      );

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, contains('Exception'));
    });
  });

  group('CreateGraphHandler', () {
    late CreateGraphHandler handler;
    late MockGraphService mockService;
    late MockCommandContext mockContext;

    setUp(() {
      mockService = MockGraphService();
      mockContext = MockCommandContext();
      handler = CreateGraphHandler(mockService);
    });

    test('should create graph successfully', () async {
      final graph = Graph(
        id: 'graph-1',
        name: 'Test Graph',
        nodeIds: [],
        viewConfig: GraphViewConfig.defaultConfig,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        nodePositions: {},
      );

      when(mockService.createGraph(name: anyNamed('name')))
          .thenAnswer((_) async => graph);

      final command = CreateGraphCommand(graphName: 'Test Graph');
      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, true);
      expect(result.data!.name, 'Test Graph');
      verify(mockService.createGraph(name: 'Test Graph')).called(1);
    });

    test('should fail when graph name is empty', () async {
      final command = CreateGraphCommand(graphName: '');
      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, '图名称不能为空');
      verifyNever(mockService.createGraph(name: anyNamed('name')));
    });

    test('should fail when graph name is whitespace only', () async {
      final command = CreateGraphCommand(graphName: '   ');
      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, '图名称不能为空');
      verifyNever(mockService.createGraph(name: anyNamed('name')));
    });

    test('should handle service exceptions', () async {
      when(mockService.createGraph(name: anyNamed('name')))
          .thenThrow(Exception('Create failed'));

      final command = CreateGraphCommand(graphName: 'Test Graph');
      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, contains('Exception'));
    });
  });

  group('LoadGraphHandler', () {
    late LoadGraphHandler handler;
    late MockGraphService mockService;
    late MockCommandContext mockContext;

    setUp(() {
      mockService = MockGraphService();
      mockContext = MockCommandContext();
      handler = LoadGraphHandler(mockService);
    });

    test('should load graph successfully', () async {
      final graph = Graph(
        id: 'graph-1',
        name: 'Test Graph',
        nodeIds: ['node-1', 'node-2'],
        viewConfig: GraphViewConfig.defaultConfig,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        nodePositions: {},
      );

      when(mockService.getGraph('graph-1')).thenAnswer((_) async => graph);

      final command = LoadGraphCommand(graphId: 'graph-1');
      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, true);
      expect(result.data!.id, 'graph-1');
      expect(result.data!.nodeIds.length, 2);
    });

    test('should fail when graph does not exist', () async {
      when(mockService.getGraph('non-existent')).thenAnswer((_) async => null);

      final command = LoadGraphCommand(graphId: 'non-existent');
      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, contains('图不存在'));
    });

    test('should handle service exceptions', () async {
      when(mockService.getGraph(any)).thenThrow(Exception('Load failed'));

      final command = LoadGraphCommand(graphId: 'graph-1');
      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, contains('Exception'));
    });
  });

  group('RenameGraphHandler', () {
    late RenameGraphHandler handler;
    late MockGraphService mockService;
    late MockCommandContext mockContext;

    setUp(() {
      mockService = MockGraphService();
      mockContext = MockCommandContext();
      handler = RenameGraphHandler(mockService);
    });

    test('should rename graph successfully', () async {
      final oldGraph = Graph(
        id: 'graph-1',
        name: 'Old Name',
        nodeIds: [],
        viewConfig: GraphViewConfig.defaultConfig,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        nodePositions: {},
      );

      final newGraph = Graph(
        id: 'graph-1',
        name: 'New Name',
        nodeIds: [],
        viewConfig: GraphViewConfig.defaultConfig,
        createdAt: oldGraph.createdAt,
        updatedAt: DateTime.now(),
        nodePositions: {},
      );

      when(mockService.getGraph('graph-1')).thenAnswer((_) async => oldGraph);
      when(mockService.updateGraph(any, name: anyNamed('name')))
          .thenAnswer((_) async => newGraph);

      final command = RenameGraphCommand(
        graphId: 'graph-1',
        updatedName: 'New Name',
      );
      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, true);
      expect(result.data!.name, 'New Name');
      expect(command.previousName, 'Old Name');
    });

    test('should fail when new name is empty', () async {
      final command = RenameGraphCommand(
        graphId: 'graph-1',
        updatedName: '',
      );
      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, '图名称不能为空');
    });

    test('should fail when graph does not exist', () async {
      when(mockService.getGraph('non-existent')).thenAnswer((_) async => null);

      final command = RenameGraphCommand(
        graphId: 'non-existent',
        updatedName: 'New Name',
      );
      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, contains('图不存在'));
    });
  });

  group('UpdateGraphHandler', () {
    late UpdateGraphHandler handler;
    late MockGraphService mockService;
    late MockCommandContext mockContext;

    setUp(() {
      mockService = MockGraphService();
      mockContext = MockCommandContext();
      handler = UpdateGraphHandler(mockService);
    });

    test('should update graph successfully', () async {
      final oldGraph = Graph(
        id: 'graph-1',
        name: 'Old Name',
        nodeIds: ['node-1'],
        viewConfig: GraphViewConfig.defaultConfig,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        nodePositions: {},
      );

      final newGraph = Graph(
        id: 'graph-1',
        name: 'Updated Name',
        nodeIds: ['node-1', 'node-2'],
        viewConfig: GraphViewConfig.defaultConfig,
        createdAt: oldGraph.createdAt,
        updatedAt: DateTime.now(),
        nodePositions: {},
      );

      when(mockService.getGraph('graph-1')).thenAnswer((_) async => oldGraph);
      when(mockService.updateGraph(
        any,
        name: anyNamed('name'),
        nodeIds: anyNamed('nodeIds'),
        viewConfig: anyNamed('viewConfig'),
        nodePositions: anyNamed('nodePositions'),
      )).thenAnswer((_) async => newGraph);

      final command = UpdateGraphCommand(
        graphId: 'graph-1',
        updatedName: 'Updated Name',
        nodeIds: ['node-1', 'node-2'],
      );
      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, true);
      expect(result.data!.name, 'Updated Name');
      expect(command.oldGraph!.name, 'Old Name');
    });

    test('should fail when graph does not exist', () async {
      when(mockService.getGraph('non-existent')).thenAnswer((_) async => null);

      final command = UpdateGraphCommand(graphId: 'non-existent');
      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, contains('图不存在'));
    });

    test('should handle service exceptions', () async {
      final oldGraph = Graph(
        id: 'graph-1',
        name: 'Test',
        nodeIds: [],
        viewConfig: GraphViewConfig.defaultConfig,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        nodePositions: {},
      );

      when(mockService.getGraph('graph-1')).thenAnswer((_) async => oldGraph);
      when(mockService.updateGraph(
        any,
        name: anyNamed('name'),
        nodeIds: anyNamed('nodeIds'),
        viewConfig: anyNamed('viewConfig'),
        nodePositions: anyNamed('nodePositions'),
      )).thenThrow(Exception('Update failed'));

      final command = UpdateGraphCommand(graphId: 'graph-1');
      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, contains('Exception'));
    });
  });

  group('AddNodeToGraphHandler', () {
    late AddNodeToGraphHandler handler;
    late MockGraphService mockService;
    late MockCommandContext mockContext;

    setUp(() {
      mockService = MockGraphService();
      mockContext = MockCommandContext();
      handler = AddNodeToGraphHandler(mockService);
    });

    test('should add node to graph successfully', () async {
      when(mockService.addNodeToGraph('graph-1', 'node-1'))
          .thenAnswer((_) async {});

      final command = AddNodeToGraphCommand(
        graphId: 'graph-1',
        nodeId: 'node-1',
      );
      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, true);
      verify(mockService.addNodeToGraph('graph-1', 'node-1')).called(1);
    });

    test('should handle service exceptions', () async {
      when(mockService.addNodeToGraph(any, any))
          .thenThrow(Exception('Add failed'));

      final command = AddNodeToGraphCommand(
        graphId: 'graph-1',
        nodeId: 'node-1',
      );
      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, contains('Exception'));
    });
  });

  group('RemoveNodeFromGraphHandler', () {
    late RemoveNodeFromGraphHandler handler;
    late MockGraphService mockService;
    late MockCommandContext mockContext;

    setUp(() {
      mockService = MockGraphService();
      mockContext = MockCommandContext();
      handler = RemoveNodeFromGraphHandler(mockService);
    });

    test('should remove node from graph successfully', () async {
      when(mockService.removeNodeFromGraph('graph-1', 'node-1'))
          .thenAnswer((_) async {});

      final command = RemoveNodeFromGraphCommand(
        graphId: 'graph-1',
        nodeId: 'node-1',
      );
      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, true);
      verify(mockService.removeNodeFromGraph('graph-1', 'node-1')).called(1);
    });

    test('should handle service exceptions', () async {
      when(mockService.removeNodeFromGraph(any, any))
          .thenThrow(Exception('Remove failed'));

      final command = RemoveNodeFromGraphCommand(
        graphId: 'graph-1',
        nodeId: 'node-1',
      );
      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, contains('Exception'));
    });
  });

  group('UpdateNodePositionHandler', () {
    late UpdateNodePositionHandler handler;
    late MockGraphRepository mockRepository;
    late MockCommandContext mockContext;

    setUp(() {
      mockRepository = MockGraphRepository();
      mockContext = MockCommandContext();
      handler = UpdateNodePositionHandler(mockRepository);
    });

    test('should update node position successfully', () async {
      final graph = Graph(
        id: 'graph-1',
        name: 'Test Graph',
        nodeIds: ['node-1'],
        viewConfig: GraphViewConfig.defaultConfig,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        nodePositions: {'node-1': const Offset(100, 100)},
      );

      when(mockRepository.load('graph-1')).thenAnswer((_) async => graph);
      when(mockRepository.save(any)).thenAnswer((_) async {});

      final command = UpdateNodePositionCommand(
        graphId: 'graph-1',
        nodeId: 'node-1',
        newPosition: const Offset(200, 200),
      );
      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, true);
      expect(command.oldPosition, const Offset(100, 100));
      verify(mockRepository.save(argThat(predicate<Graph>((g) =>
        g.nodePositions['node-1'] == const Offset(200, 200)
      )))).called(1);
    });

    test('should handle null old position', () async {
      final graph = Graph(
        id: 'graph-1',
        name: 'Test Graph',
        nodeIds: ['node-1'],
        viewConfig: GraphViewConfig.defaultConfig,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        nodePositions: {},
      );

      when(mockRepository.load('graph-1')).thenAnswer((_) async => graph);
      when(mockRepository.save(any)).thenAnswer((_) async {});

      final command = UpdateNodePositionCommand(
        graphId: 'graph-1',
        nodeId: 'node-1',
        newPosition: const Offset(200, 200),
      );
      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, true);
      expect(command.oldPosition, isNull);
    });

    test('should fail when graph does not exist', () async {
      when(mockRepository.load('non-existent')).thenAnswer((_) async => null);

      final command = UpdateNodePositionCommand(
        graphId: 'non-existent',
        nodeId: 'node-1',
        newPosition: const Offset(200, 200),
      );
      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, contains('图不存在'));
    });

    test('should handle repository exceptions', () async {
      when(mockRepository.load(any)).thenThrow(Exception('Database error'));

      final command = UpdateNodePositionCommand(
        graphId: 'graph-1',
        nodeId: 'node-1',
        newPosition: const Offset(200, 200),
      );
      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, contains('Exception'));
    });
  });
}
