import 'package:flutter/foundation.dart';

import '../plugin_manager.dart';
import 'hook_api_registry.dart';
import 'hook_base.dart';
import 'hook_point.dart';

/// Hook 状态枚举。
enum HookState {
  /// 未初始化状态。
  uninitialized,
  /// 已初始化状态。
  initialized,
  /// 已启用状态。
  enabled,
  /// 已禁用状态。
  disabled,
  /// 已销毁状态。
  disposed,
}

/// Hook 包装器。
class HookWrapper {
  /// 创建一个 Hook 包装器。
  HookWrapper({
    required this.hook,
    this.parentPlugin,
  });

  /// 被包装的 Hook 实例。
  final HookRoleBase hook;

  /// 所属的插件包装器。
  final PluginWrapper? parentPlugin;

  /// 生命周期管理器。
  final HookLifecycleManager lifecycle = HookLifecycleManager();

  static int _orderCounter = 0;

  /// 注册顺序（用于同优先级排序）。
  final int registrationOrder = _orderCounter++;

  /// 是否已启用。
  bool isEnabled = false;
}

/// 简单的 Hook 生命周期管理器。
class HookLifecycleManager {
  HookState _state = HookState.uninitialized;

  /// 当前生命周期状态。
  HookState get state => _state;

  /// 转换到目标状态并执行指定动作。
  Future<void> transitionTo(HookState target, Future<void> Function() action) async {
    await action();
    _state = target;
  }
}

/// Hook 注册表。
///
/// 管理 Hook 的注册、注销、查询。继承 ChangeNotifier 以支持 UI 更新。
class HookRoleRegistry extends ChangeNotifier {
  /// 创建 Hook 注册表。
  HookRoleRegistry();

  final Map<String, HookPointDefinition> _hookPoints = {};
  final Map<String, List<HookWrapper>> _hooks = {};
  final HookAPIRegistry _apiRegistry = HookAPIRegistry();

  /// Hook API 注册表（只读）。
  HookAPIRegistry get apiRegistry => _apiRegistry;

  // ── Hook 点管理 ──

  /// 注册一个新的 Hook 点定义。
  void registerHookPoint(HookPointDefinition point) {
    _hookPoints[point.id] = point;
  }

  /// 根据 ID 获取 Hook 点定义（若无则返回 null）。
  HookPointDefinition? getHookPoint(String id) => _hookPoints[id];

  /// 检查指定 ID 的 Hook 点是否已注册。
  bool hasHookPoint(String id) => _hookPoints.containsKey(id);

  /// 获取所有已注册的 Hook 点定义。
  List<HookPointDefinition> getAllHookPoints() => _hookPoints.values.toList();

  /// 注销指定 ID 的 Hook 点及其关联的所有 Hook。
  void unregisterHookPoint(String id) {
    _hookPoints.remove(id);
    _hooks.remove(id);
  }

  // ── Hook 注册 ──

  /// 注册一个 Hook 到对应的 Hook 点。
  void registerHook(HookRoleBase hook, {PluginWrapper? parentPlugin}) {
    final hookPointId = hook.hookPointId;
    final wrapper = HookWrapper(hook: hook, parentPlugin: parentPlugin);

    _hooks.putIfAbsent(hookPointId, () => []);
    _hooks[hookPointId]!.add(wrapper);

    _hooks[hookPointId]!.sort((a, b) {
      final cmp = a.hook.priority.value.compareTo(b.hook.priority.value);
      if (cmp != 0) return cmp;
      return a.registrationOrder.compareTo(b.registrationOrder);
    });

    // 注册 Hook 的 API
    final apis = hook.exportAPIs();
    if (apis.isNotEmpty) {
      _apiRegistry.registerAPIs(hook.metadata.id, apis);
    }

    notifyListeners();
  }

  /// 批量注册多个 Hook。
  void registerHooks(List<HookRoleBase> hooks, {PluginWrapper? parentPlugin}) {
    for (final hook in hooks) {
      registerHook(hook, parentPlugin: parentPlugin);
    }
  }

  // ── Hook 查询 ──

  /// 获取指定 Hook 点的 Hook 包装器列表。
  ///
  /// [includeDisabled] 为 true 时包含已禁用的 Hook。
  List<HookWrapper> getHookWrappers(String hookPointId, {bool includeDisabled = false}) {
    final allHooks = _hooks[hookPointId] ?? [];
    if (includeDisabled) return allHooks;
    return allHooks.where((w) => w.lifecycle.state == HookState.enabled).toList();
  }

  /// 检查指定 Hook 点是否有已注册的 Hook。
  bool hasHooks(String hookPointId) =>
      getHookWrappers(hookPointId, includeDisabled: true).isNotEmpty;

  // ── Hook 注销 ──

  /// 注销指定的 Hook 实例。
  void unregisterHook(HookRoleBase hook) {
    for (final entry in _hooks.entries) {
      entry.value.removeWhere((w) {
        if (w.hook == hook) {
          _apiRegistry.unregisterHookAPIs(hook.metadata.id);
          return true;
        }
        return false;
      });
    }
  }

  /// 注销指定插件的所有 Hook。
  void unregisterPluginHooks(String pluginId) {
    for (final entry in _hooks.entries) {
      entry.value.removeWhere((w) {
        if (w.parentPlugin?.plugin.metadata.id == pluginId) {
          _apiRegistry.unregisterHookAPIs(w.hook.metadata.id);
          return true;
        }
        return false;
      });
    }
    _hooks.removeWhere((_, wrappers) => wrappers.isEmpty);
  }

  // ── Hook API ──

  /// 获取指定 Hook 导出的特定类型的 API。
  T? getHookAPI<T>(String hookId, String apiName) =>
      _apiRegistry.getAPI<T>(hookId, apiName);

  /// 检查指定 Hook 是否导出了指定 API。
  bool hasHookAPI(String hookId, String apiName) =>
      _apiRegistry.hasAPI(hookId, apiName);

  // ── 工具 ──

  /// 已注册的 Hook 点 ID 集合。
  Set<String> get registeredHookPointIds => _hooks.keys.toSet();

  /// 已注册的 Hook 总数。
  int get totalHooks =>
      _hooks.values.fold(0, (sum, hooks) => sum + hooks.length);

  /// 清空所有 Hook 注册和 API。
  void clear() {
    _hooks.clear();
    _hookPoints.clear();
    _apiRegistry.clear();
  }
}
