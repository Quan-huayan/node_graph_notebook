import '../di/service_collection.dart';
import '../di/service_provider.dart';
import '../extensions/extension_registry.dart';
import 'exceptions.dart';
import 'plugin.dart';
import 'plugin_context.dart';

/// 插件生命周期状态。
enum PluginState {
  /// 未加载（或已卸载）。
  unloaded,

  /// 已加载（服务与扩展已注册，onLoad 完成）。
  loaded,

  /// 已启用（onEnable 完成，依赖已启用）。
  enabled,

  /// 已停用（onDisable 完成）。
  disabled,

  /// 启用/停用回调抛错后的终态。
  error,
}

/// 插件生命周期编排器。
///
/// - **加载顺序无关**：插件可以任意顺序 load，启用时按依赖拓扑序；
///   卸载按逆拓扑序（先卸依赖者）。
/// - **错误策略**：load/enable 快速失败（记录 lastError、置 error 态并重抛）；
///   unload 逐阶段捕获继续清理，最后重抛首个错误。永不静默丢弃。
/// - **并发安全**：loadPlugin 在任何 await 之前占位，杜绝重复加载。
class PluginManager {
  /// 构造：可注入宿主已有的注册表（默认自建）。
  PluginManager({ServiceCollection? services, ExtensionRegistry? extensions})
    : _collection = services ?? ServiceCollection(),
      _extensions = extensions ?? ExtensionRegistry();

  final ServiceCollection _collection;
  final ExtensionRegistry _extensions;
  final Map<String, _PluginRecord> _plugins = {};
  final Map<String, Object> _lastErrors = {};
  ServiceProvider? _provider;

  /// 服务容器（懒构建）。后续 loadPlugin 会失效并重建：
  /// 已实例化的单例身份在晚加载后可能变化——契约要求
  /// 所有相关插件加载完成后再跨插件解析服务。
  ServiceProvider get services => _provider ??= _collection.build();

  /// 全局扩展注册表（宿主可在此声明扩展点）。
  ExtensionRegistry get extensions => _extensions;

  /// 加载插件：注册服务（owned 视图盖章）→ 注册扩展 → onLoad →
  /// （enabledByDefault 时）自动启用。
  ///
  /// 重复加载抛 [PluginAlreadyLoadedException]；失败时回滚全部注册、
  /// 记录 lastError 并重抛，插件可从 map 移除以便重试。
  Future<void> loadPlugin(Plugin plugin) async {
    final id = plugin.metadata.id;
    if (_plugins.containsKey(id)) {
      throw PluginAlreadyLoadedException(id);
    }
    final record = _PluginRecord(plugin);
    _plugins[id] = record; // 在任何 await 之前占位（并发保护）
    try {
      plugin.registerServices(_collection.owned(id));
      plugin.registerExtensions(_extensions);
      final oldProvider = _provider;
      _provider = null; // 失效缓存：下次访问重建，纳入新注册的描述符
      oldProvider?.dispose();
      final context = PluginContext(
        pluginId: id,
        metadata: plugin.metadata,
        services: services,
        extensions: _extensions,
      );
      record.context = context;
      await plugin.onLoad(context);
      record.state = PluginState.loaded;
      if (plugin.metadata.enabledByDefault) {
        await enablePlugin(id);
      }
    } catch (e) {
      _plugins.remove(id);
      _collection.removeOwner(id);
      _extensions.removeOwner(id);
      _provider = null; // 丢弃可能含失败插件描述符的 provider
      _lastErrors[id] = e;
      rethrow;
    }
  }

  /// 启用插件：先按依赖拓扑序启用其依赖，再调用 onEnable。
  ///
  /// 已启用时幂等返回；依赖缺失抛 [PluginDependencyException]；
  /// 依赖循环抛 [PluginDependencyCycleException]。
  Future<void> enablePlugin(String pluginId) async {
    final record = _plugins[pluginId];
    if (record == null) {
      throw StateError('插件 "$pluginId" 未加载');
    }
    final state = record.state;
    if (state == PluginState.enabled) return;
    if (state != PluginState.loaded && state != PluginState.disabled) {
      throw StateError('插件 "$pluginId" 当前状态 $state，无法启用');
    }
    await _enableWithDeps(pluginId, {});
  }

  /// 停用插件：调用 onDisable 并置 disabled；已停用时幂等返回。
  Future<void> disablePlugin(String pluginId) async {
    final record = _plugins[pluginId];
    if (record == null) {
      throw StateError('插件 "$pluginId" 未加载');
    }
    if (record.state == PluginState.disabled) return;
    if (record.state != PluginState.enabled) {
      throw StateError('插件 "$pluginId" 当前状态 ${record.state}，无法停用');
    }
    await _disable(record);
  }

