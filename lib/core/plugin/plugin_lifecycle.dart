import 'package:flutter/foundation.dart';
import 'plugin.dart';

/// 插件生命周期管理器
///
/// 管理插件的状态转换和生命周期
class PluginLifecycleManager {
  PluginLifecycleManager(this._plugin);

  final Plugin _plugin;
  PluginState _state = PluginState.unloaded;
  final List<PluginStateListener> _listeners = [];

  /// 当前状态
  PluginState get state => _state;

  /// 检查是否可以转换到目标状态
  bool canTransitionTo(PluginState targetState) {
    switch (_state) {
      case PluginState.unloaded:
        return targetState == PluginState.loaded ||
            targetState == PluginState.loadFailed;

      case PluginState.loaded:
        return targetState == PluginState.enabled ||
            targetState == PluginState.disabled ||
            targetState == PluginState.unloaded;

      case PluginState.enabled:
        return targetState == PluginState.disabled ||
            targetState == PluginState.unloaded;

      case PluginState.disabled:
        return targetState == PluginState.enabled ||
            targetState == PluginState.unloaded;

      case PluginState.loadFailed:
      case PluginState.enableFailed:
        return targetState == PluginState.unloaded;
    }
  }

  /// 转换到目标状态
  ///
  /// [targetState] 目标状态
  /// [action] 状态转换时执行的操作
  Future<void> transitionTo(
    PluginState targetState,
    Future<void> Function() action,
  ) async {
    if (!canTransitionTo(targetState)) {
      throw PluginStateException(
        _plugin.metadata.id,
        _state.name,
        targetState.name,
      );
    }

    final oldState = _state;
    try {
      await action();
      _state = targetState;
      _notifyListeners(oldState, targetState);
    } catch (e) {
      // 转换失败，根据目标状态设置相应的失败状态
      if (targetState == PluginState.loaded) {
        _state = PluginState.loadFailed;
      } else if (targetState == PluginState.enabled) {
        _state = PluginState.enableFailed;
      }
      _notifyListeners(oldState, _state);
      rethrow;
    }
  }

  /// 添加状态监听器
  void addListener(PluginStateListener listener) {
    _listeners.add(listener);
  }

  /// 移除状态监听器
  void removeListener(PluginStateListener listener) {
    _listeners.remove(listener);
  }

  /// 通知所有监听器
  void _notifyListeners(PluginState oldState, PluginState newState) {
    for (final listener in _listeners) {
      try {
        listener(_plugin, oldState, newState);
      } catch (e) {
        // 监听器异常不应影响其他监听器
        debugPrint('Error in plugin state listener: $e');
      }
    }
  }
}

/// 插件状态监听器
///
/// 用于监听插件状态变化
typedef PluginStateListener = void Function(
  Plugin plugin,
  PluginState oldState,
  PluginState newState,
);

/// 插件包装器
///
/// 包装插件及其上下文和生命周期管理器
class PluginWrapper {
  PluginWrapper(
    this.plugin,
    this.context,
    this.lifecycle,
  );

  final Plugin plugin;
  final PluginContext context;
  final PluginLifecycleManager lifecycle;

  /// 元数据快捷访问
  PluginMetadata get metadata => plugin.metadata;

  /// 状态快捷访问
  PluginState get state => lifecycle.state;

  /// 是否已加载
  bool get isLoaded => plugin.isLoaded;

  /// 是否已启用
  bool get isEnabled => plugin.isEnabled;
}
