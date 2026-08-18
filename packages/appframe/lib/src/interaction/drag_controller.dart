/// DragController —— 拖拽事务生命周期（03 §一 四阶段 / §5.3 提交时序）。
///
/// 拖拽 = 前端图结构变更，结果通过写操作表达（00 不变量 4.2）。
///
/// 四阶段（03 §一）：dragStart（无 Command）→ dragMove（实时预览）→
/// onDrop（判定 + 提交）→ cancel（回滚，无持久化副作用）。
///
/// drop 提交（§5.3 时序）：
/// 1. 目标容器 Concept.askDropSemantics → DataMove / UIMove / Reject
/// 2. 环预判 → 命中 → 回弹（无持久化副作用）
/// 3. commandBus.dispatch（Handler 二次环校验，双保险）
/// 4. 写后通知 → UI 管理器失效广播（宿主已 attach）
/// 5. FlightShell.present → 渐变到目标位置 → 销毁
///
/// M7.4（Flowing UI 落实修正）：
/// - `dragStart`/`dragMove` 真正可被宿主接线（此前只有声明没有调用方，
///   会话态永远停留在 null）
/// - 所有出口统一清理会话态；非 CycleError 的命令失败不再泄漏到
///   async onAcceptWithDetails（架构 §8：禁止静默失败 / 未捕获错误）
/// - `present` 可直接承接 overlay 影像，成功/失败由本控制器统一编排，
///   调用方不再需要先 fly、再按结果手动 bounce（旧路径存在双影像竞态）
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

