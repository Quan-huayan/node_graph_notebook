import '../../../core/cqrs/commands/models/command.dart';
import '../../../core/cqrs/commands/models/command_context.dart';
import '../models/lua_execution_result.dart';

/// 执行Lua脚本命令
///
/// 执行指定的Lua脚本文件，支持上下文变量传递
class ExecuteLuaScriptCommand extends Command<LuaExecutionResult> {
  /// 构造函数
  ExecuteLuaScriptCommand({
    required this.scriptPath,
    this.scriptContent,
    this.context,
  });

  /// 脚本文件路径
  final String scriptPath;

  /// 脚本内容（如果直接执行代码而不是文件）
  final String? scriptContent;

  /// 执行上下文变量
  final Map<String, dynamic>? context;

  @override
  Future<CommandResult<LuaExecutionResult>> execute(CommandContext context) async {
    // 执行逻辑在Handler中实现
    throw UnimplementedError('ExecuteLuaScriptCommand.execute 应该在 Handler 中实现');
  }

  @override
  String get name => 'ExecuteLuaScript';

  @override
  String get description => '执行Lua脚本: $scriptPath';

  @override
  bool get isUndoable => false; // 脚本执行不支持撤销
}
