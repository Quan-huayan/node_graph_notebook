import 'package:flutter/material.dart';
import 'hook_base.dart';
import 'hook_context.dart';
import 'hook_priority.dart';

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
abstract class SidebarTabHookBase extends UIHookBase {
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