/// Phase 2 实时预览回调（03 §一：影像接近目标容器 → 宿主可做形态渐变）。
typedef DragMoveListener = void Function(String draggedNodeId, Offset position);

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
    this.onDragMove,
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

  /// Phase 2 实时预览回调（形态渐变的宿主接线点）。
  final DragMoveListener? onDragMove;

  final AcyclicChecker _checker;
  final MoveCommandFactory _moveCommandFactory;

  String? _dragging;
  Offset? _lastDragPosition;

  /// 当前拖拽节点（Phase 1-3 期间）。
  String? get dragging => _dragging;

  /// 最近一次 dragMove 位置（预览/落点兜底）。
  Offset? get lastDragPosition => _lastDragPosition;

  /// 拖拽起点（全局坐标）——飞行壳层视觉的 from（03 §二）。
  /// 由拖拽源（Draggable.onDragStarted）经 [recordDragStart] 记录。
  Offset? dragStartOffset;

  /// Phase 1：拖拽开始（视觉事务开启，无 Command——03 档会话态）。
  ///
  /// 重复 start 幂等；切换节点会清掉上一事务的起点/预览（防串场）。
  void dragStart(String draggedNodeId) {
    if (_dragging == draggedNodeId) {
      return;
    }
    _dragging = draggedNodeId;
    dragStartOffset = null;
    _lastDragPosition = null;
  }

  /// 记录拖拽起点（Phase 1 增强——飞行视觉）。
  void recordDragStart(Offset position) {
    dragStartOffset = position;
  }

  /// Phase 2：实时预览。只有 [dragStart] 后才会分发；无事务时忽略。
  void dragMove(Offset position) {
    final nodeId = _dragging;
    if (nodeId == null) {
      return;
    }
    _lastDragPosition = position;
    onDragMove?.call(nodeId, position);
  }

  /// Phase 3：drop 提交（§5.3 时序）。
  ///
  /// [targetContainerHook] 目标容器 Hook；[dropPoint] 落点（物理坐标）。
  /// [from] 影像起点（缺省 = [dragStartOffset] → [dropPoint]）；
  /// [overlay] + [flightChild] 提供时由本控制器统一执行飞行/回弹视觉。
  /// [moveCommandFactory] 本次 drop 的命令工厂（共享 DragController 时
  /// 按目标容器路由；缺省用构造注入）。
  Future<DropOutcome> onDrop({
    required String draggedNodeId,
    required Hook targetContainerHook,
    required Offset dropPoint,
    Offset? from,
    OverlayState? overlay,
    Widget? flightChild,
    MoveCommandFactory? moveCommandFactory,
  }) async {
    final container = graph.get(targetContainerHook.nodeId);
    final dragged = graph.get(draggedNodeId);
    if (container == null || dragged == null) {
      _rollback(
        from: from,
        dropPoint: dropPoint,
        overlay: overlay,
        flightChild: flightChild,
      );
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
          from: from,
          overlay: overlay,
          flightChild: flightChild,
          moveCommandFactory: moveCommandFactory,
        );
      case UIMove(:final key, :final value):
        // ② 外观直写（画布拖动等）。
        uiStateStore.set(key, value);
        _finishCommitted(
          dropPoint: dropPoint,
          from: from,
          overlay: overlay,
          flightChild: flightChild,
        );
        return const DropOutcome.committed();
      case RejectDrop(:final reason):
        _rollback(
          from: from,
          dropPoint: dropPoint,
          overlay: overlay,
          flightChild: flightChild,
        );
        return DropOutcome.rejected(reason);
    }
  }

  /// Phase 4：取消事务（回弹，无持久化副作用）。无事务时幂等 no-op。
  void cancel() {
    if (_dragging == null) {
      return;
    }
    _resetSession();
    flightShell.abort();
  }

  /// ① 数据命令提交：环预判 → dispatch（双保险）→ 写后通知 → 壳层过渡。
  Future<DropOutcome> _commitDataMove({
    required String draggedNodeId,
    required Hook targetContainerHook,
    required Map<String, String> newReferences,
    required Offset dropPoint,
    required Offset? from,
    required OverlayState? overlay,
    required Widget? flightChild,
    required MoveCommandFactory? moveCommandFactory,
  }) async {
    // 2. 环预判（drop 阶段即可拒绝，00 §2.3）。
    final cycle = _checker.check(
      affectedRefs: <String, Set<String>>{
        draggedNodeId: newReferences.values.toSet(),
      },
      graph: graph,
    );
    if (cycle != null) {
      _rollback(
        from: from,
        dropPoint: dropPoint,
        overlay: overlay,
        flightChild: flightChild,
      );
      return DropOutcome.cycleRejected(cycle.join(' → '));
    }
    // 3. dispatch：Handler 二次环校验（双保险）+ 落盘 + 写后通知
    //    （WriteNotifier → UI 管理器失效广播由 CommandBus 完成）。
    try {
      final factory = moveCommandFactory ?? _moveCommandFactory;
      final command = factory(
        draggedNodeId: draggedNodeId,
        targetContainerId: targetContainerHook.nodeId,
        newReferences: newReferences,
      );
      await commandBus.dispatch<Command, WriteResult>(command);
      // 5. 壳层过渡：渐变到目标位置 → 提交销毁。
      _finishCommitted(
        dropPoint: dropPoint,
        from: from,
        overlay: overlay,
        flightChild: flightChild,
      );
      return const DropOutcome.committed();
    } on CycleError catch (e) {
      // 失败路径：事务回滚 → 回弹 → 无持久化副作用。
      _rollback(
        from: from,
        dropPoint: dropPoint,
        overlay: overlay,
        flightChild: flightChild,
      );
      return DropOutcome.cycleRejected(e.cyclePath.join(' → '));
    } catch (error) {
      // 其他命令失败（源节点已删、落盘 IO 失败等）同样要终结事务，
      // 不再向 async DragTarget 回调泄漏未捕获异常。
      _rollback(
        from: from,
        dropPoint: dropPoint,
        overlay: overlay,
        flightChild: flightChild,
      );
      return DropOutcome.rejected('移动失败：$error');
    }
  }

  /// 成功出口统一收尾：视觉 present（可选）→ 会话态清理。
  void _finishCommitted({
    required Offset dropPoint,
    required Offset? from,
    required OverlayState? overlay,
    required Widget? flightChild,
  }) {
    flightShell.present(
      from: from ?? dragStartOffset ?? dropPoint,
      to: dropPoint,
      overlay: overlay,
      child: flightChild,
    );
    _resetSession();
  }

  /// 失败出口统一收尾：有影像 → 回弹；无影像 → abort 状态机 → 清理。
  void _rollback({
    required Offset? from,
    required Offset dropPoint,
    required OverlayState? overlay,
    required Widget? flightChild,
  }) {
    final origin = from ?? dragStartOffset ?? dropPoint;
    if (overlay != null && flightChild != null) {
      flightShell.bounce(
        overlay: overlay,
        child: flightChild,
        from: origin,
        to: dropPoint,
        onFinished: (_) {},
      );
    } else {
      flightShell.abort();
    }
    _resetSession();
  }

  void _resetSession() {
    _dragging = null;
    _lastDragPosition = null;
    dragStartOffset = null;
  }
}
