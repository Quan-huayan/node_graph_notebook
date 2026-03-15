import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:node_graph_notebook/core/commands/command_context.dart';
import 'package:node_graph_notebook/core/commands/handlers/create_node_handler.dart';
import 'package:node_graph_notebook/core/commands/impl/node_commands.dart';
import 'package:node_graph_notebook/core/events/app_events.dart';
import 'package:node_graph_notebook/core/models/node.dart';
import 'package:node_graph_notebook/core/models/enums.dart';
import 'package:node_graph_notebook/core/services/node_service.dart';

import 'create_node_handler_test.mocks.dart';

@GenerateMocks([NodeService])
void main() {
  group('CreateNodeHandler', () {
    late MockNodeService mockService;
    late CreateNodeHandler handler;
    late CommandContext context;

    setUp(() {
      mockService = MockNodeService();
      handler = CreateNodeHandler(mockService);
      context = CommandContext();
    });

    test('应该成功创建节点', () async {
      // Arrange
      final now = DateTime.now();
      final testNode = Node(
        id: 'node-1',
        title: 'Test Node',
        references: const {},
        position: const Offset(100, 100),
        size: const Size(200, 250),
        viewMode: NodeViewMode.titleWithPreview,
        createdAt: now,
        updatedAt: now,
        metadata: const {},
      );
      final command = CreateNodeCommand(title: 'Test Node');

      when(mockService.createNode(
        title: anyNamed('title'),
        content: anyNamed('content'),
        position: anyNamed('position'),
      )).thenAnswer((_) async => testNode);

      // Act
      final result = await handler.execute(command, context);

      // Assert
      expect(result.isSuccess, true);
      expect(result.data, testNode);
      verify(mockService.createNode(
        title: 'Test Node',
        content: null,
        position: null,
      )).called(1);
    });

    test('应该拒绝空标题', () async {
      // Arrange
      final command = CreateNodeCommand(title: '   ');

      // Act
      final result = await handler.execute(command, context);

      // Assert
      expect(result.isSuccess, false);
      expect(result.error, contains('标题不能为空'));
      verifyNever(mockService.createNode(
        title: anyNamed('title'),
        content: anyNamed('content'),
        position: anyNamed('position'),
      ));
    });

    test('应该传递所有参数到服务', () async {
      // Arrange
      final now = DateTime.now();
      final testNode = Node(
        id: 'node-1',
        title: 'Test Node',
        references: const {},
        position: const Offset(100, 100),
        size: const Size(200, 250),
        viewMode: NodeViewMode.titleWithPreview,
        createdAt: now,
        updatedAt: now,
        metadata: const {},
      );
      final testPosition = const Offset(100, 200);
      final testContent = 'Test content';

      final command = CreateNodeCommand(
        title: 'Test Node',
        content: testContent,
        position: testPosition,
      );

      when(mockService.createNode(
        title: anyNamed('title'),
        content: anyNamed('content'),
        position: anyNamed('position'),
      )).thenAnswer((_) async => testNode);

      // Act
      await handler.execute(command, context);

      // Assert
      verify(mockService.createNode(
        title: 'Test Node',
        content: testContent,
        position: testPosition,
      )).called(1);
    });

    test('应该发布 NodeDataChangedEvent', () async {
      // Arrange
      final now = DateTime.now();
      final testNode = Node(
        id: 'node-1',
        title: 'Test Node',
        references: const {},
        position: const Offset(100, 100),
        size: const Size(200, 250),
        viewMode: NodeViewMode.titleWithPreview,
        createdAt: now,
        updatedAt: now,
        metadata: const {},
      );
      final command = CreateNodeCommand(title: 'Test Node');

      final eventList = <NodeDataChangedEvent>[];
      context.eventBus.stream.listen((event) {
        if (event is NodeDataChangedEvent) {
          eventList.add(event);
        }
      });

      when(mockService.createNode(
        title: anyNamed('title'),
        content: anyNamed('content'),
        position: anyNamed('position'),
      )).thenAnswer((_) async => testNode);

      // Act
      await handler.execute(command, context);
      await Future.delayed(const Duration(milliseconds: 10));

      // Assert
      expect(eventList.length, 1);
      expect(eventList[0].action, DataChangeAction.create);
      expect(eventList[0].changedNodes, [testNode]);
    });

    test('应该处理服务异常', () async {
      // Arrange
      final command = CreateNodeCommand(title: 'Test Node');

      when(mockService.createNode(
        title: anyNamed('title'),
        content: anyNamed('content'),
        position: anyNamed('position'),
      )).thenThrow(Exception('Service error'));

      // Act
      final result = await handler.execute(command, context);

      // Assert
      expect(result.isSuccess, false);
      expect(result.error, contains('Service error'));
    });
  });
}
