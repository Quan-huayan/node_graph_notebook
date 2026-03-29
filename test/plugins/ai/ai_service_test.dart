import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/models/connection.dart';
import 'package:node_graph_notebook/core/models/enums.dart';
import 'package:node_graph_notebook/core/models/node.dart';
import 'package:node_graph_notebook/plugins/ai/service/ai_service.dart';

void main() {
  group('AIServiceImpl', () {
    late AIServiceImpl aiService;
    late MockAIProvider mockProvider;

    setUp(() {
      mockProvider = MockAIProvider();
      aiService = AIServiceImpl(mockProvider);
    });

    test('应该具有正确的初始状态', () {
      expect(aiService.isAvailable, true);
      expect(aiService.serviceName, 'Mock AI Provider');
    });

    test('当provider为空时应该不可用', () {
      final service = AIServiceImpl();
      expect(service.isAvailable, false);
      expect(service.serviceName, 'No Provider');
    });

    test('应该正确设置provider', () {
      final newProvider = MockAIProvider();
      aiService.setProvider(newProvider);
      expect(aiService.isAvailable, true);
      expect(aiService.serviceName, 'Mock AI Provider');
    });

    test('应该正确生成节点', () async {
      mockProvider.response = 'Generated Title\nGenerated content here';
      final node = await aiService.generateNode(prompt: 'Test prompt');

      expect(node.title, 'Generated Title');
      expect(node.content, 'Generated content here');
      expect(node.id, isNotEmpty);
      expect(node.position, const Offset(100, 100));
      expect(node.size, const Size(300, 400));
    });

    test('应该处理generateNode中的空响应', () async {
      mockProvider.response = '';
      final node = await aiService.generateNode(prompt: 'Test prompt');

      expect(node.title, 'Untitled');
      expect(node.content, isEmpty);
    });

    test('应该正确总结节点', () async {
      mockProvider.response = 'This is a summary';
      final node = Node(
        id: '1',
        title: 'Test Node',
        content: 'Test content',
        references: {},
        position: Offset.zero,
        size: const Size(200, 200),
        viewMode: NodeViewMode.titleWithPreview,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: {},
      );

      final summary = await aiService.summarizeNode(node);
      expect(summary, 'This is a summary');
    });

    test('当未设置provider时generateNode应该抛出异常', () async {
      final service = AIServiceImpl();
      expect(
        () => service.generateNode(prompt: 'test'),
        throwsA(isA<AIServiceException>()),
      );
    });

    test('当未设置provider时summarizeNode应该抛出异常', () async {
      final service = AIServiceImpl();
      final node = Node(
        id: '1',
        title: 'Test',
        references: {},
        position: Offset.zero,
        size: const Size(200, 200),
        viewMode: NodeViewMode.titleWithPreview,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: {},
      );

      expect(
        () => service.summarizeNode(node),
        throwsA(isA<AIServiceException>()),
      );
    });

    test('应该基于相似性建议连接', () async {
      final nodes = [
        Node(
          id: '1',
          title: 'Test Node',
          references: {},
          position: Offset.zero,
          size: const Size(200, 200),
          viewMode: NodeViewMode.titleWithPreview,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: {},
        ),
        Node(
          id: '2',
          title: 'Test Node 2',
          references: {},
          position: const Offset(100, 100),
          size: const Size(200, 200),
          viewMode: NodeViewMode.titleWithPreview,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: {},
        ),
      ];

      final suggestions = await aiService.suggestConnections(nodes: nodes);
      expect(suggestions.length, greaterThan(0));
      expect(suggestions[0].fromNodeId, '1');
      expect(suggestions[0].toNodeId, '2');
      expect(suggestions[0].relationType, 'relatesTo');
    });

    test('应该通过maxSuggestions限制建议数量', () async {
      final nodes = List.generate(
        15,
        (i) => Node(
          id: i.toString(),
          title: 'Node $i',
          references: {},
          position: Offset(i * 10.0, i * 10.0),
          size: const Size(200, 200),
          viewMode: NodeViewMode.titleWithPreview,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: {},
        ),
      );

      final suggestions = await aiService.suggestConnections(
        nodes: nodes,
        maxSuggestions: 5,
      );
      expect(suggestions.length, lessThanOrEqualTo(5));
    });

    test('应该正确分析节点', () async {
      mockProvider.response = 'Analysis result';
      final node = Node(
        id: '1',
        title: 'Test Node Title',
        references: {},
        position: Offset.zero,
        size: const Size(200, 200),
        viewMode: NodeViewMode.titleWithPreview,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: {},
      );

      final analysis = await aiService.analyzeNode(node);
      expect(analysis.nodeId, '1');
      expect(analysis.summary, 'Analysis result');
      expect(analysis.keywords, ['Test', 'Node', 'Title']);
      expect(analysis.topics, ['Topic 1', 'Topic 2']);
      expect(analysis.sentiment, 'neutral');
    });

    test('应该正确生成图谱摘要', () async {
      mockProvider.response = 'Graph summary text';
      final nodes = [
        Node(
          id: '1',
          title: 'Node 1',
          references: {},
          position: Offset.zero,
          size: const Size(200, 200),
          viewMode: NodeViewMode.titleWithPreview,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: {},
        ),
        Node(
          id: '2',
          title: 'Node 2',
          references: {},
          position: const Offset(100, 100),
          size: const Size(200, 200),
          viewMode: NodeViewMode.titleWithPreview,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: {},
        ),
      ];
      final connections = [
        const Connection(
          id: 'c1',
          fromNodeId: '1',
          toNodeId: '2',
          type: 'relatesTo',
          lineStyle: LineStyle.solid,
          thickness: 1.5,
        ),
      ];

      final summary = await aiService.generateGraphSummary(nodes, connections);
      expect(summary.title, 'Graph Summary');
      expect(summary.description, 'Graph summary text');
      expect(summary.nodeCount, 2);
      expect(summary.connectionCount, 1);
    });

    test('应该正确建议节点主题', () async {
      mockProvider.response = 'Topic 1\nTopic 2\nTopic 3\nTopic 4\nTopic 5';
      final nodes = [
        Node(
          id: '1',
          title: 'Existing Topic',
          references: {},
          position: Offset.zero,
          size: const Size(200, 200),
          viewMode: NodeViewMode.titleWithPreview,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: {},
        ),
      ];

      final topics = await aiService.suggestNodeTopics(nodes);
      expect(topics.length, 5);
      expect(topics, contains('Topic 1'));
      expect(topics, contains('Topic 5'));
    });

    test('当未设置provider时analyzeNode应该抛出异常', () async {
      final service = AIServiceImpl();
      final node = Node(
        id: '1',
        title: 'Test',
        references: {},
        position: Offset.zero,
        size: const Size(200, 200),
        viewMode: NodeViewMode.titleWithPreview,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: {},
      );

      expect(
        () => service.analyzeNode(node),
        throwsA(isA<AIServiceException>()),
      );
    });

    test('当未设置provider时suggestConnections应该抛出异常', () async {
      final service = AIServiceImpl();
      final nodes = [
        Node(
          id: '1',
          title: 'Test',
          references: {},
          position: Offset.zero,
          size: const Size(200, 200),
          viewMode: NodeViewMode.titleWithPreview,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: {},
        ),
      ];

      expect(
        () => service.suggestConnections(nodes: nodes),
        throwsA(isA<AIServiceException>()),
      );
    });

    test('对于相同标题应该正确计算相似度', () {
      final node1 = Node(
        id: '1',
        title: 'Test Node',
        references: {},
        position: Offset.zero,
        size: const Size(200, 200),
        viewMode: NodeViewMode.titleWithPreview,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: {},
      );
      final node2 = Node(
        id: '2',
        title: 'Test Node',
        references: {},
        position: const Offset(100, 100),
        size: const Size(200, 200),
        viewMode: NodeViewMode.titleWithPreview,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: {},
      );

      aiService.suggestConnections(nodes: [node1, node2]).then((value) {
        expect(value[0].confidence, 1.0);
      });
    });
  });

  group('MockAIService', () {
    late MockAIService mockService;

    setUp(() {
      mockService = MockAIService();
    });

    test('应该具有正确的初始状态', () {
      expect(mockService.isAvailable, true);
      expect(mockService.serviceName, 'Mock AI Service');
    });

    test('当配置为不可用时应该不可用', () {
      final unavailableService = MockAIService(available: false);
      expect(unavailableService.isAvailable, false);
    });

    test('应该生成模拟节点', () async {
      final node = await mockService.generateNode(prompt: 'Test prompt');

      expect(node.title, 'Mock Node');
      expect(node.content, contains('Test prompt'));
      expect(node.id, isNotEmpty);
    });

    test('应该总结模拟节点', () async {
      final node = Node(
        id: '1',
        title: 'Test Node',
        references: {},
        position: Offset.zero,
        size: const Size(200, 200),
        viewMode: NodeViewMode.titleWithPreview,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: {},
      );

      final summary = await mockService.summarizeNode(node);
      expect(summary, 'Mock summary for Test Node');
    });

    test('应该建议模拟连接', () async {
      final nodes = [
        Node(
          id: '1',
          title: 'Node 1',
          references: {},
          position: Offset.zero,
          size: const Size(200, 200),
          viewMode: NodeViewMode.titleWithPreview,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: {},
        ),
        Node(
          id: '2',
          title: 'Node 2',
          references: {},
          position: const Offset(100, 100),
          size: const Size(200, 200),
          viewMode: NodeViewMode.titleWithPreview,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: {},
        ),
      ];

      final suggestions = await mockService.suggestConnections(nodes: nodes);
      expect(suggestions.length, 1);
      expect(suggestions[0].fromNodeId, '1');
      expect(suggestions[0].toNodeId, '2');
      expect(suggestions[0].confidence, 0.8);
    });

    test('应该分析模拟节点', () async {
      final node = Node(
        id: '1',
        title: 'Test Node Title',
        references: {},
        position: Offset.zero,
        size: const Size(200, 200),
        viewMode: NodeViewMode.titleWithPreview,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: {},
      );

      final analysis = await mockService.analyzeNode(node);
      expect(analysis.nodeId, '1');
      expect(analysis.summary, 'Mock analysis for Test Node Title');
      expect(analysis.keywords, ['Test', 'Node', 'Title']);
      expect(analysis.topics, ['Topic 1', 'Topic 2']);
    });

    test('应该生成模拟图谱摘要', () async {
      final nodes = [
        Node(
          id: '1',
          title: 'Node 1',
          references: {},
          position: Offset.zero,
          size: const Size(200, 200),
          viewMode: NodeViewMode.titleWithPreview,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: {},
        ),
      ];
      final connections = <Connection>[];

      final summary = await mockService.generateGraphSummary(nodes, connections);
      expect(summary.title, 'Graph Summary');
      expect(summary.nodeCount, 1);
      expect(summary.connectionCount, 0);
    });

    test('应该建议模拟节点主题', () async {
      final nodes = [
        Node(
          id: '1',
          title: 'Existing Node',
          references: {},
          position: Offset.zero,
          size: const Size(200, 200),
          viewMode: NodeViewMode.titleWithPreview,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: {},
        ),
      ];

      final topics = await mockService.suggestNodeTopics(nodes);
      expect(topics.length, 3);
      expect(topics, contains('New Topic 1'));
      expect(topics, contains('New Topic 3'));
    });

    test('extractConcepts应该返回空列表', () async {
      final concepts = await mockService.extractConcepts(
        nodes: [],
        connections: [],
      );
      expect(concepts, isEmpty);
    });

    test('intelligentSplit应该返回空列表', () async {
      final nodes = await mockService.intelligentSplit(markdown: 'Test markdown');
      expect(nodes, isEmpty);
    });

    test('应该回答模拟问题', () async {
      final nodes = [
        Node(
          id: '1',
          title: 'Context Node',
          references: {},
          position: Offset.zero,
          size: const Size(200, 200),
          viewMode: NodeViewMode.titleWithPreview,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: {},
        ),
      ];

      final answer = await mockService.answerQuestion(
        question: 'What is this?',
        context: nodes,
      );
      expect(answer, 'Mock answer to: What is this?');
    });

    test('应该限制模拟建议数量', () async {
      final nodes = List.generate(
        5,
        (i) => Node(
          id: i.toString(),
          title: 'Node $i',
          references: {},
          position: Offset(i * 10.0, i * 10.0),
          size: const Size(200, 200),
          viewMode: NodeViewMode.titleWithPreview,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: {},
        ),
      );

      final suggestions = await mockService.suggestConnections(
        nodes: nodes,
        maxSuggestions: 1,
      );
      expect(suggestions.length, 1);
    });
  });
}

class MockAIProvider implements AIProvider {
  String response = 'Default response';

  @override
  String get serviceName => 'Mock AI Provider';

  @override
  Future<String> generate(String prompt) async => response;
}
