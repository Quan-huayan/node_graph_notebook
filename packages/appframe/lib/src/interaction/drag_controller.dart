/// DragController —— 拖拽事务生命周期（03 §一 四阶段 / §5.3 提交时序）。
///
/// 拖拽 = 前端图结构变更，结果通过写操作表达（00 不变量 4.2）。
///
/// 四阶段（03 §一）：dragStart（无 Command）→ dragMove（实时预览）→
/// onDrop（判定 + 提交）→ cancel（回滚，无持久化副作用）。
///
/// drop 提交（§5.3 时序）：
/// 1. 目标容器 Concept.askDropSemantics → DataMove / UIMove / Reject
/// 2. 环预判 → 命中 → FlightShell.abort() 回弹
/// 3. commandBus.dispatch（Handler 二次环校验，双保险）
/// 4. 写后通知 → UI 管理器失效广播（宿主已 attach）
/// 5. FlightShell.present → 渐变 → 销毁
library;

import 'package:core/core.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter/widgets.dart';

import 'flight_shell.dart';

/// drop 提交结果（宿主决策依据）。
enum DropOutcomeKind {
  /// 已提交（数据命令或外观直写）。
  committed,

  /// 撞环拒绝（FlightShell 已回弹）。
  cycleRejected,

  /// 容器 schema 不兼容 / 其他拒绝（FlightShell 已回弹）。
  rejected,
}

/// drop 提交结果。
class DropOutcome {
  const DropOutcome._(this.kind, [this.reason]);

  /// 提交成功。
  const DropOutcome.committed() : this._(DropOutcomeKind.committed);

  /// 撞环拒绝（携带环路径）。
  const DropOutcome.cycleRejected(String cyclePath)
    : this._(DropOutcomeKind.cycleRejected, cyclePath);

  /// 容器拒绝（携带原因）。
  const DropOutcome.rejected(String reason)
    : this._(DropOutcomeKind.rejected, reason);

  /// 结果种类。
  final DropOutcomeKind kind;

  /// 拒绝原因 / 环路径（用户可读文案）。
  final String? reason;
}

/// DataMove → 写命令的工厂（容器插件可定制自己的命令；
/// M6 回填：folder 场景注入 MoveNodesCommand 工厂，双写容器 + 子节点）。
typedef MoveCommandFactory =
    Command Function({
      required String draggedNodeId,
      required String targetContainerId,
      required Map<String, String> newReferences,
    });

/// 侧边栏拖入语义（M7.3 Flowing UI）：宿主缺省注册（返回 null = 默认
/// folder 语义），插件 last-wins 覆盖（如 node_ai 对 AI 节点返回
/// CreateAIPanelCommand——拖 AI 节点入侧边栏 = 钉 AI 面板 tab）。
typedef SidebarDropSemantics =
    Command? Function({
      required String draggedNodeId,
      required String targetContainerId,
    });

/// 工具栏拖入语义（M7.3 Flowing UI）：宿主缺省注册（返回 null = 默认
/// CreateToolbarButtonCommand——拖任意节点到工具栏 = 建按钮）。
typedef ToolbarDropSemantics =
    Command? Function({required String draggedNodeId});

/// 拖拽控制器：四阶段事务 + drop 语义判定 + 提交。
class DragController {
  /// 注入判定/执行依赖（环校验器与命令工厂缺省内置）。
  DragController({
    required this.graph,
    required this.concepts,
    required this.commandBus,
    required this.uiStateStore,
    required this.flightShell,
    AcyclicChecker? checker,
    MoveCommandFactory? moveCommandFactory,
  }) : _checker = checker ?? const AcyclicChecker(),
       _moveCommandFactory = moveCommandFactory ?? _defaultMoveCommand;

  static Command _defaultMoveCommand({
    required String draggedNodeId,
    required String targetContainerId,
    required Map<String, String> newReferences,
  }) => MoveReferencesCommand(
    nodeId: draggedNodeId,
    newReferences: newReferences,
  );

  /// 结构权威（容器/被拖节点读取）。
  final Graph graph;

  /// 归属判定（容器 Concept 的 askDropSemantics）。
  final ConceptRegistry concepts;

