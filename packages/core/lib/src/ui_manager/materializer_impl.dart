/// MaterializerImpl —— 物化策略实现（架构 §5.1 时序）。
///
/// findFor(node) → createHook(node, HookContext(kind)) →
/// HookIndex.materialize → WindowManager.attach → render（位置无关）。
/// 子 Hook 递归物化（00 推论 3：Hook.references 从后端图 + schema
/// 匹配 + 容器语义推导重建——M3 通用规则：references 目标全展开）。
library;

import 'package:core_data/core_data.dart';

import '../invalidation/hook_index.dart';
import '../registry/concept_registry.dart';
import 'materializer.dart';
import 'window_manager_impl.dart';

/// 物化策略的具体实现。
class MaterializerImpl implements Materializer {
  /// 组合物化依赖（图/归属/窗口/索引/渲染目标）。
  MaterializerImpl({
    required this.graph,
    required this.concepts,
    required this.window,
    required this.index,
    required RenderContext renderRoot,
  }) : _renderRoot = renderRoot;

  /// 结构权威（读 Node）。
  final Graph graph;

  /// 归属判定（findFor）。
  final ConceptRegistry concepts;

  /// 窗口登记。
  final WindowManagerImpl window;

  /// nodeId → hookId 索引。
  final HookIndex index;

  /// 渲染目标（物化时立即 render，位置无关）。
  final RenderContext _renderRoot;

  @override
  Hook? materialize(String nodeId, Hook? containerHook, String kind) {
    if (containerHook != null && window.isMaterialized(nodeId)) {
      return null;
    }
    final node = graph.get(nodeId);
    if (node == null) {
      return null;
    }
    final concept = concepts.findFor(node);
    final hook = concept.createHook(node, HookContext(kind: kind));
    index.materialize(hook.hookId, nodeId);
    window.attach(hook, containerHook, kind);
    hook.render(
      containerHook == null
          ? _renderRoot
          : _renderRoot.createChildContext(containerHook),
    );
    // 子 Hook 物化（00 推论 3）：容器语义（childNodeIdsOf，graph 传入）
    // 优先，缺省用 references 展开（M3 通用规则）。
    final childIds =
        concept.childNodeIdsOf(node, graph) ?? node.references.values;
    for (final targetId in childIds) {
      materialize(targetId, hook, kind);
    }
    return hook;
  }

  @override
  void recycle(String hookId) {
    window.recycle(hookId);
    index.recycle(hookId);
  }
}
