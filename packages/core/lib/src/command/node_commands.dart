/// 节点操作命令 DTO（P1-5 上移 core：跨插件共享的命令词表）。
///
/// 00 §2.2"边只是恰好引用低层 Node 的 Node"的落地命令集。**Handler 归
/// 插件**（node_graph 贡献执行者），DTO 归 core——插件互相不依赖、
/// 通信走 Command（04 §三 约束 3）：侧边栏（node_folder）/编辑器
/// （node_editor）发删除命令无需依赖 node_graph，只依赖本词表。
///
/// 上移范围 = 纯 DTO + WriteResult（零 appframe 依赖）；业务逻辑
/// （级联清理/环校验/快照）仍在 node_graph 的 Handler。
library;

import 'package:core_data/core_data.dart';

import 'command.dart';

/// 创建节点命令（纯 DTO）。
class CreateNodeCommand extends Command<CreateNodeCommand> {
  /// 携带新节点字段。
  const CreateNodeCommand({
    required this.id,
    required this.title,
    this.content,
    this.metadata,
  });

  /// 新节点 id（调用方生成，uuid）。
  final String id;

  /// 标题。
  final String title;

  /// 内容（markdown 等）。
  final String? content;

  /// 元数据。
  final Map<String, dynamic>? metadata;

  @override
  String get name => 'graph.create';

  @override
  Map<String, dynamic> get payload => <String, dynamic>{
    'id': id,
    'title': title,
    'content': content,
  };
}

/// 创建写结果（structure：新节点 → 树重挂/重渲染）。
class CreateNodeResult implements WriteResult {
  /// 携带新节点 id 与对偶命令（P1-2：撤销 = 删除该节点）。
  const CreateNodeResult({required this.affectedNodeIds, this.inverse});

  @override
  final Set<String> affectedNodeIds;

  @override
  ChangeKind get changeKind => ChangeKind.structure;

  @override
  final Command? inverse;
}

/// 更新节点命令（标题/内容/元数据——C2 属性面板用 metadata）。
class UpdateNodeCommand extends Command<UpdateNodeCommand> {
  /// 携带变更字段（null = 不变；metadata = 整体替换语义）。
  const UpdateNodeCommand({required this.nodeId, this.title, this.content, this.metadata});

  /// 目标节点。
  final String nodeId;

  /// 新标题（null = 不变）。
  final String? title;

  /// 新内容（null = 不变）。
  final String? content;

  /// 新元数据（整体替换；null = 不变）。
  final Map<String, dynamic>? metadata;

  @override
  String get name => 'graph.update';

  @override
  Map<String, dynamic> get payload => <String, dynamic>{
    'nodeId': nodeId,
    'title': title,
    'content': content,
    'metadata': metadata,
  };
}

/// 更新写结果（data：重绘粒度）。
class UpdateNodeResult implements WriteResult {
  /// 携带受影响节点与对偶命令（P1-2：撤销 = 恢复旧标题/内容）。
  const UpdateNodeResult({required this.affectedNodeIds, this.inverse});

  @override
  final Set<String> affectedNodeIds;

  @override
  ChangeKind get changeKind => ChangeKind.data;

  @override
  final Command? inverse;
}

/// 删除节点命令。
class DeleteNodeCommand extends Command<DeleteNodeCommand> {
  /// 携带目标节点。
  const DeleteNodeCommand({required this.nodeId});

  /// 目标节点。
  final String nodeId;

  @override
  String get name => 'graph.delete';

  @override
  Map<String, dynamic> get payload => <String, dynamic>{'nodeId': nodeId};
}

/// 删除写结果（structure；受影响 = 节点 + 被级联的关系实例）。
class DeleteNodeResult implements WriteResult {
  /// 携带全部受影响节点（含被删除的关系实例）与对偶命令
  /// （P1-2：撤销 = RestoreNodeCommand 恢复节点/关系/画布键）。
  const DeleteNodeResult({required this.affectedNodeIds, this.inverse});

  @override
  final Set<String> affectedNodeIds;

  @override
  ChangeKind get changeKind => ChangeKind.structure;

  @override
  final Command? inverse;
}

