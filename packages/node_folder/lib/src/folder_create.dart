/// 文件夹内新建（B3：Obsidian 文件夹内新建语义，一步撤销）。
///
/// Handler = 写操作唯一执行者（01-D）：新建笔记（L0，references 空）+
/// contain 实例（L1，references={parent,child} 引用两端）组合写。
/// 对偶撤销 = DeleteNodeCommand(nodeId: 新笔记)——node_graph 的
/// DeleteNodeHandler 级联删除指向它的 contain 实例（一步撤销链闭合）。
library;

import 'package:appframe/appframe.dart';
import 'package:core/core.dart';
import 'package:core_data/core_data.dart';

/// 新节点 id（无 uuid 依赖：时间戳 + 随机后缀，36 进制紧凑——同
/// node_graph 的 newNodeId 约定；插件互不依赖故本地复刻）。
String folderNewNodeId() =>
    'node-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
    '-${(DateTime.now().microsecondsSinceEpoch & 0xFFFF).toRadixString(36)}';

/// 文件夹内创建 Handler。
class CreateNodeInFolderHandler
    extends
        CommandHandler<CreateNodeInFolderCommand, CreateNodeInFolderResult> {
  /// [graphProvider] 延迟解析结构存储（plugon 生命周期：registerExtensions
  /// 阶段尚无服务提供器，onLoad 后才可解析——同 MoveNodesHandler 模式）。
  CreateNodeInFolderHandler({required Graph Function() graphProvider})
    : _graphProvider = graphProvider;

  final Graph Function() _graphProvider;

  @override
  Type get commandType => CreateNodeInFolderCommand;

  @override
  Future<CreateNodeInFolderResult> handle(
    CreateNodeInFolderCommand command,
  ) async {
    final graph = _graphProvider();
    if (graph.get(command.folderId) == null) {
      throw StateError('目标文件夹不存在: ${command.folderId}');
    }
    // audit #4（docs/review/audit-node_folder.md）：写前断言目标 id 不存在——
    // id 撞车会整体覆盖既有节点（数据丢失），且该 id 恰为 folder 祖先时
    // 新 contain 即成环（数据完整性双保险）。
    if (graph.get(command.id) != null) {
      throw StateError('目标 id 已存在: ${command.id}');
    }
    final now = DateTime.now();
    // 1. 新笔记（L0：references 恒空——00 §2.2）。
    final note = StoredNode(
      id: command.id,
      title: command.title,
      content: command.content,
      metadata: command.metadata ?? const <String, dynamic>{},
      createdAt: now,
      updatedAt: now,
    );
    graph.save(note);
    // 2. contain 实例（L1：引用两端——folder.contents = 读侧反查）。
    //    注：id 用连字符（Windows 文件名不容冒号，同 MoveNodesHandler）。
    final containId = 'contain-${command.id}-${command.folderId}';
    graph.save(
      StoredNode(
        id: containId,
        title: 'contain:${command.id}',
        references: <String, String>{
          'parent': command.folderId,
          'child': command.id,
        },
        createdAt: now,
        updatedAt: now,
      ),
    );
    return CreateNodeInFolderResult(
      affectedNodeIds: <String>{command.id, containId, command.folderId},
      // 一步撤销：删除新笔记（级联删除 contain 实例）。
      inverse: DeleteNodeCommand(nodeId: command.id),
    );
  }
}
