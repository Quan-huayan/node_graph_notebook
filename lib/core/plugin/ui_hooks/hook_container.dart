import 'package:flutter/material.dart';

import 'hook_point.dart';
import 'hook_context.dart';
import 'hook_registry.dart';

/// Hook 容器组件
class HookContainer {
  HookContainer({
    required this.hookPoint,
    required this.context,
  });

  /// Hook 点
  final HookPoint hookPoint;
  
  /// Hook 上下文
  final HookContext context;

  /// 渲染所有 Hook
  ///
  /// 返回渲染结果列表
  List<dynamic> render() {
    final hooks = hookRegistry.getHooks(hookPoint.id);
    final results = <dynamic>[];

    for (final hook in hooks) {
      try {
        final result = hook.render(context);
        results.add(result);
      } catch (e) {
        debugPrint('[HookContainer] Error rendering hook $hook: $e');
      }
    }

    return results;
  }

  /// 初始化所有 Hook
  Future<void> initialize() async {
    final hooks = hookRegistry.getHooks(hookPoint.id);
    for (final hook in hooks) {
      try {
        await hook.onInit();
      } catch (e) {
        debugPrint('[HookContainer] Error initializing hook $hook: $e');
      }
    }
  }

  /// 销毁所有 Hook
  Future<void> dispose() async {
    final hooks = hookRegistry.getHooks(hookPoint.id);
    for (final hook in hooks) {
      try {
        await hook.onDispose();
      } catch (e) {
        debugPrint('[HookContainer] Error disposing hook $hook: $e');
      }
    }
  }

  /// 处理事件
  ///
  /// [event] 事件数据
  ///
  /// 返回是否有 Hook 处理了事件
  bool handleEvent(dynamic event) {
    final hooks = hookRegistry.getHooks(hookPoint.id);
    for (final hook in hooks) {
      try {
        // UIHook 没有 handleEvent 方法，暂时返回 false
      } catch (e) {
        debugPrint('[HookContainer] Error handling event in hook $hook: $e');
      }
    }
    return false;
  }

  /// 检查是否有 Hook
  bool get hasHooks {
    return hookRegistry.hasHooks(hookPoint.id);
  }

  /// 获取 Hook 数量
  int get hookCount {
    return hookRegistry.getHooks(hookPoint.id).length;
  }
}

/// Hook 容器工厂
class HookContainerFactory {
  /// 创建 Hook 容器
  ///
  /// [hookPoint] Hook 点
  /// [context] Hook 上下文
  static HookContainer create(HookPoint hookPoint, HookContext context) {
    return HookContainer(
      hookPoint: hookPoint,
      context: context,
    );
  }

  /// 创建节点上下文菜单 Hook 容器
  static HookContainer createNodeContextMenuContainer(NodeContextMenuHookContext context) {
    return HookContainer(
      hookPoint: StandardHookPoints.nodeContextMenu,
      context: context,
    );
  }

  /// 创建图上下文菜单 Hook 容器
  static HookContainer createGraphContextMenuContainer(GraphContextMenuHookContext context) {
    return HookContainer(
      hookPoint: StandardHookPoints.graphContextMenu,
      context: context,
    );
  }

  /// 创建工具栏 Hook 容器
  static HookContainer createToolbarContainer(HookContext context) {
    return HookContainer(
      hookPoint: StandardHookPoints.mainToolbar,
      context: context,
    );
  }

  /// 创建侧边栏顶部 Hook 容器
  static HookContainer createSidebarTopContainer(HookContext context) {
    return HookContainer(
      hookPoint: StandardHookPoints.sidebarTop,
      context: context,
    );
  }

  /// 创建侧边栏底部 Hook 容器
  static HookContainer createSidebarBottomContainer(HookContext context) {
    return HookContainer(
      hookPoint: StandardHookPoints.sidebarBottom,
      context: context,
    );
  }

  /// 创建状态栏 Hook 容器
  static HookContainer createStatusBarContainer(HookContext context) {
    return HookContainer(
      hookPoint: StandardHookPoints.statusBar,
      context: context,
    );
  }
}
