import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plugon/plugon.dart' as core_barrel;
import 'package:plugon/plugon_flutter.dart' as full_barrel;

void main() {
  test('plugon.dart 可通过前缀访问全部 core 符号', () {
    expect(core_barrel.ServiceCollection, isA<Type>());
    expect(core_barrel.ServiceProvider, isA<Type>());
    expect(core_barrel.ServiceLifetime, isA<Type>());
    expect(core_barrel.ServiceNotFoundException, isA<Type>());
    expect(core_barrel.ExtensionRegistry, isA<Type>());
    expect(core_barrel.ExtensionPoint, isA<Type>());
    expect(core_barrel.Plugin, isA<Type>());
    expect(core_barrel.PluginManager, isA<Type>());
    expect(core_barrel.PluginMetadata, isA<Type>());
    expect(core_barrel.PluginContext, isA<Type>());
    expect(core_barrel.PluginState, isA<Type>());
  });

  test('plugon_flutter.dart 可访问 core + 适配符号', () {
    expect(full_barrel.ServiceCollection, isA<Type>());
    expect(full_barrel.buildProviders, isA<Function>());
    expect(full_barrel.buildBlocProviders, isA<Function>());
  });

  test('plugon.dart 源文件仅导出 core，不导入 Flutter 包', () {
    final source = File('lib/plugon.dart').readAsStringSync();
    expect(
      source,
      isNot(contains('package:flutter')),
      reason: '纯 Dart 桶不得导入 Flutter 包',
    );
    expect(source, contains("export 'core/di.dart'"));
    expect(source, contains("export 'core/extensions.dart'"));
    expect(source, contains("export 'core/plugin.dart'"));
  });

  test('plugon_flutter.dart 导出 core + 全部 flutter 适配', () {
    final source = File('lib/plugon_flutter.dart').readAsStringSync();
    expect(source, contains("export 'plugon.dart'"));
    expect(source, contains("export 'flutter/bloc.dart'"));
    expect(source, contains("export 'flutter/collection_ext.dart'"));
    expect(source, contains("export 'flutter/providers.dart'"));
  });

  test('旧库名已删除（lib/plugin.dart 与 lib/hooks 不再存在）', () {
    expect(File('lib/plugin.dart').existsSync(), isFalse);
    expect(Directory('lib/hooks').existsSync(), isFalse);
    expect(File('lib/registry.dart').existsSync(), isFalse);
    expect(File('lib/provider_builder.dart').existsSync(), isFalse);
  });
}
