import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/services/infrastructure/settings_registry.dart';

void main() {
  group('SettingDefinition', () {
    test('应该创建包含所有属性的 SettingDefinition', () {
      const definition = SettingDefinition<String>(
        key: 'test.key',
        defaultValue: 'default',
        displayName: 'Test Setting',
        description: 'Test description',
        category: 'Test Category',
      );

      expect(definition.key, 'test.key');
      expect(definition.defaultValue, 'default');
      expect(definition.displayName, 'Test Setting');
      expect(definition.description, 'Test description');
      expect(definition.category, 'Test Category');
      expect(definition.validator, null);
      expect(definition.onChanged, null);
      expect(definition.isSensitive, false);
    });

    test('应该创建带有验证器的 SettingDefinition', () {
      const definition = SettingDefinition<int>(
        key: 'test.number',
        defaultValue: 10,
        displayName: 'Test Number',
        description: 'Test description',
        category: 'Test Category',
        validator: _testValidator,
      );

      expect(definition.validator, isNotNull);
    });

    test('应该创建带有 onChanged 回调的 SettingDefinition', () {
      var callbackCalled = false;
      final definition = SettingDefinition<bool>(
        key: 'test.bool',
        defaultValue: false,
        displayName: 'Test Bool',
        description: 'Test description',
        category: 'Test Category',
        onChanged: (value) {
          callbackCalled = true;
        },
      );

      definition.onChanged?.call(true);
      expect(callbackCalled, true);
    });

    test('应该创建敏感类型的 SettingDefinition', () {
      const definition = SettingDefinition<String>(
        key: 'test.sensitive',
        defaultValue: 'secret',
        displayName: 'Sensitive Setting',
        description: 'Test description',
        category: 'Test Category',
        isSensitive: true,
      );

      expect(definition.isSensitive, true);
    });
  });
}

int _testValidator(int value) => value < 15 ? value : 20;
