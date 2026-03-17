import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/services/infrastructure/settings_registry.dart';

void main() {
  group('SettingDefinition', () {
    test('should create SettingDefinition with all properties', () {
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

    test('should create SettingDefinition with validator', () {
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

    test('should create SettingDefinition with onChanged callback', () {
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

    test('should create SettingDefinition as sensitive', () {
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
