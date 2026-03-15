import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:node_graph_notebook/plugins/builtin_plugins/graph/bloc/graph_bloc.dart';
import 'package:node_graph_notebook/plugins/builtin_plugins/graph/bloc/graph_event.dart';
import 'package:node_graph_notebook/plugins/builtin_plugins/graph/bloc/node_bloc.dart';
import 'package:node_graph_notebook/plugins/builtin_plugins/graph/bloc/node_event.dart';
import 'package:node_graph_notebook/plugins/builtin_plugins/search/ui/search_sidebar_panel.dart';
import '../../core/models/models.dart';
import '../../core/plugin/ui_hooks/hook_container.dart';
import '../../core/plugin/ui_hooks/hook_context.dart';

/// 侧边栏
class Sidebar extends StatefulWidget {
  const Sidebar({
    super.key,
    required this.graph,
    required this.nodes,
  });

  final Graph graph;
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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Delete Node'),
          content: Text('Are you sure you want to delete "${node.title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      nodeBloc.add(NodeDeleteEvent(node.id));
      setState(() {
        _selectedNodeId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
            right: BorderSide(
              color: Theme.of(context).dividerColor,
              width: 1,
            ),
          ),
        ),
        child: Column(
          children: [
            // 标题栏
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).dividerColor,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // 切换按钮
                    IconButton(
                      icon: Icon(_showSearch ? Icons.list : Icons.search),
                      tooltip: _showSearch ? 'Show Nodes' : 'Show Search',
                      onPressed: () {
                        setState(() {
                          _showSearch = !_showSearch;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _showSearch
                          ? const Text(
                              'Search',
                              style: TextStyle(
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
                                  onTapOutside: (event) => _saveGraphName(_editController.text),
                                )
                              : GestureDetector(
                                  onDoubleTap: () {
                                    setState(() {
                                      _isEditingName = true;
                                      _editController.text = widget.graph.name;
                                      // 延迟一下再请求焦点，确保 TextField 已经渲染
                                      Future.delayed(const Duration(milliseconds: 100), () {
                                        FocusScope.of(context).requestFocus(_editFocusNode);
                                        // 选择全部文本
                                        _editController.selection = TextSelection(
                                          baseOffset: 0,
                                          extentOffset: widget.graph.name.length,
                                        );
                                      });
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
                        tooltip: 'Create New Folder',
                        onPressed: () => _createFolder(context),
                      ),
                  ],
                ),
              ),
            ),

            // 内容区域
            Expanded(
              child: _showSearch
                  ? const SearchSidebarPanel()
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
      nodeBloc.add(const NodeCreateEvent(
        title: 'New Folder',
        content: 'A folder to organize your notes',
        metadata: {'isFolder': true},
      ));

      // 注意：文件夹不自动添加到节点图中，它只是一个组织工具

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New folder created')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create folder: $e')),
        );
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
  Widget _buildPluginContent(BuildContext context, List<Node> nodes, List<Node> folders) {
    // 创建 SidebarBottomHookContext
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
      },
    );

    // 创建 Hook 容器并渲染插件内容
    final container = HookContainerFactory.createSidebarBottomContainer(hookContext);
    final pluginWidgets = container.render();

    if (pluginWidgets.isEmpty) {
      // 如果没有插件注册，显示默认界面
      return _buildDefaultContent(context, nodes, folders);
    }

    // 渲染所有插件内容
    return Column(
      children: pluginWidgets.map((w) => w as Widget).toList(),
    );
  }

  /// 构建默认内容（当没有插件时）
  Widget _buildDefaultContent(BuildContext context, List<Node> nodes, List<Node> folders) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_open, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('No folder plugin loaded'),
          const SizedBox(height: 8),
          Text(
            '${nodes.length} nodes, ${folders.length} folders',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
