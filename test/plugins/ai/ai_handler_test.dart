import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/commands/command_bus.dart';
import 'package:node_graph_notebook/core/commands/models/command_context.dart';
import 'package:node_graph_notebook/core/events/app_events.dart';
import 'package:node_graph_notebook/core/models/connection.dart';
import 'package:node_graph_notebook/core/models/enums.dart';
import 'package:node_graph_notebook/core/models/node.dart';
import 'package:node_graph_notebook/core/models/node_reference.dart';
import 'package:node_graph_notebook/core/repositories/graph_repository.dart';
import 'package:node_graph_notebook/core/repositories/metadata_index.dart';
import 'package:node_graph_notebook/core/repositories/node_repository.dart';
import 'package:node_graph_notebook/plugins/ai/command/ai_commands.dart';
import 'package:node_graph_notebook/plugins/ai/handler/analyze_node_handler.dart';
import 'package:node_graph_notebook/plugins/ai/service/ai_service.dart';
import 'package:node_graph_notebook/plugins/graph/service/graph_service.dart';
import 'package:node_graph_notebook/plugins/graph/service/node_service.dart';

void main() {
  group('AnalyzeNodeHandler', () {
    late AnalyzeNodeHandler handler;
    late MockAIService mockAIService;
    late MockCommandContext mockContext;
    late Node testNode;

    setUp(() {
      mockAIService = MockAIService();
      handler = AnalyzeNodeHandler(mockAIService);
      mockContext = MockCommandContext();

      testNode = Node(
        id: 'node-1',
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
    });

    test('应该成功分析节点', () async {
      final command = AnalyzeNodeCommand(node: testNode);
      mockAIService.analysisResult = const NodeAnalysis(
        nodeId: 'node-1',
        summary: 'Test summary',
        keywords: ['test', 'node'],
        topics: ['topic1', 'topic2'],
        sentiment: 'neutral',
      );

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, true);
      expect(result.data, isNotNull);
      final analysis = result.data as NodeAnalysis;
      expect(analysis.nodeId, 'node-1');
      expect(analysis.summary, 'Test summary');
      expect(mockContext.publishedEvents.length, 1);
      expect(mockContext.publishedEvents.first, isA<NodeAnalyzedEvent>());
    });

    test('应该发布包含正确数据的NodeAnalyzedEvent', () async {
      final command = AnalyzeNodeCommand(node: testNode);
      mockAIService.analysisResult = const NodeAnalysis(
        nodeId: 'node-1',
        summary: 'Summary',
        keywords: ['key1', 'key2'],
        topics: ['topic1'],
        sentiment: 'positive',
      );

      await handler.execute(command, mockContext);

      final event = mockContext.publishedEvents.first as NodeAnalyzedEvent;
      expect(event.nodeId, 'node-1');
      expect(event.summary, 'Summary');
      expect(event.keywords, ['key1', 'key2']);
      expect(event.topics, ['topic1']);
    });

    test('应该处理AI服务错误', () async {
      final command = AnalyzeNodeCommand(node: testNode);
      mockAIService.shouldThrowError = true;

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, contains('Failed to analyze node'));
    });

    test('应该处理内容为空节点', () async {
      final emptyNode = Node(
        id: 'node-2',
        title: 'Empty Node',
        content: null,
        references: {},
        position: Offset.zero,
        size: const Size(200, 200),
        viewMode: NodeViewMode.titleWithPreview,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: {},
      );
      final command = AnalyzeNodeCommand(node: emptyNode);
      mockAIService.analysisResult = const NodeAnalysis(
        nodeId: 'node-2',
        summary: 'Empty summary',
        keywords: [],
        topics: [],
      );

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, true);
      final analysis = result.data as NodeAnalysis;
      expect(analysis.nodeId, 'node-2');
    });
  });

  group('SuggestConnectionsHandler', () {
    late SuggestConnectionsHandler handler;
    late MockAIService mockAIService;
    late MockCommandContext mockContext;
    late List<Node> testNodes;

    setUp(() {
      mockAIService = MockAIService();
      handler = SuggestConnectionsHandler(mockAIService);
      mockContext = MockCommandContext();

      testNodes = [
        Node(
          id: 'node-1',
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
          id: 'node-2',
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
    });

    test('应该成功建议连接', () async {
      final command = SuggestConnectionsCommand(nodes: testNodes);
      mockAIService.suggestions = [
        const ConnectionSuggestion(
          fromNodeId: 'node-1',
          toNodeId: 'node-2',
          reason: 'Similar content',
          confidence: 0.8,
        ),
      ];

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, true);
      final suggestions = result.data as List<ConnectionSuggestion>;
      expect(suggestions.length, 1);
      expect(suggestions.first.fromNodeId, 'node-1');
      expect(suggestions.first.toNodeId, 'node-2');
      expect(mockContext.publishedEvents.length, 1);
      expect(mockContext.publishedEvents.first, isA<ConnectionsSuggestedEvent>());
    });

    test('应该通过minConfidence过滤建议', () async {
      final command = SuggestConnectionsCommand(
        nodes: testNodes,
        minConfidence: 0.7,
      );
      mockAIService.suggestions = [
        const ConnectionSuggestion(
          fromNodeId: 'node-1',
          toNodeId: 'node-2',
          reason: 'High confidence',
          confidence: 0.9,
        ),
        const ConnectionSuggestion(
          fromNodeId: 'node-2',
          toNodeId: 'node-1',
          reason: 'Low confidence',
          confidence: 0.5,
        ),
      ];

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, true);
      final suggestions = result.data as List<ConnectionSuggestion>;
      expect(suggestions.length, 1);
      expect(suggestions.first.confidence, 0.9);
    });

    test('当AI服务不可用时应该返回失败', () async {
      final command = SuggestConnectionsCommand(nodes: testNodes);
      mockAIService.isAvailableFlag = false;

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, contains('AI service is not available'));
    });

    test('应该处理空节点列表', () async {
      final command = SuggestConnectionsCommand(nodes: []);
      mockAIService.suggestions = [];

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, true);
      final suggestions = result.data as List<ConnectionSuggestion>;
      expect(suggestions.length, 0);
    });

    test('应该发布包含正确数据的ConnectionsSuggestedEvent', () async {
      final command = SuggestConnectionsCommand(nodes: testNodes);
      mockAIService.suggestions = [
        const ConnectionSuggestion(
          fromNodeId: 'node-1',
          toNodeId: 'node-2',
          reason: 'Test reason',
          confidence: 0.8,
        ),
      ];

      await handler.execute(command, mockContext);

      final event = mockContext.publishedEvents[0] as ConnectionsSuggestedEvent;
      expect(event.suggestions.length, 1);
      expect(event.suggestions[0].reason, 'Test reason');
    });
  });

  group('GenerateGraphSummaryHandler', () {
    late GenerateGraphSummaryHandler handler;
    late MockAIService mockAIService;
    late MockCommandContext mockContext;

    setUp(() {
      mockAIService = MockAIService();
      handler = GenerateGraphSummaryHandler(mockAIService);
      mockContext = MockCommandContext();

      final testNodes = [
        Node(
          id: 'node-1',
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
      mockContext._nodeRepository.nodes = testNodes;
    });

    test('应该成功生成图谱摘要', () async {
      final command = GenerateGraphSummaryCommand();
      mockAIService.graphSummary = const GraphSummary(
        title: 'Test Summary',
        description: 'Test description',
        keyTopics: ['topic1', 'topic2'],
        nodeCount: 1,
        connectionCount: 0,
      );

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, true);
      final summary = result.data as GraphSummary;
      expect(summary.title, 'Test Summary');
      expect(summary.nodeCount, 1);
      expect(mockContext.publishedEvents.length, 1);
      expect(mockContext.publishedEvents.first, isA<GraphSummaryGeneratedEvent>());
    });

    test('当AI服务不可用时应该返回失败', () async {
      final command = GenerateGraphSummaryCommand();
      mockAIService.isAvailableFlag = false;

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, contains('AI service is not available'));
    });

    test('应该发布包含正确数据的GraphSummaryGeneratedEvent', () async {
      final command = GenerateGraphSummaryCommand();
      mockAIService.graphSummary = const GraphSummary(
        title: 'Graph Title',
        description: 'Graph description',
        keyTopics: ['topic1'],
        nodeCount: 2,
        connectionCount: 1,
      );

      await handler.execute(command, mockContext);

      final event = mockContext.publishedEvents[0] as GraphSummaryGeneratedEvent;
      expect(event.summary.title, 'Graph Title');
      expect(event.summary.nodeCount, 2);
    });

    test('应该处理空图谱', () async {
      final command = GenerateGraphSummaryCommand();
      mockContext._nodeRepository.nodes = [];
      mockAIService.graphSummary = const GraphSummary(
        title: 'Empty Graph',
        description: 'No nodes',
        keyTopics: [],
        nodeCount: 0,
        connectionCount: 0,
      );

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, true);
      final summary = result.data as GraphSummary;
      expect(summary.nodeCount, 0);
    });
  });

  group('GenerateNodeHandler', () {
    late GenerateNodeHandler handler;
    late MockAIService mockAIService;
    late MockNodeService mockNodeService;
    late MockCommandContext mockContext;

    setUp(() {
      mockAIService = MockAIService();
      mockNodeService = MockNodeService();
      handler = GenerateNodeHandler(mockAIService, mockNodeService);
      mockContext = MockCommandContext();

      mockNodeService.createdNode = Node(
        id: 'generated-node-1',
        title: 'Generated Node',
        content: 'Generated content',
        references: {},
        position: const Offset(100, 100),
        size: const Size(300, 400),
        viewMode: NodeViewMode.titleWithPreview,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: {},
      );
    });

    test('应该成功生成节点', () async {
      final command = GenerateNodeCommand(prompt: 'Generate a test node');
      mockAIService.generatedNode = Node(
        id: 'ai-node-1',
        title: 'AI Generated Node',
        content: 'AI content',
        references: {},
        position: const Offset(100, 100),
        size: const Size(300, 400),
        viewMode: NodeViewMode.titleWithPreview,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: {},
      );

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, true);
      final node = result.data as Node;
      expect(node.id, 'generated-node-1');
      expect(node.title, 'Generated Node');
      expect(mockNodeService.createNodeCalled, true);
      expect(mockContext.publishedEvents.length, 1);
      expect(mockContext.publishedEvents.first, isA<NodeGeneratedEvent>());
    });

    test('如果提供了自定义位置应该使用它', () async {
      final command = GenerateNodeCommand(
        prompt: 'Test',
        position: const Offset(200, 300),
      );
      mockAIService.generatedNode = Node(
        id: 'ai-node-1',
        title: 'Node',
        references: {},
        position: const Offset(100, 100),
        size: const Size(300, 400),
        viewMode: NodeViewMode.titleWithPreview,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: {},
      );

      await handler.execute(command, mockContext);

      expect(mockNodeService.lastPosition, const Offset(200, 300));
    });

    test('当AI服务不可用时应该返回失败', () async {
      final command = GenerateNodeCommand(prompt: 'Test');
      mockAIService.isAvailableFlag = false;

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, contains('AI service is not available'));
    });

    test('应该发布包含正确数据的NodeGeneratedEvent', () async {
      final command = GenerateNodeCommand(prompt: 'Test prompt');
      mockAIService.generatedNode = Node(
        id: 'ai-node-1',
        title: 'AI Node',
        references: {},
        position: const Offset(100, 100),
        size: const Size(300, 400),
        viewMode: NodeViewMode.titleWithPreview,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: {},
      );

      await handler.execute(command, mockContext);

      final event = mockContext.publishedEvents[0] as NodeGeneratedEvent;
      expect(event.nodeId, 'generated-node-1');
      expect(event.prompt, 'Test prompt');
    });

    test('应该传递选项给AI服务', () async {
      final command = GenerateNodeCommand(
        prompt: 'Test',
        options: {'style': 'formal', 'length': 'short'},
      );
      mockAIService.generatedNode = Node(
        id: 'ai-node-1',
        title: 'Node',
        references: {},
        position: const Offset(100, 100),
        size: const Size(300, 400),
        viewMode: NodeViewMode.titleWithPreview,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: {},
      );

      await handler.execute(command, mockContext);

      expect(mockAIService.lastOptions, {'style': 'formal', 'length': 'short'});
    });
  });
}

