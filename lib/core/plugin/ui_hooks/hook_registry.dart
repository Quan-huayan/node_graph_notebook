import 'hook_point.dart';
import 'ui_hook.dart';

/// Hook 注册表
class HookRegistry {
  /// 创建一个新的 Hook 注册表实例。
  HookRegistry();

  /// Hook 映射
  ///
  /// Key: Hook 点 ID
  /// Value: 该 Hook 点注册的所有 Hook（按优先级排序）
  final Map<HookPointId, List<UIHook>> _hooks = {};

  /// 注册 Hook
  ///
  /// [hook] Hook 实例
  void registerHook(UIHook hook) {
    final hookPointId = hook.hookPoint;
    if (!_hooks.containsKey(hookPointId)) {
      _hooks[hookPointId] = [];
    }

    _hooks[hookPointId]!.add(hook);
    _hooks[hookPointId]!.sort((a, b) => a.priority.compareTo(b.priority));
  }

  /// 注销 Hook
  ///
  /// [hook] Hook 实例
  void unregisterHook(UIHook hook) {
    final hookPointId = hook.hookPoint;
    if (_hooks.containsKey(hookPointId)) {
      _hooks[hookPointId]!.remove(hook);
    }
  }

  /// 获取指定 Hook 点的所有 Hook
  ///
  /// [hookPointId] Hook 点 ID
  ///
  /// 返回按优先级排序的 Hook 列表
  List<UIHook> getHooks(HookPointId hookPointId) => _hooks[hookPointId]?.where((hook) => hook.isEnabled).toList() ?? [];

  /// 获取指定 Hook 点的第一个 Hook
  ///
  /// [hookPointId] Hook 点 ID
  ///
  /// 返回优先级最高的 Hook
  UIHook? getFirstHook(HookPointId hookPointId) {
    final hooks = getHooks(hookPointId);
    return hooks.isNotEmpty ? hooks.first : null;
  }

  /// 检查指定 Hook 点是否有 Hook
  ///
  /// [hookPointId] Hook 点 ID
  bool hasHooks(HookPointId hookPointId) => getHooks(hookPointId).isNotEmpty;

  /// 清空所有 Hook
  void clear() {
    _hooks.clear();
  }

  /// 获取所有注册的 Hook 点
  Set<HookPointId> get registeredHookPoints => _hooks.keys.toSet();

  /// 获取 Hook 总数
  int get totalHooks => _hooks.values.fold(0, (sum, hooks) => sum + hooks.length);
}

/// 全局 Hook 注册表实例
final hookRegistry = HookRegistry();
