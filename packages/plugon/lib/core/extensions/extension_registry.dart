import 'exceptions.dart';
import 'extension_contribution.dart';
import 'extension_point.dart';

/// 扩展点注册表的键：(扩展点类型, id)。
typedef _PointKey = ({Type type, String id});

/// 类型化扩展点注册表。
///
/// 激活语义：**由插件状态派生**——不存在每贡献的状态机，
/// 贡献的活跃性完全由 [setPluginActive] 决定；宿主贡献（owner 为 null）
/// 始终活跃。插件卸载时用 [removeOwner] 移除其全部贡献。
class ExtensionRegistry {
  final Map<_PointKey, ExtensionPoint<dynamic>> _points = {};
  final Map<_PointKey, List<ExtensionContribution<dynamic>>> _contributions =
      {};
  final Map<String, bool> _activePlugins = {};
  int _order = 0;

  /// 注册扩展点；同 (Type, id) 重复注册抛
  /// [ExtensionPointAlreadyRegisteredException]。
  void registerExtensionPoint<T>(ExtensionPoint<T> point) {
    final key = _keyOf(point);
    if (_points.containsKey(key)) {
      throw ExtensionPointAlreadyRegisteredException(point.id, T);
    }
    _points[key] = point;
  }

  /// 该扩展点是否已注册。
  bool hasExtensionPoint<T>(ExtensionPoint<T> point) =>
      _points.containsKey(_keyOf(point));

  /// 移除扩展点及其全部贡献。
  void removeExtensionPoint<T>(ExtensionPoint<T> point) {
    final key = _keyOf(point);
    _points.remove(key);
    _contributions.remove(key);
  }

  /// 所有已注册扩展点的 (Type, id) 键（供工具/测试使用）。
  Set<({Type type, String id})> get extensionPointKeys => _points.keys.toSet();

  /// 添加贡献；向未注册的扩展点添加抛
  /// [ExtensionPointNotRegisteredException]（拼写错误保护）。
  ///
  /// 重复贡献允许（扩展天然是加性的），按 [priority] 升序、
  /// 注册序破平后返回。
  void addContribution<T>(
    ExtensionPoint<T> point,
    T value, {
    int priority = 0,
    String? ownerPluginId,
  }) {
    final key = _keyOf(point);
    if (!_points.containsKey(key)) {
      throw ExtensionPointNotRegisteredException(point.id, T);
    }
    _contributions
        .putIfAbsent(key, () => [])
        .add(
          ExtensionContribution<T>(
            point: point,
            value: value,
            priority: priority,
            registrationOrder: _order++,
            ownerPluginId: ownerPluginId,
          ),
        );
  }

  /// 该扩展点的全部贡献（含非活跃），按优先级排序；未注册扩展点返回空。
  List<T> getAll<T>(ExtensionPoint<T> point) {
    final list = _contributions[_keyOf(point)];
    if (list == null) return const [];
    return _sortedValues(list);
  }

  /// 该扩展点的活跃贡献（排除非活跃插件的贡献），按优先级排序；
  /// 未注册扩展点返回空。
  List<T> getActive<T>(ExtensionPoint<T> point) {
    final list = _contributions[_keyOf(point)];
    if (list == null) return const [];
    return _sortedValues(list.where((c) => _isActive(c.ownerPluginId)));
  }

  /// 该扩展点是否存在贡献；[includeInactive] 为 false 时只统计活跃贡献。
  bool hasContributions<T>(
    ExtensionPoint<T> point, {
    bool includeInactive = false,
  }) {
    final list = _contributions[_keyOf(point)];
    if (list == null || list.isEmpty) return false;
    if (includeInactive) return true;
    return list.any((c) => _isActive(c.ownerPluginId));
  }

  /// 设置插件的活跃状态：活跃插件的贡献进入 [getActive]，反之排除。
  void setPluginActive(String pluginId, bool active) {
    _activePlugins[pluginId] = active;
  }

  /// 插件是否活跃（从未设置过视为非活跃）。
  bool isPluginActive(String pluginId) => _activePlugins[pluginId] ?? false;

  /// 移除插件的全部贡献与活跃状态（卸载清理）。
  void removeOwner(String pluginId) {
    _activePlugins.remove(pluginId);
    _contributions.removeWhere((key, list) {
      list.removeWhere((c) => c.ownerPluginId == pluginId);
      return list.isEmpty;
    });
  }

  /// 已注册扩展点数量。
  int get pointCount => _points.length;

  /// 全部贡献数量。
  int get contributionCount =>
      _contributions.values.fold(0, (sum, list) => sum + list.length);

  _PointKey _keyOf<T>(ExtensionPoint<T> point) => (type: T, id: point.id);

  bool _isActive(String? ownerPluginId) {
    if (ownerPluginId == null) return true;
    return _activePlugins[ownerPluginId] ?? false;
  }

  List<T> _sortedValues<T>(
    Iterable<ExtensionContribution<dynamic>> contributions,
  ) {
    final sorted = List.of(contributions)
      ..sort((a, b) {
        final byPriority = a.priority.compareTo(b.priority);
        return byPriority != 0
            ? byPriority
            : a.registrationOrder.compareTo(b.registrationOrder);
      });
    return sorted.map((c) => c.value as T).toList();
  }
}
