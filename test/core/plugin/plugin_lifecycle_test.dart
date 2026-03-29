import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/commands/command_bus.dart';
import 'package:node_graph_notebook/core/plugin/plugin.dart';

class TestPlugin extends Plugin {
  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: 'test_plugin',
        name: '测试插件',
        version: '1.0.0',
        description: '用于生命周期测试的测试插件',
        author: '测试作者',
        dependencies: [],
        apiDependencies: [],
      );

  PluginState _state = PluginState.unloaded;

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  @override
  Future<void> onLoad(PluginContext context) async {}

  @override
  Future<void> onEnable() async {}

  @override
  Future<void> onDisable() async {}

  @override
  Future<void> onUnload() async {}
}

class FailingOnLoadPlugin extends Plugin {
  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: 'failing_plugin',
        name: '加载失败插件',
        version: '1.0.0',
        description: '在加载时失败的插件',
        author: '测试作者',
        dependencies: [],
        apiDependencies: [],
      );

  PluginState _state = PluginState.unloaded;
  late PluginContext context;

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  @override
  Future<void> onLoad(PluginContext ctx) async {
    context = ctx;
    throw Exception('Load failed');
  }

  @override
  Future<void> onEnable() async {}

  @override
  Future<void> onDisable() async {}

  @override
  Future<void> onUnload() async {}
}

class FailingOnEnablePlugin extends Plugin {
  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: 'failing_enable_plugin',
        name: '启用失败插件',
        version: '1.0.0',
        description: '在启用时失败的插件',
        author: '测试作者',
        dependencies: [],
        apiDependencies: [],
      );

  PluginState _state = PluginState.unloaded;

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  @override
  Future<void> onLoad(PluginContext context) async {}

  @override
  Future<void> onEnable() async {
    throw Exception('Enable failed');
  }

  @override
  Future<void> onDisable() async {}

  @override
  Future<void> onUnload() async {}
}

