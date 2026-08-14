import 'package:core/core.dart';
import 'package:flutter/material.dart';

import 'hook_contexts.dart';

/// 专用 Hook 基类（用于类型安全的上下文）
///
/// 提供特定 Hook 点的类型安全上下文访问
///
/// 架构说明：
/// - 类似旧系统中的 MainToolbarHook、SidebarTopHook 等
/// - 但不继承 UIHookBase，而是作为辅助类
/// - 提供 renderToolbar() 等类型安全的方法
/// - 减少样板代码，简化 Hook 开发
///
/// 使用示例：
/// ```dart
/// abstract class MyMainToolbarHook extends MainToolbarHookBase {
///   @override
///   Widget renderToolbar(MainToolbarHookContext context) {
///     // 类型安全的上下文访问
///     return IconButton(...);
///   }
/// }
/// ```
abstract class MainToolbarHookRole extends HookRoleBase {
  @override
  String get hookPointId => 'main.toolbar';

  @override
  Widget render(HookContext context) {
    final toolbarContext = MainToolbarHookContext(
      data: context.data,
      pluginContext: context.pluginContext,
      hookAPIRegistry: context.hookAPIRegistry,
    );
    return renderToolbar(toolbarContext);
  }

  /// 渲染工具栏内容
  ///
  /// [context] 主工具栏上下文
  /// 返回要渲染的 Widget
  Widget renderToolbar(MainToolbarHookContext context);
}

/// 节点上下文菜单 Hook 基类
abstract class NodeContextMenuHookRole extends HookRoleBase {
  @override
  String get hookPointId => 'context_menu.node';

  @override
  Widget render(HookContext context) {
    final menuContext = NodeContextMenuHookContext(
      data: context.data,
      pluginContext: context.pluginContext,
      hookAPIRegistry: context.hookAPIRegistry,
    );
    return renderMenu(menuContext);
  }

  /// 渲染菜单内容
  ///
  /// [context] 节点上下文菜单上下文
  /// 返回要渲染的 Widget
  Widget renderMenu(NodeContextMenuHookContext context);
}

/// 图上下文菜单 Hook 基类
abstract class GraphContextMenuHookRole extends HookRoleBase {
  @override
  String get hookPointId => 'context_menu.graph';

  @override
  Widget render(HookContext context) {
    final menuContext = GraphContextMenuHookContext(
      data: context.data,
      pluginContext: context.pluginContext,
      hookAPIRegistry: context.hookAPIRegistry,
    );
    return renderMenu(menuContext);
  }

  /// 渲染菜单内容
  ///
  /// [context] 图上下文菜单上下文
  /// 返回要渲染的 Widget
  Widget renderMenu(GraphContextMenuHookContext context);
}

/// 侧边栏 Hook 基类
abstract class SidebarHookRole extends HookRoleBase {
  @override
  Widget render(HookContext context) {
    final sidebarContext = SidebarHookContext(
      data: context.data,
      pluginContext: context.pluginContext,
      hookAPIRegistry: context.hookAPIRegistry,
    );
    return renderSidebar(sidebarContext);
  }

  /// 渲染侧边栏内容
  ///
  /// [context] 侧边栏上下文
  /// 返回要渲染的 Widget
  Widget renderSidebar(SidebarHookContext context);
}

/// 侧边栏底部 Hook 基类
abstract class SidebarBottomHookRole extends HookRoleBase {
  @override
  String get hookPointId => 'sidebar.bottom';

  @override
  Widget render(HookContext context) {
    final sidebarContext = SidebarHookContext(
      data: context.data,
      pluginContext: context.pluginContext,
      hookAPIRegistry: context.hookAPIRegistry,
    );
    return renderSidebar(sidebarContext);
  }

  /// 渲染侧边栏底部内容
  ///
  /// [context] 侧边栏上下文
  /// 返回要渲染的 Widget
  Widget renderSidebar(SidebarHookContext context);
}

/// 状态栏 Hook 基类
abstract class StatusBarHookRole extends HookRoleBase {
  @override
  Widget render(HookContext context) {
    final statusContext = StatusBarHookContext(
      data: context.data,
      pluginContext: context.pluginContext,
      hookAPIRegistry: context.hookAPIRegistry,
    );
    return renderStatusBar(statusContext);
  }

  /// 渲染状态栏内容
  ///
  /// [context] 状态栏上下文
  /// 返回要渲染的 Widget
  Widget renderStatusBar(StatusBarHookContext context);
}

/// 图工具栏 Hook 基类
///
/// 用于 graph 插件的可拖动工具栏
/// 使用独立的 hook point 'graph.toolbar'，避免与主工具栏按钮重复
abstract class GraphToolbarHookRole extends HookRoleBase {
  @override
  String get hookPointId => 'graph.toolbar';

  @override
  Widget render(HookContext context) {
    final toolbarContext = MainToolbarHookContext(
      data: context.data,
      pluginContext: context.pluginContext,
      hookAPIRegistry: context.hookAPIRegistry,
    );
    return renderToolbar(toolbarContext);
  }

  /// 渲染工具栏内容
  ///
  /// [context] 主工具栏上下文
  /// 返回要渲染的 Widget
  Widget renderToolbar(MainToolbarHookContext context);
}

