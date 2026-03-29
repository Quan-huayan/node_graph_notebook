import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/plugin/dependency_resolver.dart';
import 'package:node_graph_notebook/core/plugin/plugin.dart';

/// 插件依赖集成测试
///
/// 测试插件依赖解析、循环依赖检测、传递依赖等复杂场景
void main() {
  group('Plugin Dependency Integration Tests', () {
    late DependencyResolver resolver;

    setUp(() {
      resolver = DependencyResolver();
    });

    group('复杂依赖图测试', () {
      test('should resolve diamond dependency pattern', () {
        // 菱形依赖: A -> B -> D, A -> C -> D
        final plugins = {
          'A': const PluginMetadata(
            id: 'A',
            name: 'Plugin A',
            version: '1.0.0',
            description: 'Depends on B and C',
            author: 'Test',
            dependencies: ['B', 'C'],
            apiDependencies: [],
          ),
          'B': const PluginMetadata(
            id: 'B',
            name: 'Plugin B',
            version: '1.0.0',
            description: 'Depends on D',
            author: 'Test',
            dependencies: ['D'],
            apiDependencies: [],
          ),
          'C': const PluginMetadata(
            id: 'C',
            name: 'Plugin C',
            version: '1.0.0',
            description: 'Depends on D',
            author: 'Test',
            dependencies: ['D'],
            apiDependencies: [],
          ),
          'D': const PluginMetadata(
            id: 'D',
            name: 'Plugin D',
            version: '1.0.0',
            description: 'Base plugin',
            author: 'Test',
            dependencies: [],
            apiDependencies: [],
          ),
        };

        final result = resolver.resolve(plugins);

        expect(result.isSuccess, true);
        expect(result.loadOrder.first, 'D'); // D 应该最先加载
        expect(result.loadOrder.last, 'A'); // A 应该最后加载

        // 验证 D 在 B 和 C 之前
        final dIndex = result.loadOrder.indexOf('D');
        final bIndex = result.loadOrder.indexOf('B');
        final cIndex = result.loadOrder.indexOf('C');
        expect(dIndex, lessThan(bIndex));
        expect(dIndex, lessThan(cIndex));
      });

      test('should resolve deep dependency chain', () {
        // 长链: A -> B -> C -> D -> E
        final plugins = {
          'A': const PluginMetadata(
            id: 'A',
            name: 'Plugin A',
            version: '1.0.0',
            description: 'Top level',
            author: 'Test',
            dependencies: ['B'],
            apiDependencies: [],
          ),
          'B': const PluginMetadata(
            id: 'B',
            name: 'Plugin B',
            version: '1.0.0',
            description: 'Depends on C',
            author: 'Test',
            dependencies: ['C'],
            apiDependencies: [],
          ),
          'C': const PluginMetadata(
            id: 'C',
            name: 'Plugin C',
            version: '1.0.0',
            description: 'Depends on D',
            author: 'Test',
            dependencies: ['D'],
            apiDependencies: [],
          ),
          'D': const PluginMetadata(
            id: 'D',
            name: 'Plugin D',
            version: '1.0.0',
            description: 'Depends on E',
            author: 'Test',
            dependencies: ['E'],
            apiDependencies: [],
          ),
          'E': const PluginMetadata(
            id: 'E',
            name: 'Plugin E',
            version: '1.0.0',
            description: 'Base',
            author: 'Test',
            dependencies: [],
            apiDependencies: [],
          ),
        };

        final result = resolver.resolve(plugins);

        expect(result.isSuccess, true);
        expect(result.loadOrder, ['E', 'D', 'C', 'B', 'A']);
      });

      test('should resolve multiple independent trees', () {
        // 两个独立的树
        final plugins = {
          'A1': const PluginMetadata(
            id: 'A1',
            name: 'Tree 1 Root',
            version: '1.0.0',
            description: '',
            author: 'Test',
            dependencies: ['B1'],
            apiDependencies: [],
          ),
          'B1': const PluginMetadata(
            id: 'B1',
            name: 'Tree 1 Child',
            version: '1.0.0',
            description: '',
            author: 'Test',
            dependencies: [],
            apiDependencies: [],
          ),
          'A2': const PluginMetadata(
            id: 'A2',
            name: 'Tree 2 Root',
            version: '1.0.0',
            description: '',
            author: 'Test',
            dependencies: ['B2'],
            apiDependencies: [],
          ),
          'B2': const PluginMetadata(
            id: 'B2',
            name: 'Tree 2 Child',
            version: '1.0.0',
            description: '',
            author: 'Test',
            dependencies: [],
            apiDependencies: [],
          ),
        };

        final result = resolver.resolve(plugins);

        expect(result.isSuccess, true);
        expect(result.loadOrder.length, 4);
        // B1 和 B2 应该在 A1 和 A2 之前
        final b1Index = result.loadOrder.indexOf('B1');
        final a1Index = result.loadOrder.indexOf('A1');
        final b2Index = result.loadOrder.indexOf('B2');
        final a2Index = result.loadOrder.indexOf('A2');
        expect(b1Index, lessThan(a1Index));
        expect(b2Index, lessThan(a2Index));
      });
    });

    group('循环依赖检测测试', () {
      test('should detect simple two-node cycle', () {
        final plugins = {
          'A': const PluginMetadata(
            id: 'A',
            name: 'Plugin A',
            version: '1.0.0',
            description: '',
            author: 'Test',
            dependencies: ['B'],
            apiDependencies: [],
          ),
          'B': const PluginMetadata(
            id: 'B',
            name: 'Plugin B',
            version: '1.0.0',
            description: '',
            author: 'Test',
            dependencies: ['A'],
            apiDependencies: [],
          ),
        };

        final result = resolver.resolve(plugins);

        expect(result.isSuccess, false);
        expect(result.errors.length, greaterThan(0));
        expect(result.errors[0], contains('Circular dependency'));
      });

      test('should detect long cycle', () {
        // 长循环: A -> B -> C -> D -> E -> A
        final plugins = {
          'A': const PluginMetadata(
            id: 'A',
            name: 'Plugin A',
            version: '1.0.0',
            description: '',
            author: 'Test',
            dependencies: ['B'],
            apiDependencies: [],
          ),
          'B': const PluginMetadata(
            id: 'B',
            name: 'Plugin B',
            version: '1.0.0',
            description: '',
            author: 'Test',
            dependencies: ['C'],
            apiDependencies: [],
          ),
          'C': const PluginMetadata(
            id: 'C',
            name: 'Plugin C',
            version: '1.0.0',
            description: '',
            author: 'Test',
            dependencies: ['D'],
            apiDependencies: [],
          ),
          'D': const PluginMetadata(
            id: 'D',
            name: 'Plugin D',
            version: '1.0.0',
            description: '',
            author: 'Test',
            dependencies: ['E'],
            apiDependencies: [],
          ),
          'E': const PluginMetadata(
            id: 'E',
            name: 'Plugin E',
            version: '1.0.0',
            description: '',
            author: 'Test',
            dependencies: ['A'],
            apiDependencies: [],
          ),
        };

        final result = resolver.resolve(plugins);

        expect(result.isSuccess, false);
        expect(result.errors.any((e) => e.contains('Circular dependency')), true);
      });

      test('should detect self-dependency', () {
        final plugins = {
          'A': const PluginMetadata(
            id: 'A',
            name: 'Plugin A',
            version: '1.0.0',
            description: '',
            author: 'Test',
            dependencies: ['A'],
            apiDependencies: [],
          ),
        };

        final result = resolver.resolve(plugins);

        expect(result.isSuccess, false);
        expect(result.errors.any((e) => e.contains('Circular dependency')), true);
      });

      test('should detect all cycles in complex graph', () {
        // 复杂图包含多个循环
        final plugins = {
          'A': const PluginMetadata(
            id: 'A',
            name: 'Plugin A',
            version: '1.0.0',
            description: '',
            author: 'Test',
            dependencies: ['B'],
            apiDependencies: [],
          ),
          'B': const PluginMetadata(
            id: 'B',
            name: 'Plugin B',
            version: '1.0.0',
            description: '',
            author: 'Test',
            dependencies: ['C', 'D'],
            apiDependencies: [],
          ),
          'C': const PluginMetadata(
            id: 'C',
            name: 'Plugin C',
            version: '1.0.0',
            description: '',
            author: 'Test',
            dependencies: ['A'], // 循环: A -> B -> C -> A
            apiDependencies: [],
          ),
          'D': const PluginMetadata(
            id: 'D',
            name: 'Plugin D',
            version: '1.0.0',
            description: '',
            author: 'Test',
            dependencies: ['E'],
            apiDependencies: [],
          ),
          'E': const PluginMetadata(
            id: 'E',
            name: 'Plugin E',
            version: '1.0.0',
            description: '',
            author: 'Test',
            dependencies: ['B'], // 循环: B -> D -> E -> B
            apiDependencies: [],
          ),
        };

        final cycles = resolver.detectCycles(plugins);

        expect(cycles.length, greaterThanOrEqualTo(1));
      });
    });

    group('传递依赖测试', () {
      test('should calculate transitive dependencies', () {
        // A -> B -> C -> D
        final plugins = {
          'A': const PluginMetadata(
            id: 'A',
            name: 'Plugin A',
            version: '1.0.0',
            description: '',
            author: 'Test',
            dependencies: ['B'],
            apiDependencies: [],
          ),
          'B': const PluginMetadata(
            id: 'B',
            name: 'Plugin B',
            version: '1.0.0',
            description: '',
            author: 'Test',
            dependencies: ['C'],
            apiDependencies: [],
          ),
          'C': const PluginMetadata(
            id: 'C',
            name: 'Plugin C',
            version: '1.0.0',
            description: '',
            author: 'Test',
            dependencies: ['D'],
            apiDependencies: [],
          ),
          'D': const PluginMetadata(
            id: 'D',
            name: 'Plugin D',
            version: '1.0.0',
            description: '',
            author: 'Test',
            dependencies: [],
            apiDependencies: [],
          ),
        };

        final transitiveDeps = resolver.getTransitiveDependencies('A', plugins);

        expect(transitiveDeps, contains('B'));
        expect(transitiveDeps, contains('C'));
        expect(transitiveDeps, contains('D'));
        expect(transitiveDeps.length, 3);
      });

      test('should find all dependents', () {
        // D 被 C 和 E 依赖，C 被 B 依赖，B 被 A 依赖
        final plugins = {
          'A': const PluginMetadata(
            id: 'A',
            name: 'Plugin A',
            version: '1.0.0',
            description: '',
            author: 'Test',
            dependencies: ['B'],
            apiDependencies: [],
          ),
          'B': const PluginMetadata(
            id: 'B',
            name: 'Plugin B',
            version: '1.0.0',
            description: '',
            author: 'Test',
            dependencies: ['C'],
            apiDependencies: [],
          ),
          'C': const PluginMetadata(
            id: 'C',
            name: 'Plugin C',
            version: '1.0.0',
            description: '',
            author: 'Test',
            dependencies: ['D'],
            apiDependencies: [],
          ),
          'D': const PluginMetadata(
            id: 'D',
            name: 'Plugin D',
            version: '1.0.0',
            description: '',
            author: 'Test',
            dependencies: [],
            apiDependencies: [],
          ),
          'E': const PluginMetadata(
            id: 'E',
            name: 'Plugin E',
            version: '1.0.0',
            description: '',
            author: 'Test',
            dependencies: ['D'],
            apiDependencies: [],
          ),
        };

        final dependents = resolver.getDependents('D', plugins);

        expect(dependents, contains('C'));
        expect(dependents, contains('E'));
        expect(dependents, contains('B'));
        expect(dependents, contains('A'));
      });
    });

    group('缺失依赖处理测试', () {
      test('should report missing dependencies', () {
        final plugins = {
          'A': const PluginMetadata(
            id: 'A',
            name: 'Plugin A',
            version: '1.0.0',
            description: '',
            author: 'Test',
            dependencies: ['B', 'C'], // C 不存在
            apiDependencies: [],
          ),
          'B': const PluginMetadata(
            id: 'B',
            name: 'Plugin B',
            version: '1.0.0',
            description: '',
            author: 'Test',
            dependencies: [],
            apiDependencies: [],
          ),
        };

        final result = resolver.resolve(plugins);

        expect(result.isSuccess, false);
        expect(result.errors.any((e) => e.contains('missing dependency')), true);
      });

      test('should handle empty dependency list', () {
        final plugins = {
          'A': const PluginMetadata(
            id: 'A',
            name: 'Plugin A',
            version: '1.0.0',
            description: '',
            author: 'Test',
            dependencies: [],
            apiDependencies: [],
          ),
        };

        final result = resolver.resolve(plugins);

        expect(result.isSuccess, true);
        expect(result.loadOrder, ['A']);
      });
    });

    group('加载顺序测试', () {
      test('should resolve load order for plugin instances', () {
        final plugins = [
          _TestPlugin(id: 'A', dependencies: ['B']),
          _TestPlugin(id: 'B', dependencies: ['C']),
          _TestPlugin(id: 'C', dependencies: []),
        ];

        final ordered = resolver.resolveLoadOrder(plugins);

        expect(ordered.length, 3);
        expect(ordered[0].metadata.id, 'C');
        expect(ordered[1].metadata.id, 'B');
        expect(ordered[2].metadata.id, 'A');
      });

      test('should resolve unload order (reverse of load)', () {
        final plugins = [
          _TestPlugin(id: 'A', dependencies: ['B']),
          _TestPlugin(id: 'B', dependencies: ['C']),
          _TestPlugin(id: 'C', dependencies: []),
        ];

        final unloadOrder = resolver.resolveUnloadOrder(plugins);

        expect(unloadOrder.length, 3);
        expect(unloadOrder[0].metadata.id, 'A');
        expect(unloadOrder[1].metadata.id, 'B');
        expect(unloadOrder[2].metadata.id, 'C');
      });
    });

    group('版本兼容性测试', () {
      test('should check version compatibility', () {
        // 使用 PluginMetadata 的 isCompatibleWith 方法测试兼容性
        final compatiblePlugin = const PluginMetadata(
          id: 'compatible',
          name: 'Compatible',
          version: '1.0.0',
          minimumAppVersion: '1.0.0',
        );

        final incompatiblePlugin = const PluginMetadata(
          id: 'incompatible',
          name: 'Incompatible',
          version: '1.0.0',
          minimumAppVersion: '2.0.0',
        );

        expect(compatiblePlugin.isCompatibleWith('1.5.0'), true);
        expect(incompatiblePlugin.isCompatibleWith('1.5.0'), false);
      });
    });
  });
}

/// 测试用的简单插件实现
class _TestPlugin extends Plugin {
  _TestPlugin({required this.id, required this.dependencies});

  final String id;
  final List<String> dependencies;
  PluginState _state = PluginState.unloaded;

  @override
  PluginMetadata get metadata => PluginMetadata(
        id: id,
        name: 'Test Plugin $id',
        version: '1.0.0',
        description: 'Test plugin',
        author: 'Test',
        dependencies: dependencies,
        apiDependencies: const [],
      );

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) => _state = newState;

  @override
  Future<void> onLoad(PluginContext context) async {}

  @override
  Future<void> onEnable() async {}

  @override
  Future<void> onDisable() async {}

  @override
  Future<void> onUnload() async {}
}
