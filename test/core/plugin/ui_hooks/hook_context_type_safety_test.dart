import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/plugin/ui_hooks/hook_context.dart';

void main() {
  group('HookContext Type Safety', () {
    group('HookDataSchema', () {
      test('应该验证必需参数', () {
        const schema = HookDataSchema(
          type: String,
          required: true,
        );

        expect(schema.validate(null), equals('Required value is missing'));
        expect(schema.validate('valid'), isNull);
      });

      test('应该接受 null 值如果非必需', () {
        const schema = HookDataSchema(
          type: String,
          required: false,
        );

        expect(schema.validate(null), isNull);
        expect(schema.validate('valid'), isNull);
      });

      test('应该验证类型', () {
        const schema = HookDataSchema(
          type: String,
        );

        expect(schema.validate('string'), isNull);
        expect(schema.validate(123), isNotNull);
      });
    });

    group('HookContext', () {
      test('应该在禁用验证时正常工作', () {
        final context = BasicHookContext(
          enableTypeValidation: false,
        );

        expect(
          () => context.set('key', 'any value'),
          returnsNormally,
        );
      });

      test('应该在启用验证且未注册 Schema 时正常工作', () {
        final context = BasicHookContext(
          enableTypeValidation: true,
        );

        expect(
          () => context.set('key', 'any value'),
          returnsNormally,
        );
      });

      test('应该在启用验证且注册 Schema 时验证数据', () {
        final context = BasicHookContext(
          enableTypeValidation: true,
        );

        context.registerSchema(
          'title',
          const HookDataSchema(
            type: String,
            required: true,
          ),
        );

        // 正确的类型
        expect(() => context.set('title', 'Valid Title'), returnsNormally);

        // 错误的类型
        expect(
          () => context.set('title', 123),
          throwsA(isA<HookDataContextException>()),
        );
      });

      test('应该接受 null 值如果 Schema 标记为非必需', () {
        final context = BasicHookContext(
          enableTypeValidation: true,
        );

        context.registerSchema(
          'optional',
          const HookDataSchema(
            type: String,
            required: false,
          ),
        );

        expect(() => context.set('optional', null), returnsNormally);
      });

      test('应该拒绝 null 值如果 Schema 标记为必需', () {
        final context = BasicHookContext(
          enableTypeValidation: true,
        );

        context.registerSchema(
          'required',
          const HookDataSchema(
            type: String,
            required: true,
          ),
        );

        expect(
          () => context.set('required', null),
          throwsA(isA<HookDataContextException>()),
        );
      });

      test('应该支持多种数据类型', () {
        final context = BasicHookContext(
          enableTypeValidation: true,
        );

        context.registerSchema('stringKey', const HookDataSchema(type: String));
        context.registerSchema('intKey', const HookDataSchema(type: int));
        context.registerSchema('boolKey', const HookDataSchema(type: bool));
        context.registerSchema('doubleKey', const HookDataSchema(type: double));

        expect(() => context.set('stringKey', 'text'), returnsNormally);
        expect(() => context.set('intKey', 42), returnsNormally);
        expect(() => context.set('boolKey', true), returnsNormally);
        expect(() => context.set('doubleKey', 3.14), returnsNormally);
      });

      test('应该在获取数据时正确转换类型', () {
        final context = BasicHookContext();
        context.set('string', 'text');
        context.set('int', 42);
        context.set('bool', true);

        expect(context.get<String>('string'), equals('text'));
        expect(context.get<int>('int'), equals(42));
        expect(context.get<bool>('bool'), equals(true));
      });

      test('应该在获取不存在的键时返回 null', () {
        final context = BasicHookContext();

        expect(context.get<String>('nonexistent'), isNull);
      });

      test('应该在获取错误类型时返回 null', () {
        final context = BasicHookContext();
        context.set('key', 'string value');

        expect(context.get<int>('key'), isNull);
      });

      test('应该检查数据是否存在', () {
        final context = BasicHookContext();

        expect(context.contains('key'), false);

        context.set('key', 'value');

        expect(context.contains('key'), true);
      });

      test('HookDataContextException 应该包含有用的错误信息', () {
        final context = BasicHookContext(
          enableTypeValidation: true,
        );

        context.registerSchema(
          'typedKey',
          const HookDataSchema(type: String),
        );

        try {
          context.set('typedKey', 123);
          fail('Should have thrown HookDataContextException');
        } on HookDataContextException catch (e) {
          expect(e.message, contains('typedKey'));
          expect(e.message, contains('validation failed'));
        }
      });
    });

    group('Specialized Hook Contexts', () {
      test('MainToolbarHookContext 应该正确初始化', () {
        final context = MainToolbarHookContext();

        expect(context.showTitle, true);
        expect(context.showSearch, true);
      });

      test('NodeContextMenuHookContext 应该存储节点', () {
        final context = NodeContextMenuHookContext();

        expect(context.node, isNull);
        expect(context.isSelected, false);
      });

      test('StatusBarHookContext 应该正确初始化', () {
        final context = StatusBarHookContext(
          nodeCount: 10,
          connectionCount: 5,
        );

        expect(context.nodeCount, equals(10));
        expect(context.connectionCount, equals(5));
        expect(context.currentMode, equals('browse'));
      });
    });

    group('Backward Compatibility', () {
      test('旧代码不应该启用验证', () {
        // 不传 enableTypeValidation 参数，默认为 false
        final context = BasicHookContext();

        expect(
          () => context.set('anyKey', 'anyValue'),
          returnsNormally,
        );
      });

      test('旧代码应该继续正常工作', () {
        final context = BasicHookContext();

        // 设置各种类型的数据
        context.set('string', 'text');
        context.set('int', 42);
        context.set('bool', true);
        context.set('list', [1, 2, 3]);
        context.set('map', {'key': 'value'});

        // 获取数据
        expect(context.get<String>('string'), equals('text'));
        expect(context.get<int>('int'), equals(42));
        expect(context.get<bool>('bool'), equals(true));
        expect(context.get<List>('list')?.length, equals(3));
        expect(context.get<Map>('map')?.length, equals(1));
      });
    });
  });
}
