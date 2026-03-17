import 'package:flutter/widgets.dart';

import 'hook_context.dart';
import 'hook_metadata.dart';
import 'hook_priority.dart';

/// Hook 工厂函数类型
///
/// 用于延迟创建 Hook 实例，支持按需实例化
///
/// 架构说明：
/// - 使用工厂函数而不是直接实例，允许 Hook 的懒加载
/// - Plugin 可以返回工厂函数列表，而不是直接实例化 Hook
/// - Hook 在注册时才被实例化，避免不必要的初始化开销
typedef HookFactory = UIHookBase Function();

/// UI Hook 基类
///
/// 定义 UI Hook 的核心接口和生命周期
///
/// 架构说明：
/// - UIHookBase 不继承 Plugin，解决继承混淆问题
/// - 简化的生命周期（仅 4 个方法 vs Plugin 的 6+ 个方法）
/// - 支持动态 Hook 点（字符串 ID vs 枚举）
/// - 支持 API 导出（解决旧系统中 UIHook 无法导出 API 的问题）
/// - 使用语义化优先级（解决魔法数字问题）
///
/// 与旧 UIHook 的区别：
/// - ✅ 不继承 Plugin，无需实现 6+ 个生命周期方法
/// - ✅ Hook 点使用字符串 ID，支持动态注册
/// - ✅ 可以导出 API 供其他 Hook 使用
/// - ✅ 使用语义化优先级（HookPriority 枚举）
/// - ✅ 简化的生命周期管理
///
/// 生命周期：
/// 1. 构造 Hook 对象
/// 2. onInit(context) - Hook 初始化时调用（仅一次）
/// 3. onEnable() - Hook 启用时调用（可多次）
/// 4. onDisable() - Hook 禁用时调用（可多次）
/// 5. onDispose() - Hook 销毁时调用（仅一次）
///
/// 使用示例：
/// ```dart
/// class MyToolbarHook extends UIHookBase {
///   @override
///   HookMetadata get metadata => const HookMetadata(
///     id: 'com.example.my_toolbar_hook',
///     name: 'My Toolbar Hook',
///     version: '1.0.0',
///   );
///
///   @override
///   String get hookPointId => 'main.toolbar';
///
///   @override
///   HookPriority get priority => HookPriority.high;
///
///   NodeBloc? _nodeBloc; // 缓存的服务
///
///   @override
///   Future<void> onInit(HookContext context) async {
///     // 在初始化时解析和缓存服务
///     _nodeBloc = context.pluginContext?.read<NodeBloc>();
///   }
///
///   @override
///   Widget render(HookContext context) {
///     // 使用缓存的服务，避免每次渲染都解析
///     return IconButton(
///       icon: Icon(Icons.add),
///       onPressed: () {
///         _nodeBloc?.add(NodeCreateEvent(...));
///       },
///     );
///   }
///
///   @override
///   Map<String, dynamic> exportAPIs() => {
///     'my_api': MyAPI(),
///   };
/// }
/// ```
abstract class UIHookBase {
  /// 获取 Hook 元数据
  ///
  /// 必须实现，返回 Hook 的元数据信息
  HookMetadata get metadata;

  /// Hook 点 ID
  ///
  /// 返回 Hook 要注册到的 Hook 点 ID
  ///
  /// 使用字符串而不是枚举，支持动态 Hook 点
  ///
  /// 示例：
  /// - 'main.toolbar' - 主工具栏
  /// - 'sidebar.top' - 侧边栏顶部
  /// - 'custom.plugin.action' - 自定义 Hook 点
  String get hookPointId;

  /// Hook 优先级
  ///
  /// 返回 Hook 的优先级，数值越小优先级越高
  ///
  /// 使用 HookPriority 枚举替代魔法数字
  /// 默认为 HookPriority.medium
  HookPriority get priority => HookPriority.medium;

  /// 渲染 Hook 内容
  ///
  /// [context] Hook 上下文，包含渲染所需的数据和服务
  /// 返回要渲染的 Widget
  ///
  /// 注意：
  /// - 此方法会被频繁调用（每次构建时）
  /// - 建议在 onInit() 中缓存服务，避免在此方法中解析服务
  /// - 避免在此方法中执行耗时操作
  Widget render(HookContext context);

