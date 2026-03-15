import '../plugin.dart';
import 'hook_point.dart';
import 'hook_context.dart';
import 'package:flutter/widgets.dart';

/// UI Hook 接口
abstract class UIHook extends Plugin {
  /// Hook 点
  HookPointId get hookPoint;

  /// 优先级（数值越小优先级越高）
  int get priority => 100;

  /// 渲染 Hook 内容
  Widget render(HookContext context);

  /// 是否可见
  bool isVisible(HookContext context) => true;

  /// 初始化 Hook
  Future<void> onInit();

  /// 销毁 Hook
  Future<void> onDispose();
}

/// 主工具栏 Hook
abstract class MainToolbarHook extends UIHook {
  @override
  HookPointId get hookPoint => HookPointId.mainToolbar;

  @override
  Widget render(HookContext context) {
    final toolbarContext = MainToolbarHookContext(context.data);
    return renderToolbar(toolbarContext);
  }

  /// 渲染工具栏内容
  Widget renderToolbar(MainToolbarHookContext context);
}

/// 节点上下文菜单 Hook
abstract class NodeContextMenuHook extends UIHook {
  @override
  HookPointId get hookPoint => HookPointId.nodeContextMenu;

  @override
  Widget render(HookContext context) {
    final menuContext = NodeContextMenuHookContext(context.data);
    return renderMenu(menuContext);
  }

  /// 渲染菜单内容
  Widget renderMenu(NodeContextMenuHookContext context);
}

/// 图上下文菜单 Hook
abstract class GraphContextMenuHook extends UIHook {
  @override
  HookPointId get hookPoint => HookPointId.graphContextMenu;

  @override
  Widget render(HookContext context) {
    final menuContext = GraphContextMenuHookContext(context.data);
    return renderMenu(menuContext);
  }

  /// 渲染菜单内容
  Widget renderMenu(GraphContextMenuHookContext context);
}

/// 侧边栏顶部 Hook
abstract class SidebarTopHook extends UIHook {
  @override
  HookPointId get hookPoint => HookPointId.sidebarTop;

  @override
  Widget render(HookContext context) {
    final sidebarContext = SidebarHookContext(context.data);
    return renderSidebar(sidebarContext);
  }

  /// 渲染侧边栏内容
  Widget renderSidebar(SidebarHookContext context);
}

/// 侧边栏底部 Hook
abstract class SidebarBottomHook extends UIHook {
  @override
  HookPointId get hookPoint => HookPointId.sidebarBottom;

  @override
  Widget render(HookContext context) {
    final sidebarContext = SidebarHookContext(context.data);
    return renderSidebar(sidebarContext);
  }

  /// 渲染侧边栏内容
  Widget renderSidebar(SidebarHookContext context);
}

/// 状态栏 Hook
abstract class StatusBarHook extends UIHook {
  @override
  HookPointId get hookPoint => HookPointId.statusBar;

  @override
  Widget render(HookContext context) {
    final statusContext = StatusBarHookContext(context.data);
    return renderStatusBar(statusContext);
  }

  /// 渲染状态栏内容
  Widget renderStatusBar(StatusBarHookContext context);
}

/// 节点编辑器 Hook
abstract class NodeEditorHook extends UIHook {
  @override
  HookPointId get hookPoint => HookPointId.nodeEditor;

  @override
  Widget render(HookContext context) {
    final editorContext = NodeEditorHookContext(context.data);
    return renderEditor(editorContext);
  }

  /// 渲染编辑器内容
  Widget renderEditor(NodeEditorHookContext context);
}

/// 导入导出 Hook
abstract class ImportExportHook extends UIHook {
  @override
  HookPointId get hookPoint => HookPointId.importExport;

  @override
  Widget render(HookContext context) {
    final importExportContext = ImportExportHookContext(context.data);
    return renderImportExport(importExportContext);
  }

  /// 渲染导入导出内容
  Widget renderImportExport(ImportExportHookContext context);
}

/// 设置 Hook
abstract class SettingsHook extends UIHook {
  @override
  HookPointId get hookPoint => HookPointId.settings;

  @override
  Widget render(HookContext context) {
    final settingsContext = SettingsHookContext(context.data);
    return renderSettings(settingsContext);
  }

  /// 渲染设置内容
  Widget renderSettings(SettingsHookContext context);
}

/// 帮助 Hook
abstract class HelpHook extends UIHook {
  @override
  HookPointId get hookPoint => HookPointId.help;

  @override
  Widget render(HookContext context) {
    final helpContext = HelpHookContext(context.data);
    return renderHelp(helpContext);
  }

  /// 渲染帮助内容
  Widget renderHelp(HelpHookContext context);
}