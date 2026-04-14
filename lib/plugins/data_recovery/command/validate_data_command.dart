import '../../../core/cqrs/commands/models/command.dart';
import '../../../core/cqrs/commands/models/command_context.dart';

/// 数据验证结果
class DataValidationResult {
  /// 创建数据验证结果
  const DataValidationResult({
    required this.success,
    required this.issuesFound,
    this.message,
    this.issues = const [],
  });

  /// 是否成功
  final bool success;

  /// 发现的问题数量
  final int issuesFound;

  /// 结果消息
  final String? message;

  /// 发现的问题列表
  final List<String> issues;
}

/// 数据验证命令
///
/// 验证数据的完整性，检查目录是否存在、索引是否有效等
class ValidateDataCommand extends Command<DataValidationResult> {
  /// 创建数据验证命令
  ValidateDataCommand();

  @override
  String get name => 'ValidateData';

  @override
  String get description => '验证数据完整性';

  @override
  Future<CommandResult<DataValidationResult>> execute(CommandContext context) async {
    // 命令验证/设置逻辑（如果需要）
    // 实际验证逻辑在 Handler 中
    // 这里只是占位，实际逻辑由 Handler 处理
    throw UnimplementedError('Command should be executed through CommandBus');
  }
}
