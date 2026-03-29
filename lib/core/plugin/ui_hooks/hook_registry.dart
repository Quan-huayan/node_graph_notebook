import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../utils/logger.dart';
import '../plugin_lifecycle.dart';
import 'hook_api_registry.dart';
import 'hook_base.dart';
import 'hook_lifecycle.dart';
import 'hook_point_registry.dart';

/// Logger for HookRegistry
const _log = AppLogger('HookRegistry');

/// Hook 注册表
///
/// 管理 Hook 的注册、注销和查询
///
/// 架构说明：
/// - 仅支持新的 UIHookBase 系统
/// - 使用 HookWrapper 统一封装 Hooks
/// - 集成 HookPointRegistry 支持动态 Hook 点
/// - 集成 HookAPIRegistry 支持 Hook 间 API 通信
/// - 扩展 ChangeNotifier 支持 UI 自动更新
class HookRegistry extends ChangeNotifier {
  /// 创建一个新的 Hook 注册表实例
  HookRegistry();

  /// Hook 映射
  ///
  /// Key: Hook 点 ID（字符串）
  /// Value: 该 Hook 点注册的所有 Hook 包装器（按优先级排序）
  final Map<String, List<HookWrapper>> _hooks = {};

  /// Hook 点注册表
  ///
  /// 管理所有 Hook 点的元数据
  final HookPointRegistry _pointRegistry = HookPointRegistry();

  /// Hook API 注册表
  ///
  /// 管理 Hook 导出的 API
  final HookAPIRegistry _apiRegistry = HookAPIRegistry();

  /// 获取 Hook API 注册表（用于访问 Hook 导出的 API）
  ///
  /// 允许外部访问 Hook API 注册表，主要用于 HookContext
  HookAPIRegistry get apiRegistry => _apiRegistry;

  /// ===== Hook 点管理 =====

  /// 注册 Hook 点
  ///
  /// [point] Hook 点定义
  ///
  /// 允许插件注册自定义 Hook 点
  void registerHookPoint(HookPointDefinition point) {
    _pointRegistry.registerPoint(point);
    _log.info('Registered hook point: ${point.id}');
  }

  /// 获取 Hook 点定义
  ///
  /// [id] Hook 点 ID
  /// 返回 Hook 点定义，如果不存在则返回 null
  HookPointDefinition? getHookPoint(String id) => _pointRegistry.getPoint(id);

  /// 检查 Hook 点是否存在
  ///
  /// [id] Hook 点 ID
  /// 返回 true 如果 Hook 点已注册
  bool hasHookPoint(String id) => _pointRegistry.hasPoint(id);

  /// 获取所有 Hook 点
  ///
  /// 返回所有已注册的 Hook 点定义列表
  List<HookPointDefinition> getAllHookPoints() => _pointRegistry.getAllPoints();

  /// 注销 Hook 点
  ///
  /// [id] Hook 点 ID
  ///
  /// 注意：不建议注销标准 Hook 点
  void unregisterHookPoint(String id) {
    _pointRegistry.unregisterPoint(id);
  }

  /// ===== Hook 注册 =====

  /// 注册 Hook
  ///
  /// [hook] UIHookBase 实例
  /// [parentPlugin] 可选的父 Plugin 包装器
  void registerHook(
    UIHookBase hook, {
    PluginWrapper? parentPlugin,
  }) {
    final hookPointId = hook.hookPointId;
    final wrapper = HookWrapperFactory.wrapNewHook(
      hook,
      parentPlugin: parentPlugin,
    );

    _addHookWrapper(hookPointId, wrapper);

    // 注册 Hook 导出的 API
    final apis = hook.exportAPIs();
    if (apis.isNotEmpty) {
      _apiRegistry.registerAPIs(hook.metadata.id, apis);
    }

    // ✅ 通知 UI 更新
    notifyListeners();
  }

  /// 批量注册 Hook
  ///
  /// [hooks] UIHookBase 实例列表
  /// [parentPlugin] 可选的父 Plugin 包装器
  void registerHooks(
    List<UIHookBase> hooks, {
    PluginWrapper? parentPlugin,
  }) {
    for (final hook in hooks) {
      registerHook(hook, parentPlugin: parentPlugin);
    }
  }

  /// ===== Hook 注销 =====

  /// 注销 Hook
  ///
  /// [hook] UIHookBase 实例
  void unregisterHook(UIHookBase hook) {
    final hookPointId = hook.hookPointId;
    if (_hooks.containsKey(hookPointId)) {
      _hooks[hookPointId]!
          .removeWhere((wrapper) => wrapper.hook == hook);

      // 如果没有 Hook 了，移除该 Hook 点
      if (_hooks[hookPointId]!.isEmpty) {
        _hooks.remove(hookPointId);
      }
    }

    // 注销 Hook 的 API
    _apiRegistry.unregisterHookAPIs(hook.metadata.id);
  }

