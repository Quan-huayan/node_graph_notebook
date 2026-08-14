/// HookView —— Hook 渲染宿主（M7.1 修正：**物化 Hook 渲染宿主**）。
///
/// 节点 → UIManager.hookFor（物化实例）→ Hook.render → 收集挂载 widget。
/// 全应用统一入口：主区域/侧栏/节点打开对话框都经本 widget 渲染——
/// **UI 只有一种表达：Hook 渲染**（没有 app 手写分发）。
///
/// M7.1（UIManager 管线接入 widget 树，架构 §5.2 UI 侧落地）：
/// - **渲染物化实例**：hookFor(nodeId, kind) 取 UIManager 物化的 Hook——
///   重建不重派生（无 findFor/createHook），机制层与呈现层身份一致
/// - **失效事件定向重建**：订阅 UIManager 失效事件，命中本节点才 setState
///   （data = 重绘；structure = 树重挂 → hookFor 为空 → 重新物化）
/// - **按需物化**：未物化（结构变更后的新子级/节点打开）→
///   materializeIfAbsent——widget 驱动（容器为 null，M3 已知简化）
/// - **窗口化回收**：recycleOnDispose=true（节点打开对话框场景）——
///   打开即物化、关闭即回收（重开覆盖幂等）
///
/// 未 started（测试兼容）：回退重派生路径（findFor → createHook）。
///
/// 布局约束由父级提供（SizedBox/Expanded——ParentDataWidget 约束）。
library;

import 'package:core/core.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter/widgets.dart';

import '../host/host_runtime.dart';
import '../render/flutter_render_context.dart';

/// Hook 渲染宿主（公开——主区域/侧栏/打开对话框共用）。
///
/// **Hook Tree 递归**（02 §3.2）：本 widget 渲染单层 Hook；**树形递归
/// 由父 Hook 驱动**（父 Hook 挂载容器 widget，容器内以 HookView 渲染
/// 子级——渲染 = Hook Tree 递归遍历，父 Hook 不代替子 Hook 渲染）。
class HookView extends StatefulWidget {
  /// 注入宿主、目标节点与渲染形态。
  const HookView({
    super.key,
    required this.host,
    required this.nodeId,
    required this.kind,
    this.onCardDrop,
    this.onDragStart,
    this.recycleOnDispose = false,
  });

  /// 宿主组合根（服务通道）。
  final HostRuntime host;

  /// 渲染的节点。
  final String nodeId;

  /// 渲染形态（HookContext.kind：sidebar / graph / open …）。
  final String kind;

  /// 画布卡片 drop 语义分发（数据层——组合根注入，01 拍板 #32）。
  final CanvasCardDropHandler? onCardDrop;

  /// 拖拽起点记录（飞行视觉——父容器透传给子 Hook）。
  final void Function(Offset position)? onDragStart;

  /// 关闭时回收物化 Hook（窗口化：节点打开对话框场景）。
  final bool recycleOnDispose;

  @override
  State<HookView> createState() => _HookViewState();
}

class _HookViewState extends State<HookView> {
  @override
  void initState() {
    super.initState();
    if (widget.host.started) {
      widget.host.uiManager.addListener(_onInvalidation);
    }
  }

  @override
  void dispose() {
    if (widget.host.started) {
      widget.host.uiManager.removeListener(_onInvalidation);
      if (widget.recycleOnDispose) {
        final hook = widget.host.uiManager.hookFor(widget.nodeId, widget.kind);
        if (hook != null) {
          widget.host.uiManager.recycle(hook.hookId);
        }
      }
    }
    super.dispose();
  }

  /// 失效事件 → 定向重建（架构 §5.2 只达已物化 Hook 的 UI 侧）：
  /// - **structure**：无条件重建——容器子级是运行时枚举（childNodeIdsOf，
  ///   00 推论 3），任何结构变更都可能改变容器内容（工具栏新增按钮 /
  ///   侧边栏新增面板 tab），M7.3 拖拽建按钮暴露此缺口。
  /// - **data**：定向（只命中本节点重绘）。
  void _onInvalidation(InvalidationEvent event) {
    if (!mounted) {
      return;
    }
    if (event.changeKind == ChangeKind.structure ||
        event.nodeIds.contains(widget.nodeId)) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final hook = _resolveHook();
    if (hook == null) {
      return const SizedBox.shrink();
    }
    final sink = <Widget>[];
    hook.render(
      FlutterRenderContext(
        host: widget.host,
        kind: widget.kind,
        onCardDrop: widget.onCardDrop,
        onDragStart: widget.onDragStart,
        sink: sink,
      ),
    );
    if (sink.isEmpty) {
      return const SizedBox.shrink(); // Hook 未挂载（占位）。
    }
    if (sink.length == 1) {
      return sink.first;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final widget in sink) Expanded(child: widget)],
    );
  }

  /// 物化实例优先；未物化 → 按需物化。未 started（测试兼容）→ 重派生。
  Hook? _resolveHook() {
    final host = widget.host;
    if (host.started) {
      return host.uiManager.hookFor(widget.nodeId, widget.kind) ??
          host.uiManager.materializeIfAbsent(widget.nodeId, widget.kind);
    }
    final node = host.graph.get(widget.nodeId);
    if (node == null) {
      return null;
    }
    return host.concepts
        .findFor(node)
        .createHook(node, HookContext(kind: widget.kind));
  }
}
