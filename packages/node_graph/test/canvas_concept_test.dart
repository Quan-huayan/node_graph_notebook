/// CanvasConcept 契约测试（画布容器判定 + UIMove 语义 + HookId）。
library;

import 'package:core_data/core_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph/node_graph.dart';

/// 测试 Node（L0：references 恒空、无内容）。
class _TestNode implements Node {
  _TestNode({required this.id, required this.title, this.metadata = const {}});

  @override
  final String id;

  @override
  final String title;

  @override
  String? get content => null;

  @override
  final Map<String, String> references = const <String, String>{};

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
  }) => this;
}

void main() {
  const concept = CanvasConcept();

  test('结构匹配：metadata.kind == canvas（无 instanceOf）', () {
    expect(
      concept.validate(
        _TestNode(
          id: 'canvas',
          title: '画布',
          metadata: const <String, dynamic>{'kind': 'canvas'},
        ),
      ),
      isTrue,
    );
    expect(
      concept.validate(
        _TestNode(
          id: 'note',
          title: '笔记',
          metadata: const <String, dynamic>{'kind': 'note'},
        ),
      ),
      isFalse,
    );
    // L0：references 恒空也匹配（画布成员不由 references 表达）。
    expect(
      concept.validate(
        _TestNode(
          id: 'c',
          title: 'c',
          metadata: const <String, dynamic>{'kind': 'canvas'},
        ),
      ),
      isTrue,
    );
  });

  test('drop 语义判定 = UIMove（判据②：外观位置直写）', () {
    final semantics = concept.askDropSemantics(
      _TestNode(id: 'noteB', title: '笔记B'),
    );
    expect(semantics, isA<UIMove>());
    final move = semantics as UIMove;
    expect(move.key, 'position.graph.noteB'); // 02 §2.3 键带容器上下文。
    expect(move.value, contains('x'));
  });

  test('createHook：hookId 带容器 kind 上下文（多容器不碰撞）', () {
    final hook = concept.createHook(
      _TestNode(id: 'canvas', title: '画布'),
      const HookContext(kind: 'graph'),
    );
    expect(hook, isA<CanvasHook>());
    expect(hook.nodeId, 'canvas');
    expect(hook.hookId, 'canvas@graph');
  });
}
