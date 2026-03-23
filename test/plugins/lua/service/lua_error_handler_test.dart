import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/plugins/lua/service/lua_error_handler.dart';
import 'package:node_graph_notebook/plugins/lua/models/lua_execution_result.dart';

void main() {
  group('LuaErrorHandler', () {
    test('应该解析语法错误', () {
      final errorMessage = "syntax error near 'end'";
      final errorInfo = LuaErrorHandler.parseError(errorMessage);

      expect(errorInfo.type, LuaErrorType.syntax);
      expect(errorInfo.message, contains('syntax error'));
      expect(errorInfo.suggestion, isNotNull);
    });

    test('应该解析运行时错误', () {
      final errorMessage =
          "script:10: attempt to call a nil value (global 'undefinedFunction')";
      final errorInfo = LuaErrorHandler.parseError(errorMessage);

      expect(errorInfo.type, LuaErrorType.runtime);
      expect(errorInfo.line, 10);
      expect(errorInfo.suggestion, contains('函数未定义'));
    });

    test('应该提取错误行号', () {
      final errorMessage = "script:123: error message";
      final line = LuaErrorHandler.extractLineNumber(errorMessage);

      expect(line, 123);
    });

    test('应该提取错误上下文', () {
      final script = '''
local x = 10
local y = 20
print(x + y)
print(undefinedVariable)
local z = 30
''';

      final context = LuaErrorHandler.extractErrorContext(script, 4);

      expect(context, isNotNull);
      expect(context, contains('print(undefinedVariable)'));
    });

    test('应该创建增强的错误结果', () {
      final script = 'print("hello"';
      final result = LuaErrorHandler.createErrorResult(
        error: "script:1: syntax error near 'end'",
        script: script,
        executionTime: Duration(milliseconds: 100),
      );

      expect(result.success, false);
      expect(result.error, isNotNull);
      expect(result.executionTime, isNotNull);
    });

    test('应该生成格式化的错误信息', () {
      final result = LuaExecutionResult.failure(
        error: 'Test error',
        errorLine: 10,
        errorContext: 'print(x)',
        stackTrace: ['function1', 'function2'],
        executionTime: Duration(milliseconds: 50),
      );

      final formatted = result.formattedError;

      expect(formatted, contains('❌ 错误: Test error'));
      expect(formatted, contains('📍 行号: 10'));
      expect(formatted, contains('🔍 上下文:'));
      expect(formatted, contains('print(x)'));
      expect(formatted, contains('📚 堆栈:'));
      expect(formatted, contains('⏱️  执行时间: 50ms'));
    });

    test('应该检测安全错误', () {
      final errorMessage = 'LuaSecurityException: 权限不足';
      final errorInfo = LuaErrorHandler.parseError(errorMessage);

      expect(errorInfo.type, LuaErrorType.security);
      expect(errorInfo.suggestion, isNotNull);
    });

    test('应该检测超时错误', () {
      final errorMessage = '脚本执行超时';
      final errorInfo = LuaErrorHandler.parseError(errorMessage);

      expect(errorInfo.type, LuaErrorType.timeout);
      expect(errorInfo.suggestion, contains('优化脚本性能'));
    });

    test('应该生成详细的错误报告', () {
      final errorInfo = LuaErrorInfo.syntax(
        message: "unexpected symbol near '}'",
        line: 5,
        column: 10,
        context: 'local x = {1, 2, 3}',
      );

      final detailed = errorInfo.toDetailedString();

      expect(detailed, contains('Lua 错误详情'));
      expect(detailed, contains('语法错误'));
      expect(detailed, contains('第5行'));
      expect(detailed, contains('💡 建议'));
      expect(detailed, contains('上下文'));
    });

    test('toString应该显示成功或失败', () {
      final success = LuaExecutionResult.success(
        returnValue: 42,
        output: ['result'],
        executionTime: Duration(milliseconds: 10),
      );

      final failure = LuaExecutionResult.failure(
        error: 'Test error',
        errorLine: 10,
      );

      expect(success.toString(), contains('✅'));
      expect(success.toString(), contains('success: true'));
      expect(failure.toString(), contains('❌'));
      expect(failure.toString(), contains('success: false'));
    });
  });

  group('LuaErrorInfo', () {
    test('应该提供语法错误建议', () {
      final error1 = LuaErrorInfo.syntax(
        message: "'end' expected",
      );

      expect(error1.suggestion, contains('闭合'));

      final error2 = LuaErrorInfo.syntax(
        message: "unexpected symbol near '}'",
      );

      expect(error2.suggestion, contains('符号'));
    });

    test('应该提供运行时错误建议', () {
      final error1 = LuaErrorInfo.runtime(
        message: "attempt to call a nil value",
      );

      expect(error1.suggestion, contains('函数'));

      final error2 = LuaErrorInfo.runtime(
        message: "attempt to index a nil value",
      );

      expect(error2.suggestion, contains('变量'));
    });

    test('应该创建安全错误', () {
      final error = LuaErrorInfo.security(
        message: '脚本包含不允许的操作',
        suggestion: '请检查脚本权限',
      );

      expect(error.type, LuaErrorType.security);
      expect(error.message, contains('不允许'));
      expect(error.suggestion, contains('权限'));
    });

    test('应该创建超时错误', () {
      final error = LuaErrorInfo.timeout(
        timeout: Duration(seconds: 10),
      );

      expect(error.type, LuaErrorType.timeout);
      expect(error.message, contains('10秒'));
      expect(error.suggestion, contains('超时时间'));
    });
  });
}
