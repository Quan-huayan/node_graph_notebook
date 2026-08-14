/// M6 folder 端到端验收（architecture.md §9 杀手演示，contain 关系模型）。
///
/// 场景：创建笔记 → 拖入 folder（contain 实例创建）→ 多子级 →
/// 重排（contain 更新）→ 语义环拒绝 → 禁用降级 → 重启恢复（投影不变式）。
/// 画布场景（UIMove 判据②）已移至 node_graph 包（真实 CanvasConcept）。
///
/// 不变量断言（00 §4.2/4.3）：L0 零引用（folder/note references 恒空）、
/// 关系 = L1-node（contain 实例引用两端）、永不空洞（兜底）、
/// 前端结构零持久化（重启后从 Graph 重建）。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:core/core.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_folder/node_folder.dart';
import 'package:plugon/plugon.dart';

/// 测试渲染目标。
class _TestRenderContext implements RenderContext {
  @override
  RenderContext createChildContext(Hook childHook) => _TestRenderContext();
}

/// 测试 Node（L0：folder/note 零引用）。
class TestNode implements Node {
  TestNode({
    required this.id,
    required this.title,
    this.content,
    this.references = const {},
    this.metadata = const {},
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
       updatedAt = updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

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
  final DateTime createdAt;

  @override
  final DateTime updatedAt;

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
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

void main() {
  group('M6 杀手演示（contain 关系模型）', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('ngn_e2e');
      addTearDown(() {
        if (root.existsSync()) {
          root.deleteSync(recursive: true);
        }
      });
    });

    /// 种子：root（folder）包含 folderA；noteB/noteC 未归属。
    HostRuntime seed(HostRuntime host) {
      final now = DateTime.now();
      host.graph.save(
        StoredNode(
          id: 'root',
          title: '根目录',
          metadata: const <String, dynamic>{'kind': 'folder'},
          createdAt: now,
          updatedAt: now,
        ),
      );
      host.graph.save(
        StoredNode(
          id: 'folderA',
          title: '文件夹A',
          metadata: const <String, dynamic>{'kind': 'folder'},
          createdAt: now,
          updatedAt: now,
        ),
      );
      host.graph.save(
        StoredNode(
          id: 'contain-root-folderA',
          title: 'contain:folderA',
          references: const <String, String>{
            'parent': 'root',
            'child': 'folderA',
          },
          createdAt: now,
          updatedAt: now,
        ),
      );
      host.graph.save(
        StoredNode(id: 'noteB', title: '笔记B', createdAt: now, updatedAt: now),
      );
      host.graph.save(
        StoredNode(id: 'noteC', title: '笔记C', createdAt: now, updatedAt: now),
      );
      return host;
    }

    DragController dragFor(HostRuntime host) => DragController(
      graph: host.graph,
      concepts: host.concepts,
      commandBus: host.commandBus,
      uiStateStore: host.uiStateStore,
      flightShell: FlightShell(),
      moveCommandFactory:
          ({
            required String draggedNodeId,
            required String targetContainerId,
            required Map<String, String> newReferences,
          }) => MoveNodesCommand(
            containerId: targetContainerId,
            childId: draggedNodeId,
          ),
    );

    test('拖入 folder → contain 实例落盘（L1 引用两端，folder/note 零引用）', () async {
      final host = seed(
        HostRuntime(dataRoot: root, renderRoot: _TestRenderContext()),
      );
      await host.start(plugins: <Plugin>[FolderPlugin()], rootNodeId: 'root');
      final drag = dragFor(host);
      final folderHook = const FolderConcept().createHook(
        host.graph.get('folderA')!,
        const HookContext(kind: 'sidebar'),
      );

      final outcome = await drag.onDrop(
        draggedNodeId: 'noteB',
        targetContainerHook: folderHook,
        dropPoint: const Offset(10, 10),
      );

      expect(outcome.kind, DropOutcomeKind.committed);
      // contain 实例（L1）引用两端；folder/note 是 L0（零引用）。
      final contain = host.graph.getAll().firstWhere(
        (n) => n.references['child'] == 'noteB',
      );
      expect(contain.references['parent'], 'folderA');
      expect(host.graph.get('folderA')!.references, isEmpty);
      expect(host.graph.get('noteB')!.references, isEmpty);
      // children 读侧反查。
      expect(childrenOf(host.graph, 'folderA'), <String>['noteB']);
    });

    test('多子级：再拖 noteC → 第二个 contain 实例', () async {
      final host = seed(
        HostRuntime(dataRoot: root, renderRoot: _TestRenderContext()),
      );
      await host.start(plugins: <Plugin>[FolderPlugin()], rootNodeId: 'root');
      final drag = dragFor(host);
      final folderHook = const FolderConcept().createHook(
        host.graph.get('folderA')!,
        const HookContext(kind: 'sidebar'),
      );
      await drag.onDrop(
        draggedNodeId: 'noteB',
        targetContainerHook: folderHook,
        dropPoint: Offset.zero,
      );
      await drag.onDrop(
        draggedNodeId: 'noteC',
        targetContainerHook: folderHook,
        dropPoint: Offset.zero,
      );

      expect(childrenOf(host.graph, 'folderA').toSet(), <String>{
        'noteB',
        'noteC',
      });
      // 两个独立 contain 实例（references 契约 Map<String,String> 不变）。
      final contains = host.graph.getAll().where(
        (n) => n.references['parent'] == 'folderA',
      );
      expect(contains.length, 2);
    });

    test('重排：拖 noteB 从 folderA 到 folderC → contain 更新 parent', () async {
      final host = seed(
        HostRuntime(dataRoot: root, renderRoot: _TestRenderContext()),
      );
      host.graph.save(
        StoredNode(
          id: 'folderC',
          title: '文件夹C',
          metadata: const <String, dynamic>{'kind': 'folder'},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await host.start(plugins: <Plugin>[FolderPlugin()], rootNodeId: 'root');
      final drag = dragFor(host);
      // 先放入 folderA。
      final folderAHook = const FolderConcept().createHook(
        host.graph.get('folderA')!,
        const HookContext(kind: 'sidebar'),
      );
      await drag.onDrop(
        draggedNodeId: 'noteB',
        targetContainerHook: folderAHook,
        dropPoint: Offset.zero,
      );
      // 再拖到 folderC（重排）。
      final folderCHook = const FolderConcept().createHook(
        host.graph.get('folderC')!,
        const HookContext(kind: 'sidebar'),
      );
      final outcome = await drag.onDrop(
        draggedNodeId: 'noteB',
        targetContainerHook: folderCHook,
        dropPoint: Offset.zero,
      );

      expect(outcome.kind, DropOutcomeKind.committed);
      // contain 实例唯一（child=noteB 只有一个），parent 已更新。
      final contains = host.graph.getAll().where(
        (n) => n.references['child'] == 'noteB',
      );
      expect(contains.length, 1);
      expect(contains.single.references['parent'], 'folderC');
      expect(childrenOf(host.graph, 'folderA'), isEmpty);
    });

    test('语义环：拖 folder 进自己后代 → 拒绝 → 无持久化副作用', () async {
      final host = seed(
        HostRuntime(dataRoot: root, renderRoot: _TestRenderContext()),
      );
      // folderA 包含 folderB（contain）；把 folderA 拖入 folderB = 语义环。
      host.graph.save(
        StoredNode(
          id: 'folderB',
          title: '文件夹B',
          metadata: const <String, dynamic>{'kind': 'folder'},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      host.graph.save(
        StoredNode(
          id: 'contain-folderA-folderB',
          title: 'contain:folderB',
          references: const <String, String>{
            'parent': 'folderA',
            'child': 'folderB',
          },
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await host.start(plugins: <Plugin>[FolderPlugin()], rootNodeId: 'root');
      final drag = dragFor(host);
      final folderBHook = const FolderConcept().createHook(
        host.graph.get('folderB')!,
        const HookContext(kind: 'sidebar'),
      );

      final outcome = await drag.onDrop(
        draggedNodeId: 'folderA',
        targetContainerHook: folderBHook,
        dropPoint: Offset.zero,
      );

      expect(outcome.kind, DropOutcomeKind.cycleRejected);
      // 无持久化副作用：无"folderB 包含 folderA"的新 contain 实例
      // （seed 中 root→folderA 的 contain 不受影响）。
      expect(
        host.graph.getAll().where(
          (n) =>
              n.references['child'] == 'folderA' &&
              n.references['parent'] == 'folderB',
        ),
        isEmpty,
      );
    });

    test('禁用插件 → 降级兜底（永不空洞）；重启恢复（投影不变式）', () async {
      final host = seed(
        HostRuntime(dataRoot: root, renderRoot: _TestRenderContext()),
      );
      await host.start(plugins: <Plugin>[FolderPlugin()], rootNodeId: 'root');
      // root 以 FolderHook 物化（kind 识别）。
      expect(
        host.window.hookOf(host.hookIndex.hookIds.first),
        isA<FolderHook>(),
      );

      await host.disablePlugin('com.example.folder');

      expect(
        host.concepts.findFor(host.graph.get('root')!),
        same(host.concepts.fallback),
      );
      expect(
        host.window.hookOf(host.hookIndex.hookIds.first),
        isA<FallbackHook>(),
      );

      // 重启恢复：contain 实例从磁盘重建，前端图结构一致（§5.5）。
      await host.dispose();
      final reopened = seed(
        HostRuntime(dataRoot: root, renderRoot: _TestRenderContext()),
      );
      await reopened.start(
        plugins: <Plugin>[FolderPlugin()],
        rootNodeId: 'root',
      );
      expect(reopened.hookIndex.isMaterialized('folderA'), isTrue);
      expect(
        reopened.window.hookOf(reopened.hookIndex.hookIds.first),
        isA<FolderHook>(),
      );
      // contain 实例从 Graph 恢复（投影不变式：结构只来自 Graph）。
      expect(childrenOf(reopened.graph, 'root'), <String>['folderA']);
    });
  });
}
