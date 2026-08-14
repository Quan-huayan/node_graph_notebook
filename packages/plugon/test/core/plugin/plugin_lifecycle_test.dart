import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:plugon/core/di.dart';
import 'package:plugon/core/extensions.dart';
import 'package:plugon/core/plugin.dart';

class _EchoService {
  _EchoService(this.owner);
  final String owner;
}

const _toolbar = ExtensionPoint<String>('toolbar');

/// 生命周期可录制、可注入错误的测试插件。
class _LifecyclePlugin extends Plugin {
  _LifecyclePlugin({
    required this.id,
    this.enabledByDefault = true,
    this.loadError,
    this.enableError,
    this.disableError,
    this.registerService = false,
    this.withExtension = false,
  }) : metadata = PluginMetadata(
         id: id,
         name: id,
         version: '1.0.0',
         enabledByDefault: enabledByDefault,
       );

  final String id;
  final bool enabledByDefault;
  final Object? loadError;
  final Object? enableError;
  final Object? disableError;
  final bool registerService;
  final bool withExtension;

  @override
  final PluginMetadata metadata;

  final List<String> calls = [];
  PluginContext? loadedContext;

  @override
  void registerServices(ServiceCollection services) {
    calls.add('registerServices');
    if (registerService) {
      services.addSingleton<_EchoService>((sp) => _EchoService(id));
    }
  }

  @override
  void registerExtensions(ExtensionRegistry registry) {
    calls.add('registerExtensions');
    if (withExtension) {
      registry.registerExtensionPoint(_toolbar);
      registry.addContribution(_toolbar, 'c-$id', ownerPluginId: id);
    }
  }

  @override
  Future<void> onLoad(PluginContext context) async {
    calls.add('onLoad');
    loadedContext = context;
    if (loadError != null) throw loadError!;
  }

  @override
  Future<void> onEnable() async {
    calls.add('onEnable');
    if (enableError != null) throw enableError!;
  }

  @override
  Future<void> onDisable() async {
    calls.add('onDisable');
    if (disableError != null) throw disableError!;
  }

  @override
  Future<void> onUnload() async => calls.add('onUnload');
}