class MockAIService implements AIService {
  NodeAnalysis? analysisResult;
  List<ConnectionSuggestion>? suggestions;
  GraphSummary? graphSummary;
  Node? generatedNode;
  Map<String, dynamic>? lastOptions;
  bool shouldThrowError = false;
  bool isAvailableFlag = true;

  @override
  Future<NodeAnalysis> analyzeNode(Node node) async {
    if (shouldThrowError) throw Exception('AI service error');
    return analysisResult ?? NodeAnalysis(
      nodeId: node.id,
      summary: 'Default summary',
      keywords: [],
      topics: [],
    );
  }

  @override
  Future<List<ConnectionSuggestion>> suggestConnections({
    required List<Node> nodes,
    int? maxSuggestions,
  }) async {
    if (!isAvailableFlag) throw AIServiceException('AI service not available');
    return suggestions ?? [];
  }

  @override
  Future<GraphSummary> generateGraphSummary(
    List<Node> nodes,
    List<Connection> connections,
  ) async {
    if (!isAvailableFlag) throw AIServiceException('AI service not available');
    return graphSummary ?? GraphSummary(
      title: 'Default',
      description: 'Default',
      keyTopics: [],
      nodeCount: nodes.length,
      connectionCount: connections.length,
    );
  }

  @override
  Future<Node> generateNode({
    required String prompt,
    Map<String, dynamic>? options,
  }) async {
    if (!isAvailableFlag) throw AIServiceException('AI service not available');
    lastOptions = options;
    return generatedNode ?? Node(
      id: 'default',
      title: 'Default',
      references: {},
      position: Offset.zero,
      size: const Size(200, 200),
      viewMode: NodeViewMode.titleWithPreview,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      metadata: {},
    );
  }

