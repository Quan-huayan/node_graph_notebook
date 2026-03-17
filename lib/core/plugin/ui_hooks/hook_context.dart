import 'dart:ui' as ui;

import '../../models/node.dart';
import '../plugin_context.dart';
import 'hook_api_registry.dart';

/// Hook 上下文基础类
abstract class HookContext {
  /// 创建一个新的 Hook 上下文实例。
  ///
  /// [data] 上下文数据
  /// [pluginContext] 插件上下文
  /// [hookAPIRegistry] Hook API 注册表（用于访问其他 Hook 导出的 API）
  HookContext(
    this.data, {
    this.pluginContext,
    this.hookAPIRegistry,
  });

  /// 上下文数据
  final Map<String, dynamic> data;

  /// 插件上下文
  final PluginContext? pluginContext;

  /// Hook API 注册表
  ///
  /// 用于访问其他 Hook 导出的 API
  ///
  /// 架构说明：
  /// - 允许 Hook 之间的 API 通信
  /// - 解决旧系统中 UIHook 无法访问其他 Hook API 的问题
  /// - 提供类型安全的 API 访问方法
  final HookAPIRegistry? hookAPIRegistry;

  /// 获取数据
  T? get<T>(String key) {
    final value = data[key];
    return value is T ? value : null;
  }

  /// 设置数据
  void set(String key, dynamic value) {
    data[key] = value;
  }

  /// 检查是否有数据
  bool contains(String key) => data.containsKey(key);

  /// 获取其他 Hook 导出的 API
  ///
  /// [hookId] Hook 的唯一标识符
  /// [apiName] API 名称
  /// 返回指定类型的 API 实例，如果不存在则返回 null
  ///
  /// 使用示例：
  /// ```dart
  /// @override
  /// Widget render(HookContext context) {
  ///   // 获取另一个 Hook 导出的 API
  ///   final formattingAPI = context.getHookAPI<TextFormattingAPI>(
  ///     'com.example.formatting_hook',
  ///     'formatting_api',
  ///   );
  ///
  ///   return TextButton(
  ///     onPressed: () {
  ///       formattingAPI?.formatText(selectedText);
  ///     },
  ///     child: Text('Format'),
  ///   );
  /// }
  /// ```
  T? getHookAPI<T>(String hookId, String apiName) => hookAPIRegistry?.getAPI<T>(hookId, apiName);

  /// 检查其他 Hook 是否导出了指定的 API
  ///
  /// [hookId] Hook 的唯一标识符
  /// [apiName] API 名称
  /// 返回 true 如果 API 存在
  bool hasHookAPI(String hookId, String apiName) => hookAPIRegistry?.hasAPI(hookId, apiName) ?? false;
}

/// 基础 Hook 上下文实现
///
/// 提供一个简单的 HookContext 实现，用于不需要特定上下文类型的场景
class BasicHookContext extends HookContext {
  /// 创建一个新的基础 Hook 上下文实例。
  ///
  /// [data] 上下文数据
  /// [pluginContext] 插件上下文
  /// [hookAPIRegistry] Hook API 注册表
  BasicHookContext({
    Map<String, dynamic>? data,
    PluginContext? pluginContext,
    HookAPIRegistry? hookAPIRegistry,
  }) : super(
         data ?? {},
         pluginContext: pluginContext,
         hookAPIRegistry: hookAPIRegistry,
       );
}

