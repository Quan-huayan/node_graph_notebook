import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/blocs.dart';
import '../../core/plugin/ui_hooks/hook_container.dart';
import '../../core/plugin/ui_hooks/hook_context.dart';
import '../../core/commands/command_bus.dart';
import '../../core/events/app_events.dart';

/// 核心工具栏
///
/// 只包含 4 个核心功能：
/// 1. Plugin Market
/// 2. Settings
/// 3. Toggle Sidebar
/// 4. Toggle Connections
///
/// 其他功能通过 UI Hook 系统由插件提供
class CoreToolbar extends StatelessWidget {
  const CoreToolbar({
    super.key,
    required this.uiState,
    required this.commandBus,
    required this.eventBus,
  });

  final UIState uiState;
  final CommandBus commandBus;
  final AppEventBus eventBus;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 收起/展开按钮
            IconButton(
              icon: Icon(uiState.isToolbarExpanded ? Icons.expand_less : Icons.expand_more),
              tooltip: uiState.isToolbarExpanded ? 'Collapse Toolbar' : 'Expand Toolbar',
              onPressed: () {
                context.read<UIBloc>().add(const UIToggleToolbarEvent());
              },
            ),
            if (uiState.isToolbarExpanded)
              ...[
                // 核心功能按钮
                _buildCoreButtons(context),
                const Divider(),
                // 插件扩展区域
                _buildPluginExtensions(context),
              ],
          ],
        ),
      ),
    );
  }

  /// 构建核心功能按钮
  Widget _buildCoreButtons(BuildContext context) {
    return Column(
      children: [
        // 切换 Connections
        IconButton(
          icon: Icon(
            context.read<GraphBloc>().state.viewState.showConnections
                ? Icons.share
                : Icons.share_outlined,
          ),
          tooltip: 'Toggle Connections',
          onPressed: () {
            context.read<GraphBloc>().add(const ViewToggleConnectionsEvent());
          },
        ),
        // 切换 Sidebar
        IconButton(
          icon: Icon(
            uiState.isSidebarOpen
                ? Icons.menu_open
                : Icons.menu,
          ),
          tooltip: 'Toggle Sidebar',
          onPressed: () {
            context.read<UIBloc>().add(const UIToggleSidebarEvent());
          },
        ),
        // 设置
        IconButton(
          icon: const Icon(Icons.settings),
          tooltip: 'Settings',
          onPressed: () {
            _openSettings(context);
          },
        ),
        // 插件市场
        IconButton(
          icon: const Icon(Icons.extension),
          tooltip: 'Plugin Market',
          onPressed: () {
            _openPluginMarket(context);
          },
        ),
      ],
    );
  }

  /// 构建插件扩展区域
  Widget _buildPluginExtensions(BuildContext context) {
    // 创建 Hook 上下文
    final hookContext = MainToolbarHookContext({
      'commandBus': commandBus,
      'eventBus': eventBus,
      'uiState': uiState,
      'buildContext': context,
    });

    // 创建工具栏 Hook 容器
    final container = HookContainerFactory.createToolbarContainer(hookContext);

    // 渲染插件内容
    final pluginWidgets = container.render();

    if (pluginWidgets.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: pluginWidgets.map((widget) => widget as Widget).toList(),
    );
  }

  /// 打开设置对话框
  void _openSettings(BuildContext context) {
    // 这里可以打开设置对话框
    // 暂时使用简单的实现
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Settings'),
        content: const Text('Settings dialog will be implemented here'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// 打开插件市场
  void _openPluginMarket(BuildContext context) {
    // 这里可以打开插件市场页面
    // 暂时使用简单的实现
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Plugin Market'),
        content: const Text('Plugin market will be implemented here'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
