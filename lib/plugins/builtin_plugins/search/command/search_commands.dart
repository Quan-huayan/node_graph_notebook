import '../../../../core/commands/models/command.dart';
import '../../../../core/commands/models/command_context.dart';
import '../model/search_preset_model.dart';

/// 保存搜索预设命令
///
/// 用于保存或更新搜索预设
class SaveSearchPresetCommand extends Command<SearchPreset> {
  /// 创建保存搜索预设命令
  /// 
  /// [presetName] - 预设名称
  /// [id] - 预设 ID（可选，用于更新现有预设）
  /// [titleQuery] - 标题查询
  /// [contentQuery] - 内容查询
  /// [tags] - 标签
  SaveSearchPresetCommand({
    required this.presetName,
    this.id,
    this.titleQuery,
    this.contentQuery,
    this.tags,
  });

  /// 预设 ID（可选，用于更新现有预设）
  final String? id;

  /// 预设名称
  final String presetName;

  /// 标题查询
  final String? titleQuery;

  /// 内容查询
  final String? contentQuery;

  /// 标签
  final List<String>? tags;

  @override
  String get name => 'SaveSearchPreset';

  @override
  String get description => '保存搜索预设: $presetName';

  @override
  Future<CommandResult<SearchPreset>> execute(CommandContext context) async {
    // 由 SaveSearchPresetHandler 处理
    throw UnimplementedError('命令执行由处理器处理');
  }

  @override
  bool get isUndoable => false;
}

/// 删除搜索预设命令
///
/// 用于删除搜索预设
class DeleteSearchPresetCommand extends Command<void> {
  /// 创建删除搜索预设命令
  /// 
  /// [id] - 预设 ID
  DeleteSearchPresetCommand({required this.id});

  /// 预设 ID
  final String id;

  @override
  String get name => 'DeleteSearchPreset';

  @override
  String get description => '删除搜索预设: $id';

  @override
  Future<CommandResult<void>> execute(CommandContext context) async {
    // 由 DeleteSearchPresetHandler 处理
    throw UnimplementedError('命令执行由处理器处理');
  }

  @override
  bool get isUndoable => false;
}
