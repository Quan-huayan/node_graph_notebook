import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/plugins/lua/service/lua_function_registry.dart';
import 'package:node_graph_notebook/plugins/lua/service/lua_function_schema.dart';

void main() {
  group('LuaFunctionSchema', () {
    group('Parameter Validation', () {
      test('应该验证必需参数', () {
        const schema = LuaFunctionSchema(
          name: 'testFunc',
          parameters: [
            LuaFunctionParameterSchema(
              name: 'requiredParam',
              type: LuaType.string,
              required: true,
            ),
          ],
        );

        expect(
          () => schema.validateArguments([]),
          throwsA(isA<LuaFunctionValidationException>()
              .having((e) => e.message, 'message', contains('Required parameter'))),
        );
      });

      test('应该接受有效的参数', () {
        const schema = LuaFunctionSchema(
          name: 'testFunc',
          parameters: [
            LuaFunctionParameterSchema(
              name: 'param1',
              type: LuaType.string,
            ),
            LuaFunctionParameterSchema(
              name: 'param2',
              type: LuaType.integer,
            ),
          ],
        );

        final result = schema.validateArguments(['hello', 42]);

        expect(result, {'param1': 'hello', 'param2': 42});
      });

      test('应该拒绝错误的参数类型', () {
        const schema = LuaFunctionSchema(
          name: 'testFunc',
          parameters: [
            LuaFunctionParameterSchema(
              name: 'count',
              type: LuaType.integer,
            ),
          ],
        );

        expect(
          () => schema.validateArguments(['not a number']),
          throwsA(isA<LuaFunctionValidationException>()
              .having((e) => e.message, 'message', contains('must be integer'))),
        );
      });

      test('应该应用默认值', () {
        const schema = LuaFunctionSchema(
          name: 'testFunc',
          parameters: [
            LuaFunctionParameterSchema(
              name: 'param1',
              type: LuaType.string,
              defaultValue: 'default',
              required: false,
            ),
          ],
        );

        final result = schema.validateArguments([]);

        expect(result, {'param1': 'default'});
      });

      test('应该允许可选参数缺失', () {
        const schema = LuaFunctionSchema(
          name: 'testFunc',
          parameters: [
            LuaFunctionParameterSchema(
              name: 'required',
              type: LuaType.string,
            ),
            LuaFunctionParameterSchema(
              name: 'optional',
              type: LuaType.string,
              required: false,
            ),
          ],
        );

        final result = schema.validateArguments(['value']);

        expect(result, {
          'required': 'value',
          'optional': null,
        });
      });

      test('应该验证 table 类型参数', () {
        const schema = LuaFunctionSchema(
          name: 'testFunc',
          parameters: [
            LuaFunctionParameterSchema(
              name: 'config',
              type: LuaType.table,
            ),
          ],
        );

        final result = schema.validateArguments([{'key': 'value'}]);

        expect(result, {'config': {'key': 'value'}});
      });

      test('应该拒绝非 table 类型参数', () {
        const schema = LuaFunctionSchema(
          name: 'testFunc',
          parameters: [
            LuaFunctionParameterSchema(
              name: 'config',
              type: LuaType.table,
            ),
          ],
        );

        expect(
          () => schema.validateArguments(['not a table']),
          throwsA(isA<LuaFunctionValidationException>()
              .having((e) => e.message, 'message', contains('must be table'))),
        );
      });

      test('应该验证 array 类型参数', () {
        const schema = LuaFunctionSchema(
          name: 'testFunc',
          parameters: [
            LuaFunctionParameterSchema(
              name: 'items',
              type: LuaType.array,
            ),
          ],
        );

        final result = schema.validateArguments([[1, 2, 3]]);

        expect(result, {'items': [1, 2, 3]});
      });

      test('应该接受 any 类型参数', () {
        const schema = LuaFunctionSchema(
          name: 'testFunc',
          parameters: [
            LuaFunctionParameterSchema(
              name: 'anyValue',
              type: LuaType.any,
              required: false,
            ),
          ],
        );

        // Test various types individually
        expect(() => schema.validateArguments([null]), returnsNormally);
        expect(() => schema.validateArguments(['string']), returnsNormally);
        expect(() => schema.validateArguments([123]), returnsNormally);
        expect(() => schema.validateArguments([true]), returnsNormally);
        expect(() => schema.validateArguments([[]]), returnsNormally);
        expect(() => schema.validateArguments([{}]), returnsNormally);
      });

      test('应该拒绝过多的参数', () {
        const schema = LuaFunctionSchema(
          name: 'testFunc',
          parameters: [
            LuaFunctionParameterSchema(
              name: 'param1',
              type: LuaType.string,
            ),
          ],
        );

        expect(
          () => schema.validateArguments(['a', 'b', 'c']),
          throwsA(isA<LuaFunctionValidationException>()
              .having((e) => e.message, 'message', contains('expects at most'))),
        );
      });
    });

    group('Signature Generation', () {
      test('应该生成正确的函数签名', () {
        const schema = LuaFunctionSchema(
          name: 'myFunction',
          parameters: [
            LuaFunctionParameterSchema(
              name: 'param1',
              type: LuaType.string,
            ),
            LuaFunctionParameterSchema(
              name: 'param2',
              type: LuaType.integer,
              required: false,
            ),
          ],
        );

        expect(schema.signature, 'myFunction(string param1, integer? param2)');
      });
    });
  });

  group('LuaFunctionRegistry', () {
    late LuaFunctionRegistry registry;

    setUp(() {
      registry = LuaFunctionRegistry(
        enableTypeValidation: true,
        allowOverride: false,
      );
    });

    test('应该成功注册函数', () {
      const schema = LuaFunctionSchema(
        name: 'testFunc',
        parameters: [
          LuaFunctionParameterSchema(
            name: 'param',
            type: LuaType.string,
          ),
        ],
      );

      String handler(Map<String, dynamic> args) => args['param'];

      expect(
        () => registry.registerFunction(schema, handler, pluginId: 'testPlugin'),
        returnsNormally,
      );

      expect(registry.hasFunction('testFunc'), true);
      expect(registry.functionCount, 1);
    });

    test('应该成功调用已注册的函数', () {
      const schema = LuaFunctionSchema(
        name: 'greet',
        parameters: [
          LuaFunctionParameterSchema(
            name: 'name',
            type: LuaType.string,
          ),
        ],
      );

      String handler(Map<String, dynamic> args) => 'Hello, ${args['name']}!';

      registry.registerFunction(schema, handler, pluginId: 'testPlugin');

      final result = registry.callFunction('greet', ['World']);

      expect(result, 'Hello, World!');
    });

    test('应该验证函数调用参数', () {
      const schema = LuaFunctionSchema(
        name: 'add',
        parameters: [
          LuaFunctionParameterSchema(
            name: 'a',
            type: LuaType.integer,
          ),
          LuaFunctionParameterSchema(
            name: 'b',
            type: LuaType.integer,
          ),
        ],
      );

      int handler(Map<String, dynamic> args) => (args['a'] as int) + (args['b'] as int);

      registry.registerFunction(schema, handler, pluginId: 'testPlugin');

      final result = registry.callFunction('add', [10, 20]);

      expect(result, 30);
    });

    test('应该拒绝调用不存在的函数', () {
      expect(
        () => registry.callFunction('nonExistent', []),
        throwsA(isA<LuaFunctionCallException>()
            .having((e) => e.message, 'message', contains('is not registered'))),
      );
    });

    test('应该拒绝无效的函数调用参数', () {
      const schema = LuaFunctionSchema(
        name: 'test',
        parameters: [
          LuaFunctionParameterSchema(
            name: 'count',
            type: LuaType.integer,
          ),
        ],
      );

      int handler(Map<String, dynamic> args) => args['count'];

      registry.registerFunction(schema, handler, pluginId: 'testPlugin');

      expect(
        () => registry.callFunction('test', ['not a number']),
        throwsA(isA<LuaFunctionValidationException>()),
      );
    });

    test('应该阻止插件覆盖其他插件的函数', () {
      const schema1 = LuaFunctionSchema(
        name: 'sharedFunc',
        parameters: [
          LuaFunctionParameterSchema(
            name: 'param',
            type: LuaType.string,
          ),
        ],
      );

      const schema2 = LuaFunctionSchema(
        name: 'sharedFunc',
        parameters: [
          LuaFunctionParameterSchema(
            name: 'param',
            type: LuaType.string,
          ),
        ],
      );

      String handler1(Map<String, dynamic> args) => 'plugin1';
      String handler2(Map<String, dynamic> args) => 'plugin2';

      registry.registerFunction(schema1, handler1, pluginId: 'plugin1');

      expect(
        () => registry.registerFunction(schema2, handler2, pluginId: 'plugin2'),
        throwsA(isA<LuaFunctionRegistrationException>()
            .having((e) => e.message, 'message', contains('already registered'))),
      );
    });

    test('应该允许插件覆盖自己的函数', () {
      const schema = LuaFunctionSchema(
        name: 'myFunc',
        parameters: [
          LuaFunctionParameterSchema(
            name: 'param',
            type: LuaType.string,
          ),
        ],
      );

      String handler1(Map<String, dynamic> args) => 'v1';
      String handler2(Map<String, dynamic> args) => 'v2';

      registry.registerFunction(schema, handler1, pluginId: 'myPlugin');

      // 同一插件重新注册应该成功（即使 allowOverride = false）
      expect(
        () => registry.registerFunction(schema, handler2, pluginId: 'myPlugin'),
        returnsNormally,
      );

      final result = registry.callFunction('myFunc', ['test']);
      expect(result, 'v2');
    });

    test('应该允许覆盖模式下的跨插件覆盖', () {
      final allowOverrideRegistry = LuaFunctionRegistry(
        allowOverride: true,
      );

      const schema = LuaFunctionSchema(
        name: 'sharedFunc',
        parameters: [
          LuaFunctionParameterSchema(
            name: 'param',
            type: LuaType.string,
          ),
        ],
      );

      String handler1(Map<String, dynamic> args) => 'plugin1';
      String handler2(Map<String, dynamic> args) => 'plugin2';

      allowOverrideRegistry.registerFunction(schema, handler1, pluginId: 'plugin1');

      expect(
        () => allowOverrideRegistry.registerFunction(schema, handler2, pluginId: 'plugin2'),
        returnsNormally,
      );

      final result = allowOverrideRegistry.callFunction('sharedFunc', ['test']);
      expect(result, 'plugin2');
    });

    test('应该成功注销函数', () {
      const schema = LuaFunctionSchema(
        name: 'testFunc',
        parameters: [],
      );

      int handler(Map<String, dynamic> args) => 42;

      registry.registerFunction(schema, handler, pluginId: 'testPlugin');
      expect(registry.hasFunction('testFunc'), true);

      registry.unregisterFunction('testFunc', pluginId: 'testPlugin');
      expect(registry.hasFunction('testFunc'), false);
    });

    test('应该阻止插件注销其他插件的函数', () {
      const schema = LuaFunctionSchema(
        name: 'testFunc',
        parameters: [],
      );

      int handler(Map<String, dynamic> args) => 42;

      registry.registerFunction(schema, handler, pluginId: 'plugin1');

      // plugin2 尝试注销 plugin1 的函数应该静默失败
      registry.unregisterFunction('testFunc', pluginId: 'plugin2');

      // 函数应该仍然存在
      expect(registry.hasFunction('testFunc'), true);
      expect(registry.getOwner('testFunc'), 'plugin1');
    });

    test('应该注销插件的所有函数', () {
      registry.registerFunction(
        const LuaFunctionSchema(name: 'func1', parameters: []),
        (args) => 1,
        pluginId: 'myPlugin',
      );

      registry.registerFunction(
        const LuaFunctionSchema(name: 'func2', parameters: []),
        (args) => 2,
        pluginId: 'myPlugin',
      );

      registry.registerFunction(
        const LuaFunctionSchema(name: 'func3', parameters: []),
        (args) => 3,
        pluginId: 'otherPlugin',
      );

      expect(registry.functionCount, 3);

      registry.unregisterAllByPlugin('myPlugin');

      expect(registry.functionCount, 1);
      expect(registry.hasFunction('func1'), false);
      expect(registry.hasFunction('func2'), false);
      expect(registry.hasFunction('func3'), true);
    });

    test('应该按分类获取函数', () {
      registry.registerFunction(
        const LuaFunctionSchema(
          name: 'func1',
          category: 'math',
          parameters: [],
        ),
        (args) => 1,
        pluginId: 'testPlugin',
      );

      registry.registerFunction(
        const LuaFunctionSchema(
          name: 'func2',
          category: 'math',
          parameters: [],
        ),
        (args) => 2,
        pluginId: 'testPlugin',
      );

      registry.registerFunction(
        const LuaFunctionSchema(
          name: 'func3',
          category: 'string',
          parameters: [],
        ),
        (args) => 3,
        pluginId: 'testPlugin',
      );

      final mathFunctions = registry.getFunctionsByCategory('math');
      final stringFunctions = registry.getFunctionsByCategory('string');

      expect(mathFunctions, ['func1', 'func2']);
      expect(stringFunctions, ['func3']);
    });

    test('禁用类型验证时应该跳过参数检查', () {
      final noValidationRegistry = LuaFunctionRegistry(
        enableTypeValidation: false,
      );

      const schema = LuaFunctionSchema(
        name: 'testFunc',
        parameters: [
          LuaFunctionParameterSchema(
            name: 'count',
            type: LuaType.integer,
          ),
        ],
      );

      int handler(Map<String, dynamic> args) => 42;

      noValidationRegistry.registerFunction(schema, handler, pluginId: 'testPlugin');

      // 即使参数类型错误，也不会验证
      expect(
        () => noValidationRegistry.callFunction('testFunc', ['not a number']),
        returnsNormally,
      );
    });

    test('应该捕获函数执行错误', () {
      const schema = LuaFunctionSchema(
        name: 'errorFunc',
        parameters: [],
      );

      int handler(Map<String, dynamic> args) {
        throw Exception('Handler error');
      }

      registry.registerFunction(schema, handler, pluginId: 'testPlugin');

      expect(
        () => registry.callFunction('errorFunc', []),
        throwsA(isA<LuaFunctionCallException>()
            .having((e) => e.message, 'message', contains('Error executing function'))),
      );
    });

    test('应该生成正确的函数签名', () {
      const schema = LuaFunctionSchema(
        name: 'myFunction',
        parameters: [
          LuaFunctionParameterSchema(
            name: 'param1',
            type: LuaType.string,
          ),
          LuaFunctionParameterSchema(
            name: 'param2',
            type: LuaType.integer,
            required: false,
          ),
        ],
      );

      expect(schema.signature, 'myFunction(string param1, integer? param2)');
    });
  });
}
