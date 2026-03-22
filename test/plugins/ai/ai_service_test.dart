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

    test('should have correct initial state', () {
      expect(aiService.isAvailable, true);
      expect(aiService.serviceName, 'Mock AI Provider');
    });

    test('should be unavailable when provider is null', () {
      final service = AIServiceImpl();
      expect(service.isAvailable, false);
      expect(service.serviceName, 'No Provider');
    });

    test('should set provider correctly', () {
      final newProvider = MockAIProvider();
      aiService.setProvider(newProvider);
      expect(aiService.isAvailable, true);
      expect(aiService.serviceName, 'Mock AI Provider');
    });

    test('should generate node correctly', () async {
      mockProvider.response = 'Generated Title\nGenerated content here';
      final node = await aiService.generateNode(prompt: 'Test prompt');

      expect(node.title, 'Generated Title');
      expect(node.content, 'Generated content here');
      expect(node.id, isNotEmpty);
      expect(node.position, const Offset(100, 100));
      expect(node.size, const Size(300, 400));
    });

    test('should handle empty response in generateNode', () async {
      mockProvider.response = '';
      final node = await aiService.generateNode(prompt: 'Test prompt');

      expect(node.title, 'Untitled');
      expect(node.content, isEmpty);
    });

    test('should summarize node correctly', () async {
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

    test('should throw exception when provider not set for generateNode', () async {
      final service = AIServiceImpl();
      expect(
        () => service.generateNode(prompt: 'test'),
        throwsA(isA<AIServiceException>()),
      );
    });

    test('should throw exception when provider not set for summarizeNode', () async {
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

    test('should suggest connections based on similarity', () async {
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

    test('should limit suggestions by maxSuggestions', () async {
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

    test('should analyze node correctly', () async {
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

    test('should generate graph summary correctly', () async {
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

    test('should suggest node topics correctly', () async {
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

    test('should throw exception when provider not set for analyzeNode', () async {
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

    test('should throw exception when provider not set for suggestConnections', () async {
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

    test('should calculate similarity correctly for identical titles', () {
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

    test('should have correct initial state', () {
      expect(mockService.isAvailable, true);
      expect(mockService.serviceName, 'Mock AI Service');
    });

    test('should be unavailable when configured', () {
      final unavailableService = MockAIService(available: false);
      expect(unavailableService.isAvailable, false);
    });

    test('should generate mock node', () async {
      final node = await mockService.generateNode(prompt: 'Test prompt');

      expect(node.title, 'Mock Node');
      expect(node.content, contains('Test prompt'));
      expect(node.id, isNotEmpty);
    });

    test('should summarize mock node', () async {
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

    test('should suggest mock connections', () async {
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

    test('should analyze mock node', () async {
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

    test('should generate mock graph summary', () async {
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

    test('should suggest mock node topics', () async {
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

    test('should return empty list for extract concepts', () async {
      final concepts = await mockService.extractConcepts(
        nodes: [],
        connections: [],
      );
      expect(concepts, isEmpty);
    });

    test('should return empty list for intelligent split', () async {
      final nodes = await mockService.intelligentSplit(markdown: 'Test markdown');
      expect(nodes, isEmpty);
    });

    test('should answer mock question', () async {
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

    test('should limit mock suggestions', () async {
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
