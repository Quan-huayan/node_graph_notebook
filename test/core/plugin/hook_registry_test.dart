import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/commands/command_bus.dart';
import 'package:node_graph_notebook/core/plugin/plugin.dart';
import 'package:node_graph_notebook/core/plugin/ui_hooks/hook_base.dart';
import 'package:node_graph_notebook/core/plugin/ui_hooks/hook_context.dart';
import 'package:node_graph_notebook/core/plugin/ui_hooks/hook_lifecycle.dart';
import 'package:node_graph_notebook/core/plugin/ui_hooks/hook_metadata.dart';
import 'package:node_graph_notebook/core/plugin/ui_hooks/hook_point_registry.dart';
import 'package:node_graph_notebook/core/plugin/ui_hooks/hook_priority.dart';
import 'package:node_graph_notebook/core/plugin/ui_hooks/hook_registry.dart';

class TestHook extends UIHookBase {

  TestHook({
    required String id,
    required String name,
    this.hookPoint = 'test.hook',
    this.priorityLevel = HookPriority.medium,
    this.apis = const {},
  });
  final String hookPoint;
  final HookPriority priorityLevel;
  final Map<String, dynamic> apis;

  @override
  HookMetadata get metadata => HookMetadata(
        id: 'test.$hookPoint',
        name: 'Test Hook',
        version: '1.0.0',
      );

  @override
  String get hookPointId => hookPoint;

  @override
  HookPriority get priority => priorityLevel;

  @override
  Widget render(HookContext context) => const SizedBox.shrink();

  @override
  Map<String, dynamic> exportAPIs() => apis;
}

class HighPriorityHook extends UIHookBase {
  @override
  HookMetadata get metadata => const HookMetadata(
        id: 'high_priority_hook',
        name: 'High Priority Hook',
        version: '1.0.0',
      );

  @override
  String get hookPointId => 'test.priority';

  @override
  HookPriority get priority => HookPriority.high;

  @override
  Widget render(HookContext context) => const SizedBox.shrink();
}

class LowPriorityHook extends UIHookBase {
  @override
  HookMetadata get metadata => const HookMetadata(
        id: 'low_priority_hook',
        name: 'Low Priority Hook',
        version: '1.0.0',
      );

  @override
  String get hookPointId => 'test.priority';

  @override
  HookPriority get priority => HookPriority.low;

  @override
  Widget render(HookContext context) => const SizedBox.shrink();
}

class CriticalPriorityHook extends UIHookBase {
  @override
  HookMetadata get metadata => const HookMetadata(
        id: 'critical_priority_hook',
        name: 'Critical Priority Hook',
        version: '1.0.0',
      );

  @override
  String get hookPointId => 'test.priority';

  @override
  HookPriority get priority => HookPriority.critical;

  @override
  Widget render(HookContext context) => const SizedBox.shrink();
}

class HookWithAPI extends UIHookBase {
  @override
  HookMetadata get metadata => const HookMetadata(
        id: 'hook_with_api',
        name: 'Hook With API',
        version: '1.0.0',
      );

  @override
  String get hookPointId => 'test.api';

  @override
  Widget render(HookContext context) => const SizedBox.shrink();

  @override
  Map<String, dynamic> exportAPIs() => {
        'test_api': TestAPI(),
      };
}

class TestAPI {
  String greet() => 'Hello from TestAPI';
}

