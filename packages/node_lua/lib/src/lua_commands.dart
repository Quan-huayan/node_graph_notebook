/// Lua 命令（M7 node_lua，纯 DTO + Handler，03 §四）：
///
/// - **LuaCommand**：路由到脚本注册的命令处理函数（`Commands[name]`）
/// - **LuaWriteCommand**：宿主写 API 的 Dart 侧执行者——Lua 脚本的
///   `host.node_create/update/delete` 经单 C 回调转成此命令 dispatch，
///   **写操作唯一执行者仍是 Dart Handler**（00 不变量 4.4-1 的 Lua 侧落地）。
library;

import 'package:core/core.dart';

/// 脚本命令（name → Lua `Commands[name](payload)`）。
class LuaCommand extends Command<LuaCommand> {
  /// 携带命令名与负载（payload = Lua 表 → Dart Map）。
  const LuaCommand({required this.commandName, required this.payloadValue});

  /// 命令名（脚本 Commands 表的键）。
  final String commandName;

  /// 负载（脚本函数参数）。
  final Map<String, dynamic> payloadValue;

  @override
  String get name => 'lua.$commandName';

  @override
  Map<String, dynamic> get payload => payloadValue;
}

/// 脚本命令写结果。
class LuaCommandResult implements WriteResult {
  /// 携带受影响节点与变更粒度。
  const LuaCommandResult({
    required this.affectedNodeIds,
    required this.changeKind,
  });

  @override
  final Set<String> affectedNodeIds;

  @override
  final ChangeKind changeKind;

  @override
  Command? get inverse => null; // M7 显式不可撤销（撤销契约 03 §四）。
}

/// 宿主写命令（Lua 写 API → Dart Handler）。
class LuaWriteCommand extends Command<LuaWriteCommand> {
  /// 写动作。
  const LuaWriteCommand({
    required this.action,
    this.nodeId,
    this.title,
    this.content,
    this.references,
    this.metadata,
  });

  /// 动作：create | update | delete。
  final String action;

  /// 目标节点 id（update/delete 必填；create 可选）。
  final String? nodeId;

  /// 新标题（create/update）。
  final String? title;

  /// 新内容（create/update）。
  final String? content;

  /// 新引用（create/update——变更引用时环校验）。
  final Map<String, String>? references;

  /// 新元数据（create/update）。
  final Map<String, dynamic>? metadata;

  @override
  String get name => 'lua.host.$action';

  @override
  Map<String, dynamic> get payload => <String, dynamic>{
    'action': action,
    'nodeId': nodeId,
    'title': title,
    'content': content,
    'references': references,
    'metadata': metadata,
  };
}

/// 宿主写结果。
class LuaWriteResult implements WriteResult {
  /// 携带受影响节点。
  const LuaWriteResult({required this.affectedNodeIds});

  @override
  final Set<String> affectedNodeIds;

  @override
  ChangeKind get changeKind => ChangeKind.structure;

  @override
  Command? get inverse => null;
}
