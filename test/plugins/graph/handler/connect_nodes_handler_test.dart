import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:node_graph_notebook/core/commands/models/command_context.dart';
import 'package:node_graph_notebook/core/events/app_events.dart';
import 'package:node_graph_notebook/core/models/models.dart';
import 'package:node_graph_notebook/core/repositories/node_repository.dart';
import 'package:node_graph_notebook/plugins/graph/command/node_commands.dart';
import 'package:node_graph_notebook/plugins/graph/handler/connect_nodes_handler.dart';

@GenerateMocks([NodeRepository, CommandContext])
import 'connect_nodes_handler_test.mocks.dart';

void main() {
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
        position: Offset.zero,
        size: const Size(100, 100),
        viewMode: NodeViewMode.titleOnly,
        color: '#000000',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: {},
      );

      final targetNode = Node(
        id: 'target-id',
        title: 'Target Node',
        content: 'Target Content',
        references: {},
        position: const Offset(100, 100),
        size: const Size(100, 100),
        viewMode: NodeViewMode.titleOnly,
        color: '#000000',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: {},
      );

      final command = ConnectNodesCommand(
        sourceId: 'source-id',
        targetId: 'target-id',
      );

      when(mockRepository.load('source-id')).thenAnswer((_) async => sourceNode);
      when(mockRepository.load('target-id')).thenAnswer((_) async => targetNode);
      when(mockRepository.save(any)).thenAnswer((_) async => 'updated-id');

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, true);
      verify(mockRepository.load('source-id')).called(1);
      verify(mockRepository.load('target-id')).called(1);
      verify(mockRepository.save(any)).called(1);
      verify(mockContext.publishSingleNodeEvent(any, DataChangeAction.update)).called(1);
    });

    test('should fail when source node does not exist', () async {
      final targetNode = Node(
        id: 'target-id',
        title: 'Target Node',
        content: 'Target Content',
        references: {},
        position: const Offset(100, 100),
        size: const Size(100, 100),
        viewMode: NodeViewMode.titleOnly,
        color: '#000000',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: {},
      );

      final command = ConnectNodesCommand(
        sourceId: 'source-id',
        targetId: 'target-id',
      );

      when(mockRepository.load('source-id')).thenAnswer((_) async => null);
      when(mockRepository.load('target-id')).thenAnswer((_) async => targetNode);

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, contains('源节点不存在'));
      verifyNever(mockRepository.save(any));
      verifyNever(mockContext.publishSingleNodeEvent(any, any));
    });

    test('should fail when target node does not exist', () async {
      final sourceNode = Node(
        id: 'source-id',
        title: 'Source Node',
        content: 'Source Content',
        references: {},
        position: Offset.zero,
        size: const Size(100, 100),
        viewMode: NodeViewMode.titleOnly,
        color: '#000000',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: {},
      );

      final command = ConnectNodesCommand(
        sourceId: 'source-id',
        targetId: 'target-id',
      );

      when(mockRepository.load('source-id')).thenAnswer((_) async => sourceNode);
      when(mockRepository.load('target-id')).thenAnswer((_) async => null);

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, contains('目标节点不存在'));
      verifyNever(mockRepository.save(any));
      verifyNever(mockContext.publishSingleNodeEvent(any, any));
    });

    test('should fail when connection already exists', () async {
      const existingReference = NodeReference(
        nodeId: 'target-id',
        properties: {},
      );

      final sourceNode = Node(
        id: 'source-id',
        title: 'Source Node',
        content: 'Source Content',
        references: {'target-id': existingReference},
        position: Offset.zero,
        size: const Size(100, 100),
        viewMode: NodeViewMode.titleOnly,
        color: '#000000',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: {},
      );

      final targetNode = Node(
        id: 'target-id',
        title: 'Target Node',
        content: 'Target Content',
        references: {},
        position: const Offset(100, 100),
        size: const Size(100, 100),
        viewMode: NodeViewMode.titleOnly,
        color: '#000000',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: {},
      );

      final command = ConnectNodesCommand(
        sourceId: 'source-id',
        targetId: 'target-id',
      );

      when(mockRepository.load('source-id')).thenAnswer((_) async => sourceNode);
      when(mockRepository.load('target-id')).thenAnswer((_) async => targetNode);

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, contains('节点连接已存在'));
      verifyNever(mockRepository.save(any));
      verifyNever(mockContext.publishSingleNodeEvent(any, any));
    });

    test('should connect nodes with properties', () async {
      final sourceNode = Node(
        id: 'source-id',
        title: 'Source Node',
        content: 'Source Content',
        references: {},
        position: Offset.zero,
        size: const Size(100, 100),
        viewMode: NodeViewMode.titleOnly,
        color: '#000000',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: {},
      );

      final targetNode = Node(
        id: 'target-id',
        title: 'Target Node',
        content: 'Target Content',
        references: {},
        position: const Offset(100, 100),
        size: const Size(100, 100),
        viewMode: NodeViewMode.titleOnly,
        color: '#000000',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: {},
      );

      final command = ConnectNodesCommand(
        sourceId: 'source-id',
        targetId: 'target-id',
        properties: {'type': 'related', 'strength': 0.8},
      );

      when(mockRepository.load('source-id')).thenAnswer((_) async => sourceNode);
      when(mockRepository.load('target-id')).thenAnswer((_) async => targetNode);
      when(mockRepository.save(any)).thenAnswer((_) async => 'updated-id');

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, true);
      verify(mockRepository.save(any)).called(1);
      verify(mockContext.publishSingleNodeEvent(any, DataChangeAction.update)).called(1);
    });

    test('should handle repository errors', () async {
      final sourceNode = Node(
        id: 'source-id',
        title: 'Source Node',
        content: 'Source Content',
        references: {},
        position: Offset.zero,
        size: const Size(100, 100),
        viewMode: NodeViewMode.titleOnly,
        color: '#000000',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: {},
      );

      final command = ConnectNodesCommand(
        sourceId: 'source-id',
        targetId: 'target-id',
      );

      when(mockRepository.load('source-id')).thenAnswer((_) async => sourceNode);
      when(mockRepository.load('target-id')).thenThrow(Exception('Repository error'));

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, contains('Repository error'));
      verifyNever(mockRepository.save(any));
      verifyNever(mockContext.publishSingleNodeEvent(any, any));
    });
  });
}