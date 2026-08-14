import 'package:core/core.dart';
import 'package:core/plugin/hook/ui_hook_tree.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:repository_fs/repository_fs.dart';

import '../../service/storage_path_service.dart';
import '../bars/core_toolbar.dart';
import 'hook_bases.dart';
import 'hook_contexts.dart';

/// Root 布局 Hook
///
/// 实现主窗口布局，包含：
/// - 顶部工具栏
/// - 左侧侧边栏
/// - 主内容区（图视图）
/// - 底部状态栏
/// - 上下文菜单 overlay
class RootLayoutHook extends RootHookRole {
  @override
  HookMetadata get metadata => const HookMetadata(
    id: 'root.layout',
    name: 'Root Layout Hook',
    version: '1.0.0',
    description: 'Main window layout with toolbar, sidebar, graph view and status bar',
  );

  @override
  HookPriority get priority => HookPriority.critical;

  @override
  Widget renderRoot(RootHookContext context) {
    final buildContext = context.data['buildContext'] as BuildContext?;
    if (buildContext == null) {
      return const Scaffold(
        body: Center(child: Text('No build context')),
      );
    }

    final hook = context.data['hook'] as UIHookNode?;
    if (hook == null) {
      return const Scaffold(
        body: Center(child: Text('No hook data')),
      );
    }

    return _RootLayoutWidget(hook: hook);
  }
}

/// Root 布局 Widget
///
/// 负责渲染主窗口的整体布局结构
class _RootLayoutWidget extends StatefulWidget {
  const _RootLayoutWidget({required this.hook});

  final UIHookNode hook;

  @override
  State<_RootLayoutWidget> createState() => _RootLayoutWidgetState();
}

class _RootLayoutWidgetState extends State<_RootLayoutWidget> {
  Graph? _currentGraph;
  List<Node> _nodes = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final storagePathService = context.read<StoragePathService>();
      final nodesPath = await storagePathService.getNodesPath();

      final nodeRepo = FileSystemNodeRepository(nodesDir: nodesPath);
      await nodeRepo.init();

      final nodes = await nodeRepo.queryAll();
      setState(() {
        _nodes = nodes;
      });
    } catch (e) {
      debugPrint('Failed to load initial data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final sidebarHook = widget.hook.findByHookPointId('sidebar');
    final graphHook = widget.hook.findByHookPointId('graph');
    final statusBarHook = widget.hook.findByHookPointId('status.bar');

    return Scaffold(
      appBar: const CoreToolbar(),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (sidebarHook != null)
            _buildSidebar(context),
          if (graphHook != null)
            Expanded(
              child: _buildGraphArea(context),
            ),
        ],
      ),
      bottomNavigationBar: statusBarHook != null
          ? _buildStatusBar(context, statusBarHook)
          : null,
    );
  }

  Widget _buildSidebar(BuildContext context) {
    final sidebarHook = widget.hook.findByHookPointId('sidebar');
    if (sidebarHook == null) {
      return const Center(child: Text('No sidebar hook'));
    }

    final registry = context.read<HookRoleRegistry>();
    final hookWrappers = registry.getHookWrappers('sidebar');

    if (hookWrappers.isEmpty) {
      return Container(
        color: Colors.grey[100],
        child: const Center(
          child: Text('Sidebar - No hooks registered'),
        ),
      );
    }

    final hookContext = SidebarLayoutHookContext(
      data: {
        'buildContext': context,
        'hook': sidebarHook,
        'graph': _currentGraph,
        'nodes': _nodes,
      },
      hookAPIRegistry: registry.apiRegistry,
    );

    for (final wrapper in hookWrappers) {
      if (wrapper.hook.isVisible(hookContext)) {
        return wrapper.hook.render(hookContext);
      }
    }

    return Container(
      color: Colors.grey[100],
      child: const Center(
        child: Text('Sidebar'),
      ),
    );
  }

  Widget _buildGraphArea(BuildContext context) {
    final graphHook = widget.hook.findByHookPointId('graph');
    if (graphHook == null) {
      return const Center(child: Text('No graph area'));
    }

    final registry = context.read<HookRoleRegistry>();
    final hookWrappers = registry.getHookWrappers('graph');

    if (hookWrappers.isEmpty) {
      return Container(
        color: Colors.grey[100],
        child: const Center(
          child: Text('Graph view - No hooks registered'),
        ),
      );
    }

    final hookContext = BasicHookContext(
      data: {
        'buildContext': context,
        'hook': graphHook,
        'graph': _currentGraph,
        'nodes': _nodes,
      },
      hookAPIRegistry: registry.apiRegistry,
    );

    for (final wrapper in hookWrappers) {
      if (wrapper.hook.isVisible(hookContext)) {
        return wrapper.hook.render(hookContext);
      }
    }

    return Container(
      color: Colors.grey[100],
      child: const Center(
        child: Text('Graph view'),
      ),
    );
  }

  Widget _buildStatusBar(BuildContext context, UIHookNode statusBarHook) {
    final registry = context.read<HookRoleRegistry>();
    final hookWrappers = registry.getHookWrappers('status.bar');

    if (hookWrappers.isEmpty) {
      return Container(
        height: 24,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text('Ready', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      );
    }

    final hookContext = StatusBarHookContext(
      data: {
        'buildContext': context,
        'hook': statusBarHook,
        'nodeCount': _nodes.length,
      },
      hookAPIRegistry: registry.apiRegistry,
    );

    return Container(
      height: 24,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: hookWrappers.map((wrapper) {
          if (wrapper.hook.isVisible(hookContext)) {
            return wrapper.hook.render(hookContext);
          }
          return const SizedBox.shrink();
        }).toList(),
      ),
    );
  }
}