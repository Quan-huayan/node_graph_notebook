import '../../../core/cqrs/commands/models/command.dart';
import '../../../core/cqrs/commands/models/command_context.dart';
import '../../../core/cqrs/commands/models/command_handler.dart';
import '../command/search_commands.dart';
import '../service/search_preset_service.dart';

/// 删除搜索预设处理器
///
/// 处理删除搜索预设的命令
class DeleteSearchPresetHandler
    implements CommandHandler<DeleteSearchPresetCommand> {
  /// 创建删除搜索预设处理器
  /// 
  /// [_service] - 搜索预设服务
  DeleteSearchPresetHandler(this._service);

  final SearchPresetService _service;

  @override
  Future<CommandResult<void>> execute(
    DeleteSearchPresetCommand command,
    CommandContext context,
  ) async {
    try {
      // 验证预设 ID
      if (command.id.trim().isEmpty) {
        return CommandResult.failure('预设 ID 不能为空');
      }

      // 检查预设是否存在
      final existingPreset = await _service.getPreset(command.id);
      if (existingPreset == null) {
        return CommandResult.failure('预设不存在: ${command.id}');
      }

      // 删除预设
      await _service.deletePreset(command.id);

      return CommandResult.success(null);
    } catch (e) {
      return CommandResult.failure(e.toString());
    }
  }
}
