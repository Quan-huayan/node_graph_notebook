/// Lua错误处理器
///
/// 提供增强的错误处理、上下文提取和调试信息
library;

import 'package:flutter/foundation.dart';
import '../models/lua_execution_result.dart';

/// Lua错误类型
enum LuaErrorType {
  /// 语法错误
  syntax,

  /// 运行时错误
  runtime,

  /// 内存错误
  memory,

  /// 栈溢出
  stackOverflow,

  /// 安全违规
  security,

  /// 超时
  timeout,

  /// 未知错误
  unknown,
}

/// Lua错误信息
class LuaErrorInfo {
  /// 构造函数
  const LuaErrorInfo({
    required this.type,
    required this.message,
    this.line,
    this.column,
    this.context,
    this.suggestion,
  });

  /// 创建语法错误
  factory LuaErrorInfo.syntax({
    required String message,
    int? line,
    int? column,
    String? context,
  }) => LuaErrorInfo(
      type: LuaErrorType.syntax,
      message: message,
      line: line,
      column: column,
      context: context,
      suggestion: _getSyntaxErrorSuggestion(message),
    );

  /// 创建运行时错误
  factory LuaErrorInfo.runtime({
    required String message,
    int? line,
    String? context,
  }) => LuaErrorInfo(
      type: LuaErrorType.runtime,
      message: message,
      line: line,
      context: context,
      suggestion: _getRuntimeErrorSuggestion(message),
    );

  /// 创建安全错误
  factory LuaErrorInfo.security({
    required String message,
    String? suggestion,
  }) => LuaErrorInfo(
      type: LuaErrorType.security,
      message: message,
      suggestion: suggestion ?? '请检查脚本是否包含危险操作',
    );

  /// 创建超时错误
  factory LuaErrorInfo.timeout({
    required Duration timeout,
  }) => LuaErrorInfo(
      type: LuaErrorType.timeout,
      message: '脚本执行超时 (${timeout.inSeconds}秒)',
      suggestion: '优化脚本性能或增加超时时间',
    );

  /// 错误类型
  final LuaErrorType type;

  /// 错误消息
  final String message;

  /// 错误行号
  final int? line;

  /// 错误列号
  final int? column;

  /// 错误上下文（代码片段）
  final String? context;

  /// 修复建议
  final String? suggestion;

  /// 获取语法错误建议
  static String? _getSyntaxErrorSuggestion(String message) {
    if (message.contains('unexpected symbol')) {
      return '检查符号是否正确，如括号、引号是否配对';
    }
    if (message.contains("'end' expected")) {
      return '检查 if/for/while 函数块是否正确闭合';
    }
    if (message.contains('syntax error near')) {
      return '检查该位置附近的代码语法';
    }
    return '请检查代码语法是否正确';
  }

  /// 获取运行时错误建议
  static String? _getRuntimeErrorSuggestion(String message) {
    if (message.contains('attempt to call a nil value')) {
      return '函数未定义，请检查函数名是否正确';
    }
    if (message.contains('attempt to index a nil value')) {
      return '变量为nil，请检查变量是否已初始化';
    }
    if (message.contains('arithmetic on')) {
      return '数值运算错误，请检查操作数类型';
    }
    return '请检查代码逻辑和数据类型';
  }

  /// 转换为字符串
  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('[${_getTypeName()}] $message');

    if (line != null) {
      buffer.write(' (行 $line');
      if (column != null) {
        buffer.write(', 列 $column');
      }
      buffer.write(')');
    }

    return buffer.toString();
  }

  /// 获取类型名称
  String _getTypeName() {
    switch (type) {
      case LuaErrorType.syntax:
        return '语法错误';
      case LuaErrorType.runtime:
        return '运行时错误';
      case LuaErrorType.memory:
        return '内存错误';
      case LuaErrorType.stackOverflow:
        return '栈溢出';
      case LuaErrorType.security:
        return '安全错误';
      case LuaErrorType.timeout:
        return '超时错误';
      case LuaErrorType.unknown:
        return '未知错误';
    }
  }

  /// 转换为详细的错误信息
  String toDetailedString() {
    final buffer = StringBuffer()
    ..writeln('╔════════════════════════════════════════')
    ..writeln('║ Lua 错误详情')
    ..writeln('╠════════════════════════════════════════')
    ..writeln('║ 类型: ${_getTypeName()}')
    ..writeln('║ 消息: $message');

    if (line != null) {
      buffer.writeln('║ 位置: 第$line行');
      if (column != null) {
        buffer.writeln('║       第$column列');
      }
    }

    if (suggestion != null) {
      buffer..writeln('║ ')
      ..writeln('║ 💡 建议: $suggestion');
    }

    if (context != null && context!.isNotEmpty) {
      buffer..writeln('║ ')
      ..writeln('║ 上下文:');
      final lines = context!.split('\n');
      for (final line in lines) {
        buffer.writeln('║   $line');
      }
    }

    buffer.writeln('╚════════════════════════════════════════');
    return buffer.toString();
  }
}

/// Lua错误处理器
///
/// 解析Lua错误信息，提供增强的错误上下文和修复建议
class LuaErrorHandler {
  /// 解析Lua错误消息
  ///
  /// 尝试从Lua错误消息中提取结构化的错误信息
  static LuaErrorInfo parseError(String errorMessage) {
    // 检测错误类型
    if (_isSyntaxError(errorMessage)) {
      return _parseSyntaxError(errorMessage);
    }

    if (_isSecurityError(errorMessage)) {
      return LuaErrorInfo.security(
        message: errorMessage,
        suggestion: '脚本包含不允许的操作',
      );
    }

    if (_isTimeoutError(errorMessage)) {
      return LuaErrorInfo.timeout(
        timeout: const Duration(seconds: 5),
      );
    }

    // 默认为运行时错误
    return _parseRuntimeError(errorMessage);
  }