void main() {
  group('PluginManager 生命周期', () {
    test('loadPlugin：owned 视图注册服务 → 注册扩展 → onLoad', () async {
      final manager = PluginManager();
      final plugin = _LifecyclePlugin(
        id: 'p1',
        enabledByDefault: false,
        registerService: true,
      );

      await manager.loadPlugin(plugin);

      expect(plugin.calls, [
        'registerServices',
        'registerExtensions',
        'onLoad',
      ]);
      expect(plugin.loadedContext!.pluginId, 'p1');
      expect(
        manager.services.get<_EchoService>().owner,
        'p1',
        reason: '插件注册的服务 owner 自动盖章为插件 id',
      );
    });

    test('enabledByDefault 的插件在 onLoad 完成后自动启用', () async {
      final manager = PluginManager();
      final plugin = _LifecyclePlugin(id: 'p1');

      await manager.loadPlugin(plugin);

      expect(plugin.calls, [
        'registerServices',
        'registerExtensions',
        'onLoad',
        'onEnable',
      ]);
      expect(manager.getPluginState('p1'), PluginState.enabled);
      expect(manager.enabledPluginIds, contains('p1'));
    });

    test('后加载插件的 context 可解析先加载插件注册的服务', () async {
      final manager = PluginManager();
      final p1 = _LifecyclePlugin(
        id: 'p1',
        enabledByDefault: false,
        registerService: true,
      );
      final p2 = _LifecyclePlugin(id: 'p2', enabledByDefault: false);

      await manager.loadPlugin(p1);
      await manager.loadPlugin(p2);

      expect(p2.loadedContext!.get<_EchoService>().owner, 'p1');
    });

    test(
      'unloadPlugin：onDisable 恰一次 → onUnload → 服务与扩展清理 → 从 manager 移除',
      () async {
        final manager = PluginManager();
        final plugin = _LifecyclePlugin(
          id: 'p1',
          registerService: true,
          withExtension: true,
        );
        await manager.loadPlugin(plugin);
        manager.services.get<_EchoService>(); // 实例化，验证卸载时清理
        expect(manager.extensions.getActive(_toolbar), ['c-p1']);

        await manager.unloadPlugin('p1');

        expect(plugin.calls, [
          'registerServices',
          'registerExtensions',
          'onLoad',
          'onEnable',
          'onDisable',
          'onUnload',
        ], reason: '卸载必须先 onDisable 再 onUnload');
        expect(
          manager.services.tryGet<_EchoService>(),
          isNull,
          reason: '服务描述符与实例被清理',
        );
        expect(
          manager.extensions.getActive(_toolbar),
          isEmpty,
          reason: '扩展贡献被清理',
        );
        expect(manager.pluginIds, isNot(contains('p1')));
        expect(manager.getPluginState('p1'), PluginState.unloaded);
      },
    );

    test('unloadPlugin 对已禁用插件不重复调用 onDisable', () async {
      final manager = PluginManager();
      final plugin = _LifecyclePlugin(id: 'p1');
      await manager.loadPlugin(plugin);
      await manager.disablePlugin('p1');
      plugin.calls.clear();

      await manager.unloadPlugin('p1');

      expect(plugin.calls, ['onUnload'], reason: 'onDisable 不应重复调用');
    });

    test('disablePlugin 调用 onDisable 置 disabled，扩展贡献不再活跃', () async {
      final manager = PluginManager();
      final plugin = _LifecyclePlugin(id: 'p1', withExtension: true);
      await manager.loadPlugin(plugin);
      expect(manager.extensions.getActive(_toolbar), ['c-p1']);

      await manager.disablePlugin('p1');

      expect(plugin.calls.last, 'onDisable');
      expect(manager.getPluginState('p1'), PluginState.disabled);
      expect(manager.enabledPluginIds, isNot(contains('p1')));
      expect(manager.extensions.getActive(_toolbar), isEmpty);
    });

    test('enablePlugin 对 loaded 插件调用 onEnable 置 enabled，贡献恢复活跃', () async {
      final manager = PluginManager();
      final plugin = _LifecyclePlugin(
        id: 'p1',
        enabledByDefault: false,
        withExtension: true,
      );
      await manager.loadPlugin(plugin);

      await manager.enablePlugin('p1');

      expect(plugin.calls.last, 'onEnable');
      expect(manager.getPluginState('p1'), PluginState.enabled);
      expect(manager.extensions.getActive(_toolbar), ['c-p1']);
    });

    test('enablePlugin 幂等——已启用再次启用不重复调用 onEnable', () async {
      final manager = PluginManager();
      final plugin = _LifecyclePlugin(id: 'p1');
      await manager.loadPlugin(plugin);
      plugin.calls.clear();

      await manager.enablePlugin('p1');

      expect(plugin.calls, isEmpty);
      expect(manager.getPluginState('p1'), PluginState.enabled);
    });

    test('onLoad 抛错：记录 lastError、重抛、从 map 移除以便重试', () async {
      final manager = PluginManager();
      final plugin = _LifecyclePlugin(id: 'p1', loadError: StateError('boom'));

      await expectLater(manager.loadPlugin(plugin), throwsStateError);

      expect(manager.pluginIds, isEmpty, reason: '失败不残留');
      expect(manager.lastError('p1'), isA<StateError>());

      final retry = _LifecyclePlugin(id: 'p1', enabledByDefault: false);
      await manager.loadPlugin(retry);
      expect(manager.pluginIds, contains('p1'), reason: '可重试加载');
    });

    test('onEnable 抛错：置 error 状态、重抛、插件保持已加载', () async {
      final manager = PluginManager();
      final plugin = _LifecyclePlugin(
        id: 'p1',
        enabledByDefault: false,
        enableError: StateError('enable-boom'),
      );
      await manager.loadPlugin(plugin);

      await expectLater(manager.enablePlugin('p1'), throwsStateError);

      expect(manager.getPluginState('p1'), PluginState.error);
      expect(manager.lastError('p1'), isA<StateError>());
      expect(manager.pluginIds, contains('p1'));
    });

    test('onDisable 抛错：清理继续完成，unloadPlugin 最终重抛并记录错误', () async {
      final manager = PluginManager();
      final plugin = _LifecyclePlugin(
        id: 'p1',
        registerService: true,
        disableError: StateError('disable-boom'),
      );
      await manager.loadPlugin(plugin); // 自动启用
      manager.services.get<_EchoService>();

      await expectLater(manager.unloadPlugin('p1'), throwsStateError);

      expect(plugin.calls, contains('onUnload'), reason: '卸载继续执行');
      expect(manager.services.tryGet<_EchoService>(), isNull, reason: '清理仍完成');
      expect(manager.pluginIds, isEmpty);
      expect(manager.lastError('p1'), isA<StateError>());
    });

    test('顺序重复 loadPlugin 抛 PluginAlreadyLoadedException', () async {
      final manager = PluginManager();
      final plugin = _LifecyclePlugin(id: 'p1', enabledByDefault: false);

      await manager.loadPlugin(plugin);
      await expectLater(
        manager.loadPlugin(_LifecyclePlugin(id: 'p1')),
        throwsA(isA<PluginAlreadyLoadedException>()),
      );
    });

    test('并发 loadPlugin：第二个立即抛异常，onLoad 恰执行一次', () async {
      final manager = PluginManager();
      final gate = Completer<void>();
      final plugin = _BlockingPlugin('p1', gate);

      final f1 = manager.loadPlugin(plugin);
      final f2 = manager.loadPlugin(plugin);
      await expectLater(f2, throwsA(isA<PluginAlreadyLoadedException>()));

      gate.complete();
      await f1;
      expect(plugin.onLoadCalls, 1, reason: '并发下 onLoad 只执行一次');
    });

    test('dispose 卸载全部插件并清理', () async {
      final manager = PluginManager();
      final p1 = _LifecyclePlugin(id: 'p1', withExtension: true);
      final p2 = _LifecyclePlugin(id: 'p2', registerService: true);
      await manager.loadPlugin(p1);
      await manager.loadPlugin(p2);
      manager.services.get<_EchoService>();

      await manager.dispose();

      expect(manager.pluginCount, 0);
      expect(p1.calls, contains('onDisable'));
      expect(p1.calls, contains('onUnload'));
      expect(p2.calls, contains('onUnload'));
      expect(manager.services.tryGet<_EchoService>(), isNull);
    });
  });
}

/// 门控 onLoad 的插件，用于并发加载测试。
class _BlockingPlugin extends Plugin {
  _BlockingPlugin(this.id, this.gate)
    : metadata = PluginMetadata(id: id, name: id, version: '1.0.0');

  final String id;
  final Completer<void> gate;

  @override
  final PluginMetadata metadata;

  int onLoadCalls = 0;

  @override
  Future<void> onLoad(PluginContext context) async {
    onLoadCalls++;
    await gate.future;
  }
}