void main() {
  group('HookRegistry', () {
    late HookRegistry registry;

    setUp(() {
      registry = HookRegistry();
    });

    tearDown(() {
      registry.clear();
    });

    group('registerHook - Hook 注册', () {
      test('should register hook successfully', () {
        final hook = TestHook(id: 'test_hook', name: 'Test Hook');
        registry.registerHook(hook);

        expect(registry.hasHooks('test.hook'), true);
      });

      test('should register multiple hooks at same hook point', () {
        registry..registerHook(TestHook(id: 'hook1', name: 'Hook 1'))
        ..registerHook(TestHook(id: 'hook2', name: 'Hook 2'));

        // 获取所有hooks，包括未启用的
        final wrappers = registry.getHookWrappers('test.hook', includeDisabled: true);
        expect(wrappers.length, 2);
      });

      test('should register hooks at different hook points', () {
        registry..registerHook(TestHook(id: 'hook1', name: 'Hook 1', hookPoint: 'point.a'))
        ..registerHook(TestHook(id: 'hook2', name: 'Hook 2', hookPoint: 'point.b'));

        expect(registry.hasHooks('point.a'), true);
        expect(registry.hasHooks('point.b'), true);
      });
    });

    group('unregisterHook - Hook 注销', () {
      test('should unregister hook successfully', () {
        final hook = TestHook(id: 'test_hook', name: 'Test Hook');
        registry..registerHook(hook)

        ..unregisterHook(hook);

        expect(registry.hasHooks('test.hook'), false);
      });

      test('should remove hook point when last hook is unregistered', () {
        final hook = TestHook(id: 'test_hook', name: 'Test Hook');
        registry..registerHook(hook)

        ..unregisterHook(hook);

        expect(registry.registeredHookPointIds.contains('test.hook'), false);
      });

      test('should keep hook point when other hooks remain', () {
        final hook1 = TestHook(id: 'hook1', name: 'Hook 1');
        final hook2 = TestHook(id: 'hook2', name: 'Hook 2');
        registry..registerHook(hook1)
        ..registerHook(hook2)

        ..unregisterHook(hook1);

        expect(registry.hasHooks('test.hook'), true);
        expect(registry.getHookWrappers('test.hook', includeDisabled: true).length, 1);
      });
    });

    group('unregisterPluginHooks - 插件 Hook 注销', () {
      test('should unregister all hooks for plugin', () {
        final pluginWrapper = _createMockPluginWrapper('test_plugin');

        registry..registerHook(TestHook(id: 'hook1', name: 'Hook 1'), parentPlugin: pluginWrapper)
        ..registerHook(TestHook(id: 'hook2', name: 'Hook 2'), parentPlugin: pluginWrapper)

        ..unregisterPluginHooks('test_plugin');

        expect(registry.totalHooks, 0);
      });

      test('should not affect hooks from other plugins', () {
        final pluginA = _createMockPluginWrapper('plugin_a');
        final pluginB = _createMockPluginWrapper('plugin_b');

        registry..registerHook(TestHook(id: 'hook_a', name: 'Hook A'), parentPlugin: pluginA)
        ..registerHook(TestHook(id: 'hook_b', name: 'Hook B'), parentPlugin: pluginB)

        ..unregisterPluginHooks('plugin_a');

        expect(registry.totalHooks, 1);
      });
    });

    group('priority sorting - 优先级排序', () {
      test('should sort hooks by priority', () {
        registry..registerHook(LowPriorityHook())
        ..registerHook(HighPriorityHook())
        ..registerHook(CriticalPriorityHook());

        final wrappers = registry.getHookWrappers('test.priority', includeDisabled: true);

        expect(wrappers[0].hook.metadata.id, 'critical_priority_hook');
        expect(wrappers[1].hook.metadata.id, 'high_priority_hook');
        expect(wrappers[2].hook.metadata.id, 'low_priority_hook');
      });

      test('should maintain priority order after multiple registrations', () {
        registry..registerHook(LowPriorityHook())
        ..registerHook(CriticalPriorityHook())
        ..registerHook(HighPriorityHook())
        ..registerHook(TestHook(
          id: 'medium_hook',
          name: 'Medium Hook',
          hookPoint: 'test.priority',
          priorityLevel: HookPriority.medium,
        ));

        final wrappers = registry.getHookWrappers('test.priority', includeDisabled: true);

        expect(wrappers[0].hook.priority, HookPriority.critical);
        expect(wrappers[1].hook.priority, HookPriority.high);
        expect(wrappers[2].hook.priority, HookPriority.medium);
        expect(wrappers[3].hook.priority, HookPriority.low);
      });
    });

    group('API export - API 导出', () {
      test('should register hook APIs', () {
        registry.registerHook(HookWithAPI());

        expect(registry.hasHookAPI('hook_with_api', 'test_api'), true);
      });

      test('should return API instance', () {
        registry.registerHook(HookWithAPI());

        final api = registry.getHookAPI<TestAPI>('hook_with_api', 'test_api');

        expect(api, isNotNull);
        expect(api!.greet(), 'Hello from TestAPI');
      });

      test('should unregister APIs when hook is unregistered', () {
        final hook = HookWithAPI();
        registry..registerHook(hook)

        ..unregisterHook(hook);

        expect(registry.hasHookAPI('hook_with_api', 'test_api'), false);
      });

      test('should return all hook APIs', () {
        registry.registerHook(HookWithAPI());

        final apis = registry.getHookAPIs('hook_with_api');

        expect(apis.length, 1);
        expect(apis.containsKey('test_api'), true);
      });
    });

    group('getHookWrappers - Hook 查询', () {
      test('should return empty list for non-existent hook point', () {
        final wrappers = registry.getHookWrappers('non_existent');

        expect(wrappers, isEmpty);
      });

      test('should exclude disabled hooks by default', () async {
        final hook = TestHook(id: 'test_hook', name: 'Test Hook');
        registry.registerHook(hook);

        // 获取未启用的hook来初始化它
        final wrapper = registry.getHookWrappers('test.hook', includeDisabled: true).first;
        await wrapper.lifecycle.transitionTo(HookState.initialized, () async {});

        // uninitialized状态不是enabled，所以返回0
        expect(registry.getHookWrappers('test.hook').length, 0);

        await wrapper.lifecycle.transitionTo(HookState.enabled, () async {});
        // 现在hook启用了，应该返回1
        expect(registry.getHookWrappers('test.hook').length, 1);

        await wrapper.lifecycle.transitionTo(HookState.disabled, () async {});
        // 禁用后应该返回0
        expect(registry.getHookWrappers('test.hook').length, 0);
      });

      test('should include disabled hooks when requested', () async {
        final hook = TestHook(id: 'test_hook', name: 'Test Hook');
        registry.registerHook(hook);

        // 获取未启用的hook来初始化它
        final wrapper = registry.getHookWrappers('test.hook', includeDisabled: true).first;
        await wrapper.lifecycle.transitionTo(HookState.initialized, () async {});
        await wrapper.lifecycle.transitionTo(HookState.enabled, () async {});
        await wrapper.lifecycle.transitionTo(HookState.disabled, () async {});

        expect(
          registry.getHookWrappers('test.hook', includeDisabled: true).length,
          1,
        );
      });
    });

    group('hook points - Hook 点管理', () {
      test('should register custom hook point', () {
        registry.registerHookPoint(const HookPointDefinition(
          id: 'custom.point',
          name: 'Custom Hook Point',
          description: 'A custom hook point for testing', 
          category: 'toolbar',
        ));

        expect(registry.hasHookPoint('custom.point'), true);
      });

      test('should return hook point definition', () {
        registry.registerHookPoint(const HookPointDefinition(
          id: 'custom.point',
          name: 'Custom Hook Point',
          description: 'A custom hook point for testing',
          category: 'toolbar',
        ));

        final point = registry.getHookPoint('custom.point');

        expect(point, isNotNull);
        expect(point!.id, 'custom.point');
        expect(point.name, 'Custom Hook Point');
      });

      test('should return all hook points', () {
        registry..registerHookPoint(const HookPointDefinition(
          id: 'point.a',
          name: 'Point A',
          description: 'Point A',
          category: 'sidebar',
        ))
        ..registerHookPoint(const HookPointDefinition(
          id: 'point.b',
          name: 'Point B',
          description: 'Point B',
          category: 'context_menu',
        ));

        final points = registry.getAllHookPoints();

        expect(points.length, 2);
      });
    });

    group('statistics - 统计信息', () {
      test('should report total hooks correctly', () {
        registry..registerHook(TestHook(id: 'hook1', name: 'Hook 1'))
        ..registerHook(TestHook(id: 'hook2', name: 'Hook 2', hookPoint: 'other.point'));

        expect(registry.totalHooks, 2);
      });

      test('should report registered hook point IDs', () {
        registry..registerHook(TestHook(id: 'hook1', name: 'Hook 1', hookPoint: 'point.a'))
        ..registerHook(TestHook(id: 'hook2', name: 'Hook 2', hookPoint: 'point.b'));

        expect(registry.registeredHookPointIds, containsAll(['point.a', 'point.b']));
      });
    });

    group('clear - 清空', () {
      test('should clear all hooks and hook points', () {
        registry..registerHook(TestHook(id: 'hook1', name: 'Hook 1'))
        ..registerHookPoint(const HookPointDefinition(
          id: 'custom.point',
          name: 'Custom Point',
          description: 'Custom',
          category: 'toolbar',
        ))

        ..clear();

        expect(registry.totalHooks, 0);
        expect(registry.registeredHookPointIds, isEmpty);
      });
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
