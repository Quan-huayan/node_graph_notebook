import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/graph/graph_bloc.dart';
import '../../bloc/graph/graph_event.dart';
import '../../bloc/graph/graph_state.dart';

/// Graph Plugin 接口
abstract class GraphPlugin {
  /// 插件唯一标识
  String get id;

  /// 插件名称
  String get name;

  /// 插件描述
  String get description;

  /// 插件版本
  String get version;

  /// 初始化插件
  Future<void> initialize(GraphBloc bloc);

  /// 释放资源
  Future<void> dispose();

  /// 执行插件命令
  Future<void> execute(
    Map<String, dynamic> data,
    GraphBloc bloc,
    Emitter<GraphState> emit,
  );

  /// 监听状态变化
  void onStateChanged(GraphState oldState, GraphState newState) {}

  /// 转换事件（可选）
  GraphEvent? transformEvent(GraphEvent event) => event;

  /// 转换状态（可选）
  GraphState? transformState(GraphState state) => state;
}

/// 插件注册表
class PluginRegistry {
  PluginRegistry(this.bloc);

  final GraphBloc bloc;
  final Map<String, GraphPlugin> _plugins = {};
  GraphState? _previousState;

  /// 注册插件
  Future<void> register(GraphPlugin plugin) async {
    if (_plugins.containsKey(plugin.id)) {
      throw ArgumentError('Plugin ${plugin.id} already registered');
    }

    await plugin.initialize(bloc);
    _plugins[plugin.id] = plugin;

    // 订阅状态变化
    bloc.stream.listen((newState) {
      if (_previousState != null) {
        for (final plugin in _plugins.values) {
          try {
            plugin.onStateChanged(_previousState!, newState);
          } catch (e) {
            debugPrint('Plugin ${plugin.id} onStateChanged error: $e');
          }
        }
      }
      _previousState = newState;
    });
  }

  /// 注销插件
  Future<void> unregister(String pluginId) async {
    final plugin = _plugins.remove(pluginId);
    if (plugin != null) {
      await plugin.dispose();
    }
  }

  /// 获取插件
  GraphPlugin? getPlugin(String id) => _plugins[id];

  /// 检查插件是否已注册
  bool hasPlugin(String id) => _plugins.containsKey(id);

  /// 获取所有插件
  List<GraphPlugin> get allPlugins => _plugins.values.toList();

  /// 清空所有插件
  Future<void> clear() async {
    for (final plugin in _plugins.values) {
      await plugin.dispose();
    }
    _plugins.clear();
  }
}

/// 基础插件实现（提供默认行为）
abstract class BasePlugin extends GraphPlugin {
  @override
  Future<void> initialize(GraphBloc bloc) async {
    // 默认实现：什么都不做
  }

  @override
  Future<void> dispose() async {
    // 默认实现：什么都不做
  }

  @override
  void onStateChanged(GraphState oldState, GraphState newState) {
    // 默认实现：什么都不做
  }
}
