import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/commands/command_bus.dart';
import 'package:node_graph_notebook/core/plugin/plugin.dart';

class TestPlugin extends Plugin {
  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: 'test_plugin',
        name: 'Test Plugin',
        version: '1.0.0',
        description: 'Test plugin for lifecycle testing',
        author: 'Test Author',
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
        name: 'Failing Plugin',
        version: '1.0.0',
        description: 'Plugin that fails on load',
        author: 'Test Author',
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
        name: 'Failing Enable Plugin',
        version: '1.0.0',
        description: 'Plugin that fails on enable',
        author: 'Test Author',
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
      test('should start in unloaded state', () {
        expect(lifecycle.state, PluginState.unloaded);
      });
    });

    group('canTransitionTo - 状态转换验证', () {
      test('should allow transition from unloaded to loaded', () {
        expect(lifecycle.canTransitionTo(PluginState.loaded), true);
      });

      test('should allow transition from unloaded to loadFailed', () {
        expect(lifecycle.canTransitionTo(PluginState.loadFailed), true);
      });

      test('should not allow transition from unloaded to enabled', () {
        expect(lifecycle.canTransitionTo(PluginState.enabled), false);
      });

      test('should not allow transition from unloaded to disabled', () {
        expect(lifecycle.canTransitionTo(PluginState.disabled), false);
      });
    });

    group('canTransitionTo - loaded state', () {
      setUp(() async {
        await lifecycle.transitionTo(PluginState.loaded, () async {});
      });

      test('should allow transition from loaded to enabled', () {
        expect(lifecycle.canTransitionTo(PluginState.enabled), true);
      });

      test('should allow transition from loaded to disabled', () {
        expect(lifecycle.canTransitionTo(PluginState.disabled), true);
      });

      test('should allow transition from loaded to unloaded', () {
        expect(lifecycle.canTransitionTo(PluginState.unloaded), true);
      });

      test('should not allow transition from loaded to loaded', () {
        expect(lifecycle.canTransitionTo(PluginState.loaded), false);
      });
    });

    group('canTransitionTo - enabled state', () {
      setUp(() async {
        await lifecycle.transitionTo(PluginState.loaded, () async {});
        await lifecycle.transitionTo(PluginState.enabled, () async {});
      });

      test('should allow transition from enabled to disabled', () {
        expect(lifecycle.canTransitionTo(PluginState.disabled), true);
      });

      test('should allow transition from enabled to unloaded', () {
        expect(lifecycle.canTransitionTo(PluginState.unloaded), true);
      });

      test('should not allow transition from enabled to loaded', () {
        expect(lifecycle.canTransitionTo(PluginState.loaded), false);
      });
    });

    group('canTransitionTo - disabled state', () {
      setUp(() async {
        await lifecycle.transitionTo(PluginState.loaded, () async {});
        await lifecycle.transitionTo(PluginState.enabled, () async {});
        await lifecycle.transitionTo(PluginState.disabled, () async {});
      });

      test('should allow transition from disabled to enabled', () {
        expect(lifecycle.canTransitionTo(PluginState.enabled), true);
      });

      test('should allow transition from disabled to unloaded', () {
        expect(lifecycle.canTransitionTo(PluginState.unloaded), true);
      });
    });

    group('canTransitionTo - failed states', () {
      test('should allow transition from loadFailed to unloaded', () async {
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
          // Expected
        }

        expect(failingLifecycle.state, PluginState.loadFailed);
        expect(failingLifecycle.canTransitionTo(PluginState.unloaded), true);
      });

      test('should allow transition from enableFailed to unloaded', () async {
        final failingPlugin = FailingOnEnablePlugin();
        final failingLifecycle = PluginLifecycleManager(failingPlugin);

        await failingLifecycle.transitionTo(PluginState.loaded, () async {});

        try {
          await failingLifecycle.transitionTo(
            PluginState.enabled,
            failingPlugin.onEnable,
          );
        } catch (e) {
          // Expected
        }

        expect(failingLifecycle.state, PluginState.enableFailed);
        expect(failingLifecycle.canTransitionTo(PluginState.unloaded), true);
      });
    });

    group('transitionTo - 状态转换执行', () {
      test('should update state on successful transition', () async {
        await lifecycle.transitionTo(PluginState.loaded, () async {});

        expect(lifecycle.state, PluginState.loaded);
        expect(plugin.state, PluginState.loaded);
      });

      test('should throw on invalid transition', () async {
        expect(
          () => lifecycle.transitionTo(PluginState.enabled, () async {}),
          throwsA(isA<PluginStateException>()),
        );
      });

      test('should set loadFailed on load failure', () async {
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
          fail('Expected exception to be thrown');
        } catch (e) {
          // Expected
        }

        expect(failingLifecycle.state, PluginState.loadFailed);
        expect(failingPlugin.state, PluginState.loadFailed);
      });

      test('should set enableFailed on enable failure', () async {
        final failingPlugin = FailingOnEnablePlugin();
        final failingLifecycle = PluginLifecycleManager(failingPlugin);

        await failingLifecycle.transitionTo(PluginState.loaded, () async {});

        // 使用 try-catch 来捕获异常，然后验证状态
        try {
          await failingLifecycle.transitionTo(
            PluginState.enabled,
            failingPlugin.onEnable,
          );
          fail('Expected exception to be thrown');
        } catch (e) {
          // Expected
        }

        expect(failingLifecycle.state, PluginState.enableFailed);
        expect(failingPlugin.state, PluginState.enableFailed);
      });
    });

    group('listeners - 状态监听', () {
      test('should notify listeners on state change', () async {
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

      test('should notify listeners on failure', () async {
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
          // Expected
        }

        expect(notifiedState, PluginState.loadFailed);
      });

      test('should handle listener exceptions gracefully', () async {
        lifecycle.addListener((plugin, old, newS) {
          throw Exception('Listener error');
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

    test('should provide metadata shortcut', () {
      expect(wrapper.metadata.id, 'test_plugin');
      expect(wrapper.metadata.name, 'Test Plugin');
    });

    test('should provide state shortcut', () async {
      await lifecycle.transitionTo(PluginState.loaded, () async {});

      expect(wrapper.state, PluginState.loaded);
    });

    test('should report isLoaded correctly', () async {
      expect(wrapper.isLoaded, false);

      await lifecycle.transitionTo(PluginState.loaded, () async {});
      expect(wrapper.isLoaded, true);

      await lifecycle.transitionTo(PluginState.enabled, () async {});
      expect(wrapper.isLoaded, true);
    });

    test('should report isEnabled correctly', () async {
      expect(wrapper.isEnabled, false);

      await lifecycle.transitionTo(PluginState.loaded, () async {});
      expect(wrapper.isEnabled, false);

      await lifecycle.transitionTo(PluginState.enabled, () async {});
      expect(wrapper.isEnabled, true);
    });
  });
}
