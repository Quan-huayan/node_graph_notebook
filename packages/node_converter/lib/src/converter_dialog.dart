/// ConverterDialog —— 导入导出对话框（M7.2：converter 插件可见性恢复）。
///
/// 导出 = ExportCommand（全部节点 → JSON 文件，dataRoot/exports/）；
/// 导入 = ImportCommand（JSON 文件 → 节点）。写路径（03 §四：Handler
/// 唯一执行者）——UI 只收集路径/格式。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:flutter/material.dart';

import 'converter_commands.dart';

/// 导入导出对话框。
class ConverterDialog extends StatefulWidget {
  /// 注入宿主。
  const ConverterDialog({super.key, required this.host});

  /// 宿主组合根（命令总线 + 数据目录 + i18n）。
  final HostRuntime host;

  @override
  State<ConverterDialog> createState() => _ConverterDialogState();
}

class _ConverterDialogState extends State<ConverterDialog> {
  final TextEditingController _importPath = TextEditingController();
  bool _busy = false;
  bool _markdown = false; // 导出格式：false = JSON 往返保真；true = markdown 聚合。

  @override
  void dispose() {
    _importPath.dispose();
    super.dispose();
  }

  Future<void> _exportAll() async {
    setState(() => _busy = true);
    // 导出目标：dataRoot/exports/export-<时间戳>.json（文件树可 git 管理）。
    final sep = Platform.pathSeparator;
    final dir = '${widget.host.dataRoot.path}${sep}exports';
    final ext = _markdown ? 'md' : 'json';
    final path =
        '$dir${sep}export-${DateTime.now().microsecondsSinceEpoch}.$ext';
    final result = await widget.host.commandBus
        .dispatch<ExportCommand, ExportResult>(ExportCommand(path: path));
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.host.i18nService
              .t('converter.exported')
              .replaceFirst('%s', '${result.exportedCount}')
              .replaceFirst('%s', path),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _import() async {
    final path = _importPath.text.trim();
    if (path.isEmpty) {
      return;
    }
    setState(() => _busy = true);
    final result = await widget.host.commandBus
        .dispatch<ImportCommand, ImportResult>(ImportCommand(path: path));
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.host.i18nService
              .t('converter.imported')
              .replaceFirst('%s', '${result.importedNodeIds.length}'),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(widget.host.i18nService.t('converter.export')),
        const SizedBox(height: 8),
        // M7.2（用户裁决）：双格式——JSON 往返保真 / Markdown 聚合拆分。
        SegmentedButton<bool>(
          segments: <ButtonSegment<bool>>[
            ButtonSegment<bool>(
              value: false,
              label: Text(widget.host.i18nService.t('converter.formatJson')),
            ),
            ButtonSegment<bool>(
              value: true,
              label: Text(widget.host.i18nService.t('converter.formatMarkdown')),
            ),
          ],
          selected: <bool>{_markdown},
          onSelectionChanged: (selection) =>
              setState(() => _markdown = selection.first),
          showSelectedIcon: false,
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _busy ? null : _exportAll,
          icon: const Icon(Icons.upload_outlined),
          label: Text(widget.host.i18nService.t('converter.exportAll')),
        ),
        const SizedBox(height: 4),
        Text(
          widget.host.i18nService.t(
            _markdown ? 'converter.mdHint' : 'converter.jsonHint',
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const Divider(height: 32),
        Text(widget.host.i18nService.t('converter.importTitle')),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _importPath,
                decoration: InputDecoration(
                  hintText: widget.host.i18nService.t(
                    'converter.importPathHint',
                  ),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _busy ? null : _import,
              child: Text(widget.host.i18nService.t('converter.import')),
            ),
          ],
        ),
      ],
    ),
  );
}