  /// 卸载插件：先卸载其依赖者（逆拓扑），再执行
  /// onDisable（若已启用）→ onUnload → 服务清理 → 扩展清理 → 移除。
  ///
  /// 各阶段错误被记录（lastError）并继续清理，最后重抛首个错误。
  Future<void> unloadPlugin(String pluginId) async {
    await _unloadWithDependents(pluginId, {});
  }

  /// 卸载全部插件（逆拓扑），重抛首个错误。
  Future<void> dispose() async {
    Object? firstError;
    for (final id in List.of(_plugins.keys)) {
      try {
        await unloadPlugin(id);
      } catch (e) {
        firstError ??= e;
      }
    }
    if (firstError != null) throw firstError;
  }

  /// 已加载插件 id 列表。
  List<String> get pluginIds => _plugins.keys.toList();

  /// 已启用插件 id 集合。
  Set<String> get enabledPluginIds => _plugins.values
      .where((r) => r.state == PluginState.enabled)
      .map((r) => r.plugin.metadata.id)
      .toSet();

  /// 插件当前状态；未加载返回 unloaded。
  PluginState getPluginState(String pluginId) =>
      _plugins[pluginId]?.state ?? PluginState.unloaded;

  /// 插件上下文（onLoad 之后可用）。
  PluginContext? getContext(String pluginId) => _plugins[pluginId]?.context;

  /// 插件最近一次错误（加载/启用/停用/卸载失败时记录）。
  Object? lastError(String pluginId) => _lastErrors[pluginId];

  /// 已加载插件数量。
  int get pluginCount => _plugins.length;

  /// 深度优先启用依赖链：visiting 集检测循环，依赖先启用（拓扑序）。
  Future<void> _enableWithDeps(String pluginId, Set<String> visiting) async {
    if (!visiting.add(pluginId)) {
      throw PluginDependencyCycleException(pluginId, [...visiting, pluginId]);
    }
    try {
      final record = _plugins[pluginId];
      if (record == null) {
        throw StateError('插件 "$pluginId" 未加载');
      }
      if (record.state == PluginState.enabled) return;
      for (final depId in record.plugin.metadata.dependencies) {
        if (!_plugins.containsKey(depId)) {
          throw PluginDependencyException(pluginId, depId);
        }
        await _enableWithDeps(depId, visiting);
      }
      await _doEnable(record);
    } finally {
      visiting.remove(pluginId);
    }
  }

  Future<void> _doEnable(_PluginRecord record) async {
    final id = record.plugin.metadata.id;
    try {
      await record.plugin.onEnable();
      record.state = PluginState.enabled;
      _extensions.setPluginActive(id, true);
    } catch (e) {
      record.state = PluginState.error;
      _lastErrors[id] = e;
      rethrow;
    }
  }

  Future<void> _disable(_PluginRecord record) async {
    final id = record.plugin.metadata.id;
    try {
      await record.plugin.onDisable();
      record.state = PluginState.disabled;
    } catch (e) {
      record.state = PluginState.error;
      _lastErrors[id] = e;
      rethrow;
    } finally {
      _extensions.setPluginActive(id, false);
    }
  }

  /// 递归卸载：先卸依赖本插件的插件（逆拓扑），再卸自身。
  /// [unloading] 防止依赖环导致无限递归（环已被启用期检测，
  /// 此处为防御性保护）。
  Future<void> _unloadWithDependents(
    String pluginId,
    Set<String> unloading,
  ) async {
    if (!unloading.add(pluginId)) return;
    final record = _plugins[pluginId];
    if (record == null) return;
    for (final id in List.of(_plugins.keys)) {
      final r = _plugins[id];
      if (r != null && r.plugin.metadata.dependencies.contains(pluginId)) {
        await _unloadWithDependents(id, unloading);
      }
    }
    await _unloadSelf(record);
  }

  Future<void> _unloadSelf(_PluginRecord record) async {
    final id = record.plugin.metadata.id;
    Object? firstError;
    if (record.state == PluginState.enabled) {
      try {
        await _disable(record);
      } catch (e) {
        firstError = e;
      }
    }
    try {
      await record.plugin.onUnload();
    } catch (e) {
      firstError ??= e;
    }
    _extensions.removeOwner(id);
    _provider?.disposeOwner(id);
    _plugins.remove(id);
    record.state = PluginState.unloaded;
    if (firstError != null) {
      _lastErrors[id] = firstError;
      throw firstError;
    }
  }
}

/// 插件运行时记录（内部状态容器）。
class _PluginRecord {
  _PluginRecord(this.plugin);

  final Plugin plugin;
  PluginState state = PluginState.loaded;
  PluginContext? context;
}
