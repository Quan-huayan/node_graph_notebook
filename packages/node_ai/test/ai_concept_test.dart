/// AI/Chat Concept 测试（M7 杀手演示，01 拍板 #30）：
///
/// AIConcept 结构匹配（kind == 'ai' ∧ L0）、askDropSemantics = 数据命令、
/// 容器语义反查（chatsOf）；ChatConcept 结构匹配（{ai, source} required）。
/// 不变量：AI 节点 L0 零引用、会话 = L1 实例引用两端、永不空洞。
library;

import 'package:core_data/core_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_ai/node_ai.dart';

/// 测试 Node。
class TestNode implements Node {
  TestNode({
    required this.id,
    required this.title,
    this.content,
    this.references = const {},
    this.metadata = const {},
  });

  @override
  final String id;
  @override
  final String title;
  @override
  final String? content;
  @override
  final Map<String, String> references;
  @override
  final Map<String, dynamic> metadata;
  @override
  final DateTime createdAt = DateTime.fromMillisecondsSinceEpoch(0);
  @override
  final DateTime updatedAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Node copyWith({
    String? title,
    String? content,
    Map<String, String>? references,
    Map<String, dynamic>? metadata,
  }) => TestNode(
    id: id,
    title: title ?? this.title,
    content: content ?? this.content,
    references: references ?? this.references,
    metadata: metadata ?? this.metadata,
  );
}

/// 测试 Graph（内存，构造即含给定节点）。
class TestGraph implements Graph {
  TestGraph(Iterable<Node> nodes) : _nodes = {for (final n in nodes) n.id: n};

  final Map<String, Node> _nodes;

  @override
  Node? get(String id) => _nodes[id];

  @override
  List<Node> getMany(List<String> ids) => [for (final id in ids) _nodes[id]!];

  @override
  void save(Node node) => _nodes[node.id] = node;

  @override
  void delete(String id) => _nodes.remove(id);

  @override
  List<Node> getAll() => _nodes.values.toList();

  @override
  List<Node> getByMetadata(String key, dynamic value) =>
      throw UnimplementedError();
}

void main() {
  const ai = AIConcept();
  const chat = ChatConcept();

  group('AIConcept 结构匹配', () {
    test('kind == ai ∧ references 空 → 命中', () {
      final node = TestNode(
        id: 'ai1',
        title: 'AI 助手',
        metadata: const <String, dynamic>{'kind': 'ai'},
      );
      expect(ai.validate(node), isTrue);
    });

    test('references 非空 → 不命中（L0 约束）', () {
      final node = TestNode(
        id: 'ai1',
        title: 'AI 助手',
        references: const <String, String>{'source': 'n1'},
        metadata: const <String, dynamic>{'kind': 'ai'},
      );
      expect(ai.validate(node), isFalse);
    });

    test('kind 不是 ai → 不命中（笔记/文件夹不误判）', () {
      expect(
        ai.validate(
          TestNode(
            id: 'n1',
            title: '笔记',
            metadata: const <String, dynamic>{'kind': 'folder'},
          ),
        ),
        isFalse,
      );
      expect(ai.validate(TestNode(id: 'n2', title: '普通笔记')), isFalse);
    });
  });

  group('AIConcept 行为', () {
    test('askDropSemantics = 数据命令（拖入建会话）', () {
      final semantics = ai.askDropSemantics(TestNode(id: 'noteB', title: '笔记'));
      expect(semantics, isA<DataMove>());
    });

    test('createHook 的 hookId 带容器 kind 上下文（02 §2.3 键方案）', () {
      final hook = ai.createHook(
        TestNode(
          id: 'ai1',
          title: 'AI',
          metadata: const <String, dynamic>{'kind': 'ai'},
        ),
        const HookContext(kind: 'graph'),
      );
      expect(hook.nodeId, 'ai1');
      expect(hook.hookId, 'ai1@graph');
    });
  });

  group('ChatConcept 结构匹配（L1 引用两端）', () {
    test('{ai, source} 满足 → 命中', () {
      final node = TestNode(
        id: 'chat1',
        title: '对话',
        references: const <String, String>{'ai': 'ai1', 'source': 'n1'},
      );
      expect(chat.validate(node), isTrue);
    });

    test('缺 source → 不命中（requiredSlots 约束）', () {
      final node = TestNode(
        id: 'chat1',
        title: '对话',
        references: const <String, String>{'ai': 'ai1'},
      );
      expect(chat.validate(node), isFalse);
    });

    test('多余 slot → 不命中（slots 集合约束）', () {
      final node = TestNode(
        id: 'chat1',
        title: '对话',
        references: const <String, String>{
          'ai': 'ai1',
          'source': 'n1',
          'extra': 'x',
        },
      );
      expect(chat.validate(node), isFalse);
    });

    test('其他关系形态（parent/child 键）不误判——结构唯一', () {
      final contain = TestNode(
        id: 'c1',
        title: '包含',
        references: const <String, String>{'parent': 'f1', 'child': 'n1'},
      );
      expect(chat.validate(contain), isFalse);
    });
  });

  group('容器语义反查（00 推论 3）', () {
    test('chatsOf：references.ai == aiNodeId 的 source 集合', () {
      final graph = TestGraph(<Node>[
        TestNode(
          id: 'chat1',
          title: '对话1',
          references: const <String, String>{'ai': 'ai1', 'source': 'n1'},
        ),
        TestNode(
          id: 'chat2',
          title: '对话2',
          references: const <String, String>{'ai': 'ai1', 'source': 'n2'},
        ),
        TestNode(
          id: 'chat3',
          title: '对话3',
          references: const <String, String>{'ai': 'ai2', 'source': 'n3'},
        ),
      ]);
      expect(
        ai.childNodeIdsOf(TestNode(id: 'ai1', title: 'AI'), graph),
        <String>{'n1', 'n2'},
      );
      expect(chatsOf(graph, 'ai1'), <String>{'n1', 'n2'});
      expect(chatsOf(graph, 'ai2'), <String>{'n3'});
    });

    test('chatOfSource：一个 source 一个会话', () {
      final graph = TestGraph(<Node>[
        TestNode(
          id: 'chat1',
          title: '对话1',
          references: const <String, String>{'ai': 'ai1', 'source': 'n1'},
        ),
      ]);
      expect(chatOfSource(graph, 'n1')!.id, 'chat1');
      expect(chatOfSource(graph, 'ghost'), isNull);
    });
  });
}