  /// 从错误信息中提取行号
  static int? extractLineNumber(String errorMessage) {
    // 尝试多种格式
    // 格式1: "string "script":123: error message"
    final match1 = RegExp(r'(\d+):').firstMatch(errorMessage);
    if (match1 != null) {
      return int.tryParse(match1.group(1)!);
    }

    // 格式2: "[string "script"]:123: error message"
    final match2 = RegExp(r':(\d+):').firstMatch(errorMessage);
    if (match2 != null) {
      return int.tryParse(match2.group(1)!);
    }

    return null;
  }

  /// 从脚本中提取错误上下文
  static String? extractErrorContext(String script, int? errorLine) {
    if (errorLine == null) return null;

    final lines = script.split('\n');
    if (errorLine < 1 || errorLine > lines.length) return null;

    final start = (errorLine - 2).clamp(0, lines.length);
    final end = (errorLine + 1).clamp(0, lines.length);

    final buffer = StringBuffer();
    for (var i = start; i < end; i++) {
      final prefix = (i + 1 == errorLine) ? '>>> ' : '    ';
      buffer.writeln('$prefix${lines[i]}');
    }

    return buffer.toString().trim();
  }

  /// 创建增强的执行结果
  ///
  /// 将错误信息转换为包含详细上下文的执行结果
  static LuaExecutionResult createErrorResult({
    required String error,
    List<String> output = const [],
    String? script,
    Duration? executionTime,
    List<String> stackTrace = const [],
  }) {
    final errorInfo = parseError(error);
    final errorLine = extractLineNumber(error) ?? errorInfo.line;
    final errorContext = script != null && errorLine != null
        ? extractErrorContext(script, errorLine)
        : errorInfo.context;

    return LuaExecutionResult.failure(
      error: errorInfo.message,
      output: output,
      executionTime: executionTime,
      errorLine: errorLine,
      errorContext: errorContext,
      stackTrace: stackTrace.isNotEmpty ? stackTrace : [errorInfo.toString()],
    );
  }

  /// 是否为语法错误
  static bool _isSyntaxError(String message) => message.contains('syntax error') ||
        message.contains('unexpected symbol') ||
        message.contains("'end' expected") ||
        message.contains("near '");

  /// 是否为安全错误
  static bool _isSecurityError(String message) => message.contains('LuaSecurityException') ||
        message.contains('权限不足') ||
        message.contains('危险操作');

  /// 是否为超时错误
  static bool _isTimeoutError(String message) => message.contains('timeout') ||
        message.contains('超时') ||
        message.contains('execution time');

  /// 解析语法错误
  static LuaErrorInfo _parseSyntaxError(String message) {
    final line = extractLineNumber(message);
    final column = _extractColumnNumber(message);

    return LuaErrorInfo.syntax(
      message: _cleanErrorMessage(message),
      line: line,
      column: column,
    );
  }

  /// 解析运行时错误
  static LuaErrorInfo _parseRuntimeError(String message) {
    final line = extractLineNumber(message);

    return LuaErrorInfo.runtime(
      message: _cleanErrorMessage(message),
      line: line,
    );
  }

  /// 提取列号
  ///
  /// Lua错误消息中很少包含列号,但某些语法错误会包含位置信息
  /// 例如: "unexpected symbol near 'x'" 可以推断出大致位置
  static int? _extractColumnNumber(String message) {
    // 尝试从"near"关键字提取位置
    // 例如: "unexpected symbol near 'x'" 或 "')' expected near ','"
    final nearMatch = RegExp(r"near\s+'([^']+)'").firstMatch(message);
    if (nearMatch != null) {
      // near关键字后面通常跟着错误位置的符号
      // 但这不能直接转换为列号,需要结合脚本内容
      // 这里返回一个标记值,表示错误位置与某个符号相关
      return null;
    }

    // 某些Lua实现可能会包含列号信息
    // 格式: "line:column: error message"
    final columnMatch = RegExp(r':(\d+):(\d+):').firstMatch(message);
    if (columnMatch != null) {
      return int.tryParse(columnMatch.group(2)!);
    }

    // 尝试从"position"关键字提取
    // 例如: "error at position 123"
    final positionMatch = RegExp(r'position\s+(\d+)').firstMatch(message);
    if (positionMatch != null) {
      return int.tryParse(positionMatch.group(1)!);
    }

    return null;
  }


  /// 清理错误消息
  static String _cleanErrorMessage(String message) {
    // 移除常见的Lua错误前缀
    var cleaned = message;

    // 移除文件引用
    cleaned = cleaned.replaceFirst(RegExp(r'\[string "[^"]*"\]:\d+:\s*'), '');
    cleaned = cleaned.replaceFirst(RegExp(r'string "script":\d+:\s*'), '');

    return cleaned.trim();
  }

  /// 记录错误到调试输出
  static void logError(LuaExecutionResult result) {
    if (result.success) return;

    debugPrint('════════════════════════════════════════');
    debugPrint('Lua 脚本执行失败');
    debugPrint('──────────────────────────────────────');

    if (result.error != null) {
      debugPrint('错误: ${result.error}');
    }

    if (result.errorLine != null) {
      debugPrint('行号: ${result.errorLine}');
    }

    if (result.errorContext != null) {
      debugPrint('上下文:');
      debugPrint(result.errorContext);
    }

    if (result.stackTrace.isNotEmpty) {
      debugPrint('堆栈:');
      for (final frame in result.stackTrace) {
        debugPrint('  $frame');
      }
    }

    debugPrint('════════════════════════════════════════');
  }
}
