import '../../../core/cqrs/commands/models/command.dart';
import '../../../core/cqrs/commands/models/command_context.dart';

/// 删除Lua脚本命令
class DeleteLuaScriptCommand extends Command<void> {
  /// 构造函数
  DeleteLuaScriptCommand({
    required this.scriptId,
  });

  /// 要删除的脚本ID
  final String scriptId;

  @override
  Future<CommandResult<void>> execute(CommandContext context) async {
    throw UnimplementedError('DeleteLuaScriptCommand.execute 应该在 Handler 中实现');
  }

  @override
  String get name => 'DeleteLuaScript';

  @override
  String get description => '删除Lua脚本: $scriptId';

  @override
  bool get isUndoable => false;
}