  /// 注销 Plugin 的所有 Hook
  ///
  /// [pluginId] Plugin 的唯一标识符
  ///
  /// 当 Plugin 卸载时，自动注销其提供的所有 Hook
  void unregisterPluginHooks(String pluginId) {
    final hooksToRemove = <String>[];

    // 收集需要移除的 Hook
    for (final entry in _hooks.entries) {
      final hookPointId = entry.key;
      final wrappers = entry.value
      ..removeWhere((wrapper) {
        if (wrapper.parentPlugin?.plugin.metadata.id == pluginId) {
          // 注销 Hook 的 API
          _apiRegistry.unregisterHookAPIs(wrapper.hook.metadata.id);
          return true;
        }
        return false;
      });

      if (wrappers.isEmpty) {
        hooksToRemove.add(hookPointId);
      }
    }

    // 移除空的 Hook 点
    hooksToRemove.forEach(_hooks.remove);

    _log.info('Unregistered all hooks for plugin: $pluginId');
  }

  /// ===== Hook 查询 =====

  /// 获取指定 Hook 点的所有 Hook
  ///
  /// [hookPointId] Hook 点 ID（字符串）
  /// [includeDisabled] 是否包含已禁用的 Hook（默认 false）
  ///
  /// 返回按优先级排序的 Hook 包装器列表
  List<HookWrapper> getHookWrappers(
    String hookPointId, {
    bool includeDisabled = false,
  }) {
    final allHooks = _hooks[hookPointId] ?? [];

    if (!includeDisabled) {
      return allHooks.where((wrapper) => wrapper.isEnabled).toList();
    } else {
      return allHooks;
    }
  }

  /// 检查指定 Hook 点是否有 Hook
  /// 这包括禁用的 Hook，因为它们仍然注册在该 Hook 点上
  ///
  /// [hookPointId] Hook 点 ID
  bool hasHooks(String hookPointId) => getHookWrappers(hookPointId, includeDisabled: true).isNotEmpty;

  /// ===== Hook API 访问 =====

  /// 获取 Hook 导出的 API
  ///
  /// [hookId] Hook 的唯一标识符
  /// [apiName] API 名称
  /// 返回指定类型的 API 实例，如果不存在则返回 null
  T? getHookAPI<T>(String hookId, String apiName) => _apiRegistry.getAPI<T>(hookId, apiName);

  /// 检查 Hook 是否导出了指定的 API
  ///
  /// [hookId] Hook 的唯一标识符
  /// [apiName] API 名称
  /// 返回 true 如果 API 存在
  bool hasHookAPI(String hookId, String apiName) => _apiRegistry.hasAPI(hookId, apiName);

  /// 获取 Hook 导出的所有 API
  ///
  /// [hookId] Hook 的唯一标识符
  /// 返回该 Hook 导出的所有 API（不含前缀）
  Map<String, dynamic> getHookAPIs(String hookId) => _apiRegistry.getHookAPIs(hookId);

  /// ===== 工具方法 =====

  /// 添加 Hook 包装器到映射
  ///
  /// [hookPointId] Hook 点 ID
  /// [wrapper] Hook 包装器
  void _addHookWrapper(String hookPointId, HookWrapper wrapper) {
    if (!_hooks.containsKey(hookPointId)) {
      _hooks[hookPointId] = [];
    }

    _hooks[hookPointId]!.add(wrapper);

    // 使用稳定排序算法：优先级 + 注册顺序
    //
    // 排序规则：
    // 1. 主排序键：Hook 优先级（数值越小优先级越高）
    // 2. 次要排序键：注册顺序（数值越小表示注册越早）
    //
    // 为什么需要稳定排序：
    // - 当多个 Hook 具有相同优先级时，排序算法应保持它们的注册顺序
    // - 确保插件开发者可以预测 Hook 的显示顺序
    // - 避免因排序不稳定导致的 UI 显示不一致问题
    //
    // 示例：
    // - Hook A (priority: 100, order: 0)
    // - Hook B (priority: 500, order: 1)
    // - Hook C (priority: 100, order: 2)
    // 排序结果：A (100,0) → C (100,2) → B (500,1)
    _hooks[hookPointId]!.sort((a, b) {
      // 主排序键：按优先级排序
      final priorityComparison = a.hook.priority.value
          .compareTo(b.hook.priority.value);

      // 如果优先级不同，直接返回优先级比较结果
      if (priorityComparison != 0) {
        return priorityComparison;
      }

      // 次要排序键：优先级相同时，按注册顺序排序
      // 这确保了相同优先级的 Hook 保持其注册顺序
      return a.registrationOrder.compareTo(b.registrationOrder);
    });

    _log.info('Registered hook wrapper: ${wrapper.hook.runtimeType}');
    _log.debug('  - Hook point: $hookPointId');
    _log.debug('  - Is enabled: ${wrapper.isEnabled}');
    _log.debug('  - Priority: ${wrapper.hook.priority}');
    _log.debug('  - Registration order: ${wrapper.registrationOrder}');
    _log.debug('  - Total hooks at this point: ${_hooks[hookPointId]!.length}');
  }

  /// 清空所有 Hook
  ///
  /// 主要用于测试
  void clear() {
    _hooks.clear();
    _pointRegistry.clear();
    _apiRegistry.clear();
  }

  /// 获取所有注册的 Hook 点（字符串 ID）
  Set<String> get registeredHookPointIds => _hooks.keys.toSet();

  /// 获取 Hook 总数
  int get totalHooks =>
      _hooks.values.fold(0, (sum, hooks) => sum + hooks.length);

  @override
  String toString() =>
      'HookRegistry(hookPoints: ${_pointRegistry.count}, hooks: $totalHooks)';
}

/// 全局 Hook 注册表实例
final hookRegistry = HookRegistry();
