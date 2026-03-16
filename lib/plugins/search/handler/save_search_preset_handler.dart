import 'package:uuid/uuid.dart';

import '../../../../core/commands/models/command.dart';
import '../../../../core/commands/models/command_context.dart';
import '../../../../core/commands/models/command_handler.dart';
import '../command/search_commands.dart';
import '../model/search_preset_model.dart';
import '../service/search_preset_service.dart';

/// 保存搜索预设处理器
///
/// 处理保存或更新搜索预设的命令
class SaveSearchPresetHandler
    implements CommandHandler<SaveSearchPresetCommand> {
  /// 创建保存搜索预设处理器
  /// 
  /// [_service] - 搜索预设服务
  SaveSearchPresetHandler(this._service);

  final SearchPresetService _service;
  final Uuid _uuid = const Uuid();

  @override
  Future<CommandResult<SearchPreset>> execute(
    SaveSearchPresetCommand command,
    CommandContext context,
  ) async {
    try {
      // 验证预设名称
      if (command.presetName.trim().isEmpty) {
        return CommandResult.failure('预设名称不能为空');
      }

      // 创建或更新预设
      final preset = SearchPreset(
        id: command.id ?? _uuid.v4(),
        name: command.presetName,
        titleQuery: command.titleQuery,
        contentQuery: command.contentQuery,
        tags: command.tags,
        createdAt: DateTime.now(),
        lastUsed: DateTime.now(),
      );

      final savedPreset = await _service.savePreset(preset);

      return CommandResult.success(savedPreset);
    } catch (e) {
      return CommandResult.failure(e.toString());
    }
  }
}
