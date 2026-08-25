/// MoveReferencesCommand —— 引用变更写命令（00 判据①：数据命令）。
///
/// 侧边栏重排（拖拽提交 §5.3）的通用命令骨架：把容器判定的
/// 最终 references 写入目标 Node。folder 等容器插件可声明
/// 自己的命令类；本命令提供机制（环校验 + 落盘 + 写后通知）。
library;

import 'package:core_data/core_data.dart';

import '../cycle/acyclic_checker.dart';
import 'command.dart';
import 'exceptions.dart';

/// 引用变更命令（纯 DTO）。
class MoveReferencesCommand extends Command<MoveReferencesCommand> {
  /// 携带被移 Node 与最终 references。
  const MoveReferencesCommand({
    required this.nodeId,
    required this.newReferences,
  });

  /// 被移动的 Node。
  final String nodeId;

  /// 变更后的最终 references（容器判定推导，03 §三）。
  final Map<String, String> newReferences;

  @override
  String get name => 'move.references';

  @override
  Map<String, dynamic> get payload => <String, dynamic>{
    'nodeId': nodeId,
    'references': newReferences,
  };
}

/// 引用变更写结果。
class MoveReferencesResult implements WriteResult {
  /// 携带受影响节点。
  const MoveReferencesResult({required this.affectedNodeIds});

  @override
  final Set<String> affectedNodeIds;

  @override
  ChangeKind get changeKind => ChangeKind.structure;

  // R3c 不可撤销理由（docs/review 总览 P0-3）：references **覆盖写**——
  // handler 未捕获旧 references（构造对偶命令需旧值快照，超出本命令契约
  // 范围）；撤销链由上层容器命令承担（folder 的 MoveNodesCommand 自带
  // inverse 对偶，其 handler 捕获 previousParent）。本骨架命令显式不可撤销。
  @override
  Command? get inverse => null;
}

/// 引用变更 Handler（写操作唯一执行者，01-D）：
///
/// 1. 环校验（落盘前，00 §2.3；抛 CycleError + 用户可读文案）
/// 2. graph.save（引用变更）
/// 3. 返回 WriteResult（structure → 树重挂）
class MoveReferencesHandler
    extends CommandHandler<MoveReferencesCommand, MoveReferencesResult> {
  /// 注入结构存储与环校验器（缺省内置）。
  MoveReferencesHandler({required this.graph, AcyclicChecker? checker})
    : _checker = checker ?? const AcyclicChecker();

  /// 结构权威（引用变更落盘）。
  final Graph graph;

  final AcyclicChecker _checker;

  @override
  Type get commandType => MoveReferencesCommand;

  @override
  Future<MoveReferencesResult> handle(MoveReferencesCommand command) async {
    final node = graph.get(command.nodeId);
    if (node == null) {
      throw StateError('引用的目标节点不存在: ${command.nodeId}');
    }
    // 环校验：落盘前对受影响子图增量检查（00 §2.3 执行点）。
    // nodeId 出发的全部新引用边（多 slot → 多 target）。
    final cycle = _checker.check(
      affectedRefs: <String, Set<String>>{
        command.nodeId: command.newReferences.values.toSet(),
      },
      graph: graph,
    );
    if (cycle != null) {
      throw CycleError(cycle);
    }
    graph.save(node.copyWith(references: command.newReferences));
    return MoveReferencesResult(affectedNodeIds: <String>{command.nodeId});
  }
}
