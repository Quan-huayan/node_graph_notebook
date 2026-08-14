/// NodeEditDialog —— 节点创建/编辑对话框（M6 graph 插件）。
///
/// 旧资产（archive/graph/ui/create_node_dialog.dart 等）的新架构形态：
/// 对话框只收集标题与内容（纯 UI），落盘走数据命令（判据①，
/// Hook/对话框不直接写 Graph——00 不变量 4.4-1）。
/// 创建模式（node == null）与编辑模式（node != null）复用同一表单。
library;

import 'package:appframe/appframe.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter/material.dart';

/// 编辑表单结果（标题 + 内容 + 可选 kind）。
typedef NodeFormResult = ({String title, String? content, String? kind});

/// 节点创建/编辑对话框。
class NodeEditDialog extends StatefulWidget {
  /// 注入表单上下文与国际化服务。
  ///
  /// [node] null = 创建模式（含 kind 选择）；非 null = 编辑模式（预填当前值）。
  const NodeEditDialog({
    super.key,
    this.node,
    required this.dialogTitle,
    required this.i18n,
  });

  /// 被编辑节点（null = 创建）。
  final Node? node;

  /// 对话框标题（创建/编辑）。
  final String dialogTitle;

  /// 国际化服务（壳层——文案走语言包，M7.2 补漏）。
  final I18nService i18n;

  @override
  State<NodeEditDialog> createState() => _NodeEditDialogState();
}

class _NodeEditDialogState extends State<NodeEditDialog> {
  late final TextEditingController _title;
  late final TextEditingController _content;
  String _kind = 'note';

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.node?.title ?? '');
    _content = TextEditingController(text: widget.node?.content ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.dialogTitle),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _title,
            autofocus: true,
            decoration: InputDecoration(
              labelText: widget.i18n.t('dialog.title'),
            ),
            onSubmitted: (_) => _submit(context),
          ),
          if (widget.node == null) ...[
            const SizedBox(height: 12),
            // 创建模式类型选择（M7 回补：AI 节点/文件夹由创建对话框
            // 产生——kind 是数据（metadata），归属判定走结构匹配）。
            DropdownButtonFormField<String>(
              initialValue: _kind,
              decoration: InputDecoration(
                labelText: widget.i18n.t('dialog.type'),
                isDense: true,
              ),
              items: <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(
                  value: 'note',
                  child: Text(widget.i18n.t('node.type.note')),
                ),
                DropdownMenuItem<String>(
                  value: 'folder',
                  child: Text(widget.i18n.t('node.type.folder')),
                ),
                DropdownMenuItem<String>(
                  value: 'ai',
                  child: Text(widget.i18n.t('node.type.ai')),
                ),
              ],
              onChanged: (value) => setState(() => _kind = value ?? 'note'),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _content,
            minLines: 5,
            maxLines: 10,
            decoration: InputDecoration(
              labelText: widget.i18n.t('dialog.content'),
              alignLabelWithHint: true,
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
        onPressed: () => _submit(context),
        child: Text(widget.i18n.t('dialog.save')),
      ),
    ],
  );

  /// 提交表单（标题必填；空标题禁用保存的简化：提交时校验）。
  void _submit(BuildContext context) {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.i18n.t('dialog.titleRequired')),
          duration: const Duration(seconds: 1),
        ),
      );
      return;
    }
    Navigator.pop(context, <String, dynamic>{
      'title': title,
      'content': _content.text,
      'kind': widget.node == null ? _kind : null,
    });
  }
}

/// 新节点 id（无 uuid 依赖：时间戳 + 随机后缀，36 进制紧凑）。
String newNodeId() =>
    'node-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
    '-${(DateTime.now().microsecondsSinceEpoch & 0xFFFF).toRadixString(36)}';
