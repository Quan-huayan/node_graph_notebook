import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/plugins/lua/service/lua_engine_service.dart';

void main() {
  group('LuaEngineService', () {
    late LuaEngineService service;

    setUp(() {
      service = LuaEngineService(
        enableSandbox: false,
        enableDebugOutput: false,
      );
    });

    tearDown(() async {
      if (service.isInitialized) {
        await service.dispose();
      }
    });

    test('初始化引擎', () async {
      expect(service.isInitialized, false);

      await service.initialize();

      expect(service.isInitialized, true);
    });

    test('执行简单脚本', () async {
      await service.initialize();

      final result = await service.executeString('debugPrint("Hello, Lua!")');

      expect(result.success, true);
      expect(result.output, isNotEmpty);
      expect(result.output.first, contains('Hello, Lua!'));
    });

    test('执行包含变量的脚本', () async {
      await service.initialize();

      const script = '''
        local x = 10
        local y = 20
        debugPrint(x + y)
      ''';

      final result = await service.executeString(script);

      expect(result.success, true);
      expect(result.output.last, contains('30'));
    });

    test('执行包含函数的脚本', () async {
      await service.initialize();

      const script = '''
        function add(a, b)
          return a + b
        end
        debugPrint(add(5, 3))
      ''';

      final result = await service.executeString(script);

      expect(result.success, true);
      expect(result.output.last, contains('8'));
    });

    test('处理语法错误', () async {
      await service.initialize();

      final result = await service.executeString('debugPrint("unclosed string)');

      expect(result.success, false);
      expect(result.error, isNotNull);
    });

    test('处理运行时错误', () async {
      await service.initialize();

      final result = await service.executeString('callUndefinedFunction()');

      expect(result.success, false);
      expect(result.error, isNotNull);
    });

    test('使用上下文变量', () async {
      await service.initialize();

      final context = {
        'name': 'Test User',
        'count': 42,
      };

      final result = await service.executeString(
        'debugPrint(name .. ": " .. count)',
        context: context,
      );

      expect(result.success, true);
      expect(result.output.last, contains('Test User: 42'));
    });

    test('注册自定义函数', () async {
      await service.initialize();

      var called = false;
      service.registerFunction('customFunc', (args) {
        called = true;
        expect(args, equals(['test']));
        return 0;
      });

      await service.executeString('customFunc("test")');

      expect(called, true);
    });

    test('重置引擎', () async {
      await service.initialize();

      // 设置变量
      await service.executeString('x = 100');

      // 重置
      await service.reset();

      // 变量应该被清空
      final result = await service.executeString('debugPrint(x or "nil")');

      expect(result.success, true);
      expect(result.output.last, contains('nil'));
    });

    test('多次初始化抛出异常', () async {
      await service.initialize();

      expect(
        () async => service.initialize(),
        throwsA(isA<StateError>()),
      );
    });

    test('未初始化时执行脚本抛出异常', () async {
      expect(
        () async => service.executeString('debugPrint("test")'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
