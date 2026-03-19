import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/models/models.dart';
import '../../core/plugin/ui_hooks/hook_context.dart';
import '../../core/plugin/ui_hooks/hook_registry.dart';
import '../../core/services/i18n.dart';
import '../../plugins/graph/bloc/graph_bloc.dart';
import '../../plugins/graph/bloc/graph_event.dart';
import '../../plugins/graph/bloc/node_bloc.dart';
import '../../plugins/graph/bloc/node_event.dart';

/// 侧边栏
class Sidebar extends StatefulWidget {
  /// 创建侧边栏
  const Sidebar({super.key, required this.graph, required this.nodes});

  /// 图模型
  final Graph graph;

  /// 节点列表
  final List<Node> nodes;

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  final FocusNode _focusNode = FocusNode();
  final FocusNode _editFocusNode = FocusNode();
  final TextEditingController _editController = TextEditingController();
  String? _selectedNodeId;
  bool _showSearch = false;
  bool _isEditingName = false;

  @override
  void dispose() {
    _focusNode.dispose();
    _editFocusNode.dispose();
    _editController.dispose();
    super.dispose();
  }

  void _handleKeyPress(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.delete &&
          _selectedNodeId != null) {
        _deleteSelectedNode();
      }
    }
  }

  Future<void> _deleteSelectedNode() async {
    if (_selectedNodeId == null) return;

    final nodeBloc = context.read<NodeBloc>();
    final nodeState = nodeBloc.state;
    final node = nodeState.nodes.firstWhere(
      (n) => n.id == _selectedNodeId,
      orElse: () => nodeState.nodes.first,
    );
    final i18n = I18n.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
          title: Text(i18n.t('Delete')),
          content: Text('${i18n.t('Are you sure you want to delete')} "${node.title}"${i18n.t('?')}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: Text(i18n.t('Cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: Text(i18n.t('Delete')),
            ),
          ],
        )
    );

    if ((confirmed ?? false) && mounted) {
      nodeBloc.add(NodeDeleteEvent(node.id));
      setState(() {
        _selectedNodeId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = I18n.of(context);
    // 使用 context.select 进行细粒度状态订阅，避免不必要的重建
    // 只有当节点列表发生变化时才重建此组件
    final nodeState = context.select((NodeBloc bloc) => bloc.state);
    final allNodes = nodeState.nodes;
    final folders = allNodes.where((n) => n.isFolder).toList();

    // 过滤掉 AI 节点，不在左侧边栏显示
    final regularNodes = allNodes.where((n) {
      // 排除文件夹
      if (n.isFolder) return false;

      // 检查是否是 AI 节点（支持 bool 和 String 类型）
      final isAI = n.metadata['isAI'];
      if (isAI == true) return false;
      if (isAI == 'true') return false;

      return true;
    }).toList();

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyPress,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: Theme.of(context).dividerColor, width: 1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题栏
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // 切换按钮
                    IconButton(
                      icon: Icon(_showSearch ? Icons.list : Icons.search),
                      tooltip: i18n.t(_showSearch ? 'Show Nodes' : 'Show Search'),
                      onPressed: () {
                        setState(() {
                          _showSearch = !_showSearch;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _showSearch
                          ? Text(
                              i18n.t('Search'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : _isEditingName
                          ? TextField(
                              controller: _editController,
                              focusNode: _editFocusNode,
                              style: Theme.of(context).textTheme.titleMedium,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onSubmitted: _saveGraphName,
                              onEditingComplete: _saveGraphName,
                              onTapOutside: (event) =>
                                  _saveGraphName(_editController.text),
                            )
                          : GestureDetector(
                              onDoubleTap: () {
                                setState(() {
                                  _isEditingName = true;
                                  _editController.text = widget.graph.name;
                                  // 延迟一下再请求焦点，确保 TextField 已经渲染
                                  Future.delayed(
                                    const Duration(milliseconds: 100),
                                    () {
                                      FocusScope.of(
                                        context,
                                      ).requestFocus(_editFocusNode);
                                      // 选择全部文本
                                      _editController.selection = TextSelection(
                                        baseOffset: 0,
                                        extentOffset: widget.graph.name.length,
                                      );
                                    },
                                  );
                                });
                              },
                              child: Text(
                                widget.graph.name,
                                style: Theme.of(context).textTheme.titleMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                    ),
                    // 创建文件夹按钮
                    if (!_showSearch)
                      IconButton(
                        icon: const Icon(Icons.create_new_folder),
                        tooltip: i18n.t('Create New Folder'),
                        onPressed: () => _createFolder(context),
                      ),
                  ],
                ),
              ),
            ),

            // 内容区域
            Expanded(
              child: _showSearch
                  ? _buildSearchContent(context)
                  : _buildPluginContent(context, regularNodes, folders),
            ),
          ],
        ),
      ),
    );
  }

  void _createFolder(BuildContext context) async {
    final nodeBloc = context.read<NodeBloc>();

    try {
      // 发送创建节点事件，设置isFolder元数据
      final i18n = I18n.of(context);
      nodeBloc.add(
        NodeCreateEvent(
          title: i18n.t('New Folder'),
          content: 'A folder to organize your notes',
          metadata: {'isFolder': true},
        ),
      );

      // 注意：文件夹不自动添加到节点图中，它只是一个组织工具

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(i18n.t('New folder created'))));
      }
    } catch (e) {
      if (context.mounted) {
        final i18n = I18n.of(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${i18n.t('Failed to create folder:')} $e')));
      }
    }
  }

  void _saveGraphName([String? name]) {
    final newName = name ?? _editController.text.trim();
    if (newName.isNotEmpty) {
      context.read<GraphBloc>().add(GraphRenameEvent(newName));
    }
    setState(() {
      _isEditingName = false;
    });
  }

  /// 构建插件内容区域
  Widget _buildPluginContent(
    BuildContext context,
    List<Node> nodes,
    List<Node> folders,
  ) {
    debugPrint('[Sidebar] _buildPluginContent() called:');
    debugPrint('  - Nodes: ${nodes.length}, Folders: ${folders.length}');

    // 获取侧边栏底部的所有Hook
    final hookWrappers = hookRegistry.getHookWrappers('sidebar.bottom');
    debugPrint('  - SidebarBottom hooks found: ${hookWrappers.length}');

    if (hookWrappers.isEmpty) {
      // 如果没有插件注册，显示默认界面
      debugPrint('  - No hooks found, showing default content');
      return _buildDefaultContent(context, nodes, folders);
    }

    // 创建 SidebarHookContext
    final hookContext = SidebarHookContext(
      data: {
        'nodes': nodes,
        'folders': folders,
        'onNodeSelected': (nodeId) {
          setState(() {
            _selectedNodeId = nodeId;
          });
        },
        'nodeBloc': context.read<NodeBloc>(),
        'graphBloc': context.read<GraphBloc>(),
        'buildContext': context,
      },
      pluginContext: null,
      hookAPIRegistry: hookRegistry.apiRegistry,
    );

    // 渲染所有插件内容
    debugPrint('  - Rendering ${hookWrappers.length} hooks');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: hookWrappers.map<Widget>((hookWrapper) {
        final hook = hookWrapper.hook;
        debugPrint('    - Rendering sidebar hook: ${hook.metadata.id}');
        if (hook.isVisible(hookContext)) {
          return hook.render(hookContext);
        }
        return const SizedBox.shrink();
      }).toList(),
    );
  }

  /// 构建默认内容（当没有插件时）
  Widget _buildDefaultContent(BuildContext context, List<Node> nodes, List<Node> folders) {
    final i18n = I18n.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_open, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text(i18n.t('No folder plugin loaded')),
          const SizedBox(height: 8),
          Text(
            '${nodes.length} nodes, ${folders.length} folders',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  /// 构建搜索内容（通过Hook加载）
  Widget _buildSearchContent(BuildContext context) {
    final i18n = I18n.of(context);
    final hookWrappers = hookRegistry.getHookWrappers('sidebar.bottom');
    final hookContext = SidebarHookContext(
      data: {
        'buildContext': context,
        'isSearch': true,
      },
      pluginContext: null,
      hookAPIRegistry: hookRegistry.apiRegistry,
    );

    if (hookWrappers.isEmpty) {
      return Center(child: Text(i18n.t('No search plugin loaded')));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: hookWrappers.map<Widget>((hookWrapper) {
        final hook = hookWrapper.hook;
        if (hook.isVisible(hookContext)) {
          return hook.render(hookContext);
        }
        return const SizedBox.shrink();
      }).toList(),
    );
  }
}
