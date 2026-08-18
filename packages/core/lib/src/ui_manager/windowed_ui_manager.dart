/// WindowedUIManager —— UI 管理器实现（02 §3.5 / 03 §5.2）。
///
/// 物化协调（视口/容器驱动）+ 失效路由（nodeId → hookId 索引 →
/// 只达已物化 Hook）。渲染递归调度归框架（物化时调 render）。
///
/// 时序落地：
/// - §5.1 视口物化：onViewportChanged → queryNodes → 未物化 → 物化
/// - §5.2 失效广播：onWriteResult → changeKind 分发 → dirty 标记/树重挂
/// - §5.4 降级：onConceptsChanged → 重新 findFor → 兜底重物化
library;

import 'package:core_data/core_data.dart';

import '../command/command.dart';
import '../invalidation/hook_index.dart';
import '../registry/concept_registry.dart';
import 'materializer.dart';
import 'ui_manager.dart';
import 'value_rect.dart';
import 'viewport_query.dart';
import 'window_manager_impl.dart';

/// UI 管理器默认实现（物化/窗口化/失效路由，机制层，零 Flutter）。
class WindowedUIManager implements UIManager {
  /// 组合物化/失效依赖。
  WindowedUIManager({
    required this.graph,
    required this.concepts,
    required this.index,
    required this.window,
    required this.materializer,
    required this.query,
  });

  /// 结构权威。
  final Graph graph;

  /// 归属判定。
  final ConceptRegistry concepts;

  /// nodeId → hookId 索引（失效路由 O(1)）。
  final HookIndex index;

  /// 窗口登记（物化状态判定）。
  final WindowManagerImpl window;

  /// 物化策略。
  final Materializer materializer;

  /// 视口查询（10⁶ 空间索引由 appframe 实现，M3.5 接入）。
  final ViewportQuery query;

  /// 根容器（画布/侧边栏）Hook——视口物化挂在它下面。
  Hook? _rootHook;

  /// 视口物化使用的容器 kind（根容器 kind，启动时登记）。
  String _rootKind = 'root';

  /// 失效事件监听器（M7.1：呈现层定向重建）。
  final List<InvalidationListener> _listeners = <InvalidationListener>[];

  /// 启动：根 Node 物化（架构 §4 第 10 步：前端图从根建立）。
  ///
  /// [kind] 为该根容器的 kind（如 'graph' / 'sidebar'）。
  Hook? materializeRoot(String nodeId, {String kind = 'root'}) =>
      _rootHook = materializer.materialize(nodeId, null, _rootKind = kind);

  /// 物化（供测试/插件直接调用；容器与 kind 显式指定）。
  Hook? materialize(String nodeId, Hook? containerHook, String kind) =>
      materializer.materialize(nodeId, containerHook, kind);

  @override
  void onViewportChanged(ValueRect viewport, {String? kind}) {
    final targetKind = kind ?? _rootKind;
    // 第二容器（如画布）没有递归根 Hook；容器 null = widget 驱动物化
    // （与 materializeIfAbsent 同一简化，M7.1）。
    final container = targetKind == _rootKind ? _rootHook : null;
    for (final nodeId in query.queryNodes(viewport)) {
      if (window.isMaterialized(nodeId, kind: targetKind)) {
        continue;
      }
      materializer.materialize(nodeId, container, targetKind);
    }
  }

  @override
  void onNodeChanged(Set<String> nodeIds) {
    for (final nodeId in nodeIds) {
      final hookIds = index.lookup(nodeId);
      if (hookIds.isEmpty) {
        continue; // 未物化节点变更 = 索引更新一行，无渲染成本（02 §3.4）。
      }
      hookIds.forEach(_notify);
    }
  }

  /// 写后通知入口（带增量粒度，02 §3.4 三层）：
  /// structure → 树重挂；data → 重绘；ui → 外观直写（无需通知）。
  ///
  /// M7.1：失效路由后向呈现层发事件（widget 树定向重建）。
  void onWriteResult(WriteResult result) {
    switch (result.changeKind) {
      case ChangeKind.structure:
        result.affectedNodeIds.forEach(_rebuildSubtree);
        _emit(ChangeKind.structure, result.affectedNodeIds);
      case ChangeKind.data:
        onNodeChanged(result.affectedNodeIds);
        _emit(ChangeKind.data, result.affectedNodeIds);
      case ChangeKind.ui:
        break; // 外观直写，无数据失效。
    }
  }

  @override
  Hook? hookFor(String nodeId, String kind) {
    // kind 感知：同一节点可多容器多 Hook（sidebar 行 + graph 卡片 +
    // open 对话框）——用 WindowManager.kindOf 区分，不依赖 hookId 字符串。
    for (final hookId in index.lookup(nodeId)) {
      if (window.kindOf(hookId) == kind) {
        return window.hookOf(hookId);
      }
    }
    return null;
  }

  @override
  Hook? materializeIfAbsent(String nodeId, String kind) =>
      hookFor(nodeId, kind) ?? materializer.materialize(nodeId, null, kind);

  @override
  void recycle(String hookId) => materializer.recycle(hookId);

  @override
  void addListener(InvalidationListener listener) => _listeners.add(listener);

  @override
  void removeListener(InvalidationListener listener) =>
      _listeners.remove(listener);

  /// 失效事件广播（data/structure 各一次；快照遍历——监听器内
  /// 增删订阅安全）。
  void _emit(ChangeKind kind, Set<String> nodeIds) {
    if (_listeners.isEmpty) {
      return;
    }
    final event = InvalidationEvent(changeKind: kind, nodeIds: nodeIds);
    for (final listener in List<InvalidationListener>.of(_listeners)) {
      listener(event);
    }
  }

  @override
  void onConceptsChanged() {
    // §5.4 呈现侧：Concept 集合变化 → 物化节点重新 findFor。
    // 10⁶ 背书：只遍历已物化 Hook（≈ 视口内 Hook 数）。
    index.hookIds.toList().forEach((hookId) {
      final nodeId = index.nodeIdOf(hookId);
      if (nodeId == null) {
        return;
      }
      // 先取容器/kind（回收后登记消失），再回收 + 重物化。
      final container = window.containerOf(hookId);
      final kind = window.kindOf(hookId) ?? _rootKind;
      materializer.recycle(hookId);
      materializer.materialize(nodeId, container, kind);
    });
  }

  /// 树重挂（changeKind=structure）：受影响节点 → 回收物化子树。
  ///
  /// 重建由下一次物化路径（视口/容器）完成——M3 简化记录：
  /// 回收即生效（旧 Hook 销毁），重物化是惰性的。
  void _rebuildSubtree(String nodeId) {
    index.lookup(nodeId).toList().forEach(materializer.recycle);
  }

  void _notify(String hookId) {
    final hook = window.hookOf(hookId);
    if (hook == null) {
      return;
    }
    hook.reloadMetadata();
    hook.markDirty();
  }
}
