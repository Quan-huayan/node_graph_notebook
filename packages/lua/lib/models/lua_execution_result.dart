import 'package:json_annotation/json_annotation.dart';

part 'lua_execution_result.g.dart';

/// Lua脚本执行结果
///
/// 表示Lua脚本的执行结果，包含输出、错误和返回值
/// 支持详细的错误信息和调试上下文
@JsonSerializable()
class LuaExecutionResult {
  /// 构造函数
  const LuaExecutionResult({
    required this.success,
    this.returnValue,
    this.output = const [],
    this.error,
    this.executionTime,
    this.errorLine,
    this.errorContext,
    this.stackTrace = const [],
  });

  /// 从JSON创建
  factory LuaExecutionResult.fromJson(Map<String, dynamic> json) =>
      _$LuaExecutionResultFromJson(json);

  /// 创建成功结果
  factory LuaExecutionResult.success({
    dynamic returnValue,
    List<String> output = const [],
    Duration? executionTime,
  }) => LuaExecutionResult(
      success: true,
      returnValue: returnValue,
      output: output,
      executionTime: executionTime,
    );

  /// 创建失败结果
  factory LuaExecutionResult.failure({
    required String error,
    List<String> output = const [],
    Duration? executionTime,
    int? errorLine,
    String? errorContext,
    List<String> stackTrace = const [],
  }) => LuaExecutionResult(
      success: false,
      error: error,
      output: output,
      executionTime: executionTime,
      errorLine: errorLine,
      errorContext: errorContext,
      stackTrace: stackTrace,
    );

  /// 是否成功执行
  final bool success;

  /// 返回值
  final dynamic returnValue;

  /// 输出日志
  final List<String> output;

  /// 错误信息
  final String? error;

  /// 执行时间
  final Duration? executionTime;

  /// 错误行号（用于调试）
  final int? errorLine;

  /// 错误上下文（错误发生时的代码片段）
  final String? errorContext;

  /// 堆栈跟踪
  final List<String> stackTrace;

  /// 转换为JSON
  Map<String, dynamic> toJson() => _$LuaExecutionResultToJson(this);

  /// 获取完整输出文本
  String get outputText => output.join('\n');

  /// 获取格式化的错误信息
  String get formattedError {
    if (error == null) return '';

    final buffer = StringBuffer();
    buffer.writeln('❌ 错误: $error');

    if (errorLine != null) {
      buffer.writeln('📍 行号: $errorLine');
    }

    if (errorContext != null && errorContext!.isNotEmpty) {
      buffer.writeln('🔍 上下文:');
      buffer.writeln(errorContext);
    }

    if (stackTrace.isNotEmpty) {
      buffer.writeln('📚 堆栈:');
      for (final frame in stackTrace) {
        buffer.writeln('  $frame');
      }
    }

    if (executionTime != null) {
      buffer.writeln('⏱️  执行时间: ${executionTime!.inMilliseconds}ms');
    }

    return buffer.toString().trim();
  }

  /// 复制并更新部分字段
  LuaExecutionResult copyWith({
    bool? success,
    dynamic returnValue,
    List<String>? output,
    String? error,
    Duration? executionTime,
    int? errorLine,
    String? errorContext,
    List<String>? stackTrace,
  }) => LuaExecutionResult(
      success: success ?? this.success,
      returnValue: returnValue ?? this.returnValue,
      output: output ?? this.output,
      error: error ?? this.error,
      executionTime: executionTime ?? this.executionTime,
      errorLine: errorLine ?? this.errorLine,
      errorContext: errorContext ?? this.errorContext,
      stackTrace: stackTrace ?? this.stackTrace,
    );

  @override
  String toString() {
    if (success) {
      return '✅ LuaExecutionResult(success: true, '
          'returnValue: $returnValue, '
          'outputLines: ${output.length}, '
          'executionTime: $executionTime)';
    } else {
      return '❌ LuaExecutionResult(success: false, '
          'error: $error, '
          'errorLine: $errorLine, '
          'outputLines: ${output.length})';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is LuaExecutionResult &&
        other.success == success &&
        other.returnValue == returnValue &&
        other.error == error;
  }

  @override
  int get hashCode => success.hashCode ^ returnValue.hashCode ^ error.hashCode;
}
