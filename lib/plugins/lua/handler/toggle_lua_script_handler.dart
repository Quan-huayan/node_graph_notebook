import '../../../core/commands/models/command.dart';
import '../../../core/commands/models/command_context.dart';
import '../../../core/commands/models/command_handler.dart';
import '../command/toggle_lua_script_command.dart';
import '../service/lua_script_service.dart';

/// 切换Lua脚本启用状态命令处理器
class ToggleLuaScriptHandler implements CommandHandler<ToggleLuaScriptCommand> {
  /// 构造函数
  ToggleLuaScriptHandler({
    required this.scriptService,
  });

  /// Lua脚本服务
  final LuaScriptService scriptService;

  @override
  Future<CommandResult<void>> execute(
    ToggleLuaScriptCommand command,
    CommandContext context,
  ) async {
    try {
      // 切换脚本启用状态
      if (command.enabled) {
        await scriptService.enableScript(command.scriptId);
      } else {
        await scriptService.disableScript(command.scriptId);
      }

      return CommandResult.success(null);
    } catch (e) {
      return CommandResult.failureTyped<void>(
        '切换脚本状态失败: $e',
      );
    }
  }
}
