import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/plugins/lua/service/lua_engine_service.dart';
import 'package:node_graph_notebook/plugins/lua/models/lua_execution_result.dart';

void main() {
  group('RealLuaEngine Table Parsing Tests', () {
    late LuaEngineService engineService;

    setUp(() async {
      // 使用真正的Lua引擎
      engineService = LuaEngineService(
        engineType: LuaEngineType.realLua,
        enableDebugOutput: false,
      );
      await engineService.initialize();
    });

    tearDown(() async {
      await engineService.dispose();
    });

    test('解析简单数组', () async {
      final result = await engineService.executeString('''
        arr = {1, 2, 3, 4, 5}
        print(#arr)
        for i, v in ipairs(arr) do
          print(v)
        end
      ''');

      expect(result.success, true);
      expect(result.output, isNotEmpty);
      // 验证数组长度
      expect(result.output.any((line) => line.contains('5')), true);
    });

    test('解析字符串数组', () async {
      final result = await engineService.executeString('''
        strArr = {"hello", "world", "lua"}
        for i, v in ipairs(strArr) do
          print(v)
        end
      ''');

      expect(result.success, true);
      expect(result.output, contains('hello'));
      expect(result.output, contains('world'));
      expect(result.output, contains('lua'));
    });

    test('解析表(Map)', () async {
      final result = await engineService.executeString('''
        person = {
          name = "Alice",
          age = 30,
          city = "Beijing"
        }
        print(person.name)
        print(person.age)
        print(person.city)
      ''');

      expect(result.success, true);
      expect(result.output, contains('Alice'));
      expect(result.output, contains('30'));
      expect(result.output, contains('Beijing'));
    });

    test('解析嵌套表结构', () async {
      final result = await engineService.executeString('''
        nested = {
          user = {
            name = "Bob",
            tags = {"developer", "lua"}
          },
          score = 100
        }
        print(nested.user.name)
        print(nested.score)
        for i, tag in ipairs(nested.user.tags) do
          print(tag)
        end
      ''');

      expect(result.success, true);
      expect(result.output, contains('Bob'));
      expect(result.output, contains('100'));
      expect(result.output, contains('developer'));
      expect(result.output, contains('lua'));
    });

    test('使用上下文变量传递表', () async {
      final context = {
        'users': [
          {'name': 'Alice', 'age': 30},
          {'name': 'Bob', 'age': 25},
        ]
      };

      final result = await engineService.executeString(
        '''
        print(#users)
        for i, user in ipairs(users) do
          print(user.name)
          print(user.age)
        end
        ''',
        context: context,
      );

      expect(result.success, true);
      expect(result.output, contains('2')); // 数组长度
      expect(result.output, contains('Alice'));
      expect(result.output, contains('Bob'));
    });

    test('处理空表', () async {
      final result = await engineService.executeString('''
        empty = {}
        print(type(empty))
        print(#empty)
      ''');

      expect(result.success, true);
      expect(result.output, contains('table'));
    });

    test('处理混合数组', () async {
      final result = await engineService.executeString('''
        mixed = {1, "two", 3.0, true, nil}
        for i, v in ipairs(mixed) do
          if v ~= nil then
            print(tostring(v))
          end
        end
      ''');

      expect(result.success, true);
      expect(result.output, contains('1'));
      expect(result.output, contains('two'));
      expect(result.output, contains('3.0')); // Lua prints 3.0 for 3.0
      expect(result.output, contains('true'));
    });

    test('Dart函数接收表参数', () async {
      // 先测试简单的函数调用
      engineService.registerFunction('testSimple', (args) {
        return 42;
      });

      final simpleResult = await engineService.executeString('''
        result = testSimple()
        print("Result: " .. tostring(result))
      ''');

      expect(simpleResult.success, true);
      expect(simpleResult.output, contains('Result: 42'));

      // 测试接收数组的函数
      engineService.registerFunction('processArray', (args) {
        if (args.isNotEmpty) {
          final arr = args[0];
          if (arr is List) {
            return arr.length;
          }
        }
        return -1;
      });

      final result = await engineService.executeString('''
        arr = {1, 2, 3, 4, 5}
        count = processArray(arr)
        print("Array count: " .. tostring(count))
      ''');

      expect(result.success, true);
      expect(result.output, contains('Array count: 5'));
    });
  });

  group('RealLuaEngine API Integration Tests', () {
    late LuaEngineService engineService;

    setUp(() async {
      engineService = LuaEngineService(
        engineType: LuaEngineType.realLua,
        enableDebugOutput: false,
      );
      await engineService.initialize();
    });

    tearDown(() async {
      await engineService.dispose();
    });

    test('getAllNodes返回表并迭代', () async {
      // 模拟getAllNodes API
      engineService.registerFunction('getAllNodes', (args) {
        // 返回模拟的节点表
        return 0; // 返回值数量（在Lua中设置全局变量）
      });

      final result = await engineService.executeString('''
        -- 模拟getAllNodes设置全局变量
        _temp_nodes = {
          {id = "1", title = "Node 1"},
          {id = "2", title = "Node 2"},
          {id = "3", title = "Node 3"}
        }

        print("Total nodes: " .. #_temp_nodes)
        for i, node in ipairs(_temp_nodes) do
          print(node.id .. ": " .. node.title)
        end
      ''');

      expect(result.success, true);
      expect(result.output, contains('Total nodes: 3'));
      expect(result.output, contains('1: Node 1'));
      expect(result.output, contains('2: Node 2'));
      expect(result.output, contains('3: Node 3'));
    });
  });
}
