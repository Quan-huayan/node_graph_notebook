/// CommandPalette —— 命令面板（B1：Obsidian Ctrl+P 语义）。
///
/// 条目 = 数据驱动：内置（新建笔记/聚焦搜索/快速切换/主题切换）+
/// 工具栏动作（kind=='toolbar' 的按钮节点 → 动作名查 ToolbarActionRegistry，
/// 00"All is Node"——按钮即命令入口）。对话框内输入过滤 + 点击执行。
library;

import 'package:flutter/material.dart';

/// 面板条目（标签 + 图标 + 执行回调）。
class PaletteEntry {
  /// 构造条目。
  const PaletteEntry({
    required this.label,
    required this.icon,
    required this.run,
  });

  /// 显示标签。
  final String label;

  /// 图标。
  final IconData icon;

  /// 执行回调。
  final void Function() run;
}

/// 打开命令面板（搜索过滤 + 点击执行）。
///
/// [emptyMessage] 空结果文案（i18n——调用方传词表键解析，本对话框零硬编码）。
Future<void> showCommandPalette(
  BuildContext context,
  List<PaletteEntry> entries, {
  String emptyMessage = '',
}) =>
    showDialog<void>(
      context: context,
      builder: (context) =>
          _CommandPaletteDialog(entries: entries, emptyMessage: emptyMessage),
    );

/// 命令面板对话框。
class _CommandPaletteDialog extends StatefulWidget {
  /// 构造。
  const _CommandPaletteDialog({required this.entries, required this.emptyMessage});

  /// 全部条目。
  final List<PaletteEntry> entries;

  /// 空结果文案。
  final String emptyMessage;

  @override
  State<_CommandPaletteDialog> createState() => _CommandPaletteDialogState();
}

class _CommandPaletteDialogState extends State<_CommandPaletteDialog> {
  final TextEditingController _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final needle = _input.text.trim().toLowerCase();
    final visible = needle.isEmpty
        ? widget.entries
        : widget.entries
            .where((e) => e.label.toLowerCase().contains(needle))
            .toList();
    return Dialog(
      child: SizedBox(
        width: 420,
        // 可滚动列表 + 输入框（高度自适应内容）。
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
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Flexible(
                child: visible.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(widget.emptyMessage),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final entry = visible[index];
                          return ListTile(
                            dense: true,
                            leading: Icon(entry.icon, size: 20),
                            title: Text(entry.label, maxLines: 1),
                            onTap: () {
                              Navigator.pop(context);
                              entry.run();
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
}