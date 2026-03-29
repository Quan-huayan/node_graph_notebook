import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/commands/command_bus.dart';
import 'package:node_graph_notebook/core/plugin/plugin.dart';
import 'package:node_graph_notebook/core/plugin/ui_hooks/hook_base.dart';
import 'package:node_graph_notebook/core/plugin/ui_hooks/hook_context.dart';
import 'package:node_graph_notebook/core/plugin/ui_hooks/hook_lifecycle.dart';
import 'package:node_graph_notebook/core/plugin/ui_hooks/hook_metadata.dart';
import 'package:node_graph_notebook/core/plugin/ui_hooks/hook_priority.dart';

class TestHook extends UIHookBase {
  @override
  HookMetadata get metadata => const HookMetadata(
        id: 'test_hook',
        name: 'Test Hook',
        version: '1.0.0',
      );

  @override
  Widget render(HookContext context) => const SizedBox();

  @override
  String get hookPointId => 'test.hook';

  @override
  HookPriority get priority => HookPriority.medium;
}

void main() {
  group('HookLifecycleManager', () {
    late HookLifecycleManager lifecycle;

    setUp(() {
      lifecycle = HookLifecycleManager('test_hook');
    });

    group('initial state', () {
      test('should start in uninitialized state', () {
        expect(lifecycle.state, HookState.uninitialized);
      });

      test('should report correct initial flags', () {
        expect(lifecycle.isInitialized, false);
        expect(lifecycle.isEnabled, false);
        expect(lifecycle.isDisabled, false);
        expect(lifecycle.isDisposed, false);
      });
    });

    group('canTransitionTo - 状态转换验证', () {
      test('should allow transition from uninitialized to initialized', () {
        expect(lifecycle.canTransitionTo(HookState.initialized), true);
      });

      test('should not allow other transitions from uninitialized', () {
        expect(lifecycle.canTransitionTo(HookState.enabled), false);
        expect(lifecycle.canTransitionTo(HookState.disabled), false);
        expect(lifecycle.canTransitionTo(HookState.disposed), false);
      });
    });

    group('canTransitionTo - initialized state', () {
      setUp(() async {
        await lifecycle.transitionTo(HookState.initialized, () async {});
      });

      test('should allow transition from initialized to enabled', () {
        expect(lifecycle.canTransitionTo(HookState.enabled), true);
      });

      test('should allow transition from initialized to disposed', () {
        expect(lifecycle.canTransitionTo(HookState.disposed), true);
      });

      test('should not allow transition from initialized to disabled', () {
        expect(lifecycle.canTransitionTo(HookState.disabled), false);
      });

      test('should not allow transition from initialized to uninitialized', () {
        expect(lifecycle.canTransitionTo(HookState.uninitialized), false);
      });
    });

    group('canTransitionTo - enabled state', () {
      setUp(() async {
        await lifecycle.transitionTo(HookState.initialized, () async {});
        await lifecycle.transitionTo(HookState.enabled, () async {});
      });

      test('should allow transition from enabled to disabled', () {
        expect(lifecycle.canTransitionTo(HookState.disabled), true);
      });

      test('should allow transition from enabled to disposed', () {
        expect(lifecycle.canTransitionTo(HookState.disposed), true);
      });

      test('should not allow transition from enabled to initialized', () {
        expect(lifecycle.canTransitionTo(HookState.initialized), false);
      });
    });

    group('canTransitionTo - disabled state', () {
      setUp(() async {
        await lifecycle.transitionTo(HookState.initialized, () async {});
        await lifecycle.transitionTo(HookState.enabled, () async {});
        await lifecycle.transitionTo(HookState.disabled, () async {});
      });

      test('should allow transition from disabled to enabled', () {
        expect(lifecycle.canTransitionTo(HookState.enabled), true);
      });

      test('should allow transition from disabled to disposed', () {
        expect(lifecycle.canTransitionTo(HookState.disposed), true);
      });

      test('should not allow transition from disabled to initialized', () {
        expect(lifecycle.canTransitionTo(HookState.initialized), false);
      });
    });

    group('canTransitionTo - disposed state', () {
      setUp(() async {
        await lifecycle.transitionTo(HookState.initialized, () async {});
        await lifecycle.transitionTo(HookState.disposed, () async {});
      });

      test('should not allow any transition from disposed', () {
        expect(lifecycle.canTransitionTo(HookState.uninitialized), false);
        expect(lifecycle.canTransitionTo(HookState.initialized), false);
        expect(lifecycle.canTransitionTo(HookState.enabled), false);
        expect(lifecycle.canTransitionTo(HookState.disabled), false);
        expect(lifecycle.canTransitionTo(HookState.disposed), false);
      });
    });

    group('transitionTo - 状态转换执行', () {
      test('should update state on successful transition', () async {
        await lifecycle.transitionTo(HookState.initialized, () async {});

        expect(lifecycle.state, HookState.initialized);
        expect(lifecycle.isInitialized, true);
      });

      test('should throw on invalid transition', () {
        expect(
          () => lifecycle.transitionTo(HookState.enabled, () async {}),
          throwsA(isA<StateError>()),
        );
      });

      test('should preserve state on action failure', () async {
        try {
          await lifecycle.transitionTo(HookState.initialized, () async {
            throw Exception('Init failed');
          });
        } catch (e) {
          // 预期内的异常
        }

        expect(lifecycle.state, HookState.uninitialized);
      });

      test('should allow enable/disable cycle', () async {
        await lifecycle.transitionTo(HookState.initialized, () async {});
        expect(lifecycle.state, HookState.initialized);

        await lifecycle.transitionTo(HookState.enabled, () async {});
        expect(lifecycle.state, HookState.enabled);
        expect(lifecycle.isEnabled, true);

        await lifecycle.transitionTo(HookState.disabled, () async {});
        expect(lifecycle.state, HookState.disabled);
        expect(lifecycle.isDisabled, true);

        await lifecycle.transitionTo(HookState.enabled, () async {});
        expect(lifecycle.state, HookState.enabled);
      });
    });

    group('toString', () {
      test('should return readable string representation', () {
        expect(
          lifecycle.toString(),
          'HookLifecycleManager(test_hook, state: HookState.uninitialized)',
        );
      });
    });
  });

  group('HookWrapper', () {
    late HookWrapper wrapper;
    late TestHook hook;
    late HookLifecycleManager lifecycle;

    setUp(() {
      hook = TestHook();
      lifecycle = HookLifecycleManager('test_hook');
      wrapper = HookWrapper(hook, lifecycle, 0); // 添加注册顺序参数
    });

    test('should report isInitialized correctly', () async {
      expect(wrapper.isInitialized, false);

      await lifecycle.transitionTo(HookState.initialized, () async {});
      expect(wrapper.isInitialized, true);
    });

    test('should report isEnabled correctly', () async {
      expect(wrapper.isEnabled, false);

      await lifecycle.transitionTo(HookState.initialized, () async {});
      expect(wrapper.isEnabled, false);

      await lifecycle.transitionTo(HookState.enabled, () async {});
      expect(wrapper.isEnabled, true);
    });

    test('should report isDisposed correctly', () async {
      expect(wrapper.isDisposed, false);

      await lifecycle.transitionTo(HookState.initialized, () async {});
      await lifecycle.transitionTo(HookState.disposed, () async {});
      expect(wrapper.isDisposed, true);
    });

    group('with parent plugin', () {
      test('should check parent plugin enabled state', () async {
        final parentPlugin = _createMockPluginWrapper('parent_plugin');
        wrapper = HookWrapper(hook, lifecycle, 0, parentPlugin: parentPlugin); // 添加注册顺序参数

        await lifecycle.transitionTo(HookState.initialized, () async {});
        await lifecycle.transitionTo(HookState.enabled, () async {});

        expect(wrapper.isEnabled, false);
      });

      test('should be enabled when both hook and parent are enabled', () async {
        final parentPlugin = await _createMockEnabledPluginWrapper('parent_plugin');
        wrapper = HookWrapper(hook, lifecycle, 0, parentPlugin: parentPlugin); // 添加注册顺序参数

        await lifecycle.transitionTo(HookState.initialized, () async {});
        await lifecycle.transitionTo(HookState.enabled, () async {});

        expect(wrapper.isEnabled, true);
      });
    });

    group('toString', () {
      test('should return readable string representation', () {
        expect(
          wrapper.toString(),
          contains('HookWrapper'),
        );
      });
    });
  });

  group('HookWrapperFactory', () {
    test('should create wrapper for new hook', () {
      final hook = TestHook();
      final wrapper = HookWrapperFactory.wrapNewHook(hook);

      expect(wrapper.hook, same(hook));
      expect(wrapper.lifecycle.state, HookState.uninitialized);
      expect(wrapper.parentPlugin, isNull);
    });

    test('should create wrapper with parent plugin', () {
      final hook = TestHook();
      final parentPlugin = _createMockPluginWrapper('parent_plugin');
      final wrapper = HookWrapperFactory.wrapNewHook(hook, parentPlugin: parentPlugin);

      expect(wrapper.parentPlugin, same(parentPlugin));
    });
  });
}

PluginWrapper _createMockPluginWrapper(String pluginId) {
  final plugin = _MockPlugin(pluginId);
  final commandBus = CommandBus();
  final context = PluginContext(pluginId: pluginId, commandBus: commandBus);
  final lifecycle = PluginLifecycleManager(plugin);
  return PluginWrapper(plugin, context, lifecycle);
}

Future<PluginWrapper> _createMockEnabledPluginWrapper(String pluginId) async {
  final plugin = _MockPlugin(pluginId);
  final commandBus = CommandBus();
  final context = PluginContext(pluginId: pluginId, commandBus: commandBus);
  final lifecycle = PluginLifecycleManager(plugin);
  await lifecycle.transitionTo(PluginState.loaded, () async {});
  await lifecycle.transitionTo(PluginState.enabled, () async {});
  return PluginWrapper(plugin, context, lifecycle);
}

class _MockPlugin extends Plugin {

  _MockPlugin(this._id);
  final String _id;

  @override
  PluginMetadata get metadata => PluginMetadata(
        id: _id,
        name: 'Mock Plugin',
        version: '1.0.0',
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
