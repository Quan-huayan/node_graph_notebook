import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/commands/models/command_context.dart';
import 'package:node_graph_notebook/core/events/app_events.dart';
import 'package:node_graph_notebook/core/models/enums.dart';
import 'package:node_graph_notebook/core/models/node.dart';
import 'package:node_graph_notebook/core/plugin/service_registry.dart';
import 'package:node_graph_notebook/core/repositories/graph_repository.dart';
import 'package:node_graph_notebook/core/repositories/metadata_index.dart';
import 'package:node_graph_notebook/core/repositories/node_repository.dart';
import 'package:node_graph_notebook/plugins/graph/service/graph_service.dart';
import 'package:node_graph_notebook/plugins/graph/service/node_service.dart';

Node _createTestNode({
  required String id,
  String title = '测试节点',
  String? content,
}) => Node(
    id: id,
    title: title,
    content: content,
    references: {},
    position: const Offset(100, 100),
    size: const Size(300, 400),
    viewMode: NodeViewMode.titleWithPreview,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    metadata: {},
  );

class MockNodeRepository implements NodeRepository {
  final Map<String, Node> _nodes = {};

  @override
  Future<void> save(Node node) async => _nodes[node.id] = node;

  @override
  Future<Node?> load(String id) async => _nodes[id];

  @override
  Future<void> delete(String id) async => _nodes.remove(id);

  @override
  Future<List<Node>> queryAll() async => _nodes.values.toList();

  @override
  Future<List<Node>> loadAll(List<String> nodeIds) async =>
      _nodes.values.where((n) => nodeIds.contains(n.id)).toList();

  @override
  Future<List<Node>> search({
    String? title,
    String? content,
    List<String>? tags,
    DateTime? startDate,
    DateTime? endDate,
  }) async => [];

  @override
  Future<void> saveAll(List<Node> nodes) async {
    for (final node in nodes) {
      _nodes[node.id] = node;
    }
  }

  Future<bool> exists(String id) async => _nodes.containsKey(id);

  Future<int> count() async => _nodes.length;

  @override
  String getNodeFilePath(String nodeId) => 'data/nodes/$nodeId.md';

  @override
  Future<MetadataIndex> getMetadataIndex() async =>
      MetadataIndex(nodes: [], lastUpdated: DateTime.now());

  @override
  Future<void> updateIndex(Node node) async {}
}

