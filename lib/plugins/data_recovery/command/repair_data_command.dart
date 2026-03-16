import '../../../../core/commands/models/command.dart';
import '../../../../core/commands/models/command_context.dart';

/// 数据修复命令
///
/// 修复发现的数据问题，包括重建目录、重建索引等
class RepairDataCommand extends Command<DataRepairResult> {
  /// 创建数据修复命令
  ///
  /// [createBackup] - 是否在修复前创建备份
  RepairDataCommand({
    this.createBackup = true,
  });

  /// 是否在修复前创建备份
  final bool createBackup;

  @override
  String get name => 'RepairData';

  @override
  String get description => '修复数据问题（备份: $createBackup）';

  @override
  Future<CommandResult<DataRepairResult>> execute(CommandContext context) async {
    // 命令验证/设置逻辑（如果需要）
    // 实际修复逻辑在 Handler 中
    throw UnimplementedError('Command should be executed through CommandBus');
  }
}

/// 数据修复结果
class DataRepairResult {
  /// 创建数据修复结果
  const DataRepairResult({
    required this.success,
    required this.repairedIssues,
    required this.issuesFound,
    this.message,
    this.backupPath,
  });

  /// 是否成功
  final bool success;

  /// 修复的问题数量
  final int repairedIssues;

  /// 发现的问题数量
  final int issuesFound;

  /// 结果消息
  final String? message;

  /// 备份路径（如果创建了备份）
  final String? backupPath;
}
