/// QuickSwitcher —— 快速切换（B2：Obsidian Ctrl+O 语义）。
///
/// 输入过滤节点标题 → 点击打开（openNodeDialog 共用外壳）。UI 代理节点
/// （工具栏/画布/面板等 kind）不参与（BacklinkService.isUiProxy 同一判定）。
library;

import 'package:core_data/core_data.dart';
import 'package:flutter/material.dart';

import '../host/host_runtime.dart';
import '../knowledge/backlink_service.dart';
import 'node_open_dialog.dart';

/// 打开快速切换（标题过滤 + 点击打开节点）。
/// [hint]/[empty] 文案由调用方传词表解析（零硬编码）。
Future<void> showQuickSwitcher(
  BuildContext context,
  HostRuntime host, {
  String hint = '',
  String empty = '',
}) =>
    showDialog<void>(
      context: context,
      builder: (context) => _QuickSwitcherDialog(
        outerContext: context,
        host: host,
        hint: hint,
        empty: empty,
      ),
    );

/// 快速切换对话框。
class _QuickSwitcherDialog extends StatefulWidget {
  /// 构造。
  const _QuickSwitcherDialog({
    required this.outerContext,
    required this.host,
    required this.hint,
    required this.empty,
  });

  /// 对话框外的宿主上下文（点击打开用——弹窗 pop 后仍有效）。
  final BuildContext outerContext;

  /// 宿主组合根。
  final HostRuntime host;

  /// 输入提示。
  final String hint;

  /// 空结果文案。
  final String empty;

  @override
  State<_QuickSwitcherDialog> createState() => _QuickSwitcherDialogState();
}

class _QuickSwitcherDialogState extends State<_QuickSwitcherDialog> {
  final TextEditingController _input = TextEditingController();

  /// 全部可切换节点（剔除 UI 代理，构建时快照——只读列表）。
  late final List<Node> _nodes = widget.host.graph
      .getAll()
      .where((n) => !BacklinkService.isUiProxy(n))
      .toList()
    ..sort((a, b) => a.title.compareTo(b.title));

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final needle = _input.text.trim().toLowerCase();
    final visible = needle.isEmpty
        ? _nodes
        : _nodes.where((n) => n.title.toLowerCase().contains(needle)).toList();
    return Dialog(
      child: SizedBox(
        width: 480,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(8),
                child: TextField(
                  controller: _input,
                  autofocus: true,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.manage_search),
                    hintText: widget.hint,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Flexible(
                child: visible.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(widget.empty),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final node = visible[index];
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              _iconOf(node),
                              size: 20,
                            ),
                            title: Text(node.title, maxLines: 1),
                            onTap: () {
                              Navigator.pop(context);
                              // 外层上下文打开——pop 后的 dialog context 失效。
                              openNodeDialog(
                                widget.outerContext,
                                widget.host,
                                node.id,
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 行图标（kind 感知——同 SearchPanel 的映射约定）。
  static IconData _iconOf(Node node) => switch (node.metadata['kind']) {
    'folder' => Icons.folder_outlined,
    'ai' => Icons.smart_toy_outlined,
    _ => Icons.description_outlined,
  };
}