void main() {
  group('PluginLifecycleManager', () {
    late PluginLifecycleManager lifecycle;
    late TestPlugin plugin;

    setUp(() {
      plugin = TestPlugin();
      lifecycle = PluginLifecycleManager(plugin);
    });

    group('initial state', () {
      test('应该以未加载状态开始', () {
        expect(lifecycle.state, PluginState.unloaded);
      });
    });

    group('canTransitionTo - 状态转换验证', () {
      test('应该允许从未加载状态转换到已加载状态', () {
        expect(lifecycle.canTransitionTo(PluginState.loaded), true);
      });

      test('应该允许从未加载状态转换到加载失败状态', () {
        expect(lifecycle.canTransitionTo(PluginState.loadFailed), true);
      });

      test('不应该允许从未加载状态转换到已启用状态', () {
        expect(lifecycle.canTransitionTo(PluginState.enabled), false);
      });

      test('不应该允许从未加载状态转换到已禁用状态', () {
        expect(lifecycle.canTransitionTo(PluginState.disabled), false);
      });
    });

    group('canTransitionTo - loaded state', () {
      setUp(() async {
        await lifecycle.transitionTo(PluginState.loaded, () async {});
      });

      test('应该允许从已加载状态转换到已启用状态', () {
        expect(lifecycle.canTransitionTo(PluginState.enabled), true);
      });

      test('应该允许从已加载状态转换到已禁用状态', () {
        expect(lifecycle.canTransitionTo(PluginState.disabled), true);
      });

      test('应该允许从已加载状态转换到未加载状态', () {
        expect(lifecycle.canTransitionTo(PluginState.unloaded), true);
      });

      test('不应该允许从已加载状态转换到已加载状态', () {
        expect(lifecycle.canTransitionTo(PluginState.loaded), false);
      });
    });

    group('canTransitionTo - enabled state', () {
      setUp(() async {
        await lifecycle.transitionTo(PluginState.loaded, () async {});
        await lifecycle.transitionTo(PluginState.enabled, () async {});
      });

      test('应该允许从已启用状态转换到已禁用状态', () {
        expect(lifecycle.canTransitionTo(PluginState.disabled), true);
      });

      test('应该允许从已启用状态转换到未加载状态', () {
        expect(lifecycle.canTransitionTo(PluginState.unloaded), true);
      });

      test('不应该允许从已启用状态转换到已加载状态', () {
        expect(lifecycle.canTransitionTo(PluginState.loaded), false);
      });
    });

    group('canTransitionTo - disabled state', () {
      setUp(() async {
        await lifecycle.transitionTo(PluginState.loaded, () async {});
        await lifecycle.transitionTo(PluginState.enabled, () async {});
        await lifecycle.transitionTo(PluginState.disabled, () async {});
      });

      test('应该允许从已禁用状态转换到已启用状态', () {
        expect(lifecycle.canTransitionTo(PluginState.enabled), true);
      });

      test('应该允许从已禁用状态转换到未加载状态', () {
        expect(lifecycle.canTransitionTo(PluginState.unloaded), true);
      });
    });

    group('canTransitionTo - failed states', () {
      test('应该允许从加载失败状态转换到未加载状态', () async {
        final failingPlugin = FailingOnLoadPlugin();
        final failingLifecycle = PluginLifecycleManager(failingPlugin);

        try {
          await failingLifecycle.transitionTo(
            PluginState.loaded,
            () async {
              // 创建一个 mock context 传递给 onLoad
              final mockContext = PluginContext(
                pluginId: failingPlugin.metadata.id,
                commandBus: CommandBus(),
              );
              await failingPlugin.onLoad(mockContext);
            },
          );
        } catch (e) {
          // 预期内的异常
        }

        expect(failingLifecycle.state, PluginState.loadFailed);
        expect(failingLifecycle.canTransitionTo(PluginState.unloaded), true);
      });

      test('应该允许从启用失败状态转换到未加载状态', () async {
        final failingPlugin = FailingOnEnablePlugin();
        final failingLifecycle = PluginLifecycleManager(failingPlugin);

        await failingLifecycle.transitionTo(PluginState.loaded, () async {});

        try {
          await failingLifecycle.transitionTo(
            PluginState.enabled,
            failingPlugin.onEnable,
          );
        } catch (e) {
          // 预期内的异常
        }

        expect(failingLifecycle.state, PluginState.enableFailed);
        expect(failingLifecycle.canTransitionTo(PluginState.unloaded), true);
      });
    });

    group('transitionTo - 状态转换执行', () {
      test('应该在成功转换时更新状态', () async {
        await lifecycle.transitionTo(PluginState.loaded, () async {});

        expect(lifecycle.state, PluginState.loaded);
        expect(plugin.state, PluginState.loaded);
      });

      test('应该在无效转换时抛出异常', () async {
        expect(
          () => lifecycle.transitionTo(PluginState.enabled, () async {}),
          throwsA(isA<PluginStateException>()),
        );
      });

      test('应该在加载失败时设置为加载失败状态', () async {
        final failingPlugin = FailingOnLoadPlugin();
        final failingLifecycle = PluginLifecycleManager(failingPlugin);

        // 使用 try-catch 来捕获异常，然后验证状态
        try {
          await failingLifecycle.transitionTo(
            PluginState.loaded,
            () async {
              // 创建一个 mock context 传递给 onLoad
              final mockContext = PluginContext(
                pluginId: failingPlugin.metadata.id,
                commandBus: CommandBus(),
              );
              await failingPlugin.onLoad(mockContext);
            },
          );
          fail('预期会抛出异常');
        } catch (e) {
          // 预期内的异常
        }

        expect(failingLifecycle.state, PluginState.loadFailed);
        expect(failingPlugin.state, PluginState.loadFailed);
      });

      test('应该在启用失败时设置为启用失败状态', () async {
        final failingPlugin = FailingOnEnablePlugin();
        final failingLifecycle = PluginLifecycleManager(failingPlugin);

        await failingLifecycle.transitionTo(PluginState.loaded, () async {});

        // 使用 try-catch 来捕获异常，然后验证状态
        try {
          await failingLifecycle.transitionTo(
            PluginState.enabled,
            failingPlugin.onEnable,
          );
          fail('预期会抛出异常');
        } catch (e) {
          // 预期内的异常
        }

        expect(failingLifecycle.state, PluginState.enableFailed);
        expect(failingPlugin.state, PluginState.enableFailed);
      });
    });

    group('listeners - 状态监听', () {
      test('应该在状态变化时通知监听器', () async {
        PluginState? oldState;
        PluginState? newState;
        Plugin? notifiedPlugin;

        lifecycle.addListener((plugin, old, newS) {
          notifiedPlugin = plugin;
          oldState = old;
          newState = newS;
        });

        await lifecycle.transitionTo(PluginState.loaded, () async {});

        expect(notifiedPlugin, same(plugin));
        expect(oldState, PluginState.unloaded);
        expect(newState, PluginState.loaded);
      });

      test('应该在失败时通知监听器', () async {
        final failingPlugin = FailingOnLoadPlugin();
        final failingLifecycle = PluginLifecycleManager(failingPlugin);

        PluginState? notifiedState;

        failingLifecycle.addListener((plugin, old, newS) {
          notifiedState = newS;
        });

        try {
          await failingLifecycle.transitionTo(
            PluginState.loaded,
            () async {
              // 创建一个 mock context 传递给 onLoad
              final mockContext = PluginContext(
                pluginId: failingPlugin.metadata.id,
                commandBus: CommandBus(),
              );
              await failingPlugin.onLoad(mockContext);
            },
          );
        } catch (e) {
          // 预期内的异常
        }

        expect(notifiedState, PluginState.loadFailed);
      });

      test('应该优雅地处理监听器异常', () async {
        lifecycle.addListener((plugin, old, newS) {
          throw Exception('监听器错误');
        });

        var secondListenerCalled = false;
        lifecycle.addListener((plugin, old, newS) {
          secondListenerCalled = true;
        });

        await lifecycle.transitionTo(PluginState.loaded, () async {});

        expect(secondListenerCalled, true);
      });
    });
  });

  group('PluginWrapper', () {
    late PluginWrapper wrapper;
    late TestPlugin plugin;
    late PluginContext context;
    late PluginLifecycleManager lifecycle;

    setUp(() {
      plugin = TestPlugin();
      lifecycle = PluginLifecycleManager(plugin);
      final commandBus = CommandBus();
      context = PluginContext(
        pluginId: 'test_plugin',
        commandBus: commandBus,
      );
      wrapper = PluginWrapper(plugin, context, lifecycle);
    });

    test('应该提供元数据快捷访问', () {
      expect(wrapper.metadata.id, 'test_plugin');
      expect(wrapper.metadata.name, '测试插件');
    });

    test('应该提供状态快捷访问', () async {
      await lifecycle.transitionTo(PluginState.loaded, () async {});

      expect(wrapper.state, PluginState.loaded);
    });

    test('应该正确报告isLoaded状态', () async {
      expect(wrapper.isLoaded, false);

      await lifecycle.transitionTo(PluginState.loaded, () async {});
      expect(wrapper.isLoaded, true);

      await lifecycle.transitionTo(PluginState.enabled, () async {});
      expect(wrapper.isLoaded, true);
    });

    test('应该正确报告isEnabled状态', () async {
      expect(wrapper.isEnabled, false);

      await lifecycle.transitionTo(PluginState.loaded, () async {});
      expect(wrapper.isEnabled, false);

      await lifecycle.transitionTo(PluginState.enabled, () async {});
      expect(wrapper.isEnabled, true);
    });
  });
}
