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
  String title = 'Test Node',
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
    test('should create context with services', () {
      final nodeRepository = MockNodeRepository();
      final graphRepository = MockGraphRepository();
      final nodeService = MockNodeService();
      final graphService = MockGraphService();
      final eventBus = AppEventBus.createForTest();

      final context = CommandContext(
        nodeRepository: nodeRepository,
        graphRepository: graphRepository,
        eventBus: eventBus,
        additionalServices: {
          MockNodeService: nodeService,
          MockGraphService: graphService,
        },
      );

      expect(context.nodeRepository, equals(nodeRepository));
      expect(context.graphRepository, equals(graphRepository));
      expect(context.read<MockNodeService>(), equals(nodeService));
      expect(context.read<MockGraphService>(), equals(graphService));
      expect(context.eventBus, equals(eventBus));

      eventBus.dispose();
    });

    test('should throw ServiceNotFoundException for missing service', () {
      final context = CommandContext();

      expect(() => context.nodeRepository, throwsA(isA<ServiceNotFoundException>()));
      expect(() => context.graphRepository, throwsA(isA<ServiceNotFoundException>()));
    });

    test('should return null for optional missing services', () {
      final context = CommandContext();

      expect(context.tryRead<MockNodeService>(), isNull);
      expect(context.tryRead<MockGraphService>(), isNull);
    });

    test('should register and read custom services', () {
      final context = CommandContext();
      final customService = MockNodeService();

      context.registerService<MockNodeService>(customService);

      expect(context.read<MockNodeService>(), equals(customService));
    });

    test('should tryRead returns null for missing service', () {
      final context = CommandContext();

      expect(context.tryRead<MockNodeService>(), isNull);
    });

    test('should set and get metadata', () {
      final context = CommandContext()

      ..setMetadata('key1', 'value1')
      ..setMetadata('key2', 123);

      expect(context.getMetadata('key1'), equals('value1'));
      expect(context.getMetadata('key2'), equals(123));
      expect(context.getMetadata('nonexistent'), isNull);
    });

    test('should check metadata existence', () {
      final context = CommandContext()

      ..setMetadata('key1', 'value1');

      expect(context.hasMetadata('key1'), isTrue);
      expect(context.hasMetadata('nonexistent'), isFalse);
    });

    test('should clear metadata', () {
      final context = CommandContext()

      ..setMetadata('key1', 'value1')
      ..setMetadata('key2', 'value2')
      ..clearMetadata();

      expect(context.hasMetadata('key1'), isFalse);
      expect(context.hasMetadata('key2'), isFalse);
    });

    test('should create child context with inherited services', () {
      final nodeRepository = MockNodeRepository();
      final graphRepository = MockGraphRepository();
      final eventBus = AppEventBus.createForTest();

      final parent = CommandContext(
        nodeRepository: nodeRepository,
        graphRepository: graphRepository,
        eventBus: eventBus,
      )

      ..setMetadata('parentKey', 'parentValue');

      final child = parent.createChild();

      expect(child.nodeRepository, equals(nodeRepository));
      expect(child.graphRepository, equals(graphRepository));
      expect(child.getMetadata('parentKey'), equals('parentValue'));

      eventBus.dispose();
    });

    test('child context should have independent metadata', () {
      final parent = CommandContext()
      ..setMetadata('key', 'parentValue');

      final child = parent.createChild()
      ..setMetadata('key', 'childValue');

      expect(parent.getMetadata('key'), equals('parentValue'));
      expect(child.getMetadata('key'), equals('childValue'));
    });

    test('should publish node event', () async {
      final eventBus = AppEventBus.createForTest();
      final context = CommandContext(eventBus: eventBus);
      final node = _createTestNode(id: 'test-id');

      NodeDataChangedEvent? receivedEvent;
      eventBus.stream.listen((event) {
        if (event is NodeDataChangedEvent) {
          receivedEvent = event;
        }
      });

      context.publishSingleNodeEvent(node, DataChangeAction.create);

      await Future.delayed(const Duration(milliseconds: 10));

      expect(receivedEvent, isNotNull);
      expect(receivedEvent!.changedNodes.length, equals(1));
      expect(receivedEvent!.changedNodes.first.id, equals('test-id'));
      expect(receivedEvent!.action, equals(DataChangeAction.create));

      eventBus.dispose();
    });

    test('should publish multiple nodes event', () async {
      final eventBus = AppEventBus.createForTest();
      final context = CommandContext(eventBus: eventBus);
      final nodes = <Node>[
        _createTestNode(id: 'node-1', title: 'Node 1'),
        _createTestNode(id: 'node-2', title: 'Node 2'),
      ];

      NodeDataChangedEvent? receivedEvent;
      eventBus.stream.listen((event) {
        if (event is NodeDataChangedEvent) {
          receivedEvent = event;
        }
      });

      context.publishNodeEvent(nodes, DataChangeAction.update);

      await Future.delayed(const Duration(milliseconds: 10));

      expect(receivedEvent, isNotNull);
      expect(receivedEvent!.changedNodes.length, equals(2));
      expect(receivedEvent!.action, equals(DataChangeAction.update));

      eventBus.dispose();
    });

    test('should publish graph relation event', () async {
      final eventBus = AppEventBus.createForTest();
      final context = CommandContext(eventBus: eventBus);

      GraphNodeRelationChangedEvent? receivedEvent;
      eventBus.stream.listen((event) {
        if (event is GraphNodeRelationChangedEvent) {
          receivedEvent = event;
        }
      });

      context.publishGraphRelationEvent(
        'graph-1',
        ['node-1', 'node-2'],
        RelationChangeAction.addedToGraph,
      );

      await Future.delayed(const Duration(milliseconds: 10));

      expect(receivedEvent, isNotNull);
      expect(receivedEvent!.graphId, equals('graph-1'));
      expect(receivedEvent!.nodeIds.length, equals(2));
      expect(receivedEvent!.action, equals(RelationChangeAction.addedToGraph));

      eventBus.dispose();
    });

    test('should track transaction state', () async {
      final context = CommandContext();

      expect(context.isInTransaction, isFalse);

      final result = await context.withTransaction(() async {
        expect(context.isInTransaction, isTrue);
        return 'success';
      });

      expect(result, equals('success'));
      expect(context.isInTransaction, isFalse);
    });

    test('should mark transaction as rolled back on error', () async {
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
    test('should create exception with message', () {
      const message = 'Service not found: TestService';
      const exception = ServiceNotFoundException(message);

      expect(exception.message, equals(message));
      expect(exception.toString(), contains(message));
    });
  });
}