  @override
  bool get isAvailable => isAvailableFlag;

  @override
  String get serviceName => 'Mock AI Service';

  @override
  void setProvider(AIProvider provider) {}

  @override
  Future<String> summarizeNode(Node node) async => 'Summary';

  @override
  Future<List<ConceptExtraction>> extractConcepts({
    required List<Node> nodes,
    required List<Connection> connections,
  }) async => [];

  @override
  Future<List<Node>> intelligentSplit({required String markdown}) async => [];

  @override
  Future<String> answerQuestion({
    required String question,
    required List<Node> context,
  }) async => 'Answer';

  @override
  Future<List<String>> suggestNodeTopics(List<Node> existingNodes) async => [];
}

class MockNodeService implements NodeService {
  Node? createdNode;
  bool createNodeCalled = false;
  Offset? lastPosition;

  @override
  Future<Node> createNode({
    required String title,
    String? content,
    Offset? position,
    Size? size,
    String? color,
    Map<String, NodeReference>? references,
    Map<String, dynamic>? metadata,
  }) async {
    createNodeCalled = true;
    lastPosition = position;
    return createdNode ?? Node(
      id: 'mock-node',
      title: title,
      content: content,
      references: references ?? {},
      position: position ?? Offset.zero,
      size: size ?? const Size(200, 200),
      viewMode: NodeViewMode.titleWithPreview,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      metadata: metadata ?? {},
    );
  }

