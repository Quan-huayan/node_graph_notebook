import 'package:flutter/material.dart';

import 'hook_context.dart';
import 'hook_point.dart';
import 'hook_registry.dart';

/// Hook 容器组件
class HookContainer {
  /// 创建一个新的 Hook 容器实例。
  ///
  /// [hookPoint] Hook 点
  /// [context] Hook 上下文
  HookContainer({required this.hookPoint, required this.context});

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

    debugPrint('[HookContainer] render() for ${hookPoint.id}:');
    debugPrint('  - Hook point: ${hookPoint.name}');
    debugPrint('  - Number of hooks to render: ${hooks.length}');

    for (final hook in hooks) {
      try {
        debugPrint('  - Rendering hook: ${hook.metadata.id}');
        final result = hook.render(context);
        results.add(result);
        debugPrint('    ✓ Successfully rendered');
      } catch (e) {
        debugPrint('[HookContainer] Error rendering hook $hook: $e');
      }
    }

    debugPrint('  - Total rendered widgets: ${results.length}');
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
  bool get hasHooks => hookRegistry.hasHooks(hookPoint.id);

  /// 获取 Hook 数量
  int get hookCount => hookRegistry.getHooks(hookPoint.id).length;
}

/// Hook 容器工厂
class HookContainerFactory {
  /// 创建 Hook 容器
  ///
  /// [hookPoint] Hook 点
  /// [context] Hook 上下文
  static HookContainer create(HookPoint hookPoint, HookContext context) => HookContainer(hookPoint: hookPoint, context: context);

  /// 创建节点上下文菜单 Hook 容器
  static HookContainer createNodeContextMenuContainer(
    NodeContextMenuHookContext context,
  ) => HookContainer(
      hookPoint: StandardHookPoints.nodeContextMenu,
      context: context,
    );

  /// 创建图上下文菜单 Hook 容器
  static HookContainer createGraphContextMenuContainer(
    GraphContextMenuHookContext context,
  ) => HookContainer(
      hookPoint: StandardHookPoints.graphContextMenu,
      context: context,
    );

  /// 创建工具栏 Hook 容器
  static HookContainer createToolbarContainer(HookContext context) => HookContainer(
      hookPoint: StandardHookPoints.mainToolbar,
      context: context,
    );

  /// 创建侧边栏顶部 Hook 容器
  static HookContainer createSidebarTopContainer(HookContext context) => HookContainer(
      hookPoint: StandardHookPoints.sidebarTop,
      context: context,
    );

  /// 创建侧边栏底部 Hook 容器
  static HookContainer createSidebarBottomContainer(HookContext context) => HookContainer(
      hookPoint: StandardHookPoints.sidebarBottom,
      context: context,
    );

  /// 创建状态栏 Hook 容器
  static HookContainer createStatusBarContainer(HookContext context) => HookContainer(
      hookPoint: StandardHookPoints.statusBar,
      context: context,
    );
}
