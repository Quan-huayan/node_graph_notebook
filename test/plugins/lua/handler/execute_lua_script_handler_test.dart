import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:node_graph_notebook/core/commands/models/command_context.dart';
import 'package:node_graph_notebook/plugins/lua/command/execute_lua_script_command.dart';
import 'package:node_graph_notebook/plugins/lua/handler/execute_lua_script_handler.dart';
import 'package:node_graph_notebook/plugins/lua/models/lua_execution_result.dart';
import 'package:node_graph_notebook/plugins/lua/service/lua_engine_service.dart';
import 'package:node_graph_notebook/plugins/lua/service/lua_script_service.dart';

@GenerateMocks([LuaEngineService, LuaScriptService])
import 'execute_lua_script_handler_test.mocks.dart';

void main() {
  group('ExecuteLuaScriptHandler', () {
    late ExecuteLuaScriptHandler handler;
    late MockLuaEngineService mockEngineService;
    late MockLuaScriptService mockScriptService;
    late CommandContext context;

    setUp(() {
      mockEngineService = MockLuaEngineService();
      mockScriptService = MockLuaScriptService();
      handler = ExecuteLuaScriptHandler(
        engineService: mockEngineService,
        scriptService: mockScriptService,
      );
      context = CommandContext();  // ✅ 修复：使用默认构造函数
    });

    test('应该成功执行脚本字符串', () async {
      // 准备测试数据
      final result = LuaExecutionResult.success(
        output: ['Hello, Lua!'],
      );

      when(mockEngineService.isInitialized).thenReturn(true);
      when(mockEngineService.executeString('debugPrint("Hello")', context: null))
          .thenAnswer((_) async => result);

      // 执行命令
      final command = ExecuteLuaScriptCommand(
        scriptPath: '',
        scriptContent: 'debugPrint("Hello")',
      );

      final commandResult = await handler.execute(command, context);

      // 验证结果
      expect(commandResult.isSuccess, true);
      expect(commandResult.data?.output, equals(['Hello, Lua!']));
      verify(mockEngineService.executeString('debugPrint("Hello")', context: null))
          .called(1);
    });

    test('引擎未初始化时应该返回失败', () async {
      // 准备测试数据
      when(mockEngineService.isInitialized).thenReturn(false);

      // 执行命令
      final command = ExecuteLuaScriptCommand(
        scriptPath: '',
        scriptContent: 'debugPrint("Hello")',
      );

      final commandResult = await handler.execute(command, context);

      // 验证结果
      expect(commandResult.isSuccess, false);
      expect(commandResult.error, contains('未初始化'));
    });

    test('脚本执行失败时应该返回错误', () async {
      // 准备测试数据
      final result = LuaExecutionResult.failure(
        error: '语法错误',
        output: [],
      );

      when(mockEngineService.isInitialized).thenReturn(true);
      when(mockEngineService.executeString('invalid syntax', context: null))
          .thenAnswer((_) async => result);

      // 执行命令
      final command = ExecuteLuaScriptCommand(
        scriptPath: '',
        scriptContent: 'invalid syntax',
      );

      final commandResult = await handler.execute(command, context);

      // 验证结果
      expect(commandResult.isSuccess, false);
      expect(commandResult.error, equals('语法错误'));
    });

    test('应该处理异常情况', () async {
      // 准备测试数据
      when(mockEngineService.isInitialized).thenReturn(true);
      when(mockEngineService.executeString(any, context: anyNamed('context')))
          .thenThrow(Exception('引擎异常'));

      // 执行命令
      final command = ExecuteLuaScriptCommand(
        scriptPath: '',
        scriptContent: 'debugPrint("Hello")',
      );

      final commandResult = await handler.execute(command, context);

      // 验证结果
      expect(commandResult.isSuccess, false);
      expect(commandResult.error, contains('引擎异常'));
    });
  });
}
