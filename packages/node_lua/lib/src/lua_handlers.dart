/// Lua 命令 Handler（M7 node_lua，写操作唯一执行者，01-D）：
///
/// - **LuaCommandHandler**：脚本注册的命令处理函数路由（`Commands[name]`）
///   ——Lua 函数返回约定字符串：`"affected:<id1>,<id2>;data"` 或
///   `"error:<消息>"`；默认 `"ok"` = 无受影响节点 + data 粒度。
/// - **LuaWriteHandler**：宿主写 API 执行者——create/update/delete 落盘，
///   变更引用时环校验（00 §2.3），返回 WriteResult（写后通知）。
library;

import 'package:appframe/appframe.dart';
import 'package:core/core.dart';
import 'package:core_data/core_data.dart';

import 'lua_commands.dart';
import 'lua_engine.dart';

/// 脚本命令 Handler（Commands 表 → Lua 函数）。
class LuaCommandHandler extends CommandHandler<LuaCommand, LuaCommandResult> {
  /// 注入引擎解析器（**延迟**——registerExtensions 阶段引擎未初始化，
  /// plugon 顺序：registerServices → registerExtensions → onLoad）。
  LuaCommandHandler({required LuaEngine? Function() engineProvider})
    : _engineProvider = engineProvider;

  final LuaEngine? Function() _engineProvider;

  /// 脚本命令路由表（name → 存在性；执行经 `Commands[name](payload)`）。
  /// 由 LuaPlugin 在脚本加载时填充。
  final Set<String> commandNames = <String>{};

  @override
  Type get commandType => LuaCommand;

  @override
  Future<LuaCommandResult> handle(LuaCommand command) async {
    final engine = _engineProvider();
    if (engine == null) {
      throw StateError('Lua 引擎不可用（脚本命令不可执行）');
    }
    if (!commandNames.contains(command.commandName)) {
      throw StateError('未注册的 Lua 命令: ${command.commandName}');
    }
    final result = engine.evalBound(
      'return Commands[${LuaEngine.toLuaLiteral(command.commandName)}]'
      '(${LuaEngine.toLuaLiteral(command.payload)})',
    );
    return parseLuaCommandResult(result);
  }
}

/// 解析 Lua 命令返回值（约定字符串，M7 文档化格式）。
///
/// - `"ok"` → 空受影响 + data 粒度
/// - `"affected:<id1>,<id2>;<kind>"` → 受影响节点 + 粒度（structure/data/ui）
/// - `"error:<消息>"` → 抛 StateError（用户可读文案）
/// - 非字符串（Lua 返回布尔/数字）→ 兜底 "ok"
LuaCommandResult parseLuaCommandResult(dynamic result) {
  if (result is! String) {
    return const LuaCommandResult(
      affectedNodeIds: <String>{},
      changeKind: ChangeKind.data,
    );
  }
  if (result.startsWith('error:')) {
    throw StateError(result.substring('error:'.length));
  }
  if (!result.startsWith('affected:')) {
    return const LuaCommandResult(
      affectedNodeIds: <String>{},
      changeKind: ChangeKind.data,
    );
  }
  final body = result.substring('affected:'.length);
  final parts = body.split(';');
  final ids = parts[0].split(',').where((s) => s.isNotEmpty).toSet();
  final kind = parts.length > 1 ? parts[1] : 'data';
  return LuaCommandResult(
    affectedNodeIds: ids,
    changeKind: switch (kind) {
      'structure' => ChangeKind.structure,
      'ui' => ChangeKind.ui,
      _ => ChangeKind.data,
    },
  );
}

/// 宿主写 Handler（Lua `host.node_*` 的 Dart 执行者）。
class LuaWriteHandler extends CommandHandler<LuaWriteCommand, LuaWriteResult> {
  /// 注入结构存储与环校验器（延迟解析）。
  LuaWriteHandler({
    required Graph Function() graphProvider,
    AcyclicChecker? checker,
  }) : _graphProvider = graphProvider,
       _checker = checker ?? const AcyclicChecker();

  final Graph Function() _graphProvider;
  final AcyclicChecker _checker;

  @override
  Type get commandType => LuaWriteCommand;

  @override
  Future<LuaWriteResult> handle(LuaWriteCommand command) async =>
      applySync(command);

  /// **同步执行**（M7）：宿主 API 的 C 回调无法 await——写逻辑本身
  /// 无异步（Graph 同步落盘），同步入口供 LuaPlugin 宿主 API 直接
  /// 调用（写后通知由调用方经 CommandBus.notifyListeners 广播）。
  LuaWriteResult applySync(LuaWriteCommand command) {
    final graph = _graphProvider();
    switch (command.action) {
      case 'create':
        return _create(graph, command);
      case 'update':
        return _update(graph, command);
      case 'delete':
        return _delete(graph, command);
      default:
        throw StateError('未知 Lua 写动作: ${command.action}');
    }
  }

  LuaWriteResult _create(Graph graph, LuaWriteCommand command) {
    final id = command.nodeId ?? 'lua-${DateTime.now().microsecondsSinceEpoch}';
    if (graph.get(id) != null) {
      throw StateError('节点已存在: $id');
    }
    final references = command.references ?? const <String, String>{};
    _checkCycle(id, references, graph);
    final now = DateTime.now();
    graph.save(
      StoredNode(
        id: id,
        title: command.title ?? id,
        content: command.content,
        references: references,
        metadata: command.metadata ?? const <String, dynamic>{},
        createdAt: now,
        updatedAt: now,
      ),
    );
    return LuaWriteResult(affectedNodeIds: <String>{id});
  }

  LuaWriteResult _update(Graph graph, LuaWriteCommand command) {
    final id = command.nodeId;
    if (id == null) {
      throw StateError('update 需要 nodeId');
    }
    final node = graph.get(id);
    if (node == null) {
      throw StateError('节点不存在: $id');
    }
    final references = command.references ?? node.references;
    _checkCycle(id, references, graph);
    graph.save(
      node.copyWith(
        title: command.title,
        content: command.content,
        references: command.references,
        metadata: command.metadata,
      ),
    );
    return LuaWriteResult(affectedNodeIds: <String>{id});
  }

  /// Lua 删除为**裸删**（audit-node_lua #5，已记录）：不级联清理反向引用，
  /// 与 node_graph DeleteNodeHandler 的级联语义不同——脚本删节点后引用方
  /// （文件夹成员/连接边）引用残留，脚本作者需自行处理引用残留
  /// （先更新/删除引用方，或接受悬空引用）；M7+ 收敛为委托级联语义。
  LuaWriteResult _delete(Graph graph, LuaWriteCommand command) {
    final id = command.nodeId;
    if (id == null) {
      throw StateError('delete 需要 nodeId');
    }
    if (graph.get(id) == null) {
      throw StateError('节点不存在: $id');
    }
    graph.delete(id);
    return LuaWriteResult(affectedNodeIds: <String>{id});
  }

  /// 环校验（引用变更时，00 §2.3 执行点 = 写命令 Handler）。
  void _checkCycle(String nodeId, Map<String, String> references, Graph graph) {
    final cycle = _checker.check(
      affectedRefs: <String, Set<String>>{nodeId: references.values.toSet()},
      graph: graph,
    );
    if (cycle != null) {
      throw CycleError(cycle);
    }
  }
}
