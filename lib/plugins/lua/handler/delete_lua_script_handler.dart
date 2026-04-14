import '../../../core/cqrs/commands/models/command.dart';
import '../../../core/cqrs/commands/models/command_context.dart';
import '../../../core/cqrs/commands/models/command_handler.dart';
import '../command/delete_lua_script_command.dart';
import '../service/lua_script_service.dart';

/// 删除Lua脚本命令处理器
class DeleteLuaScriptHandler implements CommandHandler<DeleteLuaScriptCommand> {
  /// 构造函数
  DeleteLuaScriptHandler({
    required this.scriptService,
  });

  /// Lua脚本服务
  final LuaScriptService scriptService;

  @override
  Future<CommandResult<void>> execute(
    DeleteLuaScriptCommand command,
    CommandContext context,
  ) async {
    try {
      // 删除脚本
      await scriptService.deleteScript(command.scriptId);

      return CommandResult.success(null);
    } catch (e) {
      return CommandResult.failureTyped<void>(
        '删除脚本失败: $e',
      );
    }
  }
}
