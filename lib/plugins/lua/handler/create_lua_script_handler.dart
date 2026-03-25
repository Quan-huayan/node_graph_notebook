import '../../../core/commands/models/command.dart';
import '../../../core/commands/models/command_context.dart';
import '../../../core/commands/models/command_handler.dart';
import '../command/create_lua_script_command.dart';
import '../models/lua_script.dart';
import '../service/lua_script_service.dart';

/// 创建Lua脚本命令处理器
class CreateLuaScriptHandler implements CommandHandler<CreateLuaScriptCommand> {
  /// 构造函数
  CreateLuaScriptHandler({
    required this.scriptService,
  });

  /// Lua脚本服务
  final LuaScriptService scriptService;

  @override
  Future<CommandResult<LuaScript>> execute(
    CreateLuaScriptCommand command,
    CommandContext context,
  ) async {
    try {
      // 保存脚本
      await scriptService.saveScript(command.script);

      return CommandResult.success(command.script);
    } catch (e) {
      return CommandResult.failureTyped<LuaScript>(
        '创建脚本失败: $e',
      );
    }
  }
}