  /// 写通道（数据命令 dispatch）。
  final CommandBus commandBus;

  /// 外观存储（UIMove 直写）。
  final UIStateStore uiStateStore;

  /// 过渡渲染层（回弹/渐变）。
  final FlightShell flightShell;

  final AcyclicChecker _checker;
  final MoveCommandFactory _moveCommandFactory;

  /// Phase 1：拖拽开始（视觉事务开启，无 Command——03 档会话态）。
  void dragStart(String draggedNodeId) {
    _dragging = draggedNodeId;
  }

  String? _dragging;

  /// 当前拖拽节点（Phase 1-3 期间）。
  String? get dragging => _dragging;

  /// 拖拽起点（全局坐标）——飞行壳层视觉的 from（M7：影像从源起飞）。
  /// 由拖拽源（笔记行 Hook 的 Draggable.onDragStarted）记录。
  Offset? dragStartOffset;

  /// 记录拖拽起点（Phase 1 增强——飞行视觉）。
  void recordDragStart(Offset position) {
    dragStartOffset = position;
  }

  /// Phase 3：drop 提交（§5.3 时序）。
  ///
  /// [targetContainerHook] 目标容器 Hook；[dropPoint] 落点（物理坐标）。
  Future<DropOutcome> onDrop({
    required String draggedNodeId,
    required Hook targetContainerHook,
    required Offset dropPoint,
  }) async {
    final container = graph.get(targetContainerHook.nodeId);
    final dragged = graph.get(draggedNodeId);
    if (container == null || dragged == null) {
      flightShell.abort();
      return const DropOutcome.rejected('节点不存在');
    }
    final containerConcept = concepts.findFor(container);

    // 1. 判定：目标容器回答"接收这个 Node 意味着什么"（01-C / 03 §三）。
    final semantics = containerConcept.askDropSemantics(dragged);
    switch (semantics) {
      case DataMove(:final newReferences):
        return _commitDataMove(
          draggedNodeId: draggedNodeId,
          targetContainerHook: targetContainerHook,
          newReferences: newReferences,
          dropPoint: dropPoint,
        );
      case UIMove(:final key, :final value):
        // ② 外观直写（画布拖动等）。
        uiStateStore.set(key, value);
        return const DropOutcome.committed();
      case RejectDrop(:final reason):
        // 拒绝：drop 预判，Phase 4 回滚。
        flightShell.abort();
        return DropOutcome.rejected(reason);
    }
  }

  /// Phase 4：取消事务（回弹，无持久化副作用）。
  void cancel() {
    _dragging = null;
    flightShell.abort();
  }

  /// ① 数据命令提交：环预判 → dispatch（双保险）→ 写后通知 → 壳层过渡。
  Future<DropOutcome> _commitDataMove({
    required String draggedNodeId,
    required Hook targetContainerHook,
    required Map<String, String> newReferences,
    required Offset dropPoint,
  }) async {
    // 2. 环预判（drop 阶段即可拒绝，00 §2.3）。
    final cycle = _checker.check(
      affectedRefs: <String, Set<String>>{
        draggedNodeId: newReferences.values.toSet(),
      },
      graph: graph,
    );
    if (cycle != null) {
      flightShell.abort();
      return DropOutcome.cycleRejected(cycle.join(' → '));
    }
    // 3. dispatch：Handler 二次环校验（双保险）+ 落盘 + 写后通知
    //    （WriteNotifier → UI 管理器失效广播由 CommandBus 完成）。
    try {
      final command = _moveCommandFactory(
        draggedNodeId: draggedNodeId,
        targetContainerId: targetContainerHook.nodeId,
        newReferences: newReferences,
      );
      await commandBus.dispatch<Command, WriteResult>(command);
      // 5. 壳层过渡：渐变到目标位置 → 提交销毁。
      flightShell.present(from: Offset.zero, to: dropPoint);
      return const DropOutcome.committed();
    } on CycleError catch (e) {
      // 失败路径：事务回滚 → 回弹 → 无持久化副作用。
      flightShell.abort();
      return DropOutcome.cycleRejected(e.cyclePath.join(' → '));
    }
  }
}
