import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/plugins/lua/service/simple_script_engine.dart';
import 'package:node_graph_notebook/plugins/lua/models/lua_execution_result.dart';

void main() {
  group('SimpleScriptEngine', () {
    late SimpleScriptEngine engine;

    setUp(() {
      engine = SimpleScriptEngine(
        enableDebugOutput: false,
      );
    });

    tearDown(() async {
      if (engine.isInitialized) {
        await engine.dispose();
      }
    });

    test('初始化引擎', () async {
      expect(engine.isInitialized, false);

      await engine.initialize();

      expect(engine.isInitialized, true);
    });

    test('执行简单打印脚本', () async {
      await engine.initialize();

      final result = await engine.executeString('print("Hello, World!")');

      expect(result.success, true);
      expect(result.output, isNotEmpty);
      expect(result.output.first, contains('Hello, World!'));
    });

    test('执行包含变量的脚本', () async {
      await engine.initialize();

      final script = '''
        local message = "Hello"
        print(message)
      ''';

      final result = await engine.executeString(script);

      expect(result.success, true);
      expect(result.output.last, contains('Hello'));
    });

    test('执行包含函数定义的脚本', () async {
      await engine.initialize();

      final script = '''
        function greet(name)
          print("Hello, " .. name)
        end
        greet("Lua")
      ''';

      final result = await engine.executeString(script);

      expect(result.success, true);
      expect(result.output.last, contains('Hello, Lua'));
    });

    test('执行包含if语句的脚本', () async {
      await engine.initialize();

      final script = '''
        local x = 10
        if x > 5 then
          print("x大于5")
        end
      ''';

      final result = await engine.executeString(script);

      expect(result.success, true);
      expect(result.output.last, contains('x大于5'));
    });

    test('执行包含for循环的脚本', () async {
      await engine.initialize();

      final script = '''
        for i = 1, 3 do
          print("计数: " .. i)
        end
      ''';

      final result = await engine.executeString(script);

      expect(result.success, true);
      expect(result.output.length, greaterThan(0));
    });

    test('使用log函数', () async {
      await engine.initialize();

      final result = await engine.executeString('log("测试日志")');

      expect(result.success, true);
      expect(result.output.last, contains('[LOG]'));
      expect(result.output.last, contains('测试日志'));
    });

    test('使用上下文变量', () async {
      await engine.initialize();

      final context = {
        'name': 'Test User',
        'count': 42,
      };

      final result = await engine.executeString(
        'print(name .. ": " .. count)',
        context: context,
      );

      expect(result.success, true);
      expect(result.output.last, contains('Test User'));
    });

    test('注册自定义函数', () async {
      await engine.initialize();

      var called = false;
      engine.registerFunction('customFunc', (args) {
        called = true;
        expect(args, equals(['test']));
        return 0;
      });

      await engine.executeString('customFunc("test")');

      expect(called, true);
    });

    test('重置引擎', () async {
      await engine.initialize();

      // 设置变量
      await engine.executeString('x = 100');

      // 重置
      await engine.reset();

      // 变量应该被清空
      final result = await engine.executeString('print(x or "nil")');

      expect(result.success, true);
      expect(result.output.last, contains('nil'));
    });

    test('多次初始化抛出异常', () async {
      await engine.initialize();

      expect(
        () async => await engine.initialize(),
        throwsA(isA<StateError>()),
      );
    });

    test('未初始化时执行脚本抛出异常', () async {
      expect(
        () async => await engine.executeString('print("test")'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
