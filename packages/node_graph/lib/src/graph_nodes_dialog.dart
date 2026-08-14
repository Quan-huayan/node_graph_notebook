/// GraphNodesDialog —— 画布节点管理对话框（旧资产带走的投影不变式修正）。
///
/// 旧实现（archive/graph/lib/ui/graph_nodes_dialog.dart）把"哪些节点
/// 在图里"存进 Graph 结构 = 违反投影不变式 4.1（前端结构不得持久化）。
/// 新架构：画布成员 = UIStateStore 外观位置（判据②），对话框 = **位置键
/// 增删**——勾选 → 写默认布局位置；取消勾选 → remove 键。纯外观操作。
///
/// 对齐旧实现交互：勾选列表 + 选中/可用统计 + Apply。可选项 = 用户内容
/// 节点（结构判定：references 非空 = 关系实例，非用户笔记，排除——
/// 04 §三 约束 3：插件互相不依赖，不引用 folder 概念做判定）。
library;

import 'package:appframe/appframe.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter/material.dart';

import 'canvas_concept.dart';

/// 画布节点管理对话框。
class GraphNodesDialog extends StatefulWidget {
  /// 注入结构存储、外观存储与国际化服务（M7 修正：服务注入——插件 UI
  /// 不依赖组合根 host，plugon DI 解析）。
  const GraphNodesDialog({
    super.key,
    required this.graph,
    required this.uiStateStore,
    required this.i18n,
  });

  /// 结构存储。
  final Graph graph;

  /// 外观存储（位置键）。
  final UIStateStore uiStateStore;

  /// 国际化服务（壳层文案）。
  final I18nService i18n;

  @override
  State<GraphNodesDialog> createState() => _GraphNodesDialogState();
}

class _GraphNodesDialogState extends State<GraphNodesDialog> {
  late final List<Node> _availableNodes;
  late final Set<String> _selectedNodeIds;

  @override
  void initState() {
    super.initState();
    // 可用节点 = 用户内容节点（结构判定：references 非空 = 关系实例；
    // 画布自身排除——同包 Concept 判定，无跨插件依赖）。
    _availableNodes = widget.graph
        .getAll()
        .where(
          (n) => n.references.isEmpty && !const CanvasConcept().validate(n),
        )
        .toList();
    _selectedNodeIds = _availableNodes
        .map((n) => n.id)
        .where(_hasPosition)
        .toSet();
  }

  bool _hasPosition(String nodeId) =>
      widget.uiStateStore.get(canvasPositionKey(nodeId)) != null;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Row(
      children: [
        const Icon(Icons.graphic_eq),
        const SizedBox(width: 8),
        Text(widget.i18n.t('canvas.manage')),
      ],
    ),
    content: SizedBox(
      width: 420,
      height: 420,
      child: Column(
        children: [
          // 统计（对齐旧实现：选中/可用）。
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Stat(
                  label: widget.i18n.t('canvas.selectedCount'),
                  value: _selectedNodeIds.length,
                ),
                _Stat(
                  label: widget.i18n.t('canvas.availableCount'),
                  value: _availableNodes.length,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _availableNodes.isEmpty
                ? Center(child: Text(widget.i18n.t('canvas.noAvailableNodes')))
                : ListView.builder(
                    itemCount: _availableNodes.length,
                    itemBuilder: (context, index) {
                      final node = _availableNodes[index];
                      return CheckboxListTile(
                        dense: true,
                        value: _selectedNodeIds.contains(node.id),
                        onChanged: (bool? value) {
                          setState(() {
                            if (value ?? false) {
                              _selectedNodeIds.add(node.id);
                            } else {
                              _selectedNodeIds.remove(node.id);
                            }
                          });
                        },
                        secondary: const Icon(Icons.description),
                        title: Text(
                          node.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(widget.i18n.t('dialog.cancel')),
      ),
      FilledButton(
        onPressed: _applyChanges,
        child: Text(widget.i18n.t('canvas.apply')),
      ),
    ],
  );

  /// Apply：勾选 → 默认布局位置写入；取消勾选 → 移除位置键。
  ///
  /// 纯 UIStateStore 操作（判据② 外观）；返回受影响的 nodeId 集合，
  /// 宿主据此刷新画布（本对话框不直接操作图结构）。
  void _applyChanges() {
    final store = widget.uiStateStore;
    var slot = 0;
    for (final node in _availableNodes) {
      if (_selectedNodeIds.contains(node.id)) {
        if (!_hasPosition(node.id)) {
          // 默认布局：网格槽位（确定性，重启一致）。
          store.set(canvasPositionKey(node.id), <String, dynamic>{
            'x': 60 + (slot % 5) * 220,
            'y': 60 + (slot ~/ 5) * 150,
          });
        }
        slot++;
      } else if (_hasPosition(node.id)) {
        store.remove(canvasPositionKey(node.id));
      }
    }
    Navigator.pop(context, _selectedNodeIds);
  }
}

/// 统计标签（选中/可用）。
class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text('$value', style: Theme.of(context).textTheme.headlineSmall),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}
