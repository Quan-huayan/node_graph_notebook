import '../../../core/commands/models/command.dart';
import '../../../core/commands/models/command_context.dart';
import '../../../core/commands/models/command_handler.dart';
import '../command/update_lua_script_command.dart';
import '../service/lua_script_service.dart';
import '../models/lua_script.dart';

/// 更新Lua脚本命令处理器
class UpdateLuaScriptHandler implements CommandHandler<UpdateLuaScriptCommand> {
  /// 构造函数
  UpdateLuaScriptHandler({
    required this.scriptService,
  });

  /// Lua脚本服务
  final LuaScriptService scriptService;

  @override
  Future<CommandResult<LuaScript>> execute(
    UpdateLuaScriptCommand command,
    CommandContext context,
  ) async {
    try {
      // 保存脚本（更新）
      await scriptService.saveScript(command.script);

      return CommandResult.success(command.script);
    } catch (e) {
      return CommandResult.failureTyped<LuaScript>(
        '更新脚本失败: $e',
      );
    }
  }
}
