import '../../../core/cqrs/commands/models/command.dart';
import '../../../core/cqrs/commands/models/command_context.dart';

/// 数据备份命令
///
/// 创建当前数据的完整备份
class BackupDataCommand extends Command<BackupDataResult> {
  /// 创建数据备份命令
  BackupDataCommand();

  @override
  String get name => 'BackupData';

  @override
  String get description => '创建数据备份';

  @override
  Future<CommandResult<BackupDataResult>> execute(CommandContext context) async {
    // 命令验证/设置逻辑（如果需要）
    // 实际备份逻辑在 Handler 中
    throw UnimplementedError('Command should be executed through CommandBus');
  }
}

/// 数据备份结果
class BackupDataResult {
  /// 创建数据备份结果
  const BackupDataResult({
    required this.success,
    this.backupPath,
    this.message,
  });

  /// 是否成功
  final bool success;

  /// 备份路径
  final String? backupPath;

  /// 结果消息
  final String? message;
}
