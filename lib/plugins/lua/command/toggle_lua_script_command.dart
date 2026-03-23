import '../../../core/commands/models/command.dart';
import '../../../core/commands/models/command_context.dart';

/// 切换Lua脚本启用状态命令
class ToggleLuaScriptCommand extends Command<void> {
  /// 构造函数
  ToggleLuaScriptCommand({
    required this.scriptId,
    required this.enabled,
  });

  /// 脚本ID
  final String scriptId;

  /// 目标启用状态
  final bool enabled;

  @override
  Future<CommandResult<void>> execute(CommandContext context) async {
    throw UnimplementedError('ToggleLuaScriptCommand.execute 应该在 Handler 中实现');
  }

  @override
  String get name => 'ToggleLuaScript';

  @override
  String get description => '切换Lua脚本状态: $scriptId -> $enabled';

  @override
  bool get isUndoable => false;
}