class MockGraphRepository implements GraphRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockNodeService implements NodeService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockGraphService implements GraphService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  group('CommandContext', () {
    test('应该创建带有服务的上下文', () {
      final nodeRepository = MockNodeRepository();
      final graphRepository = MockGraphRepository();
      final nodeService = MockNodeService();
      final graphService = MockGraphService();

      final context = CommandContext(
        nodeRepository: nodeRepository,
        graphRepository: graphRepository,
        additionalServices: {
          MockNodeService: nodeService,
          MockGraphService: graphService,
        },
      );

      expect(context.nodeRepository, equals(nodeRepository));
      expect(context.graphRepository, equals(graphRepository));
      expect(context.read<MockNodeService>(), equals(nodeService));
      expect(context.read<MockGraphService>(), equals(graphService));
    });

    test('应该为缺失的服务抛出ServiceNotFoundException', () {
      final context = CommandContext();

      expect(() => context.nodeRepository, throwsA(isA<ServiceNotFoundException>()));
      expect(() => context.graphRepository, throwsA(isA<ServiceNotFoundException>()));
    });

    test('应该为可选的缺失服务返回null', () {
      final context = CommandContext();

      expect(context.tryRead<MockNodeService>(), isNull);
      expect(context.tryRead<MockGraphService>(), isNull);
    });

    test('应该注册和读取自定义服务', () {
      final context = CommandContext();
      final customService = MockNodeService();

      context.registerService<MockNodeService>(customService);

      expect(context.read<MockNodeService>(), equals(customService));
    });

    test('应该为缺失的服务返回null', () {
      final context = CommandContext();

      expect(context.tryRead<MockNodeService>(), isNull);
    });

    test('应该设置和获取元数据', () {
      final context = CommandContext()

      ..setMetadata('key1', 'value1')
      ..setMetadata('key2', 123);

      expect(context.getMetadata('key1'), equals('value1'));
      expect(context.getMetadata('key2'), equals(123));
      expect(context.getMetadata('nonexistent'), isNull);
    });

    test('应该检查元数据是否存在', () {
      final context = CommandContext()

      ..setMetadata('key1', 'value1');

      expect(context.hasMetadata('key1'), isTrue);
      expect(context.hasMetadata('nonexistent'), isFalse);
    });

    test('应该清除元数据', () {
      final context = CommandContext()

      ..setMetadata('key1', 'value1')
      ..setMetadata('key2', 'value2')
      ..clearMetadata();

      expect(context.hasMetadata('key1'), isFalse);
      expect(context.hasMetadata('key2'), isFalse);
    });

    test('应该创建带有继承服务的子上下文', () {
      final nodeRepository = MockNodeRepository();
      final graphRepository = MockGraphRepository();

      final parent = CommandContext(
        nodeRepository: nodeRepository,
        graphRepository: graphRepository,
      )

      ..setMetadata('parentKey', 'parentValue');

      final child = parent.createChild();

      expect(child.nodeRepository, equals(nodeRepository));
      expect(child.graphRepository, equals(graphRepository));
      expect(child.getMetadata('parentKey'), equals('parentValue'));
    });

    test('子上下文应该有独立的元数据', () {
      final parent = CommandContext()
      ..setMetadata('key', 'parentValue');

      final child = parent.createChild()
      ..setMetadata('key', 'childValue');

      expect(parent.getMetadata('key'), equals('parentValue'));
      expect(child.getMetadata('key'), equals('childValue'));
    });

    test('应该发布节点事件', () async {
      final context = CommandContext();
      final node = _createTestNode(id: 'test-id');

      context.publishSingleNodeEvent(node, DataChangeAction.create);

      // 检查待处理事件而不是订阅 eventBus
      final pendingEvents = context.getPendingEvents();
      expect(pendingEvents.length, equals(1));
      expect(pendingEvents.first, isA<NodeDataChangedEvent>());

      final event = pendingEvents.first as NodeDataChangedEvent;
      expect(event.changedNodes.length, equals(1));
      expect(event.changedNodes.first.id, equals('test-id'));
      expect(event.action, equals(DataChangeAction.create));
    });

    test('应该发布多个节点事件', () async {
      final context = CommandContext();
      final nodes = <Node>[
        _createTestNode(id: 'node-1', title: '节点 1'),
        _createTestNode(id: 'node-2', title: '节点 2'),
      ];

      context.publishNodeEvent(nodes, DataChangeAction.update);

      // 检查待处理事件而不是订阅 eventBus
      final pendingEvents = context.getPendingEvents();
      expect(pendingEvents.length, equals(1));
      expect(pendingEvents.first, isA<NodeDataChangedEvent>());

      final event = pendingEvents.first as NodeDataChangedEvent;
      expect(event.changedNodes.length, equals(2));
      expect(event.action, equals(DataChangeAction.update));
    });

    test('应该发布图谱关系事件', () async {
      final context = CommandContext();

      context.publishGraphRelationEvent(
        'graph-1',
        ['node-1', 'node-2'],
        RelationChangeAction.addedToGraph,
      );

      // 检查待处理事件而不是订阅 eventBus
      final pendingEvents = context.getPendingEvents();
      expect(pendingEvents.length, equals(1));
      expect(pendingEvents.first, isA<GraphNodeRelationChangedEvent>());

      final event = pendingEvents.first as GraphNodeRelationChangedEvent;
      expect(event.graphId, equals('graph-1'));
      expect(event.nodeIds.length, equals(2));
      expect(event.action, equals(RelationChangeAction.addedToGraph));
    });

    test('应该跟踪事务状态', () async {
      final context = CommandContext();

      expect(context.isInTransaction, isFalse);

      final result = await context.withTransaction(() async {
        expect(context.isInTransaction, isTrue);
        return 'success';
      });

      expect(result, equals('success'));
      expect(context.isInTransaction, isFalse);
    });

    test('应该在错误时将事务标记为已回滚', () async {
      final context = CommandContext();

      expect(context.isInTransaction, isFalse);

      try {
        await context.withTransaction(() async {
          expect(context.isInTransaction, isTrue);
          throw Exception('Test error');
        });
      } catch (e) {
        expect(e.toString(), contains('Test error'));
      }

      expect(context.isInTransaction, isFalse);
      expect(context.getMetadata('_transaction_rolled_back'), isTrue);
    });
  });

  group('ServiceNotFoundException', () {
    test('应该使用消息创建异常', () {
      const message = 'Service not found: TestService';
      const exception = ServiceNotFoundException(message);

      expect(exception.message, equals(message));
      expect(exception.toString(), contains(message));
    });
  });
}