/// 恢复删除命令（P1-2：DeleteNode 的对偶——撤销删除 = 完整恢复）。
///
/// 载荷 = 删除前快照：被删节点 + 被级联删除的关系实例（contain/
/// connect）+ 画布位置/样式键原值（null = 删除时无该键）。
class RestoreNodeCommand extends Command<RestoreNodeCommand> {
  /// 构造恢复命令。
  const RestoreNodeCommand({
    required this.node,
    this.relations = const <Node>[],
    this.position,
    this.style,
  });

  /// 被删节点（完整快照）。
  final Node node;

  /// 被级联删除的关系实例。
  final List<Node> relations;

  /// 画布位置键原值。
  final Map<String, dynamic>? position;

  /// 样式键原值。
  final Map<String, dynamic>? style;

  @override
  String get name => 'graph.restore';

  @override
  Map<String, dynamic> get payload => <String, dynamic>{
    'nodeId': node.id,
    'relationIds': relations.map((r) => r.id).toList(),
    'hasPosition': position != null,
    'hasStyle': style != null,
  };
}

/// 恢复写结果（structure；对偶 = 再次删除——redo 链闭合）。
class RestoreNodeResult implements WriteResult {
  /// 携带恢复的节点与关系实例。
  const RestoreNodeResult({required this.affectedNodeIds, this.inverse});

  @override
  final Set<String> affectedNodeIds;

  @override
  ChangeKind get changeKind => ChangeKind.structure;

  @override
  final Command? inverse;
}

/// 在文件夹内创建节点命令（B3：Obsidian 文件夹内新建语义）。
///
/// = 新建笔记（L0，references 空）+ 新建 contain 实例（引用两端）的
/// 组合写（Handler 归 node_folder 贡献）。对偶撤销 = DeleteNodeCommand
/// （node_graph 级联：删除笔记连带删除指向它的 contain 实例——一步
/// 撤销链闭合）。
class CreateNodeInFolderCommand extends Command<CreateNodeInFolderCommand> {
  /// 携带容器与新节点字段。
  const CreateNodeInFolderCommand({
    required this.folderId,
    required this.id,
    required this.title,
    this.content,
    this.metadata,
  });

  /// 目标文件夹。
  final String folderId;

  /// 新节点 id（调用方生成，uuid）。
  final String id;

  /// 标题。
  final String title;

  /// 内容（markdown 等）。
  final String? content;

  /// 元数据。
  final Map<String, dynamic>? metadata;

  @override
  String get name => 'folder.createIn';

  @override
  Map<String, dynamic> get payload => <String, dynamic>{
    'folderId': folderId,
    'id': id,
    'title': title,
    'content': content,
  };
}

/// 文件夹内创建写结果（structure：新节点 + contain 实例 → 树重挂）。
class CreateNodeInFolderResult implements WriteResult {
  /// 携带受影响节点（新节点 + contain 实例 + 文件夹）与对偶命令。
  const CreateNodeInFolderResult({required this.affectedNodeIds, this.inverse});

  @override
  final Set<String> affectedNodeIds;

  @override
  ChangeKind get changeKind => ChangeKind.structure;

  @override
  final Command? inverse;
}

/// 连接节点命令（00 §2.2：边 = L1-node 实例）。
class ConnectNodesCommand extends Command<ConnectNodesCommand> {
  /// 携带连接两端。
  const ConnectNodesCommand({required this.from, required this.to});

  /// 起点节点。
  final String from;

  /// 终点节点。
  final String to;

  @override
  String get name => 'graph.connect';

  @override
  Map<String, dynamic> get payload => <String, dynamic>{'from': from, 'to': to};
}

/// 连接写结果（structure：新连接实例 → 画布连接线重渲染）。
class ConnectNodesResult implements WriteResult {
  /// 携带受影响节点（连接实例 + 两端）与对偶命令
  /// （P1-2：撤销 = 删除该连接实例；幂等 no-op 时 null）。
  const ConnectNodesResult({required this.affectedNodeIds, this.inverse});

  @override
  final Set<String> affectedNodeIds;

  @override
  ChangeKind get changeKind => ChangeKind.structure;

  @override
  final Command? inverse;
}