/// Sidebar标签页Hook基类
///
/// 插件通过实现此Hook来注册Sidebar标签页
///
/// 架构说明：
/// - 继承自UIHookBase，使用'sidebar.tab' Hook点
/// - Hook提供完整的标签页（标签按钮 + 内容区域）
/// - Sidebar收集所有Hook并渲染标签栏和内容区
///
/// 使用示例：
/// ```dart
/// class NodesSidebarTabHook extends SidebarTabHookBase {
///   @override
///   String get tabId => 'nodes';
///
///   @override
///   String get tabLabel => 'Nodes';
///
///   @override
///   IconData get tabIcon => Icons.list;
///
///   @override
///   Widget buildContent(SidebarHookContext context) {
///     return ListView.builder(...);
///   }
/// }
/// ```
abstract class SidebarTabHookRole extends HookRoleBase {
  @override
  String get hookPointId => 'sidebar.tab';

  /// 标签页ID（唯一标识）
  String get tabId;

  /// 标签页标题
  String get tabLabel;

  /// 标签页图标
  IconData get tabIcon;

  /// 标签页优先级（控制排序）
  HookPriority get tabPriority => HookPriority.medium;

  /// 构建标签页内容
  ///
  /// [context] Sidebar Hook上下文，包含节点数据、回调函数等
  /// 返回要渲染的Widget
  Widget buildContent(SidebarHookContext context);

  @override
  Widget render(HookContext context) =>
      // Sidebar会直接调用buildContent，这里返回空Widget
      const SizedBox.shrink();

  /// 标签页是否可见
  ///
  /// [context] Sidebar Hook上下文
  /// 返回true如果标签页应该显示，否则返回false
  ///
  /// 默认返回true，子类可以重写以实现条件显示
  bool isTabVisible(SidebarHookContext context) => true;
}

/// Root Hook 基类
///
/// 用于主窗口布局的 Hook，负责渲染整体应用框架
///
/// 架构说明：
/// - 使用 'root' Hook 点
/// - 负责渲染工具栏、侧边栏、主内容区、状态栏等
/// - 使用 Stack 支持上下文菜单等 overlay
abstract class RootHookRole extends HookRoleBase {
  @override
  String get hookPointId => 'root';

  @override
  Future<void> onInit(HookContext context) async {
    final rootContext = RootHookContext(
      data: context.data,
      pluginContext: context.pluginContext,
      hookAPIRegistry: context.hookAPIRegistry,
    );
    await onInitRoot(rootContext);
  }

  @override
  Widget render(HookContext context) {
    final rootContext = RootHookContext(
      data: context.data,
      pluginContext: context.pluginContext,
      hookAPIRegistry: context.hookAPIRegistry,
    );
    return renderRoot(rootContext);
  }

  /// 初始化 Root Hook
  ///
  /// [context] Root Hook 上下文
  Future<void> onInitRoot(RootHookContext context) async {}

  /// 渲染主窗口布局
  ///
  /// [context] Root Hook 上下文
  /// 返回要渲染的 Widget
  Widget renderRoot(RootHookContext context);
}

/// Sidebar 布局 Hook 基类
///
/// 用于侧边栏布局的 Hook，负责渲染侧边栏整体结构
///
/// 架构说明：
/// - 使用 'sidebar' Hook 点
/// - 负责渲染侧边栏容器和子 Hook（如 sidebar.bottom）
abstract class SidebarLayoutHookRole extends HookRoleBase {
  @override
  String get hookPointId => 'sidebar';

  @override
  Future<void> onInit(HookContext context) async {
    final sidebarContext = SidebarLayoutHookContext(
      data: context.data,
      pluginContext: context.pluginContext,
      hookAPIRegistry: context.hookAPIRegistry,
    );
    await onInitSidebar(sidebarContext);
  }

  @override
  Widget render(HookContext context) {
    final sidebarContext = SidebarLayoutHookContext(
      data: context.data,
      pluginContext: context.pluginContext,
      hookAPIRegistry: context.hookAPIRegistry,
    );
    return renderSidebar(sidebarContext);
  }

  /// 初始化 Sidebar Hook
  ///
  /// [context] Sidebar Hook 上下文
  Future<void> onInitSidebar(SidebarLayoutHookContext context) async {}

  /// 渲染侧边栏布局
  ///
  /// [context] Sidebar Hook 上下文
  /// 返回要渲染的 Widget
  Widget renderSidebar(SidebarLayoutHookContext context);
}

/// MainToolbar 布局 Hook 基类
///
/// 用于主工具栏布局的 Hook，负责渲染工具栏整体结构
///
/// 架构说明：
/// - 使用 'main.toolbar.layout' Hook 点
/// - 负责渲染工具栏容器和子 Hook（如 main.toolbar）
abstract class MainToolbarLayoutHookRole extends HookRoleBase {
  @override
  String get hookPointId => 'main.toolbar.layout';

  @override
  Future<void> onInit(HookContext context) async {
    final toolbarContext = MainToolbarHookContext(
      data: context.data,
      pluginContext: context.pluginContext,
      hookAPIRegistry: context.hookAPIRegistry,
    );
    await onInitToolbar(toolbarContext);
  }

  @override
  Widget render(HookContext context) {
    final toolbarContext = MainToolbarHookContext(
      data: context.data,
      pluginContext: context.pluginContext,
      hookAPIRegistry: context.hookAPIRegistry,
    );
    return renderToolbar(toolbarContext);
  }

  /// 初始化 MainToolbar Hook
  ///
  /// [context] MainToolbar Hook 上下文
  Future<void> onInitToolbar(MainToolbarHookContext context) async {}

  /// 渲染工具栏布局
  ///
  /// [context] MainToolbar Hook 上下文
  /// 返回要渲染的 Widget
  Widget renderToolbar(MainToolbarHookContext context);
}