  @override
  Future<Node> updateNode(
    String nodeId, {
    String? title,
    String? content,
    Offset? position,
    Size? size,
    NodeViewMode? viewMode,
    String? color,
    Map<String, NodeReference>? references,
    Map<String, dynamic>? metadata,
  }) async => throw UnimplementedError();

  @override
  Future<void> deleteNode(String nodeId) async {}

  @override
  Future<Node?> getNode(String nodeId) async => null;

  @override
  Future<List<Node>> getAllNodes() async => [];

  @override
  Future<List<Node>> searchNodes(String query) async => [];

  @override
  Future<void> connectNodes({
    required String fromNodeId,
    required String toNodeId,
    Map<String, dynamic>? properties,
  }) async {}

  @override
  Future<void> disconnectNodes({
    required String fromNodeId,
    required String toNodeId,
  }) async {}

  @override
  Future<void> batchUpdate(List<NodeUpdate> updates) async {}

  @override
  Future<void> batchDelete(List<String> nodeIds) async {}

  @override
  Future<Map<String, int>> calculateNodeDepths(List<Node> nodes) async => {};
}

class MockCommandContext implements CommandContext {
  MockCommandContext() {
    _commandBus = CommandBus();
  }

  final List<AppEvent> _pendingEvents = [];

  List<Node> nodes = [];

