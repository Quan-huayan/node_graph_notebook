import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:node_graph_notebook/core/commands/models/command_context.dart';
import 'package:node_graph_notebook/core/events/app_events.dart';
import 'package:node_graph_notebook/core/models/models.dart';
import 'package:node_graph_notebook/plugins/graph/command/node_commands.dart';
import 'package:node_graph_notebook/plugins/graph/handler/create_node_handler.dart';
import 'package:node_graph_notebook/plugins/graph/service/node_service.dart';

@GenerateMocks([NodeService, CommandContext])
import 'create_node_handler_test.mocks.dart';

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

    test('应该成功创建节点', () async {
      final command = CreateNodeCommand(
        title: 'Test Node',
        content: 'Test Content',
      );

      final testNode = Node(
        id: 'test-id',
        title: 'Test Node',
        content: 'Test Content',
        references: {},
        position: Offset.zero,
        size: const Size(100, 100),
        viewMode: NodeViewMode.titleOnly,
        color: '#000000',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: {},
      );

      when(mockService.createNode(
        title: anyNamed('title'),
        content: anyNamed('content'),
        position: anyNamed('position'),
      )).thenAnswer((_) async => testNode);

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, true);
      expect(result.data?.title, 'Test Node');
      verify(mockService.createNode(
        title: 'Test Node',
        content: 'Test Content',
        position: null,
      )).called(1);
      verify(mockContext.publishSingleNodeEvent(testNode, DataChangeAction.create)).called(1);
    });

    test('应该验证空标题', () async {
      final command = CreateNodeCommand(title: '');

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, contains('标题不能为空'));
      verifyNever(mockService.createNode(
        title: anyNamed('title'),
        content: anyNamed('content'),
        position: anyNamed('position'),
      ));
      verifyNever(mockContext.publishSingleNodeEvent(any, any));
    });

    test('应该验证仅包含空白字符的标题', () async {
      final command = CreateNodeCommand(title: '   ');

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, contains('标题不能为空'));
      verifyNever(mockService.createNode(
        title: anyNamed('title'),
        content: anyNamed('content'),
        position: anyNamed('position'),
      ));
      verifyNever(mockContext.publishSingleNodeEvent(any, any));
    });

    test('应该处理服务错误', () async {
      final command = CreateNodeCommand(
        title: 'Test Node',
        content: 'Test Content',
      );

      when(mockService.createNode(
        title: anyNamed('title'),
        content: anyNamed('content'),
        position: anyNamed('position'),
      )).thenThrow(Exception('Service error'));

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, contains('Service error'));
      verifyNever(mockContext.publishSingleNodeEvent(any, any));
    });

    test('应该创建带位置的节点', () async {
      final command = CreateNodeCommand(
        title: 'Test Node',
        content: 'Test Content',
        position: const Offset(100, 200),
      );

      final testNode = Node(
        id: 'test-id',
        title: 'Test Node',
        content: 'Test Content',
        references: {},
        position: const Offset(100, 200),
        size: const Size(100, 100),
        viewMode: NodeViewMode.titleOnly,
        color: '#000000',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: {},
      );

      when(mockService.createNode(
        title: anyNamed('title'),
        content: anyNamed('content'),
        position: anyNamed('position'),
      )).thenAnswer((_) async => testNode);

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, true);
      verify(mockService.createNode(
        title: 'Test Node',
        content: 'Test Content',
        position: const Offset(100, 200),
      )).called(1);
    });

    test('应该创建内容为空的新节点', () async {
      final command = CreateNodeCommand(
        title: 'Test Node',
        content: null,
      );

      final testNode = Node(
        id: 'test-id',
        title: 'Test Node',
        content: null,
        references: {},
        position: Offset.zero,
        size: const Size(100, 100),
        viewMode: NodeViewMode.titleOnly,
        color: '#000000',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: {},
      );

      when(mockService.createNode(
        title: anyNamed('title'),
        content: anyNamed('content'),
        position: anyNamed('position'),
      )).thenAnswer((_) async => testNode);

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, true);
      verify(mockService.createNode(
        title: 'Test Node',
        content: null,
        position: null,
      )).called(1);
    });
  });
}