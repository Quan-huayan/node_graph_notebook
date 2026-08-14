import 'dart:ui' as ui;

import 'package:core/core.dart';

/// 主工具栏 Hook 上下文
class MainToolbarHookContext extends HookContext {
  /// 创建一个新的主工具栏 Hook 上下文实例。
  ///
  /// [data] 上下文数据
  /// [pluginContext] 插件上下文
  /// [hookAPIRegistry] Hook API 注册表
  /// [enableTypeValidation] 是否启用类型验证
  MainToolbarHookContext({
    Map<String, dynamic>? data,
    PluginContext? pluginContext,
    HookAPIRegistry? hookAPIRegistry,
    bool enableTypeValidation = false,
  }) : super(
         data ?? {},
         pluginContext: pluginContext,
         hookAPIRegistry: hookAPIRegistry,
         enableTypeValidation: enableTypeValidation,
       );

  /// 是否显示标题
  bool get showTitle => get<bool>('showTitle') ?? true;

  /// 是否显示搜索
  bool get showSearch => get<bool>('showSearch') ?? true;
}

/// 节点上下文菜单 Hook 上下文
class NodeContextMenuHookContext extends HookContext {
  /// 创建一个新的节点上下文菜单 Hook 上下文实例。
  ///
  /// [node] 当前节点
  /// [data] 上下文数据
  /// [pluginContext] 插件上下文
  /// [hookAPIRegistry] Hook API 注册表
  /// [enableTypeValidation] 是否启用类型验证
  NodeContextMenuHookContext({
    Node? node,
    Map<String, dynamic>? data,
    PluginContext? pluginContext,
    HookAPIRegistry? hookAPIRegistry,
    bool enableTypeValidation = false,
  }) : super(
         data ?? {}
           ..['node'] = node,
         pluginContext: pluginContext,
         hookAPIRegistry: hookAPIRegistry,
         enableTypeValidation: enableTypeValidation,
       );

  /// 当前节点
  Node? get node => get<Node>('node');

  /// 是否为选中状态
  bool get isSelected => get<bool>('isSelected') ?? false;
}

/// 图上下文菜单 Hook 上下文
class GraphContextMenuHookContext extends HookContext {
  /// 创建一个新的图上下文菜单 Hook 上下文实例。
  ///
  /// [mousePosition] 鼠标位置
  /// [selectedNodeCount] 选中的节点数量
  /// [data] 上下文数据
  /// [pluginContext] 插件上下文
  /// [hookAPIRegistry] Hook API 注册表
  /// [enableTypeValidation] 是否启用类型验证
  GraphContextMenuHookContext({
    ui.Offset? mousePosition,
    int? selectedNodeCount,
    Map<String, dynamic>? data,
    PluginContext? pluginContext,
    HookAPIRegistry? hookAPIRegistry,
    bool enableTypeValidation = false,
  }) : super(
         data ?? {}
           ..['mousePosition'] = mousePosition
           ..['selectedNodeCount'] = selectedNodeCount,
         pluginContext: pluginContext,
         hookAPIRegistry: hookAPIRegistry,
         enableTypeValidation: enableTypeValidation,
       );

  /// 鼠标位置
  ui.Offset? get mousePosition => get<ui.Offset>('mousePosition');

  /// 选中的节点数量
  int get selectedNodeCount => get<int>('selectedNodeCount') ?? 0;
}

/// 侧边栏 Hook 上下文
class SidebarHookContext extends HookContext {
  /// 创建一个新的侧边栏 Hook 上下文实例。
  ///
  /// [isExpanded] 是否展开
  /// [width] 侧边栏宽度
  /// [data] 上下文数据
  /// [pluginContext] 插件上下文
  /// [hookAPIRegistry] Hook API 注册表
  /// [enableTypeValidation] 是否启用类型验证
  SidebarHookContext({
    bool? isExpanded,
    double? width,
    Map<String, dynamic>? data,
    PluginContext? pluginContext,
    HookAPIRegistry? hookAPIRegistry,
    bool enableTypeValidation = false,
  }) : super(
         data ?? {}
           ..['isExpanded'] = isExpanded
           ..['width'] = width,
         pluginContext: pluginContext,
         hookAPIRegistry: hookAPIRegistry,
         enableTypeValidation: enableTypeValidation,
       );

