import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import '../../bloc/blocs.dart';
import '../widgets/markdown_preview_widget.dart';
import '../../converter/models/models.dart';
import '../../core/models/models.dart';

/// 导出 Markdown 对话框
class ExportMarkdownDialog extends StatefulWidget {
  const ExportMarkdownDialog({super.key});

  @override
  State<ExportMarkdownDialog> createState() => _ExportMarkdownDialogState();
}

class _ExportMarkdownDialogState extends State<ExportMarkdownDialog> {
  // 合并策略
  MergeStrategy _selectedStrategy = MergeStrategy.sequence;
  MergeRule? _selectedRule;

  // 选中的节点 ID 列表（有序）
  List<String> _selectedNodeIds = [];

  // 搜索和展开状态
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _expandedParentIds = {};

  // 排序面板展开状态
  bool _orderingPanelExpanded = false;

  @override
  void initState() {
    super.initState();
    _selectedRule = MergeRule(
      strategy: _selectedStrategy,
      sequenceRule: const SequenceMergeRule(separator: '\n\n---\n\n'),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 判断节点是否可以导出（非 folder 且非 ai）
  bool _isExportable(Node node) {
    return !node.isFolder && node.metadata['isAI'] != true;
  }

  /// 判断节点是否有子节点（用于树形显示）
  ///
  /// 基于引用结构：检查节点是否引用了其他节点
  bool _hasChildren(Node node, List<Node> allNodes) {
    return node.references.keys.any((nodeId) =>
      allNodes.any((n) => n.id == nodeId)
    );
  }

  /// 获取节点的直接子节点（被引用的节点）
  List<Node> _getDirectChildren(Node parent, List<Node> allNodes) {
    return allNodes.where((node) {
      return parent.references.containsKey(node.id);
    }).toList();
  }

  /// 获取顶层父节点（没有被其他节点引用的节点）
  List<Node> _getTopLevelParents(List<Node> allNodes) {
    final referencedIds = <String>{};
    for (final node in allNodes) {
      referencedIds.addAll(node.references.keys);
    }

    // 返回有子节点但未被其他节点引用的节点
    return allNodes.where((node) =>
      _hasChildren(node, allNodes) && !referencedIds.contains(node.id)
    ).toList();
  }

  /// 获取未被任何节点引用的可导出节点
  List<Node> _getRootExportableNodes(List<Node> allNodes) {
    final referencedIds = <String>{};
    for (final node in allNodes) {
      referencedIds.addAll(node.references.keys);
    }

    return allNodes.where((node) =>
      _isExportable(node) && !referencedIds.contains(node.id)
    ).toList();
  }

  /// 获取过滤后的节点列表
  List<Node> _getFilteredNodes(List<Node> nodes) {
    if (_searchQuery.isEmpty) {
      return nodes;
    }

    final query = _searchQuery.toLowerCase();
    return nodes.where((node) {
      return node.title.toLowerCase().contains(query) ||
          (node.content?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  /// 获取扁平化的选中节点列表（用于显示在右侧）
  List<Node> _getSelectedNodes(List<Node> allNodes) {
    return _selectedNodeIds
        .map((id) => allNodes.firstWhere((n) => n.id == id, orElse: () => allNodes.first))
        .where((n) => n.id.isNotEmpty)
        .toList();
  }

  /// 检查节点是否被选中
  bool _isNodeSelected(String nodeId) {
    return _selectedNodeIds.contains(nodeId);
  }

  /// 切换节点选择状态
  void _toggleNode(String nodeId) {
    setState(() {
      if (_isNodeSelected(nodeId)) {
        _selectedNodeIds.remove(nodeId);
      } else {
        _selectedNodeIds.add(nodeId);
      }
      _loadPreview();
    });
  }

  /// 移除节点
  void _removeNode(int index) {
    setState(() {
      _selectedNodeIds.removeAt(index);
      _loadPreview();
    });
  }

  /// 上移节点
  void _moveNodeUp(int index) {
    if (index > 0) {
      setState(() {
        final node = _selectedNodeIds.removeAt(index);
        _selectedNodeIds.insert(index - 1, node);
        _loadPreview();
      });
    }
  }

  /// 下移节点
  void _moveNodeDown(int index) {
    if (index < _selectedNodeIds.length - 1) {
      setState(() {
        final node = _selectedNodeIds.removeAt(index);
        _selectedNodeIds.insert(index + 1, node);
        _loadPreview();
      });
    }
  }

  /// 全选/取消全选
  void _toggleAll(List<Node> nodes) {
    setState(() {
      if (_selectedNodeIds.length == nodes.length) {
        _selectedNodeIds.clear();
      } else {
        _selectedNodeIds = nodes.map((n) => n.id).toList();
      }
      _loadPreview();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Export Markdown'),
      content: SizedBox(
        width: 800,
        height: 600,
        child: Column(
          children: [
            // 策略选择栏（放在顶部）
            _buildStrategyBar(),

            Expanded(
              child: Row(
                children: [
                  // 左侧：节点选择器（包含树形视图和紧凑排序列表）
                  Expanded(
                    flex: 7,
                    child: _buildNodeSelectorWithOrdering(),
                  ),

                  const VerticalDivider(width: 1),

                  // 右侧：Markdown 预览
                  Expanded(
                    flex: 3,
                    child: _buildMarkdownPreview(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _canExport()
              ? () => _exportSelected(context)
              : null,
          child: Text('Export (${_selectedNodeIds.length})'),
        ),
      ],
    );
  }

  /// 构建策略选择栏（顶部）
  Widget _buildStrategyBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.settings, size: 16),
          const SizedBox(width: 8),
          const Text('Merge Strategy:'),
          const SizedBox(width: 16),
          SegmentedButton<MergeStrategy>(
            segments: const [
              ButtonSegment(
                value: MergeStrategy.sequence,
                label: Text('Sequence'),
                icon: Icon(Icons.format_list_numbered, size: 16),
              ),
              ButtonSegment(
                value: MergeStrategy.hierarchy,
                label: Text('Hierarchy'),
                icon: Icon(Icons.account_tree, size: 16),
              ),
            ],
            selected: {_selectedStrategy},
            onSelectionChanged: (Set<MergeStrategy> selection) {
              setState(() {
                _selectedStrategy = selection.first;
                _selectedRule = MergeRule(
                  strategy: _selectedStrategy,
                  sequenceRule: const SequenceMergeRule(separator: '\n\n---\n\n'),
                  hierarchyRule: const HierarchyMergeRule(),
                );
                _loadPreview();
              });
            },
          ),
        ],
      ),
    );
  }

  /// 构建节点选择器（包含树形视图和紧凑排序列表）
  Widget _buildNodeSelectorWithOrdering() {
    return BlocBuilder<NodeBloc, NodeState>(
      builder: (context, state) {
        final allNodes = state.nodes;
        final exportableNodes = allNodes.where(_isExportable).toList();
        final filteredNodes = _getFilteredNodes(exportableNodes);
        final topLevelParents = _getTopLevelParents(allNodes);
        final rootNodes = _getRootExportableNodes(filteredNodes);
        final selectedNodes = _getSelectedNodes(allNodes);

        if (allNodes.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open, size: 48, color: Colors.grey),
                SizedBox(height: 8),
                Text('No nodes available'),
              ],
            ),
          );
        }

        return Column(
          children: [
            // 搜索框和操作按钮
            _buildSearchAndActionsBar(exportableNodes),

            const Divider(height: 1),

            // 树形视图（带序号）
            Expanded(
              flex: 3,
              child: _buildTreeViewWithOrderNumbers(
                topLevelParents,
                rootNodes,
                allNodes,
              ),
            ),

            // 分隔线
            const Divider(height: 1),

            // 紧凑的已选排序面板
            _buildCompactOrderingPanel(selectedNodes),
          ],
        );
      },
    );
  }

  /// 构建搜索框和操作按钮栏
  Widget _buildSearchAndActionsBar(List<Node> exportableNodes) {
    return Column(
      children: [
        // 搜索框
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Search',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),

        // 操作按钮
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Checkbox(
                value: _selectedNodeIds.length == exportableNodes.length && exportableNodes.isNotEmpty,
                onChanged: (_) => _toggleAll(exportableNodes),
              ),
              TextButton(
                onPressed: () => _toggleAll(exportableNodes),
                child: const Text('Select All'),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedNodeIds.clear();
                    _loadPreview();
                  });
                },
                child: const Text('Clear'),
              ),
              const Spacer(),
              Text(
                '${_selectedNodeIds.length} selected',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建带序号的树形视图
  Widget _buildTreeViewWithOrderNumbers(
    List<Node> topLevelParents,
    List<Node> rootNodes,
    List<Node> allNodes,
  ) {
    return ListView(
      children: [
        // 顶层父节点列表（有子节点的节点）
        ...topLevelParents.map((parent) =>
            _buildParentNodeItem(parent, allNodes)),

        // 分隔线
        if (topLevelParents.isNotEmpty && rootNodes.isNotEmpty)
          const Divider(height: 32),

        // 根级别的可导出节点（未被包含的）
        ...rootNodes.map((node) => _buildExportableNodeItemWithOrder(node)),
      ],
    );
  }

  /// 构建父节点项（可展开，显示子节点）
  Widget _buildParentNodeItem(Node parent, List<Node> allNodes) {
    final children = _getDirectChildren(parent, allNodes);
    // 过滤出可导出的子节点
    final exportableChildren = children.where(_isExportable).toList();
    final isExpanded = _expandedParentIds.contains(parent.id);

    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (_expandedParentIds.contains(parent.id)) {
                _expandedParentIds.remove(parent.id);
              } else {
                _expandedParentIds.add(parent.id);
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.expand_more : Icons.chevron_right,
                  size: 16,
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.folder,
                  size: 16,
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    parent.title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                    ),
                  ),
                ),
                Text(
                  '(${exportableChildren.length})',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded && exportableChildren.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Column(
              children: exportableChildren.map((child) {
                // 如果子节点也有自己的子节点，递归显示
                if (_hasChildren(child, allNodes)) {
                  return _buildParentNodeItem(child, allNodes);
                } else {
                  return _buildExportableNodeItemWithOrder(child);
                }
              }).toList(),
            ),
          ),
      ],
    );
  }

  /// 构建带序号的可导出节点项
  Widget _buildExportableNodeItemWithOrder(Node node) {
    final isSelected = _isNodeSelected(node.id);
    final orderIndex = _selectedNodeIds.indexOf(node.id);
    final hasOrder = orderIndex >= 0;

    return CheckboxListTile(
      value: isSelected,
      onChanged: (_) => _toggleNode(node.id),
      controlAffinity: ListTileControlAffinity.leading,
      title: Row(
        children: [
          // 序号徽章（如果已选）
          if (hasOrder)
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${orderIndex + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: 20, height: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              node.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
      subtitle: node.content != null && node.content!.isNotEmpty
          ? Text(
              node.content!.length > 50
                  ? '${node.content!.substring(0, 50)}...'
                  : node.content!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10),
            )
          : null,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  /// 构建紧凑的排序面板
  Widget _buildCompactOrderingPanel(List<Node> selectedNodes) {
    if (selectedNodes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // 面板标题栏（可点击展开/折叠）
        InkWell(
          onTap: () {
            setState(() {
              _orderingPanelExpanded = !_orderingPanelExpanded;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                Icon(
                  _orderingPanelExpanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  size: 16,
                ),
                const Icon(Icons.reorder, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Selected Order (${selectedNodes.length})',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
          ),
        ),

        // 可展开的排序列表
        if (_orderingPanelExpanded)
          Container(
            height: 120,
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: selectedNodes.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (oldIndex < newIndex) {
                    newIndex -= 1;
                  }
                  final item = _selectedNodeIds.removeAt(oldIndex);
                  _selectedNodeIds.insert(newIndex, item);
                  _loadPreview();
                });
              },
              itemBuilder: (context, index) {
                final node = selectedNodes[index];
                return _buildCompactOrderingItem(node, index);
              },
            ),
          ),
      ],
    );
  }

  /// 构建紧凑的排序项
  Widget _buildCompactOrderingItem(Node node, int index) {
    return Container(
      key: ValueKey(node.id),
      height: 32,
      child: Row(
        children: [
          // 拖拽手柄
          ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_handle, size: 16),
          ),
          const SizedBox(width: 8),
          // 序号
          SizedBox(
            width: 20,
            child: Text(
              '${index + 1}.',
              style: const TextStyle(fontSize: 11),
            ),
          ),
          const SizedBox(width: 8),
          // 节点标题
          Expanded(
            child: Text(
              node.title,
              style: const TextStyle(fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // 上移按钮
          IconButton(
            icon: const Icon(Icons.arrow_upward, size: 14),
            onPressed: index > 0 ? () => _moveNodeUp(index) : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          // 下移按钮
          IconButton(
            icon: const Icon(Icons.arrow_downward, size: 14),
            onPressed: index < _selectedNodeIds.length - 1
                ? () => _moveNodeDown(index)
                : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          // 删除按钮
          IconButton(
            icon: const Icon(Icons.close, size: 14),
            onPressed: () => _removeNode(index),
            color: Colors.red,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }

  /// 构建 Markdown 预览
  Widget _buildMarkdownPreview() {
    return BlocBuilder<ConverterBloc, ConverterState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 32, color: Colors.red),
                const SizedBox(height: 8),
                Text(
                  'Error: ${state.error}',
                  style: const TextStyle(fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (state.exportPreviewMarkdown.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.description, size: 32, color: Colors.grey),
                SizedBox(height: 8),
                Text(
                  'Select nodes to preview',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return MarkdownPreviewWidget(
          markdown: state.exportPreviewMarkdown,
          isRenderMode: false,
        );
      },
    );
  }

  /// 加载预览
  void _loadPreview() {
    if (_selectedNodeIds.isEmpty || _selectedRule == null) return;

    context.read<ConverterBloc>().add(
          ExportPreviewEvent(
            _selectedNodeIds,
            _selectedRule!,
          ),
        );
  }

  /// 检查是否可以导出
  bool _canExport() {
    return _selectedNodeIds.isNotEmpty;
  }

  /// 执行导出
  Future<void> _exportSelected(BuildContext context) async {
    if (_selectedRule == null) return;

    // 选择输出路径
    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save exported markdown',
      fileName: 'exported_notes.md',
      type: FileType.custom,
      allowedExtensions: ['md', 'markdown'],
    );

    if (outputPath == null) return;

    context.read<ConverterBloc>().add(
          ExportExecuteEvent(
            _selectedNodeIds,
            _selectedRule!,
            outputPath,
          ),
        );

    // 显示完成提示
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported ${_selectedNodeIds.length} nodes to $outputPath'),
          duration: const Duration(seconds: 3),
        ),
      );
      Navigator.pop(context);
    }
  }
}

/// Node 扩展 - 检查是否为文件夹
extension NodeExtension on Node {
  bool get isFolder {
    return metadata['isFolder'] == true ||
        (metadata['isFolder'] is bool && metadata['isFolder'] as bool);
  }
}