/// 主工具栏 Hook 上下文
class MainToolbarHookContext extends HookContext {
  /// 创建一个新的主工具栏 Hook 上下文实例。
  ///
  /// [data] 上下文数据
  /// [pluginContext] 插件上下文
  /// [hookAPIRegistry] Hook API 注册表
  MainToolbarHookContext({
    Map<String, dynamic>? data,
    PluginContext? pluginContext,
    HookAPIRegistry? hookAPIRegistry,
  }) : super(
         data ?? {},
         pluginContext: pluginContext,
         hookAPIRegistry: hookAPIRegistry,
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
  NodeContextMenuHookContext({
    Node? node,
    Map<String, dynamic>? data,
    PluginContext? pluginContext,
    HookAPIRegistry? hookAPIRegistry,
  }) : super(
         data ?? {}
           ..['node'] = node,
         pluginContext: pluginContext,
         hookAPIRegistry: hookAPIRegistry,
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
  GraphContextMenuHookContext({
    ui.Offset? mousePosition,
    int? selectedNodeCount,
    Map<String, dynamic>? data,
    PluginContext? pluginContext,
    HookAPIRegistry? hookAPIRegistry,
  }) : super(
         data ?? {}
           ..['mousePosition'] = mousePosition
           ..['selectedNodeCount'] = selectedNodeCount,
         pluginContext: pluginContext,
         hookAPIRegistry: hookAPIRegistry,
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
  SidebarHookContext({
    bool? isExpanded,
    double? width,
    Map<String, dynamic>? data,
    PluginContext? pluginContext,
    HookAPIRegistry? hookAPIRegistry,
  }) : super(
         data ?? {}
           ..['isExpanded'] = isExpanded
           ..['width'] = width,
         pluginContext: pluginContext,
         hookAPIRegistry: hookAPIRegistry,
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
  StatusBarHookContext({
    int? nodeCount,
    int? connectionCount,
    String? currentMode,
    Map<String, dynamic>? data,
    PluginContext? pluginContext,
    HookAPIRegistry? hookAPIRegistry,
  }) : super(
         data ?? {}
           ..['nodeCount'] = nodeCount
           ..['connectionCount'] = connectionCount
           ..['currentMode'] = currentMode,
         pluginContext: pluginContext,
         hookAPIRegistry: hookAPIRegistry,
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
  NodeEditorHookContext({
    Node? node,
    bool? isReadOnly,
    Map<String, dynamic>? data,
    PluginContext? pluginContext,
    HookAPIRegistry? hookAPIRegistry,
  }) : super(
         data ?? {}
           ..['node'] = node
           ..['isReadOnly'] = isReadOnly,
         pluginContext: pluginContext,
         hookAPIRegistry: hookAPIRegistry,
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
  ImportExportHookContext({
    List<String>? importFormats,
    List<String>? exportFormats,
    Map<String, dynamic>? data,
    PluginContext? pluginContext,
    HookAPIRegistry? hookAPIRegistry,
  }) : super(
         data ?? {}
           ..['importFormats'] = importFormats
           ..['exportFormats'] = exportFormats,
         pluginContext: pluginContext,
         hookAPIRegistry: hookAPIRegistry,
       );

  /// 支持的导入格式
  List<String> get importFormats => get<List<String>>('importFormats') ?? [];

  /// 支持的导出格式
  List<String> get exportFormats => get<List<String>>('exportFormats') ?? [];
}

/// 设置 Hook 上下文
class SettingsHookContext extends HookContext {
  /// 创建一个新的设置 Hook 上下文实例。
  ///
  /// [currentSettings] 当前设置
  /// [data] 上下文数据
  /// [pluginContext] 插件上下文
  /// [hookAPIRegistry] Hook API 注册表
  SettingsHookContext({
    Map<String, dynamic>? currentSettings,
    Map<String, dynamic>? data,
    PluginContext? pluginContext,
    HookAPIRegistry? hookAPIRegistry,
  }) : super(
         data ?? {}
           ..['currentSettings'] = currentSettings,
         pluginContext: pluginContext,
         hookAPIRegistry: hookAPIRegistry,
       );

  /// 当前设置
  Map<String, dynamic> get currentSettings =>
      get<Map<String, dynamic>>('currentSettings') ?? {};
}

/// 帮助 Hook 上下文
class HelpHookContext extends HookContext {
  /// 创建一个新的帮助 Hook 上下文实例。
  ///
  /// [helpItems] 帮助文档列表
  /// [data] 上下文数据
  /// [pluginContext] 插件上下文
  /// [hookAPIRegistry] Hook API 注册表
  HelpHookContext({
    List<HelpItem>? helpItems,
    Map<String, dynamic>? data,
    PluginContext? pluginContext,
    HookAPIRegistry? hookAPIRegistry,
  }) : super(
         data ?? {}
           ..['helpItems'] = helpItems,
         pluginContext: pluginContext,
         hookAPIRegistry: hookAPIRegistry,
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