  /// 是否展开
  bool get isExpanded => get<bool>('isExpanded') ?? true;

  /// 侧边栏宽度
  double get width => get<double>('width') ?? 250;
}

/// 状态栏 Hook 上下文
class StatusBarHookContext extends HookContext {
  /// 创建一个新的状态栏 Hook 上下文实例。
  ///
  /// [nodeCount] 节点数量
  /// [connectionCount] 连接数量
  /// [currentMode] 当前模式
  /// [data] 上下文数据
  /// [pluginContext] 插件上下文
  /// [hookAPIRegistry] Hook API 注册表
  /// [enableTypeValidation] 是否启用类型验证
  StatusBarHookContext({
    int? nodeCount,
    int? connectionCount,
    String? currentMode,
    Map<String, dynamic>? data,
    PluginContext? pluginContext,
    HookAPIRegistry? hookAPIRegistry,
    bool enableTypeValidation = false,
  }) : super(
         data ?? {}
           ..['nodeCount'] = nodeCount
           ..['connectionCount'] = connectionCount
           ..['currentMode'] = currentMode,
         pluginContext: pluginContext,
         hookAPIRegistry: hookAPIRegistry,
         enableTypeValidation: enableTypeValidation,
       );

  /// 节点数量
  int get nodeCount => get<int>('nodeCount') ?? 0;

  /// 连接数量
  int get connectionCount => get<int>('connectionCount') ?? 0;

  /// 当前模式
  String get currentMode => get<String>('currentMode') ?? 'browse';
}

/// 节点编辑器 Hook 上下文
class NodeEditorHookContext extends HookContext {
  /// 创建一个新的节点编辑器 Hook 上下文实例。
  ///
  /// [node] 当前节点
  /// [isReadOnly] 是否为只读模式
  /// [data] 上下文数据
  /// [pluginContext] 插件上下文
  /// [hookAPIRegistry] Hook API 注册表
  /// [enableTypeValidation] 是否启用类型验证
  NodeEditorHookContext({
    Node? node,
    bool? isReadOnly,
    Map<String, dynamic>? data,
    PluginContext? pluginContext,
    HookAPIRegistry? hookAPIRegistry,
    bool enableTypeValidation = false,
  }) : super(
         data ?? {}
           ..['node'] = node
           ..['isReadOnly'] = isReadOnly,
         pluginContext: pluginContext,
         hookAPIRegistry: hookAPIRegistry,
         enableTypeValidation: enableTypeValidation,
       );

  /// 当前节点
  Node? get node => get<Node>('node');

  /// 是否为只读模式
  bool get isReadOnly => get<bool>('isReadOnly') ?? false;
}

/// 导入导出 Hook 上下文
class ImportExportHookContext extends HookContext {
  /// 创建一个新的导入导出 Hook 上下文实例。
  ///
  /// [importFormats] 支持的导入格式
  /// [exportFormats] 支持的导出格式
  /// [data] 上下文数据
  /// [pluginContext] 插件上下文
  /// [hookAPIRegistry] Hook API 注册表
  /// [enableTypeValidation] 是否启用类型验证
  ImportExportHookContext({
    List<String>? importFormats,
    List<String>? exportFormats,
    Map<String, dynamic>? data,
    PluginContext? pluginContext,
    HookAPIRegistry? hookAPIRegistry,
    bool enableTypeValidation = false,
  }) : super(
         data ?? {}
           ..['importFormats'] = importFormats
           ..['exportFormats'] = exportFormats,
         pluginContext: pluginContext,
         hookAPIRegistry: hookAPIRegistry,
         enableTypeValidation: enableTypeValidation,
       );

