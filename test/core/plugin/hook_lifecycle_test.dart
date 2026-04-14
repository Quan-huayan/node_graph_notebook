import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/cqrs/commands/command_bus.dart';
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
      test('应该以未初始化状态开始', () {
        expect(lifecycle.state, HookState.uninitialized);
      });

      test('应该报告正确的初始标志', () {
        expect(lifecycle.isInitialized, false);
        expect(lifecycle.isEnabled, false);
        expect(lifecycle.isDisabled, false);
        expect(lifecycle.isDisposed, false);
      });
    });

    group('canTransitionTo - 状态转换验证', () {
      test('应该允许从未初始化状态转换到已初始化状态', () {
        expect(lifecycle.canTransitionTo(HookState.initialized), true);
      });

      test('不应该允许从未初始化状态进行其他转换', () {
        expect(lifecycle.canTransitionTo(HookState.enabled), false);
        expect(lifecycle.canTransitionTo(HookState.disabled), false);
        expect(lifecycle.canTransitionTo(HookState.disposed), false);
      });
    });

    group('canTransitionTo - initialized state', () {
      setUp(() async {
        await lifecycle.transitionTo(HookState.initialized, () async {});
      });

      test('应该允许从已初始化状态转换到已启用状态', () {
        expect(lifecycle.canTransitionTo(HookState.enabled), true);
      });

      test('应该允许从已初始化状态转换到已处置状态', () {
        expect(lifecycle.canTransitionTo(HookState.disposed), true);
      });

      test('不应该允许从已初始化状态转换到已禁用状态', () {
        expect(lifecycle.canTransitionTo(HookState.disabled), false);
      });

      test('不应该允许从已初始化状态转换到未初始化状态', () {
        expect(lifecycle.canTransitionTo(HookState.uninitialized), false);
      });
    });

    group('canTransitionTo - enabled state', () {
      setUp(() async {
        await lifecycle.transitionTo(HookState.initialized, () async {});
        await lifecycle.transitionTo(HookState.enabled, () async {});
      });

      test('应该允许从已启用状态转换到已禁用状态', () {
        expect(lifecycle.canTransitionTo(HookState.disabled), true);
      });

      test('应该允许从已启用状态转换到已处置状态', () {
        expect(lifecycle.canTransitionTo(HookState.disposed), true);
      });

      test('不应该允许从已启用状态转换到已初始化状态', () {
        expect(lifecycle.canTransitionTo(HookState.initialized), false);
      });
    });

    group('canTransitionTo - disabled state', () {
      setUp(() async {
        await lifecycle.transitionTo(HookState.initialized, () async {});
        await lifecycle.transitionTo(HookState.enabled, () async {});
        await lifecycle.transitionTo(HookState.disabled, () async {});
      });

      test('应该允许从已禁用状态转换到已启用状态', () {
        expect(lifecycle.canTransitionTo(HookState.enabled), true);
      });

      test('应该允许从已禁用状态转换到已处置状态', () {
        expect(lifecycle.canTransitionTo(HookState.disposed), true);
      });

      test('不应该允许从已禁用状态转换到已初始化状态', () {
        expect(lifecycle.canTransitionTo(HookState.initialized), false);
      });
    });

    group('canTransitionTo - disposed state', () {
      setUp(() async {
        await lifecycle.transitionTo(HookState.initialized, () async {});
        await lifecycle.transitionTo(HookState.disposed, () async {});
      });

      test('不应该允许从已处置状态进行任何转换', () {
        expect(lifecycle.canTransitionTo(HookState.uninitialized), false);
        expect(lifecycle.canTransitionTo(HookState.initialized), false);
        expect(lifecycle.canTransitionTo(HookState.enabled), false);
        expect(lifecycle.canTransitionTo(HookState.disabled), false);
        expect(lifecycle.canTransitionTo(HookState.disposed), false);
      });
    });

    group('transitionTo - 状态转换执行', () {
      test('应该在成功转换时更新状态', () async {
        await lifecycle.transitionTo(HookState.initialized, () async {});

        expect(lifecycle.state, HookState.initialized);
        expect(lifecycle.isInitialized, true);
      });

      test('应该在无效转换时抛出异常', () {
        expect(
          () => lifecycle.transitionTo(HookState.enabled, () async {}),
          throwsA(isA<StateError>()),
        );
      });

      test('应该在操作失败时保留状态', () async {
        try {
          await lifecycle.transitionTo(HookState.initialized, () async {
            throw Exception('初始化失败');
          });
        } catch (e) {
          // 预期内的异常
        }

        expect(lifecycle.state, HookState.uninitialized);
      });

      test('应该允许启用/禁用循环', () async {
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
      test('应该返回可读的字符串表示', () {
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

    test('应该正确报告isInitialized状态', () async {
      expect(wrapper.isInitialized, false);

      await lifecycle.transitionTo(HookState.initialized, () async {});
      expect(wrapper.isInitialized, true);
    });

    test('应该正确报告isEnabled状态', () async {
      expect(wrapper.isEnabled, false);

      await lifecycle.transitionTo(HookState.initialized, () async {});
      expect(wrapper.isEnabled, false);

      await lifecycle.transitionTo(HookState.enabled, () async {});
      expect(wrapper.isEnabled, true);
    });

    test('应该正确报告isDisposed状态', () async {
      expect(wrapper.isDisposed, false);

      await lifecycle.transitionTo(HookState.initialized, () async {});
      await lifecycle.transitionTo(HookState.disposed, () async {});
      expect(wrapper.isDisposed, true);
    });

    group('with parent plugin', () {
      test('应该检查父插件的启用状态', () async {
        final parentPlugin = _createMockPluginWrapper('parent_plugin');
        wrapper = HookWrapper(hook, lifecycle, 0, parentPlugin: parentPlugin); // 添加注册顺序参数

        await lifecycle.transitionTo(HookState.initialized, () async {});
        await lifecycle.transitionTo(HookState.enabled, () async {});

        expect(wrapper.isEnabled, false);
      });

      test('当hook和父插件都启用时应该处于启用状态', () async {
        final parentPlugin = await _createMockEnabledPluginWrapper('parent_plugin');
        wrapper = HookWrapper(hook, lifecycle, 0, parentPlugin: parentPlugin); // 添加注册顺序参数

        await lifecycle.transitionTo(HookState.initialized, () async {});
        await lifecycle.transitionTo(HookState.enabled, () async {});

        expect(wrapper.isEnabled, true);
      });
    });

    group('toString', () {
      test('应该返回可读的字符串表示', () {
        expect(
          wrapper.toString(),
          contains('HookWrapper'),
        );
      });
    });
  });

  group('HookWrapperFactory', () {
    test('应该为新hook创建包装器', () {
      final hook = TestHook();
      final wrapper = HookWrapperFactory.wrapNewHook(hook);

      expect(wrapper.hook, same(hook));
      expect(wrapper.lifecycle.state, HookState.uninitialized);
      expect(wrapper.parentPlugin, isNull);
    });

    test('应该创建带有父插件的包装器', () {
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
