import 'package:flutter_test/flutter_test.dart';
import 'package:plugon/core/plugin.dart';

/// 依赖测试插件：跨插件共享日志记录启用/停用/卸载顺序。
class _DepPlugin extends Plugin {
  _DepPlugin(this.id, {this.deps = const [], this.failOnDisable = false});

  final String id;
  final List<String> deps;
  final bool failOnDisable;

  static final List<String> log = [];

  @override
  PluginMetadata get metadata => PluginMetadata(
    id: id,
    name: id,
    version: '1.0.0',
    dependencies: deps,
    enabledByDefault: false,
  );

  @override
  Future<void> onEnable() async => log.add('enable:$id');

  @override
  Future<void> onDisable() async {
    log.add('disable:$id');
    if (failOnDisable) throw StateError('disable-fail:$id');
  }

  @override
  Future<void> onUnload() async => log.add('unload:$id');
}

void main() {
  setUp(_DepPlugin.log.clear);

  group('依赖编排', () {
    test('传递依赖按拓扑序先启用（依赖的 onEnable 先于依赖方）', () async {
      final manager = PluginManager();
      final a = _DepPlugin('a', deps: ['b']);
      final b = _DepPlugin('b', deps: ['c']);
      final c = _DepPlugin('c');
      await manager.loadPlugin(a);
      await manager.loadPlugin(b);
      await manager.loadPlugin(c);

      await manager.enablePlugin('a');

      expect(_DepPlugin.log, ['enable:c', 'enable:b', 'enable:a']);
      expect(manager.enabledPluginIds, {'a', 'b', 'c'});
    });

    test('依赖缺失抛 PluginDependencyException', () async {
      final manager = PluginManager();
      final a = _DepPlugin('a', deps: ['missing']);
      await manager.loadPlugin(a);

      await expectLater(
        manager.enablePlugin('a'),
        throwsA(
          isA<PluginDependencyException>()
              .having((e) => e.pluginId, 'pluginId', 'a')
              .having((e) => e.dependencyId, 'dependencyId', 'missing'),
        ),
      );
      expect(manager.getPluginState('a'), PluginState.loaded);
    });

    test('直接循环依赖 A↔B 抛 PluginDependencyCycleException 并终止', () async {
      final manager = PluginManager();
      final a = _DepPlugin('a', deps: ['b']);
      final b = _DepPlugin('b', deps: ['a']);
      await manager.loadPlugin(a);
      await manager.loadPlugin(b);

      await expectLater(
        manager.enablePlugin('a'),
        throwsA(isA<PluginDependencyCycleException>()),
      );
      expect(
        manager.getPluginState('a'),
        PluginState.loaded,
        reason: '循环在启用任何节点前被检测到',
      );
      expect(manager.getPluginState('b'), PluginState.loaded);
    });

    test('自依赖抛 PluginDependencyCycleException', () async {
      final manager = PluginManager();
      final a = _DepPlugin('a', deps: ['a']);
      await manager.loadPlugin(a);

      await expectLater(
        manager.enablePlugin('a'),
        throwsA(isA<PluginDependencyCycleException>()),
      );
    });

    test('传递循环 A→B→A 抛 PluginDependencyCycleException', () async {
      final manager = PluginManager();
      final a = _DepPlugin('a', deps: ['b']);
      final b = _DepPlugin('b', deps: ['c']);
      final c = _DepPlugin('c', deps: ['a']);
      await manager.loadPlugin(a);
      await manager.loadPlugin(b);
      await manager.loadPlugin(c);

      await expectLater(
        manager.enablePlugin('a'),
        throwsA(isA<PluginDependencyCycleException>()),
      );
    });

    test('加载顺序无关：先加载依赖方后加载依赖也能启用', () async {
      final manager = PluginManager();
      final a = _DepPlugin('a', deps: ['b']);
      final b = _DepPlugin('b');
      // 先加载依赖方 a，后加载依赖 b
      await manager.loadPlugin(a);
      await manager.loadPlugin(b);

      await manager.enablePlugin('a');

      expect(_DepPlugin.log, ['enable:b', 'enable:a']);
    });

    test('卸载依赖方时先卸载其依赖者（逆拓扑）', () async {
      final manager = PluginManager();
      final a = _DepPlugin('a', deps: ['b']);
      final b = _DepPlugin('b');
      await manager.loadPlugin(a);
      await manager.loadPlugin(b);
      await manager.enablePlugin('a');

      await manager.unloadPlugin('b');

      expect(_DepPlugin.log, [
        'enable:b',
        'enable:a',
        'disable:a',
        'unload:a',
        'disable:b',
        'unload:b',
      ], reason: '依赖者 a 必须先于依赖 b 卸载');
      expect(manager.pluginIds, isEmpty);
    });

    test('依赖者已先卸载时不重复卸载依赖', () async {
      final manager = PluginManager();
      final a = _DepPlugin('a', deps: ['b']);
      final b = _DepPlugin('b');
      await manager.loadPlugin(a);
      await manager.loadPlugin(b);
      await manager.enablePlugin('a');
      _DepPlugin.log.clear();

      await manager.unloadPlugin('a');
      await manager.unloadPlugin('b');
      await manager.unloadPlugin('a'); // 已卸载，无操作

      expect(_DepPlugin.log, [
        'disable:a',
        'unload:a',
        'disable:b',
        'unload:b',
      ]);
    });

    test('dispose 逆拓扑卸载全部并重抛首个错误', () async {
      final manager = PluginManager();
      final a = _DepPlugin('a', deps: ['b']);
      final b = _DepPlugin('b', failOnDisable: true);
      await manager.loadPlugin(a);
      await manager.loadPlugin(b);
      await manager.enablePlugin('a');

      await expectLater(manager.dispose(), throwsStateError);

      expect(manager.pluginCount, 0, reason: '错误不阻断清理');
      expect(manager.lastError('b'), isA<StateError>());
      expect(_DepPlugin.log, contains('unload:a'));
      expect(_DepPlugin.log, contains('unload:b'));
    });
  });
}
