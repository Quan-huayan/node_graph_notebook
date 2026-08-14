/// MoveNodesCommand —— 移动命令（架构 §5.3 第 3-4 步，contain 模型）。
///
/// "把 child 移入 container" = **contain 实例变更**（01 拍板 #19）：
/// - 查 child 现有 contain 实例（references.child == childId）：
///   无 → 创建 `{parent: containerId, child: childId}`；
///   有 → 更新 parent = containerId（重排）。
/// - folder/note 自身零引用变更（L0-node，00 §2.2）。
library;

import 'package:appframe/appframe.dart';
import 'package:core/core.dart';
import 'package:core_data/core_data.dart';

import 'contain_concept.dart';

/// 移动命令（纯 DTO）。
class MoveNodesCommand extends Command<MoveNodesCommand> {
  /// 携带容器与子节点。
  const MoveNodesCommand({required this.containerId, required this.childId});

  /// 目标容器（folder）。
  final String containerId;

  /// 被移动的节点。
  final String childId;

  @override
  String get name => 'folder.move';

  @override
  Map<String, dynamic> get payload => <String, dynamic>{
    'containerId': containerId,
    'childId': childId,
  };
}

/// 移动写结果（structure → 树重挂；受影响 = contain 实例 + 容器）。
class MoveNodesResult implements WriteResult {
  /// 携带受影响节点与对偶命令（P1-2：撤销 = 移回原父级，或
  /// UncontainCommand 恢复"无归属"状态）。
  const MoveNodesResult({required this.affectedNodeIds, this.inverse});

  @override
  final Set<String> affectedNodeIds;

  @override
  ChangeKind get changeKind => ChangeKind.structure;

  @override
  final Command? inverse;
}

/// 移动 Handler（写操作唯一执行者，01-D）：
///
/// 1. 语义后代检查（拖 folder 进自己后代 = 逻辑环，00 §2.3 预判）
/// 2. 环校验（contain 新边）
/// 3. contain 实例创建/更新并落盘
/// 4. 返回 WriteResult{affected, structure}
class MoveNodesHandler
    extends CommandHandler<MoveNodesCommand, MoveNodesResult> {
  /// [graphProvider] 延迟解析结构存储（插件在 registerExtensions 阶段
  /// 尚无服务提供器，onLoad 后才可解析——plugon 生命周期顺序）。
  MoveNodesHandler({
    required Graph Function() graphProvider,
    AcyclicChecker? checker,
  }) : _graphProvider = graphProvider,
       _checker = checker ?? const AcyclicChecker();

  final Graph Function() _graphProvider;
  final AcyclicChecker _checker;

  @override
  Type get commandType => MoveNodesCommand;

  @override
  Future<MoveNodesResult> handle(MoveNodesCommand command) async {
    final graph = _graphProvider();
    // 1. 语义后代检查：container 是 child 的后代 → 逻辑环拒绝。
    //    （Ln 模型 references 天然无环，folder 嵌套矛盾由本检查兜住。
    //    M7.2：拖进自己 = 自引用环——isDescendant 已含 nodeId==ancestorId
    //    判定，此处显式兜底双保险。）
    if (command.childId == command.containerId ||
        isDescendant(graph, command.childId, command.containerId)) {
      throw CycleError(<String>[
        command.childId,
        command.containerId,
        command.childId,
      ]);
    }
    // 2. 现有 contain 实例（child == childId）→ 更新 parent；无 → 新建。
    final existing = graph
        .getAll()
        .where((n) => n.references['child'] == command.childId)
        .firstOrNull;
    // P1-2：捕获原父级（null = 此前无归属——对偶命令 = Uncontain）。
    final previousParentId = existing?.references['parent'];
    // 注：id 用连字符（Windows 文件名不容冒号）。
    final containId =
        existing?.id ?? 'contain-${command.childId}-${command.containerId}';
    final newRefs = <String, String>{
      'parent': command.containerId,
      'child': command.childId,
    };
    // 3. 环校验（双保险：drop 预判 + Handler 二次，00 §2.3 执行点）。
    final cycle = _checker.check(
      affectedRefs: <String, Set<String>>{containId: newRefs.values.toSet()},
      graph: graph,
    );
    if (cycle != null) {
      throw CycleError(cycle);
    }
    // 4. contain 实例落盘（L1-node，引用两端；folder/note 零变更）。
    final child = graph.get(command.childId);
    if (child == null) {
      throw StateError('移动目标不存在: ${command.childId}');
    }
    // 无实际变更（已在该容器）→ 不可撤销 no-op。
    if (previousParentId == command.containerId) {
      return MoveNodesResult(
        affectedNodeIds: <String>{containId, command.containerId},
      );
    }
    final contain =
        existing ??
        StoredNode(
          id: containId,
          title: 'contain:${command.childId}',
          createdAt: child.createdAt,
          updatedAt: child.updatedAt,
        );
    graph.save(contain.copyWith(references: newRefs));
    // 5. 写后通知（WriteResult → UI 管理器树重挂）。
    return MoveNodesResult(
      affectedNodeIds: <String>{
        containId,
        command.containerId,
        if (previousParentId != null) previousParentId,
      },
      // P1-2：撤销 = 移回原父级；此前无归属 → 删除 contain 实例。
      inverse: previousParentId == null
          ? UncontainCommand(childId: command.childId)
          : MoveNodesCommand(
              containerId: previousParentId,
              childId: command.childId,
            ),
    );
  }
}

/// 取消包含命令（P1-2：移动撤销的对偶——child 此前无归属时，
/// 撤销 = 删除本次新建的 contain 实例，恢复"无归属"状态）。
class UncontainCommand extends Command<UncontainCommand> {
  /// 构造取消包含命令。
  const UncontainCommand({required this.childId});

  /// 被取消归属的子节点。
  final String childId;

  @override
  String get name => 'folder.uncontain';

  @override
  Map<String, dynamic> get payload => <String, dynamic>{'childId': childId};
}

/// 取消包含写结果（structure；对偶 = 移回原父级——redo 链闭合）。
class UncontainResult implements WriteResult {
  /// 携带受影响节点与对偶命令。
  const UncontainResult({required this.affectedNodeIds, this.inverse});

  @override
  final Set<String> affectedNodeIds;

  @override
  ChangeKind get changeKind => ChangeKind.structure;

  @override
  final Command? inverse;
}

/// 取消包含 Handler：删除 child 的 contain 实例（写操作唯一执行者）。
class UncontainHandler
    extends CommandHandler<UncontainCommand, UncontainResult> {
  /// [graphProvider] 延迟解析结构存储。
  UncontainHandler({required Graph Function() graphProvider})
    : _graphProvider = graphProvider;

  final Graph Function() _graphProvider;

  @override
  Type get commandType => UncontainCommand;

  @override
  Future<UncontainResult> handle(UncontainCommand command) async {
    final graph = _graphProvider();
    final existing = graph
        .getAll()
        .where((n) => n.references['child'] == command.childId)
        .firstOrNull;
    if (existing == null) {
      return UncontainResult(affectedNodeIds: <String>{command.childId});
    }
    final parentId = existing.references['parent'];
    graph.delete(existing.id);
    return UncontainResult(
      affectedNodeIds: <String>{
        existing.id,
        command.childId,
        if (parentId != null) parentId,
      },
      // redo 链闭合：取消归属的对偶 = 移回原父级。
      inverse: parentId == null
          ? null
          : MoveNodesCommand(containerId: parentId, childId: command.childId),
    );
  }
}
