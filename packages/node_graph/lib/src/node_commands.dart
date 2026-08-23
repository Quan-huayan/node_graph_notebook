/// 节点操作 Handler（M6 graph 插件，00 删除清单后按新架构重写）：
///
/// 旧 graph 插件（archive/graph）的 create/delete/update/connect 命令
/// 全部重写为纯 DTO + Handler（03 §四）：业务逻辑在 Handler（写操作
/// 唯一执行者），CommandBus 路由，写后通知 → 画布重渲染。
///
/// - CreateNode / UpdateNode / DeleteNode：Graph 写（判据①）
/// - ConnectNodes：连接 = **L1-node 实例**（00 §2.2：边只是引用低层
///   Node 的 Node，由 Concept 解释）——`connect.references = {from, to}`
/// - DeleteNode 级联：引用该节点的关系实例（contain/connect）一并删除
///   + 画布位置键清理（判据② 外观，与结构删除同步）
///
/// P1-5：DTO 上移 core（跨插件共享命令词表——插件互相不依赖、
/// 通信走 Command，04 §三 约束 3）；本文件保留 Handler 并**再导出
/// DTO**（node_graph 既有消费方零改动）。
library;

import 'package:appframe/appframe.dart';
import 'package:core/core.dart';
import 'package:core_data/core_data.dart';

export 'package:core/core.dart'
    show
        CreateNodeCommand,
        CreateNodeResult,
        UpdateNodeCommand,
        UpdateNodeResult,
        DeleteNodeCommand,
        DeleteNodeResult,
        RestoreNodeCommand,
        RestoreNodeResult,
        ConnectNodesCommand,
        ConnectNodesResult;

/// 创建 Handler：落盘新节点（写操作唯一执行者）。
class CreateNodeHandler
    extends CommandHandler<CreateNodeCommand, CreateNodeResult> {
  /// [graphProvider] 延迟解析结构存储（registerExtensions 阶段无 provider）。
  CreateNodeHandler({required Graph Function() graphProvider})
    : _graphProvider = graphProvider;

  final Graph Function() _graphProvider;

  @override
  Type get commandType => CreateNodeCommand;

  @override
  Future<CreateNodeResult> handle(CreateNodeCommand command) async {
    final now = DateTime.now();
    _graphProvider().save(
      StoredNode(
        id: command.id,
        title: command.title,
        content: command.content,
        metadata: command.metadata ?? const <String, dynamic>{},
        createdAt: now,
        updatedAt: now,
      ),
    );
    return CreateNodeResult(
      affectedNodeIds: <String>{command.id},
      // P1-2 撤销契约：创建的对偶 = 删除（级联/位置键由 DeleteNodeHandler 兜住）。
      inverse: DeleteNodeCommand(nodeId: command.id),
    );
  }
}

/// 更新 Handler：copyWith 后落盘（不可变模型）。
class UpdateNodeHandler
    extends CommandHandler<UpdateNodeCommand, UpdateNodeResult> {
  /// [graphProvider] 延迟解析结构存储。
  UpdateNodeHandler({required Graph Function() graphProvider})
    : _graphProvider = graphProvider;

  final Graph Function() _graphProvider;

  @override
  Type get commandType => UpdateNodeCommand;

  @override
  Future<UpdateNodeResult> handle(UpdateNodeCommand command) async {
    final graph = _graphProvider();
    final node = graph.get(command.nodeId);
    if (node == null) {
      throw StateError('节点不存在: ${command.nodeId}');
    }
    // P1-2：落盘前捕获旧值（对偶命令 = 恢复旧标题/内容/元数据）。
    final previousTitle = node.title;
    final previousContent = node.content;
    final previousMetadata = node.metadata;
    graph.save(
      node.copyWith(
        title: command.title,
        content: command.content,
        metadata: command.metadata,
      ),
    );
    return UpdateNodeResult(
      affectedNodeIds: <String>{command.nodeId},
      inverse: UpdateNodeCommand(
        nodeId: command.nodeId,
        title: previousTitle,
        content: previousContent,
        metadata: previousMetadata,
      ),
    );
  }
}

