import '../../../core/cqrs/commands/models/command.dart';
import '../../../core/cqrs/commands/models/command_context.dart';
import '../models/lua_script.dart';

/// 更新Lua脚本命令
class UpdateLuaScriptCommand extends Command<LuaScript> {
  /// 构造函数
  UpdateLuaScriptCommand({
    required this.script,
  });

  /// 要更新的脚本
  final LuaScript script;

  @override
  Future<CommandResult<LuaScript>> execute(CommandContext context) async {
    throw UnimplementedError('UpdateLuaScriptCommand.execute 应该在 Handler 中实现');
  }

  @override
  String get name => 'UpdateLuaScript';

  @override
  String get description => '更新Lua脚本: ${script.name}';

  @override
  bool get isUndoable => false;
}