  final MockNodeRepository _nodeRepository = MockNodeRepository();

  late final CommandBus _commandBus;

  @override
  NodeRepository get nodeRepository => _nodeRepository;

  @override
  void publishNodeEvent(List<Node> nodes, DataChangeAction action) {}

  @override
  void publishSingleNodeEvent(Node node, DataChangeAction action) {}

  @override
  void publishGraphRelationEvent(
    String graphId,
    List<String> nodeIds,
    RelationChangeAction action,
  ) {}

  @override
  Future<T> withTransaction<T>(Future<T> Function() operation) => operation();

  @override
  bool get isInTransaction => false;

  @override
  void registerService<T>(T service) {}

  @override
  T read<T>() => throw UnimplementedError();

  @override
  T? tryRead<T>() => null;

  @override
  void setMetadata(String key, dynamic value) {}

  @override
  dynamic getMetadata(String key) => null;

  @override
  bool hasMetadata(String key) => false;

  @override
  void clearMetadata() {}

  @override
  CommandContext createChild() => this;

  @override
  void publishEvent(AppEvent event) {
    _pendingEvents.add(event);
  }

  @override
  void publishEvents(List<AppEvent> events) {
    _pendingEvents.addAll(events);
  }

  @override
  List<AppEvent> getPendingEvents() => List.unmodifiable(_pendingEvents);

  @override
  void clearPendingEvents() {
    _pendingEvents.clear();
  }

  NodeService? get nodeService => null;

  @override
  GraphRepository get graphRepository => throw UnimplementedError();

  GraphService? get graphService => null;

  @override
  CommandBus get commandBus => _commandBus;

  @override
  set commandBus(CommandBus value) {}

  /// 已发布的事件列表（用于测试验证）
  List<AppEvent> get publishedEvents => _pendingEvents;
}

class MockNodeRepository implements NodeRepository {
  List<Node> nodes = [];

  @override
  Future<void> save(Node node) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<Node?> load(String id) async => null;

  @override
  Future<List<Node>> loadAll(List<String> nodeIds) async => [];

  @override
  Future<void> saveAll(List<Node> nodes) async {}

  @override
  Future<List<Node>> queryAll() async => nodes;

  @override
  Future<List<Node>> search({
    String? title,
    String? content,
    List<String>? tags,
    DateTime? startDate,
    DateTime? endDate,
  }) async => [];

  @override
  String getNodeFilePath(String nodeId) => '';

  @override
  Future<void> updateIndex(Node node) async {}

  @override
  Future<MetadataIndex> getMetadataIndex() async =>
      MetadataIndex(nodes: [], lastUpdated: DateTime.now());
}
