import 'command_context.dart';

/// 命令基类
///
/// 所有命令必须继承此类并实现 [execute] 方法。
/// 可选实现 [undo] 方法以支持撤销操作。
abstract class Command<T> {
  /// 执行命令
  ///
  /// [context] 提供命令执行所需的依赖和服务
  /// 返回命令执行结果，包含数据或错误信息
  Future<CommandResult<T>> execute(CommandContext context);

  /// 撤销命令（可选）
  ///
  /// 默认实现抛出 [UnsupportedError]，表示该命令不可撤销。
  /// 子类可以重写此方法以实现撤销逻辑。
  Future<void> undo(CommandContext context) {
    throw UnsupportedError('$name 命令不支持撤销操作');
  }

  /// 命令名称
  ///
  /// 用于日志记录和调试，应该简明扼要地描述命令类型
  String get name;

  /// 命令描述
  ///
  /// 提供更详细的命令说明，包含关键参数信息
  String get description;

  /// 是否可撤销
  ///
  /// 返回 true 表示该命令支持撤销操作
  /// 默认为 true，子类可以重写为 false
  bool get isUndoable => true;
}

/// 命令执行结果
///
/// 封装命令执行的结果，支持成功和失败两种状态
class CommandResult<T> {
  /// 私有构造函数
  CommandResult._({required this.isSuccess, this.data, this.error});

  /// 创建成功结果
  factory CommandResult.success([T? data]) => CommandResult._(isSuccess: true, data: data);

  /// 创建失败结果
  factory CommandResult.failure(String error) => CommandResult._(isSuccess: false, error: error);

  /// 是否成功
  final bool isSuccess;

  /// 结果数据（成功时可用）
  final T? data;

  /// 错误信息（失败时可用）
  final String? error;

  /// 创建带类型的失败结果（用于类型转换）
  ///
  /// 当需要在错误处理中转换结果类型时使用
  static CommandResult<T> failureTyped<T>(String error) => CommandResult<T>._(isSuccess: false, error: error);

  /// 获取数据或抛出异常
  ///
  /// 如果结果成功，返回数据；否则抛出包含错误信息的异常
  T get dataOrThrow {
    if (isSuccess) {
      return data as T;
    }
    throw CommandExecutionException(error ?? '命令执行失败');
  }

  /// 映射结果数据
  ///
  /// 如果结果成功，使用 [mapper] 函数转换数据类型
  /// 返回新的 [CommandResult] 对象
  CommandResult<R> map<R>(R Function(T data) mapper) {
    if (isSuccess) {
      try {
        return CommandResult.success(mapper(data as T));
      } catch (e) {
        return CommandResult.failureTyped<R>(e.toString());
      }
    } else {
      return CommandResult.failureTyped<R>(error!);
    }
  }
}

/// 命令执行异常
///
/// 当命令执行失败时抛出
class CommandExecutionException implements Exception {
  /// 创建一个命令执行异常
  ///
  /// [message] - 错误信息
  CommandExecutionException(this.message);

  /// 错误信息
  final String message;

  @override
  String toString() => 'CommandExecutionException: $message';
}
