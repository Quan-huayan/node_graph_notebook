import 'package:flutter/material.dart';

import '../../../core/plugin/plugin_context.dart';
import '../../../core/plugin/plugin_metadata.dart';
import '../../../core/plugin/ui_hooks/hook_context.dart';
import '../../../core/plugin/ui_hooks/ui_hook.dart';

/// 侧边栏插件
///
/// 提供侧边栏功能，通过 UI Hook 集成到侧边栏区域，显示节点列表等内容
class SidebarPlugin extends SidebarTopHook {
  /// 获取插件优先级
  ///
  /// 返回插件的优先级值，数值越小优先级越高
  @override
  int get priority => 40;

  /// 获取插件元数据
  ///
  /// 返回包含插件ID、名称、版本等信息的元数据
  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'sidebar_plugin',
    name: 'Sidebar Plugin',
    version: '1.0.0',
    description: 'Provides sidebar functionality',
    author: 'Node Graph Notebook',
  );

  /// 渲染侧边栏内容
  ///
  /// [context]: 侧边栏钩子上下文，包含渲染所需的信息
  ///
  /// 返回侧边栏的 UI 组件
  @override
  Widget renderSidebar(SidebarHookContext context) => const Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Nodes',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        // 这里可以添加节点列表或其他侧边栏内容
        Padding(
          padding: EdgeInsets.all(16),
          child: Text('Node list will be implemented here'),
        ),
      ],
    );

  /// 初始化插件
  ///
  /// 插件初始化时调用的方法
  @override
  Future<void> onInit() async {}

  /// 销毁插件
  ///
  /// 插件销毁时调用的方法，用于清理资源
  @override
  Future<void> onDispose() async {}

  /// 启用插件
  ///
  /// 插件启用时调用的方法
  @override
  Future<void> onEnable() async {}

  /// 禁用插件
  ///
  /// 插件禁用时调用的方法
  @override
  Future<void> onDisable() async {}

  /// 加载插件
  ///
  /// [context]: 插件上下文，包含系统服务和API
  ///
  /// 插件加载时调用的方法
  @override
  Future<void> onLoad(PluginContext context) async {}

  /// 卸载插件
  ///
  /// 插件卸载时调用的方法
  @override
  Future<void> onUnload() async {}

  /// 获取插件当前状态
  ///
  /// 返回当前插件的加载状态
  @override
  PluginState get state => PluginState.loaded;

  /// 设置插件状态
  ///
  /// [newState]: 新的插件状态
  @override
  set state(PluginState newState) {}
}