  /// 检查 Hook 是否可见
  ///
  /// [context] Hook 上下文
  /// 返回 true 如果 Hook 应该显示，否则返回 false
  ///
  /// 默认返回 true，子类可以重写以实现条件显示
  ///
  /// 使用示例：
  /// ```dart
  /// @override
  /// bool isVisible(HookContext context) {
  ///   // 只在有选中节点时显示
  ///   return context.get<bool>('hasSelection') ?? false;
  /// }
  /// ```
  bool isVisible(HookContext context) => true;

  /// Hook 初始化
  ///
  /// [context] Hook 上下文
  ///
  /// 在 Hook 注册后调用，仅调用一次
  /// 使用此方法执行初始化操作，如解析和缓存服务
  ///
  /// 注意：
  /// - 此方法仅调用一次
  /// - 此时 Hook 功能还未激活（需要等 onEnable）
  /// - 建议在此方法中缓存服务，避免在 render() 中重复解析
  ///
  /// 使用示例：
  /// ```dart
  /// NodeBloc? _nodeBloc;
  /// CommandBus? _commandBus;
  ///
  /// @override
  /// Future<void> onInit(HookContext context) async {
  ///   _nodeBloc = context.pluginContext?.read<NodeBloc>();
  ///   _commandBus = context.pluginContext?.read<CommandBus>();
  /// }
  /// ```
  Future<void> onInit(HookContext context) async {}

  /// Hook 启用
  ///
  /// 在 Hook 被启用时调用
  /// 使用此方法激活 Hook 功能
  ///
  /// 注意：
  /// - 此方法在 onInit() 之后调用
  /// - 可能被多次调用（禁用后再启用）
  /// - 如果 Hook 由 Plugin 提供，此方法与 Plugin 的启用状态同步
  Future<void> onEnable() async {}

  /// Hook 禁用
  ///
  /// 在 Hook 被禁用时调用
  /// 使用此方法停用 Hook 功能
  ///
  /// 注意：
  /// - 此方法应该与 onEnable 对称
  /// - 可能被多次调用（启用后再禁用）
  /// - 如果 Hook 由 Plugin 提供，此方法与 Plugin 的禁用状态同步
  Future<void> onDisable() async {}

  /// Hook 销毁
  ///
  /// 在 Hook 从系统中移除时调用
  /// 使用此方法释放所有资源
  ///
  /// 注意：
  /// - 如果 Hook 当前是启用状态，会先调用 onDisable()
  /// - 销毁后 Hook 不能再被使用
  /// - 此方法仅调用一次
  Future<void> onDispose() async {}

  /// 导出 Hook API
  ///
  /// Hook 可以导出 API 供其他 Hook 使用
  ///
  /// 返回 Map，key 为 API 名称，value 为 API 实例
  ///
  /// 使用示例：
  /// ```dart
  /// @override
  /// Map<String, dynamic> exportAPIs() => {
  ///   'formatting_api': TextFormattingAPI(),
  ///   'validation_api': InputValidationAPI(),
  /// };
  /// ```
  ///
  /// 注意：
  /// - 导出的 API 会被注册到 HookAPIRegistry
  /// - 其他 Hook 可以通过 context.getHookAPI<T>(hookId, apiName) 访问
  /// - 默认返回空 Map，表示不导出任何 API
  Map<String, dynamic> exportAPIs() => {};

  @override
  String toString() =>
      'UIHookBase(${metadata.id}, hookPoint: $hookPointId, priority: $priority)';
}

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
abstract class MainToolbarHookBase extends UIHookBase {
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
abstract class NodeContextMenuHookBase extends UIHookBase {
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
abstract class GraphContextMenuHookBase extends UIHookBase {
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
abstract class SidebarHookBase extends UIHookBase {
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
abstract class SidebarBottomHookBase extends UIHookBase {
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
abstract class StatusBarHookBase extends UIHookBase {
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

/// 设置 Hook 基类
abstract class SettingsHookBase extends UIHookBase {
  @override
  String get hookPointId => 'settings';

  @override
  Widget render(HookContext context) {
    final settingsContext = SettingsHookContext(
      data: context.data,
      pluginContext: context.pluginContext,
      hookAPIRegistry: context.hookAPIRegistry,
    );
    return renderSettings(settingsContext);
  }

  /// 渲染设置内容
  ///
  /// [context] 设置上下文
  /// 返回要渲染的 Widget
  Widget renderSettings(SettingsHookContext context);
}
