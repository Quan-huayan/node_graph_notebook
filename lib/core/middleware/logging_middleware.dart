import 'dart:developer' as developer;

import '../cqrs/commands/models/command.dart';
import '../cqrs/commands/models/command_context.dart';
import '../cqrs/commands/models/middleware.dart';
import '../utils/logger.dart';

/// 日志中间件
///
/// 记录命令执行的生命周期：
/// - 命令开始
/// - 命令成功
/// - 命令失败
/// - 命令撤销
class LoggingMiddleware extends CommandMiddlewareBase {
  /// 创建日志中间件
  ///
  /// [logLevel] 日志级别，默认 info
  /// [includeTimestamp] 是否包含时间戳，默认 true
  /// [includeDuration] 是否包含执行时长，默认 true
  LoggingMiddleware({
    LogLevel logLevel = LogLevel.info,
    bool includeTimestamp = true,
    bool includeDuration = true,
  }) : _logLevel = logLevel,
       _includeTimestamp = includeTimestamp,
       _includeDuration = includeDuration;

  /// 日志级别
  final LogLevel _logLevel;

  /// 是否包含时间戳
  final bool _includeTimestamp;

  /// 是否包含执行时长
  final bool _includeDuration;

  /// 命令开始时间缓存
  final Map<Command, DateTime> _startTimes = {};

  @override
  Future<void> processBefore(Command command, CommandContext context) async {
    _startTimes[command] = DateTime.now();

    _log(LogLevel.info, '↗️ 执行命令: ${command.name}', command: command);
  }

  @override
  Future<void> processAfter(
    Command command,
    CommandContext context,
    CommandResult result,
  ) async {
    final startTime = _startTimes[command];
    final duration = startTime != null && _includeDuration
        ? DateTime.now().difference(startTime)
        : null;

    if (result.isSuccess) {
      _log(
        LogLevel.info,
        '✓ 命令成功: ${command.name}'
        '${duration != null ? ' (${duration.inMilliseconds}ms)' : ''}',
        command: command,
      );
    } else {
      _log(
        LogLevel.error,
        '✗ 命令失败: ${command.name} - ${result.error}'
        '${duration != null ? ' (${duration.inMilliseconds}ms)' : ''}',
        command: command,
      );
    }

    _startTimes.remove(command);
  }

  /// 记录日志
  void _log(LogLevel level, String message, {required Command command}) {
    if (level.index < _logLevel.index) {
      return; // 日志级别不够，不记录
    }

    final timestamp = _includeTimestamp ? '[${DateTime.now()}] ' : '';
    final levelStr = '[${level.name.toUpperCase()}] ';
    final commandInfo = ' - ${command.description}';

    final logMessage = '$timestamp$levelStr$message$commandInfo';

    // 使用 Dart 的 log 函数
    developer.log(logMessage, level: level.value, name: 'CommandBus');
  }
}