/// 删除 Handler：级联清理（引用该节点的关系实例 + 画布位置键）。
///
/// 级联原则（00 §2.2 推论）：节点删除后引用它的 L1 实例成为悬空
/// 引用——contain/connect 一并删除；画布位置键为判据② 外观，
/// 与结构删除同步清理（孤儿键惰性 GC 的主动版）。
class DeleteNodeHandler
    extends CommandHandler<DeleteNodeCommand, DeleteNodeResult> {
  /// 注入结构存储与外观存储（延迟解析）。
  DeleteNodeHandler({
    required Graph Function() graphProvider,
    required UIStateStore Function() uiStateProvider,
  }) : _graphProvider = graphProvider,
       _uiStateProvider = uiStateProvider;

  final Graph Function() _graphProvider;
  final UIStateStore Function() _uiStateProvider;

  @override
  Type get commandType => DeleteNodeCommand;

  @override
  Future<DeleteNodeResult> handle(DeleteNodeCommand command) async {
    final graph = _graphProvider();
    // P1-2：删除前捕获快照（节点 + 级联关系实例 + 画布外观键）——
    // 对偶命令 = RestoreNodeCommand 完整恢复。
    final doomed = graph.get(command.nodeId);
    final doomedRelations = graph
        .getAll()
        .where((n) => n.references.values.contains(command.nodeId))
        .toList();
    final uiState = _uiStateProvider();
    final rawPosition = uiState.get(canvasPositionKey(command.nodeId));
    final rawStyle = uiState.get(canvasStyleKey(command.nodeId));
    final position = rawPosition is Map<String, dynamic> ? rawPosition : null;
    final style = rawStyle is Map<String, dynamic> ? rawStyle : null;

    final affected = <String>{command.nodeId};
    // 级联：引用 nodeId 的关系实例（contain/connect 等 L1）一并删除。
    for (final node in doomedRelations) {
      graph.delete(node.id);
      affected.add(node.id);
    }
    graph.delete(command.nodeId);
    // 外观同步清理（判据②：画布成员 = 位置键；样式键一并，M7.3）。
    uiState.remove(canvasPositionKey(command.nodeId));
    uiState.remove(canvasStyleKey(command.nodeId));
    // C5：最近打开键级联（recent.<ts> → 被删节点——Obsidian 最近文件
    // 语义：删除后不应残留在面板；recent.* 前缀扫描，值 == nodeId 即删）。
    for (final entry in uiState.getByPrefix('recent.').entries) {
      if (entry.value == command.nodeId) {
        uiState.remove(entry.key);
      }
    }
    return DeleteNodeResult(
      affectedNodeIds: affected,
      inverse: doomed == null
          ? null
          : RestoreNodeCommand(
              node: doomed,
              relations: doomedRelations,
              position: position,
              style: style,
            ),
    );
  }
}

/// 恢复 Handler：快照回写（节点 + 关系 + 画布键）。
class RestoreNodeHandler
    extends CommandHandler<RestoreNodeCommand, RestoreNodeResult> {
  /// 注入结构存储与外观存储（延迟解析）。
  RestoreNodeHandler({
    required Graph Function() graphProvider,
    required UIStateStore Function() uiStateProvider,
  }) : _graphProvider = graphProvider,
       _uiStateProvider = uiStateProvider;

  final Graph Function() _graphProvider;
  final UIStateStore Function() _uiStateProvider;

  @override
  Type get commandType => RestoreNodeCommand;

  @override
  Future<RestoreNodeResult> handle(RestoreNodeCommand command) async {
    final graph = _graphProvider();
    graph.save(command.node);
    final affected = <String>{command.node.id};
    for (final relation in command.relations) {
      graph.save(relation);
      affected.add(relation.id);
    }
    final uiState = _uiStateProvider();
    final position = command.position;
    if (position != null) {
      uiState.set(canvasPositionKey(command.node.id), position);
    }
    final style = command.style;
    if (style != null) {
      uiState.set(canvasStyleKey(command.node.id), style);
    }
    return RestoreNodeResult(
      affectedNodeIds: affected,
      // redo 链闭合：恢复的对偶 = 再次删除。
      inverse: DeleteNodeCommand(nodeId: command.node.id),
    );
  }
}

/// 连接 Handler：创建/更新 `connect` 实例（L1-node，引用两端）。
///
/// 语义（M6 简化，无向边）：同向或反向连接已存在 → 幂等 no-op；
/// 自连接 → 拒绝；环校验保留（防未来 L2+ 与自引用边界，00 §2.3）。
class ConnectNodesHandler
    extends CommandHandler<ConnectNodesCommand, ConnectNodesResult> {
  /// 注入结构存储与环校验器（延迟解析）。
  ConnectNodesHandler({
    required Graph Function() graphProvider,
    AcyclicChecker? checker,
  }) : _graphProvider = graphProvider,
       _checker = checker ?? const AcyclicChecker();

  final Graph Function() _graphProvider;
  final AcyclicChecker _checker;

  @override
  Type get commandType => ConnectNodesCommand;

  @override
  Future<ConnectNodesResult> handle(ConnectNodesCommand command) async {
    if (command.from == command.to) {
      throw CycleError(<String>[command.from, command.to]);
    }
    final graph = _graphProvider();
    // 无向边：任一方向已存在 → 幂等（UI 层提示"已连接"）。
    final existing = graph.getAll().where((n) {
      final refs = n.references;
      return refs['from'] == command.from && refs['to'] == command.to ||
          refs['from'] == command.to && refs['to'] == command.from;
    }).firstOrNull;
    if (existing != null) {
      // 幂等 no-op：无实际变更 → 不可撤销（inverse null）。
      return ConnectNodesResult(affectedNodeIds: <String>{existing.id});
    }
    final connId = 'conn-${command.from}-${command.to}';
    // 环校验（双保险：UI 可预判；Handler 兜底）。
    final cycle = _checker.check(
      affectedRefs: <String, Set<String>>{
        connId: <String>{command.from, command.to},
      },
      graph: graph,
    );
    if (cycle != null) {
      throw CycleError(cycle);
    }
    final now = DateTime.now();
    graph.save(
      StoredNode(
        id: connId,
        title: 'connect:${command.from}→${command.to}',
        references: <String, String>{'from': command.from, 'to': command.to},
        createdAt: now,
        updatedAt: now,
      ),
    );
    return ConnectNodesResult(
      affectedNodeIds: <String>{connId, command.from, command.to},
      // P1-2：撤销连接 = 删除连接实例（DeleteNodeHandler 级联清理）。
      inverse: DeleteNodeCommand(nodeId: connId),
    );
  }
}
