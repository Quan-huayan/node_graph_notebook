import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/plugin/plugin.dart';

void main() {
  group('DependencyResolver', () {
    late DependencyResolver resolver;

    setUp(() {
      resolver = DependencyResolver();
    });

    group('resolve - 拓扑排序', () {
      test('应该为简单依赖链返回正确的加载顺序', () {
        final plugins = {
          'plugin_a': const PluginMetadata(
            id: 'plugin_a',
            name: 'Plugin A',
            version: '1.0.0',
            dependencies: ['plugin_b'],
          ),
          'plugin_b': const PluginMetadata(
            id: 'plugin_b',
            name: 'Plugin B',
            version: '1.0.0',
            dependencies: [],
          ),
        };

        final result = resolver.resolve(plugins);

        expect(result.isSuccess, true);
        expect(result.loadOrder, equals(['plugin_b', 'plugin_a']));
      });

      test('应该为菱形依赖返回正确的加载顺序', () {
        final plugins = {
          'plugin_a': const PluginMetadata(
            id: 'plugin_a',
            name: 'Plugin A',
            version: '1.0.0',
            dependencies: ['plugin_b', 'plugin_c'],
          ),
          'plugin_b': const PluginMetadata(
            id: 'plugin_b',
            name: 'Plugin B',
            version: '1.0.0',
            dependencies: ['plugin_d'],
          ),
          'plugin_c': const PluginMetadata(
            id: 'plugin_c',
            name: 'Plugin C',
            version: '1.0.0',
            dependencies: ['plugin_d'],
          ),
          'plugin_d': const PluginMetadata(
            id: 'plugin_d',
            name: 'Plugin D',
            version: '1.0.0',
            dependencies: [],
          ),
        };

        final result = resolver.resolve(plugins);

        expect(result.isSuccess, true);
        expect(result.loadOrder.indexOf('plugin_d'), lessThan(result.loadOrder.indexOf('plugin_b')));
        expect(result.loadOrder.indexOf('plugin_d'), lessThan(result.loadOrder.indexOf('plugin_c')));
        expect(result.loadOrder.indexOf('plugin_b'), lessThan(result.loadOrder.indexOf('plugin_a')));
        expect(result.loadOrder.indexOf('plugin_c'), lessThan(result.loadOrder.indexOf('plugin_a')));
      });

      test('应该处理独立插件', () {
        final plugins = {
          'plugin_a': const PluginMetadata(
            id: 'plugin_a',
            name: 'Plugin A',
            version: '1.0.0',
            dependencies: [],
          ),
          'plugin_b': const PluginMetadata(
            id: 'plugin_b',
            name: 'Plugin B',
            version: '1.0.0',
            dependencies: [],
          ),
          'plugin_c': const PluginMetadata(
            id: 'plugin_c',
            name: 'Plugin C',
            version: '1.0.0',
            dependencies: [],
          ),
        };

        final result = resolver.resolve(plugins);

        expect(result.isSuccess, true);
        expect(result.loadOrder.length, equals(3));
        expect(result.loadOrder.toSet(), equals({'plugin_a', 'plugin_b', 'plugin_c'}));
      });
    });

    group('detectCycles - 循环依赖检测', () {
      test('应该检测简单循环依赖', () {
        final plugins = {
          'plugin_a': const PluginMetadata(
            id: 'plugin_a',
            name: 'Plugin A',
            version: '1.0.0',
            dependencies: ['plugin_b'],
          ),
          'plugin_b': const PluginMetadata(
            id: 'plugin_b',
            name: 'Plugin B',
            version: '1.0.0',
            dependencies: ['plugin_a'],
          ),
        };

        final cycles = resolver.detectCycles(plugins);

        expect(cycles.isNotEmpty, true);
      });

      test('应该检测更长的循环依赖链', () {
        final plugins = {
          'plugin_a': const PluginMetadata(
            id: 'plugin_a',
            name: 'Plugin A',
            version: '1.0.0',
            dependencies: ['plugin_b'],
          ),
          'plugin_b': const PluginMetadata(
            id: 'plugin_b',
            name: 'Plugin B',
            version: '1.0.0',
            dependencies: ['plugin_c'],
          ),
          'plugin_c': const PluginMetadata(
            id: 'plugin_c',
            name: 'Plugin C',
            version: '1.0.0',
            dependencies: ['plugin_a'],
          ),
        };

        final cycles = resolver.detectCycles(plugins);

        expect(cycles.isNotEmpty, true);
      });

      test('没有循环依赖时应该返回空列表', () {
        final plugins = {
          'plugin_a': const PluginMetadata(
            id: 'plugin_a',
            name: 'Plugin A',
            version: '1.0.0',
            dependencies: ['plugin_b'],
          ),
          'plugin_b': const PluginMetadata(
            id: 'plugin_b',
            name: 'Plugin B',
            version: '1.0.0',
            dependencies: [],
          ),
        };

        final cycles = resolver.detectCycles(plugins);

        expect(cycles, isEmpty);
      });
    });

    group('getTransitiveDependencies - 传递依赖', () {
      test('应该返回所有传递依赖', () {
        final plugins = {
          'plugin_a': const PluginMetadata(
            id: 'plugin_a',
            name: 'Plugin A',
            version: '1.0.0',
            dependencies: ['plugin_b'],
          ),
          'plugin_b': const PluginMetadata(
            id: 'plugin_b',
            name: 'Plugin B',
            version: '1.0.0',
            dependencies: ['plugin_c'],
          ),
          'plugin_c': const PluginMetadata(
            id: 'plugin_c',
            name: 'Plugin C',
            version: '1.0.0',
            dependencies: [],
          ),
        };

        final deps = resolver.getTransitiveDependencies('plugin_a', plugins);

        expect(deps, equals({'plugin_b', 'plugin_c'}));
      });

      test('对于没有依赖的插件应该返回空集合', () {
        final plugins = {
          'plugin_a': const PluginMetadata(
            id: 'plugin_a',
            name: 'Plugin A',
            version: '1.0.0',
            dependencies: [],
          ),
        };

        final deps = resolver.getTransitiveDependencies('plugin_a', plugins);

        expect(deps, isEmpty);
      });

      test('应该优雅地处理缺失的依赖', () {
        final plugins = {
          'plugin_a': const PluginMetadata(
            id: 'plugin_a',
            name: 'Plugin A',
            version: '1.0.0',
            dependencies: ['non_existent'],
          ),
        };

        final deps = resolver.getTransitiveDependencies('plugin_a', plugins);

        expect(deps, equals({'non_existent'}));
      });
    });

    group('getDependents - 获取依赖者', () {
      test('应该返回所有依赖给定插件的插件', () {
        final plugins = {
          'plugin_a': const PluginMetadata(
            id: 'plugin_a',
            name: 'Plugin A',
            version: '1.0.0',
            dependencies: ['plugin_c'],
          ),
          'plugin_b': const PluginMetadata(
            id: 'plugin_b',
            name: 'Plugin B',
            version: '1.0.0',
            dependencies: ['plugin_c'],
          ),
          'plugin_c': const PluginMetadata(
            id: 'plugin_c',
            name: 'Plugin C',
            version: '1.0.0',
            dependencies: [],
          ),
        };

        final dependents = resolver.getDependents('plugin_c', plugins);

        expect(dependents, containsAll(['plugin_a', 'plugin_b']));
      });

      test('对于没有依赖者的插件应该返回空集合', () {
        final plugins = {
          'plugin_a': const PluginMetadata(
            id: 'plugin_a',
            name: 'Plugin A',
            version: '1.0.0',
            dependencies: [],
          ),
        };

        final dependents = resolver.getDependents('plugin_a', plugins);

        expect(dependents, isEmpty);
      });
    });

    group('checkCompatibility - 版本兼容性检查', () {
      test('当所有插件都兼容时应该返回空列表', () {
        final plugins = {
          'plugin_a': const PluginMetadata(
            id: 'plugin_a',
            name: 'Plugin A',
            version: '1.0.0',
            minimumAppVersion: '1.0.0',
          ),
        };

        final incompatible = resolver.checkCompatibility(plugins, '1.0.0');

        expect(incompatible, isEmpty);
      });

      test('应该返回不兼容的插件', () {
        final plugins = {
          'plugin_a': const PluginMetadata(
            id: 'plugin_a',
            name: 'Plugin A',
            version: '1.0.0',
            minimumAppVersion: '2.0.0',
          ),
        };

        final incompatible = resolver.checkCompatibility(plugins, '1.0.0');

        expect(incompatible, contains('plugin_a'));
      });
    });

    group('resolve - 错误处理', () {
      test('应该报告缺失的依赖', () {
        final plugins = {
          'plugin_a': const PluginMetadata(
            id: 'plugin_a',
            name: 'Plugin A',
            version: '1.0.0',
            dependencies: ['non_existent'],
          ),
        };

        final result = resolver.resolve(plugins);

        expect(result.isSuccess, false);
        expect(result.errors.any((e) => e.contains('missing dependency')), true);
      });

      test('应该报告循环依赖', () {
        final plugins = {
          'plugin_a': const PluginMetadata(
            id: 'plugin_a',
            name: 'Plugin A',
            version: '1.0.0',
            dependencies: ['plugin_b'],
          ),
          'plugin_b': const PluginMetadata(
            id: 'plugin_b',
            name: 'Plugin B',
            version: '1.0.0',
            dependencies: ['plugin_a'],
          ),
        };

        final result = resolver.resolve(plugins);

        expect(result.errors.any((e) => e.contains('Circular dependency')), true);
      });
    });
  });
}