  /// 支持的导入格式
  List<String> get importFormats => get<List<String>>('importFormats') ?? [];

  /// 支持的导出格式
  List<String> get exportFormats => get<List<String>>('exportFormats') ?? [];
}


/// 帮助 Hook 上下文
class HelpHookContext extends HookContext {
  /// 创建一个新的帮助 Hook 上下文实例。
  ///
  /// [helpItems] 帮助文档列表
  /// [data] 上下文数据
  /// [pluginContext] 插件上下文
  /// [hookAPIRegistry] Hook API 注册表
  /// [enableTypeValidation] 是否启用类型验证
  HelpHookContext({
    List<HelpItem>? helpItems,
    Map<String, dynamic>? data,
    PluginContext? pluginContext,
    HookAPIRegistry? hookAPIRegistry,
    bool enableTypeValidation = false,
  }) : super(
         data ?? {}
           ..['helpItems'] = helpItems,
         pluginContext: pluginContext,
         hookAPIRegistry: hookAPIRegistry,
         enableTypeValidation: enableTypeValidation,
       );

  /// 帮助文档列表
  List<HelpItem> get helpItems => get<List<HelpItem>>('helpItems') ?? [];
}

/// 帮助项
class HelpItem {
  /// 创建一个新的帮助项实例。
  ///
  /// [title] 帮助项标题
  /// [content] 帮助项内容
  /// [icon] 帮助项图标
  HelpItem({required this.title, required this.content, this.icon});

  /// 帮助项标题
  final String title;

  /// 帮助项内容
  final String content;

  /// 帮助项图标
  final String? icon;
}

/// Root Hook 上下文
///
/// 用于主窗口布局的 Hook 上下文
class RootHookContext extends HookContext {
  /// 创建一个新的 Root Hook 上下文实例。
  ///
  /// [data] 上下文数据
  /// [pluginContext] 插件上下文
  /// [hookAPIRegistry] Hook API 注册表
  /// [enableTypeValidation] 是否启用类型验证
  RootHookContext({
    Map<String, dynamic>? data,
    PluginContext? pluginContext,
    HookAPIRegistry? hookAPIRegistry,
    bool enableTypeValidation = false,
  }) : super(
         data ?? {},
         pluginContext: pluginContext,
         hookAPIRegistry: hookAPIRegistry,
         enableTypeValidation: enableTypeValidation,
       );

  /// 子 Hook 列表
  List<dynamic> get children => get<List<dynamic>>('children') ?? [];

  /// 附着的节点
  Map<String, dynamic> get attachedNodes =>
      get<Map<String, dynamic>>('attachedNodes') ?? {};
}

/// Sidebar 布局 Hook 上下文
///
/// 用于侧边栏布局的 Hook 上下文
class SidebarLayoutHookContext extends HookContext {
  /// 创建一个新的 Sidebar 布局 Hook 上下文实例。
  ///
  /// [data] 上下文数据
  /// [pluginContext] 插件上下文
  /// [hookAPIRegistry] Hook API 注册表
  /// [enableTypeValidation] 是否启用类型验证
  SidebarLayoutHookContext({
    Map<String, dynamic>? data,
    PluginContext? pluginContext,
    HookAPIRegistry? hookAPIRegistry,
    bool enableTypeValidation = false,
  }) : super(
         data ?? {},
         pluginContext: pluginContext,
         hookAPIRegistry: hookAPIRegistry,
         enableTypeValidation: enableTypeValidation,
       );

  /// 图模型
  Graph? get graph => get<Graph>('graph');

  /// 节点列表
  List<Node> get nodes => get<List<Node>>('nodes') ?? [];

  /// 文件夹列表
  List<Node> get folders => nodes.where((n) => n.isFolder).toList();
}
