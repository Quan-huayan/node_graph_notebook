import '../../../core/commands/models/command.dart';
import '../../../core/commands/models/command_context.dart';
import '../models/lua_script.dart';

/// 创建Lua脚本命令
class CreateLuaScriptCommand extends Command<LuaScript> {
  /// 构造函数
  CreateLuaScriptCommand({
    required this.script,
  });

  /// 要创建的脚本
  final LuaScript script;

  @override
  Future<CommandResult<LuaScript>> execute(CommandContext context) async {
    throw UnimplementedError('CreateLuaScriptCommand.execute 应该在 Handler 中实现');
  }

  @override
  String get name => 'CreateLuaScript';

  @override
  String get description => '创建Lua脚本: ${script.name}';

  @override
  bool get isUndoable => false;
}
